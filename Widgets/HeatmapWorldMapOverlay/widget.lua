local AceGUI = LibStub("AceGUI-3.0")
local widget_name = "Heatmap WorldMap Overlay"
local WorldMapButton = WorldMapFrame:GetCanvas()
local heatmap_wm_overlay_frame = CreateFrame("frame", nil, WorldMapButton)
heatmap_wm_overlay_frame:SetWidth(40)
heatmap_wm_overlay_frame:SetHeight(40)
heatmap_wm_overlay_frame:Show()

local heatmap_wm_overlay_checkbox_frame = CreateFrame("frame", nil, WorldMapButton)
heatmap_wm_overlay_checkbox_frame:SetWidth(40)
heatmap_wm_overlay_checkbox_frame:SetHeight(40)
heatmap_wm_overlay_checkbox_frame:Show()

local last_calculated_map_id = nil
local granularity = 100
local grid_x = 11
local grid_y = 11

if heatmap_wm_overlay_checkbox_frame.heatmap_checkbox == nil then
	heatmap_wm_overlay_checkbox_frame.heatmap_checkbox = CreateFrame(
		"CheckButton",
		"DeathlogHeatmapCheckbox",
		heatmap_wm_overlay_checkbox_frame,
		"ChatConfigCheckButtonTemplate"
	)
	heatmap_wm_overlay_checkbox_frame.heatmap_checkbox:SetPoint("TOPLEFT", 100, -50)
	heatmap_wm_overlay_checkbox_frame.heatmap_checkbox:SetHitRectInsets(0, -75, 0, 0)
	heatmap_wm_overlay_checkbox_frame.heatmap_checkbox:Show()

	heatmap_wm_overlay_checkbox_frame.heatmap_checkbox.label =
		heatmap_wm_overlay_checkbox_frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	heatmap_wm_overlay_checkbox_frame.heatmap_checkbox.label:SetPoint(
		"LEFT",
		heatmap_wm_overlay_checkbox_frame.heatmap_checkbox,
		"RIGHT",
		0,
		0
	)
	heatmap_wm_overlay_checkbox_frame.heatmap_checkbox.label:SetFont(Deathlog_L.menu_font, 14, "OUTLINE")
	heatmap_wm_overlay_checkbox_frame.heatmap_checkbox.label:SetTextColor(0.9, 0.9, 0.9)
	heatmap_wm_overlay_checkbox_frame.heatmap_checkbox.label:SetJustifyH("RIGHT")
	heatmap_wm_overlay_checkbox_frame.heatmap_checkbox.label:SetText(Deathlog_L.show_heatmap)
	heatmap_wm_overlay_checkbox_frame.heatmap_checkbox.label:Show()
end

local function updateWMOHeatmap(map_id)
	if last_calculated_map_id == map_id then
		return
	end
	last_calculated_map_id = map_id

	for i = 1, granularity do
		for j = 1, granularity do
			heatmap_wm_overlay_frame.heatmap[i][j].intensity = 0.0
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
	if map_id ~= 947 and map_id ~= nil then
		for x, v2 in pairs(precomputed_heatmap_intensity[map_id]) do
			for y, intensity in pairs(v2) do
				heatmap_wm_overlay_frame.heatmap[x][y].intensity = intensity
			end
		end
	end
	local mWidth, mHeight = WorldMapFrame:GetCanvas():GetSize()
	for i = 1, granularity do
		for j = 1, granularity do
			local alpha = heatmap_wm_overlay_frame.heatmap[i][j].intensity * 4
			if map_id == 947 then
				alpha = 0
			end
			if alpha > 0.6 then
				alpha = 0.6
			end
			heatmap_wm_overlay_frame.heatmap[i][j]:SetColorTexture(
				1.0,
				1.1 - heatmap_wm_overlay_frame.heatmap[i][j].intensity * 4,
				0.1,
				alpha
			)
			heatmap_wm_overlay_frame.heatmap[i][j]:Show()
			heatmap_wm_overlay_frame.heatmap[i][j]:SetPoint(
				"CENTER",
				WorldMapButton,
				"TOPLEFT",
				mWidth * i / granularity,
				-mHeight * j / granularity
			)
		end
	end
end

