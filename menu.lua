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
local _menu_width = 1100
local _inner_menu_width = 800
local _menu_height = 600
local current_map_id = nil

local deathlog_tabcontainer = nil

local class_tbl = deathlog_class_tbl
local race_tbl = deathlog_race_tbl
local zone_tbl = deathlog_zone_tbl
local instance_tbl = deathlog_instance_tbl

local deathlog_menu = nil

local subtitle_data = {
	{
		"Date",
		60,
		function(_entry, _server_name)
			return date("%m/%d/%y", _entry["date"]) or ""
		end,
	},
	{
		"Lvl",
		30,
		function(_entry, _server_name)
			return _entry["level"] or ""
		end,
	},
	{
		"Name",
		90,
		function(_entry, _server_name)
			return _entry["name"] or ""
		end,
	},
	{
		"Class",
		60,
		function(_entry, _server_name)
			local class_str, _, _ = GetClassInfo(_entry["class_id"])
			if RAID_CLASS_COLORS[class_str:upper()] then
				return "|c" .. RAID_CLASS_COLORS[class_str:upper()].colorStr .. class_str .. "|r"
			end
			return class_str or ""
		end,
	},
	{
		"Race",
		60,
		function(_entry, _server_name)
			local race_info = C_CreatureInfo.GetRaceInfo(_entry["race_id"])
			return race_info.raceName or ""
		end,
	},
	{
		"Guild",
		120,
		function(_entry, _server_name)
			return _entry["guild"] or ""
		end,
	},
	{
		"Zone/Instance",
		100,
		function(_entry, _server_name)
			if _entry["map_id"] == nil then
				if _entry["instance_id"] ~= nil then
					return deathlog_id_to_instance_tbl[_entry["instance_id"]] or _entry["instance_id"]
				else
					return "-----------"
				end
			end
			local map_info = C_Map.GetMapInfo(_entry["map_id"])
			if map_info then
				return map_info.name
			end
			return "-----------"
		end,
	},
	{
		"Death Source",
		140,
		function(_entry, _server_name)
			return id_to_npc[_entry["source_id"]] or ""
		end,
	},
	{
		"Last Words",
		200,
		function(_entry, _server_name)
			return _entry["last_words"] or ""
		end,
	},
}

local AceGUI = LibStub("AceGUI-3.0")

local font_container = CreateFrame("Frame")
font_container:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
font_container:SetSize(100, 100)
font_container:Show()
local row_entry = {}
local font_strings = {} -- idx/columns
local header_strings = {} -- columns
local row_backgrounds = {} --idx

for idx, v in ipairs(subtitle_data) do
	header_strings[v[1]] = font_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	if idx == 1 then
		header_strings[v[1]]:SetPoint("LEFT", font_container, "LEFT", 0, 0)
	else
		header_strings[v[1]]:SetPoint("LEFT", last_font_string, "RIGHT", 0, 0)
	end
	last_font_string = header_strings[v[1]]
	header_strings[v[1]]:SetJustifyH("LEFT")
	header_strings[v[1]]:SetWordWrap(false)

	if idx + 1 <= #subtitle_data then
		header_strings[v[1]]:SetWidth(v[2])
	end
	header_strings[v[1]]:SetTextColor(0.7, 0.7, 0.7)
	header_strings[v[1]]:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
end

for i = 1, 100 do
	font_strings[i] = {}
	local last_font_string = nil
	for idx, v in ipairs(subtitle_data) do
		font_strings[i][v[1]] = font_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		if idx == 1 then
			font_strings[i][v[1]]:SetPoint("LEFT", font_container, "LEFT", 0, 0)
		else
			font_strings[i][v[1]]:SetPoint("LEFT", last_font_string, "RIGHT", 0, 0)
		end
		last_font_string = font_strings[i][v[1]]
		font_strings[i][v[1]]:SetJustifyH("LEFT")
		font_strings[i][v[1]]:SetWordWrap(false)

		if idx + 1 <= #subtitle_data then
			font_strings[i][v[1]]:SetWidth(v[2])
		end
		font_strings[i][v[1]]:SetTextColor(1, 1, 1)
		font_strings[i][v[1]]:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
	end

	row_backgrounds[i] = font_container:CreateTexture(nil, "OVERLAY")
	row_backgrounds[i]:SetDrawLayer("OVERLAY", 2)
	row_backgrounds[i]:SetVertexColor(0.5, 0.5, 0.5, (i % 2) / 10)
	row_backgrounds[i]:SetHeight(16)
	row_backgrounds[i]:SetWidth(1600)
	row_backgrounds[i]:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
