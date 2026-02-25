--[[
Copyright 2026 Yazpad & Deathwing
The DeathNotificationLib is distributed under the terms of the GNU General Public License (or the Lesser GPL).
This file is part of Hardcore.

The DeathNotificationLib is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

The DeathNotificationLib is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with the DeathNotificationLib. If not, see <http://www.gnu.org/licenses/>.
--]]

-- !! WARNING !!
-- This file is NO LONGER loaded by the TOC and exists only for reference.
-- All code has been dissolved into the ~tilde module files:
--
--   ~Init.lua           Bootstrap, debug flag, injected-dep slots
--   ~Localization.lua    Locale strings and translations
--   ~Protocol.lua        PlayerData type, protocol constants, environment_damage, encode/decode
--   ~PvP.lua             PvP source tracking, duel-to-death detection
--   ~BlizzardParser.lua  Universal death-broadcast parser (HARDCORE_CAUSEOFDEATH_* globals)
--   ~UnitState.lua       Per-unit state tracking, realm classification, constants
--   ~Query.lua           Query functions, single-flight /who system
--   ~PredictSource.lua   Heatmap-based death source prediction
--   ~Cache.lua           Hook system, createEntry, LRU dedup cache, public hook API
--   ~Broadcast.lua       Outbound broadcast, resolveDeathSource
--   ~Sync.lua            Continuous background database sync between peers
--   ~VersionCheck.lua    Addon version broadcasting on party/raid/guild/instance channels
--   ~Events.lua          Event handlers, AttachAddon API
--   ~Backwards.lua       Backwards compatibility shims for old API functions
--   ~Transport.lua       Send queues
--   ~DeathAlert.lua      Built-in death alert popup (BossBanner UI, sounds, AceConfig panel)
--   ~HardcoreTBC.lua     Bridge for HardcoreTBC addon death events
--   ~UltraHardcore.lua   Bridge for UltraHardcore addon death events
--   ~Testing.lua         CreateFakeEntry (public), debug test utilities
--   ~Finalizer.lua       Cleanup
--
-- If you previously loaded this file via your own TOC or XML, replace the
-- entry with the individual ~module files listed in the main Deathlog.toc.
error("DeathNotificationLib.lua is deprecated — load the ~tilde module files instead. See this file for details.")
