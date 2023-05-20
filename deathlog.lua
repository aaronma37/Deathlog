--[[
Copyright 2023 Yazpad
The Deathlog AddOn is distributed under the terms of the GNU General Public License (or the Lesser GPL).
This file is part of Deathlog.

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

local save_precompute = false
local use_precomputed = true
local last_attack_source = nil
local recent_msg = nil
local general_stats = {}
local log_normal_params = {}
local skull_locs = {}
local most_deadly_units = {
	["all"] = { -- server
		["all"] = { -- map_id
			["all"] = {}, -- class_id
		},
	},
}
Deathlog_azeroth_deadliest_dict = {} -- source_name -> ranking

local LibDeflate
if LibStub then -- You are using LibDeflate as WoW addon
	LibDeflate = LibStub:GetLibrary("LibDeflate")
end

deathlog_data = {}
deathlog_settings = {}

local deathlog_minimap_button_stub = nil
local deathlog_minimap_button_info = {}
local deathlog_minimap_button = LibStub("LibDataBroker-1.1"):NewDataObject("Deathlog", {
	type = "data source",
	text = "Deathlog",
	icon = "Interface\\TARGETINGFRAME\\UI-TargetingFrame-Skull",
	OnClick = function(self, btn)
		deathlogShowMenu(deathlog_data, general_stats, log_normal_params, skull_locs)
	end,
})
local function initMinimapButton()
	deathlog_minimap_button_stub = LibStub("LibDBIcon-1.0", true)
	deathlog_minimap_button_stub:Register("Deathlog", deathlog_minimap_button, deathlog_minimap_button_info)
end

local function loadWidgets()
	Deathlog_minilog_applySettings()
	Deathlog_CRTWidget_applySettings()
	Deathlog_HIWidget_applySettings()
end

function Deathlog_LoadFromHardcore()
	if Hardcore_Settings and Hardcore_Settings["death_log_entries"] then
		print("Retrieving deathlog entries...")
		local c = 0
		local new_entries = 0
		if deathlog_data == nil or deathlog_data["legacy"] == nil then
			deathlog_data["legacy"] = {}
		end
		local local_deathlog_fletcher16 = deathlog_fletcher16
		for _, v in ipairs(Hardcore_Settings["death_log_entries"]) do
			c = c + 1
			local checksum = local_deathlog_fletcher16(v["name"], v["guild"], v["level"], v["source_id"])
			local converted_date = deathlogConvertStringDateUnix(v["date"])
			if converted_date then
				if deathlog_data["legacy"][checksum] == nil then
					new_entries = new_entries + 1
				end
				deathlog_data["legacy"][checksum] = {
					["class_id"] = v["class_id"],
					["guild"] = v["guild"],
					["date"] = converted_date,
					["map_pos"] = v["map_pos"],
					["source_id"] = v["source_id"],
					["name"] = v["name"],
					["race_id"] = v["race_id"],
					["level"] = v["level"],
					["map_id"] = v["map_id"],
					["instance_id"] = v["instance_id"],
					["last_words"] = v["last_words"],
				}
			else
				print("failed")
			end
		end
		print("Complete. New entries: " .. new_entries .. ". Scanned: " .. c)
	end
end

local function handleEvent(self, event, ...)
	if event == "COMBAT_LOG_EVENT_UNFILTERED" then
		-- local time, token, hidding, source_serial, source_name, caster_flags, caster_flags2, target_serial, target_name, target_flags, target_flags2, ability_id, ability_name, ability_type, extraSpellID, extraSpellName, extraSchool = CombatLogGetCurrentEventInfo()
		local _, ev, _, _, source_name, _, _, target_guid, _, _, _, environmental_type, _, _, _, _, _ =
			CombatLogGetCurrentEventInfo()

		if not (source_name == PLAYER_NAME) then
			if not (source_name == nil) then
				if string.find(ev, "DAMAGE") ~= nil then
					last_attack_source = source_name
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
		DEATHLOG_selfDeathAlert(last_attack_source)
		DEATHLOG_selfDeathAlertLastWords(recent_msg)
	elseif event == "CHAT_MSG_SAY" or event == "CHAT_MSG_GUILD" or event == "CHAT_MSG_PARTY" then
		local text, sn, LN, CN, p2, sF, zcI, cI, cB, unu, lI, senderGUID = ...
		if senderGUID == UnitGUID("player") then
			recent_msg = text
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		initMinimapButton()
		C_Timer.After(5.0, function()
			DEATHLOG_deathlogJoinChannel()
		end)
		if use_precomputed then
			general_stats = precomputed_general_stats
			log_normal_params = precomputed_log_normal_params
			skull_locs = precomputed_skull_locs
			dev_precomputed_general_stats = nil
			dev_precomputed_log_normal_params = nil
			dev_precomputed_skull_locs = nil
		else
			Deathlog_LoadFromHardcore()
			general_stats = deathlog_calculate_statistics(deathlog_data, nil)
			log_normal_params = deathlog_calculateLogNormalParameters(deathlog_data)
			skull_locs = deathlog_calculateSkullLocs(deathlog_data)
			if save_precompute then
				dev_precomputed_general_stats = general_stats
				dev_precomputed_log_normal_params = log_normal_params
				dev_precomputed_skull_locs = skull_locs
			else
				dev_precomputed_general_stats = nil
				dev_precomputed_log_normal_params = nil
				dev_precomputed_skull_locs = nil
			end
		end
		most_deadly_units["all"]["all"]["all"] = deathlogGetOrdered(general_stats, { "all", "all", "all", nil })

		for k, v in ipairs(most_deadly_units["all"]["all"]["all"]) do
			if id_to_npc[v[1]] then
				Deathlog_azeroth_deadliest_dict[id_to_npc[v[1]]] = k
			end
		end
		loadWidgets()
	end
end

local deathlog_event_handler = CreateFrame("Frame", "deathlog", nil, "BackdropTemplate")
deathlog_event_handler:RegisterEvent("PLAYER_ENTERING_WORLD")
deathlog_event_handler:RegisterEvent("PLAYER_DEAD")
deathlog_event_handler:RegisterEvent("CHAT_MSG_SAY")
deathlog_event_handler:RegisterEvent("CHAT_MSG_GUILD")
deathlog_event_handler:RegisterEvent("CHAT_MSG_PARTY")
deathlog_event_handler:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")

deathlog_event_handler:SetScript("OnEvent", handleEvent)

local LSM30 = LibStub("LibSharedMedia-3.0", true)
local options = {
	name = "Deathlog",
	handler = Hardcore,
	type = "group",
	args = {
		load_from_hc = {
			type = "execute",
			name = "Import deathlog from hardcore",
			desc = "Import deathlog from hardcore. This will append entries.",
			func = function()
				Deathlog_LoadFromHardcore()
			end,
		},
	},
}

LibStub("AceConfig-3.0"):RegisterOptionsTable("Deathlog", options)
optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Deathlog", "Deathlog", nil)
