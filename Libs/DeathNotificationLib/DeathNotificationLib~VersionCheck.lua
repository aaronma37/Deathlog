--[[
DeathNotificationLib~VersionCheck.lua

Addon version broadcasting on social channels (party, raid, guild, instance).

When the player joins a group, raid, instance, or comes online in a guild,
broadcasts the addon version for each registered addon.  Peers compare the
received version with their own:
  • If the received version is newer → show an update-available chat message.
  • If the received version is older → whisper back our version so the
    sender learns about the update.

Uses a dedicated addon-message prefix ("HCDeathVer") so it doesn't
interfere with the death-alert or sync protocols.

Wire format (fields separated by COMM_FIELD_DELIM "~"):
  V$TAG~version~       – version announcement (PARTY/RAID/GUILD/INSTANCE_CHAT)
  N$TAG~version~       – newer-version notification (WHISPER response)
--]]

local _dnl = DeathNotificationLib.Internal ---@class _dnl
if not _dnl then return end

---------------------------------------------------------------------------
-- Constants
---------------------------------------------------------------------------

_dnl.VERSION_CHECK_COMM_NAME = "HCDeathVer"

local CMD_VERSION_ANNOUNCE = "V"
local CMD_NEWER_NOTIFY     = "N"

--- Per-session tracking to avoid spamming the same notification.
--- { [tag .. ":" .. version] = true }
local warned_versions = {}

--- Cooldown per channel type to avoid spamming on rapid group changes (seconds).
local ANNOUNCE_COOLDOWN = 120

--- Last announce time per channel type: { ["PARTY"] = time, ... }
local last_announce_time = {}

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

---Send an addon message via ChatThrottleLib if available, else raw.
---@param prefix string  Addon message prefix
---@param text string    Message body
---@param chatType string  "PARTY", "RAID", "GUILD", "INSTANCE_CHAT", or "WHISPER"
---@param target string|nil  Required for WHISPER
local function sendAddonMsg(prefix, text, chatType, target)
	if _G.ChatThrottleLib then
		_G.ChatThrottleLib:SendAddonMessage("BULK", prefix, text, chatType, target)
	else
		if target then
			_G.SendAddonMessage(prefix, text, chatType, target)
		else
			_G.SendAddonMessage(prefix, text, chatType)
		end
	end
end

---------------------------------------------------------------------------
-- Announce
---------------------------------------------------------------------------

---Broadcast our addon version(s) on the given channel type.
---Sends one message per registered addon that has an addon_version.
---@param chatType string  "PARTY", "RAID", "GUILD", or "INSTANCE_CHAT"
local function announceVersion(chatType)
	local now = GetServerTime()
	if last_announce_time[chatType] and (now - last_announce_time[chatType]) < ANNOUNCE_COOLDOWN then
		return
	end
	last_announce_time[chatType] = now

	for _, addon in pairs(_dnl.addons) do
		if addon.addon_version and addon.tag then
			local msg = CMD_VERSION_ANNOUNCE
				.. _dnl.COMM_COMMAND_DELIM
				.. addon.tag .. _dnl.COMM_FIELD_DELIM
				.. addon.addon_version .. _dnl.COMM_FIELD_DELIM
			sendAddonMsg(_dnl.VERSION_CHECK_COMM_NAME, msg, chatType)
		end
	end
end

---Broadcast version on all currently applicable channels.
local function announceOnAllChannels()
	if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
		announceVersion("INSTANCE_CHAT")
	elseif IsInRaid() then
		announceVersion("RAID")
	elseif IsInGroup() then
		announceVersion("PARTY")
	end
	if IsInGuild() then
		announceVersion("GUILD")
	end
end

---------------------------------------------------------------------------
-- Receive
---------------------------------------------------------------------------

