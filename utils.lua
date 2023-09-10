--
--[[
Copyright 2023 Yazpad
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

deathlog_instance_tbl = {
	["Shadowfang Keep"] = 33,
	["Stormwind Stockade"] = 34,
	["Deadmines"] = 36,
	["Wailing Caverns"] = 43,
	["Razorfen Kraul"] = 47,
	["Blackfathom Deeps"] = 48,
	["Uldaman"] = 70,
	["Gnomeregan"] = 90,
	["Sunken Temple"] = 109,
	["Razorfen Downs"] = 129,
	["Scarlet Monastery"] = 189,
	["Zul'Farrak"] = 209,
	["Blackrock Spire"] = 229,
	["Blackrock Depths"] = 230,
	["Scholomance"] = 289,
	["Stratholme"] = 329,
	["Maraudon"] = 349,
	["Ragefire Chasm"] = 389,
	["Dire Maul"] = 429,
}

deathlog_id_to_instance_tbl = {}
for k, v in pairs(deathlog_instance_tbl) do
	deathlog_id_to_instance_tbl[v] = k
end

deathlog_zone_tbl = {
	["Azeroth"] = 947,
	["Durotar"] = 1411,
	["Mulgore"] = 1412,
	["The Barrens"] = 1413,
	["Kalimdor"] = 1414,
	["Eastern Kingdoms"] = 1415,
	["Alterac Mountains"] = 1416,
	["Arathi Highlands"] = 1417,
	["Badlands"] = 1418,
	["Blasted Lands"] = 1419,
	["Tirisfal Glades"] = 1420,
	["Silverpine Forest"] = 1421,
	["Western Plaguelands"] = 1422,
	["Eastern Plaguelands"] = 1423,
	["Hillsbrad Foothills"] = 1424,
	["The Hinterlands"] = 1425,
	["Dun Morogh"] = 1426,
	["Searing Gorge"] = 1427,
	["Burning Steppes"] = 1428,
	["Elwynn Forest"] = 1429,
	["Deadwind Pass"] = 1430,
	["Duskwood"] = 1431,
	["Loch Modan"] = 1432,
	["Redridge Mountains"] = 1433,
	["Stranglethorn Vale"] = 1434,
	["Swamp of Sorrows"] = 1435,
	["Westfall"] = 1436,
	["Wetlands"] = 1437,
	["Teldrassil"] = 1438,
	["Darkshore"] = 1439,
	["Ashenvale"] = 1440,
	["Thousand Needles"] = 1441,
	["Stonetalon Mountains"] = 1442,
	["Desolace"] = 1443,
	["Feralas"] = 1444,
	["Dustwallow Marsh"] = 1445,
	["Tanaris"] = 1446,
	["Azshara"] = 1447,
	["Felwood"] = 1448,
	["Un'Goro Crater"] = 1449,
	["Moonglade"] = 1450,
	["Silithus"] = 1451,
	["Winterspring"] = 1452,
}

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

deathlog_class_colors = {}
for k, _ in pairs(deathlog_class_tbl) do
	deathlog_class_colors[k] = RAID_CLASS_COLORS[string.upper(k)]
end
deathlog_class_colors["Shaman"]:SetRGBA(36 / 255, 89 / 255, 255 / 255, 1)

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

local function calculateCDF(ln_mean, ln_std_dev)
	local function logNormal(x, mean, sigma)
		return (1 / (x * sigma * sqrt(2 * 3.14)))
			* exp((-1 / 2) * ((math.log(x) - mean) / sigma) * ((math.log(x) - mean) / sigma))
	end
	cdf = {}
	cdf[1] = logNormal(1, ln_mean, sqrt(ln_std_dev))
	for i = 2, 60 do
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

	for i = 1, 60 do
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
			table.insert(unordered_list, { k, postfix_stats["num_entries"] })
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
	local map_id = entry["map_id"] or entry["instance_id"] or "all"

	updateEntry(stats["all"]["all"]["all"]["all"], entry)

	updateEntry(stats[server_name]["all"]["all"]["all"], entry)

	updateEntry(stats["all"][map_id]["all"]["all"], entry)
	updateEntry(stats[server_name][map_id]["all"]["all"], entry)

	updateEntry(stats["all"]["all"][entry["class_id"]]["all"], entry)
	updateEntry(stats["all"][map_id][entry["class_id"]]["all"], entry)
	updateEntry(stats[server_name][map_id][entry["class_id"]]["all"], entry)

	updateEntry(stats["all"]["all"]["all"][entry["source_id"]], entry)
	updateEntry(stats["all"]["all"][entry["class_id"]][entry["source_id"]], entry)
	updateEntry(stats["all"][map_id][entry["class_id"]][entry["source_id"]], entry)
	updateEntry(stats["all"][map_id]["all"][entry["source_id"]], entry)
	updateEntry(stats[server_name][map_id][entry["class_id"]][entry["source_id"]], entry)
end

local function instantiateIfMissing(_stats, server_name, entry, _metadata_list)
	local map_id = entry["map_id"] or entry["instance_id"] or "all"
	local class_id = entry["class_id"] or "all"
	local source_id = entry["source_id"] or "all"

	if _stats[server_name] == nil then
		_stats[server_name] = {
			["all"] = {
				["all"] = {
					["all"] = generate_player_metadata(_metadata_list),
				},
			},
		}
	end

	if _stats["all"][map_id] == nil then
		_stats["all"][map_id] = {
			["all"] = {
				["all"] = generate_player_metadata(_metadata_list),
			},
		}
	end

	if _stats[server_name][map_id] == nil then
		_stats[server_name][map_id] = {
			["all"] = {
				["all"] = generate_player_metadata(_metadata_list),
			},
		}
	end

	if _stats["all"]["all"][class_id] == nil then
		_stats["all"]["all"][class_id] = {
			["all"] = generate_player_metadata(_metadata_list),
		}
	end

	if _stats["all"][map_id][class_id] == nil then
		_stats["all"][map_id][class_id] = {
			["all"] = generate_player_metadata(_metadata_list),
		}
	end

	if _stats[server_name][map_id][class_id] == nil then
		_stats[server_name][map_id][class_id] = {
			["all"] = generate_player_metadata(_metadata_list),
		}
	end

	if _stats["all"]["all"]["all"][source_id] == nil then
		_stats["all"]["all"]["all"][source_id] = generate_player_metadata(_metadata_list)
	end
	if _stats["all"]["all"][class_id][source_id] == nil then
		_stats["all"]["all"][class_id][source_id] = generate_player_metadata(_metadata_list)
	end
	if _stats["all"][map_id][class_id][source_id] == nil then
		_stats["all"][map_id][class_id][source_id] = generate_player_metadata(_metadata_list)
	end
	if _stats["all"][map_id]["all"][source_id] == nil then
		_stats["all"][map_id]["all"][source_id] = generate_player_metadata(_metadata_list)
	end
	if _stats[server_name][map_id][class_id][source_id] == nil then
		_stats[server_name][map_id][class_id][source_id] = generate_player_metadata(_metadata_list)
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
		if map_id == 947 then
			return true
		end
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
	for _, v in pairs(deathlog_zone_tbl) do
		log_normal_params[v] = calculateLogNormalParametersForMap(_deathlog_data, v)
	end

	for _, v in pairs(deathlog_instance_tbl) do
		log_normal_params[v] = calculateLogNormalParametersForMap(_deathlog_data, v)
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
