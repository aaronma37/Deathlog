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

local SOURCE = DeathNotificationLib.SOURCE

local save_precompute = false
local use_precomputed = true
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
deathlog_char_data = deathlog_char_data or {}
deathlog_dev_data = deathlog_dev_data or {}
deathlog_entry_counts = deathlog_entry_counts or {}
deathlog_purged = deathlog_purged or {}
precomputed_purges = precomputed_purges or {}

local sync_options -- forward declaration; populated after options table
local deathlog_sync_options_registered = false
local deathlog_minimap_button_stub = nil
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
	if deathlog_settings.minimap == nil then
		deathlog_settings.minimap = {}
	end
	deathlog_minimap_button_stub:Register(addonName, deathlog_minimap_button, deathlog_settings.minimap)

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
	DeathNotificationLib.UpdateDeathAlert()
	Deathlog_ReportWidget_ApplySettings()
end

--- Initialize entry counters from existing data on first load.
--- Classifies legacy entries by inspecting available fields:
---   - Has both class_id and race_id → "self_death" (older clients only had addon-reported deaths with full data)
---   - Missing class_id or race_id → "blizzard" (Blizzard's HARDCORE_DEATHS channel reports lack these fields)
local function initEntryCounters()
	if deathlog_entry_counts == nil then
		deathlog_entry_counts = {}
	end

	if deathlog_entry_counts["initialized"] then
		return
	end

	local total = 0
	local self_death = 0
	local blizzard = 0
	for _, entries in pairs(deathlog_data) do
		if type(entries) == "table" then
			for _, entry in pairs(entries) do
				total = total + 1
				if entry["class_id"] and entry["race_id"] then
					self_death = self_death + 1
				else
					blizzard = blizzard + 1
				end
			end
		end
	end

	deathlog_entry_counts[SOURCE.SELF_DEATH] = self_death
	deathlog_entry_counts[SOURCE.BLIZZARD] = blizzard
	deathlog_entry_counts["total"] = total
	deathlog_entry_counts["initialized"] = true
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
					["played"] = v["played"],
					["last_words"] = v["last_words"],
				}
			else
				print("failed")
			end
		end
		print("Complete. New entries: " .. new_entries .. ". Scanned: " .. c)
	end
end

-- sync_options registered in handleEvent after loadWidgets() so it appears last in the sidebar

-- In-memory index: name_index[realmName][player_name] = { [checksum] = true, ... }
-- Allows efficient lookup of ALL existing entries for a player name (not just the latest).
-- Built lazily on first access per realm, maintained on insert/remove.
local name_index = {}

local function ensureNameIndex(realmName)
	if name_index[realmName] then return end
	name_index[realmName] = {}
	for checksum, entry in pairs(deathlog_data[realmName] or {}) do
		local n = entry["name"]
		if n then
			if not name_index[realmName][n] then
				name_index[realmName][n] = {}
			end
			name_index[realmName][n][checksum] = true
		end
	end
end

