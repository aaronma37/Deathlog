--[[
CTAWidget – Call-to-Action popup for data-rich Deathlog users.
Shown once per session (with cooldown) when the player has collected enough
death entries to be valuable for the community database.
--]]

local CTA_THRESHOLD_DEFAULT = 25000
local CTA_REMIND_COOLDOWN = 7 * 24 * 3600 -- 7 days in seconds

local BACKDROP_INFO = {
	bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Gold-Border",
	tile     = true,
	tileSize = 32,
	edgeSize = 24,
	insets   = { left = 6, right = 6, top = 6, bottom = 6 },
}

local FRAME_WIDTH  = 440
local FRAME_HEIGHT = 300
local AUTO_DISMISS = 60 -- seconds

---------------------------------------------------------------------------
-- Frame creation
---------------------------------------------------------------------------

local cta_frame = CreateFrame("Frame", "DeathlogCTAWidget", UIParent, "BackdropTemplate")
cta_frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
cta_frame:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
cta_frame:SetBackdrop(BACKDROP_INFO)
cta_frame:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
cta_frame:SetBackdropBorderColor(0.85, 0.65, 0.15, 1)
cta_frame:SetFrameStrata("DIALOG")
cta_frame:SetMovable(true)
cta_frame:EnableMouse(true)
cta_frame:RegisterForDrag("LeftButton")
cta_frame:SetScript("OnDragStart", cta_frame.StartMoving)
cta_frame:SetScript("OnDragStop", cta_frame.StopMovingOrSizing)
cta_frame:SetClampedToScreen(true)
cta_frame:Hide()

-- Close button (top-right X)
local close_btn = CreateFrame("Button", nil, cta_frame, "UIPanelCloseButton")
close_btn:SetPoint("TOPRIGHT", cta_frame, "TOPRIGHT", -2, -2)
close_btn:SetScript("OnClick", function()
	cta_frame:Hide()
end)

---------------------------------------------------------------------------
-- Title with skull icon
---------------------------------------------------------------------------

local skull_icon = cta_frame:CreateTexture(nil, "ARTWORK")
skull_icon:SetTexture("Interface\\TARGETINGFRAME\\UI-TargetingFrame-Skull")
skull_icon:SetSize(28, 28)
skull_icon:SetPoint("TOPLEFT", cta_frame, "TOPLEFT", 14, -14)

local title_text = cta_frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title_text:SetPoint("LEFT", skull_icon, "RIGHT", 8, 0)
title_text:SetTextColor(1, 0.82, 0)

---------------------------------------------------------------------------
-- Body text
---------------------------------------------------------------------------

local body_text = cta_frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
body_text:SetPoint("TOPLEFT", skull_icon, "BOTTOMLEFT", 0, -12)
body_text:SetPoint("RIGHT", cta_frame, "RIGHT", -18, 0)
body_text:SetJustifyH("LEFT")
body_text:SetSpacing(2)

---------------------------------------------------------------------------
-- File path hint
---------------------------------------------------------------------------

local path_text = cta_frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
path_text:SetPoint("TOPLEFT", body_text, "BOTTOMLEFT", 0, -10)
path_text:SetPoint("RIGHT", cta_frame, "RIGHT", -18, 0)
path_text:SetJustifyH("LEFT")
path_text:SetTextColor(0.7, 0.7, 0.7)

---------------------------------------------------------------------------
-- Contact EditBox helper (select-all on focus so user can Ctrl+C)
---------------------------------------------------------------------------

local function createCopyBox(parent, anchor_point, anchor_to, anchor_rel, x_off, y_off, width, display_label, copy_text)
	local label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetPoint(anchor_point, anchor_to, anchor_rel, x_off, y_off)
	label:SetText(display_label)
	label:SetTextColor(1, 0.82, 0)

	local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	box:SetPoint("LEFT", label, "RIGHT", 8, 0)
	box:SetSize(width, 20)
	box:SetAutoFocus(false)
	box:SetText(copy_text)
	box:SetScript("OnEditFocusGained", function(self)
		self:HighlightText()
	end)
	box:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	-- Prevent editing
	box:SetScript("OnChar", function(self)
		self:SetText(copy_text)
		self:HighlightText()
	end)
	box:SetScript("OnTextChanged", function(self, user_input)
		if user_input then
			self:SetText(copy_text)
			self:HighlightText()
		end
	end)

	return label, box
end

---------------------------------------------------------------------------
-- Discord + Email contact rows
---------------------------------------------------------------------------

local discord_label, discord_box = createCopyBox(
	cta_frame, "TOPLEFT", path_text, "BOTTOMLEFT", 0, -14, 180,
	"|TInterface\\AddOns\\Deathlog\\Media\\discord_icon:14:14|t Discord:",
	"deathwing1337"
)

