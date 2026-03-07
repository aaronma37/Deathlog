--
--[[
Copyright 2026 Yazpad & Deathwing
The Deathlog AddOn is distributed under the terms of the GNU General Public License (or the Lesser GPL).
This file is part of Hardcore.

The Deathlog AddOn is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

The Deathlog AddOn is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with the Deathlog AddOn. If not, see <http://www.gnu.org/licenses/>.
--]]
--
--

DeathlogDataCopy = {}
if DeathlogData then
	DeathlogDataCopy.PRECOMPUTED_GENERAL_STATS = DeathlogData.PRECOMPUTED_GENERAL_STATS
	DeathlogDataCopy.PRECOMPUTED_LOG_NORMAL_PARAMS = DeathlogData.PRECOMPUTED_LOG_NORMAL_PARAMS
	DeathlogDataCopy.PRECOMPUTED_KAPLAN_MEIER = DeathlogData.PRECOMPUTED_KAPLAN_MEIER
	DeathlogDataCopy.PRECOMPUTED_MOST_DEADLY_BY_ZONE = DeathlogData.PRECOMPUTED_MOST_DEADLY_BY_ZONE
	DeathlogDataCopy.PRECOMPUTED_PURGES = DeathlogData.PRECOMPUTED_PURGES
end

local id_to_npc = DeathNotificationLib.ID_TO_NPC
local instance_to_id = DeathNotificationLib.INSTANCE_TO_ID
local id_to_instance = DeathNotificationLib.ID_TO_INSTANCE
local zone_to_id = DeathNotificationLib.ZONE_TO_ID
local deathlog_environment_damage = DeathNotificationLib.ENVIRONMENT_DAMAGE

local MAX_PLAYER_LEVEL = DeathNotificationLib.MAX_PLAYER_LEVEL

-- Weak-keyed cache so computed display sources are never saved to SavedVariables.
-- Keys are entry tables; values are { cached = <string>, predicted = <string|nil> }.
local source_cache = setmetatable({}, { __mode = "k" })

Deathlog_ALL_INSTANCES_ID = -2

-- Build set of all valid instance IDs for ALL_INSTANCES aggregation
local all_instance_id_set = {}
for _, instances in pairs(instance_to_id) do
	for _, iid in pairs(instances) do
		all_instance_id_set[iid] = true
	end
end

-- Instance minimum level requirements (from MapDifficulty game data + manual raid entries)
-- Maps instance_id -> minimum player level required to enter
local instance_min_levels = {
	-- Dungeons (from MapDifficulty)
	[389] = 8,   -- Ragefire Chasm
	[36] = 10,   -- Deadmines
	[43] = 10,   -- Wailing Caverns
	[33] = 11,   -- Shadowfang Keep
	[48] = 15,   -- Blackfathom Deeps
	[34] = 15,   -- Stormwind Stockade
	[90] = 19,   -- Gnomeregan
	[189] = 20,  -- Scarlet Monastery
	[349] = 25,  -- Maraudon
	[47] = 25,   -- Razorfen Kraul
	[70] = 30,   -- Uldaman
	[429] = 31,  -- Dire Maul
	[289] = 33,  -- Scholomance
	[129] = 35,  -- Razorfen Downs
	[329] = 37,  -- Stratholme
	[209] = 39,  -- Zul'Farrak
	[230] = 42,  -- Blackrock Depths
	[109] = 45,  -- Sunken Temple
	[229] = 48,  -- Blackrock Spire (UBRS)
	-- Raids (manual -- no MapDifficulty gate, attunement/practical minimums)
	[249] = 50,  -- Onyxia's Lair (Alliance 50, Horde 55 -- use lower bound)
	[309] = 50,  -- Zul'Gurub
	[469] = 50,  -- Blackwing Lair
	[509] = 50,  -- Ruins of Ahn'Qiraj
	[531] = 50,  -- Ahn'Qiraj Temple
	[409] = 50,  -- Molten Core
	[533] = 60,  -- Naxxramas
	-- PvP
	[30] = 51,   -- Alterac Valley
	[489] = 10,  -- Warsong Gulch
	[529] = 20,  -- Arathi Basin
}

-- TBC instance min levels
if GetExpansionLevel and GetExpansionLevel() >= 1 then
	local tbc_min_levels = {
		[543] = 57,  -- Hellfire Ramparts
		[542] = 58,  -- The Blood Furnace
		[547] = 59,  -- The Slave Pens
		[546] = 60,  -- The Underbog
		[557] = 61,  -- Mana-Tombs
		[558] = 62,  -- Auchenai Crypts
		[560] = 63,  -- The Escape From Durnholde
		[556] = 63,  -- Sethekk Halls
		[540] = 63,  -- The Shattered Halls
		[545] = 65,  -- The Steamvault
		[553] = 65,  -- The Botanica
		[554] = 65,  -- The Mechanar
		[552] = 65,  -- The Arcatraz
		[555] = 65,  -- Shadow Labyrinth
		[585] = 65,  -- Magister's Terrace
		[269] = 65,  -- Opening of the Dark Portal
		[566] = 61,  -- Eye of the Storm
		[559] = 70,  -- Nagrand Arena
		[562] = 70,  -- Blade's Edge Arena
		[572] = 70,  -- Ruins of Lordaeron
		[532] = 70,  -- Karazhan
		[565] = 70,  -- Gruul's Lair
		[544] = 70,  -- Magtheridon's Lair
		[548] = 70,  -- Serpentshrine Cavern
		[550] = 70,  -- Tempest Keep
		[534] = 70,  -- The Battle for Mount Hyjal
		[564] = 70,  -- Black Temple
		[568] = 70,  -- Zul'Aman
		[580] = 70,  -- The Sunwell
	}
	for k, v in pairs(tbc_min_levels) do
		instance_min_levels[k] = v
	end
end

-- Top-level map IDs
Deathlog_AZEROTH_ID = 947
Deathlog_EASTERN_KINGDOMS_ID = 1415
Deathlog_KALIMDOR_ID = 1414

Deathlog_ROOT_MAP_ID = Deathlog_AZEROTH_ID
Deathlog_ROOT_MAP_NAME = "Azeroth"

-- Zones that do not show heatmaps
local no_heatmap_zones = {}

