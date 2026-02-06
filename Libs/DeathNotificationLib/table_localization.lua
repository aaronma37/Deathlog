local localeMap = {
    ["koKR"] = {
        id_to_npc = id_to_npc_ko,
        npc_to_id = npc_to_id_ko,
        area_to_id = area_to_id_ko,
        instance_to_id = instance_to_id_ko,
        zone_to_id = zone_to_id_ko,
        id_to_quote = id_to_quote_ko
    },
    ["frFR"] = {
        id_to_npc = id_to_npc_fr,
        npc_to_id = npc_to_id_fr,
        area_to_id = area_to_id_fr,
        instance_to_id = instance_to_id_fr,
        zone_to_id = zone_to_id_fr,
        id_to_quote = id_to_quote_fr
    },
    ["deDE"] = {
        id_to_npc = id_to_npc_de,
        npc_to_id = npc_to_id_de,
        area_to_id = area_to_id_de,
        instance_to_id = instance_to_id_de,
        zone_to_id = zone_to_id_de,
        id_to_quote = id_to_quote_de
    },
    ["enGB"] = {
        id_to_npc = id_to_npc_en,
        npc_to_id = npc_to_id_en,
        area_to_id = area_to_id_en,
        instance_to_id = instance_to_id_en,
        zone_to_id = zone_to_id_en,
        id_to_quote = id_to_quote_en
    },
    ["enUS"] = {
        id_to_npc = id_to_npc_en,
        npc_to_id = npc_to_id_en,
        area_to_id = area_to_id_en,
        instance_to_id = instance_to_id_en,
        zone_to_id = zone_to_id_en,
        id_to_quote = id_to_quote_en
    },
    ["itIT"] = {
        id_to_npc = id_to_npc_it,
        npc_to_id = npc_to_id_it,
        area_to_id = area_to_id_it,
        instance_to_id = instance_to_id_it,
        zone_to_id = zone_to_id_it,
        id_to_quote = id_to_quote_it
    },
    ["zhCN"] = {
        id_to_npc = id_to_npc_cn,
        npc_to_id = npc_to_id_cn,
        area_to_id = area_to_id_cn,
        instance_to_id = instance_to_id_cn,
        zone_to_id = zone_to_id_cn,
        id_to_quote = id_to_quote_cn
    },
    ["zhTW"] = {
        id_to_npc = id_to_npc_cn,
        npc_to_id = npc_to_id_cn,
        area_to_id = area_to_id_cn,
        instance_to_id = instance_to_id_cn,
        zone_to_id = zone_to_id_cn,
        id_to_quote = id_to_quote_cn
    },
    ["ruRU"] = {
        id_to_npc = id_to_npc_ru,
        npc_to_id = npc_to_id_ru,
        area_to_id = area_to_id_ru,
        instance_to_id = instance_to_id_ru,
        zone_to_id = zone_to_id_ru,
        id_to_quote = id_to_quote_ru
    },
    ["esES"] = {
        id_to_npc = id_to_npc_es,
        npc_to_id = npc_to_id_es,
        area_to_id = area_to_id_es,
        instance_to_id = instance_to_id_es,
        zone_to_id = zone_to_id_es,
        id_to_quote = id_to_quote_es
    },
    ["esMX"] = {
        id_to_npc = id_to_npc_es,
        npc_to_id = npc_to_id_es,
        area_to_id = area_to_id_es,
        instance_to_id = instance_to_id_es,
        zone_to_id = zone_to_id_es,
        id_to_quote = id_to_quote_es
    },
    ["ptBR"] = {
        id_to_npc = id_to_npc_pt,
        npc_to_id = npc_to_id_pt,
        area_to_id = area_to_id_pt,
        instance_to_id = instance_to_id_pt,
        zone_to_id = zone_to_id_pt,
        id_to_quote = id_to_quote_pt
    },
    -- Default table to English
    ["default"] = {
        id_to_npc = id_to_npc_en,
        npc_to_id = npc_to_id_en,
        area_to_id = area_to_id_en,
        instance_to_id = instance_to_id_en,
        zone_to_id = zone_to_id_en,
        id_to_quote = id_to_quote_en
    }
}

local function getDataByLocale(localeCode, dataType)
    -- If the given localeCode doesn't exist in the map, use "default"
    local localeData = localeMap[localeCode] or localeMap["default"]
    return localeData[dataType]
end

local function getMergedQuotes(localeCode)
    -- Get locale-specific quotes and English fallback
    local localeQuotes = getDataByLocale(localeCode, "id_to_quote") or {}
    local englishQuotes = id_to_quote_en or {}
    
    -- If locale is already English, just return it
    if localeCode == "enUS" or localeCode == "enGB" then
        return localeQuotes
    end
    
    -- Create merged table with locale quotes taking priority
    local merged = {}
    
    -- First, copy all English quotes as fallback
    for npcId, quote in pairs(englishQuotes) do
        merged[npcId] = quote
    end
    
    -- Then override with locale-specific quotes where available
    for npcId, quote in pairs(localeQuotes) do
        merged[npcId] = quote
    end
    
    return merged
end

_localeCode = GetLocale()
id_to_npc = getDataByLocale(_localeCode, "id_to_npc")
npc_to_id = getDataByLocale(_localeCode, "npc_to_id")
area_to_id = getDataByLocale(_localeCode, "area_to_id")
instance_to_id = getDataByLocale(_localeCode, "instance_to_id")
id_to_instance = {}
for _, instances in pairs(instance_to_id) do
    for instance_name, instance_id in pairs(instances) do
        id_to_instance[instance_id] = instance_name
    end
end
zone_to_id = getDataByLocale(_localeCode, "zone_to_id")
id_to_zone = {}
for _, zones in pairs(zone_to_id) do
    for zone_name, zone_id in pairs(zones) do
        id_to_zone[zone_id] = zone_name
    end
end
id_to_quote = getMergedQuotes(_localeCode)
