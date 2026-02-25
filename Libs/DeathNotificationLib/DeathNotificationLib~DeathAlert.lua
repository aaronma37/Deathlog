--[[
DeathNotificationLib~DeathAlert.lua

Built-in death alert UI.  Displays a configurable popup when a death
is committed via createEntry() for real-time sources (self_death,
peer_broadcast, blizzard).

Settings are read from the highest-priority addon's settings["DeathAlert"].

Soft dependencies (graceful fallback when absent):
  - LibSharedMedia-3.0  → extra sounds/fonts; falls back to built-in set
  - AceConfig-3.0 + AceConfigDialog-3.0 → auto-registers options panel

Key entry points:
  _dnl.playDeathAlert(entry)     – show alert for a PlayerData table
  _dnl.testDeathAlert()          – fake entry → playDeathAlert
  _dnl.applyDeathAlertSettings() – (re)build the frame from current settings
--]]

local _dnl = DeathNotificationLib.Internal ---@class _dnl
if not _dnl then return end

local id_to_npc       = _dnl.D.ID_TO_NPC       or {}
local id_to_instance  = _dnl.D.ID_TO_INSTANCE   or {}
local id_to_display_id = _dnl.D.ID_TO_DISPLAY_ID or {}

local widget_name = "DeathAlert"

-- ── Soft dependencies ────────────────────────────────────────────────
local LSM30 = LibStub and LibStub("LibSharedMedia-3.0", true)
local AceConfig = LibStub and LibStub("AceConfig-3.0", true)
local AceConfigDialog = LibStub and LibStub("AceConfigDialog-3.0", true)

-- ── sounds / fonts ───────────────────────────────────────────────────
-- Paths are relative to _dnl.media_path (auto-detected in ~Init.lua).
local mp = _dnl.media_path or ""

local sounds = LSM30 and LSM30:HashTable("sound") or {}
sounds["default_hardcore"] = 8959
sounds["golfclap"]       = mp .. "Sounds\\golfclap.ogg"
sounds["hunger_games"]   = mp .. "Sounds\\hunger_games.ogg"
sounds["HeroFallen"]     = mp .. "Sounds\\HeroFallen.ogg"
sounds["Dread_Hunger"]   = mp .. "Sounds\\Dread_Hunger.ogg"
sounds["Arugal"]         = mp .. "Sounds\\Arugal.ogg"
sounds["random"]         = "random"

local fonts = LSM30 and LSM30:HashTable("font") or {}
fonts["blei00d"]           = "Fonts\\blei00d.TTF"  -- WoW built-in font
fonts["BreatheFire"]       = mp .. "Fonts\\BreatheFire.ttf"
fonts["BlackChancery"]     = mp .. "Fonts\\BLKCHCRY.TTF"
fonts["ArgosGeorge"]       = mp .. "Fonts\\ArgosGeorge.ttf"
fonts["GothicaBook"]       = mp .. "Fonts\\Gothica-Book.ttf"
fonts["Immortal"]          = mp .. "Fonts\\IMMORTAL.ttf"
fonts["BlackwoodCastle"]   = mp .. "Fonts\\BlackwoodCastle.ttf"
fonts["Alegreya"]          = mp .. "Fonts\\alegreya.regular.ttf"
fonts["Cathedral"]         = mp .. "Fonts\\Cathedral.ttf"
fonts["FletcherGothic"]    = mp .. "Fonts\\FletcherGothic-pwy.ttf"
fonts["GothamNarrowUltra"] = mp .. "Fonts\\GothamNarrowUltra.ttf"

local blur_mask_path = mp .. "Media\\blur_mask.blp"

local death_alert_styles = {
	["boss_banner_basic_small"]          = "boss_banner_basic_small",
	["boss_banner_basic_medium"]         = "boss_banner_basic_medium",
	["boss_banner_enemy_icon_small"]     = "boss_banner_enemy_icon_small",
	["boss_banner_enemy_icon_medium"]    = "boss_banner_enemy_icon_medium",
	["boss_banner_enemy_icon_animated"]  = "boss_banner_enemy_icon_animated",
	["lf_animated"]                      = "lf_animated",
	["text_only"]                        = "text_only",
}

-- ── helper: settings accessor ────────────────────────────────────────
local function S()
	local settings = _dnl.getDeathAlertOwnerSettings()
	return settings and settings[widget_name]
end

-- ── formatPlaytime (exposed as public API) ───────────────────────────
---@param seconds number|nil
---@return string|nil
function _dnl.formatPlaytime(seconds)
	if seconds == nil or seconds <= 0 then
		return nil
	end
	local y = math.floor(seconds / 31536000)
	local d = math.floor((seconds % 31536000) / 86400)
	local h = math.floor((seconds % 86400) / 3600)
	local m = math.floor((seconds % 3600) / 60)
	if y > 0 then
		return string.format("%dy %dd %dh %dm", y, d, h, m)
	elseif d > 0 then
		return string.format("%dd %dh %dm", d, h, m)
	elseif h > 0 then
		return string.format("%dh %dm", h, m)
	else
		return string.format("%dm", m)
	end
end

-- ── locale helpers ───────────────────────────────────────────────────
--- Reads a death-alert locale string from _dnl.D.STRINGS
--- (populated by ~Localization.lua from the client locale).
local function getLocaleString(key)
	return _dnl.D.STRINGS[key] or _dnl.L.en.STRINGS[key] or ""
end

-- ── defaults ─────────────────────────────────────────────────────────
local MAX_PLAYER_LEVEL = _dnl.MAX_PLAYER_LEVEL or 60

local defaults = {
	["enable"]              = true,
	["enable_sound"]        = true,
	["pos_x"]               = 0,
	["pos_y"]               = 250,
	["size_x"]              = 600,
	["size_y"]              = 200,
	["style"]               = "boss_banner_enemy_icon_medium",
	["display_time"]        = 6,
	["alert_subset"]        = "faction_wide",
	["font"]                = "Nimrod MT",
	["font_size"]           = 16,
	["font_color_r"]        = 1,
	["font_color_g"]        = 1,
	["font_color_b"]        = 1,
	["font_color_a"]        = 1,
	["message"]             = getLocaleString("death_alert_default_message"),
	["fall_message"]        = getLocaleString("death_alert_default_fall_message"),
	["drown_message"]       = getLocaleString("death_alert_default_drown_message"),
	["slime_message"]       = getLocaleString("death_alert_default_slime_message"),
	["lava_message"]        = getLocaleString("death_alert_default_lava_message"),
	["fire_message"]        = getLocaleString("death_alert_default_fire_message"),
	["fatigue_message"]     = getLocaleString("death_alert_default_fatigue_message"),
	["min_lvl"]             = 1,
	["min_lvl_player"]      = false,
	["max_lvl"]             = MAX_PLAYER_LEVEL,
	["guild_only"]          = false,
	["accent_color_r"]      = 1,
	["accent_color_g"]      = 1,
	["accent_color_b"]      = 1,
	["accent_color_a"]      = 1,
	["current_zone_filter"] = false,
	["alert_sound"]         = "default_hardcore",
}

