local AceGUI = LibStub("AceGUI-3.0")

local deathlog_widget_minilog_settings_container = CreateFrame("frame")
deathlog_widget_minilog_settings_container.name = "Deathlog"
deathlog_widget_minilog_settings_container.height = 100
deathlog_widget_minilog_settings_container.enable_checkbox_set_value_functor = function()
	if deathlog_settings["death_log_show"] == nil then
		deathlog_settings["death_log_show"] = true
	end
	return deathlog_settings["death_log_show"]
end
deathlog_widget_minilog_settings_container.enable_checkbox_check_functor = function(value)
	deathlog_settings["death_log_show"] = value
	initDeathlogMinilogWidget(deathlog_settings)
end

function deathlog_widget_minilog_settings_container.updateWidgetSettingsContainer(
	inline_container,
	createHeader,
	createDescription
)
	deathlog_widget_minilog_settings_container:SetParent(inline_container.frame)
	deathlog_widget_minilog_settings_container:SetPoint("TOPLEFT", inline_container.frame, "TOPLEFT", 0, 0)
	deathlog_widget_minilog_settings_container:SetHeight(inline_container.frame:GetWidth() * 0.6 * 3 / 4)
	deathlog_widget_minilog_settings_container:SetWidth(inline_container.frame:GetWidth() * 0.6)
	deathlog_widget_minilog_settings_container:Show()

	createHeader(deathlog_widget_minilog_settings_container, "Deathlog")
	createDescription(
		deathlog_widget_minilog_settings_container,
		"A mini-deathlog widget which shows entries of recent deaths.  Successor to the Hardcore Deathlog widget."
	)

	local style_search_box = AceGUI:Create("DeathlogDropdown")
	style_search_box:SetWidth(150)
	style_search_box:SetLabel("Style")
	style_search_box:AddItem("", "")
	style_search_box:AddItem("Hardcore legacy", "Hardcore legacy")
	style_search_box:SetText("Hardcore legacy")
	style_search_box:SetDisabled(true)
	inline_container:AddChild(style_search_box)

	local reset_position_button = AceGUI:Create("Button")
	reset_position_button:SetText("Reset Size and Position")
	reset_position_button:SetWidth(150)
	reset_position_button:SetCallback("OnClick", function(self)
		if deathlog_settings["death_log_pos"] == nil then
			deathlog_settings["death_log_pos"] = {}
		end

		if deathlog_settings["death_log_size"] == nil then
			deathlog_settings["death_log_size"] = {}
		end

		deathlog_settings["death_log_pos"]["x"] = 0
		deathlog_settings["death_log_pos"]["y"] = 0

		deathlog_settings["death_log_size"]["x"] = 255
		deathlog_settings["death_log_size"]["y"] = 125
		initDeathlogMinilogWidget(deathlog_settings)
	end)
	inline_container:AddChild(reset_position_button)
end

function Deathlog_WidgetSettingsContainer()
	return deathlog_widget_minilog_settings_container
end
