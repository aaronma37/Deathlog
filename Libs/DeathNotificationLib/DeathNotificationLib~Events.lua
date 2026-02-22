--[[
DeathNotificationLib~Events.lua

WoW event dispatcher and library initialization.

Registers for all game events relevant to death logging and routes them
to the appropriate handler functions.  Also provides AttachAddon(), the
per-addon registration call that binds an addon's settings, database
references, and callbacks to the multi-addon registry.

Handled events (partial list):
  CHAT_MSG_CHANNEL            – death pings, checksums, duel requests
  COMBAT_LOG_EVENT_UNFILTERED – last-attack-source tracking per unit
  PLAYER_DEAD                 – self-death broadcast (tracked characters)
  UNIT_HEALTH                 – party/raid death detection (health → 0)
  CHAT_MSG_SAY/GUILD/PARTY    – captures "last words" for death reports
  PLAYER_ENTERING_WORLD       – channel joins
  HARDCORE_DEATHS             – Blizzard built-in death announcements
  DUEL_TO_THE_DEATH_REQUESTED - duel-to-death state management
  CHAT_MSG_ADDON              – query/response protocol, sync dispatch
  WHO_LIST_UPDATE             – /who result interception
  CHAT_MSG_MONSTER_EMOTE      – Tarnished Soul emotes (via ~BlizzardParser.lua)
--]]

local _dnl = DeathNotificationLib.Internal ---@class _dnl
if not _dnl then return end
local SOURCE = _dnl.SOURCE

--- Pre-broadcast self-death hooks — called when the local player dies,
--- before the death is broadcast.  Each hook receives a **shallow copy**
--- of the PlayerData table and may mutate it freely.  If the copy still
--- passes validatePlayerData after the hook returns, the changes are
--- accepted; otherwise the copy is discarded and the original is kept.
---@type fun(player_data: PlayerData)[] 
local hook_self_death_functions = {}

local CTL = _G.ChatThrottleLib

local comm_query_locks = {}
local last_playtime = 0
local last_playtime_updated_at = time()
local playtime_suppression_counter = 0
local displayTimePlayed = ChatFrameUtil and ChatFrameUtil.DisplayTimePlayed or ChatFrame_DisplayTimePlayed

local function displayTimePlayedOverride(...)
	if playtime_suppression_counter > 0 then
		playtime_suppression_counter = playtime_suppression_counter - 1
		return
	end
	return displayTimePlayed(...)
end

if ChatFrameUtil and ChatFrameUtil.DisplayTimePlayed then
	ChatFrameUtil.DisplayTimePlayed = displayTimePlayedOverride
else
	ChatFrame_DisplayTimePlayed = displayTimePlayedOverride
end

hooksecurefunc("StaticPopup_Show", function(which, text_arg1, text_arg2, data)
	if data and type(data) == "string" then
		if string.find(data, _dnl.DEATH_ALERTS_CHANNEL_BASE) == 1 or string.find(data, _dnl.SYNC_CHANNEL_BASE) == 1 then
			StaticPopup_Hide(which)
		end
	end
end)

local function getPlaytime()
	return last_playtime + (time() - last_playtime_updated_at)
end

local function requestTimePlayed()
	playtime_suppression_counter = playtime_suppression_counter + 1
	RequestTimePlayed()
end

---------------------------------------------------------------------------
-- Multi-addon broadcast decision
---------------------------------------------------------------------------

--- Check if ANY registered addon wants to track deaths for this unit.
--- Returns true if at least one addon's isUnitTracked callback says yes.
---@param unit UnitToken
---@return boolean
function _dnl.shouldBroadcastDeath(unit)
	for _, addon in pairs(_dnl.addons) do
		if addon.isUnitTracked(unit) then
			return true
		end
	end
	return false
end

---------------------------------------------------------------------------
-- Channel management
---------------------------------------------------------------------------

