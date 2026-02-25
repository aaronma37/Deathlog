--[[
DeathNotificationLib~Broadcast.lua

Outbound death broadcasting and source resolution.

Constructs PlayerData payloads for deaths detected locally (self, party,
raid, or manually reported) and queues them for transmission.  Resolves
the death source string into a numeric source_id by trying, in order:
  1. NPC name lookup (via INSTANCE_TO_ID / NPC_TO_ID)
  2. Environment damage type (Drowning, Falling, etc.)
  3. PvP encoding (bit-packed attacker race/class/level/flag)

Location is determined per-unit: instance_id from GetInstanceInfo() for
the player, or from C_Map data for party/raid members, with a fallback
to the player's own location when the unit can't be resolved.

Key entry points:
  broadcastDeath(player_data)     – deduplicate, encode, queue for send
  reportPartyRaidDeath(unit)      – auto-report a group member's death
  broadcastReportedDeath(...)    – manual reported-death broadcast
--]]

local _dnl = DeathNotificationLib.Internal ---@class _dnl
if not _dnl then return end

---@param unit UnitToken
---@return number|nil instance_id
local function getInstanceIdForUnit(unit)
	if UnitIsUnit(unit, "player") then
		local _, _, _, _, _, _, _, instance_id, _, _ = GetInstanceInfo()
		return instance_id
	elseif _dnl.isUnitInPartyOrRaid(unit) then
		local uname = UnitName(unit)
		for i = 1, GetNumGroupMembers() do
			local memb_name, _, _, _, _, _, memb_zone = GetRaidRosterInfo(i)
			if memb_name == uname then
				if _dnl.D.INSTANCE_TO_ID then
					for _, instances in pairs(_dnl.D.INSTANCE_TO_ID) do
						for inst_name, inst_id in pairs(instances) do
							if memb_zone == inst_name then
								return inst_id
							end
						end
					end
				end

				break
			end
		end
	end

	return nil
end

---@param unit UnitToken
---@return number|nil instance_id
---@return number|nil map_id
---@return table|nil position
function _dnl.guessLocationForUnit(unit)
	local map = C_Map.GetBestMapForUnit(unit)
	local instance_id = nil
	local position = nil
	if map then
		if _dnl.D.ZONE_TO_INSTANCE[map] then
			instance_id = _dnl.D.ZONE_TO_INSTANCE[map]
		else
			position = C_Map.GetPlayerMapPosition(map, unit)
		end
	else
		instance_id = getInstanceIdForUnit(unit)
	end

	if not map and not instance_id and not UnitIsUnit(unit, "player") then
		if _dnl.DEBUG then
			print("Failed to get map for unit:", unit, "defaulting to player location")
		end
		return _dnl.guessLocationForUnit("player")
	end

	return instance_id, map, position
end


---Resolve a death source name (NPC, environment, or PvP player) to a numeric source_id.
---Returns source_id (-1 if unresolved) and optional extra_data (e.g. pvp_source_name).
---@param death_source_name string|nil          NPC name, env damage name, or player name
---@param death_source_guid string|nil          Source GUID (improves PvP/NPC resolution)
---@param try_all_locales boolean|nil           When true, iterate every loaded locale's NPC_TO_ID as a last resort (for cross-locale names from HardcoreTBC / UltraHardcore)
---@return number death_source
---@return table|nil extra_data
function _dnl.resolveDeathSource(death_source_name, death_source_guid, try_all_locales)
	local death_source = -1
	local extra_data = nil

	if death_source_name then
		if _dnl.D.NPC_TO_ID[death_source_name] then
			death_source = _dnl.D.NPC_TO_ID[death_source_name]
		elseif _dnl.ENVIRONMENT_DAMAGE_TO_ID[death_source_name] then
			death_source = _dnl.ENVIRONMENT_DAMAGE_TO_ID[death_source_name]
		else
			local success, pvp_source, pvp_source_name = _dnl.encodePvpSource(death_source_name, death_source_guid)
			if success then
				death_source = pvp_source
				if pvp_source_name then
					extra_data = { ["pvp_source_name"] = pvp_source_name }
				end
			end
		end
	end

	if death_source == -1 and death_source_guid then
		local unit_type = strsplit("-", death_source_guid)
		if unit_type == "Creature" or unit_type == "Vehicle" then
			local _, _, _, _, _, npc_id, _ = strsplit("-", death_source_guid)
			death_source = tonumber(npc_id) or death_source
		elseif unit_type == "Player" then
			local success, pvp_source, pvp_source_name = _dnl.encodePvpSource(death_source_name, death_source_guid)
			if success then
				death_source = pvp_source
				if pvp_source_name then
					extra_data = { ["pvp_source_name"] = pvp_source_name }
				end
			end
		end
	end

	-- Worst-case fallback: iterate ALL locale NPC tables.
	-- This handles cross-locale NPC names from HardcoreTBC / UltraHardcore,
	-- which send the dying player's localized NPC name without a GUID.
	-- Intentionally last and opt-in: only runs when the caller requests it
	-- and every faster path above has failed.
	if death_source == -1 and death_source_name and try_all_locales then
		for _, localeData in pairs(_dnl.L) do
			if localeData.NPC_TO_ID and localeData.NPC_TO_ID[death_source_name] then
				death_source = localeData.NPC_TO_ID[death_source_name]
				break
			end
		end
	end

	if death_source == -1 then
		if _dnl.DEBUG then
			print("Failed to resolve death source for:", death_source_name or "nil", death_source_guid or "nil")
		end
	end

	return death_source, extra_data
