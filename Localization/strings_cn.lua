deathlog_strings_cn = {
	-- fonts
	main_font = "Fonts\\FRIZQT__.TTF",
	class_font = "Fonts\\blei00d.TTF",
	death_alert_font = "Fonts\\blei00d.TTF",
	mini_log_font = "Fonts\\blei00d.TTF",
	menu_font = "Fonts\\blei00d.TTF",
	deadliest_creature_container_font = "Fonts\\blei00d.TTF",
	creature_model_quote_font = "Fonts\\MORPHEUS.TTF",
	-- death alerts messages
	death_alert_default_message = "<name> the <race> <class> has been slain\nby <source> at lvl <level> in <zone>.",
	death_alert_default_fall_message = "<name> the <race> <class> fell to\ndeath at lvl <level> in <zone>.",
	death_alert_default_drown_message = "<name> the <race> <class> drowned\n at lvl <level> in <zone>.",
	death_alert_default_slime_message = "<name> the <race> <class> has died from slime.\n at lvl <level> in <zone>.",
	death_alert_default_lava_message = "<name> the <race> <class> drowned in lava.\n at lvl <level> in <zone>.",
	death_alert_default_fire_message = "<name> the <race> <class> has died from fire.\n at lvl <level> in <zone>.",
	death_alert_default_fatigue_message = "<name> the <race> <class> has died from fatigue.\n at lvl <level> in <zone>.",
	-- words
	corpse_word = "尸体",
	of_word = "的",
	minimap_btn_left_click = "|cFF666666Left Click:|r View log",
	minimap_btn_right_click = "|cFF666666Right Click:|r ",
	class_word = "Class",
	killed_by_word = "Killed by",
	zone_instance_word = "Zone/Instance",
	date_word = "Date",
	last_words_word = "Last words",
	death_word = "Death",
	guild_word = "Guild",
	race_word = "Race",
	name_word = "Name",
	show_heatmap = "Show heatmap",
	-- tables
	tab_table = {
		{ value = "ClassStatisticsTab", text = "Class Statistics" },
		{ value = "CreatureStatisticsTab", text = "Creature Statistics" },
		{ value = "InstanceStatisticsTab", text = "Instance Statistics" },
		{ value = "StatisticsTab", text = "Zone Statistics" },
		{ value = "LogTab", text = "Search" },
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