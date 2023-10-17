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
local deadliest_creatures_container = CreateFrame("Frame")
local environment_damage = {
	[-2] = "Drowning",
	[-3] = "Falling",
	[-4] = "Fatigue",
	[-5] = "Fire",
	[-6] = "Lava",
	[-7] = "Slime",
}
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
	frame.creature_name:SetJustifyH("LEFT")
	frame.creature_name:SetWidth(150)
	frame.creature_name:SetWordWrap(false)
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
		frame.creature_name:SetText(creature_name)
	end

	frame.SetNumKills = function(self, num)
		frame.num_kills_text:SetText(num .. " kills")
	end

	return frame
end
local deadliest_creatures_textures = {}
for i = 1, 10 do
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
	deadliest_creatures_container.heading:SetPoint("TOP", deadliest_creatures_container, "TOP", 0, -20)
	deadliest_creatures_container.heading:Show()
end

if deadliest_creatures_container.heading_description == nil then
	deadliest_creatures_container.heading_description =
		deadliest_creatures_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	deadliest_creatures_container.heading_description:SetText("Mouseover to view on map.")
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

function deadliest_creatures_container.updateMenuElement(scroll_frame, current_map_id, stats_tbl, setMapRegion)
	deadliest_creatures_container.heading:Show()
	deadliest_creatures_container.left:Show()
	deadliest_creatures_container.right:Show()
	local _stats = stats_tbl["stats"]
	local valid_map = C_Map.GetMapInfo(current_map_id)
	if valid_map then
		deadliest_creatures_container.heading_description:Show()
	else
		deadliest_creatures_container.heading_description:Hide()
	end
	local num_recorded_kills = 0
	for i = 1, 10 do
		deadliest_creatures_textures[i]:Hide()
	end
	local map_id = current_map_id
	if map_id == 947 then
		map_id = "all"
	end
	local most_deadly_units = deathlogGetOrdered(_stats, { "all", map_id, "all", nil })
	if most_deadly_units and #most_deadly_units > 0 then
		local max_kills = most_deadly_units[1][2]
		for _, v in ipairs(most_deadly_units) do
			num_recorded_kills = num_recorded_kills + v[2]
		end

		deadliest_creatures_container:SetParent(scroll_frame.frame)
		deadliest_creatures_container:SetPoint("TOPLEFT", scroll_frame.frame, "TOPLEFT", 600, -25)
		deadliest_creatures_container:Show()
		deadliest_creatures_container:SetWidth(scroll_frame.frame:GetWidth() * 0.2)
		deadliest_creatures_container:SetHeight(scroll_frame.frame:GetWidth() * 0.4)
		for i = 1, 10 do
			if i <= #most_deadly_units then
				deadliest_creatures_textures[i]:SetWidth(deadliest_creatures_container:GetWidth())
				deadliest_creatures_textures[i]:SetPoint(
					"TOPLEFT",
					deadliest_creatures_container,
					"TOPLEFT",
					0,
					-35 - i * 15
				)
				deadliest_creatures_textures[i]:SetBackgroundWidth(
					deadliest_creatures_container:GetWidth() * most_deadly_units[i][2] / max_kills
				)
				deadliest_creatures_textures[i]:SetCreatureName(
					id_to_npc[most_deadly_units[i][1]] or environment_damage[most_deadly_units[i][1]]
				)
				deadliest_creatures_textures[i]:SetNumKills(most_deadly_units[i][2])
				if valid_map then
					deadliest_creatures_textures[i]:SetScript("OnEnter", function()
						Deathlog_MapContainer_showSkullSet(most_deadly_units[i][1])
					end)
					deadliest_creatures_textures[i]:SetScript("OnLeave", function()
						Deathlog_MapContainer_resetSkullSet()
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
end

function Deathlog_DeadliestCreatureContainer()
	return deadliest_creatures_container
end
