--[[
info_button.lua

Deathlog-specific UI info button for death-logging eligibility status.

Creates a small button that attaches to a container frame and displays
a tooltip explaining the player's current hardcore state. Relies on
deathlog_getHardcoreCharacterState() from hardcore_state.lua.
--]]

local HC_STATE = DeathNotificationLib.HC_STATE
local IS_SOUL_OF_IRON_REALM = DeathNotificationLib.IS_SOUL_OF_IRON_REALM

--- Append "Update Available" lines to the current GameTooltip when a newer
--- Deathlog version has been detected from peers.  Returns true if lines
--- were added, false otherwise.
---@return boolean
local function appendUpdateAvailableTooltip()
	local newer = DeathNotificationLib.GetNewerAddonVersion("Deathlog")
	if not newer then return false end
	local current = C_AddOns.GetAddOnMetadata("Deathlog", "Version") or "?"
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("|TInterface\\GossipFrame\\AvailableQuestIcon:0|t Update Available", 0.3, 1, 0.3)
	GameTooltip:AddLine(string.format("v%s >> v%s", current, newer), 1, 0.8, 0)
	GameTooltip:AddLine("Please update to the latest version!", 0.7, 0.7, 0.7)
	return true
end

function deathlog_createInfoButton(container, with_events, offset_x, offset_y)
	if container.info_button == nil then
		container.info_button = CreateFrame("Button", nil, container.frame)

		local info_button = container.info_button
		info_button.deathlog_hc_state = "NOT_DETERMINED"
		info_button.deathlog_hc_state_func = nil
		info_button:SetPoint("RIGHT", container.titletext, "RIGHT", offset_x or 32, offset_y or 0)
		info_button:SetSize(32, 32)
		info_button:SetHitRectInsets(0, 0, 0, 0)
		info_button:EnableMouse(true)
		info_button:SetFrameLevel(container.frame:GetFrameLevel() + 10)
		info_button:SetNormalTexture("Interface\\common\\help-i")
		info_button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
		info_button:SetPushedTexture("Interface\\common\\help-i")
		info_button:SetScript("OnClick", nil)
		info_button:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
		info_button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")

			if self.deathlog_hc_state_func then
				self.deathlog_hc_state_func(self)
			end

            GameTooltip:Show()
        end)

		local function updateStateInfoButton()
			if not info_button then
				return
			end

			local state = deathlog_getHardcoreCharacterState("player")
			local has_update = DeathNotificationLib.GetNewerAddonVersion("Deathlog") ~= nil

			-- Allow re-evaluation when update status changes
			if info_button.deathlog_hc_state == state and info_button.deathlog_has_update == has_update then
				return
			end

			info_button.deathlog_hc_state = state
			info_button.deathlog_has_update = has_update

			if state == HC_STATE.HARDCORE then
				if has_update then
					-- Normally hidden when Hardcore — but show for update notification
					info_button.deathlog_hc_state_func = function(self)
						GameTooltip:ClearLines()
						GameTooltip:AddLine("Deathlog", 1, 0.8, 0, 1)
						appendUpdateAvailableTooltip()
					end
					info_button:Show()
				else
					info_button:Hide()
				end
			elseif state == HC_STATE.NOT_HARDCORE_ANYMORE then
				local isExternal = deathlog_getExternalHardcoreAddon()
				info_button.deathlog_hc_state_func = function(self)
					GameTooltip:ClearLines()
					GameTooltip:AddLine("Death Logging Status", 1, 0.8, 0, 1)
					GameTooltip:AddLine(" ")
					GameTooltip:AddLine("Status: |cffFF4444NOT HARDCORE ANYMORE|r")
					GameTooltip:AddLine(" ")
					if isExternal then
						GameTooltip:AddLine("Your hardcore journey tracked by " .. isExternal, 0.7, 0.7, 0.7)
						GameTooltip:AddLine("has ended due to a death.", 0.7, 0.7, 0.7)
					else
						GameTooltip:AddLine("You have lost your Hardcore status by acquiring", 0.7, 0.7, 0.7)
						GameTooltip:AddLine("the \"Tarnished Soul\" debuff.", 0.7, 0.7, 0.7)
					end
					GameTooltip:AddLine(" ")
					GameTooltip:AddLine("As a result, your deaths will no longer be", 0.7, 0.7, 0.7)
					GameTooltip:AddLine("logged to the Deathlog system.", 0.7, 0.7, 0.7)
					appendUpdateAvailableTooltip()
				end
				info_button:Show()
			elseif state == HC_STATE.UNDETERMINED then
				local location = UnitFactionGroup("player") == "Alliance" and "Ironforge" or "Undercity"
				info_button.deathlog_hc_state_func = function(self)
					GameTooltip:ClearLines()
					GameTooltip:AddLine("Death Logging Status", 1, 0.8, 0, 1)
					GameTooltip:AddLine(" ")
					GameTooltip:AddLine("Status: |cffFFFF00SOUL OF IRON REQUIRED|r")
					GameTooltip:AddLine(" ")
					GameTooltip:AddLine("To participate in death logging, you need:", 0.7, 0.7, 0.7)
					GameTooltip:AddLine("• Get the \"Soul of Iron\" buff", 1, 1, 0.5)
					GameTooltip:AddLine("• Location: " .. location, 0.5, 1, 1)
					GameTooltip:AddLine(" ")
					GameTooltip:AddLine("Once active, your deaths will be logged to the", 0.7, 0.7, 0.7)
					GameTooltip:AddLine("Deathlog system automatically.", 0.7, 0.7, 0.7)
					appendUpdateAvailableTooltip()
				end
				info_button:Show()
			else
				info_button.deathlog_hc_state_func = function(self)
					GameTooltip:ClearLines()
					GameTooltip:AddLine("Death Logging Status", 1, 0.8, 0, 1)
					GameTooltip:AddLine(" ")
					GameTooltip:AddLine("Status: |cffFF4444NOT SUPPORTED|r")
					GameTooltip:AddLine(" ")
					GameTooltip:AddLine("Your realm or your hardcore addons are not currently supported by the", 0.7, 0.7, 0.7)
					GameTooltip:AddLine("Deathlog addon.", 0.7, 0.7, 0.7)
					GameTooltip:AddLine(" ")
					GameTooltip:AddLine("Supported Realms:", 1, 1, 0.5)
					GameTooltip:AddLine("• Classic Era Hardcore", 0.5, 1, 1)
					GameTooltip:AddLine("• Burning Crusade - Soul of Iron", 0.5, 1, 1)
					GameTooltip:AddLine(" ")
					GameTooltip:AddLine("Supported Addons:", 1, 1, 0.5)
					GameTooltip:AddLine("• Hardcore", 0.5, 1, 1)
					GameTooltip:AddLine("• HardcoreTBC", 0.5, 1, 1)
					GameTooltip:AddLine("• Ultra", 0.5, 1, 1)
					appendUpdateAvailableTooltip()
				end
				info_button:Show()
			end
		end

		container.frame:HookScript("OnShow", function()
			updateStateInfoButton()
		end)

		if with_events then
			info_button:RegisterEvent("PLAYER_ENTERING_WORLD")
			if IS_SOUL_OF_IRON_REALM then
				info_button:RegisterEvent("UNIT_AURA")
			end
			info_button:SetScript("OnEvent", function(self, event, unit)
				if event == "PLAYER_ENTERING_WORLD" or (event == "UNIT_AURA" and unit == "player") then
					updateStateInfoButton()
				end
			end)
		end

		-- React immediately when a newer addon version is confirmed.
		DeathNotificationLib.HookOnNewerVersion(function()
			if info_button then updateStateInfoButton() end
		end)
	end

	return container.info_button
end