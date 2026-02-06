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
local wrapped_map_container = CreateFrame("Frame")
wrapped_map_container:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
wrapped_map_container:SetSize(500, 500)
wrapped_map_container:Hide()
wrapped_map_container:SetMovable(false)
wrapped_map_container.map_container = Deathlog_MapContainer()

function wrapped_map_container.updateMenuElement(scroll_frame, creature_id, stats_tbl, setMapRegion)
	-- Reset any previous state before updating
	Deathlog_MapContainer_resetSkullSet()
	wrapped_map_container.map_container.overlay_highlight:Hide()
	
	local _stats = stats_tbl["stats"]
	local best_map = deathlog_ROOT_MAP_ID
	local best_subzone_count = 0  -- Track best count among subzones only
	
	-- For global death sources (Falling, Drowning, etc. with negative IDs),
	-- use the zone with the most kills (these are everywhere)
	local is_global_source = creature_id < 0
	
	-- Helper to check if a map is a valid descendant of ROOT_MAP_ID
	local function is_valid_map(map_id)
		if map_id == deathlog_ROOT_MAP_ID then return true end
		local ancestors = deathlog_get_zone_ancestors and deathlog_get_zone_ancestors(map_id) or {}
		for _, ancestor in ipairs(ancestors) do
			if ancestor == deathlog_ROOT_MAP_ID then return true end
		end
		return false
	end
	
	for map_id, _ in pairs(_stats["all"]) do
		if
			map_id ~= "all"
			and is_valid_map(map_id)
			and _stats["all"][map_id]["all"][creature_id]
			and _stats["all"][map_id]["all"][creature_id]["num_entries"] > 0
		then
			local count = _stats["all"][map_id]["all"][creature_id]["num_entries"]
			local is_container = deathlog_is_container_zone and deathlog_is_container_zone(map_id)
			
			if is_global_source and not deathlog_should_hide_heatmap(map_id) then
				-- For global sources, just pick the zone with the most kills
				if count > best_subzone_count then
					best_subzone_count = count
					best_map = map_id
				end
			elseif not is_container then
				-- For regular creatures, only consider subzones
				-- Pick the subzone with the most kills
				if count > best_subzone_count then
					best_subzone_count = count
					best_map = map_id
				end
			end
			-- Ignore container zones entirely for regular creatures
		end
	end
	
	wrapped_map_container:SetParent(scroll_frame.frame)
	wrapped_map_container:Show()
	wrapped_map_container:SetPoint("TOPLEFT", scroll_frame.frame, "TOPLEFT", 575, -160)
	wrapped_map_container:SetWidth(700)
	wrapped_map_container:SetHeight(700)
	wrapped_map_container.map_container.updateMenuElement(wrapped_map_container, best_map, stats_tbl, function() end)
	Deathlog_MapContainer_showSkullSet(creature_id)
	wrapped_map_container.map_container.heatmap_checkbox:Hide()
	wrapped_map_container.map_container.heatmap_checkbox.label:Hide()
	wrapped_map_container.map_container.darken_checkbox:Hide()
	wrapped_map_container.map_container.darken_checkbox.label:Hide()
	wrapped_map_container.map_container.map_hint:Hide()
	wrapped_map_container.map_container.overlay_highlight:Hide()
	wrapped_map_container.map_container.allowInput = false
end

function Deathlog_MapContainerForCreatures()
	return wrapped_map_container
end
