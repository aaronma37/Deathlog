--[[
DeathNotificationLib~UltraHardcore.lua

Bridge module that captures death announcements from the UltraHardcore
addon via guild chat and emote messages, converting them into DNL
death entries.

UltraHardcore announces deaths in a fixed format:
  "I've been slain at level %d by %s in %s. Their health was %s!"

This module listens on CHAT_MSG_GUILD and CHAT_MSG_EMOTE for messages
matching that pattern, extracts death data, enriches with guild roster
and GUID lookups, and feeds into the standard DNL pipeline.

Only processes messages when the UltraHardcore addon is loaded.
--]]

local _dnl = DeathNotificationLib.Internal ---@class _dnl
if not _dnl then return end

local ULTRA_ADDON_NAME = "UltraHardcore"

--- Set of instance_ids that are PvP zones (battlegrounds + arenas).
--- Unresolved death sources in these zones are assumed to be player kills.
local pvp_instance_ids = {}
for _, cat in ipairs({"Battleground", "Arena"}) do
	local ids = _dnl.D.INSTANCE_CATEGORIES and _dnl.D.INSTANCE_CATEGORIES[cat]
	if ids then
		for _, id in ipairs(ids) do
			pvp_instance_ids[id] = true
		end
	end
end

--- Pattern to match UltraHardcore death messages.
--- Captures: level (number), killer name, location, health text
local DEATH_PATTERN = "^I've been slain at level (%d+) by (.+) in (.+)%. Their health was (.+)!$"

--- Track processed deaths to avoid duplicates (emote + guild for the same death).
--- Key: "sender:level:floor(time/10)", value: true
---@type table<string, boolean>
local processed = {}

--- Cleanup interval for the processed dedup table.
local CLEANUP_INTERVAL = 300

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local enrichFromRoster = _dnl.enrichFromRoster
local raceClassFromGUID = _dnl.raceClassFromGUID

