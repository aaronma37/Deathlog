---@alias DeathStatEntry { num_entries: number, sum_lvl: number, avg_lvl: number }
---@alias PrecomputedGeneralStatsTable table<string|number, DeathStatEntry|table<string|number, any>>

---@alias KaplanMeierCurve table<number, number>
---@alias PrecomputedKaplanMeierTable table<number, KaplanMeierCurve>

---@alias LogNormalParamsTuple table<number, number>
---@alias LogNormalParamsByClass table<number, LogNormalParamsTuple>
---@alias PrecomputedLogNormalParamsTable table<string|number, LogNormalParamsByClass>

---@alias PrecomputedMostDeadlyByZoneTable table<number, table<number, number>>

---@alias PrecomputedPurgeTable table<string, table<string, boolean>>

--- Hardcore addon (Classic Era) per-character SavedVariable
---@class HardcoreCharacter
---@field guid string | nil
---@field first_recorded number | nil
---@field deaths table | nil
---@field verification_status string | nil
---@type HardcoreCharacter | nil
Hardcore_Character = nil

--- HardcoreTBC addon SavedVariable
---@class HardcoreTBCSaved
---@field ga table<string, any> | nil
---@type HardcoreTBCSaved | nil
HardcoreTBC_Saved = nil

--- HardcoreTBC distributed log database
---@class HardcoreTBCDistributedEvent
---@field type number
---@field ignored boolean | nil
---@field guid string | nil
---@class HardcoreTBCGuildData
---@field events table<string, HardcoreTBCDistributedEvent> | nil
---@type table<string, HardcoreTBCGuildData> | nil
HardcoreTBC_DistributedLogDB = nil

--- UltraHardcore addon SavedVariable
---@class UltraHardcoreCharacterStats
---@field playerDeaths number | nil
---@class UltraHardcoreDB
---@field characterSettings table<string, any> | nil
---@field characterStats table<string, UltraHardcoreCharacterStats> | nil
---@type UltraHardcoreDB | nil
UltraHardcoreDB = nil

--- Hardcore addon global SavedVariable (Classic Era)
---@class HardcoreDeathLogEntry
---@field name string | nil
---@field guild string | nil
---@field level number | nil
---@field source_id number | nil
---@field date string | nil
---@field class_id number | nil
---@field race_id number | nil
---@field map_pos string | nil
---@field map_id number | nil
---@field instance_id number | nil
---@field played number | nil
---@field last_words string | nil
---@class HardcoreSettings
---@field death_log_entries HardcoreDeathLogEntry[] | nil
---@type HardcoreSettings | nil
Hardcore_Settings = nil

--- AceGUI custom widget types used by Deathlog
---@class AceGUIDeathlogMenu : AceGUIFrame
---@field exit_button any
---@field exit_button_x any
---@field contact_button any
---@field SetVersion fun(self: AceGUIDeathlogMenu, version: string)

---@class AceGUIDeathlogTabGroup : AceGUITabGroup

---@class DeathlogMiniLog : AceGUIFrame
---@field subtitletext_tbl table
---@field info_button any
---@field SetSubTitle fun(self: DeathlogMiniLog, data: table)
---@field SetSubTitleOffset fun(self: DeathlogMiniLog, x: number, y: number, data: table)
---@field Minimize fun(self: DeathlogMiniLog)
---@field Maximize fun(self: DeathlogMiniLog)
---@field IsMinimized fun(self: DeathlogMiniLog): boolean

--- MenuElement container interface used by MenuElements/*.lua
--- All containers expose updateMenuElement with a common signature;
--- callers may pass fewer args (trailing nils are fine in Lua).
---@alias UpdateMenuElementFn fun(scroll_frame: any, id: any, stats_tbl: PrecomputedGeneralStatsTable?, callback: function?, filter_or_model: any?, metric_or_view: any?, class_id: any?)
---@class MenuElementContainer : Frame
---@field updateMenuElement UpdateMenuElementFn
---@field [any] any

--- ChatThrottleLib (embedded library) — fields accessed before full init
---@class ChatThrottleLib
---@field version number|nil
---@field securelyHooked boolean|nil
---@field MSG_OVERHEAD number|nil
---@field bQueueing boolean|nil
---@field BNSendGameData (fun(self: ChatThrottleLib, prio: string, prefix: string, text: string, chattype: string, gameAccountID: number, queueName: string?, callbackFn: function?, callbackArg: any?))|nil
---@field UpdateAvail (fun(self: ChatThrottleLib): number)|nil
---@field [any] any