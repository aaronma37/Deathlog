local localeMap = {
    ["koKR"] = DEATHLOG_STRINGS_KO,
    ["enGB"] = DEATHLOG_STRINGS_EN,
    ["enUS"] = DEATHLOG_STRINGS_EN,
    ["deDE"] = DEATHLOG_STRINGS_DE,
    ["frFR"] = DEATHLOG_STRINGS_FR,
    ["itIT"] = DEATHLOG_STRINGS_IT,
    ["zhCN"] = DEATHLOG_STRINGS_CN,
    ["zhTW"] = DEATHLOG_STRINGS_CN,
    ["ruRU"] = DEATHLOG_STRINGS_RU,
    ["esES"] = DEATHLOG_STRINGS_ES,
    ["esMX"] = DEATHLOG_STRINGS_ES,
    ["ptBR"] = DEATHLOG_STRINGS_PT,
    ["default"] = DEATHLOG_STRINGS_EN -- Default string to English
}

local function loadLocaleData(localeCode)
    local localeData = localeMap[localeCode] or localeMap["default"]

    -- Set the fallback mechanism in case the table is incomplete
    local defaultData = localeMap["default"]
    for key, value in pairs(defaultData) do
        if not localeData[key] then
            localeData[key] = value
        end
    end

    return localeData
end

local localeCode = GetLocale()

-- set global variables for Localization table
Deathlog_L = loadLocaleData(localeCode)
-- Use it like
-- SetFont(Deathlog_L.mainFont)
