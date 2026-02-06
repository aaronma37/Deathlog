--[[
Copyright 2026 Yazpad & Deathwing
The DeathNotificationLib is distributed under the terms of the GNU General Public License (or the Lesser GPL).
This file is part of Hardcore.

The DeathNotificationLib is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

The DeathNotificationLib is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with the DeathNotificationLib. If not, see <http://www.gnu.org/licenses/>.
--]]
--
local debug = false
local beautify_prefix = "8"
local enable_guild_death_notifications = false
local CTL = _G.ChatThrottleLib
local COMM_NAME = "HCDeathAlerts"
local COMM_COMMANDS = {
	["BROADCAST_DEATH_PING"] = "1",
	["BROADCAST_DEATH_PING_CHECKSUM"] = "2",
	["LAST_WORDS"] = "3",
	["GUILD_DEATH_NOTIFICATION"] = "4",
	["REQUEST_DUEL_TO_DEATH"] = "5",
	["TARNISHED_SOUL"] = "6",
}
local PROTOCOL_VERSION = 2
local SOI_MIN_PROTOCOL_VERSION = 2
-- local practice_str = "[Syphonage] drowned to death in Mist's Edge! They were level 18"
-- local practice_str = "[Syphonage] fell to death in Mist's Edge! They were level 18"
-- local practice_str_2 = "[Syphonage] has been slain by a Defias Rogue Wizard in Mirror Lake! They were level 13"
local COMM_QUERY = "Q"
local comm_query_lock = nil
local comm_query_lock_out = nil
local COMM_QUERY_ACK = "R"
local COMM_COMMAND_DELIM = "$"
local COMM_FIELD_DELIM = "~"
local HC_DEATH_LOG_MAX = 100000

Deathlog_HC_STATE_HARDCORE = "HARDCORE"
Deathlog_HC_STATE_NOT_HARDCORE_ANYMORE = "NOT_HARDCORE_ANYMORE"
Deathlog_HC_STATE_NOT_HARDCORE = "NOT_HARDCORE"
Deathlog_HC_STATE_UNDETERMINED = "UNDETERMINED"

Deathlog_maxPlayerLevel = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or MAX_PLAYER_LEVEL
Deathlog_isHardcoreRealm = (C_ClassicHardcore and C_ClassicHardcore.IsHardcoreSelf and C_ClassicHardcore.IsHardcoreSelf()) or (C_Seasons and C_Seasons.GetActiveSeason and (C_Seasons.GetActiveSeason() == 3 or C_Seasons.GetActiveSeason() == 12))
Deathlog_isSoulOfIronRealm = WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC
Deathlog_allowExport = debug

function Deathlog_playerHasSoulOfIron()
	for i = 1, 40 do
		local auraData = C_UnitAuras.GetBuffDataByIndex("player", i)
		if not auraData then break end
		if auraData.spellId == 364001 then
			return true
		end
	end

	return false
end

function Deathlog_playerHasTarnishedSoul()
	for i = 1, 40 do
		local auraData = C_UnitAuras.GetDebuffDataByIndex("player", i)
		if not auraData then break end
		if auraData.spellId == 364226 then
			return true
		end
	end

	return false
end

function Deathlog_updateSoulOfIronTracking()
	if not Deathlog_isSoulOfIronRealm then return end

	if not deathlog_char_data then deathlog_char_data = {} end

	if Deathlog_playerHasSoulOfIron() then
		deathlog_char_data.hasSoulOfIron = true
		deathlog_char_data.hadSoulOfIron = true
	else
		deathlog_char_data.hasSoulOfIron = false
	end

	if Deathlog_playerHasTarnishedSoul() then
		deathlog_char_data.hasTarnishedSoul = true
		deathlog_char_data.hadTarnishedSoul = true
	else
		deathlog_char_data.hasTarnishedSoul = false
	end
end

function Deathlog_getHardcoreCharacterState()
	if Deathlog_isHardcoreRealm then
		return Deathlog_HC_STATE_HARDCORE
	end

	if Deathlog_isSoulOfIronRealm then
		if not deathlog_char_data then deathlog_char_data = {} end

		if deathlog_char_data.hasSoulOfIron then
			return Deathlog_HC_STATE_HARDCORE
		end

		if deathlog_char_data.hadTarnishedSoul then
			return Deathlog_HC_STATE_NOT_HARDCORE_ANYMORE
		end

		return Deathlog_HC_STATE_UNDETERMINED
	end
	
	return Deathlog_HC_STATE_NOT_HARDCORE
end

function Deathlog_createInfoButton(container, with_events, offset_x, offset_y)
	if container.info_button == nil then
		container.info_button = CreateFrame("Button", nil, container.frame, "UIPanelCloseButton")

		local info_button = container.info_button
		info_button.deathlog_hc_state = "NOT_DETERMINED"
		info_button.deathlog_hc_state_func = nil
		info_button:SetPoint("RIGHT", container.titletext, "RIGHT", offset_x or 32, offset_y or 0)
		info_button:SetSize(32, 32)
		info_button:EnableMouse(true)
		info_button:SetFrameLevel(container.frame:GetFrameLevel() + 10)
		info_button:SetNormalTexture("Interface\\common\\help-i")
		info_button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
		info_button:SetPushedTexture("Interface\\common\\help-i")
		info_button:SetScript("OnClick", nil)
		info_button:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		info_button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
			
			if self.deathlog_hc_state_func then
				self.deathlog_hc_state_func(self)
			end

            GameTooltip:Show()
        end)

		local function updateStateInfoButton()
			if not info_button then
				return
			end

			local state = Deathlog_getHardcoreCharacterState()
			if info_button.deathlog_hc_state == state then
				return
			end

			info_button.deathlog_hc_state = state
			if state == Deathlog_HC_STATE_HARDCORE then
				info_button:Hide()
			elseif state == Deathlog_HC_STATE_NOT_HARDCORE_ANYMORE then
				info_button.deathlog_hc_state_func = function(self)
					GameTooltip:ClearLines()
					GameTooltip:AddLine("Death Logging Status", 1, 0.8, 0, 1)
					GameTooltip:AddLine(" ")
					GameTooltip:AddLine("Status: |cffFF4444NOT HARDCORE ANYMORE|r")
					GameTooltip:AddLine(" ")
					GameTooltip:AddLine("You have lost your Hardcore status by acquiring", 0.7, 0.7, 0.7)
					GameTooltip:AddLine("the \"Tarnished Soul\" debuff.", 0.7, 0.7, 0.7)
					GameTooltip:AddLine(" ")
					GameTooltip:AddLine("As a result, your deaths will no longer be", 0.7, 0.7, 0.7)
					GameTooltip:AddLine("logged to the Deathlog system.", 0.7, 0.7, 0.7)
				end
				info_button:Show()
			elseif state == Deathlog_HC_STATE_UNDETERMINED then
				local location = UnitFactionGroup("player") == "Alliance" and "Ironforge" or "Undercity"
				info_button.deathlog_hc_state_func = function(self)
					GameTooltip:ClearLines()
					GameTooltip:AddLine("Death Logging Status", 1, 0.8, 0, 1)
					GameTooltip:AddLine(" ")
					GameTooltip:AddLine("Status: |cffFFFF00SOUL OF IRON REQUIRED|r")
					GameTooltip:AddLine(" ")
					GameTooltip:AddLine("To participate in death logging, you need:", 0.7, 0.7, 0.7)
					GameTooltip:AddLine("• Get the \"Soul of Iron\" buff", 1, 1, 0.5)
					GameTooltip:AddLine("• Location: " .. location, 0.5, 1, 1)
					GameTooltip:AddLine(" ")
					GameTooltip:AddLine("Once active, your deaths will be logged to the", 0.7, 0.7, 0.7)
					GameTooltip:AddLine("Deathlog system automatically.", 0.7, 0.7, 0.7)
				end
				info_button:Show()
			else
				info_button.deathlog_hc_state_func = function(self)
					GameTooltip:ClearLines()
					GameTooltip:AddLine("Death Logging Status", 1, 0.8, 0, 1)
					GameTooltip:AddLine(" ")
					GameTooltip:AddLine("Status: |cffFF4444NOT SUPPORTED|r")
					GameTooltip:AddLine(" ")
					GameTooltip:AddLine("Your realm is not currently supported by the", 0.7, 0.7, 0.7)
					GameTooltip:AddLine("Deathlog addon.", 0.7, 0.7, 0.7)
					GameTooltip:AddLine(" ")
					GameTooltip:AddLine("Supported Realms:", 1, 1, 0.5)
					GameTooltip:AddLine("• Classic Era Hardcore", 0.5, 1, 1)
					GameTooltip:AddLine("• Burning Crusade - Soul of Iron", 0.5, 1, 1)
				end
				info_button:Show()
			end
		end

		container.frame:HookScript("OnShow", function()
			updateStateInfoButton()
		end)
		
		if with_events then
			info_button:RegisterEvent("PLAYER_ENTERING_WORLD")
			if Deathlog_isSoulOfIronRealm then
				info_button:RegisterEvent("UNIT_AURA")
			end
			info_button:SetScript("OnEvent", function(self, event, unit)
				if event == "PLAYER_ENTERING_WORLD" or (event == "UNIT_AURA" and unit == "player") then
					updateStateInfoButton()
				end
			end)
		end
	end

	return container.info_button