-- Use a simple icon texture fallback for Discord
discord_label:SetText("Discord:")

local email_label, email_box = createCopyBox(
	cta_frame, "TOPLEFT", discord_label, "BOTTOMLEFT", 0, -10, 250,
	"Email:", "deathwing4528@googlemail.com"
)

---------------------------------------------------------------------------
-- Action buttons
---------------------------------------------------------------------------

local btn_width = 140
local btn_height = 24

-- "Remind me later" button
local remind_btn = CreateFrame("Button", nil, cta_frame, "UIPanelButtonTemplate")
remind_btn:SetSize(btn_width, btn_height)
remind_btn:SetPoint("BOTTOMLEFT", cta_frame, "BOTTOMLEFT", 20, 16)
remind_btn:SetScript("OnClick", function()
	-- cta_last_shown already set when popup was triggered — just hide
	cta_frame:Hide()
end)

-- "Don't show again" button
local dismiss_btn = CreateFrame("Button", nil, cta_frame, "UIPanelButtonTemplate")
dismiss_btn:SetSize(btn_width, btn_height)
dismiss_btn:SetPoint("BOTTOMRIGHT", cta_frame, "BOTTOMRIGHT", -20, 16)
dismiss_btn:SetScript("OnClick", function()
	deathlog_settings["cta_dismissed"] = true
	cta_frame:Hide()
end)

---------------------------------------------------------------------------
-- Auto-dismiss timer
---------------------------------------------------------------------------

local auto_timer = nil

cta_frame:SetScript("OnShow", function(self)
	if auto_timer then
		auto_timer:Cancel()
	end
	auto_timer = C_Timer.NewTimer(AUTO_DISMISS, function()
		if self:IsShown() then
			self:Hide()
		end
	end)
end)

cta_frame:SetScript("OnHide", function()
	if auto_timer then
		auto_timer:Cancel()
		auto_timer = nil
	end
end)

-- Register ESC to close
tinsert(UISpecialFrames, "DeathlogCTAWidget")

local function getTotalEntryCount()
    if not deathlog_entry_counts then return 0 end
    return deathlog_entry_counts["total"] or 0
end

local function getValidEntryCount()
	if not deathlog_entry_counts then return 0 end
	local self_death = deathlog_entry_counts["self_death"] or 0
    local peer_broadcast = deathlog_entry_counts["peer_broadcast"] or 0
	return self_death + peer_broadcast
end

local function isThresholdReached()
	local threshold = deathlog_settings["cta_threshold"] or CTA_THRESHOLD_DEFAULT

    if getValidEntryCount() < threshold then
		return false
	end

    return true
end

--- Show the CTA popup with the given entry count.
--- @param count number  The entry count to display
local function showCTA(count)
	-- Apply localized strings
	title_text:SetText(Deathlog_L.cta_title or "Your Deathlog Data Matters!")

	local body = Deathlog_L.cta_body or "You've collected over %d death entries — that's incredible!\n\nThis data helps us build better stats, heatmaps, and insights for the entire hardcore community.\n\nPlease consider sharing your database file with us!"
	body_text:SetText(string.format(body, count))

	path_text:SetText(Deathlog_L.cta_file_path or "File: WTF/Account/<name>/SavedVariables/Deathlog.lua")

	remind_btn:SetText(Deathlog_L.cta_remind_later or "Remind me later")
	dismiss_btn:SetText(Deathlog_L.cta_dismiss or "Don't show again")

	cta_frame:Show()
end

---------------------------------------------------------------------------
-- CTA eligibility logic
---------------------------------------------------------------------------

--- Check if the CTA popup should be shown and display it if eligible.
function Deathlog_CheckCTA()
	if InCombatLockdown() or deathlog_settings["cta_dismissed"] == true then
		return
	end

	local last_shown = deathlog_settings["cta_last_shown"] or 0
	if (time() - last_shown) < CTA_REMIND_COOLDOWN then
		return
	end

    if not isThresholdReached() then
        return
    end

	deathlog_settings["cta_last_shown"] = time()

	showCTA(getTotalEntryCount())
end

--- Check if CTA banner should be visible in the menu.
--- Unlike the popup, the menu banner shows even after "remind me later" — only "dismiss" kills it.
--- @return boolean eligible
--- @return number count  non-sync entry count
function Deathlog_CTAMenuEligible()
	if deathlog_settings["cta_dismissed"] == true then
		return false, 0
	end

    if not isThresholdReached() then
        return false, 0
    end

    return true, getTotalEntryCount()
end
