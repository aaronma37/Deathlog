--[[
DeathNotificationLib~BlizzardParser.lua

Universal death-broadcast parser built from Blizzard's own
HARDCORE_CAUSEOFDEATH_* global strings.  Because those globals are
localised by the client, the parser works for every language
automatically — no per-locale functions required.

Provides:
  _dnl.parse_hc_death_broadcast(msg)
    → name, source_id, area, level, pvp_source_name   (or nils)
--]]

local _dnl = DeathNotificationLib.Internal ---@class _dnl
if not _dnl then return end

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------

--- Convert a Blizzard format string (printf-style) into a Lua pattern,
--- returning both the pattern and an index map that translates text-order
--- captures back into semantic (argument-number) order.
---
--- Handles:
---   %s / %d                → sequential args (1, 2, 3, …)
---   %N$s / %N$d            → positional args (explicit argument number N)
---   $s                     → known Blizzard typo, treated as next sequential %s
---   |3-N(…) / |1…;…;       → Russian/Korean declension wrappers (literal text)
---
---@param fmt string
---@return string pattern        Lua pattern with captures in text order
---@return table  index_map      index_map[i] = semantic argument number of capture i
local function fmtToPattern(fmt)
	-- We walk the format string character by character, building the
	-- pattern and recording which semantic argument each capture belongs to.
	local index_map = {}
	local parts = {}          -- collected pattern fragments
	local next_seq = 1        -- next sequential argument number
	local i = 1
	local len = #fmt

	while i <= len do
		local ch = fmt:sub(i, i)

		-- ── %N$s / %N$d  (positional) ──
		local pos_n, pos_type = fmt:match("^%%(%d+)%$([sd])", i)
		if pos_n then
			local n = tonumber(pos_n)
			if pos_type == "s" then
				parts[#parts + 1] = "(.-)"
			else
				parts[#parts + 1] = "(%d+)"
			end
			index_map[#index_map + 1] = n
			-- advance next_seq past any positional we've seen, so if
			-- sequential args follow they continue from the right slot
			if n >= next_seq then next_seq = n + 1 end
			i = i + #("%" .. pos_n .. "$" .. pos_type)

		-- ── %s / %d  (sequential) ──
		elseif fmt:sub(i, i + 1) == "%s" then
			parts[#parts + 1] = "(.-)"
			index_map[#index_map + 1] = next_seq
			next_seq = next_seq + 1
			i = i + 2

		elseif fmt:sub(i, i + 1) == "%d" then
			parts[#parts + 1] = "(%d+)"
			index_map[#index_map + 1] = next_seq
			next_seq = next_seq + 1
			i = i + 2

		-- ── $s  (Blizzard typo — literal in the output, NOT a format specifier) ──
		elseif fmt:sub(i, i + 1) == "$s" then
			parts[#parts + 1] = "%$s"
			i = i + 2

		-- ── literal character (escape Lua magic chars) ──
		else
			if ch:find("[%(%)%.%%%+%-%*%?%[%]%^%$]") then
				parts[#parts + 1] = "%" .. ch
			else
				parts[#parts + 1] = ch
			end
			i = i + 1
		end
	end

	return table.concat(parts) .. "$", index_map
end

--- Reorder captures from text order into semantic (argument-number) order.
---@param captures table  array of captures in text order
---@param index_map table index_map[i] = semantic arg number
---@return table          array indexed by semantic arg number
local function reorder(captures, index_map)
	local semantic = {}
	for i, arg_num in ipairs(index_map) do
		semantic[arg_num] = captures[i]
	end
	return semantic
end

---------------------------------------------------------------------------
-- build patterns at load time
---------------------------------------------------------------------------

--- Structured list of { pattern, index_map, handler }.
--- handler(semantic_args) → name, source_id, area, level, pvp_source_name
local matchers = {}

local function addMatcher(globalName, handler)
	local fmt = _G[globalName]
	if not fmt then return end
	local pat, idx = fmtToPattern(fmt)
	matchers[#matchers + 1] = { pattern = pat, index_map = idx, handler = handler }
end

-- Semantic args: 1=link, 2=name, 3=source, 4=area, 5=level
addMatcher("HARDCORE_CAUSEOFDEATH_CREATURE", function(a)
	return a[2], _dnl.D.NPC_TO_ID[a[3]], a[4], tonumber(a[5]), nil
end)

-- Semantic args: 1=link, 2=name, 3=source, 4=area, 5=level
addMatcher("HARDCORE_CAUSEOFDEATH_PVP", function(a)
	return a[2], _dnl.createPvpSourceId(_dnl.PVP_FLAGS.REGULAR), a[4], tonumber(a[5]), a[3]
end)

-- Semantic args: 1=link, 2=name, 3=source, 4=level  (no area — $s typo is literal)
-- If Blizzard fixes $s → %s: 1=link, 2=name, 3=source, 4=area, 5=level
addMatcher("HARDCORE_CAUSEOFDEATH_DUEL", function(a)
	if a[5] then
		return a[2], _dnl.createPvpSourceId(_dnl.PVP_FLAGS.DUEL_TO_DEATH), a[4], tonumber(a[5]), a[3]
	end
	return a[2], _dnl.createPvpSourceId(_dnl.PVP_FLAGS.DUEL_TO_DEATH), nil, tonumber(a[4]), a[3]
end)

-- Semantic args: 1=link, 2=name, 3=area, 4=level
addMatcher("HARDCORE_CAUSEOFDEATH_DROWNING", function(a)
	return a[2], -2, a[3], tonumber(a[4]), nil
end)

-- Semantic args: 1=link, 2=name, 3=area, 4=level
addMatcher("HARDCORE_CAUSEOFDEATH_FALLING", function(a)
	return a[2], -3, a[3], tonumber(a[4]), nil
end)

-- Semantic args: 1=link, 2=name, 3=area, 4=level
addMatcher("HARDCORE_CAUSEOFDEATH_FATIGUE", function(a)
	return a[2], -4, a[3], tonumber(a[4]), nil
end)

-- Semantic args: 1=link, 2=name, 3=area, 4=level
addMatcher("HARDCORE_CAUSEOFDEATH_FIRE", function(a)
	return a[2], -5, a[3], tonumber(a[4]), nil
end)

-- Semantic args: 1=link, 2=name, 3=area, 4=level
addMatcher("HARDCORE_CAUSEOFDEATH_LAVA", function(a)
	return a[2], -6, a[3], tonumber(a[4]), nil
end)

-- Semantic args: 1=link, 2=name, 3=area  (truncated — no level in any locale!)
-- If Blizzard adds level: 1=link, 2=name, 3=area, 4=level
addMatcher("HARDCORE_CAUSEOFDEATH_SLIME", function(a)
	return a[2], -7, a[3], tonumber(a[4]), nil
end)

-- Semantic args: 1=link, 2=name, 3=level  (no area, no source)
addMatcher("HARDCORE_CAUSEOFDEATH_NONE", function(a)
	return a[2], -1, nil, tonumber(a[3]), nil
end)

---------------------------------------------------------------------------
-- public parser
---------------------------------------------------------------------------

--- Parse a Blizzard hardcore death broadcast message.
---@param msg string
---@return string|nil name
---@return number|nil source_id
---@return string|nil area
---@return number|nil level
---@return string|nil pvp_source_name
function _dnl.parse_hc_death_broadcast(msg)
	for i = 1, #matchers do
		local m = matchers[i]
		local captures = { msg:match(m.pattern) }
		if captures[1] then
			local semantic = reorder(captures, m.index_map)
			return m.handler(semantic)
		end
	end
	return nil, nil, nil, nil, nil
end

---------------------------------------------------------------------------
-- Tarnished Soul emote patterns (Soul of Iron realms)
---------------------------------------------------------------------------

--- Patterns keyed by WoW locale code.  Each entry is a list of exact
--- strings to match against the CHAT_MSG_MONSTER_EMOTE text.
--- "%s" appears literally in the Blizzard global string.
---@type table<string, string[]>
local TARNISHED_SOUL_PATTERNS = {
	["enUS"] = { "Death tarnishes %s's soul." },
	["enGB"] = { "Death tarnishes %s's soul." },
	["deDE"] = { "Der Tod wirft einen Schatten auf die Seele von %s" },
	["frFR"] = { "La mort ternit l'âme d'%s." },
	["esES"] = { "La muerte le quita el lustre al alma de %s." },
	["esMX"] = { "La muerte mancilla el alma de %s." },
	["itIT"] = { "Death tarnishes %s's soul." },
	["ptBR"] = { "A morte maculou a alma de %s." },
	-- ruRU, koKR, zhCN, zhTW: not yet known — nil means "not supported"
}

local patterns = TARNISHED_SOUL_PATTERNS[GetLocale()]

--- Parse a CHAT_MSG_MONSTER_EMOTE message for a Tarnished Soul death.
---@param msg string  The emote text
---@return boolean
function _dnl.parseTarnishedSoulEmote(msg)
	if not patterns then return false end
	for _, pattern in ipairs(patterns) do
		if msg == pattern then
			return true
		end
	end
	return false
end