local function newEntry(_player_data, _checksum, num_peer_checks, in_guild, source)
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

	ensureNameIndex(realmName)

	local player_name = _player_data["name"]
	local current_time = _player_data["date"] or GetServerTime()

	-- Reject entries that were previously purged (e.g. false Feign Death)
	local modified_cs = DeathNotificationLib.Fletcher16(_player_data)

	if deathlog_purged[realmName] and deathlog_purged[realmName][modified_cs] then
		return
	end

	if precomputed_purges[realmName] and precomputed_purges[realmName][modified_cs] then
		return
	end

	-- Check ALL existing entries for this player name for near-duplicate deaths.
	-- The old approach only checked the single latest entry via deathlog_data_map,
	-- which missed duplicates when the latest entry was a different (newer) death.
	local existing_checksums = name_index[realmName][player_name]
	if existing_checksums then
		for cs, _ in pairs(existing_checksums) do
			local entry = deathlog_data[realmName][cs]
			if entry then
				local effective_level = math.max(tonumber(_player_data["level"]) or 0, tonumber(entry["level"]) or 0)
				local time_diff = math.abs(current_time - (entry["date"] or 0))
				if time_diff <= DeathNotificationLib.GetDedupWindow(effective_level) then
					local existing_quality = DeathNotificationLib.EntryQuality(entry)
					local new_quality = DeathNotificationLib.EntryQuality(_player_data)

					if new_quality > existing_quality then
						-- New entry has more data - merge and replace
						_player_data = DeathNotificationLib.MergeEntries(_player_data, entry)
						deathlog_data[realmName][cs] = nil
						existing_checksums[cs] = nil
						break
					elseif new_quality < existing_quality then
						-- Existing is better - merge new data into existing, skip
						local merged = DeathNotificationLib.MergeEntries(entry, _player_data)
						deathlog_data[realmName][cs] = merged
						return
					else
						-- Equal quality - merge into existing, skip
						local merged = DeathNotificationLib.MergeEntries(entry, _player_data)
						deathlog_data[realmName][cs] = merged
						return
					end
				end
			else
				-- Stale index entry, clean up
				existing_checksums[cs] = nil
			end
		end
	end

	local modified_checksum = DeathNotificationLib.Fletcher16(_player_data)

	deathlog_data[realmName][modified_checksum] = _player_data

	-- Maintain name index
	if not name_index[realmName][player_name] then
		name_index[realmName][player_name] = {}
	end
	name_index[realmName][player_name][modified_checksum] = true

	-- Only create widgets for self-reported deaths, peer broadcasts, and Blizzard notifications.
	-- Death alert is now handled internally by DNL (~DeathAlert.lua) via createEntry().
	if source == SOURCE.SELF_DEATH or source == SOURCE.PEER_BROADCAST or source == SOURCE.BLIZZARD then
		deathlog_widget_minilog_createEntry(_player_data)
	end

	deathlog_data_map[realmName][player_name] = modified_checksum

	source = source or SOURCE.UNKNOWN
	if deathlog_entry_counts then
		deathlog_entry_counts[source] = (deathlog_entry_counts[source] or 0) + 1
		deathlog_entry_counts["total"] = (deathlog_entry_counts["total"] or 0) + 1
	end
end

--- One-time cleanup: scan existing deathlog_data for near-duplicate entries
--- (same player name, same level, date within getDedupWindow(level)) and merge
--- them, keeping the highest-quality entry.  Runs synchronously on login.
--- Marks completion in deathlog_settings so it only runs once.
local DEDUP_CLEANUP_VERSION = 1  -- bump to re-run cleanup after future fixes

local function deathlog_runDedupCleanup()
	if deathlog_settings["dedup_cleanup_version"] and deathlog_settings["dedup_cleanup_version"] >= DEDUP_CLEANUP_VERSION then
		return
	end

	local total_removed = 0

	for realmName, entries in pairs(deathlog_data) do
		if type(entries) == "table" then
			-- Build a local name → [{checksum, date, level, quality}] index
			local by_name = {}
			for cs, entry in pairs(entries) do
				local n = entry["name"]
				if n then
					if not by_name[n] then by_name[n] = {} end
					by_name[n][#by_name[n] + 1] = {
						cs = cs,
						date = entry["date"] or 0,
						level = entry["level"] or 0,
						quality = DeathNotificationLib.EntryQuality(entry),
					}
				end
			end

			-- For each name, detect and merge near-duplicates
			for player_name, entry_list in pairs(by_name) do
				if #entry_list > 1 then
					-- Sort by date ascending
					table.sort(entry_list, function(a, b) return a.date < b.date end)

					local i = 1
					while i <= #entry_list do
						local j = i + 1
						while j <= #entry_list do
							local effective_level = math.max(entry_list[i].level, entry_list[j].level)
							local time_diff = math.abs(entry_list[j].date - entry_list[i].date)
							if time_diff <= DeathNotificationLib.GetDedupWindow(effective_level) then
								-- Near-duplicate: keep the higher quality entry, merge data
								local keep = entry_list[i]
								local remove = entry_list[j]
								if remove.quality > keep.quality then
									keep, remove = remove, keep
									entry_list[i] = keep
								end

								local keep_entry = entries[keep.cs]
								local remove_entry = entries[remove.cs]
								if keep_entry and remove_entry then
									local merged = DeathNotificationLib.MergeEntries(keep_entry, remove_entry)
									entries[keep.cs] = merged
									entries[remove.cs] = nil
									-- Update name_index if it exists
									if name_index[realmName] and name_index[realmName][player_name] then
										name_index[realmName][player_name][remove.cs] = nil
									end
									total_removed = total_removed + 1
								end
								table.remove(entry_list, j)
							else
								j = j + 1
							end
						end
						i = i + 1
					end
				end
			end
		end
	end

	deathlog_settings["dedup_cleanup_version"] = DEDUP_CLEANUP_VERSION

	if total_removed > 0 then
		print("|cFF00FF00[Deathlog]|r Database cleanup: removed " .. total_removed .. " duplicate entries.")
	end
