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
local instance_to_id = DeathNotificationLib.INSTANCE_TO_ID
local instance_categories = DeathNotificationLib.INSTANCE_CATEGORIES

local id_to_file_name = {
	-- Classic Dungeons
	[33] = "SHADOWFANGKEEP",
	[34] = "STORMWINDSTOCKADES",
	[36] = "DEADMINES",
	[43] = "WAILINGCAVERNS",
	[47] = "RAZORFENKRAUL",
	[48] = "BLACKFATHOMDEEPS",
	[70] = "ULDAMAN",
	[90] = "GNOMEREGAN",
	[109] = "SUNKENTEMPLE",
	[129] = "RAZORFENDOWNS",
	[189] = "SCARLETMONASTERY",
	[209] = "ZULFARAK",
	[229] = "BLACKROCKSPIRE",
	[230] = "BLACKROCKDEPTHS",
	[289] = "SCHOLOMANCE",
	[329] = "STRATHOLME",
	[349] = "MARAUDON",
	[389] = "RAGEFIRECHASM",
	[429] = "DIREMAUL",
	-- Classic Raids
	[249] = "BLACKWINGLAIR",
	[309] = "ZULGURUB",
	[409] = "MOLTENCORE",
	[469] = "BLACKWINGLAIR",
	[509] = "AQRUINS",
	[531] = "AQTEMPLE",
	[533] = "NAXXRAMAS",
	-- TBC Dungeons
	[269] = "CAVERNSOFTIME",
	[540] = "HELLFIRECITADEL",
	[542] = "HELLFIRECITADEL",
	[543] = "HELLFIRECITADEL",
	[545] = "COILFANG",
	[546] = "COILFANG",
	[547] = "COILFANG",
	[552] = "TEMPESTKEEP",
	[553] = "TEMPESTKEEP",
	[554] = "TEMPESTKEEP",
	[555] = "AUCHINDOUN",
	[556] = "AUCHINDOUN",
	[557] = "AUCHINDOUN",
	[558] = "AUCHINDOUN",
	[560] = "CAVERNSOFTIME",
	[585] = "MAGISTERSTERRACE",
	-- TBC Raids
	[532] = "KARAZHAN",
	[534] = "HYJALPAST",
	[544] = "HELLFIRECITADELRAID",
	[548] = "COILFANG",
	[550] = "TEMPESTKEEP",
	[564] = "BLACKTEMPLE",
	[565] = "GRUULSLAIR",
	[568] = "ZULAMAN",
	[580] = "SUNWELL",
}

local sorted_instance_entries = {}

local category_order = { "Dungeon", "Raid" }
for category_idx, category_name in ipairs(category_order) do
	local category_lookup = {}
	for _, instance_id in ipairs(instance_categories[category_name]) do
		category_lookup[instance_id] = true
	end

	for expansion_idx, instances in pairs(instance_to_id) do
		for instance_name, instance_id in pairs(instances) do
			if category_lookup[instance_id] then
				local sort_key = expansion_idx * 100000 + category_idx * 10000 + instance_id
				table.insert(sorted_instance_entries, { instance_id, id_to_file_name[instance_id], instance_name, sort_key, expansion_idx })
			end
		end
	end
end
table.sort(sorted_instance_entries, function(a, b) return a[4] < b[4] end)

table.insert(sorted_instance_entries, 1, { deathlog_ALL_INSTANCES_ID, "RANDOMDUNGEON", "Instances", -1, -1 })

-- Expansion filter state: which expansion indices are visible
-- By default all expansions are shown
local expansion_filter = {} -- [expansion_idx] = true/false
for expansion_idx, _ in pairs(instance_to_id) do
	expansion_filter[expansion_idx] = true
end

-- Build the list of available expansion indices, sorted
local available_expansions = {}
for expansion_idx, _ in pairs(instance_to_id) do
	table.insert(available_expansions, expansion_idx)
end
table.sort(available_expansions)

-- Returns the filtered list based on current expansion_filter
local function getFilteredEntries()
	local filtered = {}
	for _, entry in ipairs(sorted_instance_entries) do
		local exp_idx = entry[5]
		if exp_idx == -1 or expansion_filter[exp_idx] then
			table.insert(filtered, entry)
		end
	end
	return filtered
end

