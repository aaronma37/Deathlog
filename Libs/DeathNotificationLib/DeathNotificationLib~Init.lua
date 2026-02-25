--[[
DeathNotificationLib~Init.lua
--]]

local VERSION = 5

if DeathNotificationLib and (DeathNotificationLib.VERSION or 0) >= VERSION then return end

---@class DeathNotificationLib
---@field Internal _dnl
DeathNotificationLib = { VERSION = VERSION , Internal = {} }

local _dnl = DeathNotificationLib.Internal ---@class _dnl

-- ── Auto-detect the Interface path to this library folder ────────────
-- debugstack() returns "path/to/file.lua:line: ..." when the chunk loads.
-- We strip the filename to get the directory, which lets media references
-- work regardless of which addon embeds DNL.
do
	local stack = debugstack(1, 1, 0) or ""
	local dir = stack:match("^(.+[/\\])DeathNotificationLib~Init%.lua") or ""
	-- Normalise to backslash (WoW media paths use backslashes)
	dir = dir:gsub("/", "\\")
	-- Strip everything before "Interface\" — PlaySoundFile / SetFont
	-- require paths rooted at "Interface\\" not the full disk path.
	dir = dir:gsub("^.*(Interface\\)", "%1")
	--- Base Interface path to this DeathNotificationLib folder (trailing backslash).
	--- Example: "Interface\\AddOns\\Deathlog\\Libs\\DeathNotificationLib\\"
	---@type string
	_dnl.media_path = dir
end

_dnl.L = {
    cn = {},
    de = {},
    en = {},
    es = {},
    fr = {},
    it = {},
    ko = {},
    pt = {},
    ru = {}
}

_dnl.D = {}

_dnl.DEBUG = false
_dnl.LOCAL_DEBUG_ONLY = false

---------------------------------------------------------------------------
-- Version comparison utility
---------------------------------------------------------------------------

--- Parse a semantic version string ("major.minor.patch") into a comparable
--- numeric tuple.  Returns nil if the string is not a valid version.
---@param ver string|nil  e.g. "0.4.0", "1.2.3"
---@return number|nil major
---@return number|nil minor
---@return number|nil patch
function _dnl.parseVersion(ver)
	if type(ver) ~= "string" then return nil, nil, nil end
	local major, minor, patch = ver:match("^(%d+)%.(%d+)%.(%d+)$")
	if not major then return nil, nil, nil end
	return tonumber(major), tonumber(minor), tonumber(patch)
end

--- Compare two semantic version strings.
--- Returns  1 if a > b,  -1 if a < b,  0 if equal,  nil if either is invalid.
---@param a string|nil
---@param b string|nil
---@return number|nil  1, -1, 0, or nil
function _dnl.compareVersions(a, b)
	local a1, a2, a3 = _dnl.parseVersion(a)
	local b1, b2, b3 = _dnl.parseVersion(b)
	if not a1 or not b1 then return nil end
	if a1 ~= b1 then return a1 > b1 and 1 or -1 end
	if a2 ~= b2 then return a2 > b2 and 1 or -1 end
	if a3 ~= b3 then return a3 > b3 and 1 or -1 end
	return 0
end

---------------------------------------------------------------------------
-- Shared utility: hide a channel from all chat frames
---------------------------------------------------------------------------

--- Remove a channel from all default chat frames (ChatFrame1–ChatFrame10)
--- so addon traffic never appears in the player's chat windows.
---@param channelName string  Channel name to hide
function _dnl.hideChannelFromChatFrames(channelName)
	if not channelName then return end
	if not _dnl.anyAddonAllows("auto_hide_chat_channels") then return end
	for i = 1, 10 do
		if _G["ChatFrame" .. i] then
			ChatFrame_RemoveChannel(_G["ChatFrame" .. i], channelName)
		end
	end
end

---------------------------------------------------------------------------
-- Blizzard chat-frame filter — prevent HistoryKeeper memory leak
---------------------------------------------------------------------------
-- Blizzard's HistoryKeeper.lua creates a permanent accessID entry for
-- every unique (chatType, chatTarget, chanSender) tuple seen on any
-- channel message.  On a high-traffic channel with hundreds of unique
-- senders this causes monotonically growing memory and CPU cost EVEN IF
-- the addon is doing nothing with the messages.
--
-- ChatFrame_AddMessageEventFilter runs BEFORE HistoryKeeper and the
-- per-frame AddMessage path.  By returning true for messages on our
-- channels we short-circuit the entire Blizzard chat pipeline,
-- eliminating:
--   • ChatHistory_GetAccessID allocations  (the primary leak)
--   • ChatFrame:AddMessage buffer growth
--   • GetColoredName / formatting overhead
--
-- The filter is installed at file-load time so it is active even before
-- the channels are joined (e.g. if the player was still in a channel
-- from a previous session).
--
-- Channel name prefixes (upper-cased for fast comparison):
--   "HCDEATHLOGSYNCCHANNEL"   – sync channel (and fallback suffixed variants)
--   "HCDEATHALERTSCHANNEL"    – death-alerts channel (and fallback variants)
---------------------------------------------------------------------------

