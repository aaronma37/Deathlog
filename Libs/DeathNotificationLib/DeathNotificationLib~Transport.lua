--[[
DeathNotificationLib~Transport.lua

Low-level message transport and channel management.

Manages joining and maintaining the shared chat channel used for death
alerts ("hcdeathalertschannel"), with automatic retry and a backup
channel name on failure.  Drains three prioritized outbound queues:
  1. Duel-to-death requests  (highest priority)
  2. Checksum corroborations
  3. Full death pings        (lowest priority)

Messages are sent only on user input (mouse click or key press) to
comply with WoW's addon-message restrictions — sendNextInQueue() is
hooked to WorldFrame:OnMouseDown and a hidden frame's OnKeyDown.

Spam protection: a per-sender throttle counter auto-shadowbans any
peer that exceeds 1000 messages.  Uses ChatThrottleLib when available,
falling back to raw SendChatMessage otherwise.
--]]

local _dnl = DeathNotificationLib.Internal ---@class _dnl
if not _dnl then return end

_dnl.DEATH_ALERTS_CHANNEL_BASE = "hcdeathalertschannel"

_dnl.death_alerts_channel = _dnl.DEATH_ALERTS_CHANNEL_BASE
local DEATH_ALERTS_CHANNEL_PW = _dnl.DEATH_ALERTS_CHANNEL_BASE .. "pw"

_dnl.broadcast_death_ping_queue = {}
_dnl.death_alert_out_queue = {}
_dnl.deathlog_request_duel_to_death_queue = {}

--- Max age (seconds) before a queued message is discarded.
--- Queues are FIFO so oldest entry is always at index 1.
local QUEUE_MAX_AGE = 58

---@type table<string, number>
local throttle_player = {}
---@type table<string, number>
local shadowbanned = {}

--- Max messages before a sender is permanently shadowbanned.
local SHADOWBAN_THRESHOLD = 1000

--- How often (seconds) to reset per-sender throttle counters.
--- Shadowbanned senders are NOT cleared.
local THROTTLE_RESET_INTERVAL = 600

---Throttle check helper: returns true if the sender should be blocked.
---Increments throttle counter and auto-shadowbans at >SHADOWBAN_THRESHOLD.
---@param sender string
---@return boolean blocked
function _dnl.throttleCheck(sender)
	if shadowbanned[sender] then
		return true
	end

	if throttle_player[sender] == nil then
		throttle_player[sender] = 0
	end
	throttle_player[sender] = throttle_player[sender] + 1
	if throttle_player[sender] > SHADOWBAN_THRESHOLD then
		shadowbanned[sender] = 1
	end

	return false
end


function _dnl.deathlogJoinChannel()
	LeaveChannelByName(_dnl.death_alerts_channel)

	C_Timer.After(3.0, function()
		JoinChannelByName(_dnl.death_alerts_channel, DEATH_ALERTS_CHANNEL_PW)
	end)

	_dnl.hideChannelFromChatFrames(_dnl.death_alerts_channel)

	local remaining_attempts = 5
	C_Timer.NewTicker(4, function(self)
		if remaining_attempts < 1 then
			self:Cancel()
			return
		end
		local channel_num = GetChannelName(_dnl.death_alerts_channel)
		if channel_num ~= 0 then
			self:Cancel()
			return
		end
		remaining_attempts = remaining_attempts - 1
		_dnl.death_alerts_channel = _dnl.death_alerts_channel .. "b"
		if _dnl.DEBUG then
			print("Couldn't join main deathlog channel; joining backup")
		end
		JoinChannelByName(_dnl.death_alerts_channel, DEATH_ALERTS_CHANNEL_PW)
	end)
end

local function sendChatMessageDebug(prefix, text)
	print(string.format("|cffFF6600[DNL DEBUG]|r Would send message with prefix %s: %s", prefix, text))

	local _, msg, _ = string.split(_dnl.COMM_COMMAND_DELIM, text)

	local decoded = _dnl.decodeMessage(msg)
	if decoded and decoded.name then
		decoded.date = decoded.date or time()
		print(string.format("|cffFF6600[DNL DEBUG]|r Processing death locally for: %s", decoded.name))
		_dnl.createEntry(decoded, nil, 0, nil, _dnl.SOURCE.DEBUG)
	end
