--[[
DeathNotificationLib~Protocol.lua

Wire protocol, data structures, and checksums.

Defines the V3 serialization format for death notifications: a 14-field
tilde-delimited string carrying the full PlayerData payload.  Provides
encode/decode functions, entry validation, and the Fletcher-16 checksum
used for deduplication and peer corroboration.

  V3 wire format (fields separated by "~"):
    name, guild, source_id, race_id, class_id, level, instance_id,
    map_id, map_pos, played, last_words, date, extra_data, protocol_version

  Extra data: key=value pairs separated by "|", with backslash escaping
  for ~, |, =, and \ itself.

  Fletcher-16: computed over "name:guild:level" (level zeroed for
  reported deaths where source_id == -1), producing "Name-NNNN".

Key constants:
  PROTOCOL_VERSION = 3
  COMM_NAME = "HCDeathAlerts"  (addon message prefix)
  COMM_COMMANDS: BROADCAST_DEATH_PING "1", CHECKSUM "2", DUEL "5"
  QUALITY: BLIZZARD (1) < PEER (2) < SELF (3)
  ENVIRONMENT_DAMAGE: negative IDs for Drowning/Falling/Fatigue/Fire/Lava/Slime
--]]

local _dnl = DeathNotificationLib.Internal ---@class _dnl
if not _dnl then return end

--- Entry-origin constants passed as the `source` parameter to hooks.
---@enum DNL_Source
_dnl.SOURCE = {
	SELF_DEATH       = "self_death",       -- Dead player reported their own death
	PEER_BROADCAST   = "peer_broadcast",   -- Another addon user broadcast the death
	BLIZZARD         = "blizzard",         -- Blizzard HARDCORE_DEATHS channel
	SYNC             = "sync",             -- Background database sync
	HARDCORE_TBC_SYNC = "hardcore_tbc_sync", -- Imported from HardcoreTBC addon
	QUERY            = "query",            -- Response to a targeted player query
	DEBUG            = "debug",            -- Injected via debug / LOCAL_DEBUG_ONLY path
	UNKNOWN          = "unknown",          -- Fallback when source is nil
}

---@class PlayerData
---@field name string
---@field guild string
---@field source_id number
---@field race_id number
---@field class_id number
---@field level number
---@field instance_id number
---@field map_id number
---@field map_pos string
---@field date number
---@field played number
---@field last_words string
---@field extra_data table

_dnl.PROTOCOL_VERSION = 3
_dnl.MIN_SUPPORTED_PROTOCOL_VERSION = 0
_dnl.COMM_NAME = "HCDeathAlerts"
_dnl.COMM_COMMANDS = {
	["BROADCAST_DEATH_PING"] = "1",
	["BROADCAST_DEATH_PING_CHECKSUM"] = "2",
	["REQUEST_DUEL_TO_DEATH"] = "5",
}
_dnl.COMM_QUERY = "Q"
_dnl.COMM_QUERY_ACK = "R"
_dnl.COMM_COMMAND_DELIM = "$"
_dnl.COMM_FIELD_DELIM = "~"

---Universal quality tiers for death reports
---These apply to ALL death sources uniformly
_dnl.QUALITY = {
	BLIZZARD = 1, --- Blizzard HC channel: has name, level, source, area; missing guild, race, class, pos, last_words
	PEER = 2,     --- Reported by another player: has most fields but position/source may be approximate
	SELF = 3,     --- Self-reported: the dying player knows best
}

_dnl.ENVIRONMENT_DAMAGE = {
	[-2] = "Drowning",
	[-3] = "Falling",
	[-4] = "Fatigue",
	[-5] = "Fire",
	[-6] = "Lava",
	[-7] = "Slime",
}

_dnl.ENVIRONMENT_DAMAGE_TO_ID = {}
for id, name in pairs(_dnl.ENVIRONMENT_DAMAGE) do
	_dnl.ENVIRONMENT_DAMAGE_TO_ID[name] = id
end

