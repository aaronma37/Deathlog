--[[
Copyright 2023 Yazpad
The Deathlog AddOn is distributed under the terms of the GNU General Public License (or the Lesser GPL).
This file is part of Hardcore.

The Deathlog AddOn is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

The Deathlog AddOn is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with the Deathlog AddOn. If not, see <http://www.gnu.org/licenses/>.
--]]
--
local AceGUI = LibStub("AceGUI-3.0")
local max_row_num = 25
local page_number = 1
local deadliest_creatures_container = CreateFrame("Frame")
deadliest_creatures_container:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
local function createDeadliestCreaturesEntry()
	local frame = CreateFrame("Frame")
	frame:SetParent(deadliest_creatures_container)
	frame:SetWidth(60)
	frame:SetHeight(20)

	frame.background = frame:CreateTexture(nil, "OVERLAY")
	frame.background:SetPoint("LEFT", frame, "LEFT", 0, 0)
	frame.background:SetVertexColor(0.6, 0.2, 0.2)
	frame.background:SetTexture("Interface/TARGETINGFRAME/UI-StatusBar.PNG")
	frame.background:SetHeight(14)
	frame.background:SetWidth(20)
	frame.background:Show()

	frame.creature_name = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.creature_name:SetPoint("LEFT", frame, "LEFT", 10, 0)
	frame.creature_name:SetFont("Fonts\\blei00d.TTF", 14, "OUTLINE")
	frame.creature_name:SetTextColor(0.9, 0.9, 0.9)
	frame.creature_name:SetText("AAA")
	frame.creature_name:Show()

	frame.num_kills_text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.num_kills_text:SetPoint("RIGHT", frame, "RIGHT", 0, 0)
	frame.num_kills_text:SetText("")
	frame.num_kills_text:SetJustifyH("RIGHT")
	frame.num_kills_text:Show()

	frame.SetBackgroundWidth = function(self, width)
		self.background:SetWidth(width)
	end

	frame.SetCreatureName = function(self, creature_name)
		if creature_name == nil then
			frame.creature_name:SetText("Environment Damage")
		else
			frame.creature_name:SetText(creature_name)
		end
	end

	frame.SetNumKills = function(self, num)
		frame.num_kills_text:SetText(num .. " kills")
	end

	return frame
end
local deadliest_creatures_textures = {}
for i = 1, max_row_num do
	deadliest_creatures_textures[i] = createDeadliestCreaturesEntry()
	-- deadliest_creatures_textures[i].rank_text:SetText(i)
end

if deadliest_creatures_container.heading == nil then
	deadliest_creatures_container.heading =
		deadliest_creatures_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	deadliest_creatures_container.heading:SetText("Deadliest Creatures")
	deadliest_creatures_container.heading:SetFont("Fonts\\blei00d.TTF", 18, "")
	deadliest_creatures_container.heading:SetJustifyV("TOP")
	deadliest_creatures_container.heading:SetTextColor(0.9, 0.9, 0.9)
	deadliest_creatures_container.heading:SetPoint("TOP", deadliest_creatures_container, "TOP", 0, -20)
	deadliest_creatures_container.heading:Show()
end

if deadliest_creatures_container.page_str == nil then
	deadliest_creatures_container.page_str =
		deadliest_creatures_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	deadliest_creatures_container.page_str:SetText("Page " .. page_number)
	deadliest_creatures_container.page_str:SetFont("Fonts\\blei00d.TTF", 14, "")
	deadliest_creatures_container.page_str:SetJustifyV("BOTTOM")
	deadliest_creatures_container.page_str:SetJustifyH("CENTER")
	deadliest_creatures_container.page_str:SetTextColor(0.7, 0.7, 0.7)
	deadliest_creatures_container.page_str:SetPoint("TOP", deadliest_creatures_container, "TOP", 0, -430)
	deadliest_creatures_container.page_str:Show()
end

if deadliest_creatures_container.prev_button == nil then
	deadliest_creatures_container.prev_button = CreateFrame("Button", nil, deadliest_creatures_container)
	deadliest_creatures_container.prev_button:SetPoint(
		"CENTER",
		deadliest_creatures_container.page_str,
		"CENTER",
		-50,
		0
	)
	deadliest_creatures_container.prev_button:SetWidth(25)
	deadliest_creatures_container.prev_button:SetHeight(25)
	deadliest_creatures_container.prev_button:SetNormalTexture("Interface/Buttons/UI-SpellbookIcon-PrevPage-Up.PNG")
	deadliest_creatures_container.prev_button:SetHighlightTexture("Interface/Buttons/UI-SpellbookIcon-PrevPage-Up.PNG")
	deadliest_creatures_container.prev_button:SetPushedTexture("Interface/Buttons/UI-SpellbookIcon-PrevPage-Down.PNG")

	deadliest_creatures_container.prev_button:SetScript("OnClick", function()
		page_number = page_number - 1
		if page_number < 1 then
			page_number = 1
		end
	end)
