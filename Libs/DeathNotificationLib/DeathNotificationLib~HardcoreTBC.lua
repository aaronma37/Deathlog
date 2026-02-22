--[[
DeathNotificationLib~HardcoreTBC.lua

Bridge module that hooks into the HardcoreTBC addon to capture death
events from its distributed log and feed them into DeathNotificationLib's
entry pipeline.

HardcoreTBC uses a separate communication network (AceComm on prefix
"HCTBC_DLog") with its own gossip-based sync protocol.  This module
taps into that network in two ways:

  1. Real-time interception: registers an AceComm receiver for the
     HCTBC_DLog prefix, decodes incoming messages using the same
     AceSerializer + LibDeflate + yell-safe codec pipeline, and
     converts death events (type 10) into DNL PlayerData entries.

  2. Historical import: on login, scans HardcoreTBC's SavedVariable
     (HardcoreTBC_DistributedLogDB) for recent death events and
     imports any that DNL hasn't already seen.

HardcoreTBC death events carry:
  - player name, GUID, timestamp
  - extraData: pickle({l=level, m=mapID, s=killerName})

This module resolves the killer name to a DNL source_id via NPC_TO_ID,
env-damage lookup, or PvP encoding.  Class, race, and guild are enriched
from the guild roster when the dead player is a guild member.
--]]

local _dnl = DeathNotificationLib.Internal ---@class _dnl
if not _dnl then return end

local HCTBC_SYNC_PREFIX = "HCTBC_DLog"
local HCTBC_DEATH_TYPE = 10
local HCTBC_ADDON_NAME = "HardcoreTBC"

--- How far back (seconds) to import historical deaths on login.
--- 48 hours covers most typical play sessions.
local HISTORY_WINDOW = 48 * 60 * 60

--- How many events to process per frame before yielding.
local BATCH_SIZE = 20

--- Track imported event hashes to avoid duplicate processing.
local imported = {}

--- Set of instance_ids that are PvP zones (battlegrounds + arenas).
--- Built once from INSTANCE_CATEGORIES; unresolved death sources in
--- these zones are assumed to be player kills.
local pvp_instance_ids = {}
for _, cat in ipairs({"Battleground", "Arena"}) do
	local ids = _dnl.D.INSTANCE_CATEGORIES and _dnl.D.INSTANCE_CATEGORIES[cat]
	if ids then
		for _, id in ipairs(ids) do
			pvp_instance_ids[id] = true
		end
	end
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

--- Check if a player name already exists in any registered addon's
--- persistent db_map.  Unlike isNameAlreadyCommitted (which is an
--- in-memory LRU with a 60-second window), this survives reloads.
---@param name string
---@return boolean
local function isNameInAllAddonDbs(name)
	for _, addon in pairs(_dnl.addons) do
		if addon.db_map and not addon.db_map[name] then
			return false
		end
	end
	return true
end

--- Route a historical entry to each registered addon that doesn't already
--- have it, using targeted createEntry calls.  Returns true if at least
--- one addon received the entry.
---@param pd table  PlayerData
---@return boolean delivered
local function deliverToMissingAddons(pd)
	local name = pd.name
	if not name then return false end

	local delivered = false
	for addon_name, addon in pairs(_dnl.addons) do
		if addon.db_map and not addon.db_map[name] then
			_dnl.createEntry(pd, nil, 0, nil, _dnl.SOURCE.HARDCORE_TBC_SYNC, addon_name)
			delivered = true
		end
	end
	return delivered
end

--- Try to enrich a player name with guild roster data (class, race, guild)
---@param name string
local enrichFromRoster = _dnl.enrichFromRoster
local raceClassFromGUID = _dnl.raceClassFromGUID

