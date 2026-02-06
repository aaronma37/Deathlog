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
				table.insert(sorted_instance_entries, { instance_id, id_to_file_name[instance_id], instance_name, sort_key })
			end
		end
	end
end
table.sort(sorted_instance_entries, function(a, b) return a[4] < b[4] end)

local COLUMNS = 4
local BUTTON_WIDTH = 120
local BUTTON_HEIGHT = 60
local HORIZ_SPACING = 30
local VERT_SPACING = 15

local instance_container = CreateFrame("Frame")
instance_container:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
instance_container:SetSize(1000, 1000)
instance_container:Show()

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

instance_container.instance_buttons = {}

local function ensureButtonExists(index)
	if not instance_container.instance_buttons[index] then
		local data = sorted_instance_entries[index]
		if data then
			instance_container.instance_buttons[index] = createInstanceButton(scrollChild, data[2], data[3])
		end
	end
	return instance_container.instance_buttons[index]
end

local function layoutButtons(containerWidth)
	local buttonWidth = containerWidth / COLUMNS - HORIZ_SPACING
	local buttonHeight = buttonWidth * 0.5
	
	for i, v in ipairs(sorted_instance_entries) do
		local button = ensureButtonExists(i)
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
		end
	end
	
	for i = #sorted_instance_entries + 1, #instance_container.instance_buttons do
		if instance_container.instance_buttons[i] then
			instance_container.instance_buttons[i]:Hide()
		end
	end
	
	local numRows = math.ceil(#sorted_instance_entries / COLUMNS)
	local totalHeight = numRows * (buttonHeight + VERT_SPACING)
	scrollChild:SetHeight(totalHeight)
	
	return buttonHeight
end

function instance_container.updateMenuElement(scroll_frame, current_instance_id, stats_tbl, setMapRegion)
	instance_container:SetParent(scroll_frame.frame)
	instance_container:SetPoint("TOPLEFT", scroll_frame.frame, "TOPLEFT", 0, -55)
	
	local containerWidth = scroll_frame.frame:GetWidth() * 0.6
	local containerHeight = scroll_frame.frame:GetWidth() * 0.6 * 3 / 4
	
	instance_container:SetWidth(containerWidth)
	instance_container:SetHeight(containerHeight)
	instance_container:Show()
	
	scrollFrame:SetParent(instance_container)
	scrollFrame:ClearAllPoints()
	scrollFrame:SetPoint("TOPLEFT", instance_container, "TOPLEFT", 0, 0)
	scrollFrame:SetPoint("BOTTOMRIGHT", instance_container, "BOTTOMRIGHT", -54, 25)
	scrollFrame:Show()
	
	scrollChild:SetWidth(scrollFrame:GetWidth())
	
	local buttonHeight = layoutButtons(containerWidth - 20)
	
	local idx = 1
	for i, v in ipairs(sorted_instance_entries) do
		if current_instance_id == v[1] then
			idx = i
			break
		end
	end

	for i, button in ipairs(instance_container.instance_buttons) do
		if button and button.instance_texture then
			button.instance_texture:SetDesaturated(i ~= idx)
		end
	end

	for i, v in ipairs(sorted_instance_entries) do
		local button = instance_container.instance_buttons[i]
		if button then
			button:EnableMouse(true)
			button:SetScript("OnMouseDown", function()
				setMapRegion(sorted_instance_entries[i][1], sorted_instance_entries[i][3])
			end)
		end
	end
end

function Deathlog_InstanceContainer()
	return instance_container
end
