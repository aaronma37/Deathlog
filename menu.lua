--[[
Copyright 2026 Yazpad & Deathwing
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
local id_to_npc = DeathNotificationLib.ID_TO_NPC
local instance_to_id = DeathNotificationLib.INSTANCE_TO_ID
local id_to_instance = DeathNotificationLib.ID_TO_INSTANCE
local zone_to_id = DeathNotificationLib.ZONE_TO_ID
local deathlog_environment_damage = DeathNotificationLib.ENVIRONMENT_DAMAGE
local instance_categories = DeathNotificationLib.INSTANCE_CATEGORIES
local zone_categories = DeathNotificationLib.ZONE_CATEGORIES
local deathlog_class_colors = DeathNotificationLib.CLASS_ID_TO_COLOR

local _menu_width = 1100
local _inner_menu_width = 800
local _menu_height = 600
local current_map_id = nil
local max_rows = 25
local page_number = 1
local total_pages = 1

local main_font = Deathlog_L.main_font

local deathlog_tabcontainer = nil
local deathlog_cta_banner = nil

local class_tbl = deathlog_class_tbl
local race_tbl = deathlog_race_tbl

-- Cached sorted results for pagination (avoids re-filtering/re-sorting on page changes)
local cached_sorted_results = nil
local cached_filter_version = 0  -- Incremented when filters change

local deathlog_menu = nil

local WorldMapButton = WorldMapFrame:GetCanvas()
local death_tomb_frame = CreateFrame("frame", nil, WorldMapButton)
death_tomb_frame:SetAllPoints()
death_tomb_frame:SetFrameLevel(15000)

local death_tomb_frame_tex = death_tomb_frame:CreateTexture(nil, "OVERLAY")
death_tomb_frame_tex:SetTexture("Interface\\TARGETINGFRAME\\UI-TargetingFrame-Skull")
death_tomb_frame_tex:SetDrawLayer("OVERLAY", 4)
death_tomb_frame_tex:SetHeight(25)
death_tomb_frame_tex:SetWidth(25)
death_tomb_frame_tex:Hide()

local death_tomb_frame_tex_glow = death_tomb_frame:CreateTexture(nil, "OVERLAY")
death_tomb_frame_tex_glow:SetTexture("Interface\\Glues/Models/UI_HUMAN/GenericGlow64")
death_tomb_frame_tex_glow:SetDrawLayer("OVERLAY", 3)
death_tomb_frame_tex_glow:SetHeight(55)
death_tomb_frame_tex_glow:SetWidth(55)
death_tomb_frame_tex_glow:Hide()

local function WPDropDownDemo_Menu(frame, level, menuList)
	local info = UIDropDownMenu_CreateInfo()

	local function canOpenWorldMap()
		if not (death_tomb_frame.map_id and death_tomb_frame.coordinates) then
			return false
		end
		if C_Map.GetMapInfo(death_tomb_frame["map_id"]) == nil then
			return false
		end
		if tonumber(death_tomb_frame.coordinates[1]) == nil or tonumber(death_tomb_frame.coordinates[2]) == nil then
			return false
		end
		return true
	end

	local function openWorldMap()
		if not canOpenWorldMap() then
			return
		end

		WorldMapFrame:SetShown(not WorldMapFrame:IsShown())
		WorldMapFrame:SetMapID(death_tomb_frame.map_id)
		WorldMapFrame:GetCanvas()
		local mWidth, mHeight = WorldMapFrame:GetCanvas():GetSize()
		death_tomb_frame_tex:SetPoint(
			"CENTER",
			WorldMapButton,
			"TOPLEFT",
			mWidth * death_tomb_frame.coordinates[1],
			-mHeight * death_tomb_frame.coordinates[2]
		)
		death_tomb_frame_tex:Show()

		death_tomb_frame_tex_glow:SetPoint(
			"CENTER",
			WorldMapButton,
			"TOPLEFT",
			mWidth * death_tomb_frame.coordinates[1],
			-mHeight * death_tomb_frame.coordinates[2]
		)
		death_tomb_frame_tex_glow:Show()
		death_tomb_frame:Show()
		deathlog_menu:Hide()
	end

	local function canBlockUser()
		if not death_tomb_frame.clicked_name then
			return false
		end
		if C_FriendList.GetNumIgnores() >= 50 then
			return false
		end
		return true
	end

	local function blockUser()
		if canBlockUser() then
			local added = C_FriendList.AddIgnore(death_tomb_frame.clicked_name)
		end
	end

	local function canWhisperPlayer()
		if not death_tomb_frame.clicked_name then
			return false
		end
		return true
	end

	local function whisperPlayer()
		if canWhisperPlayer() then
			ChatFrame_OpenChat("/w " .. death_tomb_frame.clicked_name .. " ")
		end
	end

	if level == 1 then
		info.text, info.hasArrow, info.func, info.disabled = "Whisper player", false, whisperPlayer, not canWhisperPlayer()
		UIDropDownMenu_AddButton(info)
		info.text, info.hasArrow, info.func, info.disabled = "Show death location", false, openWorldMap, not canOpenWorldMap()
		UIDropDownMenu_AddButton(info)
		info.text, info.hasArrow, info.func, info.disabled = "Block user", false, blockUser, not canBlockUser()
		UIDropDownMenu_AddButton(info)
	end
end

hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
	death_tomb_frame:Hide()
end)

local subtitle_data = {
	{
		"Date",
		105,
		function(_entry, _server_name)
			return date("%m/%d/%y, %H:%M", _entry["date"]) or ""
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
			if _entry["class_id"] == nil then
				return ""
			end
			local class_id = _entry["class_id"]
			local class_str, _, _ = GetClassInfo(class_id)
			if class_id then
				if deathlog_class_colors[class_id] then
					return "|c"
						.. deathlog_class_colors[class_id].colorStr
						.. class_str
						.. "|r"
				end
			end
			return class_str or ""
		end,
	},
	{
		"Race",
		60,
		function(_entry, _server_name)
			if _entry["race_id"] == nil then
				return ""
			end
			local race_info = C_CreatureInfo.GetRaceInfo(_entry["race_id"])
			if race_info then
				return race_info.raceName or ""
			end
			return ""
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
					return id_to_instance[_entry["instance_id"]] or _entry["instance_id"]
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
			local _pvp_source_name = _entry["extra_data"] and _entry["extra_data"]["pvp_source_name"]
			local _source = id_to_npc[_entry["source_id"]]
				or deathlog_environment_damage[_entry["source_id"]]
				or DeathNotificationLib.DecodePvPSource(_entry["source_id"], _pvp_source_name)
				or ""

			if _source == "" then
				if _entry["predicted_source"] then
					_source = _entry["predicted_source"]
				else
					local predicted = deathlogPredictSource(_entry)
					if predicted then
						_entry["predicted_source"] = predicted
						_source = predicted
					end
				end
			end
			return _source
		end,
	},
	{
		"Playtime",
		70,
		function(_entry, _server_name)
			return DeathNotificationLib.FormatPlaytime(_entry["played"]) or ""
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
	header_strings[v[1]]:SetFont(main_font, 12, "")
end

for i = 1, max_rows do
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
		font_strings[i][v[1]]:SetFont(main_font, 10, "")
	end

	row_backgrounds[i] = font_container:CreateTexture(nil, "OVERLAY")
	row_backgrounds[i]:SetDrawLayer("OVERLAY", 2)
	row_backgrounds[i]:SetVertexColor(0.5, 0.5, 0.5, (i % 2) / 10)
	row_backgrounds[i]:SetHeight(16)
	row_backgrounds[i]:SetWidth(1600)
	row_backgrounds[i]:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
end

local function clearDeathlogMenuLogData(skipPageReset)
	if not skipPageReset then
		page_number = 1
		if font_container.page_str then
			font_container.page_str:SetText("Page " .. page_number)
		end
	end
	for i, v in ipairs(font_strings) do
		for _, col in ipairs(subtitle_data) do
			v[col[1]]:SetText("")
		end
	end
	-- Hide pagination when clearing (will be shown again if data is available)
	if not skipPageReset then
		if font_container.page_str then font_container.page_str:Hide() end
		if font_container.prev_button then font_container.prev_button:Hide() end
		if font_container.next_button then font_container.next_button:Hide() end
	end
end

-- Display a page from pre-sorted results (used for pagination)
local function displayPageFromCache()
	if not cached_sorted_results then return end
	local ordered = cached_sorted_results
	for i = 1, max_rows do
		local idx = (i + (page_number - 1) * max_rows)
		if idx > #ordered then
			break
		end
		for _, col in ipairs(subtitle_data) do
			font_strings[i][col[1]]:SetText(col[3](ordered[idx], ""))
		end
		if ordered[idx] and ordered[idx].map_id then
			font_strings[i].map_id = ordered[idx].map_id
		end
		if ordered[idx] and ordered[idx].map_pos then
			local x, y = strsplit(",", ordered[idx].map_pos, 2)
			font_strings[i].map_id_coords_x = x
			font_strings[i].map_id_coords_y = y
		end
	end

	-- Update pagination visibility
	total_pages = math.max(1, math.ceil(#ordered / max_rows))
	if font_container.page_str then
		if #ordered == 0 or total_pages <= 1 then
			font_container.page_str:Hide()
			if font_container.prev_button then font_container.prev_button:Hide() end
			if font_container.next_button then font_container.next_button:Hide() end
		else
			font_container.page_str:SetText("Page " .. page_number .. " / " .. total_pages)
			font_container.page_str:Show()
			if font_container.prev_button then
				if page_number <= 1 then
					font_container.prev_button:Hide()
				else
					font_container.prev_button:Show()
				end
			end
			if font_container.next_button then
				if page_number >= total_pages then
					font_container.next_button:Hide()
				else
					font_container.next_button:Show()
				end
			end
		end
	end
end

local function setDeathlogMenuLogData(data)
	-- Sort and cache the filtered results
	local ordered = deathlogOrderByFast(data)
	cached_sorted_results = ordered
	cached_filter_version = cached_filter_version + 1
	
	for i = 1, max_rows do
		local idx = (i + (page_number - 1) * max_rows)
		if idx > #ordered then
			break
		end
		for _, col in ipairs(subtitle_data) do
			font_strings[i][col[1]]:SetText(col[3](ordered[idx], ""))
		end
		if ordered[idx] and ordered[idx].map_id then
			font_strings[i].map_id = ordered[idx].map_id
		end
		if ordered[idx] and ordered[idx].map_pos then
			local x, y = strsplit(",", ordered[idx].map_pos, 2)
			font_strings[i].map_id_coords_x = x
			font_strings[i].map_id_coords_y = y
		end
	end

	-- Update pagination visibility based on data
	total_pages = math.max(1, math.ceil(#ordered / max_rows))
	if font_container.page_str then
		if #ordered == 0 or total_pages <= 1 then
			-- Hide pagination entirely if no data or only one page
			font_container.page_str:Hide()
			if font_container.prev_button then font_container.prev_button:Hide() end
			if font_container.next_button then font_container.next_button:Hide() end
		else
			font_container.page_str:SetText("Page " .. page_number .. " / " .. total_pages)
			font_container.page_str:Show()
			-- Show/hide prev button based on current page
			if font_container.prev_button then
				if page_number <= 1 then
					font_container.prev_button:Hide()
				else
					font_container.prev_button:Show()
				end
			end
			-- Show/hide next button based on current page
			if font_container.next_button then
				if page_number >= total_pages then
					font_container.next_button:Hide()
				else
					font_container.next_button:Show()
				end
			end
		end
	end

	if #ordered == 1 then
		deathlog_menu:SetStatusText(
			#ordered
				.. " search result/"
				.. precomputed_general_stats["all"]["all"]["all"]["all"]["num_entries"]
				.. " preprocessed"
		)
	else
		deathlog_menu:SetStatusText(
			#ordered
				.. " search results/"
				.. precomputed_general_stats["all"]["all"]["all"]["all"]["num_entries"]
				.. " preprocessed"
		)
	end
end

local _deathlog_data = {}
local _stats = {}
local _log_normal_params = {}
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

	local server_filter = nil
	local name_filter = nil
	local guidl_filter = nil
	local class_filter = nil
	local race_filter = nil
	local zone_filter = nil
	local min_level_filter = nil
	local max_level_filter = nil
	local death_source_filter = nil
	local last_words_filter = nil
	local filter = function(server_name, _entry)
		if server_filter ~= nil then
			if server_filter(server_name, _entry) == false then
				return false
			end
		end
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
		if last_words_filter ~= nil then
			if last_words_filter(server_name, _entry) == false then
				return false
			end
		end
		return true
	end

	local class_search_box = AceGUI:Create("Icon")
	class_search_box:SetWidth(50)
	class_search_box:SetHeight(50)
	class_search_box:SetDisabled(true)
	scroll_frame:AddChild(class_search_box)

	--- Server dropdown
	if font_container.server_dd == nil then
		font_container.server_dd = CreateFrame("Frame", nil, font_container, "UIDropDownMenuTemplate")
		font_container.server_dd.val = ""
	end

	local function serverDD(frame, level, menuList)
		local info = UIDropDownMenu_CreateInfo()

		local function setFilter()
			local key = font_container.server_dd.val
			if key ~= "" then
				server_filter = function(server_name, _entry)
					if server_name == key then
						return true
					else
						return false
					end
				end
				clearDeathlogMenuLogData()
				setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
			else
				server_filter = nil
				clearDeathlogMenuLogData()
				setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
			end
		end

		info.text, info.checked, info.func =
			"All", font_container.server_dd.val == "", function()
				font_container.server_dd.val = ""
				UIDropDownMenu_SetText(font_container.server_dd, "All")
				setFilter()
			end
		UIDropDownMenu_AddButton(info)

		-- Track which servers we've added to avoid duplicates
		local added_servers = {}
		
		-- Always add current realm first
		local current_realm = GetRealmName()
		if current_realm and current_realm ~= "" then
			info.text, info.checked, info.func =
				current_realm, font_container.server_dd.val == current_realm, function()
					font_container.server_dd.val = current_realm
					UIDropDownMenu_SetText(font_container.server_dd, font_container.server_dd.val)
					setFilter()
				end
			UIDropDownMenu_AddButton(info)
			added_servers[current_realm] = true
		end

		-- Add other servers from death data
		for server_name, _ in pairs(_deathlog_data) do
			if not added_servers[server_name] then
				info.text, info.checked, info.func =
					server_name, font_container.server_dd.val == server_name, function()
						font_container.server_dd.val = server_name
						UIDropDownMenu_SetText(font_container.server_dd, font_container.server_dd.val)
						setFilter()
					end
				UIDropDownMenu_AddButton(info)
				added_servers[server_name] = true
			end
		end
	end

	font_container.server_dd:SetPoint("TOPLEFT", scroll_container.frame, "TOPLEFT", -5, -20)
	UIDropDownMenu_SetText(font_container.server_dd, font_container.server_dd.val ~= "" and font_container.server_dd.val or "All")
	UIDropDownMenu_SetWidth(font_container.server_dd, 80)
	UIDropDownMenu_Initialize(font_container.server_dd, serverDD)
	UIDropDownMenu_JustifyText(font_container.server_dd, "LEFT")

	if font_container.server_dd.text == nil then
		font_container.server_dd.text = font_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	end

	font_container.server_dd.text:SetPoint("LEFT", font_container.server_dd, "LEFT", 20, 20)
	font_container.server_dd.text:SetFont(Deathlog_L.menu_font, 12, "")
	font_container.server_dd.text:SetTextColor(255 / 255, 215 / 255, 0)
	font_container.server_dd.text:SetText("Server")
	font_container.server_dd.text:Show()

	--- Race dropdown
	if font_container.race_dd == nil then
		font_container.race_dd = CreateFrame("Frame", nil, font_container, "UIDropDownMenuTemplate")
		font_container.race_dd.val = ""
	end

	local function raceDD(frame, level, menuList)
		local info = UIDropDownMenu_CreateInfo()

		local function setFilter()
			local key = font_container.race_dd.val
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
		end

		info.text, info.checked, info.func =
			"All", font_container.race_dd.val == "", function()
				font_container.race_dd.val = ""
				UIDropDownMenu_SetText(font_container.race_dd, "All")
				setFilter()
			end
		UIDropDownMenu_AddButton(info)

		for race_name, _ in pairs(race_tbl) do
			info.text, info.checked, info.func =
				race_name, font_container.race_dd.val == race_name, function()
					font_container.race_dd.val = race_name
					UIDropDownMenu_SetText(font_container.race_dd, font_container.race_dd.val)
					setFilter()
				end
			UIDropDownMenu_AddButton(info)
		end
	end

	font_container.race_dd:SetPoint("TOPLEFT", scroll_container.frame, "TOPLEFT", 90, -20)
	UIDropDownMenu_SetText(font_container.race_dd, font_container.race_dd.val ~= "" and font_container.race_dd.val or "All")
	UIDropDownMenu_SetWidth(font_container.race_dd, 80)
	UIDropDownMenu_Initialize(font_container.race_dd, raceDD)
	UIDropDownMenu_JustifyText(font_container.race_dd, "LEFT")

	if font_container.race_dd.text == nil then
		font_container.race_dd.text = font_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	end

	font_container.race_dd.text:SetPoint("LEFT", font_container.race_dd, "LEFT", 20, 20)
	font_container.race_dd.text:SetFont(Deathlog_L.menu_font, 12, "")
	font_container.race_dd.text:SetTextColor(255 / 255, 215 / 255, 0)
	font_container.race_dd.text:SetText("Race")
	font_container.race_dd.text:Show()

	--- Race dropdown
	if font_container.class_dd == nil then
		font_container.class_dd = CreateFrame("Frame", nil, font_container, "UIDropDownMenuTemplate")
		font_container.class_dd.val = ""
	end

	local function classDD(frame, level, menuList)
		local info = UIDropDownMenu_CreateInfo()

		local function setFilter()
			local key = font_container.class_dd.val
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
		end

		info.text, info.checked, info.func =
			"All", font_container.class_dd.val == "", function()
				font_container.class_dd.val = ""
				UIDropDownMenu_SetText(font_container.class_dd, "All")
				setFilter()
			end
		UIDropDownMenu_AddButton(info)

		for class_name, _ in pairs(class_tbl) do
			info.text, info.checked, info.func =
				class_name, font_container.class_dd.val == class_name, function()
					font_container.class_dd.val = class_name
					UIDropDownMenu_SetText(font_container.class_dd, font_container.class_dd.val)
					setFilter()
				end
			UIDropDownMenu_AddButton(info)
		end
	end

	font_container.class_dd:SetPoint("TOPLEFT", scroll_container.frame, "TOPLEFT", 185, -20)
	UIDropDownMenu_SetText(font_container.class_dd, font_container.class_dd.val ~= "" and font_container.class_dd.val or "All")
	UIDropDownMenu_SetWidth(font_container.class_dd, 80)
	UIDropDownMenu_Initialize(font_container.class_dd, classDD)
	UIDropDownMenu_JustifyText(font_container.class_dd, "LEFT")

	if font_container.class_dd.text == nil then
		font_container.class_dd.text = font_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	end

	font_container.class_dd.text:SetPoint("LEFT", font_container.class_dd, "LEFT", 20, 20)
	font_container.class_dd.text:SetFont(Deathlog_L.menu_font, 12, "")
	font_container.class_dd.text:SetTextColor(255 / 255, 215 / 255, 0)
	font_container.class_dd.text:SetText("Class")
	font_container.class_dd.text:Show()

	--- Zone dropdown
	if font_container.zone_dd == nil then
		font_container.zone_dd = CreateFrame("Frame", nil, font_container, "UIDropDownMenuTemplate")
		font_container.zone_dd.val = ""
	end

	-- Helper: get zone IDs from a category that exist in a specific expansion
	local function getZoneCategoryForExpansion(category_name, expansion_id)
		local category_ids = zone_categories and zone_categories[category_name]
		if not category_ids then return {} end
		
		local expansion_zones = zone_to_id[expansion_id]
		if not expansion_zones then return {} end
		
		-- Build reverse lookup: zone_id -> true for this expansion
		local expansion_zone_ids = {}
		for _, zone_id in pairs(expansion_zones) do
			expansion_zone_ids[zone_id] = true
		end
		
		-- Filter category IDs to only those in this expansion
		local filtered = {}
		for _, zone_id in ipairs(category_ids) do
			if expansion_zone_ids[zone_id] then
				table.insert(filtered, zone_id)
			end
		end
		return filtered
	end

	local function zoneDD(frame, level, menuList)
		local info = UIDropDownMenu_CreateInfo()

		local function setFilter()
			local key = font_container.zone_dd.val
			if key ~= "" then
				zone_filter = function(_, _entry)
					-- Look up zone in all expansions
					for _, zones in pairs(zone_to_id) do
						if zones[key] and zones[key] == tonumber(_entry["map_id"]) then
							return true
						end
					end
					-- Look up instance in all expansions
					for _, instances in pairs(instance_to_id) do
						if instances[key] and instances[key] == tonumber(_entry["instance_id"]) then
							return true
						end
					end
					return false
				end
				clearDeathlogMenuLogData()
				setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
			else
				zone_filter = nil
				clearDeathlogMenuLogData()
				setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
			end
		end

		-- Count how many expansions we have for zones
		local zone_expansion_count = 0
		local single_zone_expansion_id = nil
		for expansion_id, _ in pairs(zone_to_id) do
			zone_expansion_count = zone_expansion_count + 1
			single_zone_expansion_id = expansion_id
		end
		local skip_zone_expansion_layer = (zone_expansion_count == 1)

		if level == 1 or level == nil then
			-- "All" option at top level
			info.text, info.checked, info.func =
				"All", font_container.zone_dd.val == "", function()
					font_container.zone_dd.val = ""
					UIDropDownMenu_SetText(font_container.zone_dd, "All")
					setFilter()
				end
			UIDropDownMenu_AddButton(info, level)

			if skip_zone_expansion_layer then
				-- Only one expansion: show continent submenus directly at level 1
				if zone_categories then
					local sorted_categories = {}
					for category_name, _ in pairs(zone_categories) do
						local filtered_zones = getZoneCategoryForExpansion(category_name, single_zone_expansion_id)
						if #filtered_zones > 0 then
							table.insert(sorted_categories, { name = category_name, zones = filtered_zones })
						end
					end
					table.sort(sorted_categories, function(a, b) return a.name < b.name end)

					for _, category in ipairs(sorted_categories) do
						info = UIDropDownMenu_CreateInfo()
						info.text = category.name
						info.hasArrow = true
						info.notCheckable = true
						info.menuList = { type = "continent", expansion_id = single_zone_expansion_id, category_name = category.name, zones = category.zones }
						UIDropDownMenu_AddButton(info, level)
					end
				else
					-- No categories: show all zones directly
					local zones = zone_to_id[single_zone_expansion_id]
					if zones then
						local sorted_zones = {}
						for zone_name, zone_id in pairs(zones) do
							table.insert(sorted_zones, { name = zone_name, id = zone_id })
						end
						table.sort(sorted_zones, function(a, b) return a.name < b.name end)
						for _, zone in ipairs(sorted_zones) do
							info = UIDropDownMenu_CreateInfo()
							info.text = zone.name
							info.checked = font_container.zone_dd.val == zone.name
							info.func = function()
								font_container.zone_dd.val = zone.name
								UIDropDownMenu_SetText(font_container.zone_dd, font_container.zone_dd.val)
								setFilter()
								CloseDropDownMenus()
							end
							UIDropDownMenu_AddButton(info, level)
						end
					end
				end
			else
				-- Multiple expansions: show expansion submenus (sorted by expansion_id)
				local sorted_expansion_ids = {}
				for expansion_id, _ in pairs(zone_to_id) do
					table.insert(sorted_expansion_ids, expansion_id)
				end
				table.sort(sorted_expansion_ids)
				for _, expansion_id in ipairs(sorted_expansion_ids) do
					info = UIDropDownMenu_CreateInfo()
					info.text = _G["EXPANSION_NAME" .. expansion_id]
					info.hasArrow = true
					info.notCheckable = true
					info.menuList = { type = "expansion", id = expansion_id }
					UIDropDownMenu_AddButton(info, level)
				end
			end
		elseif level == 2 then
			local menu_type = menuList and menuList.type

			if menu_type == "continent" then
				-- Coming from either: single-expansion level 1, or multi-expansion level 2
				-- Show individual zones for selected continent/category
				local category_zones = menuList.zones
				local expansion_id = menuList.expansion_id
				if category_zones and expansion_id then
					local zones = zone_to_id[expansion_id]
					if zones then
						local category_zone_ids = {}
						for _, zone_id in ipairs(category_zones) do
							category_zone_ids[zone_id] = true
						end
						local sorted_zones = {}
						for zone_name, zone_id in pairs(zones) do
							if category_zone_ids[zone_id] then
								table.insert(sorted_zones, { name = zone_name, id = zone_id })
							end
						end
						table.sort(sorted_zones, function(a, b) return a.name < b.name end)
						for _, zone in ipairs(sorted_zones) do
							info = UIDropDownMenu_CreateInfo()
							info.text = zone.name
							info.checked = font_container.zone_dd.val == zone.name
							info.func = function()
								font_container.zone_dd.val = zone.name
								UIDropDownMenu_SetText(font_container.zone_dd, font_container.zone_dd.val)
								setFilter()
								CloseDropDownMenus()
							end
							UIDropDownMenu_AddButton(info, level)
						end
					end
				end
			elseif menu_type == "expansion" then
				-- Multi-expansion path: show continent submenus
				local expansion_id = menuList.id
				if zone_categories then
					local sorted_categories = {}
					for category_name, _ in pairs(zone_categories) do
						local filtered_zones = getZoneCategoryForExpansion(category_name, expansion_id)
						if #filtered_zones > 0 then
							table.insert(sorted_categories, { name = category_name, zones = filtered_zones })
						end
					end
					table.sort(sorted_categories, function(a, b) return a.name < b.name end)
					
					for _, category in ipairs(sorted_categories) do
						info = UIDropDownMenu_CreateInfo()
						info.text = category.name
						info.hasArrow = true
						info.notCheckable = true
						info.menuList = { type = "continent", expansion_id = expansion_id, category_name = category.name, zones = category.zones }
						UIDropDownMenu_AddButton(info, level)
					end
				end
			
				-- Fallback if no categories or empty: show all zones directly
				if not zone_categories then
					local zones = zone_to_id[expansion_id]
					if zones then
						local sorted_zones = {}
						for zone_name, zone_id in pairs(zones) do
							table.insert(sorted_zones, { name = zone_name, id = zone_id })
						end
						table.sort(sorted_zones, function(a, b) return a.name < b.name end)
						for _, zone in ipairs(sorted_zones) do
							info = UIDropDownMenu_CreateInfo()
							info.text = zone.name
							info.checked = font_container.zone_dd.val == zone.name
							info.func = function()
								font_container.zone_dd.val = zone.name
								UIDropDownMenu_SetText(font_container.zone_dd, font_container.zone_dd.val)
								setFilter()
								CloseDropDownMenus()
							end
							UIDropDownMenu_AddButton(info, level)
						end
					end
				end
			end
		elseif level == 3 then
			-- Zones for selected continent/category (multi-expansion path only)
			local category_zones = menuList and menuList.zones
			local expansion_id = menuList and menuList.expansion_id
			if category_zones and expansion_id then
				local zones = zone_to_id[expansion_id]
				if zones then
					-- Build lookup of zone IDs in this category
					local category_zone_ids = {}
					for _, zone_id in ipairs(category_zones) do
						category_zone_ids[zone_id] = true
					end
					-- Collect zones that belong to this category
					local sorted_zones = {}
					for zone_name, zone_id in pairs(zones) do
						if category_zone_ids[zone_id] then
							table.insert(sorted_zones, { name = zone_name, id = zone_id })
						end
					end
					table.sort(sorted_zones, function(a, b) return a.name < b.name end)
					for _, zone in ipairs(sorted_zones) do
						info = UIDropDownMenu_CreateInfo()
						info.text = zone.name
						info.checked = font_container.zone_dd.val == zone.name
						info.func = function()
							font_container.zone_dd.val = zone.name
							UIDropDownMenu_SetText(font_container.zone_dd, font_container.zone_dd.val)
							setFilter()
							CloseDropDownMenus()
						end
						UIDropDownMenu_AddButton(info, level)
					end
				end
			end
		end
	end

	font_container.zone_dd:SetPoint("TOPLEFT", scroll_container.frame, "TOPLEFT", 280, -20)
	UIDropDownMenu_SetText(font_container.zone_dd, font_container.zone_dd.val ~= "" and font_container.zone_dd.val or "All")
	UIDropDownMenu_SetWidth(font_container.zone_dd, 80)
	UIDropDownMenu_Initialize(font_container.zone_dd, zoneDD)
	UIDropDownMenu_JustifyText(font_container.zone_dd, "LEFT")

	if font_container.zone_dd.text == nil then
		font_container.zone_dd.text = font_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	end

	font_container.zone_dd.text:SetPoint("LEFT", font_container.zone_dd, "LEFT", 20, 20)
	font_container.zone_dd.text:SetFont(Deathlog_L.menu_font, 12, "")
	font_container.zone_dd.text:SetTextColor(255 / 255, 215 / 255, 0)
	font_container.zone_dd.text:SetText("Zone")
	font_container.zone_dd.text:Show()

	--- Instance dropdown
	if font_container.instance_dd == nil then
		font_container.instance_dd = CreateFrame("Frame", nil, font_container, "UIDropDownMenuTemplate")
		font_container.instance_dd.val = ""
	end

	-- Helper: get instance IDs from a category that exist in a specific expansion
	local function getInstanceCategoryForExpansion(category_name, expansion_id)
		local category_ids = instance_categories and instance_categories[category_name]
		if not category_ids then return {} end
		
		local expansion_instances = instance_to_id[expansion_id]
		if not expansion_instances then return {} end
		
		-- Build reverse lookup: instance_id -> true for this expansion
		local expansion_instance_ids = {}
		for _, instance_id in pairs(expansion_instances) do
			expansion_instance_ids[instance_id] = true
		end
		
		-- Filter category IDs to only those in this expansion
		local filtered = {}
		for _, instance_id in ipairs(category_ids) do
			if expansion_instance_ids[instance_id] then
				table.insert(filtered, instance_id)
			end
		end
		return filtered
	end

	local function instanceDD(frame, level, menuList)
		local info = UIDropDownMenu_CreateInfo()

		local function setFilter()
			local key = font_container.instance_dd.val
			if key ~= "" then
				zone_filter = function(_, _entry)
					-- Look up zone in all expansions
					for _, zones in pairs(zone_to_id) do
						if zones[key] and zones[key] == tonumber(_entry["map_id"]) then
							return true
						end
					end
					-- Look up instance in all expansions
					for _, instances in pairs(instance_to_id) do
						if instances[key] and instances[key] == tonumber(_entry["instance_id"]) then
							return true
						end
					end
					return false
				end
				clearDeathlogMenuLogData()
				setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
			else
				zone_filter = nil
				clearDeathlogMenuLogData()
				setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
			end
		end

		-- Count how many expansions we have
		local expansion_count = 0
		local single_expansion_id = nil
		for expansion_id, _ in pairs(instance_to_id) do
			expansion_count = expansion_count + 1
			single_expansion_id = expansion_id
		end
		local skip_expansion_layer = (expansion_count == 1)

		if level == 1 or level == nil then
			-- "All" option at top level
			info.text, info.checked, info.func =
				"All", font_container.instance_dd.val == "", function()
					font_container.instance_dd.val = ""
					UIDropDownMenu_SetText(font_container.instance_dd, "All")
					setFilter()
				end
			UIDropDownMenu_AddButton(info, level)

			if skip_expansion_layer then
				-- Only one expansion: show instance types directly at level 1
				if instance_categories then
					local category_order = { "Dungeon", "Raid", "Battleground", "Arena" }
					for _, category_name in ipairs(category_order) do
						local filtered_instances = getInstanceCategoryForExpansion(category_name, single_expansion_id)
						if #filtered_instances > 0 then
							info = UIDropDownMenu_CreateInfo()
							info.text = category_name
							info.hasArrow = true
							info.notCheckable = true
							info.menuList = { type = "instance_type", expansion_id = single_expansion_id, category_name = category_name, instances = filtered_instances }
							UIDropDownMenu_AddButton(info, level)
						end
					end
				else
					-- No categories: show all instances directly
					local instances = instance_to_id[single_expansion_id]
					if instances then
						local sorted_instances = {}
						for instance_name, instance_id in pairs(instances) do
							table.insert(sorted_instances, { name = instance_name, id = instance_id })
						end
						table.sort(sorted_instances, function(a, b) return a.name < b.name end)
						for _, instance in ipairs(sorted_instances) do
							info = UIDropDownMenu_CreateInfo()
							info.text = instance.name
							info.checked = font_container.instance_dd.val == instance.name
							info.func = function()
								font_container.instance_dd.val = instance.name
								UIDropDownMenu_SetText(font_container.instance_dd, font_container.instance_dd.val)
								setFilter()
								CloseDropDownMenus()
							end
							UIDropDownMenu_AddButton(info, level)
						end
					end
				end
			else
				-- Multiple expansions: show expansion submenus (sorted by expansion_id)
				local sorted_expansion_ids = {}
				for expansion_id, _ in pairs(instance_to_id) do
					table.insert(sorted_expansion_ids, expansion_id)
				end
				table.sort(sorted_expansion_ids)
				for _, expansion_id in ipairs(sorted_expansion_ids) do
					info = UIDropDownMenu_CreateInfo()
					info.text = _G["EXPANSION_NAME" .. expansion_id]
					info.hasArrow = true
					info.notCheckable = true
					info.menuList = { type = "expansion", id = expansion_id }
					UIDropDownMenu_AddButton(info, level)
				end
			end
		elseif level == 2 then
			local menu_type = menuList and menuList.type

			if menu_type == "instance_type" then
				-- Coming from either: single-expansion level 1, or multi-expansion level 2
				-- Show individual instances for selected type/category
				local category_instances = menuList.instances
				local expansion_id = menuList.expansion_id
				if category_instances and expansion_id then
					local instances = instance_to_id[expansion_id]
					if instances then
						local category_instance_ids = {}
						for _, inst_id in ipairs(category_instances) do
							category_instance_ids[inst_id] = true
						end
						local sorted_instances = {}
						for instance_name, instance_id in pairs(instances) do
							if category_instance_ids[instance_id] then
								table.insert(sorted_instances, { name = instance_name, id = instance_id })
							end
						end
						table.sort(sorted_instances, function(a, b) return a.name < b.name end)
						for _, instance in ipairs(sorted_instances) do
							info = UIDropDownMenu_CreateInfo()
							info.text = instance.name
							info.checked = font_container.instance_dd.val == instance.name
							info.func = function()
								font_container.instance_dd.val = instance.name
								UIDropDownMenu_SetText(font_container.instance_dd, font_container.instance_dd.val)
								setFilter()
								CloseDropDownMenus()
							end
							UIDropDownMenu_AddButton(info, level)
						end
					end
				end
			elseif menu_type == "expansion" then
				-- Multi-expansion path: show instance type submenus
				local expansion_id = menuList.id
				if instance_categories then
					local category_order = { "Dungeon", "Raid", "Battleground", "Arena" }
					for _, category_name in ipairs(category_order) do
						local filtered_instances = getInstanceCategoryForExpansion(category_name, expansion_id)
						if #filtered_instances > 0 then
							info = UIDropDownMenu_CreateInfo()
							info.text = category_name
							info.hasArrow = true
							info.notCheckable = true
							info.menuList = { type = "instance_type", expansion_id = expansion_id, category_name = category_name, instances = filtered_instances }
							UIDropDownMenu_AddButton(info, level)
						end
					end
				end

				-- Fallback if no categories: show all instances directly
				if not instance_categories then
					local instances = instance_to_id[expansion_id]
					if instances then
						local sorted_instances = {}
						for instance_name, instance_id in pairs(instances) do
							table.insert(sorted_instances, { name = instance_name, id = instance_id })
						end
						table.sort(sorted_instances, function(a, b) return a.name < b.name end)
						for _, instance in ipairs(sorted_instances) do
							info = UIDropDownMenu_CreateInfo()
							info.text = instance.name
							info.checked = font_container.instance_dd.val == instance.name
							info.func = function()
								font_container.instance_dd.val = instance.name
								UIDropDownMenu_SetText(font_container.instance_dd, font_container.instance_dd.val)
								setFilter()
								CloseDropDownMenus()
							end
							UIDropDownMenu_AddButton(info, level)
						end
					end
				end
			end
		elseif level == 3 then
			-- Instances for selected type/category
			local category_instances = menuList and menuList.instances
			local expansion_id = menuList and menuList.expansion_id
			if category_instances and expansion_id then
				local instances = instance_to_id[expansion_id]
				if instances then
					-- Build lookup of instance IDs in this category
					local category_instance_ids = {}
					for _, inst_id in ipairs(category_instances) do
						category_instance_ids[inst_id] = true
					end
					-- Collect instances that belong to this category
					local sorted_instances = {}
					for instance_name, instance_id in pairs(instances) do
						if category_instance_ids[instance_id] then
							table.insert(sorted_instances, { name = instance_name, id = instance_id })
						end
					end
					table.sort(sorted_instances, function(a, b) return a.name < b.name end)
					for _, instance in ipairs(sorted_instances) do
						info = UIDropDownMenu_CreateInfo()
						info.text = instance.name
						info.checked = font_container.instance_dd.val == instance.name
						info.func = function()
							font_container.instance_dd.val = instance.name
							UIDropDownMenu_SetText(font_container.instance_dd, font_container.instance_dd.val)
							setFilter()
							CloseDropDownMenus()
						end
						UIDropDownMenu_AddButton(info, level)
					end
				end
			end
		end
	end

	font_container.instance_dd:SetPoint("TOPLEFT", scroll_container.frame, "TOPLEFT", 375, -20)
	UIDropDownMenu_SetText(font_container.instance_dd, font_container.instance_dd.val ~= "" and font_container.instance_dd.val or "All")
	UIDropDownMenu_SetWidth(font_container.instance_dd, 80)
	UIDropDownMenu_Initialize(font_container.instance_dd, instanceDD)
	UIDropDownMenu_JustifyText(font_container.instance_dd, "LEFT")

	if font_container.instance_dd.text == nil then
		font_container.instance_dd.text = font_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	end

	font_container.instance_dd.text:SetPoint("LEFT", font_container.instance_dd, "LEFT", 20, 20)
	font_container.instance_dd.text:SetFont(Deathlog_L.menu_font, 12, "")
	font_container.instance_dd.text:SetTextColor(255 / 255, 215 / 255, 0)
	font_container.instance_dd.text:SetText("Instance")
	font_container.instance_dd.text:Show()

	-- Min lvl search
	if font_container.min_level_box == nil then
		font_container.min_level_box = CreateFrame("EditBox", nil, font_container, "InputBoxTemplate")
	end
	if font_container.min_level_box.text == nil then
		font_container.min_level_box.text = font_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	end
	font_container.min_level_box:SetPoint("TOPLEFT", font_container.instance_dd, "TOPRIGHT", 0, 0)
	font_container.min_level_box:SetPoint("BOTTOMLEFT", font_container.instance_dd, "TOPRIGHT", 0, -30)
	font_container.min_level_box:SetWidth(50)
	font_container.min_level_box:SetFont(Deathlog_L.menu_font, 14, "")
	font_container.min_level_box:SetMovable(false)
	font_container.min_level_box:SetBlinkSpeed(1)
	font_container.min_level_box:SetAutoFocus(false)
	font_container.min_level_box:SetMultiLine(false)
	font_container.min_level_box:SetMaxLetters(20)
	font_container.min_level_box:SetScript("OnEnterPressed", function()
		local text = font_container.min_level_box:GetText()
		if #text > 0 then
			min_level_filter = function(_, _entry)
				if _entry["level"] and tonumber(text) ~= nil and _entry["level"] >= tonumber(text) then
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

	font_container.min_level_box.text:SetPoint("LEFT", font_container.min_level_box, "LEFT", 0, 15)
	font_container.min_level_box.text:SetFont(Deathlog_L.menu_font, 12, "")
	font_container.min_level_box.text:SetTextColor(255 / 255, 215 / 255, 0)
	font_container.min_level_box.text:SetText("Min. Lvl")
	font_container.min_level_box.text:Show()

	-- Max lvl search
	if font_container.max_level_box == nil then
		font_container.max_level_box = CreateFrame("EditBox", nil, font_container, "InputBoxTemplate")
	end
	if font_container.max_level_box.text == nil then
		font_container.max_level_box.text = font_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	end
	font_container.max_level_box:SetPoint("TOPLEFT", font_container.min_level_box, "TOPRIGHT", 5, 0)
	font_container.max_level_box:SetPoint("BOTTOMLEFT", font_container.min_level_box, "TOPRIGHT", 5, -30)
	font_container.max_level_box:SetWidth(50)
	font_container.max_level_box:SetFont(Deathlog_L.menu_font, 14, "")
	font_container.max_level_box:SetMovable(false)
	font_container.max_level_box:SetBlinkSpeed(1)
	font_container.max_level_box:SetAutoFocus(false)
	font_container.max_level_box:SetMultiLine(false)
	font_container.max_level_box:SetMaxLetters(20)
	font_container.max_level_box:SetScript("OnEnterPressed", function()
		local text = font_container.max_level_box:GetText()
		if #text > 0 then
			max_level_filter = function(_, _entry)
				if _entry["level"] and tonumber(text) ~= nil and _entry["level"] <= tonumber(text) then
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

	font_container.max_level_box.text:SetPoint("LEFT", font_container.max_level_box, "LEFT", 0, 15)
	font_container.max_level_box.text:SetFont(Deathlog_L.menu_font, 12, "")
	font_container.max_level_box.text:SetTextColor(255 / 255, 215 / 255, 0)
	font_container.max_level_box.text:SetText("Max. Lvl")
	font_container.max_level_box.text:Show()

	-- Player search
	if font_container.player_search_box == nil then
		font_container.player_search_box = CreateFrame("EditBox", nil, font_container, "InputBoxTemplate")
	end
	if font_container.player_search_box.text == nil then
		font_container.player_search_box.text = font_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	end
	font_container.player_search_box:SetPoint("TOPLEFT", font_container.max_level_box, "TOPRIGHT", 5, 0)
	font_container.player_search_box:SetPoint("BOTTOMLEFT", font_container.max_level_box, "TOPRIGHT", 5, -30)
	font_container.player_search_box:SetWidth(100)
	font_container.player_search_box:SetFont(Deathlog_L.menu_font, 14, "")
	font_container.player_search_box:SetMovable(false)
	font_container.player_search_box:SetBlinkSpeed(1)
	font_container.player_search_box:SetAutoFocus(false)
	font_container.player_search_box:SetMultiLine(false)
	font_container.player_search_box:SetMaxLetters(20)
	font_container.player_search_box:SetScript("OnEnterPressed", function()
		local text = font_container.player_search_box:GetText()
		if #text > 0 then
			name_filter = function(_, _entry)
				if string.find(string.lower(_entry["name"] or ""), string.lower(text)) then
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

	font_container.player_search_box.text:SetPoint("LEFT", font_container.player_search_box, "LEFT", 0, 15)
	font_container.player_search_box.text:SetFont(Deathlog_L.menu_font, 12, "")
	font_container.player_search_box.text:SetTextColor(255 / 255, 215 / 255, 0)
	font_container.player_search_box.text:SetText("Player Name")
	font_container.player_search_box.text:Show()

	-- guild search
	if font_container.guild_search_box == nil then
		font_container.guild_search_box = CreateFrame("EditBox", nil, font_container, "InputBoxTemplate")
	end
	if font_container.guild_search_box.text == nil then
		font_container.guild_search_box.text = font_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	end
	font_container.guild_search_box:SetPoint("TOPLEFT", font_container.player_search_box, "TOPRIGHT", 5, 0)
	font_container.guild_search_box:SetPoint("BOTTOMLEFT", font_container.player_search_box, "TOPRIGHT", 5, -30)
	font_container.guild_search_box:SetWidth(100)
	font_container.guild_search_box:SetFont(Deathlog_L.menu_font, 14, "")
	font_container.guild_search_box:SetMovable(false)
	font_container.guild_search_box:SetBlinkSpeed(1)
	font_container.guild_search_box:SetAutoFocus(false)
	font_container.guild_search_box:SetMultiLine(false)
	font_container.guild_search_box:SetMaxLetters(20)
	font_container.guild_search_box:SetScript("OnEnterPressed", function()
		local text = font_container.guild_search_box:GetText()
		if #text > 0 then
			guild_filter = function(_, _entry)
				if string.find(string.lower(_entry["guild"] or ""), string.lower(text)) then
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

	font_container.guild_search_box.text:SetPoint("LEFT", font_container.guild_search_box, "LEFT", 0, 15)
	font_container.guild_search_box.text:SetFont(Deathlog_L.menu_font, 12, "")
	font_container.guild_search_box.text:SetTextColor(255 / 255, 215 / 255, 0)
	font_container.guild_search_box.text:SetText("Guild Name")
	font_container.guild_search_box.text:Show()

	-- source search
	if font_container.death_source_box == nil then
		font_container.death_source_box = CreateFrame("EditBox", nil, font_container, "InputBoxTemplate")
	end
	if font_container.death_source_box.text == nil then
		font_container.death_source_box.text = font_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	end
	font_container.death_source_box:SetPoint("TOPLEFT", font_container.guild_search_box, "TOPRIGHT", 5, 0)
	font_container.death_source_box:SetPoint("BOTTOMLEFT", font_container.guild_search_box, "TOPRIGHT", 5, -30)
	font_container.death_source_box:SetWidth(100)
	font_container.death_source_box:SetFont(Deathlog_L.menu_font, 14, "")
	font_container.death_source_box:SetMovable(false)
	font_container.death_source_box:SetBlinkSpeed(1)
	font_container.death_source_box:SetAutoFocus(false)
	font_container.death_source_box:SetMultiLine(false)
	font_container.death_source_box:SetMaxLetters(20)
	font_container.death_source_box:SetScript("OnEnterPressed", function()
		local text = font_container.death_source_box:GetText()
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

	font_container.death_source_box.text:SetPoint("LEFT", font_container.death_source_box, "LEFT", 0, 15)
	font_container.death_source_box.text:SetFont(Deathlog_L.menu_font, 12, "")
	font_container.death_source_box.text:SetTextColor(255 / 255, 215 / 255, 0)
	font_container.death_source_box.text:SetText("Death Source")
	font_container.death_source_box.text:Show()

	if font_container.last_words_check_box == nil then
		font_container.last_words_check_box =
			CreateFrame("CheckButton", "deathlog_last_words_check_box", font_container, "ChatConfigCheckButtonTemplate")
	end
	if font_container.last_words_check_box.text == nil then
		font_container.last_words_check_box.text = font_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	end

	font_container.last_words_check_box:SetPoint("TOPLEFT", font_container.death_source_box, "TOPLEFT", 98, -5)
	font_container.last_words_check_box:SetChecked(false)
	font_container.last_words_check_box:SetScript("OnClick", function()
		if font_container.last_words_check_box:GetChecked() == true then
			last_words_filter = function(_, _entry)
				if _entry and _entry["last_words"] and _entry["last_words"] ~= "" then
					return true
				end
				return false
			end

			clearDeathlogMenuLogData()
			setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
		else
			last_words_filter = nil
			clearDeathlogMenuLogData()
			setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
		end
	end)

	font_container.last_words_check_box.text:SetPoint("LEFT", font_container.last_words_check_box, "LEFT", 21, 0)
	font_container.last_words_check_box.text:SetFont(Deathlog_L.menu_font, 12, "")
	font_container.last_words_check_box.text:SetTextColor(255 / 255, 215 / 255, 0)
	font_container.last_words_check_box.text:SetText("Last Words Only")
	font_container.last_words_check_box.text:Show()

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

	header_label:SetFont(main_font, 16, "")
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
	for i = 1, max_rows do
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
		_entry:SetFont(main_font, 16, "")
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
			GameTooltip:Hide()
		end)

		_entry:SetCallback("OnClick", function()
			local click_type = GetMouseButtonClicked()

			if click_type == "LeftButton" then
			elseif click_type == "RightButton" then
				-- Only show context menu if this row has data
				local nameText = font_strings[i] and font_strings[i]["Name"] and font_strings[i]["Name"]:GetText()
				if nameText and strtrim(nameText) ~= "" then
					death_tomb_frame.map_id = font_strings[i].map_id
					death_tomb_frame.coordinates = font_strings[i].map_id_coords_x and { font_strings[i].map_id_coords_x, font_strings[i].map_id_coords_y } or nil
					death_tomb_frame.clicked_name = nameText

					local dropDown = CreateFrame("Frame", "WPDemoContextMenu", UIParent, "UIDropDownMenuTemplate")
					-- Bind an initializer function to the dropdown; see previous sections for initializer function examples.
					UIDropDownMenu_Initialize(dropDown, WPDropDownDemo_Menu, "MENU")
					ToggleDropDownMenu(1, nil, dropDown, "cursor", 3, -3)
				end
			end
		end)

		_entry:SetCallback("OnEnter", function(widget)
			-- Only show tooltip if this row has data
			local nameText = font_strings[i] and font_strings[i]["Name"] and font_strings[i]["Name"]:GetText()
			if not (nameText and strtrim(nameText) ~= "") then
				return
			end

			GameTooltip_SetDefaultAnchor(GameTooltip, WorldFrame)
			local _name = ""
			local _level = ""
			local _guild = ""
			local _race = ""
			local _class = ""
			local _source = ""
			local _zone = ""
			local _date = ""
			local _playtime = ""
			local _last_words = ""
			if font_strings[i] and font_strings[i]["Name"] then
				_name = font_strings[i]["Name"]:GetText() or ""
			end
			if font_strings[i] and font_strings[i]["Lvl"] then
				_level = font_strings[i]["Lvl"]:GetText() or ""
			end
			if font_strings[i] and font_strings[i]["Guild"] then
				_guild = font_strings[i]["Guild"]:GetText() or ""
			end
			if font_strings[i] and font_strings[i]["Race"] then
				_race = font_strings[i]["Race"]:GetText() or ""
			end
			if font_strings[i] and font_strings[i]["Class"] then
				_class = font_strings[i]["Class"]:GetText() or ""
			end
			if font_strings[i] and font_strings[i]["Death Source"] then
				_source = font_strings[i]["Death Source"]:GetText() or ""
			end
			if font_strings[i] and font_strings[i]["Zone/Instance"] then
				_zone = font_strings[i]["Zone/Instance"]:GetText() or ""
			end
			if font_strings[i] and font_strings[i]["Date"] then
				_date = font_strings[i]["Date"]:GetText() or ""
			end
			if font_strings[i] and font_strings[i]["Playtime"] then
				_playtime = font_strings[i]["Playtime"]:GetText() or ""
			end
			if font_strings[i] and font_strings[i]["Last Words"] then
				_last_words = font_strings[i]["Last Words"]:GetText() or ""
			end
			deathlog_setTooltip(_name, _level, _guild, _race, _class, _source, _zone, _date, _playtime, _last_words)
			GameTooltip:Show()
		end)

		deathlog_group:SetScroll(0)
		deathlog_group.scrollbar:Hide()
		deathlog_group:AddChild(_entry)
	end
	scroll_frame.scrollbar:Hide()

	if font_container.page_str == nil then
		font_container.page_str = font_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		font_container.page_str:SetText("Page " .. page_number)
		font_container.page_str:SetFont(Deathlog_L.menu_font, 14, "")
		font_container.page_str:SetJustifyV("BOTTOM")
		font_container.page_str:SetJustifyH("CENTER")
		font_container.page_str:SetTextColor(0.7, 0.7, 0.7)
		font_container.page_str:SetPoint("TOP", font_container, "TOP", 0, -444)
		font_container.page_str:Show()
	end

	if font_container.prev_button == nil then
		font_container.prev_button = CreateFrame("Button", nil, font_container)
		font_container.prev_button:SetPoint("CENTER", font_container.page_str, "CENTER", -50, 0)
		font_container.prev_button:SetWidth(25)
		font_container.prev_button:SetHeight(25)
		font_container.prev_button:SetNormalTexture("Interface/Buttons/UI-SpellbookIcon-PrevPage-Up.PNG")
		font_container.prev_button:SetHighlightTexture("Interface/Buttons/UI-SpellbookIcon-PrevPage-Up.PNG")
		font_container.prev_button:SetPushedTexture("Interface/Buttons/UI-SpellbookIcon-PrevPage-Down.PNG")
	end

	font_container.prev_button:SetScript("OnClick", function()
		if page_number > 1 then
			page_number = page_number - 1
			clearDeathlogMenuLogData(true)
			-- Use cached results instead of re-filtering
			displayPageFromCache()
		end
	end)

	if font_container.next_button == nil then
		font_container.next_button = CreateFrame("Button", nil, font_container)
		font_container.next_button:SetPoint("CENTER", font_container.page_str, "CENTER", 50, 0)
		font_container.next_button:SetWidth(25)
		font_container.next_button:SetHeight(25)
		font_container.next_button:SetNormalTexture("Interface/Buttons/UI-SpellbookIcon-NextPage-Up.PNG")
		font_container.next_button:SetHighlightTexture("Interface/Buttons/UI-SpellbookIcon-NextPage-Up.PNG")
		font_container.next_button:SetPushedTexture("Interface/Buttons/UI-SpellbookIcon-NextPage-Down.PNG")
	end

	font_container.next_button:SetScript("OnClick", function()
		if page_number < total_pages then
			page_number = page_number + 1
			clearDeathlogMenuLogData(true)
			-- Use cached results instead of re-filtering
			displayPageFromCache()
		end
	end)

	deathlog_group.frame:HookScript("OnHide", function()
		font_container:Hide()
	end)
end

local function drawWatchListTab(container)
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
	title_label:SetText("Watch List (Experimental)")
	title_label.label:SetFont(Deathlog_L.menu_font, 24, "")
	scroll_frame:AddChild(title_label)

	local description_label = AceGUI:Create("Label")
	description_label:SetFullWidth(true)
	description_label:SetText(
		"[Experimental] Add players of interest to a watch list.  If a player on this list dies while you are logged off, the deathlog system will try to notify you when you log in.  Add a description and icon to remember the player by."
	)
	description_label.label:SetFont(Deathlog_L.menu_font, 14, "")
	description_label.label:SetTextColor(0.6, 0.6, 0.6, 1.0)
	description_label.label:SetJustifyH("CENTER")
	scroll_frame:AddChild(description_label)

	local elements = {
		Deathlog_WatchList(),
	}

	local function updateElements()
		for _, v in ipairs(elements) do
			v.updateMenuElement(scroll_frame)
		end
	end

	updateElements()

	scroll_frame.frame:HookScript("OnHide", function()
		for _, v in ipairs(elements) do
			v:Hide()
		end
	end)
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
	title_label.label:SetFont(Deathlog_L.menu_font, 24, "")
	scroll_frame:AddChild(title_label)
	local function modifyTitle(zone)
		title_label:SetText("Death Statistics - " .. zone)
	end

	local description_label = AceGUI:Create("Label")
	description_label:SetFullWidth(true)
	description_label:SetText("Death Statistics - Azeroth")
	description_label.label:SetFont(Deathlog_L.menu_font, 14, "")
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
		local creature_name = id_to_npc[creature_id] or deathlog_environment_damage[creature_id] or "Unknown"
		description_label:SetText(
			string.format("%.2f", deaths_by_creature / all_deaths * 100)
				.. "% of all deaths are caused by "
				.. creature_name
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
	title_label.label:SetFont(Deathlog_L.menu_font, 24, "")
	scroll_frame:AddChild(title_label)
	local function modifyTitle(zone)
		title_label:SetText("Death Statistics - " .. zone)
	end

	local description_label = AceGUI:Create("Label")
	description_label:SetFullWidth(true)
	description_label:SetText("Death Statistics - Azeroth")
	description_label.label:SetFont(Deathlog_L.menu_font, 14, "")
	description_label.label:SetTextColor(0.6, 0.6, 0.6, 1.0)
	description_label.label:SetJustifyH("CENTER")
	scroll_frame:AddChild(description_label)
	local function modifyDescription(map_id, zone)
		local mid = deathlog_normalize_map_id_for_stats(map_id)
		local deaths_in_zone = 0
		if _stats["all"][mid] then
			deaths_in_zone = _stats["all"][mid]["all"]["all"]["num_entries"]
		end
		local all_deaths = _stats["all"]["all"]["all"]["all"]["num_entries"]
		description_label:SetText(
			string.format("%.2f", deaths_in_zone / all_deaths * 100) .. "% of all deaths occur in " .. zone .. "."
		)
	end

	-- Create "no data" message frame
	local no_data_frame = CreateFrame("Frame", nil, scroll_frame.frame)
	no_data_frame:SetSize(300, 100)
	no_data_frame:SetPoint("TOPRIGHT", scroll_frame.frame, "TOPRIGHT", -80, -250)
	no_data_frame:Hide()

	local no_data_text = no_data_frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	no_data_text:SetPoint("CENTER", no_data_frame, "CENTER", 0, 0)
	no_data_text:SetFont(Deathlog_L.menu_font, 16, "")
	no_data_text:SetTextColor(0.6, 0.6, 0.6, 1)
	no_data_text:SetText("No death data available\nfor this zone yet.")

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
			["stats"] = _stats,
			["log_normal_params"] = _log_normal_params,
		}

		-- Check if data exists for this zone
		local mid = deathlog_normalize_map_id_for_stats(map_id)
		local has_data = _stats and _stats["all"] and _stats["all"][mid]

		if has_data then
			-- Show stats elements, hide no data message
			no_data_frame:Hide()
			for _, v in ipairs(stats_menu_elements) do
				v.updateMenuElement(scroll_frame, map_id, stats_tbl, setMapRegion)
			end
		else
			-- Hide stats elements (except map), show no data message
			stats_menu_elements[1].updateMenuElement(scroll_frame, map_id, stats_tbl, setMapRegion)
			for i = 2, #stats_menu_elements do
				stats_menu_elements[i]:Hide()
			end
			no_data_frame:Show()
		end
	end

	setMapRegion(deathlog_ROOT_MAP_ID, deathlog_ROOT_MAP_NAME)

	scroll_frame.frame:HookScript("OnHide", function()
		for _, v in ipairs(stats_menu_elements) do
			v:Hide()
		end
		no_data_frame:Hide()
		-- Clear the map highlight overlay when switching tabs
		Deathlog_MapContainer_clearHighlight()
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
	title_label.label:SetFont(Deathlog_L.menu_font, 24, "")
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

	local function setMapRegion(map_id, name, model, view)
		current_map_id = map_id
		if name then
			modifyTitle(name)
		end
		local stats_tbl = {
			["stats"] = _stats,
			["log_normal_params"] = _log_normal_params,
		}
		for _, v in ipairs(stats_menu_elements) do
			v.updateMenuElement(scroll_frame, map_id, stats_tbl, setMapRegion, model, view)
		end
	end

	setMapRegion(1, "Warrior", "LogNormal", "Survival")

	scroll_frame.frame:HookScript("OnHide", function()
		for _, v in ipairs(stats_menu_elements) do
			v:Hide()
		end
	end)
end

local function drawInstanceStatisticsTab(container)
	local update_functions = {}
	local scroll_container = AceGUI:Create("SimpleGroup")
	local current_instance_id = deathlog_ALL_INSTANCES_ID
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
	title_label.label:SetFont(Deathlog_L.menu_font, 24, "")
	scroll_frame:AddChild(title_label)
	local function modifyTitle(zone)
		title_label:SetText("Death Statistics - " .. zone)
	end

	local description_label = AceGUI:Create("Label")
	description_label:SetFullWidth(true)
	description_label:SetText("")
	description_label.label:SetFont(Deathlog_L.menu_font, 14, "")
	description_label.label:SetTextColor(0.6, 0.6, 0.6, 1.0)
	description_label.label:SetJustifyH("CENTER")
	scroll_frame:AddChild(description_label)
	local function modifyDescription(map_id, zone)
		local mid = deathlog_normalize_map_id_for_stats(map_id)
		local deaths_in_zone = 0
		if _stats["all"][mid] then
			deaths_in_zone = _stats["all"][mid]["all"]["all"]["num_entries"]
		end
		local all_deaths = _stats["all"]["all"]["all"]["all"]["num_entries"]
		description_label:SetText(
			string.format("%.2f", deaths_in_zone / all_deaths * 100) .. "% of all deaths occur in " .. zone .. "."
		)
	end

	-- Create "no data" message frame
	local no_data_frame = CreateFrame("Frame", nil, scroll_frame.frame)
	no_data_frame:SetSize(300, 100)
	no_data_frame:SetPoint("TOPRIGHT", scroll_frame.frame, "TOPRIGHT", -80, -250)
	no_data_frame:Hide()

	local no_data_text = no_data_frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	no_data_text:SetPoint("CENTER", no_data_frame, "CENTER", 0, 0)
	no_data_text:SetFont(Deathlog_L.menu_font, 16, "")
	no_data_text:SetTextColor(0.6, 0.6, 0.6, 1)
	no_data_text:SetText("No death data available\nfor this instance yet.")

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
			modifyDescription(map_id, name)
		end
		local stats_tbl = {
			["stats"] = _stats,
			["log_normal_params"] = _log_normal_params,
		}

		-- Check if data exists for this instance
		local has_data = _stats and _stats["all"] and _stats["all"][map_id]

		if has_data then
			-- Show stats elements, hide no data message
			no_data_frame:Hide()
			for i, v in ipairs(stats_menu_elements) do
				v.updateMenuElement(scroll_frame, map_id, stats_tbl, setMapRegion)
				if i > 1 then
					v:Show()
				end
			end
		else
			-- Hide stats elements (except instance selector), show no data message
			stats_menu_elements[1].updateMenuElement(scroll_frame, map_id, stats_tbl, setMapRegion)
			for i = 2, #stats_menu_elements do
				stats_menu_elements[i]:Hide()
			end
			no_data_frame:Show()
		end
	end

	setMapRegion(deathlog_ALL_INSTANCES_ID, "Instances")

	scroll_frame.frame:HookScript("OnHide", function()
		for _, v in ipairs(stats_menu_elements) do
			v:Hide()
		end
		no_data_frame:Hide()
	end)
end

local function createDeathlogMenu()
	local ace_deathlog_menu = AceGUI:Create("DeathlogMenu")
	_G["AceDeathlogMenu"] = ace_deathlog_menu.frame -- Close on <ESC>
	tinsert(UISpecialFrames, "AceDeathlogMenu")

	ace_deathlog_menu:SetTitle("Deathlog")
	ace_deathlog_menu:SetVersion(C_AddOns.GetAddOnMetadata("Deathlog", "Version"))
	ace_deathlog_menu:SetStatusText("")
	ace_deathlog_menu:SetLayout("Flow")
	ace_deathlog_menu:SetHeight(_menu_height)
	ace_deathlog_menu:SetWidth(_menu_width)

	if ace_deathlog_menu.exit_button == nil then
		ace_deathlog_menu.exit_button = CreateFrame("Button", nil, ace_deathlog_menu.frame)
		ace_deathlog_menu.exit_button:SetPoint("TOPRIGHT", ace_deathlog_menu.frame, "TOPRIGHT", -8, -8)
		ace_deathlog_menu.exit_button:SetWidth(25)
		ace_deathlog_menu.exit_button:SetHeight(25)
		ace_deathlog_menu.exit_button:SetNormalTexture("Interface/Buttons/UI-SquareButton-Disabled.PNG")
		ace_deathlog_menu.exit_button:SetHighlightTexture("Interface/Buttons/UI-SquareButton-Up.PNG")
		ace_deathlog_menu.exit_button:SetPushedTexture("Interface/Buttons/UI-SquareButton-Down.PNG")
	end

	ace_deathlog_menu.exit_button:SetScript("OnClick", function()
		deathlog_menu:Hide()
	end)

	if ace_deathlog_menu.exit_button_x == nil then
		ace_deathlog_menu.exit_button_x = death_tomb_frame:CreateTexture(nil, "OVERLAY")
		ace_deathlog_menu.exit_button_x:SetParent(ace_deathlog_menu.exit_button)
		ace_deathlog_menu.exit_button_x:SetPoint("CENTER", ace_deathlog_menu.exit_button, "CENTER", 0, 0)
		ace_deathlog_menu.exit_button_x:SetWidth(10)
		ace_deathlog_menu.exit_button_x:SetHeight(10)
		ace_deathlog_menu.exit_button_x:SetTexture("Interface/Buttons/UI-StopButton.PNG")
		ace_deathlog_menu.exit_button_x:SetVertexColor(1, 1, 1, 0.8)
	end

	deathlog_createInfoButton(ace_deathlog_menu)

	deathlog_tabcontainer = AceGUI:Create("DeathlogTabGroup") -- "InlineGroup" is also good
	local tab_table = Deathlog_L.tab_table
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
		elseif group == "WatchListTab" then
			drawWatchListTab(container)
		end
	end

	deathlog_tabcontainer:SetCallback("OnGroupSelected", SelectGroup)

	ace_deathlog_menu:AddChild(deathlog_tabcontainer)

	deathlog_cta_banner = Deathlog_CTABannerContainer()
	deathlog_cta_banner:SetParent(ace_deathlog_menu.frame)

	return ace_deathlog_menu
end

deathlog_menu = createDeathlogMenu()

function deathlogShowMenu(deathlog_data, stats, log_normal_params)
	deathlog_menu:Show()
	deathlog_cta_banner.updateMenuElement(deathlog_menu.frame)
	deathlog_tabcontainer:SelectTab("LogTab")
	_deathlog_data = deathlog_data
	_stats = stats
	_log_normal_params = log_normal_params
	setDeathlogMenuLogData(_deathlog_data)
end

function deathlogHideMenu()
	deathlog_menu:Hide()
end