--- Maximum total wire-message length (Blizzard limit for both
--- SendChatMessage and SendAddonMessage payloads).
local WIRE_MAX = 255

--- Bytes consumed by the command prefix added by every caller
--- of encodeMessage (e.g. "1$", "R$", "E$").
local COMMAND_PREFIX_LEN = 2

--- Escape a string for safe embedding in the ~-delimited wire format.
--- Uses % as the escape character (backslash is rejected by WoW's
--- SendChatMessage as "Invalid escape code").
--- Protects against ~ (field delimiter), | (sync entry / extra_data
--- separator), \ (WoW chat escape), ; (sync entry separator), and
--- % (escape character itself) appearing in user content.
---@param s string
---@return string
local function escapeField(s)
	if s == nil or s == "" then return "" end
	return s:gsub("%%", "%%%%")
	        :gsub("\\", "%%b")
	        :gsub("~", "%%t")
	        :gsub("|", "%%p")
	        :gsub(";", "%%s")
end

--- Reverse escapeField.
---@param s string
---@return string
local function unescapeField(s)
	if s == nil or s == "" then return "" end
	return s:gsub("%%%%", "\1")
	        :gsub("%%s", ";")
	        :gsub("%%b", "\\")
	        :gsub("%%p", "|")
	        :gsub("%%t", "~")
	        :gsub("\1", "%%")
end

--- Truncate an already-escaped string to at most `max_bytes` bytes
--- without cutting inside a two-character escape sequence (%t %p %%).
---@param escaped string
---@param max_bytes number
---@return string
local function truncateEscaped(escaped, max_bytes)
	if #escaped <= max_bytes then return escaped end
	local cut = escaped:sub(1, max_bytes)
	-- If the last character is % it may be the start of an
	-- escape pair whose second character we just cut off — remove it.
	if cut:byte(max_bytes) == 0x25 then -- 0x25 == %
		cut = cut:sub(1, max_bytes - 1)
	end
	return cut
end

---------------------------------------------------------------------------
-- Extra data escaping (inner layer)
--
-- The wire format uses two independent escape layers:
--
--   Inner (this layer):  backslash-based (\\ \t \p \e)
--     Protects extra_data's own key=value delimiters (= and |) and the
--     characters that the outer layer reserves (~ and \).
--     Applied by encodeExtraData(), reversed by decodeExtraData().
--
--   Outer (escapeField/unescapeField above):  percent-based (%% %t %p %b %s)
--     Protects wire-level field separator (~), WoW UI-escape (|),
--     backslash (\, which WoW chat may strip), and sync entry separator (;).
--     Applied per-field inside encodeMessage(), reversed in decodeMessage().
--
-- Encoding order:  encodeExtraData(extra_data)  →  escapeField(result)
-- Decoding order:  unescapeField(wire_field)    →  decodeExtraData(result)
---------------------------------------------------------------------------

---@param extra_data table|nil
---@return string
local function encodeExtraData(extra_data)
	if extra_data == nil or type(extra_data) ~= "table" then
		return ""
	end
	local parts = {}
	for k, v in pairs(extra_data) do
		if type(k) == "string" and (type(v) == "string" or type(v) == "number" or type(v) == "boolean") then
			local key = tostring(k):gsub("\\", "\\\\"):gsub("~", "\\t"):gsub("|", "\\p"):gsub("=", "\\e")
			local val = tostring(v):gsub("\\", "\\\\"):gsub("~", "\\t"):gsub("|", "\\p"):gsub("=", "\\e")
			table.insert(parts, key .. "=" .. val)
		end
	end
	return table.concat(parts, "|")
end

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
			key = key:gsub("\\\\", "\1"):gsub("\\e", "="):gsub("\\p", "|"):gsub("\\t", "~"):gsub("\1", "\\")
			val = val:gsub("\\\\", "\1"):gsub("\\e", "="):gsub("\\p", "|"):gsub("\\t", "~"):gsub("\1", "\\")
			result[key] = val
		end
	end
	if next(result) == nil then
		return nil
	end
	return result
end

