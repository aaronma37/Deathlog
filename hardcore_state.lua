--[[
hardcore_state.lua

Deathlog-specific hardcore status tracking and external addon detection.

Provides the isUnitTracked callback for DeathNotificationLib.AttachAddon()
by combining multiple signals:
  1. Native Hardcore realms (always hardcore)
  2. Soul of Iron realms (BCA — buff scanning via C_UnitAuras)
  3. External addon detection (Hardcore, HardcoreTBC, UltraHardcore)

Also provides deathlog_getHardcoreCharacterState() for the info button.

All Soul of Iron / Tarnished Soul / External Hardcore state is managed
here in a local table.  The player's record is bound to the
deathlog_char_data SavedVariable at login for persistence.

Uses only the DeathNotificationLib public API — no Internal access.

IMPORTANT: This file must load AFTER DeathNotificationLib.xml so that
the DNL public API is available.
--]]

if not DeathNotificationLib then return end

---------------------------------------------------------------------------
-- Constants (all from public API)
---------------------------------------------------------------------------

local HC_STATE              = DeathNotificationLib.HC_STATE
local IS_HARDCORE_REALM     = DeathNotificationLib.IS_HARDCORE_REALM
local IS_SOUL_OF_IRON_REALM = DeathNotificationLib.IS_SOUL_OF_IRON_REALM

--- Whether external addon detection has run
local external_detection_done = false

---------------------------------------------------------------------------
-- HC state storage
--
-- hc_states["player"] is bound to deathlog_char_data (SavedVariable) at
-- PLAYER_LOGIN so that SoI / External HC fields persist across sessions.
-- Non-player units use ephemeral tables.
---------------------------------------------------------------------------

local hc_states = {}    ---@type { [UnitToken]: table }

--- Get or create the HC state record for a unit.
---@param unit UnitToken
---@return table
local function getHcState(unit)
	if not hc_states[unit] then
		hc_states[unit] = {}
	end

	local name = UnitName(unit)
	if name and hc_states[unit]._name ~= name then
		if unit ~= "player" then
			hc_states[unit] = { _name = name }
		else
			hc_states[unit]._name = name
		end
	end

	return hc_states[unit]
end

---------------------------------------------------------------------------
-- Soul of Iron / Tarnished Soul buff detection
---------------------------------------------------------------------------

---@param unit UnitToken
---@return boolean
local function unitHasSoulOfIron(unit)
	for i = 1, 40 do
		local auraData = C_UnitAuras.GetBuffDataByIndex(unit, i)
		if not auraData then break end
		if auraData.spellId == 364001 then
			return true
		end
	end
	return false
end

---@param unit UnitToken
---@return boolean
local function unitHasTarnishedSoul(unit)
	for i = 1, 40 do
		local auraData = C_UnitAuras.GetDebuffDataByIndex(unit, i)
		if not auraData then break end
		if auraData.spellId == 364226 then
			return true
		end
	end
	return false
end

--- Update Soul of Iron / Tarnished Soul fields on the HC state record.
---@param unit UnitToken
local function updateSoulOfIronTracking(unit)
	if not IS_SOUL_OF_IRON_REALM then return end

	local unitState = getHcState(unit)

	if unitHasSoulOfIron(unit) then
		unitState.hasSoulOfIron = true
		unitState.hadSoulOfIron = true
	else
		unitState.hasSoulOfIron = false
	end

	if unitHasTarnishedSoul(unit) then
		unitState.hasTarnishedSoul = true
		unitState.hadTarnishedSoul = true
	else
		unitState.hasTarnishedSoul = false
	end
end

---------------------------------------------------------------------------
-- External addon detectors
-- Each returns true only if the addon is loaded AND the player qualifies.
---------------------------------------------------------------------------

local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded

--- Hardcore (Classic Era) — per-character SavedVariable check
local function detectHardcore()
	if not isLoaded("Hardcore") then return false end
	if type(Hardcore_Character) ~= "table" then return false end

	local playerGUID = UnitGUID("player")
	if not playerGUID then return false end

	if Hardcore_Character.guid and Hardcore_Character.guid ~= playerGUID then
		return false
	end
	if not Hardcore_Character.first_recorded then
		return false
	end
	if type(Hardcore_Character.deaths) == "table" and #Hardcore_Character.deaths > 0 then
		return false
	end
	if Hardcore_Character.verification_status == "FAIL" then
		return false
	end

	return true
end

--- HardcoreTBC — audit data + distributed log death check
local function detectHardcoreTBC()
	if not isLoaded("HardcoreTBC") then return false end
	if type(HardcoreTBC_Saved) ~= "table" then return false end

	local playerGUID = UnitGUID("player")
	if not playerGUID then return false end

	if not (HardcoreTBC_Saved.ga and HardcoreTBC_Saved.ga[playerGUID]) then
		return false
	end

	if type(HardcoreTBC_DistributedLogDB) == "table" then
		for _, guildData in pairs(HardcoreTBC_DistributedLogDB) do
			if guildData.events then
				for _, event in pairs(guildData.events) do
					if event.type == 10
						and not event.ignored
						and event.guid == playerGUID
					then
						return false
					end
				end
			end
		end
	end

	if IsInGuild() then
		local playerName = UnitName("player") .. "-" .. GetNormalizedRealmName()
		for i = 1, GetNumGuildMembers() do
			local name, _, _, _, _, _, publicNote, _, _, _, _, _, _, _, _, _, guid = GetGuildRosterInfo(i)
			if guid == playerGUID or name == playerName then
				if publicNote and string.match(publicNote, "^%[D%]") then
					return false
				end
				break
			end
		end
	end

	return true
end

--- UltraHardcore — GUID-keyed character settings check
local function detectUltraHardcore()
	if not isLoaded("UltraHardcore") then return false end
	if type(UltraHardcoreDB) ~= "table" then return false end

	local playerGUID = UnitGUID("player")
	if not playerGUID then return false end

	if not (UltraHardcoreDB.characterSettings and UltraHardcoreDB.characterSettings[playerGUID]) then
		return false
	end

	if UltraHardcoreDB.characterStats
		and UltraHardcoreDB.characterStats[playerGUID]
		and (UltraHardcoreDB.characterStats[playerGUID].playerDeaths or 0) > 0
	then
		return false
	end

	return true
end

local detectors = {
	{ name = "Hardcore",      detect = detectHardcore },
	{ name = "HardcoreTBC",   detect = detectHardcoreTBC },
	{ name = "UltraHardcore", detect = detectUltraHardcore },
}

---------------------------------------------------------------------------
-- External HC marking
---------------------------------------------------------------------------

--- Mark the player as hardcore via an external addon.
--- Writes to the duck-typed fields on the player's unit state.
---@param addonName string
---@return boolean
local function markExternalHardcore(addonName)
	if not addonName or type(addonName) ~= "string" then return false end

	local state = getHcState("player")
	if state.hasExternalHardcore or state.hadExternalHardcore then return false end

	state.hasExternalHardcore = addonName
	return true
end

---------------------------------------------------------------------------
-- Run external addon detection (called once at login)
---------------------------------------------------------------------------

local function runExternalDetection()
	if external_detection_done then return end
	external_detection_done = true

	-- Skip detection on native HC realms where status is already known
	if IS_HARDCORE_REALM then return end

	-- Also skip if status is already determined via other means (e.g. Soul of Iron buff)
	local state = deathlog_getHardcoreCharacterState("player")
	if state == HC_STATE.HARDCORE or state == HC_STATE.NOT_HARDCORE_ANYMORE then
		return
	end

	for _, entry in ipairs(detectors) do
		if entry.detect() then
			markExternalHardcore(entry.name)
			return
		end
	end
end

---------------------------------------------------------------------------
-- State query
---------------------------------------------------------------------------