--- Re-check CVars, HardcoreDeaths channel membership, and keep our
--- addon channels hidden on every zone change so nothing drifts.
local function updateChannels()
	if _dnl.anyAddonAllows("auto_blizzard_deaths") then
		JoinChannelByName("HardcoreDeaths")
		SetCVar("hardcoreDeathAlertType", 2)
		SetCVar("hardcoreDeathChatType", 1)
	end

	_dnl.hideChannelFromChatFrames(_dnl.death_alerts_channel or _dnl.DEATH_ALERTS_CHANNEL_BASE)
	if _dnl.sync_channel then
		_dnl.hideChannelFromChatFrames(_dnl.sync_channel or _dnl.SYNC_CHANNEL_BASE)
	end
end

---@param arg table
local function onChatMsgChannel(arg)
	local _, channel_name = string.split(" ", arg[4])

	if channel_name == _dnl.sync_channel then
		_dnl.handleSyncChannelMessage(arg)
		return
	end

	if channel_name ~= _dnl.death_alerts_channel then
		return
	end
	local command, msg, _doublechecksum = string.split(_dnl.COMM_COMMAND_DELIM, arg[1])

	if command == _dnl.COMM_COMMANDS["BROADCAST_DEATH_PING_CHECKSUM"] then
		local player_name_short, _ = string.split("-", arg[2])
		if _dnl.throttleCheck(player_name_short) then return end

		_dnl.deathlogReceiveChannelMessageChecksum(player_name_short, msg)
		if _dnl.DEBUG then
			print("checksum", msg)
		end
		return
	end

	if command == _dnl.COMM_COMMANDS["BROADCAST_DEATH_PING"] then
		local player_name_short, _ = string.split("-", arg[2])
		if _dnl.throttleCheck(player_name_short) then return end

		local test_decoded, test_ver = _dnl.decodeMessage(msg)
		if test_decoded then
			_dnl.handleDeathBroadcast(player_name_short, msg)
		else
--#region Backwards compatible API

			if _dnl.anyAddonAllows("legacy_messages") then
				_dnl.handleV2DeathBroadcast(player_name_short, msg)
			end

--#endregion
		end
		if _dnl.DEBUG then
			print("death ping", msg)
		end
		return
	end

	if command == _dnl.COMM_COMMANDS["REQUEST_DUEL_TO_DEATH"] then
		local player_name_short, _ = string.split("-", arg[2])
		if _dnl.throttleCheck(player_name_short) then return end

		local checksum, players = string.split(_dnl.COMM_FIELD_DELIM, msg)
		local player_one, player_two = string.split("_", players)
		if player_one == UnitName("player") then
			_dnl.pvp_state.duel_to_death_player = player_two
		elseif player_two == UnitName("player") then
			_dnl.pvp_state.duel_to_death_player = player_one
		end
		return
	end

--#region Backwards compatible API

	if _dnl.backwards_dispatch[command] and _dnl.anyAddonAllows("legacy_messages") then
		local player_name_short, _ = string.split("-", arg[2])
		if _dnl.throttleCheck(player_name_short) then return end

		_dnl.backwards_dispatch[command](player_name_short, msg)
		if _dnl.DEBUG then
			print("backwards compat command", command, msg)
		end
		return
	end

--#endregion
end

---@param arg table
local function onCombatLogEventUnfiltered(arg)
	local _, ev, _, source_guid, source_name, _, _, target_guid, _, _, _, environmental_type, _, _, _, _, _ =
		CombatLogGetCurrentEventInfo()

	if ev == "ENVIRONMENTAL_DAMAGE" then
		local target = UnitTokenFromGUID(target_guid)
		if _dnl.canUseUnitStates(target) then
			_dnl.getUnitState(target).last_attack_source_name = environmental_type
			_dnl.getUnitState(target).last_attack_source_guid = nil
		end
	elseif source_guid ~= target_guid then
		if ev ~= "DAMAGE_SHIELD_MISSED" and string.find(ev, "DAMAGE") ~= nil then
			local target = UnitTokenFromGUID(target_guid)
			if _dnl.canUseUnitStates(target) then
				local source = source_name or GetUnitNameByGUID(source_guid) or UNKNOWN

				_dnl.getUnitState(target).last_attack_source_name = source
				_dnl.getUnitState(target).last_attack_source_guid = source_guid
			end
		end
	end