end

local death_alerts_channel = "hcdeathalertschannel"
local death_alerts_channel_pw = "hcdeathalertschannelpw"

local throttle_player = {}
local shadowbanned = {}
local last_attack_source = nil
local recent_msg = ""
local entry_cache = {}
local entry_cache_secure = {}
local bliz_alert_cache = {}
local attached_db = nil
local attached_db_map = nil

local _class_tbl = {
	["Warrior"] = 1,
	["Paladin"] = 2,
	["Hunter"] = 3,
	["Rogue"] = 4,
	["Priest"] = 5,
	["Shaman"] = 7,
	["Mage"] = 8,
	["Warlock"] = 9,
	["Druid"] = 11,
}

deathlog_environment_damage = {
	[-2] = "Drowning",
	[-3] = "Falling",
	[-4] = "Fatigue",
	[-5] = "Fire",
	[-6] = "Lava",
	[-7] = "Slime",
}

deathlog_last_duel_to_death_player = nil
deathlog_last_attack_player = nil
deathlog_last_attack_race = nil
deathlog_last_attack_class = nil
deathlog_last_attack_level = nil

function deathlog_refresh_last_attack_info(source_name)
	local _, _, targetRaceId = UnitRace("target")
	local _, _, targetClassId = UnitClass("target")
	local targetLevel = UnitLevel("target")

	deathlog_last_attack_player = source_name
	deathlog_last_attack_race = tonumber(targetRaceId)
	deathlog_last_attack_class = tonumber(targetClassId)
	deathlog_last_attack_level = targetLevel
end

function deathlog_clear_last_attack_info()
	deathlog_last_attack_player = nil
	deathlog_last_attack_race = nil
	deathlog_last_attack_class = nil
	deathlog_last_attack_level = nil
end

local deathlog_who_callbacks = {}
function deathlog_query_who(name, callback)
	if not name or name == "" then return false end

	deathlog_who_callbacks[name:lower()] = callback

	if FriendsFrame then
		FriendsFrame:UnregisterEvent("WHO_LIST_UPDATE")
	end

	C_FriendList.SetWhoToUi(false)
	C_FriendList.SendWho('n-"' .. name .. '"')
	return true
end

-- Encode extra_data table to string format: key1=value1|key2=value2
-- Escapes special characters: ~ -> \t, | -> \p, = -> \e, \ -> \\
local function encodeExtraData(extra_data)
	if extra_data == nil or type(extra_data) ~= "table" then
		return ""
	end
	local parts = {}
	for k, v in pairs(extra_data) do
		if type(k) == "string" and (type(v) == "string" or type(v) == "number" or type(v) == "boolean") then
			local key = tostring(k):gsub("\\", "\\\\"):gsub("~", "\\t"):gsub("|", "\\p"):gsub("=", "\\e")
			local val = tostring(v):gsub("\\", "\\\\"):gsub("~", "\\t"):gsub("|", "\\p"):gsub("=", "\\e")
			table.insert(parts, key .. "=" .. val)
		end
	end
	return table.concat(parts, "|")
end

-- Decode extra_data string back to table
local function decodeExtraData(str)
	if str == nil or str == "" then
		return nil
	end
	local result = {}
	for pair in str:gmatch("([^|]+)") do
		local key, val = pair:match("^(.-)=(.*)$")
		if key and val then
			-- Unescape in reverse order
			key = key:gsub("\\e", "="):gsub("\\p", "|"):gsub("\\t", "~"):gsub("\\\\", "\\")
			val = val:gsub("\\e", "="):gsub("\\p", "|"):gsub("\\t", "~"):gsub("\\\\", "\\")
			result[key] = val
		end
	end
	if next(result) == nil then
		return nil
	end
	return result
end

local function PlayerData(
	name,
	guild,
	source_id,
	race_id,
	class_id,
	level,
	instance_id,
	map_id,
	map_pos,
	date,
	last_words,
	extra_data
)
	return {
		["name"] = name,
		["guild"] = guild,
		["source_id"] = source_id,
		["race_id"] = race_id,
		["class_id"] = class_id,
		["level"] = level,
		["instance_id"] = instance_id,
		["map_id"] = map_id,
		["map_pos"] = map_pos,
		["date"] = date,
		["last_words"] = last_words,
		["extra_data"] = extra_data,
	}
end

