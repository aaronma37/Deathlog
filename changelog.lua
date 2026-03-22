--[[
Copyright 2026 Yazpad & Deathwing
The Deathlog AddOn is distributed under the terms of the GNU General Public License.
This file is part of Deathlog.
--]]
---@diagnostic disable: invisible

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

|cFF00FF00[0.5.5] - 2026-03-22|r

|cFFFFFFFFBug Fixes|r
- Fixed HC state being inherited when a new character shares a name with a previous one — state now resets correctly on GUID mismatch
- Fixed crash in creature ranking when saved data contains creatures with an average level above the expansion cap
- Filter out synced death entries with level exceeding the max player level

|cFF00FF00[0.5.4] - 2026-03-16|r

|cFFFFFFFFNew Features|r
- Death Filter in the search log — filter by All Deaths, Guild Only, or Guild Confederation (requires GreenWall); saved between sessions
- GreenWall confederation option now shows as soon as GreenWall is installed

|cFFFFFFFFBug Fixes|r
- Fixed search log clipping on the right side
- Fixed filters not applying when first opening the search log
- Fixed guild filters matching nothing for the first 10 seconds after login
- Deferred library initialization until at least one addon has registered, fixing early channel joins

|cFF00FF00[0.5.3] - 2026-03-15|r

|cFFFFFFFFNew Features|r
- Refresh button in the search log — reload the death list while keeping active filters
- Auto-refresh the death list every 10 seconds (disabled by default, enable in options); preserves active filters

|cFF00FF00[0.5.2] - 2026-03-11|r

|cFFFFFFFFImprovements|r
- Heatmap data is now optional — shipped separately via the DeathNotificationLibData addon (auto-downloaded via CurseForge)

|cFFFFFFFFBug Fixes|r
- Fixed minilog Source column not showing predicted sources when source_id is nil
- Fixed death source search filter only matching NPC names — now also matches environment damage, PvP, and predictions
- Added tonumber() guards on all source_id usage to handle string-typed values without errors

|cFF00FF00[0.5.1] - 2026-03-08|r

|cFFFFFFFFNew Features|r
- All ArtifactUI class backgrounds now selectable as minilog themes (DK Frost, Demon Hunter, Druid, Hunter, Mage Arcane, Monk, Paladin, Priest, Priest Shadow, Rogue, Shadow, Shaman, Warlock, Warrior)

|cFFFFFFFFBug Fixes|r
- Fixed Death Alert settings panel not appearing in Interface Options
- Fixed minilog artifact themes rendering the full sprite sheet instead of the background panel region
- Fixed Deathlog menu background texture using imprecise atlas UV coordinates

|cFF00FF00[0.5.0] - 2026-03-06|r

|cFFFFFFFFNew Features|r
- Resizable & scalable menu — drag the bottom-right corner to resize; position and scale persist between sessions
- Precomputed purge data, split by expansion
- Guild filter for the search log
- DeathlogData is now a separate addon (auto-installed as a dependency)
- Instance min-level enforcement — deaths too low-level for a dungeon/raid are filtered out
- We now have an official Discord! Click the invite link in the changelog status bar to copy it: `discord.com/invite/NphuAv75vy`

|cFFFFFFFFBug Fixes|r
- Fixed HardcoreDeaths channel pushing General/Trade/LocalDefense to wrong positions
- Fixed death alert crashes when settings weren't customized
- Fixed empty graphs with sparse data (division by zero)
- Fixed "Mouseover for metric details" tooltip positioning
- Fixed watchlist click-hitbox alignment for Name/Note/Icon columns
- Fixed watchlist remove behavior so only clicking the visible `X` removes an entry
- Fixed watchlist icon dropdown to show the currently selected icon
- Fixed watchlist `Last Checked` staying at "Never" due to refresh flow timing
- Cleaned up redundant guards in UI code
- Faster channel join on login
- Updated NPC data and statistics

|cFFFFFFFFImprovements|r
- Watchlist refresh cooldown text now updates live each second

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

	changelog_frame = AceGUI:Create("Frame") ---@type AceGUIFrame
	changelog_frame:SetTitle("Deathlog - What's New")
	changelog_frame:SetStatusText("Version " .. CURRENT_VERSION .. "  |  discord.com/invite/NphuAv75vy (click to copy)")
	changelog_frame:SetLayout("Fill")
	changelog_frame:SetWidth(500)
	changelog_frame:SetHeight(450)
	changelog_frame:SetCallback("OnClose", function(widget)
		AceGUI:Release(widget)
		changelog_frame = nil
	end)

	-- Make the status bar clickable to copy Discord invite URL
	local statusbar = changelog_frame.statustext:GetParent()
	if statusbar then
		statusbar:EnableMouse(true)
		statusbar:SetScript("OnMouseUp", function()
			Deathlog_ShowCopyPopup("discord.com/invite/NphuAv75vy")
		end)
	end

	local scrollFrame = AceGUI:Create("ScrollFrame") ---@type AceGUIScrollFrame
	scrollFrame:SetLayout("Flow")
	changelog_frame:AddChild(scrollFrame)

	local label = AceGUI:Create("Label") ---@type AceGUILabel
	label:SetText(CHANGELOG_CONTENT)
	label:SetFullWidth(true)
	label:SetFont(GameFontNormal:GetFont(), 12, "")
	scrollFrame:AddChild(label)

	-- Add "Don't show again for this version" checkbox at the bottom
	local checkbox = AceGUI:Create("CheckBox") ---@type AceGUICheckBox
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
