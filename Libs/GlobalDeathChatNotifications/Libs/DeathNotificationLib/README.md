# Death Notification Lib

Including this library in your addon will automatically

* Have the player join the unified death notification channel
* Register the player for death notifications.  The addon which includes this library needs to implement a function to handle death notifications

Only for classic era and Hardcore servers.


### Requirements

* ChatThrottleLib

### How to add to your addon

1) Copy this repo into your addons directory.  Something like `<youraddonroot>/Libs/DeathNotificationLib/`

2) In `<youraddon>.toc`, include `DeathNotificationLib.lua` somewhere early in file loading.  Note, this requires ChatThrottleLib and the included `npc_to_id_classic./lua/id_to_npc_classic.lua`.  E.g.

`Libs/ChatThrottleLib.lua`
`Libs/DeathNotificationLib/npc_to_id_classic.lua`
`Libs/DeathNotificationLib/id_to_npc_classic.lua`
`Libs/DeathNotificationLib/DeathNotificationLib.lua`
`<youraddon>.lua`

3) Register a function to hook onto death notification events (use `DeathNotificationLib_HookOnNewEntry`).  Here are the fields


``` .lua
-- DeathNotificationLib_HookOnNewEntry(function(_player_data, _checksum, _peer_report, _in_guild) ... end)
-- @param _player_data metadata for player entry.
-- 	@field name Player's name
-- 	@field guild Player's guild
-- 	@field source_id ID of creature that killed the player
-- 	@field class_id Class ID of the player
-- 	@field level Player's level
-- 	@field instance_id Instance that player died in. Nil if player did not die in an instance
-- 	@field map_id Zone ID that player died in. Nil if player died in an instance instead
-- 	@field map_pos Map coordinates within zone specified by map_id, nil if player died in an instance instead
-- 	@field date Date that the player died.  Unix Epoch.
-- 	@field last_words Player's last words.
-- @param _checksum A checksum for the player data
-- @param _peer_report Number of guildmates that verified the death
-- @param _in_guild Whether the player is in your guild
```

You can register `DeathNotificationLib_HookOnNewEntrySecure` instead, which will only notify when 2 guildmates to whomever died, acknowledge the death.

### Some notes

* Use the `_peer_report` field for added verification.  This number is the number of guildmates that verify the death within 5 seconds of the initial alert.  I recommend not using this to block alerts unless fake notifications become an issue.
* There is a 5 second delay between death and notification.  This is a grace period to transmit last words.
