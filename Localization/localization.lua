local localeMap = {
    ["koKR"] = deathlog_strings_ko,
    ["enGB"] = deathlog_strings_en,
    ["enUS"] = deathlog_strings_en,
    ["deDE"] = deathlog_strings_de,
    ["frFR"] = deathlog_strings_fr,
    ["itIT"] = deathlog_strings_it,
    ["zhCN"] = deathlog_strings_cn,
    ["zhTW"] = deathlog_strings_cn,
    ["ruRU"] = deathlog_strings_ru,
    ["esES"] = deathlog_strings_es,
    ["esMX"] = deathlog_strings_es,
    ["ptBR"] = deathlog_strings_pt,
    ["default"] = deathlog_strings_en -- Default string to English
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
