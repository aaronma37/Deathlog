--[[
DeathNotificationLib~PvP.lua

PvP death-source encoding and decoding.

Bit-packs the attacker's race, class, level, and PvP flag (regular or
duel-to-death) into a single numeric source_id so PvP kills fit neatly
into the same PlayerData pipeline used for NPC and environment deaths.

  Bit layout (multiplied by powers of 2):
    bits 21-23  – PvP flag  (NONE / REGULAR / DUEL_TO_DEATH)
    bits 29-36  – attacker race
    bits 37-44  – attacker class
    bits 45-52  – attacker level

Also maintains a transient pvp_state singleton that tracks the current
duel-to-death opponent.  Attacker race/class/level are resolved directly
from the source GUID at death time via encodePvpSource.
--]]

local _dnl = DeathNotificationLib.Internal ---@class _dnl
if not _dnl then return end

_dnl.PVP_FLAGS = {
	NONE = 0,
	REGULAR = 1,
	DUEL_TO_DEATH = 2,
}

---Grouped PvP / duel-to-death tracking state
---@class PvPState
---@field duel_to_death_player string|nil
_dnl.pvp_state = {
	duel_to_death_player = nil,
}



---Bit-pack a PvP source ID from flag + race/class/level.
---@param pvp_flag number One of _dnl.PVP_FLAGS.*
---@param race number|nil
---@param class number|nil
---@param level number|nil
---@return number source_id
function _dnl.createPvpSourceId(pvp_flag, race, class, level)
	local source_id = 0

	source_id = source_id + pvp_flag * 2^21
	source_id = source_id + (race or 0) * 2^29
	source_id = source_id + (class or 0) * 2^37
	source_id = source_id + ((level and level > 0) and level or 0) * 2^45

	return source_id
end

---Validate if a source_id corresponds to a PvP kill.
---@param source_id number|string|nil
---@return boolean is_valid
function _dnl.isValidPvpSourceId(source_id)
	if source_id == nil then return false end

	local source_id_num = tonumber(source_id)
	if not source_id_num then return false end

	if
		source_id_num == -1
		or _dnl.D.ID_TO_NPC[source_id_num]
		or _dnl.ENVIRONMENT_DAMAGE[source_id_num]
	then
		return false
	end

	local retrievedPvPFlag = math.floor(source_id_num / 2^21) % 8
	if retrievedPvPFlag and retrievedPvPFlag ~= _dnl.PVP_FLAGS.NONE then
		local retrievedEnemyRace = math.floor(source_id_num / 2^29) % 256
		if retrievedEnemyRace and retrievedEnemyRace > 0 and not _dnl.D.RACE_ID_MAP[retrievedEnemyRace] then
			return false
		end

		local retrievedEnemyClass = math.floor(source_id_num / 2^37) % 256
		if retrievedEnemyClass and retrievedEnemyClass > 0 and not _dnl.D.CLASS_ID_MAP[retrievedEnemyClass] then
			return false
		end

		local retrievedEnemyLevel = math.floor(source_id_num / 2^45) % 256
		if retrievedEnemyLevel and retrievedEnemyLevel > 0 and retrievedEnemyLevel > _dnl.MAX_PLAYER_LEVEL then
			return false
		end

		return true
	end

	return false
end