end

if deadliest_creatures_container.next_button == nil then
	deadliest_creatures_container.next_button = CreateFrame("Button", nil, deadliest_creatures_container)
	deadliest_creatures_container.next_button:SetPoint(
		"CENTER",
		deadliest_creatures_container.page_str,
		"CENTER",
		50,
		0
	)
	deadliest_creatures_container.next_button:SetWidth(25)
	deadliest_creatures_container.next_button:SetHeight(25)
	deadliest_creatures_container.next_button:SetNormalTexture("Interface/Buttons/UI-SpellbookIcon-NextPage-Up.PNG")
	deadliest_creatures_container.next_button:SetHighlightTexture("Interface/Buttons/UI-SpellbookIcon-NextPage-Up.PNG")
	deadliest_creatures_container.next_button:SetPushedTexture("Interface/Buttons/UI-SpellbookIcon-NextPage-Down.PNG")
end

if deadliest_creatures_container.heading_description == nil then
	deadliest_creatures_container.heading_description =
		deadliest_creatures_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	deadliest_creatures_container.heading_description:SetText("Click to view stats.")
	deadliest_creatures_container.heading_description:SetFont("Fonts\\blei00d.TTF", 12, "")
	deadliest_creatures_container.heading_description:SetJustifyV("TOP")
	deadliest_creatures_container.heading_description:SetTextColor(0.6, 0.6, 0.6)
	deadliest_creatures_container.heading_description:SetPoint(
		"TOP",
		deadliest_creatures_container.heading,
		"BOTTOM",
		0,
		0
	)
	deadliest_creatures_container.heading_description:Show()
end

if deadliest_creatures_container.left == nil then
	deadliest_creatures_container.left = deadliest_creatures_container:CreateTexture(nil, "BACKGROUND")
	deadliest_creatures_container.left:SetHeight(8)
	deadliest_creatures_container.left:SetPoint("LEFT", deadliest_creatures_container.heading, "LEFT", -30, 0)
	deadliest_creatures_container.left:SetPoint("RIGHT", deadliest_creatures_container.heading, "LEFT", -5, 0)
	deadliest_creatures_container.left:SetTexture(137057) -- Interface\\Tooltips\\UI-Tooltip-Border
	deadliest_creatures_container.left:SetTexCoord(0.81, 0.94, 0.5, 1)
end

if deadliest_creatures_container.right == nil then
	deadliest_creatures_container.right = deadliest_creatures_container:CreateTexture(nil, "BACKGROUND")
	deadliest_creatures_container.right:SetHeight(8)
	deadliest_creatures_container.right:SetPoint("RIGHT", deadliest_creatures_container.heading, "RIGHT", 30, 0)
	deadliest_creatures_container.right:SetPoint("LEFT", deadliest_creatures_container.heading, "RIGHT", 5, 0)
	deadliest_creatures_container.right:SetTexture(137057) -- Interface\\Tooltips\\UI-Tooltip-Border
	deadliest_creatures_container.right:SetTexCoord(0.81, 0.94, 0.5, 1)
end

