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
local min_lvl = 0
local max_lvl = 60
local AceGUI = LibStub("AceGUI-3.0")
local max_row_num = 25
local page_number = 1
local deadliest_creatures_container = CreateFrame("Frame")
deadliest_creatures_container:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
local function createDeadliestCreaturesEntry()
	local frame = CreateFrame("Frame")
	frame:SetParent(deadliest_creatures_container)
	frame:SetWidth(60)
	frame:SetHeight(20)

	frame.background = frame:CreateTexture(nil, "OVERLAY")
	frame.background:SetPoint("LEFT", frame, "LEFT", 0, 0)
	frame.background:SetVertexColor(0.6, 0.2, 0.2)
	frame.background:SetTexture("Interface/TARGETINGFRAME/UI-StatusBar.PNG")
	frame.background:SetHeight(14)
	frame.background:SetWidth(20)
	frame.background:Show()

	frame.creature_name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.creature_name:SetPoint("LEFT", frame, "LEFT", 10, 0)
	frame.creature_name:SetFont(Deathlog_L.deadliest_creature_container_font, 14, "OUTLINE")
	frame.creature_name:SetTextColor(0.9, 0.9, 0.9)
	frame.creature_name:SetText("AAA")
	frame.creature_name:Show()

	frame.num_kills_text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.num_kills_text:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
	frame.num_kills_text:SetText("")
	frame.num_kills_text:SetJustifyH("RIGHT")
	frame.num_kills_text:Show()

	frame.SetBackgroundWidth = function(self, width)
		self.background:SetWidth(width)
	end

	frame.SetCreatureName = function(self, creature_name)
		if creature_name == nil then
			frame.creature_name:SetText("Environment Damage")
		else
			frame.creature_name:SetText(creature_name)
		end
	end

	frame.SetNumKills = function(self, num, metric)
		if metric == "Total Kills" then
			frame.num_kills_text:SetText(num .. " kills")
		elseif metric == "Normalized Score" then
			frame.num_kills_text:SetText(string.format("%.1f", num) .. " pts.")
		end
	end

	return frame
end

local environment_damage = {
	[-2] = "Drowning",
	[-3] = "Falling",
	[-4] = "Fatigue",
	[-5] = "Fire",
	[-6] = "Lava",
	[-7] = "Slime",
}
local deadliest_creatures_textures = {}
for i = 1, max_row_num do
	deadliest_creatures_textures[i] = createDeadliestCreaturesEntry()
	-- deadliest_creatures_textures[i].rank_text:SetText(i)
end

if deadliest_creatures_container.heading == nil then
	deadliest_creatures_container.heading =
		deadliest_creatures_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	deadliest_creatures_container.heading:SetText("Deadliest Creatures")
	deadliest_creatures_container.heading:SetFont(Deathlog_L.deadliest_creature_container_font, 18, "")
	deadliest_creatures_container.heading:SetJustifyV("TOP")
	deadliest_creatures_container.heading:SetTextColor(0.9, 0.9, 0.9)
	deadliest_creatures_container.heading:SetPoint("TOP", deadliest_creatures_container, "TOP", 0, 20)
	deadliest_creatures_container.heading:Show()
end

if deadliest_creatures_container.page_str == nil then
	deadliest_creatures_container.page_str =
		deadliest_creatures_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	deadliest_creatures_container.page_str:SetText("Page " .. page_number)
	deadliest_creatures_container.page_str:SetFont(Deathlog_L.deadliest_creature_container_font, 14, "")
	deadliest_creatures_container.page_str:SetJustifyV("BOTTOM")
	deadliest_creatures_container.page_str:SetJustifyH("CENTER")
	deadliest_creatures_container.page_str:SetTextColor(0.7, 0.7, 0.7)
	deadliest_creatures_container.page_str:SetPoint("TOP", deadliest_creatures_container, "TOP", 0, -438)
	deadliest_creatures_container.page_str:Show()
end

