local loaded_crt = false
local widget_name = "Creature Ranking Tooltip"

local creature_ranking = {}
local creature_ranking_by_zone = {}
local creature_avg_lvl = {}

function Deathlog_activateCreatureRankingTooltip()
	if loaded_crt == false then
		GameTooltip:HookScript("OnTooltipSetUnit", function()
			if deathlog_settings[widget_name]["enable_crt"] then
				if creature_ranking then
					local a, _ = GameTooltip:GetUnit()
					local rank = creature_ranking[a]
					if rank then
						GameTooltip:AddLine("#" .. rank .. " deadliest in Azeroth", 0.6, 0.6, 0.6, 0.6, true)
					end
				end
			end

			if deathlog_settings[widget_name]["by_zone"] then
				local a, _ = GameTooltip:GetUnit()
				local _zone = C_Map.GetBestMapForUnit("player")
				local instance_id = nil
				local zone_name = ""
				if _zone then
					local map_info = C_Map.GetMapInfo(_zone)
					if map_info then
						zone_name = map_info.name
					else
						zone_name = ""
					end
				else
					local _, _, _, _, _, _, _, _instance_id, _, _ = GetInstanceInfo()
					zone_name = (deathlog_id_to_instance_tbl[_instance_id] or _instance_id)
				end
				if creature_ranking_by_zone[_zone] then
					local source_id = npc_to_id[a]
					local rank = creature_ranking_by_zone[_zone][source_id]
					if rank then
						GameTooltip:AddLine(
							"#" .. rank .. " deadliest in " .. zone_name .. ".",
							0.6,
							0.6,
							0.6,
							0.6,
							true
						)
					end
				end
			end

			if deathlog_settings[widget_name]["enable_avg_lvl"] then
				local a, _ = GameTooltip:GetUnit()
				if creature_avg_lvl[a] then
					GameTooltip:AddLine(
						"Avg. victim lvl. " .. string.format("%.1f", creature_avg_lvl[a]),
						0.6,
						0.6,
						0.6,
						0.6,
						true
					)
				end
			end
		end)
	end
	loaded_crt = true
end

local function handleEvent(self, event, ...)
	if loaded_crt == false and deathlog_settings[widget_name] and deathlog_settings[widget_name]["enable_crt"] then
		Deathlog_activateCreatureRankingTooltip()
	end
end
local event_handler = CreateFrame("frame")
event_handler:RegisterEvent("PLAYER_ENTERING_WORLD")
event_handler:SetScript("OnEvent", handleEvent)

local defaults = {
	["enable_crt"] = true,
	["enable_avg_lvl"] = true,
	["crt_metric"] = "Normalized Score",
	["by_zone"] = true,
}

local function applyDefaults(_defaults, force)
	if deathlog_settings[widget_name] == nil then
		deathlog_settings[widget_name] = {}
	end
	for k, v in pairs(_defaults) do
		if deathlog_settings[widget_name][k] == nil or force then
			deathlog_settings[widget_name][k] = v
		end
	end
end

local options = nil
local optionsframe = nil
function Deathlog_CRTWidget_applySettings()
	applyDefaults(defaults)

	creature_ranking = {}
	creature_ranking_by_zone = precomputed_most_deadly_by_zone
	if deathlog_settings[widget_name]["enable_crt"] then
		if deathlog_settings[widget_name]["crt_metric"] == "Total Kills" then
			local most_deadly_units = deathlogGetOrdered(precomputed_general_stats, { "all", "all", "all", nil })
			for k, v in ipairs(most_deadly_units) do
				if id_to_npc[v[1]] then
					creature_ranking[id_to_npc[v[1]]] = k
				end
			end
		elseif deathlog_settings[widget_name]["crt_metric"] == "Normalized Score" then
			local most_deadly_units_normalized = deathlogGetOrderedNormalized(
				precomputed_general_stats,
				{ "all", "all", "all", nil },
				precomputed_log_normal_params["all"][1][1],
				precomputed_log_normal_params["all"][1][2]
			)

			for k, v in ipairs(most_deadly_units_normalized) do
				if id_to_npc[v[1]] then
					creature_ranking[id_to_npc[v[1]]] = k
				end
			end
		end
	end

	for k, v in pairs(precomputed_general_stats["all"]["all"]["all"]) do
		if id_to_npc[k] then
			creature_avg_lvl[id_to_npc[k]] = v["avg_lvl"]
		end
	end

	Deathlog_activateCreatureRankingTooltip()

	if optionsframe == nil then
		LibStub("AceConfig-3.0"):RegisterOptionsTable(widget_name, options)
		optionsframe = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(widget_name, widget_name, "Deathlog")
	end
end

local function forceReset()
	applyDefaults(defaults, true)
	Deathlog_CRTWidget_applySettings()
end

local metric_values = { ["Normalized Score"] = "Normalized Score", ["Total Kills"] = "Total Kills" }

options = {
	name = widget_name,
	handler = Minilog,
	type = "group",
	args = {
		enable_crt = {
			type = "toggle",
			name = "Show Deadly Creature Ranking Tooltip",
			desc = "Show Deadly Creature Ranking Tooltip.  This add a line to your tooltip when hovering over a creature, which specifies its rank.",
			width = 1.6,
			order = 1,
			get = function()
				return deathlog_settings[widget_name]["enable_crt"]
			end,
			set = function()
				deathlog_settings[widget_name]["enable_crt"] = not deathlog_settings[widget_name]["enable_crt"]
				Deathlog_CRTWidget_applySettings()
			end,
		},
		enable_avg_lvl = {
			type = "toggle",
			name = "Show average level of slain victim.",
			desc = "Shows the average level of the player that this creature has kill historically.",
			width = 1.6,
			order = 1,
			get = function()
				return deathlog_settings[widget_name]["enable_avg_lvl"]
			end,
			set = function()
				deathlog_settings[widget_name]["enable_avg_lvl"] = not deathlog_settings[widget_name]["enable_avg_lvl"]
				Deathlog_CRTWidget_applySettings()
			end,
		},
		by_zone = {
			type = "toggle",
			name = "Show rank by zone.",
			desc = "Shows the rank of the creature by zone.",
			width = 1.6,
			order = 1,
			get = function()
				return deathlog_settings[widget_name]["by_zone"]
			end,
			set = function()
				deathlog_settings[widget_name]["by_zone"] = not deathlog_settings[widget_name]["by_zone"]
				Deathlog_CRTWidget_applySettings()
			end,
		},
		crt_metric = {
			type = "select",
			dialogControl = "LSM30_Font", --Select your widget here
			name = "Creature Ranking Tooltip metric",
			desc = "Which metric to use to rank creatures.\n\nNormalized score: #Kills/(1-CDF(lvl)).  This metric normalizes the creature kills based on the remaining population around that creatures kill level.\nTotal Kills: Just based on the number of kills a creature has.",
			values = metric_values, -- pull in your font list from LSM
			get = function()
				return deathlog_settings[widget_name]["crt_metric"]
			end,
			set = function(self, key)
				deathlog_settings[widget_name]["crt_metric"] = key
				Deathlog_CRTWidget_applySettings()
			end,
			order = 2,
		},
	},
}
