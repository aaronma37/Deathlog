--[[
DeathNotificationLib~Backwards.lua

Backwards compatibility layer for legacy (v0–v2) protocol messages.

Older clients use a different wire format and additional commands that were
removed in v3.  This file translates incoming legacy messages into the v3
pipeline so deaths reported by older clients are not silently dropped.

  v0 – original format: 10-field messages, no protocol_version field,
       no TARNISHED_SOUL command.
  v2 – same 10-field layout but appends protocol_version as field 11;
       added LAST_WORDS ("3") and TARNISHED_SOUL ("6") commands.

Handled legacy commands:
  "3" (LAST_WORDS)      – separate last-words message, merged into existing LRU cache entry (v2+)
  "6" (TARNISHED_SOUL)  – Soul of Iron death broadcast, re-routed through v3 reported-death pipeline (v2+)

Legacy BROADCAST_DEATH_PING ("1") messages are also handled: they have 10
fields instead of 13, with extra_data in field 10 and (in v2 only) the
protocol version appended as field 11.  This adapter decodes them, translates
to v3 PlayerData, and re-injects into _dnl.handleDeathBroadcast via a
v3-encoded message.

This module is receive-only: we never produce legacy messages.
--]]

local _dnl = DeathNotificationLib.Internal ---@class _dnl
if not _dnl then return end

local V2_COMM_COMMANDS = {
	["LAST_WORDS"] = "3",
	["TARNISHED_SOUL"] = "6",
}

local V2_QUALITY = {
	BASIC = 1,
	CONTEXT = 2,
	SELF = 3,
}

-- ============================================================================
-- V2 fletcher16: v2 hashed  name .. guild .. level  (no colons)
-- ============================================================================

---Replicate the v2 fletcher16 checksum so we can correlate v2 LAST_WORDS
---messages with LRU cache entries that were created by v2 BROADCAST_DEATH_PING.
---@param _player_data PlayerData
---@return string checksum
local function fletcher16V2(_player_data)
	local data = _player_data["name"] .. (_player_data["guild"] or "") .. (_player_data["level"] or "")
	local sum1 = 0
	local sum2 = 0
	for index = 1, #data do
		sum1 = (sum1 + string.byte(string.sub(data, index, index))) % 255
		sum2 = (sum2 + sum1) % 255
	end
	return _player_data["name"] .. "-" .. bit.bor(bit.lshift(sum2, 8), sum1)
end

-- ============================================================================
-- V2 extra_data decode (same encoding as v3, just in a different field position)
-- ============================================================================

--- Decode extra_data from the v2 wire format.
---
--- NOTE: This intentionally differs from the v3 decodeExtraData in
--- ~Protocol.lua.  The v2 encoder used a sequential gsub chain that
--- processes "\\" last, which means an input like "\\e" decodes as
--- "\" followed by "=" (because \e is replaced before \\\\ is).
--- The v3 encoder fixed this by replacing "\\\\" first (using a
--- sentinel character) so it correctly round-trips to a literal
--- backslash + "e".  We preserve the v2 behaviour here for
--- backwards compatibility with data encoded by older clients.
---@param str string|nil
---@return table|nil
local function decodeExtraData(str)
	if str == nil or str == "" then
		return nil
	end
	local result = {}
	for pair in str:gmatch("([^|]+)") do
		local key, val = pair:match("^(.-)=(.*)$")
		if key and val then
			key = key:gsub("\\e", "="):gsub("\\p", "|"):gsub("\\t", "~"):gsub("\\\\", "\\")
			val = val:gsub("\\e", "="):gsub("\\p", "|"):gsub("\\t", "~"):gsub("\\\\", "\\")
			result[key] = val
		end
	end
	if next(result) == nil then
		return nil
	end
	return result
end

-- ============================================================================
-- V2 message decoders
-- ============================================================================

---Decode a legacy BROADCAST_DEATH_PING message (9, 10, or 11 fields).
---
---Supported wire formats:
---  v0 (Hardcore addon): name~guild~source_id~race_id~class_id~level~instance_id~map_id~map_pos~  (9 fields)
---  v2 (legacy DNL):     name~guild~source_id~race_id~class_id~level~instance_id~map_id~map_pos~extra_data~  (10 fields)
---  v2 + version:        ...~extra_data~protocol_version~  (11 fields)
---@param msg string
---@return PlayerData|nil player_data
---@return number protocol_version
local function decodeV2Message(msg)
	local values = {}
	for w in msg:gmatch("(.-)~") do
		table.insert(values, w)
	end

	-- v0 (Hardcore addon) sends 9 fields, v2 sends 10 or 11
	if #values < 9 then
		return nil, 0
	end

	local name = values[1]
	local guild = values[2]
	local source_id = tonumber(values[3])
	local race_id = tonumber(values[4])
	local class_id = tonumber(values[5])
	local level = tonumber(values[6])
	local instance_id = tonumber(values[7])
	local map_id = tonumber(values[8])
	local map_pos = values[9]
	local extra_data = values[10] and decodeExtraData(values[10]) or nil
	local protocol_version = tonumber(values[11]) or 0

	if map_pos == "" then map_pos = nil end

	local player_data = _dnl.playerData(
		name, guild, source_id, race_id, class_id, level,
		instance_id, map_id, map_pos, nil, nil, nil, extra_data
	)
	return player_data, protocol_version