-- Public API to handle death notifications
-- To use, pass in a function that takes in (_player_data, _checksum, _peer_report, _in_guild)
-- E.g. DeathNotificationLib_HookOnNewEntry(function(_player_data, _checksum, _peer_report, _in_guild) ... end)
-- @param _player_data metadata for player entry.
-- 	@field name Player's name
-- 	@field guild Player's guild
-- 	@field source_id ID of creature that killed the player
-- 	@field class_id Class ID of the player
-- 	@field level Player's level
-- 	@field instance_id Instance that player died in. Nil if player did not die in an instance
-- 	@field map_id Zone ID that player died in. Nil if player died in an instance instead
-- 	@field map_pos Map coordinates within zone specified by map_id, nil if player died in an instance instead
-- 	@field date Date that the player died.  Unix Epoch.
-- 	@field last_words Player's last words.
-- 	@field extra_data Optional table with additional key-value data (e.g., {["pvp_source_name"] = "PlayerName"} for PvP deaths)
-- @param _checksum A checksum for the player data
-- @param _peer_report Number of guildmates that verified the death
-- @param _in_guild Whether the player is in your guild
local hook_on_entry_functions = {}
function DeathNotificationLib_HookOnNewEntry(fun)
	hook_on_entry_functions[#hook_on_entry_functions + 1] = fun
end

local hook_on_entry_functions_secure = {}
function DeathNotificationLib_HookOnNewEntrySecure(fun)
	hook_on_entry_functions_secure[#hook_on_entry_functions_secure + 1] = fun
end

DeathNotificationLib_HookOnNewEntrySecure(function(_player_data)
	if _player_data["name"] ~= nil then
		bliz_alert_cache[_player_data["name"]] = 1
	end
end)

DeathNotificationLib_HookOnNewEntry(function(_player_data)
	if _player_data["name"] ~= nil then
		bliz_alert_cache[_player_data["name"]] = 1
	end
end)

function DeathNotificationLib_attachDB(db, db_map)
	attached_db = db
	attached_db_map = db_map
end

local expect_ack = {}
function DeathNotificationLib_queryGuild(_name)
	local commMessage = COMM_QUERY .. COMM_COMMAND_DELIM .. _name
	if CTL then
		if comm_query_lock_out then
			return
		end
		comm_query_lock_out = C_Timer.NewTimer(3, function()
			comm_query_lock_out:Cancel()
			comm_query_lock_out = nil
		end)
		expect_ack[_name] = 1
		CTL:SendAddonMessage("BULK", COMM_NAME, commMessage, "GUILD")
	end
end

function DeathNotificationLib_queryTarget(_name, _target)
	local commMessage = COMM_QUERY .. COMM_COMMAND_DELIM .. _name
	if CTL then
		if comm_query_lock_out then
			return
		end
		comm_query_lock_out = C_Timer.NewTimer(3, function()
			comm_query_lock_out:Cancel()
			comm_query_lock_out = nil
		end)
		expect_ack[_name] = 1
		CTL:SendAddonMessage("BULK", COMM_NAME, commMessage, "WHISPER", _target)
	end
end

function DeathNotificationLib_queryYell(_name)
	local commMessage = COMM_QUERY .. COMM_COMMAND_DELIM .. _name
	if CTL then
		if comm_query_lock_out then
			return
		end
		comm_query_lock_out = C_Timer.NewTimer(3, function()
			comm_query_lock_out:Cancel()
			comm_query_lock_out = nil
		end)
		expect_ack[_name] = 1
		CTL:SendAddonMessage("BULK", COMM_NAME, commMessage, "YELL")
	end
end

function DeathNotificationLib_querySay(_name)
	local commMessage = COMM_QUERY .. COMM_COMMAND_DELIM .. _name
	if CTL then
		if comm_query_lock_out then
			return
		end
		comm_query_lock_out = C_Timer.NewTimer(3, function()
			comm_query_lock_out:Cancel()
			comm_query_lock_out = nil
		end)
		expect_ack[_name] = 1
		CTL:SendAddonMessage("BULK", COMM_NAME, commMessage, "SAY")
	end
end

local function isValidEntry(_player_data)
	if _player_data == nil then
		return false
	end
	if _player_data["source_id"] == nil then
		return false
	end
	if
		_player_data["race_id"] == nil
		or tonumber(_player_data["race_id"]) == nil
		or C_CreatureInfo.GetRaceInfo(_player_data["race_id"]) == nil
	then
		return false
	end
	if
		_player_data["class_id"] == nil
		or tonumber(_player_data["class_id"]) == nil
		or GetClassInfo(_player_data["class_id"]) == nil
	then
		return false
	end
	if _player_data["level"] == nil or _player_data["level"] < 0 or _player_data["level"] > 80 then
		return false
	end
	if _player_data["instance_id"] == nil and _player_data["map_id"] == nil then
		return false
	end
	return true
end

local function lesserIsValidEntry(_player_data)
	if _player_data == nil then
		return false
	end
	if _player_data["source_id"] == nil then
		return false
	end
	if
		_player_data["class_id"] == nil
		or tonumber(_player_data["class_id"]) == nil
		or GetClassInfo(_player_data["class_id"]) == nil
	then
		return false
	end
	if _player_data["level"] == nil or _player_data["level"] < 0 or _player_data["level"] > 80 then
		return false
	end
	return true
end

local function encodeMessage(name, guild, source_id, race_id, class_id, level, instance_id, map_id, map_pos, extra_data)
	if name == nil then
		return
	end
	if tonumber(source_id) == nil then
		return
	end
	if tonumber(race_id) == nil then
		return
	end
	if tonumber(level) == nil then
		return
	end

	local loc_str = ""
	if map_pos then
		if type(map_pos) == "table" and map_pos.x and map_pos.y then
			loc_str = string.format("%.4f,%.4f", map_pos.x, map_pos.y)
		elseif type(map_pos) == "string" then
			loc_str = map_pos
		end
	end
	local comm_message = name
		.. COMM_FIELD_DELIM
		.. (guild or "")
		.. COMM_FIELD_DELIM
		.. source_id
		.. COMM_FIELD_DELIM
		.. race_id
		.. COMM_FIELD_DELIM
		.. class_id
		.. COMM_FIELD_DELIM
		.. level
		.. COMM_FIELD_DELIM
		.. (instance_id or "")
		.. COMM_FIELD_DELIM
		.. (map_id or "")
		.. COMM_FIELD_DELIM
		.. loc_str
		.. COMM_FIELD_DELIM
		.. encodeExtraData(extra_data)
		.. COMM_FIELD_DELIM
	return comm_message
end

local function lesserEncodeMessage(name, guild, source_id, race_id, class_id, level, instance_id, map_id, map_pos, extra_data)
	if name == nil then
		return
	end
	if tonumber(source_id) == nil then
		return
	end
	if tonumber(level) == nil then
		return
	end

	local loc_str = ""
	local map_pos = nil
	local comm_message = name
		.. COMM_FIELD_DELIM
		.. (guild or "")
		.. COMM_FIELD_DELIM
		.. source_id
		.. COMM_FIELD_DELIM
		.. (race_id or "")
		.. COMM_FIELD_DELIM
		.. class_id
		.. COMM_FIELD_DELIM
		.. level
		.. COMM_FIELD_DELIM
		.. (instance_id or "")
		.. COMM_FIELD_DELIM
		.. (map_id or "")
		.. COMM_FIELD_DELIM
		.. loc_str
		.. COMM_FIELD_DELIM
		.. encodeExtraData(extra_data)
		.. COMM_FIELD_DELIM
	return comm_message
end

local function encodeMessageFull(
	name,
	guild,
	source_id,
	race_id,
	class_id,
	level,
	instance_id,
	map_id,
	map_pos,
	last_words,
	date,
	extra_data
)
	if date == nil then
		date = time()
	end
	if name == nil then
		return
	end
	if tonumber(source_id) == nil then
		return
	end
	if tonumber(race_id) == nil then
		return
	end
	if tonumber(level) == nil then
		return
	end

	local loc_str = map_pos or ""

	local comm_message = name
		.. COMM_FIELD_DELIM
		.. (guild or "")
		.. COMM_FIELD_DELIM
		.. source_id
		.. COMM_FIELD_DELIM
		.. race_id
		.. COMM_FIELD_DELIM
		.. class_id
		.. COMM_FIELD_DELIM
		.. level
		.. COMM_FIELD_DELIM
		.. (instance_id or "")
		.. COMM_FIELD_DELIM
		.. (map_id or "")
		.. COMM_FIELD_DELIM
		.. loc_str
		.. COMM_FIELD_DELIM
		.. (last_words or "")
		.. COMM_FIELD_DELIM
		.. date
		.. COMM_FIELD_DELIM
		.. encodeExtraData(extra_data)
		.. COMM_FIELD_DELIM
	return comm_message
end

local function decodeMessage(msg)
	local values = {}
	for w in msg:gmatch("(.-)~") do
		table.insert(values, w)
	end
	local date = values[11] or nil
	local last_words = values[10] or nil
	local extra_data_str = values[12] or nil
	local name = values[1]
	local guild = values[2]
	local source_id = tonumber(values[3])
	local race_id = tonumber(values[4])
	local class_id = tonumber(values[5])
	local level = tonumber(values[6])
	local instance_id = tonumber(values[7])
	local map_id = tonumber(values[8])
	local map_pos = values[9]
	local extra_data = decodeExtraData(extra_data_str)
	local player_data =
		PlayerData(name, guild, source_id, race_id, class_id, level, instance_id, map_id, map_pos, date, last_words, extra_data)
	return player_data
end

-- [checksum -> {name, guild, source, race, class, level, F's, location, last_words, location}]
local death_ping_lru_cache_tbl = {}
local death_ping_guild_notification_cache_ = {}
local death_ping_lru_cache_ll = {}
local broadcast_death_ping_queue = {}
local death_alert_out_queue = {}
local death_alert_out_queue_guild_notification = {}
local last_words_queue = {}
local deathlog_request_duel_to_death_queue = {}
local tarnished_soul_out_queue = {}

local tarnished_soul_cache = {}
local TARNISHED_SOUL_DEDUP_WINDOW = 300

local REPORT_QUALITY = {
	BASIC = 1,
	CONTEXT = 2,
	SELF = 3,
}

local function getTarnishedSoulQuality(player_data, is_self_report)
	if is_self_report then
		return REPORT_QUALITY.SELF
	elseif player_data["level"] and player_data["level"] > 0 then
		return REPORT_QUALITY.CONTEXT
	else
		return REPORT_QUALITY.BASIC
	end
end

local function shouldUpgradeTarnishedSoul(name, new_quality, new_timestamp)
	local name_lower = name:lower()
	local existing = tarnished_soul_cache[name_lower]

	if not existing then
		return true
	end

	local time_diff = math.abs(new_timestamp - existing.timestamp)
	if time_diff > TARNISHED_SOUL_DEDUP_WINDOW then
		return true
	end

	return new_quality > existing.quality
end

local function fletcher16Raw(data)
	local sum1 = 0
	local sum2 = 0
	for index = 1, #data do
		sum1 = (sum1 + string.byte(string.sub(data, index, index))) % 255
		sum2 = (sum2 + sum1) % 255
	end
	return bit.bor(bit.lshift(sum2, 8), sum1)
end

local function fletcher16(_player_data)
	local data = _player_data["name"] .. _player_data["guild"] .. _player_data["level"]
	local sum1 = 0
	local sum2 = 0
	for index = 1, #data do
		sum1 = (sum1 + string.byte(string.sub(data, index, index))) % 255
		sum2 = (sum2 + sum1) % 255
	end
	return _player_data["name"] .. "-" .. bit.bor(bit.lshift(sum2, 8), sum1)
end

local function createEntryDirect(_player_data)
	for _, f in ipairs(hook_on_entry_functions) do
		f(_player_data, nil, nil, nil)
	end
end

local function createEntry(checksum)
	if debug then
		if death_ping_lru_cache_tbl[checksum]["player_data"]["last_words"] then
			print(death_ping_lru_cache_tbl[checksum]["player_data"]["last_words"])
		else
			print("no last words detected")
		end
	end
	death_ping_lru_cache_tbl[checksum]["player_data"]["date"] = time()
	death_ping_lru_cache_tbl[checksum]["committed"] = 1

	for _, f in ipairs(hook_on_entry_functions) do
		f(
			death_ping_lru_cache_tbl[checksum]["player_data"],
			checksum,
			(death_ping_lru_cache_tbl[checksum]["peer_report"] or 0),
			death_ping_lru_cache_tbl[checksum]["in_guild"]
		)
	end
end

local function createEntrySecure(checksum)
	if debug then
		if death_ping_lru_cache_tbl[checksum]["player_data"]["last_words"] then
			print(death_ping_lru_cache_tbl[checksum]["player_data"]["last_words"])
		else
			print("no last words detected")
		end
	end
	death_ping_lru_cache_tbl[checksum]["player_data"]["date"] = time()
	death_ping_lru_cache_tbl[checksum]["committed_secure"] = 1

	for _, f in ipairs(hook_on_entry_functions_secure) do
		f(
			death_ping_lru_cache_tbl[checksum]["player_data"],
			checksum,
			(death_ping_lru_cache_tbl[checksum]["peer_report"] or 0),
			death_ping_lru_cache_tbl[checksum]["in_guild"]
		)
	end
end

local function shouldCreateEntry(checksum)
	if death_ping_lru_cache_tbl[checksum] == nil then
		return false
	end
	if death_ping_lru_cache_tbl[checksum]["player_data"] == nil then
		return false
	end
	if isValidEntry(death_ping_lru_cache_tbl[checksum]["player_data"]) == false then
		return false
	end
	if entry_cache[checksum] then
		return false
	end
	entry_cache[checksum] = 1
	return true
end

local function shouldCreateEntryGuildNotification(checksum)
	if death_ping_guild_notification_cache_[checksum] == nil then
		return false
	end
	if death_ping_guild_notification_cache_[checksum]["player_data"] == nil then
		return false
	end
	if lesserIsValidEntry(death_ping_guild_notification_cache_[checksum]["player_data"]) == false then
		return false
	end
	if entry_cache[checksum] then
		return false
	end
	if
		death_ping_guild_notification_cache_[checksum]["num_reported"] == nil
		or death_ping_guild_notification_cache_[checksum]["num_reported"] < 2
	then
		return false
	end
	entry_cache[checksum] = 1
	if death_ping_lru_cache_tbl[checksum] == nil then
		death_ping_lru_cache_tbl[checksum] = {}
	end
	death_ping_lru_cache_tbl[checksum]["player_data"] = death_ping_guild_notification_cache_[checksum]["player_data"]
	return true
end

local function shouldCreateEntrySecure(checksum)
	if death_ping_lru_cache_tbl[checksum] == nil then
		return false
	end
	if death_ping_lru_cache_tbl[checksum]["player_data"] == nil then
		return false
	end
	if isValidEntry(death_ping_lru_cache_tbl[checksum]["player_data"]) == false then
		return false
	end
	if death_ping_lru_cache_tbl[checksum]["peer_report"] == nil then
		return false
	end
	if death_ping_lru_cache_tbl[checksum]["peer_report"] < 2 then
		return false
	end
	if entry_cache_secure[checksum] then
		return false
	end
	entry_cache_secure[checksum] = 1
	return true
end

function DeathNotificationLib_CreateTarnishedSoulEntry(name, level, guild, race_id, class_id, map_id, map_pos, instance_id, is_self_report, skip_broadcast)
	local current_time = time()
	local _player_data = PlayerData(name, guild or "", -1, race_id, class_id, level, instance_id, map_id, map_pos, current_time, nil)
	local quality = getTarnishedSoulQuality(_player_data, is_self_report)
	local name_lower = name:lower()

	if debug then
		print("Tarnished soul entry for:", name, "level:", level, "quality:", quality, "self:", is_self_report and "yes" or "no")
	end

	local existing = tarnished_soul_cache[name_lower]
	if existing and existing.superseded_by_self_report then
		local time_diff = math.abs(current_time - existing.timestamp)
		if time_diff <= TARNISHED_SOUL_DEDUP_WINDOW then
			if debug then
				print("Skipping tarnished soul - already have self-reported death for:", name)
			end
			return false
		end
	end

	if not shouldUpgradeTarnishedSoul(name, quality, current_time) then
		if debug then
			print("Skipping tarnished soul - existing entry has equal or higher quality")
		end
		return false
	end

	local is_upgrade = existing ~= nil and (current_time - existing.timestamp) <= TARNISHED_SOUL_DEDUP_WINDOW
	local was_committed = existing and existing.committed

	tarnished_soul_cache[name_lower] = {
		player_data = _player_data,
		quality = quality,
		timestamp = current_time,
		committed = was_committed or false,
		broadcast_pending = not skip_broadcast,
		superseded_by_self_report = false,
	}

	if debug then
		print("Creating tarnished soul entry for:", name, "level:", level, "class:", class_id, "race:", race_id, "quality:", quality, is_upgrade and "(upgrade)" or "(new)")
	end

	if not skip_broadcast then
		local msg = encodeMessage(name, guild or "", -1, race_id or 0, class_id or 0, level or 0, instance_id, map_id, map_pos)
		if msg then
			msg = msg .. quality .. COMM_FIELD_DELIM .. PROTOCOL_VERSION .. COMM_FIELD_DELIM
			table.insert(tarnished_soul_out_queue, msg)
			if debug then
				print("Queued tarnished soul broadcast for:", name)
			end
		end
	end

	C_Timer.After(4.0, function()
		local cached = tarnished_soul_cache[name_lower]
		if not cached then
			if debug then
				print("Tarnished soul entry expired for:", name)
			end
			return
		end

		if cached.superseded_by_self_report then
			if debug then
				print("Tarnished soul entry superseded by self-report for:", name)
			end
			return
		end

		if cached.committed then
			if debug then
				print("Tarnished soul entry already committed for:", name)
			end
			return
		end

		createEntryDirect(cached.player_data)
		cached.committed = true
	
		if debug then
			print("Committed tarnished soul entry for:", name, "quality:", cached.quality)
		end
	end)

	return true
end

local function selfDeathAlertLastWords(last_words)
	if last_words == nil then
		return
	end
	local _, _, race_id = UnitRace("player")
	local _, _, class_id = UnitClass("player")
	local guildName, guildRankName, guildRankIndex = GetGuildInfo("player")
	if guildName == nil then
		guildName = ""
	end
	local death_source = "-1"
	if DeathLog_Last_Attack_Source then
		death_source = npc_to_id[death_source_str]
	end

	local player_data =
		PlayerData(UnitName("player"), guildName, nil, nil, nil, UnitLevel("player"), nil, nil, nil, nil, nil)
	local checksum = fletcher16(player_data)
	local msg = checksum .. COMM_FIELD_DELIM .. last_words .. COMM_FIELD_DELIM

	table.insert(last_words_queue, msg .. PROTOCOL_VERSION .. COMM_FIELD_DELIM)
end

local function selfDeathAlert(death_source_str)
	local map = C_Map.GetBestMapForUnit("player")
	local instance_id = nil
	local position = nil
	if map then
		position = C_Map.GetPlayerMapPosition(map, "player")
		local continentID, worldPosition = C_Map.GetWorldPosFromMapPos(map, position)
	else
		local _, _, _, _, _, _, _, _instance_id, _, _ = GetInstanceInfo()
		instance_id = _instance_id
	end

	local guildName, guildRankName, guildRankIndex = GetGuildInfo("player")
	local _, _, race_id = UnitRace("player")
	local _, _, class_id = UnitClass("player")
	local death_source = "-1"
	local extra_data = nil
	if death_source_str and npc_to_id[death_source_str] then
		death_source = npc_to_id[death_source_str]
	end

	if death_source_str and deathlog_environment_damage[death_source_str] then
		death_source = death_source_str
	end

	if death_source == "-1" and death_source_str then
		local pvp_source, pvp_source_name = deathlog_encode_pvp_source(death_source_str)
		death_source = pvp_source
		if pvp_source_name then
			extra_data = { ["pvp_source_name"] = pvp_source_name }
		end
	end

	msg = encodeMessage(
		UnitName("player"),
		guildName,
		death_source,
		race_id,
		class_id,
		UnitLevel("player"),
		instance_id,
		map,
		position,
		extra_data
	)
	if msg == nil then
		return
	end
	local channel_num = GetChannelName(death_alerts_channel)

	table.insert(death_alert_out_queue, msg .. PROTOCOL_VERSION .. COMM_FIELD_DELIM)
end

local function signalGuildDeath(_name, _class_str, _level, _zone, _race, _source)
	local area_id = area_to_id[_zone] or 0
	local instance_id = id_to_instance[area_id] and area_id or nil
	local map_id = not instance_id and area_id or nil

	local guildName, guildRankName, guildRankIndex = GetGuildInfo("player")
	local msg = lesserEncodeMessage(
		_name,
		guildName,
		npc_to_id[_source],
		nil,
		_class_tbl[_class_str],
		_level,
		instance_id,
		map_id,
		nil
	)
	table.insert(death_alert_out_queue_guild_notification, msg .. PROTOCOL_VERSION .. COMM_FIELD_DELIM)
end

-- Receive a guild message. Need to send ack
local function deathlogReceiveLastWords(sender, data)
	if data == nil then
		return
	end
	local values = {}
	for w in data:gmatch("(.-)~") do
		table.insert(values, w)
	end
	local checksum = values[1]
	local msg = values[2]

	if checksum == nil or msg == nil then
		return
	end

	if death_ping_lru_cache_tbl[checksum] == nil then
		death_ping_lru_cache_tbl[checksum] = {}
	end
	if death_ping_lru_cache_tbl[checksum]["player_data"] ~= nil then
		death_ping_lru_cache_tbl[checksum]["player_data"]["last_words"] = msg
	else
		death_ping_lru_cache_tbl[checksum]["last_words"] = msg
	end
end

-- Receive a guild message. Need to send ack
local function deathlogReceiveGuildMessage(sender, data)
	if data == nil then
		return
	end
	local decoded_player_data = decodeMessage(data)
	if sender ~= decoded_player_data["name"] then
		return
	end
	if isValidEntry(decoded_player_data) == false then
		return
	end

	local valid = false
	for i = 1, GetNumGuildMembers() do
		local name, _, _, level, class_str, _, _, _, _, _, class = GetGuildRosterInfo(i)
		if name == sender and level == decoded_player_data["level"] then
			valid = true
		end
	end
	if valid == false then
		return
	end

	local checksum = fletcher16(decoded_player_data)

	if death_ping_lru_cache_tbl[checksum] == nil then
		death_ping_lru_cache_tbl[checksum] = {
			["player_data"] = player_data,
		}
	end

	if death_ping_lru_cache_tbl[checksum]["last_words"] ~= nil then
		death_ping_lru_cache_tbl[checksum]["player_data"]["last_words"] =
			death_ping_lru_cache_tbl[checksum]["last_words"]
	end

	if death_ping_lru_cache_tbl[checksum]["committed"] then
		return
	end

	death_ping_lru_cache_tbl[checksum]["self_report"] = 1
	death_ping_lru_cache_tbl[checksum]["in_guild"] = 1
	table.insert(broadcast_death_ping_queue, checksum .. COMM_FIELD_DELIM .. PROTOCOL_VERSION .. COMM_FIELD_DELIM) -- Must be added to queue to be broadcasted to network
	local delay = 2 -- seconds; wait for last words
	C_Timer.After(delay, function()
		if shouldCreateEntry(checksum) then
			createEntry(checksum)
		end
		if shouldCreateEntrySecure(checksum) then
			createEntrySecure(checksum)
		end
	end)
end

local function deathlogReceiveChannelMessageChecksum(sender, data)
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
	if death_ping_lru_cache_tbl[checksum]["committed_secure"] then
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
	local delay = 2 -- seconds; wait for last words
	C_Timer.After(delay, function()
		if shouldCreateEntry(checksum) then
			createEntry(checksum)
		end
		if shouldCreateEntrySecure(checksum) then
			createEntrySecure(checksum)
		end
	end)
end

local function deathlogReceiveChannelMessage(sender, data)
	if data == nil then
		return
	end
	local decoded_player_data = decodeMessage(data)
	if sender ~= decoded_player_data["name"] then
		return
	end
	if isValidEntry(decoded_player_data) == false then
		return
	end

	if Deathlog_isSoulOfIronRealm then
		local name_lower = sender:lower()
		local existing_tarnished = tarnished_soul_cache[name_lower]
		if existing_tarnished then
			local time_diff = math.abs(time() - existing_tarnished.timestamp)
			if time_diff <= TARNISHED_SOUL_DEDUP_WINDOW then
				existing_tarnished.superseded_by_self_report = true
				if debug then
					print("Self-reported death supersedes tarnished soul entry for:", sender)
				end
			end
		else
			tarnished_soul_cache[name_lower] = {
				player_data = nil,
				quality = REPORT_QUALITY.SELF,
				timestamp = time(),
				committed = false,
				broadcast_pending = false,
				superseded_by_self_report = true,
			}
			if debug then
				print("Recorded self-reported death for:", sender)
			end
		end
	end

	local checksum = fletcher16(decoded_player_data)

	if death_ping_lru_cache_tbl[checksum] == nil then
		death_ping_lru_cache_tbl[checksum] = {}
	end

	if death_ping_lru_cache_tbl[checksum]["player_data"] == nil then
		death_ping_lru_cache_tbl[checksum]["player_data"] = decoded_player_data
	end

	if death_ping_lru_cache_tbl[checksum]["committed"] then
		return
	end

	local guildName, guildRankName, guildRankIndex = GetGuildInfo("player")
	if decoded_player_data["guild"] == guildName then
		local name_long = sender .. "-" .. GetNormalizedRealmName()
		for i = 1, GetNumGuildMembers() do
			local name, _, _, level, class_str, _, _, _, _, _, class = GetGuildRosterInfo(i)
			if name_long == name and level == decoded_player_data["level"] then
				death_ping_lru_cache_tbl[checksum]["player_data"]["in_guild"] = 1
				local delay = math.random(0, 10)
				C_Timer.After(delay, function()
					if death_ping_lru_cache_tbl[checksum] and death_ping_lru_cache_tbl[checksum]["committed"] then
						return
					end
					table.insert(broadcast_death_ping_queue, checksum .. COMM_FIELD_DELIM .. PROTOCOL_VERSION .. COMM_FIELD_DELIM) -- Must be added to queue to be broadcasted to network
				end)
				break
			end
		end
	end

	death_ping_lru_cache_tbl[checksum]["self_report"] = 1
	local delay = 3.5 -- seconds; wait for last words
	C_Timer.After(delay, function()
		if shouldCreateEntry(checksum) then
			createEntry(checksum)
		end
		if shouldCreateEntrySecure(checksum) then
			createEntrySecure(checksum)
		end
	end)
end

local function deathlogReceiveGuildDeathNotification(sender, data, doublechecksum)
	if data == nil then
		return
	end
	local decoded_player_data = decodeMessage(data)
	-- if sender ~= decoded_player_data["name"] then -- expected to be different
	-- 	return
	-- end
	if lesserIsValidEntry(decoded_player_data) == false then
		return
	end

	local checksum = fletcher16(decoded_player_data)

	if tonumber(fletcher16Raw(sender .. data)) ~= tonumber(doublechecksum) then
		return
	end

	if death_ping_guild_notification_cache_[checksum] == nil then
		death_ping_guild_notification_cache_[checksum] = {}
	end

	if death_ping_guild_notification_cache_[checksum]["player_data"] == nil then
		death_ping_guild_notification_cache_[checksum]["player_data"] = decoded_player_data
	end

	if death_ping_guild_notification_cache_[checksum]["committed"] then
		return
	end

	if death_ping_guild_notification_cache_[checksum]["num_reported"] == nil then
		death_ping_guild_notification_cache_[checksum]["num_reported"] = 0
	end
	death_ping_guild_notification_cache_[checksum]["num_reported"] = death_ping_guild_notification_cache_[checksum]["num_reported"]
		+ 1

	local delay = 6.0 -- seconds; wait for last words
	C_Timer.After(delay, function()
		if shouldCreateEntryGuildNotification(checksum) then
			createEntry(checksum)
		end
		if shouldCreateEntrySecure(checksum) then
			createEntrySecure(checksum)
		end
	end)
end

local function deathlogReceiveTarnishedSoul(sender, data)
	if data == nil then
		return
	end

	local values = {}
	for w in data:gmatch("(.-)~") do
		table.insert(values, w)
	end

	if #values < 10 then
		if debug then
			print("Tarnished soul message too short, values:", #values)
		end
		return
	end

	local name = values[1]
	local guild = values[2]
	local source_id = tonumber(values[3])
	local race_id = tonumber(values[4])
	local class_id = tonumber(values[5])
	local level = tonumber(values[6])
	local instance_id = values[7] ~= "" and tonumber(values[7]) or nil
	local map_id = values[8] ~= "" and tonumber(values[8]) or nil
	local map_pos_str = values[9]
	local quality = tonumber(values[10]) or REPORT_QUALITY.BASIC

	local map_pos = nil
	if map_pos_str and map_pos_str ~= "" then
		local x, y = string.split(",", map_pos_str)
		if x and y then
			map_pos = { x = tonumber(x), y = tonumber(y) }
		end
	end

	if not name or name == "" then
		return
	end

	if debug then
		print("Received tarnished soul broadcast from", sender, "for", name, "quality:", quality)
	end

	local effective_level = (level and level > 0) and level or nil

	local is_self = (quality == REPORT_QUALITY.SELF)
	DeathNotificationLib_CreateTarnishedSoulEntry(name, effective_level, guild, race_id, class_id, map_id, map_pos, instance_id, is_self, true)
end

StaticPopupDialogs["CHAT_CHANNEL_PASSWORD"] = nil
local remaining_attempts = 5
local function deathlogJoinChannel()
	LeaveChannelByName(death_alerts_channel)
	-- JoinChannelByName("HardcoreDeaths")

	local delay = 3.0
	C_Timer.After(delay, function()
		JoinChannelByName(death_alerts_channel, death_alerts_channel_pw)
	end)
	local channel_num = GetChannelName(death_alerts_channel)

	SetCVar("hardcoreDeathAlertType", 2)
	for i = 1, 10 do
		if _G["ChatFrame" .. i] then
			ChatFrame_RemoveChannel(_G["ChatFrame" .. i], death_alerts_channel)
		end
	end

	local backup_channel_ticker = C_Timer.NewTicker(4, function(self)
		if remaining_attempts < 1 then
			self:Cancel()
			return
		end
		local channel_num = GetChannelName(death_alerts_channel)
		if channel_num ~= 0 then
			self:Cancel()
			return
		end
		remaining_attempts = remaining_attempts - 1
		death_alerts_channel = death_alerts_channel .. "b"
		print("Couldn't join main deathlog channel; joining backup")
		JoinChannelByName(death_alerts_channel, death_alerts_channel_pw)
	end)
end

local function sendNextInQueue()
	if #deathlog_request_duel_to_death_queue > 0 then
		local channel_num = GetChannelName(death_alerts_channel)
		if channel_num == 0 then
			deathlogJoinChannel()
			return
		end
		local commMessage = COMM_COMMANDS["REQUEST_DUEL_TO_DEATH"]
			.. COMM_COMMAND_DELIM
			.. deathlog_request_duel_to_death_queue[1]
		CTL:SendChatMessage("BULK", COMM_NAME, commMessage, "CHANNEL", nil, channel_num)
		table.remove(deathlog_request_duel_to_death_queue, 1)
		return
	end

	if #broadcast_death_ping_queue > 0 then
		local channel_num = GetChannelName(death_alerts_channel)
		if channel_num == 0 then
			deathlogJoinChannel()
			return
		end

		local commMessage = COMM_COMMANDS["BROADCAST_DEATH_PING_CHECKSUM"]
			.. COMM_COMMAND_DELIM
			.. broadcast_death_ping_queue[1]
		CTL:SendChatMessage("BULK", COMM_NAME, commMessage, "CHANNEL", nil, channel_num)
		table.remove(broadcast_death_ping_queue, 1)
		return
	end

	if #death_alert_out_queue > 0 then
		local channel_num = GetChannelName(death_alerts_channel)
		if channel_num == 0 then
			deathlogJoinChannel()
			return
		end
		local commMessage = COMM_COMMANDS["BROADCAST_DEATH_PING"] .. COMM_COMMAND_DELIM .. death_alert_out_queue[1]
		CTL:SendChatMessage("BULK", COMM_NAME, commMessage, "CHANNEL", nil, channel_num)
		table.remove(death_alert_out_queue, 1)
		return
	end

	if #tarnished_soul_out_queue > 0 then
		local channel_num = GetChannelName(death_alerts_channel)
		if channel_num == 0 then
			deathlogJoinChannel()
			return
		end
		local commMessage = COMM_COMMANDS["TARNISHED_SOUL"] .. COMM_COMMAND_DELIM .. tarnished_soul_out_queue[1]
		CTL:SendChatMessage("BULK", COMM_NAME, commMessage, "CHANNEL", nil, channel_num)
		table.remove(tarnished_soul_out_queue, 1)
		return
	end

	if #last_words_queue > 0 then
		local channel_num = GetChannelName(death_alerts_channel)
		if channel_num == 0 then
			deathlogJoinChannel()
			return
		end
		local commMessage = COMM_COMMANDS["LAST_WORDS"] .. COMM_COMMAND_DELIM .. last_words_queue[1]
		CTL:SendChatMessage("BULK", COMM_NAME, commMessage, "CHANNEL", nil, channel_num)
		table.remove(last_words_queue, 1)
		return
	end

	if #death_alert_out_queue_guild_notification > 0 then
		local channel_num = GetChannelName(death_alerts_channel)
		if channel_num == 0 then
			deathlogJoinChannel()
			return
		end
		local commMessage = COMM_COMMANDS["GUILD_DEATH_NOTIFICATION"]
			.. COMM_COMMAND_DELIM
			.. death_alert_out_queue_guild_notification[1]
			.. COMM_COMMAND_DELIM
			.. fletcher16Raw(UnitName("player") .. death_alert_out_queue_guild_notification[1])
		CTL:SendChatMessage("BULK", COMM_NAME, commMessage, "CHANNEL", nil, channel_num)
		table.remove(death_alert_out_queue_guild_notification, 1)
		return
	end
end

-- Note: We can only send at most 1 message per click, otherwise we get a taint
WorldFrame:HookScript("OnMouseDown", function(self, button)
	sendNextInQueue()
end)

-- hooksecurefunc("ChatEdit_ParseText", function(a, b, c)
-- 	print("A", tonumber(ChatEdit_GetChannelTarget(DEFAULT_CHAT_FRAME.editBox)))
-- 	if b == 1 and beautify then
-- 		local id = tonumber(ChatEdit_GetChannelTarget(DEFAULT_CHAT_FRAME.editBox))
-- 		local id, name = GetChannelName(id)
-- 		if name == death_alerts_channel then
-- 			a:SetText(beautify_prefix .. a:GetText())
-- 		end
-- 	end
-- end)

-- This binds any key press to send, including hitting enter to type or esc to exit game
local f = Test or CreateFrame("Frame", "Test", UIParent)
f:SetScript("OnKeyDown", sendNextInQueue)
f:SetPropagateKeyboardInput(true)

local death_notification_lib_event_handler = CreateFrame("Frame")
death_notification_lib_event_handler:RegisterEvent("CHAT_MSG_CHANNEL")
death_notification_lib_event_handler:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
death_notification_lib_event_handler:RegisterEvent("PLAYER_DEAD")
death_notification_lib_event_handler:RegisterEvent("CHAT_MSG_SAY")
death_notification_lib_event_handler:RegisterEvent("CHAT_MSG_GUILD")
death_notification_lib_event_handler:RegisterEvent("CHAT_MSG_PARTY")
death_notification_lib_event_handler:RegisterEvent("CHAT_MSG_ADDON") -- enable again for queries
death_notification_lib_event_handler:RegisterEvent("PLAYER_ENTERING_WORLD")
death_notification_lib_event_handler:RegisterEvent("DUEL_TO_THE_DEATH_REQUESTED")
death_notification_lib_event_handler:RegisterEvent("HARDCORE_DEATHS")
if Deathlog_isSoulOfIronRealm then
	death_notification_lib_event_handler:RegisterEvent("CHAT_MSG_SYSTEM")
	death_notification_lib_event_handler:RegisterEvent("UNIT_AURA")
	death_notification_lib_event_handler:RegisterEvent("CHAT_MSG_MONSTER_EMOTE")
end

local function onBlizzardChat(msg)
	_G["RaidWarningFrameSlot1"]:SetText("")
	_G["RaidWarningFrameSlot2"]:SetText("")
	if deathlog_settings and deathlog_settings["addonless_logging"] == true then
		C_Timer.After(10.0, function()
			if debug then
				if not dev_hardcore_deaths_strings then
					dev_hardcore_deaths_strings = {}
				end

				table.insert(dev_hardcore_deaths_strings, msg)
			end

			-- Skip if locale doesn't have death broadcast parsing function defined
			if not Deathlog_L.parse_hc_death_broadcast then
				return
			end

			local death_name, source, area_name, parsed_lvl = Deathlog_L.parse_hc_death_broadcast(msg)
			if not death_name or not source or not area_name or not parsed_lvl then
				return
			end

			local area_id = area_to_id[area_name] or 0
			local instance_id = id_to_instance[area_id] and area_id or nil
			local map_id = not instance_id and area_id or nil

			local date = time()
			local _player_data =
				PlayerData(death_name, nil, source, nil, nil, parsed_lvl, instance_id, map_id, nil, date, nil)
			if bliz_alert_cache[_player_data["name"]] == nil then
				createEntryDirect(_player_data)
			end
		end)
	end
end

local function handleEvent(self, event, ...)
	local arg = { ... }
	if event == "CHAT_MSG_CHANNEL" then
		local _, channel_name = string.split(" ", arg[4])
		if channel_name ~= death_alerts_channel then
			return
		end
		local command, msg, _doublechecksum = string.split(COMM_COMMAND_DELIM, arg[1])

		if Deathlog_isSoulOfIronRealm then
			local values = {}
			for w in msg:gmatch("(.-)~") do
				table.insert(values, w)
			end
			local protocol_version = values[#values]

			local parsed_version = tonumber(protocol_version) or 0
			if parsed_version < SOI_MIN_PROTOCOL_VERSION then
				return
			end
		end

		if command == COMM_COMMANDS["BROADCAST_DEATH_PING_CHECKSUM"] then
			local player_name_short, _ = string.split("-", arg[2])
			if shadowbanned[player_name_short] then
				return
			end

			if throttle_player[player_name_short] == nil then
				throttle_player[player_name_short] = 0
			end
			throttle_player[player_name_short] = throttle_player[player_name_short] + 1
			if throttle_player[player_name_short] > 1000 then
				shadowbanned[player_name_short] = 1
			end

			deathlogReceiveChannelMessageChecksum(player_name_short, msg)
			if debug then
				print("checksum", msg)
			end
			return
		end

		if command == COMM_COMMANDS["BROADCAST_DEATH_PING"] then
			local player_name_short, _ = string.split("-", arg[2])
			if shadowbanned[player_name_short] then
				return
			end

			if throttle_player[player_name_short] == nil then
				throttle_player[player_name_short] = 0
			end
			throttle_player[player_name_short] = throttle_player[player_name_short] + 1
			if throttle_player[player_name_short] > 1000 then
				shadowbanned[player_name_short] = 1
			end

			deathlogReceiveChannelMessage(player_name_short, msg)
			if debug then
				print("death ping", msg)
			end
			return
		end

		if command == COMM_COMMANDS["TARNISHED_SOUL"] then
			local player_name_short, _ = string.split("-", arg[2])
			if shadowbanned[player_name_short] then
				return
			end

			if throttle_player[player_name_short] == nil then
				throttle_player[player_name_short] = 0
			end
			throttle_player[player_name_short] = throttle_player[player_name_short] + 1
			if throttle_player[player_name_short] > 1000 then
				shadowbanned[player_name_short] = 1
			end

			deathlogReceiveTarnishedSoul(player_name_short, msg)
			if debug then
				print("tarnished soul", msg)
			end
			return
		end

		if command == COMM_COMMANDS["LAST_WORDS"] then
			local player_name_short, _ = string.split("-", arg[2])
			if shadowbanned[player_name_short] then
				return
			end

			if throttle_player[player_name_short] == nil then
				throttle_player[player_name_short] = 0
			end
			throttle_player[player_name_short] = throttle_player[player_name_short] + 1
			if throttle_player[player_name_short] > 1000 then
				shadowbanned[player_name_short] = 1
			end

			deathlogReceiveLastWords(player_name_short, msg)
			if debug then
				print("last words", msg)
			end
			return
		end

		if command == COMM_COMMANDS["GUILD_DEATH_NOTIFICATION"] and enable_guild_death_notifications then -- Note: disabled until further debugging
			local player_name_short, _ = string.split("-", arg[2])
			if shadowbanned[player_name_short] then
				return
			end

			if throttle_player[player_name_short] == nil then
				throttle_player[player_name_short] = 0
			end
			throttle_player[player_name_short] = throttle_player[player_name_short] + 1
			if throttle_player[player_name_short] > 1000 then
				shadowbanned[player_name_short] = 1
			end

			deathlogReceiveGuildDeathNotification(player_name_short, msg, _doublechecksum)
			if debug then
				print("death ping", msg)
			end
			return
		end

		if command == COMM_COMMANDS["REQUEST_DUEL_TO_DEATH"] then
			local player_name_short, _ = string.split("-", arg[2])
			if shadowbanned[player_name_short] then
				return
			end

			if throttle_player[player_name_short] == nil then
				throttle_player[player_name_short] = 0
			end
			throttle_player[player_name_short] = throttle_player[player_name_short] + 1
			if throttle_player[player_name_short] > 1000 then
				shadowbanned[player_name_short] = 1
			end

			local checksum, players = string.split(COMM_FIELD_DELIM, msg)
			local player_one, player_two = string.split("_", players)
			if player_one == UnitName("player") then
				deathlog_last_duel_to_death_player = player_two
			elseif player_two == UnitName("player") then
				deathlog_last_duel_to_death_player = player_one
			end
			return
		end
	elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
		-- local time, token, hidding, source_serial, source_name, caster_flags, caster_flags2, target_serial, target_name, target_flags, target_flags2, ability_id, ability_name, ability_type, extraSpellID, extraSpellName, extraSchool = CombatLogGetCurrentEventInfo()
		local _, ev, _, _, source_name, _, _, target_guid, _, _, _, environmental_type, _, _, _, _, _ =
			CombatLogGetCurrentEventInfo()

		if not (source_name == UnitName("player")) then
			if not (source_name == nil) then
				if string.find(ev, "DAMAGE") ~= nil then
					last_attack_source = source_name

					if source_name == UnitName("target") and UnitIsPlayer("target") then
						deathlog_refresh_last_attack_info(source_name)
					end
				end
			end
		end
		if ev == "ENVIRONMENTAL_DAMAGE" then
			if target_guid == UnitGUID("player") then
				if environmental_type == "Drowning" then
					last_attack_source = -2
				elseif environmental_type == "Falling" then
					last_attack_source = -3
				elseif environmental_type == "Fatigue" then
					last_attack_source = -4
				elseif environmental_type == "Fire" then
					last_attack_source = -5
				elseif environmental_type == "Lava" then
					last_attack_source = -6
				elseif environmental_type == "Slime" then
					last_attack_source = -7
				end
			end
		end
	elseif event == "PLAYER_DEAD" then
		if Deathlog_getHardcoreCharacterState() == Deathlog_HC_STATE_HARDCORE then
			selfDeathAlert(last_attack_source)
			selfDeathAlertLastWords(recent_msg)
		end
	elseif event == "UNIT_AURA" then
		if arg[1] == "player" then
			Deathlog_updateSoulOfIronTracking()
		end
	elseif event == "CHAT_MSG_SAY" or event == "CHAT_MSG_GUILD" or event == "CHAT_MSG_PARTY" then
		local text, sn, LN, CN, p2, sF, zcI, cI, cB, unu, lI, senderGUID = ...
		local automated_text_found = string.find(text, "Our brave")
		local questie_text_found = string.find(text, "Questie")
		if senderGUID == UnitGUID("player") and automated_text_found == nil and questie_text_found == nil then
			recent_msg = text
		end
	elseif event == "CHAT_MSG_GUILD_DEATHS" then
		if debug then
			if not dev_hardcore_deaths_guid_strings then
				dev_hardcore_deaths_guid_strings = {}
			end

			table.insert(dev_hardcore_deaths_guid_strings, arg[1])
		end

		local _text = arg[1]
		local _, _b = string.split("[", _text)
		local _name, _ = string.split("]", _b)
		local _, _npc = string.split(":", _text)
		local _npc, _ = string.split(".", _npc)
		local _, _npc = strsplit(" ", _npc, 2)

		for i = 1, GetNumGuildMembers() do
			local name, _, _, level, class_str, zone, _, _, _, _, class_id = GetGuildRosterInfo(i)
			local player_name_short, _ = string.split("-", name)
			if player_name_short == _name then
				signalGuildDeath(_name, class_str, level, zone, nil, _npc)
			end
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		Deathlog_updateSoulOfIronTracking()
		C_Timer.After(5.0, function()
			deathlogJoinChannel()
		end)
	elseif event == "HARDCORE_DEATHS" then
		onBlizzardChat(arg[1])
	elseif event == "DUEL_TO_THE_DEATH_REQUESTED" then
		deathlog_last_duel_to_death_player = arg[1]

		local guildName, guildRankName, guildRankIndex = GetGuildInfo("player")
		if guildName == nil then
			guildName = ""
		end
		local player_data =
			PlayerData(UnitName("player"), guildName, nil, nil, nil, UnitLevel("player"), nil, nil, nil, nil, nil)
		local checksum = fletcher16(player_data)
		local msg = checksum
			.. COMM_FIELD_DELIM
			.. (UnitName("player") .. "_" .. deathlog_last_duel_to_death_player)
			.. COMM_FIELD_DELIM
			.. PROTOCOL_VERSION
			.. COMM_FIELD_DELIM
		table.insert(deathlog_request_duel_to_death_queue, msg)
	elseif event == "CHAT_MSG_ADDON" then
		local command, msg, _doublechecksum = string.split(COMM_COMMAND_DELIM, arg[2])
		if command == COMM_QUERY then
			local realm = GetRealmName()
			if comm_query_lock then
				return
			end
			comm_query_lock = C_Timer.NewTimer(3, function()
				comm_query_lock:Cancel()
				comm_query_lock = nil
			end)
			if expect_ack[msg] == nil then
				return
			end
			if attached_db_map and attached_db_map[msg] and attached_db[attached_db_map[msg]] then
				local data = attached_db[attached_db_map[msg]]
				local msg = encodeMessageFull(
					data.name,
					data.guild,
					data.source_id,
					data.race_id,
					data.class_id,
					data.level,
					data.instance_id,
					data.map_id,
					data.map_pos,
					data.last_words,
					data.date
				)
				local commMessage = COMM_QUERY_ACK .. COMM_COMMAND_DELIM .. msg
				CTL:SendAddonMessage("BULK", COMM_NAME, commMessage, "WHISPER", arg[4])
			end
		elseif command == COMM_QUERY_ACK then
			local _player_data = decodeMessage(msg)
			if isValidEntry(_player_data) then
				createEntryDirect(_player_data)
			end
		end
	elseif event == "CHAT_MSG_SYSTEM" then
		local message = arg[1] or ""
		local found_name = message:match("|Hplayer:([^|]+)|h")
		if found_name then
			local name_key = found_name:lower()
			local callback = deathlog_who_callbacks[name_key]
			
			if callback then
				local numResults = C_FriendList.GetNumWhoResults()
				local who_info = nil
				
				for i = 1, numResults do
					local info = C_FriendList.GetWhoInfo(i)
					if info and info.fullName and info.fullName:lower() == name_key then
						who_info = info
						break
					end
				end
				
				callback(who_info)
				deathlog_who_callbacks[name_key] = nil

				if next(deathlog_who_callbacks) == nil and FriendsFrame then
					FriendsFrame:RegisterEvent("WHO_LIST_UPDATE")
				end
			end
		end
	elseif event == "CHAT_MSG_MONSTER_EMOTE" then
		if debug then
			if not dev_tarnished_shoul_strings then
				dev_tarnished_shoul_strings = {}
			end

			table.insert(dev_tarnished_shoul_strings, arg[1])
		end

		local message = arg[1]
		local player_name = arg[2]
		local player_guid = arg[12]
		
		-- Skip if locale doesn't have tarnished soul parsing function defined
		if not Deathlog_L.parse_tarnished_soul_emote then
			return
		end
		
		if message and Deathlog_L.parse_tarnished_soul_emote(message) then
			if bliz_alert_cache[player_name] then
				return
			end
			
			if debug then
				print("Soul of Iron death detected via emote:", player_name, "GUID:", player_guid)
			end
			
			if player_name == UnitName("player") then
				return
			end
			
			bliz_alert_cache[player_name] = 1
			
			local _, englishClass, _, englishRace, _, _, _ = GetPlayerInfoByGUID(player_guid)
			
			local class_id = nil
			if englishClass then
				local class_map = {
					["WARRIOR"] = 1, ["PALADIN"] = 2, ["HUNTER"] = 3, ["ROGUE"] = 4,
					["PRIEST"] = 5, ["DEATHKNIGHT"] = 6, ["SHAMAN"] = 7, ["MAGE"] = 8,
					["WARLOCK"] = 9, ["MONK"] = 10, ["DRUID"] = 11
				}
				class_id = class_map[englishClass]
			end
			
			local race_id = nil
			if englishRace then
				local race_map = {
					["Human"] = 1, ["Orc"] = 2, ["Dwarf"] = 3, ["NightElf"] = 4,
					["Undead"] = 5, ["Tauren"] = 6, ["Gnome"] = 7, ["Troll"] = 8,
					["Goblin"] = 9, ["BloodElf"] = 10, ["Draenei"] = 11
				}
				race_id = race_map[englishRace]
			end
			
			local map_id = nil
			local map_pos = nil
			local instance_id = nil
			local map = C_Map.GetBestMapForUnit("player")
			if map then
				local position = C_Map.GetPlayerMapPosition(map, "player")
				map_id = map
				if position then
					map_pos = string.format("%.4f,%.4f", position.x, position.y)
				end
			else
				local _, _, _, _, _, _, _, _instance_id, _, _ = GetInstanceInfo()
				instance_id = _instance_id
			end
			
			local found_unit = nil
			local level = nil
			local guild = nil
			
			if player_name == UnitName("target") then
				found_unit = "target"
			end
			
			if not found_unit then
				for i = 1, 4 do
					if player_name == UnitName("party" .. i) then
						found_unit = "party" .. i
						break
					end
				end
			end
			
			if not found_unit and IsInRaid() then
				for i = 1, 40 do
					if player_name == UnitName("raid" .. i) then
						found_unit = "raid" .. i
						break
					end
				end
			end
			
			if not found_unit then
				for i = 1, 40 do
					local nameplate_unit = "nameplate" .. i
					if UnitExists(nameplate_unit) and player_name == UnitName(nameplate_unit) then
						found_unit = nameplate_unit
						break
					end
				end
			end
			
			if found_unit then
				local unit_level = UnitLevel(found_unit)
				level = (unit_level and unit_level > 0) and unit_level or nil
				guild = GetGuildInfo(found_unit)
			end
			
			local function createTarnishedSoulEntry(_level, _guild, _race_id, _class_id)
				DeathNotificationLib_CreateTarnishedSoulEntry(player_name, _level, _guild, _race_id, _class_id, map_id, map_pos, instance_id)
			end
			
			if level then
				createTarnishedSoulEntry(level, guild, race_id, class_id)
			else
				if Deathlog_ReportWidget_QueuePlayer then
					local queued = Deathlog_ReportWidget_QueuePlayer(player_name, player_guid, race_id, class_id, guild, map_id, map_pos, instance_id)
					if not queued then
						createTarnishedSoulEntry(nil, guild, race_id, class_id)
					end
				else
					createTarnishedSoulEntry(nil, guild, race_id, class_id)
				end
			end
		end
	end
end

death_notification_lib_event_handler:SetScript("OnEvent", handleEvent)
C_ChatInfo.RegisterAddonMessagePrefix(COMM_NAME)