end

---@param arg table
local function onPlayerDead(arg)
	if not _dnl.shouldBroadcastDeath("player") then return end

	local userState = _dnl.getUnitState("player")

	local death_source, extra_data = _dnl.resolveDeathSource(userState.last_attack_source_name, userState.last_attack_source_guid)
	local instance_id, map, position = _dnl.guessLocationForUnit("player")
	local _, _, race_id = UnitRace("player")
	local _, _, class_id = UnitClass("player")
	local guildName = GetGuildInfo("player")

	local player_data = _dnl.playerData(
		UnitName("player"),
		guildName,
		death_source,
		race_id,
		class_id,
		UnitLevel("player"),
		instance_id,
		map,
		position,
		time(),
		getPlaytime(),
		userState.recent_msg,
		extra_data
	)

	for _, f in ipairs(hook_self_death_functions) do
		local copy = _dnl.deepCopy(player_data)
		f(copy)

		local ok = _dnl.validatePlayerData(copy)
		if ok then
			player_data = copy
		end
	end

	_dnl.broadcastDeath(player_data)
end

---@param arg table
local function onUnitHealth(arg)
	local target = arg[1]
	if target ~= "player" and (UnitHealth(target) == 0 or UnitIsDeadOrGhost(target)) and _dnl.canUseUnitStates(target) and _dnl.shouldBroadcastDeath(target) then
		_dnl.reportPartyRaidDeath(target)
	end
end

---Shared handler for CHAT_MSG_SAY, CHAT_MSG_GUILD, CHAT_MSG_PARTY
---@param arg table
local function onChatMsg(arg)
	local text = arg[1]
	local senderGUID = arg[12]
	local automated_text_found = string.find(text, "Our brave")
	local questie_text_found = string.find(text, "Questie")
	if automated_text_found == nil and questie_text_found == nil then
		local target = UnitTokenFromGUID(senderGUID)
		if _dnl.canUseUnitStates(target) then
			_dnl.getUnitState(target).recent_msg = text
		end
	end
end

---@param arg table
local function onPlayerEnteringWorld(arg)
	requestTimePlayed()
	C_Timer.After(5.0, function()
		_dnl.deathlogJoinChannel()
		_dnl.joinSyncChannel()
	end)
	C_Timer.NewTicker(60, requestTimePlayed)
	updateChannels()
end

---@param arg table
local function onZoneChangedNewArea(arg)
	updateChannels()
end

---@param arg table
local function onHardcoreDeaths(arg)
	_dnl.onBlizzardChat(arg[1])
end

---@param arg table
local function onDuelToTheDeathRequested(arg)
	_dnl.pvp_state.duel_to_death_player = arg[1]

	local guildName = GetGuildInfo("player")
	if guildName == nil then
		guildName = ""
	end
	local player_data =
		_dnl.playerData(UnitName("player"), guildName, nil, nil, nil, UnitLevel("player"), nil, nil, nil, nil, nil, nil)
	local checksum = _dnl.fletcher16(player_data)
	local msg = checksum
		.. _dnl.COMM_FIELD_DELIM
		.. (UnitName("player") .. "_" .. _dnl.pvp_state.duel_to_death_player)
		.. _dnl.COMM_FIELD_DELIM
		.. _dnl.PROTOCOL_VERSION
		.. _dnl.COMM_FIELD_DELIM
	table.insert(_dnl.deathlog_request_duel_to_death_queue, {msg, time()})
end