--- Attempt to resolve a zone name string to a map_id using DNL's data tables.
--- Tries AREA_TO_ID first (exact zone names), then falls back to iterating
--- ZONE_TO_ID categories.  When the current locale fails, iterates ALL
--- locale tables in _dnl.L so that cross-locale zone names (e.g. a German
--- player's death message read by an English client) can still be resolved.
---@param zone_name string
---@return number|nil map_id
local function resolveZoneToMapId(zone_name)
	if not zone_name then return nil end

	-- Fast path: current locale -------------------------------------------

	-- Try AREA_TO_ID first (maps localized zone names to map IDs)
	if _dnl.D.AREA_TO_ID[zone_name] then
		return _dnl.D.AREA_TO_ID[zone_name]
	end

	-- Fall back to ZONE_TO_ID (structured as {category → {name → id}})
	for _, zones in pairs(_dnl.D.ZONE_TO_ID) do
		if zones[zone_name] then
			return zones[zone_name]
		end
	end

	-- Slow path: iterate ALL locale tables --------------------------------
	-- Death messages arrive in the sender's locale, which may differ from
	-- the local client's.  Mirror the approach used by resolveDeathSource.
	for _, localeData in pairs(_dnl.L) do
		if localeData.AREA_TO_ID and localeData.AREA_TO_ID[zone_name] then
			return localeData.AREA_TO_ID[zone_name]
		end
		if localeData.ZONE_TO_ID then
			for _, zones in pairs(localeData.ZONE_TO_ID) do
				if zones[zone_name] then
					return zones[zone_name]
				end
			end
		end
	end

	return nil
end

--- Generate a dedup key for a death message.
---@param sender string
---@param level number|string
---@return string key
local function dedupKey(sender, level)
	-- Floor time to 10-second buckets so emote + guild messages for the
	-- same death (sent within seconds of each other) match.
	return sender .. ":" .. tostring(level) .. ":" .. tostring(math.floor(GetServerTime() / 10))
end

--- Process a potential UltraHardcore death message.
---@param text string     Chat message text
---@param sender string   Sender name (no realm)
---@param senderGUID string|nil  Sender GUID from chat event
local function processDeathMessage(text, sender, senderGUID)
	local level_str, killer_name, location, health_text = text:match(DEATH_PATTERN)
	if not level_str then return end

	local level = tonumber(level_str)
	if not level or level <= 0 then return end

	-- Dedup: skip if we already processed this death
	local key = dedupKey(sender, level)
	if processed[key] then return end
	processed[key] = true

	-- Resolve killer name to source_id
	local source_id, extra_data = _dnl.resolveDeathSource(killer_name, nil, true)

	-- Resolve location: UltraHardcore uses subZone + ", " + zone or just zone.
	-- Try the full string first, then just the part after the last comma.
	local map_id = resolveZoneToMapId(location)
	local instance_id = nil

	if not map_id then
		-- Try extracting just the zone part (after last ", ")
		local zone_part = location:match(".*,%s*(.+)$")
		if zone_part then
			map_id = resolveZoneToMapId(zone_part)
		end
	end

	-- Check if this map_id is actually an instance
	if map_id and _dnl.D.ZONE_TO_INSTANCE and _dnl.D.ZONE_TO_INSTANCE[map_id] then
		instance_id = _dnl.D.ZONE_TO_INSTANCE[map_id]
	end

	-- If source is still unresolved and the death happened in a BG/Arena,
	-- assume killer_name is a player name and encode as a minimal PvP kill.
	if source_id == -1 and killer_name and instance_id and pvp_instance_ids[instance_id] then
		local success, pvp_source, pvp_source_name = _dnl.encodePvpSource(killer_name, nil)
		if success then
			source_id = pvp_source
			if pvp_source_name then
				if not extra_data then extra_data = {} end
				extra_data["pvp_source_name"] = pvp_source_name
			end
		end
	end

	-- Enrich sender with race/class/guild from GUID and roster
	local race_id, class_id
	if senderGUID then
		race_id, class_id = raceClassFromGUID(senderGUID)
	end

	local roster_class, _, guild = enrichFromRoster(sender)
	class_id = class_id or roster_class
	-- Guild: if sender posted to GUILD chat they're in the player's guild
	if not guild then
		guild = GetGuildInfo("player") or ""
	end

	-- Store killer health in extra_data if available
	if health_text and health_text ~= "Unknown" then
		if not extra_data then extra_data = {} end
		extra_data["killer_health"] = health_text
	end

	local player_data = _dnl.playerData(
		sender,
		guild,
		source_id,
		race_id,
		class_id,
		level,
		instance_id,
		(not instance_id) and map_id or nil,
		nil,          -- map_pos: not available from chat message
		GetServerTime(),
		nil,          -- played: not available
		nil,          -- last_words: not available
		extra_data
	)

	if not _dnl.isValidEntry(player_data) then
		if _dnl.DEBUG then
			print("[DNL~UltraHardcore] Invalid entry for:", sender, "- missing required fields")
		end
		return
	end

	-- Feed through the standard broadcast handler for dedup + LRU pipeline
	local encoded = _dnl.encodeMessage(player_data)
	if encoded then
		_dnl.handleDeathBroadcast(sender, encoded)
	end

	if _dnl.DEBUG then
		print(string.format(
			"[DNL~UltraHardcore] Captured death: %s lv%d killed by %s in %s",
			sender, level, killer_name, location
		))
	end
end

---------------------------------------------------------------------------
-- Event handler
---------------------------------------------------------------------------

local handlerFrame = CreateFrame("Frame")
handlerFrame:RegisterEvent("PLAYER_LOGIN")

handlerFrame:SetScript("OnEvent", function(self, event, ...)
	if event == "PLAYER_LOGIN" then
		self:UnregisterEvent("PLAYER_LOGIN")

		-- Only activate if UltraHardcore is loaded
		local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
		if not isLoaded(ULTRA_ADDON_NAME) then
			if _dnl.DEBUG then
				print("[DNL~UltraHardcore] UltraHardcore not loaded – module inactive")
			end
			return
		end

		-- Register chat events for death message sniffing
		self:RegisterEvent("CHAT_MSG_GUILD")
		self:RegisterEvent("CHAT_MSG_EMOTE")

		-- Periodic cleanup of the dedup table
		C_Timer.NewTicker(CLEANUP_INTERVAL, function()
			local cutoff_bucket = math.floor(GetServerTime() / 10) - 3 -- keep ~30s window
			for k in pairs(processed) do
				-- Extract the time bucket from the key (last colon-separated segment)
				local bucket = tonumber(k:match(":(%d+)$"))
				if bucket and bucket < cutoff_bucket then
					processed[k] = nil
				end
			end
		end)

		if _dnl.DEBUG then
			print("[DNL~UltraHardcore] Module active – listening for death announcements")
		end
		return
	end

	-- CHAT_MSG_GUILD or CHAT_MSG_EMOTE
	local text = select(1, ...)
	local sender_full = select(2, ...)
	local senderGUID = select(12, ...)

	-- Strip realm from sender name
	local sender = sender_full and _dnl.normalize(sender_full) or sender_full

	if not text or not sender then return end

	-- Skip own messages (we handle our own death via ~Events.lua)
	if sender == UnitName("player") then return end

	processDeathMessage(text, sender, senderGUID)
end)

---------------------------------------------------------------------------
-- Expose for testing
---------------------------------------------------------------------------

if _dnl.DEBUG then
	_dnl._ultra = {
		processDeathMessage = processDeathMessage,
		resolveZoneToMapId = resolveZoneToMapId,
		DEATH_PATTERN = DEATH_PATTERN,
	}
end