end

---------------------------------------------------------------------------
-- Shared GUID / roster helpers (used by HardcoreTBC + UltraHardcore adapters)
---------------------------------------------------------------------------

---Attempt to resolve class/race/guild from the guild roster.
---@param name string  Character name (no realm suffix)
---@return number|nil class_id
---@return number|nil race_id
---@return string|nil guild
function _dnl.enrichFromRoster(name)
	local guildName = GetGuildInfo("player")
	if not guildName then return nil, nil, nil end
	local name_long = name .. "-" .. GetNormalizedRealmName()
	for i = 1, GetNumGuildMembers() do
		local memberName, _, _, _, _, _, _, _, _, _, classFileName = GetGuildRosterInfo(i)
		if memberName == name_long then
			local class_id = classFileName and _dnl.D.CLASS_FILE_TO_ID[classFileName] or nil
			return class_id, nil, guildName
		end
	end
	return nil, nil, nil
end

---Try to get race and class from a player GUID.
---@param guid string|nil
---@return number|nil race_id
---@return number|nil class_id
function _dnl.raceClassFromGUID(guid)
	if not guid then return nil, nil end
	local ok, englishClass, _, englishRace = pcall(GetPlayerInfoByGUID, guid)
	if not ok then return nil, nil end
	local class_id = englishClass and _dnl.D.CLASS_FILE_TO_ID[englishClass] or nil
	local race_id = englishRace and _dnl.D.RACE_FILE_TO_ID[englishRace] or nil
	return race_id, class_id
end

---Unified death broadcast: single function for all death types
---Pre-populates the LRU cache (outbound dedup) and queues for sending
---@param player_data PlayerData
function _dnl.broadcastDeath(player_data)
	if not player_data or not player_data["name"] then return end

	local death_ping_lru_cache_tbl = _dnl.death_ping_lru_cache_tbl

	-- Name-based outbound dedup: if we already have ANY entry (under any
	-- checksum) for this player within the dedup window, skip the broadcast.
	-- This prevents multiple party members' slightly-different payloads
	-- (different guild, source, map_pos, last_words) from each generating
	-- a separate broadcast for the same death.
	local name_lower = player_data["name"]:lower()
	local name_entry = _dnl.lru_by_name[name_lower]
	if name_entry and name_entry.timestamp then
		local effective_level = math.max(tonumber(player_data["level"]) or 0, tonumber(name_entry.level) or 0)
		if math.abs(GetServerTime() - name_entry.timestamp) <= _dnl.getDedupWindow(effective_level) then
			if _dnl.DEBUG then
				print("Outbound name-dedup: skipping broadcast for", player_data["name"], "- name already in LRU")
			end
			-- Still merge our data into the existing entry if ours is better
			local existing_cs = name_entry.checksum
			if existing_cs and death_ping_lru_cache_tbl[existing_cs] and death_ping_lru_cache_tbl[existing_cs]["player_data"] then
				local existing_quality = death_ping_lru_cache_tbl[existing_cs]["quality"] or _dnl.QUALITY.PEER
				local is_self = (UnitName("player") == player_data["name"])
				local our_quality = is_self and _dnl.QUALITY.SELF or _dnl.QUALITY.PEER
				_dnl.mergeLRUEntry(death_ping_lru_cache_tbl[existing_cs]["player_data"], player_data, our_quality, existing_quality)
			end
			return
		end
	end

	local checksum = _dnl.fletcher16(player_data)
	if death_ping_lru_cache_tbl[checksum] and death_ping_lru_cache_tbl[checksum]["player_data"] then
		local existing_time = death_ping_lru_cache_tbl[checksum]["timestamp"] or 0
		if math.abs(GetServerTime() - existing_time) <= _dnl.getDedupWindow(player_data["level"]) then
			if _dnl.DEBUG then
				print("Outbound dedup: skipping broadcast for", player_data["name"], "- already in LRU cache")
			end
			return
		end
	end

	if not death_ping_lru_cache_tbl[checksum] then
		death_ping_lru_cache_tbl[checksum] = {}
	end
	death_ping_lru_cache_tbl[checksum]["player_data"] = player_data
	death_ping_lru_cache_tbl[checksum]["timestamp"] = GetServerTime()
	death_ping_lru_cache_tbl[checksum]["quality"] = _dnl.QUALITY and _dnl.QUALITY.SELF or nil
	death_ping_lru_cache_tbl[checksum]["source"] = SOURCE.SELF_DEATH

	_dnl.updateLRUByName(name_lower, checksum, nil, player_data["level"])

	local msg = _dnl.encodeMessage(player_data)
	if msg == nil then
		return
	end
	table.insert(_dnl.death_alert_out_queue, {msg, GetServerTime()})