---Construct a PlayerData table from individual fields.
---Parameter order: name, guild, source_id, race_id, class_id, level,
---instance_id, map_id, map_pos, date, played, last_words, extra_data.
---@param name string
---@param guild string|nil
---@param source_id number|string
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
---@return PlayerData
function _dnl.playerData(
	name,
	guild,
	source_id,
	race_id,
	class_id,
	level,
	instance_id,
	map_id,
	map_pos,
	date,
	played,
	last_words,
	extra_data
)
	return {
		["name"] = name,
		["guild"] = guild,
		["source_id"] = source_id,
		["race_id"] = race_id,
		["class_id"] = class_id,
		["level"] = level,
		["instance_id"] = instance_id,
		["map_id"] = map_id,
		["map_pos"] = map_pos,
		["date"] = date,
		["played"] = played,
		["last_words"] = last_words,
		["extra_data"] = extra_data,
	}
end

---Relaxed validation: allows entries with missing race/class (blizzard channel)
---and level=0 (reported deaths with unknown level)
---Required: source_id (non-nil), name (non-nil), at least one of instance_id/map_id
---@param _player_data PlayerData
---@return boolean
function _dnl.isValidEntry(_player_data)
	if _player_data == nil then
		return false
	end
	if _player_data["name"] == nil or _player_data["name"] == "" then
		return false
	end
	if _player_data["source_id"] == nil then
		return false
	end
	if _player_data["level"] == nil then
		return false
	end
	if _player_data["instance_id"] == nil and _player_data["map_id"] == nil then
		return false
	end
	return true
end

