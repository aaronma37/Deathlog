# Changelog

All notable changes to Deathlog will be documented in this file.

## [0.5.1] - 2026-03-08

### New Features
- **Minilog artifact themes** — all ArtifactUI class backgrounds are now selectable as minilog themes (Death Knight Frost, Demon Hunter, Druid, Hunter, Mage Arcane, Monk, Paladin, Priest, Priest Shadow, Rogue, Shadow, Shaman, Warlock, Warrior)

### Bug Fixes
- Fixed Death Alert settings panel not appearing in Interface Options
- Fixed minilog artifact themes rendering the full sprite sheet instead of the background panel region (now uses correct atlas UV crop via `SetTexCoord`)
- Fixed Deathlog menu background texture using imprecise UV coordinates — now uses the correct atlas crop for the Rogue BG region

## [0.5.0] - 2026-03-06

### New Features
- **Resizable & scalable menu** — drag the bottom-right corner to resize and scale the Deathlog window; position and scale are saved between sessions
- **Precomputed purge data** — purged players are now filtered using precomputed checksums, split by expansion (Classic Era / TBC)
- **Guild filter** in search log — filter the death log by guild name
- **DeathlogData** is now a separate addon, installed automatically as a dependency
- **Instance minimum level enforcement** — deaths from players too low-level for a dungeon or raid are now filtered out (e.g. a level 1 death in AQ20 is no longer counted)
- **Deathlog Discord** — join the community on Discord for support, feedback, and discussion: `discord.com/invite/NphuAv75vy` (invite link also available in the changelog status bar)

### Improvements
- `wow_project_id` is now recorded in saved variables, improving expansion-aware data collection
- Faster addon channel join on login (0.5s delay, down from 5.0s)
- Dropdown menus refactored away from legacy `UIDropDownMenu` API
- Global functions renamed from `deathlog_*` to `Deathlog_*` to follow proper naming conventions
- Global constants renamed from `precomputed_*` to `PRECOMPUTED_*`
- Proper `ADDON_LOADED` event handling for SavedVariables initialization
- Updated NPC data, heatmaps, and precomputed statistics with latest death data
- Type annotations added throughout for IDE support
- Instance min-level filtering works across both Classic Era and TBC
- Watchlist interaction zones now match visible UI columns more precisely (Name/Note/Icon)
- Watchlist remove action now triggers only when clicking directly on the visible `X` icon
- Watchlist icon dropdown now displays the currently selected icon in the control itself
- Watchlist refresh cooldown text now updates live each second instead of staying static
- Watchlist `Last Checked` now updates reliably when refresh queries run

### Bug Fixes
- Fixed HardcoreDeaths channel pushing General, Trade, and LocalDefense to wrong positions in the channel list
- Fixed death alert crash when settings hadn't been customized (messages now fall back to defaults)
- Fixed death alert frame initialization nil errors
- Fixed empty/broken graphs when only 1 death exists for a class — log-normal std dev is now clamped to a minimum of 0.01 to prevent division by zero
- Fixed "Mouseover for metric details" tooltip being positioned off-screen in the deadliest creature panel
- Removed 9 redundant `> 0` guards across UI files

### DeathNotificationLib V9
- See DeathNotificationLib CHANGELOG for full details

## [0.4.5] - 2026-02-28

### Performance
- Fixed major FPS drop caused by heatmaps — textures are now created on-demand and hidden when empty, instead of rendering all 10,000 cells every frame (applies to both the world map overlay and the statistics map)
- Added "Heatmap Resolution" setting (Low / Medium / High / Ultra) to reduce grid density for better performance on slower machines

### Bug Fixes
- Fixed API compatibility for older clients (pre-1.14.4) that lack `C_AddOns` namespace

## [0.4.4] - 2026-02-27

### New Features
- **In-game changelog popup** — see what's new after each update! Use `/dl changelog` to open it anytime
- **Death filter** — filter the minilog and death alerts to show only guild deaths, or disable notifications entirely
- **GreenWall support** — if you use GreenWall, you can filter by your entire guild confederation

### Bug Fixes
- Fixed various crashes related to minilog settings and tooltips
- Fixed "Playtime" column causing errors
- Improved stability when widgets load before settings are ready

## [0.4.3] - 2026-02-26

### Bug Fixes
- Fixed multiple "newer version available" messages appearing per session — now only one notification per addon per `/reload`, regardless of how many different newer versions are detected from peers

