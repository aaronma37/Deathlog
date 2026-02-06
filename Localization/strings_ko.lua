deathlog_strings_ko = {
	-- fonts
	main_font = "Fonts\\2002.ttf",
	class_font = "Fonts\\2002.ttf",
	death_alert_font = "Fonts\\2002.ttf",
	mini_log_font = "Fonts\\2002.ttf",
	menu_font = "Fonts\\2002.ttf",
	deadliest_creature_container_font = "Fonts\\2002.ttf",
	creature_model_quote_font = "Fonts\\MORPHEUS.TTF",
	-- death alerts messages
	death_alert_default_message = "<level>레벨 <race> <class> <name> 가\n<zone> 에서 <source> 에게 죽었습니다.",
	death_alert_default_fall_message = "<level>레벨 <race> <class> <name> 가\n <zone> 에서 낙사로 죽었습니다.",
	death_alert_default_drown_message = "<level>레벨 <race> <class> <name> 가\n <zone> 에서 익사로 죽었습니다.",
	death_alert_default_slime_message = "<level>레벨 <race> <class> <name> 가\n <zone> 에서 산성에 죽었습니다.",
	death_alert_default_lava_message = "<level>레벨 <race> <class> <name> 가\n <zone> 에서 용암에 빠져 죽었습니다.",
	death_alert_default_fire_message = "<level>레벨 <race> <class> <name> 가\n <zone> 에서 불에 타 죽었습니다.",
	death_alert_default_fatigue_message = "<level>레벨 <race> <class> <name> 가\n <zone> 에서 피로사 하였습니다.",
	-- words
	corpse_word = "시체",
	of_word = "~의",
	minimap_btn_left_click = "|cFF666666좌클릭:|r 로그 열기",
	minimap_btn_right_click = "|cFF666666우클릭:|r ",
	class_word = "Class",
	killed_by_word = "Killed by",
	zone_instance_word = "Zone/Instance",
	date_word = "Date",
	last_words_word = "Last words",
	death_word = "Death",
	guild_word = "Guild",
	race_word = "Race",
	name_word = "Name",
	show_heatmap = "사망자 발생 구간 보기",
	-- tables
	tab_table = {
		{ value = "ClassStatisticsTab", text = "직업 통계" },
		{ value = "CreatureStatisticsTab", text = "사망 통계" },
		{ value = "InstanceStatisticsTab", text = "던전 통계" },
		{ value = "StatisticsTab", text = "지역 통계" },
		{ value = "LogTab", text = "로그" },
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