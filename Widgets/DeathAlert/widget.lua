local AceGUI = LibStub("AceGUI-3.0")
local widget_name = "DeathAlert"
local alert_cache = {}
local death_alert_frame = CreateFrame("frame")
local death_alert_styles = {
	["boss_banner_basic_small"] = "boss_banner_basic_small",
	["boss_banner_basic_medium"] = "boss_banner_basic_medium",
	["boss_banner_enemy_icon_small"] = "boss_banner_enemy_icon_small",
	["boss_banner_enemy_icon_medium"] = "boss_banner_enemy_icon_medium",
	["boss_banner_enemy_icon_animated"] = "boss_banner_enemy_icon_animated",
	-- ["lf_animated"] = "lf_animated",
}
local LSM30 = LibStub("LibSharedMedia-3.0", true)
local sounds = LSM30:HashTable("sound")
sounds["default_hardcore"] = 8959
sounds["golfclap"] = "Interface\\AddOns\\Deathlog\\Sounds\\golfclap.ogg"
sounds["hunger_games"] = "Interface\\AddOns\\Deathlog\\Sounds\\hunger_games.ogg"
local fonts = LSM30:HashTable("font")
fonts["blei00d"] = "Fonts\\blei00d.TTF"
fonts["BreatheFire"] = "Interface\\AddOns\\Deathlog\\Fonts\\BreatheFire.ttf"
fonts["BlackChancery"] = "Interface\\AddOns\\Deathlog\\Fonts\\BLKCHCRY.TTF"
fonts["ArgosGeorge"] = "Interface\\AddOns\\Deathlog\\Fonts\\ArgosGeorge.ttf"
fonts["GothicaBook"] = "Interface\\AddOns\\Deathlog\\Fonts\\Gothica-Book.ttf"
fonts["Immortal"] = "Interface\\AddOns\\Deathlog\\Fonts\\IMMORTAL.ttf"
fonts["BlackwoodCastle"] = "Interface\\AddOns\\Deathlog\\Fonts\\BlackwoodCastle.ttf"
fonts["Alegreya"] = "Interface\\AddOns\\Deathlog\\Fonts\\alegreya.regular.ttf"
fonts["Cathedral"] = "Interface\\AddOns\\Deathlog\\Fonts\\Cathedral.ttf"
fonts["FletcherGothic"] = "Interface\\AddOns\\Deathlog\\Fonts\\FletcherGothic-pwy.ttf"
fonts["GothamNarrowUltra"] = "Interface\\AddOns\\Deathlog\\Fonts\\GothamNarrowUltra.ttf"

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
	local r = math.random(1, 100)
	local s = nil
	for k, _ in pairs(id_to_display_id) do
		if r == 0 then
			s = k
			break
		end
		r = r - 1
	end
	local fake_entry = {
		["name"] = UnitName("player"),
		["level"] = UnitLevel("player"),
		["race_id"] = 3,
		-- ["map_id"] = 1429,
		["instance_id"] = 34, --34,
		["class_id"] = 9,
		["source_id"] = s,
		["last_words"] = "Sample last words, help!",
	}
	alert_cache[UnitName("player")] = nil
	Deathlog_DeathAlertPlay(fake_entry)
end

