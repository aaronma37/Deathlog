local loaded = false
local widget_name = "Creature Ranking Tooltip"

function Deathlog_activateCreatureRankingTooltip()
	if loaded == false then
		GameTooltip:HookScript("OnTooltipSetUnit", function()
			if deathlog_settings[widget_name]["enable"] then
				if Deathlog_azeroth_deadliest_dict then
					local a, _ = GameTooltip:GetUnit()
					local rank = Deathlog_azeroth_deadliest_dict[a]
					if rank then
						GameTooltip:AddLine("#" .. rank .. " deadliest in Azeroth", 0.6, 0.6, 0.6, 0.6, true)
					end
				end
			end
		end)
	end
	loaded = true
end

local function handleEvent(self, event, ...)
	if loaded == false and deathlog_settings["creature_ranking_tooltip_enabled"] then
		Deathlog_activateCreatureRankingTooltip()
	end
end
local event_handler = CreateFrame("frame")
event_handler:RegisterEvent("PLAYER_ENTERING_WORLD")
event_handler:SetScript("OnEvent", handleEvent)

local defaults = {
	["enable"] = true,
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

options = {
	name = widget_name,
	handler = Minilog,
	type = "group",
	args = {
		enable = {
			type = "toggle",
			name = "Show Deadly Creature Ranking Tooltip",
			desc = "Show Deadly Creature Ranking Tooltip",
			get = function()
				return deathlog_settings[widget_name]["enable"]
			end,
			set = function()
				deathlog_settings[widget_name]["enable"] = not deathlog_settings[widget_name]["enable"]
				Deathlog_CRTWidget_applySettings()
			end,
		},
	},
}