end

local deathlog_initialized = false
local function handleEvent(self, event, ...)
	if event == "PLAYER_ENTERING_WORLD" then
		if deathlog_initialized then return end
		deathlog_initialized = true
		initMinimapButton()

		-- Ensure realm sub-tables exist so AttachAddon receives valid table
		-- references (not nil) that remain in sync with newEntry.
		local realmName = GetRealmName()
		if deathlog_data[realmName] == nil then
			deathlog_data[realmName] = {}
		end
		if deathlog_data_map[realmName] == nil then
			deathlog_data_map[realmName] = {}
		end
		if deathlog_purged[realmName] == nil then
			deathlog_purged[realmName] = {}
		end

		-- One-time dedup cleanup of existing data (runs before stats/widgets)
		deathlog_runDedupCleanup()

		DeathNotificationLib.AttachAddon({
			name             = "Deathlog",
			tag              = "DLG",
			isUnitTracked    = deathlog_isUnitTracked,
			settings         = deathlog_settings,
			db               = deathlog_data[realmName],
			db_map           = deathlog_data_map[realmName],
			dev_data         = deathlog_dev_data,
			addon_version    = C_AddOns.GetAddOnMetadata("Deathlog", "Version"),
		})
		DeathNotificationLib.HookOnNewAddonEntry("Deathlog", newEntry)
		if use_precomputed then
			general_stats = precomputed_general_stats
			log_normal_params = precomputed_log_normal_params
			deathlog_dev_data.precomputed_general_stats = nil
			deathlog_dev_data.precomputed_log_normal_params = nil
			deathlog_dev_data.class_data = nil
		else
			Deathlog_LoadFromHardcore()
			general_stats = deathlog_calculate_statistics(deathlog_data, nil)
			log_normal_params = deathlog_calculateLogNormalParameters(deathlog_data)
			class_data = deathlog_calculateClassData(deathlog_data)
			if save_precompute then
				deathlog_dev_data.precomputed_general_stats = general_stats
				deathlog_dev_data.precomputed_log_normal_params = log_normal_params
				deathlog_dev_data.class_data = class_data
			else
				deathlog_dev_data.precomputed_general_stats = nil
				deathlog_dev_data.precomputed_log_normal_params = nil
			end
		end
		most_deadly_units["all"]["all"]["all"] = deathlogGetOrdered(general_stats, { "all", "all", "all", nil })
		loadWidgets()

		initEntryCounters()
		C_Timer.After(2.5, function()
			Deathlog_CheckCTA()
			deathlog_startHunterCleanup()
		end)

		if not deathlog_sync_options_registered then
			deathlog_sync_options_registered = true
			LibStub("AceConfig-3.0"):RegisterOptionsTable("DeathlogSync", sync_options)
			LibStub("AceConfigDialog-3.0"):AddToBlizOptions("DeathlogSync", "Database Sync", "Deathlog")
		end
	end
end

