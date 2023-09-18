function getNormalFontPathByLocale(localeCode)
    if localeCode == "koKR" then
        return "Fonts\\2002.ttf"
    elseif localeCode == "frFR" then
        return "Fonts\\2002.ttf"
    elseif localeCode == "deDE" then
        return "Fonts\\2002.ttf"
    elseif localeCode == "enGB" or localeCode == "enUS" then
        return "Fonts\\blei00d.TTF"
    elseif localeCode == "itIT" then
        return "Fonts\\2002.ttf"
    elseif localeCode == "zhCN" then
        return "Fonts\\ARKai_T.ttf"
    elseif localeCode == "zhTW" then
        return "Fonts\\bHEI01B.ttf"
    elseif localeCode == "ruRU" then
        return "Fonts\\2002.ttf"
    elseif localeCode == "esES" then
        return "Fonts\\2002.ttf"
    elseif localeCode == "esMX" then
        return "Fonts\\2002.ttf"
    elseif localeCode == "ptBR" then
        return "Fonts\\2002.ttf"
    else
        return "Fonts\\blei00d.TTF" -- set default to English font
    end
end

function getTitleFontPathByLocale(localeCode)
    if localeCode == "koKR" then
        return "Fonts\\2002.ttf"
    elseif localeCode == "frFR" then
        return "Fonts\\2002.ttf"
    elseif localeCode == "deDE" then
        return "Fonts\\2002.ttf"
    elseif localeCode == "enGB" or localeCode == "enUS" then
        return "Fonts\\FRIZQT__.TTF"
    elseif localeCode == "itIT" then
        return "Fonts\\2002.ttf"
    elseif localeCode == "zhCN" then
        return "Fonts\\ARKai_T.ttf"
    elseif localeCode == "zhTW" then
        return "Fonts\\bHEI01B.ttf"
    elseif localeCode == "ruRU" then
        return "Fonts\\2002.ttf"
    elseif localeCode == "esES" then
        return "Fonts\\2002.ttf"
    elseif localeCode == "esMX" then
        return "Fonts\\2002.ttf"
    elseif localeCode == "ptBR" then
        return "Fonts\\2002.ttf"
    else
        return "Fonts\\FRIZQT__.TTF" -- set default to English font
    end
end

function getIdToNPCTableByLocale(localeCode)
    if localeCode == "koKR" then
        return id_to_npc_ko
    else
        return id_to_npc -- set default to English table
    end
end

function getNPCToIdTableByLocale(localeCode)
    if localeCode == "koKR" then
        return npc_to_id_ko
    else
        return npc_to_id -- set default to English table
    end
end

_localeCode = GetLocale()
normalFont = getNormalFontPathByLocale(_localeCode)
titleFont = getTitleFontPathByLocale(_localeCode)

id_to_npc = getIdToNPCTableByLocale(_localeCode)
npc_to_id = getNPCToIdTableByLocale(_localeCode)