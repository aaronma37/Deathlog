# Changelog

## V6 — 2026-02-25

### Bug Fix: Played-Time Suppression Across Multiple Chat Tabs
- `TIME_PLAYED_MSG` is part of the `SYSTEM` ChatTypeGroup and is dispatched to **every** chat frame that has System messages enabled via `ChatFrame_SystemEventHandler`, each calling `ChatFrame_DisplayTimePlayed`
- The old suppression decremented the counter inside `displayTimePlayedOverride` on each call, so only the first chat frame was suppressed — secondary tabs leaked the played-time message
- The override now checks the counter without decrementing; the counter is decremented in `onTimePlayedMsg` via `C_Timer.After(0)`, which fires on the next frame after all per-chatframe dispatches are complete

## V5 — 2026-02-24

### Critical Performance Fix: Blizzard HistoryKeeper Memory Leak Mitigation
- Installed `ChatFrame_AddMessageEventFilter` for `CHAT_MSG_CHANNEL`, `CHAT_MSG_CHANNEL_NOTICE`, `CHAT_MSG_CHANNEL_NOTICE_USER`, `CHAT_MSG_CHANNEL_JOIN`, and `CHAT_MSG_CHANNEL_LEAVE` to suppress **both** the sync channel (`hcdeathlogsyncchannel*`) and the death-alerts channel (`hcdeathalertschannel*`) before they reach Blizzard's chat pipeline
- **Root cause**: Blizzard's `HistoryKeeper.lua` (`ChatHistory_GetAccessID`) creates a permanent table entry for every unique `(chatType, chatTarget, chanSender)` tuple — these are **never garbage-collected**.  On a high-traffic channel with hundreds of unique senders, this causes monotonically growing memory + CPU cost even when the addon is completely disabled
- The filter runs in the `chatFilters` table (checked at line ~1126 of `ChatFrame_MessageEventHandler`), which fires **before** `ChatHistory_GetAccessID` (line ~1476), `GetColoredName`, and `AddMessage` — short-circuiting the entire Blizzard chat pipeline for our channels
- The filter is installed at file-load time in `~Init.lua` (earliest load), so it is active even if the player was still in a channel from a previous session
- This eliminates the lag that players reported even with `sync_enabled = false` or the addon disabled — the issue was Blizzard-side overhead processing `CHAT_MSG_CHANNEL` events, not addon code

### Sync: Channel-Busy Cooldown (prevent simultaneous E$ streams)
- Added `CHANNEL_BUSY_COOLDOWN` (30s): when E$ entry traffic is seen on the sync channel, new sync triggers are suppressed for 30 seconds
- Previously, multiple behind-peers could simultaneously enter `COLLECTING_WATERMARKS` → `JITTER_WAIT` and send M$ requests to different responders before any E$ appeared on the channel, causing overlapping entry streams that flooded the channel
- The cooldown is checked in `handleSyncWatermark` (before entering collect phase) and `_syncPickPeerAndJitter` (before entering jitter phase), ensuring only the first requester triggers a response while everyone else passively consumes the entries

### Performance
- `predictSource()` is no longer called during sync entry ingestion (`createEntry` with `SOURCE.SYNC`); the expensive heatmap ring-search and `C_Map` API lookups are deferred until an entry is first displayed, where all three display paths (search log, minilog, stats) already compute it lazily — eliminates the primary cause of frame-rate drops reported by users syncing large databases

### Sync Channel Lifecycle
- `joinSyncChannel()` no longer gates on `anySyncEnabled()` — the sync channel is always joined so that watermark broadcasts carrying addon-version upgrade hints are received even when syncing is disabled
- `_startSyncWatermarkTicker()` interval calculation no longer filters on `isSyncEnabled`; `broadcastWatermark()` already skips addons with sync off, so the ticker is harmless when no addons sync and starts broadcasting immediately if sync is enabled mid-session

### New: `auto_hide_chat_channels` Setting
- New opt-out setting (default `true`): when **any** attached addon sets it to `false`, `hideChannelFromChatFrames()` becomes a no-op, leaving addon channels visible in chat frames for debugging
- Added to the `DNL_Settings` type annotation

### New: Addon Version Notifications
- Watermark broadcasts now include the registering addon's semantic version string as a 5th field (backward-compatible — old clients send an empty field)
- After 3 unique peers advertise a newer version, a chat notification is printed and all `HookOnNewerVersion` callbacks are fired
- New public API:
  - `GetNewerAddonVersion(addonName)` — returns the newest detected version string, or nil
  - `HookOnNewerVersion(fn)` — registers a callback `fn(addonName, newerVersion, currentVersion)` that fires when a newer version is confirmed
  - `FireNewerVersionHook(addonName, newerVersion, currentVersion)` — test helper to manually trigger the hook at runtime
- `AttachAddon` now accepts an `addon_version` field (e.g. `"0.4.1"`) to register the local addon's version

