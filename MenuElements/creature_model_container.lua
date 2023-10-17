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

local _, _, _, tocversion = GetBuildInfo()

creature_model_container.modelFrame = CreateFrame("PlayerModel", nil, creature_model_container)
creature_model_container.modelFrame:SetPoint("TOPLEFT", creature_model_container, "TOPLEFT", 0, 0)
creature_model_container.modelFrame:SetHeight(500)
creature_model_container.modelFrame:SetWidth(500)
if tocversion >= 11404 then
	creature_model_container.modelFrame:SetCreature(1693)
else
	creature_model_container.modelFrame:SetDisplayInfo(1693)
end
creature_model_container.modelFrame:SetRotation(0)
creature_model_container.modelFrame:SetCamDistanceScale(1.5)
creature_model_container.modelFrame:SetPortraitZoom(0.6)
creature_model_container.modelFrame:Hide()

creature_model_container.quote = creature_model_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
creature_model_container.quote:SetText("")
creature_model_container.quote:SetFont(Deathlog_L.creature_model_quote_font, 14, "THICK")
creature_model_container.quote:SetJustifyV("TOP")
creature_model_container.quote:SetJustifyH("CENTER")
creature_model_container.quote:SetTextColor(0.7, 0.7, 0.7)
creature_model_container.quote:Show()

local animation = CreateFrame("Frame")

function creature_model_container.updateMenuElement(scroll_frame, creature_id, stats_tbl, updatefun)
	if id_to_display_id[creature_id] ~= nil then
		if tocversion >= 11404 then
			creature_model_container.modelFrame:SetCreature(creature_id)
		else
			creature_model_container.modelFrame:SetDisplayInfo(id_to_display_id[creature_id])
		end
		creature_model_container:SetParent(scroll_frame.frame)
		creature_model_container:Show()
		creature_model_container.modelFrame:Show()
		creature_model_container:SetPoint("TOPLEFT", scroll_frame.frame, "TOPLEFT", 620, -45)
		creature_model_container.modelFrame:SetPoint("TOPLEFT", creature_model_container, "TOPLEFT", 0, 0)
		creature_model_container:SetWidth(180)
		creature_model_container:SetHeight(180)
		creature_model_container.modelFrame:SetWidth(180)
		creature_model_container.modelFrame:SetHeight(180)
		creature_model_container.modelFrame:SetModelDrawLayer("ARTWORK", 1) -- put model at drawLayer of texture
	else
		creature_model_container:Hide()
	end
	if Deathlog_L.id_to_quote[creature_id] then
		creature_model_container.quote:SetText('"' .. Deathlog_L.id_to_quote[creature_id] .. '"')
		creature_model_container.quote:SetParent(creature_model_container.modelFrame)

		creature_model_container.quote:SetPoint("BOTTOM", creature_model_container, "BOTTOM", 0, 25)
		creature_model_container.quote:SetWidth(200)
		creature_model_container.quote:Show()
	else
		creature_model_container.quote:Hide()
	end

	if creature_model_container.textures == nil then
		creature_model_container.textures = {}
	end

	if creature_model_container.textures.map == nil then
		creature_model_container.textures.map = creature_model_container.modelFrame:CreateTexture(nil, "OVERLAY")
	end
	creature_model_container.textures.map:SetTexture("Interface\\AdventureMap\\AdventureMap")
	creature_model_container.textures.map:SetTexCoord(0.35, 0.78, 0, 0.3)
	creature_model_container.textures.map:SetPoint("CENTER", creature_model_container.modelFrame, "CENTER", 0, 0)
	creature_model_container.textures.map:SetWidth(creature_model_container.modelFrame:GetWidth() * 1.065)
	creature_model_container.textures.map:SetHeight(creature_model_container.modelFrame:GetHeight() * 1.1)
	creature_model_container.textures.map:SetDrawLayer("OVERLAY", 7)
end

function Deathlog_CreatureModelContainer()
	return creature_model_container
end