function Deathlog_DeathAlertPlay(entry)
	if deathlog_settings[widget_name]["enable"] == false then
		return
	end
	local min_lvl = deathlog_settings[widget_name]["min_lvl_player"] and UnitLevel("player")
		or deathlog_settings[widget_name]["min_lvl"]
	if entry["level"] and (entry["level"] < min_lvl or entry["level"] > deathlog_settings[widget_name]["max_lvl"]) then
		return
	end

	if deathlog_settings[widget_name]["guild_only"] then
		local guildName, guildRankName, guildRankIndex = GetGuildInfo("player")
		if entry["guild"] ~= guildName then
			return
		end
	end
	if alert_cache[entry["name"]] then
		return
	end
	alert_cache[entry["name"]] = 1

	if deathlog_settings[widget_name]["alert_sound"] == "default_hardcore" then
		PlaySound(8959)
	else
		PlaySoundFile(sounds[deathlog_settings[widget_name]["alert_sound"]])
	end
	death_alert_frame.text:SetText("Some text")

	local class = GetClassInfo(entry["class_id"]) or ""
	if deathlog_class_colors[class] then
		class = "|c" .. deathlog_class_colors[class]:GenerateHexColor() .. class .. "|r"
	end
	local race = ""
	if entry["race_id"] then
		race = C_CreatureInfo.GetRaceInfo(entry["race_id"])
		if race then
			race = race.raceName
		else
			race = ""
		end
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

	local msg = deathlog_settings[widget_name]["message"]
	local source_name = ""
	if entry["source_id"] then
		if id_to_npc[entry["source_id"]] then
			source_name = id_to_npc[entry["source_id"]]
		end
	end
	if entry["source_id"] == -2 then
		msg = deathlog_settings[widget_name]["drown_message"]
	end
	if entry["source_id"] == -3 then
		msg = deathlog_settings[widget_name]["fall_message"]
	end
	msg = msg:gsub("%<name>", entry["name"])
	msg = msg:gsub("%<class>", class)
	msg = msg:gsub("%<race>", race)
	msg = msg:gsub("%<source>", source_name)
	msg = msg:gsub("%<level>", entry["level"])
	msg = msg:gsub("%<zone>", zone)
	msg = msg:gsub("%<last_words>", entry["last_words"] or "")

	death_alert_frame.text:SetText(
		entry["name"]
			.. " the "
			.. race
			.. " "
			.. class
			.. " has been slain\nby "
			.. source_name
			.. ", at level "
			.. entry["level"]
			.. " in "
			.. zone
			.. "."
	)

	death_alert_frame.text:SetText(msg)

	if
		deathlog_settings[widget_name]["style"] == "boss_banner_enemy_icon_small"
		or deathlog_settings[widget_name]["style"] == "boss_banner_enemy_icon_medium"
	then
		if entry["source_id"] then
			if id_to_display_id[entry["source_id"]] then
				SetPortraitTextureFromCreatureDisplayID(
					death_alert_frame.textures.enemy_portrait,
					id_to_display_id[entry["source_id"]]
				)
				death_alert_frame.textures.enemy_portrait:AddMaskTexture(death_alert_frame.textures.enemy_portrait_mask)
			elseif entry["source_id"] == -2 then
				death_alert_frame.textures.enemy_portrait:SetTexture("Interface\\ICONS\\Ability_Suffocate")
			elseif entry["source_id"] == -3 then
				death_alert_frame.textures.enemy_portrait:SetTexture("Interface\\ICONS\\Spell_Magic_FeatherFall")
			end
		end
	elseif
		deathlog_settings[widget_name]["style"] == "boss_banner_enemy_icon_animated"
		or deathlog_settings[widget_name]["style"] == "lf_animated"
	then
		local texture = death_alert_frame.textures.enemy_portrait
		death_alert_frame.textures.enemy_portrait:Hide()
		local drawLayer = texture:GetDrawLayer()
		if death_alert_frame.textures.animated_portrait == nil then
			death_alert_frame.textures.animated_portrait = {}
		end
		local portrait = death_alert_frame.textures.animated_portrait
		portrait.cx = texture:GetWidth()
		portrait.cy = texture:GetHeight()

		if drawLayer == "OVERLAY" then
			drawLayer = "ARTWORK"
		else
			drawLayer = "BACKGROUND"
		end

		if death_alert_frame.textures.backlayer == nil then
			death_alert_frame.textures.backlayer = texture:GetParent():CreateTexture(nil, drawLayer, nil, -1)
		end
		portrait.backLayer = death_alert_frame.textures.backlayer --drawLayer=="OVERLAY" and "ARTWORK" or drawLayer)
		portrait.backLayer:Hide()
		portrait.backLayer:SetTexture("Interface\\AddOns\\Adapt\\Adapt-ModelBack")
		portrait.backLayer:SetWidth(portrait.cx)
		portrait.backLayer:SetHeight(portrait.cy)
		for i = 1, texture:GetNumPoints() do
			portrait.backLayer:SetPoint(texture:GetPoint(i))
		end

		if death_alert_frame.textures.modelLayer == nil then
			death_alert_frame.textures.modelLayer = CreateFrame("PlayerModel", nil, death_alert_frame)
		end
		portrait.modelLayer = death_alert_frame.textures.modelLayer
		portrait.modelLayer.useParentLevel = true
		portrait.modelLayer:Hide()
		portrait.modelLayer.parentTexture = texture
		portrait.modelLayer:SetModelDrawLayer("OVERLAY", 6) -- put model at drawLayer of texture

		if death_alert_frame.textures.maskLayer == nil then
			death_alert_frame.textures.maskLayer = death_alert_frame:CreateTexture(nil, drawLayer, nil, 1)
		end
		portrait.maskLayer = death_alert_frame.textures.maskLayer

		portrait.maskLayer:SetPoint("TOPLEFT", portrait.backLayer)
		portrait.maskLayer:SetPoint("BOTTOMRIGHT", portrait.backLayer)
		portrait.maskLayer:SetTexture("Interface\\AddOns\\Adapt\\Adapt-Mask")

		local parent = texture:GetParent()
		local xoff, yoff, toff = 0, 0, 0.2
		if 1 == 1 then -- round portraits
			local coeff = 0.1175
			xoff = coeff * portrait.cx -- circle portrait has model slightly smaller
			yoff = coeff * portrait.cy
			toff = 0 -- and full texcoord of background texture
		end
		portrait.modelLayer:SetPoint("CENTER", death_alert_frame.textures.top_emblem_overlay, "CENTER", 0, 0)
		portrait.modelLayer:SetWidth(death_alert_frame.textures.top_emblem_overlay:GetWidth() * 0.55)
		portrait.modelLayer:SetHeight(death_alert_frame.textures.top_emblem_overlay:GetHeight() * 0.55)
		portrait.modelLayer:SetShown(true)
		portrait.backLayer:SetTexCoord(toff, 1 - toff, toff, 1 - toff)
		portrait.maskLayer:SetShown(false)
		if id_to_display_id[entry["source_id"]] then
			portrait.modelLayer:SetDisplayInfo(id_to_display_id[entry["source_id"]])
		end
		portrait.modelLayer:SetPortraitZoom(1)
		if 2 == 1 then
			portrait.modelLayer:SetRotation(MODELFRAME_DEFAULT_ROTATION)
		else
			portrait.modelLayer:SetRotation(0)
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
	["style"] = "boss_banner_enemy_icon_medium",
	["display_time"] = 6,
	["alert_subset"] = "faction_wide",
	["font"] = "Nimrod MT",
	["font_size"] = 16,
	["font_color_r"] = 1,
	["font_color_g"] = 1,
	["font_color_b"] = 1,
	["font_color_a"] = 1,
	["message"] = "<name> the <race> <class> has been slain\nby <source> at lvl <level> in <zone>.",
	["fall_message"] = "<name> the <race> <class> fell to\ndeath at lvl <level> in <zone>.",
	["drown_message"] = "<name> the <race> <class> drowned\n at lvl <level> in <zone>.",
	["min_lvl"] = 1,
	["min_lvl_player"] = false,
	["max_lvl"] = MAX_PLAYER_LEVEL,
	["guild_only"] = false,
	["accent_color_r"] = 1,
	["accent_color_g"] = 1,
	["accent_color_b"] = 1,
	["accent_color_a"] = 1,
	["alert_sound"] = "default_hardcore",
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

