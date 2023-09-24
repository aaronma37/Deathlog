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
local average_class_container = CreateFrame("Frame")
average_class_container:SetSize(100, 100)
average_class_container:Show()

local class_font = Deathlog_L.class_font

local class_tbl = deathlog_class_tbl
local race_tbl = deathlog_race_tbl
local zone_tbl = deathlog_zone_tbl

local green_shade = "ff50c878"

local average_class_subtitles = {
	{ "Class", 20, "LEFT", 60 },
	{ "# Deaths", 80, "LEFT", 40 },
	{ "% of all", 150, "LEFT", 50 },
	{ "Avg. Lvl.", 200, "LEFT", 50 },
	{ "10", 280 + 0, "LEFT", 50 },
	{ "20", 280 + 50, "LEFT", 50 },
	{ "30", 280 + 100, "LEFT", 50 },
	{ "40", 280 + 150, "LEFT", 50 },
	{ "50", 280 + 200, "LEFT", 50 },
	{ "60", 280 + 250, "LEFT", 50 },
}

local average_class_header_font_strings = {}
for _, v in ipairs(average_class_subtitles) do
	average_class_header_font_strings[v[1]] = average_class_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	average_class_header_font_strings[v[1]]:SetPoint("TOPLEFT", average_class_container, "TOPLEFT", v[2], 2)
	average_class_header_font_strings[v[1]]:SetFont(class_font, 15, "")
	average_class_header_font_strings[v[1]]:SetJustifyH(v[3])
	average_class_header_font_strings[v[1]]:SetWordWrap(false)
	average_class_header_font_strings[v[1]]:SetWidth(100)
	average_class_header_font_strings[v[1]]:SetText(v[1])
end

local average_class_font_strings = {}
local sep = -18
for k, class_id in pairs(class_tbl) do
	average_class_font_strings[class_id] = {}
	for _, v in ipairs(average_class_subtitles) do
		average_class_font_strings[class_id][v[1]] =
			average_class_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		average_class_font_strings[class_id][v[1]]:SetPoint(
			"TOPLEFT",
			average_class_container,
			"TOPLEFT",
			v[2],
			sep + 5
		)
		average_class_font_strings[class_id][v[1]]:SetFont(class_font, 14, "")
		average_class_font_strings[class_id][v[1]]:SetJustifyH(v[3])
		average_class_font_strings[class_id][v[1]]:SetWidth(50)
		average_class_font_strings[class_id][v[1]]:SetTextColor(1, 1, 1, 1)
	end
	sep = sep - 15
end

average_class_font_strings["all"] = {}
for _, v in ipairs(average_class_subtitles) do
	average_class_font_strings["all"][v[1]] = average_class_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	average_class_font_strings["all"][v[1]]:SetPoint("TOPLEFT", average_class_container, "TOPLEFT", v[2], sep + 5)
	average_class_font_strings["all"][v[1]]:SetFont(class_font, 14, "")
	average_class_font_strings["all"][v[1]]:SetJustifyH(v[3])
	average_class_font_strings["all"][v[1]]:SetWidth(100)
	average_class_font_strings["all"][v[1]]:SetTextColor(1, 1, 1, 1)
end