local defaults = {
	["enable"] = true,
	["show_checkbox_on_map"] = true,
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
function Deathlog_HWMWidget_applySettings()
	applyDefaults(defaults)

	heatmap_wm_overlay_frame:SetParent(WorldMapButton)
	heatmap_wm_overlay_frame:ClearAllPoints()
	heatmap_wm_overlay_frame:SetAllPoints()
	heatmap_wm_overlay_frame:SetFrameLevel(2010)
	heatmap_wm_overlay_frame:SetFrameStrata("MEDIUM")
	heatmap_wm_overlay_frame:Show()

	heatmap_wm_overlay_checkbox_frame:SetParent(WorldMapButton)
	heatmap_wm_overlay_checkbox_frame:ClearAllPoints()
	heatmap_wm_overlay_checkbox_frame:SetAllPoints()
	heatmap_wm_overlay_checkbox_frame:SetFrameLevel(15000)
	heatmap_wm_overlay_checkbox_frame:Show()

	local mWidth, mHeight = WorldMapFrame:GetCanvas():GetSize()
	heatmap_wm_overlay_frame:SetHeight(mHeight)
	heatmap_wm_overlay_frame:SetWidth(mWidth)

	local modified_width = heatmap_wm_overlay_frame:GetWidth() * 0.98
	local modified_height = heatmap_wm_overlay_frame:GetHeight() * 0.87

	if heatmap_wm_overlay_frame.heatmap == nil then
		heatmap_wm_overlay_frame.heatmap = {}
		for i = 1, granularity do
			heatmap_wm_overlay_frame.heatmap[i] = {}
			for j = 1, granularity do
				heatmap_wm_overlay_frame.heatmap[i][j] = heatmap_wm_overlay_frame:CreateTexture(nil, "BACKGROUND")
				heatmap_wm_overlay_frame.heatmap[i][j]:SetDrawLayer("OVERLAY", -7)
				heatmap_wm_overlay_frame.heatmap[i][j]:SetHeight(grid_x)
				heatmap_wm_overlay_frame.heatmap[i][j]:SetColorTexture(1.0, 0.1, 0.1, 0)
				heatmap_wm_overlay_frame.heatmap[i][j]:SetWidth(grid_y)
				heatmap_wm_overlay_frame.heatmap[i][j]:SetPoint(
					"CENTER",
					heatmap_wm_overlay_frame,
					"TOPLEFT",
					modified_width * i / granularity,
					-modified_height * j / granularity
				)
				heatmap_wm_overlay_frame.heatmap[i][j]:Show()
				heatmap_wm_overlay_frame.heatmap[i][j].intensity = 0.0
			end
		end
	end

	heatmap_wm_overlay_checkbox_frame.heatmap_checkbox:SetChecked(deathlog_settings[widget_name]["enable"])
	heatmap_wm_overlay_checkbox_frame.heatmap_checkbox:SetScript("OnClick", function()
		deathlog_settings[widget_name]["enable"] = not deathlog_settings[widget_name]["enable"]
		Deathlog_HWMWidget_applySettings()
	end)

	updateWMOHeatmap(WorldMapFrame:GetMapID())
	if deathlog_settings[widget_name]["enable"] == nil or deathlog_settings[widget_name]["enable"] == false then
		heatmap_wm_overlay_frame:Hide()
	else
		heatmap_wm_overlay_frame:Show()
	end

	if deathlog_settings[widget_name]["show_checkbox_on_map"] then
		heatmap_wm_overlay_checkbox_frame:Show()
	else
		heatmap_wm_overlay_checkbox_frame:Hide()
	end

	if optionsframe == nil then
		LibStub("AceConfig-3.0"):RegisterOptionsTable(widget_name, options)
		optionsframe = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(widget_name, widget_name, "Deathlog")
	end
end

local function forceReset()
	applyDefaults(defaults, true)
	Deathlog_HWMWidget_applySettings()
end

options = {
	name = widget_name,
	handler = Minilog,
	type = "group",
	args = {
		enable = {
			type = "toggle",
			name = "Show Heatmap WorldMap Overlay",
			desc = "Show Heatmap WorldMap Overlay",
			get = function()
				return deathlog_settings[widget_name]["enable"]
			end,
			set = function()
				deathlog_settings[widget_name]["enable"] = not deathlog_settings[widget_name]["enable"]
				Deathlog_HWMWidget_applySettings()
			end,
		},
		show_checkbox = {
			type = "toggle",
			name = "Show checkbox on Worldmap Overlay",
			desc = "Show checkbox on Worldmap Overlay",
			get = function()
				return deathlog_settings[widget_name]["show_checkbox_on_map"]
			end,
			set = function()
				deathlog_settings[widget_name]["show_checkbox_on_map"] =
					not deathlog_settings[widget_name]["show_checkbox_on_map"]
				Deathlog_HWMWidget_applySettings()
			end,
		},
	},
}

hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
	updateWMOHeatmap(WorldMapFrame:GetMapID())
end)
