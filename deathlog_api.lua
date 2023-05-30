--[[
Copyright 2023 Yazpad
The Deathlog AddOn is distributed under the terms of the GNU General Public License (or the Lesser GPL).
This file is part of Hardcore.

The Deathlog AddOn is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

The Deathlog AddOn is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with the Deathlog AddOn. If not, see <http://www.gnu.org/licenses/>.
--]]
--
local debug = false
local CTL = _G.ChatThrottleLib
local COMM_NAME = "HCDeathAlerts"
local COMM_COMMANDS = {
	["BROADCAST_DEATH_PING"] = "1",
	["BROADCAST_DEATH_PING_CHECKSUM"] = "2",
	["LAST_WORDS"] = "3",
}
local COMM_COMMAND_DELIM = "$"
local COMM_FIELD_DELIM = "~"
local HC_REQUIRED_ACKS = 3
local HC_DEATH_LOG_MAX = 100000

local death_alerts_channel = "hcdeathalertschannel"
local death_alerts_channel_pw = "hcdeathalertschannelpw"

local throttle_player = {}
local shadowbanned = {}

local environment_damage = {
	[-2] = "Drowning",
	[-3] = "Falling",
	[-4] = "Fatigue",
	[-5] = "Fire",
	[-6] = "Lava",
	[-7] = "Slime",
}

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
	last_words
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
	}
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

local function encodeMessage(name, guild, source_id, race_id, class_id, level, instance_id, map_id, map_pos)
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
		loc_str = string.format("%.4f,%.4f", map_pos.x, map_pos.y)
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
	return comm_message
end

local function decodeMessage(msg)
	local values = {}
	for w in msg:gmatch("(.-)~") do
		table.insert(values, w)
	end
	local date = nil
	local last_words = nil
	local name = values[1]
	local guild = values[2]
	local source_id = tonumber(values[3])
	local race_id = tonumber(values[4])
	local class_id = tonumber(values[5])
	local level = tonumber(values[6])
	local instance_id = tonumber(values[7])
	local map_id = tonumber(values[8])
	local map_pos = values[9]
	local player_data =
		PlayerData(name, guild, source_id, race_id, class_id, level, instance_id, map_id, map_pos, date, last_words)
	return player_data
end

-- [checksum -> {name, guild, source, race, class, level, F's, location, last_words, location}]
local death_ping_lru_cache_tbl = {}
local death_ping_lru_cache_ll = {}
local broadcast_death_ping_queue = {}
local death_alert_out_queue = {}
local last_words_queue = {}

local function deathlog_modified_fletcher16(_player_data)
	return deathlog_fletcher16(
		_player_data["name"],
		_player_data["guild"],
		_player_data["level"],
		_player_data["source_id"]
	)
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

local death_log_cache = {}

local function createEntry(checksum)
	death_ping_lru_cache_tbl[checksum]["player_data"]["date"] = time()
	death_ping_lru_cache_tbl[checksum]["committed"] = 1
	local realmName = GetRealmName()

	if deathlog_data == nil then
		deathlog_data = {}
	end
	if deathlog_data[realmName] == nil then
		deathlog_data[realmName] = {}
	end
	local modified_checksum = deathlog_modified_fletcher16(death_ping_lru_cache_tbl[checksum]["player_data"])
	deathlog_data[realmName][modified_checksum] = death_ping_lru_cache_tbl[checksum]["player_data"]
	deathlog_widget_minilog_createEntry(death_ping_lru_cache_tbl[checksum]["player_data"])

	Deathlog_DeathAlertPlay(death_ping_lru_cache_tbl[checksum]["player_data"])
end

local function recentEntryCreated(entry_name)
	if deathlog_data then
		local realmName = GetRealmName()
		if deathlog_data[realmName] then
			for _, v in pairs(deathlog[realmName]) do
				if v["name"] == entry_name then
					if abs(v["date"] - time()) < 60 * 60 * 24 then
						return true
					end
				end
			end
		end
	end
	return false
end

local function shouldCreateEntry(checksum)
	if death_ping_lru_cache_tbl[checksum] == nil then
		return false
	end
	if death_ping_lru_cache_tbl[checksum]["player_data"] == nil then
		return false
	end
	if
		deathlog_settings.death_log_types == nil
		or deathlog_settings.death_log_types == "faction_wide"
			and isValidEntry(death_ping_lru_cache_tbl[checksum]["player_data"])
			and recentEntryCreated(death_ping_lru_cache_tbl[checksum]["player_data"]["name"]) == false
	then
		if
			death_ping_lru_cache_tbl[checksum]["peer_report"]
			and death_ping_lru_cache_tbl[checksum]["peer_report"] > HC_REQUIRED_ACKS
		then
			return true
		else
			if debug then
				print(
					"not enough peers for "
						.. checksum
						.. ": "
						.. (death_ping_lru_cache_tbl[checksum]["peer_report"] or "0")
				)
			end
		end
	end
	if death_ping_lru_cache_tbl[checksum]["in_guild"] then
		return true
	end
	return false
end

function DEATHLOG_selfDeathAlertLastWords(last_words)
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

	table.insert(last_words_queue, msg)
end

function DEATHLOG_selfDeathAlert(death_source_str)
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
	if DeathLog_Last_Attack_Source then
		death_source = npc_to_id[death_source_str]
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
		position
	)
	if msg == nil then
		return
	end
	local channel_num = GetChannelName(death_alerts_channel)

	table.insert(death_alert_out_queue, msg)
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
	table.insert(broadcast_death_ping_queue, checksum) -- Must be added to queue to be broadcasted to network
	if shouldCreateEntry(checksum) then
		createEntry(checksum)
	end
end

local function deathlogReceiveChannelMessageChecksum(sender, checksum)
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
	if shouldCreateEntry(checksum) then
		createEntry(checksum)
	end
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
					table.insert(broadcast_death_ping_queue, checksum) -- Must be added to queue to be broadcasted to network
				end)
				break
			end
		end
	end

	death_ping_lru_cache_tbl[checksum]["self_report"] = 1
	if shouldCreateEntry(checksum) then
		createEntry(checksum)
	end
end

function DEATHLOG_deathlogJoinChannel()
	JoinChannelByName(death_alerts_channel, death_alerts_channel_pw)
	local channel_num = GetChannelName(death_alerts_channel)
	if channel_num == 0 then
		print("Failed to join death alerts channel")
	else
		print("Successfully joined deathlog channel.")
	end

	for i = 1, 10 do
		if _G["ChatFrame" .. i] then
			ChatFrame_RemoveChannel(_G["ChatFrame" .. i], death_alerts_channel)
		end
	end
end

local function sendNextInQueue()
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
end

-- Note: We can only send at most 1 message per click, otherwise we get a taint
WorldFrame:HookScript("OnMouseDown", function(self, button)
	sendNextInQueue()
end)

-- This binds any key press to send, including hitting enter to type or esc to exit game
local f = Test or CreateFrame("Frame", "Test", UIParent)
f:SetScript("OnKeyDown", sendNextInQueue)
f:SetPropagateKeyboardInput(true)

local death_log_handler = CreateFrame("Frame")
death_log_handler:RegisterEvent("CHAT_MSG_CHANNEL")

local function handleEvent(self, event, ...)
	local arg = { ... }
	if event == "CHAT_MSG_CHANNEL" then
		local _, channel_name = string.split(" ", arg[4])
		if channel_name ~= death_alerts_channel then
			return
		end
		local command, msg = string.split(COMM_COMMAND_DELIM, arg[1])
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
	end
end

death_log_handler:SetScript("OnEvent", handleEvent)
