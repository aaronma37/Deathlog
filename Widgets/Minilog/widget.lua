local ace_refresh_timer_handle = nil
local entry_cache = {}
local font_handle = nil

local main_font = Deathlog_L.main_font
local deathlog_instance_tbl = Deathlog_L.instance_tbl

local tmap = {
	["Warrior"] = { 0, 0.25, 0, 0.25 },
	["Mage"] = { 0.25, 0.5, 0, 0.25 },
	["Rogue"] = { 0.5, 0.75, 0, 0.25 },
	["Druid"] = { 0.75, 1, 0, 0.25 },
	["Hunter"] = { 0, 0.25, 0.25, 0.5 },
	["Shaman"] = { 0.25, 0.5, 0.25, 0.5 },
	["Priest"] = { 0.5, 0.75, 0.25, 0.5 },
	["Warlock"] = { 0.75, 1, 0.25, 0.5 },
	["Paladin"] = { 0, 0.25, 0.5, 0.75 },
}

local rmap = {
	["Human"] = { 0, 0.25, 0, 0.25 },
	["Dwarf"] = { 0.25, 0.5, 0, 0.25 },
	["Gnome"] = { 0.5, 0.75, 0, 0.25 },
	["Night Elf"] = { 0.75, 1, 0, 0.25 },
	["Tauren"] = { 0, 0.25, 0.25, 0.5 },
	["Undead"] = { 0.25, 0.5, 0.25, 0.5 },
	["Troll"] = { 0.5, 0.75, 0.25, 0.5 },
	["Orc"] = { 0.75, 1, 0.25, 0.5 },
}

local presets = {
	["Hardcore (legacy)"] = "Hardcore (legacy)",
	["concise"] = "concise",
	["Yazpad"] = "Yazpad",
	["ChefCarlos"] = "ChefCarlos",
}

local LSM30 = LibStub("LibSharedMedia-3.0", true)
local default_font = Deathlog_L.mini_log_font
local widget_name = "minilog"

local fonts = LSM30:HashTable("font")
fonts["default_font"] = default_font
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

local themes = {
	["None"] = "None",
	["Parchment"] = "Parchment",
	["Warlock"] = "Warlock",
	["Druid"] = "Druid",
	["Paladin"] = "Paladin",
	["Warrior"] = "Warrior",
	["Hunter"] = "Hunter",
	["Priest"] = "Priest",
}

local AceGUI = LibStub("AceGUI-3.0")
local death_log_icon_frame = CreateFrame("frame")
death_log_icon_frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
death_log_icon_frame:SetSize(40, 40)
death_log_icon_frame:SetMovable(true)
death_log_icon_frame:EnableMouse(true)
death_log_icon_frame:Show()

local black_round_tex = death_log_icon_frame:CreateTexture(nil, "OVERLAY")
black_round_tex:SetPoint("CENTER", death_log_icon_frame, "CENTER", -5, 4)
black_round_tex:SetParent(UIParent)
black_round_tex:SetDrawLayer("OVERLAY", 2)
black_round_tex:SetHeight(40)
black_round_tex:SetWidth(40)
black_round_tex:SetTexture("Interface\\PVPFrame\\PVP-Separation-Circle-Cooldown-overlay")

local hc_fire_tex = death_log_icon_frame:CreateTexture(nil, "OVERLAY")
hc_fire_tex:SetParent(UIParent)
hc_fire_tex:SetPoint("CENTER", death_log_icon_frame, "CENTER", -4, 4)
hc_fire_tex:SetDrawLayer("OVERLAY", 3)
hc_fire_tex:SetHeight(25)
hc_fire_tex:SetWidth(25)
hc_fire_tex:SetTexture("Interface\\TARGETINGFRAME\\UI-TargetingFrame-Skull")

local gold_ring_tex = death_log_icon_frame:CreateTexture(nil, "OVERLAY")
gold_ring_tex:SetParent(UIParent)
gold_ring_tex:SetPoint("CENTER", death_log_icon_frame, "CENTER", 0, 0)
gold_ring_tex:SetDrawLayer("OVERLAY", 4)
gold_ring_tex:SetHeight(50)
gold_ring_tex:SetWidth(50)
gold_ring_tex:SetTexture("Interface\\COMMON\\BlueMenuRing")

death_log_icon_frame:HookScript("OnShow", function(self, button)
	black_round_tex:Show()
	hc_fire_tex:Show()
	gold_ring_tex:Show()
end)

death_log_icon_frame:HookScript("OnHide", function(self, button)
	black_round_tex:Hide()
	hc_fire_tex:Hide()
	gold_ring_tex:Hide()
end)

local environment_damage = {
	[-2] = "Drowning",
	[-3] = "Falling",
	[-4] = "Fatigue",
	[-5] = "Fire",
	[-6] = "Lava",
	[-7] = "Slime",
}
local WorldMapButton = WorldMapFrame:GetCanvas()
local death_tomb_frame = CreateFrame("frame", nil, WorldMapButton)
death_tomb_frame:SetAllPoints()
death_tomb_frame:SetFrameLevel(15000)

local death_tomb_frame_tex = death_tomb_frame:CreateTexture(nil, "OVERLAY")
death_tomb_frame_tex:SetTexture("Interface\\TARGETINGFRAME\\UI-TargetingFrame-Skull")
death_tomb_frame_tex:SetDrawLayer("OVERLAY", 4)
death_tomb_frame_tex:SetHeight(25)
death_tomb_frame_tex:SetWidth(25)
death_tomb_frame_tex:Hide()