---@param arg table
local function onChatMsgAddon(arg)
	if arg[1] == _dnl.SYNC_COMM_NAME then
		_dnl.handleSyncAddonMessage(arg)
		return
	end

	if arg[1] ~= _dnl.COMM_NAME then
		return
	end
	local command, msg = string.split(_dnl.COMM_COMMAND_DELIM, arg[2])
	if command == _dnl.COMM_QUERY then
		local query_sender = arg[4]
		if comm_query_locks[query_sender] then
			return
		end
		comm_query_locks[query_sender] = C_Timer.NewTimer(3, function()
			comm_query_locks[query_sender]:Cancel()
			comm_query_locks[query_sender] = nil
		end)
		-- Extract tag from query: "Q$TAG~name" → tag = first 3 chars of msg, name = rest after ~
		local query_tag, query_name = nil, msg
		if msg and #msg > 4 and msg:sub(4, 4) == _dnl.COMM_FIELD_DELIM then
			query_tag = msg:sub(1, 3)
			query_name = msg:sub(5)
		end
		-- Tag is required — reject tagless or unknown-tag queries
		if not query_tag or not _dnl.tag_to_addon[query_tag] then return end
		local found_data = nil
		local found_tag = nil
		local addon_entry = _dnl.addons[_dnl.tag_to_addon[query_tag]]
		if addon_entry and addon_entry.db_map and addon_entry.db and addon_entry.db_map[query_name] and addon_entry.db[addon_entry.db_map[query_name]] then
			found_data = addon_entry.db[addon_entry.db_map[query_name]]
			found_tag = query_tag
		end
		if found_data then
			local response_data = _dnl.playerData(
				found_data.name, found_data.guild, found_data.source_id, found_data.race_id, found_data.class_id,
				found_data.level, found_data.instance_id, found_data.map_id, found_data.map_pos,
				found_data.date, found_data.played, found_data.last_words, found_data.extra_data
			)
			local tag_overhead = found_tag and 4 or 0  -- "TAG~" = 4 bytes
			local encoded = _dnl.encodeMessage(response_data, tag_overhead)
			if encoded then
				local resp_prefix = found_tag and (found_tag .. _dnl.COMM_FIELD_DELIM) or ""
				local commMessage = _dnl.COMM_QUERY_ACK .. _dnl.COMM_COMMAND_DELIM .. resp_prefix .. encoded
				if CTL then
					CTL:SendAddonMessage("BULK", _dnl.COMM_NAME, commMessage, "WHISPER", arg[4])
				else
					_G.SendAddonMessage(_dnl.COMM_NAME, commMessage, "WHISPER", arg[4])
				end
			end
		end
	elseif command == _dnl.COMM_QUERY_ACK then
		-- Strip tag prefix: "TAG~encoded..." → tag + encoded data
		local ack_tag, ack_data = nil, msg
		if msg and #msg > 4 and msg:sub(4, 4) == _dnl.COMM_FIELD_DELIM then
			ack_tag = msg:sub(1, 3)
			ack_data = msg:sub(5)
		end
		local _player_data, _protocol_version = _dnl.decodeMessage(ack_data)
		if _protocol_version and _protocol_version < _dnl.MIN_SUPPORTED_PROTOCOL_VERSION then
			return
		end
		if _player_data and _player_data["name"] and _dnl.expect_ack[_player_data["name"]] then
			-- Tag is required to route the response to the correct addon
			if not ack_tag or not _dnl.tag_to_addon[ack_tag] then return end
			if _dnl.isValidEntry(_player_data) then
				_dnl.createEntry(_player_data, nil, 0, nil, SOURCE.QUERY, _dnl.tag_to_addon[ack_tag])
			end
			_dnl.expect_ack[_player_data["name"]] = nil
		end
	end
end

---@param arg table
local function onWhoListUpdate(arg)
	_dnl.handleWhoListUpdate()
end

---@param arg table
local function onTimePlayedMsg(arg)
	last_playtime = arg[1]
	last_playtime_updated_at = time()

	if _dnl.DEBUG then
		print("Received new time played:", last_playtime)
	end
end

