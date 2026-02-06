--[[
Copyright 2026 Yazpad & Deathwing
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
local addonName, addon = ...

local save_precompute = false
local use_precomputed = true
local last_attack_source = nil
local recent_msg = nil
local general_stats = {}
local log_normal_params = {}
local class_data = {}
local most_deadly_units = {
	["all"] = { -- server
		["all"] = { -- map_id
			["all"] = {}, -- class_id
		},
	},
}

local most_deadly_units_normalized = {
	["all"] = { -- server
		["all"] = { -- map_id
			["all"] = {}, -- class_id
		},
	},
}

deathlog_data = deathlog_data or {}
deathlog_data_map = deathlog_data_map or {}
deathlog_settings = deathlog_settings or {}

local deathlog_minimap_button_stub = nil
local deathlog_minimap_button_info = {}
local deathlog_minimap_button = LibStub("LibDataBroker-1.1"):NewDataObject(addonName, {
	type = "data source",
	text = addonName,
	icon = "Interface\\TARGETINGFRAME\\UI-TargetingFrame-Skull",
	OnClick = function(self, btn)
		if btn == "LeftButton" then
			deathlogShowMenu(deathlog_data, general_stats, log_normal_params)
		else
			Settings.OpenToCategory(addonName)
		end
	end,
	OnTooltipShow = function(tooltip)
		tooltip:AddLine(addonName)
		tooltip:AddLine(Deathlog_L.minimap_btn_left_click)
		tooltip:AddLine(Deathlog_L.minimap_btn_right_click .. GAMEOPTIONS_MENU)
	end,
})
local function initMinimapButton()
	deathlog_minimap_button_stub = LibStub("LibDBIcon-1.0", true)
	if deathlog_minimap_button_stub:IsRegistered(addonName) then
		return
	end
	deathlog_minimap_button_stub:Register(addonName, deathlog_minimap_button, deathlog_minimap_button_info)

	if deathlog_settings["show_minimap"] ~= nil and deathlog_settings["show_minimap"] == false then
		deathlog_minimap_button_stub:Hide(addonName)
	end
end

local function loadWidgets()
	Deathlog_minilog_applySettings(true)
	Deathlog_CRTWidget_applySettings()
	Deathlog_CTTWidget_applySettings()
	Deathlog_HIWidget_applySettings()
	Deathlog_HWMWidget_applySettings()
	Deathlog_DeathAlertWidget_applySettings()
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
	if event == "PLAYER_ENTERING_WORLD" then
		initMinimapButton()
		if deathlog_data[GetRealmName()] and deathlog_data_map[GetRealmName()] then
			DeathNotificationLib_attachDB(deathlog_data[GetRealmName()], deathlog_data_map[GetRealmName()])
		end
		if use_precomputed then
			general_stats = precomputed_general_stats
			log_normal_params = precomputed_log_normal_params
			dev_precomputed_general_stats = nil
			dev_precomputed_log_normal_params = nil
			dev_class_data = nil
		else
			Deathlog_LoadFromHardcore()
			general_stats = deathlog_calculate_statistics(deathlog_data, nil)
			log_normal_params = deathlog_calculateLogNormalParameters(deathlog_data)
			class_data = deathlog_calculateClassData(deathlog_data)
			if save_precompute then
				dev_precomputed_general_stats = general_stats
				dev_precomputed_log_normal_params = log_normal_params
				dev_class_data = class_data
			else
				dev_precomputed_general_stats = nil
				dev_precomputed_log_normal_params = nil
			end
		end
		most_deadly_units["all"]["all"]["all"] = deathlogGetOrdered(general_stats, { "all", "all", "all", nil })
		loadWidgets()
	end
end

local function SlashHandler(msg, editbox)
	if msg == "option" or msg == "options" then
		Settings.OpenToCategory(addonName)
	elseif msg == "alert" then
		Deathlog_DeathAlertFakeDeath()
	else
		deathlogShowMenu(deathlog_data, general_stats, log_normal_params)
	end
end

SLASH_DEATHLOG1, SLASH_DEATHLOG2 = "/deathlog", "/dl"
SlashCmdList["DEATHLOG"] = SlashHandler

local deathlog_event_handler = CreateFrame("Frame", "deathlog", nil, "BackdropTemplate")
deathlog_event_handler:RegisterEvent("PLAYER_ENTERING_WORLD")

deathlog_event_handler:SetScript("OnEvent", handleEvent)

local LSM30 = LibStub("LibSharedMedia-3.0", true)
local options = {
	name = addonName,
	handler = Hardcore,
	type = "group",
	args = {
		load_from_hc = {
			type = "execute",
			name = "Import deathlog from hardcore",
			desc = "Import deathlog from hardcore. This will append entries.",
			width = 1.3,
			func = function()
				Deathlog_LoadFromHardcore()
			end,
		},
		clear_cache_button = {
			type = "execute",
			name = "Clear cache",
			desc = "WARNING: This will remove deathlog data.  Do this if your log is getting too long.  The data is stored at _classic_era_/WTF/Account/<your_account_name>/SavedVariables/Deathlog.lua.  Reload after doing this.",
			width = 1.3,
			func = function()
				deathlog_data = {}
				deathlog_data_map = {}
			end,
		},
		require_validation = {
			type = "toggle",
			name = "Allow guildless death logging",
			desc = "Toggle guildless death logging.  Guild-based death logging requires validation from guildmates to validate.  Guildless logging allows deaths to get logged without being validated.",
			width = 1.3,
			get = function()
				if deathlog_settings["deathless_logging"] == nil then
					deathlog_settings["deathless_logging"] = true
				end
				return deathlog_settings["deathless_logging"]
			end,
			set = function()
				deathlog_settings["deathless_logging"] = not deathlog_settings["deathless_logging"]
			end,
		},
		show_addonless_deaths = {
			type = "toggle",
			name = "Allow addonless death logging",
			desc = "Toggle addonless death logging.  Addonless deaths use blizzard notifications to log deaths from those who are not using the addon.",
			width = 1.3,
			get = function()
				if deathlog_settings["addonless_logging"] == nil then
					deathlog_settings["addonless_logging"] = false
				end
				return deathlog_settings["addonless_logging"]
			end,
			set = function()
				deathlog_settings["addonless_logging"] = not deathlog_settings["addonless_logging"]
			end,
		},
		show_minimap_button = {
			type = "toggle",
			name = "Show minimap button",
			desc = "Toggles whether the minimap is visible.",
			width = 1.3,
			get = function()
				if deathlog_settings["show_minimap"] == nil then
					deathlog_settings["show_minimap"] = true
				end
				return deathlog_settings["show_minimap"]
			end,
			set = function()
				deathlog_settings["show_minimap"] = not deathlog_settings["show_minimap"]

				if deathlog_settings["show_minimap"] then
					deathlog_minimap_button_stub:Show(addonName)
				else
					deathlog_minimap_button_stub:Hide(addonName)
				end
			end,
		},
		colored_tooltips = {
			type = "toggle",
			name = "Colored tooltips",
			desc = "Toggles whether tooltips have colored fields.",
			width = 1.3,
			get = function()
				if deathlog_settings["colored_tooltips"] == nil then
					deathlog_settings["colored_tooltips"] = false
				end
				return deathlog_settings["colored_tooltips"]
			end,
			set = function()
				deathlog_settings["colored_tooltips"] = not deathlog_settings["colored_tooltips"]
			end,
		},
		prediction_radius = {
			type = "range",
			name = "Source prediction radius",
			desc = "Search radius (in map cells) when predicting the death source from heatmap data. Higher values may find matches further away but could be less accurate.",
			width = 1.5,
			min = 0,
			max = 20,
			step = 1,
			get = function()
				if deathlog_settings["prediction_radius"] == nil then
					deathlog_settings["prediction_radius"] = 5
				end
				return deathlog_settings["prediction_radius"]
			end,
			set = function(_, val)
				deathlog_settings["prediction_radius"] = val
			end,
		},
	},
}

LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, options)
optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(addonName, "Deathlog", nil)

-- Deduplication window in seconds - deaths of the same player within this window are considered duplicates
-- This works alongside DeathNotificationLib's dedup mechanisms (bliz_alert_cache, tarnished_soul_cache)
-- but operates at the final entry point to catch duplicates from different sources (addon broadcast vs HARDCORE_DEATHS)
local DEATHLOG_DEDUP_WINDOW = 60

-- Calculate entry quality by counting populated fields
-- Similar to DeathNotificationLib's REPORT_QUALITY but more granular
local function deathlog_calculate_entry_quality(entry)
	local count = 0
	if entry["guild"] and entry["guild"] ~= "" then count = count + 1 end
	if entry["race_id"] then count = count + 1 end
	if entry["class_id"] then count = count + 1 end
	if entry["source_id"] and entry["source_id"] ~= -1 then count = count + 1 end
	if entry["map_id"] then count = count + 1 end
	if entry["map_pos"] then count = count + 1 end
	if entry["instance_id"] then count = count + 1 end
	if entry["last_words"] and entry["last_words"] ~= "" then count = count + 1 end
	return count
end

-- Merge two entries, preferring non-nil/non-empty values
-- Returns a new merged entry
local function deathlog_merge_entries(entry_a, entry_b)
	local merged = {}
	local fields = {"name", "guild", "source_id", "race_id", "class_id", "level", "instance_id", "map_id", "map_pos", "date", "last_words", "extra_data", "predicted_source"}
	for _, field in ipairs(fields) do
		local val_a = entry_a[field]
		local val_b = entry_b[field]
		-- Prefer non-nil, non-empty values; for source_id prefer non -1
		if field == "source_id" then
			if val_a and val_a ~= -1 then
				merged[field] = val_a
			elseif val_b and val_b ~= -1 then
				merged[field] = val_b
			else
				merged[field] = val_a or val_b
			end
		elseif field == "guild" or field == "last_words" or field == "map_pos" then
			-- For string fields, prefer non-empty
			if val_a and val_a ~= "" then
				merged[field] = val_a
			elseif val_b and val_b ~= "" then
				merged[field] = val_b
			else
				merged[field] = val_a or val_b
			end
		else
			merged[field] = val_a or val_b
		end
	end
	return merged
end

local function newEntry(_player_data, _checksum, num_peer_checks, in_guild)
	local realmName = GetRealmName()
	if deathlog_data == nil then
		deathlog_data = {}
	end

	if deathlog_data_map == nil then
		deathlog_data_map = {}
	end

	if deathlog_data[realmName] == nil then
		deathlog_data[realmName] = {}
	end

	if deathlog_data_map[realmName] == nil then
		deathlog_data_map[realmName] = {}
	end

	local function deathlog_modified_fletcher16(_player_data)
		local function deathlog_fletcher16(name, guild, level, source)
			local data = name .. (guild or "") .. (level or 0) .. (source or -1)
			local sum1 = 0
			local sum2 = 0
			for index = 1, #data do
				sum1 = (sum1 + string.byte(string.sub(data, index, index))) % 255
				sum2 = (sum2 + sum1) % 255
			end
			return name .. "-" .. bit.bor(bit.lshift(sum2, 8), sum1)
		end
		return deathlog_fletcher16(
			_player_data["name"],
			_player_data["guild"],
			_player_data["level"],
			_player_data["source_id"]
		)
	end

	local player_name = _player_data["name"]
	local current_time = _player_data["date"] or time()

	-- Check for existing entry for this player (deduplication)
	local existing_checksum = deathlog_data_map[realmName][player_name]
	if existing_checksum and deathlog_data[realmName][existing_checksum] then
		local existing_entry = deathlog_data[realmName][existing_checksum]
		local existing_time = existing_entry["date"] or 0
		local time_diff = math.abs(current_time - existing_time)

		-- If there's a recent entry for the same player, merge or skip
		if time_diff <= DEATHLOG_DEDUP_WINDOW then
			local existing_quality = deathlog_calculate_entry_quality(existing_entry)
			local new_quality = deathlog_calculate_entry_quality(_player_data)

			if new_quality > existing_quality then
				-- New entry has more data - merge entries to preserve any unique data from existing
				_player_data = deathlog_merge_entries(_player_data, existing_entry)
				-- Remove old entry (will be replaced with merged entry under new checksum)
				deathlog_data[realmName][existing_checksum] = nil
			elseif new_quality < existing_quality then
				-- Existing entry is better - merge any new unique data into existing, skip creating new
				local merged = deathlog_merge_entries(existing_entry, _player_data)
				deathlog_data[realmName][existing_checksum] = merged
				return
			else
				-- Equal quality - merge and keep existing checksum, skip new entry
				local merged = deathlog_merge_entries(existing_entry, _player_data)
				deathlog_data[realmName][existing_checksum] = merged
				return
			end
		end
	end

	local modified_checksum = deathlog_modified_fletcher16(_player_data)

	-- Predict source if unknown and store it for future use
	if _player_data["source_id"] and _player_data["predicted_source"] == nil then
		local known_source = id_to_npc and id_to_npc[_player_data["source_id"]]
		local env_source = deathlog_environment_damage and deathlog_environment_damage[_player_data["source_id"]]
		local pvp_source_name = _player_data["extra_data"] and _player_data["extra_data"]["pvp_source_name"]
		local pvp_source = deathlog_decode_pvp_source and deathlog_decode_pvp_source(_player_data["source_id"], pvp_source_name)
		if not known_source and not env_source and (not pvp_source or pvp_source == "") then
			if deathlogPredictSource then
				_player_data["predicted_source"] = deathlogPredictSource(_player_data["map_pos"], _player_data["map_id"])
			end
		end
	end

	deathlog_data[realmName][modified_checksum] = _player_data
	deathlog_widget_minilog_createEntry(_player_data)
	Deathlog_DeathAlertPlay(_player_data)
	deathlog_data_map[realmName][player_name] = modified_checksum
end

-- Hook to DeathNotificationLib
DeathNotificationLib_HookOnNewEntry(newEntry)

-- local b = C_Timer.NewTicker(0.5, function()
-- DeathNotificationLib_queryTarget("Hogbishop", UnitName("player"))
-- DeathNotificationLib_queryYell("Hogbishop")
-- end)

-- DeathNotificationLib_HookOnNewEntrySecure(function()
-- 	print("secure!")
-- end)
