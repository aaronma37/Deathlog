--[[-----------------------------------------------------------------------------
Frame Container
-------------------------------------------------------------------------------]]
local Type, Version = "DeathlogMenu", 30
local AceGUI = LibStub and LibStub("AceGUI-3.0", true)
if not AceGUI or (AceGUI:GetWidgetVersion(Type) or 0) >= Version then
	return
end

local background_inset = 10

-- Lua APIs
local pairs, assert, type = pairs, assert, type
local wipe = table.wipe

-- WoW APIs
local PlaySound = PlaySound
local CreateFrame, UIParent = CreateFrame, UIParent

-- Global vars/functions that we don't upvalue since they might get hooked, or upgraded
-- List them here for Mikk's FindGlobals script
-- GLOBALS: CLOSE

--[[-----------------------------------------------------------------------------
Scripts
-------------------------------------------------------------------------------]]
local function Button_OnClick(frame)
	PlaySound(799) -- SOUNDKIT.GS_TITLE_OPTION_EXIT
	frame.obj:Hide()
end

local function Frame_OnShow(frame)
	frame.obj:Fire("OnShow")
end

local function Frame_OnClose(frame)
	frame.obj:Fire("OnClose")
end

local function Frame_OnMouseDown(frame)
	AceGUI:ClearFocus()
end

local function Title_OnMouseDown(frame)
	frame:GetParent():StartMoving()
	AceGUI:ClearFocus()
end

local function MoverSizer_OnMouseUp(mover)
	local frame = mover:GetParent()
	frame:StopMovingOrSizing()
	local self = frame.obj
	local status = self.status or self.localstatus
	local scale = frame:GetScale()
	status.width = frame:GetWidth()
	status.height = frame:GetHeight()
	-- Store screen coordinates (offset * scale) for consistent restore
	status.top = frame:GetTop() * scale
	status.left = frame:GetLeft() * scale
end

local function StatusBar_OnEnter(frame)
	frame.obj:Fire("OnEnterStatusBar")
end

local function StatusBar_OnLeave(frame)
	frame.obj:Fire("OnLeaveStatusBar")
end

--[[-----------------------------------------------------------------------------
Methods
-------------------------------------------------------------------------------]]
local methods = {
	["OnAcquire"] = function(self)
		self.frame:SetParent(UIParent)
		self.frame:SetFrameStrata("FULLSCREEN_DIALOG")
		self.frame:SetFrameLevel(100) -- Lots of room to draw under it
		self:SetTitle()
		self:SetStatusText()
		self:ApplyStatus()
		self:Show()
		self.sizer_se:Show()
	end,

	["OnRelease"] = function(self)
		self.status = nil
		wipe(self.localstatus)
	end,

	["OnWidthSet"] = function(self, width)
		local content = self.content
		local contentwidth = width - 34
		if contentwidth < 0 then
			contentwidth = 0
		end
		content:SetWidth(contentwidth)
		content.width = contentwidth
		self.background_texture:SetWidth(self.frame:GetWidth() - background_inset * 2)
	end,

	["OnHeightSet"] = function(self, height)
		local content = self.content
		local contentheight = height - 57
		if contentheight < 0 then
			contentheight = 0
		end
		content:SetHeight(contentheight)
		content.height = contentheight
		self.background_texture:SetHeight(self.frame:GetHeight() - background_inset * 2)
	end,

	["SetTitle"] = function(self, title)
		self.titletext:SetText(title)
		self.titlebg:SetWidth((self.titletext:GetWidth() or 0) + 10)
	end,

	["SetVersion"] = function(self, version)
		self.versiontext:SetText(version)
	end,

	["SetStatusText"] = function(self, text)
		self.statustext:SetText(text)
	end,

	["Hide"] = function(self)
		self.frame:Hide()
	end,

	["Show"] = function(self)
		self.frame:Show()
	end,

	["EnableResize"] = function(self, state)
		local func = state and "Show" or "Hide"
		self.sizer_se[func](self.sizer_se)
	end,

	-- called to set an external table to store status in
	["SetStatusTable"] = function(self, status)
		assert(type(status) == "table")
		self.status = status
		self:ApplyStatus()
	end,

	["ApplyStatus"] = function(self)
		local status = self.status or self.localstatus
		local frame = self.frame
		self:SetWidth(status.width or 1100)
		self:SetHeight(status.height or 600)
		local scale = status.scale or 1.0
		frame:SetScale(scale)
		frame:ClearAllPoints()
		if status.top and status.left then
			-- status.left/top are screen coords from GetLeft/GetTop;
			-- SetPoint offsets get multiplied by scale, so divide to compensate
			frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", status.left / scale, status.top / scale)
		else
			frame:SetPoint("CENTER")
		end
	end,
}

--[[-----------------------------------------------------------------------------
Constructor
-------------------------------------------------------------------------------]]
local FrameBackdrop = {
	bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
	edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
	tile = true,
	tileSize = 32,
	edgeSize = 32,
	insets = { left = 8, right = 8, top = 8, bottom = 8 },
}

