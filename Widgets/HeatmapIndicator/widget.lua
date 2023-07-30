local AceGUI = LibStub("AceGUI-3.0")
local widget_name = "Heatmap Indicator"
local heatmap_indicator_frame = CreateFrame("frame")
heatmap_indicator_frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
heatmap_indicator_frame:SetWidth(40)
heatmap_indicator_frame:SetHeight(40)
heatmap_indicator_frame:SetMovable(true)
heatmap_indicator_frame:EnableMouse(true)
heatmap_indicator_frame:Show()

heatmap_indicator_frame.tex = heatmap_indicator_frame:CreateTexture(nil, "OVERLAY")
heatmap_indicator_frame.tex:SetAllPoints()
heatmap_indicator_frame.tex:SetDrawLayer("OVERLAY", 7)
heatmap_indicator_frame.tex:SetVertexColor(1, 1, 1, 1)
heatmap_indicator_frame.tex:SetHeight(40)
heatmap_indicator_frame.tex:SetWidth(40)
heatmap_indicator_frame.tex:SetTexture("Interface\\TARGETINGFRAME\\UI-TargetingFrame-Skull")
heatmap_indicator_frame.tex:Show()

heatmap_indicator_frame.numeric_text = heatmap_indicator_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
heatmap_indicator_frame.numeric_text:SetText("")
heatmap_indicator_frame.numeric_text:SetFont("Fonts\\blei00d.TTF", 10, "")
heatmap_indicator_frame.numeric_text:SetJustifyH("CENTER")
heatmap_indicator_frame.numeric_text:SetParent(heatmap_indicator_frame)
heatmap_indicator_frame.numeric_text:SetPoint("BOTTOM", heatmap_indicator_frame, "BOTTOM", 0, 0)
heatmap_indicator_frame.numeric_text:Show()

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
				if heatmap_indicator_frame.heatmap[x][y] < 0.1 then
					heatmap_indicator_frame.tex:SetVertexColor(1, 1, 1, 1)
				elseif heatmap_indicator_frame.heatmap[x][y] < 0.25 then
					heatmap_indicator_frame.tex:SetVertexColor(1, 1, 0, 1)
				else
					heatmap_indicator_frame.tex:SetVertexColor(1, 0, 0, 1)
				end
				heatmap_indicator_frame.numeric_text:SetText(
					string.format("%.1f", heatmap_indicator_frame.heatmap[x][y] * 10)
				)
				if deathlog_settings[widget_name]["show_value"] then
					heatmap_indicator_frame.numeric_text:Show()
				else
					heatmap_indicator_frame.numeric_text:Hide()
				end
			else
				heatmap_indicator_frame.tex:SetVertexColor(1, 1, 1, 0.25)
				heatmap_indicator_frame.numeric_text:Hide()
			end
		end)
	end
end

heatmap_indicator_frame:SetScript("OnShow", function()
	startUpdate()
end)

heatmap_indicator_frame:RegisterForDrag("LeftButton")
heatmap_indicator_frame:SetScript("OnDragStart", function(self, button)
	self:StartMoving()
	-- heatmap_indicator_frame.tex:SetPoint("CENTER", heatmap_indicator_frame, "CENTER", 10, -10)
end)
heatmap_indicator_frame:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	local x, y = self:GetCenter()
	local px = (GetScreenWidth() * UIParent:GetEffectiveScale()) / 2
	local py = (GetScreenHeight() * UIParent:GetEffectiveScale()) / 2
	deathlog_settings[widget_name]["pos_x"] = x - px
	deathlog_settings[widget_name]["pos_y"] = y - py
	-- heatmap_indicator_frame.tex:SetPoint("CENTER", heatmap_indicator_frame, "CENTER", 10, -10)
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

local defaults = {
	["enable"] = false,
	["pos_x"] = 0,
	["pos_y"] = 0,
	["size_x"] = 40,
	["size_y"] = 40,
	["show_value"] = false,
}

local function applyDefaults(_defaults, force)
	if deathlog_settings[widget_name] == nil then
		deathlog_settings[widget_name] = {}
	end
	for k, v in pairs(_defaults) do
		if deathlog_settings[widget_name][k] == nil or force then
			deathlog_settings[widget_name][k] = v
		end
	end
end

local options = nil
local optionsframe = nil
function Deathlog_HIWidget_applySettings()
	applyDefaults(defaults)

	if deathlog_settings[widget_name]["enable"] == nil or deathlog_settings[widget_name]["enable"] == false then
		heatmap_indicator_frame:Hide()
		heatmap_indicator_frame.tex:Hide()
	else
		startUpdate()
		heatmap_indicator_frame:Show()
		heatmap_indicator_frame.tex:Show()
	end

	heatmap_indicator_frame:ClearAllPoints()
	heatmap_indicator_frame:SetPoint(
		"CENTER",
		UIParent,
		"CENTER",
		deathlog_settings[widget_name]["pos_x"],
		deathlog_settings[widget_name]["pos_y"]
	)
	heatmap_indicator_frame.tex:SetAllPoints()

	heatmap_indicator_frame:SetSize(deathlog_settings[widget_name]["size_x"], deathlog_settings[widget_name]["size_y"])

	if deathlog_settings[widget_name]["show_value"] then
		heatmap_indicator_frame.numeric_text:Show()
	else
		heatmap_indicator_frame.numeric_text:Hide()
	end

	if optionsframe == nil then
		LibStub("AceConfig-3.0"):RegisterOptionsTable(widget_name, options)
		optionsframe = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(widget_name, widget_name, "Deathlog")
	end
end

local function forceReset()
	applyDefaults(defaults, true)
	Deathlog_HIWidget_applySettings()
end

options = {
	name = widget_name,
	handler = Minilog,
	type = "group",
	args = {
		enable = {
			type = "toggle",
			name = "Show Heatmap Indicator",
			desc = "Show Heatmap Indicator",
			get = function()
				return deathlog_settings[widget_name]["enable"]
			end,
			set = function()
				deathlog_settings[widget_name]["enable"] = not deathlog_settings[widget_name]["enable"]
				Deathlog_HIWidget_applySettings()
			end,
		},
		reset_size_and_pos = {
			type = "execute",
			name = "Reset to default",
			desc = "Reset to default",
			func = function()
				forceReset()
			end,
		},
		scale = {
			type = "range",
			name = "Scale",
			desc = "Scale",
			min = 1,
			max = 100,
			step = 1,
			get = function()
				return deathlog_settings[widget_name]["size_x"]
			end,
			set = function(self, value)
				deathlog_settings[widget_name]["size_x"] = value
				deathlog_settings[widget_name]["size_y"] = value
				Deathlog_HIWidget_applySettings()
			end,
		},
		show_value = {
			type = "toggle",
			name = "Show Value Text",
			desc = "Show Value Text",
			get = function()
				return deathlog_settings[widget_name]["show_value"]
			end,
			set = function()
				deathlog_settings[widget_name]["show_value"] = not deathlog_settings[widget_name]["show_value"]
				Deathlog_HIWidget_applySettings()
			end,
		},
	},
}
