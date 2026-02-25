--[[
DeathNotificationLib~Cache.lua

Central death-processing pipeline and LRU deduplication cache.

Every death report — whether from a peer broadcast, the Blizzard
HARDCORE_DEATHS channel, or self-detection — flows through this module.
Incoming reports are decoded, validated, and merged into an LRU cache
keyed by Fletcher-16 checksum, with quality-aware field resolution
(SELF > PEER > BLIZZARD).  A secondary name-based index prevents the
same player from being committed twice within a 60-second window, even
if checksums differ across sources.

Peer corroboration: when a matching checksum arrives from a different
sender, the peer count increments and secure hooks fire once the
threshold (≥ 2 peers) is met.

Auto-commit timers: reported deaths (source_id == -1) commit after 4 s;
regular deaths after 3.5 s.  On commit, registered consumer hooks are
fired via createEntry().  A periodic ticker (120 s) garbage-collects
stale LRU entries whose age exceeds getDedupWindow(level).

Hook registration:
  HookOnNewEntry(fn)               – fires for every committed death (global)
  HookOnNewEntrySecure(fn)         – fires only when peer_count ≥ 2 (global)
  HookOnNewAddonEntry(name, fn)    – fires for deaths destined for a specific addon
  HookOnNewAddonEntrySecure(name, fn) – secure variant of above
  HookQueuePlayer(fn)              – fires when a player needs level lookup
--]]

local _dnl = DeathNotificationLib.Internal ---@class _dnl
if not _dnl then return end
local SOURCE = _dnl.SOURCE

--- Commit delay for regular deaths (seconds).
local COMMIT_DELAY = 3.5

--- Commit delay for reported deaths with source_id == -1 (seconds).
local REPORTED_COMMIT_DELAY = 4.0

--- Commit delay after receiving a checksum corroboration (seconds).
local CHECKSUM_COMMIT_DELAY = 2.0

--- Garbage-collection interval for expired LRU entries (seconds).
local GC_INTERVAL = 120

---@alias HookOnNewEntryCallback fun(player_data: PlayerData, checksum: string|nil, peer_report: number, in_guild: number|nil, source: DNL_Source|nil)

---------------------------------------------------------------------------
-- Hook tables
---------------------------------------------------------------------------

--- Global hooks (fire for every non-addonless death, regardless of addon).
local hook_on_entry_functions = {}
local hook_on_entry_functions_secure = {}

--- Per-addon hooks keyed by addon name.
--- { [addonName] = { fn1, fn2, ... } }
local per_addon_hooks = {}
local per_addon_hooks_secure = {}

_dnl.per_addon_hooks = per_addon_hooks
_dnl.per_addon_hooks_secure = per_addon_hooks_secure

---@alias QueuePlayerHook fun(name: string, guid: string, race_id: number|nil, class_id: number|nil, guild: string|nil, map_id: number|nil, map_pos: string|nil, instance_id: number|nil): boolean
local hook_queue_player_functions = {}

_dnl.hook_queue_player_functions = hook_queue_player_functions

--- Safely call a hook function, catching and reporting errors so one
--- misbehaving hook cannot break the entire death pipeline.
local function safeCallHook(f, ...)
	local ok, err = pcall(f, ...)
	if not ok and _dnl.DEBUG then
		print("[DNL] Hook error: " .. tostring(err))
	end
end

--- Deep-copy a table (with recursion depth limit to guard against
--- unexpected circular references or deeply nested structures).
---@param t table
---@param _depth number|nil  Internal recursion counter (do not pass externally)
---@return table
function _dnl.deepCopy(t, _depth)
	_depth = _depth or 0
	if _depth > 10 then return {} end
	local out = {}
	for k, v in pairs(t) do
		local vtype = type(v)
		if vtype == "nil" or vtype == "number" or vtype == "string" or vtype == "boolean" then
			out[k] = v
		elseif vtype == "table" then
			out[k] = _dnl.deepCopy(v, _depth + 1)
		end
	end
	return out
end

