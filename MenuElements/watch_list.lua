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
local _watch_list_width = 1100
local _inner_watch_list_width = 800
local _watch_list_height = 600
local current_map_id = nil
local max_rows = 25
local page_number = 1
local environment_damage = {
	[-2] = "Drowning",
	[-3] = "Falling",
	[-4] = "Fatigue",
	[-5] = "Fire",
	[-6] = "Lava",
	[-7] = "Slime",
}

local selected_entry = 1

local main_font = Deathlog_L.main_font

local deathlog_tabcontainer = nil

local class_tbl = deathlog_class_tbl
local race_tbl = deathlog_race_tbl
local zone_tbl = deathlog_zone_tbl
local instance_tbl = deathlog_instance_tbl

local deathlog_watch_list = nil

local function EntryData(name, description)
	return {
		["name"] = name,
		["description"] = description,
		["status"] = "alive",
	}
end

deathlog_watchlist_entries = { EntryData("Yazpad", "WoW"), EntryData("Yaz", "Y") }

local subtitle_data = {
	{
		"Name",
		105,
		function(_entry)
			return _entry["name"] or ""
		end,
	},
	{
		"Description",
		300,
		function(_entry)
			return _entry["description"] or ""
		end,
	},
	{
		"Class",
		100,
		function(_entry)
			return _entry["description"] or ""
		end,
	},
	{
		"Lvl",
		50,
		function(_entry)
			return _entry["description"] or ""
		end,
	},
	{
		"Status",
		90,
		function(_entry)
			return _entry["description"] or ""
		end,
	},
	{
		"Last Words",
		310,
		function(_entry)
			return _entry["description"] or ""
		end,
	},
	{
		"Action",
		60,
		function(_entry)
			return _entry["description"] or ""
		end,
	},
}

local watch_list_frame = CreateFrame("Frame")
watch_list_frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
watch_list_frame:SetSize(100, 100)
watch_list_frame:Show()
local font_strings = {} -- idx/columns
local description_frame = {} -- idx/columns
local header_strings = {} -- columns
local row_backgrounds = {} --idx

local function setFontData(i, _entry)
	for _, v in ipairs(subtitle_data) do
		font_strings[i][v[1]]:SetText(v[3](_entry))
	end
end

local function refreshFontData()
	local i = 1
	for k, v in pairs(deathlog_watchlist_entries) do
		setFontData(i, v)
		i = i + 1
	end
end

local function DDMenu(frame, level, menuList)
	local info = UIDropDownMenu_CreateInfo()
	local function addDescription()
		local name = font_strings[selected_entry]["Name"]
		if deathlog_watchlist_entries[name] == nil then
			deathlog_watchlist_entries[name] = EntryData(name, "")
		end
		refreshFontData()
	end

	local function removePlayer()
		local name = font_strings[selected_entry]["Name"]
		deathlog_watchlist_entries[name] = nil
		refreshFontData()
	end

	if level == 1 then
		info.text, info.hasArrow, info.func, info.disabled = "Add Description", false, addDescription, false
		UIDropDownMenu_AddButton(info)
		info.text, info.hasArrow, info.func, info.disabled = "Remove Player", false, removePlayer, false
		UIDropDownMenu_AddButton(info)
	end
end

for idx, v in ipairs(subtitle_data) do
	header_strings[v[1]] = watch_list_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	if idx == 1 then
		header_strings[v[1]]:SetPoint("LEFT", watch_list_frame, "LEFT", 0, 0)
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
		font_strings[i][v[1]] = watch_list_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		if idx == 1 then
			font_strings[i][v[1]]:SetPoint("LEFT", watch_list_frame, "LEFT", 0, 0)
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
		font_strings[i][v[1]]:SetFont(main_font, 10, " A")
	end

	row_backgrounds[i] = watch_list_frame:CreateTexture(nil, "OVERLAY")
	row_backgrounds[i]:SetParent(watch_list_frame)
	row_backgrounds[i]:SetDrawLayer("OVERLAY", 2)
	row_backgrounds[i]:SetVertexColor(0.5, 0.5, 0.5, (i % 2) / 10)
	row_backgrounds[i]:SetHeight(16)
	row_backgrounds[i]:SetWidth(1200)
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
	if #ordered == 1 then
		deathlog_watch_list:SetStatusText(
			#ordered
				.. " search result/"
				.. precomputed_general_stats["all"]["all"]["all"]["all"]["num_entries"]
				.. " preprocessed"
		)
	else
		deathlog_watch_list:SetStatusText(
			#ordered
				.. " search results/"
				.. precomputed_general_stats["all"]["all"]["all"]["all"]["num_entries"]
				.. " preprocessed"
		)
	end
