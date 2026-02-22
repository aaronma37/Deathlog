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
local id_to_npc = DeathNotificationLib.ID_TO_NPC
local instance_to_id = DeathNotificationLib.INSTANCE_TO_ID
local id_to_instance = DeathNotificationLib.ID_TO_INSTANCE
local zone_to_id = DeathNotificationLib.ZONE_TO_ID
local deathlog_environment_damage = DeathNotificationLib.ENVIRONMENT_DAMAGE

local MAX_PLAYER_LEVEL = DeathNotificationLib.MAX_PLAYER_LEVEL

deathlog_ALL_INSTANCES_ID = -2

-- Top-level map IDs
deathlog_AZEROTH_ID = 947
deathlog_EASTERN_KINGDOMS_ID = 1415
deathlog_KALIMDOR_ID = 1414

deathlog_ROOT_MAP_ID = deathlog_AZEROTH_ID
deathlog_ROOT_MAP_NAME = "Azeroth"

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
	deathlog_WORLD_MAP_ID = 946
	deathlog_OUTLAND_ID = 1945

	deathlog_ROOT_MAP_ID = deathlog_WORLD_MAP_ID
	deathlog_ROOT_MAP_NAME = "Cosmos"

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
function deathlog_get_zone_ancestors(map_id)
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
function deathlog_is_container_zone(map_id)
	return container_zone_set[map_id] == true
end

-- Check if a zone should NOT show a heatmap (only Cosmos)
-- Continents can show aggregated heatmaps from child zones
function deathlog_should_hide_heatmap(map_id)
	return no_heatmap_zones[map_id] == true
end

-- Normalize a map_id for stats lookup
-- Root Map always shows "all" stats
function deathlog_normalize_map_id_for_stats(map_id)
	if map_id == nil then
		return "all"
	end
	-- For Root Map, include all data
	if map_id == deathlog_ROOT_MAP_ID then
		return "all"
	end
	return map_id
end

-- Check if viewing a container zone that should show aggregated stats
function deathlog_should_show_container_stats(map_id)
	return container_zone_set[map_id] == true
end