---createEntry: routes committed deaths to the correct hooks.
---
---For normal (non-targeted) deaths: fires global hooks (HookOnNewEntry /
---HookOnNewEntrySecure) AND per-addon hooks registered via
---HookOnNewAddonEntry / HookOnNewAddonEntrySecure.
---
---For addonless deaths (source == BLIZZARD, no class_id, no race_id):
---global hooks are SKIPPED entirely.  Only per-addon hooks whose addon
---has addonless_logging enabled in its settings will fire.
---
---Hooks receive a **defensive copy** so they cannot corrupt the internal
---LRU cache.
---@param _player_data PlayerData
---@param checksum string|nil
---@param peer_count number|nil
---@param in_guild number|nil
---@param source DNL_Source|nil  Entry origin constant from _dnl.SOURCE / DeathNotificationLib.SOURCE
---@param target_addon_name string|nil  When set, ONLY this addon's per-addon hooks fire (no global hooks, no other addons). Used for sync/query where data belongs to a specific addon.
function _dnl.createEntry(_player_data, checksum, peer_count, in_guild, source, target_addon_name)
	peer_count = peer_count or 0
	source = source or SOURCE.UNKNOWN

	-- Addonless = Blizzard-sourced death with no class/race enrichment from WHO.
	-- Only addons that explicitly opt in via addonless_logging should receive these.
	local is_addonless = (source == SOURCE.BLIZZARD and not _player_data["class_id"] and not _player_data["race_id"])

	-- Resolve which addon owns the death alert so we can reuse its copy
	local _, alert_owner_name = _dnl.getDeathAlertOwnerSettings()
	local alert_copy = nil

	-- Per-addon copy preparation:
	-- Strip playtime if the addon explicitly opted out (share_playtime = false).
	local function prepareAddonCopy(addon_copy, addon)
		if addon.settings and addon.settings.share_playtime == false then
			addon_copy["played"] = nil
		end
	end

	-- Fire all per-addon hooks (both normal and secure) for a given addon.
	local function fireAddonHooks(addon_name, addon, copy, is_secure_only)
		if not is_secure_only then
			local hooks = per_addon_hooks[addon_name]
			if hooks then
				for _, f in ipairs(hooks) do
					safeCallHook(f, copy, checksum, peer_count, in_guild, source)
				end
			end
		end
		if peer_count >= 2 then
			local secure_hooks = per_addon_hooks_secure[addon_name]
			if secure_hooks then
				for _, f in ipairs(secure_hooks) do
					safeCallHook(f, copy, checksum, peer_count, in_guild, source)
				end
			end
		end
	end

	-- Targeted mode: only fire hooks for one specific addon
	if target_addon_name then
		local addon = _dnl.addons[target_addon_name]
		if addon then
			local addon_copy = _dnl.deepCopy(_player_data)
			prepareAddonCopy(addon_copy, addon)
			fireAddonHooks(target_addon_name, addon, addon_copy, false)
		end
		return
	end

	if is_addonless then
		-- Per-addon hooks ONLY — filtered by addonless_logging setting
		for addon_name, addon in pairs(_dnl.addons) do
			if addon.settings and addon.settings.addonless_logging then
				local addon_copy = _dnl.deepCopy(_player_data)
				prepareAddonCopy(addon_copy, addon)
				if addon_name == alert_owner_name then alert_copy = addon_copy end
				fireAddonHooks(addon_name, addon, addon_copy, false)
			end
		end
	else
		-- Normal path: global hooks get a shared copy,
		-- then each per-addon hook gets its own copy prepared according to that addon's settings.
		local shared_copy = _dnl.deepCopy(_player_data)

		for _, f in ipairs(hook_on_entry_functions) do
			safeCallHook(f, shared_copy, checksum, peer_count, in_guild, source)
		end

		for addon_name, addon in pairs(_dnl.addons) do
			local addon_copy = _dnl.deepCopy(_player_data)
			prepareAddonCopy(addon_copy, addon)
			if addon_name == alert_owner_name then alert_copy = addon_copy end
			fireAddonHooks(addon_name, addon, addon_copy, false)
		end

		if peer_count >= 2 then
			for _, f in ipairs(hook_on_entry_functions_secure) do
				safeCallHook(f, shared_copy, checksum, peer_count, in_guild, source)
			end
		end
	end

	if alert_copy and (source == SOURCE.SELF_DEATH or source == SOURCE.PEER_BROADCAST or source == SOURCE.BLIZZARD) then
		_dnl.playDeathAlert(alert_copy)
	end
