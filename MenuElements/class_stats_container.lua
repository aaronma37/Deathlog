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
local class_stat_comparison_container = CreateFrame("Frame")
class_stat_comparison_container:SetSize(100, 100)
class_stat_comparison_container:Show()

local class_font = Deathlog_L.class_font

local class_tbl = deathlog_class_tbl
local race_tbl = deathlog_race_tbl
local zone_tbl = deathlog_zone_tbl

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
	average_class_header_font_strings[v[1]] =
		class_stat_comparison_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	average_class_header_font_strings[v[1]]:SetPoint("TOPLEFT", class_stat_comparison_container, "TOPLEFT", v[2], 2)
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
			class_stat_comparison_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		average_class_font_strings[class_id][v[1]]:SetPoint(
			"TOPLEFT",
			class_stat_comparison_container,
			"TOPLEFT",
			v[2],
			sep + 5
		)
		average_class_font_strings[class_id][v[1]]:SetFont(class_font, 14, "")
		average_class_font_strings[class_id][v[1]]:SetJustifyH(v[3])
		average_class_font_strings[class_id][v[1]]:SetWidth(50)
		average_class_font_strings[class_id][v[1]]:SetTextColor(1, 1, 1, 1)
		average_class_font_strings[class_id][v[1]]:SetWordWrap(false)
	end
	sep = sep - 15
end

average_class_font_strings["all"] = {}
for _, v in ipairs(average_class_subtitles) do
	average_class_font_strings["all"][v[1]] =
		class_stat_comparison_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	average_class_font_strings["all"][v[1]]:SetPoint(
		"TOPLEFT",
		class_stat_comparison_container,
		"TOPLEFT",
		v[2],
		sep + 5
	)
	average_class_font_strings["all"][v[1]]:SetFont(class_font, 14, "")
	average_class_font_strings["all"][v[1]]:SetJustifyH(v[3])
	average_class_font_strings["all"][v[1]]:SetWidth(100)
	average_class_font_strings["all"][v[1]]:SetTextColor(1, 1, 1, 1)
end

