local AceGUI = LibStub("AceGUI-3.0")

local creature_ranking_tooltip_settings_container = CreateFrame("frame")
creature_ranking_tooltip_settings_container.name = "Deathlog"
creature_ranking_tooltip_settings_container.height = 100
creature_ranking_tooltip_settings_container.enable_checkbox_set_value_functor = function()
	if deathlog_settings["creature_ranking_tooltip_enabled"] == nil then
		deathlog_settings["creature_ranking_tooltip_enabled"] = true
	end
	return deathlog_settings["creature_ranking_tooltip_enabled"]
end
creature_ranking_tooltip_settings_container.enable_checkbox_check_functor = function(value)
	deathlog_settings["creature_ranking_tooltip_enabled"] = value
	if deathlog_settings["creature_ranking_tooltip_enabled"] then
		Deathlog_activateCreatureRankingTooltip()
	end
end

function creature_ranking_tooltip_settings_container.updateWidgetSettingsContainer(
	inline_container,
	createHeader,
	createDescription
)
	creature_ranking_tooltip_settings_container:SetParent(inline_container.frame)
	creature_ranking_tooltip_settings_container:SetPoint("TOPLEFT", inline_container.frame, "TOPLEFT", 0, 0)
	creature_ranking_tooltip_settings_container:SetHeight(inline_container.frame:GetWidth() * 0.6 * 3 / 4)
	creature_ranking_tooltip_settings_container:SetWidth(inline_container.frame:GetWidth() * 0.6)
	creature_ranking_tooltip_settings_container:Show()

	createHeader(creature_ranking_tooltip_settings_container, "Creature Ranking Tooltip")
	createDescription(
		creature_ranking_tooltip_settings_container,
		"Adds a line to tooltip which provides the rank of a creature based on how many hardcore kills they have."
	)
	if deathlog_settings["creature_ranking_tooltip_enabled"] then
		Deathlog_activateCreatureRankingTooltip()
	end
end

function Deathlog_WidgetCreatureRankingTooltipSettingsContainer()
	return creature_ranking_tooltip_settings_container
end
