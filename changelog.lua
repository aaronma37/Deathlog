--[[
Copyright 2026 Yazpad & Deathwing
The Deathlog AddOn is distributed under the terms of the GNU General Public License.
This file is part of Deathlog.
--]]

-- In-game changelog popup
-- Shows automatically on first load after a version upgrade

local addonName, addon = ...
local AceGUI = LibStub("AceGUI-3.0")

-- API compatibility: Classic Era uses GetAddOnMetadata, TBC Anniversary uses C_AddOns.GetAddOnMetadata
local GetAddOnMetadata = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata

-- Current version from TOC
local CURRENT_VERSION = GetAddOnMetadata("Deathlog", "Version") or "0.0.0"

-- Changelog content (update this with each release)
local CHANGELOG_CONTENT = [[
|cFFFFD700Deathlog Changelog|r

|cFF00FF00[0.4.5] - 2026-02-28|r
- Fixed major FPS drop when heatmap is enabled (world map and statistics map)
- New "Heatmap Resolution" setting in options (Low / Medium / High / Ultra)
- Fixed API compatibility for older clients

|cFF00FF00[0.4.4] - 2026-02-27|r

|cFFFFFFFFNew Features|r
- In-game changelog popup (you're looking at it!)
- Death filter for minilog and alerts - show all, guild only, or none
- GreenWall support - filter by your entire guild confederation

|cFFFFFFFFBug Fixes|r
- Fixed various crashes and improved stability

|cFF888888Use /dl changelog to open this anytime|r

|cFF00FF00[0.4.3] - 2026-02-26|r
- Fixed multiple "newer version" messages per session

|cFF00FF00[0.4.2] - 2026-02-25|r
- Fixed /played spam in secondary chat tabs

|cFF00FF00[0.4.1] - 2026-02-24|r
- Fixed watchlist queries
- Fixed death alert crashes
- Fixed minilog font and click issues
- Fixed duplicate death entries
- New "Auto-hide addon channels" setting
- Improved watchlist detection
- "Update Available" indicator on info button

|cFF888888For full details, see CHANGELOG.md|r
]]

local changelog_frame = nil

--- Check if the changelog popup is currently visible
local function isChangelogVisible()
	return changelog_frame ~= nil and changelog_frame.frame and changelog_frame.frame:IsShown()
end

--- Creates and shows the changelog popup
local function showChangelog()
	if changelog_frame then
		changelog_frame:Show()
		return
	end

	changelog_frame = AceGUI:Create("Frame")
	changelog_frame:SetTitle("Deathlog - What's New")
	changelog_frame:SetStatusText("Version " .. CURRENT_VERSION)
	changelog_frame:SetLayout("Fill")
	changelog_frame:SetWidth(500)
	changelog_frame:SetHeight(450)
	changelog_frame:SetCallback("OnClose", function(widget)
		AceGUI:Release(widget)
		changelog_frame = nil
	end)

	local scrollFrame = AceGUI:Create("ScrollFrame")
	scrollFrame:SetLayout("Flow")
	changelog_frame:AddChild(scrollFrame)

	local label = AceGUI:Create("Label")
	label:SetText(CHANGELOG_CONTENT)
	label:SetFullWidth(true)
	label:SetFont(GameFontNormal:GetFont(), 12, "")
	scrollFrame:AddChild(label)

	-- Add "Don't show again for this version" checkbox at the bottom
	local checkbox = AceGUI:Create("CheckBox")
	checkbox:SetLabel("Don't show this changelog again")
	checkbox:SetValue(false)
	checkbox:SetCallback("OnValueChanged", function(widget, event, value)
		if value then
			deathlog_settings["last_changelog_version"] = CURRENT_VERSION
		end
	end)
	scrollFrame:AddChild(checkbox)
end

--- Checks if we should show the changelog (version upgrade detected)
local function checkShowChangelog()
	if deathlog_settings == nil then
		deathlog_settings = {}
	end

	local last_version = deathlog_settings["last_seen_version"]
	local last_changelog_version = deathlog_settings["last_changelog_version"]

	-- Always update to current version
	deathlog_settings["last_seen_version"] = CURRENT_VERSION

	-- Detect existing user: they have settings but no last_seen_version (pre-0.4.4 user)
	local is_existing_user = false
	if not last_version then
		-- Check if user has any other settings (minilog, etc.) indicating they're not a fresh install
		for k, _ in pairs(deathlog_settings) do
			if k ~= "last_seen_version" and k ~= "last_changelog_version" then
				is_existing_user = true
				break
			end
		end
	end

	-- Show if:
	-- 1a. We have a previous version recorded and it's different (normal upgrade), OR
	-- 1b. No previous version but user has other settings (existing user upgrading to 0.4.4+)
	-- 2. User hasn't dismissed the changelog for this version
	local is_upgrade = (last_version and last_version ~= CURRENT_VERSION) or is_existing_user
	if is_upgrade and last_changelog_version ~= CURRENT_VERSION then
		-- Delay slightly to ensure UI is ready
		C_Timer.After(3, showChangelog)
	end
end

-- Slash command to manually open changelog
local function handleChangelogCommand()
	showChangelog()
end

-- Register slash command
SLASH_DEATHLOGCHANGELOG1 = "/dlchangelog"
SlashCmdList["DEATHLOGCHANGELOG"] = handleChangelogCommand

-- Export functions for use in deathlog.lua
Deathlog_ShowChangelog = showChangelog
Deathlog_CheckShowChangelog = checkShowChangelog
Deathlog_IsChangelogVisible = isChangelogVisible