local death_tomb_frame_tex_glow = death_tomb_frame:CreateTexture(nil, "OVERLAY")
death_tomb_frame_tex_glow:SetTexture("Interface\\Glues/Models/UI_HUMAN/GenericGlow64")
death_tomb_frame_tex_glow:SetDrawLayer("OVERLAY", 3)
death_tomb_frame_tex_glow:SetHeight(55)
death_tomb_frame_tex_glow:SetWidth(55)
death_tomb_frame_tex_glow:Hide()
local death_log_frame = AceGUI:Create("Deathlog_MiniLog")
death_log_frame.frame:SetMovable(false)
death_log_frame.frame:EnableMouse(false)
death_log_frame:SetTitle("Deathlog")
death_log_frame.titletext:SetFont(Deathlog_L.mini_log_font, 19, "THICK")
local subtitle_metadata = {
	["ColoredName"] = {
		"Name",
		80,
		function(_entry)
			local class_id = _entry.player_data["class_id"]
			if class_id then
				if deathlog_class_tbl[class_id] then
					if RAID_CLASS_COLORS[deathlog_id_to_class_tbl[class_id]:upper()] then
						return "|c"
							.. RAID_CLASS_COLORS[deathlog_id_to_class_tbl[class_id]:upper()].colorStr
							.. (_entry.player_data["name"] or "")
							.. "|r"
					end
				end
			end
			return _entry.player_data["name"] or ""
		end,
	},
	["Zone"] = {
		"Zone",
		70,
		function(_entry)
			if _entry.player_data["map_id"] then
				local mapinfo = C_Map.GetMapInfo(_entry.player_data["map_id"])
				return mapinfo.name or ""
			end
			if _entry.player_data["instance_id"] then
				return deathlog_id_to_instance_tbl[_entry.player_data["instance_id"]] or nil
			end
			return ""
		end,
	},
	["Name"] = {
		"Name",
		80,
		function(_entry)
			return _entry.player_data["name"] or ""
		end,
	},
	["Source"] = {
		"Source",
		120,
		function(_entry)
			if _entry.player_data["source_id"] == nil then
				return ""
			end
			local _source = id_to_npc[_entry.player_data["source_id"]]
				or environment_damage[_entry.player_data["source_id"]]
				or deathlog_decode_pvp_source(_entry.player_data["source_id"])
				or ""

			if _source == "" and deathlogPredictSource then
				_source = deathlogPredictSource(_entry.player_data["map_pos"], _entry.player_data["map_id"]) or ""
			end
			return _source
		end,
	},
	["Class"] = {
		"Class",
		60,
		function(_entry)
			local class_id = _entry.player_data["class_id"]
			if class_id then
				local class_str, _, _ = GetClassInfo(class_id)
				if class_id then
					if deathlog_id_to_class_tbl[class_id] then
						if RAID_CLASS_COLORS[deathlog_id_to_class_tbl[class_id]:upper()] then
							return "|c"
								.. RAID_CLASS_COLORS[deathlog_id_to_class_tbl[class_id]:upper()].colorStr
								.. class_str
								.. "|r"
						end
					end
				end
				return class_str or ""
			end
			return ""
		end,
	},
	["Race"] = {
		"Race",
		60,
		function(_entry)
			if _entry.player_data["race_id"] == nil then
				return ""
			end
			local race_info = C_CreatureInfo.GetRaceInfo(_entry.player_data["race_id"])
			if race_info then
				return race_info.raceName or ""
			end
			return ""
		end,
	},
	["Lvl"] = {
		"Lvl",
		40,
		function(_entry)
			return _entry.player_data["level"] or ""
		end,
	},
	["LastWords"] = {
		"LastWords",
		100,
		function(_entry)
			return _entry.player_data["last_words"] or ""
		end,
	},
	["ClassLogo1"] = {
		"ClassLogo1",
		20,
		function(_entry)
      if _entry.player_data["class_id"] == nil then return "" end
			local class_str, _, _ = GetClassInfo(_entry.player_data["class_id"])
			if class_str then
				local msg = "|TInterface\\WorldStateFrame\\ICONS-CLASSES:16:16:0:0:64:64:"
					.. tmap[class_str][1] * 64
					.. ":"
					.. tmap[class_str][2] * 64
					.. ":"
					.. tmap[class_str][3] * 64
					.. ":"
					.. tmap[class_str][4] * 64
					.. "|t"

				return msg
			else
				return ""
			end
		end,
	},
	["ClassLogo2"] = {
		"ClassLogo2",
		20,
		function(_entry)
      if _entry.player_data["class_id"] == nil then return "" end
			local class_str, _, _ = GetClassInfo(_entry.player_data["class_id"])
			if class_str then
				local msg = "|TInterface\\ARENAENEMYFRAME\\UI-CLASSES-CIRCLES:16:16:0:0:64:64:"
					.. tmap[class_str][1] * 64
					.. ":"
					.. tmap[class_str][2] * 64
					.. ":"
					.. tmap[class_str][3] * 64
					.. ":"
					.. tmap[class_str][4] * 64
					.. "|t"

				return msg
			else
				return ""
			end
		end,
	},
	["RaceLogoSquare"] = {
		"RaceLogoSquare",
		20,
		function(_entry)
			if _entry.player_data["race_id"] == nil then
				return ""
			end
			local race_info = C_CreatureInfo.GetRaceInfo(_entry.player_data["race_id"])
			if race_info and race_info.raceName and rmap[race_info.raceName] and _entry.player_data["level"] then
				local msg = "|TInterface\\Glues\\CHARACTERCREATE\\UI-CHARACTERCREATE-RACES.PNG:16:16:0:0:64:64:"
					.. rmap[race_info.raceName][1] * 64
					.. ":"
					.. rmap[race_info.raceName][2] * 64
					.. ":"
					.. rmap[race_info.raceName][3] * 64 + (_entry.player_data["level"] % 2) * 32
					.. ":"
					.. rmap[race_info.raceName][4] * 64 + (_entry.player_data["level"] % 2) * 32
					.. "|t"

				return msg
			else
				return ""
			end
		end,
	},
}

local subtitle_data = {}

