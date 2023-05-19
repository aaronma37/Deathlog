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
local creature_model_container = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
creature_model_container:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
creature_model_container:SetSize(500, 500)
creature_model_container:Hide()
creature_model_container:SetBackdropColor(0, 0.4, 0, 1)
creature_model_container:SetMovable(false)

creature_model_container.modelFrame = CreateFrame("PlayerModel", nil, creature_model_container)
creature_model_container.modelFrame:SetPoint("TOPLEFT", creature_model_container, "TOPLEFT", 0, 0)
creature_model_container.modelFrame:SetHeight(500)
creature_model_container.modelFrame:SetWidth(500)
creature_model_container.modelFrame:SetDisplayInfo(1693)
creature_model_container.modelFrame:SetRotation(0.8)
creature_model_container.modelFrame:SetCamDistanceScale(1.5)
creature_model_container.modelFrame:Hide()

creature_model_container.quote = creature_model_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
creature_model_container.quote:SetText("")
creature_model_container.quote:SetFont("Fonts\\MORPHEUS.TTF", 14, "THICK")
creature_model_container.quote:SetJustifyV("TOP")
creature_model_container.quote:SetJustifyH("CENTER")
creature_model_container.quote:SetTextColor(0.7, 0.7, 0.7)
creature_model_container.quote:Show()

local animation = CreateFrame("Frame")

function creature_model_container.updateMenuElement(scroll_frame, creature_id, stats_tbl, updatefun)
	if id_to_display_id[creature_id] ~= nil then
		creature_model_container.modelFrame:SetDisplayInfo(id_to_display_id[creature_id])
		creature_model_container.modelFrame:RefreshCamera()
		creature_model_container:SetParent(scroll_frame.frame)
		creature_model_container:Show()
		creature_model_container.modelFrame:Show()
		creature_model_container:SetPoint("TOPLEFT", scroll_frame.frame, "TOPLEFT", 620, -35)
		creature_model_container.modelFrame:SetPoint("TOPLEFT", creature_model_container, "TOPLEFT", 0, 0)
		creature_model_container:SetWidth(200)
		creature_model_container:SetHeight(200)
		creature_model_container.modelFrame:SetWidth(200)
		creature_model_container.modelFrame:SetHeight(200)
	else
		creature_model_container:Hide()
	end
	if id_to_quote[creature_id] then
		creature_model_container.quote:SetText('"' .. id_to_quote[creature_id] .. '"')
		creature_model_container.quote:SetParent(creature_model_container.modelFrame)

		creature_model_container.quote:SetPoint("BOTTOM", creature_model_container, "BOTTOM", 0, 25)
		creature_model_container.quote:SetWidth(200)
		creature_model_container.quote:Show()
	else
		creature_model_container.quote:Hide()
	end
end

function Deathlog_CreatureModelContainer()
	return creature_model_container
end
