-- EllesmereUI Quality of Life for 5.4.8: the runtime of the retail "QoL" page
-- (EllesmereUIQoL.lua), GENERAL / GROUP FINDER / UI parts. EXTRAS (FPS,
-- secondary stats, durability, crosshair, combat alert, ...) live in
-- EllesmereUIQoL_Extras.lua, Self Combat Text in EllesmereUIQoL_SelfCombatText.lua.
--
-- Saved settings, like retail:
--   * the page toggles live on the core account table EllesmereUIDB (retail
--     keeps them there too, so the retail values carry over 1:1);
--   * the per-profile "extras" (FPS counter, secondary stats, self combat
--     text) live in EllesmereUIQoLDB (retail profile.addons.EllesmereUIQoL),
--     next to battleRes / bloodlust / cursor of the other QoL files.
-- 5.4.8 parts of gossip and cinematics are taken from QuickQuest and DBM.

local addonName = ...
local ns = EllesmereUI

local Q = ns.QoL or {}
ns.QoL = Q

local select, pairs, ipairs, type, floor = select, pairs, ipairs, type, math.floor

---------------------------------------------------------------------------
-- Saved tables
---------------------------------------------------------------------------
-- Account root (core SV): the retail QoL page keys.
local function R()
	if type(EllesmereUIDB) ~= "table" then
		EllesmereUIDB = {}
	end
	return EllesmereUIDB
end
Q.R = R

-- Module SV (EllesmereUIQoLDB): retail QoLExtras + selfCombatText.
local qol = {}
local function QDB()
	return qol
end
Q.DB = QDB

-- Retail EllesmereUI.QoLExtrasGet / Set: the profile value, else the
-- account root (retail reads fall back the same way).
function Q.XGet(k)
	local v = qol[k]
	if v ~= nil then return v end
	local r = EllesmereUIDB
	return type(r) == "table" and r[k] or nil
end
function Q.XSet(k, v)
	qol[k] = v
end
ns.QoLExtrasGet = Q.XGet
ns.QoLExtrasSet = Q.XSet

-- Retail toggles that are ON while never written ("~= false").
local DEFAULT_ON = {
	autoRepair = true, autoSellJunk = true, autoRepairGuild = true,
	autoGossipShiftSkip = true, autoGossipDisableInstance = true,
	hideScreenshotStatus = true, repairWarning = true, bonusRollOnly = true,
	suppressErrors = true,
}
function Q.On(key)
	local v = R()[key]
	if v == nil then
		return DEFAULT_ON[key] and true or false
	end
	return v and true or false
end

---------------------------------------------------------------------------
-- Timers (5.4.8 has no C_Timer)
---------------------------------------------------------------------------
local timers = {}
local timerFrame = CreateFrame("Frame")
timerFrame:Hide()
timerFrame:SetScript("OnUpdate", function(self)
	local now = GetTime()
	local i = 1
	while i <= #timers do
		local t = timers[i]
		if now >= t.at then
			table.remove(timers, i)
			t.fn()
		else
			i = i + 1
		end
	end
	if #timers == 0 then
		self:Hide()
	end
end)
function Q.After(sec, fn)
	timers[#timers + 1] = { at = GetTime() + (sec or 0), fn = fn }
	timerFrame:Show()
end

-- Repeating timer: handle:Cancel() stops it.
function Q.NewTicker(interval, fn)
	local f = CreateFrame("Frame")
	local acc = 0
	f:SetScript("OnUpdate", function(_, dt)
		acc = acc + dt
		if acc >= interval then
			acc = 0
			fn()
		end
	end)
	local handle = {}
	handle.Cancel = function()
		f:SetScript("OnUpdate", nil)
		f:Hide()
	end
	return handle
end

-- Work that must wait for the end of combat (protected frames, bindings).
local combatQueue = {}
local combatFrame = CreateFrame("Frame")
combatFrame:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_REGEN_ENABLED")
	for key, fn in pairs(combatQueue) do
		combatQueue[key] = nil
		fn()
	end
end)
function Q.AfterCombat(key, fn)
	if not InCombatLockdown() then
		fn()
		return
	end
	combatQueue[key] = fn
	combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
end

local function Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff0CD29DEllesmereUI:|r " .. msg)
end
Q.Print = Print

-- QoL module font (retail "extras").
function Q.Font()
	return (ns.GetFontPath and ns.GetFontPath("qol")) or STANDARD_TEXT_FONT
end
function Q.Outline()
	return (ns.GetFontOutlineFlag and ns.GetFontOutlineFlag("qol")) or ""
end
-- Outline forced on (retail alert texts add OUTLINE when the font has none).
function Q.OutlineForced()
	local o = Q.Outline()
	if not o:find("OUTLINE") then
		o = (o == "") and "OUTLINE" or (o .. ", OUTLINE")
	end
	return o
end

function Q.ClassColor()
	local _, cls = UnitClass("player")
	local c = cls and RAID_CLASS_COLORS[cls]
	if c then return c.r, c.g, c.b end
	return 1, 1, 1
end

---------------------------------------------------------------------------
-- Skip Cinematics (EllesmereUIDB.skipCinematics / skipCinematicsAuto)
---------------------------------------------------------------------------
-- Escape, Space or Enter ends the cinematic or movie (and accepts the "skip?"
-- prompt when the client shows one). Auto: they end as soon as they start.
local function StopCinematicNow()
	if CinematicFrame and CinematicFrame:IsShown() then
		if CinematicFrame_CancelCinematic then
			CinematicFrame_CancelCinematic()
		elseif StopCinematic then
			StopCinematic()
		end
	end
end