---@param arg table
local function onChatMsgMonsterEmote(arg)
	local message = arg[1]
	local player_name = arg[2]
	local player_guid = arg[12]

	if not _dnl.parseTarnishedSoulEmote(message) then
		return
	end

	if _dnl.isNameAlreadyCommitted(player_name) then
		return
	end

	if _dnl.DEBUG then
		print("Soul of Iron death detected via emote:", player_name, "GUID:", player_guid)
	end

	if player_name == UnitName("player") then
		return
	end

	local _, englishClass, _, englishRace, _, _, _ = GetPlayerInfoByGUID(player_guid)
	local class_id = englishClass and _dnl.D.CLASS_FILE_TO_ID[englishClass] or nil
	local race_id = englishRace and _dnl.D.RACE_FILE_TO_ID[englishRace] or nil

	local found_unit = _dnl.findPlayerTokenByName(player_name)
	local level = nil
	local guild = nil

	local instance_id, map, position = _dnl.guessLocationForUnit(found_unit)
	if position then
		position = string.format("%.4f,%.4f", position.x, position.y)
	end

	if found_unit then
		local unit_level = UnitLevel(found_unit)
		level = (unit_level and unit_level > 0) and unit_level or nil
		guild = GetGuildInfo(found_unit)
	end

	local function doReportedDeathBroadcast(_level, _guild, _race_id, _class_id)
		local _player_data = _dnl.playerData(
			player_name,
			_guild,
			-1,
			_race_id,
			_class_id,
			_level,
			instance_id,
			map,
			position,
			time(),
			nil,
			nil
		)
		_dnl.broadcastDeath(_player_data)
	end

	if level and race_id and class_id then
		doReportedDeathBroadcast(level, guild, race_id, class_id)
	else
		local invoked = false

		local function reportOrEnqueue()
			if invoked then return end
			invoked = true

			if level and race_id and class_id then
				doReportedDeathBroadcast(level, guild, race_id, class_id)
			else
				local queued = false
				for _, hook in ipairs(_dnl.hook_queue_player_functions) do
					if hook(player_name, player_guid, race_id, class_id, guild, map, position, instance_id) then
						queued = true
					end
				end
				if not queued then
					doReportedDeathBroadcast(level, guild, race_id, class_id)
				end
			end
		end

		local cancelWho = _dnl.enqueueWhoPlayer(player_name, function(who_info)
			if who_info then
				level = level or who_info.level
				guild = guild or (who_info.fullGuildName and _dnl.normalize(who_info.fullGuildName) or nil)
				class_id = class_id or (who_info.filename and _dnl.D.CLASS_FILE_TO_ID[who_info.filename] or nil)
				race_id = race_id or (who_info.raceStr and _dnl.D.RACE_NAME_TO_ID[who_info.raceStr] or nil)
			end

			reportOrEnqueue()
		end)

		C_Timer.After(5.0, function()
			cancelWho()
			reportOrEnqueue()
		end)
	end
end

local dispatch = {
	["CHAT_MSG_CHANNEL"]             = onChatMsgChannel,
	["COMBAT_LOG_EVENT_UNFILTERED"]  = onCombatLogEventUnfiltered,
	["PLAYER_DEAD"]                  = onPlayerDead,
	["UNIT_HEALTH"]                  = onUnitHealth,
	["CHAT_MSG_SAY"]                 = onChatMsg,
	["CHAT_MSG_GUILD"]               = onChatMsg,
	["CHAT_MSG_PARTY"]               = onChatMsg,
	["PLAYER_ENTERING_WORLD"]        = onPlayerEnteringWorld,
	["ZONE_CHANGED_NEW_AREA"]        = onZoneChangedNewArea,
	["HARDCORE_DEATHS"]              = onHardcoreDeaths,
	["DUEL_TO_THE_DEATH_REQUESTED"]  = onDuelToTheDeathRequested,
	["CHAT_MSG_ADDON"]               = onChatMsgAddon,
	["WHO_LIST_UPDATE"]              = onWhoListUpdate,
	["TIME_PLAYED_MSG"]              = onTimePlayedMsg,
}

if _dnl.IS_SOUL_OF_IRON_REALM then
    dispatch["CHAT_MSG_MONSTER_EMOTE"] = onChatMsgMonsterEmote