if deadliest_creatures_container.prev_button == nil then
	deadliest_creatures_container.prev_button = CreateFrame("Button", nil, deadliest_creatures_container)
	deadliest_creatures_container.prev_button:SetPoint(
		"CENTER",
		deadliest_creatures_container.page_str,
		"CENTER",
		-50,
		0
	)
	deadliest_creatures_container.prev_button:SetWidth(25)
	deadliest_creatures_container.prev_button:SetHeight(25)
	deadliest_creatures_container.prev_button:SetNormalTexture("Interface/Buttons/UI-SpellbookIcon-PrevPage-Up.PNG")
	deadliest_creatures_container.prev_button:SetHighlightTexture("Interface/Buttons/UI-SpellbookIcon-PrevPage-Up.PNG")
	deadliest_creatures_container.prev_button:SetPushedTexture("Interface/Buttons/UI-SpellbookIcon-PrevPage-Down.PNG")

	deadliest_creatures_container.prev_button:SetScript("OnClick", function()
		page_number = page_number - 1
		if page_number < 1 then
			page_number = 1
		end
	end)
end

if deadliest_creatures_container.next_button == nil then
	deadliest_creatures_container.next_button = CreateFrame("Button", nil, deadliest_creatures_container)
	deadliest_creatures_container.next_button:SetPoint(
		"CENTER",
		deadliest_creatures_container.page_str,
		"CENTER",
		50,
		0
	)
	deadliest_creatures_container.next_button:SetWidth(25)
	deadliest_creatures_container.next_button:SetHeight(25)
	deadliest_creatures_container.next_button:SetNormalTexture("Interface/Buttons/UI-SpellbookIcon-NextPage-Up.PNG")
	deadliest_creatures_container.next_button:SetHighlightTexture("Interface/Buttons/UI-SpellbookIcon-NextPage-Up.PNG")
	deadliest_creatures_container.next_button:SetPushedTexture("Interface/Buttons/UI-SpellbookIcon-NextPage-Down.PNG")
end

if deadliest_creatures_container.heading_description == nil then
	deadliest_creatures_container.heading_description =
		deadliest_creatures_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	deadliest_creatures_container.heading_description:SetText("Click to view stats.")
	deadliest_creatures_container.heading_description:SetFont(Deathlog_L.deadliest_creature_container_font, 12, "")
	deadliest_creatures_container.heading_description:SetJustifyV("TOP")
	deadliest_creatures_container.heading_description:SetTextColor(0.6, 0.6, 0.6)
	deadliest_creatures_container.heading_description:SetPoint(
		"TOP",
		deadliest_creatures_container.heading,
		"BOTTOM",
		0,
		0
	)
	deadliest_creatures_container.heading_description:Show()
end

if deadliest_creatures_container.left == nil then
	deadliest_creatures_container.left = deadliest_creatures_container:CreateTexture(nil, "BACKGROUND")
	deadliest_creatures_container.left:SetHeight(8)
	deadliest_creatures_container.left:SetPoint("LEFT", deadliest_creatures_container.heading, "LEFT", -30, 0)
	deadliest_creatures_container.left:SetPoint("RIGHT", deadliest_creatures_container.heading, "LEFT", -5, 0)
	deadliest_creatures_container.left:SetTexture(137057) -- Interface\\Tooltips\\UI-Tooltip-Border
	deadliest_creatures_container.left:SetTexCoord(0.81, 0.94, 0.5, 1)
end

if deadliest_creatures_container.right == nil then
	deadliest_creatures_container.right = deadliest_creatures_container:CreateTexture(nil, "BACKGROUND")
	deadliest_creatures_container.right:SetHeight(8)
	deadliest_creatures_container.right:SetPoint("RIGHT", deadliest_creatures_container.heading, "RIGHT", 30, 0)
	deadliest_creatures_container.right:SetPoint("LEFT", deadliest_creatures_container.heading, "RIGHT", 5, 0)
	deadliest_creatures_container.right:SetTexture(137057) -- Interface\\Tooltips\\UI-Tooltip-Border
	deadliest_creatures_container.right:SetTexCoord(0.81, 0.94, 0.5, 1)
end

