if Deathlog_allowExport then
    -- Run this in WoW with: /run LoadAddOn("Deathlog"); Deathlog_ExtractMapBounds()
    -- Or paste in chat as a macro. Output will be in chat - copy to a file.
    -- The extracted bounds will be specific to the current game version (Classic vs TBC)

    -- Detect game version using WoW API
    -- GetExpansionLevel() doesn't exist in Classic Era, returns 1 for TBC
    local function GetExpansionInfo()
        if GetExpansionLevel then
            local level = GetExpansionLevel()
            if level >= 1 then
                return "tbc", level
            end
        end
        return "vanilla", 0
    end

    function Deathlog_CollectMapBounds()
        local expansionName, expansionLevel = GetExpansionInfo()
        
        local mapIds = {
            -- Continents
            947,  -- Azeroth
            1414, -- Kalimdor
            1415, -- Eastern Kingdoms
            1945, -- Outland
            -- Eastern Kingdoms zones
            1416, 1417, 1418, 1419, 1420, 1421, 1422, 1423, 1424, 1425,
            1426, 1427, 1428, 1429, 1430, 1431, 1432, 1433, 1434, 1435,
            1436, 1437, 1453, 1455, 1458, 1941, 1942, 1954, 1957,
            -- Kalimdor zones
            1411, 1412, 1413, 1438, 1439, 1440, 1441, 1442, 1443, 1444,
            1445, 1446, 1447, 1448, 1449, 1450, 1451, 1452, 1454, 1456,
            1457, 1943, 1947, 1950,
            -- Outland zones
            1944, 1946, 1948, 1949, 1951, 1952, 1953, 1955,
        }

        local output = string.format("# Map bounds extracted from %s client (expansion_level=%d)\n", expansionName, expansionLevel)
        output = output .. "map_bounds = {\n"
        
        for _, mapId in ipairs(mapIds) do
            local mapInfo = C_Map.GetMapInfo(mapId)
            if mapInfo and mapInfo.parentMapID and mapInfo.parentMapID > 0 then
                local parentId = mapInfo.parentMapID
                local topLeft = CreateVector2D(0, 0)
                local bottomRight = CreateVector2D(1, 1)
                
                local cid1, wp1 = C_Map.GetWorldPosFromMapPos(mapId, topLeft)
                local cid2, wp2 = C_Map.GetWorldPosFromMapPos(mapId, bottomRight)
                
                if wp1 and wp2 then
                    -- Note: GetMapPosFromWorldPos returns (mapID, position)
                    local _, pp1 = C_Map.GetMapPosFromWorldPos(cid1, wp1, parentId)
                    local _, pp2 = C_Map.GetMapPosFromWorldPos(cid2, wp2, parentId)
                    
                    if pp1 and pp2 then
                        local x1, y1 = pp1:GetXY()
                        local x2, y2 = pp2:GetXY()
                        output = output .. string.format("    %d: {'parent': %d, 'x1': %.6f, 'y1': %.6f, 'x2': %.6f, 'y2': %.6f},\n",
                            mapId, parentId, x1, y1, x2, y2)
                    end
                end
            end
        end
        
        output = output .. "}"

        return output
    end

    function Deathlog_ExtractMapBounds()
        local data = Deathlog_CollectMapBounds()
        -- Save to SavedVariables for easy extraction
        dev_map_bounds = data
        print("-- Map bounds data for coordinate transformation")
        print(data)
        print("-- Data also saved to SavedVariables. /reload and check SavedVariables/Deathlog.lua for dev_map_bounds")
    end

    -- Alternative: simpler version that just prints to chat
    function Deathlog_ExtractMapBoundsSimple()
        -- Write to SavedVariables
        dev_map_bounds = Deathlog_CollectMapBounds()
        print("Map bounds extracted! /reload and check SavedVariables/Deathlog.lua for dev_map_bounds")
    end

    -- Extract world map dimensions
    -- Format: { width, height, left, top } in world coordinates
    -- This is used to detect coordinate system differences between Classic and TBC
    function Deathlog_ExtractWorldMapData()
        local expansionName, expansionLevel = GetExpansionInfo()
        
        -- Continent instance IDs: 0 = Eastern Kingdoms, 1 = Kalimdor, 530 = Outland
        local continentMaps = {
            {mapId = 1415, instanceId = 0, name = "Eastern Kingdoms"},
            {mapId = 1414, instanceId = 1, name = "Kalimdor"},
            {mapId = 1945, instanceId = 530, name = "Outland"},
        }
        
        -- All zone map IDs to extract world bounds for
        local zoneMaps = {
            -- Eastern Kingdoms zones
            1416, 1417, 1418, 1419, 1420, 1421, 1422, 1423, 1424, 1425,
            1426, 1427, 1428, 1429, 1430, 1431, 1432, 1433, 1434, 1435,
            1436, 1437, 1453, 1455, 1458, 1941, 1942, 1954, 1957,
            -- Kalimdor zones
            1411, 1412, 1413, 1438, 1439, 1440, 1441, 1442, 1443, 1444,
            1445, 1446, 1447, 1448, 1449, 1450, 1451, 1452, 1454, 1456,
            1457, 1943, 1947, 1950,
            -- Outland zones
            1944, 1946, 1948, 1949, 1951, 1952, 1953, 1955,
        }
        
        local output = string.format("-- World map data extracted from %s client (expansion_level=%d)\n", expansionName, expansionLevel)
        output = output .. "-- Format: { width, height, left, top } in world coordinates\n"
        output = output .. "world_map_data = {\n"
        output = output .. string.format('    ["%s"] = {\n', expansionName)
        
        -- Extract continent bounds
        output = output .. "        -- Continents (by instance ID)\n"
        for _, continent in ipairs(continentMaps) do
            local mapId = continent.mapId
            local topLeft = CreateVector2D(0, 0)
            local bottomRight = CreateVector2D(1, 1)
            
            local cid1, wp1 = C_Map.GetWorldPosFromMapPos(mapId, topLeft)
            local cid2, wp2 = C_Map.GetWorldPosFromMapPos(mapId, bottomRight)
            
            if wp1 and wp2 then
                local x1, y1 = wp1:GetXY()
                local x2, y2 = wp2:GetXY()
                
                -- Calculate dimensions: width = right - left, height = bottom - top
                local width = math.abs(x2 - x1)
                local height = math.abs(y2 - y1)
                local left = math.min(x1, x2)
                local top = math.min(y1, y2)
                
                output = output .. string.format('        %d: {"width": %.2f, "height": %.2f, "left": %.2f, "top": %.2f},  -- %s\n',
                    continent.instanceId, width, height, left, top, continent.name)
            end
        end
        
        -- Extract zone bounds (in world coordinates)
        output = output .. "        -- Zones (by map ID) - world coordinates for zone corners\n"
        for _, mapId in ipairs(zoneMaps) do
            local mapInfo = C_Map.GetMapInfo(mapId)
            if mapInfo then
                local topLeft = CreateVector2D(0, 0)
                local bottomRight = CreateVector2D(1, 1)
                
                local cid1, wp1 = C_Map.GetWorldPosFromMapPos(mapId, topLeft)
                local cid2, wp2 = C_Map.GetWorldPosFromMapPos(mapId, bottomRight)
                
                if wp1 and wp2 then
                    local x1, y1 = wp1:GetXY()
                    local x2, y2 = wp2:GetXY()
                    
                    -- Store raw corner positions (left=x1, top=y1, right=x2, bottom=y2)
                    local width = x2 - x1
                    local height = y2 - y1
                    
                    output = output .. string.format('        %d: {"left": %.2f, "top": %.2f, "width": %.2f, "height": %.2f},  -- %s\n',
                        mapId, x1, y1, width, height, mapInfo.name or "Unknown")
                end
            end
        end
        
        output = output .. "    },\n"
        output = output .. "}"
        
        -- Save to SavedVariables
        dev_world_map_data = output
        print(output)
        print("-- Data also saved to SavedVariables. /reload and check SavedVariables/Deathlog.lua for dev_world_map_data")
        return output
    end
end