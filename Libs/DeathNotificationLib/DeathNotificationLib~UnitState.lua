--[[
DeathNotificationLib~UnitState.lua

Per-unit state tracking and realm classification.

Maintains a UnitState record for each party/raid member, tracking
last attack source and recent chat ("last words").  Determines at
load time whether the current realm is Hardcore or Soul of Iron.

Exported constants:
  HC_STATE           – enum: UNDETERMINED / HARDCORE / NOT_HARDCORE / NOT_HARDCORE_ANYMORE
  IS_HARDCORE_REALM  – true on native Hardcore realms
  IS_SOUL_OF_IRON_REALM – true on Burning Crusade Classic
  MAX_PLAYER_LEVEL   – expansion-dependent level cap
  ROOT_MAP_ID        – top-level continent map id

UnitState fields per unit:
  name, guid, recent_msg, last_attack_source_name, last_attack_source_guid
--]]

local _dnl = DeathNotificationLib.Internal ---@class _dnl
if not _dnl then return end

_dnl.HC_STATE = {
	UNDETERMINED = 0,
	HARDCORE = 1,
	NOT_HARDCORE = 2,
	NOT_HARDCORE_ANYMORE = 3,
}

_dnl.MAX_PLAYER_LEVEL = GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion() or MAX_PLAYER_LEVEL
_dnl.IS_HARDCORE_REALM = (C_GameRules.IsHardcoreActive and C_GameRules.IsHardcoreActive()) or (C_ClassicHardcore and C_ClassicHardcore.IsHardcoreSelf and C_ClassicHardcore.IsHardcoreSelf()) or (C_Seasons and C_Seasons.GetActiveSeason and (C_Seasons.GetActiveSeason() == 3 or C_Seasons.GetActiveSeason() == 12))
_dnl.IS_SOUL_OF_IRON_REALM = WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC
_dnl.ROOT_MAP_ID = GetExpansionLevel and GetExpansionLevel() >= 1 and 946 or 947

---@class UnitState
---@field name string
---@field guid string
---@field recent_msg string
---@field last_attack_source_name string|nil
---@field last_attack_source_guid string|nil

---@type { [UnitToken]: UnitState }
local unit_states = {}

---@param unit UnitToken
---@return boolean
function _dnl.isUnitInPartyOrRaid(unit)
	return UnitInParty(unit) or UnitInRaid(unit)
end

---@param char_data UnitState|nil
function _dnl.initUnitStates(char_data)
	unit_states["player"] = char_data
end

---@param unit UnitToken
---@return UnitState
function _dnl.getUnitState(unit)
	if not unit_states[unit] or unit_states[unit].name ~= UnitName(unit) then
		unit_states[unit] = {
			name = UnitName(unit),
			guid = UnitGUID(unit),
			recent_msg = "",
		}
	end

	return unit_states[unit]
end

---@param unit UnitToken
---@return boolean
function _dnl.canUseUnitStates(unit)
	return unit == "player" or _dnl.isUnitInPartyOrRaid(unit)
end

--- Build the full list of unit tokens to scan when searching by name.
--- Generated programmatically to avoid a ~130-entry hardcoded list.
local TOKEN_OPTIONS = {
	"player", "vehicle", "pet",
}
for i = 1, 4 do
	TOKEN_OPTIONS[#TOKEN_OPTIONS + 1] = "party" .. i
end
for i = 1, 4 do
	TOKEN_OPTIONS[#TOKEN_OPTIONS + 1] = "partypet" .. i
end
for i = 1, 40 do
	TOKEN_OPTIONS[#TOKEN_OPTIONS + 1] = "raid" .. i
end
for i = 1, 40 do
	TOKEN_OPTIONS[#TOKEN_OPTIONS + 1] = "raidpet" .. i
end
for i = 1, 40 do
	TOKEN_OPTIONS[#TOKEN_OPTIONS + 1] = "nameplate" .. i
end
for i = 1, 3 do
	TOKEN_OPTIONS[#TOKEN_OPTIONS + 1] = "arena" .. i
end
for i = 1, 3 do
	TOKEN_OPTIONS[#TOKEN_OPTIONS + 1] = "arenapet" .. i
end
for i = 1, 5 do
	TOKEN_OPTIONS[#TOKEN_OPTIONS + 1] = "boss" .. i
end
for _, token in ipairs({ "target", "focus", "npc", "mouseover", "softenemy", "softfriend", "softinteract" }) do
	TOKEN_OPTIONS[#TOKEN_OPTIONS + 1] = token
end

---Find a unit token for a given unit name, searching all avaliable token options
---@param unit_name string
---@return UnitToken|nil
function _dnl.findUnitTokenByName(unit_name)
	if not unit_name then return nil end

	for _, token in ipairs(TOKEN_OPTIONS) do
		if UnitExists(token) and UnitName(token) == unit_name then
			return token
		end
	end

	return nil
end

---Find a player token for a given player name, searching all avaliable token options
---@param player_name string
---@return UnitToken|nil
function _dnl.findPlayerTokenByName(player_name)
	if not player_name then return nil end

	for _, token in ipairs(TOKEN_OPTIONS) do
		if UnitExists(token) and UnitIsPlayer(token) and UnitName(token) == player_name then
			return token
		end
	end

	return nil
end

--#region API

DeathNotificationLib.MAX_PLAYER_LEVEL = _dnl.MAX_PLAYER_LEVEL

DeathNotificationLib.HC_STATE = _dnl.HC_STATE

DeathNotificationLib.IS_HARDCORE_REALM = _dnl.IS_HARDCORE_REALM

DeathNotificationLib.IS_SOUL_OF_IRON_REALM = _dnl.IS_SOUL_OF_IRON_REALM

--#endregion