### New: Social-Channel Version Broadcast (`~VersionCheck.lua`)
- New module broadcasts the addon version on social channels (PARTY, RAID, GUILD, INSTANCE_CHAT) when the player joins a group, raid, instance, or logs in while in a guild
- Uses a dedicated addon-message prefix `HCDeathVer` to avoid interfering with the death-alert or sync protocols
- Wire commands: `V$TAG~version~` (version announcement) and `N$TAG~version~` (newer-version whisper notification)
- On receiving a version announcement:
  - If the remote version is **newer**: immediately shows an update-available chat message and fires `HookOnNewerVersion` callbacks (no multi-peer threshold — a single sender on a trusted channel is sufficient)
  - If the remote version is **older**: whispers back the local version via `N$` so the sender also learns about the update
- Per-session dedup prevents the same version notification from appearing more than once
- 120-second cooldown per channel type prevents spam on rapid group changes
- Triggered by `PLAYER_ENTERING_WORLD` (login/reload) and `GROUP_ROSTER_UPDATE` (group composition changes)
- Registered the `HCDeathVer` prefix via `C_ChatInfo.RegisterAddonMessagePrefix` in `~Events.lua`
- `CHAT_MSG_ADDON` dispatch in `~Events.lua` routes `HCDeathVer` messages to `_dnl.handleVersionCheckAddonMessage`

### Protocol Hardening
- Messages from protocol versions **newer than the local version** are now silently rejected in all three receive paths: death broadcasts (`~Cache`), query ACKs (`~Events`), and sync entries (`~Sync`)
- Removed the old protocol-version upgrade chat hint (replaced by the more accurate per-addon version notification above)

### New: Watchlist Channel Query (`WATCHLIST_QUERY` / command `"6"`)
- New protocol command broadcasts comma-separated watchlist names over the death alerts channel (`6$TAG~name1,name2,...`)
- Every connected addon user receives the query, checks their local DB, and whispers back up to 10 matching death records via the existing `COMM_QUERY_ACK` (`R$`) pathway
- Wire format respects the 255-byte limit — names are batched until the budget is exhausted; remaining names are omitted from that message
- Inbound handler validates the tag, ignores self-queries, and skips unknown tags
- New public API: `QueryChannel(names, tag)` — queues a batch watchlist query for the realm-wide death channel
- New `watchlist_query_queue` — drained on user input alongside existing queues (priority: duel requests > watchlist queries > checksums > death pings); stale-entry trimming (58 s max age) covers the queue

### Bug Fixes
- Fixed a race condition where deaths arriving via Blizzard's `HARDCORE_DEATHS` channel were discarded when a peer broadcast with `source_id = -1` had already been committed — the Blizzard message now upgrades the committed entry's `source_id` to the correct NPC ID and re-fires hooks so addon databases receive the corrected data; previously these deaths were displayed with a heatmap-predicted source (trailing `*`) even though the real killer was known
- **Fixed duplicate entries from party/sync sources** — multiple root causes in the dedup pipeline:
  - `fletcher16` produces different checksums for the same death when guild or source_id differs between reporters; all dedup layers now use **name-based** matching (via `lru_by_name`) in addition to checksum matching
  - **Outbound broadcast dedup** (`~Broadcast`): `broadcastDeath()` now checks `lru_by_name` before computing a checksum — if the same player name is already in the LRU within the dedup window, the broadcast is suppressed and the data is merged into the existing entry via quality-aware merge; prevents multiple party members from each sending a separate broadcast for the same death
  - **Inbound broadcast dedup** (`~Cache`): `handleDeathBroadcast()` equal-or-lower quality path now always merges into the existing entry and returns, regardless of whether the existing entry has committed — previously, an uncommitted equal-quality entry with a different checksum fell through and created a parallel LRU entry that committed as a duplicate
  - **Sync ingestion dedup** (`~Sync`): `_processSyncEntry()` now pre-checks the target addon's DB (via `db_map`) for an existing entry with the same player name within the dedup window before calling `createEntry`; matching entries are merged instead of duplicated
  - `NAME_DEDUP_WINDOW` increased from 60 s to a dynamic value across all layers
- **Fixed late quality-upgrade race** — when network/CPU timing spread caused a higher-quality broadcast (e.g. SELF from the dying player) to arrive after a lower-quality PEER entry had already committed, the better data was silently discarded; the quality-upgrade path in `handleDeathBroadcast` now detects the already-committed state, merges the superior data in-place, and re-fires `createEntry` with the existing checksum so addon hooks overwrite the DB entry with the best available information

### Internal
- New semver utilities: `parseVersion(ver)` and `compareVersions(a, b)` on the internal `_dnl` namespace
- `DNL_RegisteredAddon` gains `addon_version` and `newest_detected_version` fields

---

## V4 — 2026-02-22

### Bug Fixes
- Added `UnitIsFeignDeath` guard to party/raid death detection — Hunters using Feign Death are no longer falsely reported as dead

### Improvements
- Incoming sync entries are now queued in a backlog and drained in batches (8 per tick at 50 ms intervals) to avoid frame-rate spikes when many `E$` messages arrive at once
- Watermark broadcast timing is now jittered: initial delay randomised to 10–40 s, ongoing ticks vary ±20 % — prevents multiple clients from phase-locking their broadcasts

---

## V3 — 2026-02-22

Initial standalone release.  
Previously bundled inside [Deathlog](https://www.curseforge.com/wow/addons/deathlog); now available as a shared library for any addon to embed.
