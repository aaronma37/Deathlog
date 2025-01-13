local localeMap = {
    ["koKR"] = {
        d_id_to_npc = id_to_npc_ko,
        d_npc_to_id = npc_to_id_ko
    },
    ["frFR"] = {
        d_id_to_npc = id_to_npc_fr,
        d_npc_to_id = npc_to_id_fr
    },
    ["deDE"] = {
        d_id_to_npc = id_to_npc_de,
        d_npc_to_id = npc_to_id_de
    },
    ["enGB"] = {
        d_id_to_npc = id_to_npc_en,
        d_npc_to_id = npc_to_id_en
    },
    ["enUS"] = {
        d_id_to_npc = id_to_npc_en,
        d_npc_to_id = npc_to_id_en
    },
    ["itIT"] = {
        d_id_to_npc = id_to_npc_it,
        d_npc_to_id = npc_to_id_it
    },
    ["zhCN"] = {
        d_id_to_npc = id_to_npc_cn,
        d_npc_to_id = npc_to_id_cn
    },
    ["zhTW"] = {
        d_id_to_npc = id_to_npc_cn,
        d_npc_to_id = npc_to_id_cn
    },
    ["ruRU"] = {
        d_id_to_npc = id_to_npc_ru,
        d_npc_to_id = npc_to_id_ru
    },
    ["esES"] = {
        d_id_to_npc = id_to_npc_es,
        d_npc_to_id = npc_to_id_es
    },
    ["esMX"] = {
        d_id_to_npc = id_to_npc_es,
        d_npc_to_id = npc_to_id_es
    },
    ["ptBR"] = {
        d_id_to_npc = id_to_npc_pt,
        d_npc_to_id = npc_to_id_pt
    },
    -- Default table to English
    ["default"] = {
        d_id_to_npc = id_to_npc_en,
        d_npc_to_id = npc_to_id_en
    }
}

local function getDataByLocale(localeCode, dataType)
    -- If the given localeCode doesn't exist in the map, use "default"
    local localeData = localeMap[localeCode] or localeMap["default"]
    return localeData[dataType]
end

_localeCode = GetLocale()
d_id_to_npc = getDataByLocale(_localeCode, "d_id_to_npc")
d_npc_to_id = getDataByLocale(_localeCode, "d_npc_to_id")