end

function watch_list_frame.updateMenuElement(scroll_frame)
	watch_list_frame:SetParent(scroll_frame.frame)
	watch_list_frame:Show()
	watch_list_frame:SetPoint("TOPLEFT", scroll_frame.frame, "TOPLEFT", 0, -80)
	watch_list_frame:SetWidth(1040)
	watch_list_frame:SetHeight(880)
	watch_list_frame:SetClipsChildren(false)

	if watch_list_frame.name_box == nil then
		watch_list_frame.name_box = CreateFrame("EditBox", nil, watch_list_frame, "InputBoxTemplate")
	end

	if watch_list_frame.description_box == nil then
		watch_list_frame.description_box = CreateFrame("EditBox", nil, watch_list_frame, "InputBoxTemplate")
	end

	if watch_list_frame.lvl_max_search_box == nil then
		watch_list_frame.lvl_max_search_box = CreateFrame("EditBox", nil, watch_list_frame, "InputBoxTemplate")
	end

	if watch_list_frame.name_box.text == nil then
		watch_list_frame.name_box.text = watch_list_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	end

	if watch_list_frame.description_box.text == nil then
		watch_list_frame.description_box.text = watch_list_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	end
	watch_list_frame.name_box:SetPoint("TOPLEFT", watch_list_frame, "TOPLEFT", 0, 20)
	watch_list_frame.name_box:SetPoint("BOTTOMLEFT", watch_list_frame, "TOPLEFT", 75, -50)
	watch_list_frame.name_box:SetWidth(100)
	watch_list_frame.name_box:SetFont(Deathlog_L.deadliest_creature_container_font, 14, "")
	watch_list_frame.name_box:SetMovable(false)
	watch_list_frame.name_box:SetBlinkSpeed(1)
	watch_list_frame.name_box:SetAutoFocus(false)
	watch_list_frame.name_box:SetMultiLine(false)
	watch_list_frame.name_box:SetMaxLetters(20)
	watch_list_frame.name_box:SetScript("OnEnterPressed", function()
		watch_list_frame.updateMenuElement(scroll_frame, _, stats_tbl, updateFun, filterFunction, metric, class_id)
	end)

	if 1 == 1 then
		return
	end

	watch_list_frame.name_box.text:SetPoint("LEFT", watch_list_frame.name_box, "LEFT", 0, 15)
	watch_list_frame.name_box.text:SetFont(Deathlog_L.deadliest_creature_container_font, 12, "")
	watch_list_frame.name_box.text:SetTextColor(255 / 255, 215 / 255, 0)
	watch_list_frame.name_box.text:Show()

	watch_list_frame.description_box:SetPoint("TOPLEFT", watch_list_frame.name_box, "TOPRIGHT", 10, 0)
	watch_list_frame.description_box:SetPoint("BOTTOMLEFT", watch_list_frame.name_box, "BOTTOMRIGHT", 10, 0)
	watch_list_frame.description_box:SetWidth(300)
	watch_list_frame.description_box:SetFont(Deathlog_L.deadliest_creature_container_font, 14, "")
	watch_list_frame.description_box:SetMovable(false)
	watch_list_frame.description_box:SetBlinkSpeed(1)
	watch_list_frame.description_box:SetAutoFocus(false)
	watch_list_frame.description_box:SetMultiLine(false)
	watch_list_frame.description_box:SetMaxLetters(20)
	watch_list_frame.description_box:SetScript("OnEnterPressed", function()
		watch_list_frame.updateMenuElement(scroll_frame, _, stats_tbl, updateFun, filterFunction, metric, class_id)
	end)

	watch_list_frame.description_box.text:SetPoint("LEFT", watch_list_frame.description_box, "LEFT", 0, 15)
	watch_list_frame.description_box.text:SetFont(Deathlog_L.deadliest_creature_container_font, 12, "")
	watch_list_frame.description_box.text:SetTextColor(255 / 255, 215 / 255, 0)
	watch_list_frame.description_box.text:Show()

	local last_frame = watch_list_frame
	for i = 1, max_rows do
		local idx = 101 - i
		local _entry = CreateFrame("Frame", nil, watch_list_frame)
		_entry:SetWidth(watch_list_frame:GetWidth())
		_entry:SetHeight(15)
		_entry:SetPoint("TOPLEFT", last_frame, "TOPLEFT", 0, -15)
		last_frame = _entry

		font_strings[i][subtitle_data[1][1]]:SetPoint("LEFT", _entry, "LEFT", 0, 0)
		font_strings[i][subtitle_data[1][1]]:Show()
		setFontData(1, EntryData("Yazpad", "B"))
		for _, v in ipairs(subtitle_data) do
			font_strings[i][v[1]]:SetParent(_entry)
		end

		row_backgrounds[i]:SetPoint("LEFT", _entry, "LEFT", 0, 0)
		row_backgrounds[i]:SetParent(_entry)
		row_backgrounds[i]:SetWidth(_entry:GetWidth())

		_entry:SetHeight(40)
		_entry:SetWidth(watch_list_frame:GetWidth())

		_entry:SetScript("OnMouseDown", function(self, button)
			if button == "RightButton" then
				selected_entry = i
				if font_strings[i]["Name"] == nil then
					return
				end
				local dropDown = CreateFrame("Frame", "WPDemoContextMenu", UIParent, "UIDropDownMenuTemplate")
				-- Bind an initializer function to the dropdown; see previous sections for initializer function examples.
				UIDropDownMenu_Initialize(dropDown, DDMenu, "MENU")
				ToggleDropDownMenu(1, nil, dropDown, "cursor", 3, -3)
			end
		end)

		-- _entry:SetCallback("OnLeave", function(widget)
		-- 	GameTooltip:Hide()
		-- end)

		-- _entry:SetCallback("OnClick", function()
		-- 	local click_type = GetMouseButtonClicked()

		-- 	if click_type == "LeftButton" then
		-- 	elseif click_type == "RightButton" then
		-- 		local dropDown = CreateFrame("Frame", "WPDemoContextMenu", UIParent, "UIDropDownMenuTemplate")
		-- 		-- Bind an initializer function to the dropdown; see previous sections for initializer function examples.
		-- 		UIDropDownMenu_Initialize(dropDown, WPDropDownDemo_Menu, "MENU")
		-- 		ToggleDropDownMenu(1, nil, dropDown, "cursor", 3, -3)
		-- 	end
		-- end)

		-- _entry:SetCallback("OnEnter", function(widget)
		-- 	GameTooltip_SetDefaultAnchor(GameTooltip, WorldFrame)
		-- 	local _name = ""
		-- 	local _level = ""
		-- 	local _guild = ""
		-- 	local _race = ""
		-- 	local _class = ""
		-- 	local _source = ""
		-- 	local _zone = ""
		-- 	local _date = ""
		-- 	local _last_words = ""
		-- 	if font_strings[i] and font_strings[i]["Name"] then
		-- 		_name = font_strings[i]["Name"]:GetText() or ""
		-- 	end
		-- 	if font_strings[i] and font_strings[i]["Lvl"] then
		-- 		_level = font_strings[i]["Lvl"]:GetText() or ""
		-- 	end
		-- 	if font_strings[i] and font_strings[i]["Guild"] then
		-- 		_guild = font_strings[i]["Guild"]:GetText() or ""
		-- 	end
		-- 	if font_strings[i] and font_strings[i]["Race"] then
		-- 		_race = font_strings[i]["Race"]:GetText() or ""
		-- 	end
		-- 	if font_strings[i] and font_strings[i]["Class"] then
		-- 		_class = font_strings[i]["Class"]:GetText() or ""
		-- 	end
		-- 	if font_strings[i] and font_strings[i]["Death Source"] then
		-- 		_source = font_strings[i]["Death Source"]:GetText() or ""
		-- 	end
		-- 	if font_strings[i] and font_strings[i]["Zone/Instance"] then
		-- 		_zone = font_strings[i]["Zone/Instance"]:GetText() or ""
		-- 	end
		-- 	if font_strings[i] and font_strings[i]["Date"] then
		-- 		_date = font_strings[i]["Date"]:GetText() or ""
		-- 	end
		-- 	if font_strings[i] and font_strings[i]["Last Words"] then
		-- 		_last_words = font_strings[i]["Last Words"]:GetText() or ""
		-- 	end

		-- 	if string.sub(_name, #_name) == "s" then
		-- 		GameTooltip:AddDoubleLine(_name .. "' Death", "Lvl. " .. _level, 1, 1, 1, 0.5, 0.5, 0.5)
		-- 	else
		-- 		GameTooltip:AddDoubleLine(_name .. "'s Death", "Lvl. " .. _level, 1, 1, 1, 0.5, 0.5, 0.5)
		-- 	end
		-- 	GameTooltip:AddLine("Name: " .. _name, 1, 1, 1)
		-- 	GameTooltip:AddLine("Guild: " .. _guild, 1, 1, 1)
		-- 	GameTooltip:AddLine("Race: " .. _race, 1, 1, 1)
		-- 	GameTooltip:AddLine("Class: " .. _class, 1, 1, 1)
		-- 	if deathlog_settings["colored_tooltips"] == nil or deathlog_settings["colored_tooltips"] == false then
		-- 		GameTooltip:AddLine("Killed by: " .. _source, 1, 1, 1)
		-- 		GameTooltip:AddLine("Zone/Instance: " .. _zone, 1, 1, 1)
		-- 	else
		-- 		GameTooltip:AddLine("Killed by: |cfffda172" .. _source .. "|r", 1, 1, 1)
		-- 		GameTooltip:AddLine("Zone/Instance: |cff9fe2bf" .. _zone .. "|r", 1, 1, 1)
		-- 	end
		-- 	GameTooltip:AddLine("Date: " .. _date, 1, 1, 1)
		-- 	if _last_words and _last_words ~= "" then
		-- 		GameTooltip:AddLine("Last words: " .. _last_words, 1, 1, 0, true)
		-- 	end

		-- 	GameTooltip:Show()
		-- end)
	end

	header_strings[subtitle_data[1][1]]:SetPoint("TOPLEFT", font_strings[1]["Name"], "TOPLEFT", 0, 40)
	header_strings[subtitle_data[1][1]]:Show()
	for _, v in ipairs(subtitle_data) do
		header_strings[v[1]]:SetParent(watch_list_frame)
		header_strings[v[1]]:SetText(v[1])
	end

	-- if watch_list_frame.page_str == nil then
	-- 	watch_list_frame.page_str = watch_list_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	-- 	watch_list_frame.page_str:SetText("Page " .. page_number)
	-- 	watch_list_frame.page_str:SetFont(L.menu_font, 14, "")
	-- 	watch_list_frame.page_str:SetJustifyV("BOTTOM")
	-- 	watch_list_frame.page_str:SetJustifyH("CENTER")
	-- 	watch_list_frame.page_str:SetTextColor(0.7, 0.7, 0.7)
	-- 	watch_list_frame.page_str:SetPoint("TOP", watch_list_frame, "TOP", 0, -444)
	-- 	watch_list_frame.page_str:Show()
	-- end

	-- if watch_list_frame.prev_button == nil then
	-- 	watch_list_frame.prev_button = CreateFrame("Button", nil, watch_list_frame)
	-- 	watch_list_frame.prev_button:SetPoint("CENTER", watch_list_frame.page_str, "CENTER", -50, 0)
	-- 	watch_list_frame.prev_button:SetWidth(25)
	-- 	watch_list_frame.prev_button:SetHeight(25)
	-- 	watch_list_frame.prev_button:SetNormalTexture("Interface/Buttons/UI-SpellbookIcon-PrevPage-Up.PNG")
	-- 	watch_list_frame.prev_button:SetHighlightTexture("Interface/Buttons/UI-SpellbookIcon-PrevPage-Up.PNG")
	-- 	watch_list_frame.prev_button:SetPushedTexture("Interface/Buttons/UI-SpellbookIcon-PrevPage-Down.PNG")
	-- end

	-- watch_list_frame.prev_button:SetScript("OnClick", function()
	-- 	page_number = page_number - 1
	-- 	if page_number < 1 then
	-- 		page_number = 1
	-- 	end
	-- 	watch_list_frame.page_str:SetText("Page " .. page_number)
	-- 	-- setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
	-- end)

	-- if watch_list_frame.next_button == nil then
	-- 	watch_list_frame.next_button = CreateFrame("Button", nil, watch_list_frame)
	-- 	watch_list_frame.next_button:SetPoint("CENTER", watch_list_frame.page_str, "CENTER", 50, 0)
	-- 	watch_list_frame.next_button:SetWidth(25)
	-- 	watch_list_frame.next_button:SetHeight(25)
	-- 	watch_list_frame.next_button:SetNormalTexture("Interface/Buttons/UI-SpellbookIcon-NextPage-Up.PNG")
	-- 	watch_list_frame.next_button:SetHighlightTexture("Interface/Buttons/UI-SpellbookIcon-NextPage-Up.PNG")
	-- 	watch_list_frame.next_button:SetPushedTexture("Interface/Buttons/UI-SpellbookIcon-NextPage-Down.PNG")
	-- end

	-- watch_list_frame.next_button:SetScript("OnClick", function()
	-- 	page_number = page_number + 1
	-- 	watch_list_frame.page_str:SetText("Page " .. page_number)
	-- 	-- setDeathlogMenuLogData(deathlogFilter(_deathlog_data, filter))
	-- end)

	refreshFontData()
	scroll_frame.frame:HookScript("OnHide", function()
		watch_list_frame:Hide()
	end)
end

function Deathlog_WatchList()
	return watch_list_frame
end