function class_stat_comparison_container.updateMenuElement(
	scroll_frame,
	inc_class_id,
	stats_tbl,
	setMapRegion,
	model,
	view
)
	if model == nil then
		model = "Kaplan-Meier"
	end

	if view == nil then
		view = "Survival"
	end

	local kaplan_meier = precomputed_kaplan_meier
	local class_log_normal_params = precomputed_log_normal_params["all"]
	class_stat_comparison_container:Show()
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
	if class_stat_comparison_container.configure_for == "map" and _stats["all"][map_id] == nil then
		return
	end

	class_stat_comparison_container:SetParent(scroll_frame.frame)
	class_stat_comparison_container:SetPoint("TOPLEFT", scroll_frame.frame, "TOPLEFT", 0, -100)
	class_stat_comparison_container:SetWidth(600)
	class_stat_comparison_container:SetHeight(200)

	if class_stat_comparison_container.heading == nil then
		class_stat_comparison_container.heading =
			class_stat_comparison_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		class_stat_comparison_container.heading:SetText("Class Stats")
		class_stat_comparison_container.heading:SetFont(class_font, 18, "")
		class_stat_comparison_container.heading:SetJustifyV("TOP")
		class_stat_comparison_container.heading:SetTextColor(0.9, 0.9, 0.9)
		class_stat_comparison_container.heading:SetPoint("TOP", class_stat_comparison_container, "TOP", -10, 30)
		class_stat_comparison_container.heading:Show()
	end

	if class_stat_comparison_container.milestone_text == nil then
		class_stat_comparison_container.milestone_text =
			class_stat_comparison_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		class_stat_comparison_container.milestone_text:SetFont(class_font, 12, "")
		class_stat_comparison_container.milestone_text:SetJustifyV("TOP")
		class_stat_comparison_container.milestone_text:SetPoint("TOP", class_stat_comparison_container, "TOP", 120, 13)
		class_stat_comparison_container.milestone_text:Show()
	end

	if view == "Survival" then
		class_stat_comparison_container.milestone_text:SetText(
			"Probability of reaching milestone starting from lvl 1 (P(X > x))"
		)
	elseif view == "Hazard" then
		class_stat_comparison_container.milestone_text:SetText(
			"Probability of reaching milestone from last milestone (P(X > x | X=x-10))"
		)
	end

	if class_stat_comparison_container.left == nil then
		class_stat_comparison_container.left = class_stat_comparison_container:CreateTexture(nil, "BACKGROUND")
		class_stat_comparison_container.left:SetHeight(8)
		class_stat_comparison_container.left:SetPoint("LEFT", class_stat_comparison_container.heading, "LEFT", -200, 0)
		class_stat_comparison_container.left:SetPoint("RIGHT", class_stat_comparison_container.heading, "LEFT", -25, 0)
		class_stat_comparison_container.left:SetTexture(137057) -- Interface\\Tooltips\\UI-Tooltip-Border
		class_stat_comparison_container.left:SetTexCoord(0.81, 0.94, 0.5, 1)
	end

	if class_stat_comparison_container.right == nil then
		class_stat_comparison_container.right = class_stat_comparison_container:CreateTexture(nil, "BACKGROUND")
		class_stat_comparison_container.right:SetHeight(8)
		class_stat_comparison_container.right:SetPoint(
			"RIGHT",
			class_stat_comparison_container.heading,
			"RIGHT",
			200,
			0
		)
		class_stat_comparison_container.right:SetPoint("LEFT", class_stat_comparison_container.heading, "RIGHT", 25, 0)
		class_stat_comparison_container.right:SetTexture(137057) -- Interface\\Tooltips\\UI-Tooltip-Border
		class_stat_comparison_container.right:SetTexCoord(0.81, 0.94, 0.5, 1)
	end

	local function createEntryData(class_id)
		local v = _stats["all"][map_id][class_id]
		if v == nil then
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
			entry_data[class_id]["# Deaths"] = v["all"]["num_entries"]
			entry_data[class_id]["% of all"] = string.format(
				"%.1f",
				v["all"]["num_entries"] / _stats["all"][map_id]["all"]["all"]["num_entries"] * 100.0
			) .. "%"
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
					return 1 - (cdf[x] or 0)
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

			local viewFunction = nil

			if view == "Survival" then
				viewFunction = function(cdf_values, x)
					return cdf_values(x) * 100
				end
			elseif view == "Hazard" then
				viewFunction = function(cdf_values, x)
					local num = cdf_values(x)
					local den = cdf_values(x - 10) or 1.0
					return num / den * 100
				end
			end

			entry_data[class_id]["Avg. Lvl."] = string.format("%.1f", v["all"]["avg_lvl"])
			entry_data[class_id]["10"] = string.format("%.1f", viewFunction(cdf_values, 10)) .. "%"
			entry_data[class_id]["20"] = string.format("%.1f", viewFunction(cdf_values, 20)) .. "%"
			entry_data[class_id]["30"] = string.format("%.1f", viewFunction(cdf_values, 30)) .. "%"
			entry_data[class_id]["40"] = string.format("%.1f", viewFunction(cdf_values, 40)) .. "%"
			entry_data[class_id]["50"] = string.format("%.2f", viewFunction(cdf_values, 50)) .. "%"
			entry_data[class_id]["60"] = string.format("%.2f", viewFunction(cdf_values, 60)) .. "%"
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

	class_stat_comparison_container:SetScript("OnHide", function()
		class_stat_comparison_container.heading:Hide()
		class_stat_comparison_container.left:Hide()
		class_stat_comparison_container.right:Hide()
		for _, v in ipairs(average_class_subtitles) do
			average_class_header_font_strings[v[1]]:Hide()
		end
		for k, class_id in pairs(class_tbl) do
			for _, v in ipairs(average_class_subtitles) do
				average_class_font_strings[class_id][v[1]]:Hide()
			end
		end
	end)

	class_stat_comparison_container:SetScript("OnShow", function()
		class_stat_comparison_container.heading:Show()
		class_stat_comparison_container.left:Show()
		class_stat_comparison_container.right:Show()
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

function Deathlog_ClassStatsComparisonContainer()
	return class_stat_comparison_container
end