end

local function sendNextInQueue()
	---Send a single CHANNEL message via shared CTL-aware helper.
	---@param text string   Full chat message
	---@param channel_num number  Channel index
	---@return boolean sent  true if message was sent (or debug-printed)
	local function doSend(text, channel_num)
		if _dnl.LOCAL_DEBUG_ONLY then
			sendChatMessageDebug(_dnl.COMM_NAME, text)
			return true
		end
		return _dnl.safeSendChannel(text, channel_num)
	end

	if #_dnl.deathlog_request_duel_to_death_queue > 0 then
		local channel_num = GetChannelName(_dnl.death_alerts_channel)
		if channel_num == 0 then
			_dnl.deathlogJoinChannel()
			return
		end
		local entry = _dnl.deathlog_request_duel_to_death_queue[1]
		local commMessage = _dnl.COMM_COMMANDS["REQUEST_DUEL_TO_DEATH"] .. _dnl.COMM_COMMAND_DELIM .. entry[1]
		if doSend(commMessage, channel_num) then
			table.remove(_dnl.deathlog_request_duel_to_death_queue, 1)
		end
		return
	end

	if #_dnl.broadcast_death_ping_queue > 0 then
		local channel_num = GetChannelName(_dnl.death_alerts_channel)
		if channel_num == 0 then
			_dnl.deathlogJoinChannel()
			return
		end
		local entry = _dnl.broadcast_death_ping_queue[1]
		local commMessage = _dnl.COMM_COMMANDS["BROADCAST_DEATH_PING_CHECKSUM"] .. _dnl.COMM_COMMAND_DELIM .. entry[1]
		if doSend(commMessage, channel_num) then
			table.remove(_dnl.broadcast_death_ping_queue, 1)
		end
		return
	end

	if #_dnl.death_alert_out_queue > 0 then
		local channel_num = GetChannelName(_dnl.death_alerts_channel)
		if channel_num == 0 then
			_dnl.deathlogJoinChannel()
			return
		end
		local entry = _dnl.death_alert_out_queue[1]
		local commMessage = _dnl.COMM_COMMANDS["BROADCAST_DEATH_PING"] .. _dnl.COMM_COMMAND_DELIM .. entry[1]
		if doSend(commMessage, channel_num) then
			table.remove(_dnl.death_alert_out_queue, 1)
		end
		return
	end
end

-- Register Transport's own queue drain
_dnl.registerInputDrain(sendNextInQueue)

---------------------------------------------------------------------------
-- Stale queue cleanup
-- Runs every second.  Pops entries from the front of each queue whose
-- enqueue timestamp is older than QUEUE_MAX_AGE.  Queues are FIFO so
-- once we hit a fresh entry we can stop — everything behind it is newer.
---------------------------------------------------------------------------

---Trim stale entries from the front of a timestamped queue.
---@param queue table  Array of {text, enqueue_time}
local function trimStaleEntries(queue)
	local now = time()
	while #queue > 0 and (now - queue[1][2]) >= QUEUE_MAX_AGE do
		table.remove(queue, 1)
	end
end

C_Timer.NewTicker(1, function()
	trimStaleEntries(_dnl.broadcast_death_ping_queue)
	trimStaleEntries(_dnl.death_alert_out_queue)
	trimStaleEntries(_dnl.deathlog_request_duel_to_death_queue)
	-- sync_out_queue is NOT trimmed here — sync has its own 60s
	-- response timeout in the protocol state machine, and manifest
	-- responses can legitimately queue 100+ messages that take time
	-- to drain through the hardware-event bottleneck.
end)

--- Periodically reset per-sender throttle counters to prevent the
--- throttle_player table from growing unbounded over long sessions.
--- Shadowbanned senders are intentionally NOT cleared.
C_Timer.NewTicker(THROTTLE_RESET_INTERVAL, function()
	wipe(throttle_player)
end)