-- Container zones (continents and world-level maps that aggregate child zone stats)
-- Use as a set: container_zone_set[map_id] = true
local container_zone_set = {
	[947] = true,  -- Azeroth
	[1414] = true, -- Kalimdor
	[1415] = true, -- Eastern Kingdoms
}

-- Zone parent mapping: zone_id -> parent_id
-- This defines the zone hierarchy for stats aggregation
local zone_parent_map = {
	-- Azeroth contains continents
	[1414] = 947, -- Kalimdor -> Azeroth
	[1415] = 947, -- Eastern Kingdoms -> Azeroth
	
	-- Eastern Kingdoms zones
	[1416] = 1415, -- Alterac Mountains
	[1417] = 1415, -- Arathi Highlands
	[1418] = 1415, -- Badlands
	[1419] = 1415, -- Blasted Lands
	[1420] = 1415, -- Tirisfal Glades
	[1421] = 1415, -- Silverpine Forest
	[1422] = 1415, -- Western Plaguelands
	[1423] = 1415, -- Eastern Plaguelands
	[1424] = 1415, -- Hillsbrad Foothills
	[1425] = 1415, -- The Hinterlands
	[1426] = 1415, -- Dun Morogh
	[1427] = 1415, -- Searing Gorge
	[1428] = 1415, -- Burning Steppes
	[1429] = 1415, -- Elwynn Forest
	[1430] = 1415, -- Deadwind Pass
	[1431] = 1415, -- Duskwood
	[1432] = 1415, -- Loch Modan
	[1433] = 1415, -- Redridge Mountains
	[1434] = 1415, -- Stranglethorn Vale
	[1435] = 1415, -- Swamp of Sorrows
	[1436] = 1415, -- Westfall
	[1437] = 1415, -- Wetlands
	[1453] = 1415, -- Stormwind City
	[1455] = 1415, -- Ironforge
	[1458] = 1415, -- Undercity
	
	-- Kalimdor zones
	[1411] = 1414, -- Durotar
	[1412] = 1414, -- Mulgore
	[1413] = 1414, -- The Barrens
	[1438] = 1414, -- Teldrassil
	[1439] = 1414, -- Darkshore
	[1440] = 1414, -- Ashenvale
	[1441] = 1414, -- Thousand Needles
	[1442] = 1414, -- Stonetalon Mountains
	[1443] = 1414, -- Desolace
	[1444] = 1414, -- Feralas
	[1445] = 1414, -- Dustwallow Marsh
	[1446] = 1414, -- Tanaris
	[1447] = 1414, -- Azshara
	[1448] = 1414, -- Felwood
	[1449] = 1414, -- Un'Goro Crater
	[1450] = 1414, -- Moonglade
	[1451] = 1414, -- Silithus
	[1452] = 1414, -- Winterspring
	[1454] = 1414, -- Orgrimmar
	[1456] = 1414, -- Thunder Bluff
	[1457] = 1414, -- Darnassus
	
	-- PvP zones in Azeroth
	[1459] = 1415, -- Alterac Valley (in Alterac Mountains area)
	[1460] = 1414, -- Warsong Gulch (in Ashenvale/Barrens area)
	[1461] = 1415, -- Arathi Basin (in Arathi Highlands)
}

-- TBC zones and hierarchy (add if expansion is available)
if GetExpansionLevel and GetExpansionLevel() >= 1 then
	Deathlog_WORLD_MAP_ID = 946
	Deathlog_OUTLAND_ID = 1945

	Deathlog_ROOT_MAP_ID = Deathlog_WORLD_MAP_ID
	Deathlog_ROOT_MAP_NAME = "Cosmos"

	no_heatmap_zones[946] = true  -- Cosmos

	container_zone_set[946] = true  -- Cosmos
	container_zone_set[1945] = true -- Outland

	-- In TBC, Cosmos becomes the top-level, containing both Azeroth and Outland
	zone_parent_map[947] = 946   -- Azeroth -> Cosmos
	zone_parent_map[1945] = 946  -- Outland -> Cosmos
	
	-- TBC starting zones attached to existing continents
	zone_parent_map[1941] = 1415 -- Eversong Woods (attached to EK)
	zone_parent_map[1942] = 1415 -- Ghostlands (attached to EK)
	zone_parent_map[1943] = 1414 -- Azuremyst Isle (attached to Kalimdor)
	zone_parent_map[1950] = 1414 -- Bloodmyst Isle (attached to Kalimdor)
	zone_parent_map[1954] = 1415 -- Silvermoon City (attached to EK)
	zone_parent_map[1947] = 1414 -- The Exodar (attached to Kalimdor)
	
	-- Outland zones parent to Outland
	zone_parent_map[1944] = 1945 -- Hellfire Peninsula
	zone_parent_map[1946] = 1945 -- Zangarmarsh
	zone_parent_map[1948] = 1945 -- Shadowmoon Valley
	zone_parent_map[1949] = 1945 -- Blade's Edge Mountains
	zone_parent_map[1951] = 1945 -- Nagrand
	zone_parent_map[1952] = 1945 -- Terokkar Forest
	zone_parent_map[1953] = 1945 -- Netherstorm
	zone_parent_map[1955] = 1945 -- Shattrath City
	zone_parent_map[1957] = 1945 -- Isle of Quel'Danas
end

-- Get all ancestor zone IDs for a given zone (including the zone itself)
-- Returns a table of zone IDs from the zone up to the Cosmos
function Deathlog_get_zone_ancestors(map_id)
	local ancestors = {}
	local current = map_id
	
	while current ~= nil do
		table.insert(ancestors, current)
		current = zone_parent_map[current]
	end
	
	-- Always include "all" as the top-level aggregator
	table.insert(ancestors, "all")
	
	return ancestors
end

-- Check if a zone is a "container" zone (continent or world-level)
-- These zones aggregate stats from their children
function Deathlog_is_container_zone(map_id)
	return container_zone_set[map_id] == true
end

-- Check if a zone should NOT show a heatmap (only Cosmos)
-- Continents can show aggregated heatmaps from child zones
function Deathlog_should_hide_heatmap(map_id)
	return no_heatmap_zones[map_id] == true
end

-- Normalize a map_id for stats lookup
-- Root Map always shows "all" stats
function Deathlog_normalize_map_id_for_stats(map_id)
	if map_id == nil then
		return "all"
	end
	-- For Root Map, include all data
	if map_id == Deathlog_ROOT_MAP_ID then
		return "all"
	end
	return map_id
