--[[
DeathNotificationLib~PredictSource.lua

Heatmap-based death source prediction.

Given a PlayerData entry with map_pos and map_id, attempts to predict
which NPC (or environmental hazard) killed the player by searching
precomputed heatmap data around the death location.

The caller passes a search_radius argument (defaults to 5).
This lets each addon control the prediction via its own settings.
--]]

local _dnl = DeathNotificationLib.Internal ---@class _dnl
if not _dnl then return end

local floor = math.floor
local abs   = math.abs

---------------------------------------------------------------------------
-- Core algorithm
---------------------------------------------------------------------------

--- Check whether precomputed heatmap data is available.
---@return boolean
local function hasHeatmapData()
	return type(_dnl.D.HEATMAP_INTENSITY) == "table"
		and type(_dnl.D.HEATMAP_CREATURE_SUBSET) == "table"
end

--- Check a single (map_id, x, y) coordinate against the heatmap.
---@return string|nil  predicted source name with trailing "*"
local function checkCoordinate(map_id, x, y)
	if x <= 0 or x >= 100 or y <= 0 or y >= 100 then return nil end

	local intensity_map = _dnl.D.HEATMAP_INTENSITY[map_id]
	if not intensity_map or not intensity_map[x] or not intensity_map[x][y] then
		return nil
	end

	local creature_map = _dnl.D.HEATMAP_CREATURE_SUBSET[map_id]
	if not creature_map then return nil end

	for npc_id, grid in pairs(creature_map) do
		if grid[x] and grid[x][y] then
			if _dnl.D.ID_TO_NPC[npc_id] then
				return _dnl.D.ID_TO_NPC[npc_id] .. "*"
			end
			if _dnl.ENVIRONMENT_DAMAGE[npc_id] then
				return _dnl.ENVIRONMENT_DAMAGE[npc_id] .. "*"
			end
		end
	end

	return nil
end

--- Search expanding rings around (base_x, base_y) on a given map.
---@return string|nil
local function searchAroundPosition(map_id, base_x, base_y, search_radius)
	local result = checkCoordinate(map_id, base_x, base_y)
	if result then return result end

	for radius = 1, search_radius do
		for dx = -radius, radius do
			for dy = -radius, radius do
				if abs(dx) == radius or abs(dy) == radius then
					result = checkCoordinate(map_id, base_x + dx, base_y + dy)
					if result then return result end
				end
			end
		end
	end

	return nil
end

--- Predict the death source for a PlayerData entry.
---
--- @param entry table  PlayerData (must have map_pos and map_id)
--- @param search_radius number|nil  How many cells to search outward (default 5)
--- @return string|nil  predicted source name (suffixed with "*") or nil
function _dnl.predictSource(entry, search_radius)
	if not hasHeatmapData() then return nil end

	local map_pos = entry and entry.map_pos
	local map_id  = entry and tonumber(entry.map_id)
	if not map_pos or not map_id then return nil end

	local xx, yy = strsplit(",", map_pos, 2)
	if not xx or not tonumber(xx) then return nil end

	search_radius = search_radius or 5

	-- Try the entry's own map first
	local base_x = floor(tonumber(xx) * 100 + 0.5)
	local base_y = floor(tonumber(yy) * 100 + 0.5)

	local result = searchAroundPosition(map_id, base_x, base_y, search_radius)
	if result then return result end

	-- Walk up the map hierarchy with coordinate conversion
	local pos = { x = tonumber(xx), y = tonumber(yy) }
	local cont, cont_pos = C_Map.GetWorldPosFromMapPos(map_id, pos)
	if not cont then return nil end

	local current_map_id = map_id
	for _ = 1, 5 do
		local map_info = C_Map.GetMapInfo(current_map_id)
		if not map_info or not map_info.parentMapID or map_info.parentMapID == 0 then
			break
		end

		local parent_map_id = map_info.parentMapID
		local m, parent_pos = C_Map.GetMapPosFromWorldPos(cont, cont_pos, parent_map_id)
		if m then
			local parent_x = floor(parent_pos.x * 100 + 0.5)
			local parent_y = floor(parent_pos.y * 100 + 0.5)

			result = searchAroundPosition(parent_map_id, parent_x, parent_y, search_radius)
			if result then return result end
		end

		current_map_id = parent_map_id
	end

	return nil
end

--#region API

DeathNotificationLib.PredictSource = _dnl.predictSource

--#endregion