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
creature_model_container.modelFrame:SetRotation(0)
creature_model_container.modelFrame:SetCamDistanceScale(1.5)
creature_model_container.modelFrame:SetPortraitZoom(0.6)
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
	if id_to_quote[creature_id] then
		creature_model_container.quote:SetText('"' .. id_to_quote[creature_id] .. '"')
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

	-- if creature_model_container.textures.top == nil then
	-- 	creature_model_container.textures.top = creature_model_container.modelFrame:CreateTexture(nil, "OVERLAY")
	-- end
	-- creature_model_container.textures.top:SetTexture("Interface\\BlackMarket\\_WoodFrame-TileHorizontal")
	-- creature_model_container.textures.top:SetTexCoord(0, 1, 0.5, 1)
	-- creature_model_container.textures.top:SetPoint("TOP", creature_model_container.modelFrame, "TOP", 0, 6)
	-- creature_model_container.textures.top:SetWidth(creature_model_container.modelFrame:GetWidth())
	-- creature_model_container.textures.top:SetHeight(creature_model_container.modelFrame:GetWidth() * 0.1)

	-- if creature_model_container.textures.bottom == nil then
	-- 	creature_model_container.textures.bottom = creature_model_container.modelFrame:CreateTexture(nil, "OVERLAY")
	-- end
	-- creature_model_container.textures.bottom:SetTexture("Interface\\BlackMarket\\_WoodFrame-TileHorizontal")
	-- creature_model_container.textures.bottom:SetTexCoord(0, 1, 0, 0.5)
	-- creature_model_container.textures.bottom:SetPoint("Bottom", creature_model_container.modelFrame, "Bottom", 0, -6)
	-- creature_model_container.textures.bottom:SetWidth(creature_model_container.modelFrame:GetWidth())
	-- creature_model_container.textures.bottom:SetHeight(creature_model_container.modelFrame:GetWidth() * 0.1)
	-- creature_model_container.textures.bottom:SetDrawLayer("OVERLAY", 7)

	-- if creature_model_container.textures.right == nil then
	-- 	creature_model_container.textures.right = creature_model_container.modelFrame:CreateTexture(nil, "OVERLAY")
	-- end
	-- creature_model_container.textures.right:SetTexture("Interface\\BlackMarket\\!WoodFrame-TileVertical")
	-- creature_model_container.textures.right:SetTexCoord(0, 0.5, 0, 1)
	-- creature_model_container.textures.right:SetPoint("RIGHT", creature_model_container.modelFrame, "RIGHT", 6, 0)
	-- creature_model_container.textures.right:SetWidth(creature_model_container.modelFrame:GetHeight() * 0.1)
	-- creature_model_container.textures.right:SetHeight(creature_model_container.modelFrame:GetHeight())
	-- creature_model_container.textures.right:SetDrawLayer("OVERLAY", 7)

	-- if creature_model_container.textures.left == nil then
	-- 	creature_model_container.textures.left = creature_model_container.modelFrame:CreateTexture(nil, "OVERLAY")
	-- end
	-- creature_model_container.textures.left:SetTexture("Interface\\BlackMarket\\!WoodFrame-TileVertical")
	-- creature_model_container.textures.left:SetTexCoord(0.5, 1, 0, 1)
	-- creature_model_container.textures.left:SetPoint("LEFT", creature_model_container.modelFrame, "LEFT", -6, 0)
	-- creature_model_container.textures.left:SetWidth(creature_model_container.modelFrame:GetHeight() * 0.1)
	-- creature_model_container.textures.left:SetHeight(creature_model_container.modelFrame:GetHeight())
	-- creature_model_container.textures.left:SetDrawLayer("OVERLAY", 7)
	if creature_model_container.textures.map == nil then
		creature_model_container.textures.map = creature_model_container.modelFrame:CreateTexture(nil, "OVERLAY")
	end
	creature_model_container.textures.map:SetTexture("Interface\\AdventureMap\\AdventureMap")
	creature_model_container.textures.map:SetTexCoord(0.35, 0.78, 0, 0.3)
	creature_model_container.textures.map:SetPoint("CENTER", creature_model_container.modelFrame, "CENTER", 0, 0)
	creature_model_container.textures.map:SetWidth(creature_model_container.modelFrame:GetWidth() * 1.065)
	creature_model_container.textures.map:SetHeight(creature_model_container.modelFrame:GetHeight() * 1.1)
	creature_model_container.textures.map:SetDrawLayer("OVERLAY", 7)

	-- if creature_model_container.textures.out == nil then
	-- 	creature_model_container.textures.out = creature_model_container.modelFrame:CreateTexture(nil, "OVERLAY")
	-- end
	-- creature_model_container.textures.out:SetTexture("Interface\\AdventureMap\\AdventureMapBorder")
	-- creature_model_container.textures.out:SetTexCoord(0, 1, 0, 0.65)
	-- creature_model_container.textures.out:SetPoint("CENTER", creature_model_container.modelFrame, "CENTER", 0, 0)
	-- creature_model_container.textures.out:SetWidth(creature_model_container.modelFrame:GetWidth())
	-- creature_model_container.textures.out:SetHeight(creature_model_container.modelFrame:GetHeight())
	-- creature_model_container.textures.out:SetDrawLayer("OVERLAY", 7)
end

function Deathlog_CreatureModelContainer()
	return creature_model_container
end