---Validate a PlayerData table against WoW constraints.
---Checks every field for type correctness, range limits, and semantic validity
---(e.g. source_id must be a known NPC / env-damage / PvP encoding,
---race_id / class_id must resolve via C_CreatureInfo, etc.).
---
---This is a general-purpose validator usable anywhere a PlayerData object
---needs to be sanity-checked.
---
---@param pd PlayerData
---@return boolean success
---@return string|nil error_message  Human-readable reason on failure
function _dnl.validatePlayerData(pd)
	if type(pd) ~= "table" then
		return false, "playerData must be a table"
	end

	-- ── name (required, 2-12 chars) ──────────────────────────────────
	local name = pd["name"]
	if type(name) ~= "string" or name == "" then
		return false, "name must be a non-empty string"
	end
	if #name < 2 or #name > 12 then
		return false, "name must be 2-12 characters (got " .. #name .. ")"
	end
	if name:find("[~|$\\;%%]") then
		return false, "name contains wire-unsafe characters"
	end

	-- ── guild (max 24 chars) ─────────────────────────────────────────
	local guild = pd["guild"]
	if guild ~= nil and guild ~= "" then
		if type(guild) ~= "string" then
			return false, "guild must be a string or nil"
		end
		if #guild > 24 then
			return false, "guild must be at most 24 characters (got " .. #guild .. ")"
		end
		if guild:find("[~|$\\;%%]") then
			return false, "guild contains wire-unsafe characters"
		end
	end

	-- ── source_id (required) ─────────────────────────────────────────
	local source_id = pd["source_id"]
	if source_id == nil then
		return false, "source_id is required"
	end
	if type(source_id) ~= "number" then
		return false, "source_id must be numeric"
	end
	if source_id ~= -1
		and not _dnl.D.ID_TO_NPC[source_id]
		and not _dnl.ENVIRONMENT_DAMAGE[source_id]
		and not _dnl.isValidPvpSourceId(source_id)
	then
		return false, "source_id " .. tostring(source_id) .. " is not a known NPC, environment type, or valid PvP source"
	end

	-- ── race_id (C_CreatureInfo.GetRaceInfo must resolve) ────────────
	local race_id = pd["race_id"]
	if race_id ~= nil then
		if type(race_id) ~= "number" then
			return false, "race_id must be numeric or nil"
		end
		if C_CreatureInfo and C_CreatureInfo.GetRaceInfo and not C_CreatureInfo.GetRaceInfo(race_id) then
			return false, "race_id " .. tostring(race_id) .. " is not a valid race (C_CreatureInfo.GetRaceInfo returned nil)"
		end
	end

	-- ── class_id (C_CreatureInfo.GetClassInfo must resolve) ──────────
	local class_id = pd["class_id"]
	if class_id ~= nil then
		if type(class_id) ~= "number" then
			return false, "class_id must be numeric or nil"
		end
		if C_CreatureInfo and C_CreatureInfo.GetClassInfo and not C_CreatureInfo.GetClassInfo(class_id) then
			return false, "class_id " .. tostring(class_id) .. " is not a valid class (C_CreatureInfo.GetClassInfo returned nil)"
		end
	end

	-- ── level (required, 0-80) ───────────────────────────────────────
	local level = pd["level"]
	if level == nil then
		return false, "level is required"
	end
	if type(level) ~= "number" then
		return false, "level must be numeric"
	end
	if level < 0 or level > _dnl.MAX_PLAYER_LEVEL then
		return false, "level must be 0-" .. tostring(_dnl.MAX_PLAYER_LEVEL) .. " (got " .. tostring(level) .. ")"
	end

	-- ── instance_id / map_id (at least one required) ─────────────────
	local instance_id = pd["instance_id"]
	local map_id = pd["map_id"]
	if instance_id ~= nil and (type(instance_id) ~= "number" or instance_id < 0) then
		return false, "instance_id must be a non-negative number or nil"
	end
	if map_id ~= nil and (type(map_id) ~= "number" or map_id < 0) then
		return false, "map_id must be a non-negative number or nil"
	end
	if instance_id == nil and map_id == nil then
		return false, "at least one of instance_id or map_id must be provided"
	end

	-- ── map_pos ──────────────────────────────────────────────────────
	local map_pos = pd["map_pos"]
	if map_pos ~= nil then
		if type(map_pos) == "table" then
			local x, y = tonumber(map_pos.x), tonumber(map_pos.y)
			if not x or not y or x < 0 or x > 1 or y < 0 or y > 1 then
				return false, "map_pos table must have x,y fields in range 0-1"
			end
		elseif type(map_pos) == "string" then
			local xs, ys = map_pos:match("^([%d%.]+),([%d%.]+)$")
			local x, y = tonumber(xs), tonumber(ys)
			if not x or not y or x < 0 or x > 1 or y < 0 or y > 1 then
				return false, "map_pos string must be \"x,y\" with values in range 0-1"
			end
		else
			return false, "map_pos must be a \"x,y\" string, {x=,y=} table, or nil"
		end
	end

	-- ── date ─────────────────────────────────────────────────────────
	local date = pd["date"]
	if date ~= nil then
		if type(date) ~= "number" then
			return false, "date must be numeric or nil"
		end
		if date < 1072915200 then
			return false, "date timestamp is before 2004"
		end
		if date > time() + 60 then
			return false, "date timestamp is more than 60 seconds in the future"
		end
	end

	-- ── played ───────────────────────────────────────────────────────
	local played = pd["played"]
	if played ~= nil then
		if type(played) ~= "number" or played < 0 then
			return false, "played must be a non-negative number or nil"
		end
	end

	-- ── last_words ───────────────────────────────────────────────────
	local last_words = pd["last_words"]
	if last_words ~= nil then
		if type(last_words) ~= "string" then
			return false, "last_words must be a string or nil"
		end
		if #last_words > 255 then
			return false, "last_words must be at most 255 characters"
		end
	end

	-- ── extra_data ───────────────────────────────────────────────────
	local extra_data = pd["extra_data"]
	if extra_data ~= nil and type(extra_data) ~= "table" then
		return false, "extra_data must be a table or nil"
	end

	return true, nil
end

