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
local edit_box_type = nil

local main_font = Deathlog_L.main_font

local deathlog_tabcontainer = nil

local class_tbl = deathlog_class_tbl
local race_tbl = deathlog_race_tbl
local zone_tbl = deathlog_zone_tbl
local instance_tbl = deathlog_instance_tbl

local deathlog_watch_list = nil

deathlog_watchlist_entries = deathlog_watchlist_entries or {}

local function isDead(_name)
	return deathlog_data_map[GetRealmName()][_name]
end

local subtitle_data = {
	{
		"Name",
		120,
		function(_entry)
			if _entry["Name"] == "" then
				return "<Click to add>"
			end
			local _status = ""
			if _entry["Name"] ~= nil then
				if isDead(_entry["Name"]) then
					_status = " |cffff0000(DEAD)|r"
				end
				return (_entry["Name"] .. _status)
			end
			return "<Click to add>"
		end,
	},
	{
		"Note",
		650,
		function(_entry)
			if _entry["Note"] == "" then
				return "<Click to add note>"
			end
			return _entry["Note"] or "<Click to add note>"
		end,
	},
	{
		"Last Checked",
		100,
		function(_entry)
			if _entry["last_checked"] == nil then
				return "Never"
			end
			local dur = abs(time() - _entry["last_checked"])
			if dur < 60 then
				return ceil(dur) .. "s ago"
			elseif dur < 3600 then
				return ceil(dur / 60) .. "m ago"
			else
				return ceil(dur / 3600) .. "hr ago"
			end
		end,
	},
	{
		"Icon",
		100,
		function(_entry)
			return _entry["Icon"] or "<Click to set>"
		end,
	},
	{
		"Remove",
		50,
		function(_entry)
			return "|TInterface\\WorldMap\\X_MARK_64:16:16:0:0:64:64:0:32:0:32|t"
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
local status_string = watch_list_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")

if watch_list_frame.icon_dd == nil then
	watch_list_frame.icon_dd = CreateFrame("Frame", nil, watch_list_frame, "UIDropDownMenuTemplate")
end

local dropdownFunctions = nil
watch_list_frame.icon_dd:SetPoint("TOPLEFT", watch_list_frame, "BOTTOMLEFT", -20, 0)
watch_list_frame.icon_dd:Hide()
UIDropDownMenu_SetText(watch_list_frame.icon_dd, "")
UIDropDownMenu_SetWidth(watch_list_frame.icon_dd, 50)
UIDropDownMenu_Initialize(watch_list_frame.icon_dd, dropdownFunctions)
UIDropDownMenu_JustifyText(watch_list_frame.icon_dd, "LEFT")

local function setFontData(i, _entry)
	for _, v in ipairs(subtitle_data) do
		font_strings[i][v[1]]:SetText(v[3](_entry))
		font_strings[i].name = _entry["Name"]
	end
end

local function refreshFontData()
	local i = 1
	for _name, v in pairs(deathlog_watchlist_entries) do
		setFontData(i, v)
		i = i + 1
	end
	setFontData(i, {})
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

local comm_query_lock_out = nil
local last_time = nil
local scroll_frame_ref = nil
local ticker_handler = nil
local function checkAll()
	if comm_query_lock_out then
		local time_til = ""
		if last_time then
			time_til = math.ceil(60 - (time() - last_time))
		end

		if ticker_handler then
			status_string:SetText("Querying for deaths...")
		else
			status_string:SetText("Can't refresh yet; wait " .. time_til .. " seconds and visit this tab again.")
		end
		return
	end
	comm_query_lock_out = C_Timer.NewTimer(60, function()
		comm_query_lock_out:Cancel()
		comm_query_lock_out = nil
	end)

	status_string:SetText("Querying for deaths...")
	last_time = time()
	local idx = 1
	ticker_handler = C_Timer.NewTicker(5, function(self)
		if watch_list_frame:IsShown() then
			watch_list_frame.updateMenuElement(scroll_frame_ref)
		end
		if font_strings[idx] == nil or font_strings[idx].name == nil or font_strings[idx].name == "" then
			self:Cancel()
			ticker_handler = nil
			status_string:SetText("Done querying!")
			return
		end
		local _name = font_strings[idx].name
		if isDead(_name) == nil then
			if deathlog_watchlist_entries[_name] then
				deathlog_watchlist_entries[_name]["last_checked"] = time()
			end
			DeathNotificationLib_queryGuild(_name)
			DeathNotificationLib_querySay(_name)
		end
		idx = idx + 1
	end, 20)
end

function watch_list_frame.updateMenuElement(scroll_frame)
	scroll_frame_ref = scroll_frame
	watch_list_frame:SetParent(scroll_frame.frame)
	watch_list_frame:Show()
	watch_list_frame:SetPoint("TOPLEFT", scroll_frame.frame, "TOPLEFT", 0, -80)
	watch_list_frame:SetWidth(1040)
	watch_list_frame:SetHeight(880)

	if watch_list_frame.name_box == nil then
		watch_list_frame.name_box = CreateFrame("EditBox", nil, watch_list_frame, "InputBoxTemplate")
	end

	if watch_list_frame.name_box.text == nil then
		watch_list_frame.name_box.text = watch_list_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	end

	watch_list_frame.name_box:SetPoint("TOPLEFT", watch_list_frame, "TOPLEFT", 0, 20)
	watch_list_frame.name_box:SetPoint("BOTTOMLEFT", watch_list_frame, "TOPLEFT", 75, -50)
	watch_list_frame.name_box:SetWidth(100)
	watch_list_frame.name_box:SetFont(Deathlog_L.deadliest_creature_container_font, 14, "")
	watch_list_frame.name_box:SetMovable(false)
	watch_list_frame.name_box:SetBlinkSpeed(1)
	-- watch_list_frame.name_box:SetAutoFocus(false)
	watch_list_frame.name_box:SetMultiLine(false)
	watch_list_frame.name_box:SetMaxLetters(20)
	watch_list_frame.name_box:SetScript("OnEnterPressed", function(self, msg)
		if edit_box_type == 1 then
			local name = font_strings[selected_entry].name
			if name == nil then
				return
			end
			if deathlog_watchlist_entries[name] == nil then
				return
			end
			deathlog_watchlist_entries[name]["Note"] = watch_list_frame.name_box:GetText()
			watch_list_frame.updateMenuElement(scroll_frame, _, stats_tbl, updateFun, filterFunction, metric, class_id)
		else
			local name = font_strings[selected_entry]["Name"]
			if name ~= nil and name["Name"] ~= nil then
				deathlog_watchlist_entries[_name] = nil
			end
			local _name = watch_list_frame.name_box:GetText():gsub("^%l", string.upper)
			deathlog_watchlist_entries[_name] = {
				["Name"] = _name,
				["Icon"] = "|TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_7:16:16:0:0:64:64:|t",
			}
			watch_list_frame.updateMenuElement(scroll_frame, _, stats_tbl, updateFun, filterFunction, metric, class_id)
		end
	end)

	watch_list_frame.name_box.text:SetPoint("LEFT", watch_list_frame.name_box, "LEFT", 0, 15)
	watch_list_frame.name_box.text:SetFont(Deathlog_L.deadliest_creature_container_font, 12, "")
	watch_list_frame.name_box.text:SetTextColor(255 / 255, 215 / 255, 0)
	watch_list_frame.name_box.text:Show()

	status_string:SetPoint("TOPLEFT", watch_list_frame, "TOPLEFT", 0, -400)
	dropdownFunctions = function(frame, level, menuList)
		local info = UIDropDownMenu_CreateInfo()
		info.text, info.checked, info.func =
			"|T133784:16|t", metric == "|T133784:16|t", function()
				local name = font_strings[selected_entry].name
				if name == nil then
					return
				end
				if deathlog_watchlist_entries[name] == nil then
					return
				end
				deathlog_watchlist_entries[name]["Icon"] = "|T133784:16|t"
				watch_list_frame.updateMenuElement(scroll_frame)
			end
		UIDropDownMenu_AddButton(info)
		info.text, info.checked, info.func =
			"|TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_7:16:16:0:0:64:64:|t",
			metric == "|TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_7:16:16:0:0:64:64:|t",
			function()
				local name = font_strings[selected_entry].name
				if name == nil then
					return
				end
				if deathlog_watchlist_entries[name] == nil then
					return
				end
				deathlog_watchlist_entries[name]["Icon"] =
					"|TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_7:16:16:0:0:64:64:|t"
				watch_list_frame.updateMenuElement(scroll_frame)
			end
		UIDropDownMenu_AddButton(info)
		info.text, info.checked, info.func =
			"|TInterface\\COMMON\\friendship-heart:16:16:0:0:64:64:|t",
			metric == "|TInterface\\COMMON\\friendship-heart:16:16:0:0:64:64:|t",
			function()
				local name = font_strings[selected_entry].name
				if name == nil then
					return
				end
				if deathlog_watchlist_entries[name] == nil then
					return
				end
				deathlog_watchlist_entries[name]["Icon"] = "|TInterface\\COMMON\\friendship-heart:16:16:0:0:64:64:|t"
				watch_list_frame.updateMenuElement(scroll_frame)
			end
		UIDropDownMenu_AddButton(info)
	end
	UIDropDownMenu_Initialize(watch_list_frame.icon_dd, dropdownFunctions)
	watch_list_frame.icon_dd:Hide()

	local last_frame = watch_list_frame
	local shift = 0
	for i = 1, max_rows do
		local idx = 101 - i

		local _entry = CreateFrame("Frame", nil, watch_list_frame)
		_entry:SetWidth(watch_list_frame:GetWidth())
		_entry:SetHeight(15)
		if shift == 0 then
			_entry:SetPoint("TOPLEFT", last_frame, "TOPLEFT", 0, 0)
		else
			_entry:SetPoint("TOPLEFT", last_frame, "BOTTOMLEFT", 0, 0)
		end
		shift = -30
		last_frame = _entry

		font_strings[i][subtitle_data[1][1]]:SetPoint("LEFT", _entry, "LEFT", 0, 0)
		font_strings[i][subtitle_data[1][1]]:Show()
		-- setFontData(1, EntryData("Yazpad", "B"))
		for _, v in ipairs(subtitle_data) do
			font_strings[i][v[1]]:SetParent(_entry)
		end

		row_backgrounds[i]:SetPoint("LEFT", _entry, "LEFT", 0, 0)
		row_backgrounds[i]:SetParent(_entry)
		row_backgrounds[i]:SetWidth(_entry:GetWidth())

		-- _entry:SetHeight(40)
		_entry:SetWidth(watch_list_frame:GetWidth())

		_entry:SetScript("OnEnter", function(widget)
			local hash = isDead(font_strings[i].name)
			if hash == nil then
				return
			end
			GameTooltip_SetDefaultAnchor(GameTooltip, WorldFrame)
			deathlog_setTooltipFromEntry(deathlog_data[GetRealmName()][hash])
			GameTooltip:Show()
		end)

		_entry:SetScript("OnLeave", function(widget)
			GameTooltip:Hide()
		end)

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
			else
				selected_entry = i
				if font_strings[i]["Name"]:GetText() == "" or font_strings[i]["Name"]:GetText() == nil then
					return
				end

				local x, y = GetCursorPosition()
				local pos_x = x - _entry:GetLeft()
				if pos_x < 100 then
					edit_box_type = 0
					local function setEditBox(other)
						watch_list_frame.name_box:ClearAllPoints()
						watch_list_frame.name_box:SetPoint(
							"LEFT",
							other,
							"LEFT",
							font_strings[i]["Name"]:GetLeft() - _entry:GetLeft(),
							0
						)
						watch_list_frame.name_box:SetWidth(120)
						watch_list_frame.name_box:SetHeight(15)
					end
					setEditBox(_entry)
					watch_list_frame.name_box:SetText((font_strings[i]["Name"]:GetText() or "<Click to add>"))
					font_strings[i]["Name"]:SetText("")
					watch_list_frame.name_box:HighlightText()
					watch_list_frame.name_box:SetFocus()

					watch_list_frame.name_box:Show()
				elseif pos_x < 600 then
					edit_box_type = 1
					local function setEditBox(other)
						watch_list_frame.name_box:ClearAllPoints()
						watch_list_frame.name_box:SetPoint(
							"LEFT",
							other,
							"LEFT",
							font_strings[i]["Note"]:GetLeft() - _entry:GetLeft(),
							0
						)
						watch_list_frame.name_box:SetWidth(400)
						watch_list_frame.name_box:SetHeight(15)
					end
					setEditBox(_entry)
					watch_list_frame.name_box:SetText((font_strings[i]["Note"]:GetText() or "<Click to add note>"))
					font_strings[i]["Note"]:SetText("")
					watch_list_frame.name_box:HighlightText()
					watch_list_frame.name_box:SetFocus()

					watch_list_frame.name_box:Show()
				elseif pos_x < 760 and pos_x > 720 then
					watch_list_frame.icon_dd:SetParent(_entry)
					watch_list_frame.icon_dd:ClearAllPoints()
					watch_list_frame.icon_dd:SetPoint(
						"LEFT",
						_entry,
						"LEFT",
						font_strings[i]["Icon"]:GetLeft() - _entry:GetLeft() - 20,
						0
					)
					watch_list_frame.icon_dd:Show()
					UIDropDownMenu_SetWidth(watch_list_frame.icon_dd, 50)
				elseif pos_x > 820 and pos_x < 850 then
					if deathlog_watchlist_entries and deathlog_watchlist_entries[font_strings[i].name] then
						deathlog_watchlist_entries[font_strings[i].name] = nil
						watch_list_frame.updateMenuElement(
							scroll_frame,
							_,
							stats_tbl,
							updateFun,
							filterFunction,
							metric,
							class_id
						)
					end
				end
			end
		end)
	end
	watch_list_frame.name_box:Hide()

	header_strings[subtitle_data[1][1]]:SetPoint("TOPLEFT", font_strings[1]["Name"], "TOPLEFT", 0, 20)
	header_strings[subtitle_data[1][1]]:Show()
	for _, v in ipairs(subtitle_data) do
		header_strings[v[1]]:SetParent(watch_list_frame)
		header_strings[v[1]]:SetText(v[1])
	end
	checkAll()

	refreshFontData()
	scroll_frame.frame:HookScript("OnHide", function()
		watch_list_frame:Hide()
	end)
end

function Deathlog_WatchList()
	return watch_list_frame
end

local watchlist_idx = 1
local watchlist_event_handler = CreateFrame("Frame")

watchlist_event_handler:RegisterEvent("PLAYER_ENTERING_WORLD")
watchlist_event_handler:SetScript("OnEvent", handleEvent)