end

---@class LRUCacheEntry
---@field player_data PlayerData|nil
---@field peer_report number|nil Count of unique peers who confirmed via checksum
---@field peers table<string, number>|nil Per-sender dedup of corroboration
---@field in_guild number|nil 1 if dead player matched guild roster
---@field self_report number|nil 1 if sender == dead player
---@field committed number|nil 1 once createEntry has been called
---@field quality number|nil QUALITY tier (BLIZZARD/PEER/SELF)
---@field auto_commit boolean|nil true for deaths that don't need peer corroboration
---@field timestamp number|nil GetServerTime() when entry was created
---@field source string|nil Entry origin label

---@class LRUByNameEntry
---@field checksum string|nil
---@field timestamp number|nil
---@field committed boolean|nil

---@type table<string, LRUCacheEntry>
local death_ping_lru_cache_tbl = {}

---@type table<string, LRUByNameEntry>
local lru_by_name = {}

--- Returns the dedup window in seconds based on character level.
--- Higher-level Hardcore characters take exponentially longer to re-level,
--- so we can safely use wider windows to catch duplicate death reports.
---   Level  1-9:   120s (2 min)  — quick to recreate
---   Level 10-19:  300s (5 min)  — moderate investment
---   Level 20-39:  600s (10 min) — significant /played
---   Level 40-59: 1800s (30 min) — days of /played
---   Level 60+:   3600s (1 hour) — endgame
---@param level number|nil
---@return number seconds
local function getDedupWindow(level)
	level = tonumber(level) or 0
	if level >= 60 then return 3600 end
	if level >= 40 then return 1800 end
	if level >= 20 then return 600 end
	if level >= 10 then return 300 end
	return 120
end

_dnl.death_ping_lru_cache_tbl = death_ping_lru_cache_tbl
_dnl.lru_by_name = lru_by_name
_dnl.getDedupWindow = getDedupWindow

---Update the lru_by_name index for a player
---@param name_lower string
---@param checksum string|nil
---@param committed boolean|nil If nil, committed field is not touched
---@param level number|nil Character level (stored for level-scaled dedup window)
local function updateLRUByName(name_lower, checksum, committed, level)
	if not lru_by_name[name_lower] then
		lru_by_name[name_lower] = {}
	end
	if checksum then
		lru_by_name[name_lower].checksum = checksum
	end
	lru_by_name[name_lower].timestamp = GetServerTime()
	if committed ~= nil then
		lru_by_name[name_lower].committed = committed
	end
	if level then
		lru_by_name[name_lower].level = level
	end
end
_dnl.updateLRUByName = updateLRUByName

C_Timer.NewTicker(GC_INTERVAL, function()
	local now = GetServerTime()
	local stale_checksums = {}
	for checksum, entry in pairs(death_ping_lru_cache_tbl) do
		if entry["committed"] then
			local lvl = entry["player_data"] and entry["player_data"]["level"]
			if (now - (entry["timestamp"] or 0)) > getDedupWindow(lvl) then
				table.insert(stale_checksums, checksum)
			end
		end
	end
	for _, checksum in ipairs(stale_checksums) do
		death_ping_lru_cache_tbl[checksum] = nil
	end
	local stale_names = {}
	for name_lower, entry in pairs(lru_by_name) do
		if entry.committed and (now - (entry.timestamp or 0)) > getDedupWindow(entry.level) then
			table.insert(stale_names, name_lower)
		end
	end
	for _, name_lower in ipairs(stale_names) do
		lru_by_name[name_lower] = nil
	end
end)

