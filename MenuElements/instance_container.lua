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
local instance_tbl = Deathlog_L.instance_tbl

local instance_container = CreateFrame("Frame")
instance_container:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
instance_container:SetSize(1000, 1000)
instance_container:Show()

local function createInstanceButton(path_postfix, title_text)
	local frame = CreateFrame("Frame")
	frame:SetParent(instance_container)
	frame:SetPoint("TOPLEFT", instance_container, "TOPLEFT", 0, 0)
	frame:SetWidth(60)
	frame:SetHeight(20)
	frame:Hide()
	frame.instance_texture = frame:CreateTexture(nil, "OVERLAY")
	frame.instance_texture:SetDrawLayer("OVERLAY", 7)
	frame.instance_texture:SetVertexColor(1, 1, 1, 1)
	frame.instance_texture:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
	frame.instance_texture:SetTexture("Interface\\LFGFRAME\\UI-LFG-BACKGROUND-" .. path_postfix)
	frame.instance_texture:SetParent(frame)
	frame.instance_texture:SetDesaturated(1)
	frame.instance_texture:Hide()

	frame.instance_str = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.instance_str:SetPoint("CENTER", frame.instance_texture, "CENTER", 0, -20)
	frame.instance_str:SetFont(Deathlog_L.menu_font, 15, "OUTLINE")
	frame.instance_str:SetTextColor(1, 1, 1, 1)
	frame.instance_str:SetJustifyH("CENTER")
	frame.instance_str:SetText(title_text)
	frame.instance_str:SetWidth(180)
	frame.instance_str:Hide()
	return frame
end

instance_container.instance_buttons = {}
for i, v in ipairs(instance_tbl) do
	instance_container.instance_buttons[i] = createInstanceButton(v[2], v[3])
	instance_container.instance_buttons[i]:Show()
end

for i = 2, #instance_container.instance_buttons do
	instance_container.instance_buttons[i]:SetPoint(
		"TOPLEFT",
		instance_container.instance_buttons[i - 1],
		"TOPLEFT",
		10,
		-10
	)
end

function instance_container.updateMenuElement(scroll_frame, current_instance_id, stats_tbl, setMapRegion)
	instance_container:SetParent(scroll_frame.frame)
	instance_container:SetPoint("TOPLEFT", scroll_frame.frame, "TOPLEFT", 0, -55)
	instance_container:SetHeight(scroll_frame.frame:GetWidth() * 0.6 * 3 / 4)
	instance_container:SetWidth(scroll_frame.frame:GetWidth() * 0.6)
	instance_container:Show()

	local vert_sep = -75

	for i = 1, #instance_tbl do
		instance_container.instance_buttons[i]:SetHeight(instance_container:GetWidth() / 10)
		instance_container.instance_buttons[i]:SetWidth(instance_container:GetWidth() / 10 * 2)
		instance_container.instance_buttons[i].instance_texture:SetHeight(instance_container:GetWidth() / 10)
		instance_container.instance_buttons[i].instance_texture:SetWidth(instance_container:GetWidth() / 10 * 2)
		instance_container.instance_buttons[i]:Show()
		instance_container.instance_buttons[i].instance_texture:Show()
		instance_container.instance_buttons[i].instance_str:Show()
	end
	instance_container.instance_buttons[2]:SetPoint(
		"TOPLEFT",
		instance_container.instance_buttons[1],
		"TOPLEFT",
		150,
		0
	)
	instance_container.instance_buttons[3]:SetPoint(
		"TOPLEFT",
		instance_container.instance_buttons[2],
		"TOPLEFT",
		150,
		0
	)
	instance_container.instance_buttons[4]:SetPoint(
		"TOPLEFT",
		instance_container.instance_buttons[3],
		"TOPLEFT",
		150,
		0
	)

	instance_container.instance_buttons[5]:SetPoint(
		"TOPLEFT",
		instance_container.instance_buttons[1],
		"TOPLEFT",
		0,
		vert_sep
	)
	instance_container.instance_buttons[6]:SetPoint(
		"TOPLEFT",
		instance_container.instance_buttons[2],
		"TOPLEFT",
		0,
		vert_sep
	)
	instance_container.instance_buttons[7]:SetPoint(
		"TOPLEFT",
		instance_container.instance_buttons[3],
		"TOPLEFT",
		0,
		vert_sep
	)
	instance_container.instance_buttons[8]:SetPoint(
		"TOPLEFT",
		instance_container.instance_buttons[4],
		"TOPLEFT",
		0,
		vert_sep
	)

	instance_container.instance_buttons[9]:SetPoint(
		"TOPLEFT",
		instance_container.instance_buttons[5],
		"TOPLEFT",
		0,
		vert_sep
	)
	instance_container.instance_buttons[10]:SetPoint(
		"TOPLEFT",
		instance_container.instance_buttons[6],
		"TOPLEFT",
		0,
		vert_sep
	)
	instance_container.instance_buttons[11]:SetPoint(
		"TOPLEFT",
		instance_container.instance_buttons[7],
		"TOPLEFT",
		0,
		vert_sep
	)
	instance_container.instance_buttons[12]:SetPoint(
		"TOPLEFT",
		instance_container.instance_buttons[8],
		"TOPLEFT",
		0,
		vert_sep
	)

	instance_container.instance_buttons[13]:SetPoint(
		"TOPLEFT",
		instance_container.instance_buttons[9],
		"TOPLEFT",
		0,
		vert_sep
	)
	instance_container.instance_buttons[14]:SetPoint(
		"TOPLEFT",
		instance_container.instance_buttons[10],
		"TOPLEFT",
		0,
		vert_sep
	)
	instance_container.instance_buttons[15]:SetPoint(
		"TOPLEFT",
		instance_container.instance_buttons[11],
		"TOPLEFT",
		0,
		vert_sep
	)
	instance_container.instance_buttons[16]:SetPoint(
		"TOPLEFT",
		instance_container.instance_buttons[12],
		"TOPLEFT",
		0,
		vert_sep
	)

	instance_container.instance_buttons[17]:SetPoint(
		"TOPLEFT",
		instance_container.instance_buttons[13],
		"TOPLEFT",
		0,
		vert_sep
	)
	instance_container.instance_buttons[18]:SetPoint(
		"TOPLEFT",
		instance_container.instance_buttons[14],
		"TOPLEFT",
		0,
		vert_sep
	)
	instance_container.instance_buttons[19]:SetPoint(
		"TOPLEFT",
		instance_container.instance_buttons[15],
		"TOPLEFT",
		0,
		vert_sep
	)
	instance_container.instance_buttons[20]:SetPoint(
		"TOPLEFT",
		instance_container.instance_buttons[16],
		"TOPLEFT",
		0,
		vert_sep
	)

	local idx = 1
	for i, v in ipairs(instance_tbl) do
		if current_instance_id == v[1] then
			idx = i
			break
		end
	end

	for _, v in ipairs(instance_container.instance_buttons) do
		v.instance_texture:SetDesaturated(1)
	end

	instance_container.instance_buttons[idx].instance_texture:SetDesaturated(nil)

	for i, v in ipairs(instance_container.instance_buttons) do
		instance_container.instance_buttons[i]:SetScript("OnMouseDown", function()
			setMapRegion(instance_tbl[i][1], instance_tbl[i][3])
		end)
	end
end

function Deathlog_InstanceContainer()
	return instance_container
end