---Encode a PvP death source from a player name and/or GUID.
---Resolves race/class from GetPlayerInfoByGUID when a GUID is available,
---and attempts to get the level via UnitTokenFromGUID.  When no GUID is
---given, falls back to finding the unit by name (target, party, raid,
---nameplates) and reading race/class/level from that unit token.
---@param source_name string|nil Player name (may be resolved from GUID)
---@param source_guid string|nil Player GUID
---@return boolean success Whether PvP encoding succeeded
---@return number|nil source_id Bit-packed source ID
---@return string|nil pvp_source_name Player name if PvP kill detected
function _dnl.encodePvpSource(source_name, source_guid)
	local function create_result(name, race, class, level)
		local pvp_flag = _dnl.PVP_FLAGS.REGULAR
		if _dnl.pvp_state.duel_to_death_player ~= nil and _dnl.pvp_state.duel_to_death_player == name then
			pvp_flag = _dnl.PVP_FLAGS.DUEL_TO_DEATH
		end

		return true, _dnl.createPvpSourceId(pvp_flag, race, class, level), name
	end

	-- GUID path: use GetPlayerInfoByGUID for race/class/name, UnitTokenFromGUID for level
	if source_guid then
		local source_type = strsplit("-", source_guid)
		if source_type ~= "Player" then
			return false, nil, nil
		end

		local _, englishClass, _, englishRace, _, guid_name, _ = GetPlayerInfoByGUID(source_guid)
		local resolved_name = source_name or guid_name

		if not resolved_name then
			return false, nil, nil
		end

		local race_id = englishRace and _dnl.D.RACE_FILE_TO_ID[englishRace] or nil
		local class_id = englishClass and _dnl.D.CLASS_FILE_TO_ID[englishClass] or nil

		-- Try to get level from the unit token (may be nil or -1/0 for ?? targets)
		local level = nil
		local unit = UnitTokenFromGUID(source_guid)
		if unit then
			local unit_level = UnitLevel(unit)
			level = (unit_level and unit_level > 0) and unit_level or nil
		end

		return create_result(resolved_name, race_id, class_id, level)
	end

	-- Non-GUID path: try to find a visible unit token by name
	if not source_name then
		return false, nil, nil
	end

	local unit = _dnl.findPlayerTokenByName(source_name)
	if unit then
		local _, _, enemyRaceId = UnitRace(unit)
		local _, _, enemyClassId = UnitClass(unit)
		local unit_level = UnitLevel(unit)
		local level = (unit_level and unit_level > 0) and unit_level or nil

		return create_result(source_name, tonumber(enemyRaceId), tonumber(enemyClassId), level)
	end

	-- Last resort: if the name matches "PlayerName-RealmName" format it is
	-- very likely a cross-addon source (HardcoreTBC, UltraHardcore) where we
	-- have neither GUID nor visible unit.
	-- WoW character names are 2-12 alphabetic characters followed immediately
	-- by a hyphen and a realm name (also alphabetic, no spaces before the hyphen).
	-- NPC names never carry a realm suffix, so this heuristic is safe.
	local player_part = source_name:match("^(%a+)%-")
	if player_part and #player_part >= 2 and #player_part <= 12 then
		return create_result(source_name, nil, nil, nil)
	end

	-- No GUID, no visible unit, no realm suffix — cannot confirm PvP
	return false, nil, nil
end

---Decode a bit-packed PvP source ID into a human-readable string.
---@param source_id number|string|nil
---@param player_name string|nil
---@return string Formatted description, or "" if not a PvP source
function _dnl.decodePvpSource(source_id, player_name)
	if source_id == nil then return "" end

	local source_id_num = tonumber(source_id)
	if not source_id_num then return "" end

	if
		source_id_num == -1
		or _dnl.D.ID_TO_NPC[source_id_num]
		or _dnl.ENVIRONMENT_DAMAGE[source_id_num]
	then
		return ""
	end

	local retrievedPvPFlag = math.floor(source_id_num / 2^21) % 8
	if retrievedPvPFlag and retrievedPvPFlag ~= _dnl.PVP_FLAGS.NONE then
		local retrievedEnemyRace = math.floor(source_id_num / 2^29) % 256
		local retrievedEnemyClass = math.floor(source_id_num / 2^37) % 256
		local retrievedEnemyLevel = math.floor(source_id_num / 2^45) % 256

		local enemyClass = nil
		if retrievedEnemyClass and retrievedEnemyClass > 0 and _dnl.D.CLASS_ID_MAP[retrievedEnemyClass] then
			enemyClass = GetClassInfo(retrievedEnemyClass) or ""
			if _dnl.D.CLASS_ID_TO_COLOR[retrievedEnemyClass] then
				enemyClass = "|c" .. _dnl.D.CLASS_ID_TO_COLOR[retrievedEnemyClass]:GenerateHexColor() .. enemyClass .. "|r"
			end
		end

		local enemyRace = nil
		if retrievedEnemyRace and retrievedEnemyRace > 0 and _dnl.D.RACE_ID_MAP[retrievedEnemyRace] then
			enemyRace = C_CreatureInfo.GetRaceInfo(retrievedEnemyRace)
			if enemyRace then
				enemyRace = enemyRace.raceName
			else
				enemyRace = ""
			end
		end

		local enemyLevel = nil
		if retrievedEnemyLevel and retrievedEnemyLevel > 0 and retrievedEnemyLevel <= _dnl.MAX_PLAYER_LEVEL then
			enemyLevel = retrievedEnemyLevel
		end

		local source_name = player_name and (player_name .. " in PvP") or "PvP"
		if retrievedPvPFlag == _dnl.PVP_FLAGS.DUEL_TO_DEATH then
			source_name = player_name and (player_name .. " in a Duel to Death") or "Duel to Death"
		end

		if enemyClass or enemyRace or enemyLevel then
			local enemyTable = {}
			if enemyLevel then
				table.insert(enemyTable, "level " .. enemyLevel)
			end
			if enemyRace then
				table.insert(enemyTable, enemyRace)
			end
			if enemyClass then
				table.insert(enemyTable, enemyClass)
			end

			source_name = source_name .. " (" .. table.concat(enemyTable, " ") .. ")"
		end

		return source_name
	end

	return ""
end

--#region API

DeathNotificationLib.PVP_FLAGS = _dnl.PVP_FLAGS

DeathNotificationLib.CreatePvPSourceId = _dnl.createPvpSourceId

DeathNotificationLib.DecodePvPSource = _dnl.decodePvpSource

--#endregion