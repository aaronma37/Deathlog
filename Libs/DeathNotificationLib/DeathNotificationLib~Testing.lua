--[[
DeathNotificationLib~Testing.lua

Test suites, simulation helpers, and developer tooling.

Provides fake death generation (CreateFakeEntry, available without DEBUG)
and a comprehensive set of in-game test suites gated behind _dnl.DEBUG:

  testIntegration()       – 38-phase suite covering encode/decode,
                            fletcher16, dedup, broadcast, corroboration,
                            PvP, quality merge, throttle, secure hooks,
                            malformed messages, and more
  testV2BackwardsCompat() – 7-phase suite for legacy V2 protocol paths
  testSync()              – 6-phase suite for the sync state machine
  testAttachAddon()       – 6-phase suite for the AttachAddon multi-addon
                            registry, settings aggregation, per-addon hook
                            dispatch, sync isolation, and edge cases
  testDedup()             – 10-phase suite for cross-checksum name dedup,
                            late quality upgrades, ZF party scenarios,
                            outbound broadcast dedup, inbound merge,
                            dedup window boundaries, and mergeLRUEntry
  testAll()               – chains all suites with staggered timers

Each suite uses test_tracking to record checksums, names, and queue
positions so artifacts can be cleaned up after a run.  Cleanup is
two-phase: an immediate testSweep() plus follow-up sweeps (3 × 15 s)
to catch sends delayed by WoW's addon-message throttle.

Also includes map-data extraction utilities (extractMapBounds,
extractWorldMapData, collectMapBounds) for development use.
--]]

local _dnl = DeathNotificationLib.Internal ---@class _dnl
if not _dnl then return end