---Check if a player name has already been committed within the dedup window
---@param name string|nil
---@param level number|nil Incoming entry's level (for level-scaled window)
---@return boolean
function _dnl.isNameAlreadyCommitted(name, level)
	if not name then return false end
	local name_lower = name:lower()
	local existing = lru_by_name[name_lower]
	if not existing then return false end
	if not existing.committed then return false end
	local effective_level = math.max(tonumber(level) or 0, tonumber(existing.level) or 0)
	local time_diff = math.abs(GetServerTime() - (existing.timestamp or 0))
	return time_diff <= getDedupWindow(effective_level)
end

---Try to commit a death from the LRU cache
---@param checksum string
local function tryCommitEntry(checksum)
	if death_ping_lru_cache_tbl[checksum] == nil then
		return
	end
	if death_ping_lru_cache_tbl[checksum]["player_data"] == nil then
		return
	end
	if _dnl.isValidEntry(death_ping_lru_cache_tbl[checksum]["player_data"]) == false then
		return
	end
	if death_ping_lru_cache_tbl[checksum]["committed"] then
		return
	end

	local pdata = death_ping_lru_cache_tbl[checksum]["player_data"]
	local pdata_name = pdata["name"]
	if pdata_name and _dnl.isNameAlreadyCommitted(pdata_name, pdata["level"]) then
		death_ping_lru_cache_tbl[checksum]["committed"] = 1
		return
	end

	local cache = death_ping_lru_cache_tbl[checksum]
	cache["player_data"]["date"] = cache["player_data"]["date"] or GetServerTime()
	cache["committed"] = 1

	if pdata_name then
		updateLRUByName(pdata_name:lower(), checksum, true, pdata["level"])
	end

	_dnl.createEntry(
		pdata,
		checksum,
		(cache["peer_report"] or 0),
		cache["in_guild"],
		cache["source"]
	)
end

---Merge incoming player_data into an existing LRU cache entry
---Higher quality data wins for each field
---@param existing_data PlayerData
---@param incoming_data PlayerData
---@param incoming_quality number QUALITY tier
---@param existing_quality number QUALITY tier
local function mergeLRUEntry(existing_data, incoming_data, incoming_quality, existing_quality)
	if incoming_quality > existing_quality then
		for k, v in pairs(incoming_data) do
			if v ~= nil and v ~= "" then
				existing_data[k] = v
			end
		end
		return
	end

	if incoming_data["played"] and incoming_data["played"] > 0 and (not existing_data["played"] or existing_data["played"] == 0) then
		existing_data["played"] = incoming_data["played"]
	end
	if incoming_data["last_words"] and (not existing_data["last_words"] or existing_data["last_words"] == "") then
		existing_data["last_words"] = incoming_data["last_words"]
	end
	if incoming_data["date"] and not existing_data["date"] then
		existing_data["date"] = incoming_data["date"]
	end
	if incoming_data["extra_data"] and not existing_data["extra_data"] then
		existing_data["extra_data"] = incoming_data["extra_data"]
	end
	if incoming_data["race_id"] and not existing_data["race_id"] then
		existing_data["race_id"] = incoming_data["race_id"]
	end
	if incoming_data["class_id"] and not existing_data["class_id"] then
		existing_data["class_id"] = incoming_data["class_id"]
	end
	if incoming_data["guild"] and incoming_data["guild"] ~= "" and (not existing_data["guild"] or existing_data["guild"] == "") then
		existing_data["guild"] = incoming_data["guild"]
	end
	if incoming_data["map_pos"] and (not existing_data["map_pos"] or existing_data["map_pos"] == "") then
		existing_data["map_pos"] = incoming_data["map_pos"]
	end
	if incoming_data["source_id"] and incoming_data["source_id"] ~= -1 and (not existing_data["source_id"] or existing_data["source_id"] == -1) then
		existing_data["source_id"] = incoming_data["source_id"]
	end
	if incoming_data["level"] and incoming_data["level"] > 0 and (not existing_data["level"] or existing_data["level"] == 0) then
		existing_data["level"] = incoming_data["level"]
	end
