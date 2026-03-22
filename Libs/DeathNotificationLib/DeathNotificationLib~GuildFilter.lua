--[[
DeathNotificationLib~GuildFilter.lua

Guild filtering module that supports GreenWall multi-guild confederations.
Provides a unified API for filtering death entries by guild membership.

This module is self-contained and does not depend on any host addon.
It directly queries the GreenWall global `gw` when available.

Key entry points:
  DeathNotificationLib.PassesGuildFilterMode(entry, filter_mode)
  DeathNotificationLib.GetGuildFilterModeOptions()
  DeathNotificationLib.GetGreenWallStatus()
--]]

local _dnl = DeathNotificationLib.Internal ---@class _dnl
if not _dnl then return end

-- ── guild member cache ───────────────────────────────────────────────
-- Refreshed periodically to track current guild roster
local _player_guild = nil
local _confederation_guilds = {}  -- guild_name → true
local _guild_members = {}  -- player_name (short) → true

--- Check if GreenWall addon is loaded
---@return boolean
local function isGreenWallAvailable()
	return type(gw) == "table" and type(gw.config) == "table"
end

--- Check if GreenWall config is fully initialized (peers parsed)
---@return boolean
local function isGreenWallConfigured()
	return isGreenWallAvailable() and gw.config.valid == true
end

--- Get the list of confederation guilds from GreenWall
--- Returns an empty table if GreenWall is not available
---@return table<string, boolean> Map of guild names that are in the confederation
local function getConfederationGuilds()
	local guilds = {}
	
	-- Add player's own guild
	local myGuild = GetGuildInfo("player")
	if myGuild then
		guilds[myGuild] = true
	end
	
	-- If GreenWall is available, add confederation peers
	if isGreenWallAvailable() and gw.config.peer then
		for _, peer_name in pairs(gw.config.peer) do
			if peer_name and peer_name ~= "" then
				-- Remove realm suffix if present
				local short_name = peer_name:match("^([^%-]+)") or peer_name
				guilds[short_name] = true
			end
		end
	end
	
	return guilds
end

--- Refresh the guild member cache
local function refreshGuildMembers()
	_guild_members = {}
	local numTotal = GetNumGuildMembers()
	for i = 1, numTotal do
		local name = GetGuildRosterInfo(i)
		if name then
			local short_name = name:match("^([^%-]+)") or name
			_guild_members[short_name] = true
		end
	end
	
	-- Cache player's guild
	_player_guild = GetGuildInfo("player")
	
	-- Refresh confederation guilds
	_confederation_guilds = getConfederationGuilds()
end

-- Exposed on _dnl so Events.lua can call it from initializeOnFirstReady
_dnl.refreshGuildMembers = refreshGuildMembers
C_Timer.NewTicker(10, refreshGuildMembers)

--- Check if a guild name is in the player's guild or GreenWall confederation
---@param guildName string|nil The guild name to check
---@return boolean True if the guild is the player's guild or a confederation member
local function isGuildOrConfederation(guildName)
	if not guildName or guildName == "" then
		return false
	end
	
	-- Direct match with player's guild
	if _player_guild and guildName == _player_guild then
		return true
	end
	
	-- Check confederation guilds (includes player's guild)
	if _confederation_guilds[guildName] then
		return true
	end
	
	-- If GreenWall is available, use its is_peer function as fallback
	if isGreenWallAvailable() and gw.config.is_peer then
		return gw.config:is_peer(guildName)
	end
	
	return false
end

--- Check if a player is in the player's guild
---@param playerName string|nil The player name to check (can be with or without realm)
---@return boolean True if the player is in the player's guild
local function isGuildMember(playerName)
	if not playerName then
		return false
	end
	
	local short_name = playerName:match("^([^%-]+)") or playerName
	return _guild_members[short_name] == true
end

--- Check if an entry passes the guild filter based on the filter mode
--- This is the main public API for filtering entries.
---@param entry table PlayerData entry with guild and name fields
---@param filter_mode string "all", "guild_only", "guild_confederation", or "none"
---@return boolean True if entry passes the guild filter
function _dnl.passesGuildFilterMode(entry, filter_mode)
	-- "none" mode blocks everything
	if filter_mode == "none" then
		return false
	end
	
	-- "all" mode passes everything
	if not filter_mode or filter_mode == "all" then
		return true
	end
	
	-- Fallback: confederation selected but GreenWall no longer available → guild_only
	if filter_mode == "guild_confederation" and not isGreenWallAvailable() then
		filter_mode = "guild_only"
	end
	
	if not entry then
		return false
	end
	
	local entryGuild = entry["guild"]
	local entryName = entry["name"]
	
	-- Check guild name match
	local guildMatches = false
	if entryGuild and entryGuild ~= "" then
		if filter_mode == "guild_confederation" then
			guildMatches = isGuildOrConfederation(entryGuild)
		else
			-- guild_only mode
			guildMatches = (_player_guild and entryGuild == _player_guild) or false
		end
	end
	
	-- Also verify guild membership for extra robustness (catches edge cases)
	local memberMatches = isGuildMember(entryName)
	
	-- Pass if either condition is true (guild name matches OR is known guild member)
	return guildMatches or memberMatches
end

--- Get filter mode options for settings UI
---@param exclude_none? boolean If true, omit the "None (Disabled)" option
---@return table Options for filter dropdown
function _dnl.getGuildFilterModeOptions(exclude_none)
	local options = {
		["all"] = "All Deaths",
		["guild_only"] = "Guild Only",
	}
	if not exclude_none then
		options["none"] = "None (Disabled)"
	end
	
	-- Only show GreenWall option if it's available
	if isGreenWallAvailable() then
		options["guild_confederation"] = "Guild + Confederation (GreenWall)"
	end
	
	return options
end

--- Get a human-readable GreenWall status string
---@return string Status message
function _dnl.getGreenWallStatus()
	if isGreenWallAvailable() then
		local count = 0
		if gw.config.peer then
			for _ in pairs(gw.config.peer) do
				count = count + 1
			end
		end
		if count > 0 then
			return "GreenWall active: " .. count .. " confederation guild(s) detected"
		else
			return "GreenWall active but no confederation peers configured"
		end
	else
		return "GreenWall not detected - install GreenWall addon for multi-guild support"
	end
end

-- ── Public API ───────────────────────────────────────────────────────

DeathNotificationLib.PassesGuildFilterMode = _dnl.passesGuildFilterMode

DeathNotificationLib.GetGuildFilterModeOptions = _dnl.getGuildFilterModeOptions

DeathNotificationLib.GetGreenWallStatus = _dnl.getGreenWallStatus