local PaneBackdrop = {
	bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
	edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
	tile = true,
	tileSize = 16,
	edgeSize = 16,
	insets = { left = 3, right = 3, top = 5, bottom = 3 },
}

local function Constructor()
	local frame = CreateFrame("Frame", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	frame:Hide()

	frame:EnableMouse(true)
	frame:SetMovable(true)
	frame:SetResizable(false)
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:SetFrameLevel(100) -- Lots of room to draw under it
	frame:SetBackdrop(FrameBackdrop)
	frame:SetBackdropColor(0, 0, 0, 1)
	frame:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)
	if frame.SetResizeBounds then
		frame:SetResizeBounds(400, 200)
	end
	if frame.SetMinResize then
		frame:SetMinResize(400, 200)
	end

	frame:SetToplevel(true)
	frame:SetScript("OnShow", Frame_OnShow)
	frame:SetScript("OnHide", Frame_OnClose)
	frame:SetScript("OnMouseDown", Frame_OnMouseDown)

	local background_texture = frame:CreateTexture(nil, "BACKGROUND")
	background_texture:SetTexture("Interface\\Artifacts/ArtifactUIRogue.PNG")
	background_texture:SetTexCoord(0.000976562, 0.875977, 0.000976562, 0.601562)
	background_texture:SetVertexColor(1, 1, 1, 1)
	background_texture:SetPoint("TOPLEFT", frame, "TOPLEFT", background_inset, -background_inset)
	background_texture:SetWidth(frame:GetWidth())
	background_texture:SetHeight(frame:GetHeight())

	local statusbg = CreateFrame("Button", nil, frame, BackdropTemplateMixin and "BackdropTemplate" or nil)
	statusbg:SetPoint("BOTTOMLEFT", 15, 15)
	statusbg:SetPoint("BOTTOMRIGHT", -132, 15)
	statusbg:SetHeight(24)
	statusbg:SetBackdrop(PaneBackdrop)
	statusbg:SetBackdropColor(0.1, 0.1, 0.1)
	statusbg:SetBackdropBorderColor(0.4, 0.4, 0.4)
	statusbg:SetScript("OnEnter", StatusBar_OnEnter)
	statusbg:SetScript("OnLeave", StatusBar_OnLeave)
	statusbg:Hide()

	local statustext = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	statustext:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 10)
	statustext:SetHeight(20)
	statustext:SetTextColor(1, 1, 1, 1)
	statustext:SetFont(Deathlog_L.menu_font, 16)
	statustext:SetJustifyH("RIGHT")
	statustext:SetText("")

	local titlebg = frame:CreateTexture(nil, "OVERLAY")
	titlebg:SetTexture(131080) -- Interface\\DialogFrame\\UI-DialogBox-Header
	titlebg:SetTexCoord(0.31, 0.67, 0, 0.63)
	titlebg:SetPoint("TOPLEFT", 20, 18)
	titlebg:SetVertexColor(0, 0, 0, 0)
	titlebg:SetWidth(100)
	titlebg:SetHeight(60)

	local title = CreateFrame("Frame", nil, frame)
	title:EnableMouse(false)
	title:SetAllPoints(titlebg)

	local titletext = title:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	titletext:SetFont(Deathlog_L.menu_font, 40, "OUTLINE")
	titletext:SetTextColor(1, 1, 1, 1)
	titletext:SetPoint("TOP", titlebg, "TOP", 0, -38)

	local versiontext = title:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	versiontext:SetFont(Deathlog_L.menu_font, 16)
	versiontext:SetTextColor(1, 1, 1, 1)
	versiontext:SetPoint("BOTTOMLEFT", titletext, "BOTTOMRIGHT", 5, 0)

	-- Skull drag handle at top-left corner (matches minilog icon style, scaled up)
	local drag_handle = CreateFrame("Frame", nil, frame)
	drag_handle:SetPoint("TOPLEFT", frame, "TOPLEFT", -8, 8)
	drag_handle:SetSize(56, 56)
	drag_handle:EnableMouse(true)
	drag_handle:SetFrameLevel(frame:GetFrameLevel() + 10)
	drag_handle:SetScript("OnMouseDown", Title_OnMouseDown)
	drag_handle:SetScript("OnMouseUp", MoverSizer_OnMouseUp)

	local drag_handle_bg = drag_handle:CreateTexture(nil, "OVERLAY")
	drag_handle_bg:SetPoint("CENTER", drag_handle, "CENTER", -7, 6)
	drag_handle_bg:SetSize(56, 56)
	drag_handle_bg:SetTexture("Interface\\PVPFrame\\PVP-Separation-Circle-Cooldown-overlay")
	drag_handle_bg:SetDrawLayer("OVERLAY", 2)

	local drag_handle_skull = drag_handle:CreateTexture(nil, "OVERLAY")
	drag_handle_skull:SetPoint("CENTER", drag_handle, "CENTER", -6, 6)
	drag_handle_skull:SetSize(35, 35)
	drag_handle_skull:SetTexture("Interface\\TARGETINGFRAME\\UI-TargetingFrame-Skull")
	drag_handle_skull:SetDrawLayer("OVERLAY", 3)

	local drag_handle_ring = drag_handle:CreateTexture(nil, "OVERLAY")
	drag_handle_ring:SetPoint("CENTER", drag_handle, "CENTER", 0, 0)
	drag_handle_ring:SetSize(70, 70)
	drag_handle_ring:SetTexture("Interface\\COMMON\\BlueMenuRing")
	drag_handle_ring:SetDrawLayer("OVERLAY", 4)

	local titlebg_l = frame:CreateTexture(nil, "OVERLAY")
	titlebg_l:SetTexture(131080) -- Interface\\DialogFrame\\UI-DialogBox-Header
	titlebg_l:SetTexCoord(0.21, 0.31, 0, 0.63)
	titlebg_l:SetPoint("RIGHT", titlebg, "LEFT")
	titlebg_l:SetVertexColor(0, 0, 0, 0)
	titlebg_l:SetWidth(30)
	titlebg_l:SetHeight(60)

	local titlebg_r = frame:CreateTexture(nil, "OVERLAY")
	titlebg_r:SetTexture(131080) -- Interface\\DialogFrame\\UI-DialogBox-Header
	titlebg_r:SetTexCoord(0.67, 0.77, 0, 0.63)
	titlebg_r:SetPoint("LEFT", titlebg, "RIGHT")
	titlebg_r:SetVertexColor(0, 0, 0, 0)
	titlebg_r:SetWidth(30)
	titlebg_r:SetHeight(60)

	local sizer_se = CreateFrame("Frame", nil, frame)
	sizer_se:SetPoint("BOTTOMRIGHT")
	sizer_se:SetWidth(25)
	sizer_se:SetHeight(25)
	sizer_se:EnableMouse(true)

	local line1 = sizer_se:CreateTexture(nil, "BACKGROUND")
	line1:SetWidth(14)
	line1:SetHeight(14)
	line1:SetPoint("BOTTOMRIGHT", -8, 8)
	line1:SetTexture(137057) -- Interface\\Tooltips\\UI-Tooltip-Border
	local x = 0.1 * 14 / 17
	line1:SetTexCoord(0.05 - x, 0.5, 0.05, 0.5 + x, 0.05, 0.5 - x, 0.5 + x, 0.5)

	local line2 = sizer_se:CreateTexture(nil, "BACKGROUND")
	line2:SetWidth(8)
	line2:SetHeight(8)
	line2:SetPoint("BOTTOMRIGHT", -8, 8)
	line2:SetTexture(137057) -- Interface\\Tooltips\\UI-Tooltip-Border
	local x = 0.1 * 8 / 17
	line2:SetTexCoord(0.05 - x, 0.5, 0.05, 0.5 + x, 0.05, 0.5 - x, 0.5 + x, 0.5)

	-- Drag to scale: drag down-right = bigger, up-left = smaller
	-- Pinned at the top-left corner so the window doesn't drift while scaling
	sizer_se:SetScript("OnMouseDown", function(self)
		local parent = self:GetParent()
		local startScale = parent:GetScale()
		local startX, startY = GetCursorPosition()
		-- GetLeft()/GetTop() return offsets in parent space;
		-- multiply by scale to get actual screen position (captured ONCE)
		local screenLeft = parent:GetLeft() * startScale
		local screenTop = parent:GetTop() * startScale
		self:SetScript("OnUpdate", function()
			local curX, curY = GetCursorPosition()
			-- Diagonal delta: rightward + downward = scale up
			local delta = ((curX - startX) + (startY - curY)) * 0.5
			local newScale = startScale + delta / 1000
			if newScale < 0.5 then newScale = 0.5 end
			if newScale > 1.0 then newScale = 1.0 end
			parent:SetScale(newScale)
			-- offset = screenCoord / scale so that
			-- actual screen pos = offset * scale = screenCoord (constant)
			parent:ClearAllPoints()
			parent:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", screenLeft / newScale, screenTop / newScale)
		end)
		-- Set OnMouseUp inside OnMouseDown so it shares the screenLeft/screenTop upvalues
		self:SetScript("OnMouseUp", function(self)
			self:SetScript("OnUpdate", nil)
			local parent = self:GetParent()
			local widget = parent.obj
			if widget then
				local status = widget.status or widget.localstatus
				status.scale = parent:GetScale()
				-- Store screen coordinates (same ones we pinned to)
				status.left = screenLeft
				status.top = screenTop
			end
		end)
		AceGUI:ClearFocus()
	end)

	--Container Support
	local content = CreateFrame("Frame", nil, frame)
	content:SetPoint("TOPLEFT", 17, -27)
	content:SetPoint("BOTTOMRIGHT", -17, 30)

	local widget = {
		localstatus = {},
		titletext = titletext,
		versiontext = versiontext,
		statustext = statustext,
		background_texture = background_texture,
		titlebg = titlebg,
		sizer_se = sizer_se,
		content = content,
		frame = frame,
		type = Type,
	}
	for method, func in pairs(methods) do
		widget[method] = func
	end

	return AceGUI:RegisterAsContainer(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