local function setSubtitleData()
	subtitle_data = {}
	for _, k in ipairs(deathlog_settings[widget_name]["columns"]) do
		subtitle_data[#subtitle_data + 1] = subtitle_metadata[k]
	end
	death_log_frame:SetSubTitle(subtitle_data)

	local _x_offset = deathlog_settings[widget_name]["entry_x_offset"]
	local _y_offset = deathlog_settings[widget_name]["entry_y_offset"]
	death_log_frame.content:SetPoint("TOPLEFT", 3 + _x_offset, -33 + _y_offset)
	death_log_frame.content:SetPoint("BOTTOMRIGHT", 15, 6)
	death_log_frame:SetSubTitleOffset(_x_offset, _y_offset, subtitle_data)
end

death_log_frame:SetLayout("Fill")
death_log_frame.frame:SetSize(255, 125)
death_log_frame:Show()

local scroll_frame = AceGUI:Create("ScrollFrame")
scroll_frame:SetLayout("List")
death_log_frame:AddChild(scroll_frame)

local selected = nil
local row_entry = {}
local loaded = false
local function setupRowEntries()
	loaded = true
	row_entry = {}
	local function WPDropDownDemo_Menu(frame, level, menuList)
		local info = UIDropDownMenu_CreateInfo()

		if death_tomb_frame.map_id and death_tomb_frame.coordinates then
		end

		local function openWorldMap()
			if not (death_tomb_frame.map_id and death_tomb_frame.coordinates) then
				return
			end
			if C_Map.GetMapInfo(death_tomb_frame["map_id"]) == nil then
				return
			end
			if tonumber(death_tomb_frame.coordinates[1]) == nil or tonumber(death_tomb_frame.coordinates[2]) == nil then
				return
			end

			WorldMapFrame:SetShown(not WorldMapFrame:IsShown())
			WorldMapFrame:SetMapID(death_tomb_frame.map_id)
			WorldMapFrame:GetCanvas()
			local mWidth, mHeight = WorldMapFrame:GetCanvas():GetSize()
			death_tomb_frame_tex:SetPoint(
				"CENTER",
				WorldMapButton,
				"TOPLEFT",
				mWidth * death_tomb_frame.coordinates[1],
				-mHeight * death_tomb_frame.coordinates[2]
			)
			death_tomb_frame_tex:Show()

			death_tomb_frame_tex_glow:SetPoint(
				"CENTER",
				WorldMapButton,
				"TOPLEFT",
				mWidth * death_tomb_frame.coordinates[1],
				-mHeight * death_tomb_frame.coordinates[2]
			)
			death_tomb_frame_tex_glow:Show()
			death_tomb_frame:Show()
		end

		local function blockUser()
			if death_tomb_frame.clicked_name then
				local added = C_FriendList.AddIgnore(death_tomb_frame.clicked_name)
			end
		end

		local function checkSpoof()
			if death_tomb_frame.clicked_name then
				C_FriendList.SendWho(death_tomb_frame.clicked_name)
			end
		end

		if level == 1 then
			info.text, info.hasArrow, info.func, info.disabled = "Show death location", false, openWorldMap, false
			UIDropDownMenu_AddButton(info)
			info.text, info.hasArrow, info.func, info.disabled = "Block user", false, blockUser, false
			UIDropDownMenu_AddButton(info)
			info.text, info.hasArrow, info.func, info.disabled = "Inspect user", false, checkSpoof, false
			UIDropDownMenu_AddButton(info)
		end
	end

	for i = 1, 20 do
		local idx = 21 - i
		row_entry[idx] = AceGUI:Create("InteractiveLabel")
		local _entry = row_entry[idx]
		_entry:SetHighlight("Interface\\Glues\\CharacterSelect\\Glues-CharacterSelect-Highlight")
		_entry.font_strings = {}
		local next_x = 0
		local current_column_offset = 15
		for idx, v in ipairs(subtitle_data) do
			_entry.font_strings[v[1]] = _entry.frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
			_entry.font_strings[v[1]]:SetPoint("LEFT", _entry.frame, "LEFT", current_column_offset, 0)
			_entry.font_strings[v[1]]:SetWordWrap(false)
			current_column_offset = current_column_offset + v[2]
			_entry.font_strings[v[1]]:SetJustifyH("LEFT")

			if idx + 1 <= #subtitle_data then
				_entry.font_strings[v[1]]:SetWidth(v[2])
			end
			_entry.font_strings[v[1]]:SetTextColor(1, 1, 1)
			_entry.font_strings[v[1]]:SetFont(Deathlog_L.mini_log_font, 14, "")
		end

		_entry.background = _entry.frame:CreateTexture(nil, "OVERLAY")
		_entry.background:SetPoint("CENTER", _entry.frame, "CENTER", 0, 0)
		_entry.background:SetDrawLayer("OVERLAY", 2)
		_entry.background:SetVertexColor(0.5, 0.5, 0.5, (i % 2) / 10)
		_entry.background:SetHeight(16)
		_entry.background:SetWidth(1000)
		_entry.background:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")

		_entry:SetHeight(40)
		_entry:SetFont(main_font, 16, "")
		_entry:SetColor(1, 1, 1)
		_entry:SetText(" ")

		function _entry:deselect()
			for _, v in pairs(_entry.font_strings) do
				-- v:SetTextColor(1, 1, 1)
			end
		end

		function _entry:select()
			selected = idx
			for _, v in pairs(_entry.font_strings) do
				-- v:SetTextColor(1, 1, 0)
			end
		end

		_entry:SetCallback("OnLeave", function(widget)
			if _entry.player_data == nil then
				return
			end
			GameTooltip:Hide()
		end)

		_entry:SetCallback("OnClick", function()
			if _entry.player_data == nil then
				return
			end
			local click_type = GetMouseButtonClicked()

			if click_type == "LeftButton" then
				if selected then
					row_entry[selected]:deselect()
				end
				_entry:select()
				if IsShiftKeyDown() then
					C_FriendList.SendWho(_entry["player_data"]["name"])
				end
			elseif click_type == "RightButton" then
				local dropDown = CreateFrame("Frame", "WPDemoContextMenu", UIParent, "UIDropDownMenuTemplate")
				-- Bind an initializer function to the dropdown; see previous sections for initializer function examples.
				UIDropDownMenu_Initialize(dropDown, WPDropDownDemo_Menu, "MENU")
				ToggleDropDownMenu(1, nil, dropDown, "cursor", 3, -3)
				if _entry["player_data"]["map_id"] and _entry["player_data"]["map_pos"] then
					death_tomb_frame.map_id = _entry["player_data"]["map_id"]
					local x, y = strsplit(",", _entry["player_data"]["map_pos"], 2)
					death_tomb_frame.coordinates = { x, y }
					death_tomb_frame.clicked_name = _entry["player_data"]["name"]
				end
			end
		end)

		_entry:SetCallback("OnEnter", function(widget)
			if _entry.player_data == nil then
				return
			end
			GameTooltip_SetDefaultAnchor(GameTooltip, WorldFrame)
			deathlog_setTooltipFromEntry(_entry.player_data)
			GameTooltip:Show()
		end)

		scroll_frame:SetScroll(0)
		scroll_frame.scrollbar:Hide()
		scroll_frame:AddChild(_entry)
	end
end

local function setEntry(player_data, _entry)
	_entry.player_data = player_data
	for _, v in ipairs(subtitle_data) do
		_entry.font_strings[v[1]]:SetText(v[3](_entry))
	end
end

local function shiftEntry(_entry_from, _entry_to)
	setEntry(_entry_from.player_data, _entry_to)
end

function deathlog_widget_minilog_createEntry(player_data)
	if entry_cache[player_data["name"]] then
		return
	end
	entry_cache[player_data["name"]] = 1
	if
		player_data["level"]
		and (
			player_data["level"] < deathlog_settings[widget_name]["min_lvl"]
			or player_data["level"] > deathlog_settings[widget_name]["max_lvl"]
		)
	then
		return
	end
	for i = 1, 19 do
		if row_entry[i + 1].player_data ~= nil then
			shiftEntry(row_entry[i + 1], row_entry[i])
			if selected and selected == i + 1 then
				row_entry[i + 1]:deselect()
				row_entry[i]:select()
			end
		end
	end
	setEntry(player_data, row_entry[20])
end
death_log_icon_frame:RegisterForDrag("LeftButton")
death_log_icon_frame:SetScript("OnDragStart", function(self, button)
	if deathlog_settings[widget_name]["lock"] ~= nil and deathlog_settings[widget_name]["lock"] == true then
		return
	end
	death_log_frame.frame:ClearAllPoints()
	self:StartMoving()
	death_log_frame.frame:SetPoint("TOPLEFT", death_log_icon_frame, "TOPLEFT", 10, -10)
end)
death_log_icon_frame:SetScript("OnDragStop", function(self)
	if deathlog_settings[widget_name]["lock"] ~= nil and deathlog_settings[widget_name]["lock"] == true then
		return
	end
	self:StopMovingOrSizing()
	local x, y = self:GetCenter()
	local px = (GetScreenWidth() * UIParent:GetEffectiveScale()) / 2
	local py = (GetScreenHeight() * UIParent:GetEffectiveScale()) / 2
	deathlog_settings[widget_name]["pos_x"] = x - px
	deathlog_settings[widget_name]["pos_y"] = y - py
	death_log_frame.frame:SetPoint("TOPLEFT", death_log_icon_frame, "TOPLEFT", 10, -10)
end)

hooksecurefunc(death_log_frame.frame, "StopMovingOrSizing", function()
	deathlog_settings[widget_name]["size_x"] = death_log_frame.frame:GetWidth()
	deathlog_settings[widget_name]["size_y"] = death_log_frame.frame:GetHeight()
end)

local function DeathFrameDropdown(frame, level, menuList)
	local info = UIDropDownMenu_CreateInfo()

	local function minimize()
		death_log_frame:Minimize()
	end

	local function maximize()
		death_log_frame:Maximize()
	end

	local function hide()
		death_log_frame.frame:Hide()
		death_log_icon_frame:Hide()
		deathlog_settings[widget_name]["enable"] = false
	end

	local function openSettings()
		Settings.OpenToCategory("Deathlog")
	end

	if level == 1 then
		if death_log_frame:IsMinimized() then
			info.text, info.hasArrow, info.func = "Maximize", false, maximize
			UIDropDownMenu_AddButton(info)
		else
			info.text, info.hasArrow, info.func = "Minimize", false, minimize
			UIDropDownMenu_AddButton(info)
		end

		info.text, info.hasArrow, info.func = "Settings", false, openSettings
		UIDropDownMenu_AddButton(info)

		info.text, info.hasArrow, info.func = "Hide", false, hide
		UIDropDownMenu_AddButton(info)
	end
end

death_log_icon_frame:SetScript("OnMouseDown", function(self, button)
	if button == "RightButton" then
		local dropDown = CreateFrame("Frame", "death_frame_dropdown_menu", UIParent, "UIDropDownMenuTemplate")
		UIDropDownMenu_Initialize(dropDown, DeathFrameDropdown, "MENU")
		ToggleDropDownMenu(1, nil, dropDown, "cursor", 3, -3)
	end
end)

hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
	death_tomb_frame:Hide()
end)
local default_text_color_r, default_text_color_g, default_text_color_b, default_text_color_a =
	GameFontNormal:GetTextColor()