local function SlashHandler(msg, editbox)
	if msg == "option" or msg == "options" then
		Settings.OpenToCategory(addonName)
	elseif msg == "alert" then
		DeathNotificationLib.TestDeathAlert()
	elseif msg == "sync" then
		DeathNotificationLib.SyncStatus()
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
			order = 1,
			func = function()
				Deathlog_LoadFromHardcore()
			end,
		},
		clear_cache_button = {
			type = "execute",
			name = "Clear cache",
			desc = "WARNING: This will remove deathlog data.  Do this if your log is getting too long.  The data is stored at _classic_era_/WTF/Account/<your_account_name>/SavedVariables/Deathlog.lua.  Reload after doing this.",
			width = 1.3,
			order = 2,
			func = function()
				wipe(deathlog_data)
				wipe(deathlog_data_map)
			end,
		},
		peer_reporting = {
			type = "toggle",
			name = "Allow peer-reported deaths",
			desc = "When enabled, deaths reported by party/raid members and tarnished soul detections from other players are accepted. When disabled, only self-reported deaths and Blizzard's hardcore death channel notifications are shown.",
			width = 1.3,
			order = 10,
			get = function()
				if deathlog_settings["peer_reporting"] == nil then
					deathlog_settings["peer_reporting"] = true
				end
				return deathlog_settings["peer_reporting"]
			end,
			set = function()
				deathlog_settings["peer_reporting"] = not deathlog_settings["peer_reporting"]
			end,
		},
		accept_legacy_messages = {
			type = "toggle",
			name = "Accept legacy protocol messages",
			desc = "When enabled, death messages from older addon versions (v0–v2 protocol) are accepted. When disabled, only current (v3) protocol messages are processed.",
			width = 1.3,
			order = 20,
			get = function()
				if deathlog_settings["legacy_messages"] == nil then
					deathlog_settings["legacy_messages"] = true
				end
				return deathlog_settings["legacy_messages"]
			end,
			set = function()
				deathlog_settings["legacy_messages"] = not deathlog_settings["legacy_messages"]
			end,
		},
		show_addonless_deaths = {
			type = "toggle",
			name = "Allow addonless death logging",
			desc = "When enabled, deaths received from Blizzard's HardcoreDeaths channel are converted into Deathlog entries. These entries have less detail (no race, class, or precise location) since the dying player isn't running the addon. Disable this if you only want full-quality addon-reported deaths in your log.",
			width = 1.3,
			order = 30,
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
		auto_blizzard_deaths = {
			type = "toggle",
			name = "Auto-configure Blizzard death tracking",
			desc = "When enabled, Deathlog automatically configures the Blizzard hardcore death CVars, joins the HardcoreDeaths channel (hidden), and periodically verifies they remain active. This lets us convert Blizzard's built-in death notifications into full Deathlog entries. If you don't want lower-quality data from these notifications, you can leave this on and disable 'Allow addonless death logging' instead.",
			width = 1.3,
			order = 35,
			get = function()
				if deathlog_settings["auto_blizzard_deaths"] == nil then
					deathlog_settings["auto_blizzard_deaths"] = true
				end
				return deathlog_settings["auto_blizzard_deaths"]
			end,
			set = function()
				deathlog_settings["auto_blizzard_deaths"] = not deathlog_settings["auto_blizzard_deaths"]
			end,
		},
		auto_hide_chat_channels = {
			type = "toggle",
			name = "Auto-hide addon chat channels",
			desc = "When enabled, Deathlog automatically hides its chat channels (death alerts, sync) from all chat frames so they don't clutter your chat windows. Disable this if you want to see the raw channel traffic for debugging.",
			width = 1.3,
			order = 36,
			get = function()
				if deathlog_settings["auto_hide_chat_channels"] == nil then
					deathlog_settings["auto_hide_chat_channels"] = true
				end
				return deathlog_settings["auto_hide_chat_channels"]
			end,
			set = function()
				deathlog_settings["auto_hide_chat_channels"] = not deathlog_settings["auto_hide_chat_channels"]
			end,
		},
		share_playtime = {
			type = "toggle",
			name = "Include playtime in death report",
			desc = "When enabled, your total /played time is included in your death broadcast so others can see how long you survived. Disable this if you prefer to keep your playtime private.",
			width = 1.3,
			order = 37,
			get = function()
				if deathlog_settings["share_playtime"] == nil then
					deathlog_settings["share_playtime"] = true
				end
				return deathlog_settings["share_playtime"]
			end,
			set = function()
				deathlog_settings["share_playtime"] = not deathlog_settings["share_playtime"]
			end,
		},
		show_minimap_button = {
			type = "toggle",
			name = "Show minimap button",
			desc = "Toggles whether the minimap button is visible.",
			width = 1.3,
			order = 40,
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
			order = 50,
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
			order = 60,
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

sync_options = {
	name = "Database Sync",
	type = "group",
	args = {
		sync_desc = {
			type = "description",
			name = "Continuously sync death entries with other Deathlog users in the background. Peers exchange watermarks, manifests, and entries over a dedicated addon channel.",
			fontSize = "medium",
			order = 1,
		},
		sync_enabled = {
			type = "toggle",
			name = "Enable database sync",
			desc = "Toggle background database sync on or off.",
			width = 1.3,
			order = 10,
			get = function()
				if deathlog_settings["sync_enabled"] == nil then
					deathlog_settings["sync_enabled"] = true
				end
				return deathlog_settings["sync_enabled"]
			end,
			set = function()
				deathlog_settings["sync_enabled"] = not deathlog_settings["sync_enabled"]
			end,
		},
		sync_window_days = {
			type = "range",
			name = "Sync window (days)",
			desc = "Only sync entries from the last N days. Larger windows exchange more data but cover more history. Set to -1 to sync ALL data.",
			width = 1.5,
			min = -1,
			max = 30,
			step = 1,
			order = 20,
			get = function()
				if deathlog_settings["sync_window_days"] == nil then
					deathlog_settings["sync_window_days"] = 7
				end
				return deathlog_settings["sync_window_days"]
			end,
			set = function(_, val)
				deathlog_settings["sync_window_days"] = val
			end,
		},
		sync_interval = {
			type = "range",
			name = "Watermark interval (seconds)",
			desc = "How often to broadcast your watermark to other peers. Lower values detect gaps faster but generate more traffic.",
			width = 1.5,
			min = 60,
			max = 3600,
			step = 30,
			order = 30,
			get = function()
				if deathlog_settings["sync_interval"] == nil then
					deathlog_settings["sync_interval"] = 300
				end
				return deathlog_settings["sync_interval"]
			end,
			set = function(_, val)
				deathlog_settings["sync_interval"] = val
			end,
		},
		sync_max_entries = {
			type = "range",
			name = "Max entries per sync",
			desc = "Maximum number of entries to request in a single sync session. Higher values catch up faster but use more bandwidth.",
			width = 1.5,
			min = 10,
			max = 2000,
			step = 10,
			order = 40,
			get = function()
				if deathlog_settings["sync_max_entries"] == nil then
					deathlog_settings["sync_max_entries"] = 500
				end
				return deathlog_settings["sync_max_entries"]
			end,
			set = function(_, val)
				deathlog_settings["sync_max_entries"] = val
			end,
		},
		sync_cooldown = {
			type = "range",
			name = "Sync cooldown (seconds)",
			desc = "Minimum time between sync sessions. Lower values re-sync sooner after finishing but generate more traffic. Set to 0 to sync continuously.",
			width = 1.5,
			min = 0,
			max = 3600,
			step = 30,
			order = 45,
			get = function()
				if deathlog_settings["sync_cooldown"] == nil then
					deathlog_settings["sync_cooldown"] = 300
				end
				return deathlog_settings["sync_cooldown"]
			end,
			set = function(_, val)
				deathlog_settings["sync_cooldown"] = val
			end,
		},
		sync_status = {
			type = "execute",
			name = "Show sync status",
			desc = "Print current sync status to chat (state, peer count, last sync time, cooldown).",
			width = 1.3,
			order = 50,
			func = function()
				DeathNotificationLib.SyncStatus()
			end,
		},
	},
}