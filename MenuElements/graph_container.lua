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

local graph_lines = {}
local graph_container = CreateFrame("frame")

local class_tbl = deathlog_class_tbl
local race_tbl = deathlog_race_tbl
local zone_tbl = deathlog_zone_tbl

function graph_container.updateMenuElement(scroll_frame, current_map_id, stats_tbl, setMapRegion)
	local _log_normal_params = stats_tbl["log_normal_params"]
	graph_container:Show()
	graph_container:SetParent(scroll_frame.frame)
	graph_container.height = 205
	graph_container.width = 380
	graph_container.offsetx = 45
	graph_container.zoomy = 8
	graph_container.offsety = 10
	graph_container:SetPoint("TOPLEFT", 590, -280)
	graph_container:SetWidth(400)
	graph_container:SetHeight(200)
	graph_container:SetFrameLevel(15000)

	if graph_container.heading == nil then
		graph_container.heading = graph_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		graph_container.heading:SetText("Death Level by Class PDF")
		graph_container.heading:SetFont(Deathlog_L.menu_font, 18, "")
		graph_container.heading:SetJustifyV("TOP")
		graph_container.heading:SetTextColor(0.9, 0.9, 0.9)
		graph_container.heading:SetPoint("TOP", graph_container, "TOP", 25, 50)
		graph_container.heading:Show()
	end

	if graph_container.left == nil then
		graph_container.left = graph_container:CreateTexture(nil, "BACKGROUND")
		graph_container.left:SetHeight(8)
		graph_container.left:SetPoint("LEFT", graph_container.heading, "LEFT", -80, 0)
		graph_container.left:SetPoint("RIGHT", graph_container.heading, "LEFT", -5, 0)
		graph_container.left:SetTexture(137057) -- Interface\\Tooltips\\UI-Tooltip-Border
		graph_container.left:SetTexCoord(0.81, 0.94, 0.5, 1)
	end

	if graph_container.right == nil then
		graph_container.right = graph_container:CreateTexture(nil, "BACKGROUND")
		graph_container.right:SetHeight(8)
		graph_container.right:SetPoint("RIGHT", graph_container.heading, "RIGHT", 80, 0)
		graph_container.right:SetPoint("LEFT", graph_container.heading, "RIGHT", 5, 0)
		graph_container.right:SetTexture(137057) -- Interface\\Tooltips\\UI-Tooltip-Border
		graph_container.right:SetTexCoord(0.81, 0.94, 0.5, 1)
	end

	if graph_container.y_label == nil then
		graph_container.y_label = graph_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		graph_container.y_label:SetText("P(lvl)")
		graph_container.y_label:SetFont(Deathlog_L.menu_font, 14, "")
		graph_container.y_label:SetJustifyV("TOP")
		graph_container.y_label:SetTextColor(0.7, 0.7, 0.7)
		graph_container.y_label:SetPoint("BOTTOM", graph_container, "BOTTOM", -165, 225)
		graph_container.y_label:Show()
	end

	if graph_container.x_label == nil then
		graph_container.x_label = graph_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		graph_container.x_label:SetText("Lvl.")
		graph_container.x_label:SetFont(Deathlog_L.menu_font, 14, "")
		graph_container.x_label:SetJustifyV("TOP")
		graph_container.x_label:SetTextColor(0.7, 0.7, 0.7)
		graph_container.x_label:SetPoint("BOTTOM", graph_container, "BOTTOM", 25, -15)
		graph_container.x_label:Show()
	end

	local function createLine(name, start_coords, end_coords, color, label)
		if graph_lines[name] == nil then
			graph_lines[name] = graph_container:CreateLine(nil, "OVERLAY")
			graph_lines[name].start_point = CreateFrame("frame", nil, graph_container)
			graph_lines[name].end_point = CreateFrame("frame", nil, graph_container)
		end
		graph_lines[name]:SetTexture("interface/buttons/white8x8")
		graph_lines[name]:SetThickness(1)
		graph_lines[name].start_point:SetSize(1, 1)
		graph_lines[name].start_point:Show()
		graph_lines[name].end_point:SetSize(1, 1)
		graph_lines[name].end_point:SetPoint("BOTTOMLEFT", graph_container, "BOTTOMLEFT", end_coords[1], end_coords[2])
		graph_lines[name].start_point:SetPoint(
			"BOTTOMLEFT",
			graph_container,
			"BOTTOMLEFT",
			start_coords[1],
			start_coords[2]
		)
		graph_lines[name].end_point:Show()
		graph_lines[name]:SetStartPoint("CENTER", graph_lines[name].start_point, 0, 0)
		graph_lines[name]:SetEndPoint("CENTER", graph_lines[name].end_point, 0, 0)
		if color == nil then
			graph_lines[name]:SetVertexColor(0.5, 0.5, 0.5, 0.5)
		else
			graph_lines[name]:SetVertexColor(color.r, color.g, color.b, 0.5)
		end
		if label then
			if graph_lines[name].label == nil then
				graph_lines[name].label = graph_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			end
			graph_lines[name].label:SetPoint("BOTTOMLEFT", start_coords[1] + label[2], start_coords[2] + label[3])
			graph_lines[name].label:SetText(label[1])
			graph_lines[name].label:SetFont(Deathlog_L.menu_font, 10, "")
			graph_lines[name].label:SetTextColor(0.7, 0.7, 0.7, 0.7)
		end
		graph_lines[name]:Show()
	end

	createLine(
		"y_axis",
		{ graph_container.offsetx, graph_container.height + graph_container.offsety },
		{ graph_container.offsetx, graph_container.offsety }
	)
	createLine(
		"x_axis",
		{ graph_container.offsetx, graph_container.offsety },
		{ graph_container.offsetx + graph_container.width, graph_container.offsety }
	)

	local y_values = {}
	for k, v in pairs(class_tbl) do
		y_values[v] = {}
	end
	local max_y = 0
	local function logNormal(x, mean, sigma)
		local d1 = (x * sigma * sqrt(2 * 3.14))
		if d1 > 0 then
			return (1 / d1) * exp((-1 / 2) * ((log(x) - mean) / sigma) * ((log(x) - mean) / sigma))
		end
		return 0.0
	end
	for k, v in pairs(class_tbl) do
		if
			_log_normal_params[current_map_id]
			and _log_normal_params[current_map_id][v]
			and _log_normal_params[current_map_id][v][1]
		then
			for i = 1, 60 do
				y_values[v][i] = logNormal(
					i,
					_log_normal_params[current_map_id][v][1],
					sqrt(_log_normal_params[current_map_id][v][2])
				)
				if y_values[v][i] > max_y and _log_normal_params[current_map_id][v][3] > 2 then
					max_y = y_values[v][i]
				end
			end
		end
	end
	if max_y > 0 then
		graph_container.zoomy = 1 / max_y
	else
		graph_container.zoomy = 1
	end

	for i = 1, 5 do
		createLine(
			"y_tick_" .. i .. "0",
			{ graph_container.offsetx, (graph_container.height + graph_container.offsety) * i / 5 },
			{ graph_container.offsetx + 5, (graph_container.height + graph_container.offsety) * i / 5 },
			nil,
			{ string.format("%.1f", i / 5 / graph_container.zoomy * 100.0) .. "%", -23, -5 }
		)
	end

	for i = 1, 6 do
		createLine(
			"x_tick_" .. i .. "0",
			{ graph_container.offsetx + graph_container.width * i / 6, graph_container.offsety },
			{ graph_container.offsetx + graph_container.width * i / 6, graph_container.offsety + 5 },
			nil,
			{ i .. "0", -5, -11 }
		)
	end

	local class_colors = deathlog_class_colors
	if _log_normal_params[current_map_id] then
		for i = 2, 60 do
			for k, v in pairs(class_tbl) do
				if _log_normal_params[current_map_id][v] and _log_normal_params[current_map_id][v][1] then
					-- level_num[v][i] = level_num[v][i] / total[v]
					-- createLine(k..i, {25+(i-2)/60*375,level_num[v][i-1]*100*8}, {25+(i-1)/60*375,level_num[v][i]*100*8}, RAID_CLASS_COLORS[string.upper(k)])
					local y1 = logNormal(
						i - 1,
						_log_normal_params[current_map_id][v][1],
						sqrt(_log_normal_params[current_map_id][v][2])
					)
					local y2 = logNormal(
						i,
						_log_normal_params[current_map_id][v][1],
						sqrt(_log_normal_params[current_map_id][v][2])
					)
					createLine(k .. i, {
						graph_container.offsetx + (i - 2) / 60 * graph_container.width,
						y1 * graph_container.height * graph_container.zoomy + graph_container.offsety,
					}, {
						graph_container.offsetx + (i - 1) / 60 * graph_container.width,
						y2 * graph_container.height * graph_container.zoomy + graph_container.offsety,
					}, class_colors[k])

					if _log_normal_params[current_map_id][v][3] < 3 and graph_lines[k .. i] then
						graph_lines[k .. i]:Hide()
					end
				else
					if graph_lines[k .. i] then
						graph_lines[k .. i]:Hide()
					end
				end
			end
		end
	end

	graph_container:SetScript("OnHide", function()
		graph_container.heading:Hide()
		graph_container.left:Hide()
		graph_container.right:Hide()

		for _, v in pairs(graph_lines) do
			v:Hide()
		end
	end)

	graph_container:SetScript("OnShow", function()
		graph_container.heading:Show()
		graph_container.left:Show()
		graph_container.right:Show()
	end)
end

function Deathlog_GraphContainer()
	return graph_container
end