---Handle a version announcement from a peer.
---@param sender string  Sender character name
---@param tag string     3-char addon tag
---@param remote_ver string  Remote addon version
---@param chatType string  Channel the message came from
local function handleVersionAnnounce(sender, tag, remote_ver, chatType)
	if sender == UnitName("player") then return end
	if not remote_ver or remote_ver == "" then return end

	local addon_name = _dnl.tag_to_addon[tag]
	if not addon_name then return end
	local local_addon = _dnl.addons[addon_name]
	if not local_addon or not local_addon.addon_version then return end

	local cmp = _dnl.compareVersions(remote_ver, local_addon.addon_version)
	if not cmp then return end

	if cmp > 0 then
		-- Remote is newer — we need to update
		local warn_key = tag .. ":" .. remote_ver
		if not warned_versions[warn_key] then
			warned_versions[warn_key] = true

			-- Update newest_detected_version
			if not local_addon.newest_detected_version
				or _dnl.compareVersions(remote_ver, local_addon.newest_detected_version) == 1 then
				local_addon.newest_detected_version = remote_ver
			end

			print(string.format(
				"|cffFFFF00[%s]|r A newer version (v%s) is available — you are running v%s. Please update!",
				local_addon.name, remote_ver, local_addon.addon_version))

			if _dnl.hook_newer_version_functions then
				for _, fn in ipairs(_dnl.hook_newer_version_functions) do
					fn(local_addon.name, remote_ver, local_addon.addon_version)
				end
			end
		end
	elseif cmp < 0 then
		-- Remote is older — whisper them our version so they know
		local msg = CMD_NEWER_NOTIFY
			.. _dnl.COMM_COMMAND_DELIM
			.. tag .. _dnl.COMM_FIELD_DELIM
			.. local_addon.addon_version .. _dnl.COMM_FIELD_DELIM
		sendAddonMsg(_dnl.VERSION_CHECK_COMM_NAME, msg, "WHISPER", sender)
	end
end

---Handle a newer-version whisper notification.
---@param sender string  Sender character name
---@param tag string     3-char addon tag
---@param remote_ver string  The sender's (newer) version
local function handleNewerNotify(sender, tag, remote_ver)
	if sender == UnitName("player") then return end
	if not remote_ver or remote_ver == "" then return end

	local addon_name = _dnl.tag_to_addon[tag]
	if not addon_name then return end
	local local_addon = _dnl.addons[addon_name]
	if not local_addon or not local_addon.addon_version then return end

	local cmp = _dnl.compareVersions(remote_ver, local_addon.addon_version)
	if not cmp or cmp <= 0 then return end

	local warn_key = tag .. ":" .. remote_ver
	if warned_versions[warn_key] then return end
	warned_versions[warn_key] = true

	if not local_addon.newest_detected_version
		or _dnl.compareVersions(remote_ver, local_addon.newest_detected_version) == 1 then
		local_addon.newest_detected_version = remote_ver
	end

	print(string.format(
		"|cffFFFF00[%s]|r A newer version (v%s) is available — you are running v%s. Please update!",
		local_addon.name, remote_ver, local_addon.addon_version))

	if _dnl.hook_newer_version_functions then
		for _, fn in ipairs(_dnl.hook_newer_version_functions) do
			fn(local_addon.name, remote_ver, local_addon.addon_version)
		end
	end
end

---------------------------------------------------------------------------
-- CHAT_MSG_ADDON dispatch
---------------------------------------------------------------------------

---Handle an incoming addon message on the VERSION_CHECK_COMM_NAME prefix.
---Called from the main event dispatcher in ~Events.lua.
---@param arg table  CHAT_MSG_ADDON event args: {prefix, message, chatType, sender}
function _dnl.handleVersionCheckAddonMessage(arg)
	local prefix = arg[1]
	if prefix ~= _dnl.VERSION_CHECK_COMM_NAME then return end

	local message  = arg[2]
	local chatType = arg[3]
	local sender   = arg[4]

	-- Strip realm suffix if present ("Player-Realm" → "Player")
	if sender then
		sender = Ambiguate(sender, "short")
	end

	local command, payload = string.split(_dnl.COMM_COMMAND_DELIM, message)
	if not command or not payload then return end

	-- Parse "TAG~version~" from payload
	local tag, remote_ver
	local iter = payload:gmatch("(.-)~")
	tag = iter()
	remote_ver = iter()

	if not tag or not remote_ver then return end

	if command == CMD_VERSION_ANNOUNCE then
		handleVersionAnnounce(sender, tag, remote_ver, chatType)
	elseif command == CMD_NEWER_NOTIFY then
		handleNewerNotify(sender, tag, remote_ver)
	end
end

---------------------------------------------------------------------------
-- Event triggers
---------------------------------------------------------------------------

---Called when events indicate the player may have joined a new social
---context (group, raid, guild login, instance).  Waits a short delay
---to let the client settle, then broadcasts version.
function _dnl.versionCheckOnSocialJoin()
	-- Small delay so channel membership is fully established
	C_Timer.After(3, announceOnAllChannels)
end

---------------------------------------------------------------------------
-- Test-only internals (gated on DEBUG)
---------------------------------------------------------------------------
if _dnl.DEBUG then
	_dnl._vc_warned_versions   = warned_versions
	_dnl._vc_last_announce_time = last_announce_time
	_dnl._vc_CMD_VERSION_ANNOUNCE = CMD_VERSION_ANNOUNCE
	_dnl._vc_CMD_NEWER_NOTIFY    = CMD_NEWER_NOTIFY
end
