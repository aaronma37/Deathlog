local AceGUI = LibStub("AceGUI-3.0")

local death_alert_settings_container = CreateFrame("frame")
death_alert_settings_container.name = "Deathlog"
death_alert_settings_container.height = 100
death_alert_settings_container.enable_checkbox_set_value_functor = function()
	if deathlog_settings["death_alert_enabled"] == nil then
		deathlog_settings["death_alert_enabled"] = true
	end
	return deathlog_settings["death_alert_enabled"]
end
death_alert_settings_container.enable_checkbox_check_functor = function(value)
	deathlog_settings["death_alert_enabled"] = value
	initDeathAlertWidget(deathlog_settings)
end

function death_alert_settings_container.updateWidgetSettingsContainer(inline_container, createHeader, createDescription)
	death_alert_settings_container:SetParent(inline_container.frame)
	death_alert_settings_container:SetPoint("TOPLEFT", inline_container.frame, "TOPLEFT", 0, 0)
	death_alert_settings_container:SetHeight(inline_container.frame:GetWidth() * 0.6 * 3 / 4)
	death_alert_settings_container:SetWidth(inline_container.frame:GetWidth() * 0.6)
	death_alert_settings_container:Show()

	createHeader(death_alert_settings_container, "Death Alerts")
	createDescription(death_alert_settings_container, "Death alerts that play a noise and visual when a player dies.")

	local reset_position_button = AceGUI:Create("Button")
end

function Deathlog_WidgetDeathAlertSettingsContainer()
	return death_alert_settings_container
end
