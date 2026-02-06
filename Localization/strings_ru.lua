deathlog_strings_ru = {
	-- fonts
	main_font = "Fonts\\NIM_____.ttf",
	class_font = "Fonts\\NIM_____.ttf",
	death_alert_font = "Fonts\\NIM_____.ttf",
	mini_log_font = "Fonts\\MORPHEUS_CYR.TTF",
	menu_font = "Fonts\\NIM_____.ttf",
	deadliest_creature_container_font = "Fonts\\FRIZQT___CYR.TTF",
	creature_model_quote_font = "Fonts\\MORPHEUS_CYR.TTF",
	-- death alerts messages
	death_alert_default_message = "<name> <race> <class> был убит\n<source> на уровне <level> в <zone>.",
	death_alert_default_fall_message = "<name> <race> <class> разбился\nнасмерть на уровне <level> в <zone>.",
	death_alert_default_drown_message = "<name> <race> <class> утонул\n на уровне <level> в <zone>.",
	death_alert_default_slime_message = "<name> <race> <class> умер от слизи.\n на уровне <level> в <zone>.",
	death_alert_default_lava_message = "<name> <race> <class> утонул в лаве.\n на уровне <level> в <zone>.",
	death_alert_default_fire_message = "<name> <race> <class> умер от огня.\n на уровне <level> в <zone>.",
	death_alert_default_fatigue_message = "<name> <race> <class> умер от усталости.\n на уровне <level> в <zone>.",
	-- words
	corpse_word = "Труп",
	of_word = "из",
	minimap_btn_left_click = "|cFF666666ЛКМ:|r Посмотреть журнал",
 	minimap_btn_right_click = "|cFF666666ПКМ:|r ",
	class_word = "Класс",
	killed_by_word = "Убит",
	zone_instance_word = "Зона/Подземелье",
	date_word = "Дата",
	last_words_word = "Последние слова",
	death_word = "Смерть",
	guild_word = "Гильдия",
	race_word = "Раса",
	name_word = "Имя",
	show_heatmap = "Heatmap",
	-- tables
	tab_table = {
		{ value = "ClassStatisticsTab", text = "Статистика классов" },
		{ value = "CreatureStatisticsTab", text = "Статистика существ" },
		{ value = "InstanceStatisticsTab", text = "Статистика подземелий" },
		{ value = "StatisticsTab", text = "Статистика зон" },
		{ value = "LogTab", text = "Поиск" },
		{ value = "WatchListTab", text = "Watch List" },
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
	parse_hc_death_broadcast = nil,
	--- Soul of Iron tarnished soul emote parsing function (nil if not supported in this language yet)
	-- @param msg string The emote message to check
	-- @return boolean true if message matches tarnished soul pattern, false otherwise
	parse_tarnished_soul_emote = nil,
}