end
_dnl.mergeLRUEntry = mergeLRUEntry

---Unified death broadcast receiver
---Handles all death types through a single pipeline:
---1. Decode & validate
---2. Determine quality (SELF/PEER)
---3. Cross-source dedup via lru_by_name
---4. Store in LRU cache with quality-aware merging
---5. For reported deaths (source_id == -1): auto-commit after 4s (blizzard emote is proof)
---6. For regular deaths: wait for peer corroboration, commit after 3.5s
---@param sender string
---@param data string|nil
function _dnl.handleDeathBroadcast(sender, data)
	if data == nil then
		return
	end

	local decoded_player_data, protocol_version = _dnl.decodeMessage(data)
	if not decoded_player_data then
		return
	end

	if protocol_version and (protocol_version < _dnl.MIN_SUPPORTED_PROTOCOL_VERSION or protocol_version > _dnl.PROTOCOL_VERSION) then
		return
	end

	local is_self_report = (sender == decoded_player_data["name"])
	local quality = is_self_report and _dnl.QUALITY.SELF or _dnl.QUALITY.PEER
	local entry_source = is_self_report and SOURCE.SELF_DEATH or SOURCE.PEER_BROADCAST

	if not is_self_report and not _dnl.anyAddonAllows("peer_reporting") then
		if _dnl.DEBUG then
			print("Peer-reported death ignored (all addons disabled peer_reporting):", decoded_player_data["name"], "reported by:", sender)
		end
		return
	end

	if _dnl.isValidEntry(decoded_player_data) == false then
		return
	end

	local dead_player_name = decoded_player_data["name"]

	local is_reported_death = (decoded_player_data["source_id"] and tonumber(decoded_player_data["source_id"]) == -1)
	local auto_commit = is_reported_death

	if is_reported_death then
		decoded_player_data["level"] = decoded_player_data["level"] or 0
	end

	local checksum = _dnl.fletcher16(decoded_player_data)
	local name_lower = dead_player_name:lower()

	local name_entry = lru_by_name[name_lower]
	if name_entry then
		local effective_level = math.max(tonumber(decoded_player_data["level"]) or 0, tonumber(name_entry.level) or 0)
		local time_diff = math.abs(GetServerTime() - (name_entry.timestamp or 0))
		if time_diff <= getDedupWindow(effective_level) then
			local existing_checksum = name_entry.checksum
			if existing_checksum and existing_checksum ~= checksum then
				local existing_cache = death_ping_lru_cache_tbl[existing_checksum]
				if existing_cache and existing_cache["player_data"] then
					local existing_quality = existing_cache["quality"] or _dnl.QUALITY.PEER

					if quality > existing_quality then
						if existing_cache["committed"] then
							-- The lower-quality entry already committed (timer race:
							-- arrival spread exceeded commit delay). Upgrade the
							-- committed data in-place and re-fire addon hooks so
							-- the DB entry is overwritten with the better data.
							mergeLRUEntry(existing_cache["player_data"], decoded_player_data, quality, existing_quality)
							existing_cache["quality"] = quality

							if _dnl.DEBUG then
								print("Late quality upgrade for", dead_player_name,
									": re-firing hooks with SELF data (existing already committed)")
							end

							_dnl.createEntry(
								existing_cache["player_data"],
								existing_checksum,
								(existing_cache["peer_report"] or 0),
								existing_cache["in_guild"],
								SOURCE.UPGRADE
							)
							return
						end

						-- Not yet committed — supersede normally
						mergeLRUEntry(decoded_player_data, existing_cache["player_data"], existing_quality, quality)
						existing_cache["committed"] = 1

						if _dnl.DEBUG then
							print("Quality upgrade for", dead_player_name, ": replacing", existing_checksum, "with", checksum)
						end
					else
						-- Existing is equal or better quality — merge incoming data into
						-- existing and skip, regardless of committed state. This prevents
						-- creating a parallel LRU entry (and thus a duplicate commit) when
						-- multiple party members broadcast the same death with different
						-- checksums (different guild/source/map_pos).
						mergeLRUEntry(existing_cache["player_data"], decoded_player_data, quality, existing_quality)
						return
					end
				end
			end
		end
	end

	if death_ping_lru_cache_tbl[checksum] == nil then
		death_ping_lru_cache_tbl[checksum] = {}
	end

	local cache_entry = death_ping_lru_cache_tbl[checksum]

	if cache_entry["player_data"] == nil then
		cache_entry["player_data"] = decoded_player_data
		cache_entry["quality"] = quality
		cache_entry["auto_commit"] = auto_commit
		cache_entry["timestamp"] = GetServerTime()
		cache_entry["source"] = entry_source
	else
		local existing_quality = cache_entry["quality"] or _dnl.QUALITY.PEER
		mergeLRUEntry(cache_entry["player_data"], decoded_player_data, quality, existing_quality)
		if quality > existing_quality then
			cache_entry["quality"] = quality
		end
	end

	updateLRUByName(name_lower, checksum, cache_entry["committed"] and true or false, decoded_player_data["level"])

	if cache_entry["committed"] then
		return
	end

	if not auto_commit then
		local guildName = GetGuildInfo("player")
		if decoded_player_data["guild"] and decoded_player_data["guild"] == guildName then
			local name_long = dead_player_name .. "-" .. GetNormalizedRealmName()
			for i = 1, GetNumGuildMembers() do
				local name, _, _, level, _, _, _, _, _, _, _ = GetGuildRosterInfo(i)
				if name_long == name and level == decoded_player_data["level"] then
					cache_entry["in_guild"] = 1
					local delay = math.random(0, 10)
					C_Timer.After(delay, function()
						if death_ping_lru_cache_tbl[checksum] and death_ping_lru_cache_tbl[checksum]["committed"] then
							return
						end
						table.insert(_dnl.broadcast_death_ping_queue, {checksum .. _dnl.COMM_FIELD_DELIM .. _dnl.PROTOCOL_VERSION .. _dnl.COMM_FIELD_DELIM, GetServerTime()})
					end)
					break
				end
			end
		end
	end

	if is_self_report then
		cache_entry["self_report"] = 1
	end

	if auto_commit then
		C_Timer.After(REPORTED_COMMIT_DELAY, function()
			tryCommitEntry(checksum)
		end)
	else
		C_Timer.After(COMMIT_DELAY, function()
			tryCommitEntry(checksum)
		end)
	end