local function StopMovieNow()
	if MovieFrame and MovieFrame:IsShown() and MovieFrame_OnMovieFinished then
		MovieFrame_OnMovieFinished(MovieFrame)
	end
end

local SKIP_KEYS = { ESCAPE = true, SPACE = true, ENTER = true }
local cinematicHooked = false

local function HookCinematics()
	if cinematicHooked then
		return
	end
	cinematicHooked = true
	if CinematicFrame and CinematicFrame.HookScript then
		CinematicFrame:HookScript("OnKeyUp", function(_, key)
			if not Q.On("skipCinematics") or not SKIP_KEYS[key] then
				return
			end
			local confirm = _G.CinematicFrameCloseDialogConfirmButton
			if confirm and confirm:IsVisible() then
				confirm:Click()
			else
				StopCinematicNow()
			end
		end)
	end
	if MovieFrame and MovieFrame.HookScript then
		MovieFrame:HookScript("OnKeyUp", function(_, key)
			if not Q.On("skipCinematics") or not SKIP_KEYS[key] then
				return
			end
			local dialog = MovieFrame.CloseDialog
			if dialog and dialog.ConfirmButton and dialog:IsShown() then
				dialog.ConfirmButton:Click()
			else
				StopMovieNow()
			end
		end)
		-- Movies have no event of their own here: watch the Blizzard frame (like DBM).
		MovieFrame:HookScript("OnEvent", function(_, event)
			if event == "PLAY_MOVIE" and Q.On("skipCinematics") and Q.On("skipCinematicsAuto") then
				StopMovieNow()
			end
		end)
	end
end

---------------------------------------------------------------------------
-- Auto Select Single Gossip (EllesmereUIDB.autoGossip + cog keys)
---------------------------------------------------------------------------
-- GetGossipActiveQuests: title, level, isLowLevel, isComplete, isLegendary (5 per quest)
local function GossipActiveComplete(index)
	return select((index - 1) * 5 + 4, GetGossipActiveQuests()) and true or false
end
-- GetGossipAvailableQuests: title, level, isLowLevel, isDaily, isRepeatable, isLegendary (6 per quest)
local function GossipAvailableTrivial(index)
	return select((index - 1) * 6 + 3, GetGossipAvailableQuests()) and true or false
end

-- Each page + option is picked once per conversation, so two single-option
-- pages that lead to each other cannot flip back and forth.
local picked = {}

-- Never picks the option while the NPC has a quest that Quest Tracker would
-- accept or turn in, so both addons can handle GOSSIP_SHOW in any order.
local function AutoGossip()
	if not Q.On("autoGossip") then
		return
	end
	if Q.On("autoGossipShiftSkip") and IsShiftKeyDown() then
		return
	end
	if Q.On("autoGossipDisableInstance") and IsInInstance() then
		return
	end
	if GetNumGossipOptions() ~= 1 then
		return
	end
	local optionText = GetGossipOptions()
	local key = (GetGossipText() or "") .. "\0" .. tostring(optionText)
	if picked[key] then
		return
	end
	-- Low level quests only count as "ignorable" if Auto Accept also ignores them.
	local quest = ns.GetQuestTrackerDB and ns.GetQuestTrackerDB()
	local ignoreTrivial = Q.On("autoGossipIgnoreTrivial")
		and not (quest and quest.autoAccept and not quest.autoAcceptIgnoreTrivial)
	for index = 1, GetNumGossipAvailableQuests() do
		if not (ignoreTrivial and GossipAvailableTrivial(index)) then
			return
		end
	end
	for index = 1, GetNumGossipActiveQuests() do
		if GossipActiveComplete(index) then
			return
		end
	end
	picked[key] = true
	SelectGossipOption(1)
end

---------------------------------------------------------------------------
-- Hide Blizzard Party Panel (EllesmereUIDB.hideBlizzardPartyFrame)
---------------------------------------------------------------------------
-- The collapsed raid manager on the left edge (CompactRaidFrameManager).
-- While Raid Frames is loaded the toggle sits on its page (same as retail);
-- this code does the hiding either way (Raid Frames leaves the panel alone).
local partyHooked = false
local function PartyPanelOwned()
	return false
end
function Q.ApplyPartyPanel()
	local m = _G.CompactRaidFrameManager
	if not m or PartyPanelOwned() then
		return
	end
	if not partyHooked then
		partyHooked = true
		m:HookScript("OnShow", function(self)
			if Q.On("hideBlizzardPartyFrame") and not PartyPanelOwned() then
				Q.AfterCombat("partyPanel", function() self:Hide() end)
			end
		end)
	end
	Q.AfterCombat("partyPanel", function()
		if Q.On("hideBlizzardPartyFrame") then
			m:Hide()
		elseif CompactRaidFrameManager_UpdateShown then
			CompactRaidFrameManager_UpdateShown(m)
		end
	end)
end
EllesmereUI._applyHideBlizzardPartyFrame = function() Q.ApplyPartyPanel() end

---------------------------------------------------------------------------
-- Quick Loot (EllesmereUIDB.quickLoot): every slot is looted as the window
-- opens; hold Shift to see the window. (5.4.8 has LOOT_OPENED, no LOOT_READY.)
---------------------------------------------------------------------------
local lootFrame
function Q.ApplyQuickLoot()
	if Q.On("quickLoot") then
		if not lootFrame then
			lootFrame = CreateFrame("Frame")
			lootFrame:SetScript("OnEvent", function()
				if IsShiftKeyDown() then return end
				for i = GetNumLootItems(), 1, -1 do
					LootSlot(i)
				end
			end)
		end
		lootFrame:RegisterEvent("LOOT_OPENED")
	elseif lootFrame then
		lootFrame:UnregisterEvent("LOOT_OPENED")
	end
