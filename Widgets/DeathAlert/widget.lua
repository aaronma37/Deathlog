local AceGUI = LibStub("AceGUI-3.0")
local widget_name = "DeathAlert"
local death_alert_frame = CreateFrame("frame")
local death_alert_styles =
	{ ["boss_banner_basic"] = "boss_banner_basic", ["boss_banner_enemy_icon"] = "boss_banner_enemy_icon" }
local LSM30 = LibStub("LibSharedMedia-3.0", true)
local fonts = LSM30:HashTable("font")
fonts["blei00d"] = "Fonts\\blei00d.TTF"
death_alert_frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
death_alert_frame:SetWidth(25)
death_alert_frame:SetHeight(25)
death_alert_frame:SetMovable(false)
death_alert_frame:EnableMouse(false)
death_alert_frame:SetFrameStrata("FULLSCREEN_DIALOG")
death_alert_frame:Show()

death_alert_frame.text = death_alert_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
death_alert_frame.text:SetText(
	UnitName("player")
		.. " the "
		.. UnitClass("player")
		.. " "
		.. UnitRace("player")
		.. " has\ndied at level "
		.. UnitLevel("player")
		.. " in Elywynn Forest."
)

death_alert_frame.text:SetFont("Fonts\\blei00d.TTF", 22, "")
death_alert_frame.text:SetTextColor(1, 1, 1, 1)
death_alert_frame.text:SetJustifyH("CENTER")
death_alert_frame.text:SetParent(death_alert_frame)
death_alert_frame.text:Show()

function Deathlog_DeathAlertFakeDeath()
	local fake_entry = {
		["name"] = UnitName("player"),
		["level"] = UnitLevel("player"),
		["race_id"] = 3,
		-- ["map_id"] = 1429,
		["instance_id"] = 34, --34,
		["class_id"] = 9,
		["source_id"] = 30,
	}
	Deathlog_DeathAlertPlay(fake_entry)
end

function Deathlog_DeathAlertPlay(entry)
	if deathlog_settings[widget_name]["enable"] == false then
		return
	end
	PlaySound(8959)
	death_alert_frame.text:SetText("Some text")

	local class = GetClassInfo(entry["class_id"]) or ""
	if deathlog_class_colors[class] then
		class = "|c" .. deathlog_class_colors[class]:GenerateHexColor() .. class .. "|r"
	end
	local race = C_CreatureInfo.GetRaceInfo(entry["race_id"])
	if race then
		race = race.raceName
	else
		race = ""
	end
	local zone = ""
	if entry["map_id"] then
		local map_info = C_Map.GetMapInfo(entry["map_id"])
		if map_info then
			zone = map_info.name
		end
	elseif entry["instance_id"] then
		zone = deathlog_id_to_instance_tbl[entry["instance_id"]] or ""
	end

	local source_name = ""
	if entry["source_id"] then
		if id_to_npc[entry["source_id"]] then
			source_name = id_to_npc[entry["source_id"]]
		end
	end
	death_alert_frame.text:SetText(
		entry["name"]
			.. " the "
			.. class
			.. " "
			.. race
			.. " has beenslain\nby "
			.. source_name
			.. ", at level "
			.. entry["level"]
			.. " in "
			.. zone
			.. "."
	)

	if deathlog_settings[widget_name]["style"] == "boss_banner_enemy_icon" then
		if entry["source_id"] then
			if id_to_display_id[entry["source_id"]] then
				SetPortraitTextureFromCreatureDisplayID(
					death_alert_frame.textures.enemy_portrait,
					id_to_display_id[entry["source_id"]]
				)
				death_alert_frame.textures.enemy_portrait:AddMaskTexture(death_alert_frame.textures.enemy_portrait_mask)
			end
		end
	end

	death_alert_frame:Show()

	if death_alert_frame.timer then
		death_alert_frame.timer:Cancel()
	end
	death_alert_frame.timer = C_Timer.NewTimer(deathlog_settings[widget_name]["display_time"], function()
		death_alert_frame:Hide()
	end)
end

