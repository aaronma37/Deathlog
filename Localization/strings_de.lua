deathlog_strings_de = {
	-- fonts
	main_font = "Fonts\\FRIZQT__.TTF",
	class_font = "Fonts\\blei00d.TTF",
	death_alert_font = "Fonts\\blei00d.TTF",
	mini_log_font = "Fonts\\blei00d.TTF",
	menu_font = "Fonts\\blei00d.TTF",
	deadliest_creature_container_font = "Fonts\\blei00d.TTF",
	creature_model_quote_font = "Fonts\\MORPHEUS.TTF",
	-- death alerts messages
	death_alert_default_message = "<name> der <race> <class> wurde\nvon <source> auf Stufe <level> in <zone> getötet.",
	death_alert_default_fall_message = "<name> der <race> <class> ist\nauf Stufe <level> in <zone> zu Tode gestürzt.",
	death_alert_default_drown_message = "<name> der <race> <class> ist\nauf Stufe <level> in <zone> ertrunken.",
	death_alert_default_slime_message = "<name> der <race> <class> ist durch Schleim gestorben.\nauf Stufe <level> in <zone>.",
	death_alert_default_lava_message = "<name> der <race> <class> ist in Lava ertrunken.\nauf Stufe <level> in <zone>.",
	death_alert_default_fire_message = "<name> der <race> <class> ist durch Feuer gestorben.\nauf Stufe <level> in <zone>.",
	death_alert_default_fatigue_message = "<name> der <race> <class> ist an Erschöpfung gestorben.\nauf Stufe <level> in <zone>.",
	-- words
	corpse_word = "Leichnam",
	of_word = "von",
	minimap_btn_left_click = "|cFF666666Left Click:|r View log",
	minimap_btn_right_click = "|cFF666666Right Click:|r ",
	class_word = "Klasse",
	killed_by_word = "Getötet von",
	zone_instance_word = "Zone/Instanz",
	date_word = "Datum",
	last_words_word = "Letzte Worte",
	death_word = "Tod",
	guild_word = "Gilde",
	race_word = "Rasse",
	name_word = "Name",
	show_heatmap = "Show heatmap",
	-- tables
	tab_table = {
		{ value = "ClassStatisticsTab", text = "Klassenstatistik" },
		{ value = "CreatureStatisticsTab", text = "Kreaturenstatistik" },
		{ value = "InstanceStatisticsTab", text = "Instanzenstatistik" },
		{ value = "StatisticsTab", text = "Zonenstatistik" },
		{ value = "LogTab", text = "Suche" },
		{ value = "WatchListTab", text = "Beobachtungsliste" },
	},
	-- Expansion names for UI display
	expansion_names = {
		[0] = "Classic",
		[1] = "The Burning Crusade",
	},
	--- Blizzard hardcore death broadcast parsing function (nil if not supported in this language yet)
	-- @param msg string The death broadcast message to parse
	-- @return string|nil name The player name
	-- @return number|nil source_id The creature/source ID or special ID for environmental deaths
	-- @return string|nil area The area name where death occurred
	-- @return number|nil level The player level
	-- @return string|nil pvp_source_name The PvP player name (if applicable)
	parse_hc_death_broadcast = function(msg)
		-- Regex: \|Hplayer:(.*)\|h\[(.*)]\|h wurde von einer Kreatur \((.*)\) in (.*) getötet! Die Stufe war (\d*)\.
		local _, name, source, area, level = msg:match("|Hplayer:(.-)|h%[(.-)%]|h wurde von einer Kreatur %((.-)%) in (.-) getötet! Die Stufe war (%d+)%.")
		if name and source and area and level then
			return name, npc_to_id[source], area, tonumber(level), nil
		end

		-- Regex: \|Hplayer:(.*)\|h\[(.*)]\|h wurde von (.*) in (.*) getötet! Die Stufe war (\d*)\.
		_, name, source, area, level = msg:match("|Hplayer:(.-)|h%[(.-)%]|h wurde von (.-) in (.-) getötet! Die Stufe war (%d+)%.")
		if name and source and area and level then
			return name, deathlog_create_pvp_source_id(deathlog_pvp_flag.REGULAR) , area, tonumber(level), source
		end

		-- Regex: \|Hplayer:(.*)\|h\[(.*)]\|h ist in (.*) ertrunken! Die Stufe war (\d*)\.
		_, name, area, level = msg:match("|Hplayer:(.-)|h%[(.-)%]|h ist in (.+) ertrunken! Die Stufe war (%d+)%.")
		if name and area and level then
			return name, -2, area, tonumber(level), nil
		end

		-- Regex: \|Hplayer:(.*)\|h\[(.*)]\|h ist in (.*) in den Tod gestürzt! Die Stufe war (\d*)\.
		_, name, area, level = msg:match("|Hplayer:(.-)|h%[(.-)%]|h ist in (.+) in den Tod gestürzt! Die Stufe war (%d+)%.")
		if name and area and level then
			return name, -3, area, tonumber(level), nil
		end

		-- Regex: \|Hplayer:(.*)\|h\[(.*)]\|h ist in (.*) an Erschöpfung gestorben! Die Stufe war (\d*)\.
		_, name, area, level = msg:match("|Hplayer:(.-)|h%[(.-)%]|h ist in (.+) an Erschöpfung gestorben! Die Stufe war (%d+)%.")
		if name and area and level then
			return name, -4, area, tonumber(level), nil
		end

		return nil, nil, nil, nil, nil
	end,
	--- Soul of Iron tarnished soul emote parsing function (nil if not supported in this language yet)
	-- @param msg string The emote message to check
	-- @return boolean true if message matches tarnished soul pattern, false otherwise
	parse_tarnished_soul_emote = function(msg)
		return msg == "Der Tod wirft einen Schatten auf die Seele von %s"
	end,
}