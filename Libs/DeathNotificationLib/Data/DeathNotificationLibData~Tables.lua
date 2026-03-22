local _dnld = DeathNotificationLibData.Internal
if not _dnld then return end

--#region API

---@diagnostic disable: undefined-field
DeathNotificationLibData.HEATMAP_INTENSITY = _dnld.HEATMAP_INTENSITY ---@type table<number, table<number, table<number, number>>>

DeathNotificationLibData.HEATMAP_CREATURE_SUBSET = _dnld.HEATMAP_CREATURE_SUBSET ---@type table<number, table<number, table<number, table<number, boolean>>>>
---@diagnostic enable: undefined-field

--#endregion