end

---@param sender string
---@param data string|nil
function _dnl.deathlogReceiveChannelMessageChecksum(sender, data)
	if data == nil then
		return
	end
	local values = {}
	for w in data:gmatch("(.-)~") do
		table.insert(values, w)
	end
	local checksum = values[1]

	if checksum == nil then
		return
	end

	if death_ping_lru_cache_tbl[checksum] == nil then
		death_ping_lru_cache_tbl[checksum] = {}
	end
	if death_ping_lru_cache_tbl[checksum]["committed"] then
		return
	end

	if death_ping_lru_cache_tbl[checksum]["peers"] == nil then
		death_ping_lru_cache_tbl[checksum]["peers"] = {}
	end

	if death_ping_lru_cache_tbl[checksum]["peers"][sender] then
		return
	end
	death_ping_lru_cache_tbl[checksum]["peers"][sender] = 1

	if death_ping_lru_cache_tbl[checksum]["peer_report"] == nil then
		death_ping_lru_cache_tbl[checksum]["peer_report"] = 0
	end

	death_ping_lru_cache_tbl[checksum]["peer_report"] = death_ping_lru_cache_tbl[checksum]["peer_report"] + 1

	C_Timer.After(CHECKSUM_COMMIT_DELAY, function()
		tryCommitEntry(checksum)
	end)
end