local function applyDefaults(force)
	local settings = _dnl.getDeathAlertOwnerSettings()
	if not settings then return end
	settings[widget_name] = settings[widget_name] or {}
	local s = settings[widget_name]
	for k, v in pairs(defaults) do
		if s[k] == nil or force then
			s[k] = v
		end
	end
end

-- ── frame creation ───────────────────────────────────────────────────
local death_alert_frame = nil

local function createDeathAlertFrame()
	if death_alert_frame then
		if death_alert_frame.timer then death_alert_frame.timer:Cancel() end
		death_alert_frame:Hide()
		death_alert_frame:SetParent(nil)
		death_alert_frame = nil
	end

	death_alert_frame = CreateFrame("frame")
	death_alert_frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	death_alert_frame:SetWidth(25)
	death_alert_frame:SetHeight(25)
	death_alert_frame:SetMovable(false)
	death_alert_frame:EnableMouse(false)
	death_alert_frame:SetFrameStrata("FULLSCREEN_DIALOG")
	death_alert_frame:Show()

	death_alert_frame.text = death_alert_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	death_alert_frame.text:SetText("")
	death_alert_frame.text:SetFont(getLocaleString("death_alert_font"), 22, "")
	death_alert_frame.text:SetTextColor(1, 1, 1, 1)
	death_alert_frame.text:SetJustifyH("CENTER")
	death_alert_frame.text:SetParent(death_alert_frame)
	death_alert_frame.text:Show()
end

-- ── alert dedup cache ────────────────────────────────────────────────
local alert_cache = {}

C_Timer.NewTicker(30, function()
	local now = GetServerTime()
	for name, info in pairs(alert_cache) do
		if now - info.ts > _dnl.getDedupWindow(info.level) then
			alert_cache[name] = nil
		end
	end
end)

-- ── guild member cache (for guild_only filter) ───────────────────────
local _guild_members = {}
local function _refreshGuildList()
	local numTotal = GetNumGuildMembers()
	for i = 1, numTotal do
		local name = GetGuildRosterInfo(i)
		if name then
			local _short_name = string.split("-", name)
			if _short_name then
				_guild_members[_short_name] = 1
			end
		end
	end
end
C_Timer.NewTicker(10, _refreshGuildList)