local COLUMNS = 4
local BUTTON_WIDTH = 120
local BUTTON_HEIGHT = 60
local HORIZ_SPACING = 30
local VERT_SPACING = 15
local FILTER_BAR_HEIGHT = 24

local instance_container = CreateFrame("Frame")
instance_container:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
instance_container:SetSize(1000, 1000)
instance_container:Show()

-- Expansion filter bar (only shown when more than one expansion is available)
local filterBar = CreateFrame("Frame", "DeathlogInstanceFilterBar", instance_container)
filterBar:SetHeight(FILTER_BAR_HEIGHT)
filterBar:Hide()

local filterButtons = {}
local pendingRefresh = nil -- will hold a function to call after toggling

local function updateFilterButtonAppearance()
	for exp_idx, btn in pairs(filterButtons) do
		if expansion_filter[exp_idx] then
			btn.label:SetTextColor(1, 0.82, 0, 1) -- gold / active
		else
			btn.label:SetTextColor(0.5, 0.5, 0.5, 1) -- grey / inactive
		end
	end
end

local function createFilterButton(parent, exp_idx, label_text)
	local btn = CreateFrame("Button", nil, parent)
	btn:SetHeight(FILTER_BAR_HEIGHT)

	btn.label = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	btn.label:SetPoint("CENTER", btn, "CENTER", 0, 0)
	btn.label:SetFont(Deathlog_L.menu_font, 12, "OUTLINE")
	btn.label:SetText(label_text)

	-- Measure text width and add padding
	btn:SetWidth(btn.label:GetStringWidth() + 20)

	btn:SetScript("OnClick", function()
		expansion_filter[exp_idx] = not expansion_filter[exp_idx]
		-- Ensure at least one expansion stays enabled
		local any_enabled = false
		for _, v in pairs(expansion_filter) do
			if v then any_enabled = true; break end
		end
		if not any_enabled then
			expansion_filter[exp_idx] = true
		end
		updateFilterButtonAppearance()
		if pendingRefresh then
			pendingRefresh()
		end
	end)

	btn:SetScript("OnEnter", function(self)
		if expansion_filter[exp_idx] then
			self.label:SetTextColor(1, 1, 1, 1)
		else
			self.label:SetTextColor(0.8, 0.8, 0.8, 1)
		end
	end)

	btn:SetScript("OnLeave", function()
		updateFilterButtonAppearance()
	end)

	filterButtons[exp_idx] = btn
	return btn
end

-- Only create filter buttons if TBC (or higher) is available
local show_filter_bar = GetExpansionLevel and GetExpansionLevel() >= 1 and #available_expansions > 1
if show_filter_bar then
	local x_offset = 0
	for _, exp_idx in ipairs(available_expansions) do
		local name = _G["EXPANSION_NAME" .. exp_idx] or ("Expansion " .. exp_idx)
		local btn = createFilterButton(filterBar, exp_idx, name)
		btn:SetPoint("LEFT", filterBar, "LEFT", x_offset, 0)
		x_offset = x_offset + btn:GetWidth() + 8
	end
	updateFilterButtonAppearance()
end

local scrollFrame = CreateFrame("ScrollFrame", "DeathlogInstanceScrollFrame", instance_container, "UIPanelScrollFrameTemplate")
local scrollChild = CreateFrame("Frame", "DeathlogInstanceScrollChild", scrollFrame)
scrollFrame:SetScrollChild(scrollChild)
scrollFrame:Hide()

local function createInstanceButton(parent, path_postfix, title_text)
	local frame = CreateFrame("Frame", nil, parent)
	frame:SetWidth(BUTTON_WIDTH)
	frame:SetHeight(BUTTON_HEIGHT)
	frame:Hide()
	
	frame.instance_texture = frame:CreateTexture(nil, "OVERLAY")
	frame.instance_texture:SetDrawLayer("OVERLAY", 7)
	frame.instance_texture:SetVertexColor(1, 1, 1, 1)
	frame.instance_texture:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	frame.instance_texture:SetTexture("Interface\\LFGFRAME\\UI-LFG-BACKGROUND-" .. path_postfix)
	frame.instance_texture:SetWidth(BUTTON_WIDTH)
	frame.instance_texture:SetHeight(BUTTON_HEIGHT)
	frame.instance_texture:SetDesaturated(1)
	frame.instance_texture:Hide()

	frame.instance_str = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.instance_str:SetPoint("CENTER", frame.instance_texture, "CENTER", 0, -15)
	frame.instance_str:SetFont(Deathlog_L.menu_font, 13, "OUTLINE")
	frame.instance_str:SetTextColor(1, 1, 1, 1)
	frame.instance_str:SetJustifyH("CENTER")
	frame.instance_str:SetText(title_text)
	frame.instance_str:SetWidth(BUTTON_WIDTH - 5)
	frame.instance_str:Hide()
	
	return frame
