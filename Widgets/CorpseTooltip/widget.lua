local loaded_ctt = false
local widget_name = "Corpse Tooltip"

local timer_handle = nil

-- Build a Lua pattern from Blizzard's localized CORPSE_TOOLTIP ("Corpse of %s")
local corpse_pattern = string.gsub(CORPSE_TOOLTIP, "%%s", "(.+)")

local function checkForEntryAndSetTooltip()
	if timer_handle then
		timer_handle:Cancel()
	end
	timer_handle = C_Timer.NewTimer(0.1, function()
		local text = _G["GameTooltipTextLeft1"]:GetText()
		if text ~= nil then
			local _name = string.match(text, corpse_pattern)
			if _name then
				local realmName = GetRealmName()
				if deathlog_data[realmName] and deathlog_data_map[realmName] and deathlog_data_map[realmName][_name] then
					local _entry = deathlog_data[realmName][deathlog_data_map[realmName][_name]]
					deathlog_setTooltipFromEntry(_entry)
					GameTooltip:Show()
				end
			end
		end
	end)
end
function Deathlog_activateCorpseTooltip()
	if loaded_ctt == false and deathlog_settings[widget_name]["enable_ctt"] then
		GameTooltip:HookScript("OnTooltipCleared", function(self, button)
			checkForEntryAndSetTooltip()
		end)
		GameTooltip:HookScript("OnShow", function(self, button)
			checkForEntryAndSetTooltip()
		end)
	end
	loaded_ctt = true
end

local function handleEvent(self, event, ...)
	if loaded_ctt == false and deathlog_settings[widget_name] and deathlog_settings[widget_name]["enable_ctt"] then
		Deathlog_activateCorpseTooltip()
	end
end
local event_handler = CreateFrame("frame")
event_handler:RegisterEvent("PLAYER_ENTERING_WORLD")
event_handler:SetScript("OnEvent", handleEvent)

local defaults = {
	["enable_ctt"] = true,
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
function Deathlog_CTTWidget_applySettings()
	applyDefaults(defaults)

	if deathlog_settings[widget_name]["enable_ctt"] then
		Deathlog_activateCorpseTooltip()
	end

	if optionsframe == nil then
		LibStub("AceConfig-3.0"):RegisterOptionsTable(widget_name, options)
		optionsframe = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(widget_name, widget_name, "Deathlog")
	end
end

local function forceReset()
	applyDefaults(defaults, true)
	Deathlog_CTTWidget_applySettings()
end

options = {
	name = widget_name,
	type = "group",
	args = {
		enable_ctt = {
			type = "toggle",
			name = "Show corpse tooltip on hover.",
			desc = "Shows player death information on hover over a corpse.",
			width = 1.6,
			order = 1,
			get = function()
				return deathlog_settings[widget_name]["enable_ctt"]
			end,
			set = function()
				deathlog_settings[widget_name]["enable_ctt"] = not deathlog_settings[widget_name]["enable_ctt"]
				Deathlog_CTTWidget_applySettings()
			end,
		},
	},
}