end

-- Check if viewing a container zone that should show aggregated stats
function Deathlog_should_show_container_stats(map_id)
	return container_zone_set[map_id] == true
end

Deathlog_class_tbl = {
	["Warrior"] = 1,
	["Paladin"] = 2,
	["Hunter"] = 3,
	["Rogue"] = 4,
	["Priest"] = 5,
	["Shaman"] = 7,
	["Mage"] = 8,
	["Warlock"] = 9,
	["Druid"] = 11,
}

Deathlog_id_to_class_tbl = {
	[1] = "Warrior",
	[2] = "Paladin",
	[3] = "Hunter",
	[4] = "Rogue",
	[5] = "Priest",
	[7] = "Shaman",
	[8] = "Mage",
	[9] = "Warlock",
	[11] = "Druid",
}

Deathlog_race_tbl = {
	["Human"] = 1,
	["Orc"] = 2,
	["Dwarf"] = 3,
	["Night Elf"] = 4,
	["Undead"] = 5,
	["Tauren"] = 6,
	["Gnome"] = 7,
	["Troll"] = 8,
}
if GetExpansionLevel and GetExpansionLevel() >= 1 then
	Deathlog_race_tbl["Blood Elf"] = 10
	Deathlog_race_tbl["Draenei"] = 11
end
-- sort function from stack overflow
local function spairs(t, order)
	local keys = {}
	for k in pairs(t) do
		keys[#keys + 1] = k
	end

	if order then
		table.sort(keys, function(a, b)
			return order(t, a, b)
		end)
	else
		table.sort(keys)
	end

	local i = 0
	return function()
		i = i + 1
		if keys[i] then
			return keys[i], t[keys[i]]
		end
	end
end

function DeathlogShallowCopy(t)
	local t2 = {}
	for k, v in pairs(t) do
		t2[k] = v
	end
	return t2
end

function DeathlogPredictSource(entry)
	local search_radius = (deathlog_settings and deathlog_settings["prediction_radius"]) or 5

	return DeathNotificationLib.PredictSource(entry, search_radius)
end

function DeathlogGetCachedSource(entry)
	if not entry then
		return ""
	end

	local sc = source_cache[entry]
	if not sc then
		sc = {}
		source_cache[entry] = sc
	end

	if sc.cached then
		return sc.cached
	end

	-- clear old predicted_source / cached_source from entry
	if entry.predicted_source then entry.predicted_source = nil end
	if entry.cached_source then entry.cached_source = nil end

	local _pvp_source_name = entry["extra_data"] and entry["extra_data"]["pvp_source_name"]
	local _source = entry["source_id"] and (id_to_npc[entry["source_id"]]
		or deathlog_environment_damage[entry["source_id"]]
		or DeathNotificationLib.DecodePvPSource(entry["source_id"], _pvp_source_name)
		or "") or ""

	if _source == "" then
		if sc.predicted then
			_source = sc.predicted
		else
			local predicted = DeathlogPredictSource(entry)
			if predicted then
				sc.predicted = predicted
				_source = predicted
			end
		end
	end

	sc.cached = _source
	return _source
end

-- Tue Apr 18 21:36:54 2023
function DeathlogConvertStringDateUnix(s)
	if tonumber(s) then
		return s
	end
	local p = "%a+ (%a+) (%d+) (%d+):(%d+):(%d+) (%d+)"
	local month, day, hour, minute, sec, year = s:match(p)
	if month == nil or day == nil or hour == nil or minute == nil or sec == nil or year == nil then
		p = "%a+ (%a+)  (%d+) (%d+):(%d+):(%d+) (%d+)"
		month, day, hour, minute, sec, year = s:match(p)
	end
	if month == nil or day == nil or hour == nil or minute == nil or sec == nil or year == nil then
		return nil
	end
	local MON = {
		Jan = 1,
		Feb = 2,
		Mar = 3,
		Apr = 4,
		May = 5,
		Jun = 6,
		Jul = 7,
		Aug = 8,
		Sep = 9,
		Oct = 10,
		Nov = 11,
		Dec = 12,
	}
	month = MON[month]
---@diagnostic disable-next-line: param-type-mismatch
	local offset = time() - time(date("!*t"))
	return time({ day = day, month = month, year = year, hour = hour, minute = minute, sec = sec }) + offset
end

function Deathlog_fletcher16(name, guild, level, source)
	local data = name .. (guild or "") .. level .. source
	local sum1 = 0
	local sum2 = 0
	for index = 1, #data do
		sum1 = (sum1 + string.byte(string.sub(data, index, index))) % 255
		sum2 = (sum2 + sum1) % 255
	end
	return name .. "-" .. bit.bor(bit.lshift(sum2, 8), sum1)
end

local function generate_player_metadata(metadata_list)
	local metadata = {
		["num_entries"] = 0,
		["sum_lvl"] = 0,
		["avg_lvl"] = 0,
	}
	metadata_list[#metadata_list + 1] = metadata
	return metadata
end

--- Returns true if the entry should be visible given the current settings.
--- Addonless entries (no class_id, no race_id) are hidden when addonless_logging
--- is disabled, preventing synced low-quality entries from cluttering the view.
function Deathlog_shouldShowEntry(entry)
	if entry == nil then
		return false
	end
	-- Filter entries below instance minimum level
	local iid = entry["instance_id"]
	if iid and entry["level"] then
		local min_lvl = instance_min_levels[iid]
		if min_lvl and entry["level"] < min_lvl then
			return false
		end
	end
	-- If addonless_logging is enabled, show everything
	if deathlog_settings and deathlog_settings["addonless_logging"] then
		return true
	end
	-- Addonless gate: entries with neither class nor race are Blizzard-sourced
	-- deaths from players not running the addon.
	if not entry["class_id"] and not entry["race_id"] then
		return false
	end
	return true
end

function DeathlogFilter(_deathlog_data, filter)
	local filtered_death_log = {}
	for server_name, entry_tbl in pairs(_deathlog_data) do
		filtered_death_log[server_name] = {}
		for checksum, entry in pairs(entry_tbl) do
			if Deathlog_shouldShowEntry(entry) and filter(server_name, entry) then
				filtered_death_log[server_name][checksum] = entry
			end
		end
	end

	return filtered_death_log
end

function DeathlogOrderBy(_deathlog, order_function)
	local unordered_list = {}
	local ordered = {}
	for server_name, entry_tbl in pairs(_deathlog) do
		for _, v in pairs(entry_tbl) do
			unordered_list[#unordered_list + 1] = v
		end
	end
	for i, v in spairs(unordered_list, order_function) do
		table.insert(ordered, v)
	end
	return ordered
end

-- Optimized version: sorts by date descending, uses native table.sort (much faster for large datasets)
function DeathlogOrderByFast(_deathlog)
	local list = {}
	local n = 0
	for _, entry_tbl in pairs(_deathlog) do
		for _, v in pairs(entry_tbl) do
			if Deathlog_shouldShowEntry(v) then
				n = n + 1
				list[n] = v
			end
		end
	end
	-- Sort descending by date (newest first) using native table.sort
	table.sort(list, function(a, b)
		local date_a = tonumber(a.date) or 0
		local date_b = tonumber(b.date) or 0
		return date_a > date_b
	end)
	return list
end

local function calculateCDF(ln_mean, ln_std_dev)
	local function logNormal(x, mean, sigma)
		return (1 / (x * sigma * sqrt(2 * 3.14)))
			* exp((-1 / 2) * ((math.log(x) - mean) / sigma) * ((math.log(x) - mean) / sigma))
	end
	local cdf = {}
	cdf[1] = logNormal(1, ln_mean, sqrt(ln_std_dev))
	for i = 2, MAX_PLAYER_LEVEL do
		cdf[i] = cdf[i - 1] + logNormal(i, ln_mean, sqrt(ln_std_dev))
	end
	return cdf
end

function Deathlog_CalculateCDF(ln_mean, ln_std_dev)
	return calculateCDF(ln_mean, ln_std_dev)
end

function Deathlog_CalculateCDF2(ln_mean, ln_sig)
	local a1 = 0.278393
	local a2 = 0.230389
	local a3 = 0.000972
	local a4 = 0.078108

	local function erf(x)
		local negative = 1
		if x < 0 then
			x = -x
			negative = -1
		end
		local denom = (1 + a1 * x + a2 * x * x + a3 * x * x * x + a4 * x * x * x * x)
		local denom = denom * denom * denom * denom
		return negative * (1 - 1 / denom)
	end

	local cdf = {}

	for i = 1, MAX_PLAYER_LEVEL do
		local err_term = erf((math.log(i) - ln_mean) / (sqrt(2) * ln_sig))
		cdf[i] = (1 / 2) * (1 + err_term)
	end
	return cdf
end

-- Example input stats, {"all", "all", "all", nil} to get most deadly mob
function DeathlogGetOrderedNormalized(stats, parameters, ln_mean, ln_std_dev)
	local function normalizeFunc(kills, pr)
		return kills / pr
	end
	local function logNormal(x, mean, sigma)
		return (1 / (x * sigma * sqrt(2 * 3.14)))
			* exp((-1 / 2) * ((math.log(x) - mean) / sigma) * ((math.log(x) - mean) / sigma))
	end
	local function calculateNormalizedValue(kills, avg_lvl, cdf)
		if kills < 10 then
			return 0
		end
		local pr = 1 - cdf[ceil(avg_lvl)]
		return normalizeFunc(kills, pr)
	end
	local cdf = calculateCDF(ln_mean, ln_std_dev)
	local unordered_list = {}
	local ordered = {}
	local prefix_stats = stats
	local post_parameters = {}
	local active = false
	for _, v in ipairs(parameters) do
		if active then
			post_parameters[#post_parameters + 1] = v
		else
			if v == nil then
				active = true
			else
				if prefix_stats[v] == nil then
					return nil
				end
				prefix_stats = prefix_stats[v]
			end
		end
	end

	for k, v in pairs(prefix_stats) do
		if k ~= "all" then
			local postfix_stats = v
			for _, v in ipairs(post_parameters) do
				postfix_stats = postfix_stats[v]
			end
			table.insert(unordered_list, { k, postfix_stats["num_entries"], postfix_stats["avg_lvl"] })
		end
	end
	for i, v in
		spairs(unordered_list, function(t, a, b)
			return calculateNormalizedValue(t[b][2], t[b][3], cdf) < calculateNormalizedValue(t[a][2], t[a][3], cdf)
		end)
	do
		table.insert(ordered, { v[1], calculateNormalizedValue(v[2], v[3], cdf) })
	end
	return ordered
end

-- Example input stats, {"all", "all", "all", nil} to get most deadly mob
function DeathlogGetOrdered(stats, parameters)
	local unordered_list = {}
	local ordered = {}
	local prefix_stats = stats
	local post_parameters = {}
	local active = false
	for _, v in ipairs(parameters) do
		if active then
			post_parameters[#post_parameters + 1] = v
		else
			if v == nil then
				active = true
			else
				if prefix_stats[v] == nil then
					return nil
				end
				prefix_stats = prefix_stats[v]
			end
		end
	end

	for k, v in pairs(prefix_stats) do
		if k ~= "all" then
			local postfix_stats = v
			for _, v in ipairs(post_parameters) do
				postfix_stats = postfix_stats[v]
			end
			if k ~= -1 then
				table.insert(unordered_list, { k, postfix_stats["num_entries"] })
			end
		end
	end
	for i, v in
		spairs(unordered_list, function(t, a, b)
			return t[b][2] < t[a][2]
		end)
	do
		table.insert(ordered, v)
	end
	return ordered
end

local function updateEntry(stats_leaf, entry)
	stats_leaf["num_entries"] = stats_leaf["num_entries"] + 1
	stats_leaf["sum_lvl"] = stats_leaf["sum_lvl"] + entry["level"]
end

local function updateStats(stats, server_name, entry)
	local entry_map_id = entry["map_id"] or entry["instance_id"] or "all"
	
	-- Get all zones this entry should contribute to (zone + all ancestors)
	local zones_to_update = Deathlog_get_zone_ancestors(entry_map_id)
	
	-- Always update "all" stats
	updateEntry(stats["all"]["all"]["all"]["all"], entry)
	updateEntry(stats[server_name]["all"]["all"]["all"], entry)
	updateEntry(stats["all"]["all"][entry["class_id"]]["all"], entry)
	updateEntry(stats["all"]["all"]["all"][entry["source_id"]], entry)
	updateEntry(stats["all"]["all"][entry["class_id"]][entry["source_id"]], entry)
	
	-- Update stats for each zone in the hierarchy
	for _, zone_id in ipairs(zones_to_update) do
		if zone_id ~= "all" then -- "all" already updated above
			updateEntry(stats["all"][zone_id]["all"]["all"], entry)
			updateEntry(stats[server_name][zone_id]["all"]["all"], entry)
			updateEntry(stats["all"][zone_id][entry["class_id"]]["all"], entry)
			updateEntry(stats["all"][zone_id][entry["class_id"]][entry["source_id"]], entry)
			updateEntry(stats["all"][zone_id]["all"][entry["source_id"]], entry)
			updateEntry(stats[server_name][zone_id][entry["class_id"]][entry["source_id"]], entry)
		end
	end

	-- Aggregate into "all instances" bucket if this is an instance death
	local iid = entry["instance_id"]
	if iid and all_instance_id_set[iid] then
		local aid = Deathlog_ALL_INSTANCES_ID
		updateEntry(stats["all"][aid]["all"]["all"], entry)
		updateEntry(stats["all"][aid][entry["class_id"]]["all"], entry)
		updateEntry(stats["all"][aid][entry["class_id"]][entry["source_id"]], entry)
		updateEntry(stats["all"][aid]["all"][entry["source_id"]], entry)
	end
end

local function instantiateIfMissing(_stats, server_name, entry, _metadata_list)
	local entry_map_id = entry["map_id"] or entry["instance_id"] or "all"
	local class_id = entry["class_id"] or "all"
	local source_id = entry["source_id"] or "all"
	
	-- Get all zones this entry should contribute to
	local zones_to_update = Deathlog_get_zone_ancestors(entry_map_id)

	if _stats[server_name] == nil then
		_stats[server_name] = {
			["all"] = {
				["all"] = {
					["all"] = generate_player_metadata(_metadata_list),
				},
			},
		}
	end

	-- Ensure stats structures exist for all zones in hierarchy
	for _, zone_id in ipairs(zones_to_update) do
		if zone_id ~= "all" then
			if _stats["all"][zone_id] == nil then
				_stats["all"][zone_id] = {
					["all"] = {
						["all"] = generate_player_metadata(_metadata_list),
					},
				}
			end

			if _stats[server_name][zone_id] == nil then
				_stats[server_name][zone_id] = {
					["all"] = {
						["all"] = generate_player_metadata(_metadata_list),
					},
				}
			end

			if _stats["all"][zone_id][class_id] == nil then
				_stats["all"][zone_id][class_id] = {
					["all"] = generate_player_metadata(_metadata_list),
				}
			end

			if _stats[server_name][zone_id][class_id] == nil then
				_stats[server_name][zone_id][class_id] = {
					["all"] = generate_player_metadata(_metadata_list),
				}
			end

			if _stats["all"][zone_id][class_id][source_id] == nil then
				_stats["all"][zone_id][class_id][source_id] = generate_player_metadata(_metadata_list)
			end
			if _stats["all"][zone_id]["all"][source_id] == nil then
				_stats["all"][zone_id]["all"][source_id] = generate_player_metadata(_metadata_list)
			end
			if _stats[server_name][zone_id][class_id][source_id] == nil then
				_stats[server_name][zone_id][class_id][source_id] = generate_player_metadata(_metadata_list)
			end
		end
	end

	-- Ensure "all instances" aggregation bucket exists for instance deaths
	local iid = entry["instance_id"]
	if iid and all_instance_id_set[iid] then
		local aid = Deathlog_ALL_INSTANCES_ID
		if _stats["all"][aid] == nil then
			_stats["all"][aid] = {
				["all"] = {
					["all"] = generate_player_metadata(_metadata_list),
				},
			}
		end
		if _stats["all"][aid][class_id] == nil then
			_stats["all"][aid][class_id] = {
				["all"] = generate_player_metadata(_metadata_list),
			}
		end
		if _stats["all"][aid][class_id][source_id] == nil then
			_stats["all"][aid][class_id][source_id] = generate_player_metadata(_metadata_list)
		end
		if _stats["all"][aid]["all"][source_id] == nil then
			_stats["all"][aid]["all"][source_id] = generate_player_metadata(_metadata_list)
		end
	end

	-- Always ensure "all" level structures exist
	if _stats["all"]["all"][class_id] == nil then
		_stats["all"]["all"][class_id] = {
			["all"] = generate_player_metadata(_metadata_list),
		}
	end

	if _stats["all"]["all"]["all"][source_id] == nil then
		_stats["all"]["all"]["all"][source_id] = generate_player_metadata(_metadata_list)
	end
	if _stats["all"]["all"][class_id][source_id] == nil then
		_stats["all"]["all"][class_id][source_id] = generate_player_metadata(_metadata_list)
	end
end

-- [server][map_id][class_id][source_id] = {num_entries, sum_lvl, avg_level}
function Deathlog_calculate_statistics(_deathlog_data)
	local metadata_list = {}
	local stats = {
		["all"] = {
			["all"] = {
				["all"] = {
					["all"] = generate_player_metadata(metadata_list),
				},
			},
		},
	}

	-- First pass
	for server_name, entry_tbl in pairs(_deathlog_data) do
		for checksum, entry in pairs(entry_tbl) do
			if Deathlog_shouldShowEntry(entry) and entry["class_id"] then
				instantiateIfMissing(stats, server_name, entry, metadata_list)

				local map_id = entry["map_id"] or entry["instance_id"] or "all"
				updateStats(stats, server_name, entry)
			end
		end
	end

	for k, v in ipairs(metadata_list) do
		v["avg_lvl"] = v["sum_lvl"] / v["num_entries"]
	end

	-- local ordered = DeathlogGetOrdered(stats, {"all", "all", "all", nil})
	-- for i,v in ipairs(ordered) do
	--   if i < 25 then
	--     print(i, id_to_npc[v[1]], v[2])
	--   end
	-- end

	return stats
end

function Deathlog_serializeTable(val, name, skipnewlines, depth)
	skipnewlines = skipnewlines or false
	depth = depth or 0

	local tmp = string.rep(" ", depth)

	if name then
		if type(name) == "string" then
			tmp = tmp .. "['" .. name .. "']" .. " = "
		else
			tmp = tmp .. "[" .. name .. "]" .. " = "
		end
	end

	if type(val) == "table" then
		tmp = tmp .. "{" .. (not skipnewlines and "" or "")

		for k, v in pairs(val) do
			tmp = tmp
				.. Deathlog_serializeTable(v, k, skipnewlines, depth + 1)
				.. ","
				.. (not skipnewlines and "" or "")
		end

		tmp = tmp .. string.rep(" ", depth) .. "}"
	elseif type(val) == "number" then
		tmp = tmp .. tostring(val)
	elseif type(val) == "string" then
		tmp = tmp .. string.format("%q", val)
	elseif type(val) == "boolean" then
		tmp = tmp .. (val and "true" or "false")
	else
		tmp = tmp .. '"[inserializeable datatype:' .. type(val) .. ']"'
	end

	return tmp
end

-- Output format matches Python preprocessor: result[class_id] = {ln_mean, ln_std_dev, total}
local function calculateLogNormalParametersForMap(_deathlog_data, map_id)
	local function filter_by_map_function(servername, entry)
		-- For Root Map, include all data
		if map_id == Deathlog_ROOT_MAP_ID then
			return true
		end
		-- ALL_INSTANCES aggregate: include any entry whose instance_id is valid
		if map_id == Deathlog_ALL_INSTANCES_ID then
			local iid = entry["instance_id"]
			return iid ~= nil and all_instance_id_set[iid] == true
		end
		-- For container zones (continents, Outland), check if entry's zone is a descendant
		if Deathlog_is_container_zone(map_id) then
			local entry_map = entry["map_id"] or entry["instance_id"]
			if entry_map then
				local ancestors = Deathlog_get_zone_ancestors(entry_map)
				for _, ancestor_id in ipairs(ancestors) do
					if ancestor_id == map_id then
						return true
					end
				end
			end
			return false
		end
		-- For regular zones, exact match
		if entry["map_id"] == map_id or entry["instance_id"] == map_id then
			return true
		end
		return false
	end
	local filtered_by_map = DeathlogFilter(_deathlog_data, filter_by_map_function)

	-- Collect levels per class_id
	local levels_by_class = {}
	for servername, entry_tbl in pairs(filtered_by_map) do
		for _, v in pairs(entry_tbl) do
			if v["class_id"] and v["level"] and v["level"] > 0 then
				local cid = v["class_id"]
				if not levels_by_class[cid] then
					levels_by_class[cid] = {}
				end
				levels_by_class[cid][#levels_by_class[cid] + 1] = v["level"]
			end
		end
	end

	-- Compute log-normal params per class: result[class_id] = {ln_mean, ln_std_dev, total}
	local result = {}
	for cid, levels in pairs(levels_by_class) do
		local total = #levels
		if total > 0 then
			local ln_mean = 0
			for _, lvl in ipairs(levels) do
				ln_mean = ln_mean + math.log(lvl)
			end
			ln_mean = ln_mean / total

			local ln_std_dev = 0
			for _, lvl in ipairs(levels) do
				local diff = math.log(lvl) - ln_mean
				ln_std_dev = ln_std_dev + diff * diff
			end
			ln_std_dev = ln_std_dev / total
			if ln_std_dev < 0.01 then ln_std_dev = 0.01 end

			result[cid] = { ln_mean, ln_std_dev, total }
		end
	end
	return result
end

function Deathlog_calculateLogNormalParameters(_deathlog_data)
	local log_normal_params = {}

	-- "all" key: aggregate across all data (matches Python's dists["all"])
	log_normal_params["all"] = calculateLogNormalParametersForMap(_deathlog_data, Deathlog_ROOT_MAP_ID)

	for _, zones in pairs(zone_to_id) do
		for _, v in pairs(zones) do
			log_normal_params[v] = calculateLogNormalParametersForMap(_deathlog_data, v)
		end
	end

	for _, instances in pairs(instance_to_id) do
		for _, v in pairs(instances) do
			log_normal_params[v] = calculateLogNormalParametersForMap(_deathlog_data, v)
		end
	end

	-- "all instances" aggregate bucket
	log_normal_params[Deathlog_ALL_INSTANCES_ID] = calculateLogNormalParametersForMap(_deathlog_data, Deathlog_ALL_INSTANCES_ID)

	return log_normal_params
end

-- Kaplan-Meier computation is disabled (requires statistical library not available in Lua).
-- The Python preprocessor also has this commented out; the precomputed data ships as {}.
function Deathlog_calculateKaplanMeier(_deathlog_data)
	return {}
end

-- Count deaths per creature per zone, then rank top 10 per zone.
-- Structure: result[zone_id][creature_id] = rank (1-10)
function Deathlog_calculateMostDeadlyByZone(_deathlog_data)
	local creature_deaths_by_zone = { ["all"] = {} }

	for _, entry_tbl in pairs(_deathlog_data) do
		for _, v in pairs(entry_tbl) do
			local source_id = v["source_id"]
			if source_id then
				-- Count for "all" zones
				creature_deaths_by_zone["all"][source_id] = (creature_deaths_by_zone["all"][source_id] or 0) + 1

				-- Count for specific zone and all parent zones
				local map_id = v["map_id"]
				if map_id then
					local ancestors = Deathlog_get_zone_ancestors(map_id)
					for _, zone_id in ipairs(ancestors) do
						if zone_id ~= "all" then -- already counted above
							if creature_deaths_by_zone[zone_id] == nil then
								creature_deaths_by_zone[zone_id] = {}
							end
							creature_deaths_by_zone[zone_id][source_id] = (creature_deaths_by_zone[zone_id][source_id] or 0) + 1
						end
					end
				end

				-- Aggregate into "all instances" bucket
				local instance_id = v["instance_id"]
				if instance_id and all_instance_id_set[instance_id] then
					if creature_deaths_by_zone[Deathlog_ALL_INSTANCES_ID] == nil then
						creature_deaths_by_zone[Deathlog_ALL_INSTANCES_ID] = {}
					end
					creature_deaths_by_zone[Deathlog_ALL_INSTANCES_ID][source_id] = (creature_deaths_by_zone[Deathlog_ALL_INSTANCES_ID][source_id] or 0) + 1
				end
			end
		end
	end

	-- Rank top 10 creatures per zone
	local most_deadly_by_zone = {}
	for zone_id, creatures in pairs(creature_deaths_by_zone) do
		-- Collect into sortable list
		local sorted = {}
		for creature_id, count in pairs(creatures) do
			sorted[#sorted + 1] = { creature_id, count }
		end
		table.sort(sorted, function(a, b) return a[2] > b[2] end)

		most_deadly_by_zone[zone_id] = {}
		for rank = 1, math.min(10, #sorted) do
			most_deadly_by_zone[zone_id][sorted[rank][1]] = rank
		end
	end

	return most_deadly_by_zone
end

-- Return the local purge list. The Python preprocessor aggregates purges from
-- all contributors; at runtime we only have the local deathlog_purged SavedVariable.
function Deathlog_calculatePurges(_deathlog_data)
	return deathlog_purged or {}
end

function Deathlog_calculateSkullLocs(_deathlog_data)
	local skull_locs = {}
	for servername, entry_tbl in pairs(_deathlog_data) do
		for _, v in pairs(entry_tbl) do
			if v["map_id"] and v["map_pos"] then
				if skull_locs[v["map_id"]] == nil then
					skull_locs[v["map_id"]] = {}
				end
				local x, y = strsplit(",", v["map_pos"], 2)
				skull_locs[v["map_id"]][#skull_locs[v["map_id"]] + 1] = { x * 1000, y * 1000, v["source_id"] }
			end
		end
	end
	return skull_locs
end

function Deathlog_setTooltipFromEntry(_entry)
	if _entry == nil then
		return
	end
	local _name = _entry["name"]
	local _level = _entry["level"]
	local _guild = _entry["guild"] or ""
	local _race = nil
	local _class = nil
	local _source = DeathlogGetCachedSource(_entry)
	local _zone = nil
	local _loc = _entry["map_pos"]
	local _date = nil
	if _entry["date"] then
		_date = date("%m/%d/%y", _entry["date"])
	end
	local _playtime = DeathNotificationLib.FormatPlaytime(_entry["played"])
	local _last_words = nil
	if _entry["last_words"] ~= nil and not _entry["last_words"]:match("^%s*$") then
		_last_words = _entry["last_words"]
	end

	if _entry["race_id"] ~= nil then
		local race_info = C_CreatureInfo.GetRaceInfo(_entry["race_id"])
		if race_info then
			_race = race_info.raceName
		end
	end

	if _entry["class_id"] ~= nil then
		local class_str = GetClassInfo(_entry["class_id"])
		if class_str then
			local color = DeathNotificationLib.CLASS_ID_TO_COLOR[_entry["class_id"]]
			if color then
				_class = "|c" .. color.colorStr .. class_str .. "|r"
			else
				_class = class_str
			end
		end
	end

	if _entry["map_id"] then
		local map_info = C_Map.GetMapInfo(_entry["map_id"])
		if map_info then
			_zone = map_info.name
		end
	elseif _entry["instance_id"] then
		_zone = (id_to_instance[_entry["instance_id"]] or _entry["instance_id"])
	end
	Deathlog_setTooltip(_name, _level, _guild, _race, _class, _source, _zone, _date, _playtime, _last_words)
end

function Deathlog_setTooltip(_name, _lvl, _guild, _race, _class, _source, _zone, _date, _playtime, _last_words)
	if _name == nil or _lvl == nil then
		return
	end

	local _deathlog_watchlist_icon = ""
	if
		deathlog_watchlist_entries
		and deathlog_watchlist_entries[_name]
		and deathlog_watchlist_entries[_name]["Icon"]
	then
		_deathlog_watchlist_icon = deathlog_watchlist_entries[_name]["Icon"] .. " "
	end
	if string.sub(_name, #_name) == "s" then
		GameTooltip:AddDoubleLine(
			_deathlog_watchlist_icon .. _name .. "' " .. Deathlog_L.death_word,
			(_lvl and _lvl ~= "" and ("Lvl. " .. _lvl) or ""),
			1,
			1,
			1,
			0.5,
			0.5,
			0.5
		)
	else
		GameTooltip:AddDoubleLine(
			_deathlog_watchlist_icon .. _name .. "'s " .. Deathlog_L.death_word,
			(_lvl and _lvl ~= "" and ("Lvl. " .. _lvl) or ""),
			1,
			1,
			1,
			0.5,
			0.5,
			0.5
		)
	end

	local ml = deathlog_settings["minilog"]
	if ml == nil then return end

	if ml["tooltip_name"] and _name then
		GameTooltip:AddLine(Deathlog_L.name_word .. ": " .. _name, 1, 1, 1)
	end
	if ml["tooltip_guild"] and _guild and _guild ~= "" then
		GameTooltip:AddLine(Deathlog_L.guild_word .. ": " .. _guild, 1, 1, 1)
	end

	if ml["tooltip_race"] and _race and _race ~= "" then
		GameTooltip:AddLine(Deathlog_L.race_word .. ": " .. _race, 1, 1, 1)
	end

	if ml["tooltip_class"] and _class and _class ~= "" then
		GameTooltip:AddLine(Deathlog_L.class_word .. ": " .. _class, 1, 1, 1)
	end
	if deathlog_settings["colored_tooltips"] == nil or deathlog_settings["colored_tooltips"] == false then
		if ml["tooltip_killedby"] and _source then
			GameTooltip:AddLine(Deathlog_L.killed_by_word .. ": " .. _source, 1, 1, 1)
		end
		if ml["tooltip_zone"] and _zone then
			GameTooltip:AddLine(Deathlog_L.zone_instance_word .. ": " .. _zone, 1, 1, 1)
		end
	else
		if ml["tooltip_killedby"] and _source then
			GameTooltip:AddLine(Deathlog_L.killed_by_word .. ": |cfffda172" .. _source .. "|r", 1, 1, 1)
		end
		if ml["tooltip_zone"] and _zone then
			GameTooltip:AddLine(Deathlog_L.zone_instance_word .. ": |cff9fe2bf" .. _zone .. "|r", 1, 1, 1)
		end
	end

	if ml["tooltip_date"] and _date then
		GameTooltip:AddLine(Deathlog_L.date_word .. ": " .. _date, 1, 1, 1)
	end

	if ml["tooltip_playtime"] then
		if _playtime and _playtime ~= "" then
			GameTooltip:AddLine(Deathlog_L.playtime_word .. ": " .. _playtime, 1, 1, 1)
		end
	end

	if ml["tooltip_lastwords"] then
		if _last_words and _last_words ~= "" then
			GameTooltip:AddLine(Deathlog_L.last_words_word .. ": " .. _last_words, 1, 1, 0, true)
		end
	end
end

local record_econ_handler = nil
local record_econ_timer = nil
local record_econ_start_time = GetServerTime()
local logged_already = {}

local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded

-- Only enable recording if guild opts in, e.g. :M:Hardcore:
local function registerRecorders()
	local guild_info_text = GetGuildInfoText()
	if guild_info_text then
		local _, g, k = string.split(":", guild_info_text)
		if g and g == "M" and k then
			record_econ_handler = CreateFrame("Frame")
			local start_gold = GetMoney()
			local _v = isLoaded(k)
			if _v == false then
				deathlog_record_econ_stats[GetServerTime() .. "general"] = UnitName("player")
					.. ": Logged without "
					.. k
					.. "."
				record_econ_handler:RegisterEvent("MAIL_SHOW") -- Using mailbox
				record_econ_handler:RegisterEvent("MAIL_INBOX_UPDATE") -- Using mailbox
				record_econ_handler:RegisterEvent("CHAT_MSG_LOOT") -- Using mailbox
				record_econ_handler:RegisterEvent("TRADE_SHOW") -- Trade opened
				record_econ_handler:RegisterEvent("AUCTION_BIDDER_LIST_UPDATE") -- Using Auction house

				TradeFrameTradeButton:SetScript("OnClick", function()
					local _item_name, _, _, _, _enchantment_name, _ = GetTradePlayerItemInfo(7)
					if _item_name and _enchantment_name then
						local _target_trader = TradeFrameRecipientNameText:GetText()
						deathlog_record_econ_stats[GetServerTime() .. "Ench"] = UnitName("player")
							.. ": Received enchantment for "
							.. _item_name
							.. ","
							.. _enchantment_name
							.. ", from: "
							.. (_target_trader or "unknown")
					end
					AcceptTrade()
				end)

				record_econ_handler:SetScript("OnEvent", function(self, event, arg)
					if event == "MAIL_SHOW" then
						deathlog_record_econ_stats[GetServerTime() .. "mail"] = UnitName("player") .. ": Opened mail"
					elseif event == "MAIL_INBOX_UPDATE" then
						for _mail_idx = 1, 8 do
							local _, _, _sender_name, _desc = GetInboxHeaderInfo(_mail_idx)
							if _sender_name and _desc then
								if
									_sender_name == "Alliance Auction House"
									or _sender_name == "Horde Auction House"
								then
									if logged_already[_sender_name .. _desc] == nil then
										logged_already[_sender_name .. _desc] = 1
										deathlog_record_econ_stats[GetServerTime() .. _sender_name .. _mail_idx] = UnitName(
											"player"
										) .. ": Inbox has " .. _desc
									end
								end
							end
						end
					elseif event == "CHAT_MSG_LOOT" then
						deathlog_record_econ_stats[GetServerTime() .. "gained"] = UnitName("player") .. ": " .. arg
					elseif event == "TRADE_SHOW" then
						deathlog_record_econ_stats[GetServerTime() .. "trade"] = UnitName("player") .. ": Traded"
					elseif event == "AUCTION_BIDDER_LIST_UPDATE" then
						deathlog_record_econ_stats[GetServerTime() .. "AH"] = UnitName("player") .. ": Used AH"
					end
				end)

				C_Timer.NewTicker(5, function()
					deathlog_record_econ_stats[record_econ_start_time .. "session_stats"] = UnitName("player")
						.. ": Duration: "
						.. (GetServerTime() - record_econ_start_time)
						.. "s. Gold Difference: "
						.. (GetMoney() - start_gold)
						.. "c"
				end)
			end
		end
	end
end

local attempts = 0
C_Timer.NewTicker(1, function(self)
	local guild_info_text = GetGuildInfoText()
	if guild_info_text ~= nil and guild_info_text ~= "" then
		registerRecorders()
		self:Cancel()
	end
	attempts = attempts + 1
	if attempts > 10 then
		self:Cancel()
	end
end)

local deathlog_copy_popup = nil

--- Show a small popup with an EditBox for easy copying.
---@param text string
function Deathlog_ShowCopyPopup(text)
	if not deathlog_copy_popup then
		local popup = CreateFrame("Frame", "DeathlogCopyPopupFrame", UIParent, "BackdropTemplate")
		popup:SetSize(320, 120)
		popup:SetPoint("CENTER", UIParent, "CENTER", 0, 40)
		popup:SetFrameStrata("TOOLTIP")
		popup:SetToplevel(true)
		popup:EnableMouse(true)
		popup:SetMovable(true)
		popup:RegisterForDrag("LeftButton")
		popup:SetScript("OnDragStart", popup.StartMoving)
		popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
		popup:SetBackdrop({
			bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
			edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
			tile = true,
			tileSize = 32,
			edgeSize = 32,
			insets = { left = 8, right = 8, top = 8, bottom = 8 },
		})

		local title = popup:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		title:SetPoint("TOP", popup, "TOP", 0, -16)
		title:SetText("Press Ctrl+C to copy")

		local close = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
		close:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -4, -4)

		local editBox = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
		editBox:SetAutoFocus(true)
		editBox:SetSize(220, 30)
		editBox:SetPoint("CENTER", popup, "CENTER", 0, -6)
		editBox:SetScript("OnEscapePressed", function(self)
			self:ClearFocus()
			popup:Hide()
		end)
		popup.editBox = editBox

		local hint = popup:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
		hint:SetPoint("BOTTOM", popup, "BOTTOM", 0, 12)
		hint:SetText("Esc to close")

		popup:Hide()
		deathlog_copy_popup = popup
	end

	local value = text or ""
	deathlog_copy_popup.editBox:SetText(value)
	deathlog_copy_popup.editBox:HighlightText()
	deathlog_copy_popup:Show()
	deathlog_copy_popup:Raise()
	deathlog_copy_popup.editBox:SetFocus()
end