---Blizzard HARDCORE_DEATHS: lowest quality source, routed through the unified LRU cache
---@param msg string
function _dnl.onBlizzardChat(msg)
	local death_name, source, area_name, parsed_lvl, pvp_source_name = _dnl.parse_hc_death_broadcast(msg)
	if not death_name or not source then
		return
	end

	-- SLIME has no level (Blizzard truncated it), DUEL/NONE have no area
	parsed_lvl = parsed_lvl or 0

	local extra_data = nil
	if pvp_source_name then
		extra_data = { ["pvp_source_name"] = pvp_source_name }
	end

	local invoked = false
	local curr_time = GetServerTime()

	local guild = nil
	local class_id = nil
	local race_id = nil

	local function commit()
		if invoked then return end
		invoked = true

		if not _dnl.anyAddonEnables("addonless_logging") and not class_id and not race_id then
			return
		end

		if _dnl.isNameAlreadyCommitted(death_name, parsed_lvl) then
			-- Even though an entry was already committed (e.g. from a peer broadcast
			-- with source_id=-1), the Blizzard HARDCORE_DEATHS message may carry
			-- the correct NPC source_id.  Upgrade the committed entry and re-fire
			-- hooks so addon databases receive the better data.
			if source and source ~= -1 then
				local name_lower = death_name:lower()
				local name_entry = lru_by_name[name_lower]
				if name_entry and name_entry.checksum then
					local existing_cache = death_ping_lru_cache_tbl[name_entry.checksum]
					if existing_cache and existing_cache["player_data"]
						and (not existing_cache["player_data"]["source_id"] or existing_cache["player_data"]["source_id"] == -1) then
						existing_cache["player_data"]["source_id"] = source
						-- Re-fire hooks so addon databases merge the upgraded source_id
						_dnl.createEntry(
							existing_cache["player_data"],
							name_entry.checksum,
							existing_cache["peer_report"] or 0,
							existing_cache["in_guild"],
							existing_cache["source"]
						)
						if _dnl.DEBUG then
							print("Blizzard source upgrade for", death_name, ": source_id", -1, "→", source)
						end
					end
				end
			end
			if _dnl.DEBUG then
				print("Blizzard death skipped - addon already committed:", death_name)
			end
			return
		end

		local area_id = _dnl.D.AREA_TO_ID[area_name]
		local instance_id = area_id and (_dnl.D.ID_TO_INSTANCE[area_id] and area_id or _dnl.D.ZONE_TO_INSTANCE[area_id])
		local map_id = not instance_id and (area_id or _dnl.ROOT_MAP_ID) or nil

		local _player_data = _dnl.playerData(death_name, guild, source, race_id, class_id, parsed_lvl, instance_id, map_id, nil, curr_time, nil, nil, extra_data)

		local checksum = _dnl.fletcher16(_player_data)

		if death_ping_lru_cache_tbl[checksum] and death_ping_lru_cache_tbl[checksum]["committed"] then
			return
		end

		if not death_ping_lru_cache_tbl[checksum] then
			death_ping_lru_cache_tbl[checksum] = {}
		end

		local cache_entry = death_ping_lru_cache_tbl[checksum]
		if cache_entry["player_data"] then
			mergeLRUEntry(cache_entry["player_data"], _player_data, _dnl.QUALITY.BLIZZARD, cache_entry["quality"] or _dnl.QUALITY.PEER)
		else
			cache_entry["player_data"] = _player_data
			cache_entry["quality"] = _dnl.QUALITY.BLIZZARD
			cache_entry["auto_commit"] = true
			cache_entry["timestamp"] = GetServerTime()
			cache_entry["source"] = SOURCE.BLIZZARD
		end

		updateLRUByName(death_name:lower(), checksum, nil, _player_data["level"])

		tryCommitEntry(checksum)
	end

	local cancelWho = _dnl.enqueueWhoPlayer(death_name, function(who_info)
		if who_info then
			guild = who_info.fullGuildName and _dnl.normalize(who_info.fullGuildName) or nil
			class_id = who_info.filename and _dnl.D.CLASS_FILE_TO_ID[who_info.filename] or nil
			race_id = who_info.raceStr and _dnl.D.RACE_NAME_TO_ID[who_info.raceStr] or nil

			local elapsed = GetServerTime() - curr_time
			if elapsed < 5 then
				C_Timer.After(5 - elapsed, commit)
			else
				commit()
			end
		end
	end)

	C_Timer.After(10.0, function()
		cancelWho()
		commit()
	end)
