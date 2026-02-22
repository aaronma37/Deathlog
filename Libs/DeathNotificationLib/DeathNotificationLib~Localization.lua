--[[
DeathNotificationLib~Localization.lua

Locale-aware data initialization.

At load time, selects the appropriate locale table from _dnl.L.* based on
the client language and wires it into the runtime data layer (_dnl.D.*).
Also builds reverse-lookup maps (ID → name) for instances and zones so
consumers can translate numeric IDs back to display strings.

Passthrough tables (available both internally and on the public API):
  NPC_TO_ID / ID_TO_NPC      – NPC name ↔ numeric ID
  AREA_TO_ID                  – area name → area ID
  INSTANCE_TO_ID / ID_TO_INSTANCE – instance name ↔ ID (reverse built here)
  ZONE_TO_ID / ID_TO_ZONE     – zone name ↔ ID (reverse built here)
  ID_TO_QUOTE                 – death flavor quotes by ID
  INSTANCE_CATEGORIES, ZONE_CATEGORIES, ZONE_TO_INSTANCE, ID_TO_DISPLAY_ID

This module is pure data wiring: it defines no functions.
--]]

local _dnl = DeathNotificationLib.Internal ---@class _dnl
if not _dnl then return end

local LOCALE_MAP = {
    ["deDE"] = _dnl.L.de,
    ["enGB"] = _dnl.L.en,
    ["enUS"] = _dnl.L.en,
    ["esES"] = _dnl.L.es,
    ["esMX"] = _dnl.L.es,
    ["frFR"] = _dnl.L.fr,
    ["itIT"] = _dnl.L.it,
    ["koKR"] = _dnl.L.ko,
    ["ptBR"] = _dnl.L.pt,
    ["ruRU"] = _dnl.L.ru,
    ["zhCN"] = _dnl.L.cn,
    ["zhTW"] = _dnl.L.cn,
}

local _localeTable = LOCALE_MAP[GetLocale()] or LOCALE_MAP["enUS"]

_dnl.D.ID_TO_NPC = _localeTable.ID_TO_NPC
_dnl.D.NPC_TO_ID = _localeTable.NPC_TO_ID
_dnl.D.AREA_TO_ID = _localeTable.AREA_TO_ID
_dnl.D.INSTANCE_TO_ID = _localeTable.INSTANCE_TO_ID
_dnl.D.ID_TO_INSTANCE = {}
for _, instances in pairs(_dnl.D.INSTANCE_TO_ID) do
    for instance_name, instance_id in pairs(instances) do
        _dnl.D.ID_TO_INSTANCE[instance_id] = instance_name
    end
end
_dnl.D.ZONE_TO_ID = _localeTable.ZONE_TO_ID
_dnl.D.ID_TO_ZONE = {}
for _, zones in pairs(_dnl.D.ZONE_TO_ID) do
    for zone_name, zone_id in pairs(zones) do
        _dnl.D.ID_TO_ZONE[zone_id] = zone_name
    end
end
_dnl.D.ID_TO_QUOTE = _localeTable.ID_TO_QUOTE
_dnl.D.STRINGS = _localeTable.STRINGS

_dnl.D.CLASS_ID_MAP = {}
_dnl.D.CLASS_FILE_TO_ID = {}
_dnl.D.CLASS_NAME_TO_ID = {}

for i = 1, 100, 1 do
    local info = C_CreatureInfo.GetClassInfo(i)
    if info then
        _dnl.D.CLASS_ID_MAP[info.classID] = true
        _dnl.D.CLASS_FILE_TO_ID[info.classFile] = info.classID
        _dnl.D.CLASS_NAME_TO_ID[info.className] = info.classID
    end
end

_dnl.D.RACE_ID_MAP = {}
_dnl.D.RACE_FILE_TO_ID = {}
_dnl.D.RACE_NAME_TO_ID = {}

for i = 1, 100, 1 do
    local info = C_CreatureInfo.GetRaceInfo(i)
    if info then
        _dnl.D.RACE_ID_MAP[info.raceID] = true
        _dnl.D.RACE_FILE_TO_ID[info.clientFileString] = info.raceID
        _dnl.D.RACE_NAME_TO_ID[info.raceName] = info.raceID
    end