--- Convert a HardcoreTBC death event into a DNL PlayerData table.
---@param event table  HardcoreTBC event: {type, player, guid, timestamp, src, extraData}
---@return table|nil player_data  DNL PlayerData or nil on failure
local function convertEvent(event)
	local name = event.player
	local timestamp = event.timestamp
	local raw_extra = event.extraData
	local guid = event.guid

	if not name or not raw_extra then return nil end

	-- unpickle() is a global provided by HardcoreTBC addon.
	-- If unavailable (addon not loaded), pcall catches the error gracefully.
	local data
	local ok, err = pcall(function() data = unpickle(raw_extra) end)
	if not ok or not data then return nil end

	local level = data.l
	local map_id = data.m
	local source_name = data.s

	-- New fields added by HardcoreTBC (may be nil on older deaths)
	local hctbc_race = data.r       -- race_id (number) from select(3, UnitRace)
	local hctbc_class = data.c      -- class_id (number) from select(3, UnitClass)
	local hctbc_guild = data.g      -- guild name string
	local hctbc_map_pos = data.p    -- "0.1234,0.5678"

	if not level or level <= 0 then return nil end

	-- Resolve death source
	local source_id = -1
	local extra_data = nil

	if source_name then
		source_id, extra_data = _dnl.resolveDeathSource(source_name, nil, true)
	end

	-- Instance check: if map_id maps to an instance, split accordingly
	local instance_id = nil
	if map_id and _dnl.D.ZONE_TO_INSTANCE and _dnl.D.ZONE_TO_INSTANCE[map_id] then
		instance_id = _dnl.D.ZONE_TO_INSTANCE[map_id]
	end

	-- If source is still unresolved and the death happened in a BG/Arena,
	-- assume source_name is a player name and encode as a minimal PvP kill.
	if source_id == -1 and source_name and instance_id and pvp_instance_ids[instance_id] then
		local success, pvp_source, pvp_source_name = _dnl.encodePvpSource(source_name, nil)
		if success then
			source_id = pvp_source
			if pvp_source_name then
				extra_data = { ["pvp_source_name"] = pvp_source_name }
			end
		end
	end

	-- Race / class / guild: prefer the new inline fields (already numeric
	-- IDs), fall back to roster lookup and GUID inspection for older deaths.
	local race_id = hctbc_race
	local class_id = hctbc_class
	local guild = hctbc_guild

	if not class_id or not race_id or not guild then
		local roster_class, _, roster_guild = enrichFromRoster(name)
		class_id = class_id or roster_class
		guild = guild or roster_guild
	end

	if not race_id or not class_id then
		local guid_race, guid_class = raceClassFromGUID(guid)
		race_id = race_id or guid_race
		class_id = class_id or guid_class
	end

	-- Map position: use inline field when available, nil otherwise
	local map_pos = hctbc_map_pos  -- already in "x,y" string format

	local player_data = _dnl.playerData(
		name,
		guild,
		source_id,
		race_id,
		class_id,
		level,
		instance_id,
		(not instance_id) and map_id or nil,
		(not instance_id) and map_pos or nil,
		timestamp or time(),
		data.t and tonumber(data.t) or nil,
		nil,                  -- last_words: not available
		extra_data
	)

	return player_data
end

---------------------------------------------------------------------------
-- Historical import
---------------------------------------------------------------------------

