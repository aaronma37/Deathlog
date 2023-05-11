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
    for k,v in pairs(t) do
      t2[k] = v
    end
    return t2
end

-- Tue Apr 18 21:36:54 2023
function deathlogConvertStringDateUnix(s)
  if tonumber(s) then return s end
  p="%a+ (%a+) (%d+) (%d+):(%d+):(%d+) (%d+)"
  month,day,hour,minute,sec,year=s:match(p)
  if month == nil or day == nil or hour == nil or minute == nil or sec == nil or year == nil then  
    p="%a+ (%a+)  (%d+) (%d+):(%d+):(%d+) (%d+)"
    month,day,hour,minute,sec,year=s:match(p)
  end
  if month == nil or day == nil or hour == nil or minute == nil or sec == nil or year == nil then  
    return nil
  end
  MON={Jan=1,Feb=2,Mar=3,Apr=4,May=5,Jun=6,Jul=7,Aug=8,Sep=9,Oct=10,Nov=11,Dec=12}
  month=MON[month]
  offset=time()-time(date("!*t"))
  return time({day=day,month=month,year=year,hour=hour,minute=minute,sec=sec})+offset
end

function deathlog_fletcher16(name, guild, level, source)
	local data = name .. (guild or "") .. level .. source
	local sum1 = 0
	local sum2 = 0
        for index=1,#data do
		sum1 = (sum1 + string.byte(string.sub(data,index,index))) % 255;
		sum2 = (sum2 + sum1) % 255;
        end
        return name .. "-" .. bit.bor(bit.lshift(sum2,8), sum1)
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
  for server_name,entry_tbl in pairs(_deathlog) do
    for _,v in pairs(entry_tbl) do
      unordered_list[#unordered_list+1] = v
    end
  end
  for i, v in spairs(unordered_list, order_function) do
	  table.insert(ordered, v)
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
  for _,v in ipairs(parameters) do
    if active then
      post_parameters[#post_parameters+1] = v
    else
      if v == nil then
	active = true
      else
	if prefix_stats[v] == nil then return nil end
	prefix_stats=prefix_stats[v]
      end
    end
  end

  for k,v in pairs(prefix_stats) do 
    if k ~= "all" then 
      local postfix_stats = v
      for _,v in ipairs(post_parameters) do
	postfix_stats = postfix_stats[v]
      end
      table.insert(unordered_list, {k, postfix_stats["num_entries"]})
    end
  end
  for i, v in spairs(unordered_list, function(t,a,b) return t[b][2] < t[a][2] end) do
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
	  ["all"] = generate_player_metadata(_metadata_list)
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
	  ["all"] = generate_player_metadata(metadata_list)
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

  for k,v in ipairs(metadata_list) do
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