end

---------------------------------------------------------------------------
-- Auto-Fill Delete Confirmation (EllesmereUIDB.autoFillDelete)
---------------------------------------------------------------------------
local function HookDeletePopups()
	for i = 1, 4 do
		local popup = _G["StaticPopup" .. i]
		if popup then
			popup:HookScript("OnShow", function(self)
				if self.which ~= "DELETE_GOOD_ITEM" and self.which ~= "DELETE_GOOD_QUEST_ITEM" then return end
				if not Q.On("autoFillDelete") then return end
				local editBox = self.editBox or _G[self:GetName() .. "EditBox"]
				if not editBox or not DELETE_ITEM_CONFIRM_STRING then return end
				editBox:SetText(DELETE_ITEM_CONFIRM_STRING)
				editBox:SetFocus()
			end)
		end
	end
end

---------------------------------------------------------------------------
-- Auto Repair + Auto Sell Junk (autoRepair, autoRepairGuild, repairCoinIcons, autoSellJunk)
---------------------------------------------------------------------------
-- Coin icons (cog option) or the short "12g 34s" text.
local function RepairCostString(cost)
	if Q.On("repairCoinIcons") and GetCoinTextureString then
		return GetCoinTextureString(cost)
	end
	local g = floor(cost / 10000)
	local s = floor((cost % 10000) / 100)
	local c = cost % 100
	local out = ""
	if g > 0 then out = g .. "g" end
	if s > 0 then out = out .. (out ~= "" and " " or "") .. s .. "s" end
	if c > 0 then out = out .. (out ~= "" and " " or "") .. c .. "c" end
	if out == "" then out = "0c" end
	return out
end

local merchantOpen = false