local function importHistory()
	if not HardcoreTBC_DistributedLogDB then return end

	-- Collect all unprocessed death events into a flat list.
	local pending = {}

	for _, guildData in pairs(HardcoreTBC_DistributedLogDB) do
		if guildData.events then
			for eventId, event in pairs(guildData.events) do
				if event.type == HCTBC_DEATH_TYPE
					and not event.ignored
					and not imported[eventId]
				then
					imported[eventId] = true
					table.insert(pending, event)
				end
			end
		end
	end

	if #pending == 0 then return end

	-- Process in batches across frames to avoid lag spikes.
	local best_by_name = {}
	local idx = 0

	local function processBatch()
		local count = 0
		while idx < #pending and count < BATCH_SIZE do
			idx = idx + 1
			count = count + 1

			local pd = convertEvent(pending[idx])
			if pd and _dnl.isValidEntry(pd) and pd.name then
				local prev = best_by_name[pd.name]
				if not prev then
					best_by_name[pd.name] = pd
				else
					best_by_name[pd.name] = _dnl.mergeEntries(pd, prev)
				end
			end
		end

		if idx < #pending then
			C_Timer.After(0, processBatch)
			return
		end

		-- All events converted — commit entries in batches too.
		local commit_list = {}
		for pname, pd in pairs(best_by_name) do
			table.insert(commit_list, { name = pname, pd = pd })
		end

		local ci = 0
		local new_count = 0

		local function commitBatch()
			local cc = 0
			while ci < #commit_list and cc < BATCH_SIZE do
				ci = ci + 1
				cc = cc + 1
				local entry = commit_list[ci]
				if not isNameInAllAddonDbs(entry.name) then
					deliverToMissingAddons(entry.pd)
					new_count = new_count + 1
				end
			end

			if ci < #commit_list then
				C_Timer.After(0, commitBatch)
			elseif new_count > 0 and _dnl.DEBUG then
				print("[DNL~HardcoreTBC] Imported " .. new_count .. " deaths from HardcoreTBC history")
			end
		end

		if #commit_list > 0 then
			commitBatch()
		end
	end

	processBatch()
end

---------------------------------------------------------------------------
-- Real-time AceComm interception
---------------------------------------------------------------------------

local function setupRealtime()
	local AceComm      = LibStub and LibStub("AceComm-3.0", true)
	local AceSerializer = LibStub and LibStub("AceSerializer-3.0", true)
	local LibDeflate   = LibStub and LibStub("LibDeflate", true)

	if not AceComm or not AceSerializer or not LibDeflate then
		if _dnl.DEBUG then
			print("[DNL~HardcoreTBC] Required libs unavailable – real-time hook skipped")
		end
		return false
	end

	-- Same yell-safe codec HardcoreTBC uses
	local codec = LibDeflate:CreateCodec("\000\010\013", "\001", "")

	local receiver = {}
	AceComm:Embed(receiver)

	receiver:RegisterComm(HCTBC_SYNC_PREFIX, function(prefix, msg, channel, sender)
		-- Decode the compression pipeline: codec → decompress → deserialize
		local decoded = codec:Decode(msg)
		if not decoded then return end

		local decompressed = LibDeflate:DecompressDeflate(decoded)
		if not decompressed then return end

		local success, data = AceSerializer:Deserialize(decompressed)
		if not success or type(data) ~= "table" then return end

		-- Only process single-event broadcasts carrying a death
		if data.type ~= "EVENT" or not data.data then return end
		local event = data.data
		if event.type ~= HCTBC_DEATH_TYPE then return end

		-- Anti-spoofing: sender must be the dying player
		-- (HardcoreTBC enforces this on its side too)
		if sender ~= event.player then return end

		-- Dedup key: matches HardcoreTBC's GenerateEventId logic
		local dedup_key = table.concat({
			tostring(event.type),
			tostring(event.guid),
			tostring(event.player),
			tostring(event.timestamp),
		}, "|")
		if imported[dedup_key] then return end
		imported[dedup_key] = true

		local pd = convertEvent(event)
		if pd and _dnl.isValidEntry(pd) then
			-- Feed through the unified broadcast handler so DNL's own dedup
			-- and peer-corroboration pipeline kicks in correctly.
			local encoded = _dnl.encodeMessage(pd)
			if encoded then
				_dnl.handleDeathBroadcast(sender, encoded)
			end

			if _dnl.DEBUG then
				print("[DNL~HardcoreTBC] Real-time death:", event.player, "lv", pd.level, "via", channel)
			end
		end
	end)

	if _dnl.DEBUG then
		print("[DNL~HardcoreTBC] Real-time AceComm hook active on prefix", HCTBC_SYNC_PREFIX)
	end
	return true