end

---Public API: broadcast a reported death.
---Called by ReportWidget and external addons.
---@param name string
---@param guild string|nil
---@param source_id number|string|nil
---@param race_id number|nil
---@param class_id number|nil
---@param level number|nil
---@param instance_id number|nil
---@param map_id number|nil
---@param map_pos string|table|nil
---@param date number|nil
---@param played number|nil
---@param last_words string|nil
---@param extra_data table|nil
---@return boolean success
---@return string|nil error_message
function _dnl.broadcastReportedDeath(name, guild, source_id, race_id, class_id, level, instance_id, map_id, map_pos, date, played, last_words, extra_data)
	local _player_data = _dnl.playerData(
		name, guild, source_id, race_id, class_id, level, instance_id, map_id, map_pos, date, played, last_words, extra_data
	)

	local ok, err = _dnl.validatePlayerData(_player_data)
	if not ok then
		return false, err
	end

	local msg = _dnl.encodeMessage(_player_data)
	if msg == nil then
		return false, "encodeMessage failed"
	end

	if #msg + 2 > 255 then
		return false, "encoded message exceeds 255 bytes"
	end

	if _dnl.DEBUG then
		print("Broadcasting reported death for:", name, "guild:", guild or "nil", "source_id:", source_id or "nil", "race_id:", race_id or "nil", "class_id:", class_id or "nil", "level:", level or "nil", "instance_id:", instance_id or "nil", "map_id:", map_id or "nil")
	end

	_dnl.broadcastDeath(_player_data)
	return true, nil
end

---Auto-report death of a party/raid member
---Outbound dedup is handled by broadcastDeath's LRU cache check
---@param unit UnitToken|nil
function _dnl.reportPartyRaidDeath(unit)
	if not unit then return end

	local player_name = UnitName(unit)
	local player_guid = UnitGUID(unit)
	if not player_name or not player_guid then return end

	local _, _, race_id = UnitRace(unit)
	local _, _, class_id = UnitClass(unit)
	local level = UnitLevel(unit)
	local guild = GetGuildInfo(unit)

	if not race_id or not class_id or not level or level <= 0 then
		if _dnl.DEBUG then
			print("Party/raid death missing required data:", player_name, "race:", race_id, "class:", class_id, "level:", level)
		end
		return
	end

	local unitState = _dnl.getUnitState(unit)
	local death_source, extra_data = _dnl.resolveDeathSource(unitState.last_attack_source_name, unitState.last_attack_source_guid)

	local instance_id, map, position = _dnl.guessLocationForUnit(unit)

	local last_words = unitState.recent_msg

	local player_data = _dnl.playerData(
		player_name,
		guild,
		death_source,
		race_id,
		class_id,
		level,
		instance_id,
		map,
		position,
		GetServerTime(),
		nil,
		last_words,
		extra_data
	)

	if _dnl.DEBUG then
		print("Auto-reporting party/raid member death:", player_name, "level:", level, "source:", unitState.last_attack_source_name or "unknown")
	end

	_dnl.broadcastDeath(player_data)
end

--#region API

DeathNotificationLib.BroadcastReportedDeath = _dnl.broadcastReportedDeath

DeathNotificationLib.ResolveDeathSource = _dnl.resolveDeathSource

--#endregion