local defaults = {
	["enable"] = true,
	["font"] = "default_font",
	["entry_font"] = "default_font",
	["title_font_size"] = 19,
	["entry_font_size"] = 14,
	["title_x_offset"] = 0,
	["title_y_offset"] = 0,
	["entry_x_offset"] = 0,
	["entry_y_offset"] = 0,
	["border_alpha"] = 1.0,
	["min_lvl"] = 1,
	["max_lvl"] = MAX_PLAYER_LEVEL,
	["pos_x"] = 470,
	["pos_y"] = -100,
	["size_x"] = 255,
	["size_y"] = 125,
	["show_icon"] = true,
	["show_title"] = true,
	["columns"] = { "Name", "Class", "Race", "Lvl" },
	["theme"] = "None",
	["hide_subtitle_heading"] = false,
	["presets"] = "Yazpad",
	["title_color_r"] = default_text_color_r,
	["title_color_g"] = default_text_color_g,
	["title_color_b"] = default_text_color_b,
	["title_color_a"] = default_text_color_a,
	["tooltip_name"] = true,
	["tooltip_guild"] = true,
	["tooltip_race"] = true,
	["tooltip_class"] = true,
	["tooltip_killedby"] = true,
	["tooltip_zone"] = true,
	["tooltip_loc"] = true,
	["tooltip_date"] = true,
	["tooltip_lastwords"] = true,
	["lock"] = false,
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
local function applyFont()
	local success = true
	death_log_frame.titletext:SetFont(
		fonts[deathlog_settings[widget_name]["font"]],
		deathlog_settings[widget_name]["title_font_size"],
		"THICK"
	)

	if fonts[deathlog_settings[widget_name]["font"]] ~= death_log_frame.titletext:GetFont() then
		success = false
	end
	death_log_frame.titletext:SetTextColor(
		deathlog_settings[widget_name]["title_color_r"],
		deathlog_settings[widget_name]["title_color_g"],
		deathlog_settings[widget_name]["title_color_b"],
		deathlog_settings[widget_name]["title_color_a"]
	)
	death_log_frame.titletext:SetPoint(
		"LEFT",
		death_log_frame.frame,
		"TOPLEFT",
		deathlog_settings[widget_name]["title_x_offset"] + 32,
		deathlog_settings[widget_name]["title_y_offset"] - 10
	)

	for i = 1, 20 do
		for idx, v in ipairs(subtitle_data) do
			row_entry[i].font_strings[v[1]]:SetFont(
				fonts[deathlog_settings[widget_name]["entry_font"]],
				deathlog_settings[widget_name]["entry_font_size"],
				""
			)

			if fonts[deathlog_settings[widget_name]["entry_font"]] ~= row_entry[i].font_strings[v[1]]:GetFont() then
				success = false
			end
		end
	end

	if success == true then
		if font_handle then
			font_handle:Cancel()
		end
	end
end
function Deathlog_minilog_applySettings(rebuild_ace)
	applyDefaults(defaults)
	if rebuild_ace then
		setSubtitleData()
		if loaded == false then
			setupRowEntries()
		end
	end
	applyFont()
	font_handle = C_Timer.NewTicker(1, applyFont)

	if deathlog_settings[widget_name]["enable"] == nil or deathlog_settings[widget_name]["enable"] == true then
		death_log_frame.frame:Show()
		death_log_icon_frame:Show()
		if
			deathlog_settings[widget_name]["show_icon"] == nil
			or deathlog_settings[widget_name]["show_icon"] == true
		then
			death_log_icon_frame:Show()
		else
			death_log_icon_frame:Show()
			hc_fire_tex:Hide()
			gold_ring_tex:Hide()
			black_round_tex:Hide()
		end

		if
			deathlog_settings[widget_name]["show_title"] == nil
			or deathlog_settings[widget_name]["show_title"] == true
		then
			death_log_frame.titletext:Show()
		else
			death_log_frame.titletext:Hide()
		end
	else
		death_log_frame.frame:Hide()
		death_log_icon_frame:Hide()
	end

	death_log_icon_frame:ClearAllPoints()
	death_log_frame.frame:ClearAllPoints()
	death_log_icon_frame:SetPoint(
		"CENTER",
		UIParent,
		"CENTER",
		deathlog_settings[widget_name]["pos_x"],
		deathlog_settings[widget_name]["pos_y"]
	)
	death_log_frame.frame:SetBackdropBorderColor(1, 1, 1, deathlog_settings[widget_name]["border_alpha"])

	death_log_frame.frame:SetSize(deathlog_settings[widget_name]["size_x"], deathlog_settings[widget_name]["size_y"])

	death_log_frame.frame:SetPoint("TOPLEFT", death_log_icon_frame, "TOPLEFT", 10, -10)
	death_log_frame.frame:SetFrameStrata("BACKGROUND")
	death_log_frame.frame:Lower()

	if deathlog_settings[widget_name]["hide_subtitle_heading"] then
		for _, v in pairs(death_log_frame.subtitletext_tbl) do
			v:Hide()
		end
	else
		for _, v in pairs(death_log_frame.subtitletext_tbl) do
			v:Show()
		end
	end

	if deathlog_settings[widget_name]["theme"] == "Parchment" then
		local PaneBackdrop = {
			bgFile = "Interface\\ACHIEVEMENTFRAME\\UI-Achievement-Parchment-Horizontal",
			edgeFile = "Interface\\Glues\\COMMON\\TextPanel-Border",
			tile = true,
			tileSize = 170,
			edgeSize = 24,
			insets = { left = 3, right = 3, top = 3, bottom = 3 },
		}

		death_log_frame.frame:SetBackdrop(PaneBackdrop)
		death_log_frame.frame:SetBackdropColor(0.4, 0.4, 0.4, 1)
		death_log_frame.frame:SetBackdropBorderColor(0.5, 0.5, 0.5, deathlog_settings[widget_name]["border_alpha"])
	elseif deathlog_class_tbl[deathlog_settings[widget_name]["theme"]] then
		local PaneBackdrop = {
			bgFile = "Interface\\Artifacts\\ArtifactUI" .. deathlog_settings[widget_name]["theme"],
			edgeFile = "Interface\\Glues\\COMMON\\TextPanel-Border",
			tile = true,
			tileSize = 170,
			edgeSize = 24,
			insets = { left = 3, right = 3, top = 3, bottom = 3 },
		}

		death_log_frame.frame:SetBackdrop(PaneBackdrop)
		death_log_frame.frame:SetBackdropColor(0.4, 0.4, 0.4, 1)
		death_log_frame.frame:SetBackdropBorderColor(0.5, 0.5, 0.5, deathlog_settings[widget_name]["border_alpha"])
	else
		local PaneBackdrop = {
			bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
			edgeFile = "Interface\\Glues\\COMMON\\TextPanel-Border",
			tile = true,
			tileSize = 16,
			edgeSize = 24,
			insets = { left = 3, right = 3, top = 3, bottom = 3 },
		}
		death_log_frame.frame:SetBackdrop(PaneBackdrop)
		death_log_frame.frame:SetBackdropColor(0, 0, 0, 0.6)
		death_log_frame.frame:SetBackdropBorderColor(1, 1, 1, deathlog_settings[widget_name]["border_alpha"])
	end

	if optionsframe == nil then
		LibStub("AceConfig-3.0"):RegisterOptionsTable(widget_name, options)
		optionsframe = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(widget_name, widget_name, "Deathlog")
	end
end

local function forceReset()
	applyDefaults(defaults, true)
	Deathlog_minilog_applySettings(true)
end

local column_options = {}

for k, v in pairs(subtitle_metadata) do
	column_options[k] = k
end
column_options["-----"] = ""

local function columnFunc(idx, key)
	local clear = false
	local maxent = max(#deathlog_settings[widget_name]["columns"], idx)

	for i = idx, maxent do
		if
			deathlog_settings[widget_name]["columns"][i] == key
			or (deathlog_settings[widget_name]["columns"][i] == nil and i ~= idx)
		then
			clear = true
		end
		if i == idx then
			deathlog_settings[widget_name]["columns"][idx] = key
			if key == "-----" then
				deathlog_settings[widget_name]["columns"][idx] = nil
				clear = true
			end
		end
		if clear then
			deathlog_settings[widget_name]["columns"][i] = nil
		end
	end
	Deathlog_minilog_applySettings(true)
end

options = {
	name = widget_name,
	handler = Minilog,
	type = "group",
	args = {
		show_death_log = {
			type = "toggle",
			name = "Show death log",
			desc = "Show death log",
			get = function()
				if
					deathlog_settings[widget_name]["enable"] == nil
					or deathlog_settings[widget_name]["enable"] == true
				then
					return true
				else
					return false
				end
			end,
			set = function()
				if deathlog_settings[widget_name]["enable"] == nil then
					deathlog_settings[widget_name]["enable"] = true
				end
				deathlog_settings[widget_name]["enable"] = not deathlog_settings[widget_name]["enable"]
				Deathlog_minilog_applySettings()
			end,
			order = 1,
		},
		lock_position = {
			type = "toggle",
			name = "Lock position",
			desc = "Lock position of the death log.",
			get = function()
				if deathlog_settings[widget_name]["lock"] == nil or deathlog_settings[widget_name]["lock"] == false then
					return false
				else
					return true
				end
			end,
			set = function()
				if deathlog_settings[widget_name]["lock"] == nil then
					deathlog_settings[widget_name]["lock"] = true
				end
				deathlog_settings[widget_name]["lock"] = not deathlog_settings[widget_name]["lock"]
			end,
			order = 1,
		},
		show_title_text = {
			type = "toggle",
			name = "Show Title Text",
			desc = "Show the 'Deathlog' title text.",
			get = function()
				if
					deathlog_settings[widget_name]["show_title"] == nil
					or deathlog_settings[widget_name]["show_title"] == true
				then
					return true
				else
					return false
				end
			end,
			set = function()
				if deathlog_settings[widget_name]["show_title"] == nil then
					deathlog_settings[widget_name]["show_title"] = true
				end
				deathlog_settings[widget_name]["show_title"] = not deathlog_settings[widget_name]["show_title"]
				Deathlog_minilog_applySettings()
			end,
			order = 2,
		},
		show_skull_icon = {
			type = "toggle",
			name = "Show Skull Icon (Requires reload)",
			desc = "Show the deathlog icon.",
			get = function()
				if
					deathlog_settings[widget_name]["show_icon"] == nil
					or deathlog_settings[widget_name]["show_icon"] == true
				then
					return true
				else
					return false
				end
			end,
			set = function()
				if deathlog_settings[widget_name]["show_icon"] == nil then
					deathlog_settings[widget_name]["show_icon"] = true
				end
				deathlog_settings[widget_name]["show_icon"] = not deathlog_settings[widget_name]["show_icon"]
				Deathlog_minilog_applySettings()
			end,
			order = 2,
		},
		show_icon = {
			type = "toggle",
			name = "Hide Subtitle Heading",
			desc = "Hide subtitle heading.",
			get = function()
				if
					deathlog_settings[widget_name]["hide_subtitle_heading"] == nil
					or deathlog_settings[widget_name]["hide_subtitle_heading"] == true
				then
					return true
				else
					return false
				end
			end,
			set = function()
				if deathlog_settings[widget_name]["hide_subtitle_heading"] == nil then
					deathlog_settings[widget_name]["hide_subtitle_heading"] = true
				end
				deathlog_settings[widget_name]["hide_subtitle_heading"] =
					not deathlog_settings[widget_name]["hide_subtitle_heading"]
				Deathlog_minilog_applySettings()
			end,
			order = 2,
		},
		font = {
			type = "select",
			dialogControl = "LSM30_Font", --Select your widget here
			name = "Title Font",
			desc = "Title Font to use for the mini deathlog.",
			values = fonts, -- pull in your font list from LSM
			get = function()
				return deathlog_settings[widget_name]["font"]
			end,
			set = function(self, key)
				deathlog_settings[widget_name]["font"] = key
				Deathlog_minilog_applySettings()
			end,
		},
		entryfont = {
			type = "select",
			dialogControl = "LSM30_Font", --Select your widget here
			name = "Entry Font",
			desc = "Entry Font to use for the mini deathlog.",
			values = fonts, -- pull in your font list from LSM
			get = function()
				return deathlog_settings[widget_name]["entry_font"]
			end,
			set = function(self, key)
				deathlog_settings[widget_name]["entry_font"] = key
				Deathlog_minilog_applySettings()
			end,
		},
		fontsize = {
			type = "range",
			name = "Title Font Size",
			desc = "Title Font Size",
			min = 7,
			max = 30,
			step = 1,
			get = function()
				return deathlog_settings[widget_name]["title_font_size"]
			end,
			set = function(self, value)
				deathlog_settings[widget_name]["title_font_size"] = value
				Deathlog_minilog_applySettings()
			end,
			disabled = hidenametextoptions,
		},
		borderalpha = {
			type = "range",
			name = "Border Alpha",
			desc = "Change border alpha",
			min = 0,
			max = 1,
			step = 0.05,
			get = function()
				return deathlog_settings[widget_name]["border_alpha"]
			end,
			set = function(self, value)
				deathlog_settings[widget_name]["border_alpha"] = value
				Deathlog_minilog_applySettings()
			end,
			disabled = hidenametextoptions,
		},
		entryfontsize = {
			type = "range",
			name = "Entry Font Size",
			desc = "Entry Font Size",
			min = 7,
			max = 30,
			step = 1,
			get = function()
				return deathlog_settings[widget_name]["entry_font_size"]
			end,
			set = function(self, value)
				deathlog_settings[widget_name]["entry_font_size"] = value
				Deathlog_minilog_applySettings()
			end,
			disabled = hidenametextoptions,
		},
		titlexoffset = {
			type = "range",
			name = "Title x-offset",
			desc = "Title x-offset",
			min = -50,
			max = 250,
			step = 1,
			get = function()
				return deathlog_settings[widget_name]["title_x_offset"]
			end,
			set = function(self, value)
				deathlog_settings[widget_name]["title_x_offset"] = value
				Deathlog_minilog_applySettings()
			end,
			disabled = hidenametextoptions,
		},
		titleyoffset = {
			type = "range",
			name = "Title y-offset",
			desc = "Title y-offset",
			min = -50,
			max = 250,
			step = 1,
			get = function()
				return deathlog_settings[widget_name]["title_y_offset"]
			end,
			set = function(self, value)
				deathlog_settings[widget_name]["title_y_offset"] = value
				Deathlog_minilog_applySettings()
			end,
			disabled = hidenametextoptions,
		},
		entryxoffset = {
			type = "range",
			name = "Entry x-offset (requires reload)",
			desc = "Entry x-offset",
			min = -50,
			max = 250,
			step = 1,
			get = function()
				return deathlog_settings[widget_name]["entry_x_offset"]
			end,
			set = function(self, value)
				deathlog_settings[widget_name]["entry_x_offset"] = value

				if ace_refresh_timer_handle then
					ace_refresh_timer_handle:Cancel()
				end
				ace_refresh_timer_handle = C_Timer.NewTimer(0.05, function()
					Deathlog_minilog_applySettings(true)
					ace_refresh_timer_handle:Cancel()
				end)
			end,
			disabled = hidenametextoptions,
		},
		entryyoffset = {
			type = "range",
			name = "Entry y-offset",
			desc = "Entry y-offset",
			min = -50,
			max = 250,
			step = 1,
			get = function()
				return deathlog_settings[widget_name]["entry_y_offset"]
			end,
			set = function(self, value)
				deathlog_settings[widget_name]["entry_y_offset"] = value
				if ace_refresh_timer_handle then
					ace_refresh_timer_handle:Cancel()
				end
				ace_refresh_timer_handle = C_Timer.NewTimer(0.05, function()
					Deathlog_minilog_applySettings(true)
					ace_refresh_timer_handle:Cancel()
				end)
			end,
			disabled = hidenametextoptions,
		},
		reset_size_and_pos = {
			type = "execute",
			name = "Reset to default",
			desc = "Reset to default",
			func = function()
				forceReset()
			end,
		},

		theme = {
			type = "select",
			dialogControl = "LSM30_Font", --Select your widget here
			name = "Theme",
			desc = "Texture theme",
			values = themes, -- pull in your font list from LSM
			get = function()
				return deathlog_settings[widget_name]["theme"]
			end,
			set = function(self, key)
				deathlog_settings[widget_name]["theme"] = key
				Deathlog_minilog_applySettings()
			end,
		},

		preset_ = {
			type = "select",
			dialogControl = "LSM30_Font", --Select your widget here
			name = "Preset Settings",
			desc = "Preset Settings",
			order = 3,
			values = presets, -- pull in your font list from LSM
			get = function()
				return deathlog_settings[widget_name]["presets"]
			end,
			set = function(self, key)
				deathlog_settings[widget_name]["presets"] = key
				if deathlog_settings[widget_name]["presets"] == "concise" then
					deathlog_settings[widget_name]["enable"] = true
					deathlog_settings[widget_name]["font"] = "BreatheFire"
					deathlog_settings[widget_name]["entry_font"] = "default_font"
					deathlog_settings[widget_name]["title_font_size"] = 19
					deathlog_settings[widget_name]["entry_font_size"] = 16
					deathlog_settings[widget_name]["title_x_offset"] = 13
					deathlog_settings[widget_name]["title_y_offset"] = -9
					deathlog_settings[widget_name]["border_alpha"] = 1.0
					deathlog_settings[widget_name]["size_x"] = 181.8763122558594
					deathlog_settings[widget_name]["size_y"] = 102.3703765869141
					deathlog_settings[widget_name]["show_icon"] = false
					deathlog_settings[widget_name]["show_title"] = true
					deathlog_settings[widget_name]["entry_x_offset"] = 0
					deathlog_settings[widget_name]["entry_y_offset"] = 0
					deathlog_settings[widget_name]["columns"] = {
						"Lvl", -- [1]
						"Name", -- [2]
						"RaceLogoSquare", -- [3]
						"ClassLogo1", -- [4]
					}
					deathlog_settings[widget_name]["theme"] = "Parchment"
					deathlog_settings[widget_name]["hide_subtitle_heading"] = true
					deathlog_settings[widget_name]["presets"] = "concise"
				end
				if deathlog_settings[widget_name]["presets"] == "Yazpad" then
					deathlog_settings[widget_name]["enable"] = true
					deathlog_settings[widget_name]["font"] = "BreatheFire"
					deathlog_settings[widget_name]["entry_font"] = "default_font"
					deathlog_settings[widget_name]["title_font_size"] = 19
					deathlog_settings[widget_name]["entry_font_size"] = 16
					deathlog_settings[widget_name]["title_x_offset"] = 13
					deathlog_settings[widget_name]["title_y_offset"] = -9
					deathlog_settings[widget_name]["border_alpha"] = 1.0
					deathlog_settings[widget_name]["size_x"] = 161.8763122558594
					deathlog_settings[widget_name]["size_y"] = 102.3703765869141
					deathlog_settings[widget_name]["show_icon"] = false
					deathlog_settings[widget_name]["show_title"] = true
					deathlog_settings[widget_name]["entry_x_offset"] = 0
					deathlog_settings[widget_name]["entry_y_offset"] = 0
					deathlog_settings[widget_name]["columns"] = {
						"Lvl", -- [1]
						"Name", -- [2]
						"RaceLogoSquare", -- [3]
						"ClassLogo1", -- [4]
					}
					deathlog_settings[widget_name]["theme"] = "Warrior"
					deathlog_settings[widget_name]["hide_subtitle_heading"] = true
					deathlog_settings[widget_name]["presets"] = "Yazpad"

					deathlog_settings[widget_name]["title_color_r"] = 1
					deathlog_settings[widget_name]["title_color_g"] = 1
					deathlog_settings[widget_name]["title_color_b"] = 1
					deathlog_settings[widget_name]["title_color_a"] = 1
				end
				if deathlog_settings[widget_name]["presets"] == "ChefCarlos" then
					deathlog_settings[widget_name]["enable"] = true
					deathlog_settings[widget_name]["font"] = "2002 Bold"
					deathlog_settings[widget_name]["entry_font"] = "2002 Bold"
					deathlog_settings[widget_name]["title_font_size"] = 14
					deathlog_settings[widget_name]["entry_font_size"] = 11
					deathlog_settings[widget_name]["title_x_offset"] = -20
					deathlog_settings[widget_name]["title_y_offset"] = 0
					deathlog_settings[widget_name]["border_alpha"] = 1.0
					deathlog_settings[widget_name]["size_x"] = 500
					deathlog_settings[widget_name]["size_y"] = 150
					deathlog_settings[widget_name]["show_icon"] = false
					deathlog_settings[widget_name]["show_title"] = true
					deathlog_settings[widget_name]["entry_x_offset"] = 0
					deathlog_settings[widget_name]["entry_y_offset"] = 0
					deathlog_settings[widget_name]["columns"] = {
						"Name", -- [1]
						"ClassLogo1", -- [2]
						"Lvl", -- [3]
						"Source", -- [4]
						"LastWords", -- [5]
					}
					deathlog_settings[widget_name]["theme"] = "None"
					deathlog_settings[widget_name]["hide_subtitle_heading"] = false
					deathlog_settings[widget_name]["presets"] = "ChefCarlos"
					deathlog_settings[widget_name]["title_color_r"] = 1
					deathlog_settings[widget_name]["title_color_g"] = 1
					deathlog_settings[widget_name]["title_color_b"] = 1
					deathlog_settings[widget_name]["title_color_a"] = 1
				end
				Deathlog_minilog_applySettings()
			end,
		},
		add_fake = {
			type = "execute",
			name = "Add fake entry",
			desc = "Add fake entry",
			func = function()
				local idx = math.random(1, 100)
				local some_name = UnitName("player")
				local some_guild = ""
				local found_random_name = false
				if deathlog_data then
					for servername, v in pairs(deathlog_data) do
						for checksum, entry in pairs(v) do
							some_name = entry["name"]
							some_guild = entry["guild"]
							idx = idx - 1
							if idx < 1 then
								found_random_name = true
								break
							end
						end
						if found_random_name then
							break
						end
					end
				end
				idx = math.random(1, 100)
				local some_source_id = -2
				for k, v in pairs(id_to_npc) do
					idx = idx - 1
					some_source_id = k
					if idx < 1 then
						break
					end
				end

				idx = math.random(1, 2)
				local map_id = nil
				local instance_id = nil
				if idx == 1 then
					idx = math.random(1, 10)
					for k, v in pairs(deathlog_id_to_instance_tbl) do
						idx = idx - 1
						instance_id = k
						if idx < 1 then
							break
						end
					end
				else
					idx = math.random(1, 10)
					for k, v in pairs(deathlog_zone_tbl) do
						idx = idx - 1
						map_id = v
						if idx < 1 then
							break
						end
					end
				end

				fake_player_data = {
					["name"] = some_name,
					["level"] = math.random(1, 60),
					["class_id"] = math.random(1, 12),
					["race_id"] = math.random(1, 8),
					["source_id"] = some_source_id,
					["map_id"] = map_id,
					["instance_id"] = instance_id,
					["guild"] = some_guild,
				}

				-- pvp tests
				local pvp_r = math.random(0, 3)
				if pvp_r == 1 then
					fake_player_data["source_id"] = deathlog_encode_pvp_source("target")
				elseif pvp_r == 2 then
					fake_player_data["source_id"] = deathlog_encode_pvp_source(deathlog_last_attack_player)
				elseif pvp_r == 3 and UnitIsPlayer("target") then
					deathlog_refresh_last_attack_info(UnitName("target"))
					deathlog_last_duel_to_death_player = deathlog_last_attack_player
					fake_player_data["source_id"] = deathlog_encode_pvp_source(deathlog_last_attack_player)
					deathlog_last_duel_to_death_player = nil
					deathlog_clear_last_attack_info()
				end

				deathlog_widget_minilog_createEntry(fake_player_data)
			end,
		},

		titlecolor = {
			type = "color",
			name = "Title Text Color",
			desc = "Title Text Color",
			get = function()
				return deathlog_settings[widget_name]["title_color_r"],
					deathlog_settings[widget_name]["title_color_g"],
					deathlog_settings[widget_name]["title_color_b"],
					deathlog_settings[widget_name]["title_color_a"]
			end,
			set = function(self, r, g, b, a)
				deathlog_settings[widget_name]["title_color_r"] = r
				deathlog_settings[widget_name]["title_color_g"] = g
				deathlog_settings[widget_name]["title_color_b"] = b
				deathlog_settings[widget_name]["title_color_a"] = a

				Deathlog_minilog_applySettings()
			end,
		},

		alert_options_header = {
			type = "group",
			name = "Column Configuration (May require reload)",
			order = 10,
			inline = true,
			args = {
				column1 = {
					type = "select",
					dialogControl = "LSM30_Font", --Select your widget here
					name = "Column1",
					desc = "Which value should go into the first column",
					values = column_options, -- pull in your font list from LSM
					get = function()
						return deathlog_settings[widget_name]["columns"][1] or "-----"
					end,
					set = function(self, key)
						columnFunc(1, key)
					end,
				},
				column2 = {
					type = "select",
					dialogControl = "LSM30_Font", --Select your widget here
					name = "Column2",
					desc = "Which value should go into the second column",
					values = column_options, -- pull in your font list from LSM
					get = function()
						return deathlog_settings[widget_name]["columns"][2] or "-----"
					end,
					set = function(self, key)
						columnFunc(2, key)
					end,
				},
				column3 = {
					type = "select",
					dialogControl = "LSM30_Font", --Select your widget here
					name = "Column3",
					desc = "Which value should go into the second column",
					values = column_options, -- pull in your font list from LSM
					get = function()
						return deathlog_settings[widget_name]["columns"][3] or "-----"
					end,
					set = function(self, key)
						columnFunc(3, key)
					end,
				},
				column4 = {
					type = "select",
					dialogControl = "LSM30_Font", --Select your widget here
					name = "Column4",
					desc = "Which value should go into the second column",
					values = column_options, -- pull in your font list from LSM
					get = function()
						return deathlog_settings[widget_name]["columns"][4] or "-----"
					end,
					set = function(self, key)
						columnFunc(4, key)
					end,
				},
				column5 = {
					type = "select",
					dialogControl = "LSM30_Font", --Select your widget here
					name = "Column5",
					desc = "Which value should go into the second column",
					values = column_options, -- pull in your font list from LSM
					get = function()
						return deathlog_settings[widget_name]["columns"][5] or "-----"
					end,
					set = function(self, key)
						columnFunc(5, key)
					end,
				},
				column6 = {
					type = "select",
					dialogControl = "LSM30_Font", --Select your widget here
					name = "Column6",
					desc = "Which value should go into the second column",
					values = column_options, -- pull in your font list from LSM
					get = function()
						return deathlog_settings[widget_name]["columns"][6] or "-----"
					end,
					set = function(self, key)
						columnFunc(6, key)
					end,
				},
			},
		},
		minilog_lvl_filter = {
			type = "group",
			name = "Filter Options",
			order = 11,
			inline = true,
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
						Deathlog_minilog_applySettings()
					end,
				},
			},
		},

		minilog_tooltip = {
			type = "group",
			name = "Tooltip Options",
			order = 11,
			inline = true,
			args = {
				name = {
					type = "toggle",
					name = "Name",
					desc = "Show the 'Name' row in the minilog tooltip",
					order = 1,
					get = function()
						if
							deathlog_settings[widget_name]["tooltip_name"] == nil
							or deathlog_settings[widget_name]["tooltip_name"] == true
						then
							return true
						else
							return false
						end
					end,
					set = function()
						if deathlog_settings[widget_name]["tooltip_name"] == nil then
							deathlog_settings[widget_name]["tooltip_name"] = true
						end
						deathlog_settings[widget_name]["tooltip_name"] =
							not deathlog_settings[widget_name]["tooltip_name"]
					end,
				},
				guild = {
					type = "toggle",
					name = "Guild",
					desc = "Show the 'Guild' row in the minilog tooltip",
					order = 2,
					get = function()
						if
							deathlog_settings[widget_name]["tooltip_guild"] == nil
							or deathlog_settings[widget_name]["tooltip_guild"] == true
						then
							return true
						else
							return false
						end
					end,
					set = function()
						if deathlog_settings[widget_name]["tooltip_guild"] == nil then
							deathlog_settings[widget_name]["tooltip_guild"] = true
						end
						deathlog_settings[widget_name]["tooltip_guild"] =
							not deathlog_settings[widget_name]["tooltip_guild"]
					end,
				},
				race = {
					type = "toggle",
					name = "Race",
					desc = "Show the 'Race' row in the minilog tooltip",
					order = 3,
					get = function()
						if
							deathlog_settings[widget_name]["tooltip_race"] == nil
							or deathlog_settings[widget_name]["tooltip_race"] == true
						then
							return true
						else
							return false
						end
					end,
					set = function()
						if deathlog_settings[widget_name]["tooltip_race"] == nil then
							deathlog_settings[widget_name]["tooltip_race"] = true
						end
						deathlog_settings[widget_name]["tooltip_race"] =
							not deathlog_settings[widget_name]["tooltip_race"]
					end,
				},
				class = {
					type = "toggle",
					name = "Class",
					desc = "Show the 'Class' row in the minilog tooltip",
					order = 4,
					get = function()
						if
							deathlog_settings[widget_name]["tooltip_class"] == nil
							or deathlog_settings[widget_name]["tooltip_class"] == true
						then
							return true
						else
							return false
						end
					end,
					set = function()
						if deathlog_settings[widget_name]["tooltip_class"] == nil then
							deathlog_settings[widget_name]["tooltip_class"] = true
						end
						deathlog_settings[widget_name]["tooltip_class"] =
							not deathlog_settings[widget_name]["tooltip_class"]
					end,
				},
				killed_by = {
					type = "toggle",
					name = "Killed By",
					desc = "Show the 'Killed by' row in the minilog tooltip",
					order = 5,
					get = function()
						if
							deathlog_settings[widget_name]["tooltip_killedby"] == nil
							or deathlog_settings[widget_name]["tooltip_killedby"] == true
						then
							return true
						else
							return false
						end
					end,
					set = function()
						if deathlog_settings[widget_name]["tooltip_killedby"] == nil then
							deathlog_settings[widget_name]["tooltip_killedby"] = true
						end
						deathlog_settings[widget_name]["tooltip_killedby"] =
							not deathlog_settings[widget_name]["tooltip_killedby"]
					end,
				},
				zone = {
					type = "toggle",
					name = "Zone",
					desc = "Show the 'Zone' row in the minilog tooltip",
					order = 6,
					get = function()
						if
							deathlog_settings[widget_name]["tooltip_zone"] == nil
							or deathlog_settings[widget_name]["tooltip_zone"] == true
						then
							return true
						else
							return false
						end
					end,
					set = function()
						if deathlog_settings[widget_name]["tooltip_zone"] == nil then
							deathlog_settings[widget_name]["tooltip_zone"] = true
						end
						deathlog_settings[widget_name]["tooltip_zone"] =
							not deathlog_settings[widget_name]["tooltip_zone"]
					end,
				},
				location = {
					type = "toggle",
					name = "Location",
					desc = "Show the 'Loc' row in the minilog tooltip",
					order = 7,
					get = function()
						if
							deathlog_settings[widget_name]["tooltip_loc"] == nil
							or deathlog_settings[widget_name]["tooltip_loc"] == true
						then
							return true
						else
							return false
						end
					end,
					set = function()
						if deathlog_settings[widget_name]["tooltip_loc"] == nil then
							deathlog_settings[widget_name]["tooltip_loc"] = true
						end
						deathlog_settings[widget_name]["tooltip_loc"] =
							not deathlog_settings[widget_name]["tooltip_loc"]
					end,
				},
				timestamp = {
					type = "toggle",
					name = "Date",
					desc = "Show the 'Date' row in the minilog tooltip",
					order = 8,
					get = function()
						if
							deathlog_settings[widget_name]["tooltip_date"] == nil
							or deathlog_settings[widget_name]["tooltip_date"] == true
						then
							return true
						else
							return false
						end
					end,
					set = function()
						if deathlog_settings[widget_name]["tooltip_date"] == nil then
							deathlog_settings[widget_name]["tooltip_date"] = true
						end
						deathlog_settings[widget_name]["tooltip_date"] =
							not deathlog_settings[widget_name]["tooltip_date"]
					end,
				},
				last_words = {
					type = "toggle",
					name = "Last Words",
					desc = "Show the 'Last words' row in the minilog tooltip",
					order = 8,
					get = function()
						if
							deathlog_settings[widget_name]["tooltip_lastwords"] == nil
							or deathlog_settings[widget_name]["tooltip_lastwords"] == true
						then
							return true
						else
							return false
						end
					end,
					set = function()
						if deathlog_settings[widget_name]["tooltip_lastwords"] == nil then
							deathlog_settings[widget_name]["tooltip_lastwords"] = true
						end
						deathlog_settings[widget_name]["tooltip_lastwords"] =
							not deathlog_settings[widget_name]["tooltip_lastwords"]
					end,
				},
			},
		},
	},
}