---Calculate entry quality by counting populated fields.
---Higher means more complete data.
---@param entry PlayerData
---@return number
function _dnl.entryQuality(entry)
	local count = 0
	if entry["guild"] and entry["guild"] ~= "" then count = count + 1 end
	if entry["race_id"] then count = count + 1 end
	if entry["class_id"] then count = count + 1 end
	if entry["source_id"] and entry["source_id"] ~= -1 then count = count + 1 end
	if entry["map_id"] then count = count + 1 end
	if entry["map_pos"] then count = count + 1 end
	if entry["instance_id"] then count = count + 1 end
	if entry["played"] and entry["played"] > 0 then count = count + 1 end
	if entry["last_words"] and entry["last_words"] ~= "" then count = count + 1 end
	return count
end

---Merge two PlayerData entries, preferring non-nil/non-empty values from entry_a.
---Returns a new merged table.
---@param entry_a PlayerData  preferred entry
---@param entry_b PlayerData  fallback entry
---@return PlayerData
function _dnl.mergeEntries(entry_a, entry_b)
	local merged = {}
	local fields = {"name", "guild", "source_id", "race_id", "class_id", "level",
		"instance_id", "map_id", "map_pos", "played", "last_words", "date", "extra_data", "predicted_source"}
	for _, field in ipairs(fields) do
		local val_a = entry_a[field]
		local val_b = entry_b[field]
		if field == "source_id" then
			if val_a and val_a ~= -1 then
				merged[field] = val_a
			elseif val_b and val_b ~= -1 then
				merged[field] = val_b
			else
				merged[field] = val_a or val_b
			end
		elseif field == "guild" or field == "last_words" or field == "map_pos" then
			if val_a and val_a ~= "" then
				merged[field] = val_a
			elseif val_b and val_b ~= "" then
				merged[field] = val_b
			else
				merged[field] = val_a or val_b
			end
		else
			merged[field] = val_a or val_b
		end
	end
	return merged
end

---V3 unified encoder: encodes a PlayerData table into a wire-format string
---Wire format: name~guild~source_id~race_id~class_id~level~instance_id~map_id~map_pos~played~last_words~date~extra_data~protocol_version~
---@param player_data PlayerData
---@param extra_overhead number|nil  Additional bytes reserved beyond the 2-byte command prefix (e.g. 4 for "TAG~")
---@return string|nil
function _dnl.encodeMessage(player_data, extra_overhead)
	local name = player_data["name"]
	local guild = player_data["guild"]
	local source_id = player_data["source_id"]
	local race_id = player_data["race_id"]
	local class_id = player_data["class_id"]
	local level = player_data["level"]
	local instance_id = player_data["instance_id"]
	local map_id = player_data["map_id"]
	local map_pos = player_data["map_pos"]
	local played = player_data["played"]
	local last_words = player_data["last_words"]
	local date = player_data["date"] or time()
	local extra_data = player_data["extra_data"]

	if name == nil then
		return
	end
	if tonumber(source_id) == nil then
		return
	end

	local loc_str = ""
	if map_pos then
		if type(map_pos) == "table" and map_pos.x and map_pos.y then
			loc_str = string.format("%.4f,%.4f", map_pos.x, map_pos.y)
		elseif type(map_pos) == "string" then
			loc_str = map_pos
		end
	end

	-- Build the message WITHOUT last_words first so we can compute
	-- how many bytes remain for the (escaped) last_words field.
	local D = _dnl.COMM_FIELD_DELIM
	local escaped_extra = escapeField(encodeExtraData(extra_data))

	local base = escapeField(name)
		.. D .. escapeField(guild or "")
		.. D .. string.format("%.0f", source_id)
		.. D .. (race_id or "")
		.. D .. (class_id or "")
		.. D .. (level or 0)
		.. D .. (instance_id or "")
		.. D .. (map_id or "")
		.. D .. loc_str
		.. D .. (played or "")
		.. D  -- last_words placeholder comes next
	local tail = D .. date
		.. D .. escaped_extra
		.. D .. _dnl.PROTOCOL_VERSION
		.. D

	-- Dynamic budget: the escaped last_words must fit in whatever
	-- space remains after base + tail + the 2-byte command prefix
	-- every caller prepends (e.g. "1$").
	local budget = WIRE_MAX - COMMAND_PREFIX_LEN - (extra_overhead or 0) - #base - #tail
	local escaped_lw = escapeField(last_words or "")
	if budget < 0 then budget = 0 end
	escaped_lw = truncateEscaped(escaped_lw, budget)

	return base .. escaped_lw .. tail
