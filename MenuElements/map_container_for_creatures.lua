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
local wrapped_map_container = CreateFrame("Frame")
wrapped_map_container:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
wrapped_map_container:SetSize(500, 500)
wrapped_map_container:Hide()
wrapped_map_container:SetMovable(false)
wrapped_map_container.map_container = Deathlog_MapContainer()

function wrapped_map_container.updateMenuElement(scroll_frame, creature_id, stats_tbl, setMapRegion)
	local _stats = stats_tbl["stats"]
	local best_map = 947
	local num = 0
	for map_id, _ in pairs(_stats["all"]) do
		if
			map_id ~= "all"
			and _stats["all"][map_id]["all"][creature_id]
			and _stats["all"][map_id]["all"][creature_id]["num_entries"] > num
		then
			num = _stats["all"][map_id]["all"][creature_id]["num_entries"]
			best_map = map_id
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
end

function Deathlog_MapContainerForCreatures()
	return wrapped_map_container
end