local function initializeLFBanner(icon_type, icon_size)
	if death_alert_frame.textures == nil then
		death_alert_frame.textures = {}
	end
	if death_alert_frame.textures.top == nil then
		death_alert_frame.textures.top = death_alert_frame:CreateTexture(nil, "OVERLAY")
	end
	death_alert_frame.textures.top:SetPoint("CENTER", death_alert_frame, "CENTER", 0, 0)
	death_alert_frame.textures.top:SetWidth(400)
	death_alert_frame.textures.top:SetHeight(120)
	death_alert_frame.textures.top:SetDrawLayer("OVERLAY", 4)
	death_alert_frame.textures.top:SetVertexColor(1, 1, 1, 1)
	death_alert_frame.textures.top:SetTexture("Interface\\LootFrame\\LootToastAtlas")
	death_alert_frame.textures.top:SetTexCoord(0.55, 0.825, 0.39, 0.7)
	death_alert_frame.textures.top:Show()

	if death_alert_frame.textures.top_emblem == nil then
		death_alert_frame.textures.top_emblem = death_alert_frame:CreateTexture(nil, "OVERLAY")
	end
	death_alert_frame.textures.top_emblem:SetPoint(
		"LEFT",
		death_alert_frame.textures.top,
		"LEFT",
		death_alert_frame.textures.top:GetWidth() * 0.1,
		0
	)
	death_alert_frame.textures.top_emblem:SetWidth(death_alert_frame.textures.top:GetHeight() * 0.5 * 1.5)
	death_alert_frame.textures.top_emblem:SetHeight(death_alert_frame.textures.top:GetHeight() * 0.2 * 1.5)

	death_alert_frame.textures.top_emblem:SetDrawLayer("OVERLAY", 5)
	death_alert_frame.textures.top_emblem:SetVertexColor(1, 1, 1, 1)
	death_alert_frame.textures.top_emblem:SetTexture("Interface\\LevelUp\\BossBanner")
	death_alert_frame.textures.top_emblem:SetTexCoord(0.24, 0.59, 0.58, 0.72)
	death_alert_frame.textures.top_emblem:Show()

	if death_alert_frame.textures.top_emblem_overlay == nil then
		death_alert_frame.textures.top_emblem_overlay = death_alert_frame:CreateTexture(nil, "OVERLAY")
	end

	death_alert_frame.textures.top_emblem_overlay:SetPoint(
		"LEFT",
		death_alert_frame.textures.top,
		"LEFT",
		death_alert_frame:GetWidth() * 0.075,
		0
	)
	death_alert_frame.textures.top_emblem_overlay:SetWidth(death_alert_frame.textures.top:GetHeight() * 0.225 * 2.7)
	death_alert_frame.textures.top_emblem_overlay:SetHeight(death_alert_frame.textures.top:GetHeight() * 0.225 * 2.7)
	death_alert_frame.textures.top_emblem_overlay:SetTexture("Interface\\PVPFrame\\SilverIconBorder")
	death_alert_frame.textures.top_emblem_overlay:SetVertexColor(0.5, 0.2, 0.2, 1)
	death_alert_frame.textures.top_emblem_overlay:SetDrawLayer("OVERLAY", 7)

	death_alert_frame.textures.top_emblem_overlay:Show()

	if death_alert_frame.textures.top_emblem_background == nil then
		death_alert_frame.textures.top_emblem_background = death_alert_frame:CreateTexture(nil, "OVERLAY")
	end
	death_alert_frame.textures.top_emblem_background:SetPoint(
		"CENTER",
		death_alert_frame.textures.top_emblem_overlay,
		"CENTER",
		0,
		0
	)
	death_alert_frame.textures.top_emblem_background:SetHeight(
		death_alert_frame.textures.top_emblem_overlay:GetHeight() * 0.7
	)
	death_alert_frame.textures.top_emblem_background:SetWidth(
		death_alert_frame.textures.top_emblem_overlay:GetWidth() * 0.7
	)

	death_alert_frame.textures.top_emblem_background:SetDrawLayer("OVERLAY", 6)
	death_alert_frame.textures.top_emblem_background:SetColorTexture(0, 0, 0, 1)

	if death_alert_frame.textures.enemy_portrait == nil then
		death_alert_frame.textures.enemy_portrait = death_alert_frame:CreateTexture(nil, "OVERLAY")
	end
	death_alert_frame.textures.enemy_portrait:SetPoint(
		"TOP",
		death_alert_frame.textures.top,
		"TOP",
		2,
		-death_alert_frame.textures.top:GetHeight() * 0.237
	)
	death_alert_frame.textures.enemy_portrait:SetWidth(death_alert_frame.textures.top:GetHeight() * 0.225 * 0.8 * 1.15)
	death_alert_frame.textures.enemy_portrait:SetHeight(death_alert_frame.textures.top:GetHeight() * 0.225 * 0.8 * 1.15)
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
	death_alert_frame.textures.enemy_portrait_mask:SetHeight(death_alert_frame.textures.enemy_portrait:GetWidth() * 1)
	death_alert_frame.textures.enemy_portrait_mask:SetWidth(death_alert_frame.textures.enemy_portrait:GetWidth() * 1)
	death_alert_frame.textures.enemy_portrait_mask:SetTexture(
		"Interface\\Addons\\Deathlog\\Media\\blur_mask.blp",
		"CLAMPTOBLACKADDITIVE",
		"CLAMPTOBLACKADDITIVE"
	)
	death_alert_frame.textures.enemy_portrait:AddMaskTexture(death_alert_frame.textures.enemy_portrait_mask)

	death_alert_frame.text:SetPoint(
		"CENTER",
		death_alert_frame.textures.top,
		"CENTER",
		death_alert_frame:GetWidth() * 0.05,
		-death_alert_frame.textures.top:GetHeight() * 0.04
	)

	death_alert_frame.text:SetWidth(death_alert_frame:GetWidth() * 0.3)
	death_alert_frame:Hide()