function deadliest_creatures_container.updateMenuElement(scroll_frame, _, stats_tbl, updateFun, filter)
	local current_map_id = 947
	deadliest_creatures_container.page_str:SetText("Page " .. page_number)
	deadliest_creatures_container.heading:Show()
	deadliest_creatures_container.left:Show()
	deadliest_creatures_container.right:Show()
	local _stats = stats_tbl["stats"]
	local valid_map = C_Map.GetMapInfo(current_map_id)
	if valid_map then
		deadliest_creatures_container.heading_description:Show()
	else
		deadliest_creatures_container.heading_description:Hide()
	end
	local num_recorded_kills = 0
	for i = 1, max_row_num do
		deadliest_creatures_textures[i]:Hide()
	end
	local map_id = current_map_id
	if map_id == 947 then
		map_id = "all"
	end

	if deadliest_creatures_container.player_search_box == nil then
		deadliest_creatures_container.player_search_box =
			CreateFrame("EditBox", nil, deadliest_creatures_container, "InputBoxTemplate")
	end

	if deadliest_creatures_container.player_search_box.text == nil then
		deadliest_creatures_container.player_search_box.text =
			deadliest_creatures_container:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	end
	deadliest_creatures_container.player_search_box:SetPoint("TOP", deadliest_creatures_container, "TOP", -190, -25)
	deadliest_creatures_container.player_search_box:SetWidth(130)
	deadliest_creatures_container.player_search_box:SetHeight(30)
	deadliest_creatures_container.player_search_box:SetMovable(false)
	deadliest_creatures_container.player_search_box:SetBlinkSpeed(1)
	deadliest_creatures_container.player_search_box:SetAutoFocus(false)
	deadliest_creatures_container.player_search_box:SetMultiLine(false)
	deadliest_creatures_container.player_search_box:SetMaxLetters(20)
	deadliest_creatures_container.player_search_box:SetScript("OnEnterPressed", function()
		deadliest_creatures_container.updateMenuElement(scroll_frame, _, stats_tbl, updateFun, function(name)
			if name == nil then
				return false
			end
			if
				string.find(string.lower(name), string.lower(deadliest_creatures_container.player_search_box:GetText()))
			then
				return true
			else
				return false
			end
		end)
	end)

	deadliest_creatures_container.player_search_box.text:SetPoint(
		"LEFT",
		deadliest_creatures_container.player_search_box,
		"LEFT",
		0,
		15
	)
	deadliest_creatures_container.player_search_box.text:SetFont("Fonts\\blei00d.TTF", 12, "")
	deadliest_creatures_container.player_search_box.text:SetTextColor(255 / 255, 215 / 255, 0)
	deadliest_creatures_container.player_search_box.text:SetText("Creature Search")
	deadliest_creatures_container.player_search_box.text:Show()

	local most_deadly_units = deathlogGetOrdered(_stats, { "all", map_id, "all", nil })
	local filtered_most_deadly_units = {}
	if filter == nil then
		filtered_most_deadly_units = most_deadly_units
	else
		for k, v in ipairs(most_deadly_units) do
			if filter(id_to_npc[v[1]]) then
				filtered_most_deadly_units[#filtered_most_deadly_units + 1] = v
			end
		end
	end
	if filtered_most_deadly_units and #filtered_most_deadly_units > 0 then
		local max_kills = filtered_most_deadly_units[1][2]
		for _, v in ipairs(filtered_most_deadly_units) do
			num_recorded_kills = num_recorded_kills + v[2]
		end

		deadliest_creatures_container:SetParent(scroll_frame.frame)
		deadliest_creatures_container:SetPoint("TOPLEFT", scroll_frame.frame, "TOPLEFT", 0, -25)
		deadliest_creatures_container:Show()
		deadliest_creatures_container:SetWidth(scroll_frame.frame:GetWidth() * 0.5)
		deadliest_creatures_container:SetHeight(scroll_frame.frame:GetWidth() * 0.8)
		for i = 1, max_row_num do
			local idx = (i + (page_number - 1) * max_row_num)
			if idx <= #filtered_most_deadly_units then
				deadliest_creatures_textures[i]:SetWidth(deadliest_creatures_container:GetWidth())
				deadliest_creatures_textures[i]:SetPoint(
					"TOPLEFT",
					deadliest_creatures_container,
					"TOPLEFT",
					0,
					-35 - i * 15
				)
				deadliest_creatures_textures[i]:SetBackgroundWidth(
					deadliest_creatures_container:GetWidth() * filtered_most_deadly_units[idx][2] / max_kills
				)
				deadliest_creatures_textures[i]:SetCreatureName(id_to_npc[filtered_most_deadly_units[idx][1]])
				deadliest_creatures_textures[i]:SetNumKills(filtered_most_deadly_units[idx][2])
				if valid_map then
					deadliest_creatures_textures[i]:SetScript("OnMouseDown", function()
						local c_id = filtered_most_deadly_units[idx][1]
						local c_name = id_to_npc[filtered_most_deadly_units[idx][1]]
						updateFun(c_id, c_name, function(name)
							if name == nil then
								return false
							end
							if
								string.find(
									string.lower(name),
									string.lower(deadliest_creatures_container.player_search_box:GetText())
								)
							then
								return true
							else
								return false
							end
						end)
					end)
				end
				deadliest_creatures_textures[i]:SetHeight(20)
				deadliest_creatures_textures[i]:Show()
			end
		end
	end

	deadliest_creatures_container:SetScript("OnHide", function()
		for _, v in ipairs(deadliest_creatures_textures) do
			v:Hide()
		end
		deadliest_creatures_container.heading:Hide()
		deadliest_creatures_container.left:Hide()
		deadliest_creatures_container.right:Hide()
	end)

	deadliest_creatures_container.prev_button:SetScript("OnClick", function()
		page_number = page_number - 1
		if page_number < 1 then
			page_number = 1
		end
		deadliest_creatures_container.updateMenuElement(scroll_frame, _, stats_tbl, updateFun)
	end)

	deadliest_creatures_container.next_button:SetScript("OnClick", function()
		page_number = page_number + 1
		if page_number > #most_deadly_units / max_row_num + 1 then
			page_number = #most_deadly_units / max_row_num + 1
		end
		deadliest_creatures_container.updateMenuElement(scroll_frame, _, stats_tbl, updateFun)
	end)
end

function Deathlog_DeadliestCreatureExtContainer()
	return deadliest_creatures_container
end
