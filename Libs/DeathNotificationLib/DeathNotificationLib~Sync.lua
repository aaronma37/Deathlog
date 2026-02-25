--[[
DeathNotificationLib~Sync.lua

Continuous background database sync (day-bucket protocol).

Uses a dedicated channel ("hcdeathlogsyncchannel") separate from the main
death-alert channel.  Peers periodically advertise a compact watermark
(latest timestamp + entry count).  When a peer detects it is behind, a
jittered lazy-election picks one requester who whispers the best peer
with per-day entry counts.  The responder diffs locally and streams only
entries from days where it has more, directly via E$ on the sync channel
so every listener can eavesdrop and fill gaps for free.

Protocol commands (all prefixed with COMM_COMMAND_DELIM "$"):
  W  – watermark advertisement       (sync channel broadcast)
  M  – day-bucket request            (addon whisper to chosen peer)
  E  – entry data response           (sync channel broadcast)
--]]

local _dnl = DeathNotificationLib.Internal ---@class _dnl
if not _dnl then return end

local CTL = _G.ChatThrottleLib

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

_dnl.SYNC_CHANNEL_BASE = "hcdeathlogsyncchannel"

_dnl.sync_channel = _dnl.SYNC_CHANNEL_BASE

local SYNC_CHANNEL_PW       = _dnl.SYNC_CHANNEL_BASE .. "pw"

--- Return the channel number for the sync channel we actually joined.
--- joinSyncChannel() may have fallen back to a suffixed name (e.g.
--- "hcdeathlogsyncchannelb") and stored it in _dnl.sync_channel.
local function getSyncChannelNum()
	return GetChannelName(_dnl.sync_channel or _dnl.SYNC_CHANNEL_BASE)
end

_dnl.SYNC_COMM_NAME = "HCDeathSync"

local SYNC_CMD_WATERMARK    = "W"
local SYNC_CMD_BUCKET_REQ   = "M"
local SYNC_CMD_ENTRY_RES    = "E"

--- Cooldown between full sync sessions (seconds)
local DEFAULT_SYNC_COOLDOWN = 300

--- How long to collect watermarks before picking a peer (seconds)
local WATERMARK_COLLECT_WINDOW = 10

--- Random jitter range before becoming the requester (seconds).
--- Needs to be large enough that the first requester's E$ responses
--- appear on the channel before later jitter timers fire — E$ goes
--- through the hardware-event-gated queue so there is a 1-3s delay
--- between the M$ whisper and the first visible E$.
local JITTER_MAX            = 15

--- Timeout waiting for entry data (seconds)
local RESPONSE_TIMEOUT      = 60

--- Timeout for the responder streaming entries (seconds)
local RESPONDING_TIMEOUT    = 120

--- Minimum entry-count gap before triggering a sync
local SYNC_THRESHOLD        = 5

--- Default settings
local DEFAULT_SYNC_ENABLED      = true
local DEFAULT_SYNC_WINDOW_DAYS  = 7
local DEFAULT_SYNC_INTERVAL     = 300
local DEFAULT_SYNC_MAX_ENTRIES  = 500

---@param settings DNL_Settings|nil  Per-addon settings (nil → default)
---@return number seconds
local function getSyncCooldown(settings)
	local s = settings and settings.sync_cooldown or nil
	if s then
		s = tonumber(s)
		if s and s >= 0 and s <= 3600 then return s end
	end
	return DEFAULT_SYNC_COOLDOWN
end

---------------------------------------------------------------------------
-- Module state
---------------------------------------------------------------------------

local SYNC_STATE = {
	IDLE                  = 0,
	COLLECTING_WATERMARKS = 1,
	JITTER_WAIT           = 2,
	AWAITING_ENTRIES      = 3,
	RESPONDING_ENTRIES    = 4,
}

local state = SYNC_STATE.IDLE

--- Collected watermarks from other peers  { [sender] = { ts, count, window } }
local watermark_peers = {}

--- The peer we chose to sync from
local sync_partner = nil

--- The tag of the addon we're syncing (set during peer election)
local sync_tag = nil

--- Pending multi-chunk bucket request being accumulated (responder side)
--- { sender, window_days, buckets = { [day_index] = count } }
local pending_request = nil

--- Statistics for current / last sync session
local stats = {
	entries_received   = 0,
	entries_sent       = 0,
	last_sync_time     = 0,
	last_sync_entries  = 0,
}

--- Per-addon cooldown timestamps  { [tag] = time_value }
--- Each addon tracks its own cooldown independently so that syncing
--- one addon does not block the others.
local sync_cooldown_per_addon = {}

--- Timer handles (so we can cancel them)
local watermark_ticker   = nil
local collect_timer      = nil
local jitter_timer       = nil
local response_timer     = nil
local responding_timer   = nil

--- Timestamp of the last E$ message seen on the channel (from any peer).
--- Used to suppress new sync triggers while the channel is already busy
--- streaming entries — prevents multiple responders from overlapping.
local last_entry_seen_time = 0

--- How long after seeing E$ traffic to suppress new sync triggers (seconds).
local CHANNEL_BUSY_COOLDOWN = 30

--- Absolute timeout: if the state machine stays non-IDLE for longer
--- than this many seconds, force-reset to IDLE as a safety net.
local ABSOLUTE_TIMEOUT   = 180
local absolute_timer     = nil

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

---Check whether sync is enabled for a specific addon.
---@param settings DNL_Settings|nil  Per-addon settings (nil → default)
---@return boolean
local function isSyncEnabled(settings)
	if settings and settings.sync_enabled == false then
		return false
	end
	return DEFAULT_SYNC_ENABLED
end

---Check whether ANY registered addon has sync enabled.
---Used for global gates (join channel, accept E$ entries).
---@return boolean
local function anySyncEnabled()
	for _, addon in pairs(_dnl.addons) do
		if isSyncEnabled(addon.settings) then return true end
	end
	return false
end

---@param settings DNL_Settings|nil  Per-addon settings (nil → default)
---@return number days
local function getSyncWindowDays(settings)
	local d = settings and settings.sync_window_days or nil
	if d then
		d = tonumber(d)
		if d and (d == -1 or (d >= 1 and d <= 30)) then return d end
	end
	return DEFAULT_SYNC_WINDOW_DAYS
end

