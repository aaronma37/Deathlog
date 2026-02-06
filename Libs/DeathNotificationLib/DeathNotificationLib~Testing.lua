-- Debug: Simulate Own Death. Usage: /dump Deathlog_TestSelfDeathWithTarnishedSoul()
function Deathlog_TestSelfDeathWithTarnishedSoul()
	Deathlog_TestSelfDeath()
	Deathlog_TestTarnishedSoul()
end

-- Debug: Simulate Own Death. Usage: /dump Deathlog_TestSelfDeath()
function Deathlog_TestSelfDeath()
	print("|cffFF6600[Deathlog]|r Simulating self death.")
	last_attack_source = -9999 -- Test NPC ID
	recent_msg = "This is my last words."
    local soul_of_iron_was_active = nil
	if deathlog_char_data then
		soul_of_iron_was_active = deathlog_char_data.hasSoulOfIron
		deathlog_char_data.hasSoulOfIron = true
	end
	handleEvent(death_notification_lib_event_handler, "PLAYER_DEAD")
	if deathlog_char_data then
		deathlog_char_data.hasSoulOfIron = soul_of_iron_was_active
	end
end

-- Debug: Simulate Soul of Iron death for current target. Usage: /dump Deathlog_TestTarnishedSoul()
function Deathlog_TestTarnishedSoul()
	if not UnitExists("target") then
		print("|cffFF6600[Deathlog]|r No target. Target a player first.")
		return
	end
	local name = UnitName("target")
	local guid = UnitGUID("target")
	if not guid or not guid:match("^Player") then
		print("|cffFF6600[Deathlog]|r Target is not a player.")
		return
	end
	print("|cffFF6600[Deathlog]|r Simulating Soul of Iron death for:", name, "GUID:", guid)

	-- Clear cache for this player so test can run again
	bliz_alert_cache[name] = nil

	-- Capture values for closure
	local test_msg = "Death tarnishes " .. name .. "'s soul."
	local test_name = name
	local test_guid = guid

	-- Invoke delayed so we can deselect target before processing
	C_Timer.After(1, function()
		print("Processing emote...")
		-- Set global arg right before calling handler
		local my_args = {
			[1] = test_msg,
			[2] = test_name,
			[3] = "",
			[4] = "",
			[5] = test_name,
			[6] = "",
			[7] = "",
			[8] = "",
			[9] = "",
			[10] = "",
			[11] = "",
			[12] = test_guid,
		}
		handleEvent(death_notification_lib_event_handler, "CHAT_MSG_MONSTER_EMOTE", unpack(my_args))
	end)
end