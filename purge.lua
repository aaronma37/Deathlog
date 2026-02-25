--[[
purge.lua

Feign Death cleanup: purges false Hunter death entries caused by the
pre-V4 Feign Death detection bug.

Phase 1a – Duplicate detection (runs once, persisted):
  If the same Hunter name appears dead more than once within the eligible
  window, all entries except the newest are guaranteed fakes — you can only
  truly die once on Hardcore. These are purged immediately.

Phase 1b – Cluster detection (runs once, persisted):
  Two heuristics identify groups of hunter-only deaths that are almost
  certainly mass Feign Death triggers during raid/instance wipes:
  H1: Same guild + same raid + <=10 min window + 2+ hunters + 0 non-hunters
  H2: Any instance + <=10 min window + 2+ hunters + 0 non-hunters
  The union of H1+H2 flagged entries are purged automatically.

  Since older protocol clients are now rejected, no new fake entries can
  enter the database.  Phase 1 completion is persisted in deathlog_purged
  so it never re-runs.

Phase 2 – /who verification (drains automatically on player input):
  Remaining single-entry Hunters are verified via /who queries that fire
  one per player interaction (mouse click / key press), since SendWho is
  a protected function.

  Phase 2a — Level band sweep: 7 broadband queries (`c-"Hunter" 30-39`,
    `40-49`, `50-54`, `55-59`, `60-60`, `61-69`, `70-70`) each return up
    to 49 online hunters.  Any name from our list found online → purge.
    Cheap upfront pass that can resolve many names in very few queries.
  Phase 2b — Guild batch: guilds with 2+ dead Hunters are checked with a
    single `/who g-"Guild" c-"Hunter" minLvl-maxLvl`.  Any name from our
    list found online is alive → purge.  One query resolves many entries.
  Phase 2c — Individual: remaining Hunters (no guild, single-hunter guild,
    or not resolved by batch) get individual `/who n-"Name"` queries via
    the existing DeathNotificationLib.WhoPlayer API.

Purged checksums are persisted in the deathlog_purged SavedVariable so
they cannot re-enter the database via sync.

Usage:  Runs automatically.  `/deathlog cleanup` prints status.
--]]

local DEBUG = true

local HUNTER_CLASS_ID = 3

--- Epoch timestamp for 2026-02-22 00:00:00 UTC — only entries on or after
--- this date are eligible for cleanup (the FD bug was live from this point).
local FD_BUG_CUTOFF = 1771718400

--- Raid instance IDs (Onyxia, MC, BWL, AQ20, AQ40, Naxx, ZG)
local RAID_IDS = { [249]=true, [409]=true, [469]=true, [509]=true, [531]=true, [533]=true, [309]=true }

--- Cluster detection window in seconds (10 minutes)
local CLUSTER_WINDOW = 600

--- Hard cutoff: stop all purge activity after this date.
--- Epoch timestamp for 2026-04-01 00:00:00 UTC.
local PURGE_EXPIRY = 1775001600

--- Assumed leveling rate for estimating a hunter's current level.
--- "Levels per day" of wall-clock time — generous to avoid false negatives.
local LEVEL_UP_RATE_PER_DAY = 2

--- Level cap used when projecting how far a hunter could have leveled.
local MAX_LEVEL_CAP = 60

--- Level bands for broadband /who sweeps (Phase 2a)
--- Each band becomes one `c-"Hunter" lo-hi` query (max 49 results).
local LEVEL_BANDS = {
	{ 30, 39 },
	{ 40, 49 },
	{ 50, 54 },
	{ 55, 59 },
	{ 60, 60 },
	{ 61, 69 },  -- TBC
	{ 70, 70 },  -- TBC
}

--- Minimum seconds between /who queries to avoid hogging the who channel.
local PURGE_WHO_COOLDOWN = 20

-- Phase state (phase1 completion is persisted in deathlog_purged)
local phase2_complete = false
local purge_realm = nil

-- Work queue: ordered list of { type, ... } items
-- type = "guild_batch": { guild, filter, hunters = {normName -> {item,...}}, count }
-- type = "individual" : { item = {checksum, entry} }
local work_queue = nil
local work_idx = 0
local work_total = 0