-- Gray items with a sell price, in bag order.
local function JunkSlots()
	local list = {}
	for bag = 0, 4 do
		for slot = 1, GetContainerNumSlots(bag) do
			local _, _, locked, quality, _, _, link = GetContainerItemInfo(bag, slot)
			if link and quality == 0 and not locked then
				local price = select(11, GetItemInfo(link))
				if price and price > 0 then
					list[#list + 1] = { bag, slot }
				end
			end
		end
	end
	return list
end

-- Sells in small batches: the server drops fast sell requests, so the
-- sweep runs again while the count keeps falling.
local function SellJunk(pass, lastCount)
	if not merchantOpen then return end
	local list = JunkSlots()
	if #list == 0 then return end
	if pass > 1 and #list >= lastCount then
		Print(("%d junk item(s) could not be sold."):format(#list))
		return
	end
	for i = 1, math.min(#list, 12) do
		UseContainerItem(list[i][1], list[i][2])
	end
	Q.After(0.4, function() SellJunk(pass + 1, #list) end)
end

local function AutoRepair()
	if not Q.On("autoRepair") or not CanMerchantRepair() then
		return
	end
	local cost, canRepair = GetRepairAllCost()
	if not canRepair or not cost or cost <= 0 then
		return
	end
	if Q.On("autoRepairGuild") and IsInGuild() and CanGuildBankRepair() then
		local allowance = GetGuildBankWithdrawMoney()
		if allowance == -1 or (allowance and allowance >= cost) then
			RepairAllItems(1)
			Print(("Repaired all items for %s"):format(RepairCostString(cost)) .. " (guild bank)")
			return
		end
	end
	if GetMoney() >= cost then
		RepairAllItems()
		Print(("Repaired all items for %s"):format(RepairCostString(cost)))
	else
		Print("|cffff6060Not enough gold to repair.|r")
	end
end

local merchantFrame = CreateFrame("Frame")
merchantFrame:RegisterEvent("MERCHANT_SHOW")
merchantFrame:RegisterEvent("MERCHANT_CLOSED")
merchantFrame:SetScript("OnEvent", function(_, event)
	if event == "MERCHANT_CLOSED" then
		merchantOpen = false
		return
	end
	merchantOpen = true
	AutoRepair()
	if Q.On("autoSellJunk") then
		-- After the repair debit, like retail.
		Q.After(0.3, function() SellJunk(1, 0) end)
	end
end)

---------------------------------------------------------------------------
-- Show Coordinates on Map (mapCoords, mapCoordsTextSize)
---------------------------------------------------------------------------
-- "C: x, y | P: x, y" under the world map (5.4.8 map: WorldMapButton).
local coordFrame, coordCursor, coordPlayer, coordDivider
local function CreateCoordFrame()
	if coordFrame or not WorldMapButton then return end
	coordFrame = CreateFrame("Frame", nil, WorldMapButton)
	coordFrame:SetFrameStrata("HIGH")
	coordFrame:SetSize(1, 1)
	coordFrame:SetPoint("BOTTOM", WorldMapButton, "BOTTOM", 0, 10)
	coordDivider = coordFrame:CreateTexture(nil, "OVERLAY")
	coordDivider:SetTexture(1, 1, 1, 0.9)
	coordDivider:SetPoint("BOTTOM", coordFrame, "BOTTOM", 0, 0)
	coordCursor = coordFrame:CreateFontString(nil, "OVERLAY")
	coordCursor:SetFont(Q.Font(), 12, Q.Outline())
	coordCursor:SetTextColor(1, 1, 1, 0.9)
	coordCursor:SetJustifyH("RIGHT")
	coordCursor:SetPoint("RIGHT", coordDivider, "LEFT", -10, 0)
	coordPlayer = coordFrame:CreateFontString(nil, "OVERLAY")
	coordPlayer:SetFont(Q.Font(), 12, Q.Outline())
	coordPlayer:SetTextColor(1, 1, 1, 0.9)
	coordPlayer:SetJustifyH("LEFT")
	coordPlayer:SetPoint("LEFT", coordDivider, "RIGHT", 10, 0)
	local elapsed = 0
	coordFrame:SetScript("OnUpdate", function(_, dt)
		elapsed = elapsed + dt
		if elapsed < 0.05 then return end
		elapsed = 0
		local px, py = GetPlayerMapPosition("player")
		if px and py and px > 0 and py > 0 then
			coordPlayer:SetText(("P: %.0f, %.0f"):format(px * 100, py * 100))
			coordPlayer:Show()
			coordDivider:Show()
		else
			coordPlayer:Hide()
			coordDivider:Hide()
		end
		local text = "0, 0"
		local map = WorldMapButton
		if map:IsMouseOver() then
			local w, h = map:GetWidth(), map:GetHeight()
			local left, top = map:GetLeft(), map:GetTop()
			local scale = map:GetEffectiveScale()
			if w and w > 0 and h and h > 0 and left and top and scale then
				local cx, cy = GetCursorPosition()
				local nx = (cx / scale - left) / w
				local ny = (top - cy / scale) / h
				if nx >= 0 and nx <= 1 and ny >= 0 and ny <= 1 then
					text = ("%.0f, %.0f"):format(nx * 100, ny * 100)
				end
			end
		end
		coordCursor:SetText("C: " .. text)
	end)
end
function Q.ApplyMapCoords()
	if Q.On("mapCoords") then
		CreateCoordFrame()
		if coordFrame then
			local sz = R().mapCoordsTextSize or 12
			coordCursor:SetFont(Q.Font(), sz, Q.Outline())
			coordPlayer:SetFont(Q.Font(), sz, Q.Outline())
			coordDivider:SetSize(2, sz)
			coordFrame:Show()
		end
	elseif coordFrame then
		coordFrame:Hide()
	end
end

---------------------------------------------------------------------------
-- Suppress Lua Errors (suppressErrors; same key and CVar as Global Settings)
---------------------------------------------------------------------------
function Q.ApplySuppressErrors()
	if ns.SetCVarSafe then
		ns.SetCVarSafe("scriptErrors", Q.On("suppressErrors") and "0" or "1")
	end
end

---------------------------------------------------------------------------
-- Hide Error Messages (hideErrorMessages)
---------------------------------------------------------------------------
-- UIErrorsFrame stops listening to UI_ERROR_MESSAGE; this frame passes the
-- useful ones (full bags, quest log, dead pet, ...) on to it.
local errorFrame, errorKeep
local function BuildKeepList()
	if errorKeep then return end
	errorKeep = {}
	for _, name in ipairs({
		"ERR_INV_FULL", "ERR_QUEST_LOG_FULL", "ERR_RAID_GROUP_ONLY",
		"ERR_PARTY_LFG_BOOT_LIMIT", "ERR_PARTY_LFG_BOOT_DUNGEON_COMPLETE",
		"ERR_PARTY_LFG_BOOT_IN_COMBAT", "ERR_PARTY_LFG_BOOT_IN_PROGRESS",
		"ERR_PARTY_LFG_BOOT_LOOT_ROLLS", "ERR_PARTY_LFG_TELEPORT_IN_COMBAT",
		"ERR_PET_SPELL_DEAD", "ERR_PLAYER_DEAD",
		"SPELL_FAILED_TARGET_NO_POCKETS", "ERR_ALREADY_PICKPOCKETED",
	}) do
		local msg = _G[name]
		if msg then errorKeep[msg] = true end
	end
end
local function IsBootNotEligible(msg)
	if type(msg) ~= "string" or not ERR_PARTY_LFG_BOOT_NOT_ELIGIBLE_S then return false end
	local ok, found = pcall(string.find, msg, ERR_PARTY_LFG_BOOT_NOT_ELIGIBLE_S:gsub("%%s", ".+"))
	return ok and found and true or false
end
function Q.ApplyHideErrors()
	if not UIErrorsFrame then return end
	if Q.On("hideErrorMessages") then
		BuildKeepList()
		if not errorFrame then
			errorFrame = CreateFrame("Frame")
			errorFrame:SetScript("OnEvent", function(_, _, msg)
				if errorKeep[msg] or IsBootNotEligible(msg) then
					UIErrorsFrame:AddMessage(msg, 1.0, 0.1, 0.1, 1.0)
				end
			end)
		end
		UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")
		errorFrame:RegisterEvent("UI_ERROR_MESSAGE")
	elseif errorFrame then
		errorFrame:UnregisterEvent("UI_ERROR_MESSAGE")
		UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
	end
end

---------------------------------------------------------------------------
-- Hide Tutorial Pop-ups (hideTutorials)
---------------------------------------------------------------------------
-- 5.4.8: the tutorial CVar, the TutorialFrame popups and the (i) help-plate
-- buttons (MainHelpButton) of the Blizzard panels.
local tutorialHooked, tutorialCVarSet = false, false
local hiddenHelp = {}
local function HideHelpButtons(frame)
	if type(frame) ~= "table" or not frame.GetName then return end
	local btn = frame.MainHelpButton or (frame:GetName() and _G[frame:GetName() .. "MainHelpButton"])
	if btn and btn.SetAlpha then
		btn:SetAlpha(0)
		btn:EnableMouse(false)
		hiddenHelp[btn] = true
	end
end
function Q.ApplyHideTutorials()
	if Q.On("hideTutorials") then
		if not tutorialHooked then
			tutorialHooked = true
			hooksecurefunc("ShowUIPanel", function(frame)
				if Q.On("hideTutorials") then HideHelpButtons(frame) end
			end)
			if TutorialFrame_NewTutorial then
				hooksecurefunc("TutorialFrame_NewTutorial", function()
					if Q.On("hideTutorials") and TutorialFrame then TutorialFrame:Hide() end
				end)
			end
			if HelpPlate_Show and HelpPlate_Hide then
				hooksecurefunc("HelpPlate_Show", function()
					if Q.On("hideTutorials") then HelpPlate_Hide() end
				end)
			end
		end
		if ns.SetCVarSafe then ns.SetCVarSafe("showTutorials", "0") end
		tutorialCVarSet = true
		if TutorialFrame and TutorialFrame:IsShown() then TutorialFrame:Hide() end
	else
		if tutorialCVarSet and ns.SetCVarSafe then
			ns.SetCVarSafe("showTutorials", "1")
			tutorialCVarSet = false
		end
		for btn in pairs(hiddenHelp) do
			btn:SetAlpha(1)
			btn:EnableMouse(true)
			hiddenHelp[btn] = nil
		end
	end
end

---------------------------------------------------------------------------
-- Hide Loot Rolls Window (hideLootHistory, lootHistoryMode, lootHistoryDelay)
---------------------------------------------------------------------------
-- 5.4.8: the Loot History window (LootHistoryFrame).
local lootHistHooked, closeGen = false, 0
local function EnforceLootHistory()
	local f = _G.LootHistoryFrame
	if not f or not Q.On("hideLootHistory") then return end
	closeGen = closeGen + 1
	if R().lootHistoryMode ~= "autoclose" then
		f:Hide()
		return
	end
	local gen = closeGen
	local delay = R().lootHistoryDelay
	if type(delay) ~= "number" or delay <= 0 then delay = 5 end
	Q.After(delay, function()
		if gen ~= closeGen or not Q.On("hideLootHistory") then return end
		if f:IsShown() then f:Hide() end
	end)
end
function Q.ApplyHideLootHistory()
	local f = _G.LootHistoryFrame
	if f and not lootHistHooked and Q.On("hideLootHistory") then
		lootHistHooked = true
		f:HookScript("OnShow", EnforceLootHistory)
	end
	closeGen = closeGen + 1
	if f and f:IsShown() then EnforceLootHistory() end
end

---------------------------------------------------------------------------
-- Announce Instance Reset (instanceResetAnnounce, instanceResetAnnounceMsg)
---------------------------------------------------------------------------
local RESET_PATTERNS = {
	"has been reset", "wurde zur", "a été réinitialisé", "ha sido reiniciada",
	"è stato resettato", "foi reiniciada", "сброшен", "已重置", "초기화되었습니다",
}
local FAIL_PATTERNS = {
	"players still", "noch spieler", "joueurs sont encore", "jugadores todavía",
	"giocatori sono ancora", "jogadores ainda", "игроки ещё", "还有玩家", "아직 플레이어",
}
local function MatchesAny(msg, patterns)
	if type(msg) ~= "string" then return false end
	local lower = msg:lower()
	for _, pat in ipairs(patterns) do
		if lower:find(pat:lower(), 1, true) then return true end
	end
	return false
end
local resetPending, resetFailPending = false, false
local resetFrame = CreateFrame("Frame")
resetFrame:SetScript("OnEvent", function(_, _, msg)
	if not Q.On("instanceResetAnnounce") then return end
	if not (IsInGroup() or (LE_PARTY_CATEGORY_INSTANCE and IsInGroup(LE_PARTY_CATEGORY_INSTANCE))) then return end
	local success = MatchesAny(msg, RESET_PATTERNS) or (not IsInRaid() and MatchesAny(msg, FAIL_PATTERNS))
	if success then
		if resetPending then return end
		resetPending = true
		Q.After(0.3, function()
			resetPending = false
			local text = R().instanceResetAnnounceMsg
			if type(text) ~= "string" or text == "" then
				text = "Instance has been reset - you can re-enter now!"
			end
			SendChatMessage("[EUI] " .. text, IsInRaid() and "RAID" or "PARTY")
		end)
	elseif MatchesAny(msg, FAIL_PATTERNS) then
		if resetFailPending then return end
		resetFailPending = true
		Q.After(0.3, function()
			resetFailPending = false
			SendChatMessage("[EUI] Reset failed - there are still players inside the instance.", IsInRaid() and "RAID" or "PARTY")
		end)
	end
end)
function Q.ApplyInstanceReset()
	if Q.On("instanceResetAnnounce") then
		resetFrame:RegisterEvent("CHAT_MSG_SYSTEM")
	else
		resetFrame:UnregisterEvent("CHAT_MSG_SYSTEM")
	end
end

---------------------------------------------------------------------------
-- Hide Screenshot Status (hideScreenshotStatus, default on)
---------------------------------------------------------------------------
local ssFrame = CreateFrame("Frame")
ssFrame:RegisterEvent("SCREENSHOT_SUCCEEDED")
ssFrame:RegisterEvent("SCREENSHOT_FAILED")
ssFrame:SetScript("OnEvent", function()
	if Q.On("hideScreenshotStatus") then
		Q.After(0, function()
			if _G.ActionStatus then _G.ActionStatus:Hide() end
		end)
	end
end)

---------------------------------------------------------------------------
-- Train All Button (trainAllButton)
---------------------------------------------------------------------------
local trainBtn, trainHooked
-- 5.4.8 API; the fallbacks only keep test harnesses without them quiet.
local GetProfessions = GetProfessions or function() return nil end
local GetNumTrainerServices = GetNumTrainerServices or function() return 0 end
local function FreeProfessionSlots()
	local a, b = GetProfessions()
	return 2 - (a and 1 or 0) - (b and 1 or 0)
end
-- 5.4.8: GetTrainerServiceInfo -> name, subText, type; GetTrainerServiceCost -> money, talent, profession.
local function SkillIsAffordable(i, wallet, freeSlots)
	local kind = select(3, GetTrainerServiceInfo(i))
	if kind ~= "available" then return false, 0, false end
	local cost, _, profCost = GetTrainerServiceCost(i)
	cost = cost or 0
	local takesSlot = (profCost or 0) > 0
	if cost > wallet then return false, 0, false end
	if takesSlot and freeSlots <= 0 then return false, 0, false end
	return true, cost, takesSlot
end
local function TrainableSummary()
	local n, gold = 0, 0
	local wallet, slots = GetMoney(), FreeProfessionSlots()
	for i = 1, GetNumTrainerServices() do
		local ok, cost = SkillIsAffordable(i, wallet, slots)
		if ok then n = n + 1; gold = gold + cost end
	end
	return n, gold
end
local function RefreshTrainButton()
	if not trainBtn then return end
	if not Q.On("trainAllButton") then
		trainBtn:Hide()
		return
	end
	trainBtn:SetEnabled(TrainableSummary() > 0)
	trainBtn:Show()
end
function Q.ApplyTrainAll()
	if not Q.On("trainAllButton") then
		if trainBtn then trainBtn:Hide() end
		return
	end
	if not ClassTrainerFrame or not ClassTrainerTrainButton then return end
	if not trainBtn then
		trainBtn = CreateFrame("Button", "EUI_TrainAllButton", ClassTrainerFrame, "UIPanelButtonTemplate")
		trainBtn:SetText("Train All")
		trainBtn:SetHeight(ClassTrainerTrainButton:GetHeight() or 22)
		trainBtn:SetWidth(80)
		trainBtn:SetPoint("RIGHT", ClassTrainerTrainButton, "LEFT", -2, 0)
		trainBtn:SetScript("OnClick", function()
			local wallet, slots = GetMoney(), FreeProfessionSlots()
			for i = GetNumTrainerServices(), 1, -1 do
				local ok, cost, takesSlot = SkillIsAffordable(i, wallet, slots)
				if ok then
					BuyTrainerService(i)
					wallet = wallet - cost
					if takesSlot then slots = slots - 1 end
				end
			end
		end)
		trainBtn:SetScript("OnEnter", function(self)
			local n, gold = TrainableSummary()
			if n <= 0 then return end
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(("Learn %d skill%s for %s"):format(n, n == 1 and "" or "s", GetCoinTextureString(gold)), 1, 1, 1)
			GameTooltip:Show()
		end)
		trainBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end
	if not trainHooked and ClassTrainerFrame_Update then
		trainHooked = true
		hooksecurefunc("ClassTrainerFrame_Update", RefreshTrainButton)
	end
	RefreshTrainButton()
end

---------------------------------------------------------------------------
-- Auto Open Containers (autoOpenContainers)
---------------------------------------------------------------------------
-- Opens lootable bag items (boxes, bags of loot) one at a time. Waits while
-- a vendor (a click would sell), the mailbox (until it closes), the loot
-- window or combat is open. 5.4.8 has no warbound items or payouts, so the
-- two retail cog rows do not exist.
local openFrame = CreateFrame("Frame")
local openBusy, mailOpen, lootOpen = false, false, false
local function OpenBlocked()
	return merchantOpen or mailOpen or lootOpen or InCombatLockdown()
		or (BankFrame and BankFrame:IsShown())
end
local function OpenNext()
	openBusy = false
	if not Q.On("autoOpenContainers") or OpenBlocked() then return end
	for bag = 0, 4 do
		for slot = 1, GetContainerNumSlots(bag) do
			local _, _, locked, _, _, lootable, link = GetContainerItemInfo(bag, slot)
			if link and lootable and not locked then
				UseContainerItem(bag, slot)
				openBusy = true
				-- Next one after the loot window of this one is handled.
				Q.After(1, OpenNext)
				return
			end
		end
	end
end
local function ScheduleOpen()
	if openBusy then return end
	openBusy = true
	Q.After(0.3, OpenNext)
end
openFrame:SetScript("OnEvent", function(_, event)
	if event == "MAIL_SHOW" then
		mailOpen = true
	elseif event == "MAIL_CLOSED" then
		mailOpen = false
	elseif event == "LOOT_OPENED" then
		lootOpen = true
		return
	elseif event == "LOOT_CLOSED" then
		lootOpen = false
	elseif event == "MERCHANT_SHOW" then
		return
	end
	ScheduleOpen()
end)
function Q.ApplyAutoOpen()
	if Q.On("autoOpenContainers") then
		for _, e in ipairs({ "BAG_UPDATE_DELAYED", "MAIL_SHOW", "MAIL_CLOSED", "LOOT_OPENED",
			"LOOT_CLOSED", "MERCHANT_CLOSED", "PLAYER_REGEN_ENABLED", "BANKFRAME_CLOSED" }) do
			openFrame:RegisterEvent(e)
		end
		ScheduleOpen()
	else
		openFrame:UnregisterAllEvents()
	end
end

---------------------------------------------------------------------------
-- Bonus Roll Confirmation (bonusRollConfirmation, bonusRollOnly)
---------------------------------------------------------------------------
-- Click-catching buttons over the Roll (and Pass) buttons of the bonus roll
-- prompt ask first and show the loot specialization.
local rollOverlay, passOverlay, rollHooked
local function BonusEnabled()
	return Q.On("bonusRollConfirmation") and not IsAddOnLoaded("BonusRollConfirm")
end
local function LootSpecName()
	local id = GetLootSpecialization()
	if not id or id == 0 then
		local index = GetSpecialization()
		id = index and GetSpecializationInfo(index)
	end
	local name = id and select(2, GetSpecializationInfoByID(id))
	return name or UNKNOWN or "Unknown"
end
local function SyncBonusOverlays()
	if not rollOverlay then return end
	local frame = BonusRollFrame
	local show = BonusEnabled() and frame and frame:IsShown() and true or false
	rollOverlay:SetShown(show)
	passOverlay:SetShown(show and not Q.On("bonusRollOnly"))
end
StaticPopupDialogs["EUI_QOL_BONUSROLL"] = {
	text = "%s",
	button1 = YES,
	button2 = CANCEL,
	OnAccept = function(_, data)
		if data and data.button and data.button:IsShown() and data.button:IsEnabled() then
			data.button:Click()
		end
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}
local function MakeBonusOverlay(button, isRoll)
	local overlay = CreateFrame("Button", nil, button)
	overlay:SetAllPoints(button)
	overlay:SetFrameLevel(button:GetFrameLevel() + 2)
	overlay:RegisterForClicks("LeftButtonUp")
	overlay:SetScript("OnClick", function()
		local text = isRoll and ("Use a bonus roll?\n\nLoot specialization: %s"):format(LootSpecName())
			or "Pass on this bonus roll?"
		local dialog = StaticPopup_Show("EUI_QOL_BONUSROLL", text)
		if dialog then dialog.data = { button = button } end
	end)
	overlay:Hide()
	return overlay
end
function Q.ApplyBonusRoll()
	local prompt = type(BonusRollFrame) == "table" and BonusRollFrame.PromptFrame
	if type(prompt) ~= "table" then prompt = nil end
	local roll, pass = prompt and prompt.RollButton, prompt and prompt.PassButton
	if type(roll) ~= "table" or type(pass) ~= "table" then roll, pass = nil, nil end
	if BonusEnabled() and roll and pass and not rollOverlay
		and not roll:IsProtected() and not pass:IsProtected() then
		rollOverlay = MakeBonusOverlay(roll, true)
		passOverlay = MakeBonusOverlay(pass, false)
	end
	if rollOverlay and not rollHooked then
		rollHooked = true
		BonusRollFrame:HookScript("OnShow", SyncBonusOverlays)
		BonusRollFrame:HookScript("OnHide", SyncBonusOverlays)
	end
	SyncBonusOverlays()
end

---------------------------------------------------------------------------
-- First login: the retail settings of the user (retail_sv, profile "Naowh")
---------------------------------------------------------------------------
-- Only values that differ from the retail defaults. Marker: EllesmereUIQoLDB._seeded.
local SEED_ROOT = {
	hideErrorMessages = true,
	mapCoords = true,
	quickLoot = true,
	hideTutorials = true,
	combatAlertPos = { point = "CENTER", relPoint = "CENTER", x = 0, y = -90 },
	groupDeathAlertPos = { point = "CENTER", relPoint = "CENTER", x = 0, y = 326 },
}
local SEED_PROFILE = {
	fpsShowLocalMS = true,
	fpsTextSize = 13,
	fpsHideLabel = true,
	fpsColor = { r = 1, g = 1, b = 1, a = 1 },
	fpsPos = { point = "CENTER", relPoint = "CENTER", x = 0, y = 680 },
	showFPS = false,
	fpsUpdateInterval = 2,
	fpsShowWorldMS = false,
	showSecondaryStats = false,
	secondaryStatsHidden = { speed = true, avoidance = true, leech = true },
	secondaryStatsPos = { point = "TOPLEFT", relPoint = "BOTTOMLEFT", x = 511, y = 78 },
}
local function DeepCopy(v)
	if type(v) ~= "table" then return v end
	local t = {}
	for k, x in pairs(v) do t[k] = DeepCopy(x) end
	return t
end
Q.DeepCopy = DeepCopy

-- Before this version Skip Cinematics / Auto Gossip were saved in
-- EllesmereUIQoLDB; retail keeps them on EllesmereUIDB.
local MOVED = {
	"skipCinematics", "skipCinematicsAuto", "autoGossip", "autoGossipShiftSkip",
	"autoGossipDisableInstance", "autoGossipIgnoreTrivial",
}

local function InitDB()
	-- Before 3.1 the settings were EllesmereUIDB.qol.
	qol = ns.ModuleDB("EllesmereUIQoLDB", "qol")
	local root = R()
	for _, key in ipairs(MOVED) do
		if qol[key] ~= nil then
			if root[key] == nil then root[key] = qol[key] end
			qol[key] = nil
		end
	end
	if qol._seeded ~= 1 then
		qol._seeded = 1
		for k, v in pairs(SEED_ROOT) do
			if root[k] == nil then root[k] = DeepCopy(v) end
		end
		for k, v in pairs(SEED_PROFILE) do
			if qol[k] == nil then qol[k] = DeepCopy(v) end
		end
	end
end

---------------------------------------------------------------------------
-- Apply (login, settings window via ns.applyHooks)
---------------------------------------------------------------------------
Q.applies = Q.applies or {}
function Q.ApplyGeneral()
	Q.ApplyPartyPanel()
	Q.ApplyQuickLoot()
	Q.ApplyMapCoords()
	Q.ApplyHideErrors()
	Q.ApplyHideTutorials()
	Q.ApplyHideLootHistory()
	Q.ApplyInstanceReset()
	Q.ApplyTrainAll()
	Q.ApplyAutoOpen()
	Q.ApplyBonusRoll()
end

local loggedIn = false
function Q.ApplyAll()
	if not loggedIn then return end
	Q.ApplyGeneral()
	for _, fn in ipairs(Q.applies) do
		local ok, err = pcall(fn)
		if not ok and geterrorhandler then geterrorhandler()(err) end
	end
end
ns.applyHooks = ns.applyHooks or {}
tinsert(ns.applyHooks, function() Q.ApplyAll() end)

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", function(self, event, ...)
	if event == "GOSSIP_SHOW" then
		AutoGossip()
	elseif event == "GOSSIP_CLOSED" then
		wipe(picked)
	elseif event == "CINEMATIC_START" then
		if Q.On("skipCinematics") and Q.On("skipCinematicsAuto") then
			StopCinematicNow()
		end
	elseif event == "ADDON_LOADED" then
		local name = ...
		if name == addonName then
			InitDB()
		elseif name == "Blizzard_TrainerUI" then
			Q.ApplyTrainAll()
		end
	elseif event == "PLAYER_LOGIN" then
		loggedIn = true
		HookCinematics()
		HookDeletePopups()
		if R().suppressErrors ~= nil then
			Q.ApplySuppressErrors()
		end
		Q.ApplyAll()
	end
end)
frame:RegisterEvent("GOSSIP_SHOW")
frame:RegisterEvent("GOSSIP_CLOSED")
frame:RegisterEvent("CINEMATIC_START")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

---------------------------------------------------------------------------
-- Retail profile import (EllesmereUI_ProfilesRetail.lua): the core
-- converter keeps battleRes / bloodlust; this one also carries the
-- per-profile extras (FPS, secondary stats, self combat text). It wraps the
-- converter that is there, so other QoL files can wrap this one too.
---------------------------------------------------------------------------
local EXTRA_KEYS = {
	"showFPS", "fpsColor", "fpsColorMode", "fpsAttachToStats", "fpsTextSize",
	"fpsShowLocalMS", "fpsShowWorldMS", "fpsHideLabel", "fpsUpdateInterval", "fpsPos",
	"showSecondaryStats", "secondaryStatsColor", "secondaryStatsColorMode",
	"coloredPercentages", "secondaryStatsAbbreviateLabels", "showSecondaryStatsRaw",
	"showSecondaryStatsBoth", "secondaryStatsHidden", "secondaryStatsOrder",
	"secondaryStatsPos", "tertiaryStatsColor", "tertiaryStatsColorMode",
	"selfCombatText",
}
if ns.ProfileRetail and ns.ProfileRetail.CONVERT then
	local CONVERT = ns.ProfileRetail.CONVERT
	local prev = CONVERT.EllesmereUIQoL
	CONVERT.EllesmereUIQoL = function(blob, notes)
		local root = prev and prev(blob, notes)
		local any = root ~= nil
		if not root then
			root = DeepCopy(type(EllesmereUIQoLDB) == "table" and EllesmereUIQoLDB or {})
		end
		for _, k in ipairs(EXTRA_KEYS) do
			if blob[k] ~= nil then
				root[k] = DeepCopy(blob[k])
				any = true
			end
		end
		return any and root or nil
	end
end

---------------------------------------------------------------------------
-- API for the settings window
---------------------------------------------------------------------------
ns.GetQoLDB = function() return qol end

-- Retail onReset: the page keys on EllesmereUIDB back to their defaults,
-- and (like before) the whole EllesmereUIQoLDB (Battle Res / Bloodlust
-- re-seed their defaults; the first-login seed does not run again).
local RESET_ROOT = {
	"hideBlizzardPartyFrame", "quickLoot", "autoGossip", "autoGossipShiftSkip",
	"autoGossipDisableInstance", "autoGossipIgnoreTrivial", "skipCinematics",
	"skipCinematicsAuto", "autoFillDelete", "instanceResetAnnounce",
	"instanceResetAnnounceMsg", "trainAllButton",
	"autoOpenContainers", "bonusRollConfirmation", "bonusRollOnly", "hideErrorMessages",
	"hideLootHistory",
	"lootHistoryMode", "lootHistoryDelay", "announceGroupDeaths", "groupDeathTextSize",
	"groupDeathAlertPos", "groupDeathSound", "groupDeathSoundKey", "combatAlertEnabled",
	"combatAlertMode", "combatAlertTextSize", "combatAlertPos", "combatAlertEnterText",
	"combatAlertLeaveText", "combatAlertEnterColor", "combatAlertLeaveColor",
	"combatAlertEnterUseClassColor", "combatAlertLeaveUseClassColor",
	"targetDistanceEnabled", "targetDistanceFormat", "targetDistanceAlign",
	"targetDistanceTextSize", "targetDistancePos", "targetDistanceStrata",
	"hideTransforms", "hideTransformItems",
}
ns.ResetQoLSettings = function()
	local root = R()
	for _, k in ipairs(RESET_ROOT) do
		root[k] = nil
	end
	-- Retail writes these two off (their never-written default is on).
	root.hideScreenshotStatus = false
	root.autoRepairGuild = false
	if type(root.unlockAnchors) == "table" then
		root.unlockAnchors.EUI_TargetDistance = nil
	end
	-- The Macro Factory choices are kept (retail keeps them on reset too).
	for k in pairs(qol) do
		if k ~= "_seeded" and k ~= "macroFactory" then qol[k] = nil end
	end
end