deathlog_class_tbl = {
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

deathlog_id_to_class_tbl = {
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

deathlog_race_tbl = {
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
	deathlog_race_tbl["Blood Elf"] = 10
	deathlog_race_tbl["Draenei"] = 11
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

function deathlogShallowCopy(t)
	local t2 = {}
	for k, v in pairs(t) do
		t2[k] = v
	end
	return t2
end

function deathlogPredictSource(entry)
	local search_radius = (deathlog_settings and deathlog_settings["prediction_radius"]) or 5

	return DeathNotificationLib.PredictSource(entry, search_radius)
end

-- Tue Apr 18 21:36:54 2023
function deathlogConvertStringDateUnix(s)
	if tonumber(s) then
		return s
	end
	p = "%a+ (%a+) (%d+) (%d+):(%d+):(%d+) (%d+)"
	month, day, hour, minute, sec, year = s:match(p)
	if month == nil or day == nil or hour == nil or minute == nil or sec == nil or year == nil then
		p = "%a+ (%a+)  (%d+) (%d+):(%d+):(%d+) (%d+)"
		month, day, hour, minute, sec, year = s:match(p)
	end
	if month == nil or day == nil or hour == nil or minute == nil or sec == nil or year == nil then
		return nil
	end
	MON = {
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
	offset = time() - time(date("!*t"))
	return time({ day = day, month = month, year = year, hour = hour, minute = minute, sec = sec }) + offset
end

function deathlog_fletcher16(name, guild, level, source)
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

function deathlogFilter(_deathlog_data, filter)
	local filtered_death_log = {}
	for server_name, entry_tbl in pairs(_deathlog_data) do
		filtered_death_log[server_name] = {}
		for checksum, entry in pairs(entry_tbl) do
			if filter(server_name, entry) then
				filtered_death_log[server_name][checksum] = entry
			end
		end
	end

	return filtered_death_log
end

function deathlogOrderBy(_deathlog, order_function)
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
function deathlogOrderByFast(_deathlog)
	local list = {}
	local n = 0
	for _, entry_tbl in pairs(_deathlog) do
		for _, v in pairs(entry_tbl) do
			n = n + 1
			list[n] = v
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
	cdf = {}
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
function deathlogGetOrderedNormalized(stats, parameters, ln_mean, ln_std_dev)
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
function deathlogGetOrdered(stats, parameters)
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
	local zones_to_update = deathlog_get_zone_ancestors(entry_map_id)
	
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
end

local function instantiateIfMissing(_stats, server_name, entry, _metadata_list)
	local entry_map_id = entry["map_id"] or entry["instance_id"] or "all"
	local class_id = entry["class_id"] or "all"
	local source_id = entry["source_id"] or "all"
	
	-- Get all zones this entry should contribute to
	local zones_to_update = deathlog_get_zone_ancestors(entry_map_id)

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
function deathlog_calculate_statistics(_deathlog_data)
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
			instantiateIfMissing(stats, server_name, entry, metadata_list)

			local map_id = entry["map_id"] or entry["instance_id"] or "all"
			updateStats(stats, server_name, entry)
		end
	end

	for k, v in ipairs(metadata_list) do
		v["avg_lvl"] = v["sum_lvl"] / v["num_entries"]
	end

	-- local ordered = deathlogGetOrdered(stats, {"all", "all", "all", nil})
	-- for i,v in ipairs(ordered) do
	--   if i < 25 then
	--     print(i, id_to_npc[v[1]], v[2])
	--   end
	-- end

	return stats
end

function deathlog_serializeTable(val, name, skipnewlines, depth)
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
				.. deathlog_serializeTable(v, k, skipnewlines, depth + 1)
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

local function calculateLogNormalParametersForMap(_deathlog_data, map_id)
	local function filter_by_map_function(servername, entry)
		-- For Root Map, include all data
		if map_id == deathlog_ROOT_MAP_ID then
			return true
		end
		-- For container zones (continents, Outland), check if entry's zone is a descendant
		if deathlog_is_container_zone(map_id) then
			local entry_map = entry["map_id"] or entry["instance_id"]
			if entry_map then
				local ancestors = deathlog_get_zone_ancestors(entry_map)
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
	local filtered_by_map = deathlogFilter(_deathlog_data, filter_by_map_function)
	local log_normal_params_for_map_id = {}
	log_normal_params_for_map_id["ln_mean"] = {}
	log_normal_params_for_map_id["ln_std_dev"] = {}
	log_normal_params_for_map_id["total"] = {}
	for k, v in pairs(deathlog_class_tbl) do
		log_normal_params_for_map_id["total"][v] = 0
		log_normal_params_for_map_id["ln_mean"][v] = 0
		log_normal_params_for_map_id["ln_std_dev"][v] = 0
	end

	for servername, entry_tbl in pairs(filtered_by_map) do
		for _, v in pairs(entry_tbl) do
			log_normal_params_for_map_id["total"][v["class_id"]] = log_normal_params_for_map_id["total"][v["class_id"]]
				+ 1
			log_normal_params_for_map_id["ln_mean"][v["class_id"]] = log_normal_params_for_map_id["ln_mean"][v["class_id"]]
				+ math.log(v["level"])
		end
	end

	for k, v in pairs(deathlog_class_tbl) do
		log_normal_params_for_map_id["ln_mean"][v] = log_normal_params_for_map_id["ln_mean"][v]
			/ log_normal_params_for_map_id["total"][v]
	end

	for servername, entry_tbl in pairs(filtered_by_map) do
		for _, v in pairs(entry_tbl) do
			log_normal_params_for_map_id["ln_std_dev"][v["class_id"]] = log_normal_params_for_map_id["ln_std_dev"][v["class_id"]]
				+ (math.log(v["level"]) - log_normal_params_for_map_id["ln_mean"][v["class_id"]])
					* (math.log(v["level"]) - log_normal_params_for_map_id["ln_mean"][v["class_id"]])
		end
	end

	for k, v in pairs(deathlog_class_tbl) do
		log_normal_params_for_map_id["ln_std_dev"][v] = log_normal_params_for_map_id["ln_std_dev"][v]
			/ log_normal_params_for_map_id["total"][v]
	end
	return log_normal_params_for_map_id
end

function deathlog_calculateClassData(_deathlog_data)
	local class_data = {} --[class_id] -> {lvl,}

	for servername, entry_tbl in pairs(_deathlog_data) do
		for _, v in pairs(entry_tbl) do
			if class_data[v["class_id"]] == nil then
				class_data[v["class_id"]] = {}
			end
			class_data[v["class_id"]][#class_data[v["class_id"]] + 1] = v["level"]
		end
	end
	return class_data
end

function deathlog_calculateLogNormalParameters(_deathlog_data)
	local log_normal_params = {}
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
	return log_normal_params
end

function deathlog_calculateSkullLocs(_deathlog_data)
	local skull_locs = {}
	for servername, entry_tbl in pairs(_deathlog_data) do
		for _, v in pairs(entry_tbl) do
			if v["map_id"] then
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

function deathlog_setTooltipFromEntry(_entry)
	if _entry == nil then
		return
	end
	local _name = _entry["name"]
	local _level = _entry["level"]
	local _guild = _entry["guild"] or ""
	local _race = nil
	local _class = nil
	local _pvp_source_name = _entry["extra_data"] and _entry["extra_data"]["pvp_source_name"]
	local _source = id_to_npc[_entry["source_id"]]
		or deathlog_environment_damage[_entry["source_id"]]
		or DeathNotificationLib.DecodePvPSource(_entry["source_id"], _pvp_source_name)
		or ""
	if _source == "" then
		if _entry["predicted_source"] then
			_source = _entry["predicted_source"]
		else
			local predicted = deathlogPredictSource(_entry)
			if predicted then
				_entry["predicted_source"] = predicted
				_source = predicted
			end
		end
	end
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
	deathlog_setTooltip(_name, _level, _guild, _race, _class, _source, _zone, _date, _playtime, _last_words)
end

function deathlog_setTooltip(_name, _lvl, _guild, _race, _class, _source, _zone, _date, _playtime, _last_words)
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

	if deathlog_settings["minilog"]["tooltip_name"] and _name then
		GameTooltip:AddLine(Deathlog_L.name_word .. ": " .. _name, 1, 1, 1)
	end
	if deathlog_settings["minilog"]["tooltip_guild"] and _guild and _guild ~= "" then
		GameTooltip:AddLine(Deathlog_L.guild_word .. ": " .. _guild, 1, 1, 1)
	end

	if deathlog_settings["minilog"]["tooltip_race"] and _race and _race ~= "" then
		GameTooltip:AddLine(Deathlog_L.race_word .. ": " .. _race, 1, 1, 1)
	end

	if deathlog_settings["minilog"]["tooltip_class"] and _class and _class ~= "" then
		GameTooltip:AddLine(Deathlog_L.class_word .. ": " .. _class, 1, 1, 1)
	end
	if deathlog_settings["colored_tooltips"] == nil or deathlog_settings["colored_tooltips"] == false then
		if deathlog_settings["minilog"]["tooltip_killedby"] and _source then
			GameTooltip:AddLine(Deathlog_L.killed_by_word .. ": " .. _source, 1, 1, 1)
		end
		if deathlog_settings["minilog"]["tooltip_zone"] and _zone then
			GameTooltip:AddLine(Deathlog_L.zone_instance_word .. ": " .. _zone, 1, 1, 1)
		end
	else
		if deathlog_settings["minilog"]["tooltip_killedby"] and _source then
			GameTooltip:AddLine(Deathlog_L.killed_by_word .. ": |cfffda172" .. _source .. "|r", 1, 1, 1)
		end
		if deathlog_settings["minilog"]["tooltip_zone"] and _zone then
			GameTooltip:AddLine(Deathlog_L.zone_instance_word .. ": |cff9fe2bf" .. _zone .. "|r", 1, 1, 1)
		end
	end

	if deathlog_settings["minilog"]["tooltip_date"] and _date then
		GameTooltip:AddLine(Deathlog_L.date_word .. ": " .. _date, 1, 1, 1)
	end

	if deathlog_settings["minilog"]["tooltip_playtime"] then
		if _playtime and _playtime ~= "" then
			GameTooltip:AddLine(Deathlog_L.playtime_word .. ": " .. _playtime, 1, 1, 1)
		end
	end

	if deathlog_settings["minilog"]["tooltip_lastwords"] then
		if _last_words and _last_words ~= "" then
			GameTooltip:AddLine(Deathlog_L.last_words_word .. ": " .. _last_words, 1, 1, 0, true)
		end
	end
end

deathlog_record_econ_stats = deathlog_record_econ_stats or {}

local record_econ_handler = nil
local record_econ_timer = nil
local record_econ_start_time = GetServerTime()
local logged_already = {}

-- Only enable recording if guild opts in, e.g. :M:Hardcore:
local function registerRecorders()
	local guild_info_text = GetGuildInfoText()
	if guild_info_text then
		local _, g, k = string.split(":", guild_info_text)
		if g and g == "M" and k then
			record_econ_handler = CreateFrame("Frame")
			local start_gold = GetMoney()
			local _v = IsAddOnLoaded(k)
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