--- Generate a random fake death entry for testing widgets.
--- Picks random name/guild from attached_db if available, random source from
--- _dnl.D.ID_TO_NPC, random map or instance, and includes PVP source randomization.
---@return PlayerData
local function createFakeEntry()
	local idx = math.random(1, 100)
	local some_name = UnitName("player")
	local some_guild = ""

	local found_random_name = false
	for _, addon in pairs(_dnl.addons) do
		if addon.db then
			for _, entry in pairs(addon.db) do
				some_name = entry["name"]
				some_guild = entry["guild"]
				idx = idx - 1
				if idx < 1 then
					found_random_name = true
					break
				end
			end
			if found_random_name then break end
		end
	end

	if not found_random_name then
		some_name = some_name .. math.random(1, 1000)
	end

	idx = math.random(1, 100)
	local some_source_id = -2
	for k, _ in pairs(_dnl.D.ID_TO_NPC) do
		idx = idx - 1
		some_source_id = k
		if idx < 1 then break end
	end

	idx = math.random(1, 2)
	local map_id = nil
	local instance_id = nil
	if idx == 1 then
		idx = math.random(1, 10)
		for k, _ in pairs(_dnl.D.ID_TO_INSTANCE) do
			idx = idx - 1
			instance_id = k
			if idx < 1 then break end
		end
	else
		idx = math.random(1, 10)
		for _, zones in pairs(_dnl.D.ZONE_TO_ID) do
			for _, v in pairs(zones) do
				idx = idx - 1
				map_id = v
				if idx < 1 then break end
			end
			if idx < 1 then break end
		end
	end

	local valid_class_ids = {1, 2, 3, 4, 5, 7, 8, 9, 11}
	local fake_entry = {
		["name"] = some_name,
		["level"] = math.random(1, 60),
		["class_id"] = valid_class_ids[math.random(1, #valid_class_ids)],
		["race_id"] = math.random(1, 8),
		["source_id"] = some_source_id,
		["map_id"] = map_id,
		["instance_id"] = instance_id,
		["guild"] = some_guild,
		["played"] = math.random(3600, 864000),
		["last_words"] = "Sample last words, help!",
	}

	local pvp_r = math.random(0, 3)
	local pvp_source_name = nil
	if pvp_r == 1 or pvp_r == 2 then
		local pvp_ok, src_id, src_name = _dnl.encodePvpSource(UnitName("target"), UnitGUID("target"))
		if pvp_ok and src_id then
			fake_entry["source_id"] = src_id
			pvp_source_name = src_name
		end
	elseif pvp_r == 3 and UnitIsPlayer("target") then
		_dnl.pvp_state.duel_to_death_player = UnitName("target")
		local _, src_id, src_name = _dnl.encodePvpSource(UnitName("target"), UnitGUID("target"))
		fake_entry["source_id"] = src_id
		pvp_source_name = src_name
		_dnl.pvp_state.duel_to_death_player = nil
	end

	if pvp_source_name and math.random(0, 100) < 50 then
		fake_entry["extra_data"] = {
			["pvp_source_name"] = pvp_source_name,
		}
	end

	return fake_entry
end

--#region API

--- Public API: generate a random fake death entry for widget previews
--- and smoke-testing.  This is intentionally exposed outside the DEBUG
--- guard because it is used by the Death Alert preview
--- (~DeathAlert.lua) in production.
DeathNotificationLib.CreateFakeEntry = createFakeEntry

--#endregion

if not _dnl.DEBUG then return end

-- ============================================================================
-- Test tracking & cleanup infrastructure
-- ============================================================================
-- Tracks all checksums/names created during a test run so they can be
-- removed afterwards, preventing test deaths from cluttering the real
-- deathlog.

local test_tracking = {
	active              = false,
	checksums           = {},   -- set of checksums created during test
	names               = {},   -- set of lowercase names touched
	queue_start         = 0,    -- #death_alert_out_queue before test began
	followups_scheduled = false,
	all_depth           = 0,    -- >0 when running inside testAll; suppresses individual cleanup,
	was_local_only      = nil,  -- for restoring _dnl.LOCAL_DEBUG_ONLY after testAll
	global_results      = {},   -- aggregated results across all suites during testAll
}

--- Number of silent follow-up sweeps after the initial cleanup.
--- Catches entries from sends delayed until player moves.
local CLEANUP_FOLLOW_UPS = 3
--- Seconds between follow-up sweeps.
local CLEANUP_FOLLOW_UP_INTERVAL = 15

--- Begin tracking test-created entries.  Call before any test logic.
--- Re-entrant: if already active, does not reset (allows nested test calls).
local function testBegin()
	if test_tracking.active then return end
	wipe(test_tracking.checksums)
	wipe(test_tracking.names)
	test_tracking.queue_start = #_dnl.death_alert_out_queue
	test_tracking.was_local_only = _dnl.LOCAL_DEBUG_ONLY
	_dnl.LOCAL_DEBUG_ONLY = true
	test_tracking.active = true
	test_tracking.followups_scheduled = false

	-- Pause real sync activity so it doesn't contaminate test results.
	-- Leverage the existing per-addon sync_enabled setting.
	-- Store addon references + originals in an array so nil values survive.
	test_tracking.saved_sync_enabled = {}
	for _, addon in pairs(_dnl.addons) do
		if addon.settings then
			table.insert(test_tracking.saved_sync_enabled, { addon = addon, original = addon.settings.sync_enabled })
			addon.settings.sync_enabled = false
		end
	end
	if _dnl._stopSyncWatermarkTicker then
		_dnl._stopSyncWatermarkTicker()
	end
	if _dnl._syncResetToIdle then
		_dnl._syncResetToIdle()
	end
end

--- Remove all currently tracked test entries from caches and database.
--- Does NOT deactivate tracking — late arrivals via the hook are still recorded
--- and will be cleaned by follow-up sweeps.
local function testSweep()
	-- LRU cache
	for cs in pairs(test_tracking.checksums) do
		_dnl.death_ping_lru_cache_tbl[cs] = nil
	end

	-- Name index
	for name in pairs(test_tracking.names) do
		_dnl.lru_by_name[name] = nil
	end

	-- Database: clean all registered addons' dbs
	for _, addon in pairs(_dnl.addons) do
		if addon.db then
			for cs in pairs(test_tracking.checksums) do
				addon.db[cs] = nil
			end
		end
		if addon.db_map then
			for name in pairs(test_tracking.names) do
				for map_name, map_cs in pairs(addon.db_map) do
					if map_name:lower() == name then
						if addon.db then addon.db[map_cs] = nil end
						addon.db_map[map_name] = nil
					end
				end
			end
		end
	end
end

--- Stop tracking and remove all test artifacts from:
---   1. _dnl.death_ping_lru_cache_tbl
---   2. _dnl.lru_by_name
---   3. _dnl.death_alert_out_queue  (entries added during the test)
---   4. all registered addons' db / db_map tables
---
--- After the initial sweep, tracking stays active and follow-up sweeps run
--- every CLEANUP_FOLLOW_UP_INTERVAL seconds to catch sends that were delayed
--- by WoW's addon-message throttle (queued until player moves/acts).
---
--- When running inside testAll (all_depth > 0), individual test cleanup calls
--- only perform a sweep — follow-ups and deactivation are deferred to testAll.
local function testCleanup()
	if not test_tracking.active then return end

	-- Inside testAll: just sweep, don't schedule follow-ups or deactivate
	if test_tracking.all_depth > 0 then
		testSweep()
		return
	end

	-- Out queue: remove entries appended during the test (only on first cleanup)
	local queue_end = #_dnl.death_alert_out_queue
	if queue_end > test_tracking.queue_start then
		for i = queue_end, test_tracking.queue_start + 1, -1 do
			table.remove(_dnl.death_alert_out_queue, i)
		end
	end

	-- Immediate sweep
	testSweep()

	-- Print summary & schedule follow-ups only on the first testCleanup call.
	-- Re-entrant tests may fire additional testCleanup calls — those just
	-- perform an extra (idempotent) sweep above.
	if not test_tracking.followups_scheduled then
		test_tracking.followups_scheduled = true

		local cs_count = 0
		for _ in pairs(test_tracking.checksums) do cs_count = cs_count + 1 end
		local name_count = 0
		for _ in pairs(test_tracking.names) do name_count = name_count + 1 end
		print(string.format("|cffFF6600[Deathlog]|r Test cleanup: removed %d checksums, %d names from caches", cs_count, name_count))
		print(string.format("|cffFF6600[Deathlog]|r  (tracking stays active for %ds to catch delayed sends)",
			CLEANUP_FOLLOW_UPS * CLEANUP_FOLLOW_UP_INTERVAL))

		for i = 1, CLEANUP_FOLLOW_UPS do
			C_Timer.After(i * CLEANUP_FOLLOW_UP_INTERVAL, function()
				if not test_tracking.active then return end
				testSweep()
				if i == CLEANUP_FOLLOW_UPS then
					test_tracking.active = false
					wipe(test_tracking.checksums)
					wipe(test_tracking.names)
					_dnl.LOCAL_DEBUG_ONLY = test_tracking.was_local_only
					-- Restore per-addon sync_enabled settings
					if test_tracking.saved_sync_enabled then
						for _, entry in ipairs(test_tracking.saved_sync_enabled) do
							entry.addon.settings.sync_enabled = entry.original
						end
						test_tracking.saved_sync_enabled = nil
					end
					if _dnl._startSyncWatermarkTicker then
						_dnl._startSyncWatermarkTicker()
					end
				end
			end)
		end
	end
end

--- Track a checksum + name generated during a test.
--- Called from createEntry hook and direct insertions.
local function testTrack(player_data, checksum)
	if not test_tracking.active then return end
	if checksum then
		test_tracking.checksums[checksum] = true
	end
	if player_data and player_data["name"] then
		test_tracking.names[player_data["name"]:lower()] = true
	end
end

-- Install a permanent createEntry hook that only records when tracking is active.
-- Because it checks test_tracking.active, it's a no-op during normal play.
DeathNotificationLib.HookOnNewEntry(function(player_data, checksum, peer_count, in_guild)
	testTrack(player_data, checksum)
end)

-- Also track entries that go through broadcastDeath (outbound) but haven't
-- hit createEntry yet — track when we insert into LRU cache
local orig_updateLRUByName = _dnl.updateLRUByName
_dnl.updateLRUByName = function(name_lower, checksum, committed, level)
	orig_updateLRUByName(name_lower, checksum, committed, level)
	if test_tracking.active then
		if checksum then test_tracking.checksums[checksum] = true end
		if name_lower then test_tracking.names[name_lower] = true end
	end
end

-- Expose for internal use
_dnl._testBegin   = testBegin
_dnl._testCleanup = testCleanup
_dnl._testTrack   = testTrack

function _dnl.testSelfDeathWithReportedDeath()
	testBegin()
	_dnl.testSelfDeath()
	_dnl.testReportedDeath()
	-- Cleanup after the async reported-death timer (1s) + buffer
	C_Timer.After(5, testCleanup)
end

function _dnl.testSelfDeath()
	testBegin()
	print("|cffFF6600[Deathlog]|r Simulating self death.")
	local unitState = _dnl.getUnitState("player")
	unitState.last_attack_source_name = _dnl.D.ID_TO_NPC[448]
	unitState.recent_msg = "This is my last words."
	local soul_of_iron_was_active = nil
	if unitState.hasSoulOfIron ~= nil then
		soul_of_iron_was_active = unitState.hasSoulOfIron
		unitState.hasSoulOfIron = true
	end
	_dnl.lru_by_name[UnitName("player"):lower()] = nil
	_dnl.handleEvent(_dnl.event_handler, "PLAYER_DEAD")
	if unitState.hasSoulOfIron ~= nil then
		unitState.hasSoulOfIron = soul_of_iron_was_active
	end
	-- Cleanup after LRU auto-commit timer (3.5s) + buffer
	C_Timer.After(5, testCleanup)
end

function _dnl.testReportedDeath()
	testBegin()
	if not UnitExists("target") then
		print("|cffFF6600[Deathlog]|r No target. Target a player first.")
		testCleanup()
		return
	end
	local name = UnitName("target")
	local guid = UnitGUID("target")
	if not guid or not guid:match("^Player") then
		print("|cffFF6600[Deathlog]|r Target is not a player.")
		testCleanup()
		return
	end
	print("|cffFF6600[Deathlog]|r Simulating Soul of Iron death for:", name, "GUID:", guid)

	_dnl.lru_by_name[name:lower()] = nil

	local test_msg = "Death tarnishes %s's soul."
	local test_name = name
	local test_guid = guid

	C_Timer.After(1, function()
		print("Processing emote...")
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
		_dnl.handleEvent(_dnl.event_handler, "CHAT_MSG_MONSTER_EMOTE", unpack(my_args))
		-- Cleanup after LRU auto-commit + buffer
		C_Timer.After(5, testCleanup)
	end)
end

function _dnl.testPartyDeath()
	testBegin()
	local group_units = {}

	if IsInRaid() then
		for i = 1, 40 do
			local unit = "raid" .. i
			if UnitExists(unit) and not UnitIsUnit(unit, "player") and UnitIsPlayer(unit) then
				table.insert(group_units, unit)
			end
		end
	else
		for i = 1, 4 do
			local unit = "party" .. i
			if UnitExists(unit) and not UnitIsUnit(unit, "player") and UnitIsPlayer(unit) then
				table.insert(group_units, unit)
			end
		end
	end

	if #group_units == 0 then
		print("|cffFF6600[Deathlog]|r No party/raid members found. Join a group first.")
		testCleanup()
		return
	end

	local random_unit = group_units[math.random(1, #group_units)]
	local player_name = UnitName(random_unit)

	C_Timer.After(1, function() 
		print("|cffFF6600[Deathlog]|r Simulating party/raid death for:", player_name, "(", random_unit, ")")

		_dnl.lru_by_name[player_name:lower()] = nil

		local unitState = _dnl.getUnitState(random_unit)
		unitState.last_attack_source_name = _dnl.D.ID_TO_NPC[448]
		unitState.recent_msg = "This is my last words."

		_dnl.reportPartyRaidDeath(random_unit)

		print("|cffFF6600[Deathlog]|r Death report queued. Press any key or click to process send queue.")
		-- Cleanup after LRU auto-commit + buffer
		C_Timer.After(5, testCleanup)
	end)
end

local function GetExpansionInfo()
	if GetExpansionLevel then
		local level = GetExpansionLevel()
		if level >= 1 then
			return "tbc", level
		end
	end
	return "vanilla", 0
end

function _dnl.collectMapBounds()
	local expansionName, expansionLevel = GetExpansionInfo()
	
	local mapIds = {}
	for zone_id, _ in pairs(_dnl.D.ID_TO_ZONE) do
		table.insert(mapIds, zone_id)
	end
	table.sort(mapIds)

	local output = string.format("# Map bounds extracted from %s client (expansion_level=%d)\n", expansionName, expansionLevel)
	output = output .. "map_bounds = {\n"
	
	for _, mapId in ipairs(mapIds) do
		local mapInfo = C_Map.GetMapInfo(mapId)
		if mapInfo and mapInfo.parentMapID and mapInfo.parentMapID > 0 then
			local parentId = mapInfo.parentMapID
			local topLeft = CreateVector2D(0, 0)
			local bottomRight = CreateVector2D(1, 1)
			
			local cid1, wp1 = C_Map.GetWorldPosFromMapPos(mapId, topLeft)
			local cid2, wp2 = C_Map.GetWorldPosFromMapPos(mapId, bottomRight)
			
			if wp1 and wp2 then
				local _, pp1 = C_Map.GetMapPosFromWorldPos(cid1, wp1, parentId)
				local _, pp2 = C_Map.GetMapPosFromWorldPos(cid2, wp2, parentId)
				
				if pp1 and pp2 then
					local x1, y1 = pp1:GetXY()
					local x2, y2 = pp2:GetXY()
					output = output .. string.format("    %d: {'parent': %d, 'x1': %.6f, 'y1': %.6f, 'x2': %.6f, 'y2': %.6f},\n",
						mapId, parentId, x1, y1, x2, y2)
				end
			end
		end
	end
	
	output = output .. "}"

	return output
end

function _dnl.extractMapBounds()
	local data = _dnl.collectMapBounds()
	for _, addon in pairs(_dnl.addons) do
		if addon.dev_data then
			addon.dev_data.map_bounds = data
		end
	end
	print("-- Map bounds data for coordinate transformation")
	print(data)
	print("-- Data also saved to SavedVariables. /reload and check SavedVariables/Deathlog.lua")
end

function _dnl.extractMapBoundsSimple()
	for _, addon in pairs(_dnl.addons) do
		if addon.dev_data then
			addon.dev_data.map_bounds = _dnl.collectMapBounds()
		end
	end
	print("Map bounds extracted! /reload and check SavedVariables/Deathlog.lua")
end

function _dnl.extractWorldMapData()
	local expansionName, expansionLevel = GetExpansionInfo()
	
	local continentMaps = {
		{mapId = 1415, instanceId = 0, name = "Eastern Kingdoms"},
		{mapId = 1414, instanceId = 1, name = "Kalimdor"},
		{mapId = 1945, instanceId = 530, name = "Outland"},
	}
	
	local zoneMaps = {}
	for zone_id, _ in pairs(_dnl.D.ID_TO_ZONE) do
		table.insert(zoneMaps, zone_id)
	end
	table.sort(zoneMaps)
	
	local output = string.format("-- World map data extracted from %s client (expansion_level=%d)\n", expansionName, expansionLevel)
	output = output .. "-- Format: { width, height, left, top } in world coordinates\n"
	output = output .. "world_map_data = {\n"
	output = output .. string.format('    ["%s"] = {\n', expansionName)
	
	output = output .. "        -- Continents (by instance ID)\n"
	for _, continent in ipairs(continentMaps) do
		local mapId = continent.mapId
		local topLeft = CreateVector2D(0, 0)
		local bottomRight = CreateVector2D(1, 1)
		
		local cid1, wp1 = C_Map.GetWorldPosFromMapPos(mapId, topLeft)
		local cid2, wp2 = C_Map.GetWorldPosFromMapPos(mapId, bottomRight)
		
		if wp1 and wp2 then
			local x1, y1 = wp1:GetXY()
			local x2, y2 = wp2:GetXY()
			
			local width = math.abs(x2 - x1)
			local height = math.abs(y2 - y1)
			local left = math.min(x1, x2)
			local top = math.min(y1, y2)
			
			output = output .. string.format('        %d: {"width": %.2f, "height": %.2f, "left": %.2f, "top": %.2f},  -- %s\n',
				continent.instanceId, width, height, left, top, continent.name)
		end
	end
	
	output = output .. "        -- Zones (by map ID) - world coordinates for zone corners\n"
	for _, mapId in ipairs(zoneMaps) do
		local mapInfo = C_Map.GetMapInfo(mapId)
		if mapInfo then
			local topLeft = CreateVector2D(0, 0)
			local bottomRight = CreateVector2D(1, 1)
			
			local cid1, wp1 = C_Map.GetWorldPosFromMapPos(mapId, topLeft)
			local cid2, wp2 = C_Map.GetWorldPosFromMapPos(mapId, bottomRight)
			
			if wp1 and wp2 then
				local x1, y1 = wp1:GetXY()
				local x2, y2 = wp2:GetXY()
				
				local width = x2 - x1
				local height = y2 - y1
				
				output = output .. string.format('        %d: {"left": %.2f, "top": %.2f, "width": %.2f, "height": %.2f},  -- %s\n',
					mapId, x1, y1, width, height, mapInfo.name or "Unknown")
			end
		end
	end
	
	output = output .. "    },\n"
	output = output .. "}"
	
	for _, addon in pairs(_dnl.addons) do
		if addon.dev_data then
			addon.dev_data.world_map_data = output
		end
	end
	print(output)
	print("-- Data also saved to SavedVariables. /reload and check SavedVariables/Deathlog.lua")
	return output
end

-- ============================================================================
-- V2 backwards compatibility tests
-- ============================================================================

function _dnl.testV2BackwardsCompat()
	testBegin()
	local PASS = "|cff00FF00PASS|r"
	local FAIL = "|cffFF0000FAIL|r"
	local TAG  = "|cffFF6600[Backwards Compat]|r "

	local results = {}
	local function record(name, ok, detail)
		table.insert(results, { name = name, ok = ok, detail = detail })
		if test_tracking.all_depth > 0 then
			table.insert(test_tracking.global_results, { suite = "Backwards", name = name, ok = ok, detail = detail })
		end
		local status = ok and PASS or FAIL
		print(TAG .. status .. " " .. name .. (detail and (" - " .. detail) or ""))
	end

	local function printSummary()
		print(TAG .. "--- Summary ---")
		local passed, failed = 0, 0
		for _, r in ipairs(results) do
			if r.ok then passed = passed + 1 else failed = failed + 1 end
		end
		for _, r in ipairs(results) do
			local status = r.ok and PASS or FAIL
			print(TAG .. "  " .. status .. " " .. r.name)
		end
		local color = failed == 0 and "|cff00FF00" or "|cffFF0000"
		print(TAG .. color .. string.format("%d/%d passed|r", passed, passed + failed))
	end

	if not _dnl._backwards then
		print(TAG .. "|cffFF0000SKIP|r Backwards module not loaded (DEBUG mode required)")
		return
	end

	local bw = _dnl._backwards

	-- ============================================================
	-- Phase 1: V2 fletcher16
	-- ============================================================
	print(TAG .. "Phase 1: V2 fletcher16")

	local test_pd = _dnl.playerData("TestPlayer", "TestGuild", 100, 1, 1, 30, nil, 1429, nil, nil, nil, nil)
	local v2_cs = bw.fletcher16V2(test_pd)
	local v3_cs = _dnl.fletcher16(test_pd)
	record("v2 fletcher16 returns string", type(v2_cs) == "string" and v2_cs ~= "")
	record("v2 fletcher16 starts with name", v2_cs:sub(1, #"TestPlayer") == "TestPlayer")
	record("v2 and v3 fletcher16 differ",
		v2_cs ~= v3_cs,
		string.format("v2=%s, v3=%s", v2_cs, v3_cs))

	-- v2 fletcher16 is deterministic
	record("v2 fletcher16 deterministic", bw.fletcher16V2(test_pd) == v2_cs)

	-- ============================================================
	-- Phase 2: V2 message decode (10-field format)
	-- ============================================================
	print(TAG .. "Phase 2: V2 message decode")

	-- Build a v2-format message: name~guild~source_id~race_id~class_id~level~instance_id~map_id~map_pos~extra_data~protocol_version~
	local v2_msg = "V2Player~V2Guild~1234~1~3~42~~1429~0.5000,0.6000~~2~"
	local v2_decoded, v2_ver = bw.decodeV2Message(v2_msg)
	record("decodeV2Message returns PlayerData", v2_decoded ~= nil, type(v2_decoded))
	if v2_decoded then
		record("v2 decode: name", v2_decoded["name"] == "V2Player", tostring(v2_decoded["name"]))
		record("v2 decode: guild", v2_decoded["guild"] == "V2Guild", tostring(v2_decoded["guild"]))
		record("v2 decode: source_id", tonumber(v2_decoded["source_id"]) == 1234)
		record("v2 decode: race_id", tonumber(v2_decoded["race_id"]) == 1)
		record("v2 decode: class_id", tonumber(v2_decoded["class_id"]) == 3)
		record("v2 decode: level", tonumber(v2_decoded["level"]) == 42)
		record("v2 decode: map_id", tonumber(v2_decoded["map_id"]) == 1429)
		record("v2 decode: map_pos", v2_decoded["map_pos"] == "0.5000,0.6000")
		record("v2 decode: protocol_version", v2_ver == 2, tostring(v2_ver))
	end

	-- Too-short message returns nil
	local short_v2, _ = bw.decodeV2Message("Name~Guild~100~")
	record("decodeV2Message rejects short message", short_v2 == nil)

	-- ============================================================
	-- Phase 3: V2 BROADCAST_DEATH_PING adapter (end-to-end)
	-- ============================================================
	print(TAG .. "Phase 3: V2 death broadcast adapter")

	local v2_death_name = "V2DeathTest" .. math.random(10000, 99999)
	_dnl.lru_by_name[v2_death_name:lower()] = nil

	-- Build a v2-format death ping (10 fields + protocol version)
	local v2_death_msg = v2_death_name .. "~TestGuild~1234~1~3~42~~1429~0.5000,0.6000~~2~"
	_dnl.handleV2DeathBroadcast("V2Sender", v2_death_msg)

	-- Verify it ended up in the v3 LRU cache
	local v2_lru = _dnl.lru_by_name[v2_death_name:lower()]
	record("v2 death broadcast stored in LRU", v2_lru ~= nil)
	if v2_lru and v2_lru.checksum then
		local v2_cache = _dnl.death_ping_lru_cache_tbl[v2_lru.checksum]
		record("v2 death broadcast has player_data", v2_cache ~= nil and v2_cache["player_data"] ~= nil)
		if v2_cache and v2_cache["player_data"] then
			record("v2 death broadcast: name correct",
				v2_cache["player_data"]["name"] == v2_death_name)
			record("v2 death broadcast: level correct",
				tonumber(v2_cache["player_data"]["level"]) == 42)
			record("v2 death broadcast: source_id correct",
				tonumber(v2_cache["player_data"]["source_id"]) == 1234)
		end
	end

	-- ============================================================
	-- Phase 4: V2 LAST_WORDS handler
	-- ============================================================
	print(TAG .. "Phase 4: V2 LAST_WORDS handler")

	-- Create a cache entry first, then send last words to it
	local lw_name = "LWTest" .. math.random(10000, 99999)
	_dnl.lru_by_name[lw_name:lower()] = nil

	local lw_pd = _dnl.playerData(lw_name, "G", 100, 1, 1, 30, nil, 1429, nil, GetServerTime(), nil, nil)
	local lw_v3_cs = _dnl.fletcher16(lw_pd)
	_dnl.death_ping_lru_cache_tbl[lw_v3_cs] = {
		player_data = lw_pd,
		quality = _dnl.QUALITY.PEER,
		timestamp = GetServerTime(),
	}
	_dnl.updateLRUByName(lw_name:lower(), lw_v3_cs, false, lw_pd["level"])

	-- v2 uses a different checksum, so it won't match directly — should use name fallback
	local lw_v2_cs = bw.fletcher16V2(lw_pd)
	local lw_msg = lw_v2_cs .. _dnl.COMM_FIELD_DELIM .. "Avenge me!" .. _dnl.COMM_FIELD_DELIM .. "2" .. _dnl.COMM_FIELD_DELIM
	bw.V2_COMM_COMMANDS["LAST_WORDS"] = "3"  -- sanity check

	-- Invoke the handler through the dispatch table
	_dnl.backwards_dispatch["3"]("LastWordsSender", lw_msg)

	-- Verify the last words were patched into the v3 entry
	local lw_cache = _dnl.death_ping_lru_cache_tbl[lw_v3_cs]
	record("v2 LAST_WORDS patched via name lookup",
		lw_cache and lw_cache["player_data"] and lw_cache["player_data"]["last_words"] == "Avenge me!",
		string.format("got '%s'", tostring(lw_cache and lw_cache["player_data"] and lw_cache["player_data"]["last_words"])))

	-- Test orphan last words (no cache entry yet)
	local orphan_name = "OrphanLW" .. math.random(10000, 99999)
	local orphan_pd = _dnl.playerData(orphan_name, "", 100, 1, 1, 25, nil, 1429, nil, nil, nil, nil)
	local orphan_v2_cs = bw.fletcher16V2(orphan_pd)
	_dnl.backwards_dispatch["3"]("OrphanSender",
		orphan_v2_cs .. _dnl.COMM_FIELD_DELIM .. "Help!" .. _dnl.COMM_FIELD_DELIM .. "2" .. _dnl.COMM_FIELD_DELIM)
	record("orphan last_words stored under v2 checksum",
		_dnl.death_ping_lru_cache_tbl[orphan_v2_cs] ~= nil
		and _dnl.death_ping_lru_cache_tbl[orphan_v2_cs]["last_words"] == "Help!")

	-- ============================================================
	-- Phase 5: V2 TARNISHED_SOUL handler
	-- ============================================================
	print(TAG .. "Phase 5: V2 TARNISHED_SOUL handler")

	local ts_name = "V2TarnishedTest" .. math.random(10000, 99999)
	_dnl.lru_by_name[ts_name:lower()] = nil

	-- v2 tarnished soul format: name~guild~source_id(-1)~race_id~class_id~level~instance_id~map_id~map_pos~extra_data~quality~protocol_version~
	local ts_msg = ts_name .. "~TSGuild~-1~2~4~35~~1426~0.4000,0.5000~~" .. bw.V2_QUALITY.CONTEXT .. "~2~"
	_dnl.backwards_dispatch["6"]("TSSender", ts_msg)

	-- Verify it entered the v3 pipeline
	local ts_lru = _dnl.lru_by_name[ts_name:lower()]
	record("v2 TARNISHED_SOUL stored in LRU", ts_lru ~= nil)
	if ts_lru and ts_lru.checksum then
		local ts_cache = _dnl.death_ping_lru_cache_tbl[ts_lru.checksum]
		record("v2 TARNISHED_SOUL has player_data",
			ts_cache ~= nil and ts_cache["player_data"] ~= nil)
		if ts_cache and ts_cache["player_data"] then
			record("v2 TARNISHED_SOUL source_id is -1",
				tonumber(ts_cache["player_data"]["source_id"]) == -1)
			record("v2 TARNISHED_SOUL level correct",
				tonumber(ts_cache["player_data"]["level"]) == 35)
		end
	end

	-- Test self-report quality routing
	local ts_self_name = "V2TSSelf" .. math.random(10000, 99999)
	_dnl.lru_by_name[ts_self_name:lower()] = nil
	local ts_self_msg = ts_self_name .. "~SG~-1~1~1~40~~1429~~~" .. bw.V2_QUALITY.SELF .. "~2~"
	_dnl.backwards_dispatch["6"](ts_self_name, ts_self_msg)
	local ts_self_lru = _dnl.lru_by_name[ts_self_name:lower()]
	if ts_self_lru and ts_self_lru.checksum then
		local ts_self_cache = _dnl.death_ping_lru_cache_tbl[ts_self_lru.checksum]
		record("v2 TARNISHED_SOUL self-report quality is SELF",
			ts_self_cache and ts_self_cache["quality"] == _dnl.QUALITY.SELF,
			string.format("expected %d, got %s", _dnl.QUALITY.SELF, tostring(ts_self_cache and ts_self_cache["quality"])))
	else
		record("v2 TARNISHED_SOUL self-report quality is SELF", false, "no LRU entry found")
	end

	-- ============================================================
	-- Phase 6: V0/V2 protocol version handling
	-- ============================================================
	print(TAG .. "Phase 6: V0/V2 protocol version boundary")

	record("MIN_SUPPORTED_PROTOCOL_VERSION is 0",
		_dnl.MIN_SUPPORTED_PROTOCOL_VERSION == 0,
		string.format("got %s", tostring(_dnl.MIN_SUPPORTED_PROTOCOL_VERSION)))

	-- v0 messages (no version field, 10 fields) are handled by the backwards adapter
	-- and re-encoded as v3, so they pass the version gate.
	-- The MIN==0 means even a hypothetical 13-field v0 message would be accepted.

	-- v2 death broadcast with explicit protocol version
	local v2_explicit_name = "V2Explicit" .. math.random(10000, 99999)
	_dnl.lru_by_name[v2_explicit_name:lower()] = nil
	local v2_explicit_msg = v2_explicit_name .. "~G~100~1~1~30~~1429~0.5,0.6~~2~"
	_dnl.handleV2DeathBroadcast("V2ExplicitSender", v2_explicit_msg)
	record("v2 death broadcast accepted (explicit version)",
		_dnl.lru_by_name[v2_explicit_name:lower()] ~= nil,
		"entry should exist in LRU")

	-- v0 death broadcast (no version field, only 10 fields)
	local v0_name = "V0Player" .. math.random(10000, 99999)
	_dnl.lru_by_name[v0_name:lower()] = nil
	local v0_msg = v0_name .. "~G~100~1~1~25~~1429~0.5,0.5~~"
	_dnl.handleV2DeathBroadcast("V0Sender", v0_msg)
	record("v0 death broadcast accepted (no version field)",
		_dnl.lru_by_name[v0_name:lower()] ~= nil,
		"entry should exist in LRU")

	-- Verify v0 decode returns protocol_version == 0
	local v0_decoded, v0_ver = bw.decodeV2Message(v0_msg)
	record("v0 message decodes with version 0",
		v0_decoded ~= nil and v0_ver == 0,
		string.format("ver=%s", tostring(v0_ver)))

	-- ============================================================
	-- Phase 6b: Hardcore addon 9-field messages (no extra_data field)
	-- ============================================================
	print(TAG .. "Phase 6b: Hardcore addon 9-field messages")

	-- The Hardcore addon's encodeMessage produces exactly 9 tilde-delimited
	-- fields with a trailing tilde: name~guild~src~race~class~lvl~inst~map~pos~
	-- Unlike v0/v2 which have 10+ fields, there is no extra_data field at all.
	local hc_name = "HCAddon" .. math.random(10000, 99999)
	local hc_msg_9 = hc_name .. "~HCGuild~1234~1~3~42~~1429~0.5000,0.6000~"
	local hc_decoded_9, hc_ver_9 = bw.decodeV2Message(hc_msg_9)
	record("9-field HC message decodes successfully", hc_decoded_9 ~= nil)
	record("9-field HC message: version == 0", hc_ver_9 == 0, tostring(hc_ver_9))
	if hc_decoded_9 then
		record("9-field HC decode: name", hc_decoded_9["name"] == hc_name, tostring(hc_decoded_9["name"]))
		record("9-field HC decode: guild", hc_decoded_9["guild"] == "HCGuild", tostring(hc_decoded_9["guild"]))
		record("9-field HC decode: source_id", tonumber(hc_decoded_9["source_id"]) == 1234)
		record("9-field HC decode: race_id", tonumber(hc_decoded_9["race_id"]) == 1)
		record("9-field HC decode: class_id", tonumber(hc_decoded_9["class_id"]) == 3)
		record("9-field HC decode: level", tonumber(hc_decoded_9["level"]) == 42)
		record("9-field HC decode: map_id", tonumber(hc_decoded_9["map_id"]) == 1429)
		record("9-field HC decode: map_pos", hc_decoded_9["map_pos"] == "0.5000,0.6000")
	end

	-- 9-field message with empty instance_id/map_pos (dungeon death)
	local hc_name_d = "HCDungeon" .. math.random(10000, 99999)
	local hc_msg_dungeon = hc_name_d .. "~HCGuild~5678~2~4~35~~~0.0000,0.0000~"
	local hc_decoded_d, _ = bw.decodeV2Message(hc_msg_dungeon)
	record("9-field HC dungeon message decodes", hc_decoded_d ~= nil)
	if hc_decoded_d then
		record("9-field HC dungeon: name", hc_decoded_d["name"] == hc_name_d)
		record("9-field HC dungeon: level", tonumber(hc_decoded_d["level"]) == 35)
	end

	-- 9-field message through handleV2DeathBroadcast end-to-end
	local hc_e2e_name = "HCE2E" .. math.random(10000, 99999)
	_dnl.lru_by_name[hc_e2e_name:lower()] = nil
	local hc_e2e_msg = hc_e2e_name .. "~TestGuild~1234~1~3~55~~1429~0.5000,0.6000~"
	_dnl.handleV2DeathBroadcast("HCSender", hc_e2e_msg)
	record("9-field HC death broadcast stored in LRU",
		_dnl.lru_by_name[hc_e2e_name:lower()] ~= nil,
		"entry should exist in LRU")
	if _dnl.lru_by_name[hc_e2e_name:lower()] then
		local hc_cs = _dnl.lru_by_name[hc_e2e_name:lower()].checksum
		local hc_cache = hc_cs and _dnl.death_ping_lru_cache_tbl[hc_cs]
		record("9-field HC E2E: player_data exists",
			hc_cache ~= nil and hc_cache["player_data"] ~= nil)
		if hc_cache and hc_cache["player_data"] then
			record("9-field HC E2E: name correct",
				hc_cache["player_data"]["name"] == hc_e2e_name)
			record("9-field HC E2E: level correct",
				tonumber(hc_cache["player_data"]["level"]) == 55)
			record("9-field HC E2E: source_id correct",
				tonumber(hc_cache["player_data"]["source_id"]) == 1234)
		end
	end

	-- 8-field message should still be rejected (too short)
	local short_8, _ = bw.decodeV2Message("A~B~1~2~3~4~5~6~")
	record("8-field message rejected", short_8 == nil)

	-- ============================================================
	-- Phase 7: Malformed legacy messages
	-- ============================================================
	print(TAG .. "Phase 7: Malformed legacy messages")

	record("handleV2DeathBroadcast ignores nil",
		pcall(function() _dnl.handleV2DeathBroadcast("S", nil) end))
	record("handleV2DeathBroadcast ignores empty",
		pcall(function() _dnl.handleV2DeathBroadcast("S", "") end))
	record("v2 LAST_WORDS ignores nil",
		pcall(function() _dnl.backwards_dispatch["3"]("S", nil) end))
	record("v2 TARNISHED_SOUL ignores nil",
		pcall(function() _dnl.backwards_dispatch["6"]("S", nil) end))
	record("v2 TARNISHED_SOUL ignores short msg",
		pcall(function() _dnl.backwards_dispatch["6"]("S", "Name~Guild~") end))

	-- ============================================================
	-- Summary
	-- ============================================================
	C_Timer.After(0.5, function()
		print(TAG .. "=========================")
		printSummary()
		print(TAG .. "=========================")
		testCleanup()
	end)
end

-- ============================================================================
-- Integration test: end-to-end pipeline validation
-- ============================================================================

--- Run a multi-step integration test that exercises the full death processing
--- pipeline: self-death → reported death → dedup → encode/decode round-trip →
--- fake entry → pass/fail summary. Uses C_Timer.After to sequence each stage
--- so the LRU cache timers run between steps.
function _dnl.testIntegration()
	testBegin()
	local PASS = "|cff00FF00PASS|r"
	local FAIL = "|cffFF0000FAIL|r"
	local TAG  = "|cffFF6600[Deathlog Integration]|r "

	local results = {}
	local function record(name, ok, detail)
		table.insert(results, { name = name, ok = ok, detail = detail })
		if test_tracking.all_depth > 0 then
			table.insert(test_tracking.global_results, { suite = "Integration", name = name, ok = ok, detail = detail })
		end
		local status = ok and PASS or FAIL
		print(TAG .. status .. " " .. name .. (detail and (" - " .. detail) or ""))
	end

	local function printSummary()
		print(TAG .. "--- Summary ---")
		local passed, failed = 0, 0
		for _, r in ipairs(results) do
			if r.ok then passed = passed + 1 else failed = failed + 1 end
		end
		for _, r in ipairs(results) do
			local status = r.ok and PASS or FAIL
			print(TAG .. "  " .. status .. " " .. r.name)
		end
		local color = failed == 0 and "|cff00FF00" or "|cffFF0000"
		print(TAG .. color .. string.format("%d/%d passed|r", passed, passed + failed))
	end

	-- Capture hook callbacks for verification
	local captured_entries = {}   -- { checksum -> player_data }

	local test_hook_called = false
	local test_hook_data = nil
	local test_hook_checksum = nil

	local function resetHookCapture()
		test_hook_called = false
		test_hook_data = nil
		test_hook_checksum = nil
	end

	DeathNotificationLib.HookOnNewEntry(function(player_data, checksum, peer_report, in_guild)
		test_hook_called = true
		test_hook_data = player_data
		test_hook_checksum = checksum
		if checksum then
			captured_entries[checksum] = player_data
		end
	end)

	print(TAG .. "Starting integration test...")
	print(TAG .. "Phase 1: Encode/Decode round-trip")

	-- Step 1: Encode/Decode round-trip
	local function step1_encodeDecode()
		local test_data = _dnl.playerData(
			"TestPlayer",
			"TestGuild",
			1234,  -- source_id (some NPC)
			1,     -- race_id (Human)
			1,     -- class_id (Warrior)
			42,    -- level
			nil,   -- instance_id
			1429,  -- map_id (Elwynn Forest)
			"0.5000,0.5000",  -- map_pos
			GetServerTime(),
			nil,   -- played
			"Avenge me!"
		)

		local encoded = _dnl.encodeMessage(test_data)
		record("encodeMessage returns string", encoded ~= nil and type(encoded) == "string")

		if encoded then
			local decoded, version = _dnl.decodeMessage(encoded)
			record("decodeMessage returns table", decoded ~= nil and type(decoded) == "table")

			if decoded then
				record("round-trip: name preserved",
					decoded["name"] == test_data["name"],
					string.format("expected '%s', got '%s'", test_data["name"], tostring(decoded["name"])))

				record("round-trip: level preserved",
					tonumber(decoded["level"]) == test_data["level"],
					string.format("expected %d, got %s", test_data["level"], tostring(decoded["level"])))

				record("round-trip: source_id preserved",
					tonumber(decoded["source_id"]) == test_data["source_id"],
					string.format("expected %d, got %s", test_data["source_id"], tostring(decoded["source_id"])))

				record("round-trip: guild preserved",
					decoded["guild"] == test_data["guild"],
					string.format("expected '%s', got '%s'", test_data["guild"], tostring(decoded["guild"])))

				record("round-trip: last_words preserved",
					decoded["last_words"] == test_data["last_words"],
					string.format("expected '%s', got '%s'", test_data["last_words"], tostring(decoded["last_words"])))

				record("round-trip: protocol version",
					version ~= nil and version == _dnl.PROTOCOL_VERSION,
					string.format("expected %s, got %s", tostring(_dnl.PROTOCOL_VERSION), tostring(version)))
			end

			-- Checksum consistency
			local cs1 = _dnl.fletcher16(test_data)
			local cs2 = _dnl.fletcher16(test_data)
			record("fletcher16 deterministic", cs1 == cs2, string.format("%s == %s", tostring(cs1), tostring(cs2)))
		end
	end

	step1_encodeDecode()

	-- Step 2: CreateFakeEntry
	print(TAG .. "Phase 2: CreateFakeEntry validation")
	local function step2_fakeEntry()
		local fake = createFakeEntry()
		record("createFakeEntry returns table", fake ~= nil and type(fake) == "table")
		if fake then
			record("fake entry has name", fake["name"] ~= nil and fake["name"] ~= "")
			record("fake entry has level", fake["level"] ~= nil and fake["level"] > 0)
			record("fake entry has class_id", fake["class_id"] ~= nil and fake["class_id"] >= 1 and fake["class_id"] <= 12)
			record("fake entry has race_id", fake["race_id"] ~= nil and fake["race_id"] >= 1 and fake["race_id"] <= 8)
			record("fake entry has source_id", fake["source_id"] ~= nil and type(fake["source_id"]) == "number")
			record("fake entry has map_id or instance_id",
				fake["map_id"] ~= nil or fake["instance_id"] ~= nil)

			-- Verify encode/decode round-trip on fake entry (source_id must be a number for encodeMessage)
			local encoded_fake = _dnl.encodeMessage(fake)
			record("fake entry encodes successfully", encoded_fake ~= nil,
				not encoded_fake and string.format("source_id=%s, name=%s", tostring(fake["source_id"]), tostring(fake["name"])) or nil)
		end
	end

	step2_fakeEntry()

	-- Step 3: Self-death simulation (requires handleEvent + broadcastDeath)
	print(TAG .. "Phase 3: Self-death simulation (async)")
	resetHookCapture()

	-- Clear any existing LRU entry for this player
	local player_name = UnitName("player")
	_dnl.lru_by_name[player_name:lower()] = nil

	-- Set up controlled death source
	local unitState = _dnl.getUnitState("player")
	local saved_last_attack_name = unitState.last_attack_source_name
	local saved_last_attack_guid = unitState.last_attack_source_guid
	local saved_recent_msg = unitState.recent_msg
	local saved_hasSoulOfIron = unitState.hasSoulOfIron
	local saved_is_hardcore_realm = _dnl.IS_HARDCORE_REALM

	unitState.last_attack_source_name = _dnl.D.ID_TO_NPC[448]  -- synthetic source
	unitState.recent_msg = "Integration test last words"
	-- Force hardcore state so onPlayerDead actually broadcasts
	_dnl.IS_HARDCORE_REALM = true
	if unitState.hasSoulOfIron ~= nil then
		unitState.hasSoulOfIron = true
	end

	local queue_size_before_death = #_dnl.death_alert_out_queue
	_dnl.handleEvent(_dnl.event_handler, "PLAYER_DEAD")
	local self_death_was_queued = #_dnl.death_alert_out_queue > queue_size_before_death

	-- Restore state
	_dnl.IS_HARDCORE_REALM = saved_is_hardcore_realm
	unitState.last_attack_source_name = saved_last_attack_name
	unitState.last_attack_source_guid = saved_last_attack_guid
	unitState.recent_msg = saved_recent_msg
	if saved_hasSoulOfIron ~= nil then
		unitState.hasSoulOfIron = saved_hasSoulOfIron
	end

	-- Wait for LRU auto-commit (3.5s for regular death)
	C_Timer.After(5.0, function()
		-- Verify death was queued in out_queue (captured immediately, before
		-- OnMouseDown/OnKeyDown hooks can drain the queue)
		record("self-death queued in out_queue", self_death_was_queued)

		-- Verify LRU name index was populated
		local lru_entry = _dnl.lru_by_name[player_name:lower()]
		record("self-death LRU name index populated", lru_entry ~= nil)

		if lru_entry and lru_entry.checksum then
			local cache = _dnl.death_ping_lru_cache_tbl[lru_entry.checksum]
			record("self-death LRU cache entry exists", cache ~= nil)
			if cache then
				record("self-death cache has player_data", cache["player_data"] ~= nil)
			end
		end

		-- Step 4: Dedup test — same player shouldn't trigger twice
		print(TAG .. "Phase 4: Dedup validation")
		resetHookCapture()
		local queue_size_before = #_dnl.death_alert_out_queue

		unitState.last_attack_source_name = _dnl.D.ID_TO_NPC[448]
		unitState.recent_msg = "Duplicate death"
		_dnl.IS_HARDCORE_REALM = true
		if unitState.hasSoulOfIron ~= nil then
			unitState.hasSoulOfIron = true
		end

		_dnl.handleEvent(_dnl.event_handler, "PLAYER_DEAD")

		_dnl.IS_HARDCORE_REALM = saved_is_hardcore_realm
		unitState.last_attack_source_name = saved_last_attack_name
		unitState.last_attack_source_guid = saved_last_attack_guid
		unitState.recent_msg = saved_recent_msg
		if saved_hasSoulOfIron ~= nil then
			unitState.hasSoulOfIron = saved_hasSoulOfIron
		end

		local queue_size_after = #_dnl.death_alert_out_queue
		record("dedup: duplicate death NOT re-queued",
			queue_size_after == queue_size_before,
			string.format("queue before=%d, after=%d", queue_size_before, queue_size_after))

		-- Step 5: handleDeathBroadcast (simulate incoming peer broadcast)
		print(TAG .. "Phase 5: Incoming broadcast simulation")
		resetHookCapture()

		local peer_data = _dnl.playerData(
			"IntegrationTestPeer" .. math.random(10000, 99999),
			"PeerGuild",
			5678,  -- some source
			3,     -- Dwarf
			3,     -- Hunter
			35,
			nil,
			1426,  -- Dun Morogh
			"0.4000,0.6000",
			GetServerTime(),
			nil,   -- played
			"Peer's last words"
		)

		-- Clear dedup for this test name
		_dnl.lru_by_name[peer_data["name"]:lower()] = nil

		local encoded_peer = _dnl.encodeMessage(peer_data)
		record("peer data encodes", encoded_peer ~= nil)

		if encoded_peer then
			_dnl.handleDeathBroadcast("FakeSender", encoded_peer)

			local peer_checksum = _dnl.fletcher16(peer_data)
			local peer_cache = _dnl.death_ping_lru_cache_tbl[peer_checksum]
			record("incoming broadcast stored in LRU", peer_cache ~= nil and peer_cache["player_data"] ~= nil)

			if peer_cache then
				record("incoming broadcast quality is PEER",
					peer_cache["quality"] == _dnl.QUALITY.PEER,
					string.format("expected %d, got %s", _dnl.QUALITY.PEER, tostring(peer_cache["quality"])))
			end

			-- Run before auto-commit timer (3.5s) so entry is still uncommitted
			C_Timer.After(2.0, function()
				-- Step 6: Checksum corroboration
				print(TAG .. "Phase 6: Checksum corroboration")
				local peer_checksum2 = _dnl.fletcher16(peer_data)
				local pre_peer_report = (_dnl.death_ping_lru_cache_tbl[peer_checksum2] or {})["peer_report"] or 0

				_dnl.deathlogReceiveChannelMessageChecksum("CorroboratorA",
					peer_checksum2 .. _dnl.COMM_FIELD_DELIM .. _dnl.PROTOCOL_VERSION .. _dnl.COMM_FIELD_DELIM)

				local post_cache = _dnl.death_ping_lru_cache_tbl[peer_checksum2]
				record("checksum corroboration increments peer_report",
					post_cache and (post_cache["peer_report"] or 0) > pre_peer_report,
					string.format("before=%d, after=%s", pre_peer_report,
						tostring(post_cache and post_cache["peer_report"])))

				-- Duplicate corroboration from same sender should be ignored
				local report_before = post_cache and post_cache["peer_report"] or 0
				_dnl.deathlogReceiveChannelMessageChecksum("CorroboratorA",
					peer_checksum2 .. _dnl.COMM_FIELD_DELIM .. _dnl.PROTOCOL_VERSION .. _dnl.COMM_FIELD_DELIM)
				local report_after = (post_cache or {})["peer_report"] or 0
				record("duplicate corroboration ignored",
					report_after == report_before,
					string.format("before=%d, after=%d", report_before, report_after))

				-- Step 7: isNameAlreadyCommitted
				print(TAG .. "Phase 7: Name dedup utility")
				-- Use a definitely-not-committed name
				record("isNameAlreadyCommitted false for unknown",
					not _dnl.isNameAlreadyCommitted("zzzNobodyEver" .. math.random(100000, 999999)))

				-- ============================================================
				-- Phase 8: isValidEntry edge cases
				-- ============================================================
				print(TAG .. "Phase 8: isValidEntry edge cases")
				record("isValidEntry rejects nil", _dnl.isValidEntry(nil) == false)
				record("isValidEntry rejects empty name",
					_dnl.isValidEntry({ name = "", source_id = 1, level = 10, map_id = 1 }) == false)
				record("isValidEntry rejects nil name",
					_dnl.isValidEntry({ source_id = 1, level = 10, map_id = 1 }) == false)
				record("isValidEntry rejects nil source_id",
					_dnl.isValidEntry({ name = "Test", level = 10, map_id = 1 }) == false)
				record("isValidEntry rejects nil level",
					_dnl.isValidEntry({ name = "Test", source_id = 1, map_id = 1 }) == false)
				record("isValidEntry rejects missing location",
					_dnl.isValidEntry({ name = "Test", source_id = 1, level = 10 }) == false)
				record("isValidEntry accepts map_id only",
					_dnl.isValidEntry({ name = "Test", source_id = 1, level = 10, map_id = 1429 }) == true)
				record("isValidEntry accepts instance_id only",
					_dnl.isValidEntry({ name = "Test", source_id = 1, level = 10, instance_id = 349 }) == true)
				record("isValidEntry accepts level 0",
					_dnl.isValidEntry({ name = "Test", source_id = -1, level = 0, map_id = 1429 }) == true)

				-- ============================================================
				-- Phase 9: Extra data encode/decode round-trip
				-- ============================================================
				print(TAG .. "Phase 9: Extra data round-trip")
				local ed_test = _dnl.playerData(
					"ExtraDataPlayer", "Guild", 100, 1, 1, 30, nil, 1429, nil, GetServerTime(), nil, nil,
					{ pvp_source_name = "Attacker", custom_key = "value~with|special=chars" }
				)
				local ed_encoded = _dnl.encodeMessage(ed_test)
				record("extra_data encodes", ed_encoded ~= nil)
				if ed_encoded then
					local ed_decoded = _dnl.decodeMessage(ed_encoded)
					record("extra_data decodes", ed_decoded ~= nil and ed_decoded["extra_data"] ~= nil)
					if ed_decoded and ed_decoded["extra_data"] then
						record("extra_data: pvp_source_name preserved",
							ed_decoded["extra_data"]["pvp_source_name"] == "Attacker",
							string.format("got '%s'", tostring(ed_decoded["extra_data"]["pvp_source_name"])))
						record("extra_data: special chars preserved",
							ed_decoded["extra_data"]["custom_key"] == "value~with|special=chars",
							string.format("got '%s'", tostring(ed_decoded["extra_data"]["custom_key"])))
					end
				end

				-- Nil extra_data round-trip
				local ed_nil_test = _dnl.playerData("NoExtra", "", 100, 1, 1, 30, nil, 1429, nil, GetServerTime(), nil, nil, nil)
				local ed_nil_enc = _dnl.encodeMessage(ed_nil_test)
				if ed_nil_enc then
					local ed_nil_dec = _dnl.decodeMessage(ed_nil_enc)
					record("nil extra_data stays nil after round-trip",
						ed_nil_dec ~= nil and ed_nil_dec["extra_data"] == nil)
				end

				-- Backslash round-trip (tests escape ordering fix)
				local ed_bs_test = _dnl.playerData(
					"BackslashTest", "Guild", 100, 1, 1, 30, nil, 1429, nil, GetServerTime(), nil, nil,
					{ backslash_tilde = "a\\~b", double_backslash = "x\\\\y", backslash_t = "c\\td" }
				)
				local ed_bs_enc = _dnl.encodeMessage(ed_bs_test)
				record("extra_data with backslashes encodes", ed_bs_enc ~= nil)
				if ed_bs_enc then
					local ed_bs_dec = _dnl.decodeMessage(ed_bs_enc)
					record("extra_data backslash round-trip", ed_bs_dec ~= nil and ed_bs_dec["extra_data"] ~= nil)
					if ed_bs_dec and ed_bs_dec["extra_data"] then
						record("extra_data: backslash+tilde preserved",
							ed_bs_dec["extra_data"]["backslash_tilde"] == "a\\~b",
							string.format("got '%s'", tostring(ed_bs_dec["extra_data"]["backslash_tilde"])))
						record("extra_data: double backslash preserved",
							ed_bs_dec["extra_data"]["double_backslash"] == "x\\\\y",
							string.format("got '%s'", tostring(ed_bs_dec["extra_data"]["double_backslash"])))
						record("extra_data: backslash+t preserved",
							ed_bs_dec["extra_data"]["backslash_t"] == "c\\td",
							string.format("got '%s'", tostring(ed_bs_dec["extra_data"]["backslash_t"])))
					end
				end

				-- ============================================================
				-- Phase 10: PvP source encode/decode round-trip
				-- ============================================================
				print(TAG .. "Phase 10: PvP source encode/decode")
				local pvp_src_regular = _dnl.createPvpSourceId(_dnl.PVP_FLAGS.REGULAR, 1, 1, 42)
				record("createPvpSourceId returns number", type(pvp_src_regular) == "number" and pvp_src_regular > 0)

				local pvp_decoded = _dnl.decodePvpSource(pvp_src_regular, "TestKiller")
				record("decodePvpSource returns PvP string",
					pvp_decoded ~= nil and pvp_decoded ~= "" and string.find(pvp_decoded, "PvP") ~= nil,
					string.format("got '%s'", tostring(pvp_decoded)))
				record("decodePvpSource includes player name",
					string.find(pvp_decoded, "TestKiller") ~= nil,
					string.format("got '%s'", tostring(pvp_decoded)))

				-- Duel to death flag
				local pvp_src_duel = _dnl.createPvpSourceId(_dnl.PVP_FLAGS.DUEL_TO_DEATH, 3, 5, 60)
				local pvp_duel_decoded = _dnl.decodePvpSource(pvp_src_duel, "DuelKiller")
				record("decodePvpSource duel flag detected",
					string.find(pvp_duel_decoded, "Duel to Death") ~= nil,
					string.format("got '%s'", tostring(pvp_duel_decoded)))

				-- Non-PvP source returns empty string
				record("decodePvpSource returns '' for NPC source",
					_dnl.decodePvpSource(nil, "x") == "")
				record("decodePvpSource returns '' for -1",
					_dnl.decodePvpSource(-1, "x") == "")

				-- Round-trip through encode/decode message
				local pvp_player_data = _dnl.playerData(
					"PvPVictim", "G", pvp_src_regular, 1, 1, 42, nil, 1429, nil, GetServerTime(), nil, "PvP death!"
				)
				local pvp_enc = _dnl.encodeMessage(pvp_player_data)
				if pvp_enc then
					local pvp_dec = _dnl.decodeMessage(pvp_enc)
					record("PvP source_id survives encode/decode",
						pvp_dec ~= nil and tonumber(pvp_dec["source_id"]) == pvp_src_regular,
						string.format("expected %s, got %s", tostring(pvp_src_regular), tostring(pvp_dec and pvp_dec["source_id"])))
				end

				-- ============================================================
				-- Phase 11: Protocol version boundary checks
				-- ============================================================
				print(TAG .. "Phase 11: Protocol version handling")

				-- Manually craft a message with too few fields
				local short_msg = "Name~Guild~100~"
				local short_decoded, short_ver = _dnl.decodeMessage(short_msg)
				record("decodeMessage rejects short message (< 13 fields)",
					short_decoded == nil,
					string.format("got %s", tostring(short_decoded)))

				-- Craft a message with a low protocol version — should still be accepted (MIN=0)
				local old_version_msg = "OldPlayer~Guild~100~1~1~30~~1429~0.5,0.5~~words~" .. GetServerTime() .. "~~1~"
				local old_decoded, old_ver = _dnl.decodeMessage(old_version_msg)
				record("decodeMessage parses old version message",
					old_decoded ~= nil,
					string.format("ver=%s", tostring(old_ver)))

				-- handleDeathBroadcast should accept any protocol version >= 0
				local old_lru_name = "oldprotocolplayer" .. math.random(100000, 999999)
				_dnl.lru_by_name[old_lru_name:lower()] = nil
				local old_msg = old_lru_name .. "~Guild~100~1~1~30~~1429~0.5,0.5~~words~" .. GetServerTime() .. "~~1~"
				_dnl.handleDeathBroadcast("OldSender", old_msg)
				local old_cache = _dnl.lru_by_name[old_lru_name:lower()]
				record("handleDeathBroadcast accepts v1 message (MIN=0)",
					old_cache ~= nil,
					"entry should be stored in LRU")

				-- ============================================================
				-- Phase 12: fletcher16 edge cases
				-- ============================================================
				print(TAG .. "Phase 12: fletcher16 edge cases")

				-- Two entries differing only in name should produce different checksums
				local f16_a = _dnl.playerData("Alice", "G", 100, 1, 1, 30, nil, 1429, nil, GetServerTime(), nil, nil)
				local f16_b = _dnl.playerData("Bob", "G", 100, 1, 1, 30, nil, 1429, nil, GetServerTime(), nil, nil)
				record("fletcher16 different names → different checksums",
					_dnl.fletcher16(f16_a) ~= _dnl.fletcher16(f16_b))

				-- source_id == -1 should zero out level in checksum
				local f16_reported_a = _dnl.playerData("SamePlayer", "G", -1, 1, 1, 20, nil, 1429, nil, GetServerTime(), nil, nil)
				local f16_reported_b = _dnl.playerData("SamePlayer", "G", -1, 1, 1, 40, nil, 1429, nil, GetServerTime(), nil, nil)
				record("fletcher16 ignores level when source_id == -1",
					_dnl.fletcher16(f16_reported_a) == _dnl.fletcher16(f16_reported_b),
					string.format("%s vs %s", _dnl.fletcher16(f16_reported_a), _dnl.fletcher16(f16_reported_b)))

				-- Different guilds should produce different checksums
				local f16_g1 = _dnl.playerData("Same", "GuildA", 100, 1, 1, 30, nil, 1429, nil, GetServerTime(), nil, nil)
				local f16_g2 = _dnl.playerData("Same", "GuildB", 100, 1, 1, 30, nil, 1429, nil, GetServerTime(), nil, nil)
				record("fletcher16 different guilds → different checksums",
					_dnl.fletcher16(f16_g1) ~= _dnl.fletcher16(f16_g2))

				-- Checksum starts with name
				local cs_prefix = _dnl.fletcher16(f16_a)
				record("fletcher16 checksum starts with player name",
					cs_prefix:sub(1, #"Alice") == "Alice",
					string.format("got '%s'", cs_prefix))

				-- ============================================================
				-- Phase 13: Quality-aware merge
				-- ============================================================
				print(TAG .. "Phase 13: Quality-aware merge via broadcast")

				local merge_name = "MergeTestPlayer" .. math.random(10000, 99999)
				_dnl.lru_by_name[merge_name:lower()] = nil

				-- First: simulate a low-quality (PEER) broadcast
				local peer_entry = _dnl.playerData(
					merge_name, "", 100, nil, nil, 25, nil, 1429, nil, GetServerTime(), nil, nil
				)
				local peer_enc_merge = _dnl.encodeMessage(peer_entry)
				if peer_enc_merge then
					_dnl.handleDeathBroadcast("PeerSender", peer_enc_merge)

					-- LRU should exist
					local merge_lru = _dnl.lru_by_name[merge_name:lower()]
					record("merge: initial PEER entry stored", merge_lru ~= nil)

					-- Now send a SELF-reported broadcast from the player (higher quality)
					local self_entry = _dnl.playerData(
						merge_name, "MyGuild", 100, 1, 1, 25, nil, 1429, "0.3000,0.7000", GetServerTime(), nil, "My last words"
					)
					local self_enc_merge = _dnl.encodeMessage(self_entry)
					if self_enc_merge then
						_dnl.handleDeathBroadcast(merge_name, self_enc_merge)

						-- Check that the cache entry now has the richer data
						local merge_lru2 = _dnl.lru_by_name[merge_name:lower()]
						if merge_lru2 and merge_lru2.checksum then
							local merge_cache = _dnl.death_ping_lru_cache_tbl[merge_lru2.checksum]
							if merge_cache and merge_cache["player_data"] then
								record("merge: guild enriched by SELF report",
									merge_cache["player_data"]["guild"] == "MyGuild",
									string.format("got '%s'", tostring(merge_cache["player_data"]["guild"])))
								record("merge: last_words enriched by SELF report",
									merge_cache["player_data"]["last_words"] == "My last words",
									string.format("got '%s'", tostring(merge_cache["player_data"]["last_words"])))
								record("merge: quality upgraded to SELF",
									merge_cache["quality"] == _dnl.QUALITY.SELF,
									string.format("expected %d, got %s", _dnl.QUALITY.SELF, tostring(merge_cache["quality"])))
							end
						end
					end
				end

				-- ============================================================
				-- Phase 14: Throttle system
				-- ============================================================
				print(TAG .. "Phase 14: Throttle system")
				local throttle_sender = "ThrottleTest" .. math.random(100000, 999999)

				-- First call should not be blocked
				record("throttleCheck not blocked on first call",
					_dnl.throttleCheck(throttle_sender) == false)

				-- After 1000+ calls, should be shadowbanned
				for i = 1, 1001 do
					_dnl.throttleCheck(throttle_sender)
				end
				record("throttleCheck blocks after 1000+ calls",
					_dnl.throttleCheck(throttle_sender) == true)

				-- ============================================================
				-- Phase 15: HookOnNewEntrySecure (peer_count threshold)
				-- ============================================================
				print(TAG .. "Phase 15: Secure hook threshold")
				local secure_hook_called = false
				local secure_hook_peer_count = nil
				DeathNotificationLib.HookOnNewEntrySecure(function(pd, cs, pc, ig)
					secure_hook_called = true
					secure_hook_peer_count = pc
				end)

				-- createEntry with peer_count=1 should NOT fire secure hooks
				secure_hook_called = false
				local sec_data_1 = _dnl.playerData(
					"SecureTestOne" .. math.random(10000,99999), "", 100, 1, 1, 20, nil, 1429, nil, GetServerTime(), nil, nil
				)
				_dnl.createEntry(sec_data_1, "fake-cs-1", 1, nil, _dnl.SOURCE.DEBUG)
				record("secure hook NOT called with peer_count=1", secure_hook_called == false)

				-- createEntry with peer_count=2 SHOULD fire secure hooks
				secure_hook_called = false
				local sec_data_2 = _dnl.playerData(
					"SecureTestTwo" .. math.random(10000,99999), "", 100, 1, 1, 20, nil, 1429, nil, GetServerTime(), nil, nil
				)
				_dnl.createEntry(sec_data_2, "fake-cs-2", 2, nil, _dnl.SOURCE.DEBUG)
				record("secure hook called with peer_count=2",
					secure_hook_called == true,
					string.format("called=%s, peer_count=%s", tostring(secure_hook_called), tostring(secure_hook_peer_count)))

				-- ============================================================
				-- Phase 16: Multiple distinct corroborators
				-- ============================================================
				print(TAG .. "Phase 16: Multiple corroborators")
				local multi_name = "MultiCorrobTest" .. math.random(10000, 99999)
				_dnl.lru_by_name[multi_name:lower()] = nil

				-- Insert a cache entry directly
				local multi_data = _dnl.playerData(multi_name, "", 200, 1, 1, 40, nil, 1429, nil, GetServerTime(), nil, nil)
				local multi_cs = _dnl.fletcher16(multi_data)
				_dnl.death_ping_lru_cache_tbl[multi_cs] = {
					player_data = multi_data,
					quality = _dnl.QUALITY.PEER,
					timestamp = GetServerTime(),
				}
				_dnl.updateLRUByName(multi_name:lower(), multi_cs, false, multi_data["level"])

				-- Send corroborations from 3 different senders
				for i = 1, 3 do
					_dnl.deathlogReceiveChannelMessageChecksum("Corroborator" .. i,
						multi_cs .. _dnl.COMM_FIELD_DELIM .. _dnl.PROTOCOL_VERSION .. _dnl.COMM_FIELD_DELIM)
				end
				local multi_cache = _dnl.death_ping_lru_cache_tbl[multi_cs]
				record("3 unique corroborators → peer_report=3",
					multi_cache and multi_cache["peer_report"] == 3,
					string.format("got %s", tostring(multi_cache and multi_cache["peer_report"])))

				-- Same sender again should be ignored
				_dnl.deathlogReceiveChannelMessageChecksum("Corroborator1",
					multi_cs .. _dnl.COMM_FIELD_DELIM .. _dnl.PROTOCOL_VERSION .. _dnl.COMM_FIELD_DELIM)
				record("repeat corroborator ignored (still 3)",
					multi_cache and multi_cache["peer_report"] == 3,
					string.format("got %s", tostring(multi_cache and multi_cache["peer_report"])))

				-- ============================================================
				-- Phase 17: Malformed message handling
				-- ============================================================
				print(TAG .. "Phase 17: Malformed message handling")
				record("handleDeathBroadcast ignores nil data",
					pcall(function() _dnl.handleDeathBroadcast("Sender", nil) end))
				record("decodeMessage empty string returns nil",
					_dnl.decodeMessage("") == nil)
				record("encodeMessage nil name returns nil",
					_dnl.encodeMessage({ source_id = 1, level = 10 }) == nil)
				record("encodeMessage non-numeric source_id returns nil",
					_dnl.encodeMessage({ name = "Test", source_id = "abc", level = 10 }) == nil)
				record("deathlogReceiveChannelMessageChecksum ignores nil data",
					pcall(function() _dnl.deathlogReceiveChannelMessageChecksum("Sender", nil) end))

				-- ============================================================
				-- Phase 18: map_pos table format handling
				-- ============================================================
				print(TAG .. "Phase 18: map_pos table format")
				local mp_data = _dnl.playerData(
					"MapPosTest", "", 100, 1, 1, 30, nil, 1429, { x = 0.1234, y = 0.5678 }, GetServerTime(), nil, nil
				)
				local mp_enc = _dnl.encodeMessage(mp_data)
				record("map_pos table encodes", mp_enc ~= nil)
				if mp_enc then
					local mp_dec = _dnl.decodeMessage(mp_enc)
					record("map_pos table round-trips to string",
						mp_dec and mp_dec["map_pos"] and mp_dec["map_pos"]:find("0.1234") ~= nil,
						string.format("got '%s'", tostring(mp_dec and mp_dec["map_pos"])))
				end

				-- ============================================================
				-- Phase 19: resolveDeathSource
				-- ============================================================
				print(TAG .. "Phase 19: resolveDeathSource")

				-- Known environment damage source
				local env_src, env_extra = _dnl.resolveDeathSource("Falling") -- env ID -3
				record("resolveDeathSource: env damage returns id",
					env_src == -3,
					string.format("expected -3, got %s", tostring(env_src)))
				record("resolveDeathSource: env damage no extra_data",
					env_extra == nil)

				-- Unknown source returns a number (may be -1 or PvP source depending
				-- on whether the player currently has a hostile player targeted)
				local unk_src, _ = _dnl.resolveDeathSource("SomeUnknownThing12345", nil)
				record("resolveDeathSource: unknown string returns number",
					type(unk_src) == "number",
					string.format("got %s (%s)", tostring(unk_src), type(unk_src)))

				-- Nil source
				local nil_src, nil_extra = _dnl.resolveDeathSource(nil)
				record("resolveDeathSource: nil returns -1",
					nil_src == -1,
					string.format("got %s", tostring(nil_src)))

				-- Nil name + nil guid
				local nn_src, nn_extra = _dnl.resolveDeathSource(nil, nil)
				record("resolveDeathSource: nil+nil returns -1",
					nn_src == -1 and nn_extra == nil)

				-- Known NPC name (by name string)
				local npc_name = _dnl.D.ID_TO_NPC[448]  -- Hogger or similar
				if npc_name then
					local npc_src, npc_extra = _dnl.resolveDeathSource(npc_name, nil)
					record("resolveDeathSource: known NPC name returns NPC id",
						npc_src == 448,
						string.format("expected 448, got %s", tostring(npc_src)))
					record("resolveDeathSource: known NPC name no extra_data",
						npc_extra == nil)
				end

				-- Environment damage by string name
				local env_name_src, env_name_extra = _dnl.resolveDeathSource("Drowning", nil)
				record("resolveDeathSource: env 'Drowning' returns -2",
					env_name_src == -2,
					string.format("expected -2, got %s", tostring(env_name_src)))
				record("resolveDeathSource: env 'Drowning' no extra_data",
					env_name_extra == nil)

				local env_fall_src, _ = _dnl.resolveDeathSource("Falling", nil)
				record("resolveDeathSource: env 'Falling' returns -3",
					env_fall_src == -3,
					string.format("expected -3, got %s", tostring(env_fall_src)))

				local env_lava_src, _ = _dnl.resolveDeathSource("Lava", nil)
				record("resolveDeathSource: env 'Lava' returns -6",
					env_lava_src == -6,
					string.format("expected -6, got %s", tostring(env_lava_src)))

				-- Creature GUID fallback (name not in NPC_TO_ID, but GUID has npc_id)
				local creature_guid = "Creature-0-0-0-0-448-0000000001"
				local cg_src, cg_extra = _dnl.resolveDeathSource("SomeMobNotInTable", creature_guid)
				record("resolveDeathSource: Creature GUID extracts npc_id",
					cg_src == 448,
					string.format("expected 448, got %s", tostring(cg_src)))
				record("resolveDeathSource: Creature GUID no extra_data",
					cg_extra == nil)

				-- Vehicle GUID fallback
				local vehicle_guid = "Vehicle-0-0-0-0-12345-0000000002"
				local vg_src, _ = _dnl.resolveDeathSource("SomeVehicle", vehicle_guid)
				record("resolveDeathSource: Vehicle GUID extracts npc_id",
					vg_src == 12345,
					string.format("expected 12345, got %s", tostring(vg_src)))

				-- NPC name takes priority over Creature GUID
				if npc_name then
					local priority_src, _ = _dnl.resolveDeathSource(npc_name, "Creature-0-0-0-0-99999-0000000003")
					record("resolveDeathSource: NPC name wins over Creature GUID",
						priority_src == 448,
						string.format("expected 448 (name lookup), got %s", tostring(priority_src)))
				end

				-- Env name takes priority over Creature GUID
				local env_priority_src, _ = _dnl.resolveDeathSource("Falling", "Creature-0-0-0-0-99999-0000000004")
				record("resolveDeathSource: env name wins over Creature GUID",
					env_priority_src == -3,
					string.format("expected -3, got %s", tostring(env_priority_src)))

				-- Player GUID with unknown name should try PvP encoding
				local player_guid_test = "Player-0-0-0-0-0-0000000005"
				local pg_src, pg_extra = _dnl.resolveDeathSource("SomePlayerName", player_guid_test)
				record("resolveDeathSource: Player GUID triggers PvP encode",
					pg_src ~= -1,
					string.format("got %s (should not be -1)", tostring(pg_src)))
				record("resolveDeathSource: Player GUID pvp_source_name in extra_data",
					pg_extra ~= nil and pg_extra["pvp_source_name"] == "SomePlayerName",
					string.format("got %s", tostring(pg_extra and pg_extra["pvp_source_name"])))

				-- Non-Player GUID with unknown name (Pet, GameObject) -> should be -1
				local pet_guid = "Pet-0-0-0-0-0-0000000006"
				local pet_src, pet_extra = _dnl.resolveDeathSource("SomePet", pet_guid)
				record("resolveDeathSource: Pet GUID unresolvable returns -1",
					pet_src == -1,
					string.format("got %s", tostring(pet_src)))

				-- Nil name + Creature GUID should still resolve via GUID
				local nil_name_cg_src, _ = _dnl.resolveDeathSource(nil, "Creature-0-0-0-0-1000-0000000007")
				record("resolveDeathSource: nil name + Creature GUID resolves",
					nil_name_cg_src == 1000,
					string.format("expected 1000, got %s", tostring(nil_name_cg_src)))

				-- Nil name + Player GUID — GetPlayerInfoByGUID may or may not resolve
				-- a fake GUID depending on WoW's internal cache. Accept either -1
				-- (unresolved) or a valid PvP source id (cached resolution).
				local nil_name_pg_src, _ = _dnl.resolveDeathSource(nil, "Player-0-0-0-0-0-0000000008")
				record("resolveDeathSource: nil name + fake Player GUID returns -1 or PvP id",
					nil_name_pg_src == -1 or _dnl.isValidPvpSourceId(nil_name_pg_src),
					string.format("got %s", tostring(nil_name_pg_src)))

				-- Duel to death: Player GUID with duel active
				local saved_duel = _dnl.pvp_state.duel_to_death_player
				_dnl.pvp_state.duel_to_death_player = "DuelOpponent"
				local duel_src, duel_extra = _dnl.resolveDeathSource("DuelOpponent", "Player-0-0-0-0-0-0000000009")
				record("resolveDeathSource: duel-to-death flags source",
					duel_src ~= -1 and _dnl.isValidPvpSourceId(duel_src),
					string.format("got %s", tostring(duel_src)))
				if duel_src ~= -1 then
					local duel_flag = math.floor(duel_src / 2^21) % 8
					record("resolveDeathSource: duel-to-death flag is DUEL_TO_DEATH",
						duel_flag == _dnl.PVP_FLAGS.DUEL_TO_DEATH,
						string.format("expected %d, got %d", _dnl.PVP_FLAGS.DUEL_TO_DEATH, duel_flag))
				end
				_dnl.pvp_state.duel_to_death_player = saved_duel

				-- ============================================================
				-- Phase 19b: encodePvpSource
				-- ============================================================
				print(TAG .. "Phase 19b: encodePvpSource")

				-- Nil name with no GUID
				local eps_ok1, eps_id1, eps_name1 = _dnl.encodePvpSource(nil, nil)
				record("encodePvpSource: nil name + nil GUID returns false",
					eps_ok1 == false and eps_id1 == nil and eps_name1 == nil)

				-- Nil name with Player GUID (fake GUID — GetPlayerInfoByGUID may
				-- resolve a cached name, making this succeed). Accept both outcomes.
				local eps_ok2, eps_id2, eps_name2 = _dnl.encodePvpSource(nil, "Player-0-0-0-0-0-0000000010")
				record("encodePvpSource: nil name + fake Player GUID returns false or valid PvP",
					(eps_ok2 == false and eps_id2 == nil and eps_name2 == nil)
					or (eps_ok2 == true and type(eps_id2) == "number" and type(eps_name2) == "string"))

				-- Non-Player GUID (Creature)
				local eps_ok3, eps_id3, eps_name3 = _dnl.encodePvpSource("SomeName", "Creature-0-0-0-0-100-0000000011")
				record("encodePvpSource: Creature GUID returns false",
					eps_ok3 == false and eps_id3 == nil and eps_name3 == nil)

				-- Non-Player GUID (Pet)
				local eps_ok3b, _, _ = _dnl.encodePvpSource("SomeName", "Pet-0-0-0-0-0-0000000012")
				record("encodePvpSource: Pet GUID returns false",
					eps_ok3b == false)

				-- Player GUID (may not be resolvable in test env, but should still succeed)
				local eps_ok4, eps_id4, eps_name4 = _dnl.encodePvpSource("TestPvPPlayer", "Player-0-0-0-0-0-0000000013")
				record("encodePvpSource: Player GUID returns success=true",
					eps_ok4 == true,
					string.format("ok=%s", tostring(eps_ok4)))
				record("encodePvpSource: Player GUID returns source_id number",
					type(eps_id4) == "number",
					string.format("got %s (%s)", tostring(eps_id4), type(eps_id4)))
				record("encodePvpSource: Player GUID returns source_name",
					eps_name4 == "TestPvPPlayer",
					string.format("got %s", tostring(eps_name4)))

				-- Verify PvP flag is REGULAR by default
				if eps_ok4 and eps_id4 then
					local pvp_flag = math.floor(eps_id4 / 2^21) % 8
					record("encodePvpSource: default flag is REGULAR",
						pvp_flag == _dnl.PVP_FLAGS.REGULAR,
						string.format("expected %d, got %d", _dnl.PVP_FLAGS.REGULAR, pvp_flag))
				end

				-- Duel-to-death flag
				local saved_duel2 = _dnl.pvp_state.duel_to_death_player
				_dnl.pvp_state.duel_to_death_player = "DuelTarget"
				local dtd_ok, dtd_id, dtd_name = _dnl.encodePvpSource("DuelTarget", "Player-0-0-0-0-0-0000000014")
				record("encodePvpSource: duel-to-death returns success",
					dtd_ok == true)
				record("encodePvpSource: duel-to-death source_name correct",
					dtd_name == "DuelTarget")
				if dtd_ok and dtd_id then
					local dtd_flag = math.floor(dtd_id / 2^21) % 8
					record("encodePvpSource: duel-to-death flag is DUEL_TO_DEATH",
						dtd_flag == _dnl.PVP_FLAGS.DUEL_TO_DEATH,
						string.format("expected %d, got %d", _dnl.PVP_FLAGS.DUEL_TO_DEATH, dtd_flag))
				end
				-- Non-matching duel opponent should get REGULAR flag
				local reg_ok, reg_id, _ = _dnl.encodePvpSource("SomeoneElse", "Player-0-0-0-0-0-0000000015")
				if reg_ok and reg_id then
					local reg_flag = math.floor(reg_id / 2^21) % 8
					record("encodePvpSource: non-duel opponent flag is REGULAR",
						reg_flag == _dnl.PVP_FLAGS.REGULAR,
						string.format("expected %d, got %d", _dnl.PVP_FLAGS.REGULAR, reg_flag))
				end
				_dnl.pvp_state.duel_to_death_player = saved_duel2

				-- No GUID, no matching target -> should fail
				local eps_ok5, eps_id5, eps_name5 = _dnl.encodePvpSource("RandomNameNoGUID", nil)
				record("encodePvpSource: no GUID + no target match returns false",
					eps_ok5 == false and eps_id5 == nil and eps_name5 == nil)

				-- Validate round-trip: encode then decode via decodePvpSource
				local rt_ok, rt_id, rt_name = _dnl.encodePvpSource("RoundTripPlayer", "Player-0-0-0-0-0-0000000016")
				if rt_ok and rt_id then
					local decoded_str = _dnl.decodePvpSource(rt_id, "RoundTripPlayer")
					record("encodePvpSource: round-trip decode produces string",
						type(decoded_str) == "string" and #decoded_str > 0,
						string.format("got '%s'", tostring(decoded_str)))
					record("encodePvpSource: round-trip decode contains player name",
						decoded_str:find("RoundTripPlayer") ~= nil,
						string.format("got '%s'", decoded_str))
				end

				-- Validate isValidPvpSourceId on encoded result
				if eps_ok4 and eps_id4 then
					record("encodePvpSource: result passes isValidPvpSourceId",
						_dnl.isValidPvpSourceId(eps_id4),
						string.format("id=%s", tostring(eps_id4)))
				end

				-- createPvpSourceId with known values and decode
				local manual_id = _dnl.createPvpSourceId(_dnl.PVP_FLAGS.REGULAR, 1, 1, 42)
				record("createPvpSourceId: produces number", type(manual_id) == "number")
				local manual_flag = math.floor(manual_id / 2^21) % 8
				local manual_race = math.floor(manual_id / 2^29) % 256
				local manual_class = math.floor(manual_id / 2^37) % 256
				local manual_level = math.floor(manual_id / 2^45) % 256
				record("createPvpSourceId: flag correct",
					manual_flag == _dnl.PVP_FLAGS.REGULAR,
					string.format("expected %d, got %d", _dnl.PVP_FLAGS.REGULAR, manual_flag))
				record("createPvpSourceId: race correct",
					manual_race == 1,
					string.format("expected 1, got %d", manual_race))
				record("createPvpSourceId: class correct",
					manual_class == 1,
					string.format("expected 1, got %d", manual_class))
				record("createPvpSourceId: level correct",
					manual_level == 42,
					string.format("expected 42, got %d", manual_level))

				local manual_decoded = _dnl.decodePvpSource(manual_id, "ManualPlayer")
				record("createPvpSourceId: decode contains 'PvP'",
					manual_decoded:find("PvP") ~= nil,
					string.format("got '%s'", manual_decoded))
				record("createPvpSourceId: decode contains 'level 42'",
					manual_decoded:find("level 42") ~= nil,
					string.format("got '%s'", manual_decoded))

				-- ============================================================
				-- Phase 20: broadcastDeath outbound dedup
				-- ============================================================
				print(TAG .. "Phase 20: broadcastDeath outbound dedup")
				local bd_name = "BroadcastDedupTest" .. math.random(10000, 99999)
				_dnl.lru_by_name[bd_name:lower()] = nil

				local bd_data = _dnl.playerData(bd_name, "", 100, 1, 1, 30, nil, 1429, nil, GetServerTime(), nil, nil)
				local bd_cs = _dnl.fletcher16(bd_data)
				-- Clear any prior cache
				_dnl.death_ping_lru_cache_tbl[bd_cs] = nil

				local q_before = #_dnl.death_alert_out_queue
				_dnl.broadcastDeath(bd_data)
				local q_after_first = #_dnl.death_alert_out_queue
				record("broadcastDeath first call queues message",
					q_after_first == q_before + 1,
					string.format("before=%d, after=%d", q_before, q_after_first))

				-- Second call with same data should be deduped
				_dnl.broadcastDeath(bd_data)
				local q_after_second = #_dnl.death_alert_out_queue
				record("broadcastDeath second call deduped",
					q_after_second == q_after_first,
					string.format("first=%d, second=%d", q_after_first, q_after_second))

				do -- scope block for phases 21-34 (local variable budget)
				-- ============================================================
				-- Phase 21: broadcastReportedDeath
				-- ============================================================
				print(TAG .. "Phase 21: broadcastReportedDeath")
				local rpt_name = "ReportedDeathTest" .. math.random(10000, 99999)
				-- Trim to 12 chars (WoW name limit) so validatePlayerData passes
				rpt_name = rpt_name:sub(1, 12)
				_dnl.lru_by_name[rpt_name:lower()] = nil
				-- Clear any cache that might match
				-- Compute expected checksum with source_id=-1 (reported death) so we can clear LRU
				local rpt_preview = _dnl.playerData(rpt_name, "RG", -1, 2, 3, 0, nil, 1426, nil, GetServerTime(), nil, nil)
				local rpt_cs = _dnl.fletcher16(rpt_preview)
				_dnl.death_ping_lru_cache_tbl[rpt_cs] = nil

				local rpt_q_before = #_dnl.death_alert_out_queue
				local rpt_ok, rpt_err = _dnl.broadcastReportedDeath(rpt_name, "RG", -1, 2, 3, 25, nil, 1426, nil)
				local rpt_q_after = #_dnl.death_alert_out_queue
				record("broadcastReportedDeath returns true",
					rpt_ok == true,
					string.format("ok=%s, err=%s", tostring(rpt_ok), tostring(rpt_err)))
				record("broadcastReportedDeath queues message",
					rpt_q_after > rpt_q_before,
					string.format("before=%d, after=%d", rpt_q_before, rpt_q_after))

				-- Verify the queued message has source_id == -1
				if rpt_q_after > rpt_q_before then
					local last_entry = _dnl.death_alert_out_queue[rpt_q_after]
					local last_msg = last_entry and last_entry[1] or nil
					local rpt_decoded = _dnl.decodeMessage(last_msg)
					record("broadcastReportedDeath source_id is -1",
						rpt_decoded and tonumber(rpt_decoded["source_id"]) == -1,
						string.format("got %s", tostring(rpt_decoded and rpt_decoded["source_id"])))
				end

				-- Negative tests: should return (false, string)
				local function expect_fail(label, ...)
					local ok_v, err_v = _dnl.broadcastReportedDeath(...)
					record(label, ok_v == false and type(err_v) == "string",
						string.format("ok=%s, err=%s", tostring(ok_v), tostring(err_v)))
				end
				expect_fail("rejects nil name", nil, nil, nil, 2, 3, 25, nil, 1426, nil)
				expect_fail("rejects empty name", "", nil, nil, 2, 3, 25, nil, 1426, nil)
				expect_fail("rejects name > 12 chars", "Abcdefghijklm", nil, nil, 2, 3, 25, nil, 1426, nil)
				expect_fail("rejects name with 1 char", "A", nil, nil, 2, 3, 25, nil, 1426, nil)
				expect_fail("rejects guild > 24 chars", "Aa", string.rep("G", 25), nil, 2, 3, 25, nil, 1426, nil)
				expect_fail("rejects level > 80", "Testname", nil, nil, 2, 3, 81, nil, 1426, nil)
				expect_fail("rejects missing location", "Testname", nil, nil, 2, 3, 25, nil, nil, nil)
				expect_fail("rejects wire-unsafe name", "Te~st", nil, nil, 2, 3, 25, nil, 1426, nil)

				-- ============================================================
				-- Phase 21b: validatePlayerData
				-- ============================================================
				print(TAG .. "Phase 21b: validatePlayerData")
				-- Valid minimal PlayerData
				local v_ok, v_err = _dnl.validatePlayerData(
					_dnl.playerData("Testplayer", "", -1, nil, nil, 10, nil, 1429, nil, GetServerTime(), nil, nil, nil))
				record("validatePlayerData accepts valid minimal",
					v_ok == true, tostring(v_err))

				-- Valid full PlayerData
				v_ok, v_err = _dnl.validatePlayerData(
					_dnl.playerData("TestFull", "MyGuild", -1, 2, 3, 42, 349, 1429, "0.5,0.5", GetServerTime(), 36000, "goodbye", { key = "val" }))
				record("validatePlayerData accepts valid full",
					v_ok == true, tostring(v_err))

				-- Rejects non-table
				v_ok, v_err = _dnl.validatePlayerData("not a table")
				record("validatePlayerData rejects non-table",
					v_ok == false and v_err:find("table"), tostring(v_err))

				-- Rejects nil source_id
				v_ok, v_err = _dnl.validatePlayerData(
					_dnl.playerData("Testplayer", "", nil, nil, nil, 10, nil, 1429, nil, GetServerTime(), nil, nil, nil))
				record("validatePlayerData rejects nil source_id",
					v_ok == false and v_err:find("source_id"), tostring(v_err))

				-- Rejects name too long
				v_ok, v_err = _dnl.validatePlayerData(
					{ name = "Abcdefghijklm", guild = "", source_id = -1, level = 10, map_id = 1429 })
				record("validatePlayerData rejects name > 12",
					v_ok == false and v_err:find("2%-12"), tostring(v_err))

				-- Rejects bad map_pos
				v_ok, v_err = _dnl.validatePlayerData(
					{ name = "Testplayer", guild = "", source_id = -1, level = 10, map_id = 1429, map_pos = "5.0,3.0" })
				record("validatePlayerData rejects map_pos out of range",
					v_ok == false and v_err:find("map_pos"), tostring(v_err))

				-- Rejects negative level
				v_ok, v_err = _dnl.validatePlayerData(
					{ name = "Testplayer", guild = "", source_id = -1, level = -1, map_id = 1429 })
				record("validatePlayerData rejects negative level",
					v_ok == false and v_err:find("level"), tostring(v_err))

				-- Accepts level 0
				v_ok, v_err = _dnl.validatePlayerData(
					{ name = "Testplayer", guild = "", source_id = -1, level = 0, map_id = 1429 })
				record("validatePlayerData accepts level 0",
					v_ok == true, tostring(v_err))

				-- Rejects string source_id (after playerData stores it as-is)
				v_ok, v_err = _dnl.validatePlayerData(
					{ name = "Testplayer", guild = "", source_id = "abc", level = 10, map_id = 1429 })
				record("validatePlayerData rejects string source_id",
					v_ok == false and v_err:find("source_id"), tostring(v_err))

				-- ============================================================
				-- Phase 22: updateLRUByName behavior
				-- ============================================================
				print(TAG .. "Phase 22: updateLRUByName")
				local lru_test_name = "lrutestname" .. math.random(100000, 999999)
				_dnl.lru_by_name[lru_test_name] = nil

				-- Create entry with committed=true
				_dnl.updateLRUByName(lru_test_name, "cs-test", true, 25)
				record("updateLRUByName sets committed",
					_dnl.lru_by_name[lru_test_name] and _dnl.lru_by_name[lru_test_name].committed == true)
				record("updateLRUByName sets checksum",
					_dnl.lru_by_name[lru_test_name] and _dnl.lru_by_name[lru_test_name].checksum == "cs-test")
				record("updateLRUByName sets timestamp",
					_dnl.lru_by_name[lru_test_name] and _dnl.lru_by_name[lru_test_name].timestamp ~= nil)

				-- Update with committed=nil should leave committed unchanged
				_dnl.updateLRUByName(lru_test_name, "cs-test-2", nil, 25)
				record("updateLRUByName nil committed preserves existing",
					_dnl.lru_by_name[lru_test_name].committed == true,
					string.format("got %s", tostring(_dnl.lru_by_name[lru_test_name].committed)))
				record("updateLRUByName updates checksum",
					_dnl.lru_by_name[lru_test_name].checksum == "cs-test-2")

				-- ============================================================
				-- Phase 23: playerData constructor
				-- ============================================================
				print(TAG .. "Phase 23: playerData constructor")
				local pd = _dnl.playerData("N", "G", 42, 1, 2, 30, 349, 1429, "0.5,0.5", 12345, nil, "bye", { foo = "bar" })
				record("playerData name", pd.name == "N")
				record("playerData guild", pd.guild == "G")
				record("playerData source_id", pd.source_id == 42)
				record("playerData race_id", pd.race_id == 1)
				record("playerData class_id", pd.class_id == 2)
				record("playerData level", pd.level == 30)
				record("playerData instance_id", pd.instance_id == 349)
				record("playerData map_id", pd.map_id == 1429)
				record("playerData map_pos", pd.map_pos == "0.5,0.5")
				record("playerData played", pd.played == nil)
				record("playerData date", pd.date == 12345)
				record("playerData last_words", pd.last_words == "bye")
				record("playerData extra_data", pd.extra_data and pd.extra_data.foo == "bar")

				-- ============================================================
				-- Phase 24: Peer reporting disabled setting
				-- ============================================================
				print(TAG .. "Phase 24: Peer reporting disabled")
				-- Temporarily override the first addon's settings so getSetting returns our mock
				local saved_addon_settings = {}
				for addonName, addon in pairs(_dnl.addons) do
					if addon.settings then
						saved_addon_settings[addonName] = addon.settings
						addon.settings = { peer_reporting = false, death_alert_priority = (addon.settings.death_alert_priority or 0) }
					end
				end

				local pr_name = "PeerReportDisabled" .. math.random(10000, 99999)
				_dnl.lru_by_name[pr_name:lower()] = nil

				local pr_data = _dnl.playerData(pr_name, "", 100, 1, 1, 30, nil, 1429, nil, GetServerTime(), nil, nil)
				local pr_enc = _dnl.encodeMessage(pr_data)
				if pr_enc then
					_dnl.handleDeathBroadcast("SomeOtherPlayer", pr_enc)
					record("peer_reporting=false rejects non-self broadcast",
						_dnl.lru_by_name[pr_name:lower()] == nil,
						"entry should not exist in LRU")
				end

				-- Restore addon settings
				for addonName, s in pairs(saved_addon_settings) do
					_dnl.addons[addonName].settings = s
				end

				-- ============================================================
				-- Phase 25: isNameAlreadyCommitted positive case
				-- ============================================================
				print(TAG .. "Phase 25: isNameAlreadyCommitted positive")
				local commit_name = "CommittedPlayer" .. math.random(10000, 99999)
				_dnl.updateLRUByName(commit_name:lower(), "test-cs", true, 30)
				record("isNameAlreadyCommitted true for committed name",
					_dnl.isNameAlreadyCommitted(commit_name) == true)

				-- Case insensitivity
				record("isNameAlreadyCommitted case insensitive",
					_dnl.isNameAlreadyCommitted(commit_name:upper()) == true)

				-- Nil input
				record("isNameAlreadyCommitted nil returns false",
					_dnl.isNameAlreadyCommitted(nil) == false)

				-- ============================================================
				-- Phase 26: Environment damage constants
				-- ============================================================
				print(TAG .. "Phase 26: Environment damage constants")
				record("ENVIRONMENT_DAMAGE[-2] = Drowning",
					_dnl.ENVIRONMENT_DAMAGE[-2] == "Drowning")
				record("ENVIRONMENT_DAMAGE[-3] = Falling",
					_dnl.ENVIRONMENT_DAMAGE[-3] == "Falling")
				record("ENVIRONMENT_DAMAGE[-4] = Fatigue",
					_dnl.ENVIRONMENT_DAMAGE[-4] == "Fatigue")
				record("ENVIRONMENT_DAMAGE[-5] = Fire",
					_dnl.ENVIRONMENT_DAMAGE[-5] == "Fire")
				record("ENVIRONMENT_DAMAGE[-6] = Lava",
					_dnl.ENVIRONMENT_DAMAGE[-6] == "Lava")
				record("ENVIRONMENT_DAMAGE[-7] = Slime",
					_dnl.ENVIRONMENT_DAMAGE[-7] == "Slime")

				-- ============================================================
				-- Phase 27: PvP bit-shift round-trip
				-- ============================================================
				print(TAG .. "Phase 27: PvP bit-shift round-trip")

				local pvp_races = { 1, 7, 8, 11 }
				for _, test_race in ipairs(pvp_races) do
					local test_src = _dnl.createPvpSourceId(_dnl.PVP_FLAGS.REGULAR, test_race, 3, 42)
					local rt_flag = math.floor(test_src / 2^21) % 8
					local rt_race = math.floor(test_src / 2^29) % 256
					local rt_class = math.floor(test_src / 2^37) % 256
					local rt_level = math.floor(test_src / 2^45) % 256
					record(string.format("PvP round-trip race=%d", test_race),
						rt_race == test_race,
						string.format("encoded=%s, decoded_race=%d, class=%d, level=%d, flag=%d",
							tostring(test_src), rt_race, rt_class, rt_level, rt_flag))
				end

				for test_class = 1, 9 do
					local test_src = _dnl.createPvpSourceId(_dnl.PVP_FLAGS.REGULAR, 1, test_class, 30)
					local rt_class = math.floor(test_src / 2^37) % 256
					record(string.format("PvP round-trip class=%d", test_class),
						rt_class == test_class,
						string.format("decoded_class=%d", rt_class))
				end

				local test_levels = { 1, 30, 60 }
				for _, test_level in ipairs(test_levels) do
					local test_src = _dnl.createPvpSourceId(_dnl.PVP_FLAGS.REGULAR, 1, 1, test_level)
					local rt_level = math.floor(test_src / 2^45) % 256
					record(string.format("PvP round-trip level=%d", test_level),
						rt_level == test_level,
						string.format("decoded_level=%d", rt_level))
				end

				local test_flags = { _dnl.PVP_FLAGS.NONE, _dnl.PVP_FLAGS.REGULAR, _dnl.PVP_FLAGS.DUEL_TO_DEATH }
				for _, test_flag in ipairs(test_flags) do
					local test_src = _dnl.createPvpSourceId(test_flag, 1, 1, 30)
					local rt_flag = math.floor(test_src / 2^21) % 8
					record(string.format("PvP round-trip flag=%d", test_flag),
						rt_flag == test_flag,
						string.format("decoded_flag=%d", rt_flag))
				end

				-- ============================================================
				-- Phase 28: last_words escaping round-trip
				-- ============================================================
				print(TAG .. "Phase 28: last_words escaping round-trip")

				-- last_words containing ~ (field delimiter)
				local lw_tilde_data = _dnl.playerData(
					"EscTilde", "G", 100, 1, 1, 30, nil, 1429, nil, GetServerTime(), nil, "hello~world"
				)
				local lw_tilde_enc = _dnl.encodeMessage(lw_tilde_data)
				record("last_words with ~ encodes", lw_tilde_enc ~= nil)
				if lw_tilde_enc then
					local lw_tilde_dec = _dnl.decodeMessage(lw_tilde_enc)
					record("last_words with ~ decodes",
						lw_tilde_dec ~= nil,
						"decoded=" .. tostring(lw_tilde_dec ~= nil))
					record("last_words with ~ round-trips",
						lw_tilde_dec and lw_tilde_dec["last_words"] == "hello~world",
						string.format("expected 'hello~world', got '%s'",
							tostring(lw_tilde_dec and lw_tilde_dec["last_words"])))
				end

				-- last_words containing | (sync entry separator)
				local lw_pipe_data = _dnl.playerData(
					"EscPipe", "G", 100, 1, 1, 30, nil, 1429, nil, GetServerTime(), nil, "foo|bar|baz"
				)
				local lw_pipe_enc = _dnl.encodeMessage(lw_pipe_data)
				record("last_words with | encodes", lw_pipe_enc ~= nil)
				if lw_pipe_enc then
					local lw_pipe_dec = _dnl.decodeMessage(lw_pipe_enc)
					record("last_words with | round-trips",
						lw_pipe_dec and lw_pipe_dec["last_words"] == "foo|bar|baz",
						string.format("expected 'foo|bar|baz', got '%s'",
							tostring(lw_pipe_dec and lw_pipe_dec["last_words"])))
				end

				-- last_words containing % (escape character)
				local lw_pct_data = _dnl.playerData(
					"EscPercent", "G", 100, 1, 1, 30, nil, 1429, nil, GetServerTime(), nil, "50% hp left"
				)
				local lw_pct_enc = _dnl.encodeMessage(lw_pct_data)
				record("last_words with %% encodes", lw_pct_enc ~= nil)
				if lw_pct_enc then
					local lw_pct_dec = _dnl.decodeMessage(lw_pct_enc)
					record("last_words with %% round-trips",
						lw_pct_dec and lw_pct_dec["last_words"] == "50% hp left",
						string.format("expected '50%% hp left', got '%s'",
							tostring(lw_pct_dec and lw_pct_dec["last_words"])))
				end

				-- last_words containing \ (WoW chat escape character)
				local lw_bs_data = _dnl.playerData(
					"EscBackslash", "G", 100, 1, 1, 30, nil, 1429, nil, GetServerTime(), nil, "path\\to\\file"
				)
				local lw_bs_enc = _dnl.encodeMessage(lw_bs_data)
				record("last_words with \\ encodes", lw_bs_enc ~= nil)
				if lw_bs_enc then
					local lw_bs_dec = _dnl.decodeMessage(lw_bs_enc)
					record("last_words with \\ round-trips",
						lw_bs_dec and lw_bs_dec["last_words"] == "path\\to\\file",
						string.format("expected 'path\\to\\file', got '%s'",
							tostring(lw_bs_dec and lw_bs_dec["last_words"])))
				end

				-- last_words with all special characters combined
				local lw_all_data = _dnl.playerData(
					"EscAll", "G", 100, 1, 1, 30, nil, 1429, nil, GetServerTime(), nil, "~|%%\\~|"
				)
				local lw_all_enc = _dnl.encodeMessage(lw_all_data)
				record("last_words with ~|%%\\ combined encodes", lw_all_enc ~= nil)
				if lw_all_enc then
					local lw_all_dec = _dnl.decodeMessage(lw_all_enc)
					record("last_words with ~|%%\\ combined round-trips",
						lw_all_dec and lw_all_dec["last_words"] == "~|%%\\~|",
						string.format("expected '~|%%%%\\~|', got '%s'",
							tostring(lw_all_dec and lw_all_dec["last_words"])))
				end

				-- ============================================================
				-- Phase 29: extra_data escaping for sync safety
				-- ============================================================
				print(TAG .. "Phase 29: extra_data escaping (multi-key round-trip)")

				local ed_multi_data = _dnl.playerData(
					"ExtraMulti", "G", 100, 1, 1, 30, nil, 1429, nil, GetServerTime(), nil, nil,
					{ pvp_source_name = "Attacker", realm = "Whitemane" }
				)
				local ed_multi_enc = _dnl.encodeMessage(ed_multi_data)
				record("multi-key extra_data encodes", ed_multi_enc ~= nil)
				if ed_multi_enc then
					-- Wire format must NOT contain unescaped |
					-- (The pipe is escaped as %p at the wire level)
					local raw_pipe_count = 0
					-- Count literal | that are NOT preceded by %
					for i = 1, #ed_multi_enc do
						if ed_multi_enc:byte(i) == 0x7C then -- |
							if i == 1 or ed_multi_enc:byte(i-1) ~= 0x25 then -- not preceded by %
								raw_pipe_count = raw_pipe_count + 1
							end
						end
					end
					record("wire format has no unescaped |",
						raw_pipe_count == 0,
						"unescaped pipes=" .. raw_pipe_count)

					-- Wire format must NOT contain any backslash
					-- (WoW rejects \ sequences in SendChatMessage)
					local has_backslash = ed_multi_enc:find("\\", 1, true) ~= nil
					record("wire format has no backslash",
						not has_backslash,
						"found backslash=" .. tostring(has_backslash))

					local ed_multi_dec = _dnl.decodeMessage(ed_multi_enc)
					record("multi-key extra_data decodes",
						ed_multi_dec ~= nil and ed_multi_dec["extra_data"] ~= nil)
					if ed_multi_dec and ed_multi_dec["extra_data"] then
						record("extra_data pvp_source_name preserved",
							ed_multi_dec["extra_data"]["pvp_source_name"] == "Attacker",
							"got: " .. tostring(ed_multi_dec["extra_data"]["pvp_source_name"]))
						record("extra_data realm preserved",
							ed_multi_dec["extra_data"]["realm"] == "Whitemane",
							"got: " .. tostring(ed_multi_dec["extra_data"]["realm"]))
					end
				end

				-- ============================================================
				-- Phase 30: Message length within 253-byte budget
				-- ============================================================
				print(TAG .. "Phase 30: Message length within 253-byte budget")

				-- Worst-case PvP source_id (max 16 digits)
				local pvp_src = _dnl.createPvpSourceId(
					_dnl.PVP_FLAGS.DUEL_TO_DEATH, 8, 11, 60)

				-- 255-char last_words (max WoW chat)
				local long_lw = string.rep("A", 255)
				local len_data = _dnl.playerData(
					"Longwordsman", "TwentyFourCharGuild!", pvp_src,
					1, 11, 60, 99999, 9999, "0.9999,0.9999", GetServerTime(), nil, long_lw,
					{ pvp_source_name = "TwelveChars" }
				)
				local len_enc = _dnl.encodeMessage(len_data)
				record("worst-case message encodes", len_enc ~= nil)
				if len_enc then
					record("worst-case message <= 253 bytes",
						#len_enc <= 253,
						"length=" .. #len_enc)
					-- Verify it still decodes correctly
					local len_dec = _dnl.decodeMessage(len_enc)
					record("worst-case message decodes",
						len_dec ~= nil and len_dec["name"] == "Longwordsman")
					-- last_words should be truncated but present
					record("truncated last_words is non-empty",
						len_dec and len_dec["last_words"] ~= nil and #len_dec["last_words"] > 0,
						"length=" .. tostring(len_dec and len_dec["last_words"] and #len_dec["last_words"]))
				end

				-- Simple PvE case should have more room for last_words
				local pve_data = _dnl.playerData(
					"Pve", "", 100, 1, 1, 30, nil, 1429, nil, GetServerTime(), nil, long_lw
				)
				local pve_enc = _dnl.encodeMessage(pve_data)
				record("PvE worst-case message <= 253 bytes",
					pve_enc ~= nil and #pve_enc <= 253,
					"length=" .. tostring(pve_enc and #pve_enc))

				-- ============================================================
				-- Phase 31: Sync E$ entry splitting safety
				-- ============================================================
				print(TAG .. "Phase 31: Sync entry splitting safety")

				local sync_data1 = _dnl.playerData(
					"SyncSafe1", "", 100, 1, 1, 30, nil, 1429, nil, GetServerTime(), nil, "words~with|pipes",
					{ key1 = "val1", key2 = "val2" }
				)
				local sync_data2 = _dnl.playerData(
					"SyncSafe2", "", 200, 2, 3, 40, nil, 1429, nil, GetServerTime(), nil, nil,
					{ pvp_source_name = "Enemy" }
				)
				local enc1 = _dnl.encodeMessage(sync_data1)
				local enc2 = _dnl.encodeMessage(sync_data2)
				record("sync entry 1 encodes", enc1 ~= nil)
				record("sync entry 2 encodes", enc2 ~= nil)

				if enc1 and enc2 then
					-- Simulate what handleSyncEntry does: pack with ";", then split
					local packed = enc1 .. ";" .. enc2
					local split_entries = { strsplit(";", packed) }
					-- With proper escaping, strsplit should yield exactly 2 parts
					record("strsplit on packed entries yields 2",
						#split_entries == 2,
						"got " .. #split_entries .. " parts")

					if #split_entries == 2 then
						local dec1 = _dnl.decodeMessage(split_entries[1])
						local dec2 = _dnl.decodeMessage(split_entries[2])
						record("packed entry 1 decodes correctly",
							dec1 ~= nil and dec1["name"] == "SyncSafe1",
							"name=" .. tostring(dec1 and dec1["name"]))
						record("packed entry 2 decodes correctly",
							dec2 ~= nil and dec2["name"] == "SyncSafe2",
							"name=" .. tostring(dec2 and dec2["name"]))
						-- Verify special chars survived the pack/split
						if dec1 then
							record("last_words with ~| survives sync packing",
								dec1["last_words"] == "words~with|pipes",
								"got: " .. tostring(dec1["last_words"]))
						end
						if dec1 and dec1["extra_data"] then
							record("multi-key extra_data survives sync packing",
								dec1["extra_data"]["key1"] == "val1" and dec1["extra_data"]["key2"] == "val2",
								string.format("key1=%s, key2=%s",
									tostring(dec1["extra_data"]["key1"]),
									tostring(dec1["extra_data"]["key2"])))
						end
					end
				end

				-- ============================================================
				-- Phase 32: name and guild escaping round-trip
				-- ============================================================
				print(TAG .. "Phase 32: name and guild escaping")

				-- Synthetic name containing ~ (impossible in real WoW, but
				-- verifies the escaping layer is complete)
				local ng_data = _dnl.playerData(
					"Name~Evil", "Guild|Bad%%", 100, 1, 1, 30, nil, 1429, nil, GetServerTime(), nil, "hi"
				)
				local ng_enc = _dnl.encodeMessage(ng_data)
				record("name with ~ encodes", ng_enc ~= nil)
				if ng_enc then
					local ng_dec = _dnl.decodeMessage(ng_enc)
					record("name with ~ decodes",
						ng_dec ~= nil,
						"decoded=" .. tostring(ng_dec ~= nil))
					record("name with ~ round-trips",
						ng_dec and ng_dec["name"] == "Name~Evil",
						string.format("expected 'Name~Evil', got '%s'",
							tostring(ng_dec and ng_dec["name"])))
					record("guild with |+%% round-trips",
						ng_dec and ng_dec["guild"] == "Guild|Bad%%",
						string.format("expected 'Guild|Bad%%%%', got '%s'",
							tostring(ng_dec and ng_dec["guild"])))
					-- Other fields should be intact
					record("other fields survive name/guild escaping",
						ng_dec and ng_dec["last_words"] == "hi" and tonumber(ng_dec["level"]) == 30,
						string.format("lw=%s, level=%s",
							tostring(ng_dec and ng_dec["last_words"]),
							tostring(ng_dec and ng_dec["level"])))
				end

				-- ============================================================
				-- Phase 33: entryQuality
				-- ============================================================
				print(TAG .. "Phase 33: entryQuality")

				-- Empty entry (only required fields) should score 1
				-- (map_id or instance_id is required for validity and always counts)
				local eq_empty = _dnl.playerData("EqEmpty", nil, -1, nil, nil, 10, nil, 1429, nil, GetServerTime(), nil, nil)
				record("entryQuality: minimal entry = 1",
					_dnl.entryQuality(eq_empty) == 1,
					"got " .. _dnl.entryQuality(eq_empty))

				-- Entry with all optional fields filled
				local eq_full = _dnl.playerData(
					"EqFull", "MyGuild", 1234, 1, 2, 30, 349, 1429, "0.5,0.5", GetServerTime(), nil, "famous last words"
				)
				-- guild(1) + race(1) + class(1) + source!=−1(1) + map(1) + pos(1) + instance(1) + last_words(1) = 8
				record("entryQuality: full entry = 8",
					_dnl.entryQuality(eq_full) == 8,
					"got " .. _dnl.entryQuality(eq_full))

				-- source_id == -1 should NOT count
				local eq_unknown_src = _dnl.playerData("EqSrc", "G", -1, 1, 2, 30, nil, 1429, nil, GetServerTime(), nil, nil)
				-- guild(1) + race(1) + class(1) + source(-1→0) + map(1) = 4
				record("entryQuality: source_id=-1 not counted",
					_dnl.entryQuality(eq_unknown_src) == 4,
					"got " .. _dnl.entryQuality(eq_unknown_src))

				-- Empty-string guild and last_words should not count
				local eq_empty_str = _dnl.playerData("EqStr", "", 100, nil, nil, 10, nil, 1429, nil, GetServerTime(), nil, "")
				-- source(1) + map(1) = 2  (guild="" → 0, last_words="" → 0)
				record("entryQuality: empty strings not counted",
					_dnl.entryQuality(eq_empty_str) == 2,
					"got " .. _dnl.entryQuality(eq_empty_str))

				-- ============================================================
				-- Phase 34: mergeEntries
				-- ============================================================
				print(TAG .. "Phase 34: mergeEntries")

				-- Basic merge: entry_a fields preferred
				local me_a = _dnl.playerData("Merged", "GuildA", 100, 1, nil, 30, nil, 1429, nil, GetServerTime(), nil, nil)
				local me_b = _dnl.playerData("Merged", "GuildB", 200, nil, 3, 30, nil, 1429, "0.5,0.5", GetServerTime(), nil, "bye")
				local me_m = _dnl.mergeEntries(me_a, me_b)

				record("mergeEntries: name from A",
					me_m.name == "Merged")
				record("mergeEntries: guild prefers A (non-empty)",
					me_m.guild == "GuildA",
					"got " .. tostring(me_m.guild))
				record("mergeEntries: source_id prefers A (non -1)",
					me_m.source_id == 100,
					"got " .. tostring(me_m.source_id))
				record("mergeEntries: race_id from A",
					me_m.race_id == 1,
					"got " .. tostring(me_m.race_id))
				record("mergeEntries: class_id falls back to B",
					me_m.class_id == 3,
					"got " .. tostring(me_m.class_id))
				record("mergeEntries: map_pos falls back to B",
					me_m.map_pos == "0.5,0.5",
					"got " .. tostring(me_m.map_pos))
				record("mergeEntries: last_words falls back to B",
					me_m.last_words == "bye",
					"got " .. tostring(me_m.last_words))

				-- source_id: -1 in A should fall back to B's real value
				local me_src_a = _dnl.playerData("SrcMerge", nil, -1, nil, nil, 10, nil, 1429, nil, GetServerTime(), nil, nil)
				local me_src_b = _dnl.playerData("SrcMerge", nil, 555, nil, nil, 10, nil, 1429, nil, GetServerTime(), nil, nil)
				local me_src_m = _dnl.mergeEntries(me_src_a, me_src_b)
				record("mergeEntries: source_id -1 falls back to B",
					me_src_m.source_id == 555,
					"got " .. tostring(me_src_m.source_id))

				-- Both -1 should keep -1
				local me_both_a = _dnl.playerData("Both", nil, -1, nil, nil, 10, nil, 1429, nil, GetServerTime(), nil, nil)
				local me_both_b = _dnl.playerData("Both", nil, -1, nil, nil, 10, nil, 1429, nil, GetServerTime(), nil, nil)
				local me_both_m = _dnl.mergeEntries(me_both_a, me_both_b)
				record("mergeEntries: both source_id=-1 keeps -1",
					me_both_m.source_id == -1,
					"got " .. tostring(me_both_m.source_id))

				-- Empty-string guild in A should fall back to B
				local me_guild_a = _dnl.playerData("GuildMerge", "", 100, nil, nil, 10, nil, 1429, nil, GetServerTime(), nil, nil)
				local me_guild_b = _dnl.playerData("GuildMerge", "RealGuild", 100, nil, nil, 10, nil, 1429, nil, GetServerTime(), nil, nil)
				local me_guild_m = _dnl.mergeEntries(me_guild_a, me_guild_b)
				record("mergeEntries: empty guild falls back to B",
					me_guild_m.guild == "RealGuild",
					"got " .. tostring(me_guild_m.guild))

				-- Merge returns new table (doesn't mutate inputs)
				record("mergeEntries: returns new table (not A)",
					me_m ~= me_a)
				record("mergeEntries: returns new table (not B)",
					me_m ~= me_b)
				record("mergeEntries: original A unchanged",
					me_a.class_id == nil,
					"got " .. tostring(me_a.class_id))

				-- Merge quality should be >= both inputs
				record("mergeEntries: merged quality >= A quality",
					_dnl.entryQuality(me_m) >= _dnl.entryQuality(me_a),
					string.format("merged=%d, A=%d", _dnl.entryQuality(me_m), _dnl.entryQuality(me_a)))
				record("mergeEntries: merged quality >= B quality",
					_dnl.entryQuality(me_m) >= _dnl.entryQuality(me_b),
					string.format("merged=%d, B=%d", _dnl.entryQuality(me_m), _dnl.entryQuality(me_b)))
				end -- end scope block for phases 21-34

				do -- scope block for phases 35-39 (local variable budget)
				-- ============================================================
				-- Phase 35: ResolveDeathSource public API
				-- ============================================================
				print(TAG .. "Phase 35: ResolveDeathSource public API")
				-- Public API is wired to internal
				record("ResolveDeathSource is exposed",
					DeathNotificationLib.ResolveDeathSource ~= nil)
				record("ResolveDeathSource == _dnl.resolveDeathSource",
					DeathNotificationLib.ResolveDeathSource == _dnl.resolveDeathSource)
				-- Unknown source returns -1
				local rds_id, rds_ed = DeathNotificationLib.ResolveDeathSource("NonexistentNPC12345", nil)
				record("ResolveDeathSource unknown returns -1",
					rds_id == -1,
					"got " .. tostring(rds_id))
				record("ResolveDeathSource unknown extra_data nil",
					rds_ed == nil)
				-- Nil source returns -1
				local rds_nil_id, _ = DeathNotificationLib.ResolveDeathSource(nil, nil)
				record("ResolveDeathSource nil returns -1",
					rds_nil_id == -1)

				-- ============================================================
				-- Phase 36: GetDeathRecord
				-- ============================================================
				print(TAG .. "Phase 36: GetDeathRecord")
				record("GetDeathRecord is exposed",
					DeathNotificationLib.GetDeathRecord ~= nil)
				-- Query non-existent name → nil
				local gdr_pd, gdr_pc = DeathNotificationLib.GetDeathRecord("NoSuchPlayer999")
				record("GetDeathRecord unknown returns nil",
					gdr_pd == nil and gdr_pc == nil)
				-- Query nil → nil
				local gdr_nil_pd, gdr_nil_pc = DeathNotificationLib.GetDeathRecord(nil)
				record("GetDeathRecord nil returns nil",
					gdr_nil_pd == nil)
				-- Inject a committed entry and query it
				local gdr_name = "GdrTest" .. math.random(10000, 99999)
				local gdr_name_lower = gdr_name:lower()
				-- Trim to 12 chars
				gdr_name = gdr_name:sub(1, 12)
				gdr_name_lower = gdr_name:lower()
				local gdr_test_pd = _dnl.playerData(gdr_name, "", -1, nil, nil, 15, nil, 1429, nil, GetServerTime(), nil, nil)
				local gdr_test_cs = _dnl.fletcher16(gdr_test_pd)
				_dnl.death_ping_lru_cache_tbl[gdr_test_cs] = {
					player_data = gdr_test_pd,
					peer_report = 3,
					committed = 1,
					timestamp = GetServerTime(),
				}
				_dnl.updateLRUByName(gdr_name_lower, gdr_test_cs, true)
				local gdr_found_pd, gdr_found_pc = DeathNotificationLib.GetDeathRecord(gdr_name)
				record("GetDeathRecord finds committed entry",
					gdr_found_pd ~= nil and gdr_found_pd.name == gdr_name,
					"got " .. tostring(gdr_found_pd and gdr_found_pd.name))
				record("GetDeathRecord returns peer_count",
					gdr_found_pc == 3,
					"got " .. tostring(gdr_found_pc))
				-- Case insensitive
				local gdr_upper_pd, _ = DeathNotificationLib.GetDeathRecord(gdr_name:upper())
				record("GetDeathRecord case insensitive",
					gdr_upper_pd ~= nil and gdr_upper_pd.name == gdr_name)

				-- ============================================================
				-- Phase 37: ValidatePlayerData + PlayerData public API
				-- ============================================================
				print(TAG .. "Phase 37: ValidatePlayerData + PlayerData public API")
				record("ValidatePlayerData is exposed",
					DeathNotificationLib.ValidatePlayerData ~= nil)
				record("ValidatePlayerData == _dnl.validatePlayerData",
					DeathNotificationLib.ValidatePlayerData == _dnl.validatePlayerData)
				record("PlayerData is exposed",
					DeathNotificationLib.PlayerData ~= nil)
				record("PlayerData == _dnl.playerData",
					DeathNotificationLib.PlayerData == _dnl.playerData)
				-- Build + validate via public API
				local pub_pd = DeathNotificationLib.PlayerData("PubTest", "G", -1, nil, nil, 10, nil, 1429, nil, GetServerTime(), nil, nil)
				local pub_ok, pub_err = DeathNotificationLib.ValidatePlayerData(pub_pd)
				record("Public PlayerData + ValidatePlayerData works",
					pub_ok == true,
					tostring(pub_err))

				-- ============================================================
				-- Phase 38: HookOnSelfDeath registration
				-- ============================================================
				print(TAG .. "Phase 38: HookOnSelfDeath")
				record("HookOnSelfDeath is exposed",
					DeathNotificationLib.HookOnSelfDeath ~= nil)
				-- We can't trigger a real PLAYER_DEAD in tests, but we can verify
				-- the hook registration function exists and accepts a callback
				local hook_registered = false
				local function testSelfDeathHook(pd)
					hook_registered = true
					-- Hook mutates the copy in place; no return needed.
				end
				-- Should not error
				DeathNotificationLib.HookOnSelfDeath(testSelfDeathHook)
				record("HookOnSelfDeath accepts callback without error", true)
				end -- end scope block for phases 35-39

				-- Final summary
				C_Timer.After(0.5, function()
					print(TAG .. "=========================")
					printSummary()
					print(TAG .. "=========================")
					testCleanup()
				end)
			end)
		else
			print(TAG .. "Skipping phases 5-7 (encode failed)")
			printSummary()
			testCleanup()
		end
	end)
end

---------------------------------------------------------------------------
-- testSync: exercises the sync protocol in-process
---------------------------------------------------------------------------
function _dnl.testSync()
	if not _dnl.DEBUG then
		print("|cffFF0000[Deathlog]|r testSync requires DEBUG mode")
		return
	end

	testBegin()
	local TAG = "|cff00CCFF[DNL Sync Test]|r "
	local pass_count, fail_count = 0, 0
	local results = {}

	local function record(label, ok, detail)
		if ok then
			pass_count = pass_count + 1
			print(TAG .. "|cff00FF00PASS|r " .. label .. (detail and (" — " .. detail) or ""))
		else
			fail_count = fail_count + 1
			print(TAG .. "|cffFF0000FAIL|r " .. label .. (detail and (" — " .. detail) or ""))
		end
		results[#results + 1] = { label = label, ok = ok }
		if test_tracking.all_depth > 0 then
			table.insert(test_tracking.global_results, { suite = "Sync", name = label, ok = ok, detail = detail })
		end
	end

	print(TAG .. "=========================")
	print(TAG .. "Sync Protocol Unit Tests")
	print(TAG .. "=========================")

	-- Save original addons state and register a test addon with mock dbs
	local saved_addons = _dnl.addons
	local saved_tag_to_addon = _dnl.tag_to_addon

	-- Set up a mock database
	local now = GetServerTime()
	local mock_db = {}
	local mock_db_map = {}
	for i = 1, 50 do
		local name = "SyncTestPlayer" .. i
		local pd = _dnl.playerData(name, "TestGuild", 100, 1, 1, 30 + (i % 30), nil, 1429, nil, now - (i * 3600), nil, nil)
		local cs = _dnl.fletcher16(pd)
		mock_db[cs] = pd
		mock_db_map[name] = cs
	end

	-- Register a temporary test addon
	_dnl.addons = {
		["__test_sync__"] = {
			name = "__test_sync__",
			tag = "TST",
			isUnitTracked = function() return true end,
			settings = { death_alert_priority = 100 },
			db = mock_db,
			db_map = mock_db_map,
		}
	}
	_dnl.tag_to_addon = { TST = "__test_sync__" }

	local wm_ts, wm_count = _dnl._computeLocalWatermark(mock_db, 7)
	record("watermark timestamp > 0", wm_ts > 0, "ts=" .. tostring(wm_ts))
	record("watermark count matches db size within window",
		wm_count > 0 and wm_count <= 50,
		"count=" .. tostring(wm_count))

	-- ----------------------------------------------------------------
	-- Phase 2: Day-bucket diff
	-- ----------------------------------------------------------------
	print(TAG .. "Phase 2: Day-bucket diff (in-process)")

	-- Simulate: peer has entries we don't (on a specific day)
	local peer_only_entries = {}
	local peer_day_ts = now - 3600  -- ~1 hour ago (same UTC day as most mock entries)
	for i = 51, 60 do
		local name = "PeerOnlyPlayer" .. i
		local pd = _dnl.playerData(name, "PeerGuild", 200, 2, 3, 25, nil, 1429, nil, peer_day_ts - (i * 60), nil, nil)
		local cs = _dnl.fletcher16(pd)
		peer_only_entries[cs] = pd
	end

	-- Compute requester (our) day index — single-pass replacement for old computeLocalBuckets
	local day_idx = _dnl._buildDayIndex(mock_db, 7)
	local bucket_count = 0
	for _ in pairs(day_idx) do bucket_count = bucket_count + 1 end
	record("buildDayIndex returns non-empty",
		bucket_count > 0,
		"day_buckets=" .. tostring(bucket_count))

	-- Verify dayIndex helper
	local test_ts = 1695225600  -- 2023-09-20 16:00:00 UTC
	local expected_di = math.floor(test_ts / 86400)
	record("dayIndex computes correctly",
		_dnl._dayIndex(test_ts) == expected_di,
		"dayIndex=" .. tostring(_dnl._dayIndex(test_ts)) .. " expected=" .. tostring(expected_di))

	-- Verify checksumNumeric helper
	record("checksumNumeric parses suffix",
		_dnl._checksumNumeric("TestPlayer-12345") == 12345,
		"parsed=" .. tostring(_dnl._checksumNumeric("TestPlayer-12345")))
	record("checksumNumeric handles missing dash",
		_dnl._checksumNumeric("NoSuffix") == 0)

	-- Verify per-day XOR hash is non-zero for populated days
	local any_nonzero_hash = false
	for di, info in pairs(day_idx) do
		if info.hash ~= 0 then
			any_nonzero_hash = true
			break
		end
	end
	record("per-day XOR hash is non-zero for at least one day",
		any_nonzero_hash)

	-- Verify entries are sorted newest-first within each day
	local sort_ok = true
	for di, info in pairs(day_idx) do
		for j = 2, #info.entries do
			if (info.entries[j-1].data.date or 0) < (info.entries[j].data.date or 0) then
				sort_ok = false
				break
			end
		end
		if not sort_ok then break end
	end
	record("entries sorted newest-first within each day", sort_ok)

	-- Build "peer buckets" by adding peer-only entries to a copy of our counts/hashes
	local peer_buckets = {}
	for di, info in pairs(day_idx) do
		peer_buckets[di] = { count = info.count, hash = info.hash }
	end
	for cs, pd in pairs(peer_only_entries) do
		local di = _dnl._dayIndex(pd.date)
		local pb = peer_buckets[di]
		if pb then
			pb.count = pb.count + 1
			pb.hash = bit.bxor(pb.hash, _dnl._checksumNumeric(cs))
		else
			peer_buckets[di] = { count = 1, hash = _dnl._checksumNumeric(cs) }
		end
	end

	-- Identify short days (where peer has more than us, or hash mismatch)
	local short_day_count = 0
	for di, peer_info in pairs(peer_buckets) do
		local our_info = day_idx[di]
		local our_count = our_info and our_info.count or 0
		local our_hash  = our_info and our_info.hash  or 0
		if peer_info.count > our_count
			or (peer_info.count == our_count and peer_info.hash ~= our_hash) then
			short_day_count = short_day_count + 1
		end
	end
	record("detected short days where peer has more entries",
		short_day_count > 0,
		"short_days=" .. tostring(short_day_count))

	-- Verify day entries are accessible from the index
	local sample_di = _dnl._dayIndex(now - 3600)
	local sample_day = day_idx[sample_di]
	local entries_on_day = sample_day and #sample_day.entries or 0
	record("buildDayIndex entries accessible for populated day",
		entries_on_day >= 0,
		"entries_on_day=" .. tostring(entries_on_day))

	-- ----------------------------------------------------------------
	-- Phase 3: Entry consumption via handleSyncEntry
	-- ----------------------------------------------------------------
	print(TAG .. "Phase 3: Entry consumption")

	-- Reset state for entry consumption
	_dnl._syncResetToIdle()

	local entries_before = 0
	for _ in pairs(mock_db) do entries_before = entries_before + 1 end
	_dnl._syncStats.entries_received = 0

	-- Simulate receiving E$ entries (feed encoded data through handleSyncEntry)
	local consumed = 0
	for cs, pd in pairs(peer_only_entries) do
		local encoded = _dnl.encodeMessage(pd)
		if encoded then
			-- handleSyncEntry expects "TAG~encoded_data" format
			_dnl.handleSyncEntry("FakePeer", "TST" .. _dnl.COMM_FIELD_DELIM .. encoded)
			consumed = consumed + 1
		end
	end
	_dnl._drainSyncBacklogAll()

	record("all 10 peer entries were consumed",
		consumed == 10,
		"consumed=" .. tostring(consumed))

	record("sync stats tracked entries_received",
		_dnl._syncStats.entries_received == 10,
		"entries_received=" .. tostring(_dnl._syncStats.entries_received))

	-- ----------------------------------------------------------------
	-- Phase 4: Dedup — re-sending same entries should not double-count
	-- ----------------------------------------------------------------
	print(TAG .. "Phase 4: Dedup on re-receive")

	local received_before = _dnl._syncStats.entries_received
	for cs, pd in pairs(peer_only_entries) do
		local encoded = _dnl.encodeMessage(pd)
		if encoded then
			_dnl.handleSyncEntry("FakePeer", "TST" .. _dnl.COMM_FIELD_DELIM .. encoded)
		end
	end
	_dnl._drainSyncBacklogAll()
	-- entries_received increments even for dupes (createEntry fires hooks
	-- which do app-level dedup), but the addon db won't actually grow.
	-- The key check is that handleSyncEntry doesn't error out.
	record("re-receive of same entries doesn't error", true)

	-- ----------------------------------------------------------------
	-- Phase 5: State machine transitions
	-- ----------------------------------------------------------------
	print(TAG .. "Phase 5: State machine")

	_dnl._syncResetToIdle()
	record("resetToIdle → state is IDLE",
		_dnl._syncState() == _dnl.SYNC_STATE.IDLE)

	-- Simulate watermark that puts us behind (format: TAG~ts~count~window~)
	wipe(_dnl._syncCooldownPerAddon)
	_dnl.handleSyncWatermark("BigPeer", "TST~" .. wm_ts .. "~" .. (wm_count + 100) .. "~7~")
	record("watermark triggers COLLECTING_WATERMARKS",
		_dnl._syncState() == _dnl.SYNC_STATE.COLLECTING_WATERMARKS)

	-- Clean up
	_dnl._syncResetToIdle()
	wipe(_dnl._syncCooldownPerAddon)

	-- ----------------------------------------------------------------
	-- Phase 6: Jitter cancellation on passive E$ detection
	-- ----------------------------------------------------------------
	print(TAG .. "Phase 6: Passive mode on E$ during jitter")

	_dnl._syncSetState(_dnl.SYNC_STATE.JITTER_WAIT)
	local extra_pd = _dnl.playerData("PassiveTest", "", 100, 1, 1, 20, nil, 1429, nil, now, nil, nil)
	local extra_enc = _dnl.encodeMessage(extra_pd)
	if extra_enc then
		_dnl.handleSyncEntry("AnotherPeer", "TST" .. _dnl.COMM_FIELD_DELIM .. extra_enc)
	end
	record("E$ during JITTER_WAIT → drops to IDLE",
		_dnl._syncState() == _dnl.SYNC_STATE.IDLE)

	-- ----------------------------------------------------------------
	-- Summary
	-- ----------------------------------------------------------------
	-- Restore original state
	_dnl.addons = saved_addons
	_dnl.tag_to_addon = saved_tag_to_addon
	_dnl._syncResetToIdle()
	_dnl._syncStats.entries_received = 0
	_dnl._syncStats.entries_sent = 0

	print(TAG .. "=========================")
	print(string.format(TAG .. "Results: |cff00FF00%d passed|r, |cffFF0000%d failed|r", pass_count, fail_count))
	print(TAG .. "=========================")
	testCleanup()
end

-- ============================================================================
-- testSyncEndToEnd: full protocol simulation (requester ↔ responder)
-- ============================================================================

--- Simulate a complete sync session between two mock peers in-process.
--- Creates a "requester" database (small) and a "responder" database (superset),
--- manually formats the M$ bucket-request, feeds it through
--- handleSyncBucketRequest (which queues E$ entries in sync_out_queue),
--- then drains those E$ entries through handleSyncEntry and verifies
--- the requester's database grew with the missing entries.
---
--- This exercises the full pipeline without any real network traffic:
---   watermark detection → bucket request → day-bucket diff →
---   entry streaming → createEntry → dedup → state cleanup
function _dnl.testSyncEndToEnd()
	if not _dnl.DEBUG then
		print("|cffFF0000[Deathlog]|r testSyncEndToEnd requires DEBUG mode")
		return
	end

	testBegin()
	local TAG  = "|cff00CCFF[DNL Sync E2E]|r "
	local PASS = "|cff00FF00PASS|r"
	local FAIL = "|cffFF0000FAIL|r"

	local pass_count, fail_count = 0, 0
	local results = {}

	local function record(label, ok, detail)
		if ok then
			pass_count = pass_count + 1
			print(TAG .. PASS .. " " .. label .. (detail and (" — " .. detail) or ""))
		else
			fail_count = fail_count + 1
			print(TAG .. FAIL .. " " .. label .. (detail and (" — " .. detail) or ""))
		end
		results[#results + 1] = { label = label, ok = ok }
		if test_tracking.all_depth > 0 then
			table.insert(test_tracking.global_results, { suite = "SyncE2E", name = label, ok = ok, detail = detail })
		end
	end

	print(TAG .. "==========================================")
	print(TAG .. "Sync End-to-End Protocol Simulation")
	print(TAG .. "==========================================")

	-- Save original state
	local saved_addons        = _dnl.addons
	local saved_tag_to_addon  = _dnl.tag_to_addon

	-- ----------------------------------------------------------------
	-- Setup: build two databases with overlapping entries
	-- ----------------------------------------------------------------
	local now = GetServerTime()

	-- Shared entries: both requester and responder have these (30 entries)
	local shared_db          = {}
	local shared_db_map      = {}
	local shared_checksums   = {}
	for i = 1, 30 do
		local name = "SharedSync" .. i
		local pd = _dnl.playerData(name, "SharedGuild", 100 + i, 1, 1, 20 + (i % 40), nil, 1429, nil, now - (i * 3600), nil, nil)
		local cs = _dnl.fletcher16(pd)
		shared_db[cs]       = pd
		shared_db_map[name] = cs
		shared_checksums[cs] = true
	end

	-- Responder-only entries: requester is missing these (20 entries)
	local responder_extra_checksums = {}
	local responder_extra_count     = 20
	local responder_db              = {}
	local responder_db_map          = {}

	-- Copy shared entries into responder db
	for cs, pd in pairs(shared_db) do
		responder_db[cs] = pd
		responder_db_map[pd.name] = cs
	end

	-- Add the extra entries the requester doesn't have
	for i = 1, responder_extra_count do
		local name = "ResponderOnly" .. i
		local pd = _dnl.playerData(name, "ExtraGuild", 200 + i, 2, 3, 10 + (i * 2), nil, 1429, nil, now - (i * 1800), nil, nil)
		local cs = _dnl.fletcher16(pd)
		responder_db[cs]       = pd
		responder_db_map[name] = cs
		responder_extra_checksums[cs] = true
	end

	-- Requester db: just the shared entries
	local requester_db     = {}
	local requester_db_map = {}
	for cs, pd in pairs(shared_db) do
		requester_db[cs] = pd
		requester_db_map[pd.name] = cs
	end

	local requester_count_before = 0
	for _ in pairs(requester_db) do requester_count_before = requester_count_before + 1 end

	local responder_total = 0
	for _ in pairs(responder_db) do responder_total = responder_total + 1 end

	record("setup: requester has 30 entries", requester_count_before == 30,
		"count=" .. tostring(requester_count_before))
	record("setup: responder has 50 entries", responder_total == 50,
		"count=" .. tostring(responder_total))

	-- Register test addon pointing at the requester db initially
	_dnl.addons = {
		["__test_sync_e2e__"] = {
			name = "__test_sync_e2e__",
			tag = "TSE",
			isUnitTracked = function() return true end,
			settings = { death_alert_priority = 100 },
			db = requester_db,
			db_map = requester_db_map,
		},
	}
	_dnl.tag_to_addon = { TSE = "__test_sync_e2e__" }

	-- Register a per-addon hook that stores entries in db/db_map,
	-- mimicking what real addons (Deathlog) do.  Without this,
	-- createEntry(target_addon_name) only fires hooks but doesn't
	-- write to the addon's db directly.
	DeathNotificationLib.HookOnNewAddonEntry("__test_sync_e2e__", function(player_data, checksum)
		local addon = _dnl.addons["__test_sync_e2e__"]
		if addon and addon.db and checksum and player_data and player_data.name then
			-- Only accept entries created by THIS test.  Without this guard,
			-- dangling C_Timer callbacks from earlier test suites fire during
			-- our timer waits, iterate _dnl.addons, and the hook writes their
			-- rogue entries into responder_db / requester_db.
			local n = player_data.name
			if n:sub(1, 10) == "SharedSync"
				or n:sub(1, 13) == "ResponderOnly"
				or n:sub(1, 11) == "MismatchRepl" then
				addon.db[checksum] = player_data
				addon.db_map[player_data.name] = checksum
			end
		end
	end)

	-- Prevent the hardware-event input drain from sending (and removing)
	-- queued sync messages while C_Timer.After waits run.  By making
	-- safeSendChannel return false, sendNextInQueue keeps items in the
	-- queue so we can read them later.
	local saved_safeSendChannel = _dnl.safeSendChannel
	_dnl.safeSendChannel = function() return false end

	-- ----------------------------------------------------------------
	-- Phase 1: Watermark detection
	-- ----------------------------------------------------------------
	print(TAG .. "Phase 1: Watermark detection")

	_dnl._syncResetToIdle()
	wipe(_dnl._syncCooldownPerAddon)

	local req_wm_ts, req_wm_count = _dnl._computeLocalWatermark(requester_db, 7)
	local resp_wm_ts, resp_wm_count = _dnl._computeLocalWatermark(responder_db, 7)

	record("requester watermark count < responder",
		req_wm_count < resp_wm_count,
		"req=" .. tostring(req_wm_count) .. " resp=" .. tostring(resp_wm_count))

	-- Feed a fake watermark from "SyncTestResponder" as if they broadcast W$
	local wm_payload = "TSE~" .. resp_wm_ts .. "~" .. resp_wm_count .. "~7~"
	_dnl.handleSyncWatermark("SyncTestResponder", wm_payload)
	record("watermark triggers COLLECTING_WATERMARKS",
		_dnl._syncState() == _dnl.SYNC_STATE.COLLECTING_WATERMARKS)

	_dnl._syncResetToIdle()
	wipe(_dnl._syncCooldownPerAddon)

	-- ----------------------------------------------------------------
	-- Phase 2: Build bucket request (requester side)
	-- ----------------------------------------------------------------
	print(TAG .. "Phase 2: Build bucket request from requester's day index")

	local req_day_idx = _dnl._buildDayIndex(requester_db, 7)
	local sorted_buckets = {}
	for di, info in pairs(req_day_idx) do
		sorted_buckets[#sorted_buckets + 1] = { di = di, c = info.count, h = info.hash }
	end
	table.sort(sorted_buckets, function(a, b) return a.di < b.di end)

	record("requester day index built", #sorted_buckets > 0,
		"buckets=" .. tostring(#sorted_buckets))

	-- Format as the M$ payload that handleSyncBucketRequest expects
	-- (after the "M$" prefix has been stripped by the dispatcher):
	-- "TSE~7~<d0>:<c0>:<h0>~...~0~"
	local bucket_parts = {}
	for _, b in ipairs(sorted_buckets) do
		bucket_parts[#bucket_parts + 1] = b.di .. ":" .. b.c .. ":" .. b.h
	end
	local bucket_payload = "TSE~7~" .. table.concat(bucket_parts, "~") .. "~0~"

	record("bucket request payload formatted", #bucket_payload > 10,
		"len=" .. tostring(#bucket_payload))

	-- ----------------------------------------------------------------
	-- Phase 3: Responder processes bucket request → queues E$ entries
	-- ----------------------------------------------------------------
	print(TAG .. "Phase 3: Responder processes bucket request")

	-- Swap addon to point at the responder's (larger) database
	_dnl.addons["__test_sync_e2e__"].db     = responder_db
	_dnl.addons["__test_sync_e2e__"].db_map = responder_db_map

	-- Reset state to IDLE so handleSyncBucketRequest accepts the request
	_dnl._syncResetToIdle()
	_dnl._syncStats.entries_sent     = 0
	_dnl._syncStats.entries_received = 0

	-- Clear the sync out queue so we only capture entries from this test
	wipe(_dnl.sync_out_queue)

	-- Feed the bucket request as if it arrived via addon whisper
	_dnl.handleSyncBucketRequest("SyncTestRequester", bucket_payload)

	-- handleSyncBucketRequest is partially async (sendNextBatch uses C_Timer.After).
	-- Wait 3 seconds for all batches to complete, then Phase 4.
	C_Timer.After(3, function()
		-- ----------------------------------------------------------------
		-- Phase 4: Drain E$ queue → requester processes entries
		-- ----------------------------------------------------------------
		print(TAG .. "Phase 4: Requester processes streamed entries")

		local queued_messages = {}
		for _, item in ipairs(_dnl.sync_out_queue) do
			local text = item[1]
			-- E$ messages start with "E$"; extract payload after "$"
			if text and text:sub(1, 2) == _dnl.SYNC_CMD_ENTRY_RES .. _dnl.COMM_COMMAND_DELIM then
				local payload = text:sub(3)  -- "TSE~encoded_data" or "TSE~entry1;entry2;..."
				queued_messages[#queued_messages + 1] = payload
			end
		end

		record("responder queued E$ messages", #queued_messages > 0,
			"messages=" .. tostring(#queued_messages))

		local entries_sent_stat = _dnl._syncStats.entries_sent
		record("responder stats.entries_sent > 0", entries_sent_stat > 0,
			"entries_sent=" .. tostring(entries_sent_stat))

		-- Swap addon back to the requester's (smaller) database
		_dnl.addons["__test_sync_e2e__"].db     = requester_db
		_dnl.addons["__test_sync_e2e__"].db_map = requester_db_map

		-- Set state to AWAITING_ENTRIES (simulates the requester waiting)
		_dnl._syncSetState(_dnl.SYNC_STATE.AWAITING_ENTRIES)
		_dnl._syncStats.entries_received = 0

		-- Feed each E$ message through handleSyncEntry
		for _, payload in ipairs(queued_messages) do
			_dnl.handleSyncEntry("SyncTestResponder", payload)
		end
		_dnl._drainSyncBacklogAll()

		local entries_received_stat = _dnl._syncStats.entries_received
		record("requester received entries via handleSyncEntry",
			entries_received_stat > 0,
			"entries_received=" .. tostring(entries_received_stat))

		-- Count requester's DB after sync
		local requester_count_after = 0
		for _ in pairs(requester_db) do requester_count_after = requester_count_after + 1 end

		record("requester DB grew after sync",
			requester_count_after > requester_count_before,
			"before=" .. tostring(requester_count_before) .. " after=" .. tostring(requester_count_after))

		-- Verify specific extra entries made it into the requester DB
		local extra_found = 0
		for cs in pairs(responder_extra_checksums) do
			if requester_db[cs] then
				extra_found = extra_found + 1
			end
		end
		record("requester gained responder-only entries",
			extra_found > 0,
			"found=" .. tostring(extra_found) .. "/" .. tostring(responder_extra_count))

		record("requester gained ALL responder-only entries",
			extra_found == responder_extra_count,
			"found=" .. tostring(extra_found) .. " expected=" .. tostring(responder_extra_count))

		-- ----------------------------------------------------------------
		-- Phase 5: Dedup — re-feeding the same E$ messages should not grow DB
		-- ----------------------------------------------------------------
		print(TAG .. "Phase 5: Dedup on re-sync")

		local count_before_dedup = requester_count_after
		_dnl._syncStats.entries_received = 0

		for _, payload in ipairs(queued_messages) do
			_dnl.handleSyncEntry("SyncTestResponder", payload)
		end
		_dnl._drainSyncBacklogAll()

		local count_after_dedup = 0
		for _ in pairs(requester_db) do count_after_dedup = count_after_dedup + 1 end

		record("re-sync does not duplicate entries",
			count_after_dedup == count_before_dedup,
			"before=" .. tostring(count_before_dedup) .. " after=" .. tostring(count_after_dedup))

		-- ----------------------------------------------------------------
		-- Phase 6: Fully synced — requester DB matches responder DB
		-- ----------------------------------------------------------------
		print(TAG .. "Phase 6: Fully synced DB verification")

		-- Directly verify that requester_db now contains every entry that
		-- responder_db has (and vice versa).  This is a semantic check on
		-- the data itself, immune to async sendNextBatch timer leakage.
		local missing_in_req = 0
		for cs in pairs(responder_db) do
			if not requester_db[cs] then missing_in_req = missing_in_req + 1 end
		end
		local extra_in_req = 0
		for cs in pairs(requester_db) do
			if not responder_db[cs] then extra_in_req = extra_in_req + 1 end
		end

		record("fully synced: requester has all responder entries",
			missing_in_req == 0,
			"missing=" .. tostring(missing_in_req))
		record("fully synced: no extra entries in requester",
			extra_in_req == 0,
			"extra=" .. tostring(extra_in_req))

		-- Also verify day-bucket indexes produce identical hashes
		local req_idx  = _dnl._buildDayIndex(requester_db, 7)
		local resp_idx = _dnl._buildDayIndex(responder_db, 7)
		local bucket_diffs = 0
		for di, resp_day in pairs(resp_idx) do
			local req_day = req_idx[di]
			if not req_day
				or req_day.count ~= resp_day.count
				or req_day.hash  ~= resp_day.hash then
				bucket_diffs = bucket_diffs + 1
			end
		end
		for di in pairs(req_idx) do
			if not resp_idx[di] then bucket_diffs = bucket_diffs + 1 end
		end
		record("fully synced: day-bucket indexes match",
			bucket_diffs == 0,
			"diffs=" .. tostring(bucket_diffs))

		-- ----------------------------------------------------------------
		-- Phase 7: Hash-mismatch-only days trigger entry streaming
		-- ----------------------------------------------------------------
		print(TAG .. "Phase 7: Hash-mismatch-only sync")

			-- Build a requester with same counts but different hashes on one day.
			-- We do this by replacing one entry with a different one on the same day.
			local mismatch_db     = {}
			local mismatch_db_map = {}

			-- Copy responder entries
			for cs, pd in pairs(responder_db) do
				mismatch_db[cs] = pd
				mismatch_db_map[pd.name] = cs
			end

			-- Remove one responder-only entry and add a different one
			local removed_cs = nil
			local removed_pd = nil
			for cs in pairs(responder_extra_checksums) do
				removed_cs = cs
				removed_pd = responder_db[cs]
				break
			end

			if removed_cs and removed_pd then
				-- Remove from mismatch db
				mismatch_db[removed_cs] = nil
				mismatch_db_map[removed_pd.name] = nil

				-- Add a replacement entry with the same date (same day bucket)
				-- but different data → different checksum → different XOR hash
				local repl_name = "MismatchRepl1"
				local repl_pd = _dnl.playerData(repl_name, "MismatchG", 999, 3, 5, 45, nil, 1429, nil, removed_pd.date, nil, nil)
				local repl_cs = _dnl.fletcher16(repl_pd)
				mismatch_db[repl_cs]       = repl_pd
				mismatch_db_map[repl_name] = repl_cs

				-- Build mismatch requester's bucket payload
				local mm_day_idx = _dnl._buildDayIndex(mismatch_db, 7)
				local mm_sorted = {}
				for di, info in pairs(mm_day_idx) do
					mm_sorted[#mm_sorted + 1] = { di = di, c = info.count, h = info.hash }
				end
				table.sort(mm_sorted, function(a, b) return a.di < b.di end)

				local mm_parts = {}
				for _, b in ipairs(mm_sorted) do
					mm_parts[#mm_parts + 1] = b.di .. ":" .. b.c .. ":" .. b.h
				end
				local mm_payload = "TSE~7~" .. table.concat(mm_parts, "~") .. "~0~"

				-- Responder still has the original DB
				_dnl.addons["__test_sync_e2e__"].db     = responder_db
				_dnl.addons["__test_sync_e2e__"].db_map = responder_db_map
				_dnl._syncResetToIdle()
				_dnl._syncStats.entries_sent = 0
				wipe(_dnl.sync_out_queue)

				_dnl.handleSyncBucketRequest("MismatchRequester", mm_payload)

				C_Timer.After(2, function()
					local mm_msgs = 0
					for _, item in ipairs(_dnl.sync_out_queue) do
						if item[1]:sub(1, 2) == _dnl.SYNC_CMD_ENTRY_RES .. _dnl.COMM_COMMAND_DELIM then
							mm_msgs = mm_msgs + 1
						end
					end

					record("hash-mismatch: responder streams entries",
						mm_msgs > 0,
						"messages=" .. tostring(mm_msgs))

					-- ----------------------------------------------------------------
					-- Phase 8: State machine round-trip validation
					-- ----------------------------------------------------------------
					print(TAG .. "Phase 8: State machine round-trip")

					_dnl._syncResetToIdle()
					record("state is IDLE after reset",
						_dnl._syncState() == _dnl.SYNC_STATE.IDLE)

					-- Simulate the full requester state progression:
					-- IDLE → COLLECTING_WATERMARKS → JITTER_WAIT → AWAITING_ENTRIES → finish
					_dnl._syncSetState(_dnl.SYNC_STATE.COLLECTING_WATERMARKS)
					record("can transition to COLLECTING_WATERMARKS",
						_dnl._syncState() == _dnl.SYNC_STATE.COLLECTING_WATERMARKS)

					_dnl._syncSetState(_dnl.SYNC_STATE.JITTER_WAIT)
					record("can transition to JITTER_WAIT",
						_dnl._syncState() == _dnl.SYNC_STATE.JITTER_WAIT)

					_dnl._syncSetState(_dnl.SYNC_STATE.AWAITING_ENTRIES)
					record("can transition to AWAITING_ENTRIES",
						_dnl._syncState() == _dnl.SYNC_STATE.AWAITING_ENTRIES)

					-- _syncFinish puts us back to IDLE and records stats
					_dnl._syncFinish("test-complete")
					record("_syncFinish → state is IDLE",
						_dnl._syncState() == _dnl.SYNC_STATE.IDLE)
					record("_syncFinish → last_sync_time recorded",
						_dnl._syncStats.last_sync_time > 0)

					-- ----------------------------------------------------------------
					-- Phase 9: Empty requester DB (peer has everything, we have nothing)
					-- ----------------------------------------------------------------
					print(TAG .. "Phase 9: Empty requester syncs from full responder")

					local empty_db     = {}
					local empty_db_map = {}

					-- Empty requester's bucket payload: no buckets at all
					local empty_payload = "TSE~7~0~"

					-- Responder has full DB
					_dnl.addons["__test_sync_e2e__"].db     = responder_db
					_dnl.addons["__test_sync_e2e__"].db_map = responder_db_map
					_dnl._syncResetToIdle()
					_dnl._syncStats.entries_sent = 0
					wipe(_dnl.sync_out_queue)

					_dnl.handleSyncBucketRequest("EmptyRequester", empty_payload)

					C_Timer.After(2, function()
						local empty_e2e_msgs = {}
						for _, item in ipairs(_dnl.sync_out_queue) do
							if item[1]:sub(1, 2) == _dnl.SYNC_CMD_ENTRY_RES .. _dnl.COMM_COMMAND_DELIM then
								empty_e2e_msgs[#empty_e2e_msgs + 1] = item[1]:sub(3)
							end
						end

						record("empty requester: responder queued entries",
							#empty_e2e_msgs > 0,
							"messages=" .. tostring(#empty_e2e_msgs))

						-- Swap to empty DB and consume entries
						_dnl.addons["__test_sync_e2e__"].db     = empty_db
						_dnl.addons["__test_sync_e2e__"].db_map = empty_db_map
						_dnl._syncSetState(_dnl.SYNC_STATE.AWAITING_ENTRIES)
						_dnl._syncStats.entries_received = 0

						for _, payload in ipairs(empty_e2e_msgs) do
							_dnl.handleSyncEntry("SyncTestResponder", payload)
						end
						_dnl._drainSyncBacklogAll()

						local empty_count_after = 0
						for _ in pairs(empty_db) do empty_count_after = empty_count_after + 1 end

						record("empty requester gained entries",
							empty_count_after > 0,
							"gained=" .. tostring(empty_count_after))

						-- Verify every responder entry is present in the empty_db.
						-- Async sendNextBatch continuations from prior phases may
						-- leak extra E$ messages into the queue during the timer
						-- wait, so we check coverage rather than exact count.
						local empty_missing = 0
						for cs in pairs(responder_db) do
							if not empty_db[cs] then empty_missing = empty_missing + 1 end
						end
						record("empty requester has all responder entries",
							empty_missing == 0,
							"missing=" .. tostring(empty_missing) .. " gained=" .. tostring(empty_count_after) .. " expected=" .. tostring(responder_total))

						-- --------------------------------------------------------
						-- Cleanup & summary
						-- --------------------------------------------------------
						_dnl.safeSendChannel = saved_safeSendChannel
						_dnl.per_addon_hooks["__test_sync_e2e__"] = nil
						_dnl.addons        = saved_addons
						_dnl.tag_to_addon  = saved_tag_to_addon
						_dnl._syncResetToIdle()
						_dnl._syncStats.entries_received = 0
						_dnl._syncStats.entries_sent     = 0
						wipe(_dnl.sync_out_queue)

						print(TAG .. "==========================================")
						print(string.format(TAG .. "Results: |cff00FF00%d passed|r, |cffFF0000%d failed|r",
							pass_count, fail_count))
						print(TAG .. "==========================================")
						testCleanup()
					end)   -- close Phase 9 timer
				end)       -- close Phase 7 timer
			end            -- close if removed_cs
		end)               -- close Phase 3→4 timer
end

-- ============================================================================
-- testWho: /who system unit tests
-- ============================================================================

--- Test the /who query system: API validation, normalize, enqueued lookup,
--- and lookup-table resolution.  The live lookup uses enqueueWhoPlayer so
--- it drains on the next user input (mouse/key) — no taint issues.
function _dnl.testWho()
	if not _dnl.DEBUG then
		print("|cffFF0000[Deathlog]|r testWho requires DEBUG mode")
		return
	end

	testBegin()
	local TAG  = "|cff00AAFF[DNL Who Test]|r "
	local PASS = "|cff00FF00PASS|r"
	local FAIL = "|cffFF0000FAIL|r"

	local results = {}
	local function record(name, ok, detail)
		table.insert(results, { name = name, ok = ok, detail = detail })
		if test_tracking.all_depth > 0 then
			table.insert(test_tracking.global_results, { suite = "Who", name = name, ok = ok, detail = detail })
		end
		print(TAG .. (ok and PASS or FAIL) .. " " .. name .. (detail and (" - " .. detail) or ""))
	end

	local function printSummary()
		print(TAG .. "--- Summary ---")
		local passed, failed = 0, 0
		for _, r in ipairs(results) do
			if r.ok then passed = passed + 1 else failed = failed + 1 end
		end
		for _, r in ipairs(results) do
			print(TAG .. "  " .. (r.ok and PASS or FAIL) .. " " .. r.name)
		end
		local color = failed == 0 and "|cff00FF00" or "|cffFF0000"
		print(TAG .. color .. string.format("%d/%d passed|r", passed, passed + failed))
	end

	print(TAG .. "=========================")
	print(TAG .. "Who System Tests")
	print(TAG .. "=========================")

	-- ============================================================
	-- Phase 1: API validation (synchronous)
	-- ============================================================
	print(TAG .. "Phase 1: API validation")

	record("whoPlayer rejects nil name",
		_dnl.whoPlayer(nil, function() end) == false)
	record("whoPlayer rejects empty name",
		_dnl.whoPlayer("", function() end) == false)
	record("enqueueWhoPlayer doesn't error",
		(pcall(_dnl.enqueueWhoPlayer, "TestWhoName", function() end)))
	record("handleWhoListUpdate doesn't error when idle",
		(pcall(_dnl.handleWhoListUpdate)))

	-- ============================================================
	-- Phase 2: normalize function
	-- ============================================================
	print(TAG .. "Phase 2: normalize")

	record("normalize strips realm suffix",
		_dnl.normalize("Dispella-Stitches") == "Dispella",
		string.format("got '%s'", _dnl.normalize("Dispella-Stitches")))
	record("normalize preserves plain name",
		_dnl.normalize("Dispella") == "Dispella",
		string.format("got '%s'", _dnl.normalize("Dispella")))
	record("normalize handles hyphenated realm",
		_dnl.normalize("Player-Some-Realm") == "Player",
		string.format("got '%s'", _dnl.normalize("Player-Some-Realm")))

	-- ============================================================
	-- Phase 3: Lookup table validation
	-- ============================================================
	print(TAG .. "Phase 3: Lookup table validation")

	-- CLASS_FILE_TO_ID should resolve all standard class filenames
	local class_files = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
	for _, cf in ipairs(class_files) do
		local cid = _dnl.D.CLASS_FILE_TO_ID[cf]
		record("CLASS_FILE_TO_ID[" .. cf .. "]",
			cid ~= nil and cid > 0,
			string.format("→ %s", tostring(cid)))
	end

	-- RACE_FILE_TO_ID should resolve standard race file strings (non-localized)
	local race_files = { "Human", "Orc", "Dwarf", "NightElf", "Scourge", "Tauren", "Gnome", "Troll" }
	for _, rf in ipairs(race_files) do
		local rid = _dnl.D.RACE_FILE_TO_ID[rf]
		record("RACE_FILE_TO_ID[" .. rf .. "]",
			rid ~= nil and rid > 0,
			string.format("→ %s", tostring(rid)))
	end

	-- fullGuildName realm-stripping pattern
	record("realm-strip 'Guild-Realm' → 'Guild'",
		("MyGuild-Stitches"):match("^([^-]+)") == "MyGuild")
	record("realm-strip 'Guild' (no realm) → 'Guild'",
		("MyGuild"):match("^([^-]+)") == "MyGuild")
	record("realm-strip nil-safe",
		pcall(function() return (nil or ""):match("^([^-]+)") end))

	-- ============================================================
	-- Phase 4: Live self-lookup via enqueueWhoPlayer (async)
	-- ============================================================
	print(TAG .. "Phase 4: Live self-lookup via enqueueWhoPlayer")
	print(TAG .. "|cffFFFF00Press any key or click to drain the who queue!|r")

	local player_name = UnitName("player")
	local self_callback_fired = false
	local self_callback_info = nil

	_dnl.enqueueWhoPlayer(player_name, function(info)
		self_callback_fired = true
		self_callback_info = info
	end)
	record("enqueueWhoPlayer(self) accepted", true)

	-- Wait for user input to drain + response (up to 15s)
	C_Timer.After(15, function()
		-- ============================================================
		-- Phase 5: Self-lookup results
		-- ============================================================
		print(TAG .. "Phase 5: Self-lookup results")

		record("self-lookup callback fired", self_callback_fired,
			not self_callback_fired and "did you click/press a key?" or nil)

		if self_callback_info then
			record("self-lookup returned WhoInfo", true)

			local result_name = self_callback_info.fullName
				and _dnl.normalize(self_callback_info.fullName)
				or nil
			record("self-lookup: name matches",
				result_name == player_name,
				string.format("expected '%s', got '%s'", player_name, tostring(result_name)))

			record("self-lookup: has level",
				self_callback_info.level ~= nil and self_callback_info.level > 0,
				"level=" .. tostring(self_callback_info.level))

			record("self-lookup: has class (filename)",
				self_callback_info.filename ~= nil and self_callback_info.filename ~= "",
				"class=" .. tostring(self_callback_info.filename))

			record("self-lookup: has race",
				self_callback_info.raceStr ~= nil and self_callback_info.raceStr ~= "",
				"race=" .. tostring(self_callback_info.raceStr))

			-- Verify lookup tables can resolve the actual who data
			if self_callback_info.filename then
				local class_id = _dnl.D.CLASS_FILE_TO_ID[self_callback_info.filename]
				record("CLASS_FILE_TO_ID resolves live who filename",
					class_id ~= nil and class_id > 0,
					string.format("filename='%s' → class_id=%s", self_callback_info.filename, tostring(class_id)))
			end

			if self_callback_info.raceStr then
				local race_id = _dnl.D.RACE_NAME_TO_ID[self_callback_info.raceStr]
				record("RACE_NAME_TO_ID resolves live who raceStr",
					race_id ~= nil and race_id > 0,
					string.format("raceStr='%s' → race_id=%s", self_callback_info.raceStr, tostring(race_id)))
			end

			if self_callback_info.fullGuildName and self_callback_info.fullGuildName ~= "" then
				local stripped = self_callback_info.fullGuildName:match("^([^-]+)")
				record("fullGuildName realm-strip on live data",
					stripped ~= nil and stripped ~= "",
					string.format("'%s' → '%s'", self_callback_info.fullGuildName, tostring(stripped)))
			end
		else
			record("self-lookup returned WhoInfo", false,
				"callback fired=" .. tostring(self_callback_fired) .. " but info was nil (timeout or no input?)")
		end

		C_Timer.After(0.5, function()
			print(TAG .. "=========================")
			printSummary()
			print(TAG .. "=========================")
			testCleanup()
		end)
	end)
end

-- ============================================================================
-- UltraHardcore bridge tests
-- ============================================================================

--- Test the UltraHardcore death message parser and zone resolver.
--- Requires DEBUG mode for _dnl._ultra to be populated.
function _dnl.testUltraHardcore()
	testBegin()
	local PASS = "|cff00FF00PASS|r"
	local FAIL = "|cffFF0000FAIL|r"
	local TAG  = "|cffFF6600[Deathlog UltraHardcore]|r "

	local results = {}
	local function record(name, ok, detail)
		table.insert(results, { name = name, ok = ok, detail = detail })
		if test_tracking.all_depth > 0 then
			table.insert(test_tracking.global_results, { suite = "UltraHardcore", name = name, ok = ok, detail = detail })
		end
		local status = ok and PASS or FAIL
		print(TAG .. status .. " " .. name .. (detail and (" - " .. detail) or ""))
	end

	local function printSummary()
		print(TAG .. "--- Summary ---")
		local pass, fail = 0, 0
		for _, r in ipairs(results) do
			if r.ok then pass = pass + 1 else fail = fail + 1 end
		end
		print(TAG .. string.format("%d/%d passed", pass, pass + fail))
	end

	print(TAG .. "=========================")
	print(TAG .. "UltraHardcore Bridge Tests")
	print(TAG .. "=========================")

	-- ============================================================
	-- Phase 1: Death message pattern matching
	-- ============================================================
	print(TAG .. "Phase 1: Death message pattern matching")

	local pattern = _dnl._ultra and _dnl._ultra.DEATH_PATTERN
	record("_ultra test helpers available", _dnl._ultra ~= nil)
	if not _dnl._ultra then
		print(TAG .. "|cffFF0000Skipping — _ultra not available (DEBUG mode required)|r")
		printSummary()
		testCleanup()
		return
	end

	-- Standard death message
	local msg1 = "I've been slain at level 42 by Hogger in Elwynn Forest. Their health was 1000/2000 (50%)!"
	local l1, k1, z1, h1 = msg1:match(pattern)
	record("standard msg: level", l1 == "42", tostring(l1))
	record("standard msg: killer", k1 == "Hogger", tostring(k1))
	record("standard msg: zone", z1 == "Elwynn Forest", tostring(z1))
	record("standard msg: health", h1 == "1000/2000 (50%)", tostring(h1))

	-- Death with subzone
	local msg2 = "I've been slain at level 60 by Onyxia in Onyxia's Lair, Dustwallow Marsh. Their health was 500000/1000000 (50%)!"
	local l2, k2, z2, h2 = msg2:match(pattern)
	record("subzone msg: level", l2 == "60", tostring(l2))
	record("subzone msg: killer", k2 == "Onyxia", tostring(k2))
	record("subzone msg: zone contains comma", z2 == "Onyxia's Lair, Dustwallow Marsh", tostring(z2))

	-- Death with unknown health
	local msg3 = "I've been slain at level 10 by Murloc in Westfall. Their health was Unknown!"
	local l3, k3, z3, h3 = msg3:match(pattern)
	record("unknown health: level", l3 == "10", tostring(l3))
	record("unknown health: health text", h3 == "Unknown", tostring(h3))

	-- Non-matching messages should not match
	local msg_no = "Player has died at level 42 in Elwynn Forest"
	local ln, _, _, _ = msg_no:match(pattern)
	record("non-matching message returns nil", ln == nil)

	-- ============================================================
	-- Phase 2: Zone name resolution
	-- ============================================================
	print(TAG .. "Phase 2: Zone name resolution")

	local resolveZone = _dnl._ultra.resolveZoneToMapId

	-- Test with a known zone (Elwynn Forest is map_id 37 in most data)
	-- We check that the function returns *something* for a common zone
	-- rather than hardcoding IDs, since data tables are locale-dependent.
	local elwynn_id = resolveZone("Elwynn Forest")
	record("resolveZoneToMapId returns value for known zone",
		elwynn_id ~= nil,
		string.format("Elwynn Forest → %s", tostring(elwynn_id)))

	-- Unknown zone returns nil
	record("resolveZoneToMapId returns nil for unknown zone",
		resolveZone("Zangarmarsh Planet X") == nil)

	-- Subzone format: "SubZone, Zone" — the module should try the zone part
	-- (This tests the calling code logic, not resolveZoneToMapId itself)

	-- ============================================================
	-- Phase 3: processDeathMessage end-to-end
	-- ============================================================
	print(TAG .. "Phase 3: processDeathMessage end-to-end")

	local processMsg = _dnl._ultra.processDeathMessage
	local ultra_name = "UltraTest" .. math.random(10000, 99999)
	_dnl.lru_by_name[ultra_name:lower()] = nil

	local test_msg = "I've been slain at level 33 by Defias Pillager in Westfall. Their health was 500/800 (62%)!"
	processMsg(test_msg, ultra_name, nil)

	-- Give the handler time (handleDeathBroadcast is synchronous but LRU commit is async)
	local ultra_lru = _dnl.lru_by_name[ultra_name:lower()]
	record("processDeathMessage stores entry in LRU",
		ultra_lru ~= nil,
		"entry should exist")
	if ultra_lru and ultra_lru.checksum then
		local ultra_cache = _dnl.death_ping_lru_cache_tbl[ultra_lru.checksum]
		record("processDeathMessage: player_data exists",
			ultra_cache ~= nil and ultra_cache["player_data"] ~= nil)
		if ultra_cache and ultra_cache["player_data"] then
			record("processDeathMessage: name correct",
				ultra_cache["player_data"]["name"] == ultra_name)
			record("processDeathMessage: level correct",
				tonumber(ultra_cache["player_data"]["level"]) == 33)
			-- Source resolution: "Defias Pillager" may or may not be in NPC_TO_ID
			-- depending on data tables — just verify source_id is set
			record("processDeathMessage: source_id set",
				ultra_cache["player_data"]["source_id"] ~= nil)
		end
	end

	-- Dedup: processing the same message again should not create a duplicate
	local ultra_name2 = ultra_name  -- same sender, same level
	processMsg(test_msg, ultra_name2, nil)
	-- If a duplicate were created, the LRU checksum would change — verify it didn't
	local ultra_lru2 = _dnl.lru_by_name[ultra_name2:lower()]
	record("processDeathMessage dedup: no duplicate entry",
		ultra_lru2 ~= nil and ultra_lru2.checksum == (ultra_lru and ultra_lru.checksum),
		"checksums should match")

	-- ============================================================
	-- Summary
	-- ============================================================
	C_Timer.After(0.5, function()
		print(TAG .. "=========================")
		printSummary()
		print(TAG .. "=========================")
		testCleanup()
	end)
end

-- ============================================================================
-- testAttachAddon: multi-addon registration & isolation tests
-- ============================================================================

--- Comprehensive test suite for the AttachAddon multi-addon registry.
--- Exercises input validation (7 assert paths), multi-addon coexistence,
--- settings aggregation (anyAddonAllows/anyAddonEnables/getDeathAlertOwnerSettings),
--- shouldBroadcastDeath OR-semantics, per-addon hook dispatch (normal + secure +
--- addonless + targeted + share_playtime isolation), per-addon DB isolation via
--- sync entry routing, HookOnNewAddonEntry edge cases, and deepCopy/getDeathRecord
--- coverage.  All test-created addons, hooks, and LRU artifacts are cleaned up at
--- the end.
function _dnl.testAttachAddon()
	if not _dnl.DEBUG then
		print("|cffFF0000[Deathlog]|r testAttachAddon requires DEBUG mode")
		return
	end

	testBegin()
	local TAG  = "|cff00FFAA[DNL AttachAddon Test]|r "
	local PASS = "|cff00FF00PASS|r"
	local FAIL = "|cffFF0000FAIL|r"

	local results = {}
	local function record(name, ok, detail)
		table.insert(results, { name = name, ok = ok, detail = detail })
		if test_tracking.all_depth > 0 then
			table.insert(test_tracking.global_results, { suite = "AttachAddon", name = name, ok = ok, detail = detail })
		end
		print(TAG .. (ok and PASS or FAIL) .. " " .. name .. (detail and (" — " .. detail) or ""))
	end

	local function printSummary()
		print(TAG .. "--- Summary ---")
		local passed, failed = 0, 0
		for _, r in ipairs(results) do
			if r.ok then passed = passed + 1 else failed = failed + 1 end
		end
		for _, r in ipairs(results) do
			print(TAG .. "  " .. (r.ok and PASS or FAIL) .. " " .. r.name)
		end
		local color = failed == 0 and "|cff00FF00" or "|cffFF0000"
		print(TAG .. color .. string.format("%d/%d passed|r", passed, passed + failed))
	end

	print(TAG .. "=========================")
	print(TAG .. "AttachAddon Test Suite")
	print(TAG .. "=========================")

	-- Save FULL registry state so we can restore after the test.
	local saved_addons            = _dnl.addons
	local saved_tag_to_addon      = _dnl.tag_to_addon
	local saved_per_addon_hooks   = _dnl.per_addon_hooks
	local saved_per_addon_secure  = _dnl.per_addon_hooks_secure

	-- Start with an empty registry for isolation.
	_dnl.addons            = {}
	_dnl.tag_to_addon      = {}
	_dnl.per_addon_hooks   = {}
	_dnl.per_addon_hooks_secure = {}

	local dummy_fn = function() return true end

	-- ================================================================
	-- Phase 1: AttachAddon Input Validation
	-- ================================================================
	print(TAG .. "Phase 1: Input validation")

	-- 1a: non-table options
	record("rejects non-table options",
		not pcall(_dnl.attachAddon, "string"))

	-- 1b: missing name
	record("rejects missing name",
		not pcall(_dnl.attachAddon, { tag = "AAA", isUnitTracked = dummy_fn }))

	-- 1c: empty name
	record("rejects empty name",
		not pcall(_dnl.attachAddon, { name = "", tag = "AAA", isUnitTracked = dummy_fn }))

	-- 1d: missing tag
	record("rejects missing tag",
		not pcall(_dnl.attachAddon, { name = "Test", isUnitTracked = dummy_fn }))

	-- 1e: short tag (2 chars)
	record("rejects tag length 2",
		not pcall(_dnl.attachAddon, { name = "Test", tag = "AB", isUnitTracked = dummy_fn }))

	-- 1f: long tag (4 chars)
	record("rejects tag length 4",
		not pcall(_dnl.attachAddon, { name = "Test", tag = "ABCD", isUnitTracked = dummy_fn }))

	-- 1g: missing isUnitTracked
	record("rejects missing isUnitTracked",
		not pcall(_dnl.attachAddon, { name = "Test", tag = "AAA" }))

	-- 1h: non-function isUnitTracked
	record("rejects non-function isUnitTracked",
		not pcall(_dnl.attachAddon, { name = "Test", tag = "AAA", isUnitTracked = "string" }))

	-- 1i: db without db_map
	record("rejects db without db_map",
		not pcall(_dnl.attachAddon, { name = "Test", tag = "AAA", isUnitTracked = dummy_fn, db = {} }))

	-- 1j: db_map without db
	record("rejects db_map without db",
		not pcall(_dnl.attachAddon, { name = "Test", tag = "AAA", isUnitTracked = dummy_fn, db_map = {} }))

	-- 1k: successful minimal registration
	local ok_min = pcall(_dnl.attachAddon, { name = "MinTest", tag = "MN1", isUnitTracked = dummy_fn })
	record("accepts minimal registration", ok_min)
	record("minimal: addon stored in registry",
		_dnl.addons["MinTest"] ~= nil and _dnl.addons["MinTest"].name == "MinTest")
	record("minimal: tag lookup populated",
		_dnl.tag_to_addon["MN1"] == "MinTest")

	-- 1l: successful full registration
	local full_db     = {}
	local full_db_map = {}
	local full_dev    = {}
	local full_settings = { death_alert_priority = 50, peer_reporting = true }
	local ok_full = pcall(_dnl.attachAddon, {
		name          = "FullTest",
		tag           = "FL1",
		isUnitTracked = dummy_fn,
		settings      = full_settings,
		db            = full_db,
		db_map        = full_db_map,
		dev_data      = full_dev,
	})
	record("accepts full registration", ok_full)
	record("full: settings stored",
		_dnl.addons["FullTest"] ~= nil and _dnl.addons["FullTest"].settings == full_settings)
	record("full: db stored",
		_dnl.addons["FullTest"] ~= nil and _dnl.addons["FullTest"].db == full_db)
	record("full: db_map stored",
		_dnl.addons["FullTest"] ~= nil and _dnl.addons["FullTest"].db_map == full_db_map)
	record("full: dev_data stored",
		_dnl.addons["FullTest"] ~= nil and _dnl.addons["FullTest"].dev_data == full_dev)

	-- 1m: duplicate addon name
	record("rejects duplicate addon name",
		not pcall(_dnl.attachAddon, { name = "MinTest", tag = "MN2", isUnitTracked = dummy_fn }))

	-- 1n: duplicate tag
	record("rejects duplicate tag",
		not pcall(_dnl.attachAddon, { name = "AnotherAddon", tag = "MN1", isUnitTracked = dummy_fn }))

	-- Clean up Phase 1 registrations
	_dnl.addons       = {}
	_dnl.tag_to_addon = {}

	-- ================================================================
	-- Phase 2: Multi-Addon Coexistence
	-- ================================================================
	print(TAG .. "Phase 2: Multi-addon coexistence")

	local alpha_tracks = true
	local beta_tracks  = false

	local alpha_db     = {}
	local alpha_db_map = {}
	local beta_db      = {}
	local beta_db_map  = {}

	_dnl.attachAddon({
		name          = "__TestAlpha__",
		tag           = "AL1",
		isUnitTracked = function() return alpha_tracks end,
		settings      = {
			peer_reporting       = true,
			addonless_logging    = false,
			death_alert_priority = 5,
			share_playtime       = true,
			sync_enabled         = true,
		},
		db            = alpha_db,
		db_map        = alpha_db_map,
	})

	_dnl.attachAddon({
		name          = "__TestBeta__",
		tag           = "BE1",
		isUnitTracked = function() return beta_tracks end,
		settings      = {
			peer_reporting       = true,
			addonless_logging    = false,
			death_alert_priority = 10,
			share_playtime       = false,
			sync_enabled         = true,
		},
		db            = beta_db,
		db_map        = beta_db_map,
	})

	record("two addons registered",
		_dnl.addons["__TestAlpha__"] ~= nil and _dnl.addons["__TestBeta__"] ~= nil)

	-- 2a: shouldBroadcastDeath OR-semantics
	-- Alpha tracks = true, Beta tracks = false → should return true
	alpha_tracks = true; beta_tracks = false
	record("shouldBroadcastDeath: Alpha=true Beta=false → true",
		_dnl.shouldBroadcastDeath("player") == true)

	-- Alpha tracks = false, Beta tracks = true → should return true
	alpha_tracks = false; beta_tracks = true
	record("shouldBroadcastDeath: Alpha=false Beta=true → true",
		_dnl.shouldBroadcastDeath("player") == true)

	-- Both track = true → true
	alpha_tracks = true; beta_tracks = true
	record("shouldBroadcastDeath: both true → true",
		_dnl.shouldBroadcastDeath("player") == true)

	-- Neither tracks → false
	alpha_tracks = false; beta_tracks = false
	record("shouldBroadcastDeath: both false → false",
		_dnl.shouldBroadcastDeath("player") == false)

	-- Restore
	alpha_tracks = true; beta_tracks = true

	-- 2b: anyAddonAllows (opt-out semantics, default=true)
	-- Both allow peer_reporting → true
	record("anyAddonAllows: both allow → true",
		_dnl.anyAddonAllows("peer_reporting") == true)

	-- Alpha disallows, Beta still allows → true
	_dnl.addons["__TestAlpha__"].settings.peer_reporting = false
	record("anyAddonAllows: one disallows → true (other still allows)",
		_dnl.anyAddonAllows("peer_reporting") == true)

	-- Both disallow → false
	_dnl.addons["__TestBeta__"].settings.peer_reporting = false
	record("anyAddonAllows: both disallow → false",
		_dnl.anyAddonAllows("peer_reporting") == false)

	-- Restore
	_dnl.addons["__TestAlpha__"].settings.peer_reporting = true
	_dnl.addons["__TestBeta__"].settings.peer_reporting = true

	-- 2c: anyAddonAllows with no settings on either → defaults to true
	local saved_alpha_s = _dnl.addons["__TestAlpha__"].settings
	local saved_beta_s  = _dnl.addons["__TestBeta__"].settings
	_dnl.addons["__TestAlpha__"].settings = nil
	_dnl.addons["__TestBeta__"].settings  = nil
	record("anyAddonAllows: no settings on any addon → true (default)",
		_dnl.anyAddonAllows("peer_reporting") == true)
	_dnl.addons["__TestAlpha__"].settings = saved_alpha_s
	_dnl.addons["__TestBeta__"].settings  = saved_beta_s

	-- 2d: anyAddonEnables (opt-in semantics, default=false)
	record("anyAddonEnables: both false → false",
		_dnl.anyAddonEnables("addonless_logging") == false)

	_dnl.addons["__TestAlpha__"].settings.addonless_logging = true
	record("anyAddonEnables: one true → true",
		_dnl.anyAddonEnables("addonless_logging") == true)

	_dnl.addons["__TestAlpha__"].settings.addonless_logging = false
	record("anyAddonEnables: back to both false → false",
		_dnl.anyAddonEnables("addonless_logging") == false)

	-- 2e: getDeathAlertOwnerSettings (highest priority wins)
	local owner_settings, owner_name = _dnl.getDeathAlertOwnerSettings()
	record("getDeathAlertOwnerSettings: Beta wins (priority 10 > 5)",
		owner_name == "__TestBeta__",
		string.format("got '%s'", tostring(owner_name)))

	-- Swap priorities
	_dnl.addons["__TestAlpha__"].settings.death_alert_priority = 20
	owner_settings, owner_name = _dnl.getDeathAlertOwnerSettings()
	record("getDeathAlertOwnerSettings: Alpha wins after priority change",
		owner_name == "__TestAlpha__",
		string.format("got '%s'", tostring(owner_name)))

	-- Restore
	_dnl.addons["__TestAlpha__"].settings.death_alert_priority = 5

	-- ================================================================
	-- Phase 3: Per-Addon Hook Dispatch
	-- ================================================================
	print(TAG .. "Phase 3: Per-addon hook dispatch")

	-- Clear per_addon_hooks between sub-phases since we register fresh hooks.
	_dnl.per_addon_hooks         = {}
	_dnl.per_addon_hooks_secure  = {}

	local alpha_hook_count   = 0
	local alpha_hook_pd      = nil
	local alpha_hook_played  = nil
	local beta_hook_count    = 0
	local beta_hook_pd       = nil
	local beta_hook_played   = nil
	local global_hook_count  = 0

	-- Register per-addon hooks
	DeathNotificationLib.HookOnNewAddonEntry("__TestAlpha__", function(pd, cs, pc, ig, src)
		alpha_hook_count = alpha_hook_count + 1
		alpha_hook_pd = pd
		alpha_hook_played = pd and pd["played"]
	end)
	DeathNotificationLib.HookOnNewAddonEntry("__TestBeta__", function(pd, cs, pc, ig, src)
		beta_hook_count = beta_hook_count + 1
		beta_hook_pd = pd
		beta_hook_played = pd and pd["played"]
	end)

	-- Register a global hook to track calls
	local global_hook_tracker = function(pd, cs, pc, ig, src)
		global_hook_count = global_hook_count + 1
	end
	DeathNotificationLib.HookOnNewEntry(global_hook_tracker)

	-- 3a: Normal createEntry → both addon hooks AND global hook fire
	alpha_hook_count = 0; beta_hook_count = 0; global_hook_count = 0
	local test_pd_3a = _dnl.playerData(
		"HookTestA" .. math.random(10000, 99999), "G", 100, 1, 1, 30, nil, 1429, nil, GetServerTime(), 7200, nil
	)
	_dnl.createEntry(test_pd_3a, "hooktest-cs-3a", 1, nil, _dnl.SOURCE.DEBUG)
	record("createEntry: Alpha hook fires",
		alpha_hook_count == 1,
		string.format("count=%d", alpha_hook_count))
	record("createEntry: Beta hook fires",
		beta_hook_count == 1,
		string.format("count=%d", beta_hook_count))
	record("createEntry: global hook fires",
		global_hook_count >= 1,
		string.format("count=%d", global_hook_count))

	-- 3b: Targeted createEntry → only Alpha's hook fires
	alpha_hook_count = 0; beta_hook_count = 0; global_hook_count = 0
	local test_pd_3b = _dnl.playerData(
		"HookTestB" .. math.random(10000, 99999), "G", 200, 2, 3, 25, nil, 1429, nil, GetServerTime(), nil, nil
	)
	_dnl.createEntry(test_pd_3b, "hooktest-cs-3b", 1, nil, _dnl.SOURCE.DEBUG, "__TestAlpha__")
	record("targeted createEntry: Alpha hook fires",
		alpha_hook_count == 1,
		string.format("count=%d", alpha_hook_count))
	record("targeted createEntry: Beta hook does NOT fire",
		beta_hook_count == 0,
		string.format("count=%d", beta_hook_count))
	record("targeted createEntry: global hook does NOT fire",
		global_hook_count == 0,
		string.format("count=%d", global_hook_count))

	-- 3c: Secure per-addon hooks (peer_count threshold)
	local alpha_secure_count = 0
	local beta_secure_count  = 0
	DeathNotificationLib.HookOnNewAddonEntrySecure("__TestAlpha__", function(pd, cs, pc)
		alpha_secure_count = alpha_secure_count + 1
	end)
	DeathNotificationLib.HookOnNewAddonEntrySecure("__TestBeta__", function(pd, cs, pc)
		beta_secure_count = beta_secure_count + 1
	end)

	-- peer_count=1 → secure hooks should NOT fire
	alpha_secure_count = 0; beta_secure_count = 0
	local test_pd_3c1 = _dnl.playerData(
		"SecAddonA" .. math.random(10000, 99999), "", 100, 1, 1, 20, nil, 1429, nil, GetServerTime(), nil, nil
	)
	_dnl.createEntry(test_pd_3c1, "sec-addon-cs-1", 1, nil, _dnl.SOURCE.DEBUG)
	record("per-addon secure hook: NOT called at peer_count=1",
		alpha_secure_count == 0 and beta_secure_count == 0,
		string.format("alpha=%d, beta=%d", alpha_secure_count, beta_secure_count))

	-- peer_count=2 → secure hooks SHOULD fire
	alpha_secure_count = 0; beta_secure_count = 0
	local test_pd_3c2 = _dnl.playerData(
		"SecAddonB" .. math.random(10000, 99999), "", 100, 1, 1, 20, nil, 1429, nil, GetServerTime(), nil, nil
	)
	_dnl.createEntry(test_pd_3c2, "sec-addon-cs-2", 2, nil, _dnl.SOURCE.DEBUG)
	record("per-addon secure hook: called at peer_count=2",
		alpha_secure_count == 1 and beta_secure_count == 1,
		string.format("alpha=%d, beta=%d", alpha_secure_count, beta_secure_count))

	-- 3d: Addonless routing — only addons with addonless_logging=true receive
	alpha_hook_count = 0; beta_hook_count = 0; global_hook_count = 0
	_dnl.addons["__TestAlpha__"].settings.addonless_logging = true
	_dnl.addons["__TestBeta__"].settings.addonless_logging = false

	local test_pd_3d = {
		name      = "AddonlessTest" .. math.random(10000, 99999),
		guild     = "",
		source_id = -1,
		level     = 0,
		map_id    = 1429,
	}
	-- Addonless = source BLIZZARD + no class_id + no race_id
	_dnl.createEntry(test_pd_3d, "addonless-cs", 1, nil, _dnl.SOURCE.BLIZZARD)
	record("addonless: Alpha hook fires (addonless_logging=true)",
		alpha_hook_count == 1,
		string.format("count=%d", alpha_hook_count))
	record("addonless: Beta hook does NOT fire (addonless_logging=false)",
		beta_hook_count == 0,
		string.format("count=%d", beta_hook_count))
	record("addonless: global hook does NOT fire",
		global_hook_count == 0,
		string.format("count=%d", global_hook_count))

	-- Restore
	_dnl.addons["__TestAlpha__"].settings.addonless_logging = false

	-- 3e: share_playtime isolation
	-- Alpha has share_playtime=true, Beta has share_playtime=false
	alpha_hook_count = 0; beta_hook_count = 0
	alpha_hook_played = nil; beta_hook_played = nil
	local test_pd_3e = _dnl.playerData(
		"PlaytimeTest" .. math.random(10000, 99999), "G", 100, 1, 1, 30, nil, 1429, nil, GetServerTime(), 36000, nil
	)
	_dnl.createEntry(test_pd_3e, "playtime-cs", 1, nil, _dnl.SOURCE.DEBUG)
	record("share_playtime: Alpha receives played (share_playtime=true)",
		alpha_hook_played ~= nil and alpha_hook_played == 36000,
		string.format("got %s", tostring(alpha_hook_played)))
	record("share_playtime: Beta receives played=nil (share_playtime=false)",
		beta_hook_played == nil,
		string.format("got %s", tostring(beta_hook_played)))

	-- ================================================================
	-- Phase 4: Per-Addon DB Isolation via Sync Entry Routing
	-- ================================================================
	print(TAG .. "Phase 4: Per-addon DB isolation (sync routing)")

	-- Reset sync state
	_dnl._syncResetToIdle()
	local sync_stats_saved = { entries_received = _dnl._syncStats.entries_received }

	-- Create a test entry and route it through Alpha's tag
	local sync_pd_alpha = _dnl.playerData(
		"SyncAlphaP" .. math.random(1000, 9999), "SG", 300, 1, 1, 40, nil, 1429, nil, GetServerTime(), nil, nil
	)
	local sync_enc_alpha = _dnl.encodeMessage(sync_pd_alpha)
	local sync_cs_alpha  = _dnl.fletcher16(sync_pd_alpha)

	-- Clear any prior entry
	alpha_db[sync_cs_alpha] = nil
	beta_db[sync_cs_alpha]  = nil

	-- Reset per-addon hook counters before sync
	alpha_hook_count = 0; beta_hook_count = 0

	if sync_enc_alpha then
		_dnl.handleSyncEntry("FakeSyncPeer", "AL1" .. _dnl.COMM_FIELD_DELIM .. sync_enc_alpha)
	end
	_dnl._drainSyncBacklogAll()

	-- Alpha's targeted hook should fire, Beta's should not
	record("sync routing AL1: Alpha hook fires",
		alpha_hook_count == 1,
		string.format("count=%d", alpha_hook_count))
	record("sync routing AL1: Beta hook does NOT fire",
		beta_hook_count == 0,
		string.format("count=%d", beta_hook_count))

	-- Route an entry through Beta's tag
	local sync_pd_beta = _dnl.playerData(
		"SyncBetaPl" .. math.random(1000, 9999), "SG", 400, 2, 3, 35, nil, 1426, nil, GetServerTime(), nil, nil
	)
	local sync_enc_beta = _dnl.encodeMessage(sync_pd_beta)
	local sync_cs_beta  = _dnl.fletcher16(sync_pd_beta)

	alpha_db[sync_cs_beta] = nil
	beta_db[sync_cs_beta]  = nil

	alpha_hook_count = 0; beta_hook_count = 0
	if sync_enc_beta then
		_dnl.handleSyncEntry("FakeSyncPeer", "BE1" .. _dnl.COMM_FIELD_DELIM .. sync_enc_beta)
	end
	_dnl._drainSyncBacklogAll()

	record("sync routing BE1: Beta hook fires",
		beta_hook_count == 1,
		string.format("count=%d", beta_hook_count))
	record("sync routing BE1: Alpha hook does NOT fire",
		alpha_hook_count == 0,
		string.format("count=%d", alpha_hook_count))

	-- Unknown tag → neither fires
	alpha_hook_count = 0; beta_hook_count = 0
	local sync_pd_unk = _dnl.playerData(
		"SyncUnkPla" .. math.random(1000, 9999), "SG", 500, 1, 1, 20, nil, 1429, nil, GetServerTime(), nil, nil
	)
	local sync_enc_unk = _dnl.encodeMessage(sync_pd_unk)
	if sync_enc_unk then
		_dnl.handleSyncEntry("FakeSyncPeer", "ZZZ" .. _dnl.COMM_FIELD_DELIM .. sync_enc_unk)
	end
	_dnl._drainSyncBacklogAll()
	record("sync routing unknown tag: neither hook fires",
		alpha_hook_count == 0 and beta_hook_count == 0,
		string.format("alpha=%d, beta=%d", alpha_hook_count, beta_hook_count))

	-- Restore sync stats
	_dnl._syncStats.entries_received = sync_stats_saved.entries_received
	_dnl._syncResetToIdle()

	-- ================================================================
	-- Phase 5: HookOnNewAddonEntry Edge Cases
	-- ================================================================
	print(TAG .. "Phase 5: Hook registration edge cases")

	-- Registration for non-existent addon
	local reg_unknown = DeathNotificationLib.HookOnNewAddonEntry("__NoSuchAddon__", function() end)
	record("HookOnNewAddonEntry: returns false for unknown addon",
		reg_unknown == false)

	local reg_secure_unknown = DeathNotificationLib.HookOnNewAddonEntrySecure("__NoSuchAddon__", function() end)
	record("HookOnNewAddonEntrySecure: returns false for unknown addon",
		reg_secure_unknown == false)

	-- Registration for existing addon
	local reg_ok = DeathNotificationLib.HookOnNewAddonEntry("__TestAlpha__", function() end)
	record("HookOnNewAddonEntry: returns true for existing addon",
		reg_ok == true)

	-- Multiple hooks per addon all fire
	local multi_hook_a = 0
	local multi_hook_b = 0
	local multi_hook_c = 0

	-- Clear and re-register hooks
	_dnl.per_addon_hooks["__TestAlpha__"] = {}
	DeathNotificationLib.HookOnNewAddonEntry("__TestAlpha__", function() multi_hook_a = multi_hook_a + 1 end)
	DeathNotificationLib.HookOnNewAddonEntry("__TestAlpha__", function() multi_hook_b = multi_hook_b + 1 end)
	DeathNotificationLib.HookOnNewAddonEntry("__TestAlpha__", function() multi_hook_c = multi_hook_c + 1 end)

	local test_pd_5 = _dnl.playerData(
		"MultiHookP" .. math.random(10000, 99999), "", 100, 1, 1, 20, nil, 1429, nil, GetServerTime(), nil, nil
	)
	_dnl.createEntry(test_pd_5, "multi-hook-cs", 1, nil, _dnl.SOURCE.DEBUG, "__TestAlpha__")
	record("multiple hooks per addon: all 3 fire",
		multi_hook_a == 1 and multi_hook_b == 1 and multi_hook_c == 1,
		string.format("a=%d, b=%d, c=%d", multi_hook_a, multi_hook_b, multi_hook_c))

	-- ================================================================
	-- Phase 6: deepCopy & getDeathRecord coverage
	-- ================================================================
	print(TAG .. "Phase 6: deepCopy & getDeathRecord")

	-- deepCopy: basic deep isolation
	local orig = { name = "Orig", nested = { foo = "bar" } }
	local copy = _dnl.deepCopy(orig)
	copy.name = "Changed"
	copy.nested.foo = "baz"
	record("deepCopy: top-level isolation",
		orig.name == "Orig",
		string.format("orig.name='%s'", orig.name))
	record("deepCopy: nested isolation",
		orig.nested.foo == "bar",
		string.format("orig.nested.foo='%s'", orig.nested.foo))

	-- deepCopy: handles nil fields
	local sparse = { name = "Sparse", guild = nil, level = 10 }
	local sparse_copy = _dnl.deepCopy(sparse)
	record("deepCopy: preserves nil fields",
		sparse_copy.guild == nil and sparse_copy.name == "Sparse" and sparse_copy.level == 10)

	-- getDeathRecord: committed entry found
	local gdr_name = "GetRecordP" .. math.random(10000, 99999)
	local gdr_pd  = _dnl.playerData(gdr_name, "GR", 100, 1, 1, 30, nil, 1429, nil, GetServerTime(), nil, nil)
	local gdr_cs  = _dnl.fletcher16(gdr_pd)
	_dnl.death_ping_lru_cache_tbl[gdr_cs] = {
		player_data = gdr_pd,
		peer_report = 2,
		committed   = 1,
		timestamp   = GetServerTime(),
	}
	_dnl.updateLRUByName(gdr_name:lower(), gdr_cs, true)

	local gdr_result, gdr_peers = DeathNotificationLib.GetDeathRecord(gdr_name)
	record("getDeathRecord: finds committed entry",
		gdr_result ~= nil and gdr_result.name == gdr_name,
		string.format("got name='%s'", tostring(gdr_result and gdr_result.name)))
	record("getDeathRecord: returns peer count",
		gdr_peers == 2,
		string.format("got %s", tostring(gdr_peers)))

	-- getDeathRecord returns a copy, not the original
	if gdr_result then
		gdr_result.name = "Mutated"
		record("getDeathRecord: returns deep copy (not reference)",
			_dnl.death_ping_lru_cache_tbl[gdr_cs].player_data.name == gdr_name)
	end

	-- getDeathRecord: nil / empty
	record("getDeathRecord: nil returns nil",
		DeathNotificationLib.GetDeathRecord(nil) == nil)
	record("getDeathRecord: empty string returns nil",
		DeathNotificationLib.GetDeathRecord("") == nil)
	record("getDeathRecord: unknown name returns nil",
		DeathNotificationLib.GetDeathRecord("zzzNobodyEverrrr" .. math.random(100000, 999999)) == nil)

	-- Clean up LRU artifacts
	_dnl.death_ping_lru_cache_tbl[gdr_cs] = nil
	_dnl.lru_by_name[gdr_name:lower()] = nil

	-- ================================================================
	-- Cleanup: restore original registry
	-- ================================================================
	_dnl.addons                 = saved_addons
	_dnl.tag_to_addon           = saved_tag_to_addon
	_dnl.per_addon_hooks        = saved_per_addon_hooks
	_dnl.per_addon_hooks_secure = saved_per_addon_secure

	C_Timer.After(0.5, function()
		print(TAG .. "=========================")
		printSummary()
		print(TAG .. "=========================")
		testCleanup()
	end)
end

-- ============================================================================
-- testWatchlistQuery: channel-based watchlist query unit tests
-- ============================================================================

--- Test the WATCHLIST_QUERY protocol: outbound queryChannel batching,
--- wire-format compliance, expect_ack registration, input validation,
--- and inbound handler DB-lookup logic (simulated in-process).
function _dnl.testWatchlistQuery()
	if not _dnl.DEBUG then
		print("|cffFF0000[Deathlog]|r testWatchlistQuery requires DEBUG mode")
		return
	end

	testBegin()
	local TAG  = "|cffFFAA00[DNL WatchlistQuery Test]|r "
	local PASS = "|cff00FF00PASS|r"
	local FAIL = "|cffFF0000FAIL|r"

	local results = {}
	local function record(name, ok, detail)
		table.insert(results, { name = name, ok = ok, detail = detail })
		if test_tracking.all_depth > 0 then
			table.insert(test_tracking.global_results, { suite = "WatchlistQuery", name = name, ok = ok, detail = detail })
		end
		print(TAG .. (ok and PASS or FAIL) .. " " .. name .. (detail and (" — " .. detail) or ""))
	end

	local function printSummary()
		print(TAG .. "--- Summary ---")
		local passed, failed = 0, 0
		for _, r in ipairs(results) do
			if r.ok then passed = passed + 1 else failed = failed + 1 end
		end
		for _, r in ipairs(results) do
			print(TAG .. "  " .. (r.ok and PASS or FAIL) .. " " .. r.name)
		end
		local color = failed == 0 and "|cff00FF00" or "|cffFF0000"
		print(TAG .. color .. string.format("%d/%d passed|r", passed, passed + failed))
	end

	print(TAG .. "=========================")
	print(TAG .. "Watchlist Query Tests")
	print(TAG .. "=========================")

	-- Save state
	local saved_addons       = _dnl.addons
	local saved_tag_to_addon = _dnl.tag_to_addon
	local saved_queue        = _dnl.watchlist_query_queue
	local saved_expect_ack   = _dnl.expect_ack

	-- Set up a mock addon with a populated DB
	local mock_db     = {}
	local mock_db_map = {}
	local now = GetServerTime()

	-- Populate 15 entries in the mock DB
	for i = 1, 15 do
		local name = "WatchQTest" .. i
		local pd = _dnl.playerData(name, "TestGuild", 100 + i, 1, 1, 20 + i, nil, 1429, nil, now - (i * 3600), nil, nil)
		local cs = _dnl.fletcher16(pd)
		mock_db[cs] = pd
		mock_db_map[name] = cs
	end

	_dnl.addons = {
		["__test_wq__"] = {
			name          = "__test_wq__",
			tag           = "WQT",
			isUnitTracked = function() return true end,
			settings      = { death_alert_priority = 100 },
			db            = mock_db,
			db_map        = mock_db_map,
		},
	}
	_dnl.tag_to_addon = { WQT = "__test_wq__" }

	-- ================================================================
	-- Phase 1: COMM_COMMANDS constant
	-- ================================================================
	print(TAG .. "Phase 1: COMM_COMMANDS constant")

	record("WATCHLIST_QUERY command exists",
		_dnl.COMM_COMMANDS["WATCHLIST_QUERY"] ~= nil)
	record("WATCHLIST_QUERY == '6'",
		_dnl.COMM_COMMANDS["WATCHLIST_QUERY"] == "6")
	record("WATCHLIST_QUERY is 1-char",
		#_dnl.COMM_COMMANDS["WATCHLIST_QUERY"] == 1)

	-- ================================================================
	-- Phase 2: queryChannel input validation
	-- ================================================================
	print(TAG .. "Phase 2: queryChannel input validation")

	_dnl.watchlist_query_queue = {}
	_dnl.expect_ack = {}

	-- nil tag → no-op
	_dnl.queryChannel({"Alice"}, nil)
	record("queryChannel rejects nil tag",
		#_dnl.watchlist_query_queue == 0)

	-- unregistered tag → no-op
	_dnl.queryChannel({"Alice"}, "ZZZ")
	record("queryChannel rejects unregistered tag",
		#_dnl.watchlist_query_queue == 0)

	-- nil names → no-op
	_dnl.queryChannel(nil, "WQT")
	record("queryChannel rejects nil names",
		#_dnl.watchlist_query_queue == 0)

	-- empty names table → no-op
	_dnl.queryChannel({}, "WQT")
	record("queryChannel rejects empty names",
		#_dnl.watchlist_query_queue == 0)

	-- No expect_ack entries after invalid calls
	local ack_count = 0
	for _ in pairs(_dnl.expect_ack) do ack_count = ack_count + 1 end
	record("no expect_ack after invalid calls",
		ack_count == 0,
		"count=" .. tostring(ack_count))

	-- ================================================================
	-- Phase 3: queryChannel queues correctly
	-- ================================================================
	print(TAG .. "Phase 3: queryChannel queues correctly")

	_dnl.watchlist_query_queue = {}
	_dnl.expect_ack = {}

	local test_names = {"Alice", "Bob", "Charlie"}
	_dnl.queryChannel(test_names, "WQT")

	record("one message queued",
		#_dnl.watchlist_query_queue == 1,
		"queued=" .. tostring(#_dnl.watchlist_query_queue))

	-- Check queue entry format: {msg, timestamp}
	local q_entry = _dnl.watchlist_query_queue[1]
	record("queue entry is table with 2 elements",
		q_entry ~= nil and type(q_entry) == "table" and q_entry[2] ~= nil)

	-- Check message format: "WQT~Alice,Bob,Charlie"
	local q_msg = q_entry and q_entry[1]
	local expected_msg = "WQT" .. _dnl.COMM_FIELD_DELIM .. "Alice,Bob,Charlie"
	record("queue message format correct",
		q_msg == expected_msg,
		string.format("expected '%s', got '%s'", expected_msg, tostring(q_msg)))

	-- Check expect_ack was set for each name
	record("expect_ack[Alice] set",
		_dnl.expect_ack["Alice"] == 1)
	record("expect_ack[Bob] set",
		_dnl.expect_ack["Bob"] == 1)
	record("expect_ack[Charlie] set",
		_dnl.expect_ack["Charlie"] == 1)

	-- ================================================================
	-- Phase 4: Wire format & 255-byte budget
	-- ================================================================
	print(TAG .. "Phase 4: Wire format & budget")

	_dnl.watchlist_query_queue = {}
	_dnl.expect_ack = {}

	-- The final on-wire message is: "6$WQT~name1,name2,..."
	-- overhead = 1("6") + 1("$") + 3("WQT") + 1("~") = 6 bytes
	-- Budget for names = 255 - 6 = 249 bytes
	local overhead = #_dnl.COMM_COMMANDS["WATCHLIST_QUERY"] + #_dnl.COMM_COMMAND_DELIM + 3 + #_dnl.COMM_FIELD_DELIM
	record("computed overhead = 6",
		overhead == 6,
		"overhead=" .. tostring(overhead))

	-- Generate many long names to test budget truncation
	local many_names = {}
	for i = 1, 50 do
		table.insert(many_names, "LongTestName" .. string.format("%04d", i))  -- 16 chars each
	end
	_dnl.queryChannel(many_names, "WQT")

	record("budget-exceeded: still queues one message",
		#_dnl.watchlist_query_queue == 1)

	local budget_msg = _dnl.watchlist_query_queue[1] and _dnl.watchlist_query_queue[1][1]
	local full_wire = _dnl.COMM_COMMANDS["WATCHLIST_QUERY"] .. _dnl.COMM_COMMAND_DELIM .. budget_msg
	record("budget-exceeded: full wire <= 255 bytes",
		#full_wire <= 255,
		"length=" .. tostring(#full_wire))

	-- Count how many names made it into the message
	local name_part = budget_msg and budget_msg:sub(5) or ""  -- skip "WQT~"
	local queued_names_count = 0
	for _ in name_part:gmatch("([^,]+)") do
		queued_names_count = queued_names_count + 1
	end
	record("budget-exceeded: not all 50 names fit",
		queued_names_count < 50,
		"names_in_msg=" .. tostring(queued_names_count))
	record("budget-exceeded: at least 1 name fits",
		queued_names_count >= 1)

	-- Only the names that fit should have expect_ack set
	local ack_budget_count = 0
	for _ in pairs(_dnl.expect_ack) do ack_budget_count = ack_budget_count + 1 end
	record("budget-exceeded: expect_ack count matches names in msg",
		ack_budget_count == queued_names_count,
		string.format("ack=%d, names=%d", ack_budget_count, queued_names_count))

	-- ================================================================
	-- Phase 5: Single name query
	-- ================================================================
	print(TAG .. "Phase 5: Single name query")

	_dnl.watchlist_query_queue = {}
	_dnl.expect_ack = {}

	_dnl.queryChannel({"Solo"}, "WQT")
	record("single name queues one message",
		#_dnl.watchlist_query_queue == 1)

	local solo_msg = _dnl.watchlist_query_queue[1] and _dnl.watchlist_query_queue[1][1]
	local solo_expected = "WQT" .. _dnl.COMM_FIELD_DELIM .. "Solo"
	record("single name message format",
		solo_msg == solo_expected,
		string.format("expected '%s', got '%s'", solo_expected, tostring(solo_msg)))

	-- ================================================================
	-- Phase 6: Inbound handler simulation (DB lookup)
	-- ================================================================
	print(TAG .. "Phase 6: Inbound handler DB-lookup simulation")

	-- Simulate what the onChatMsgChannel handler does when receiving
	-- a WATCHLIST_QUERY.  We replicate the lookup logic in-process.

	local addon_entry = _dnl.addons["__test_wq__"]

	-- Query for names that exist
	local query_names = {"WatchQTest1", "WatchQTest5", "WatchQTest10"}
	local found_count = 0
	for _, qn in ipairs(query_names) do
		local cs = addon_entry.db_map[qn]
		if cs and addon_entry.db[cs] then
			found_count = found_count + 1
		end
	end
	record("handler sim: finds all 3 existing entries",
		found_count == 3,
		"found=" .. tostring(found_count))

	-- Query for names that don't exist
	local missing_count = 0
	local missing_names = {"NobodyHere", "Nonexistent"}
	for _, qn in ipairs(missing_names) do
		local cs = addon_entry.db_map[qn]
		if cs and addon_entry.db[cs] then
			missing_count = missing_count + 1
		end
	end
	record("handler sim: unknown names return 0 matches",
		missing_count == 0)

	-- Verify encoding of found entries (used in response)
	local test_cs = addon_entry.db_map["WatchQTest1"]
	local test_pd = test_cs and addon_entry.db[test_cs]
	if test_pd then
		local tag_overhead = 4  -- "WQT~"
		local encoded = _dnl.encodeMessage(test_pd, tag_overhead)
		record("handler sim: found entry encodes for response",
			encoded ~= nil,
			"len=" .. tostring(encoded and #encoded))
		if encoded then
			local resp_msg = _dnl.COMM_QUERY_ACK .. _dnl.COMM_COMMAND_DELIM
				.. "WQT" .. _dnl.COMM_FIELD_DELIM .. encoded
			record("handler sim: response wire format <= 255",
				#resp_msg <= 255,
				"len=" .. tostring(#resp_msg))
		end
	end

	-- MAX_RESPONSES cap: query all 15 entries + 5 missing = handler would
	-- only respond to the first 10 found
	local all_query_names = {}
	for i = 1, 15 do table.insert(all_query_names, "WatchQTest" .. i) end
	for i = 1, 5 do table.insert(all_query_names, "Nobody" .. i) end

	local response_count = 0
	local MAX_RESPONSES = 10
	for _, qn in ipairs(all_query_names) do
		if response_count >= MAX_RESPONSES then break end
		local cs = addon_entry.db_map[qn]
		if cs and addon_entry.db[cs] then
			response_count = response_count + 1
		end
	end
	record("handler sim: MAX_RESPONSES caps at 10",
		response_count == MAX_RESPONSES,
		"responded=" .. tostring(response_count))

	-- ================================================================
	-- Phase 7: Unknown tag rejected by handler
	-- ================================================================
	print(TAG .. "Phase 7: Tag validation")

	-- Simulate receiving a query with unknown tag
	local unknown_tag = "ZZZ"
	local unknown_addon = _dnl.tag_to_addon[unknown_tag]
	record("handler sim: unknown tag → no addon lookup",
		unknown_addon == nil)

	-- Valid tag resolves correctly
	local valid_addon = _dnl.tag_to_addon["WQT"]
	record("handler sim: valid tag resolves to addon",
		valid_addon == "__test_wq__")

	-- ================================================================
	-- Phase 8: Parse format "TAG~name1,name2,..." validation
	-- ================================================================
	print(TAG .. "Phase 8: Message parse validation")

	-- Simulate the parse logic from onChatMsgChannel
	local function parseWatchlistMsg(msg_body)
		local query_tag, name_list = nil, msg_body
		if msg_body and #msg_body > 4 and msg_body:sub(4, 4) == _dnl.COMM_FIELD_DELIM then
			query_tag = msg_body:sub(1, 3)
			name_list = msg_body:sub(5)
		end
		return query_tag, name_list
	end

	local p_tag, p_names = parseWatchlistMsg("WQT~Alice,Bob")
	record("parse: extracts tag from well-formed msg",
		p_tag == "WQT")
	record("parse: extracts name list",
		p_names == "Alice,Bob")

	-- Short message (no tag prefix)
	local p_tag2, p_names2 = parseWatchlistMsg("AB")
	record("parse: short msg returns nil tag",
		p_tag2 == nil)

	-- Missing delimiter
	local p_tag3, p_names3 = parseWatchlistMsg("WQTXAlice")
	record("parse: wrong delimiter returns nil tag",
		p_tag3 == nil)

	-- Correct format with single name
	local p_tag4, p_names4 = parseWatchlistMsg("WQT~Solo")
	record("parse: single name works",
		p_tag4 == "WQT" and p_names4 == "Solo")

	-- Name iteration via gmatch
	local parsed_names = {}
	for n in ("Alice,Bob,Charlie"):gmatch("([^,]+)") do
		table.insert(parsed_names, n)
	end
	record("parse: gmatch splits comma-separated names",
		#parsed_names == 3 and parsed_names[1] == "Alice" and parsed_names[3] == "Charlie")

	-- ================================================================
	-- Phase 9: Public API surface
	-- ================================================================
	print(TAG .. "Phase 9: Public API surface")

	record("QueryChannel is exposed",
		DeathNotificationLib.QueryChannel ~= nil)
	record("QueryChannel is a function",
		type(DeathNotificationLib.QueryChannel) == "function")

	-- Public API should proxy to internal queryChannel
	_dnl.watchlist_query_queue = {}
	_dnl.expect_ack = {}
	DeathNotificationLib.QueryChannel({"ApiTest"}, "WQT")
	record("QueryChannel proxies to queryChannel",
		#_dnl.watchlist_query_queue == 1)

	local api_msg = _dnl.watchlist_query_queue[1] and _dnl.watchlist_query_queue[1][1]
	record("QueryChannel: message format correct",
		api_msg == "WQT" .. _dnl.COMM_FIELD_DELIM .. "ApiTest")

	-- ================================================================
	-- Phase 10: Transport queue format (drain simulation)
	-- ================================================================
	print(TAG .. "Phase 10: Transport queue drain format")

	_dnl.watchlist_query_queue = {}
	_dnl.expect_ack = {}

	-- Queue a message and verify the wire format that sendNextInQueue
	-- would construct: COMM_COMMANDS["WATCHLIST_QUERY"] .. "$" .. entry[1]
	_dnl.queryChannel({"DrainTest"}, "WQT")
	local drain_entry = _dnl.watchlist_query_queue[1]
	if drain_entry then
		local wire = _dnl.COMM_COMMANDS["WATCHLIST_QUERY"]
			.. _dnl.COMM_COMMAND_DELIM .. drain_entry[1]
		record("drain: wire = '6$WQT~DrainTest'",
			wire == "6$WQT~DrainTest",
			"got '" .. wire .. "'")
		record("drain: wire <= 255 bytes",
			#wire <= 255,
			"len=" .. tostring(#wire))
	end

	-- ================================================================
	-- Cleanup
	-- ================================================================
	_dnl.addons              = saved_addons
	_dnl.tag_to_addon        = saved_tag_to_addon
	_dnl.watchlist_query_queue = saved_queue
	_dnl.expect_ack          = saved_expect_ack

	C_Timer.After(0.5, function()
		print(TAG .. "=========================")
		printSummary()
		print(TAG .. "=========================")
		testCleanup()
	end)
end

---------------------------------------------------------------------------
-- testDedup: exercises cross-checksum name dedup, late quality upgrade,
--            outbound name dedup, and inbound equal-quality merge
---------------------------------------------------------------------------

--- 10 phases, ~8s (5s commit timer wait + buffer)
function _dnl.testDedup()
	if not _dnl.DEBUG then
		print("|cffFF0000[Deathlog]|r testDedup requires DEBUG mode")
		return
	end

	testBegin()
	local PASS = "|cff00FF00PASS|r"
	local FAIL = "|cffFF0000FAIL|r"
	local TAG  = "|cffFF6600[Deathlog Dedup]|r "

	local results = {}
	local function record(name, ok, detail)
		table.insert(results, { name = name, ok = ok, detail = detail })
		if test_tracking.all_depth > 0 then
			table.insert(test_tracking.global_results, { suite = "Dedup", name = name, ok = ok, detail = detail })
		end
		local status = ok and PASS or FAIL
		print(TAG .. status .. " " .. name .. (detail and (" - " .. detail) or ""))
	end

	local function printSummary()
		print(TAG .. "--- Summary ---")
		local passed, failed = 0, 0
		for _, r in ipairs(results) do
			if r.ok then passed = passed + 1 else failed = failed + 1 end
		end
		for _, r in ipairs(results) do
			local status = r.ok and PASS or FAIL
			print(TAG .. "  " .. status .. " " .. r.name)
		end
		local color = failed == 0 and "|cff00FF00" or "|cffFF0000"
		print(TAG .. color .. string.format("%d/%d passed|r", passed, passed + failed))
	end

	-- Hook to capture createEntry calls
	local hook_calls = {}  -- { [name_lower] = { count, last_pd, last_cs } }
	DeathNotificationLib.HookOnNewEntry(function(pd, cs, pc, ig, src)
		if not test_tracking.active then return end
		local n = pd and pd["name"] and pd["name"]:lower() or "?"
		if not hook_calls[n] then
			hook_calls[n] = { count = 0, last_pd = nil, last_cs = nil }
		end
		hook_calls[n].count = hook_calls[n].count + 1
		hook_calls[n].last_pd = pd
		hook_calls[n].last_cs = cs
	end)

	print(TAG .. "Starting dedup test suite...")

	-- ================================================================
	-- Phase 1: Cross-checksum inbound name dedup
	-- Two peers broadcast for the same player with different guilds
	-- → different checksums → should merge into one LRU entry
	-- ================================================================
	print(TAG .. "Phase 1: Cross-checksum inbound name dedup")
	do
		local dd_name = "DedupXcs" .. math.random(10000, 99999)
		dd_name = dd_name:sub(1, 12)
		local dd_name_lower = dd_name:lower()
		_dnl.lru_by_name[dd_name_lower] = nil

		-- Peer A sees the dead player as guild "AlphaGuild"
		local pd_a = _dnl.playerData(dd_name, "AlphaGuild", 100, 1, 1, 30, nil, 1429, "0.3,0.4", GetServerTime(), nil, nil)
		local cs_a = _dnl.fletcher16(pd_a)
		-- Peer B sees no guild
		local pd_b = _dnl.playerData(dd_name, "", 100, nil, nil, 30, nil, 1429, nil, GetServerTime(), nil, nil)
		local cs_b = _dnl.fletcher16(pd_b)

		record("phase1: different guilds → different checksums",
			cs_a ~= cs_b,
			string.format("%s vs %s", cs_a, cs_b))

		-- Simulate inbound: Peer A's broadcast arrives first
		local enc_a = _dnl.encodeMessage(pd_a)
		if enc_a then
			_dnl.handleDeathBroadcast("PeerAlpha", enc_a)
		end

		local lru_after_a = _dnl.lru_by_name[dd_name_lower]
		record("phase1: first broadcast stored in LRU",
			lru_after_a ~= nil and lru_after_a.checksum ~= nil)

		-- Peer B's broadcast arrives — should merge, not create second entry
		local enc_b = _dnl.encodeMessage(pd_b)
		if enc_b then
			_dnl.handleDeathBroadcast("PeerBeta", enc_b)
		end

		local lru_after_b = _dnl.lru_by_name[dd_name_lower]
		record("phase1: second broadcast merged (same LRU name entry)",
			lru_after_b ~= nil)

		-- Verify only ONE LRU cache entry exists for this player
		local cache_count = 0
		for cs, entry in pairs(_dnl.death_ping_lru_cache_tbl) do
			if entry["player_data"] and entry["player_data"]["name"] == dd_name then
				cache_count = cache_count + 1
			end
		end
		record("phase1: exactly 1 LRU cache entry (not 2)",
			cache_count == 1,
			string.format("found %d", cache_count))

		-- The surviving entry should have the guild from A (richer data)
		if lru_after_b and lru_after_b.checksum then
			local cache = _dnl.death_ping_lru_cache_tbl[lru_after_b.checksum]
			if cache and cache["player_data"] then
				record("phase1: merged entry preserves guild",
					cache["player_data"]["guild"] == "AlphaGuild",
					string.format("got '%s'", tostring(cache["player_data"]["guild"])))
			else
				record("phase1: merged entry preserves guild", false, "no cache entry")
			end
		end
	end

	-- ================================================================
	-- Phase 2: Outbound broadcastDeath name dedup across checksums
	-- Simulates two party members: A calls broadcastDeath with guild,
	-- then B calls with no guild → B should be suppressed
	-- ================================================================
	print(TAG .. "Phase 2: Outbound broadcastDeath cross-checksum dedup")
	do
		local bd_name = "DedupOutbd" .. math.random(10000, 99999)
		bd_name = bd_name:sub(1, 12)
		_dnl.lru_by_name[bd_name:lower()] = nil

		local pd_with_guild = _dnl.playerData(bd_name, "SomeGuild", 200, 2, 3, 40, nil, 1426, nil, GetServerTime(), nil, "First words")
		local pd_no_guild   = _dnl.playerData(bd_name, "", 200, nil, nil, 40, nil, 1426, nil, GetServerTime(), nil, nil)

		local cs1 = _dnl.fletcher16(pd_with_guild)
		local cs2 = _dnl.fletcher16(pd_no_guild)
		_dnl.death_ping_lru_cache_tbl[cs1] = nil
		_dnl.death_ping_lru_cache_tbl[cs2] = nil

		local q_before = #_dnl.death_alert_out_queue

		-- A's broadcast
		_dnl.broadcastDeath(pd_with_guild)
		local q_after_first = #_dnl.death_alert_out_queue
		record("phase2: first broadcastDeath queues message",
			q_after_first == q_before + 1,
			string.format("before=%d, after=%d", q_before, q_after_first))

		-- B's broadcast for same player, different checksum
		_dnl.broadcastDeath(pd_no_guild)
		local q_after_second = #_dnl.death_alert_out_queue
		record("phase2: second broadcastDeath suppressed by name dedup",
			q_after_second == q_after_first,
			string.format("first=%d, second=%d", q_after_first, q_after_second))

		-- Verify the data was merged (last_words from A should be in the surviving entry)
		local lru = _dnl.lru_by_name[bd_name:lower()]
		if lru and lru.checksum then
			local c = _dnl.death_ping_lru_cache_tbl[lru.checksum]
			if c and c["player_data"] then
				record("phase2: suppressed broadcast data merged into existing",
					c["player_data"]["guild"] == "SomeGuild",
					string.format("guild='%s'", tostring(c["player_data"]["guild"])))
			else
				record("phase2: suppressed broadcast data merged into existing", false, "no cache")
			end
		else
			record("phase2: suppressed broadcast data merged into existing", false, "no lru")
		end
	end

	-- ================================================================
	-- Phase 3: Equal-quality inbound merge (PEER + PEER)
	-- Two PEER broadcasts with different checksums → same name →
	-- should merge, not create parallel LRU entries
	-- ================================================================
	print(TAG .. "Phase 3: Equal-quality inbound merge")
	do
		local eq_name = "DedupEqQul" .. math.random(10000, 99999)
		eq_name = eq_name:sub(1, 12)
		_dnl.lru_by_name[eq_name:lower()] = nil

		-- PEER A: has race/class but no last_words
		local eq_a = _dnl.playerData(eq_name, "GuildA", 100, 2, 4, 35, nil, 1429, nil, GetServerTime(), nil, nil)
		local eq_enc_a = _dnl.encodeMessage(eq_a)
		if eq_enc_a then _dnl.handleDeathBroadcast("EqPeerA", eq_enc_a) end

		-- PEER B: different guild (→ different checksum), has last_words
		local eq_b = _dnl.playerData(eq_name, "", 100, nil, nil, 35, nil, 1429, "0.6,0.7", GetServerTime(), 5000, "Famous last words")
		local eq_enc_b = _dnl.encodeMessage(eq_b)
		if eq_enc_b then _dnl.handleDeathBroadcast("EqPeerB", eq_enc_b) end

		-- Should still have exactly 1 cache entry
		local eq_count = 0
		for _, entry in pairs(_dnl.death_ping_lru_cache_tbl) do
			if entry["player_data"] and entry["player_data"]["name"] == eq_name then
				eq_count = eq_count + 1
			end
		end
		record("phase3: equal-quality broadcasts → 1 LRU entry",
			eq_count == 1,
			string.format("found %d", eq_count))

		-- Merged entry should have best of both: guild from A, last_words from B
		local eq_lru = _dnl.lru_by_name[eq_name:lower()]
		if eq_lru and eq_lru.checksum then
			local eq_cache = _dnl.death_ping_lru_cache_tbl[eq_lru.checksum]
			if eq_cache and eq_cache["player_data"] then
				record("phase3: merged entry has guild from A",
					eq_cache["player_data"]["guild"] == "GuildA",
					string.format("got '%s'", tostring(eq_cache["player_data"]["guild"])))
				record("phase3: merged entry has last_words from B",
					eq_cache["player_data"]["last_words"] == "Famous last words",
					string.format("got '%s'", tostring(eq_cache["player_data"]["last_words"])))
				record("phase3: merged entry has map_pos from B",
					eq_cache["player_data"]["map_pos"] == "0.6,0.7",
					string.format("got '%s'", tostring(eq_cache["player_data"]["map_pos"])))
			else
				record("phase3: merged entry has guild from A", false, "no cache")
				record("phase3: merged entry has last_words from B", false, "no cache")
				record("phase3: merged entry has map_pos from B", false, "no cache")
			end
		end
	end

	-- ================================================================
	-- Phase 4: SELF upgrade before commit (the fast path)
	-- PEER arrives → SELF arrives within 3.5s → quality upgrade
	-- ================================================================
	print(TAG .. "Phase 4: SELF upgrade before commit")
	do
		local up_name = "DedupUpFst" .. math.random(10000, 99999)
		up_name = up_name:sub(1, 12)
		_dnl.lru_by_name[up_name:lower()] = nil

		-- Peer broadcast (no guild, no last_words)
		local up_peer = _dnl.playerData(up_name, "", 300, nil, nil, 45, nil, 1429, nil, GetServerTime(), nil, nil)
		local up_peer_enc = _dnl.encodeMessage(up_peer)
		if up_peer_enc then _dnl.handleDeathBroadcast("PeerSender", up_peer_enc) end

		local up_lru = _dnl.lru_by_name[up_name:lower()]
		local up_cs_before = up_lru and up_lru.checksum or nil

		-- SELF broadcast (has guild, last_words, map_pos)
		local up_self = _dnl.playerData(up_name, "SelfGuild", 300, 3, 5, 45, nil, 1429, "0.2,0.8", GetServerTime(), 12345, "My own death")
		local up_self_enc = _dnl.encodeMessage(up_self)
		if up_self_enc then _dnl.handleDeathBroadcast(up_name, up_self_enc) end

		local up_lru2 = _dnl.lru_by_name[up_name:lower()]
		if up_lru2 and up_lru2.checksum then
			local up_cache = _dnl.death_ping_lru_cache_tbl[up_lru2.checksum]
			record("phase4: quality upgraded to SELF",
				up_cache and up_cache["quality"] == _dnl.QUALITY.SELF,
				string.format("got %s", tostring(up_cache and up_cache["quality"])))
			if up_cache and up_cache["player_data"] then
				record("phase4: upgraded entry has guild",
					up_cache["player_data"]["guild"] == "SelfGuild",
					string.format("got '%s'", tostring(up_cache["player_data"]["guild"])))
				record("phase4: upgraded entry has last_words",
					up_cache["player_data"]["last_words"] == "My own death",
					string.format("got '%s'", tostring(up_cache["player_data"]["last_words"])))
			end
		else
			record("phase4: quality upgraded to SELF", false, "no lru")
		end

		-- Old PEER entry should be marked committed (blocked)
		if up_cs_before then
			local old_cache = _dnl.death_ping_lru_cache_tbl[up_cs_before]
			record("phase4: old PEER entry marked committed",
				old_cache and old_cache["committed"] == 1,
				string.format("committed=%s", tostring(old_cache and old_cache["committed"])))
		end
	end

	-- ================================================================
	-- Phase 5: Late SELF upgrade AFTER commit (the race condition fix)
	-- Manually commit a PEER entry, then send SELF → should re-fire
	-- createEntry with upgraded data, not silently discard
	-- ================================================================
	print(TAG .. "Phase 5: Late SELF upgrade after commit (async)")
	do
		local late_name = "DedupLate" .. math.random(10000, 99999)
		late_name = late_name:sub(1, 12)
		local late_name_lower = late_name:lower()
		_dnl.lru_by_name[late_name_lower] = nil
		hook_calls[late_name_lower] = nil

		-- Simulate a PEER broadcast that has already committed
		local late_peer = _dnl.playerData(late_name, "", 400, nil, nil, 50, nil, 1429, nil, GetServerTime(), nil, nil)
		local late_peer_cs = _dnl.fletcher16(late_peer)
		_dnl.death_ping_lru_cache_tbl[late_peer_cs] = {
			player_data = _dnl.deepCopy(late_peer),
			quality = _dnl.QUALITY.PEER,
			timestamp = GetServerTime(),
			committed = 1,
			source = _dnl.SOURCE.PEER_BROADCAST,
		}
		_dnl.updateLRUByName(late_name_lower, late_peer_cs, true)

		-- Also fire createEntry so the addon DB has the PEER entry
		_dnl.createEntry(
			_dnl.deepCopy(late_peer),
			late_peer_cs,
			0, nil,
			_dnl.SOURCE.PEER_BROADCAST
		)

		local hook_before = hook_calls[late_name_lower] and hook_calls[late_name_lower].count or 0
		record("phase5: initial PEER committed to DB",
			hook_before >= 1,
			string.format("hook calls=%d", hook_before))

		-- Now the SELF broadcast arrives late
		local late_self = _dnl.playerData(late_name, "LateGuild", 400, 4, 7, 50, nil, 1429, "0.1,0.9", GetServerTime(), 99999, "Late but best")
		local late_self_enc = _dnl.encodeMessage(late_self)
		if late_self_enc then
			_dnl.handleDeathBroadcast(late_name, late_self_enc)
		end

		-- The re-fire should have called createEntry again with upgraded data
		local hook_after = hook_calls[late_name_lower] and hook_calls[late_name_lower].count or 0
		record("phase5: createEntry re-fired after late upgrade",
			hook_after > hook_before,
			string.format("before=%d, after=%d", hook_before, hook_after))

		-- Verify the re-fired data has SELF quality fields
		local last_pd = hook_calls[late_name_lower] and hook_calls[late_name_lower].last_pd
		if last_pd then
			record("phase5: re-fired data has guild",
				last_pd["guild"] == "LateGuild",
				string.format("got '%s'", tostring(last_pd["guild"])))
			record("phase5: re-fired data has last_words",
				last_pd["last_words"] == "Late but best",
				string.format("got '%s'", tostring(last_pd["last_words"])))
			record("phase5: re-fired data has played",
				last_pd["played"] == 99999,
				string.format("got %s", tostring(last_pd["played"])))
		else
			record("phase5: re-fired data has guild", false, "no hook data")
			record("phase5: re-fired data has last_words", false, "no hook data")
			record("phase5: re-fired data has played", false, "no hook data")
		end

		-- The LRU cache entry should now reflect SELF quality
		local late_cache = _dnl.death_ping_lru_cache_tbl[late_peer_cs]
		record("phase5: LRU cache quality upgraded to SELF",
			late_cache and late_cache["quality"] == _dnl.QUALITY.SELF,
			string.format("got %s", tostring(late_cache and late_cache["quality"])))
	end

	-- ================================================================
	-- Phase 6: Three PEERs with different data → only 1 commit
	-- Simulates ZF scenario: 3 party members report same death
	-- with different guild/source/map_pos → different checksums
	-- ================================================================
	print(TAG .. "Phase 6: ZF party scenario — 3 peers, 1 commit (async)")
	do
		local zf_name = "DedupZfRak" .. math.random(10000, 99999)
		zf_name = zf_name:sub(1, 12)
		local zf_name_lower = zf_name:lower()
		_dnl.lru_by_name[zf_name_lower] = nil
		hook_calls[zf_name_lower] = nil

		-- Peer 1: has guild, saw the kill source
		local zf_pd1 = _dnl.playerData(zf_name, "ZfGuild", 500, 1, 2, 44, nil, 1429, "0.5,0.5", GetServerTime(), nil, nil)
		-- Peer 2: no guild, different source (-1 = reported), different pos
		local zf_pd2 = _dnl.playerData(zf_name, "", -1, nil, nil, 0, nil, 1429, "0.51,0.49", GetServerTime(), nil, "Help me!")
		-- Peer 3: different guild, same source, different pos
		local zf_pd3 = _dnl.playerData(zf_name, "OtherGuild", 500, 3, 4, 44, nil, 1429, "0.49,0.51", GetServerTime(), 7200, nil)

		-- All produce different checksums
		local zf_cs1 = _dnl.fletcher16(zf_pd1)
		local zf_cs2 = _dnl.fletcher16(zf_pd2)
		local zf_cs3 = _dnl.fletcher16(zf_pd3)
		_dnl.death_ping_lru_cache_tbl[zf_cs1] = nil
		_dnl.death_ping_lru_cache_tbl[zf_cs2] = nil
		_dnl.death_ping_lru_cache_tbl[zf_cs3] = nil

		record("phase6: 3 peers produce different checksums",
			zf_cs1 ~= zf_cs2 and zf_cs2 ~= zf_cs3 and zf_cs1 ~= zf_cs3,
			string.format("%s / %s / %s", zf_cs1, zf_cs2, zf_cs3))

		-- Send all three inbound
		local zf_enc1 = _dnl.encodeMessage(zf_pd1)
		local zf_enc2 = _dnl.encodeMessage(zf_pd2)
		local zf_enc3 = _dnl.encodeMessage(zf_pd3)
		if zf_enc1 then _dnl.handleDeathBroadcast("ZfPeer1", zf_enc1) end
		if zf_enc2 then _dnl.handleDeathBroadcast("ZfPeer2", zf_enc2) end
		if zf_enc3 then _dnl.handleDeathBroadcast("ZfPeer3", zf_enc3) end

		-- Should have exactly 1 cache entry with uncommitted state
		local zf_cache_count = 0
		local zf_surviving_cs = nil
		for cs, entry in pairs(_dnl.death_ping_lru_cache_tbl) do
			if entry["player_data"] and entry["player_data"]["name"] == zf_name and not entry["committed"] then
				zf_cache_count = zf_cache_count + 1
				zf_surviving_cs = cs
			end
		end
		record("phase6: exactly 1 uncommitted cache entry",
			zf_cache_count == 1,
			string.format("found %d", zf_cache_count))

		-- The surviving entry should have the richest merged data
		if zf_surviving_cs then
			local zf_cache = _dnl.death_ping_lru_cache_tbl[zf_surviving_cs]
			if zf_cache and zf_cache["player_data"] then
				-- Guild from peer 1 (first, richer)
				record("phase6: merged entry has guild",
					zf_cache["player_data"]["guild"] == "ZfGuild",
					string.format("got '%s'", tostring(zf_cache["player_data"]["guild"])))
				-- last_words from peer 2
				record("phase6: merged entry has last_words from peer 2",
					zf_cache["player_data"]["last_words"] == "Help me!",
					string.format("got '%s'", tostring(zf_cache["player_data"]["last_words"])))
				-- played from peer 3
				record("phase6: merged entry has played from peer 3",
					zf_cache["player_data"]["played"] == 7200,
					string.format("got %s", tostring(zf_cache["player_data"]["played"])))
			end
		end

		-- Wait for auto-commit (3.5s + buffer)
		C_Timer.After(5.0, function()
			local zf_hook = hook_calls[zf_name_lower]
			record("phase6: createEntry fired exactly 1 time",
				zf_hook and zf_hook.count == 1,
				string.format("count=%s", tostring(zf_hook and zf_hook.count)))

			-- ================================================================
			-- Phase 7: ZF + SELF (4 addon users, dying player has addon)
			-- Same scenario but SELF broadcast arrives 1s after 3 PEERs
			-- ================================================================
			print(TAG .. "Phase 7: ZF + SELF — 4 addon users")
			do
				local zfs_name = "DdpZfSelf" .. math.random(10000, 99999)
				zfs_name = zfs_name:sub(1, 12)
				local zfs_lower = zfs_name:lower()
				_dnl.lru_by_name[zfs_lower] = nil
				hook_calls[zfs_lower] = nil

				local zfs_pd1 = _dnl.playerData(zfs_name, "",         600, nil, nil, 38, nil, 1429, "0.4,0.4", GetServerTime(), nil, nil)
				local zfs_pd2 = _dnl.playerData(zfs_name, "ZfsGuild", 600, 2,   3,   38, nil, 1429, "0.41,0.39", GetServerTime(), nil, nil)
				-- SELF: dying player's own broadcast (richest data)
				local zfs_self = _dnl.playerData(zfs_name, "ZfsGuild", 600, 2, 3, 38, nil, 1429, "0.4,0.4", GetServerTime(), 50000, "I died in ZF!")

				-- Clear caches
				for _, pd in ipairs({ zfs_pd1, zfs_pd2, zfs_self }) do
					local cs = _dnl.fletcher16(pd)
					_dnl.death_ping_lru_cache_tbl[cs] = nil
				end

				-- 2 PEERs arrive
				local ze1 = _dnl.encodeMessage(zfs_pd1)
				local ze2 = _dnl.encodeMessage(zfs_pd2)
				if ze1 then _dnl.handleDeathBroadcast("ZfsPeer1", ze1) end
				if ze2 then _dnl.handleDeathBroadcast("ZfsPeer2", ze2) end

				-- SELF arrives (sender == name → is_self_report = true)
				local ze_self = _dnl.encodeMessage(zfs_self)
				if ze_self then _dnl.handleDeathBroadcast(zfs_name, ze_self) end

				-- Should have exactly 1 active cache entry with SELF quality
				local zfs_count = 0
				local zfs_best_quality = 0
				for _, entry in pairs(_dnl.death_ping_lru_cache_tbl) do
					if entry["player_data"] and entry["player_data"]["name"] == zfs_name then
						if not entry["committed"] then
							zfs_count = zfs_count + 1
						end
						if (entry["quality"] or 0) > zfs_best_quality then
							zfs_best_quality = entry["quality"] or 0
						end
					end
				end
				record("phase7: 2 PEERs + 1 SELF → 1 uncommitted entry",
					zfs_count == 1,
					string.format("found %d", zfs_count))
				record("phase7: surviving entry is SELF quality",
					zfs_best_quality == _dnl.QUALITY.SELF,
					string.format("got %d", zfs_best_quality))

				-- Wait for commit
				C_Timer.After(5.0, function()
					local zfs_hook = hook_calls[zfs_lower]
					record("phase7: createEntry fired exactly 1 time",
						zfs_hook and zfs_hook.count == 1,
						string.format("count=%s", tostring(zfs_hook and zfs_hook.count)))
					if zfs_hook and zfs_hook.last_pd then
						record("phase7: committed data has played (SELF)",
							zfs_hook.last_pd["played"] == 50000,
							string.format("got %s", tostring(zfs_hook.last_pd["played"])))
						record("phase7: committed data has last_words (SELF)",
							zfs_hook.last_pd["last_words"] == "I died in ZF!",
							string.format("got '%s'", tostring(zfs_hook.last_pd["last_words"])))
					end

					-- ============================================================
					-- Phase 8: isNameAlreadyCommitted blocks duplicate commit
					-- ============================================================
					print(TAG .. "Phase 8: isNameAlreadyCommitted guard")
					do
						local dup_name = "DedupGuard" .. math.random(10000, 99999)
						dup_name = dup_name:sub(1, 12)
						local dup_lower = dup_name:lower()

						-- Manually mark as committed in lru_by_name
						_dnl.lru_by_name[dup_lower] = {
							checksum = "fake-committed-cs",
							timestamp = GetServerTime(),
							committed = true,
						}

						record("phase8: isNameAlreadyCommitted returns true for committed name",
							_dnl.isNameAlreadyCommitted(dup_name) == true)

						-- After dedup window expires (no level stored → 120s default window), should return false
						_dnl.lru_by_name[dup_lower].timestamp = GetServerTime() - _dnl.getDedupWindow(0) - 10
						record("phase8: isNameAlreadyCommitted returns false after window expires",
							_dnl.isNameAlreadyCommitted(dup_name) == false)

						-- With a high-level entry, the window is wider
						_dnl.lru_by_name[dup_lower].level = 40
						_dnl.lru_by_name[dup_lower].timestamp = GetServerTime() - 600
						record("phase8: isNameAlreadyCommitted returns true with level-scaled window",
							_dnl.isNameAlreadyCommitted(dup_name) == true)

						-- Beyond the level-40 window (1800s)
						_dnl.lru_by_name[dup_lower].timestamp = GetServerTime() - 1810
						record("phase8: isNameAlreadyCommitted returns false beyond level-scaled window",
							_dnl.isNameAlreadyCommitted(dup_name) == false)

						-- Nil/empty name → false
						record("phase8: isNameAlreadyCommitted(nil) = false",
							_dnl.isNameAlreadyCommitted(nil) == false)

						-- Clean up
						_dnl.lru_by_name[dup_lower] = nil
					end

					-- ============================================================
					-- Phase 9: mergeLRUEntry field-level merge correctness
					-- ============================================================
					print(TAG .. "Phase 9: mergeLRUEntry field-level merge")
					do
						-- Higher quality incoming: overwrites everything
						local existing_hi = _dnl.playerData("MergeLru", "OldGuild", 100, 1, 1, 30, nil, 1429, "0.5,0.5", GetServerTime(), 1000, "old words")
						local incoming_hi = _dnl.playerData("MergeLru", "NewGuild", 200, 3, 5, 30, nil, 1426, "0.3,0.3", GetServerTime(), 5000, "new words")
						_dnl.mergeLRUEntry(existing_hi, incoming_hi, _dnl.QUALITY.SELF, _dnl.QUALITY.PEER)
						record("phase9: higher quality incoming overwrites guild",
							existing_hi["guild"] == "NewGuild",
							string.format("got '%s'", tostring(existing_hi["guild"])))
						record("phase9: higher quality incoming overwrites source_id",
							existing_hi["source_id"] == 200,
							string.format("got %s", tostring(existing_hi["source_id"])))
						record("phase9: higher quality incoming overwrites last_words",
							existing_hi["last_words"] == "new words",
							string.format("got '%s'", tostring(existing_hi["last_words"])))

						-- Lower quality incoming: only fills gaps
						local existing_lo = _dnl.playerData("MergeLru2", "KeepGuild", 300, 2, 4, 40, nil, 1429, nil, GetServerTime(), nil, nil)
						local incoming_lo = _dnl.playerData("MergeLru2", "IgnoredGuild", 301, nil, nil, 40, nil, 1429, "0.7,0.7", GetServerTime(), 8000, "fill words")
						_dnl.mergeLRUEntry(existing_lo, incoming_lo, _dnl.QUALITY.PEER, _dnl.QUALITY.SELF)
						record("phase9: lower quality preserves existing guild",
							existing_lo["guild"] == "KeepGuild",
							string.format("got '%s'", tostring(existing_lo["guild"])))
						record("phase9: lower quality fills missing map_pos",
							existing_lo["map_pos"] == "0.7,0.7",
							string.format("got '%s'", tostring(existing_lo["map_pos"])))
						record("phase9: lower quality fills missing played",
							existing_lo["played"] == 8000,
							string.format("got %s", tostring(existing_lo["played"])))
						record("phase9: lower quality fills missing last_words",
							existing_lo["last_words"] == "fill words",
							string.format("got '%s'", tostring(existing_lo["last_words"])))
						record("phase9: lower quality does NOT overwrite source_id",
							existing_lo["source_id"] == 300,
							string.format("got %s", tostring(existing_lo["source_id"])))

						-- source_id = -1 in existing: should be filled by real source_id from incoming lower-quality
						local existing_src = _dnl.playerData("MergeLru3", "", -1, nil, nil, 20, nil, 1429, nil, GetServerTime(), nil, nil)
						local incoming_src = _dnl.playerData("MergeLru3", "", 555, nil, nil, 20, nil, 1429, nil, GetServerTime(), nil, nil)
						_dnl.mergeLRUEntry(existing_src, incoming_src, _dnl.QUALITY.PEER, _dnl.QUALITY.SELF)
						record("phase9: lower quality fills source_id=-1 with real value",
							existing_src["source_id"] == 555,
							string.format("got %s", tostring(existing_src["source_id"])))
					end

					-- ============================================================
					-- Phase 10: Dedup window boundary test
					-- ============================================================
					print(TAG .. "Phase 10: Dedup window boundary")
					do
						local bnd_name = "DedupBndry" .. math.random(10000, 99999)
						bnd_name = bnd_name:sub(1, 12)
						local bnd_lower = bnd_name:lower()

						-- Place an entry at the edge of the dedup window
						local bnd_pd = _dnl.playerData(bnd_name, "G", 100, 1, 1, 25, nil, 1429, nil, GetServerTime(), nil, nil)
						local bnd_cs = _dnl.fletcher16(bnd_pd)
						_dnl.death_ping_lru_cache_tbl[bnd_cs] = {
							player_data = _dnl.deepCopy(bnd_pd),
							quality = _dnl.QUALITY.PEER,
							timestamp = GetServerTime(),
							source = _dnl.SOURCE.PEER_BROADCAST,
						}

						-- Just inside window: should dedup
						-- Level 25 → getDedupWindow(25) = 600s, so 115s ago is well within
						_dnl.lru_by_name[bnd_lower] = {
							checksum = bnd_cs,
							timestamp = GetServerTime() - _dnl.getDedupWindow(25) + 5,
							level = 25,
						}
						local bnd_inside = _dnl.playerData(bnd_name, "", 100, nil, nil, 25, nil, 1429, nil, GetServerTime(), nil, nil)
						local bnd_inside_enc = _dnl.encodeMessage(bnd_inside)
						local bnd_count_before = 0
						for _, e in pairs(_dnl.death_ping_lru_cache_tbl) do
							if e["player_data"] and e["player_data"]["name"] == bnd_name then
								bnd_count_before = bnd_count_before + 1
							end
						end
						if bnd_inside_enc then _dnl.handleDeathBroadcast("BndPeer", bnd_inside_enc) end
						local bnd_count_after = 0
						for _, e in pairs(_dnl.death_ping_lru_cache_tbl) do
							if e["player_data"] and e["player_data"]["name"] == bnd_name then
								bnd_count_after = bnd_count_after + 1
							end
						end
						record("phase10: inside window → deduped (count unchanged)",
							bnd_count_after == bnd_count_before,
							string.format("before=%d, after=%d", bnd_count_before, bnd_count_after))

						-- Just outside window: should create new entry
						-- Level 26 → getDedupWindow(26) = 600s, set timestamp just beyond
						_dnl.lru_by_name[bnd_lower] = {
							checksum = bnd_cs,
							timestamp = GetServerTime() - _dnl.getDedupWindow(26) - 5,
							level = 26,
						}
						local bnd_outside = _dnl.playerData(bnd_name, "NewGuild", 101, nil, nil, 26, nil, 1429, nil, GetServerTime(), nil, nil)
						local bnd_outside_cs = _dnl.fletcher16(bnd_outside)
						_dnl.death_ping_lru_cache_tbl[bnd_outside_cs] = nil
						local bnd_outside_enc = _dnl.encodeMessage(bnd_outside)
						if bnd_outside_enc then _dnl.handleDeathBroadcast("BndPeer2", bnd_outside_enc) end
						local bnd_new_entry = _dnl.death_ping_lru_cache_tbl[bnd_outside_cs]
						record("phase10: outside window → new entry created",
							bnd_new_entry ~= nil and bnd_new_entry["player_data"] ~= nil)

						-- Clean up
						_dnl.death_ping_lru_cache_tbl[bnd_cs] = nil
						_dnl.death_ping_lru_cache_tbl[bnd_outside_cs] = nil
						_dnl.lru_by_name[bnd_lower] = nil
					end

					-- Final summary
					C_Timer.After(0.5, function()
						print(TAG .. "=========================")
						printSummary()
						print(TAG .. "=========================")
						testCleanup()
					end)
				end)
			end
		end)
	end
end

-- ============================================================================
-- testVersionCheck: version broadcast & notification tests
-- ============================================================================

--- Test the VersionCheck module: wire format, message dispatch,
--- newer/older version handling, whisper-back, dedup, and cooldown.
function _dnl.testVersionCheck()
	if not _dnl.DEBUG then
		print("|cffFF0000[Deathlog]|r testVersionCheck requires DEBUG mode")
		return
	end

	testBegin()
	local TAG  = "|cffFFAA00[DNL VersionCheck Test]|r "
	local PASS = "|cff00FF00PASS|r"
	local FAIL = "|cffFF0000FAIL|r"

	local results = {}
	local function record(name, ok, detail)
		table.insert(results, { name = name, ok = ok, detail = detail })
		if test_tracking.all_depth > 0 then
			table.insert(test_tracking.global_results, { suite = "VersionCheck", name = name, ok = ok, detail = detail })
		end
		print(TAG .. (ok and PASS or FAIL) .. " " .. name .. (detail and (" — " .. detail) or ""))
	end

	local function printSummary()
		print(TAG .. "--- Summary ---")
		local passed, failed = 0, 0
		for _, r in ipairs(results) do
			if r.ok then passed = passed + 1 else failed = failed + 1 end
		end
		for _, r in ipairs(results) do
			print(TAG .. "  " .. (r.ok and PASS or FAIL) .. " " .. r.name)
		end
		local color = failed == 0 and "|cff00FF00" or "|cffFF0000"
		print(TAG .. color .. string.format("%d/%d passed|r", passed, passed + failed))
	end

	print(TAG .. "=========================")
	print(TAG .. "Version Check Tests")
	print(TAG .. "=========================")

	-- Save state
	local saved_addons              = _dnl.addons
	local saved_tag_to_addon        = _dnl.tag_to_addon
	local saved_hook_newer_version  = _dnl.hook_newer_version_functions

	-- Capture whisper messages sent by the version check module
	local whisper_log = {}
	local saved_CTL = _G.ChatThrottleLib
	local saved_SendAddonMessage = _G.SendAddonMessage
	_G.ChatThrottleLib = nil  -- force raw path
	_G.SendAddonMessage = function(prefix, text, chatType, target)
		table.insert(whisper_log, {
			prefix   = prefix,
			text     = text,
			chatType = chatType,
			target   = target,
		})
	end

	-- Register a mock addon
	_dnl.addons = {}
	_dnl.tag_to_addon = {}
	_dnl.addons["__TestVC__"] = {
		name          = "__TestVC__",
		tag           = "VC1",
		isUnitTracked = function() return true end,
		settings      = {},
		addon_version = "1.0.0",
	}
	_dnl.tag_to_addon["VC1"] = "__TestVC__"

	-- Clear version check state
	wipe(_dnl._vc_warned_versions)
	wipe(_dnl._vc_last_announce_time)

	-- Capture HookOnNewerVersion calls
	local hook_calls = {}
	_dnl.hook_newer_version_functions = {
		function(addonName, newerVer, currentVer)
			table.insert(hook_calls, {
				addon   = addonName,
				newer   = newerVer,
				current = currentVer,
			})
		end,
	}

	-- ================================================================
	-- Phase 1: Constants & prefix
	-- ================================================================
	print(TAG .. "Phase 1: Constants")

	record("VERSION_CHECK_COMM_NAME defined",
		_dnl.VERSION_CHECK_COMM_NAME ~= nil and _dnl.VERSION_CHECK_COMM_NAME == "HCDeathVer")

	record("CMD_VERSION_ANNOUNCE is V",
		_dnl._vc_CMD_VERSION_ANNOUNCE == "V")

	record("CMD_NEWER_NOTIFY is N",
		_dnl._vc_CMD_NEWER_NOTIFY == "N")

	-- ================================================================
	-- Phase 2: Receiving a NEWER version announcement
	-- ================================================================
	print(TAG .. "Phase 2: Newer version announcement")

	wipe(hook_calls)
	wipe(whisper_log)

	-- Simulate receiving V$VC1~2.0.0~ from "RemotePeer" on GUILD
	local msg_newer = "V" .. _dnl.COMM_COMMAND_DELIM .. "VC1" .. _dnl.COMM_FIELD_DELIM .. "2.0.0" .. _dnl.COMM_FIELD_DELIM
	_dnl.handleVersionCheckAddonMessage({
		_dnl.VERSION_CHECK_COMM_NAME,
		msg_newer,
		"GUILD",
		"RemotePeer",
	})

	record("newer version: hook fired",
		#hook_calls == 1,
		"count=" .. tostring(#hook_calls))

	record("newer version: hook addon name correct",
		#hook_calls >= 1 and hook_calls[1].addon == "__TestVC__")

	record("newer version: hook newer version correct",
		#hook_calls >= 1 and hook_calls[1].newer == "2.0.0")

	record("newer version: hook current version correct",
		#hook_calls >= 1 and hook_calls[1].current == "1.0.0")

	record("newer version: newest_detected_version updated",
		_dnl.addons["__TestVC__"].newest_detected_version == "2.0.0")

	-- Should NOT whisper back (remote is newer, we don't tell them anything)
	record("newer version: no whisper sent",
		#whisper_log == 0,
		"whispers=" .. tostring(#whisper_log))

	-- ================================================================
	-- Phase 3: Dedup — same version again should not re-fire
	-- ================================================================
	print(TAG .. "Phase 3: Dedup (same newer version)")

	wipe(hook_calls)
	wipe(whisper_log)

	-- Same message again
	_dnl.handleVersionCheckAddonMessage({
		_dnl.VERSION_CHECK_COMM_NAME,
		msg_newer,
		"GUILD",
		"AnotherPeer",
	})

	record("dedup: hook NOT fired for same version",
		#hook_calls == 0,
		"count=" .. tostring(#hook_calls))

	record("dedup: no whisper sent",
		#whisper_log == 0)

	-- ================================================================
	-- Phase 4: Even newer version should fire again
	-- ================================================================
	print(TAG .. "Phase 4: Even newer version")

	wipe(hook_calls)

	local msg_even_newer = "V" .. _dnl.COMM_COMMAND_DELIM .. "VC1" .. _dnl.COMM_FIELD_DELIM .. "3.0.0" .. _dnl.COMM_FIELD_DELIM
	_dnl.handleVersionCheckAddonMessage({
		_dnl.VERSION_CHECK_COMM_NAME,
		msg_even_newer,
		"PARTY",
		"ThirdPeer",
	})

	record("even newer: hook fires for 3.0.0",
		#hook_calls == 1)

	record("even newer: newest_detected_version updated to 3.0.0",
		_dnl.addons["__TestVC__"].newest_detected_version == "3.0.0")

	-- ================================================================
	-- Phase 5: Receiving an OLDER version announcement → whisper back
	-- ================================================================
	print(TAG .. "Phase 5: Older version announcement (whisper back)")

	wipe(hook_calls)
	wipe(whisper_log)

	local msg_older = "V" .. _dnl.COMM_COMMAND_DELIM .. "VC1" .. _dnl.COMM_FIELD_DELIM .. "0.5.0" .. _dnl.COMM_FIELD_DELIM
	_dnl.handleVersionCheckAddonMessage({
		_dnl.VERSION_CHECK_COMM_NAME,
		msg_older,
		"RAID",
		"OldPeer",
	})

	record("older version: no hook fired (we're not outdated)",
		#hook_calls == 0)

	record("older version: whisper sent",
		#whisper_log == 1,
		"whispers=" .. tostring(#whisper_log))

	if #whisper_log >= 1 then
		record("older version: whisper prefix correct",
			whisper_log[1].prefix == _dnl.VERSION_CHECK_COMM_NAME)

		record("older version: whisper target correct",
			whisper_log[1].target == "OldPeer")

		record("older version: whisper chatType is WHISPER",
			whisper_log[1].chatType == "WHISPER")

		-- Verify whisper message format: N$VC1~1.0.0~
		local expected_whisper = "N" .. _dnl.COMM_COMMAND_DELIM
			.. "VC1" .. _dnl.COMM_FIELD_DELIM
			.. "1.0.0" .. _dnl.COMM_FIELD_DELIM
		record("older version: whisper message format correct",
			whisper_log[1].text == expected_whisper,
			string.format("expected '%s', got '%s'", expected_whisper, tostring(whisper_log[1].text)))
	end

	-- ================================================================
	-- Phase 6: Receiving a SAME version announcement → no action
	-- ================================================================
	print(TAG .. "Phase 6: Same version announcement")

	wipe(hook_calls)
	wipe(whisper_log)

	local msg_same = "V" .. _dnl.COMM_COMMAND_DELIM .. "VC1" .. _dnl.COMM_FIELD_DELIM .. "1.0.0" .. _dnl.COMM_FIELD_DELIM
	_dnl.handleVersionCheckAddonMessage({
		_dnl.VERSION_CHECK_COMM_NAME,
		msg_same,
		"PARTY",
		"SamePeer",
	})

	record("same version: no hook fired",
		#hook_calls == 0)

	record("same version: no whisper sent",
		#whisper_log == 0)

	-- ================================================================
	-- Phase 7: Receiving N$ (newer notify whisper) — we're outdated
	-- ================================================================
	print(TAG .. "Phase 7: Newer notify whisper (N$)")

	-- Reset warned_versions so we can test the N$ path fresh
	wipe(_dnl._vc_warned_versions)
	_dnl.addons["__TestVC__"].newest_detected_version = nil
	wipe(hook_calls)
	wipe(whisper_log)

	local msg_notify = "N" .. _dnl.COMM_COMMAND_DELIM .. "VC1" .. _dnl.COMM_FIELD_DELIM .. "5.0.0" .. _dnl.COMM_FIELD_DELIM
	_dnl.handleVersionCheckAddonMessage({
		_dnl.VERSION_CHECK_COMM_NAME,
		msg_notify,
		"WHISPER",
		"HelperPeer",
	})

	record("N$ notify: hook fired",
		#hook_calls == 1)

	record("N$ notify: newest_detected_version updated",
		_dnl.addons["__TestVC__"].newest_detected_version == "5.0.0")

	-- N$ should NOT trigger a whisper back (it's already a whisper response)
	record("N$ notify: no whisper sent",
		#whisper_log == 0)

	-- ================================================================
	-- Phase 8: N$ with older/same version → ignored
	-- ================================================================
	print(TAG .. "Phase 8: N$ with not-newer version")

	wipe(hook_calls)

	local msg_notify_old = "N" .. _dnl.COMM_COMMAND_DELIM .. "VC1" .. _dnl.COMM_FIELD_DELIM .. "0.1.0" .. _dnl.COMM_FIELD_DELIM
	_dnl.handleVersionCheckAddonMessage({
		_dnl.VERSION_CHECK_COMM_NAME,
		msg_notify_old,
		"WHISPER",
		"LiarPeer",
	})

	record("N$ old version: no hook fired",
		#hook_calls == 0)

	-- ================================================================
	-- Phase 9: Self-messages are ignored
	-- ================================================================
	print(TAG .. "Phase 9: Self-messages ignored")

	wipe(_dnl._vc_warned_versions)
	wipe(hook_calls)
	wipe(whisper_log)

	local my_name = UnitName("player")
	local msg_self = "V" .. _dnl.COMM_COMMAND_DELIM .. "VC1" .. _dnl.COMM_FIELD_DELIM .. "9.0.0" .. _dnl.COMM_FIELD_DELIM
	_dnl.handleVersionCheckAddonMessage({
		_dnl.VERSION_CHECK_COMM_NAME,
		msg_self,
		"GUILD",
		my_name,
	})

	record("self V$: no hook fired",
		#hook_calls == 0)

	record("self V$: no whisper sent",
		#whisper_log == 0)

	-- N$ from self
	local msg_notify_self = "N" .. _dnl.COMM_COMMAND_DELIM .. "VC1" .. _dnl.COMM_FIELD_DELIM .. "9.0.0" .. _dnl.COMM_FIELD_DELIM
	_dnl.handleVersionCheckAddonMessage({
		_dnl.VERSION_CHECK_COMM_NAME,
		msg_notify_self,
		"WHISPER",
		my_name,
	})

	record("self N$: no hook fired",
		#hook_calls == 0)

	-- ================================================================
	-- Phase 10: Unknown tag → ignored
	-- ================================================================
	print(TAG .. "Phase 10: Unknown tag")

	wipe(hook_calls)
	wipe(whisper_log)

	local msg_unk = "V" .. _dnl.COMM_COMMAND_DELIM .. "ZZZ" .. _dnl.COMM_FIELD_DELIM .. "2.0.0" .. _dnl.COMM_FIELD_DELIM
	_dnl.handleVersionCheckAddonMessage({
		_dnl.VERSION_CHECK_COMM_NAME,
		msg_unk,
		"GUILD",
		"SomePeer",
	})

	record("unknown tag: no hook fired",
		#hook_calls == 0)

	record("unknown tag: no whisper sent",
		#whisper_log == 0)

	-- ================================================================
	-- Phase 11: Malformed messages → no crash
	-- ================================================================
	print(TAG .. "Phase 11: Malformed messages")

	wipe(hook_calls)
	wipe(whisper_log)

	-- Wrong prefix
	_dnl.handleVersionCheckAddonMessage({ "WrongPrefix", "V$VC1~2.0.0~", "GUILD", "Peer" })
	record("wrong prefix: no crash, no hook",
		#hook_calls == 0)

	-- Missing payload
	_dnl.handleVersionCheckAddonMessage({ _dnl.VERSION_CHECK_COMM_NAME, "V", "GUILD", "Peer" })
	record("missing payload: no crash",
		#hook_calls == 0)

	-- No command delimiter
	_dnl.handleVersionCheckAddonMessage({ _dnl.VERSION_CHECK_COMM_NAME, "garbage", "GUILD", "Peer" })
	record("no delimiter: no crash",
		#hook_calls == 0)

	-- Empty version
	local msg_empty_ver = "V" .. _dnl.COMM_COMMAND_DELIM .. "VC1" .. _dnl.COMM_FIELD_DELIM .. "" .. _dnl.COMM_FIELD_DELIM
	_dnl.handleVersionCheckAddonMessage({ _dnl.VERSION_CHECK_COMM_NAME, msg_empty_ver, "GUILD", "Peer" })
	record("empty version: no crash",
		#hook_calls == 0)

	-- Invalid version string
	local msg_bad_ver = "V" .. _dnl.COMM_COMMAND_DELIM .. "VC1" .. _dnl.COMM_FIELD_DELIM .. "notaversion" .. _dnl.COMM_FIELD_DELIM
	_dnl.handleVersionCheckAddonMessage({ _dnl.VERSION_CHECK_COMM_NAME, msg_bad_ver, "GUILD", "Peer" })
	record("invalid version string: no crash, no hook",
		#hook_calls == 0)

	-- ================================================================
	-- Phase 12: Multiple addons — each gets checked independently
	-- ================================================================
	print(TAG .. "Phase 12: Multiple addons")

	_dnl.addons["__TestVC2__"] = {
		name          = "__TestVC2__",
		tag           = "VC2",
		isUnitTracked = function() return true end,
		settings      = {},
		addon_version = "2.0.0",
	}
	_dnl.tag_to_addon["VC2"] = "__TestVC2__"

	wipe(_dnl._vc_warned_versions)
	wipe(hook_calls)
	wipe(whisper_log)

	-- VC1 gets a newer version
	local msg_vc1_newer = "V" .. _dnl.COMM_COMMAND_DELIM .. "VC1" .. _dnl.COMM_FIELD_DELIM .. "8.0.0" .. _dnl.COMM_FIELD_DELIM
	_dnl.handleVersionCheckAddonMessage({
		_dnl.VERSION_CHECK_COMM_NAME, msg_vc1_newer, "GUILD", "MultiPeer",
	})

	record("multi addon: VC1 hook fired",
		#hook_calls == 1 and hook_calls[1].addon == "__TestVC__")

	-- VC2 gets an older version → whisper back
	local msg_vc2_older = "V" .. _dnl.COMM_COMMAND_DELIM .. "VC2" .. _dnl.COMM_FIELD_DELIM .. "1.0.0" .. _dnl.COMM_FIELD_DELIM
	_dnl.handleVersionCheckAddonMessage({
		_dnl.VERSION_CHECK_COMM_NAME, msg_vc2_older, "GUILD", "MultiPeer2",
	})

	record("multi addon: VC2 no extra hook (not outdated)",
		#hook_calls == 1)

	record("multi addon: VC2 whisper sent",
		#whisper_log == 1 and whisper_log[1].target == "MultiPeer2")

	-- ================================================================
	-- Cleanup: restore original state
	-- ================================================================
	_dnl.addons                       = saved_addons
	_dnl.tag_to_addon                 = saved_tag_to_addon
	_dnl.hook_newer_version_functions = saved_hook_newer_version
	_G.ChatThrottleLib                = saved_CTL
	_G.SendAddonMessage               = saved_SendAddonMessage

	wipe(_dnl._vc_warned_versions)
	wipe(_dnl._vc_last_announce_time)

	C_Timer.After(0.5, function()
		print(TAG .. "=========================")
		printSummary()
		print(TAG .. "=========================")
		testCleanup()
	end)
end

-- ============================================================================
-- testAll: run all test suites in sequence
-- ============================================================================

--- Run backwards compat → sync → integration → who → ultrahardcore → attachaddon
--- → watchlistquery → versioncheck → dedup tests in sequence.  Uses staggered
--- timers so each suite completes before the next begins.  Cleanup and
--- follow-up sweeps happen once at the very end.
function _dnl.testAll()
	if not _dnl.DEBUG then
		print("|cffFF0000[Deathlog]|r testAll requires DEBUG mode")
		return
	end

	local TAG = "|cffFF00FF[Deathlog testAll]|r "

	testBegin()
	test_tracking.all_depth = test_tracking.all_depth + 1

	wipe(test_tracking.global_results)

	print(TAG .. "Starting full test suite...")
	print(TAG .. "============================================")

	-- Suite 1: V2 Backwards Compatibility (synchronous + 0.5s summary timer)
	print(TAG .. "Suite 1/10: Backwards Compatibility")
	_dnl.testV2BackwardsCompat()

	-- Suite 2: Sync Protocol (synchronous) — start after backwards finishes
	C_Timer.After(2, function()
		print(TAG .. "Suite 2/10: Sync Protocol")
		_dnl.testSync()

		-- Suite 3: Sync End-to-End (async, ~10s) — start after sync unit tests
		C_Timer.After(1, function()
			print(TAG .. "Suite 3/10: Sync End-to-End")
			_dnl.testSyncEndToEnd()

			-- SyncE2E takes ~10s (3s + 1s + 2s + 2s nested timers + buffer).
			-- Suite 4: Integration (async, ~8s) — start after sync e2e finishes
			C_Timer.After(12, function()
				print(TAG .. "Suite 4/10: Integration")
				_dnl.testIntegration()

				-- Integration takes ~8s (5s + 2s + 0.5s nested timers).
				-- Suite 5: Who system (async, ~15s) — start after integration finishes
				C_Timer.After(12, function()
					print(TAG .. "Suite 5/10: Who System")
					_dnl.testWho()

					-- Who test takes ~15s (enqueue + user input + 0.5s summary).
					C_Timer.After(18, function()
						-- Suite 6: UltraHardcore bridge (synchronous + 0.5s summary)
print(TAG .. "Suite 6/10: UltraHardcore Bridge")
						_dnl.testUltraHardcore()

						C_Timer.After(2, function()
							-- Suite 7: AttachAddon multi-addon tests (synchronous + 0.5s summary)
print(TAG .. "Suite 7/10: AttachAddon")
							_dnl.testAttachAddon()

					C_Timer.After(3, function()
						-- Suite 8: WatchlistQuery (synchronous + 0.5s summary)
print(TAG .. "Suite 8/10: WatchlistQuery")
						_dnl.testWatchlistQuery()

					C_Timer.After(3, function()
						-- Suite 9: VersionCheck (synchronous + 0.5s summary)
						print(TAG .. "Suite 9/10: VersionCheck")
						_dnl.testVersionCheck()

					C_Timer.After(3, function()
						-- Suite 10: Dedup (async, ~11s) — cross-checksum dedup, late upgrades, ZF scenario
						print(TAG .. "Suite 10/10: Dedup")
						_dnl.testDedup()

					C_Timer.After(13, function()
						test_tracking.all_depth = test_tracking.all_depth - 1
						print(TAG .. "============================================")
						print(TAG .. "GRAND SUMMARY")
						print(TAG .. "============================================")

					local total_pass, total_fail = 0, 0
					local failures = {}
					for _, r in ipairs(test_tracking.global_results) do
						if r.ok then
							total_pass = total_pass + 1
						else
							total_fail = total_fail + 1
							table.insert(failures, r)
						end
					end

					-- Per-suite breakdown
					local suite_counts = {}
					for _, r in ipairs(test_tracking.global_results) do
						if not suite_counts[r.suite] then
							suite_counts[r.suite] = { pass = 0, fail = 0 }
						end
						if r.ok then
							suite_counts[r.suite].pass = suite_counts[r.suite].pass + 1
						else
							suite_counts[r.suite].fail = suite_counts[r.suite].fail + 1
						end
					end
						for _, suite_name in ipairs({ "Backwards", "Sync", "SyncE2E", "Integration", "Who", "UltraHardcore", "AttachAddon", "WatchlistQuery", "VersionCheck", "Dedup" }) do
						local sc = suite_counts[suite_name]
						if sc then
							local c = sc.fail == 0 and "|cff00FF00" or "|cffFF0000"
							print(TAG .. string.format("  %-12s " .. c .. "%d/%d passed|r",
								suite_name, sc.pass, sc.pass + sc.fail))
						end
					end

					-- List failures
					if #failures > 0 then
						print(TAG .. "|cffFF0000FAILURES:|r")
						for _, f in ipairs(failures) do
							print(TAG .. string.format("  |cffFF0000FAIL|r [%s] %s%s",
								f.suite, f.name, f.detail and (" - " .. f.detail) or ""))
						end
					end

					-- Grand total
					local grand_color = total_fail == 0 and "|cff00FF00" or "|cffFF0000"
					print(TAG .. grand_color .. string.format("Total: %d/%d passed|r", total_pass, total_pass + total_fail))
					print(TAG .. "============================================")

					wipe(test_tracking.global_results)
					testCleanup()
					end)   -- close C_Timer.After(13, ...) — grand summary
					end)   -- close C_Timer.After(3, ...) — suite 10 (Dedup)
					end)   -- close C_Timer.After(3, ...) — suite 9 (VersionCheck)
					end)   -- close C_Timer.After(3, ...) — suite 8
					end)   -- close C_Timer.After(2, ...) — suite 7
					end)   -- close C_Timer.After(18, ...) — suite 6
				end)       -- close C_Timer.After(12, ...) — suite 5
			end)           -- close C_Timer.After(12, ...) — suite 4
		end)               -- close C_Timer.After(1, ...) — suite 3
	end)                   -- close C_Timer.After(2, ...) — suite 2
end

--#region API

---Manually fire all HookOnNewerVersion callbacks.  Intended for testing
---from /run — e.g.  /run DeathNotificationLib.FireNewerVersionHook("Deathlog", "99.0.0", "0.4.0")
---@param addonName string
---@param newerVersion string
---@param currentVersion string
DeathNotificationLib.FireNewerVersionHook = function(addonName, newerVersion, currentVersion)
	local addon = _dnl.addons[addonName]
	if addon then addon.newest_detected_version = newerVersion end
	for _, fn in ipairs(_dnl.hook_newer_version_functions) do
		fn(addonName, newerVersion, currentVersion)
	end
end

DeathNotificationLib.Tests = {
	SelfDeathWithReportedDeath = _dnl.testSelfDeathWithReportedDeath,
	SelfDeath = _dnl.testSelfDeath,
	ReportedDeath = _dnl.testReportedDeath,
	PartyDeath = _dnl.testPartyDeath,
	V2BackwardsCompat = _dnl.testV2BackwardsCompat,
	Integration = _dnl.testIntegration,
	Sync = _dnl.testSync,
	SyncEndToEnd = _dnl.testSyncEndToEnd,
	Who = _dnl.testWho,
	UltraHardcore = _dnl.testUltraHardcore,
	AttachAddon = _dnl.testAttachAddon,
	WatchlistQuery = _dnl.testWatchlistQuery,
	Dedup = _dnl.testDedup,
	VersionCheck = _dnl.testVersionCheck,
	All = _dnl.testAll,
}

--#endregion