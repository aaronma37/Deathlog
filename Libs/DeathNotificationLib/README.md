# Death Notification Lib

Including this library in your addon will automatically

* Have the player join the unified death notification channel
* Register the player for death notifications.  The addon which includes this library needs to implement a function to handle death notifications

Supports **Classic Era** Hardcore realms and **TBC Anniversary** Soul of Iron servers.


### Requirements

* ChatThrottleLib

### How to add to your addon

1) Copy this repo into your addons directory.  Something like `<youraddonroot>/Libs/DeathNotificationLib/`

2) In `<youraddon>.toc`, include `DeathNotificationLib.xml`.  This single XML file loads all data files and modules in the correct order.  Make sure ChatThrottleLib is loaded before it.  E.g.

```
Libs/ChatThrottleLib.lua
Libs/DeathNotificationLib/DeathNotificationLib.xml
<youraddon>.lua
```

> **Note:** The old single-file `DeathNotificationLib.lua` is deprecated and will `error()` if loaded.  Use the XML include instead.

3) Register a function to hook onto death notification events.  Use `DeathNotificationLib.HookOnNewAddonEntry` for per-addon hooks (fires only for deaths destined for your addon) or `DeathNotificationLib.HookOnNewEntry` for global hooks (fires for all non-addonless deaths).


``` .lua
-- Per-addon hook (requires AttachAddon first):
-- DeathNotificationLib.HookOnNewAddonEntry("MyAddon", function(_player_data, _checksum, _peer_report, _in_guild, _source) ... end)
--
-- Global hook:
-- DeathNotificationLib.HookOnNewEntry(function(_player_data, _checksum, _peer_report, _in_guild, _source) ... end)
-- @param _player_data metadata for player entry.
-- 	@field name Player's name
-- 	@field guild Player's guild
-- 	@field source_id ID of creature that killed the player (negative for environmental: -2 Drowning, -3 Falling, etc.)
-- 	@field race_id Race ID of the player
-- 	@field class_id Class ID of the player
-- 	@field level Player's level
-- 	@field instance_id Instance that player died in. Nil if player did not die in an instance
-- 	@field map_id Zone ID that player died in. Nil if player died in an instance instead
-- 	@field map_pos Map coordinates within zone specified by map_id, nil if player died in an instance instead
-- 	@field date Date that the player died.  Unix Epoch.
-- 	@field played Total /played time in seconds. Nil if unknown.
-- 	@field last_words Player's last words.
-- 	@field extra_data Table of additional data (e.g. {pvp_source_name = "..."}). Nil if none.
-- @param _checksum A checksum for the player data
-- @param _peer_report Number of guildmates that verified the death
-- @param _in_guild Whether the player is in your guild
-- @param _source Entry origin constant from DeathNotificationLib.SOURCE (e.g. "self_death", "peer_broadcast", "blizzard", "sync")
```

You can use the `Secure` variants (`HookOnNewAddonEntrySecure` / `HookOnNewEntrySecure`) instead, which will only notify when 2 guildmates to whomever died, acknowledge the death.

### Module structure

The library is split into focused modules, all loaded via `DeathNotificationLib.xml`:

| Module | Purpose |
|---|---|
| `~Init.lua` | Bootstrap `_dnl` namespace, debug flag, injected-dep slots |
| `~Localization.lua` | Locale strings and translations |
| `~Protocol.lua` | PlayerData type, protocol constants, environment damage, encode/decode, fletcher16 |
| `~PvP.lua` | PvP source tracking, duel-to-death detection |
| `~BlizzardParser.lua` | Universal death-broadcast parser built from Blizzard's `HARDCORE_CAUSEOFDEATH_*` globals |
| `~UnitState.lua` | Per-unit state tracking, realm classification, constants |
| `~Query.lua` | Query functions, single-flight /who system |
| `~PredictSource.lua` | Heatmap-based death source prediction |
| `~Cache.lua` | Hook system, `createEntry`, LRU dedup cache, public hook API |
| `~Broadcast.lua` | Outbound broadcast, `resolveDeathSource` |
| `~Sync.lua` | Continuous background database sync between peers |
| `~Events.lua` | Event handlers, `AttachAddon` API |
| `~Backwards.lua` | Backwards compatibility shims |
| `~Transport.lua` | Send queues |
| `~DeathAlert.lua` | Built-in death alert popup (BossBanner UI, sounds, AceConfig options panel) |
| `~HardcoreTBC.lua` | Bridge for HardcoreTBC addon death events |
| `~UltraHardcore.lua` | Bridge for UltraHardcore addon death events |
| `~Testing.lua` | `CreateFakeEntry` (public), debug test utilities |
| `~Finalizer.lua` | Cleanup |

Data tables (Areas, Instances, NPCs, Zones) are loaded automatically by the XML before the modules.

### Some notes

* Use the `_peer_report` field for added verification.  This number is the number of guildmates that verify the death within 5 seconds of the initial alert.  I recommend not using this to block alerts unless fake notifications become an issue.
* There is a 5 second delay between death and notification.  This is a grace period to transmit last words.
