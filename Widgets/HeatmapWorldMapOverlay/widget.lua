local precomputed_heatmap_intensity = DeathNotificationLib.HEATMAP_INTENSITY

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

local GRANULARITY_VALUES = {
	["low"] = 25,
	["medium"] = 50,
	["high"] = 75,
	["ultra"] = 100,
}

local function getGranularity()
	if deathlog_settings and deathlog_settings[widget_name] and deathlog_settings[widget_name]["granularity"] then
		return GRANULARITY_VALUES[deathlog_settings[widget_name]["granularity"]] or 100
	end
	return 100
end

function Deathlog_GetHeatmapGranularity()
	return getGranularity()
end

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
	if heatmap_wm_overlay_frame.heatmap == nil then
		return
	end
	if last_calculated_map_id == map_id then
		return
	end
	last_calculated_map_id = map_id

	-- Hide all existing textures from previous zone
	for i, row in pairs(heatmap_wm_overlay_frame.heatmap) do
		for j, tex in pairs(row) do
			tex:Hide()
		end
	end

	local should_hide = Deathlog_should_hide_heatmap and Deathlog_should_hide_heatmap(map_id)
	if should_hide or map_id == nil or precomputed_heatmap_intensity[map_id] == nil then
		return
	end

	local gran = getGranularity()
	local cell_size = math.ceil(11 * 100 / gran)

	-- Bucket the precomputed data into the current granularity
	local bucketed = {}
	for x, v2 in pairs(precomputed_heatmap_intensity[map_id]) do
		for y, intensity in pairs(v2) do
			local bx = math.ceil(x * gran / 100)
			local by = math.ceil(y * gran / 100)
			if bx >= 1 and bx <= gran and by >= 1 and by <= gran then
				if bucketed[bx] == nil then bucketed[bx] = {} end
				if bucketed[bx][by] == nil or intensity > bucketed[bx][by] then
					bucketed[bx][by] = intensity
				end
			end
		end
	end

	local mWidth, mHeight = WorldMapFrame:GetCanvas():GetSize()
	for x, row in pairs(bucketed) do
		for y, intensity in pairs(row) do
			local alpha = intensity * 4
			if alpha > 0 then
				if alpha > 0.6 then
					alpha = 0.6
				end
				if heatmap_wm_overlay_frame.heatmap[x] == nil then
					heatmap_wm_overlay_frame.heatmap[x] = {}
				end
				if heatmap_wm_overlay_frame.heatmap[x][y] == nil then
					local tex = heatmap_wm_overlay_frame:CreateTexture(nil, "BACKGROUND")
					tex:SetDrawLayer("OVERLAY", -7)
					heatmap_wm_overlay_frame.heatmap[x][y] = tex
				end
				local tex = heatmap_wm_overlay_frame.heatmap[x][y]
				tex:SetHeight(cell_size)
				tex:SetWidth(cell_size)
				tex:SetColorTexture(1.0, 1.1 - intensity * 4, 0.1, alpha)
				tex:SetPoint("CENTER", WorldMapButton, "TOPLEFT", mWidth * x / gran, -mHeight * y / gran)
				tex:Show()
			end
		end
	end
end

local defaults = {
	["enable"] = true,
	["show_checkbox_on_map"] = true,
	["granularity"] = "ultra",
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

local options = {}
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

	if heatmap_wm_overlay_frame.heatmap == nil then
		heatmap_wm_overlay_frame.heatmap = {}
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
		heatmap_resolution = {
			type = "select",
			name = "Heatmap Resolution",
			desc = "Controls the heatmap grid resolution. Lower values improve performance.",
			values = {
				["low"] = "Low (25x25)",
				["medium"] = "Medium (50x50)",
				["high"] = "High (75x75)",
				["ultra"] = "Ultra (100x100)",
			},
			sorting = { "low", "medium", "high", "ultra" },
			get = function()
				return deathlog_settings[widget_name]["granularity"]
			end,
			set = function(_, value)
				deathlog_settings[widget_name]["granularity"] = value
				-- Wipe heatmap to force re-render at new resolution
				if heatmap_wm_overlay_frame.heatmap then
					for i, row in pairs(heatmap_wm_overlay_frame.heatmap) do
						for j, tex in pairs(row) do
							tex:Hide()
						end
					end
					heatmap_wm_overlay_frame.heatmap = {}
				end
				last_calculated_map_id = nil
				updateWMOHeatmap(WorldMapFrame:GetMapID())
			end,
		},
	},
}

hooksecurefunc(WorldMapFrame, "OnMapChanged", function()
	updateWMOHeatmap(WorldMapFrame:GetMapID())
end)
