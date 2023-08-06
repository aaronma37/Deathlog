--[[
Copyright 2023 Yazpad
The GlobalDeathChatNotifications AddOn is distributed under the terms of the GNU General Public License (or the Lesser GPL).
This file is part of GlobalDeathChatNotifications.

The GlobalDeathChatNotifications AddOn is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

The GlobalDeathChatNotifications AddOn is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with the GlobalDeathChatNotifications AddOn. If not, see <http://www.gnu.org/licenses/>.
--]]

global_death_chat_notifications_settings = {}

local _instance_tbl = {
	["Shadowfang Keep"] = 33,
	["Stormwind Stockade"] = 34,
	["Deadmines"] = 36,
	["Wailing Caverns"] = 43,
	["Razorfen Kraul"] = 47,
	["Blackfathom Deeps"] = 48,
	["Uldaman"] = 70,
	["Gnomeregan"] = 90,
	["Sunken Temple"] = 109,
	["Razorfen Downs"] = 129,
	["Scarlet Monastery"] = 189,
	["Zul'Farrak"] = 209,
	["Blackrock Spire"] = 229,
	["Blackrock Depths"] = 230,
	["Scholomance"] = 289,
	["Stratholme"] = 329,
	["Maraudon"] = 349,
	["Dire Maul"] = 429,
}

_id_to_instance_tbl = {}
for k, v in pairs(_instance_tbl) do
	_id_to_instance_tbl[v] = k
end

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

local _class_colors = {}
for k, _ in pairs(_class_tbl) do
	_class_colors[k] = RAID_CLASS_COLORS[string.upper(k)]
end
_class_colors["Shaman"]:SetRGBA(36 / 255, 89 / 255, 255 / 255, 1)

local function notify(_player_data, _checksum, num_peer_checks, in_guild, force)
	local should_show = false

	if global_death_chat_notifications_settings["show_all_deaths"] then
		should_show = true
	end

	if global_death_chat_notifications_settings["show_guild_deaths"] and in_guild ~= nil and in_guild == true then
		should_show = true
	end
	if global_death_chat_notifications_settings["show_zone_deaths"] then
		local map = C_Map.GetBestMapForUnit("player")
		if tonumber(map) == tonumber(_player_data["map_id"]) then
			should_show = true
		end
	end

	if should_show == false then
		return
	end

	local msg = global_death_chat_notifications_settings["message_template"]
	if _player_data["source_id"] and _player_data["source_id"] < 1 then
		if tonumber(_player_data["source_id"]) == -2 then
			local msg = global_death_chat_notifications_settings["drowned_template"]
		elseif tonumber(_player_data["source_id"]) == -3 then
			local msg = global_death_chat_notifications_settings["fallen_template"]
		end
	else
	end
	local race = ""
	if _player_data["race_id"] then
		race = C_CreatureInfo.GetRaceInfo(_player_data["race_id"])
		if race then
			race = race.raceName
		else
			race = ""
		end
	end

	local class = GetClassInfo(_player_data["class_id"]) or ""
	if _class_colors[class] then
		class = "|c" .. _class_colors[class]:GenerateHexColor() .. class .. "|r"
	end

	local source_name = ""
	if _player_data["source_id"] then
		if id_to_npc[_player_data["source_id"]] then
			source_name = id_to_npc[_player_data["source_id"]]
		end
	end

	local zone = ""
	if _player_data["map_id"] then
		local map_info = C_Map.GetMapInfo(_player_data["map_id"])
		if map_info then
			zone = map_info.name
		end
	elseif _player_data["instance_id"] then
		zone = _id_to_instance_tbl[_player_data["instance_id"]] or ""
	end

	local hex = ("%02X"):format(tonumber(global_death_chat_notifications_settings["accent_color"]["r"] * 255))
		.. ("%02X"):format(tonumber(global_death_chat_notifications_settings["accent_color"]["g"] * 255))
		.. ("%02X"):format(tonumber(global_death_chat_notifications_settings["accent_color"]["b"] * 255))
	msg = "|cFF" .. hex .. msg
	msg = msg:gsub("%<name>", _player_data["name"])
	msg = msg:gsub("%<class>", class)
	msg = msg:gsub("%<race>", race)
	msg = msg:gsub("%<source>", source_name)
	msg = msg:gsub("%<level>", _player_data["level"])
	msg = msg:gsub("%<zone>", zone)

	if _player_data["last_words"] ~= nil then
		local last_words_msg

		local hex = ("%02X"):format(tonumber(global_death_chat_notifications_settings["last_words_color"]["r"] * 255))
			.. ("%02X"):format(tonumber(global_death_chat_notifications_settings["last_words_color"]["g"] * 255))
			.. ("%02X"):format(tonumber(global_death_chat_notifications_settings["last_words_color"]["b"] * 255))
		last_words_msg = global_death_chat_notifications_settings["last_words_template"]
		-- last_words_msg =
		-- 	last_words_msg:gsub("%<last_words>", "|cFF" .. hex .. '"' .. _player_data["last_words"] .. '"|r')
		last_words_msg = last_words_msg:gsub("%<last_words>", "|cFF" .. hex .. '"' .. "AA" .. '"|r')
		msg = msg .. last_words_msg
	end
	msg = msg .. "|r"
	print(msg)