local defaults = {
	["enable"] = true,
	["pos_x"] = 0,
	["pos_y"] = 250,
	["size_x"] = 600,
	["size_y"] = 200,
	["style"] = "boss_banner_enemy_icon",
	["display_time"] = 6,
	["alert_subset"] = "faction_wide",
	["font"] = "Nimrod MT",
	["font_size"] = 16,
	["font_color_r"] = 1,
	["font_color_g"] = 1,
	["font_color_b"] = 1,
	["font_color_a"] = 1,
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

local function initializeBossBanner(icon_type)
	if death_alert_frame.textures == nil then
		death_alert_frame.textures = {}
	end
	if death_alert_frame.textures.top == nil then
		death_alert_frame.textures.top = death_alert_frame:CreateTexture(nil, "OVERLAY")
	end
	death_alert_frame.textures.top:SetAllPoints()
	death_alert_frame.textures.top:SetDrawLayer("OVERLAY", 4)
	death_alert_frame.textures.top:SetVertexColor(1, 1, 1, 1)
	death_alert_frame.textures.top:SetTexture("Interface\\LevelUp\\BossBanner")
	death_alert_frame.textures.top:SetTexCoord(0, 0.84, 0, 0.43)
	death_alert_frame.textures.top:Show()

	if death_alert_frame.textures.middle == nil then
		death_alert_frame.textures.middle = death_alert_frame:CreateTexture(nil, "OVERLAY")
	end
	death_alert_frame.textures.middle:SetPoint(
		"CENTER",
		death_alert_frame.textures.top,
		"CENTER",
		0,
		-death_alert_frame.textures.top:GetHeight() * 0.03
	)
	death_alert_frame.textures.middle:SetWidth(death_alert_frame.textures.top:GetWidth())
	death_alert_frame.textures.middle:SetHeight(death_alert_frame.textures.top:GetHeight() * 0.32)
	death_alert_frame.textures.middle:SetDrawLayer("OVERLAY", 4)
	death_alert_frame.textures.middle:SetVertexColor(1, 1, 1, 1)
	death_alert_frame.textures.middle:SetTexture("Interface\\LevelUp\\BossBanner")
	death_alert_frame.textures.middle:SetTexCoord(0, 0.8, 0.43, 0.58)
	death_alert_frame.textures.middle:Show()

	if death_alert_frame.textures.top_emblem == nil then
		death_alert_frame.textures.top_emblem = death_alert_frame:CreateTexture(nil, "OVERLAY")
	end
	death_alert_frame.textures.top_emblem:SetPoint(
		"TOP",
		death_alert_frame.textures.top,
		"TOP",
		0,
		-death_alert_frame.textures.top:GetHeight() * 0.209
	)
	death_alert_frame.textures.top_emblem:SetWidth(death_alert_frame.textures.top:GetHeight() * 0.5 * 1.25)
	death_alert_frame.textures.top_emblem:SetHeight(death_alert_frame.textures.top:GetHeight() * 0.2 * 1.25)
	death_alert_frame.textures.top_emblem:SetDrawLayer("OVERLAY", 5)
	death_alert_frame.textures.top_emblem:SetVertexColor(1, 1, 1, 1)
	death_alert_frame.textures.top_emblem:SetTexture("Interface\\LevelUp\\BossBanner")
	death_alert_frame.textures.top_emblem:SetTexCoord(0.24, 0.59, 0.58, 0.72)
	death_alert_frame.textures.top_emblem:Show()

	if icon_type == "enemy_icon" then
		if death_alert_frame.textures.top_emblem_overlay == nil then
			death_alert_frame.textures.top_emblem_overlay = death_alert_frame:CreateTexture(nil, "OVERLAY")
		end
		death_alert_frame.textures.top_emblem_overlay:SetPoint(
			"TOP",
			death_alert_frame.textures.top,
			"TOP",
			0,
			-death_alert_frame.textures.top:GetHeight() * 0.21
		)
		death_alert_frame.textures.top_emblem_overlay:SetWidth(death_alert_frame.textures.top:GetHeight() * 0.225)
		death_alert_frame.textures.top_emblem_overlay:SetHeight(death_alert_frame.textures.top:GetHeight() * 0.225)
		death_alert_frame.textures.top_emblem_overlay:SetDrawLayer("OVERLAY", 6)
		death_alert_frame.textures.top_emblem_overlay:SetVertexColor(1, 1, 1, 1)
		death_alert_frame.textures.top_emblem_overlay:SetTexture("Interface\\LevelUp\\BossBanner")
		death_alert_frame.textures.top_emblem_overlay:SetTexCoord(0.86, 0.962, 0, 0.12)
		death_alert_frame.textures.top_emblem_overlay:Show()

		if death_alert_frame.textures.enemy_portrait == nil then
			death_alert_frame.textures.enemy_portrait = death_alert_frame:CreateTexture(nil, "OVERLAY")
		end
		death_alert_frame.textures.enemy_portrait:SetPoint(
			"TOP",
			death_alert_frame.textures.top,
			"TOP",
			2,
			-death_alert_frame.textures.top:GetHeight() * 0.27
		)
		death_alert_frame.textures.enemy_portrait:SetWidth(death_alert_frame.textures.top:GetHeight() * 0.225 * 0.8)
		death_alert_frame.textures.enemy_portrait:SetHeight(death_alert_frame.textures.top:GetHeight() * 0.225 * 0.8)
		death_alert_frame.textures.enemy_portrait:SetDrawLayer("OVERLAY", 7)
		death_alert_frame.textures.enemy_portrait:Show()

		if death_alert_frame.textures.enemy_portrait_mask == nil then
			death_alert_frame.textures.enemy_portrait_mask = death_alert_frame:CreateMaskTexture()
		end

		death_alert_frame.textures.enemy_portrait_mask:SetPoint(
			"CENTER",
			death_alert_frame.textures.enemy_portrait,
			"CENTER",
			0,
			0
		)
		death_alert_frame.textures.enemy_portrait_mask:SetHeight(
			death_alert_frame.textures.enemy_portrait:GetWidth() * 1
		)
		death_alert_frame.textures.enemy_portrait_mask:SetWidth(
			death_alert_frame.textures.enemy_portrait:GetWidth() * 1
		)
		death_alert_frame.textures.enemy_portrait_mask:SetTexture(
			"Interface\\Addons\\Deathlog\\Media\\blur_mask.blp",
			"CLAMPTOBLACKADDITIVE",
			"CLAMPTOBLACKADDITIVE"
		)
		death_alert_frame.textures.enemy_portrait:AddMaskTexture(death_alert_frame.textures.enemy_portrait_mask)
	end

	if death_alert_frame.textures.bottom_emblem == nil then
		death_alert_frame.textures.bottom_emblem = death_alert_frame:CreateTexture(nil, "OVERLAY")
	end
	death_alert_frame.textures.bottom_emblem:SetPoint(
		"TOP",
		death_alert_frame.textures.top,
		"TOP",
		0,
		-death_alert_frame.textures.top:GetHeight() * 0.639
	)
	death_alert_frame.textures.bottom_emblem:SetWidth(death_alert_frame.textures.top:GetHeight() * 0.35)
	death_alert_frame.textures.bottom_emblem:SetHeight(death_alert_frame.textures.top:GetHeight() * 0.1)
	death_alert_frame.textures.bottom_emblem:SetDrawLayer("OVERLAY", 5)
	death_alert_frame.textures.bottom_emblem:SetVertexColor(1, 1, 1, 1)
	death_alert_frame.textures.bottom_emblem:SetTexture("Interface\\LevelUp\\BossBanner")
	death_alert_frame.textures.bottom_emblem:SetTexCoord(0.85, 1, 0.32, 0.37)
	death_alert_frame.textures.bottom_emblem:Show()

	death_alert_frame.text:SetPoint(
		"CENTER",
		death_alert_frame.textures.top,
		"CENTER",
		0,
		-death_alert_frame.textures.top:GetHeight() * 0.04
	)
	death_alert_frame:Hide()
end

local options = nil
local optionsframe = nil
function Deathlog_DeathAlertWidget_applySettings()
	applyDefaults(defaults)

	death_alert_frame:ClearAllPoints()
	death_alert_frame:SetPoint(
		"CENTER",
		UIParent,
		"CENTER",
		deathlog_settings[widget_name]["pos_x"],
		deathlog_settings[widget_name]["pos_y"]
	)

	death_alert_frame:SetSize(deathlog_settings[widget_name]["size_x"], deathlog_settings[widget_name]["size_y"])

	if deathlog_settings[widget_name]["style"] == "boss_banner_basic" then
		initializeBossBanner()
	elseif deathlog_settings[widget_name]["style"] == "boss_banner_enemy_icon" then
		initializeBossBanner("enemy_icon")
	end

	death_alert_frame.text:SetFont(
		fonts[deathlog_settings[widget_name]["font"]],
		deathlog_settings[widget_name]["font_size"]
	)

	death_alert_frame.text:SetTextColor(
		deathlog_settings[widget_name]["font_color_r"],
		deathlog_settings[widget_name]["font_color_g"],
		deathlog_settings[widget_name]["font_color_b"],
		deathlog_settings[widget_name]["font_color_a"]
	)

	if optionsframe == nil then
		LibStub("AceConfig-3.0"):RegisterOptionsTable(widget_name, options)
		optionsframe = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(widget_name, widget_name, "Deathlog")
	end
end

local function forceReset()
	applyDefaults(defaults, true)
	Deathlog_DeathAlertWidget_applySettings()
end

options = {
	name = widget_name,
	handler = Minilog,
	type = "group",
	args = {
		enable = {
			type = "toggle",
			name = "Show Death Alert",
			desc = "Show Death Alert",
			get = function()
				return deathlog_settings[widget_name]["enable"]
			end,
			set = function()
				deathlog_settings[widget_name]["enable"] = not deathlog_settings[widget_name]["enable"]
				Deathlog_DeathAlertWidget_applySettings()
			end,
		},
		reset_size_and_pos = {
			type = "execute",
			name = "Reset to default",
			desc = "Reset to default",
			func = function()
				forceReset()
			end,
		},
		test = {
			type = "execute",
			name = "Test",
			desc = "Test the death alert.  Clicking this button fakes a death alert.",
			func = function()
				Deathlog_DeathAlertFakeDeath()
			end,
		},
		x_size = {
			type = "range",
			name = "X-Scale",
			desc = "X-Scale",
			min = 200,
			max = 1000,
			step = 1,
			get = function()
				return deathlog_settings[widget_name]["size_x"]
			end,
			set = function(self, value)
				deathlog_settings[widget_name]["size_x"] = value
				Deathlog_DeathAlertWidget_applySettings()
			end,
		},
		y_size = {
			type = "range",
			name = "Y-Scale",
			desc = "Y-Scale",
			min = 50,
			max = 600,
			step = 1,
			get = function()
				return deathlog_settings[widget_name]["size_y"]
			end,
			set = function(self, value)
				deathlog_settings[widget_name]["size_y"] = value
				Deathlog_DeathAlertWidget_applySettings()
			end,
		},
		pos_x = {
			type = "range",
			name = "X-Position",
			desc = "X-Position",
			min = -1000,
			max = 1000,
			step = 1,
			get = function()
				return deathlog_settings[widget_name]["pos_x"]
			end,
			set = function(self, value)
				deathlog_settings[widget_name]["pos_x"] = value
				Deathlog_DeathAlertWidget_applySettings()
			end,
		},
		pos_y = {
			type = "range",
			name = "Y-Position",
			desc = "Y-Position",
			min = -1000,
			max = 1000,
			step = 1,
			get = function()
				return deathlog_settings[widget_name]["pos_y"]
			end,
			set = function(self, value)
				deathlog_settings[widget_name]["pos_y"] = value
				Deathlog_DeathAlertWidget_applySettings()
			end,
		},
		display_time = {
			type = "range",
			name = "Alert Display Time",
			desc = "Alert Display Time",
			min = 1,
			max = 10,
			step = 0.5,
			get = function()
				return deathlog_settings[widget_name]["display_time"]
			end,
			set = function(self, value)
				deathlog_settings[widget_name]["display_time"] = value
				Deathlog_DeathAlertWidget_applySettings()
			end,
		},
		dl_styles = {
			type = "select",
			dialogControl = "LSM30_Font", --Select your widget here
			name = "Theme",
			desc = "Choose a Deathlog Alert Theme",
			values = death_alert_styles, -- pull in your font list from LSM
			get = function()
				return deathlog_settings[widget_name]["style"]
			end,
			set = function(self, key)
				deathlog_settings[widget_name]["style"] = key
				Deathlog_DeathAlertWidget_applySettings()
			end,
		},
		font = {
			type = "select",
			dialogControl = "LSM30_Font", --Select your widget here
			name = "Font",
			desc = "Font to use for death alerts.",
			values = fonts, -- pull in your font list from LSM
			get = function()
				return deathlog_settings[widget_name]["font"]
			end,
			set = function(self, key)
				deathlog_settings[widget_name]["font"] = key
				Deathlog_DeathAlertWidget_applySettings()
			end,
		},
		font_size = {
			type = "range",
			name = "Font size",
			desc = "Font size",
			min = 6,
			max = 40,
			step = 1,
			get = function()
				return deathlog_settings[widget_name]["font_size"]
			end,
			set = function(self, value)
				deathlog_settings[widget_name]["font_size"] = value
				Deathlog_DeathAlertWidget_applySettings()
			end,
		},
		font_color = {
			type = "color",
			name = "Font color",
			desc = "Font color",
			get = function()
				return deathlog_settings[widget_name]["font_color_r"],
					deathlog_settings[widget_name]["font_color_g"],
					deathlog_settings[widget_name]["font_color_b"],
					deathlog_settings[widget_name]["font_color_a"]
			end,
			set = function(self, r, g, b, a)
				deathlog_settings[widget_name]["font_color_r"] = r
				deathlog_settings[widget_name]["font_color_g"] = g
				deathlog_settings[widget_name]["font_color_b"] = b
				deathlog_settings[widget_name]["font_color_a"] = a

				Deathlog_DeathAlertWidget_applySettings()
			end,
		},
	},
}