---@param settings DNL_Settings|nil  Per-addon settings (nil → default)
---@return number seconds
local function getSyncInterval(settings)
	local s = settings and settings.sync_interval or nil
	if s then
		s = tonumber(s)
		if s and s >= 60 and s <= 3600 then return s end
	end
	return DEFAULT_SYNC_INTERVAL
end

---@param settings DNL_Settings|nil  Per-addon settings (nil → default)
---@return number
local function getSyncMaxEntries(settings)
	local n = settings and settings.sync_max_entries or nil
	if n then
		n = tonumber(n)
		if n and n >= 10 and n <= 2000 then return n end
	end
	return DEFAULT_SYNC_MAX_ENTRIES
end

---Outbound queue for sync channel messages.
---SendChatMessage is a hardware-event-protected function in Classic Era,
---so we cannot call it from timers or coroutines.  Instead we push
---messages here and drain them one-per-event from OnMouseDown/OnKeyDown,
---exactly like Transport.lua does for death alerts.
---@type table[]  Array of {text, enqueue_time}
_dnl.sync_out_queue = {}

---Queue a message for sending on the sync channel.
---The actual send happens on the next hardware event (mouse/key).
---@param text string  Full message including command prefix
local function sendSyncChannel(text)
	-- Watermarks are idempotent: only the latest per addon matters.
	-- Replace any existing W$ with the SAME tag instead of piling duplicates.
	-- Match on "W$TAG~" (6 chars) so each addon keeps its own queue slot.
	local cmd = text:sub(1, 2)  -- e.g. "W$"
	if cmd == SYNC_CMD_WATERMARK .. _dnl.COMM_COMMAND_DELIM then
		local tag_prefix = text:sub(1, 6)  -- e.g. "W$DLG~"
		for i = 1, #_dnl.sync_out_queue do
			local existing = _dnl.sync_out_queue[i][1]
			if existing:sub(1, 6) == tag_prefix then
				_dnl.sync_out_queue[i] = {text, GetServerTime()}
				return
			end
		end
	end
	_dnl.sync_out_queue[#_dnl.sync_out_queue + 1] = {text, GetServerTime()}
end

---Drain one queued sync-channel message.  Called from hardware events.
local function sendNextInQueue()
	if #_dnl.sync_out_queue == 0 then return end

	local channel_num = getSyncChannelNum()
	if channel_num == 0 then
		_dnl.joinSyncChannel()
		return
	end

	if _dnl.safeSendChannel(_dnl.sync_out_queue[1][1], channel_num) then
		table.remove(_dnl.sync_out_queue, 1)
	end
end

---Send an addon whisper via CTL (NORMAL priority for control messages).
---@param target string  Player name (or Name-Realm)
---@param text string    Full message including command prefix
local function sendAddonWhisper(target, text)
	if CTL then
		CTL:SendAddonMessage("NORMAL", _dnl.SYNC_COMM_NAME, text, "WHISPER", target)
	else
		_G.SendAddonMessage(_dnl.SYNC_COMM_NAME, text, "WHISPER", target)
	end
end

---Cancel a timer handle safely.
---@param handle table|nil
local function cancelTimer(handle)
	if handle then
		pcall(function() handle:Cancel() end)
	end
end

---Reset state machine to IDLE.
local function resetToIdle()
	state = SYNC_STATE.IDLE
	sync_partner = nil
	sync_tag = nil
	pending_request = nil
	cancelTimer(collect_timer)
	cancelTimer(jitter_timer)
	cancelTimer(response_timer)
	cancelTimer(responding_timer)
	cancelTimer(absolute_timer)
	collect_timer    = nil
	jitter_timer     = nil
	response_timer   = nil
	responding_timer = nil
	absolute_timer   = nil
	last_entry_seen_time = 0
end

--- Start the absolute timeout safety net.  Called whenever the state
--- machine leaves IDLE.  If it ever fires, something went wrong and
--- we force-reset to prevent the state machine from getting stuck.
local function startAbsoluteTimeout()
	cancelTimer(absolute_timer)
	absolute_timer = C_Timer.NewTimer(ABSOLUTE_TIMEOUT, function()
		absolute_timer = nil
		if state ~= SYNC_STATE.IDLE then
			if _dnl.DEBUG then
				print("[DNL Sync] Absolute timeout (" .. ABSOLUTE_TIMEOUT .. "s) — force-resetting to IDLE")
			end
			resetToIdle()
		end
	end)
end

---------------------------------------------------------------------------
-- Per-addon database helpers
---------------------------------------------------------------------------

--- Return all registered addons that have a database (sync-eligible).
---@return DNL_RegisteredAddon[]
local function getSyncAddons()
	local result = {}
	for _, addon in pairs(_dnl.addons) do
		if addon.db then
			result[#result + 1] = addon
		end
	end
	return result
end

--- Resolve an addon from a 3-char tag.  Returns nil for unknown tags.
---@param tag string|nil
---@return DNL_RegisteredAddon|nil
local function addonForTag(tag)
	if not tag then return nil end
	local name = _dnl.tag_to_addon[tag]
	return name and _dnl.addons[name] or nil
end

---------------------------------------------------------------------------
-- Watermark: compute local stats, broadcast, and listen
---------------------------------------------------------------------------

---Compute local watermark for a specific addon's database.
---@param db table  The addon's db table
---@param window_days number  Lookback window in days (-1 = all)
---@return number latest_timestamp  Newest death date in window
---@return number count             Number of entries in window
local function computeLocalWatermark(db, window_days)
	if not db then return 0, 0 end
	local cutoff = (window_days == -1) and 0 or (GetServerTime() - window_days * 86400)
	local latest = 0
	local count  = 0
	for _, entry in pairs(db) do
		local d = entry.date or 0
		if d >= cutoff then
			count = count + 1
			if d > latest then latest = d end
		end
	end
	return latest, count
end

---Count local entries within an arbitrary day range for a specific db.
---@param db table  The addon's db table
---@param days number  Window in days (-1 = all)
---@return number count
local function countLocalEntries(db, days)
	if not db then return 0 end
	local cutoff = (days == -1) and 0 or (GetServerTime() - days * 86400)
	local count = 0
	for _, entry in pairs(db) do
		if (entry.date or 0) >= cutoff then
			count = count + 1
		end
	end
	return count
end

---Broadcast watermarks on the sync channel — one per addon with a database.
---Each addon's own settings determine whether it syncs and its window.
---Format: "W$TAG~ts~count~window~addon_version~"
local function broadcastWatermark()
	local ch = getSyncChannelNum()
	if ch == 0 then return end
	for _, addon in pairs(_dnl.addons) do
		if addon.db and isSyncEnabled(addon.settings) then
			local window = getSyncWindowDays(addon.settings)
			local ts, count = computeLocalWatermark(addon.db, window)
			local msg = SYNC_CMD_WATERMARK
				.. _dnl.COMM_COMMAND_DELIM
				.. addon.tag .. _dnl.COMM_FIELD_DELIM
				.. ts .. _dnl.COMM_FIELD_DELIM
				.. count .. _dnl.COMM_FIELD_DELIM
				.. window .. _dnl.COMM_FIELD_DELIM
				.. (addon.addon_version or "") .. _dnl.COMM_FIELD_DELIM
			sendSyncChannel(msg)
		end
	end
end

---------------------------------------------------------------------------
-- Day-bucket helpers
---------------------------------------------------------------------------

--- UTC day index for a unix timestamp.
---@param ts number  Unix timestamp
---@return number  Day index (integer)
local function dayIndex(ts)
	return math.floor(ts / 86400)
end

--- Extract the numeric suffix from a fletcher16 checksum string.
--- Checksum format is "PlayerName-NNNNN" where NNNNN is 0–65535.
---@param cs string  Checksum string
---@return number  Numeric portion (0 if unparseable)
local function checksumNumeric(cs)
	local n = cs:match("%-(%d+)$")
	return tonumber(n) or 0
end

--- Build a full day-index from a specific addon's database in a single pass.
--- Returns per-day counts, XOR hashes (for divergence detection), and
--- entry lists sorted newest-first — everything the protocol needs.
---@param db table  The addon's db table
---@param window_days number  Number of days (-1 = all)
---@return table  { [day_index] = { count=N, hash=H, entries={{checksum,data},...} } }
local function buildDayIndex(db, window_days)
	if not db then return {} end
	local cutoff = (window_days == -1) and 0 or (GetServerTime() - window_days * 86400)
	local index = {}
	local bxor = bit.bxor
	for cs, entry in pairs(db) do
		local d = entry.date or 0
		if d >= cutoff then
			local di = dayIndex(d)
			local day = index[di]
			if not day then
				day = { count = 0, hash = 0, entries = {} }
				index[di] = day
			end
			day.count = day.count + 1
			day.hash  = bxor(day.hash, checksumNumeric(cs))
			day.entries[#day.entries + 1] = { checksum = cs, data = entry }
		end
	end
	-- Sort each day's entries newest-first so the most-likely-missing
	-- entries (newest) are sent first within the max_entries cap.
	for _, day in pairs(index) do
		table.sort(day.entries, function(a, b)
			return (a.data.date or 0) > (b.data.date or 0)
		end)
	end
	return index
end

---------------------------------------------------------------------------
-- Addon version upgrade hints
---------------------------------------------------------------------------

--- Per-tag tracking for addon version upgrade notifications.
--- Mirrors the protocol-version hint logic in ~Cache.lua, but operates
--- per-addon (keyed by tag) and uses the semantic version string from
--- the watermark rather than the protocol_version integer.
---
--- Structure:  { [tag] = { senders = { [sender] = true }, warned = { [ver] = true } } }
---@type table<string, { senders: table<string, boolean>, warned: table<string, boolean> }>
local addon_version_hint_state = {}

--- Number of unique senders advertising a newer addon version before
--- we print a chat notification.
local ADDON_VERSION_HINT_THRESHOLD = 3

---Check whether a remote peer's addon version is newer than ours and,
---after enough unique senders confirm, print a one-time chat hint.
---@param tag string           3-char addon tag
---@param sender string        Sender's character name
---@param remote_ver string|nil  Remote addon version string (may be nil/"")
function _dnl._checkAddonVersionHint(tag, sender, remote_ver)
	if not remote_ver or remote_ver == "" then return end

	local local_addon = _dnl.addons[_dnl.tag_to_addon[tag]]
	if not local_addon or not local_addon.addon_version then return end

	local cmp = _dnl.compareVersions(remote_ver, local_addon.addon_version)
	if not cmp or cmp <= 0 then return end  -- not newer or invalid

	if not addon_version_hint_state[tag] then
		addon_version_hint_state[tag] = { senders = {}, warned = {} }
	end
	local hint_state = addon_version_hint_state[tag]

	if hint_state.warned[remote_ver] then return end

	hint_state.senders[sender] = true
	local count = 0
	for _ in pairs(hint_state.senders) do count = count + 1 end

	if count >= ADDON_VERSION_HINT_THRESHOLD then
		hint_state.warned[remote_ver] = true
		wipe(hint_state.senders)

		-- Store the newest detected version on the addon entry so consumers
		-- (e.g. info_button) can query it via GetNewerAddonVersion().
		if not local_addon.newest_detected_version
			or _dnl.compareVersions(remote_ver, local_addon.newest_detected_version) == 1 then
			local_addon.newest_detected_version = remote_ver
		end

		print(string.format(
			"|cffFFFF00[%s]|r A newer version (v%s) is available — you are running v%s. Please update!",
			local_addon.name, remote_ver, local_addon.addon_version))

		-- Fire HookOnNewerVersion callbacks so consumers (e.g. info_button)
		-- can react immediately without polling.
		if _dnl.hook_newer_version_functions then
			for _, fn in ipairs(_dnl.hook_newer_version_functions) do
				fn(local_addon.name, remote_ver, local_addon.addon_version)
			end
		end
	end
end

---------------------------------------------------------------------------
-- Incoming watermark handler
---------------------------------------------------------------------------

---Handle a watermark broadcast from another peer.
---Format: "TAG~ts~count~window~addon_version~"
---@param sender string
---@param payload string
function _dnl.handleSyncWatermark(sender, payload)
	if sender == UnitName("player") then return end

	local values = {}
	for w in payload:gmatch("(.-)~") do
		table.insert(values, w)
	end
	local tag    = values[1]
	local ts     = tonumber(values[2])
	local count  = tonumber(values[3])
	local window = tonumber(values[4])
	local remote_addon_version = values[5]  -- may be nil or "" for old clients
	if not tag or not ts or not count or not window then return end

	-- ── Addon version upgrade hint ──────────────────────────────────
	_dnl._checkAddonVersionHint(tag, sender, remote_addon_version)

	-- Find the local addon matching this tag
	local local_addon = addonForTag(tag)
	if not local_addon or not local_addon.db then return end

	-- Gate on this specific addon's sync_enabled setting
	if not isSyncEnabled(local_addon.settings) then return end

	watermark_peers[sender .. ":" .. tag] = { ts = ts, count = count, window = window, tag = tag }

	-- If we're already syncing, just store the watermark
	if state ~= SYNC_STATE.IDLE then return end
	-- Per-addon cooldown: skip if THIS addon is still on cooldown
	if GetServerTime() < (sync_cooldown_per_addon[tag] or 0) then return end
	-- Channel-busy cooldown: skip if E$ traffic was seen recently,
	-- meaning another sync session is already streaming entries.
	if GetServerTime() - last_entry_seen_time < CHANNEL_BUSY_COOLDOWN then return end

	local local_window = getSyncWindowDays(local_addon.settings)
	local cmp_window = math.min(
		local_window == -1 and 9999 or local_window,
		window == -1 and 9999 or window)
	local local_count = countLocalEntries(local_addon.db, cmp_window)
	if count - local_count < SYNC_THRESHOLD then return end

	-- Start collecting watermarks to find the best peer
	state = SYNC_STATE.COLLECTING_WATERMARKS
	startAbsoluteTimeout()
	wipe(watermark_peers)
	watermark_peers[sender .. ":" .. tag] = { ts = ts, count = count, window = window, tag = tag }

	if _dnl.DEBUG then
		print(string.format("[DNL Sync] Behind peer %s (tag=%s) by %d entries, collecting watermarks…",
			sender, tag, count - local_count))
	end

	cancelTimer(collect_timer)
	collect_timer = C_Timer.NewTimer(WATERMARK_COLLECT_WINDOW, function()
		collect_timer = nil
		_dnl._syncPickPeerAndJitter()
	end)
end

---------------------------------------------------------------------------
-- Peer election + jitter
---------------------------------------------------------------------------

---Pick the best peer from collected watermarks, then jitter before requesting.
function _dnl._syncPickPeerAndJitter()
	if state ~= SYNC_STATE.COLLECTING_WATERMARKS then return end

	-- Abort if E$ traffic appeared during the collect window — another
	-- sync session is already streaming and we should just consume passively.
	if GetServerTime() - last_entry_seen_time < CHANNEL_BUSY_COOLDOWN then
		if _dnl.DEBUG then
			print("[DNL Sync] Channel busy (E$ seen recently) — aborting sync trigger")
		end
		resetToIdle()
		return
	end

	-- Pick the peer:addon combination with the largest entry gap,
	-- skipping addons that are still on their own cooldown.
	local best_key, best_gap, best_tag = nil, 0, nil
	local now = GetServerTime()
	for key, info in pairs(watermark_peers) do
		local addon = addonForTag(info.tag)
		if addon and addon.db and isSyncEnabled(addon.settings) then
			if now >= (sync_cooldown_per_addon[info.tag] or 0) then
				local local_window = getSyncWindowDays(addon.settings)
				local cmp_window = math.min(
					local_window == -1 and 9999 or local_window,
					info.window == -1 and 9999 or info.window)
				local local_count = countLocalEntries(addon.db, cmp_window)
				local gap = info.count - local_count
				if gap > best_gap then
					best_key = key
					best_gap = gap
					best_tag = info.tag
				end
			end
		end
	end

	if not best_key or best_gap < SYNC_THRESHOLD then
		resetToIdle()
		return
	end

	-- Extract sender name from key ("SenderName:TAG")
	local sender_name = best_key:match("^(.+):")
	sync_partner = sender_name
	sync_tag = best_tag
	state = SYNC_STATE.JITTER_WAIT

	local jitter = math.random() * JITTER_MAX
	if _dnl.DEBUG then
		print(string.format("[DNL Sync] Best peer: %s (tag=%s, gap=%d). Jitter: %.1fs",
			sender_name, best_tag, best_gap, jitter))
	end

	cancelTimer(jitter_timer)
	jitter_timer = C_Timer.NewTimer(jitter, function()
		jitter_timer = nil
		_dnl._syncSendBucketRequest()
	end)
end

---------------------------------------------------------------------------
-- Bucket request (requester side, replaces the old manifest phase)
---------------------------------------------------------------------------

---Send a day-bucket request to the chosen peer.
---Format: "M$TAG~<window>~<d0>:<c0>~<d1>:<c1>~...~<has_more>~"
---Continuation chunks use "+" as window field: "M$TAG~+~<dN>:<cN>~...~<has_more>~"
function _dnl._syncSendBucketRequest()
	-- If we saw E$ traffic during jitter, someone else already triggered a sync.
	if state ~= SYNC_STATE.JITTER_WAIT then return end

	if not sync_partner or not sync_tag then
		resetToIdle()
		return
	end

	local local_addon = addonForTag(sync_tag)
	if not local_addon or not local_addon.db then
		resetToIdle()
		return
	end

	local window = getSyncWindowDays(local_addon.settings)
	local day_idx = buildDayIndex(local_addon.db, window)

	-- Flatten to sorted array of { day_index, count, hash } for deterministic order
	local sorted = {}
	for di, info in pairs(day_idx) do
		sorted[#sorted + 1] = { di = di, c = info.count, h = info.hash }
	end
	table.sort(sorted, function(a, b) return a.di < b.di end)

	state = SYNC_STATE.AWAITING_ENTRIES
	stats.entries_received = 0

	if _dnl.DEBUG then
		print(string.format("[DNL Sync] Sending bucket request to %s (%d days, %d buckets)",
			sync_partner, window, #sorted))
	end

	-- Pack buckets into 255-byte whisper chunks.
	-- First chunk: "M$TAG~<window>~<d>:<c>~...~<has_more>~"
	-- Continuation: "M$TAG~+~<d>:<c>~...~<has_more>~"
	-- Prefix "M$" = 2 bytes. Tag+delim = 4 bytes. Suffix "~0~" or "~1~" = 3 bytes.
	local PREFIX_LEN   = 2  -- "M$"
	local TAG_LEN      = 4  -- "TAG~"
	local SUFFIX_LEN   = 3  -- "~0~" or "~1~"
	local MAX_MSG      = 255
	local idx          = 1
	local is_first     = true

	local function sendNextChunk()
		-- Header field: window (first chunk) or "+" (continuation)
		local header = is_first and tostring(window) or "+"
		local header_field = header .. _dnl.COMM_FIELD_DELIM  -- e.g. "7~" or "+~"
		local overhead = PREFIX_LEN + TAG_LEN + #header_field + SUFFIX_LEN
		local budget   = MAX_MSG - overhead

		local parts = {}
		local bytes = 0
		while idx <= #sorted do
			local pair_str = sorted[idx].di .. ":" .. sorted[idx].c .. ":" .. sorted[idx].h
			local pair_len = #pair_str + 1  -- +1 for trailing "~"
			if bytes + pair_len > budget and #parts > 0 then
				break
			end
			parts[#parts + 1] = pair_str
			bytes = bytes + pair_len
			idx = idx + 1
		end

		local has_more = (idx <= #sorted) and "1" or "0"
		local msg = SYNC_CMD_BUCKET_REQ
			.. _dnl.COMM_COMMAND_DELIM
			.. sync_tag .. _dnl.COMM_FIELD_DELIM
			.. header_field
			.. table.concat(parts, _dnl.COMM_FIELD_DELIM)
			.. _dnl.COMM_FIELD_DELIM
			.. has_more
			.. _dnl.COMM_FIELD_DELIM

		sendAddonWhisper(sync_partner, msg)
		is_first = false

		if idx <= #sorted then
			C_Timer.After(0.1, sendNextChunk)
		end
	end

	sendNextChunk()

	-- Timeout: if no entries arrive, finish
	cancelTimer(response_timer)
	response_timer = C_Timer.NewTimer(RESPONSE_TIMEOUT, function()
		response_timer = nil
		if state == SYNC_STATE.AWAITING_ENTRIES then
			_dnl._syncFinish("timeout")
		end
	end)
end

---------------------------------------------------------------------------
-- Bucket request handler (responder side)
---------------------------------------------------------------------------

---Handle an incoming day-bucket request (we are the responder).
---Accumulates multi-chunk M$ messages, then diffs and streams E$ directly.
---Format: "TAG~<window|+>~<d>:<c>~...~<has_more>~"
---@param sender string
---@param payload string
function _dnl.handleSyncBucketRequest(sender, payload)
	local values = {}
	for w in payload:gmatch("(.-)~") do
		values[#values + 1] = w
	end
	if #values < 3 then return end

	-- First field is always the tag
	local req_tag = values[1]
	local local_addon = addonForTag(req_tag)
	if not local_addon or not local_addon.db then return end

	-- Gate on this specific addon's sync_enabled setting
	if not isSyncEnabled(local_addon.settings) then return end

	local header = values[2]
	local has_more = values[#values]

	if header ~= "+" then
		-- First chunk of a new request — only respond if idle
		if state ~= SYNC_STATE.IDLE then return end

		local window = tonumber(header)
		if not window then return end

		pending_request = {
			sender      = sender,
			window_days = window,
			tag         = req_tag,
			buckets     = {},
		}
	else
		-- Continuation chunk — must match current pending sender and tag
		if not pending_request or pending_request.sender ~= sender or pending_request.tag ~= req_tag then return end
	end

	-- Parse day:count:hash triples from values[3] .. values[#values - 1]
	for i = 3, #values - 1 do
		local d_str, c_str, h_str = values[i]:match("^(%d+):(%d+):(%d+)$")
		if d_str and c_str and h_str then
			local di = tonumber(d_str)
			local c  = tonumber(c_str)
			local h  = tonumber(h_str)
			if di and c and h then
				pending_request.buckets[di] = { count = c, hash = h }
			end
		end
	end

	if has_more == "1" then
		-- More chunks coming — wait
		return
	end

	-- All chunks received — compute diff and stream entries
	local req = pending_request
	pending_request = nil

	-- Re-resolve addon (in case it was deregistered between chunks)
	local resp_addon = addonForTag(req.tag)
	if not resp_addon or not resp_addon.db then return end

	if _dnl.DEBUG then
		local bc = 0; for _ in pairs(req.buckets) do bc = bc + 1 end
		print(string.format("[DNL Sync] Bucket request from %s (tag=%s): window=%d, %d day-buckets",
			req.sender, req.tag, req.window_days, bc))
	end

	state = SYNC_STATE.RESPONDING_ENTRIES

	-- Start a safety timeout so the state machine doesn't stick
	-- in RESPONDING_ENTRIES if sendNextBatch errors or stalls.
	cancelTimer(responding_timer)
	responding_timer = C_Timer.NewTimer(RESPONDING_TIMEOUT, function()
		responding_timer = nil
		if state == SYNC_STATE.RESPONDING_ENTRIES then
			if _dnl.DEBUG then
				print("[DNL Sync] Responding timeout \226\128\148 resetting to IDLE")
			end
			resetToIdle()
		end
	end)

	local day_idx = buildDayIndex(resp_addon.db, req.window_days)

	-- Identify days where we have more entries OR same count but different hash
	local short_days = {}
	for di, my_day in pairs(day_idx) do
		local their = req.buckets[di]
		local their_count = their and their.count or 0
		local their_hash  = their and their.hash  or 0
		if my_day.count > their_count
			or (my_day.count == their_count and my_day.hash ~= their_hash) then
			short_days[#short_days + 1] = {
				di  = di,
				gap = my_day.count - their_count,
			}
		end
	end

	-- Sort by gap descending so the biggest mismatches go first
	table.sort(short_days, function(a, b) return a.gap > b.gap end)

	-- Collect entries from short days, capped at max_entries.
	-- buildDayIndex already sorted each day's entries newest-first.
	local max_entries = getSyncMaxEntries(resp_addon.settings)
	local to_send = {}
	for _, sd in ipairs(short_days) do
		if #to_send >= max_entries then break end
		local day = day_idx[sd.di]
		if day then
			for _, e in ipairs(day.entries) do
				to_send[#to_send + 1] = e
				if #to_send >= max_entries then break end
			end
		end
	end

	if #to_send == 0 then
		if _dnl.DEBUG then
			print("[DNL Sync] No entries to send (requester is up to date)")
		end
		cancelTimer(responding_timer)
		responding_timer = nil
		state = SYNC_STATE.IDLE
		return
	end

	if _dnl.DEBUG then
		print(string.format("[DNL Sync] Streaming %d entries across %d short days",
			#to_send, #short_days))
	end

	-- Stream entries as E$ messages on the sync channel.
	-- Format: "E$TAG~encoded_data" or "E$TAG~entry1;entry2;..."
	-- Pack multiple entries per message using ";" separator.
	local MAX_PAYLOAD = 249  -- 255 (wire limit) - 2 ("E$") - 4 ("TAG~")
	local ENTRY_SEP   = ";"
	local send_idx    = 1
	local queued      = 0
	local resp_tag    = req.tag

	local function sendNextBatch()
		if send_idx > #to_send then
			cancelTimer(responding_timer)
			responding_timer = nil
			state = SYNC_STATE.IDLE
			if _dnl.DEBUG then
				print(string.format("[DNL Sync] Finished streaming %d entries", queued))
			end
			return
		end

		local buf    = nil
		local buflen = 0

		local function flushBuf()
			if buf then
				local msg = SYNC_CMD_ENTRY_RES
					.. _dnl.COMM_COMMAND_DELIM
					.. resp_tag .. _dnl.COMM_FIELD_DELIM
					.. buf
				sendSyncChannel(msg)
			end
			buf    = nil
			buflen = 0
		end

		-- Pack entries into the current batch until we've queued a few messages
		local msgs_this_batch = 0
		local MAX_MSGS_PER_BATCH = 5

		while send_idx <= #to_send and msgs_this_batch < MAX_MSGS_PER_BATCH do
			local entry = to_send[send_idx]
			local encoded = _dnl.encodeMessage(entry.data, 4)  -- 4 bytes for "TAG~" prefix
			if encoded then
				local elen = #encoded
				if elen > MAX_PAYLOAD then
					-- Single entry exceeds budget (should not happen after
					-- encodeMessage truncation, but guard defensively).
					if _dnl.DEBUG then
						print("[DNL Sync] WARNING: encoded entry exceeds MAX_PAYLOAD ("
							.. elen .. " > " .. MAX_PAYLOAD .. "), skipping")
					end
				elseif buf == nil then
					buf    = encoded
					buflen = elen
				elseif buflen + 1 + elen <= MAX_PAYLOAD then
					buf    = buf .. ENTRY_SEP .. encoded
					buflen = buflen + 1 + elen
				else
					flushBuf()
					msgs_this_batch = msgs_this_batch + 1
					buf    = encoded
					buflen = elen
				end
				queued = queued + 1
				stats.entries_sent = stats.entries_sent + 1
			end
			send_idx = send_idx + 1
		end
		flushBuf()
		msgs_this_batch = msgs_this_batch + 1

		if send_idx <= #to_send then
			C_Timer.After(0.1, sendNextBatch)
		else
			cancelTimer(responding_timer)
			responding_timer = nil
			state = SYNC_STATE.IDLE
			if _dnl.DEBUG then
				print(string.format("[DNL Sync] Finished streaming %d entries", queued))
			end
		end
	end

	sendNextBatch()
end

---------------------------------------------------------------------------
-- Entry response handler (requester + passive listeners)
---------------------------------------------------------------------------

---Process a single decoded entry from a sync E$ message.
---@param single_payload string  Encoded PlayerData
---@param tag string|nil  3-char addon tag from the E$ message
function _dnl._processSyncEntry(single_payload, tag)
	if not single_payload or single_payload == "" then return end

	-- Tag is required to know which addon this entry belongs to
	if not tag then return end
	local target_addon = addonForTag(tag)
	if not target_addon or not target_addon.db then return end

	local decoded, protocol_version = _dnl.decodeMessage(single_payload)
	if not decoded then return end
	if protocol_version and (protocol_version < _dnl.MIN_SUPPORTED_PROTOCOL_VERSION or protocol_version > _dnl.PROTOCOL_VERSION) then return end
	if not _dnl.isValidEntry(decoded) then return end

	local checksum = _dnl.fletcher16(decoded)

	-- Skip if the target addon already has this entry (exact checksum match)
	if target_addon.db[checksum] then return end

	-- Name-based dedup: skip if the addon's db already contains an entry
	-- for this player name with a date within the dedup window.
	-- This catches duplicates where different guild/source info produces
	-- a different fletcher16 checksum for the same death event.
	local dead_name = decoded["name"]
	local dead_date = decoded["date"] or 0
	if dead_name and target_addon.db_map then
		-- Quick check via db_map (latest entry for this name)
		local mapped_cs = target_addon.db_map[dead_name]
		if mapped_cs and target_addon.db[mapped_cs] then
			local existing = target_addon.db[mapped_cs]
			local effective_level = math.max(tonumber(decoded["level"]) or 0, tonumber(existing["level"]) or 0)
			local dedup_window = _dnl.getDedupWindow(effective_level)
			if math.abs(dead_date - (existing["date"] or 0)) <= dedup_window then
				-- Near-duplicate exists — merge into existing, skip
				local merged = _dnl.mergeEntries(existing, decoded)
				target_addon.db[mapped_cs] = merged
				return
			end
		end
	end

	-- Feed through createEntry targeting only this addon
	decoded["date"] = decoded["date"] or GetServerTime()
	_dnl.createEntry(decoded, checksum, 0, nil, _dnl.SOURCE.SYNC, target_addon.name)

	stats.entries_received = stats.entries_received + 1
end

--- Backlog of raw E$ payloads waiting to be processed.
--- handleSyncEntry pushes {tag, single_payload} tuples here;
--- a periodic ticker drains them in small batches to avoid
--- frame spikes when many E$ messages arrive at once.
---@type table[]  Array of {tag, single_payload}
local sync_entry_backlog = {}

--- Max entries to process per tick (one tick = 0.05s).
local SYNC_PROCESS_BATCH = 8

--- Drain up to SYNC_PROCESS_BATCH entries from the backlog.
local function drainSyncBacklog()
	local processed = 0
	while #sync_entry_backlog > 0 and processed < SYNC_PROCESS_BATCH do
		local item = table.remove(sync_entry_backlog, 1)
		_dnl._processSyncEntry(item[1], item[2])
		processed = processed + 1
	end
	if #sync_entry_backlog > 0 then
		C_Timer.After(0.05, drainSyncBacklog)
	end
end

---Handle an incoming entry broadcast on the sync channel.
---Both the active requester and any passive listener consume this.
---Format: "TAG~encoded_data" or "TAG~entry1;entry2;..."
---@param sender string
---@param payload string
function _dnl.handleSyncEntry(sender, payload)
	if not anySyncEnabled() then return end
	if sender == UnitName("player") then return end

	-- Parse tag from payload: "TAG~rest..."
	local tag, entry_data = nil, payload
	if payload and #payload > 4 and payload:sub(4, 4) == _dnl.COMM_FIELD_DELIM then
		tag = payload:sub(1, 3)
		entry_data = payload:sub(5)
	end

	-- Tag is required to route entries to the correct addon
	if not tag then return end

	-- E$ messages may contain multiple entries separated by ";"
	-- Push into backlog for batched processing to avoid frame spikes.
	local entries = { strsplit(";", entry_data) }
	local was_empty = #sync_entry_backlog == 0
	for _, single_payload in ipairs(entries) do
		sync_entry_backlog[#sync_entry_backlog + 1] = { single_payload, tag }
	end
	if was_empty and #sync_entry_backlog > 0 then
		C_Timer.After(0.05, drainSyncBacklog)
	end

	-- If we're the active requester, reset the response timeout on each entry
	if state == SYNC_STATE.AWAITING_ENTRIES then
		cancelTimer(response_timer)
		response_timer = C_Timer.NewTimer(RESPONSE_TIMEOUT, function()
			response_timer = nil
			_dnl._syncFinish("complete")
		end)
	end

	-- If we were in JITTER_WAIT, someone else triggered sync — go passive
	if state == SYNC_STATE.JITTER_WAIT then
		cancelTimer(jitter_timer)
		jitter_timer = nil
		state = SYNC_STATE.IDLE
		if _dnl.DEBUG then
			print("[DNL Sync] Another requester active — consuming passively")
		end
	end

	-- Track when we last saw E$ traffic so we can suppress new sync
	-- triggers while the channel is busy (CHANNEL_BUSY_COOLDOWN).
	last_entry_seen_time = GetServerTime()
end

---------------------------------------------------------------------------
-- Finish / cleanup
---------------------------------------------------------------------------

---@param reason string  "complete" | "timeout"
function _dnl._syncFinish(reason)
	local received = stats.entries_received

	-- Capture the syncing addon's tag and cooldown BEFORE resetToIdle clears sync_tag
	local finished_tag = sync_tag
	local sync_addon = finished_tag and addonForTag(finished_tag) or nil
	local cooldown = getSyncCooldown(sync_addon and sync_addon.settings or nil)

	stats.last_sync_time    = GetServerTime()
	stats.last_sync_entries = received
	stats.entries_received  = 0

	if _dnl.DEBUG and received > 0 then
		print(string.format("[DNL Sync] Sync %s: received %d entries", reason, received))
	end

	resetToIdle()
	if finished_tag then
		sync_cooldown_per_addon[finished_tag] = GetServerTime() + cooldown
	end
end

---------------------------------------------------------------------------
-- Sync channel management
---------------------------------------------------------------------------

local sync_channel_join_attempts = 5

function _dnl.joinSyncChannel()
	-- Always join the sync channel even when sync is disabled:
	-- we still need to receive watermark broadcasts that carry
	-- addon-version upgrade hints from other players.

	local channel_name = _dnl.SYNC_CHANNEL_BASE
	LeaveChannelByName(channel_name)

	C_Timer.After(3.0, function()
		JoinChannelByName(channel_name, SYNC_CHANNEL_PW)
	end)

	_dnl.hideChannelFromChatFrames(channel_name)

	local remaining = sync_channel_join_attempts
	C_Timer.NewTicker(4, function(self)
		if remaining < 1 then
			self:Cancel()
			return
		end
		local ch = GetChannelName(channel_name)
		if ch ~= 0 then
			self:Cancel()
			_dnl.sync_channel = channel_name
			_dnl._startSyncWatermarkTicker()
			return
		end
		remaining = remaining - 1
		channel_name = channel_name .. "b"
		JoinChannelByName(channel_name, SYNC_CHANNEL_PW)
	end)
end

---------------------------------------------------------------------------
-- Watermark ticker (starts after successfully joining the sync channel)
---------------------------------------------------------------------------

function _dnl._stopSyncWatermarkTicker()
	if watermark_ticker then
		cancelTimer(watermark_ticker)
		watermark_ticker = nil
		if _dnl.DEBUG then
			print("[DNL Sync] Watermark ticker stopped")
		end
	end
end

function _dnl._startSyncWatermarkTicker()
	if watermark_ticker then return end

	-- Use the minimum sync_interval across all registered addons
	-- (not gated on isSyncEnabled so watermarks carrying addon-version
	-- hints from peers are still received on the channel listener).
	local min_interval = DEFAULT_SYNC_INTERVAL
	for _, addon in pairs(_dnl.addons) do
		local iv = getSyncInterval(addon.settings)
		if iv < min_interval then min_interval = iv end
	end

	-- Jitter the first watermark (10-40s) so clients that log in at
	-- the same time don't all broadcast simultaneously.
	local initial_delay = 10 + math.random() * 30
	C_Timer.After(initial_delay, broadcastWatermark)

	-- Jitter ongoing ticks by ±20% to prevent phase-locking.
	-- C_Timer.NewTicker fires at a fixed rate, so we re-schedule
	-- ourselves with a randomised delay each time instead.
	local function scheduleNext()
		local jittered = min_interval * (0.8 + math.random() * 0.4)
		watermark_ticker = C_Timer.NewTimer(jittered, function()
			broadcastWatermark()
			scheduleNext()
		end)
	end
	C_Timer.After(initial_delay + 1, scheduleNext)

	if _dnl.DEBUG then
		print(string.format("[DNL Sync] Watermark ticker started (base interval: %ds, initial delay: %.0fs)",
			min_interval, initial_delay))
	end
end

---------------------------------------------------------------------------
-- Status / debug
---------------------------------------------------------------------------

local STATE_NAMES = {
	[SYNC_STATE.IDLE]                  = "IDLE",
	[SYNC_STATE.COLLECTING_WATERMARKS] = "COLLECTING_WATERMARKS",
	[SYNC_STATE.JITTER_WAIT]           = "JITTER_WAIT",
	[SYNC_STATE.AWAITING_ENTRIES]      = "AWAITING_ENTRIES",
	[SYNC_STATE.RESPONDING_ENTRIES]    = "RESPONDING_ENTRIES",
}

---Print current sync status to chat (per-addon breakdown).
function _dnl.syncStatus()
	print("|cff00CCFF[DNL Sync]|r Status:")
	print("  State:          " .. (STATE_NAMES[state] or tostring(state)))
	print("  Sync partner:   " .. (sync_partner or "none"))
	print("  Known peers:    " .. _dnl._syncCountPeers())
	print("  Last sync:      " .. (stats.last_sync_time > 0
		and date("%Y-%m-%d %H:%M:%S", stats.last_sync_time) or "never"))
	print("  Last sync size: " .. stats.last_sync_entries .. " entries")

	for name, addon in pairs(_dnl.addons) do
		local enabled = isSyncEnabled(addon.settings)
		local wd = getSyncWindowDays(addon.settings)
		local count = 0
		if addon.db then
			_, count = computeLocalWatermark(addon.db, wd)
		end
		local cd = (sync_cooldown_per_addon[addon.tag] or 0) - GetServerTime()
		local cd_str = cd > 0 and string.format(", cd=%ds", math.floor(cd)) or ""
		print(string.format("  [%s] (%s): sync=%s, window=%s, entries=%d%s",
			name, addon.tag, tostring(enabled),
			wd == -1 and "ALL" or (wd .. "d"), count, cd_str))
	end
end

---@return number
function _dnl._syncCountPeers()
	local n = 0
	for _ in pairs(watermark_peers) do n = n + 1 end
	return n
end

---------------------------------------------------------------------------
-- Channel message dispatch (called from Events.lua via CHAT_MSG_CHANNEL)
-- Since SendAddonMessage with "CHANNEL" is disabled on Classic,
-- sync traffic is sent as regular chat and arrives here.
---------------------------------------------------------------------------

local SYNC_CMD_LABELS = {
	[SYNC_CMD_WATERMARK]  = "WATERMARK",
	[SYNC_CMD_BUCKET_REQ] = "BUCKET_REQ",
	[SYNC_CMD_ENTRY_RES]  = "ENTRY_RES",
}

---Handle a sync message received via CHAT_MSG_ADDON (whisper-based commands).
---Commands: M (day-bucket request).
---@param arg table  CHAT_MSG_ADDON event args
function _dnl.handleSyncAddonMessage(arg)
	local command, msg = string.split(_dnl.COMM_COMMAND_DELIM, arg[2])
	local sender_short, _ = string.split("-", arg[4])

	if _dnl.DEBUG then
		local label = SYNC_CMD_LABELS[command] or command
		local preview = msg and msg:sub(1, 80) or ""
		print(string.format("|cff00CCFF[Deathlog Sync]|r ADDON %s from %s: %s%s",
			label, sender_short, preview, (#(msg or "") > 80) and "…" or ""))
	end

	if _dnl.throttleCheck(sender_short) then return end

	if command == SYNC_CMD_BUCKET_REQ then
		_dnl.handleSyncBucketRequest(sender_short, msg)
	end
end

---Handle a sync message received via CHAT_MSG_CHANNEL on the sync channel.
---Commands: W (watermark), E (entry response).
---@param arg table  CHAT_MSG_CHANNEL event args
function _dnl.handleSyncChannelMessage(arg)
	local text, sender = arg[1], arg[2]
	local command, msg = string.split(_dnl.COMM_COMMAND_DELIM, text)
	local sender_short, _ = string.split("-", sender)

	-- Ignore our own channel messages echoed back
	if sender_short == UnitName("player") then return end

	if _dnl.DEBUG then
		local label = SYNC_CMD_LABELS[command] or command
		local preview = msg and msg:sub(1, 80) or ""
		print(string.format("|cff00CCFF[Deathlog Sync]|r CHANNEL %s from %s: %s%s",
			label, sender_short, preview, (#(msg or "") > 80) and "…" or ""))
	end

	if _dnl.throttleCheck(sender_short) then return end

	if command == SYNC_CMD_WATERMARK then
		_dnl.handleSyncWatermark(sender_short, msg)
	elseif command == SYNC_CMD_ENTRY_RES then
		_dnl.handleSyncEntry(sender_short, msg)
	end
end

_dnl.registerInputDrain(sendNextInQueue)

---------------------------------------------------------------------------
-- Expose internals for testing
---------------------------------------------------------------------------

if _dnl.DEBUG then
	_dnl.SYNC_STATE             = SYNC_STATE
	_dnl._syncState             = function() return state end
	_dnl._syncSetState          = function(s) state = s end
	_dnl._syncWatermarkPeers    = watermark_peers
	_dnl._syncStats             = stats
	_dnl._syncResetToIdle       = resetToIdle
	_dnl._broadcastWatermark    = broadcastWatermark
	_dnl._computeLocalWatermark = computeLocalWatermark
	_dnl._buildDayIndex         = buildDayIndex
	_dnl._checksumNumeric       = checksumNumeric
	_dnl._dayIndex              = dayIndex
	_dnl._syncCooldownPerAddon  = sync_cooldown_per_addon

	_dnl._drainSyncBacklogAll   = function()
		while #sync_entry_backlog > 0 do
			local item = table.remove(sync_entry_backlog, 1)
			_dnl._processSyncEntry(item[1], item[2])
		end
	end

	_dnl.SYNC_CMD_WATERMARK     = SYNC_CMD_WATERMARK
	_dnl.SYNC_CMD_BUCKET_REQ    = SYNC_CMD_BUCKET_REQ
	_dnl.SYNC_CMD_ENTRY_RES     = SYNC_CMD_ENTRY_RES
end

---------------------------------------------------------------------------
-- API
---------------------------------------------------------------------------

DeathNotificationLib.SyncStatus = _dnl.syncStatus