end

---@param msg string
---@return PlayerData|nil player_data
---@return number protocol_version
function _dnl.decodeMessage(msg)
	local values = {}
	for w in msg:gmatch("(.-)~") do
		table.insert(values, w)
	end

	local num_fields = #values
	if num_fields < 14 then
		return nil, 0
	end

	local name = unescapeField(values[1])
	local guild = unescapeField(values[2])
	if guild == "" then guild = nil end
	local source_id = tonumber(values[3])
	local race_id = tonumber(values[4])
	local class_id = tonumber(values[5])
	local level = tonumber(values[6])
	local instance_id = tonumber(values[7])
	local map_id = tonumber(values[8])
	local map_pos = values[9]
	if map_pos == "" then map_pos = nil end
	local played = tonumber(values[10])

	local last_words = unescapeField(values[11])
	if last_words == "" then last_words = nil end
	local date = tonumber(values[12])
	local extra_data = decodeExtraData(unescapeField(values[13]))
	local protocol_version = tonumber(values[14]) or 3

	local player_data = _dnl.playerData(name, guild, source_id, race_id, class_id, level, instance_id, map_id, map_pos, date, played, last_words, extra_data)
	return player_data, protocol_version
end

---@param _player_data PlayerData
---@return string checksum
function _dnl.fletcher16(_player_data)
	local level = _player_data["level"] or 0
	if _player_data["source_id"] and _player_data["source_id"] == -1 then
		level = 0
	end
	local data = _player_data["name"] .. ":" .. (_player_data["guild"] or "") .. ":" .. level
	local sum1 = 0
	local sum2 = 0
	for index = 1, #data do
		sum1 = (sum1 + string.byte(string.sub(data, index, index))) % 255
		sum2 = (sum2 + sum1) % 255
	end
	return _player_data["name"] .. "-" .. bit.bor(bit.lshift(sum2, 8), sum1)
end

---@param name string player or guild name
---@return string normalized name (without realm)
function _dnl.normalize(name)
	return name:match("^([^-]+)") or name
end

--- Send a chat message on a numbered channel, respecting ChatThrottleLib
--- bandwidth budget.  Bypasses CTL:SendChatMessage (which defers CHANNEL
--- sends out of hardware-event context, breaking Classic restrictions)
--- but still honours the global byte budget via CTL's secure hook on
--- _G.SendChatMessage.
---
--- Returns true if the message was sent, false if the bandwidth budget
--- was exhausted or the pcall failed.
---@param text string         Full chat message text
---@param channel_num number  Channel index from GetChannelName()
---@return boolean sent
function _dnl.safeSendChannel(text, channel_num)
	local CTL = _G.ChatThrottleLib
	if CTL then
		local cost = #text + (CTL.MSG_OVERHEAD or 40)
		local avail = CTL:UpdateAvail()
		if CTL.bQueueing or cost >= avail then
			return false
		end
	end
	local ok, err = pcall(_G.SendChatMessage, text, "CHANNEL", nil, channel_num)
	if not ok and _dnl.DEBUG then
		print("[DNL] safeSendChannel failed: " .. tostring(err))
	end
	return ok
end

--#region API

DeathNotificationLib.SOURCE = _dnl.SOURCE

DeathNotificationLib.ENVIRONMENT_DAMAGE = _dnl.ENVIRONMENT_DAMAGE

DeathNotificationLib.Fletcher16 = _dnl.fletcher16

DeathNotificationLib.EntryQuality = _dnl.entryQuality

DeathNotificationLib.MergeEntries = _dnl.mergeEntries

DeathNotificationLib.ValidatePlayerData = _dnl.validatePlayerData

DeathNotificationLib.PlayerData = _dnl.playerData

--#endregion