end

---------------------------------------------------------------------------
-- Periodic re-scan of saved variable for day-synced deaths
---------------------------------------------------------------------------

--- HardcoreTBC's gossip protocol fills in historical deaths over time via
--- day-sync and player-sync responses.  These arrive outside of the
--- BroadcastEvent path, so our AceComm hook won't see them.  A periodic
--- re-scan of the saved variable catches these late arrivals.

local RESCAN_INTERVAL = 300  -- 5 minutes

local function startPeriodicRescan()
	C_Timer.NewTicker(RESCAN_INTERVAL, function()
		if not HardcoreTBC_DistributedLogDB then return end

		local cutoff = time() - HISTORY_WINDOW

		-- Collect unseen events into a flat list
		local pending = {}

		for _, guildData in pairs(HardcoreTBC_DistributedLogDB) do
			if guildData.events then
				for eventId, event in pairs(guildData.events) do
					if event.type == HCTBC_DEATH_TYPE
						and not event.ignored
						and (event.timestamp or 0) >= cutoff
						and not imported[eventId]
					then
						imported[eventId] = true
						table.insert(pending, event)
					end
				end
			end
		end

		if #pending == 0 then return end

		local best_by_name = {}
		local idx = 0

		local function processBatch()
			local count = 0
			while idx < #pending and count < BATCH_SIZE do
				idx = idx + 1
				count = count + 1

				local pd = convertEvent(pending[idx])
				if pd and _dnl.isValidEntry(pd) and pd.name then
					local prev = best_by_name[pd.name]
					if not prev then
						best_by_name[pd.name] = pd
					else
						best_by_name[pd.name] = _dnl.mergeEntries(pd, prev)
					end
				end
			end

			if idx < #pending then
				C_Timer.After(0, processBatch)
				return
			end

			local commit_list = {}
			for pname, pd in pairs(best_by_name) do
				table.insert(commit_list, { name = pname, pd = pd })
			end

			local ci = 0
			local new_count = 0

			local function commitBatch()
				local cc = 0
				while ci < #commit_list and cc < BATCH_SIZE do
					ci = ci + 1
					cc = cc + 1
					local entry = commit_list[ci]
					if not isNameInAllAddonDbs(entry.name) then
						deliverToMissingAddons(entry.pd)
						new_count = new_count + 1
					end
				end

				if ci < #commit_list then
					C_Timer.After(0, commitBatch)
				elseif new_count > 0 and _dnl.DEBUG then
					print("[DNL~HardcoreTBC] Periodic re-scan: " .. new_count .. " new")
				end
			end

			if #commit_list > 0 then
				commitBatch()
			end
		end

		processBatch()
	end)
end

---------------------------------------------------------------------------
-- Initialization
---------------------------------------------------------------------------

-- PLAYER_LOGIN fires exactly once, after every ADDON_LOADED has fired,
-- so all addons (including HardcoreTBC) are guaranteed to be fully
-- initialised by this point.  Unlike PLAYER_ENTERING_WORLD it does not
-- re-fire on zone transitions or reloads, so no guard is needed.
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")

initFrame:SetScript("OnEvent", function(self, event, ...)
	self:UnregisterAllEvents()

	-- Check if HardcoreTBC is available
	local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
	if not isLoaded(HCTBC_ADDON_NAME) then
		if _dnl.DEBUG then
			print("[DNL~HardcoreTBC] HardcoreTBC not loaded \226\128\147 module inactive")
		end
		return
	end

	-- Wire up the real-time AceComm hook
	setupRealtime()

	-- Start periodic re-scan for day-synced deaths
	startPeriodicRescan()

	-- Import existing deaths after a short delay so HardcoreTBC's
	-- EventManager has time to finish initialization + markIgnored()
	C_Timer.After(10.0, importHistory)
end)