local DNL_CHANNEL_PREFIXES = {
	"HCDEATHLOGSYNCCHANNEL",
	"HCDEATHALERTSCHANNEL",
}

--- ChatFrame_AddMessageEventFilter callback.
--- arg9 (11th parameter) is the channel name without number prefix.
---@return boolean true to suppress, false to pass through
local function dnlChannelChatFilter(self, event, arg1, arg2, arg3, arg4,
		arg5, arg6, arg7, arg8, arg9, ...)
	if arg9 then
		local upper = arg9:upper()
		for _, prefix in ipairs(DNL_CHANNEL_PREFIXES) do
			if upper:sub(1, #prefix) == prefix then
				return true  -- suppress: prevent HistoryKeeper + AddMessage processing
			end
		end
	end
	return false
end

local addMessageEventFilter = ChatFrameUtil and ChatFrameUtil.AddMessageEventFilter or ChatFrame_AddMessageEventFilter

if not _dnl.DEBUG then
	addMessageEventFilter("CHAT_MSG_CHANNEL", dnlChannelChatFilter)
	addMessageEventFilter("CHAT_MSG_CHANNEL_NOTICE", dnlChannelChatFilter)
	addMessageEventFilter("CHAT_MSG_CHANNEL_NOTICE_USER", dnlChannelChatFilter)
	addMessageEventFilter("CHAT_MSG_CHANNEL_JOIN", dnlChannelChatFilter)
	addMessageEventFilter("CHAT_MSG_CHANNEL_LEAVE", dnlChannelChatFilter)
end

---------------------------------------------------------------------------
-- Shared hardware-event input dispatcher
---------------------------------------------------------------------------
-- WoW Classic requires a hardware event (mouse click / key press) to send
-- chat messages.  Instead of each module hooking WorldFrame independently,
-- we maintain a single hook and dispatch to registered drain callbacks.
-- Defined here (Init) so every module can call registerInputDrain at load
-- time regardless of their own load order.

local _input_drain_callbacks = {}

function _dnl.registerInputDrain(callback)
	_input_drain_callbacks[#_input_drain_callbacks + 1] = callback
end

local function drainAll()
	for _, cb in ipairs(_input_drain_callbacks) do
		cb()
	end
end

WorldFrame:HookScript("OnMouseDown", function(self, button)
	drainAll()
end)

local input_frame = CreateFrame("Frame", nil, UIParent)
input_frame:SetScript("OnKeyDown", drainAll)
input_frame:SetPropagateKeyboardInput(true)

---------------------------------------------------------------------------
-- Multi-addon registry
---------------------------------------------------------------------------

--- A registered addon entry stored in _dnl.addons.
---@class DNL_RegisteredAddon
---@field name string           Unique addon name (e.g. "Deathlog")
---@field tag string            Exactly 3 characters, unique (e.g. "DLG")
---@field isUnitTracked fun(unit: UnitToken): boolean  Should DNL broadcast deaths for this unit?
---@field settings DNL_Settings|nil  Per-addon SavedVariables (optional; all keys have defaults)
---@field db DNL_Database|nil        READ-ONLY by DNL: { [checksum] = PlayerData } for sync/query
---@field db_map DNL_DatabaseMap|nil READ-ONLY by DNL: { [name] = checksum } for sync/query
---@field dev_data DNL_DevData|nil   Optional debug data
---@field addon_version string|nil   Semantic version string (e.g. "0.4.0") for upgrade notifications

--- Registry of all attached addons, keyed by addon name.
---@type table<string, DNL_RegisteredAddon>
_dnl.addons = {}

--- Lookup from 3-char tag to addon name for fast dispatch.
---@type table<string, string>
_dnl.tag_to_addon = {}

--- Runtime settings consumed by DeathNotificationLib.
--- These are read as optional values from each addon's settings table;
--- defaults are applied when keys are nil.
---@class DNL_Settings
---@field peer_reporting boolean|nil Accept peer-reported deaths when true (default true)
---@field addonless_logging boolean|nil Accept Blizzard-only deaths with missing class/race when true (default false)
---@field auto_blizzard_deaths boolean|nil Auto-join/configure HardcoreDeaths channel when not false
---@field auto_hide_chat_channels boolean|nil Automatically hide addon chat channels from all chat frames when not false
---@field legacy_messages boolean|nil Accept legacy protocol messages (v0-v2) when not false
---@field share_playtime boolean|nil Include /played in hook copies (default true; set false to strip played from this addon's hooks)
---@field sync_enabled boolean|nil Enable background database sync when not false
---@field sync_window_days number|nil Sync lookback window in days (-1 = all, default 7)
---@field sync_interval number|nil Watermark broadcast interval in seconds (default 300)
---@field sync_max_entries number|nil Max entries streamed per sync session (default 500)
---@field sync_cooldown number|nil Cooldown between sync sessions in seconds (default 300)
---@field death_alert_priority number|nil Higher number wins when multiple addons provide settings (default 0)
---@field DeathAlert DNL_DeathAlertSettings|nil Sub-table consumed by ~DeathAlert.lua (auto-populated with defaults)

--- Settings sub-table for the built-in Death Alert widget.
--- All fields are optional; defaults are applied by ~DeathAlert.lua when nil.
---@class DNL_DeathAlertSettings
---@field enable boolean|nil Show death alert popup (default true)
---@field enable_sound boolean|nil Play a sound on death alert (default true)
---@field pos_x number|nil X offset from CENTER (default 0)
---@field pos_y number|nil Y offset from CENTER (default 250)
---@field size_x number|nil Frame width (default 600)
---@field size_y number|nil Frame height (default 200)
---@field style string|nil Visual style key: "boss_banner_basic_small"|"boss_banner_basic_medium"|"boss_banner_enemy_icon_small"|"boss_banner_enemy_icon_medium"|"boss_banner_enemy_icon_animated"|"text_only" (default "boss_banner_enemy_icon_medium")
---@field display_time number|nil Seconds to show the alert (default 6)
---@field alert_subset string|nil "faction_wide"|"guild_only" etc. (default "faction_wide")
---@field font string|nil Font key in shared media or built-in table (default "Nimrod MT")
---@field font_size number|nil Font point size (default 16)
---@field font_color_r number|nil Font red channel 0-1 (default 1)
---@field font_color_g number|nil Font green channel 0-1 (default 1)
---@field font_color_b number|nil Font blue channel 0-1 (default 1)
---@field font_color_a number|nil Font alpha channel 0-1 (default 1)
---@field message string|nil Default death message template
---@field fall_message string|nil Fall death message template
---@field drown_message string|nil Drown death message template
---@field slime_message string|nil Slime death message template
---@field lava_message string|nil Lava death message template
---@field fire_message string|nil Fire death message template
---@field fatigue_message string|nil Fatigue death message template
---@field min_lvl number|nil Minimum victim level to show (default 1)
---@field min_lvl_player boolean|nil Use player level as min_lvl (default false)
---@field max_lvl number|nil Maximum victim level to show (default MAX_PLAYER_LEVEL)
---@field guild_only boolean|nil Only show guild member deaths (default false)
---@field accent_color_r number|nil Accent red channel 0-1 (default 1)
---@field accent_color_g number|nil Accent green channel 0-1 (default 1)
---@field accent_color_b number|nil Accent blue channel 0-1 (default 1)
---@field accent_color_a number|nil Accent alpha channel 0-1 (default 1)
---@field current_zone_filter boolean|nil Only show deaths in current zone (default false)
---@field alert_sound string|nil Sound key: "default_hardcore"|"random"|any LSM key (default "default_hardcore")

--- Persistent death entry stored by checksum.
---@alias DNL_DBEntry PlayerData

--- Database keyed by fletcher16 checksum.
---@alias DNL_Database table<string, DNL_DBEntry>

--- Name-to-checksum lookup table for fast query by player name.
---@alias DNL_DatabaseMap table<string, string>

--- Optional debug / analysis outputs populated by testing utilities and addon runtime.
---@class DNL_DevData
---@field map_bounds table|nil
---@field world_map_data table|nil

---------------------------------------------------------------------------
-- Settings helpers (per-addon)
---------------------------------------------------------------------------

--- For settings with default-true (opt-out) semantics:
--- Returns true if ANY registered addon hasn't explicitly set key to false.
--- If no addon has settings, returns true (the default).
--- Examples: peer_reporting, auto_blizzard_deaths, legacy_messages.
---@param key string
---@return boolean
function _dnl.anyAddonAllows(key)
	local found_any = false
	for _, addon in pairs(_dnl.addons) do
		if addon.settings then
			found_any = true
			if addon.settings[key] ~= false then
				return true
			end
		end
	end
	return not found_any -- no addon has settings → default true
end

--- For settings with default-false (opt-in) semantics:
--- Returns true if ANY registered addon has explicitly set key to a truthy value.
--- Examples: addonless_logging.
---@param key string
---@return boolean
function _dnl.anyAddonEnables(key)
	for _, addon in pairs(_dnl.addons) do
		if addon.settings and addon.settings[key] then
			return true
		end
	end
	return false
end

--- Return the settings table and addon name from the addon with the highest death_alert_priority.
--- Used ONLY by the DeathAlert widget to read/write its sub-table.
--- Returns nil, nil if no addon has settings.
---@return DNL_Settings|nil settings
---@return string|nil addon_name
function _dnl.getDeathAlertOwnerSettings()
	local best_settings = nil
	local best_name = nil
	local best_prio = -math.huge
	for _, addon in pairs(_dnl.addons) do
		if addon.settings then
			local p = addon.settings.death_alert_priority or 0
			if p > best_prio then
				best_prio = p
				best_settings = addon.settings
				best_name = addon.name
			end
		end
	end
	return best_settings, best_name
end
