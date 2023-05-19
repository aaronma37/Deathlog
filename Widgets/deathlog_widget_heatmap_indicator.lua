local AceGUI = LibStub("AceGUI-3.0")
local heatmap_indicator_frame = CreateFrame("frame")
heatmap_indicator_frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
heatmap_indicator_frame:SetWidth(25)
heatmap_indicator_frame:SetHeight(25)
heatmap_indicator_frame:SetMovable(true)
heatmap_indicator_frame:EnableMouse(true)
heatmap_indicator_frame:Show()

heatmap_indicator_frame.tex = heatmap_indicator_frame:CreateTexture(nil, "OVERLAY")
heatmap_indicator_frame.tex:SetAllPoints()
heatmap_indicator_frame.tex:SetDrawLayer("OVERLAY", 7)
heatmap_indicator_frame.tex:SetVertexColor(1, 1, 1, 1)
heatmap_indicator_frame.tex:SetHeight(25)
heatmap_indicator_frame.tex:SetWidth(25)
heatmap_indicator_frame.tex:SetTexture("Interface\\TARGETINGFRAME\\UI-TargetingFrame-Skull")
heatmap_indicator_frame.tex:Show()
local last_calculated_map_id = nil

function updateHeatmap(map_id)
	if last_calculated_map_id == map_id then
		return
	end
	last_calculated_map_id = map_id
	_skull_locs = precomputed_skull_locs
	if heatmap_indicator_frame.heatmap == nil then
		heatmap_indicator_frame.heatmap = {}
		for i = 1, 100 do
			heatmap_indicator_frame.heatmap[i] = {}
			for j = 1, 100 do
				heatmap_indicator_frame.heatmap[i][j] = 0
			end
		end
	end

	for i = 1, 100 do
		for j = 1, 100 do
			heatmap_indicator_frame.heatmap[i][j] = 0.0
		end
	end
	local iv = {
		[1] = {
			[1] = 0.025,
			[2] = 0.045,
			[3] = 0.025,
		},
		[2] = {
			[1] = 0.045,
			[2] = 0.1,
			[3] = 0.045,
		},
		[3] = {
			[1] = 0.025,
			[2] = 0.045,
			[3] = 0.025,
		},
	}
	local max_intensity = 0
	if _skull_locs[map_id] then
		for idx, v in ipairs(_skull_locs[map_id]) do
			local x = ceil(v[1] / 10)
			local y = ceil(v[2] / 10)
			for xi = 1, 3 do
				for yj = 1, 3 do
					local x_in_map = x - 2 + xi
					local y_in_map = y - 2 + yj
					if
						heatmap_indicator_frame.heatmap[x_in_map]
						and heatmap_indicator_frame.heatmap[x_in_map][y_in_map]
					then
						heatmap_indicator_frame.heatmap[x_in_map][y_in_map] = heatmap_indicator_frame.heatmap[x_in_map][y_in_map]
							+ iv[xi][yj]
						if heatmap_indicator_frame.heatmap[x_in_map][y_in_map] > max_intensity then
							max_intensity = heatmap_indicator_frame.heatmap[x_in_map][y_in_map]
						end
					end
				end
			end
		end
	end

	for i = 1, 100 do
		for j = 1, 100 do
			heatmap_indicator_frame.heatmap[i][j] = heatmap_indicator_frame.heatmap[i][j] / max_intensity
		end
	end
end

local function startUpdate()
	if heatmap_indicator_frame.ticker == nil then
		heatmap_indicator_frame.ticker = C_Timer.NewTicker(1, function()
			local map = C_Map.GetBestMapForUnit("player")
			local instance_id = nil
			local position = nil
			if map then
				position = C_Map.GetPlayerMapPosition(map, "player")

				local x = ceil(position.x * 100)
				local y = ceil(position.y * 100)
				updateHeatmap(map)
				if heatmap_indicator_frame.heatmap[x][y] < 0.2 then
					heatmap_indicator_frame.tex:SetVertexColor(1, 1, 1, 1)
				elseif heatmap_indicator_frame.heatmap[x][y] < 0.7 then
					heatmap_indicator_frame.tex:SetVertexColor(1, 1, 0, 1)
				else
					heatmap_indicator_frame.tex:SetVertexColor(1, 0, 0, 1)
				end
			else
				heatmap_indicator_frame.tex:SetVertexColor(1, 1, 1, 0.25)
			end
		end)
	end
end

heatmap_indicator_frame:SetScript("OnShow", function()
	startUpdate()
end)

function initDeathlogHeatmapIndicatorWidget(_settings)
	if deathlog_settings["heatmap_indicator_show"] == nil or deathlog_settings["heatmap_indicator_show"] == false then
		heatmap_indicator_frame:Hide()
		heatmap_indicator_frame.tex:Hide()
	else
		startUpdate()
		heatmap_indicator_frame:Show()
		heatmap_indicator_frame.tex:Show()
	end

	heatmap_indicator_frame:ClearAllPoints()
	if heatmap_indicator_frame and deathlog_settings["heatmap_indicator_pos"] then
		heatmap_indicator_frame:SetPoint(
			"CENTER",
			UIParent,
			"CENTER",
			deathlog_settings["heatmap_indicator_pos"]["x"],
			deathlog_settings["heatmap_indicator_pos"]["y"]
		)
	else
		heatmap_indicator_frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end

	if heatmap_indicator_frame and deathlog_settings["heatmap_indicator_size"] then
		heatmap_indicator_frame:SetSize(
			deathlog_settings["heatmap_indicator_size"]["x"],
			deathlog_settings["heatmap_indicator_size"]["y"]
		)
	else
		heatmap_indicator_frame:SetSize(255, 125)
	end
end

heatmap_indicator_frame:RegisterForDrag("LeftButton")
heatmap_indicator_frame:SetScript("OnDragStart", function(self, button)
	self:StartMoving()
	heatmap_indicator_frame.tex:SetPoint("TOPLEFT", heatmap_indicator_frame, "TOPLEFT", 10, -10)
end)
heatmap_indicator_frame:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	local x, y = self:GetCenter()
	local px = (GetScreenWidth() * UIParent:GetEffectiveScale()) / 2
	local py = (GetScreenHeight() * UIParent:GetEffectiveScale()) / 2
	if deathlog_settings["heatmap_indicator_pos"] == nil then
		deathlog_settings["heatmap_indicator_pos"] = {}
	end
	deathlog_settings["heatmap_indicator_pos"]["x"] = x - px
	deathlog_settings["heatmap_indicator_pos"]["y"] = y - py
	heatmap_indicator_frame.tex:SetPoint("TOPLEFT", heatmap_indicator_frame, "TOPLEFT", 10, -10)
end)

local function getLoc()
	local map = C_Map.GetBestMapForUnit("player")
	local instance_id = nil
	local position = nil
	if map then
		position = C_Map.GetPlayerMapPosition(map, "player")
		return map, position
	end
	return nil, nil
end

-- hooksecurefunc(death_log_frame, "OnShow", function()
-- 	print(getLoc)
-- end)