end

local function handleEvent(self, event, ...)
	local handler = dispatch[event]
	if handler then
		handler({ ... })
	end
end

local death_notification_lib_event_handler = CreateFrame("Frame")
for event, _ in pairs(dispatch) do
    death_notification_lib_event_handler:RegisterEvent(event)
end

if _dnl.DEBUG then
	_dnl.handleEvent = handleEvent
	_dnl.event_handler = death_notification_lib_event_handler
end

death_notification_lib_event_handler:SetScript("OnEvent", handleEvent)
C_ChatInfo.RegisterAddonMessagePrefix(_dnl.COMM_NAME)
C_ChatInfo.RegisterAddonMessagePrefix(_dnl.SYNC_COMM_NAME)

---------------------------------------------------------------------------
-- AttachAddon
---------------------------------------------------------------------------

--- Register an addon with DeathNotificationLib.
--- May be called multiple times by different addons; each gets its own
--- entry in the multi-addon registry.
---
---@class DNL_AttachAddonOptions
---@field name string                          Unique addon name (e.g. "Deathlog")
---@field tag string                           Exactly 3 characters, unique across addons (e.g. "DLG")
---@field isUnitTracked fun(unit: UnitToken): boolean  REQUIRED — should DNL broadcast deaths for this unit?
---@field settings DNL_Settings|nil            Per-addon settings (all keys have defaults)
---@field db DNL_Database|nil                  READ-ONLY by DNL: { [checksum] = PlayerData } for sync/query
---@field db_map DNL_DatabaseMap|nil           READ-ONLY by DNL: { [name] = checksum } for sync/query
---@field dev_data DNL_DevData|nil             Optional debug data
---@param options DNL_AttachAddonOptions
function _dnl.attachAddon(options)
	assert(type(options) == "table", "[DNL] AttachAddon: options must be a table")
	assert(type(options.name) == "string" and options.name ~= "", "[DNL] AttachAddon: name is required")
	assert(type(options.tag) == "string" and #options.tag == 3, "[DNL] AttachAddon: tag must be exactly 3 characters")
	assert(type(options.isUnitTracked) == "function", "[DNL] AttachAddon: isUnitTracked function is required")
	assert(not _dnl.addons[options.name], "[DNL] AttachAddon: addon '" .. options.name .. "' already registered")
	assert(not _dnl.tag_to_addon[options.tag], "[DNL] AttachAddon: tag '" .. options.tag .. "' already in use by '" .. (_dnl.tag_to_addon[options.tag] or "") .. "'")

	-- If db is provided, db_map must also be provided (and vice versa)
	if options.db or options.db_map then
		assert(options.db and options.db_map, "[DNL] AttachAddon: db and db_map must both be provided together")
	end

	---@type DNL_RegisteredAddon
	local addon = {
		name              = options.name,
		tag               = options.tag,
		isUnitTracked     = options.isUnitTracked,
		settings          = options.settings,
		db                = options.db,
		db_map            = options.db_map,
		dev_data          = options.dev_data,
	}

	_dnl.addons[options.name] = addon
	_dnl.tag_to_addon[options.tag] = options.name

	if _dnl.DEBUG then
		print(string.format("[DNL] Addon registered: %s (tag=%s, db=%s, settings=%s)",
			options.name, options.tag,
			options.db and "yes" or "no",
			options.settings and "yes" or "no"))
	end
end

--#region API

DeathNotificationLib.AttachAddon = _dnl.attachAddon

---Register a hook that fires when the local player dies, before broadcast.
---The hook receives a **shallow copy** of the PlayerData table.  Mutate it
---in place to enrich it (e.g. add extra_data fields).  If the copy fails
---validatePlayerData after your hook returns, the changes are silently
---discarded and the original data is broadcast unchanged.
---@param fn fun(player_data: PlayerData)
DeathNotificationLib.HookOnSelfDeath = function(fn) hook_self_death_functions[#hook_self_death_functions + 1] = fn end

--#endregion