-- ── random sound ─────────────────────────────────────────────────────
local function PlayRandomSound()
	local paths = {}
	for k, v in pairs(sounds) do
		if type(v) == "string" and k ~= "random" and v ~= "random" then
			paths[#paths + 1] = v
		end
	end
	if #paths > 0 then
		PlaySoundFile(paths[math.random(1, #paths)])
	end
end

-- ── initializeBossBanner / initializeLFBanner ────────────────────────
-- (These are self-contained; they only reference `death_alert_frame` and `S()`)

local function initializeLFBanner(icon_type, icon_size)
	local s = S()
	if death_alert_frame.textures == nil then death_alert_frame.textures = {} end

	if death_alert_frame.textures.top == nil then
		death_alert_frame.textures.top = death_alert_frame:CreateTexture(nil, "OVERLAY")
	end
	death_alert_frame.textures.top:SetPoint("CENTER", death_alert_frame, "CENTER", 0, 0)
	death_alert_frame.textures.top:SetWidth(400)
	death_alert_frame.textures.top:SetHeight(100)
	death_alert_frame.textures.top:SetDrawLayer("OVERLAY", 4)
	death_alert_frame.textures.top:SetVertexColor(1, 1, 1, 1)
	death_alert_frame.textures.top:SetTexture("Interface\\LootFrame\\LootToastAtlas")
	death_alert_frame.textures.top:SetTexCoord(0.55, 0.825, 0.39, 0.7)
	death_alert_frame.textures.top:Show()

	if death_alert_frame.textures.top_emblem == nil then
		death_alert_frame.textures.top_emblem = death_alert_frame:CreateTexture(nil, "OVERLAY")
	end
	death_alert_frame.textures.top_emblem:SetPoint("LEFT", death_alert_frame.textures.top, "LEFT", death_alert_frame.textures.top:GetWidth() * 0.1, 0)
	death_alert_frame.textures.top_emblem:SetWidth(death_alert_frame.textures.top:GetHeight() * 0.5 * 1.5)
	death_alert_frame.textures.top_emblem:SetHeight(death_alert_frame.textures.top:GetHeight() * 0.2 * 1.5)
	death_alert_frame.textures.top_emblem:SetDrawLayer("OVERLAY", 5)
	death_alert_frame.textures.top_emblem:SetVertexColor(1, 1, 1, 1)
	death_alert_frame.textures.top_emblem:SetTexture("Interface\\LevelUp\\BossBanner")
	death_alert_frame.textures.top_emblem:SetTexCoord(0.24, 0.59, 0.58, 0.72)
	death_alert_frame.textures.top_emblem:Hide()

	if death_alert_frame.textures.top_emblem_overlay == nil then
		death_alert_frame.textures.top_emblem_overlay = death_alert_frame:CreateTexture(nil, "OVERLAY")
	end
	death_alert_frame.textures.top_emblem_overlay:SetPoint("LEFT", death_alert_frame.textures.top, "LEFT", death_alert_frame:GetWidth() * 0.066, 2)
	death_alert_frame.textures.top_emblem_overlay:SetWidth(death_alert_frame.textures.top:GetHeight() * 0.225 * 3)
	death_alert_frame.textures.top_emblem_overlay:SetHeight(death_alert_frame.textures.top:GetHeight() * 0.225 * 3)
	death_alert_frame.textures.top_emblem_overlay:SetTexture("Interface\\PVPFrame\\SilverIconBorder")
	-- Crop out the ornamental wing so only the frame ring remains.
	death_alert_frame.textures.top_emblem_overlay:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	death_alert_frame.textures.top_emblem_overlay:SetVertexColor(0.5, 0.2, 0.2, 1)
	death_alert_frame.textures.top_emblem_overlay:SetDrawLayer("OVERLAY", 3)
	death_alert_frame.textures.top_emblem_overlay:Show()

	if death_alert_frame.textures.top_emblem_background == nil then
		death_alert_frame.textures.top_emblem_background = death_alert_frame:CreateTexture(nil, "OVERLAY")
	end
	death_alert_frame.textures.top_emblem_background:SetPoint("CENTER", death_alert_frame.textures.top_emblem_overlay, "CENTER", 0, 0)
	death_alert_frame.textures.top_emblem_background:SetHeight(death_alert_frame.textures.top_emblem_overlay:GetHeight() * 0.7)
	death_alert_frame.textures.top_emblem_background:SetWidth(death_alert_frame.textures.top_emblem_overlay:GetWidth() * 0.7)
	death_alert_frame.textures.top_emblem_background:SetDrawLayer("OVERLAY", 6)
	death_alert_frame.textures.top_emblem_background:SetColorTexture(0, 0, 0, 1)
	death_alert_frame.textures.top_emblem_background:Show()

	if death_alert_frame.textures.enemy_portrait == nil then
		death_alert_frame.textures.enemy_portrait = death_alert_frame:CreateTexture(nil, "OVERLAY")
	end
	death_alert_frame.textures.enemy_portrait:SetPoint("TOP", death_alert_frame.textures.top, "TOP", 0, -death_alert_frame.textures.top:GetHeight() * 0.237)
	death_alert_frame.textures.enemy_portrait:SetWidth(death_alert_frame.textures.top:GetHeight() * 0.225 * 0.8 * 1.15)
	death_alert_frame.textures.enemy_portrait:SetHeight(death_alert_frame.textures.top:GetHeight() * 0.225 * 0.8 * 1.15)
	death_alert_frame.textures.enemy_portrait:SetDrawLayer("OVERLAY", 7)
	death_alert_frame.textures.enemy_portrait:Show()

	if death_alert_frame.textures.enemy_portrait_mask == nil then
		death_alert_frame.textures.enemy_portrait_mask = death_alert_frame:CreateMaskTexture()
	end
	death_alert_frame.textures.enemy_portrait_mask:SetPoint("CENTER", death_alert_frame.textures.enemy_portrait, "CENTER", 0, 0)
	death_alert_frame.textures.enemy_portrait_mask:SetHeight(death_alert_frame.textures.enemy_portrait:GetWidth() * 1)
	death_alert_frame.textures.enemy_portrait_mask:SetWidth(death_alert_frame.textures.enemy_portrait:GetWidth() * 1)
	death_alert_frame.textures.enemy_portrait_mask:SetTexture(blur_mask_path, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
	death_alert_frame.textures.enemy_portrait:AddMaskTexture(death_alert_frame.textures.enemy_portrait_mask)

	death_alert_frame.text:SetPoint("CENTER", death_alert_frame.textures.top, "CENTER", death_alert_frame:GetWidth() * 0.07, death_alert_frame.textures.top:GetHeight() * 0.01)
	death_alert_frame.text:SetWidth(death_alert_frame:GetWidth() * 0.40)
	death_alert_frame.lf_font_scale = 0.7
	death_alert_frame.remove_new_lines = true
	death_alert_frame:Hide()
end

local function initializeBossBanner(icon_type, icon_size)
	local s = S()
	if not s then return end
	if death_alert_frame.textures == nil then death_alert_frame.textures = {} end

	if death_alert_frame.textures.top == nil then
		death_alert_frame.textures.top = death_alert_frame:CreateTexture(nil, "OVERLAY")
	end
	death_alert_frame.textures.top:SetAllPoints()
	death_alert_frame.textures.top:SetDrawLayer("OVERLAY", 4)
	death_alert_frame.textures.top:SetVertexColor(s["accent_color_r"], s["accent_color_g"], s["accent_color_b"], s["accent_color_a"])
	death_alert_frame.textures.top:SetTexture("Interface\\LevelUp\\BossBanner")
	death_alert_frame.textures.top:SetTexCoord(0, 0.84, 0, 0.43)
	death_alert_frame.textures.top:Show()

	if death_alert_frame.textures.middle == nil then
		death_alert_frame.textures.middle = death_alert_frame:CreateTexture(nil, "OVERLAY")
	end
	death_alert_frame.textures.middle:SetPoint("CENTER", death_alert_frame.textures.top, "CENTER", 0, -death_alert_frame.textures.top:GetHeight() * 0.03)
	death_alert_frame.textures.middle:SetWidth(death_alert_frame.textures.top:GetWidth())
	death_alert_frame.textures.middle:SetHeight(death_alert_frame.textures.top:GetHeight() * 0.32)
	death_alert_frame.textures.middle:SetDrawLayer("OVERLAY", 4)
	death_alert_frame.textures.middle:SetVertexColor(s["accent_color_r"], s["accent_color_g"], s["accent_color_b"], s["accent_color_a"])
	death_alert_frame.textures.middle:SetTexture("Interface\\LevelUp\\BossBanner")
	death_alert_frame.textures.middle:SetTexCoord(0, 0.8, 0.43, 0.58)
	death_alert_frame.textures.middle:Show()

	if death_alert_frame.textures.top_emblem == nil then
		death_alert_frame.textures.top_emblem = death_alert_frame:CreateTexture(nil, "OVERLAY")
	end
	if icon_size == "small" then
		death_alert_frame.textures.top_emblem:SetPoint("TOP", death_alert_frame.textures.top, "TOP", 0, -death_alert_frame.textures.top:GetHeight() * 0.209)
		death_alert_frame.textures.top_emblem:SetWidth(death_alert_frame.textures.top:GetHeight() * 0.5 * 1.25)
		death_alert_frame.textures.top_emblem:SetHeight(death_alert_frame.textures.top:GetHeight() * 0.2 * 1.25)
	elseif icon_size == "medium" or icon_size == "animated" then
		death_alert_frame.textures.top_emblem:SetPoint("BOTTOM", death_alert_frame.textures.top, "BOTTOM", 0, death_alert_frame.textures.top:GetHeight() * 0.53)
		death_alert_frame.textures.top_emblem:SetWidth(death_alert_frame.textures.top:GetHeight() * 0.5 * 1.5)
		death_alert_frame.textures.top_emblem:SetHeight(death_alert_frame.textures.top:GetHeight() * 0.2 * 1.5)
	end
	death_alert_frame.textures.top_emblem:SetDrawLayer("OVERLAY", 5)
	death_alert_frame.textures.top_emblem:SetVertexColor(s["accent_color_r"], s["accent_color_g"], s["accent_color_b"], s["accent_color_a"])
	death_alert_frame.textures.top_emblem:SetTexture("Interface\\LevelUp\\BossBanner")
	death_alert_frame.textures.top_emblem:SetTexCoord(0.24, 0.59, 0.58, 0.72)
	death_alert_frame.textures.top_emblem:Show()

	if icon_type == "enemy_icon" then
		if death_alert_frame.textures.top_emblem_overlay == nil then
			death_alert_frame.textures.top_emblem_overlay = death_alert_frame:CreateTexture(nil, "OVERLAY")
		end
		if icon_size == "small" then
			death_alert_frame.textures.top_emblem_overlay:SetPoint("TOP", death_alert_frame.textures.top, "TOP", 0, -death_alert_frame.textures.top:GetHeight() * 0.21)
			death_alert_frame.textures.top_emblem_overlay:SetWidth(death_alert_frame.textures.top:GetHeight() * 0.225)
			death_alert_frame.textures.top_emblem_overlay:SetHeight(death_alert_frame.textures.top:GetHeight() * 0.225)
			death_alert_frame.textures.top_emblem_overlay:SetTexture("Interface\\LevelUp\\BossBanner")
			death_alert_frame.textures.top_emblem_overlay:SetTexCoord(0.86, 0.962, 0, 0.12)
			death_alert_frame.textures.top_emblem_overlay:SetDrawLayer("OVERLAY", 6)
			death_alert_frame.textures.top_emblem_overlay:SetVertexColor(s["accent_color_r"], s["accent_color_g"], s["accent_color_b"], s["accent_color_a"])
		elseif icon_size == "animated" then
			death_alert_frame.textures.top_emblem_overlay:SetPoint("TOP", death_alert_frame.textures.top, "TOP", 2, -death_alert_frame.textures.top:GetHeight() * 0.14)
			death_alert_frame.textures.top_emblem_overlay:SetWidth(death_alert_frame.textures.top:GetHeight() * 0.225 * 1.7)
			death_alert_frame.textures.top_emblem_overlay:SetHeight(death_alert_frame.textures.top:GetHeight() * 0.225 * 1.7)
			death_alert_frame.textures.top_emblem_overlay:SetTexture("Interface\\PVPFrame\\SilverIconBorder")
			death_alert_frame.textures.top_emblem_overlay:SetVertexColor(s["accent_color_r"] * 0.5, s["accent_color_g"] * 0.2, s["accent_color_b"] * 0.2, s["accent_color_a"] * 1)
			death_alert_frame.textures.top_emblem_overlay:SetDrawLayer("OVERLAY", 7)

			if death_alert_frame.textures.top_emblem_background == nil then
				death_alert_frame.textures.top_emblem_background = death_alert_frame:CreateTexture(nil, "OVERLAY")
			end
			death_alert_frame.textures.top_emblem_background:SetPoint("CENTER", death_alert_frame.textures.top_emblem_overlay, "CENTER", 0, 0)
			death_alert_frame.textures.top_emblem_background:SetHeight(death_alert_frame.textures.top_emblem_overlay:GetHeight() * 0.7)
			death_alert_frame.textures.top_emblem_background:SetWidth(death_alert_frame.textures.top_emblem_overlay:GetWidth() * 0.7)
			death_alert_frame.textures.top_emblem_background:SetDrawLayer("OVERLAY", 6)
			death_alert_frame.textures.top_emblem_background:SetColorTexture(0, 0, 0, 1)
		end
		death_alert_frame.textures.top_emblem_overlay:Show()

		if death_alert_frame.textures.enemy_portrait == nil then
			death_alert_frame.textures.enemy_portrait = death_alert_frame:CreateTexture(nil, "OVERLAY")
		end
		if icon_size == "small" then
			death_alert_frame.textures.enemy_portrait:SetPoint("TOP", death_alert_frame.textures.top, "TOP", 2, -death_alert_frame.textures.top:GetHeight() * 0.27)
			death_alert_frame.textures.enemy_portrait:SetWidth(death_alert_frame.textures.top:GetHeight() * 0.225 * 0.8)
			death_alert_frame.textures.enemy_portrait:SetHeight(death_alert_frame.textures.top:GetHeight() * 0.225 * 0.8)
		elseif icon_size == "medium" or icon_size == "animated" then
			death_alert_frame.textures.enemy_portrait:SetPoint("TOP", death_alert_frame.textures.top, "TOP", 2, -death_alert_frame.textures.top:GetHeight() * 0.237)
			death_alert_frame.textures.enemy_portrait:SetWidth(death_alert_frame.textures.top:GetHeight() * 0.225 * 0.8 * 1.15)
			death_alert_frame.textures.enemy_portrait:SetHeight(death_alert_frame.textures.top:GetHeight() * 0.225 * 0.8 * 1.15)
		end
		death_alert_frame.textures.enemy_portrait:SetDrawLayer("OVERLAY", 7)
		death_alert_frame.textures.enemy_portrait:Show()

		if death_alert_frame.textures.enemy_portrait_mask == nil then
			death_alert_frame.textures.enemy_portrait_mask = death_alert_frame:CreateMaskTexture()
		end
		death_alert_frame.textures.enemy_portrait_mask:SetPoint("CENTER", death_alert_frame.textures.enemy_portrait, "CENTER", 0, 0)
		death_alert_frame.textures.enemy_portrait_mask:SetHeight(death_alert_frame.textures.enemy_portrait:GetWidth() * 1)
		death_alert_frame.textures.enemy_portrait_mask:SetWidth(death_alert_frame.textures.enemy_portrait:GetWidth() * 1)
		death_alert_frame.textures.enemy_portrait_mask:SetTexture(blur_mask_path, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		death_alert_frame.textures.enemy_portrait:AddMaskTexture(death_alert_frame.textures.enemy_portrait_mask)
	end

	if death_alert_frame.textures.bottom_emblem == nil then
		death_alert_frame.textures.bottom_emblem = death_alert_frame:CreateTexture(nil, "OVERLAY")
	end
	death_alert_frame.textures.bottom_emblem:SetPoint("TOP", death_alert_frame.textures.top, "TOP", 0, -death_alert_frame.textures.top:GetHeight() * 0.639)
	death_alert_frame.textures.bottom_emblem:SetWidth(death_alert_frame.textures.top:GetHeight() * 0.35)
	death_alert_frame.textures.bottom_emblem:SetHeight(death_alert_frame.textures.top:GetHeight() * 0.1)
	death_alert_frame.textures.bottom_emblem:SetDrawLayer("OVERLAY", 5)
	death_alert_frame.textures.bottom_emblem:SetVertexColor(s["accent_color_r"] * 0.5, s["accent_color_g"] * 0.2, s["accent_color_b"] * 0.2, s["accent_color_a"] * 1)
	death_alert_frame.textures.bottom_emblem:SetTexture("Interface\\LevelUp\\BossBanner")
	death_alert_frame.textures.bottom_emblem:SetTexCoord(0.85, 1, 0.32, 0.37)
	death_alert_frame.textures.bottom_emblem:Show()

	death_alert_frame.text:SetPoint("CENTER", death_alert_frame.textures.top, "CENTER", 0, -death_alert_frame.textures.top:GetHeight() * 0.04)
	death_alert_frame:Hide()
end

-- Environment damage icon textures (same as DeathAlert widget)
local environment_damage_icons = {
	[-2] = "Interface\\ICONS\\Ability_Suffocate", -- Drowning
	[-3] = "Interface\\ICONS\\Spell_Magic_FeatherFall", -- Falling
	[-4] = "Interface\\ICONS\\Spell_Nature_Sleep", -- Fatigue
	[-5] = "Interface\\ICONS\\Spell_Fire_Fire", -- Fire
	[-6] = "Interface\\ICONS\\Spell_Fire_Volcano", -- Lava
	[-7] = "Interface\\ICONS\\INV_Misc_Slime_01", -- Slime
}

-- ── playDeathAlert ───────────────────────────────────────────────────
---Show a death alert popup for the given PlayerData entry.
---@param entry PlayerData
function _dnl.playDeathAlert(entry)
	local s = S()
	if not s or s["enable"] == false then return end

	-- Ensure the alert frame has been fully initialized (textures, font, etc.)
	if not death_alert_frame or not death_alert_frame.textures then
		_dnl.applyDeathAlertSettings()
		if not death_alert_frame or not death_alert_frame.textures then return end
	end

	-- Level filter
	local min_lvl = s["min_lvl_player"] and UnitLevel("player") or s["min_lvl"]
	if entry["level"] and (entry["level"] < min_lvl or entry["level"] > s["max_lvl"]) then
		return
	end

	-- Current zone filter
	if s["current_zone_filter"] then
		local my_current_map = C_Map.GetBestMapForUnit("player")
		if my_current_map == nil then
			local _, _, _, _, _, _, _, _instance_id = GetInstanceInfo()
			if entry["instance_id"] ~= _instance_id then return end
		end
		if entry["map_id"] ~= my_current_map then return end
	end

	-- Guild only filter
	if s["guild_only"] then
		local guildName = GetGuildInfo("player")
		if entry["guild"] ~= guildName or _guild_members[entry["name"]] == nil then return end
	end

	-- Name dedup
	local cached = alert_cache[entry["name"]]
	if cached then
		if GetServerTime() - cached.ts <= _dnl.getDedupWindow(math.max(tonumber(entry["level"]) or 0, cached.level or 0)) then return end
	end
	alert_cache[entry["name"]] = { ts = GetServerTime(), level = tonumber(entry["level"]) or 0 }

	-- Sound
	if s["enable_sound"] then
		if s["alert_sound"] == "default_hardcore" then
			PlaySound(8959)
		elseif s["alert_sound"] == "random" then
			PlayRandomSound()
		else
			PlaySoundFile(sounds[s["alert_sound"]])
		end
	end

	-- Resolve class/race/zone strings
	local class = ""
	if entry["class_id"] then
		class = GetClassInfo(entry["class_id"]) or ""
		if _dnl.D.CLASS_ID_TO_COLOR[entry["class_id"]] then
			class = "|c" .. _dnl.D.CLASS_ID_TO_COLOR[entry["class_id"]]:GenerateHexColor() .. class .. "|r"
		end
	end

	local race = ""
	if entry["race_id"] then
		local race_info = C_CreatureInfo.GetRaceInfo(entry["race_id"])
		if race_info then race = race_info.raceName else race = "" end
	end

	local zone = ""
	if entry["map_id"] then
		local map_info = C_Map.GetMapInfo(entry["map_id"])
		if map_info then zone = map_info.name end
	elseif entry["instance_id"] then
		zone = id_to_instance[entry["instance_id"]] or ""
	end

	-- Pick message template
	local msg = s["message"]
	local source_name = ""
	if entry["source_id"] then
		if id_to_npc[entry["source_id"]] then
			source_name = id_to_npc[entry["source_id"]]
		end
	end

	if entry["source_id"] == -2 then msg = s["drown_message"] end
	if entry["source_id"] == -3 then msg = s["fall_message"] end
	if entry["source_id"] == -4 then msg = s["fatigue_message"] end
	if entry["source_id"] == -5 then msg = s["fire_message"] end
	if entry["source_id"] == -6 then msg = s["lava_message"] end
	if entry["source_id"] == -7 then msg = s["slime_message"] end

	-- PvP source
	local pvp_source_name = entry["extra_data"] and entry["extra_data"]["pvp_source_name"]
	local source_name_pvp = _dnl.decodePvpSource(entry["source_id"], pvp_source_name) or ""
	if source_name_pvp ~= "" then source_name = source_name_pvp end

	-- Watchlist icon (optional — depends on host providing deathlog_watchlist_entries)
	local watchlist_icon = ""
	if type(deathlog_watchlist_entries) == "table"
		and deathlog_watchlist_entries[entry["name"]]
		and deathlog_watchlist_entries[entry["name"]]["Icon"] then
		watchlist_icon = deathlog_watchlist_entries[entry["name"]]["Icon"] .. " "
	end

	-- Substitutions
	local subs = {
		["name"]       = watchlist_icon .. (entry["name"] or ""),
		["class"]      = class or "",
		["race"]       = race or "",
		["source"]     = source_name or "",
		["guild"]      = entry["guild"] or "",
		["level"]      = entry["level"] and tostring(entry["level"]) or "",
		["zone"]       = zone or "",
		["playtime"]   = _dnl.formatPlaytime(entry["played"]) or "",
		["last_words"] = entry["last_words"] or "",
	}

	local function applySubs(str)
		return str:gsub("<([^>]+)>", function(tag) return subs[tag] or ("<" .. tag .. ">") end)
	end

	-- Strict groups [...]: ALL tags must be non-empty
	msg = msg:gsub("%[(.-)%]", function(group)
		for tag in group:gmatch("<([^>]+)>") do
			if not subs[tag] or subs[tag] == "" then return "" end
		end
		return applySubs(group)
	end)
	-- Relaxed groups (...): at least ONE tag must be non-empty
	msg = msg:gsub("%((.-)%)", function(group)
		local any = false
		for tag in group:gmatch("<([^>]+)>") do
			if subs[tag] and subs[tag] ~= "" then any = true; break end
		end
		if not any then return "" end
		return applySubs(group)
	end)
	-- Remaining tags outside groups
	msg = applySubs(msg)
	if death_alert_frame.remove_new_lines then
		msg = msg:gsub("\n", " ")
	end

	death_alert_frame.text:SetText(msg)

	-- Hide textures for text_only style
	if s["style"] == "text_only" and death_alert_frame.textures then
		for _, v in pairs(death_alert_frame.textures) do
			if v.Hide then v:Hide() end
		end
	end

	if not death_alert_frame.textures then return end

	-- Hide animated model from a previous alert if this style doesn't use it
	if s["style"] ~= "boss_banner_enemy_icon_animated" and s["style"] ~= "lf_animated" then
		if death_alert_frame.textures.modelLayer then death_alert_frame.textures.modelLayer:Hide() end
		if death_alert_frame.textures.backlayer then death_alert_frame.textures.backlayer:Hide() end
	end

	-- Enemy portrait (static)
	if s["style"] == "boss_banner_enemy_icon_small" or s["style"] == "boss_banner_enemy_icon_medium" then
		if source_name_pvp ~= "" then
			if string.find(source_name_pvp, "Duel to Death") then
				death_alert_frame.textures.enemy_portrait:SetTexture("Interface\\ICONS\\inv_jewelry_trinketpvp_02")
			else
				death_alert_frame.textures.enemy_portrait:SetTexture("Interface\\ICONS\\Ability_warrior_challange")
			end
		elseif entry["source_id"] then
			if id_to_display_id[entry["source_id"]] then
				local portrait_to_use = death_alert_frame.textures.enemy_portrait
				portrait_to_use:Hide()
				SetPortraitTextureFromCreatureDisplayID(portrait_to_use, id_to_display_id[entry["source_id"]])
				portrait_to_use:AddMaskTexture(death_alert_frame.textures.enemy_portrait_mask)
				C_Timer.After(0.04, function()
					if portrait_to_use and portrait_to_use.Show then portrait_to_use:Show() end
				end)
			elseif environment_damage_icons[entry["source_id"]] then
				death_alert_frame.textures.enemy_portrait:SetTexture(environment_damage_icons[entry["source_id"]])
			else
				death_alert_frame.textures.enemy_portrait:SetTexture("Interface\\ICONS\\INV_Misc_Bone_ElfSkull_01")
			end
		else
			death_alert_frame.textures.enemy_portrait:SetTexture("Interface\\ICONS\\INV_Misc_Bone_ElfSkull_01")
		end
	elseif s["style"] == "boss_banner_enemy_icon_animated" or s["style"] == "lf_animated" then
		local texture = death_alert_frame.textures.enemy_portrait
		texture:Hide()
		local drawLayer = texture:GetDrawLayer()
		if death_alert_frame.textures.animated_portrait == nil then
			death_alert_frame.textures.animated_portrait = {}
		end
		local portrait = death_alert_frame.textures.animated_portrait
		portrait.cx = texture:GetWidth()
		portrait.cy = texture:GetHeight()

		if drawLayer == "OVERLAY" then drawLayer = "ARTWORK" else drawLayer = "BACKGROUND" end

		if death_alert_frame.textures.backlayer == nil then
			death_alert_frame.textures.backlayer = texture:GetParent():CreateTexture(nil, drawLayer, nil, -1)
		end
		portrait.backLayer = death_alert_frame.textures.backlayer
		portrait.backLayer:Hide()
		portrait.backLayer:SetTexture("Interface\\AddOns\\Adapt\\Adapt-ModelBack")
		portrait.backLayer:SetWidth(portrait.cx)
		portrait.backLayer:SetHeight(portrait.cy)
		for i = 1, texture:GetNumPoints() do
			portrait.backLayer:SetPoint(texture:GetPoint(i))
		end

		if death_alert_frame.textures.modelLayer == nil then
			death_alert_frame.textures.modelLayer = CreateFrame("PlayerModel", nil, death_alert_frame)
		end
		portrait.modelLayer = death_alert_frame.textures.modelLayer
		portrait.modelLayer.useParentLevel = true
		portrait.modelLayer:Hide()
		portrait.modelLayer.parentTexture = texture
		portrait.modelLayer:SetModelDrawLayer("OVERLAY", 6)

		if death_alert_frame.textures.maskLayer == nil then
			death_alert_frame.textures.maskLayer = death_alert_frame:CreateTexture(nil, drawLayer, nil, 1)
		end
		portrait.maskLayer = death_alert_frame.textures.maskLayer
		portrait.maskLayer:SetPoint("TOPLEFT", portrait.backLayer)
		portrait.maskLayer:SetPoint("BOTTOMRIGHT", portrait.backLayer)
		portrait.maskLayer:SetTexture("Interface\\AddOns\\Adapt\\Adapt-Mask")

		portrait.modelLayer:SetPoint("CENTER", death_alert_frame.textures.top_emblem_overlay, "CENTER", 0, 0)
		portrait.modelLayer:SetWidth(death_alert_frame.textures.top_emblem_overlay:GetWidth() * 0.55)
		portrait.modelLayer:SetHeight(death_alert_frame.textures.top_emblem_overlay:GetHeight() * 0.55)
		portrait.modelLayer:SetShown(true)
		portrait.backLayer:SetTexCoord(0, 1, 0, 1)
		portrait.maskLayer:SetShown(false)

		-- Create a dedicated envIcon for environment damage (flat icon, no mask)
		if death_alert_frame.textures.envIcon == nil then
			death_alert_frame.textures.envIcon = death_alert_frame:CreateTexture(nil, "OVERLAY")
			death_alert_frame.textures.envIcon:SetDrawLayer("OVERLAY", 7)
		end
		death_alert_frame.textures.envIcon:SetPoint("CENTER", death_alert_frame.textures.top_emblem_overlay, "CENTER", 0, 0)
		death_alert_frame.textures.envIcon:SetSize(
			death_alert_frame.textures.top_emblem_overlay:GetWidth() * 0.55,
			death_alert_frame.textures.top_emblem_overlay:GetHeight() * 0.55
		)

		if id_to_display_id[entry["source_id"]] then
			portrait.modelLayer:ClearModel()
			portrait.modelLayer:SetDisplayInfo(id_to_display_id[entry["source_id"]])
			portrait.modelLayer:SetPortraitZoom(1)
			portrait.modelLayer:SetRotation(0)
			death_alert_frame.textures.envIcon:Hide()
		elseif environment_damage_icons[entry["source_id"]] then
			portrait.modelLayer:SetShown(false)
			death_alert_frame.textures.envIcon:SetTexture(environment_damage_icons[entry["source_id"]])
			death_alert_frame.textures.envIcon:Show()
		else
			portrait.modelLayer:SetShown(false)
			death_alert_frame.textures.envIcon:SetTexture("Interface\\ICONS\\INV_Misc_Bone_ElfSkull_01")
			death_alert_frame.textures.envIcon:Show()
		end
	end

	death_alert_frame:Show()
	death_alert_frame.text:SetFont((fonts[s["font"]] or "Fonts\\NIM_____.ttf"), s["font_size"] * (death_alert_frame.lf_font_scale or 1))

	if death_alert_frame.timer then death_alert_frame.timer:Cancel() end
	death_alert_frame.timer = C_Timer.NewTimer(s["display_time"], function()
		death_alert_frame:Hide()
	end)
end

-- ── testDeathAlert ───────────────────────────────────────────────────
function _dnl.testDeathAlert()
	if type(DeathNotificationLib.CreateFakeEntry) == "function" then
		local fake_entry = DeathNotificationLib.CreateFakeEntry()
		alert_cache[fake_entry["name"]] = nil
		_dnl.playDeathAlert(fake_entry)
	end
end

-- ── applyDeathAlertSettings ──────────────────────────────────────────
local _da_options_registered = false

function _dnl.applyDeathAlertSettings()
	local settings = _dnl.getDeathAlertOwnerSettings()
	if not settings then return end
	applyDefaults(false)
	local s = S()
	if not s then return end

	createDeathAlertFrame()

	death_alert_frame:ClearAllPoints()
	death_alert_frame:SetPoint("CENTER", UIParent, "CENTER", s["pos_x"], s["pos_y"])
	death_alert_frame:SetSize(s["size_x"], s["size_y"])

	if s["style"] == "boss_banner_basic_small" then
		initializeBossBanner(nil, "small")
	elseif s["style"] == "boss_banner_basic_medium" then
		initializeBossBanner(nil, "medium")
	elseif s["style"] == "boss_banner_enemy_icon_small" then
		initializeBossBanner("enemy_icon", "small")
	elseif s["style"] == "boss_banner_enemy_icon_medium" then
		initializeBossBanner("enemy_icon", "medium")
	elseif s["style"] == "boss_banner_enemy_icon_animated" then
		initializeBossBanner("enemy_icon", "animated")
	elseif s["style"] == "lf_animated" then
		initializeLFBanner("enemy_icon", "animated")
	elseif s["style"] == "text_only" then
		initializeBossBanner("enemy_icon", "medium")
	end

	death_alert_frame.text:SetFont((fonts[s["font"]] or "Fonts\\NIM_____.ttf"), s["font_size"] * (death_alert_frame.lf_font_scale or 1))
	death_alert_frame.text:SetTextColor(s["font_color_r"], s["font_color_g"], s["font_color_b"], s["font_color_a"])

	-- Register AceConfig options panel if available and not yet registered
	if AceConfig and AceConfigDialog and not _da_options_registered then
		_da_options_registered = true
		local da_options = {
			name = widget_name,
			type = "group",
			args = {
				enable = {
					type = "toggle", name = "Show Death Alert", desc = "Show Death Alert", order = 0,
					get = function() return S()["enable"] end,
					set = function() S()["enable"] = not S()["enable"]; _dnl.applyDeathAlertSettings() end,
				},
				enable_sound = {
					type = "toggle", name = "Enable Sound", desc = "Enable alert sound.", order = 0,
					get = function() return S()["enable_sound"] end,
					set = function() S()["enable_sound"] = not S()["enable_sound"]; _dnl.applyDeathAlertSettings() end,
				},
				guild_only_toggle = {
					type = "toggle", name = "Guild only alerts", desc = "Only show alerts for deaths within the player's guild.", order = 1,
					get = function() return S()["guild_only"] end,
					set = function() S()["guild_only"] = not S()["guild_only"]; _dnl.applyDeathAlertSettings() end,
				},
				my_zone_only_toggle = {
					type = "toggle", name = "Current zone only alerts", desc = "Only show alerts for deaths within the player's current zone.", order = 1,
					get = function() return S()["current_zone_filter"] end,
					set = function() S()["current_zone_filter"] = not S()["current_zone_filter"]; _dnl.applyDeathAlertSettings() end,
				},
				display_time = {
					type = "range", name = "Alert Display Time", desc = "Alert Display Time", min = 1, max = 10, step = 0.5, order = 2,
					get = function() return S()["display_time"] end,
					set = function(_, value) S()["display_time"] = value; _dnl.applyDeathAlertSettings() end,
				},
				test = {
					type = "execute", name = "Test", desc = "Test the death alert. Clicking this button fakes a death alert.",
					func = function() _dnl.testDeathAlert() end,
				},
				lvl_opts = {
					type = "group", name = "Level Settings", inline = true, order = 5,
					args = {
						min_lvl = {
							type = "range", name = "Min. Lvl. to Display", desc = "Minimum level to display", min = 1, max = MAX_PLAYER_LEVEL, step = 1, order = 1,
							disabled = function() return S()["min_lvl_player"] end,
							get = function() if S()["min_lvl_player"] then return UnitLevel("player") end; return S()["min_lvl"] end,
							set = function(_, value) S()["min_lvl"] = value; _dnl.applyDeathAlertSettings() end,
						},
						max_lvl = {
							type = "range", name = "Max. Lvl. to Display", desc = "Maximum level to display", min = 1, max = MAX_PLAYER_LEVEL, step = 1,
							get = function() return S()["max_lvl"] end,
							set = function(_, value) S()["max_lvl"] = value; _dnl.applyDeathAlertSettings() end,
						},
						min_lvl_player = {
							type = "toggle", name = "Use my level as Min. Lvl.", desc = "Only show alerts for characters your level or higher",
							get = function() return S()["min_lvl_player"] end,
							set = function(_, value) S()["min_lvl_player"] = value; _dnl.applyDeathAlertSettings() end,
						},
					},
				},
				dl_styles = {
					type = "select", name = "Theme", width = 1.4, desc = "Choose a Death Alert Theme",
					dialogControl = LSM30 and "LSM30_Font" or nil,
					values = death_alert_styles,
					get = function() return S()["style"] end,
					set = function(_, key) S()["style"] = key; _dnl.applyDeathAlertSettings() end,
				},
				font = {
					type = "select", name = "Font", desc = "Font to use for death alerts.",
					dialogControl = LSM30 and "LSM30_Font" or nil,
					values = fonts,
					get = function() return S()["font"] end,
					set = function(_, key) S()["font"] = key; _dnl.applyDeathAlertSettings() end,
				},
				font_size = {
					type = "range", name = "Font size", desc = "Font size", min = 6, max = 40, step = 1,
					get = function() return S()["font_size"] end,
					set = function(_, value) S()["font_size"] = value; _dnl.applyDeathAlertSettings() end,
				},
				font_color = {
					type = "color", name = "Font color", desc = "Font color",
					get = function() return S()["font_color_r"], S()["font_color_g"], S()["font_color_b"], S()["font_color_a"] end,
					set = function(_, r, g, b, a) S()["font_color_r"]=r; S()["font_color_g"]=g; S()["font_color_b"]=b; S()["font_color_a"]=a; _dnl.applyDeathAlertSettings() end,
				},
				msginput = {
					type = "input", name = "Message", width = 2.5, multiline = true,
					desc = "Customize the death alert message.\nSubstitutions:\n<name> = Character name\n<race> = Character race\n<class> = Character class\n<level> = Character level\n<guild> = Guild name\n<source> = Killer name\n<zone> = Character zone\n<playtime> = Time played\n<last_words> = Last words\n\nGroups:\n(...) = Relaxed group, shown if at least one tag has a value\n[...] = Strict group, shown only if all tags have values",
					get = function() return S()["message"] end,
					set = function(_, val) S()["message"] = val; _dnl.applyDeathAlertSettings() end,
					validate = function(_, val)
						local valid_tags = { name=1, race=1, class=1, level=1, guild=1, source=1, zone=1, playtime=1, last_words=1 }
						for tag in val:gmatch("<([^>]+)>") do if not valid_tags[tag] then return "Unknown tag: <"..tag..">" end end
						local pd, bd = 0, 0
						for i = 1, #val do
							local c = val:sub(i,i)
							if c=="(" then pd=pd+1; if pd>1 then return "Nested (...) groups are not supported" end
							elseif c==")" then pd=pd-1; if pd<0 then return "Unexpected ')' without matching '('" end
							elseif c=="[" then bd=bd+1; if bd>1 then return "Nested [...] groups are not supported" end
							elseif c=="]" then bd=bd-1; if bd<0 then return "Unexpected ']' without matching '['" end end
						end
						if pd~=0 then return "Unclosed '(' — missing ')'" end
						if bd~=0 then return "Unclosed '[' — missing ']'" end
						local stack = {}
						for i = 1, #val do
							local c = val:sub(i,i)
							if c=="(" or c=="[" then
								table.insert(stack, c)
							elseif c==")" then
								if #stack==0 or stack[#stack]~="(" then return "Mismatched groups: ')' closes a '[' group" end
								table.remove(stack)
							elseif c=="]" then
								if #stack==0 or stack[#stack]~="[" then return "Mismatched groups: ']' closes a '(' group" end
								table.remove(stack)
							end
						end
						for group in val:gmatch("%((.-)%)") do
							if not group:find("<[^>]+>") then return "Relaxed group (...) must contain at least one <tag>" end
						end
						for group in val:gmatch("%[(.-)%]") do
							if not group:find("<[^>]+>") then return "Strict group [...] must contain at least one <tag>" end
						end
						return true
					end,
				},
				reset_size_and_pos = {
					type = "execute", name = "Reset to default", desc = "Reset to default",
					func = function() applyDefaults(true); _dnl.applyDeathAlertSettings() end,
				},
				accent_color = {
					type = "color", name = "Frame accent color", desc = "Frame accent color",
					get = function() return S()["accent_color_r"], S()["accent_color_g"], S()["accent_color_b"], S()["accent_color_a"] end,
					set = function(_, r, g, b, a) S()["accent_color_r"]=r; S()["accent_color_g"]=g; S()["accent_color_b"]=b; S()["accent_color_a"]=a; _dnl.applyDeathAlertSettings() end,
				},
				da_sound = {
					type = "select", name = "Death Alert Sound", desc = "Sound to use for death alerts.",
					dialogControl = LSM30 and "LSM30_Sound" or nil,
					values = LSM30 and LSM30:HashTable("sound") or sounds,
					get = function() return S()["alert_sound"] end,
					set = function(_, key) S()["alert_sound"] = key; _dnl.applyDeathAlertSettings() end,
				},
				position = {
					type = "group", name = "Position", inline = true, order = -1,
					args = {
						x_size = { type = "range", name = "X-Scale", desc = "X-Scale", min = 200, max = 1000, step = 1, get = function() return S()["size_x"] end, set = function(_,v) S()["size_x"]=v; _dnl.applyDeathAlertSettings() end },
						y_size = { type = "range", name = "Y-Scale", desc = "Y-Scale", min = 50, max = 600, step = 1, get = function() return S()["size_y"] end, set = function(_,v) S()["size_y"]=v; _dnl.applyDeathAlertSettings() end },
						pos_x = { type = "range", name = "X-Position", desc = "X-Position", min = -1000, max = 1000, step = 1, get = function() return S()["pos_x"] end, set = function(_,v) S()["pos_x"]=v; _dnl.applyDeathAlertSettings() end },
						pos_y = { type = "range", name = "Y-Position", desc = "Y-Position", min = -1000, max = 1000, step = 1, get = function() return S()["pos_y"] end, set = function(_,v) S()["pos_y"]=v; _dnl.applyDeathAlertSettings() end },
					},
				},
			},
		}
		-- Register under parent category if one exists, otherwise standalone
		local parent = settings._death_alert_options_parent or "Deathlog"
		AceConfig:RegisterOptionsTable(widget_name, da_options)
		AceConfigDialog:AddToBlizOptions(widget_name, widget_name, parent)
	end
end

--#region API

DeathNotificationLib.FormatPlaytime = _dnl.formatPlaytime

DeathNotificationLib.PlayDeathAlert = _dnl.playDeathAlert

DeathNotificationLib.TestDeathAlert = _dnl.testDeathAlert

DeathNotificationLib.UpdateDeathAlert = _dnl.applyDeathAlertSettings

--#endregion