end

-- Buttons are keyed by instance_id so they can be reused across filter changes
instance_container.instance_buttons = {}

local function ensureButtonExists(instance_id, file_name, display_name)
	if not instance_container.instance_buttons[instance_id] then
		instance_container.instance_buttons[instance_id] = createInstanceButton(scrollChild, file_name, display_name)
	end
	return instance_container.instance_buttons[instance_id]
end

local function layoutButtons(containerWidth, current_instance_id, setMapRegion)
	local buttonWidth = containerWidth / COLUMNS - HORIZ_SPACING
	local buttonHeight = buttonWidth * 0.5

	local filtered = getFilteredEntries()

	-- Hide all existing buttons first
	for _, button in pairs(instance_container.instance_buttons) do
		button:Hide()
	end

	-- Layout the filtered entries
	for i, v in ipairs(filtered) do
		local button = ensureButtonExists(v[1], v[2], v[3])
		if button then
			local col = (i - 1) % COLUMNS
			local row = math.floor((i - 1) / COLUMNS)
			
			button:ClearAllPoints()
			button:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", col * (buttonWidth + HORIZ_SPACING), -row * (buttonHeight + VERT_SPACING))
			button:SetWidth(buttonWidth)
			button:SetHeight(buttonHeight)
			button.instance_texture:SetWidth(buttonWidth)
			button.instance_texture:SetHeight(buttonHeight)
			button.instance_str:SetWidth(buttonWidth - 5)
			button.instance_str:SetText(v[3])
			button:Show()
			button.instance_texture:Show()
			button.instance_str:Show()

			-- Highlight the currently selected instance
			button.instance_texture:SetDesaturated(v[1] ~= current_instance_id)

			-- Click handler
			button:EnableMouse(true)
			button:SetScript("OnMouseDown", function()
				setMapRegion(v[1], v[3])
			end)
		end
	end
	
	local numRows = math.ceil(#filtered / COLUMNS)
	local totalHeight = numRows * (buttonHeight + VERT_SPACING)
	scrollChild:SetHeight(totalHeight)
	
	return buttonHeight
end

function instance_container.updateMenuElement(scroll_frame, current_instance_id, stats_tbl, setMapRegion)
	instance_container:SetParent(scroll_frame.frame)

	local containerWidth = scroll_frame.frame:GetWidth() * 0.6
	local containerHeight = scroll_frame.frame:GetWidth() * 0.6 * 3 / 4

	instance_container:SetPoint("TOPLEFT", scroll_frame.frame, "TOPLEFT", 0, -55)
	instance_container:SetWidth(containerWidth)
	instance_container:SetHeight(containerHeight)
	instance_container:Show()
	
	scrollFrame:SetParent(instance_container)
	scrollFrame:ClearAllPoints()
	scrollFrame:SetPoint("TOPLEFT", instance_container, "TOPLEFT", 0, 0)
	scrollFrame:SetPoint("BOTTOMRIGHT", instance_container, "BOTTOMRIGHT", -54, 25)
	scrollFrame:Show()
	
	scrollChild:SetWidth(scrollFrame:GetWidth())

	-- Position filter bar inside the scroll child, above the instance buttons
	if show_filter_bar then
		filterBar:SetParent(instance_container)
		filterBar:ClearAllPoints()
		filterBar:SetPoint("BOTTOMLEFT", scrollFrame, "TOPLEFT", 0, 4)
		filterBar:SetWidth(containerWidth)
		filterBar:Show()
	end

	layoutButtons(containerWidth - 20, current_instance_id, setMapRegion)

	-- Store a refresh callback so filter toggles can re-layout
	pendingRefresh = function()
		layoutButtons(containerWidth - 20, current_instance_id, setMapRegion)
	end
end

function Deathlog_InstanceContainer()
	return instance_container
end
