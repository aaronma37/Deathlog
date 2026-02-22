--[[
DeathNotificationLib~Query.lua

Outbound death-data queries and /who lookups.

Provides a throttled query mechanism for requesting death records from
other players via guild, whisper, yell, or say channels.  Each query
sends a "Q$name" addon message and expects a "R$" acknowledgment
(handled by Events); a 3-second lockout prevents query spam.

Also provides a single-flight /who system.  whoPlayer(name, callback)
sends a C_FriendList.SendWho query with a timeout.  SetWhoToUi(true)
routes results into the API data store (suppressing chat output);
FriendsFrame's WHO_LIST_UPDATE is temporarily unregistered to prevent
the Who panel from opening.  Our own WHO_LIST_UPDATE handler reads the
results via GetWhoInfo() and fires the callback.

enqueueWhoPlayer() adds requests to a queue that drains one at a time
on user input (mouse click or key press), ensuring compliance with
WoW's hardware-event requirement.
--]]

local _dnl = DeathNotificationLib.Internal ---@class _dnl
if not _dnl then return end

local CTL = _G.ChatThrottleLib

---@type table<string, number>
_dnl.expect_ack = {}

local comm_query_lock_out = nil

---@param name string
---@param channelType string "GUILD"|"WHISPER"|"YELL"|"SAY"
---@param target string|nil Required when channelType == "WHISPER"
---@param tag string|nil  3-char addon tag (required for query routing)
local function sendQuery(name, channelType, target, tag)
	if not tag or not _dnl.tag_to_addon[tag] then
		if _dnl.DEBUG then
			print("[DNL] sendQuery: valid tag is required")
		end
		return
	end
	local commMessage = _dnl.COMM_QUERY .. _dnl.COMM_COMMAND_DELIM .. tag .. _dnl.COMM_FIELD_DELIM .. name
    if comm_query_lock_out then
        return
    end
    comm_query_lock_out = C_Timer.NewTimer(3, function()
        comm_query_lock_out = nil
    end)
    _dnl.expect_ack[name] = 1
    if channelType == "WHISPER" then
        if CTL then
            CTL:SendAddonMessage("BULK", _dnl.COMM_NAME, commMessage, channelType, target)
        else
            _G.SendAddonMessage(_dnl.COMM_NAME, commMessage, channelType, target)
        end
    else
        if CTL then
            CTL:SendAddonMessage("BULK", _dnl.COMM_NAME, commMessage, channelType)
        else
            _G.SendAddonMessage(_dnl.COMM_NAME, commMessage, channelType)
        end
    end
end

---@type { name: string, callback: fun(info: WhoInfo|nil) }[]
local who_player_queue = {}

local who_is_running = false

local who_request_name = nil
local who_request_callback = nil
local who_request_timeout = nil

---@param info WhoInfo|nil
local function handleWhoListResult(info)
	if _dnl.DEBUG then
		print("WHO result for", who_request_name, "is", info and "found" or "not found")
	end

	if who_request_timeout then
		who_request_timeout:Cancel()
		who_request_timeout = nil
	end

	who_is_running = false

	if FriendsFrame then
		FriendsFrame:RegisterEvent("WHO_LIST_UPDATE")
	end

	local cb = who_request_callback
	who_request_name = nil
	who_request_callback = nil

	if cb then
		local ok, err = pcall(cb, info)
		if not ok and _dnl.DEBUG then
			print("WHO callback error:", err)
		end
	end
end

---@param name string
---@param callback fun(info: WhoInfo|nil)
---@return boolean
function _dnl.whoPlayer(name, callback)
	if not name or name == "" then return false end

	local name_key = _dnl.normalize(name)
	if not name_key or name_key == "" then return false end

	if who_is_running then
		_dnl.enqueueWhoPlayer(name, callback)
		return true
	end

	if _dnl.DEBUG then
		print("Initiating WHO lookup for", name_key)
	end

	who_is_running = true
	who_request_name = name_key
	who_request_callback = callback

	who_request_timeout = C_Timer.NewTimer(5, function()
		handleWhoListResult(nil)
	end)

	if FriendsFrame then
		FriendsFrame:UnregisterEvent("WHO_LIST_UPDATE")
	end

	C_FriendList.SetWhoToUi(true)
	C_FriendList.SendWho('n-"' .. name .. '"')

	return true
end

function _dnl.handleWhoListUpdate()
    if not who_is_running then return end
	if _dnl.DEBUG then
		print("Received WHO_LIST_UPDATE for", who_request_name)
	end

    local num = C_FriendList.GetNumWhoResults()
	if not num or num <= 0 then
		return
	end

	for i = 1, num do
		local info = C_FriendList.GetWhoInfo(i)
		local name = info and _dnl.normalize(info.fullName) or nil
		if name and name == who_request_name then
			handleWhoListResult(info)
			return
		end
	end

    handleWhoListResult(nil)
end

--- Queue a /who lookup to be dispatched on next user input.
--- Returns a cancel function that removes the entry from the queue
--- (no-op if it has already been dispatched).
---@param name string
---@param callback fun(info: WhoInfo|nil)
---@return fun(): boolean cancel  Remove this entry; returns true if it was still queued.
function _dnl.enqueueWhoPlayer(name, callback)
	if _dnl.DEBUG then
		print("Enqueuing WHO lookup for", name)
	end
	local entry = { name = name, callback = callback }
	table.insert(who_player_queue, entry)
	return function()
		for i = #who_player_queue, 1, -1 do
			if who_player_queue[i] == entry then
				table.remove(who_player_queue, i)
				if _dnl.DEBUG then
					print("Dequeued WHO lookup for", name)
				end
				return true
			end
		end
		return false
	end
end

local function whoNextInQueue()
    if who_is_running then return end
	if #who_player_queue > 0 then
		local entry = table.remove(who_player_queue, 1)
		_dnl.whoPlayer(entry.name, entry.callback)
	end
end

_dnl.registerInputDrain(whoNextInQueue)

--#region API

---@param _name string
---@param _tag string  3-char addon tag
DeathNotificationLib.QueryGuild = function(_name, _tag) sendQuery(_name, "GUILD", nil, _tag) end

---@param _name string
---@param _target string
---@param _tag string  3-char addon tag
DeathNotificationLib.QueryTarget = function(_name, _target, _tag) sendQuery(_name, "WHISPER", _target, _tag) end

---@param _name string
---@param _tag string  3-char addon tag
DeathNotificationLib.QueryYell = function(_name, _tag) sendQuery(_name, "YELL", nil, _tag) end

---@param _name string
---@param _tag string  3-char addon tag
DeathNotificationLib.QuerySay = function(_name, _tag) sendQuery(_name, "SAY", nil, _tag) end

DeathNotificationLib.WhoPlayer = _dnl.whoPlayer

--#endregion