end

local defaults = {
	["show_guild_deaths"] = true,
	["show_zone_deaths"] = true,
	["show_all_deaths"] = true,
	["accent_color"] = { ["r"] = 1, ["g"] = 0.2, ["b"] = 0.2, ["a"] = 1 },
	["last_words_color"] = { ["r"] = 0.8, ["g"] = 0.8, ["b"] = 0.8, ["a"] = 1 },
	["message_template"] = "|TInterface\\WorldStateFrame\\SkullBones:18:18:0:0:64:64:0:32:0:32|t<name> the lvl <level> <race> <class> has been slain by <source> in <zone>.",
	["fallen_template"] = "|TInterface\\WorldStateFrame\\SkullBones:18:18:0:0:64:64:0:32:0:32|t<name> the lvl <level> <race> <class> drowned in <zone>.",
	["drowned_template"] = "|TInterface\\WorldStateFrame\\SkullBones:18:18:0:0:64:64:0:32:0:32|t<name> the lvl <level> <race> <class> fell to their death in <zone>.",
	["last_words_template"] = "Their last words were <last_words>.",
}

local function applyDefaults(_defaults, force)
	if global_death_chat_notifications_settings == nil then
		global_death_chat_notifications_settings = {}
	end
	for k, v in pairs(_defaults) do
		if global_death_chat_notifications_settings[k] == nil or force then
			global_death_chat_notifications_settings[k] = v
		end
	end
end

local function handleEvent(self, event, ...)
	if event == "PLAYER_ENTERING_WORLD" then
		applyDefaults(defaults, false)
	end
end

local event_handler = CreateFrame("Frame", "GlobalDeathChatNotifications", nil, "BackdropTemplate")
event_handler:RegisterEvent("PLAYER_ENTERING_WORLD")
event_handler:SetScript("OnEvent", handleEvent)