end

-- ============================================================================
-- Legacy BROADCAST_DEATH_PING adapter
-- ============================================================================

---Handle a v2-format BROADCAST_DEATH_PING ("1") that has fewer than 13 fields.
---Decodes the v2 10-field message, translates to v3 PlayerData, re-encodes as
---v3, and feeds into _dnl.handleDeathBroadcast so the entire v3 pipeline
---(LRU dedup, quality merge, commit timers) is reused.
---@param sender string
---@param data string
function _dnl.handleV2DeathBroadcast(sender, data)
	if data == nil then return end

	local player_data, protocol_version = decodeV2Message(data)
	if not player_data then
		if _dnl.DEBUG then
			print("|cff888888[Backwards]|r Failed to decode v2 death broadcast")
		end
		return
	end

	-- Fill in missing v3 fields
	player_data["date"] = player_data["date"] or GetServerTime()

	-- Merge orphan last_words stored by handleV2LastWords (Strategy 3)
	if not player_data["last_words"] or player_data["last_words"] == "" then
		local v2_cs = fletcher16V2(player_data)
		local cache = _dnl.death_ping_lru_cache_tbl
		if cache[v2_cs] and cache[v2_cs]["last_words"] then
			player_data["last_words"] = cache[v2_cs]["last_words"]
			cache[v2_cs]["last_words"] = nil
			if _dnl.DEBUG then
				print("|cff888888[Backwards]|r Merged orphan last_words for:", player_data["name"])
			end
		end
	end

	-- Re-encode as v3 and feed into the standard pipeline
	local v3_msg = _dnl.encodeMessage(player_data)
	if not v3_msg then
		if _dnl.DEBUG then
			print("|cff888888[Backwards]|r Failed to re-encode v2 death as v3 for:", player_data["name"])
		end
		return
	end

	if _dnl.DEBUG then
		print("|cff888888[Backwards]|r Translated v2 death broadcast for:", player_data["name"], "from:", sender)
	end

	_dnl.handleDeathBroadcast(sender, v3_msg)
end

-- ============================================================================
-- V2 LAST_WORDS handler
-- ============================================================================

---Handle a v2 LAST_WORDS ("3") message.
---Format: checksum~last_words~protocol_version~
---The checksum is a v2-format fletcher16 (no colons).  We try to find the
---matching LRU cache entry by:
---  1. Direct checksum lookup (works when the entry was also created from a v2 message)
---  2. Name-based lookup via _dnl.lru_by_name (works when the entry was created by v3)
---@param sender string
---@param data string|nil
local function handleV2LastWords(sender, data)
	if data == nil then return end

	local values = {}
	for w in data:gmatch("(.-)~") do
		table.insert(values, w)
	end

	local v2_checksum = values[1]
	local last_words = values[2]

	if not v2_checksum or not last_words or last_words == "" then
		return
	end

	if _dnl.DEBUG then
		print("|cff888888[Backwards]|r Received v2 LAST_WORDS from:", sender, "checksum:", v2_checksum)
	end

	-- Extract player name from the v2 checksum (format: "Name-<number>")
	local player_name = v2_checksum:match("^(.+)%-")

	-- Strategy 1: direct v2 checksum lookup
	local cache = _dnl.death_ping_lru_cache_tbl
	if cache[v2_checksum] then
		if cache[v2_checksum]["player_data"] then
			cache[v2_checksum]["player_data"]["last_words"] = last_words
		else
			cache[v2_checksum]["last_words"] = last_words
		end
		if _dnl.DEBUG then
			print("|cff888888[Backwards]|r Patched last_words via v2 checksum match")
		end
		return
	end

	-- Strategy 2: name-based lookup (v3 checksum differs from v2)
	if player_name then
		local name_lower = player_name:lower()
		local name_entry = _dnl.lru_by_name[name_lower]
		if name_entry and name_entry.checksum then
			local v3_entry = cache[name_entry.checksum]
			if v3_entry then
				if v3_entry["player_data"] then
					if not v3_entry["player_data"]["last_words"] or v3_entry["player_data"]["last_words"] == "" then
						v3_entry["player_data"]["last_words"] = last_words
						if _dnl.DEBUG then
							print("|cff888888[Backwards]|r Patched last_words via name lookup:", player_name)
						end
					end
				end
				return
			end
		end
	end

	-- Strategy 3: no cache entry yet — store under v2 checksum so if the death
	-- broadcast arrives later, it can be merged
	cache[v2_checksum] = cache[v2_checksum] or {}
	cache[v2_checksum]["last_words"] = last_words

	if _dnl.DEBUG then
		print("|cff888888[Backwards]|r Stored orphan last_words under v2 checksum:", v2_checksum)
	end
