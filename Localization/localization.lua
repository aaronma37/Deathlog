local localeMap = {
    ["koKR"] = strings_ko,
    ["enGB"] = strings_en,
    ["enUS"] = strings_en,
    ["deDE"] = strings_de,
    ["frFR"] = strings_fr,
    ["itIT"] = strings_it,
    ["zhCN"] = strings_cn,
    ["zhTW"] = strings_cn,
    ["ruRU"] = strings_ru,
    ["esES"] = strings_es,
    ["esMX"] = strings_es,
    ["ptBR"] = strings_pt,
    ["default"] = strings_en -- Default string to English
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
L = loadLocaleData(localeCode)
-- Use it like
-- SetFont(L.mainFont)
