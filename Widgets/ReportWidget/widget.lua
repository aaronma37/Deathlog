-- ReportWidget: Helps players report Soul of Iron deaths by providing a click-to-target button
-- Uses InsecureActionButtonTemplate to allow /target via secure button click

local widget_name = "ReportWidget"

-- Queue of players to report: { [name] = { name, guid, race_id, class_id, guild, map_id, map_pos, instance_id, timestamp } }
local report_queue = {}
local report_queue_order = {} -- Ordered list of names for FIFO processing

-- Main frame
local report_frame = CreateFrame("Frame", "DeathlogReportWidget", UIParent, "BackdropTemplate")
report_frame:SetSize(300, 80)
report_frame:SetPoint("TOP", UIParent, "TOP", 0, -150)
report_frame:SetMovable(true)
report_frame:EnableMouse(true)
report_frame:RegisterForDrag("LeftButton")
report_frame:SetScript("OnDragStart", function(self)
	if not InCombatLockdown() then
		self:StartMoving()
	end
end)
report_frame:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	local point, _, relPoint, x, y = self:GetPoint()
	deathlog_settings[widget_name]["pos_x"] = x
	deathlog_settings[widget_name]["pos_y"] = y
end)
report_frame:SetBackdrop({
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true, tileSize = 32, edgeSize = 16,
	insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
report_frame:SetBackdropColor(0.1, 0.1, 0.1, 0.9)
report_frame:SetFrameStrata("HIGH")
report_frame:Hide()

-- Title text
report_frame.title = report_frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
report_frame.title:SetPoint("TOP", report_frame, "TOP", 0, -10)
report_frame.title:SetText("Soul of Iron Death Detected")
report_frame.title:SetTextColor(1, 0.5, 0, 1)

-- Player name text
report_frame.playerName = report_frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
report_frame.playerName:SetPoint("TOP", report_frame.title, "BOTTOM", 0, -5)
report_frame.playerName:SetText("")

-- Combat lockdown text
report_frame.combatText = report_frame:CreateFontString(nil, "OVERLAY", "GameFontRed")
report_frame.combatText:SetPoint("BOTTOM", report_frame, "BOTTOM", 0, 30)
report_frame.combatText:SetText("In Combat - Wait...")
report_frame.combatText:Hide()

-- Queue count text
report_frame.queueText = report_frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
report_frame.queueText:SetPoint("BOTTOMRIGHT", report_frame, "BOTTOMRIGHT", -8, 8)
report_frame.queueText:SetText("")

-- Close/Skip button
report_frame.skipBtn = CreateFrame("Button", nil, report_frame, "UIPanelCloseButton")
report_frame.skipBtn:SetPoint("TOPRIGHT", report_frame, "TOPRIGHT", -2, -2)
report_frame.skipBtn:SetScript("OnClick", function()
	Deathlog_ReportWidget_Skip()
end)

-- The main action button - just calls /dlr slash command
report_frame.actionBtn = CreateFrame("Button", "DeathlogReportActionButton", report_frame, "InsecureActionButtonTemplate, UIPanelButtonTemplate")
report_frame.actionBtn:SetSize(140, 25)
report_frame.actionBtn:SetPoint("BOTTOM", report_frame, "BOTTOM", 0, 8)
report_frame.actionBtn:SetText("Click to Report")
report_frame.actionBtn:SetAttribute("type", "macro")
report_frame.actionBtn:RegisterForClicks("AnyUp", "AnyDown")
report_frame.actionBtn:SetAttribute("macrotext", "/dlr")

-- Combat lockdown handling
local combat_frame = CreateFrame("Frame")
combat_frame:RegisterEvent("PLAYER_REGEN_DISABLED")
combat_frame:RegisterEvent("PLAYER_REGEN_ENABLED")
combat_frame:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_REGEN_DISABLED" then
		-- Entered combat
		report_frame.actionBtn:Disable()
		report_frame.combatText:Show()
	elseif event == "PLAYER_REGEN_ENABLED" then
		-- Left combat
		report_frame.actionBtn:Enable()
		report_frame.combatText:Hide()
	end
end)

-- Slash command /dlr: Gather info from current target (macro already targeted the player)
SLASH_DEATHLOGREPORT1 = "/dlr"
SlashCmdList["DEATHLOGREPORT"] = function()
	local current = report_queue_order[1]
	if not current then
		return
	end
	
	local entry = report_queue[current]
	if not entry then
		Deathlog_ReportWidget_Skip()
		return
	end
	
	-- The macro already did /target <name>, so just read current target
	local target_name = UnitName("target")

	if target_name and target_name:lower() == entry.name:lower() then
		-- Successfully targeted! Gather all the info
		local level = UnitLevel("target")
		local guild = GetGuildInfo("target")
		local _, _, class_id = UnitClass("target")
		local _, _, race_id = UnitRace("target")
		
		-- Use GUID-based info if we didn't get it from targeting
		if not class_id then class_id = entry.class_id end
		if not race_id then race_id = entry.race_id end
		
		-- Create the death entry
		Deathlog_ReportWidget_CreateEntry(entry.name, level, guild, race_id, class_id, entry.map_id, entry.map_pos, entry.instance_id)
		
		-- Remove from queue and show next
		Deathlog_ReportWidget_RemoveFromQueue(entry.name)
	else
		-- Targeting failed (player out of range/released), try /who as fallback
		if DeathNotificationLib.WhoPlayer then
			DeathNotificationLib.WhoPlayer(entry.name, function(who_info)
				if who_info then
					local who_class_id = who_info.filename and DeathNotificationLib.CLASS_FILE_TO_ID[who_info.filename] or nil
					local who_race_id = who_info.raceStr and DeathNotificationLib.RACE_NAME_TO_ID[who_info.raceStr] or nil

					Deathlog_ReportWidget_CreateEntry(entry.name, who_info.level, who_info.fullGuildName, who_race_id, who_class_id, entry.map_id, entry.map_pos, entry.instance_id)
				else
					-- Both failed, create with partial info
					Deathlog_ReportWidget_CreateEntry(entry.name, nil, entry.guild, entry.race_id, entry.class_id, entry.map_id, entry.map_pos, entry.instance_id)
				end
				Deathlog_ReportWidget_RemoveFromQueue(entry.name)
			end)

			-- Timeout for /who
			C_Timer.After(5, function()
				if report_queue[entry.name] then
					Deathlog_ReportWidget_CreateEntry(entry.name, nil, entry.guild, entry.race_id, entry.class_id, entry.map_id, entry.map_pos, entry.instance_id)
					Deathlog_ReportWidget_RemoveFromQueue(entry.name)
				end
			end)
		else
			-- No /who available, create with partial info
			Deathlog_ReportWidget_CreateEntry(entry.name, nil, entry.guild, entry.race_id, entry.class_id, entry.map_id, entry.map_pos, entry.instance_id)
			Deathlog_ReportWidget_RemoveFromQueue(entry.name)
		end
	end
end

-- Helper: Broadcast reported death via DeathNotificationLib
function Deathlog_ReportWidget_CreateEntry(name, level, guild, race_id, class_id, map_id, map_pos, instance_id)
	if not DeathNotificationLib.BroadcastReportedDeath then
		print("|cffFF6600[Deathlog]|r ReportWidget: DeathNotificationLib not loaded")
		return
	end

	local success, error_message = DeathNotificationLib.BroadcastReportedDeath(name, guild, -1, race_id, class_id, level, instance_id, map_id, map_pos, GetServerTime(), nil, nil)
	if not success then
		print("|cffFF6600[Deathlog]|r ReportWidget: Failed to broadcast death - " .. (error_message or "unknown error"))
	end
end

-- Add a player to the report queue (registered as a QueuePlayer hook)
local function reportWidgetQueuePlayer(name, guid, race_id, class_id, guild, map_id, map_pos, instance_id)
	-- Check if reporting is enabled
	if deathlog_settings and deathlog_settings[widget_name] and deathlog_settings[widget_name]["enable"] == false then
		return false
	end
	
	-- Don't queue if already in queue
	if report_queue[name] then
		return false
	end
	
	-- Add to queue
	report_queue[name] = {
		name = name,
		guid = guid,
		race_id = race_id,
		class_id = class_id,
		guild = guild,
		map_id = map_id,
		map_pos = map_pos,
		instance_id = instance_id,
		timestamp = GetServerTime()
	}
	table.insert(report_queue_order, name)
	
	-- Update and show widget
	Deathlog_ReportWidget_UpdateDisplay()
	
	-- Set timeout to auto-remove after 60 seconds
	C_Timer.After(60, function()
		if report_queue[name] then
			Deathlog_ReportWidget_RemoveFromQueue(name)
		end
	end)
	
	return true
end

-- Remove a player from the queue (called when death is reported by others too)
function Deathlog_ReportWidget_RemoveFromQueue(name)
	if not report_queue[name] then return end
	
	report_queue[name] = nil
	
	-- Remove from ordered list
	for i, n in ipairs(report_queue_order) do
		if n == name then
			table.remove(report_queue_order, i)
			break
		end
	end
	
	Deathlog_ReportWidget_UpdateDisplay()
end

-- Skip current player in queue
function Deathlog_ReportWidget_Skip()
	local current = report_queue_order[1]
	if current then
		Deathlog_ReportWidget_RemoveFromQueue(current)
	end
end

-- Update the widget display
function Deathlog_ReportWidget_UpdateDisplay()
	local current = report_queue_order[1]
	
	if not current or not report_queue[current] then
		report_frame:Hide()
		return
	end
	
	local entry = report_queue[current]
	report_frame.playerName:SetText("|cFFFFFFFF" .. entry.name .. "|r")
	
	-- Update macro text for targeting (macro does: target -> gather info -> restore target)
	if not InCombatLockdown() then
		report_frame.actionBtn:SetAttribute("macrotext", "/target " .. entry.name .. "\n/dlr\n/targetlasttarget")
	end
	
	-- Update queue count
	local count = #report_queue_order
	if count > 1 then
		report_frame.queueText:SetText("+" .. (count - 1) .. " more")
		report_frame.queueText:Show()
	else
		report_frame.queueText:Hide()
	end
	
	-- Update combat state
	if InCombatLockdown() then
		report_frame.actionBtn:Disable()
		report_frame.combatText:Show()
	else
		report_frame.actionBtn:Enable()
		report_frame.combatText:Hide()
	end
	
	report_frame:Show()
end

-- Settings defaults
local defaults = {
	["enable"] = true,
	["pos_x"] = 0,
	["pos_y"] = -150,
}

local function applyDefaults(_defaults, force)
	deathlog_settings[widget_name] = deathlog_settings[widget_name] or {}
	for k, v in pairs(_defaults) do
		if deathlog_settings[widget_name][k] == nil or force then
			deathlog_settings[widget_name][k] = v
		end
	end
end

-- Options for AceConfig
local options = {
	name = widget_name,
	type = "group",
	args = {
		enable = {
			type = "toggle",
			name = "Enable Death Reporting",
			desc = "Show the report widget when Soul of Iron deaths are detected nearby. Allows you to click to target and report full player info.",
			order = 0,
			width = "full",
			get = function()
				return deathlog_settings[widget_name]["enable"]
			end,
			set = function()
				deathlog_settings[widget_name]["enable"] = not deathlog_settings[widget_name]["enable"]
				if not deathlog_settings[widget_name]["enable"] then
					-- Clear queue and hide when disabled
					report_queue = {}
					report_queue_order = {}
					report_frame:Hide()
				end
			end,
		},
		description = {
			type = "description",
			name = "\nWhen a Soul of Iron player dies nearby and we can't automatically get their full info, this widget appears asking you to click a button. This targets the player (if still in range) so we can gather their level, class, race, and guild for accurate death logging.\n\nThe widget is draggable. Deaths timeout after 60 seconds.",
			order = 1,
		},
		reset_position = {
			type = "execute",
			name = "Reset Position",
			desc = "Reset the widget to its default position",
			order = 2,
			func = function()
				deathlog_settings[widget_name]["pos_x"] = defaults["pos_x"]
				deathlog_settings[widget_name]["pos_y"] = defaults["pos_y"]
				Deathlog_ReportWidget_ApplySettings()
			end,
		},
	},
}

local optionsframe = nil
function Deathlog_ReportWidget_ApplySettings()
	applyDefaults(defaults)
	
	report_frame:ClearAllPoints()
	report_frame:SetPoint(
		"TOP",
		UIParent,
		"TOP",
		deathlog_settings[widget_name]["pos_x"],
		deathlog_settings[widget_name]["pos_y"]
	)
	
	if optionsframe == nil then
		LibStub("AceConfig-3.0"):RegisterOptionsTable(widget_name, options)
		optionsframe = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(widget_name, widget_name, "Deathlog")
	end
end

-- Hook into death notifications to remove reported players from queue
local function hookDeathNotifications()
	if DeathNotificationLib.HookOnNewEntry then
		DeathNotificationLib.HookOnNewEntry(function(_player_data)
			if _player_data and _player_data["name"] then
				-- Someone else reported this death, remove from our queue
				Deathlog_ReportWidget_RemoveFromQueue(_player_data["name"])
			end
		end)
	end
end

-- Initialize on load
local init_frame = CreateFrame("Frame")
init_frame:RegisterEvent("PLAYER_LOGIN")
init_frame:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_LOGIN" then
		hookDeathNotifications()
	end
end)

-- Register the queue-player hook so DNL invokes us for reported deaths
DeathNotificationLib.HookQueuePlayer(reportWidgetQueuePlayer)
