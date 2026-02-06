# Deathlog

A WoW Hardcore addon that provides a UI for exploring the deathlog and death statistics. Works on **Classic Era** Hardcore realms and **TBC Anniversary** Soul of Iron servers!

**Over 870,000 death records** collected and counting!

**[SEE WIKI FOR OFFLINE STATS](https://github.com/aaronma37/Deathlog/wiki)**  The wiki will be updated as the database grows

*Feel free to use the database for any purpose!* [Database](https://github.com/aaronma37/Deathlog/tree/master/db/db.json)

## Compatibility

- **Classic Era**: Full support on official Hardcore realms
- **TBC Anniversary**: Full support via Soul of Iron buff detection (all TBC zones, dungeons, and raids included)

This addon is completely safe to run alongside the `Hardcore` addon.  Alternatively, this addon can be run without the Hardcore addon running, however, it does not provide verification for the solo self-found challenge.

See [CHANGELOG.md](CHANGELOG.md) for version history.

## Features

### Faction-wide Death notification compatibility with the Hardcore addon
* Emits notifications when your character dies
* Receives and records incoming death notifications
* Can be set to guild only

### Death Report Widget (TBC Anniversary / Soul of Iron)
* Automatically detects when a nearby player loses their Soul of Iron
* A popup appears asking you to help report their death - even if they don't have Deathlog!
* Simply click the button to gather and log their character info
* Help the community by reporting deaths you witness in the world

### Highly customizable Death Alerts
![DeathAlert](git_images/deathalert.png)

### Browse the Deathlog
* Search by name, level, class, race, etc..

![Deathlog](git_images/deathlog_deathlog.png)

### Deathlog Statistics per Zone

* Fully functional map with heatmap overlay and death location overlays
* List of deadliest creatures for each Zone
* Death statistics by class list and probability density function graph
* Continental aggregation: view stats for all of Kalimdor, Eastern Kingdoms, Outland, or combined Azeroth

![Westfall death statistics](git_images/statistics_westfall.png)

### Deathlog Statistics per Instance

* View death stats per instance (all Classic & TBC dungeons/raids)
* Scrollable grid for easy navigation

![Instance Stats](git_images/instance_stats.png)

### Deathlog Statistics by NPC/Creature

* See what creatures do the most killing in Azeroth. Normalized and total kill ranking
* Creature locations and models

![Instance Stats](git_images/creature_stats.png)

### Customizable Deathlog (minilog widget)

* Configure columns of the deathlog
* Configure font of the deathlog

![custom deathlog](git_images/deathlog_custom.png)

### Heatmap Indicator

* Skull icon which turns red when the player is in a dangerous area

![heatmap icon](git_images/heatmap_icon.png)

### Heatmap WorldMap Overlay

* Open the world map to see an overlay of dangerous areas

### Preprocessed collection

* Large database of deathlog entries used for statistics
* Separate databases for Classic Era and TBC Anniversary
* The file `collected_entries.lua` can be referenced for all entries.  This file isn't actually loaded and is included for sharing.

### Tooltip Information

* View deadly ranking in npc hover over tooltip

![tooltip](git_images/tooltip_mod.png)