end

-- ============================================================================
-- V2 TARNISHED_SOUL handler
-- ============================================================================

---Handle a v2 TARNISHED_SOUL ("6") message.
---Format: name~guild~source_id~race_id~class_id~level~instance_id~map_id~map_pos~extra_data~quality~protocol_version~
---This is the v2 10-field message with two extra fields appended (quality and protocol_version).
---We translate this into a v3 reported-death broadcast (source_id == -1).
---@param sender string
---@param data string|nil
local function handleV2TarnishedSoul(sender, data)
	if data == nil then return end

	local values = {}
	for w in data:gmatch("(.-)~") do
		table.insert(values, w)
	end

	if #values < 10 then
		if _dnl.DEBUG then
			print("|cff888888[Backwards]|r Tarnished soul message too short, values:", #values)
		end
		return
	end

	local name = values[1]
	local guild = values[2]
	-- values[3] is source_id, but for tarnished soul it was always -1 in v2
	local race_id = tonumber(values[4])
	local class_id = tonumber(values[5])
	local level = tonumber(values[6])
	local instance_id = values[7] ~= "" and tonumber(values[7]) or nil
	local map_id = values[8] ~= "" and tonumber(values[8]) or nil
	local map_pos_str = values[9]
	-- values[10] is extra_data in v2 format
	local v2_quality = tonumber(values[11]) or V2_QUALITY.BASIC
	-- values[12] is protocol_version

	if not name or name == "" then
		return
	end

	local map_pos = nil
	if map_pos_str and map_pos_str ~= "" then
		map_pos = map_pos_str
	end

	local is_self = (v2_quality == V2_QUALITY.SELF)

	-- Respect peer_reporting setting for non-self reports
	if not is_self and not _dnl.anyAddonAllows("peer_reporting") then
		if _dnl.DEBUG then
			print("|cff888888[Backwards]|r Peer-reported tarnished soul ignored (all addons disabled peer_reporting):", name)
		end
		return
	end

	-- Check name dedup
	if _dnl.isNameAlreadyCommitted(name, level) then
		if _dnl.DEBUG then
			print("|cff888888[Backwards]|r Tarnished soul already committed:", name)
		end
		return
	end

	local effective_level = (level and level > 0) and level or 0

	if _dnl.DEBUG then
		print("|cff888888[Backwards]|r Received v2 TARNISHED_SOUL from:", sender, "for:", name,
			"level:", effective_level, "quality:", v2_quality)
	end

	-- Build a v3 reported-death PlayerData (source_id == -1) and feed into the
	-- v3 pipeline via a v3-encoded message through handleDeathBroadcast
	local player_data = _dnl.playerData(
		name, guild or "", -1, race_id, class_id, effective_level,
		instance_id, map_id, map_pos, GetServerTime(), nil, nil
	)

	local v3_msg = _dnl.encodeMessage(player_data)
	if not v3_msg then
		if _dnl.DEBUG then
			print("|cff888888[Backwards]|r Failed to re-encode v2 tarnished soul as v3 for:", name)
		end
		return
	end

	-- When the v2 message was a self-report, use the dead player's name as sender
	-- so the v3 pipeline recognises it as a self-report
	local effective_sender = is_self and name or sender
	_dnl.handleDeathBroadcast(effective_sender, v3_msg)
end

-- ============================================================================
-- Dispatch table: maps legacy-only command codes to their handlers
-- ============================================================================

---@type table<string, fun(sender: string, data: string|nil)>
_dnl.backwards_dispatch = {
	[V2_COMM_COMMANDS["LAST_WORDS"]]     = handleV2LastWords,
	[V2_COMM_COMMANDS["TARNISHED_SOUL"]] = handleV2TarnishedSoul,
}

-- ============================================================================
-- Expose helpers for testing
-- ============================================================================

if _dnl.DEBUG then
	_dnl._backwards = {
		fletcher16V2 = fletcher16V2,
		decodeV2Message = decodeV2Message,
		V2_COMM_COMMANDS = V2_COMM_COMMANDS,
		V2_QUALITY = V2_QUALITY,
	}
end