-- /who in-flight flag (shared by both batch and individual paths)
local who_pending = false
local last_who_time = 0  -- GetTime() of last /who query

-- Stats
local phase2_purged = 0
local phase2_kept = 0
local total_who_queries = 0  -- actual queries sent

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

--- Purge a single entry: add to purged set, remove from db + name map.
local function purgeEntry(realmName, db, purged, cs, entry)
	purged[cs] = true
	db[cs] = nil
	local name = entry["name"]
	if deathlog_data_map[realmName] and deathlog_data_map[realmName][name] == cs then
		deathlog_data_map[realmName][name] = nil
	end
end

--- Strip realm suffix: "Name-Realm" → "Name"
local function normalizeName(name)
	return name and name:match("^([^-]+)") or name
end

--- Estimate the maximum level a sub-60 hunter could have reached by now,
--- given their recorded level and the time elapsed since the fake "death".
--- Hunters who feigned death are alive and leveling, so the further we are
--- from the recorded date the higher they may be.
local function estimateMaxLevel(death_level, death_date)
	if death_level >= MAX_LEVEL_CAP then return death_level end
	local elapsed_days = (GetServerTime() - (death_date or 0)) / 86400
	if elapsed_days < 0 then elapsed_days = 0 end
	local max_level = death_level + math.floor(elapsed_days * LEVEL_UP_RATE_PER_DAY)
	if max_level > MAX_LEVEL_CAP then max_level = MAX_LEVEL_CAP end
	return max_level
end

---------------------------------------------------------------------------
-- Phase 1 – Duplicate detection
---------------------------------------------------------------------------

