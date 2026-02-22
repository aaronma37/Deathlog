--[[
Copyright 2026 Yazpad & Deathwing
The Deathlog AddOn is distributed under the terms of the GNU General Public License (or the Lesser GPL).
This file is part of Deathlog.

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
-- CTA (Call-to-Action) menu banner for data-rich users.
-- Follows the MenuElement pattern: container frame with updateMenuElement().

local cta_banner_container = CreateFrame("Frame", "DeathlogCTABanner", nil, "BackdropTemplate")
cta_banner_container:SetHeight(40)
cta_banner_container:SetBackdrop({
	bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
	tile     = true,
	tileSize = 16,
	edgeSize = 12,
	insets   = { left = 3, right = 3, top = 3, bottom = 3 },
})
cta_banner_container:SetBackdropColor(0.15, 0.12, 0.02, 0.9)
cta_banner_container:SetBackdropBorderColor(0.85, 0.65, 0.15, 0.8)
cta_banner_container:Hide()

---------------------------------------------------------------------------
-- Skull icon + label
---------------------------------------------------------------------------

local skull = cta_banner_container:CreateTexture(nil, "ARTWORK")
skull:SetTexture("Interface\\TARGETINGFRAME\\UI-TargetingFrame-Skull")
skull:SetSize(18, 18)
skull:SetPoint("LEFT", cta_banner_container, "LEFT", 8, 0)

cta_banner_container.label = cta_banner_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
cta_banner_container.label:SetPoint("LEFT", skull, "RIGHT", 6, 0)
cta_banner_container.label:SetTextColor(1, 0.82, 0)

---------------------------------------------------------------------------
-- Discord copy button + inline editbox
---------------------------------------------------------------------------

local discord_btn = CreateFrame("Button", nil, cta_banner_container, "UIPanelButtonTemplate")
discord_btn:SetSize(90, 18)
discord_btn:SetPoint("RIGHT", cta_banner_container, "RIGHT", -100, 0)
discord_btn:SetText("Discord")
discord_btn:SetScript("OnClick", function()
	if cta_banner_container.discord_editbox and cta_banner_container.discord_editbox:IsShown() then
		cta_banner_container.discord_editbox:Hide()
	else
		if not cta_banner_container.discord_editbox then
			cta_banner_container.discord_editbox = CreateFrame("EditBox", nil, cta_banner_container, "InputBoxTemplate")
			cta_banner_container.discord_editbox:SetSize(140, 20)
			cta_banner_container.discord_editbox:SetPoint("BOTTOM", discord_btn, "TOP", 0, 2)
			cta_banner_container.discord_editbox:SetAutoFocus(false)
			cta_banner_container.discord_editbox:SetText("deathwing1337")
			cta_banner_container.discord_editbox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
			cta_banner_container.discord_editbox:SetScript("OnEscapePressed", function(self) self:ClearFocus(); self:Hide() end)
			cta_banner_container.discord_editbox:SetScript("OnChar", function(self) self:SetText("deathwing1337"); self:HighlightText() end)
		end
		cta_banner_container.discord_editbox:Show()
		cta_banner_container.discord_editbox:SetFocus()
		cta_banner_container.discord_editbox:HighlightText()
	end
end)

---------------------------------------------------------------------------
-- Email copy button + inline editbox
---------------------------------------------------------------------------

local email_btn = CreateFrame("Button", nil, cta_banner_container, "UIPanelButtonTemplate")
email_btn:SetSize(90, 18)
email_btn:SetPoint("RIGHT", cta_banner_container, "RIGHT", -6, 0)
email_btn:SetText("Email")
email_btn:SetScript("OnClick", function()
	if cta_banner_container.email_editbox and cta_banner_container.email_editbox:IsShown() then
		cta_banner_container.email_editbox:Hide()
	else
		if not cta_banner_container.email_editbox then
			cta_banner_container.email_editbox = CreateFrame("EditBox", nil, cta_banner_container, "InputBoxTemplate")
			cta_banner_container.email_editbox:SetSize(220, 20)
			cta_banner_container.email_editbox:SetPoint("BOTTOM", email_btn, "TOP", 0, 2)
			cta_banner_container.email_editbox:SetAutoFocus(false)
			cta_banner_container.email_editbox:SetText("deathwing4528@googlemail.com")
			cta_banner_container.email_editbox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
			cta_banner_container.email_editbox:SetScript("OnEscapePressed", function(self) self:ClearFocus(); self:Hide() end)
			cta_banner_container.email_editbox:SetScript("OnChar", function(self) self:SetText("deathwing4528@googlemail.com"); self:HighlightText() end)
		end
		cta_banner_container.email_editbox:Show()
		cta_banner_container.email_editbox:SetFocus()
		cta_banner_container.email_editbox:HighlightText()
	end
end)

---------------------------------------------------------------------------
-- Dismiss (X) button
---------------------------------------------------------------------------

local dismiss_btn = CreateFrame("Button", nil, cta_banner_container)
dismiss_btn:SetSize(16, 16)
dismiss_btn:SetPoint("TOPRIGHT", cta_banner_container, "TOPRIGHT", -2, -2)
dismiss_btn:SetNormalTexture("Interface\\Buttons\\UI-StopButton")
dismiss_btn:SetHighlightTexture("Interface\\Buttons\\UI-StopButton")
dismiss_btn:SetScript("OnClick", function()
	deathlog_settings["cta_dismissed"] = true
	cta_banner_container:Hide()
end)

---------------------------------------------------------------------------
-- updateMenuElement – called by menu.lua when the menu opens
---------------------------------------------------------------------------

--- @param parent_frame Frame  The menu's top-level frame to anchor to
function cta_banner_container.updateMenuElement(parent_frame)
	if not Deathlog_CTAMenuEligible then
		cta_banner_container:Hide()
		return
	end

	local eligible, count = Deathlog_CTAMenuEligible()
	if not eligible then
		cta_banner_container:Hide()
		return
	end

	cta_banner_container:SetParent(parent_frame)
	cta_banner_container:ClearAllPoints()
	cta_banner_container:SetPoint("BOTTOMLEFT", parent_frame, "TOPLEFT", 12, -25)
	cta_banner_container:SetPoint("BOTTOMRIGHT", parent_frame, "TOPRIGHT", -35, -25)
	cta_banner_container:SetFrameLevel(parent_frame:GetFrameLevel() + 10)

	local msg = Deathlog_L.cta_menu_banner or "You have %d entries! Help the community — share your data."
	cta_banner_container.label:SetText(string.format(msg, count))
	cta_banner_container:Show()
end

---------------------------------------------------------------------------
-- Public constructor
---------------------------------------------------------------------------

function Deathlog_CTABannerContainer()
	return cta_banner_container
end