function average_class_container.updateMenuElement(scroll_frame, inc_class_id, stats_tbl, setMapRegion, model, view)
	if model == nil then
		model = "Kaplan-Meier"
	end

	if view == nil then
		view = "Survival"
	end

	local kaplan_meier = precomputed_kaplan_meier
	local class_log_normal_params = precomputed_log_normal_params["all"]
	average_class_container:Show()
	local entry_data = {}
	local map_id = 947
	local _stats = stats_tbl["stats"]
	local _log_normal_params = stats_tbl["log_normal_params"]
	if map_id == 1414 or map_id == 1415 then
		return
	end
	if map_id == 947 then
		map_id = "all"
	end
	if average_class_container.configure_for == "map" and _stats["all"][map_id] == nil then
		return
	end

	average_class_container:SetParent(scroll_frame.frame)
	average_class_container:SetPoint("TOPLEFT", scroll_frame.frame, "TOPLEFT", 0, -305)
	average_class_container:SetWidth(600)
	average_class_container:SetHeight(200)

	if average_class_container.heading == nil then
		average_class_container.heading = average_class_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		average_class_container.heading:SetText("Compare")
		average_class_container.heading:SetFont(class_font, 18, "")
		average_class_container.heading:SetJustifyV("TOP")
		average_class_container.heading:SetTextColor(0.9, 0.9, 0.9)
		average_class_container.heading:SetPoint("TOP", average_class_container, "TOP", -10, 30)
		average_class_container.heading:Show()
	end

	if average_class_container.milestone_text == nil then
		average_class_container.milestone_text =
			average_class_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		average_class_container.milestone_text:SetText("Probability of reaching milestone (P(X > x))")
		average_class_container.milestone_text:SetFont(class_font, 12, "")
		average_class_container.milestone_text:SetJustifyV("TOP")
		average_class_container.milestone_text:SetPoint("TOP", average_class_container, "TOP", 120, 13)
		average_class_container.milestone_text:Show()
	end

	if view == "Survival" then
		average_class_container.milestone_text:SetText("Probability of reaching milestone (P(X > x))")
	elseif view == "Hazard" then
		average_class_container.milestone_text:SetText(
			"Probability of reaching milestone from last milestone (P(X > x | X=x-10))"
		)
	end

	if average_class_container.x_hint == nil then
		average_class_container.x_hint = average_class_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		average_class_container.x_hint:SetText("E.g. 1.7x means 1.7 more likely to reach milestone")
		average_class_container.x_hint:SetFont(class_font, 12, "")
		average_class_container.x_hint:SetTextColor(0.7 .. 7, 0.7, 0.7)
		average_class_container.x_hint:SetJustifyV("TOP")
		average_class_container.x_hint:SetPoint("TOP", average_class_container, "TOP", 120, -170)
		average_class_container.x_hint:Show()
	end

	if average_class_container.left == nil then
		average_class_container.left = average_class_container:CreateTexture(nil, "BACKGROUND")
		average_class_container.left:SetHeight(8)
		average_class_container.left:SetPoint("LEFT", average_class_container.heading, "LEFT", -200, 0)
		average_class_container.left:SetPoint("RIGHT", average_class_container.heading, "LEFT", -25, 0)
		average_class_container.left:SetTexture(137057) -- Interface\\Tooltips\\UI-Tooltip-Border
		average_class_container.left:SetTexCoord(0.81, 0.94, 0.5, 1)
	end

	if average_class_container.right == nil then
		average_class_container.right = average_class_container:CreateTexture(nil, "BACKGROUND")
		average_class_container.right:SetHeight(8)
		average_class_container.right:SetPoint("RIGHT", average_class_container.heading, "RIGHT", 200, 0)
		average_class_container.right:SetPoint("LEFT", average_class_container.heading, "RIGHT", 25, 0)
		average_class_container.right:SetTexture(137057) -- Interface\\Tooltips\\UI-Tooltip-Border
		average_class_container.right:SetTexCoord(0.81, 0.94, 0.5, 1)
	end

	local s_class_info = {}
	s_class_info["# Deaths"] = _stats["all"][map_id][inc_class_id]["all"]["num_entries"]
	s_class_info["% of all"] = _stats["all"][map_id][inc_class_id]["all"]["num_entries"]
		/ _stats["all"][map_id]["all"]["all"]["num_entries"]
		* 100.0
	s_class_info["Avg. Lvl."] = _stats["all"][map_id][inc_class_id]["all"]["avg_lvl"]

	local cdf = nil
	local cdf_values = nil
	local viewFunction = nil
	if view == "Survival" then
		if model == "LogNormal" then
			viewFunction = function(cdf, x)
				return (1 - cdf[x]) * 100
			end
		elseif model == "Kaplan-Meier" then
			viewFunction = function(cdf, x)
				return cdf[x] * 100
			end
		end
	elseif view == "Hazard" then
		if model == "LogNormal" then
			viewFunction = function(cdf, x)
				return (1 - cdf[x]) / (1 - (cdf[x - 10] or 0.0)) * 100
			end
		elseif model == "Kaplan-Meier" then
			viewFunction = function(cdf, x)
				return cdf[x] / (cdf[x - 10] or 1.0) * 100
			end
		end
	end

	if model == "LogNormal" then
		cdf = Deathlog_CalculateCDF2(class_log_normal_params[inc_class_id][1], class_log_normal_params[inc_class_id][2])
	elseif model == "Kaplan-Meier" then
		cdf = kaplan_meier[inc_class_id]
	end

	s_class_info["10"] = viewFunction(cdf, 10)
	s_class_info["20"] = viewFunction(cdf, 20)
	s_class_info["30"] = viewFunction(cdf, 30)
	s_class_info["40"] = viewFunction(cdf, 40)
	s_class_info["50"] = viewFunction(cdf, 50)
	s_class_info["60"] = viewFunction(cdf, 60)

	local function createEntryData(class_id)
		local v = _stats["all"][map_id][class_id]
		if v == nil or class_id == inc_class_id then
			entry_data[class_id] = {}
			local class_str, _, _ = GetClassInfo(class_id)
			entry_data[class_id]["Class"] = class_str
			entry_data[class_id]["# Deaths"] = "-"
			entry_data[class_id]["% of all"] = "-"
			entry_data[class_id]["Avg. Lvl."] = "-"
			entry_data[class_id]["10"] = "-"
			entry_data[class_id]["20"] = "-"
			entry_data[class_id]["30"] = "-"
			entry_data[class_id]["40"] = "-"
			entry_data[class_id]["50"] = "-"
			entry_data[class_id]["60"] = "-"
		else
			local class_str = ""
			if class_id ~= "all" then
				class_str, _, _ = GetClassInfo(class_id)
			else
				class_str = "all"
			end
			entry_data[class_id] = {}
			entry_data[class_id]["Class"] = class_str
			entry_data[class_id]["# Deaths"] = s_class_info["# Deaths"] - v["all"]["num_entries"]
			if entry_data[class_id]["# Deaths"] > 0 then
				entry_data[class_id]["# Deaths"] = "|c"
					.. green_shade
					.. "+"
					.. tostring(entry_data[class_id]["# Deaths"])
					.. "|r"
			else
				entry_data[class_id]["# Deaths"] = "|cffff0000" .. tostring(entry_data[class_id]["# Deaths"]) .. "|r"
			end
			entry_data[class_id]["% of all"] = s_class_info["% of all"]
				/ (v["all"]["num_entries"] / _stats["all"][map_id]["all"]["all"]["num_entries"] * 100.0)
			if entry_data[class_id]["% of all"] > 1 then
				entry_data[class_id]["% of all"] = "|c"
					.. green_shade
					.. string.format("%.1f", entry_data[class_id]["% of all"])
					.. "x|r"
			else
				entry_data[class_id]["% of all"] = "|cffff0000"
					.. string.format("%.1f", entry_data[class_id]["% of all"])
					.. "x|r"
			end

			local cdf = {}
			local cdf_values = nil
			if model == "LogNormal" then
				if class_id == "all" then
					for i = 1, 60 do
						cdf[i] = 0
					end
					for k, v in pairs(deathlog_class_tbl) do
						local l_cdf =
							Deathlog_CalculateCDF2(class_log_normal_params[v][1], class_log_normal_params[v][2])
						for i = 1, 60 do
							cdf[i] = cdf[i] + l_cdf[i] / 9
						end
					end
				else
					cdf = Deathlog_CalculateCDF2(
						class_log_normal_params[class_id][1],
						class_log_normal_params[class_id][2]
					)
				end
				cdf_values = function(x)
					return 1 - cdf[x]
				end
			elseif model == "Kaplan-Meier" then
				if class_id == "all" then
					for i = 1, 60 do
						cdf[i] = 0
					end
					for k, v in pairs(deathlog_class_tbl) do
						local l_cdf = kaplan_meier[v]
						for i = 1, 60 do
							cdf[i] = cdf[i] + l_cdf[i] / 9
						end
					end
				else
					cdf = kaplan_meier[class_id]
				end
				cdf_values = function(x)
					return cdf[x]
				end
			end

			entry_data[class_id]["Avg. Lvl."] = s_class_info["Avg. Lvl."] - v["all"]["avg_lvl"]
			if entry_data[class_id]["Avg. Lvl."] > 0 then
				entry_data[class_id]["Avg. Lvl."] = "|c"
					.. green_shade
					.. "+"
					.. string.format("%.1f", entry_data[class_id]["Avg. Lvl."])
					.. "|r"
			else
				entry_data[class_id]["Avg. Lvl."] = "|cffff0000"
					.. string.format("%.1f", entry_data[class_id]["Avg. Lvl."])
					.. "|r"
			end

			entry_data[class_id]["10"] = s_class_info["10"] / viewFunction(cdf, 10)
			if entry_data[class_id]["10"] > 1 then
				entry_data[class_id]["10"] = "|c"
					.. green_shade
					.. string.format("%.1f", entry_data[class_id]["10"])
					.. "x|r"
			else
				entry_data[class_id]["10"] = "|cffff0000" .. string.format("%.1f", entry_data[class_id]["10"]) .. "x|r"
			end

			entry_data[class_id]["20"] = s_class_info["20"] / viewFunction(cdf, 20)
			if entry_data[class_id]["20"] > 1 then
				entry_data[class_id]["20"] = "|c"
					.. green_shade
					.. string.format("%.1f", entry_data[class_id]["20"])
					.. "x|r"
			else
				entry_data[class_id]["20"] = "|cffff0000" .. string.format("%.1f", entry_data[class_id]["20"]) .. "x|r"
			end

			entry_data[class_id]["30"] = s_class_info["30"] / viewFunction(cdf, 30)
			if entry_data[class_id]["30"] > 1 then
				entry_data[class_id]["30"] = "|c"
					.. green_shade
					.. string.format("%.1f", entry_data[class_id]["30"])
					.. "x|r"
			else
				entry_data[class_id]["30"] = "|cffff0000" .. string.format("%.1f", entry_data[class_id]["30"]) .. "x|r"
			end

			entry_data[class_id]["40"] = s_class_info["40"] / (viewFunction(cdf, 40))
			if entry_data[class_id]["40"] > 1 then
				entry_data[class_id]["40"] = "|c"
					.. green_shade
					.. string.format("%.1f", entry_data[class_id]["40"])
					.. "x|r"
			else
				entry_data[class_id]["40"] = "|cffff0000" .. string.format("%.1f", entry_data[class_id]["40"]) .. "x|r"
			end

			entry_data[class_id]["50"] = s_class_info["50"] / (viewFunction(cdf, 50))
			if entry_data[class_id]["50"] > 1 then
				entry_data[class_id]["50"] = "|c"
					.. green_shade
					.. string.format("%.1f", entry_data[class_id]["50"])
					.. "x|r"
			else
				entry_data[class_id]["50"] = "|cffff0000" .. string.format("%.1f", entry_data[class_id]["50"]) .. "x|r"
			end

			entry_data[class_id]["60"] = s_class_info["60"] / (viewFunction(cdf, 60))
			if entry_data[class_id]["60"] > 1 then
				entry_data[class_id]["60"] = "|c"
					.. green_shade
					.. string.format("%.1f", entry_data[class_id]["60"])
					.. "x|r"
			else
				entry_data[class_id]["60"] = "|cffff0000" .. string.format("%.1f", entry_data[class_id]["60"]) .. "x|r"
			end
		end
	end

	local function createEntryDataForCreature(class_id, creature_id)
		local v = _stats["all"]["all"][class_id]
		if v == nil or v[creature_id] == nil then
			entry_data[class_id] = {}
			local class_str, _, _ = GetClassInfo(class_id)
			entry_data[class_id]["Class"] = class_str
			entry_data[class_id]["#"] = "-"
			entry_data[class_id]["%"] = "-"
			entry_data[class_id]["Avg."] = "-"
		else
			local class_str = ""
			if class_id ~= "all" then
				class_str, _, _ = GetClassInfo(class_id)
			else
				class_str = "all"
			end
			entry_data[class_id] = {}
			entry_data[class_id]["Class"] = class_str
			entry_data[class_id]["#"] = v[creature_id]["num_entries"]
			entry_data[class_id]["%"] = string.format(
				"%.1f",
				v[creature_id]["num_entries"] / _stats["all"]["all"]["all"]["all"]["num_entries"] * 100.0
			) .. "%"
			entry_data[class_id]["Avg."] = string.format("%.1f", v[creature_id]["avg_lvl"])
		end
	end

	for k, class_id in pairs(class_tbl) do
		createEntryData(class_id)
	end
	createEntryData("all")

	for k, class_id in pairs(class_tbl) do
		for _, v in ipairs(average_class_subtitles) do
			if inc_class_id == class_id then
				average_class_font_strings[class_id][v[1]]:SetTextColor(
					deathlog_class_colors[k].r,
					deathlog_class_colors[k].g,
					deathlog_class_colors[k].b
				)
			else
				average_class_font_strings[class_id][v[1]]:SetTextColor(1, 1, 1)
			end
			average_class_font_strings[class_id][v[1]]:SetText(entry_data[class_id][v[1]])
		end
	end
	for _, v in ipairs(average_class_subtitles) do
		average_class_font_strings["all"][v[1]]:SetText(entry_data["all"][v[1]])
	end

	average_class_container:SetScript("OnHide", function()
		average_class_container.heading:Hide()
		average_class_container.left:Hide()
		average_class_container.right:Hide()
		for _, v in ipairs(average_class_subtitles) do
			average_class_header_font_strings[v[1]]:Hide()
		end
		for k, class_id in pairs(class_tbl) do
			for _, v in ipairs(average_class_subtitles) do
				average_class_font_strings[class_id][v[1]]:Hide()
			end
		end
	end)

	average_class_container:SetScript("OnShow", function()
		average_class_container.heading:Show()
		average_class_container.left:Show()
		average_class_container.right:Show()
		for _, v in ipairs(average_class_subtitles) do
			average_class_header_font_strings[v[1]]:Show()
		end
		for k, class_id in pairs(class_tbl) do
			for _, v in ipairs(average_class_subtitles) do
				average_class_font_strings[class_id][v[1]]:Show()
			end
		end
	end)
end

function Deathlog_ClassStatsContainer()
	return average_class_container
end