local function runDuplicatePass(realmName, db, purged)
	local eligible = {}
	for cs, entry in pairs(db) do
		if entry["class_id"] == HUNTER_CLASS_ID
			and (entry["level"] or 0) >= 30
			and (entry["date"] or 0) >= FD_BUG_CUTOFF
			and not purged[cs]
		then
			eligible[#eligible + 1] = { checksum = cs, entry = entry }
		end
	end

	if #eligible == 0 then
		if DEBUG then
			print("|cffFFFF00[Deathlog]|r No eligible Hunter death entries found.")
		end
		return nil, 0, 0
	end

	local by_name = {}
	for _, item in ipairs(eligible) do
		local name = item.entry["name"] or "?"
		if not by_name[name] then
			by_name[name] = {}
		end
		by_name[name][#by_name[name] + 1] = item
	end

	local dup_purged = 0
	local remaining = {}
	for _, items in pairs(by_name) do
		if #items > 1 then
			table.sort(items, function(a, b)
				return (a.entry["date"] or 0) > (b.entry["date"] or 0)
			end)
			remaining[#remaining + 1] = items[1]
			for i = 2, #items do
				purgeEntry(realmName, db, purged, items[i].checksum, items[i].entry)
				dup_purged = dup_purged + 1
			end
		else
			remaining[#remaining + 1] = items[1]
		end
	end

	return remaining, #eligible, dup_purged
end

---------------------------------------------------------------------------
-- Phase 1b – Cluster detection (hunter-only instance/raid clusters)
---------------------------------------------------------------------------

--- Scan all deaths since cutoff, find temporal clusters in instances/raids
--- where ONLY hunters (lvl>=30) died (no mixed-class deaths).  These are
--- almost certainly mass Feign Death triggers during wipes.
--- Returns: new_remaining (list), cluster_purged (count)
local function runClusterPass(realmName, db, purged, remaining_items)
	-- Collect ALL entries (all classes) since cutoff for cluster context
	local all_since = {}
	for cs, entry in pairs(db) do
		if (entry["date"] or 0) >= FD_BUG_CUTOFF and not purged[cs] then
			all_since[#all_since + 1] = { checksum = cs, entry = entry }
		end
	end

	-- Build set of remaining hunter checksums for quick lookup
	local remaining_set = {}
	for _, item in ipairs(remaining_items) do
		remaining_set[item.checksum] = true
	end

	local flagged = {} -- checksum -> true

	-- Helper: scan a group of items sorted by date for hunter-only clusters
	local function scanClusters(items)
		table.sort(items, function(a, b)
			return (a.entry["date"] or 0) < (b.entry["date"] or 0)
		end)
		for _, anchor in ipairs(items) do
			local t0 = anchor.entry["date"] or 0
			local hunters_in_window = {}
			local has_non_hunter = false
			for _, other in ipairs(items) do
				local dt = math.abs((other.entry["date"] or 0) - t0)
				if dt <= CLUSTER_WINDOW then
					if other.entry["class_id"] == HUNTER_CLASS_ID
						and (other.entry["level"] or 0) >= 30 then
						hunters_in_window[#hunters_in_window + 1] = other
					else
						has_non_hunter = true
						break
					end
				end
			end
			if not has_non_hunter and #hunters_in_window >= 2 then
				for _, h in ipairs(hunters_in_window) do
					if remaining_set[h.checksum] then
						flagged[h.checksum] = true
					end
				end
			end
		end
	end

	-- H2: Group by instance_id — any instance, hunter-only cluster
	local by_instance = {}
	for _, item in ipairs(all_since) do
		local iid = item.entry["instance_id"]
		if iid and iid ~= 0 then
			if not by_instance[iid] then by_instance[iid] = {} end
			by_instance[iid][#by_instance[iid] + 1] = item
		end
	end
	for _, items in pairs(by_instance) do
		scanClusters(items)
	end

	-- H1: Group by (guild, raid_id) — same guild in a raid
	local by_guild_raid = {}
	for _, item in ipairs(all_since) do
		local guild = item.entry["guild"]
		local iid = item.entry["instance_id"]
		if guild and guild ~= "" and iid and RAID_IDS[iid] then
			local key = guild .. "\0" .. iid
			if not by_guild_raid[key] then by_guild_raid[key] = {} end
			by_guild_raid[key][#by_guild_raid[key] + 1] = item
		end
	end
	for _, items in pairs(by_guild_raid) do
		scanClusters(items)
	end

	-- Purge flagged entries and build new remaining list
	local cluster_purged = 0
	local new_remaining = {}
	for _, item in ipairs(remaining_items) do
		if flagged[item.checksum] then
			purgeEntry(realmName, db, purged, item.checksum, item.entry)
			cluster_purged = cluster_purged + 1
		else
			new_remaining[#new_remaining + 1] = item
		end
	end

	return new_remaining, cluster_purged
end

---------------------------------------------------------------------------
-- Phase 2 – Build ordered work queue from remaining entries
---------------------------------------------------------------------------

local function buildWorkQueue(remaining)
	-- Get localized class name for Hunter
	local hunterClassName = GetClassInfo(HUNTER_CLASS_ID) or "Hunter"

	local queue = {}

	-- ---------------------------------------------------------------
	-- Phase 2a: Level band sweeps
	-- ---------------------------------------------------------------
	-- Build a name->items lookup for ALL remaining hunters so that
	-- when a band sweep returns online names we can resolve them.
	local all_by_name = {}  -- normName(lower) -> { item, ... }
	for _, item in ipairs(remaining) do
		local norm = normalizeName(item.entry["name"])
		if norm then
			norm = norm:lower()
			if not all_by_name[norm] then all_by_name[norm] = {} end
			all_by_name[norm][#all_by_name[norm] + 1] = item
		end
	end

	for _, band in ipairs(LEVEL_BANDS) do
		-- Only queue bands that cover at least one remaining hunter
		local band_names = {}  -- normName(lower) -> true
		local count = 0
		for _, item in ipairs(remaining) do
			local lvl = item.entry["level"] or 0
			local max_lvl = estimateMaxLevel(lvl, item.entry["date"] or 0)
			-- Include this hunter if their possible level range overlaps the band
			if lvl <= band[2] and max_lvl >= band[1] then
				local norm = normalizeName(item.entry["name"])
				if norm then
					norm = norm:lower()
					if not band_names[norm] then
						band_names[norm] = true
						count = count + 1
					end
				end
			end
		end
		if count > 0 then
			local filter = string.format('c-"%s" %d-%d',
				hunterClassName, band[1], band[2])
			queue[#queue + 1] = {
				type = "level_band",
				filter = filter,
				band = band,
				band_names = band_names,  -- normName(lower) -> true
				all_by_name = all_by_name, -- shared ref for resolution
				count = count,
			}
		end
	end

	-- ---------------------------------------------------------------
	-- Phase 2b: Guild batch queries
	-- ---------------------------------------------------------------
	local by_guild = {}  -- guild -> { items }
	local no_guild = {}  -- items with no guild

	for _, item in ipairs(remaining) do
		local guild = item.entry["guild"]
		if guild and guild ~= "" then
			if not by_guild[guild] then
				by_guild[guild] = {}
			end
			by_guild[guild][#by_guild[guild] + 1] = item
		else
			no_guild[#no_guild + 1] = item
		end
	end

	local guild_list = {}
	for guild, items in pairs(by_guild) do
		guild_list[#guild_list + 1] = { guild = guild, items = items }
	end
	table.sort(guild_list, function(a, b)
		return #a.items > #b.items
	end)

	for _, g in ipairs(guild_list) do
		if #g.items >= 2 then
			local hunters = {}  -- normName -> list of items
			local min_level = 999
			local max_level = 0
			for _, item in ipairs(g.items) do
				local norm = normalizeName(item.entry["name"])
				if norm then
					norm = norm:lower()
					if not hunters[norm] then
						hunters[norm] = {}
					end
					hunters[norm][#hunters[norm] + 1] = item
				end
				local lvl = item.entry["level"] or 30
				local max_lvl = estimateMaxLevel(lvl, item.entry["date"] or 0)
				if lvl < min_level then min_level = lvl end
				if max_lvl > max_level then max_level = max_lvl end
			end

			local filter = string.format('g-"%s" c-"%s" %d-%d',
				g.guild, hunterClassName, min_level, max_level)

			queue[#queue + 1] = {
				type = "guild_batch",
				guild = g.guild,
				filter = filter,
				hunters = hunters,   -- normName(lower) -> {item,...}
				count = #g.items,
			}
		else
			-- Single-hunter guild → individual query
			for _, item in ipairs(g.items) do
				queue[#queue + 1] = { type = "individual", item = item }
			end
		end
	end

	-- Phase 2c: no-guild individuals
	for _, item in ipairs(no_guild) do
		queue[#queue + 1] = { type = "individual", item = item }
	end

	return queue
end

---------------------------------------------------------------------------
-- Raw /who – guild batch query (bypasses DNL's single-name system)
---------------------------------------------------------------------------

-- Own event frame for WHO_LIST_UPDATE so we don't collide with DNL's
-- single-name handler (which early-returns when its who_is_running is false).
local raw_who_frame = CreateFrame("Frame", "DeathlogPurgeWhoFrame")
local raw_who_callback = nil
local raw_who_timeout = nil

raw_who_frame:RegisterEvent("WHO_LIST_UPDATE")
raw_who_frame:SetScript("OnEvent", function()
	if not raw_who_callback then return end

	local results = {}
	local num = C_FriendList.GetNumWhoResults()
	for i = 1, (num or 0) do
		local info = C_FriendList.GetWhoInfo(i)
		if info then
			results[#results + 1] = info
		end
	end

	if raw_who_timeout then
		raw_who_timeout:Cancel()
		raw_who_timeout = nil
	end

	if FriendsFrame then
		FriendsFrame:RegisterEvent("WHO_LIST_UPDATE")
	end

	local cb = raw_who_callback
	raw_who_callback = nil
	cb(results)
end)

--- Send a raw /who filter and receive ALL results via callback.
--- Must be called from hardware-event context.
local function sendRawWho(filter, callback)
	raw_who_callback = callback
	raw_who_timeout = C_Timer.NewTimer(5, function()
		raw_who_timeout = nil
		if FriendsFrame then
			FriendsFrame:RegisterEvent("WHO_LIST_UPDATE")
		end
		local cb = raw_who_callback
		raw_who_callback = nil
		if cb then cb({}) end
	end)

	if FriendsFrame then
		FriendsFrame:UnregisterEvent("WHO_LIST_UPDATE")
	end
	C_FriendList.SetWhoToUi(true)
	C_FriendList.SendWho(filter)
end

---------------------------------------------------------------------------
-- Phase 2 – Drain one work item per player input
---------------------------------------------------------------------------

--- Check if we should skip draining right now.
local function shouldThrottle()
	-- Already in flight
	if who_pending then return true end
	-- Cooldown not elapsed
	if (GetTime() - last_who_time) < PURGE_WHO_COOLDOWN then return true end
	-- User has the Who panel open — don't steal their results
	if FriendsFrame and FriendsFrame:IsShown() then return true end
	return false
end

local function drainOneWorkItem()
	-- Loop instead of recursing so pre-resolved items don't grow the stack.
	-- Async /who paths break out via return; skipped items loop back.
	while true do
		if shouldThrottle() then return end
		if not work_queue then return end

		work_idx = work_idx + 1
		if work_idx > work_total then
			phase2_complete = true
			if DEBUG then
				print(string.format(
					"|cffFFFF00[Deathlog]|r Phase 2 complete — |cff44FF44%d purged|r, |cffFF8844%d kept|r. (%d /who queries sent)",
					phase2_purged, phase2_kept, total_who_queries))
			end
			work_queue = nil
			return
		end

		local work = work_queue[work_idx]
		local realmName = purge_realm
		local db = deathlog_data[realmName]
		local purged_set = deathlog_purged[realmName]

		if work.type == "level_band" then
			who_pending = true
			last_who_time = GetTime()
			total_who_queries = total_who_queries + 1
			if DEBUG then
				print(string.format(
					"|cffFFFF00[Deathlog]|r /who [%d/%d] level band: %d-%d (%d hunters in range) …",
					work_idx, work_total, work.band[1], work.band[2], work.count))
			end

			sendRawWho(work.filter, function(results)
				who_pending = false

				local band_purged = 0
				for _, info in ipairs(results) do
					local norm = normalizeName(info.fullName)
					if norm then
						norm = norm:lower()
						if work.band_names[norm] and work.all_by_name[norm] then
							-- Found alive — purge all entries for this name
							local items = work.all_by_name[norm]
							for _, item in ipairs(items) do
								if not purged_set[item.checksum] then
									purgeEntry(realmName, db, purged_set, item.checksum, item.entry)
									phase2_purged = phase2_purged + 1
									band_purged = band_purged + 1
								end
							end
							-- Remove from shared lookup so later phases skip them
							work.all_by_name[norm] = nil
						end
					end
				end

				if DEBUG then
					print(string.format(
						"  lvl %d-%d: %d online result(s), |cff44FF44%d purged|r from our list",
						work.band[1], work.band[2], #results, band_purged))
				end
			end)
			return

		elseif work.type == "guild_batch" then
			-- Check if all hunters in this batch were already resolved (e.g. by band sweep)
			local any_unresolved = false
			for _, items in pairs(work.hunters) do
				for _, item in ipairs(items) do
					if not purged_set[item.checksum] then
						any_unresolved = true
						break
					end
				end
				if any_unresolved then break end
			end
			if not any_unresolved then
				-- All resolved — skip to next work item (loop continues)
			else
				who_pending = true
				last_who_time = GetTime()
				total_who_queries = total_who_queries + 1
				if DEBUG then
					print(string.format(
						"|cffFFFF00[Deathlog]|r /who [%d/%d] guild batch: <%s> (%d hunters) …",
						work_idx, work_total, work.guild, work.count))
				end

				sendRawWho(work.filter, function(results)
					who_pending = false

					-- Build set of names found alive
					local alive_set = {}
					for _, info in ipairs(results) do
						local norm = normalizeName(info.fullName)
						if norm then
							alive_set[norm:lower()] = info
						end
					end

					-- Check each hunter in this batch
					local batch_purged = 0
					local batch_kept = 0
					for norm_name, items in pairs(work.hunters) do
						if alive_set[norm_name] then
							-- Found alive → purge all entries for this name
							for _, item in ipairs(items) do
								if not purged_set[item.checksum] then
									purgeEntry(realmName, db, purged_set, item.checksum, item.entry)
									phase2_purged = phase2_purged + 1
									batch_purged = batch_purged + 1
								end
							end
						else
							-- Not found (offline or dead) → keep
							for _, item in ipairs(items) do
								if not purged_set[item.checksum] then
									phase2_kept = phase2_kept + 1
									batch_kept = batch_kept + 1
								end
							end
						end
					end

					if DEBUG then
						print(string.format(
							"  <%s>: %d online result(s), |cff44FF44%d purged|r, |cffFF8844%d kept|r",
							work.guild, #results, batch_purged, batch_kept))
					end
				end)
				return
			end

		elseif work.type == "individual" then
			local item = work.item
			local name = item.entry["name"]
			local entry_level = item.entry["level"] or 0

			-- Skip if already resolved by a prior phase (level band sweep)
			if purged_set[item.checksum] then
				-- Loop continues to next work item
			else
				who_pending = true
				last_who_time = GetTime()
				total_who_queries = total_who_queries + 1

				-- Progress every 10 individual queries
				if work_idx == 1 or work_idx % 10 == 0 then
					if DEBUG then
						print(string.format("|cffFFFF00[Deathlog]|r /who [%d/%d] individual: %s (lvl %d) …",
							work_idx, work_total, name, entry_level))
					end
				end

				DeathNotificationLib.WhoPlayer(name, function(info)
					who_pending = false
					if info then
						local who_level = info.level or 0
						if who_level >= entry_level then
							purgeEntry(realmName, db, purged_set, item.checksum, item.entry)
							phase2_purged = phase2_purged + 1
							if DEBUG then
								print(string.format(
									"  |cff44FF44ALIVE|r — %s is level %d, purged fake death.",
									name, who_level))
							end
						else
							phase2_kept = phase2_kept + 1
							if DEBUG then
								print(string.format(
									"  |cffFF8844KEPT|r — %s found at level %d (entry was %d).",
									name, who_level, entry_level))
							end
						end
					else
						phase2_kept = phase2_kept + 1
						if DEBUG then
							print(string.format(
								"  |cffFF8844KEPT|r — %s not found (offline or dead).",
								name))
						end
					end
				end)
				return
			end
		end
	end -- while true
end

---------------------------------------------------------------------------
-- Auto-start (called from deathlog.lua on PLAYER_ENTERING_WORLD)
---------------------------------------------------------------------------

function deathlog_startHunterCleanup()
	-- Hard cutoff: no purge activity after the expiry date
	if GetServerTime() > PURGE_EXPIRY then
		if DEBUG then
			print("|cffFFFF00[Deathlog]|r Hunter cleanup expired (past cutoff date). Skipping.")
		end
		return
	end

	local realmName = GetRealmName()
	local db = deathlog_data[realmName]
	if not db then
		if DEBUG then
			print("|cffFFFF00[Deathlog]|r No death data on this realm.")
		end
		return
	end

	if deathlog_purged[realmName] == nil then
		deathlog_purged[realmName] = {}
	end
	local purged = deathlog_purged[realmName]

	-- Precomputed purges: remove known-bad entries shipped with the addon
	-- (don't add to deathlog_purged — they're always available from the data file)
	if precomputed_purges[realmName] then
		local precomp_purged = 0
		for cs, _ in pairs(precomputed_purges[realmName]) do
			if cs ~= "_phase1_complete" and db[cs] then
				local name = db[cs]["name"]
				db[cs] = nil
				if deathlog_data_map[realmName] and deathlog_data_map[realmName][name] == cs then
					deathlog_data_map[realmName][name] = nil
				end
				precomp_purged = precomp_purged + 1
			end
		end
		if precomp_purged > 0 then
			print("|cFF00FF00[Deathlog]|r Database cleanup: removed " .. precomp_purged .. " invalid entries.")
		end
	end

	-- Collect remaining eligible hunters (not yet purged)
	local function collectRemaining()
		local items = {}
		local seen_names = {}
		for cs, entry in pairs(db) do
			if entry["class_id"] == HUNTER_CLASS_ID
				and (entry["level"] or 0) >= 30
				and (entry["date"] or 0) >= FD_BUG_CUTOFF
				and not purged[cs]
			then
				local name = entry["name"] or "?"
				-- Keep only the newest entry per name (duplicates already purged)
				if not seen_names[name] or (entry["date"] or 0) > (seen_names[name].entry["date"] or 0) then
					seen_names[name] = { checksum = cs, entry = entry }
				end
			end
		end
		for _, item in pairs(seen_names) do
			items[#items + 1] = item
		end
		return items
	end

	-- Phase 1: only runs once ever (persisted flag)
	local remaining
	if not purged["_phase1_complete"] then
		local total_eligible, dup_purged
		remaining, total_eligible, dup_purged = runDuplicatePass(realmName, db, purged)
		if not remaining then
			return
		end

		if DEBUG then
			print(string.format(
				"|cffFFFF00[Deathlog]|r Phase 1a — |cff44FF44%d duplicate(s) purged|r out of %d eligible Hunter entries.",
				dup_purged, total_eligible))
		end

		local cluster_purged
		remaining, cluster_purged = runClusterPass(realmName, db, purged, remaining)

		if DEBUG then
			print(string.format(
				"|cffFFFF00[Deathlog]|r Phase 1b — |cff44FF44%d cluster(s) purged|r (hunter-only instance/raid wipe detection).",
				cluster_purged))
		end

		purged["_phase1_complete"] = true

		-- SKIP FOR NOW
		if true then return end
	else
		-- SKIP FOR NOW
		if true then return end

		-- Phase 1 already done in a prior session — collect what's left
		remaining = collectRemaining()
	end

	if #remaining == 0 then
		if not phase2_complete then
			if DEBUG then
				print("|cffFFFF00[Deathlog]|r No remaining Hunter entries to /who-verify.")
			end
		end
		return
	end

	-- Build Phase 2 work queue (runs every session — players may come online)
	if not work_queue and not phase2_complete then
		purge_realm = realmName
		work_queue = buildWorkQueue(remaining)
		work_idx = 0
		work_total = #work_queue
		phase2_purged = 0
		phase2_kept = 0
		phase2_complete = false
		total_who_queries = 0

		local n_bands = 0
		local n_batches = 0
		local n_individual = 0
		for _, w in ipairs(work_queue) do
			if w.type == "level_band" then
				n_bands = n_bands + 1
			elseif w.type == "guild_batch" then
				n_batches = n_batches + 1
			else
				n_individual = n_individual + 1
			end
		end

		---------------------------------------------------------------------------
		-- Input hooks — fire drainOneWorkItem on every player interaction
		---------------------------------------------------------------------------

		WorldFrame:HookScript("OnMouseDown", function()
			drainOneWorkItem()
		end)

		do
			local kf = CreateFrame("Frame", "DeathlogPurgeInputFrame", UIParent)
			kf:SetScript("OnKeyDown", function()
				drainOneWorkItem()
			end)
			kf:SetPropagateKeyboardInput(true)
		end

		if DEBUG then
			print(string.format(
				"|cffFFFF00[Deathlog]|r %d unique Hunters queued: %d band sweep(s) + %d guild batch(es) + %d individual. Drains on input.",
				#remaining, n_bands, n_batches, n_individual))
		end
		return
	end

	-- If called again (e.g. /dl cleanup), print status
	if work_queue then
		if DEBUG then
			print(string.format(
				"|cffFFFF00[Deathlog]|r /who queue: %d / %d processed (%d purged, %d kept, %d queries sent). Draining on input…",
				work_idx, work_total, phase2_purged, phase2_kept, total_who_queries))
		end
	elseif phase2_complete then
		if DEBUG then
			print("|cffFFFF00[Deathlog]|r Cleanup already finished this session.")
		end
	end
end