### DeathNotificationLib V7
- Unified version notification logic across VersionCheck and Sync modules into a single shared function (`notifyNewerVersion`)
- Sync's watermark-based version hint now delegates to the same once-per-session notification path used by social-channel broadcasts

## [0.4.2] - 2026-02-25

### Bug Fixes
- Fixed /played time message showing up in secondary chat tabs — players with multiple chat windows no longer see unwanted "Time Played" spam

### DeathNotificationLib V6
- Fixed played-time suppression for players with multiple chat tabs

## [0.4.1] - 2026-02-24

### Bug Fixes
- Fixed watchlist queries not being sent correctly
- Fixed a crash when death alerts played before the alert style was fully loaded
- Fixed minilog font errors when a custom font wasn't available yet — falls back to the default font until it loads
- Fixed minilog entries not being clickable or highlightable — several invisible UI elements were blocking mouse input across the entry area; all resolved
- Fixed duplicate death log entries caused by party members and sync each producing different checksums for the same death — name-based dedup now covers all paths, dedup window widened to 120s, and a one-time cleanup merges existing duplicates on login
- Fixed late-arriving high-quality broadcasts (e.g. SELF from the dying player) being silently discarded when a lower-quality entry had already committed due to network timing spread

### Improvements
- New **Auto-hide addon chat channels** setting — when disabled, Deathlog's chat channels (death alerts, sync) remain visible in your chat frames for debugging; enabled by default
- Watchlist now reactively detects deaths from **all** sources (sync manager, peer broadcasts, guild queries) via `HookOnNewEntry`, instead of relying solely on active polling when the tab is open
- The watchlist now broadcasts all watched player names over the death alerts channel so every connected addon user can check their local DB and whisper back matches — dramatically improves detection speed across the realm; per-name guild/say queries still run as a fallback
- On login, the watchlist scans the local death database for any watched players who died while you were offline and prints a chat notification
- The `addonless_logging` setting is now respected in all display paths — addonless entries (no class/race) synced from other players are hidden in the search log, minilog, and statistics when the setting is disabled; entries remain stored so toggling the setting back on reveals them instantly
- Info button now shows an **"Update Available"** tooltip when a newer Deathlog version is detected from peers, including the current and new version numbers
- On Hardcore characters (where the info button is normally hidden), it re-appears specifically to surface the update notification

### DeathNotificationLib V5
- Fixed a Blizzard-side memory leak caused by high-traffic addon channels — eliminates the gradual lag increase some players experienced even with sync disabled
- Sync no longer causes frame-rate drops when processing large databases
- Sync sessions no longer overlap when multiple peers trigger them simultaneously
- Multiple fixes for duplicate death entries from party members and sync
- Fixed a race condition that could show a predicted killer instead of the real one when the actual killer was known
- Fixed late-arriving higher-quality death reports being discarded when a lower-quality report had already been saved
- Addon version checks now also work over party, raid, guild, and instance chat — you'll see update notifications faster
- New watchlist channel query lets all connected users help find watched player deaths across the realm
- Messages from newer protocol versions are now safely rejected to prevent processing incompatible data

---

## [0.4.0] - 2026-02-22

### Bug Fixes
- Fixed inverted right-click menu conditions — Block User, Whisper Player, and Check Spoof now actually trigger when the option is available (affected both minilog and main search log)

### Improvements
- Zone and Instance filter dropdowns now skip the expansion submenu layer when only one expansion is present, reducing unnecessary clicks on single-expansion realms
- CTA widget uses `SOURCE` enum constants instead of raw string keys
- Removed unused `cta_threshold` setting reference from the CTA widget
- Minor cleanup: suppressed unused loop variable warning in entry counter init
- Updated precomputed stats for Vanilla and TBC with latest death data

### DeathNotificationLib V4
- Added Feign Death guard — Hunters using Feign Death are no longer falsely reported as dead in party/raid death detection
- Sync entry processing is now batched (8 entries per tick) to prevent frame spikes from large `E$` bursts
- Watermark broadcast timing jittered (10–40 s initial delay, ±20 % ongoing variance) to avoid client phase-locking

---

## [0.3.0] - 2026-02-21

### New: Smarter Death Detection & Enrichment
- **Automatic `/who` enrichment** — Blizzard's death messages only include the player's name; Deathlog now runs a background `/who` lookup to fill in level, class, race, and guild automatically
- **Party/raid death reporting** — deaths of your group members are captured and broadcast with full details, even if they don't have Deathlog installed
- **Universal death broadcast parser** — a single `BlizzardParser` built from Blizzard's own `HARDCORE_CAUSEOFDEATH_*` globals replaces the old hand-written per-locale parsers, supporting all 11 client languages out of the box (including positional format arguments and known Blizzard typos)