end

_dnl.D.CLASS_COLORS = {}

for k, c in pairs(RAID_CLASS_COLORS) do
    local copy = CreateColor(c.r, c.g, c.b, c.a)
    copy.colorStr = c.colorStr

    _dnl.D.CLASS_COLORS[k] = copy
end

if _dnl.D.CLASS_COLORS["PALADIN"] and _dnl.D.CLASS_COLORS["SHAMAN"] and _dnl.D.CLASS_COLORS["PALADIN"].colorStr == _dnl.D.CLASS_COLORS["SHAMAN"].colorStr then
	local shaman_color = CreateColor(0 / 255, 112 / 255, 221 / 255)
	shaman_color.colorStr = "ff0070dd"
	_dnl.D.CLASS_COLORS["SHAMAN"] = shaman_color
end

local class_color_entries = {}
for k, v in pairs(_dnl.D.CLASS_COLORS) do
    local proper_name = k:sub(1, 1) .. k:sub(2):lower()
    class_color_entries[proper_name] = v
end

for k, v in pairs(class_color_entries) do
    _dnl.D.CLASS_COLORS[k] = v
end

_dnl.D.CLASS_ID_TO_COLOR = {}

for classFile, classID in pairs(_dnl.D.CLASS_FILE_TO_ID) do
    if _dnl.D.CLASS_COLORS[classFile] then
        _dnl.D.CLASS_ID_TO_COLOR[classID] = _dnl.D.CLASS_COLORS[classFile]
    end
end

--#region API

DeathNotificationLib.ID_TO_NPC = _dnl.D.ID_TO_NPC

DeathNotificationLib.NPC_TO_ID = _dnl.D.NPC_TO_ID

DeathNotificationLib.AREA_TO_ID = _dnl.D.AREA_TO_ID

DeathNotificationLib.INSTANCE_TO_ID = _dnl.D.INSTANCE_TO_ID

DeathNotificationLib.ID_TO_INSTANCE = _dnl.D.ID_TO_INSTANCE

DeathNotificationLib.ZONE_TO_ID = _dnl.D.ZONE_TO_ID

DeathNotificationLib.ID_TO_ZONE = _dnl.D.ID_TO_ZONE

DeathNotificationLib.ID_TO_QUOTE = _dnl.D.ID_TO_QUOTE

DeathNotificationLib.CLASS_ID_MAP = _dnl.D.CLASS_ID_MAP

DeathNotificationLib.CLASS_FILE_TO_ID = _dnl.D.CLASS_FILE_TO_ID

DeathNotificationLib.CLASS_NAME_TO_ID = _dnl.D.CLASS_NAME_TO_ID

DeathNotificationLib.CLASS_COLORS = _dnl.D.CLASS_COLORS

DeathNotificationLib.CLASS_ID_TO_COLOR = _dnl.D.CLASS_ID_TO_COLOR

DeathNotificationLib.RACE_ID_MAP = _dnl.D.RACE_ID_MAP

DeathNotificationLib.RACE_FILE_TO_ID = _dnl.D.RACE_FILE_TO_ID

DeathNotificationLib.RACE_NAME_TO_ID = _dnl.D.RACE_NAME_TO_ID

DeathNotificationLib.INSTANCE_CATEGORIES = _dnl.D.INSTANCE_CATEGORIES

DeathNotificationLib.ZONE_TO_INSTANCE = _dnl.D.ZONE_TO_INSTANCE

DeathNotificationLib.ID_TO_DISPLAY_ID = _dnl.D.ID_TO_DISPLAY_ID

DeathNotificationLib.ZONE_CATEGORIES = _dnl.D.ZONE_CATEGORIES

DeathNotificationLib.HEATMAP_INTENSITY = _dnl.D.HEATMAP_INTENSITY

DeathNotificationLib.HEATMAP_CREATURE_SUBSET = _dnl.D.HEATMAP_CREATURE_SUBSET

--#endregion