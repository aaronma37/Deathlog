# Death Notification Lib (DNL)

**A shared WoW addon library for real-time Hardcore / Soul of Iron death notifications.**

DNL handles everything needed to detect, broadcast, receive, and verify player deaths on Classic Era Hardcore and TBC Anniversary Soul of Iron servers. Embed it in your addon and get rich, structured death data delivered straight to your callback — no channel management, no protocol work, no data wrangling.

## Features

- **Real-time death detection** — Listens to Blizzard's Hardcore death channel, guild chat, and peer addon messages simultaneously
- **Structured PlayerData** — Every death arrives as a clean table: name, guild, killer, class, race, level, zone/instance, map coordinates, /played, last words, and more
- **Peer verification** — Guild members automatically corroborate deaths; the `peer_report` count tells you how trustworthy a report is
- **Background database sync** — Peers continuously exchange death records in the background so your database fills in even for deaths you missed
- **LRU dedup cache** — Duplicate reports from multiple sources are merged automatically; your hook fires once per unique death
- **Built-in death alert UI** — Optional BossBanner-style popup with sound, fully configurable through AceConfig (or hide it entirely)
- **Protocol V3** — Compact encoding/decoding with fletcher16 checksums and backwards compatibility down to V0
- **PvP tracking** — Detects duel-to-death kills and captures the PvP source player name
- **Heatmap-based source prediction** — When the killer NPC is unknown, DNL predicts the most likely source from bundled heatmap data
- **Last words** — Captures the player's final chat message before death (5-second grace period)
- **Localized** — All NPC, zone, and instance names resolved to the client's locale

## Supported Realms

| Realm Type | Game Version |
|---|---|
| Hardcore | Classic Era (1.15.x) |
| Soul of Iron | TBC Anniversary (2.5.x) |

## Quick Start

### 1. Copy DNL into your addon

```
YourAddon/
  Libs/
    ChatThrottleLib.lua
    DeathNotificationLib/
      DeathNotificationLib.xml
      ...
  YourAddon.toc
  YourAddon.lua
```

### 2. Update your `.toc`

```
Libs/ChatThrottleLib.lua
Libs/DeathNotificationLib/DeathNotificationLib.xml
YourAddon.lua
```

> **Note:** The old single-file `DeathNotificationLib.lua` is deprecated. Use the XML include instead.

### 3. Register your addon

```lua
DeathNotificationLib.AttachAddon({
    name = "YourAddon",
    tag  = "YAD",                          -- exactly 3 characters
    isUnitTracked = function(unit)
        -- return true for units your addon cares about
        return UnitIsPlayer(unit)
    end,
    db     = YourAddonDB,                  -- optional: SavedVariable table for sync
    db_map = YourAddonDB_Map,              -- optional: map table for sync
})
```

### 4. Hook into death events

```lua
-- Per-addon hook (only deaths destined for your addon):
DeathNotificationLib.HookOnNewAddonEntry("YourAddon", function(player_data, checksum, peer_report, in_guild, source)
    print(player_data.name .. " (Level " .. player_data.level .. ") was killed by " .. (player_data.source_id or "unknown"))
end)

-- Or global hook (fires for ALL deaths):
DeathNotificationLib.HookOnNewEntry(function(player_data, checksum, peer_report, in_guild, source)
    -- ...
end)
```

Use the `Secure` variants (`HookOnNewAddonEntrySecure` / `HookOnNewEntrySecure`) to only fire when at least 2 guild members have verified the death.

## PlayerData Fields

| Field | Type | Description |
|---|---|---|
| `name` | string | Player's character name |
| `guild` | string | Player's guild name |
| `source_id` | number | NPC ID of killer. Negative for environmental: -2 Drowning, -3 Falling, etc. |
| `race_id` | number | Race ID |
| `class_id` | number | Class ID |
| `level` | number | Player's level at death |
| `instance_id` | number? | Instance ID (nil if outdoor death) |
| `map_id` | number? | Zone ID (nil if instance death) |
| `map_pos` | string? | Map coordinates within zone (nil if instance death) |
| `date` | number | Unix epoch timestamp |
| `played` | number? | Total /played seconds (nil if unknown) |
| `last_words` | string? | Player's last chat message |
| `extra_data` | table? | Additional data, e.g. `{pvp_source_name = "..."}` |

## Bundled Data Tables

DNL ships with locale-aware lookup tables exposed on the `DeathNotificationLib` global:

| Table | Description |
|---|---|
| `ID_TO_NPC` / `NPC_TO_ID` | NPC ID ↔ localized name |
| `ZONE_TO_ID` / `ID_TO_ZONE` | Zone name ↔ ID |
| `INSTANCE_TO_ID` / `ID_TO_INSTANCE` | Instance name ↔ ID |
| `AREA_TO_ID` | Sub-area name → ID |
| `CLASS_ID_MAP` / `CLASS_NAME_TO_ID` / `CLASS_FILE_TO_ID` | Class lookups |
| `CLASS_COLORS` / `CLASS_ID_TO_COLOR` | Class color tables |
| `RACE_ID_MAP` / `RACE_NAME_TO_ID` / `RACE_FILE_TO_ID` | Race lookups |
| `INSTANCE_CATEGORIES` / `ZONE_CATEGORIES` | Categorized zone/instance groupings |
| `ZONE_TO_INSTANCE` | Zone → instance mapping |
| `ID_TO_DISPLAY_ID` | NPC ID → display model ID |
| `ID_TO_QUOTE` | NPC ID → flavor quote |
| `HEATMAP_INTENSITY` / `HEATMAP_CREATURE_SUBSET` | Death heatmap data |

## Public API Reference

| Function | Description |
|---|---|
| `AttachAddon(options)` | Register your addon with DNL |
| `HookOnNewEntry(fn)` | Global hook — fires for all deaths |
| `HookOnNewEntrySecure(fn)` | Global hook — fires only for verified deaths (2+ peer reports) |
| `HookOnNewAddonEntry(name, fn)` | Per-addon hook — fires only for deaths tagged for your addon |
| `HookOnNewAddonEntrySecure(name, fn)` | Per-addon verified hook |
| `GetDeathRecord(name)` | Look up a cached death record by player name |
| `CreateFakeEntry()` | Generate a fake death entry (useful for UI testing) |
| `PlayDeathAlert(player_data)` | Programmatically trigger the death alert popup |
| `TestDeathAlert()` | Fire a test alert with a fake entry |
| `UpdateDeathAlert()` | Re-apply death alert settings after config changes |
| `FormatPlaytime(seconds)` | Format a `/played` duration as a human-readable string |
| `SyncStatus()` | Get current background sync status |
| `QueryGuild(name, tag)` | Query guild channel for a player's death record |
| `QueryTarget(name, target, tag)` | Whisper-query a specific player |
| `WhoPlayer(name)` | Single-flight `/who` lookup |
| `SOURCE` | Entry-origin enum: `"self_death"`, `"peer_broadcast"`, `"blizzard"`, `"sync"`, etc. |

## Used By

- [Deathlog](https://www.curseforge.com/wow/addons/deathlog) — the original death logging addon for Classic Hardcore

## Links

- [Source Code (GitHub)](https://github.com/aaronma37/Deathlog)
- [Integration Guide](https://github.com/aaronma37/Deathlog/blob/master/Libs/DeathNotificationLib/README.md)