--- Returns the hardcore state for the given unit.
--- Reads duck-typed fields (hasSoulOfIron, hasExternalHardcore, etc.) from
--- the unit state table.  These fields are managed by this file, not by DNL.
---@param unit UnitToken|nil  defaults to "player"
---@return integer  One of HC_STATE values
function deathlog_getHardcoreCharacterState(unit)
	unit = unit or "player"

	if IS_HARDCORE_REALM then
		return HC_STATE.HARDCORE
	end

	local unitState = getHcState(unit)

	if unitState.hadExternalHardcore then
		return HC_STATE.NOT_HARDCORE_ANYMORE
	end

	if unitState.hasExternalHardcore then
		return HC_STATE.HARDCORE
	end

	if IS_SOUL_OF_IRON_REALM then
		if unitState.hadTarnishedSoul then
			return HC_STATE.NOT_HARDCORE_ANYMORE
		end

		if unitState.hasSoulOfIron then
			return HC_STATE.HARDCORE
		end

		return HC_STATE.UNDETERMINED
	end

	return HC_STATE.NOT_HARDCORE
end

---------------------------------------------------------------------------
-- isUnitTracked callback for AttachAddon
---------------------------------------------------------------------------

--- Returns the name of the external HC addon the player had, or nil.
---@return string|nil
function deathlog_getExternalHardcoreAddon()
	return getHcState("player").hadExternalHardcore
end

--- Returns true if the unit should have its deaths tracked by Deathlog.
--- This is the callback passed to DeathNotificationLib.AttachAddon().
---@param unit string  Unit token (e.g. "player", "party1")
---@return boolean
function deathlog_isUnitTracked(unit)
	return deathlog_getHardcoreCharacterState(unit) == HC_STATE.HARDCORE
end

---------------------------------------------------------------------------
-- Death-time state transitions
--
-- When the player dies, flip external-HC "has" → "had" and mark SoI
-- as tainted so future isUnitTracked calls return false.
-- This runs in a separate PLAYER_DEAD handler AFTER DNL's handler
-- (because this frame is created later), so the broadcast has already
-- been decided by the time we flip the state.
---------------------------------------------------------------------------

local deathFrame = CreateFrame("Frame")
deathFrame:RegisterEvent("PLAYER_DEAD")
deathFrame:SetScript("OnEvent", function()
	local unitState = getHcState("player")

	-- External HC: they died, so they HAD it but no longer HAVE it
	if unitState.hasExternalHardcore then
		unitState.hadExternalHardcore = unitState.hasExternalHardcore
		unitState.hasExternalHardcore = nil
	end

	-- SoI realm: mark tainted on any death so we don't broadcast again
	if IS_SOUL_OF_IRON_REALM then
		unitState.hadSoulOfIron = true
		unitState.hadTarnishedSoul = true
	end
end)

---------------------------------------------------------------------------
-- UNIT_AURA tracking (SoI realms only)
---------------------------------------------------------------------------

if IS_SOUL_OF_IRON_REALM then
	local auraFrame = CreateFrame("Frame")
	auraFrame:RegisterEvent("UNIT_AURA")
	auraFrame:SetScript("OnEvent", function(self, event, unit)
		if unit == "player" or UnitInParty(unit) or UnitInRaid(unit) then
			updateSoulOfIronTracking(unit)
		end
	end)
end

---------------------------------------------------------------------------
-- Initialization — run at login
---------------------------------------------------------------------------

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
	self:UnregisterAllEvents()

	-- Bind the per-character SavedVariable as the player's HC state so
	-- Soul of Iron / Tarnished Soul / External HC fields persist across sessions.
	deathlog_char_data = deathlog_char_data or {}
	hc_states["player"] = deathlog_char_data
	updateSoulOfIronTracking("player")

	-- Delay slightly so other addons' PLAYER_LOGIN handlers have run
	C_Timer.After(0.2, function()
		runExternalDetection()
	end)
end)
