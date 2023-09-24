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

function graph_container.updateMenuElement(scroll_frame, class_id, stats_tbl, setMapRegion, model)
	if model == nil then
		model = "Kaplan-Meier"
	end

	local class_log_normal_params = precomputed_log_normal_params["all"]
	local kaplan_meier = precomputed_kaplan_meier
	graph_container:Show()
	graph_container:SetParent(scroll_frame.frame)
	graph_container.height = 140
	graph_container.width = 400
	graph_container.offsetx = 25
	graph_container.zoomy = 8
	graph_container.offsety = -30
	graph_container:SetPoint("TOPLEFT", 590, -70)
	graph_container:SetWidth(400)
	graph_container:SetHeight(140)
	graph_container:SetFrameLevel(15000)

	if graph_container.heading == nil then
		graph_container.heading = graph_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		graph_container.heading:SetText("Death Level by Class PDF")
		graph_container.heading:SetFont(Deathlog_L.class_font, 18, "")
		graph_container.heading:SetJustifyV("TOP")
		graph_container.heading:SetTextColor(0.9, 0.9, 0.9)
		graph_container.heading:SetPoint("TOP", graph_container, "TOP", 25, 0)
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

	local function createLine(name, start_coords, end_coords, color, label, alpha)
		if alpha == nil then
			alpha = 0.5
		end
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
			graph_lines[name]:SetVertexColor(color.r, color.g, color.b, alpha)
		end
		if label then
			if graph_lines[name].label == nil then
				graph_lines[name].label = graph_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			end
			graph_lines[name].label:SetPoint("BOTTOMLEFT", start_coords[1] + label[2], start_coords[2] + label[3])
			graph_lines[name].label:SetText(label[1])
			graph_lines[name].label:SetFont(Deathlog_L.class_font, 10, "")
			graph_lines[name].label:SetTextColor(0.7, 0.7, 0.7, 0.7)
		end
		graph_lines[name]:Show()
	end

	local function createPDF()
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
			return (1 / (x * sigma * sqrt(2 * 3.14)))
				* exp((-1 / 2) * ((log(x) - mean) / sigma) * ((log(x) - mean) / sigma))
		end
		for k, v in pairs(class_tbl) do
			if class_log_normal_params and class_log_normal_params[v][1] then
				for i = 1, 60 do
					y_values[v][i] = logNormal(i, class_log_normal_params[v][1], class_log_normal_params[v][2])
					if y_values[v][i] > max_y then
						max_y = y_values[v][i]
					end
				end
			end
		end
		graph_container.zoomy = 1 / max_y

		for i = 1, 5 do
			createLine(
				"y_tick_" .. i .. "0",
				{ graph_container.offsetx, graph_container.height * i / 5 + graph_container.offsety },
				{ graph_container.offsetx + 5, graph_container.height * i / 5 + graph_container.offsety },
				nil,
				{
					string.format("%.1f", i / 5 / graph_container.zoomy * 100.0) .. "%",
					-23,
					-5,
				}
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
		if class_log_normal_params then
			for i = 2, 60 do
				for k, v in pairs(class_tbl) do
					local alpha = 0.2
					if class_id == v then
						alpha = 1
					end
					if class_log_normal_params[v][1] then
						local y1 = logNormal(i - 1, class_log_normal_params[v][1], class_log_normal_params[v][2])
						local y2 = logNormal(i, class_log_normal_params[v][1], class_log_normal_params[v][2])
						createLine(k .. i, {
							graph_container.offsetx + (i - 2) / 60 * graph_container.width,
							y1 * graph_container.height * graph_container.zoomy + graph_container.offsety,
						}, {
							graph_container.offsetx + (i - 1) / 60 * graph_container.width,
							y2 * graph_container.height * graph_container.zoomy + graph_container.offsety,
						}, class_colors[k], nil, alpha)
					else
						if graph_lines[k .. i] then
							graph_lines[k .. i]:Hide()
						end
					end
				end
			end
		end
	end

	local function createCDF(y_offset)
		local _offsety = y_offset + graph_container.offsety
		createLine(
			"cdf_y_axis",
			{ graph_container.offsetx, graph_container.height + _offsety },
			{ graph_container.offsetx, _offsety }
		)
		createLine(
			"cdf_x_axis",
			{ graph_container.offsetx, _offsety },
			{ graph_container.offsetx + graph_container.width, _offsety }
		)

		local y_values = {}
		for k, v in pairs(class_tbl) do
			y_values[v] = {}
		end
		local max_y = 0
		local function logNormal(x, mean, sigma)
			return (1 / (x * sigma * sqrt(2 * 3.14)))
				* exp((-1 / 2) * ((log(x) - mean) / sigma) * ((log(x) - mean) / sigma))
		end
		for k, v in pairs(class_tbl) do
			if class_log_normal_params and class_log_normal_params[v][1] then
				for i = 1, 60 do
					y_values[v][i] = logNormal(i, class_log_normal_params[v][1], class_log_normal_params[v][2])
					if y_values[v][i] > max_y then
						max_y = y_values[v][i]
					end
				end
			end
		end
		graph_container.zoomy = 1

		for i = 1, 5 do
			createLine(
				"cdf_y_tick_" .. i .. "0",
				{ graph_container.offsetx, (graph_container.height + 0) * i / 5 + _offsety },
				{ graph_container.offsetx + 5, (graph_container.height + 0) * i / 5 + _offsety },
				nil,
				{ string.format("%.1f", i / 5 / graph_container.zoomy * 100.0) .. "%", -23, -5 }
			)
		end

		for i = 1, 6 do
			createLine(
				"cdf_x_tick_" .. i .. "0",
				{ graph_container.offsetx + graph_container.width * i / 6, _offsety },
				{ graph_container.offsetx + graph_container.width * i / 6, _offsety + 5 },
				nil,
				{ i .. "0", -5, -11 }
			)
		end

		if model == "LogNormal" then
			local class_colors = deathlog_class_colors
			if class_log_normal_params then
				local cdf = {}
				for i = 2, 60 do
					for k, v in pairs(class_tbl) do
						if cdf[v] == nil then
							cdf[v] =
								Deathlog_CalculateCDF2(class_log_normal_params[v][1], class_log_normal_params[v][2])
						end
						local alpha = 0.2
						if class_id == v then
							alpha = 1
						end
						if class_log_normal_params[v][1] then
							createLine("cdf" .. k .. i, {
								graph_container.offsetx + (i - 1) / 60 * graph_container.width,
								(1 - cdf[v][i - 1]) * graph_container.height + _offsety,
							}, {
								graph_container.offsetx + i / 60 * graph_container.width,
								(1 - cdf[v][i]) * graph_container.height + _offsety,
							}, class_colors[k], nil, alpha)
						else
							if graph_lines["cdf" .. k .. i] then
								graph_lines["cdf" .. k .. i]:Hide()
							end
						end
					end
				end
			end
		elseif model == "Kaplan-Meier" then
			local class_colors = deathlog_class_colors
			for i = 2, 60 do
				for k, v in pairs(class_tbl) do
					local alpha = 0.2
					if class_id == v then
						alpha = 1
					end
					createLine("cdf" .. k .. i, {
						graph_container.offsetx + (i - 1) / 60 * graph_container.width,
						kaplan_meier[v][i - 1] * graph_container.height + _offsety,
					}, {
						graph_container.offsetx + i / 60 * graph_container.width,
						kaplan_meier[v][i] * graph_container.height + _offsety,
					}, class_colors[k], nil, alpha)
				end
			end
		end
	end

	createPDF()

	if graph_container.cdf_heading == nil then
		graph_container.cdf_heading = graph_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		graph_container.cdf_heading:SetText("Class Level Expectancy (1-CDF(x))")
		graph_container.cdf_heading:SetFont(Deathlog_L.class_font, 18, "")
		graph_container.cdf_heading:SetJustifyV("TOP")
		graph_container.cdf_heading:SetTextColor(0.9, 0.9, 0.9)
		graph_container.cdf_heading:SetPoint("TOP", graph_container, "TOP", 25, -210)
		graph_container.cdf_heading:Show()
	end

	if graph_container.cdf_left == nil then
		graph_container.cdf_left = graph_container:CreateTexture(nil, "BACKGROUND")
		graph_container.cdf_left:SetHeight(8)
		graph_container.cdf_left:SetPoint("LEFT", graph_container.cdf_heading, "LEFT", -60, 0)
		graph_container.cdf_left:SetPoint("RIGHT", graph_container.cdf_heading, "LEFT", -5, 0)
		graph_container.cdf_left:SetTexture(137057) -- Interface\\Tooltips\\UI-Tooltip-Border
		graph_container.cdf_left:SetTexCoord(0.81, 0.94, 0.5, 1)
	end

	if graph_container.cdf_right == nil then
		graph_container.cdf_right = graph_container:CreateTexture(nil, "BACKGROUND")
		graph_container.cdf_right:SetHeight(8)
		graph_container.cdf_right:SetPoint("RIGHT", graph_container.cdf_heading, "RIGHT", 60, 0)
		graph_container.cdf_right:SetPoint("LEFT", graph_container.cdf_heading, "RIGHT", 5, 0)
		graph_container.cdf_right:SetTexture(137057) -- Interface\\Tooltips\\UI-Tooltip-Border
		graph_container.cdf_right:SetTexCoord(0.81, 0.94, 0.5, 1)
	end
	createCDF(-220)

	if graph_container.cdf_desc == nil then
		graph_container.cdf_desc = graph_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		graph_container.cdf_desc:SetText("Calculated using the lognormal distribution PDF.")
		graph_container.cdf_desc:SetFont(Deathlog_L.class_font, 11, "")
		graph_container.cdf_desc:SetJustifyV("TOP")
		graph_container.cdf_desc:SetTextColor(0.7, 0.7, 0.7)
		graph_container.cdf_desc:SetPoint("TOP", graph_container, "TOP", 25, -405)
		graph_container.cdf_desc:Show()
	end

	if graph_container.desc == nil then
		graph_container.desc = graph_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		graph_container.desc:SetText("Calculated using MLE on right truncated data and fitting lognormal.")
		graph_container.desc:SetFont(Deathlog_L.class_font, 11, "")
		graph_container.desc:SetJustifyV("TOP")
		graph_container.desc:SetTextColor(0.7, 0.7, 0.7)
		graph_container.desc:SetPoint("TOP", graph_container, "TOP", 25, -185)
		graph_container.desc:Show()
	end

	graph_container:SetScript("OnHide", function()
		graph_container.heading:Hide()
		graph_container.left:Hide()
		graph_container.right:Hide()

		graph_container.cdf_heading:Hide()
		graph_container.cdf_left:Hide()
		graph_container.cdf_right:Hide()

		for _, v in pairs(graph_lines) do
			v:Hide()
		end
	end)

	graph_container:SetScript("OnShow", function()
		graph_container.cdf_heading:Show()
		graph_container.cdf_left:Show()
		graph_container.cdf_right:Show()
	end)
end

function Deathlog_ClassGraphContainer()
	return graph_container
end
