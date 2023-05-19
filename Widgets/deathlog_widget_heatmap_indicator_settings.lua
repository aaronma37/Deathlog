local AceGUI = LibStub("AceGUI-3.0")

local deathlog_widget_heatmap_indicator_settings_container = CreateFrame("frame")
deathlog_widget_heatmap_indicator_settings_container.name = "Deathlog"
deathlog_widget_heatmap_indicator_settings_container.height = 100
deathlog_widget_heatmap_indicator_settings_container.enable_checkbox_set_value_functor = function()
	if deathlog_settings["heatmap_indicator_show"] == nil then
		deathlog_settings["heatmap_indicator_show"] = true
	end
	return deathlog_settings["heatmap_indicator_show"]
end
deathlog_widget_heatmap_indicator_settings_container.enable_checkbox_check_functor = function(value)
	deathlog_settings["heatmap_indicator_show"] = value
	initDeathlogHeatmapIndicatorWidget(deathlog_settings)
end

function deathlog_widget_heatmap_indicator_settings_container.updateWidgetSettingsContainer(
	inline_container,
	createHeader,
	createDescription
)
	deathlog_widget_heatmap_indicator_settings_container:SetParent(inline_container.frame)
	deathlog_widget_heatmap_indicator_settings_container:SetPoint("TOPLEFT", inline_container.frame, "TOPLEFT", 0, 0)
	deathlog_widget_heatmap_indicator_settings_container:SetHeight(inline_container.frame:GetWidth() * 0.6 * 3 / 4)
	deathlog_widget_heatmap_indicator_settings_container:SetWidth(inline_container.frame:GetWidth() * 0.6)
	deathlog_widget_heatmap_indicator_settings_container:Show()

	createHeader(deathlog_widget_heatmap_indicator_settings_container, "Heatmap Indicator")
	createDescription(
		deathlog_widget_heatmap_indicator_settings_container,
		"A pop-out frame which indicates how dangerous the area is based on the heatmap."
	)

	local reset_position_button = AceGUI:Create("Button")
	reset_position_button:SetText("Reset Size and Position")
	reset_position_button:SetWidth(200)
	reset_position_button:SetCallback("OnClick", function(self)
		if deathlog_settings["heatmap_indicator_pos"] == nil then
			deathlog_settings["heatmap_indicator_pos"] = {}
		end

		if deathlog_settings["heatmap_indicator_size"] == nil then
			deathlog_settings["heatmap_indicator_size"] = {}
		end

		deathlog_settings["heatmap_indicator_pos"]["x"] = 0
		deathlog_settings["heatmap_indicator_pos"]["y"] = 0

		deathlog_settings["heatmap_indicator_size"]["x"] = 35
		deathlog_settings["heatmap_indicator_size"]["y"] = 35
		initDeathlogHeatmapIndicatorWidget(deathlog_settings)
	end)
	inline_container:AddChild(reset_position_button)
end

function Deathlog_WidgetHeatmapIndicatorSettingsContainer()
	return deathlog_widget_heatmap_indicator_settings_container
end