### New: Background Database Sync
- Automatically exchange death entries with other Deathlog users over a dedicated addon channel — no setup required
- Configurable sync window, interval, cooldown, and max entries per session
- New settings panel: Interface → AddOns → Deathlog → Database Sync

### New: Playtime Tracking
- Your total `/played` time is now recorded in every death report
- Displayed in the minilog, search log, tooltips, and death alerts
- New `<playtime>` substitution tag for death alert messages (e.g., "died after 2d 14h 32m")
- Tooltip toggle: show or hide playtime (enabled by default)
- **Privacy opt-out**: disable "Include playtime in death report" in settings
- Compatible with HardcoreTBC addon's playtime data

### New: Death Alert Overhaul
- **Group syntax** for context-aware messages:
  - `(...)` relaxed group — shown if at least one tag inside has a value
  - `[...]` strict group — shown only if **all** tags inside have values
  - Example: `<name>( the <race> <class>)[ of <guild>] has been slain by <source>[ at lvl <level>][ in <zone>].`
- New `<guild>` substitution tag — works in all message types
- **Real-time input validation** — detects unknown tags, unbalanced groups, nested groups, and empty groups with clear error messages
- All 9 locales updated with new group-syntax default messages

### New: Data Contribution Prompt
- One-time popup when you've collected a large database, asking you to share your data
- Persistent banner in the main menu shows your entry count with contact info

### Improvements
- Hardcore status info button in the main menu — shows your tracking state, supported realms, and detected addons
- Server filter dropdown in the search log now actually filters results
- Right-click menu options properly disabled when not applicable (e.g., "Show death location" grayed out without location data)
- Minimap button saves its position correctly across reloads
- Creature ranking tooltip no longer incorrectly fires on player units
- Corpse tooltip now uses Blizzard's `CORPSE_TOOLTIP` global instead of per-locale word tables
- PvP killer name captured and stored in `extra_data` for Blizzard-sourced deaths
- Duplicate entries merged using quality-aware logic — higher-quality reports (self > peer > Blizzard) take priority, unique fields from both are preserved
- Removed 8 development-only SavedVariables, reducing disk and memory usage
- Settings panel reordered: Report Widget now appears last
- Modular DeathNotificationLib architecture (split into focused modules)
- Updated precomputed stats with latest death data
- Expansion filter for instance grid (TBC only)

### Bug Fixes
- Fixed missing heatmap overlays for TBC zones
- Removed global override that broke Blizzard's `CHAT_CHANNEL_PASSWORD` popup for other addons
- Raid warning removal for Hardcore deaths now only matches the expected format, avoiding interference with other addons
- Shaman class color on Classic realms correctly set to 0, 112, 221 without overriding `RAID_CLASS_COLORS` globally

---

## [0.2.0] - 2026-02-06

### New: TBC Anniversary / Soul of Iron Support
- Full support for **Burning Crusade Anniversary** realms
- Detects Soul of Iron buff and Tarnished Soul debuff automatically
- All TBC dungeons, raids, and Outland zones included
- Your hardcore status is saved between sessions

### New: Death Report Widget
- When a nearby player loses their Soul of Iron, a popup appears
- Click to help report their death - works even if they don't have Deathlog!
- Draggable widget with configurable timeout
- Help build the community death database by reporting deaths you witness

### New: Continental Map Views
- View combined heatmap and death stats for **Azeroth**, **Kalimdor**, **Eastern Kingdoms**, or **Outland**
- Great for seeing the bigger picture of where deaths occur

### Improvements
- Zone and Instance dropdowns now organized by expansion (Classic / TBC submenus)
- Scrollable instance selection grid (supports all 50+ instances)
- Improved pagination: shows "Page X / Y" format
- "Whisper player" option added to death log right-click menu
- Environmental deaths (Falling, Drowning, Lava, etc.) now show proper icons in creature stats
- Warning message when playing on an unsupported realm

### Bug Fixes
- Min/Max level filters in search now work correctly
- Watch list "Remove" button actually removes entries now
- Fixed heatmap positioning for TBC zones
- Fixed creature highlighting on continental maps
- Search results reset to page 1 when applying filters
- Various UI fixes for empty rows and tooltips