end

local function initializeBossBanner(icon_type, icon_size)
	if death_alert_frame.textures == nil then
		death_alert_frame.textures = {}
	end
	if death_alert_frame.textures.top == nil then
		death_alert_frame.textures.top = death_alert_frame:CreateTexture(nil, "OVERLAY")
	end
	death_alert_frame.textures.top:SetAllPoints()
	death_alert_frame.textures.top:SetDrawLayer("OVERLAY", 4)
	death_alert_frame.textures.top:SetVertexColor(
		deathlog_settings[widget_name]["accent_color_r"],
		deathlog_settings[widget_name]["accent_color_g"],
		deathlog_settings[widget_name]["accent_color_b"],
		deathlog_settings[widget_name]["accent_color_a"]
	)
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
	death_alert_frame.textures.middle:SetVertexColor(
		deathlog_settings[widget_name]["accent_color_r"],
		deathlog_settings[widget_name]["accent_color_g"],
		deathlog_settings[widget_name]["accent_color_b"],
		deathlog_settings[widget_name]["accent_color_a"]
	)
	death_alert_frame.textures.middle:SetTexture("Interface\\LevelUp\\BossBanner")
	death_alert_frame.textures.middle:SetTexCoord(0, 0.8, 0.43, 0.58)
	death_alert_frame.textures.middle:Show()

	if death_alert_frame.textures.top_emblem == nil then
		death_alert_frame.textures.top_emblem = death_alert_frame:CreateTexture(nil, "OVERLAY")
	end
	if icon_size == "small" then
		death_alert_frame.textures.top_emblem:SetPoint(
			"TOP",
			death_alert_frame.textures.top,
			"TOP",
			0,
			-death_alert_frame.textures.top:GetHeight() * 0.209
		)
		death_alert_frame.textures.top_emblem:SetWidth(death_alert_frame.textures.top:GetHeight() * 0.5 * 1.25)
		death_alert_frame.textures.top_emblem:SetHeight(death_alert_frame.textures.top:GetHeight() * 0.2 * 1.25)
	elseif icon_size == "medium" or icon_size == "animated" then
		death_alert_frame.textures.top_emblem:SetPoint(
			"BOTTOM",
			death_alert_frame.textures.top,
			"BOTTOM",
			0,
			death_alert_frame.textures.top:GetHeight() * 0.53
		)
		death_alert_frame.textures.top_emblem:SetWidth(death_alert_frame.textures.top:GetHeight() * 0.5 * 1.5)
		death_alert_frame.textures.top_emblem:SetHeight(death_alert_frame.textures.top:GetHeight() * 0.2 * 1.5)
	end
	death_alert_frame.textures.top_emblem:SetDrawLayer("OVERLAY", 5)
	death_alert_frame.textures.top_emblem:SetVertexColor(
		deathlog_settings[widget_name]["accent_color_r"],
		deathlog_settings[widget_name]["accent_color_g"],
		deathlog_settings[widget_name]["accent_color_b"],
		deathlog_settings[widget_name]["accent_color_a"]
	)
	death_alert_frame.textures.top_emblem:SetTexture("Interface\\LevelUp\\BossBanner")
	death_alert_frame.textures.top_emblem:SetTexCoord(0.24, 0.59, 0.58, 0.72)
	death_alert_frame.textures.top_emblem:Show()

	if icon_type == "enemy_icon" then
		if death_alert_frame.textures.top_emblem_overlay == nil then
			death_alert_frame.textures.top_emblem_overlay = death_alert_frame:CreateTexture(nil, "OVERLAY")
		end
		if icon_size == "small" then
			death_alert_frame.textures.top_emblem_overlay:SetPoint(
				"TOP",
				death_alert_frame.textures.top,
				"TOP",
				0,
				-death_alert_frame.textures.top:GetHeight() * 0.21
			)
			death_alert_frame.textures.top_emblem_overlay:SetWidth(death_alert_frame.textures.top:GetHeight() * 0.225)
			death_alert_frame.textures.top_emblem_overlay:SetHeight(death_alert_frame.textures.top:GetHeight() * 0.225)
			death_alert_frame.textures.top_emblem_overlay:SetTexture("Interface\\LevelUp\\BossBanner")
			death_alert_frame.textures.top_emblem_overlay:SetTexCoord(0.86, 0.962, 0, 0.12)
			death_alert_frame.textures.top_emblem_overlay:SetDrawLayer("OVERLAY", 6)
			death_alert_frame.textures.top_emblem_overlay:SetVertexColor(
				deathlog_settings[widget_name]["accent_color_r"],
				deathlog_settings[widget_name]["accent_color_g"],
				deathlog_settings[widget_name]["accent_color_b"],
				deathlog_settings[widget_name]["accent_color_a"]
			)
		elseif icon_size == "animated" then
			death_alert_frame.textures.top_emblem_overlay:SetPoint(
				"TOP",
				death_alert_frame.textures.top,
				"TOP",
				2,
				-death_alert_frame.textures.top:GetHeight() * 0.14
			)
			death_alert_frame.textures.top_emblem_overlay:SetWidth(
				death_alert_frame.textures.top:GetHeight() * 0.225 * 1.7
			)
			death_alert_frame.textures.top_emblem_overlay:SetHeight(
				death_alert_frame.textures.top:GetHeight() * 0.225 * 1.7
			)
			death_alert_frame.textures.top_emblem_overlay:SetTexture("Interface\\PVPFrame\\SilverIconBorder")
			death_alert_frame.textures.top_emblem_overlay:SetVertexColor(
				deathlog_settings[widget_name]["accent_color_r"] * 0.5,
				deathlog_settings[widget_name]["accent_color_g"] * 0.2,
				deathlog_settings[widget_name]["accent_color_b"] * 0.2,
				deathlog_settings[widget_name]["accent_color_a"] * 1
			)
			death_alert_frame.textures.top_emblem_overlay:SetDrawLayer("OVERLAY", 7)

			if death_alert_frame.textures.top_emblem_background == nil then
				death_alert_frame.textures.top_emblem_background = death_alert_frame:CreateTexture(nil, "OVERLAY")
			end
			death_alert_frame.textures.top_emblem_background:SetPoint(
				"CENTER",
				death_alert_frame.textures.top_emblem_overlay,
				"CENTER",
				0,
				0
			)
			death_alert_frame.textures.top_emblem_background:SetHeight(
				death_alert_frame.textures.top_emblem_overlay:GetHeight() * 0.7
			)
			death_alert_frame.textures.top_emblem_background:SetWidth(
				death_alert_frame.textures.top_emblem_overlay:GetWidth() * 0.7
			)
			death_alert_frame.textures.top_emblem_background:SetDrawLayer("OVERLAY", 6)
			death_alert_frame.textures.top_emblem_background:SetColorTexture(0, 0, 0, 1)
		end
		-- death_alert_frame.textures.top_emblem_overlay:SetTexture("Interface\\LevelUp\\BossBanner")
		death_alert_frame.textures.top_emblem_overlay:Show()

		if death_alert_frame.textures.enemy_portrait == nil then
			death_alert_frame.textures.enemy_portrait = death_alert_frame:CreateTexture(nil, "OVERLAY")
		end
		if icon_size == "small" then
			death_alert_frame.textures.enemy_portrait:SetPoint(
				"TOP",
				death_alert_frame.textures.top,
				"TOP",
				2,
				-death_alert_frame.textures.top:GetHeight() * 0.27
			)
			death_alert_frame.textures.enemy_portrait:SetWidth(death_alert_frame.textures.top:GetHeight() * 0.225 * 0.8)
			death_alert_frame.textures.enemy_portrait:SetHeight(
				death_alert_frame.textures.top:GetHeight() * 0.225 * 0.8
			)
		elseif icon_size == "medium" or icon_size == "animated" then
			death_alert_frame.textures.enemy_portrait:SetPoint(
				"TOP",
				death_alert_frame.textures.top,
				"TOP",
				2,
				-death_alert_frame.textures.top:GetHeight() * 0.237
			)
			death_alert_frame.textures.enemy_portrait:SetWidth(
				death_alert_frame.textures.top:GetHeight() * 0.225 * 0.8 * 1.15
			)
			death_alert_frame.textures.enemy_portrait:SetHeight(
				death_alert_frame.textures.top:GetHeight() * 0.225 * 0.8 * 1.15
			)
		end
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
	death_alert_frame.textures.bottom_emblem:SetVertexColor(
		deathlog_settings[widget_name]["accent_color_r"] * 0.5,
		deathlog_settings[widget_name]["accent_color_g"] * 0.2,
		deathlog_settings[widget_name]["accent_color_b"] * 0.2,
		deathlog_settings[widget_name]["accent_color_a"] * 1
	)
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

	if deathlog_settings[widget_name]["style"] == "boss_banner_basic_small" then
		initializeBossBanner(nil, "small")
	elseif deathlog_settings[widget_name]["style"] == "boss_banner_basic_medium" then
		initializeBossBanner(nil, "medium")
	elseif deathlog_settings[widget_name]["style"] == "boss_banner_enemy_icon_small" then
		initializeBossBanner("enemy_icon", "small")
	elseif deathlog_settings[widget_name]["style"] == "boss_banner_enemy_icon_medium" then
		initializeBossBanner("enemy_icon", "medium")
	elseif deathlog_settings[widget_name]["style"] == "boss_banner_enemy_icon_animated" then
		initializeBossBanner("enemy_icon", "animated")
	elseif deathlog_settings[widget_name]["style"] == "lf_animated" then
		initializeLFBanner("enemy_icon", "animated")
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
			order = 0,
			get = function()
				return deathlog_settings[widget_name]["enable"]
			end,
			set = function()
				deathlog_settings[widget_name]["enable"] = not deathlog_settings[widget_name]["enable"]
				Deathlog_DeathAlertWidget_applySettings()
			end,
		},
		guild_only_toggle = {
			type = "toggle",
			name = "Guild only alerts",
			desc = "Only show alerts for deaths within the player's guild.",
			order = 1,
			get = function()
				return deathlog_settings[widget_name]["guild_only"]
			end,
			set = function()
				deathlog_settings[widget_name]["guild_only"] = not deathlog_settings[widget_name]["guild_only"]
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
			order = 2,
			get = function()
				return deathlog_settings[widget_name]["display_time"]
			end,
			set = function(self, value)
				deathlog_settings[widget_name]["display_time"] = value
				Deathlog_DeathAlertWidget_applySettings()
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
		lvl_opts = {
			type = "group",
			name = "Level Settings",
			inline = true,
			order = 5,
			args = {
				min_lvl = {
					type = "range",
					name = "Min. Lvl. to Display",
					desc = "Minimum level to display",
					min = 1,
					max = MAX_PLAYER_LEVEL,
					step = 1,
					order = 1,
					disabled = function()
						return deathlog_settings[widget_name]["min_lvl_player"]
					end,
					get = function()
						if deathlog_settings[widget_name]["min_lvl_player"] then
							return UnitLevel("player")
						end
						return deathlog_settings[widget_name]["min_lvl"]
					end,
					set = function(self, value)
						deathlog_settings[widget_name]["min_lvl"] = value
						Deathlog_DeathAlertWidget_applySettings()
					end,
				},
				max_lvl = {
					type = "range",
					name = "Max. Lvl. to Display",
					desc = "Maximum level to display",
					min = 1,
					max = MAX_PLAYER_LEVEL,
					step = 1,
					get = function()
						return deathlog_settings[widget_name]["max_lvl"]
					end,
					set = function(self, value)
						deathlog_settings[widget_name]["max_lvl"] = value
						Deathlog_DeathAlertWidget_applySettings()
					end,
				},
				min_lvl_player = {
					type = "toggle",
					name = "Use my level as Min. Lvl.",
					desc = "Only show alerts for characters your level or higher",
					get = function()
						return deathlog_settings[widget_name]["min_lvl_player"]
					end,
					set = function(self, value)
						deathlog_settings[widget_name]["min_lvl_player"] = value
						Deathlog_DeathAlertWidget_applySettings()
					end,
				},
			},
		},
		dl_styles = {
			type = "select",
			dialogControl = "LSM30_Font", --Select your widget here
			name = "Theme",
			width = 1.4,
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
		msginput = {
			type = "input",
			name = "Message",
			desc = "Customize the death alert message. \nSubstitutions:\n<name> = Character name\n<race> = Character race\n<class> = Character class\n<level> = Character level\n<source> = Killer name\n<zone> = Character zone\n<last_words> = Last words",
			width = 2.5,
			multiline = true,
			get = function()
				return deathlog_settings[widget_name]["message"]
			end,
			set = function(self, msg)
				deathlog_settings[widget_name]["message"] = msg
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
		accent_color = {
			type = "color",
			name = "Frame accent color",
			desc = "Frame accent color",
			get = function()
				return deathlog_settings[widget_name]["accent_color_r"],
					deathlog_settings[widget_name]["accent_color_g"],
					deathlog_settings[widget_name]["accent_color_b"],
					deathlog_settings[widget_name]["accent_color_a"]
			end,
			set = function(self, r, g, b, a)
				deathlog_settings[widget_name]["accent_color_r"] = r
				deathlog_settings[widget_name]["accent_color_g"] = g
				deathlog_settings[widget_name]["accent_color_b"] = b
				deathlog_settings[widget_name]["accent_color_a"] = a

				Deathlog_DeathAlertWidget_applySettings()
			end,
		},
		da_sound = {
			type = "select",
			dialogControl = "LSM30_Sound", --Select your widget here
			name = "Death Alert Sound",
			desc = "Sound to use for death alerts.",
			values = LSM30:HashTable("sound"), -- pull in your font list from LSM
			get = function()
				return deathlog_settings[widget_name]["alert_sound"]
			end,
			set = function(self, key)
				deathlog_settings[widget_name]["alert_sound"] = key
				Deathlog_DeathAlertWidget_applySettings()
			end,
		},
		position = {
			type = "group",
			name = "Position",
			inline = true,
			order = -1,
			args = {
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
			},
		},
	},
}