end

---Look up a recently committed death record by character name.
---Returns a deep copy of the PlayerData and peer count, or nil if not found / expired.
---Note: the cache has a 600s TTL — for long-term storage, use HookOnNewEntry or HookOnNewAddonEntry.
---@param name string  Character name (case-insensitive)
---@return PlayerData|nil player_data
---@return number|nil peer_count
local function getDeathRecord(name)
	if type(name) ~= "string" or name == "" then return nil, nil end
	local entry = lru_by_name[name:lower()]
	if not entry or not entry.committed or not entry.checksum then return nil, nil end
	local cache_entry = death_ping_lru_cache_tbl[entry.checksum]
	if not cache_entry or not cache_entry.player_data then return nil, nil end
	return _dnl.deepCopy(cache_entry.player_data), cache_entry.peer_report or 0
end

--#region API

--- Register a global callback for new death entries.
--- Fires for every committed non-addonless death, regardless of which addon
--- produced it.  For per-addon filtering, use HookOnNewAddonEntry instead.
--- source is a DNL_Source constant from DeathNotificationLib.SOURCE.
---@param fun HookOnNewEntryCallback
DeathNotificationLib.HookOnNewEntry = function(fun) hook_on_entry_functions[#hook_on_entry_functions + 1] = fun end

--- Register a global callback for secure death entries (peer_count >= 2).
---@param fun HookOnNewEntryCallback
DeathNotificationLib.HookOnNewEntrySecure = function(fun) hook_on_entry_functions_secure[#hook_on_entry_functions_secure + 1] = fun end

--- Register a per-addon callback for new death entries.
--- Fires for every committed death destined for this addon, including
--- addonless deaths when the addon has addonless_logging enabled, and
--- targeted sync/query entries.  The addon must already be registered
--- via AttachAddon; returns false if the addon name is unknown.
---@param addon_name string  Addon name passed to AttachAddon (e.g. "Deathlog")
---@param fun HookOnNewEntryCallback
---@return boolean registered  true if the hook was added
DeathNotificationLib.HookOnNewAddonEntry = function(addon_name, fun)
	if not _dnl.addons[addon_name] then
		if _dnl.DEBUG then print("[DNL] HookOnNewAddonEntry: unknown addon '" .. tostring(addon_name) .. "'") end
		return false
	end
	if not per_addon_hooks[addon_name] then per_addon_hooks[addon_name] = {} end
	per_addon_hooks[addon_name][#per_addon_hooks[addon_name] + 1] = fun
	return true
end

--- Register a per-addon callback for secure death entries (peer_count >= 2).
---@param addon_name string  Addon name passed to AttachAddon (e.g. "Deathlog")
---@param fun HookOnNewEntryCallback
---@return boolean registered  true if the hook was added
DeathNotificationLib.HookOnNewAddonEntrySecure = function(addon_name, fun)
	if not _dnl.addons[addon_name] then
		if _dnl.DEBUG then print("[DNL] HookOnNewAddonEntrySecure: unknown addon '" .. tostring(addon_name) .. "'") end
		return false
	end
	if not per_addon_hooks_secure[addon_name] then per_addon_hooks_secure[addon_name] = {} end
	per_addon_hooks_secure[addon_name][#per_addon_hooks_secure[addon_name] + 1] = fun
	return true
end

---Register a callback for player data enrichment.
---Fires when a new death is detected and the player's name is known, but before createEntry is called.
---Each hook receives a shallow copy of the player_data; if the hook returns true, the copy is merged back into the cache entry and will be used for createEntry.  
---This allows external modules to enrich or modify player data before it is committed.
---@param fun QueuePlayerHook
DeathNotificationLib.HookQueuePlayer = function(fun) hook_queue_player_functions[#hook_queue_player_functions + 1] = fun end

DeathNotificationLib.GetDeathRecord = getDeathRecord

DeathNotificationLib.GetDedupWindow = getDedupWindow

--#endregion
