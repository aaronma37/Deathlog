local AceGUI = LibStub("AceGUI-3.0")
local death_alert_frame = CreateFrame("frame")
death_alert_frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
death_alert_frame:SetWidth(25)
death_alert_frame:SetHeight(25)
death_alert_frame:SetMovable(true)
death_alert_frame:EnableMouse(true)
death_alert_frame:Show()

death_alert_frame.tex = death_alert_frame:CreateTexture(nil, "OVERLAY")
death_alert_frame.tex:SetAllPoints()
death_alert_frame.tex:SetDrawLayer("OVERLAY", 7)
death_alert_frame.tex:SetVertexColor(1, 1, 1, 1)
death_alert_frame.tex:SetHeight(25)
death_alert_frame.tex:SetWidth(25)
death_alert_frame.tex:SetTexture("Interface\\TARGETINGFRAME\\UI-TargetingFrame-Skull")
death_alert_frame.tex:Show()
local last_calculated_map_id = nil

function initDeathAlertWidget(_settings)
	if deathlog_settings["death_alert_show"] == nil or deathlog_settings["death_alert_show"] == false then
		death_alert_frame:Hide()
		death_alert_frame.tex:Hide()
	else
		startUpdate()
		death_alert_frame:Hide()
		death_alert_frame.tex:Hide()
	end

	death_alert_frame:ClearAllPoints()
	if death_alert_frame and deathlog_settings["death_alert_pos"] then
		death_alert_frame:SetPoint(
			"CENTER",
			UIParent,
			"CENTER",
			deathlog_settings["death_alert_pos"]["x"],
			deathlog_settings["death_alert_pos"]["y"]
		)
	else
		death_alert_frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end

	if death_alert_frame and deathlog_settings["death_alert_size"] then
		death_alert_frame:SetSize(
			deathlog_settings["death_alert_size"]["x"],
			deathlog_settings["death_alert_size"]["y"]
		)
	else
		death_alert_frame:SetSize(255, 125)
	end
end

death_alert_frame:RegisterForDrag("LeftButton")
death_alert_frame:SetScript("OnDragStart", function(self, button)
	self:StartMoving()
	death_alert_frame.tex:SetPoint("TOPLEFT", death_alert_frame, "TOPLEFT", 10, -10)
end)
death_alert_frame:SetScript("OnDragStop", function(self)
	self:StopMovingOrSizing()
	local x, y = self:GetCenter()
	local px = (GetScreenWidth() * UIParent:GetEffectiveScale()) / 2
	local py = (GetScreenHeight() * UIParent:GetEffectiveScale()) / 2
	if deathlog_settings["death_alert_pos"] == nil then
		deathlog_settings["death_alert_pos"] = {}
	end
	deathlog_settings["death_alert_pos"]["x"] = x - px
	deathlog_settings["death_alert_pos"]["y"] = y - py
	death_alert_frame.tex:SetPoint("TOPLEFT", death_alert_frame, "TOPLEFT", 10, -10)
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