function deadliest_creatures_container.updateMenuElement(
	scroll_frame,
	_,
	stats_tbl,
	updateFun,
	filter,
	metric,
	class_id
)
	if class_id == nil then
		class_id = "all"
	end
	if metric == nil then
		metric = "Normalized Score"
	end
	local current_map_id = 947
	deadliest_creatures_container.page_str:SetText("Page " .. page_number)
	deadliest_creatures_container.heading:Show()
	deadliest_creatures_container.left:Show()
	deadliest_creatures_container.right:Show()
	local _stats = stats_tbl["stats"]
	local _log_normal_params = stats_tbl["log_normal_params"]
	local valid_map = C_Map.GetMapInfo(current_map_id)
	if valid_map then
		deadliest_creatures_container.heading_description:Show()
	else
		deadliest_creatures_container.heading_description:Hide()
	end
	local num_recorded_kills = 0
	for i = 1, max_row_num do
		deadliest_creatures_textures[i]:Hide()
	end
	local map_id = current_map_id
	if map_id == 947 then
		map_id = "all"
	end

	if deadliest_creatures_container.sort_by_text == nil then
		deadliest_creatures_container.sort_by_text =
			deadliest_creatures_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	end

	deadliest_creatures_container.sort_by_text:SetPoint("TOPLEFT", deadliest_creatures_container, "TOPLEFT", 0, -8)
	deadliest_creatures_container.sort_by_text:SetFont(Deathlog_L.deadliest_creature_container_font, 12, "")
	deadliest_creatures_container.sort_by_text:SetTextColor(255 / 255, 215 / 255, 0)
	deadliest_creatures_container.sort_by_text:SetText("Sort Metric")
	deadliest_creatures_container.sort_by_text:SetJustifyH("LEFT")
	deadliest_creatures_container.sort_by_text:Show()

	if deadliest_creatures_container.sort_by_class_text == nil then
		deadliest_creatures_container.sort_by_class_text =
			deadliest_creatures_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	end

	deadliest_creatures_container.sort_by_class_text:SetPoint(
		"TOPLEFT",
		deadliest_creatures_container,
		"TOPLEFT",
		150,
		-8
	)
	deadliest_creatures_container.sort_by_class_text:SetFont(Deathlog_L.deadliest_creature_container_font, 12, "")
	deadliest_creatures_container.sort_by_class_text:SetTextColor(255 / 255, 215 / 255, 0)
	deadliest_creatures_container.sort_by_class_text:SetText("Against Class")
	deadliest_creatures_container.sort_by_class_text:SetJustifyH("LEFT")
	deadliest_creatures_container.sort_by_class_text:Show()

	if deadliest_creatures_container.player_search_box == nil then
		deadliest_creatures_container.player_search_box =
			CreateFrame("EditBox", nil, deadliest_creatures_container, "InputBoxTemplate")
	end

	if deadliest_creatures_container.lvl_min_search_box == nil then
		deadliest_creatures_container.lvl_min_search_box =
			CreateFrame("EditBox", nil, deadliest_creatures_container, "InputBoxTemplate")
	end

	if deadliest_creatures_container.lvl_max_search_box == nil then
		deadliest_creatures_container.lvl_max_search_box =
			CreateFrame("EditBox", nil, deadliest_creatures_container, "InputBoxTemplate")
	end

	if deadliest_creatures_container.metric_dd == nil then
		deadliest_creatures_container.metric_dd =
			CreateFrame("Frame", nil, deadliest_creatures_container, "UIDropDownMenuTemplate")
	end

	if deadliest_creatures_container.class_dd == nil then
		deadliest_creatures_container.class_dd =
			CreateFrame("Frame", nil, deadliest_creatures_container, "UIDropDownMenuTemplate")
	end
	local function filterFunction(name)
		if name == nil then
			return false
		end
		if string.find(string.lower(name), string.lower(deadliest_creatures_container.player_search_box:GetText())) then
			return true
		end
		return false
	end
	local function dropdownFunctions(frame, level, menuList)
		local info = UIDropDownMenu_CreateInfo()
		info.text, info.checked, info.func =
			"Normalized Score", metric == "Normalized Score", function()
				deadliest_creatures_container.updateMenuElement(scroll_frame, _, stats_tbl, updateFun, filterFunction, "Normalized Score", class_id)
			end
		UIDropDownMenu_AddButton(info)
		info.text, info.checked, info.func =
			"Total Kills", metric == "Total Kills", function()
				deadliest_creatures_container.updateMenuElement(scroll_frame, _, stats_tbl, updateFun, filterFunction, "Total Kills", class_id)
			end
		UIDropDownMenu_AddButton(info)
	end
	deadliest_creatures_container.metric_dd:SetPoint(
		"TOPLEFT",
		deadliest_creatures_container.sort_by_text,
		"BOTTOMLEFT",
		-20,
		0
	)
	UIDropDownMenu_SetText(deadliest_creatures_container.metric_dd, metric)
	UIDropDownMenu_SetWidth(deadliest_creatures_container.metric_dd, 130)
	UIDropDownMenu_Initialize(deadliest_creatures_container.metric_dd, dropdownFunctions)
	UIDropDownMenu_JustifyText(deadliest_creatures_container.metric_dd, "LEFT")

	local function classDropdownFunctions(frame, level, menuList)
		local info = UIDropDownMenu_CreateInfo()

		info.text, info.checked, info.func =
			"", class_id == "all", function()
				deadliest_creatures_container.updateMenuElement(scroll_frame, _, stats_tbl, updateFun, filterFunction, metric, "all")
			end

		UIDropDownMenu_AddButton(info)
		for k, v in pairs(deathlog_class_tbl) do
			info.text, info.checked, info.func =
				k, metric == k, function()
					deadliest_creatures_container.updateMenuElement(scroll_frame, _, stats_tbl, updateFun, filterFunction, metric, v)
				end
			UIDropDownMenu_AddButton(info)
		end
	end
	deadliest_creatures_container.class_dd:SetPoint(
		"TOPLEFT",
		deadliest_creatures_container.sort_by_class_text,
		"BOTTOMLEFT",
		-20,
		0
	)
	local class_str = ""
	if tonumber(class_id) ~= nil then
		class_str, _, _ = GetClassInfo(class_id)
	end
	UIDropDownMenu_SetText(deadliest_creatures_container.class_dd, class_str)
	UIDropDownMenu_SetWidth(deadliest_creatures_container.class_dd, 100)
	UIDropDownMenu_Initialize(deadliest_creatures_container.class_dd, classDropdownFunctions)
	UIDropDownMenu_JustifyText(deadliest_creatures_container.class_dd, "LEFT")

	if deadliest_creatures_container.player_search_box.text == nil then
		deadliest_creatures_container.player_search_box.text =
			deadliest_creatures_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	end
	deadliest_creatures_container.player_search_box:SetPoint("TOP", deadliest_creatures_container, "TOP", 75, -20)
	deadliest_creatures_container.player_search_box:SetPoint("BOTTOM", deadliest_creatures_container, "TOP", 75, -50)
	deadliest_creatures_container.player_search_box:SetWidth(130)
	deadliest_creatures_container.player_search_box:SetFont(Deathlog_L.deadliest_creature_container_font, 14, "")
	deadliest_creatures_container.player_search_box:SetMovable(false)
	deadliest_creatures_container.player_search_box:SetBlinkSpeed(1)
	deadliest_creatures_container.player_search_box:SetAutoFocus(false)
	deadliest_creatures_container.player_search_box:SetMultiLine(false)
	deadliest_creatures_container.player_search_box:SetMaxLetters(20)
	deadliest_creatures_container.player_search_box:SetScript("OnEnterPressed", function()
		deadliest_creatures_container.updateMenuElement(
			scroll_frame,
			_,
			stats_tbl,
			updateFun,
			filterFunction,
			metric,
			class_id
		)
	end)

	deadliest_creatures_container.player_search_box.text:SetPoint(
		"LEFT",
		deadliest_creatures_container.player_search_box,
		"LEFT",
		0,
		15
	)
	deadliest_creatures_container.player_search_box.text:SetFont(Deathlog_L.deadliest_creature_container_font, 12, "")
	deadliest_creatures_container.player_search_box.text:SetTextColor(255 / 255, 215 / 255, 0)
	deadliest_creatures_container.player_search_box.text:SetText("Name Filter")
	deadliest_creatures_container.player_search_box.text:Show()

	deadliest_creatures_container.lvl_min_search_box:SetPoint("TOP", deadliest_creatures_container, "TOP", 170, -20)
	deadliest_creatures_container.lvl_min_search_box:SetPoint("BOTTOM", deadliest_creatures_container, "TOP", 170, -50)
	deadliest_creatures_container.lvl_min_search_box:SetWidth(45)
	deadliest_creatures_container.lvl_min_search_box:SetFont(Deathlog_L.deadliest_creature_container_font, 14, "")
	deadliest_creatures_container.lvl_min_search_box:SetMovable(false)
	deadliest_creatures_container.lvl_min_search_box:SetBlinkSpeed(1)
	deadliest_creatures_container.lvl_min_search_box:SetAutoFocus(false)
	deadliest_creatures_container.lvl_min_search_box:SetText(min_lvl)
	deadliest_creatures_container.lvl_min_search_box:SetMultiLine(false)
	deadliest_creatures_container.lvl_min_search_box:SetMaxLetters(20)
	deadliest_creatures_container.lvl_min_search_box:SetScript("OnEnterPressed", function()
		if tonumber(deadliest_creatures_container.lvl_min_search_box:GetText()) == nil then
			return
		end
		min_lvl = tonumber(deadliest_creatures_container.lvl_min_search_box:GetText())
		deadliest_creatures_container.updateMenuElement(
			scroll_frame,
			_,
			stats_tbl,
			updateFun,
			filterFunction,
			metric,
			class_id
		)
	end)

	if deadliest_creatures_container.lvl_min_search_box.text == nil then
		deadliest_creatures_container.lvl_min_search_box.text =
			deadliest_creatures_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	end

	deadliest_creatures_container.lvl_min_search_box.text:SetPoint(
		"LEFT",
		deadliest_creatures_container.lvl_min_search_box,
		"LEFT",
		0,
		15
	)
	deadliest_creatures_container.lvl_min_search_box.text:SetFont(Deathlog_L.deadliest_creature_container_font, 12, "")
	deadliest_creatures_container.lvl_min_search_box.text:SetTextColor(255 / 255, 215 / 255, 0)
	deadliest_creatures_container.lvl_min_search_box.text:SetText("Min. Lvl.")
	deadliest_creatures_container.lvl_min_search_box.text:Show()

	deadliest_creatures_container.lvl_max_search_box:SetPoint("TOP", deadliest_creatures_container, "TOP", 220, -20)
	deadliest_creatures_container.lvl_max_search_box:SetPoint("BOTTOM", deadliest_creatures_container, "TOP", 220, -50)
	deadliest_creatures_container.lvl_max_search_box:SetWidth(45)
	deadliest_creatures_container.lvl_max_search_box:SetFont(Deathlog_L.deadliest_creature_container_font, 14, "")
	deadliest_creatures_container.lvl_max_search_box:SetMovable(false)
	deadliest_creatures_container.lvl_max_search_box:SetBlinkSpeed(1)
	deadliest_creatures_container.lvl_max_search_box:SetText(max_lvl)
	deadliest_creatures_container.lvl_max_search_box:SetAutoFocus(false)
	deadliest_creatures_container.lvl_max_search_box:SetMultiLine(false)
	deadliest_creatures_container.lvl_max_search_box:SetMaxLetters(20)
	deadliest_creatures_container.lvl_max_search_box:SetScript("OnEnterPressed", function()
		if tonumber(deadliest_creatures_container.lvl_max_search_box:GetText()) == nil then
			return
		end
		max_lvl = tonumber(deadliest_creatures_container.lvl_max_search_box:GetText())
		deadliest_creatures_container.updateMenuElement(
			scroll_frame,
			_,
			stats_tbl,
			updateFun,
			filterFunction,
			metric,
			class_id
		)
	end)

	if deadliest_creatures_container.lvl_max_search_box.text == nil then
		deadliest_creatures_container.lvl_max_search_box.text =
			deadliest_creatures_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	end

	deadliest_creatures_container.lvl_max_search_box.text:SetPoint(
		"LEFT",
		deadliest_creatures_container.lvl_max_search_box,
		"LEFT",
		0,
		15
	)
	deadliest_creatures_container.lvl_max_search_box.text:SetFont(Deathlog_L.deadliest_creature_container_font, 12, "")
	deadliest_creatures_container.lvl_max_search_box.text:SetTextColor(255 / 255, 215 / 255, 0)
	deadliest_creatures_container.lvl_max_search_box.text:SetText("Max. Lvl.")
	deadliest_creatures_container.lvl_max_search_box.text:Show()

	if deadliest_creatures_container.normalized_metric_frame == nil then
		deadliest_creatures_container.normalized_metric_frame =
			CreateFrame("Frame", nil, deadliest_creatures_container, "BackdropTemplate")
		local PaneBackdrop = {
			bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
			edgeFile = "Interface\\Glues\\COMMON\\TextPanel-Border",
			tile = true,
			tileSize = 16,
			edgeSize = 16,
			insets = { left = 3, right = 3, top = 5, bottom = 3 },
			deadliest_creatures_container.normalized_metric_frame:SetBackdrop(PaneBackdrop),
		}
		if deadliest_creatures_container.normalized_metric_desc == nil then
			deadliest_creatures_container.normalized_metric_desc =
				deadliest_creatures_container.normalized_metric_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		end
	end

	deadliest_creatures_container.normalized_metric_frame:SetPoint(
		"TOPRIGHT",
		deadliest_creatures_container,
		"TOPRIGHT",
		0,
		20
	)
	deadliest_creatures_container.normalized_metric_frame:SetBackdropColor(0, 0, 0, 0.6)
	deadliest_creatures_container.normalized_metric_frame:SetBackdropBorderColor(1, 1, 1, 1)
	deadliest_creatures_container.normalized_metric_frame:SetSize(100, 100)
	deadliest_creatures_container.normalized_metric_frame:Show()

	deadliest_creatures_container.normalized_metric_frame:SetScript("OnEnter", function()
		GameTooltip:SetOwner(WorldFrame, "ANCHOR_CURSOR")
		GameTooltip:SetMinimumWidth(450)
		GameTooltip:AddLine(
			"Normalized Score: #Kills/(1-CumulativeDensityFunction(x))\nWhere the cumulative density function represents the ratio of characters whom have died by `x` lvl.  This metric normalizes the creatures kill count by the fraction of population that is alive around that creature's level.  We can extract the cumulative density function from the probability density function using a log normal distribution.  Most Hardcore characters don't make it to 60, so we assume that the remaining population at `x` level is roughly 1 - CDF(lvl) \n \nTotal Kills: This just uses the number of kills to sort the creatures.  Note that there are more Hardcore players at lower levels, so lower level creatures have a higher kill count in general.",
			1,
			1,
			1,
			1,
			true
		)
		GameTooltip:Show()
	end)
	deadliest_creatures_container.normalized_metric_frame:SetScript("OnLeave", function()
		GameTooltip:Hide()
	end)

	deadliest_creatures_container.normalized_metric_desc:SetFont(Deathlog_L.deadliest_creature_container_font, 14, "OUTLINE")
	deadliest_creatures_container.normalized_metric_desc:SetTextColor(0.8, 0.8, 0.8)
	deadliest_creatures_container.normalized_metric_desc:SetText("Mouseover for\nmetric details")
	deadliest_creatures_container.normalized_metric_desc:SetPoint(
		"TOP",
		deadliest_creatures_container.normalized_metric_frame,
		"TOP",
		0,
		0
	)
	deadliest_creatures_container.normalized_metric_desc:Show()

	local most_deadly_units = nil
	if metric == "Total Kills" then
		most_deadly_units = deathlogGetOrdered(_stats, { "all", map_id, class_id, nil })
	elseif metric == "Normalized Score" then
		most_deadly_units = deathlogGetOrderedNormalized(
			_stats,
			{ "all", "all", class_id, nil },
			_log_normal_params["all"][1][1],
			_log_normal_params["all"][1][2] * _log_normal_params["all"][1][2]
		)
	end

	local filtered_most_deadly_units = {}
	local function lvlFunction(lvl)
		if lvl >= min_lvl then
			if lvl <= max_lvl then
				return true
			end
		end
		return false
	end

	if filter == nil then
		for k, v in ipairs(most_deadly_units) do
			if v[1] ~= -1 then
				filtered_most_deadly_units[#filtered_most_deadly_units + 1] = v
			end
		end
	else
		for k, v in ipairs(most_deadly_units) do
			if
				filter(id_to_npc[v[1]] or environment_damage[v[1]])
				and lvlFunction(_stats["all"]["all"]["all"][v[1]]["avg_lvl"])
			then
				filtered_most_deadly_units[#filtered_most_deadly_units + 1] = v
			end
		end
	end
	if filtered_most_deadly_units and #filtered_most_deadly_units > 0 then
		local max_kills = filtered_most_deadly_units[1][2]
		for _, v in ipairs(filtered_most_deadly_units) do
			num_recorded_kills = num_recorded_kills + v[2]
		end

		deadliest_creatures_container:SetParent(scroll_frame.frame)
		deadliest_creatures_container:SetPoint("TOPLEFT", scroll_frame.frame, "TOPLEFT", 0, -70)
		deadliest_creatures_container:Show()
		deadliest_creatures_container:SetWidth(scroll_frame.frame:GetWidth() * 0.5)
		deadliest_creatures_container:SetHeight(scroll_frame.frame:GetWidth() * 0.8)
		for i = 1, max_row_num do
			local idx = (i + (page_number - 1) * max_row_num)
			if idx <= #filtered_most_deadly_units then
				deadliest_creatures_textures[i]:SetWidth(deadliest_creatures_container:GetWidth())
				deadliest_creatures_textures[i]:SetPoint(
					"TOPLEFT",
					deadliest_creatures_container,
					"TOPLEFT",
					0,
					-35 - i * 15
				)
				deadliest_creatures_textures[i]:SetBackgroundWidth(
					deadliest_creatures_container:GetWidth() * filtered_most_deadly_units[idx][2] / max_kills
				)
				if id_to_npc[filtered_most_deadly_units[idx][1]] ~= nil then
					deadliest_creatures_textures[i]:SetCreatureName(id_to_npc[filtered_most_deadly_units[idx][1]])
				elseif environment_damage[filtered_most_deadly_units[idx][1]] ~= nil then
					deadliest_creatures_textures[i]:SetCreatureName(
						environment_damage[filtered_most_deadly_units[idx][1]]
					)
				end
				deadliest_creatures_textures[i]:SetNumKills(filtered_most_deadly_units[idx][2], metric)
				if valid_map then
					deadliest_creatures_textures[i]:SetScript("OnMouseDown", function()
						local c_id = filtered_most_deadly_units[idx][1]
						local c_name = id_to_npc[filtered_most_deadly_units[idx][1]]
						updateFun(c_id, c_name, function(name)
							if name == nil then
								return false
							end
							if
								string.find(
									string.lower(name),
									string.lower(deadliest_creatures_container.player_search_box:GetText())
								)
							then
								return true
							else
								return false
							end
						end)
					end)
				end
				deadliest_creatures_textures[i]:SetHeight(20)
				deadliest_creatures_textures[i]:Show()
			end
		end
	end

	deadliest_creatures_container:SetScript("OnHide", function()
		for _, v in ipairs(deadliest_creatures_textures) do
			v:Hide()
		end
		deadliest_creatures_container.heading:Hide()
		deadliest_creatures_container.left:Hide()
		deadliest_creatures_container.right:Hide()
	end)

	deadliest_creatures_container.prev_button:SetScript("OnClick", function()
		page_number = page_number - 1
		if page_number < 1 then
			page_number = 1
		end
		deadliest_creatures_container.updateMenuElement(
			scroll_frame,
			_,
			stats_tbl,
			updateFun,
			filterFunction,
			metric,
			class_id
		)
	end)

	deadliest_creatures_container.next_button:SetScript("OnClick", function()
		page_number = page_number + 1
		if page_number > #most_deadly_units / max_row_num + 1 then
			page_number = #most_deadly_units / max_row_num + 1
		end
		deadliest_creatures_container.updateMenuElement(
			scroll_frame,
			_,
			stats_tbl,
			updateFun,
			filterFunction,
			metric,
			class_id
		)
	end)
end

function Deathlog_DeadliestCreatureExtContainer()
	return deadliest_creatures_container
end
