local VERSION = 1772751600

if DeathlogData and (DeathlogData.VERSION or 0) >= VERSION then return end

---@class DeathlogData
---@field Internal _dd
DeathlogData = { VERSION = VERSION, Internal = {} }

local _dd = DeathlogData.Internal ---@class _dd