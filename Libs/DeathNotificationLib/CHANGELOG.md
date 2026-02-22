# Changelog

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