end

local function clearDeathlogMenuLogData()
	for i, v in ipairs(font_strings) do
		for _, col in ipairs(subtitle_data) do
			v[col[1]]:SetText("")
		end
	end
end

local function setDeathlogMenuLogData(data)
	local ordered = deathlogOrderBy(data, function(t, a, b)
		return tonumber(t[b]["date"]) < tonumber(t[a]["date"])
	end)
	for idx, v in ipairs(ordered) do
		for _, col in ipairs(subtitle_data) do
			font_strings[idx][col[1]]:SetText(col[3](v, ""))
		end
		if idx > 99 then
			break
		end
	end
	if #ordered == 1 then
		deathlog_menu:SetStatusText(#ordered .. " result")
	else
		deathlog_menu:SetStatusText(#ordered .. " results")
	end
	-- for server_name,entry_tbl in pairs(data) do
	--   for checksum,v in pairs(entry_tbl) do
	-- for _,col in ipairs(subtitle_data) do
	-- font_strings[c][col[1]]:SetText(col[3](v, server_name))
	-- end
	-- c=c+1
	-- if c > 99 then break end
	--   end
	-- end
end

local _deathlog_data = {}
local _stats = {}
local _log_normal_params = {}
local _skull_locs = {}
local initialized = false

local function drawLogTab(container)
	local scroll_container = AceGUI:Create("SimpleGroup")
	scroll_container:SetFullWidth(true)
	scroll_container:SetFullHeight(true)
	scroll_container:SetLayout("Fill")
	deathlog_tabcontainer:AddChild(scroll_container)

	local scroll_frame = AceGUI:Create("ScrollFrame")
	scroll_frame:SetLayout("Flow")
	scroll_container:AddChild(scroll_frame)

	local name_filter = nil
	local guidl_filter = nil
	local class_filter = nil
	local race_filter = nil
	local zone_filter = nil
	local min_level_filter = nil
	local max_level_filter = nil
	local death_source_filter = nil
	local filter = function(server_name, _entry)
		if name_filter ~= nil then
			if name_filter(server_name, _entry) == false then
				return false
			end
		end
		if min_level_filter ~= nil then
			if min_level_filter(server_name, _entry) == false then
				return false
			end
		end
		if max_level_filter ~= nil then
			if max_level_filter(server_name, _entry) == false then
				return false
			end
		end
		if death_source_filter ~= nil then
			if death_source_filter(server_name, _entry) == false then
				return false
			end
		end
		if class_filter ~= nil then
			if class_filter(server_name, _entry) == false then
				return false
			end
		end
		if race_filter ~= nil then
			if race_filter(server_name, _entry) == false then
				return false
			end
		end
		if zone_filter ~= nil then
			if zone_filter(server_name, _entry) == false then
				return false
			end
		end
		if guild_filter ~= nil then
			if guild_filter(server_name, _entry) == false then
				return false
			end
		end
		return true
	end

	local server_search_box = AceGUI:Create("DeathlogDropdown")
	server_search_box:SetWidth(150)
	server_search_box:SetDisabled(false)
	server_search_box:SetLabel("Server")
	server_search_box:SetPoint("TOP", 2, 5)
	server_search_box:AddItem("", "")
	for server_name, _ in pairs(_deathlog_data) do
		server_search_box:AddItem(server_name, server_name)
	end
	server_search_box:SetText("")
	scroll_frame:AddChild(server_search_box)

	local class_search_box = AceGUI:Create("DeathlogDropdown")
	class_search_box:SetWidth(100)
	class_search_box:SetDisabled(false)
	class_search_box:SetLabel("Class")
	class_search_box:SetPoint("TOP", 0, 0)
	class_search_box.label:SetFont("Fonts\\blei00d.TTF", 13, "")
	class_search_box:AddItem("", "")
	for class_name, _ in pairs(class_tbl) do
		class_search_box:AddItem(class_name, class_name)
	end
	class_search_box:SetCallback("OnValueChanged", function()
		local key = class_search_box:GetValue()
		if key ~= "" then
			class_filter = function(_, _entry)
				if class_tbl[key] == tonumber(_entry["class_id"]) then
					return true
				else
					return false
				end
			end
			clearDeathlogMenuLogData()
			setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
		else
			class_filter = nil
			clearDeathlogMenuLogData()
			setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
		end
	end)
	scroll_frame:AddChild(class_search_box)

	local race_search_box = AceGUI:Create("DeathlogDropdown")
	race_search_box:SetWidth(100)
	race_search_box:SetDisabled(false)
	race_search_box:SetLabel("Race")
	race_search_box:SetPoint("TOP", 0, 0)
	race_search_box.label:SetFont("Fonts\\blei00d.TTF", 13, "")
	race_search_box:AddItem("", "")
	for race_name, _ in pairs(race_tbl) do
		race_search_box:AddItem(race_name, race_name)
	end
	race_search_box:SetCallback("OnValueChanged", function()
		local key = race_search_box:GetValue()
		if key ~= "" then
			race_filter = function(_, _entry)
				if race_tbl[key] == tonumber(_entry["race_id"]) then
					return true
				else
					return false
				end
			end
			clearDeathlogMenuLogData()
			setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
		else
			race_filter = nil
			clearDeathlogMenuLogData()
			setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
		end
	end)
	scroll_frame:AddChild(race_search_box)

	local zone_search_box = AceGUI:Create("DeathlogDropdown")
	zone_search_box:SetWidth(140)
	zone_search_box:SetDisabled(false)
	zone_search_box:SetLabel("Zone/Instance")
	zone_search_box:SetPoint("TOP", 0, 0)
	zone_search_box.label:SetFont("Fonts\\blei00d.TTF", 13, "")
	zone_search_box:AddItem("", "")
	for zone_name, _ in pairs(zone_tbl) do
		zone_search_box:AddItem(zone_name, zone_name)
	end
	zone_search_box:AddItem("", "---------")
	for zone_name, _ in pairs(instance_tbl) do
		zone_search_box:AddItem(zone_name, zone_name)
	end
	zone_search_box:SetCallback("OnValueChanged", function()
		local key = zone_search_box:GetValue()
		if key ~= "" then
			zone_filter = function(_, _entry)
				if
					(zone_tbl[key] and zone_tbl[key] == tonumber(_entry["map_id"]))
					or (instance_tbl[key] and instance_tbl[key] == tonumber(_entry["instance_id"]))
				then
					return true
				else
					return false
				end
			end
			clearDeathlogMenuLogData()
			setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
		else
			zone_filter = nil
			clearDeathlogMenuLogData()
			setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
		end
	end)
	scroll_frame:AddChild(zone_search_box)

	local min_level_box = AceGUI:Create("DeathlogEditBox")
	min_level_box:SetWidth(60)
	min_level_box:SetDisabled(false)
	min_level_box:SetLabel("min lvl")
	min_level_box:SetPoint("TOP", 2, 5)
	min_level_box:DisableButton(false)
	min_level_box:SetCallback("OnEnterPressed", function()
		local text = min_level_box:GetText()
		if #text > 0 then
			min_level_filter = function(_, _entry)
				if tonumber(text) ~= nil and tonumber(text) < _entry["level"] then
					return true
				end
				return false
			end
			clearDeathlogMenuLogData()
			setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
		else
			min_level_filter = nil
			clearDeathlogMenuLogData()
			setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
		end
	end)
	scroll_frame:AddChild(min_level_box)

	local max_level_box = AceGUI:Create("DeathlogEditBox")
	max_level_box:SetWidth(60)
	max_level_box:SetDisabled(false)
	max_level_box:SetPoint("TOP", 2, 5)
	max_level_box:SetLabel("max lvl")
	max_level_box:DisableButton(false)
	max_level_box:SetCallback("OnEnterPressed", function()
		local text = max_level_box:GetText()
		if #text > 0 then
			max_level_filter = function(_, _entry)
				if tonumber(text) ~= nil and tonumber(text) > _entry["level"] then
					return true
				end
				return false
			end
			clearDeathlogMenuLogData()
			setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
		else
			max_level_filter = nil
			clearDeathlogMenuLogData()
			setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
		end
	end)
	scroll_frame:AddChild(max_level_box)

	local player_search_box = AceGUI:Create("DeathlogEditBox")
	player_search_box:SetWidth(120)
	player_search_box:SetDisabled(false)
	player_search_box:SetLabel("Name")
	player_search_box:SetPoint("TOP", 0, 0)
	player_search_box.label:SetFont("Fonts\\blei00d.TTF", 13, "")
	player_search_box:DisableButton(false)
	player_search_box:SetCallback("OnEnterPressed", function()
		local text = player_search_box:GetText()
		if #text > 0 then
			name_filter = function(_, _entry)
				if string.find(string.lower(_entry["name"]), string.lower(text)) then
					return true
				else
					return false
				end
			end
			clearDeathlogMenuLogData()
			setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
		else
			name_filter = nil
			clearDeathlogMenuLogData()
			setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
		end
	end)
	scroll_frame:AddChild(player_search_box)

	local guild_search_box = AceGUI:Create("DeathlogEditBox")
	guild_search_box:SetWidth(120)
	guild_search_box:SetDisabled(false)
	guild_search_box:SetLabel("Guild")
	guild_search_box:SetPoint("TOP", 0, 0)
	guild_search_box.label:SetFont("Fonts\\blei00d.TTF", 13, "")
	guild_search_box:DisableButton(false)
	guild_search_box:SetCallback("OnEnterPressed", function()
		local text = guild_search_box:GetText()
		if #text > 0 then
			guild_filter = function(_, _entry)
				if string.find(string.lower(_entry["guild"]), string.lower(text)) then
					return true
				else
					return false
				end
			end
			clearDeathlogMenuLogData()
			setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
		else
			guild_filter = nil
			clearDeathlogMenuLogData()
			setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
		end
	end)
	scroll_frame:AddChild(guild_search_box)

	local death_source_box = AceGUI:Create("DeathlogEditBox")
	death_source_box:SetWidth(150)
	death_source_box:SetDisabled(false)
	death_source_box:SetLabel("Death source")
	death_source_box:SetPoint("TOP", 2, 5)
	death_source_box:DisableButton(false)
	death_source_box:SetCallback("OnEnterPressed", function()
		local text = death_source_box:GetText()
		if #text > 0 then
			death_source_filter = function(_, _entry)
				if
					id_to_npc[_entry["source_id"]] ~= nil
					and string.find(string.lower(id_to_npc[_entry["source_id"]]), string.lower(text))
				then
					return true
				else
					return false
				end
			end
			clearDeathlogMenuLogData()
			setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
		else
			death_source_filter = nil
			clearDeathlogMenuLogData()
			setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
		end
	end)
	scroll_frame:AddChild(death_source_box)

	local header_label = AceGUI:Create("InteractiveLabel")
	header_label:SetFullWidth(true)
	header_label:SetHeight(60)
	header_label.font_strings = {}

	header_strings[subtitle_data[1][1]]:SetPoint("LEFT", header_label.frame, "LEFT", 0, 0)
	header_strings[subtitle_data[1][1]]:Show()
	for _, v in ipairs(subtitle_data) do
		header_strings[v[1]]:SetParent(header_label.frame)
		header_strings[v[1]]:SetText(v[1])
	end

	header_label:SetFont("Fonts\\FRIZQT__.TTF", 16, "")
	header_label:SetColor(1, 1, 1)
	header_label:SetText(" ")
	scroll_frame:AddChild(header_label)

	local deathlog_group = AceGUI:Create("ScrollFrame")
	deathlog_group:SetFullWidth(true)
	deathlog_group:SetHeight(440)
	scroll_frame:AddChild(deathlog_group)
	font_container:SetParent(deathlog_group.frame)
	-- font_container:SetPoint("TOP", deathlog_group.frame, "TOP", 0, -100)
	font_container:SetHeight(400)
	font_container:Show()
	for i = 1, 100 do
		local idx = 101 - i
		local _entry = AceGUI:Create("InteractiveLabel")
		_entry:SetHighlight("Interface\\Glues\\CharacterSelect\\Glues-CharacterSelect-Highlight")

		font_strings[i][subtitle_data[1][1]]:SetPoint("LEFT", _entry.frame, "LEFT", 0, 0)
		font_strings[i][subtitle_data[1][1]]:Show()
		for _, v in ipairs(subtitle_data) do
			font_strings[i][v[1]]:SetParent(_entry.frame)
		end

		row_backgrounds[i]:SetPoint("CENTER", _entry.frame, "CENTER", 0, 0)
		row_backgrounds[i]:SetParent(_entry.frame)

		_entry:SetHeight(40)
		_entry:SetFullWidth(true)
		_entry:SetFont("Fonts\\FRIZQT__.TTF", 16, "")
		_entry:SetColor(1, 1, 1)
		_entry:SetText(" ")

		function _entry:deselect()
			for _, v in pairs(_entry.font_strings) do
				v:SetTextColor(1, 1, 1)
			end
		end

		function _entry:select()
			selected = idx
			for _, v in pairs(_entry.font_strings) do
				v:SetTextColor(1, 1, 0)
			end
		end

		_entry:SetCallback("OnLeave", function(widget)
			if _entry.player_data == nil then
				return
			end
			GameTooltip:Hide()
		end)

		_entry:SetCallback("OnClick", function()
			if _entry.player_data == nil then
				return
			end
			local click_type = GetMouseButtonClicked()

			if click_type == "LeftButton" then
				if selected then
					row_entry[selected]:deselect()
				end
				_entry:select()
			elseif click_type == "RightButton" then
				local dropDown = CreateFrame("Frame", "WPDemoContextMenu", UIParent, "UIDropDownMenuTemplate")
				-- Bind an initializer function to the dropdown; see previous sections for initializer function examples.
				UIDropDownMenu_Initialize(dropDown, WPDropDownDemo_Menu, "MENU")
				ToggleDropDownMenu(1, nil, dropDown, "cursor", 3, -3)
				if _entry["player_data"]["map_id"] and _entry["player_data"]["map_pos"] then
					death_tomb_frame.map_id = _entry["player_data"]["map_id"]
					local x, y = strsplit(",", _entry["player_data"]["map_pos"], 2)
					death_tomb_frame.coordinates = { x, y }
				end
			end
		end)

		_entry:SetCallback("OnEnter", function(widget)
			if _entry.player_data == nil then
				return
			end
			GameTooltip_SetDefaultAnchor(GameTooltip, WorldFrame)

			if string.sub(_entry.player_data["name"], #_entry.player_data["name"]) == "s" then
				GameTooltip:AddDoubleLine(
					_entry.player_data["name"] .. "' Death",
					"Lvl. " .. _entry.player_data["level"],
					1,
					1,
					1,
					0.5,
					0.5,
					0.5
				)
			else
				GameTooltip:AddDoubleLine(
					_entry.player_data["name"] .. "'s Death",
					"Lvl. " .. _entry.player_data["level"],
					1,
					1,
					1,
					0.5,
					0.5,
					0.5
				)
			end
			GameTooltip:AddLine("Name: " .. _entry.player_data["name"], 1, 1, 1)
			GameTooltip:AddLine("Guild: " .. _entry.player_data["guild"], 1, 1, 1)

			local race_info = C_CreatureInfo.GetRaceInfo(_entry.player_data["race_id"])
			if race_info then
				GameTooltip:AddLine("Race: " .. race_info.raceName, 1, 1, 1)
			end

			if _entry.player_data["class_id"] then
				local class_str, _, _ = GetClassInfo(_entry.player_data["class_id"])
				if class_str then
					GameTooltip:AddLine("Class: " .. class_str, 1, 1, 1)
				end
			end

			if _entry.player_data["source_id"] then
				local source_id = id_to_npc[_entry.player_data["source_id"]]
				if source_id then
					GameTooltip:AddLine("Killed by: " .. source_id, 1, 1, 1, true)
				elseif environment_damage[_entry.player_data["source_id"]] then
					GameTooltip:AddLine(
						"Died from: " .. environment_damage[_entry.player_data["source_id"]],
						1,
						1,
						1,
						true
					)
				end
			end

			if race_name then
				GameTooltip:AddLine("Race: " .. race_name, 1, 1, 1)
			end

			if _entry.player_data["map_id"] then
				local map_info = C_Map.GetMapInfo(_entry.player_data["map_id"])
				if map_info then
					GameTooltip:AddLine("Zone: " .. map_info.name, 1, 1, 1, true)
				end
			end

			if _entry.player_data["map_pos"] then
				GameTooltip:AddLine("Loc: " .. _entry.player_data["map_pos"], 1, 1, 1, true)
			end

			if _entry.player_data["date"] then
				GameTooltip:AddLine("Date: " .. _entry.player_data["date"], 1, 1, 1, true)
			end

			if _entry.player_data["last_words"] then
				GameTooltip:AddLine("Last words: " .. _entry.player_data["last_words"], 1, 1, 0, true)
			end
			GameTooltip:Show()
		end)

		deathlog_group:SetScroll(0)
		deathlog_group.scrollbar:Hide()
		deathlog_group:AddChild(_entry)
	end
	scroll_frame.scrollbar:Hide()
end

local function drawCreatureStatisticsTab(container)
	local current_creature_id = nil
	local update_functions = {}
	local scroll_container = AceGUI:Create("SimpleGroup")
	scroll_container:SetFullWidth(true)
	scroll_container:SetFullHeight(true)
	scroll_container:SetLayout("Fill")
	deathlog_tabcontainer:AddChild(scroll_container)

	local scroll_frame = AceGUI:Create("SimpleGroup")
	scroll_frame:SetLayout("Flow")
	scroll_container:AddChild(scroll_frame)

	local title_label = AceGUI:Create("Heading")
	title_label:SetFullWidth(true)
	title_label:SetText("Death Statistics - Azeroth")
	title_label.label:SetFont("Fonts\\blei00d.TTF", 24, "")
	scroll_frame:AddChild(title_label)
	local function modifyTitle(zone)
		title_label:SetText("Death Statistics - " .. zone)
	end

	local description_label = AceGUI:Create("Label")
	description_label:SetFullWidth(true)
	description_label:SetText("Death Statistics - Azeroth")
	description_label.label:SetFont("Fonts\\blei00d.TTF", 14, "")
	description_label.label:SetTextColor(0.6, 0.6, 0.6, 1.0)
	description_label.label:SetJustifyH("CENTER")
	scroll_frame:AddChild(description_label)
	local function modifyDescription(creature_id)
		local c_id = creature_id
		local deaths_by_creature = 0
		if _stats["all"]["all"]["all"][creature_id] then
			deaths_by_creature = _stats["all"]["all"]["all"][creature_id]["num_entries"]
		end
		local all_deaths = _stats["all"]["all"]["all"]["all"]["num_entries"]
		description_label:SetText(
			string.format("%.2f", deaths_by_creature / all_deaths * 100)
				.. "% of all deaths are caused by "
				.. id_to_npc[creature_id]
				.. "."
		)
	end

	local stats_menu_elements = {
		Deathlog_CreatureModelContainer(),
		Deathlog_AverageClassContainer(),
		Deathlog_MapContainerForCreatures(),
		Deathlog_DeadliestCreatureExtContainer(),
	}
	stats_menu_elements[2].configure_for = "creature"

	local function updateElements(creature_id, name, filter)
		current_creature_id = creature_id
		if name then
			modifyTitle(name)
			modifyDescription(current_creature_id, name)
		end
		local stats_tbl = {
			["skull_locs"] = _skull_locs,
			["stats"] = _stats,
			["log_normal_params"] = _log_normal_params,
		}
		for _, v in ipairs(stats_menu_elements) do
			v.updateMenuElement(scroll_frame, current_creature_id, stats_tbl, updateElements, filter)
		end
	end

	updateElements(40, "Kobold Miner")

	scroll_frame.frame:HookScript("OnHide", function()
		for _, v in ipairs(stats_menu_elements) do
			v:Hide()
		end
	end)
end

local function drawStatisticsTab(container)
	local update_functions = {}
	local scroll_container = AceGUI:Create("SimpleGroup")
	scroll_container:SetFullWidth(true)
	scroll_container:SetFullHeight(true)
	scroll_container:SetLayout("Fill")
	deathlog_tabcontainer:AddChild(scroll_container)

	local scroll_frame = AceGUI:Create("SimpleGroup")
	scroll_frame:SetLayout("Flow")
	scroll_container:AddChild(scroll_frame)

	local title_label = AceGUI:Create("Heading")
	title_label:SetFullWidth(true)
	title_label:SetText("Death Statistics - Azeroth")
	title_label.label:SetFont("Fonts\\blei00d.TTF", 24, "")
	scroll_frame:AddChild(title_label)
	local function modifyTitle(zone)
		title_label:SetText("Death Statistics - " .. zone)
	end

	local description_label = AceGUI:Create("Label")
	description_label:SetFullWidth(true)
	description_label:SetText("Death Statistics - Azeroth")
	description_label.label:SetFont("Fonts\\blei00d.TTF", 14, "")
	description_label.label:SetTextColor(0.6, 0.6, 0.6, 1.0)
	description_label.label:SetJustifyH("CENTER")
	scroll_frame:AddChild(description_label)
	local function modifyDescription(map_id, zone)
		local mid = map_id
		if mid == 947 then
			mid = "all"
		end
		local deaths_in_zone = 0
		if _stats["all"][mid] then
			deaths_in_zone = _stats["all"][mid]["all"]["all"]["num_entries"]
		end
		local all_deaths = _stats["all"]["all"]["all"]["all"]["num_entries"]
		description_label:SetText(
			string.format("%.2f", deaths_in_zone / all_deaths * 100) .. "% of all deaths occur in " .. zone .. "."
		)
	end

	local stats_menu_elements = {
		Deathlog_MapContainer(),
		Deathlog_DeadliestCreatureContainer(),
		Deathlog_AverageClassContainer(),
		Deathlog_GraphContainer(),
	}

	stats_menu_elements[3].configure_for = "map"

	local function setMapRegion(map_id, name)
		current_map_id = map_id
		if name then
			modifyTitle(name)
			modifyDescription(map_id, name)
		end
		local stats_tbl = {
			["skull_locs"] = _skull_locs,
			["stats"] = _stats,
			["log_normal_params"] = _log_normal_params,
		}
		for _, v in ipairs(stats_menu_elements) do
			v.updateMenuElement(scroll_frame, map_id, stats_tbl, setMapRegion)
		end
	end

	setMapRegion(947, "Azeroth")

	scroll_frame.frame:HookScript("OnHide", function()
		for _, v in ipairs(stats_menu_elements) do
			v:Hide()
		end
	end)
end

local function drawClassStatisticsTab(container)
	local update_functions = {}
	local scroll_container = AceGUI:Create("SimpleGroup")
	local current_instance_id = 36
	scroll_container:SetFullWidth(true)
	scroll_container:SetFullHeight(true)
	scroll_container:SetLayout("Fill")
	deathlog_tabcontainer:AddChild(scroll_container)

	local scroll_frame = AceGUI:Create("SimpleGroup")
	scroll_frame:SetLayout("Flow")
	scroll_container:AddChild(scroll_frame)

	local title_label = AceGUI:Create("Heading")
	title_label:SetFullWidth(true)
	title_label:SetText("Death Statistics - Azeroth")
	title_label.label:SetFont("Fonts\\blei00d.TTF", 24, "")
	scroll_frame:AddChild(title_label)
	local function modifyTitle(zone)
		title_label:SetText("Death Statistics - " .. zone)
	end

	local stats_menu_elements = {
		Deathlog_ClassGraphContainer(),
		Deathlog_ClassStatsContainer(),
		Deathlog_ClassSelectorContainer(),
		Deathlog_ClassStatsComparisonContainer(),
	}

	local function setMapRegion(map_id, name)
		current_map_id = map_id
		if name then
			modifyTitle(name)
		end
		local stats_tbl = {
			["skull_locs"] = _skull_locs,
			["stats"] = _stats,
			["log_normal_params"] = _log_normal_params,
		}
		for _, v in ipairs(stats_menu_elements) do
			v.updateMenuElement(scroll_frame, map_id, stats_tbl, setMapRegion)
		end
	end

	setMapRegion(1, "Warrior")

	scroll_frame.frame:HookScript("OnHide", function()
		for _, v in ipairs(stats_menu_elements) do
			v:Hide()
		end
	end)
end

local function drawInstanceStatisticsTab(container)
	local update_functions = {}
	local scroll_container = AceGUI:Create("SimpleGroup")
	local current_instance_id = 36
	scroll_container:SetFullWidth(true)
	scroll_container:SetFullHeight(true)
	scroll_container:SetLayout("Fill")
	deathlog_tabcontainer:AddChild(scroll_container)

	local scroll_frame = AceGUI:Create("SimpleGroup")
	scroll_frame:SetLayout("Flow")
	scroll_container:AddChild(scroll_frame)

	local title_label = AceGUI:Create("Heading")
	title_label:SetFullWidth(true)
	title_label:SetText("Death Statistics - Azeroth")
	title_label.label:SetFont("Fonts\\blei00d.TTF", 24, "")
	scroll_frame:AddChild(title_label)
	local function modifyTitle(zone)
		title_label:SetText("Death Statistics - " .. zone)
	end

	local stats_menu_elements = {
		Deathlog_InstanceContainer(),
		Deathlog_DeadliestCreatureContainer(),
		Deathlog_AverageClassContainer(),
		Deathlog_GraphContainer(),
	}
	stats_menu_elements[3].configure_for = "map"

	local function setMapRegion(map_id, name)
		current_map_id = map_id
		if name then
			modifyTitle(name)
		end
		local stats_tbl = {
			["skull_locs"] = _skull_locs,
			["stats"] = _stats,
			["log_normal_params"] = _log_normal_params,
		}
		for _, v in ipairs(stats_menu_elements) do
			v.updateMenuElement(scroll_frame, map_id, stats_tbl, setMapRegion)
		end
	end

	setMapRegion(36, "Deadmines")

	scroll_frame.frame:HookScript("OnHide", function()
		for _, v in ipairs(stats_menu_elements) do
			v:Hide()
		end
	end)
end

local function createDeathlogMenu()
	ace_deathlog_menu = AceGUI:Create("DeathlogMenu")
	_G["AceDeathlogMenu"] = ace_deathlog_menu.frame -- Close on <ESC>
	tinsert(UISpecialFrames, "AceDeathlogMenu")

	ace_deathlog_menu:SetTitle("Deathlog")
	ace_deathlog_menu:SetVersion(GetAddOnMetadata("Deathlog", "Version"))
	ace_deathlog_menu:SetStatusText("")
	ace_deathlog_menu:SetLayout("Flow")
	ace_deathlog_menu:SetHeight(_menu_height)
	ace_deathlog_menu:SetWidth(_menu_width)

	deathlog_tabcontainer = AceGUI:Create("DeathlogTabGroup") -- "InlineGroup" is also good
	local tab_table = {
		{ value = "ClassStatisticsTab", text = "Class Statistics" },
		{ value = "CreatureStatisticsTab", text = "Creature Statistics" },
		{ value = "InstanceStatisticsTab", text = "Instance Statistics" },
		{ value = "StatisticsTab", text = "Zone Statistics" },
		{ value = "LogTab", text = "Search" },
	}
	deathlog_tabcontainer:SetTabs(tab_table)
	deathlog_tabcontainer:SetFullWidth(true)
	deathlog_tabcontainer:SetFullHeight(true)
	deathlog_tabcontainer:SetLayout("Flow")

	local function SelectGroup(container, event, group)
		container:ReleaseChildren()
		if group == "StatisticsTab" then
			drawStatisticsTab(container)
		elseif group == "InstanceStatisticsTab" then
			drawInstanceStatisticsTab(container)
		elseif group == "ClassStatisticsTab" then
			drawClassStatisticsTab(container)
		elseif group == "CreatureStatisticsTab" then
			drawCreatureStatisticsTab(container)
		elseif group == "LogTab" then
			drawLogTab(container)
		end
	end

	deathlog_tabcontainer:SetCallback("OnGroupSelected", SelectGroup)
	deathlog_tabcontainer:SelectTab("LogTab")

	ace_deathlog_menu:AddChild(deathlog_tabcontainer)
	return ace_deathlog_menu
end

deathlog_menu = createDeathlogMenu()

function deathlogShowMenu(deathlog_data, stats, log_normal_params, skull_locs)
	deathlog_menu:Show()
	deathlog_tabcontainer:SelectTab("LogTab")
	_deathlog_data = deathlog_data
	_stats = stats
	_log_normal_params = log_normal_params
	_skull_locs = skull_locs
	setDeathlogMenuLogData(_deathlog_data)
end

function deathlogHideMenu()
	deathlog_menu:Hide()
end