local options = {
	name = "Global Death Chat Notifications",
	handler = Hardcore,
	type = "group",
	args = {
		cross_guild_header = {
			type = "group",
			name = "Filter",
			inline = true,
			args = {
				show_guild_deaths_toggle = {
					type = "toggle",
					name = "Show Guild Deaths",
					desc = "Select to show guild deaths in chat.",
					width = 1.3,
					get = function()
						return global_death_chat_notifications_settings["show_guild_deaths"]
					end,
					set = function()
						global_death_chat_notifications_settings["show_guild_deaths"] =
							not global_death_chat_notifications_settings["show_guild_deaths"]
					end,
				},
				show_in_zone_deaths_toggle = {
					type = "toggle",
					name = "Show Zone Deaths",
					desc = "Select to show deaths that happened in your current zone in chat.",
					width = 1.3,
					get = function()
						return global_death_chat_notifications_settings["show_zone_deaths"]
					end,
					set = function()
						global_death_chat_notifications_settings["show_zone_deaths"] =
							not global_death_chat_notifications_settings["show_zone_deaths"]
					end,
				},
				show_all_deaths_toggle = {
					type = "toggle",
					name = "Show All Deaths",
					desc = "Select to show all deaths in chat.  This will force other toggles (guild/zone) to be selected as well.",
					width = 1.3,
					get = function()
						if global_death_chat_notifications_settings["show_all_deaths"] == true then
							global_death_chat_notifications_settings["show_zone_deaths"] = true
							global_death_chat_notifications_settings["show_guild_deaths"] = true
						end
						return global_death_chat_notifications_settings["show_all_deaths"]
					end,
					set = function()
						global_death_chat_notifications_settings["show_all_deaths"] =
							not global_death_chat_notifications_settings["show_all_deaths"]

						if global_death_chat_notifications_settings["show_all_deaths"] then
							global_death_chat_notifications_settings["show_zone_deaths"] = true
							global_death_chat_notifications_settings["show_guild_deaths"] = true
						end
					end,
				},
			},
		},
		chat_alert_color = {
			type = "color",
			name = "Chat Notification Text Color",
			desc = "Text color that is used for death chat notifications.",
			get = function()
				return global_death_chat_notifications_settings["accent_color"]["r"],
					global_death_chat_notifications_settings["accent_color"]["g"],
					global_death_chat_notifications_settings["accent_color"]["b"],
					global_death_chat_notifications_settings["accent_color"]["a"]
			end,
			set = function(self, r, g, b, a)
				global_death_chat_notifications_settings["accent_color"]["r"] = r
				global_death_chat_notifications_settings["accent_color"]["g"] = g
				global_death_chat_notifications_settings["accent_color"]["b"] = b
				global_death_chat_notifications_settings["accent_color"]["a"] = a
			end,
		},
		last_words_color = {
			type = "color",
			name = "Last Words Chat Color",
			desc = "Text color that is used for last words",
			get = function()
				return global_death_chat_notifications_settings["last_words_color"]["r"],
					global_death_chat_notifications_settings["last_words_color"]["g"],
					global_death_chat_notifications_settings["last_words_color"]["b"],
					global_death_chat_notifications_settings["last_words_color"]["a"]
			end,
			set = function(self, r, g, b, a)
				global_death_chat_notifications_settings["last_words_color"]["r"] = r
				global_death_chat_notifications_settings["last_words_color"]["g"] = g
				global_death_chat_notifications_settings["last_words_color"]["b"] = b
				global_death_chat_notifications_settings["last_words_color"]["a"] = a
			end,
		},
		custom_chat_header = {
			type = "group",
			name = "Set Custom Text",
			inline = true,
			args = {
				msg_input = {
					type = "input",
					name = "Customize Chat Notification Message",
					desc = "Customize the death alert message. \nSubstitutions:<name> = Character name\n<race> = Character race\n<class> = Character class\n<level> = Character level\n<source> = Killer name\n<zone> = Character zones",
					width = 2.5,
					multiline = true,
					get = function()
						return global_death_chat_notifications_settings["message_template"]
					end,
					set = function(self, msg)
						global_death_chat_notifications_settings["message_template"] = msg
					end,
				},
				msg_input3 = {
					type = "input",
					name = "Customize drowned to death message",
					desc = "Customize drowned to death message.\nSubstitutions:<name> = Character name\n<race> = Character race\n<class> = Character class\n<level> = Character level\n<source> = Killer name\n<zone> = Character zones",
					width = 2.5,
					multiline = true,
					get = function()
						return global_death_chat_notifications_settings["drowned_template"]
					end,
					set = function(self, msg)
						global_death_chat_notifications_settings["drowned_template"] = msg
					end,
				},
				msg_input4 = {
					type = "input",
					name = "Customize fell to death message",
					desc = "Customize fell to death message.\nSubstitutions:<name> = Character name\n<race> = Character race\n<class> = Character class\n<level> = Character level\n<source> = Killer name\n<zone> = Character zones",
					width = 2.5,
					multiline = true,
					get = function()
						return global_death_chat_notifications_settings["fallen_template"]
					end,
					set = function(self, msg)
						global_death_chat_notifications_settings["fallen_template"] = msg
					end,
				},
				msg_input2 = {
					type = "input",
					name = "Customize Last Words Message",
					desc = "Customize last words message.\n<last_words> = Character's last words",
					width = 2.5,
					multiline = true,
					get = function()
						return global_death_chat_notifications_settings["last_words_template"]
					end,
					set = function(self, msg)
						global_death_chat_notifications_settings["last_words_template"] = msg
					end,
				},
			},
		},
		reset_to_default = {
			type = "execute",
			name = "Set to Default",
			desc = "Reset settings back to default.",
			func = function()
				applyDefaults(defaults, true)
			end,
		},
		test_exe = {
			type = "execute",
			name = "Sample Notification",
			desc = "Press to trigger a sample notification",
			func = function()
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
				-- @param _checksum A checksum for the player data
				-- @param _peer_report Number of guildmates that verified the death
				-- @param _in_guild Whether the player is in your guild
				local player_data = {
					["name"] = UnitName("player"),
					["guild"] = "GuildName",
					["source_id"] = 123,
					["class_id"] = 1,
					["race_id"] = 1,
					["level"] = UnitLevel("player"),
					["instance_id"] = nil,
					["map_id"] = 1426,
					["map_pos"] = nil,
					["date"] = time(),
					["last_words"] = "Last words sample text.",
				}
				local checksum = nil
				local peer_report = nil
				local in_guild = true
				notify(player_data, checksum, peer_report, in_guild, true)
			end,
		},
	},
}

LibStub("AceConfig-3.0"):RegisterOptionsTable("Global Death Chat Notifications", options)
optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(
	"Global Death Chat Notifications",
	"Global Death Chat Notifications",
	nil
)

-- Hook to DeathNotificationLib
DeathNotificationLib_HookOnNewEntry(function(_player_data, _checksum, num_peer_checks, in_guild)
	notify(_player_data, _checksum, num_peer_checks, in_guild, false)
end)
