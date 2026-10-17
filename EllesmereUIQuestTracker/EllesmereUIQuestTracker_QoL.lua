-------------------------------------------------------------------------------
-- EllesmereUIQuestTracker_QoL.lua (5.4.8 port)
--
-- Retail QoL layer: Auto Accept Quests, Auto Turn In Quests (the 5.4.8 gossip /
-- quest frame parts come from QuickQuest) and the Quest Item Hotkey.
-- Skipped: Ignore Older Expansion Quests (no expansion data on 5.4.8 quests)
-- and the SplashFrame taint fix (retail only frame).
-------------------------------------------------------------------------------
local addonName, P = ...
local EQT = P.EQT

local select = select

local function Cfg(k) return EQT.Cfg(k) end

---------------------------------------------------------------------------
-- 5.4.8 gossip API (return strides from QuickQuest)
---------------------------------------------------------------------------
-- GetGossipActiveQuests: title, level, isLowLevel, isComplete, isLegendary (5 per quest)
local function GossipActiveComplete(index)
	return select((index - 1) * 5 + 4, GetGossipActiveQuests()) and true or false
end

-- GetGossipAvailableQuests: title, level, isLowLevel, isDaily, isRepeatable, isLegendary (6 per quest)
local function GossipAvailableTrivial(index)
	return select((index - 1) * 6 + 3, GetGossipAvailableQuests()) and true or false
end

local function GreetingAvailableTrivial(index)
	if GetAvailableQuestInfo then
		return GetAvailableQuestInfo(index) and true or false
	elseif IsAvailableQuestTrivial then
		return IsAvailableQuestTrivial(index) and true or false
	end
	return false
end

---------------------------------------------------------------------------
-- Auto Accept Quests / Auto Turn In Quests
---------------------------------------------------------------------------
-- Prevent Multi Quest Accept: an NPC that once offered more than one quest is
-- left to the player for the rest of the session.
local preventNPC = {}

local function AcceptSkipped()
	return Cfg("autoAcceptShiftSkip") and IsShiftKeyDown()
end

local function TurnInSkipped()
	return Cfg("autoTurnInShiftSkip") and IsShiftKeyDown()
end

-- Picks one available quest; count and isTrivial(index) come from the gossip or greeting API.
-- Ignore Older Expansion Quests (retail autoAcceptIgnoreOldExpansion): at max
-- level, quests below Pandaria level (86) are older content. Leveling runs
-- through older content, so the toggle waits for max level.
local OLD_EXPANSION_LEVEL = 86
local function OldExpansion(level)
	if not Cfg("autoAcceptIgnoreOldExpansion") or not level or level <= 0 then return false end
	if UnitLevel("player") < (GetMaxPlayerLevel and GetMaxPlayerLevel() or 90) then return false end
	return level < OLD_EXPANSION_LEVEL
end

local function PickAvailable(count, isTrivial, selectFunc, levelOf)
	if not Cfg("autoAccept") or count == 0 or AcceptSkipped() then
		return false
	end
	local list = {}
	for index = 1, count do
		if not (Cfg("autoAcceptIgnoreTrivial") and isTrivial(index)) and not OldExpansion(levelOf and levelOf(index)) then
			list[#list + 1] = index
		end
	end
	if #list == 0 then
		return false
	end
	if Cfg("autoAcceptPreventMulti") then
		local npc = UnitGUID("npc")
		if #list > 1 and npc then
			preventNPC[npc] = true
		end
		if npc and preventNPC[npc] then
			return false
		end
	end
	selectFunc(list[1])
	return true
end

-- The single gossip option (EllesmereUIQoL) is never picked while a quest
-- here could be, see AutoGossip there.
local function QuestGossipShow()
	if Cfg("autoTurnIn") and not TurnInSkipped() then
		for index = 1, GetNumGossipActiveQuests() do
			if GossipActiveComplete(index) then
				SelectGossipActiveQuest(index)
				return true
			end
		end
	end
	return PickAvailable(GetNumGossipAvailableQuests(), GossipAvailableTrivial, SelectGossipAvailableQuest,
		function(index) return tonumber((select((index - 1) * 6 + 2, GetGossipAvailableQuests()))) end)
end

-- 5.4.8 shows NPCs with several quests in the quest frame greeting panel.
local function OnQuestGreeting()
	if Cfg("autoTurnIn") and not TurnInSkipped() then
		for index = 1, GetNumActiveQuests() do
			local _, isComplete = GetActiveTitle(index)
			if isComplete then
				SelectActiveQuest(index)
				return
			end
		end
	end
	PickAvailable(GetNumAvailableQuests(), GreetingAvailableTrivial, SelectAvailableQuest,
		function(index) return GetAvailableLevel and GetAvailableLevel(index) end)
end

local function OnQuestDetail()
	if not Cfg("autoAccept") or AcceptSkipped() then
		return
	end
	if QuestGetAutoAccept and QuestGetAutoAccept() then
		-- The game accepts it by itself; QUEST_ACCEPTED closes the frame.
		return
	end
	AcceptQuest()
end

local function OnQuestAccepted()
	if Cfg("autoAccept") and QuestFrame and QuestFrame:IsShown() and QuestGetAutoAccept and QuestGetAutoAccept() then
		CloseQuest()
	end
end

-- Escort / shared quest started by another player.
local function OnQuestAcceptConfirm()
	if not Cfg("autoAccept") or AcceptSkipped() then
		return
	end
	if ConfirmAcceptQuest then
		ConfirmAcceptQuest()
	else
		AcceptQuest()
	end
	StaticPopup_Hide("QUEST_ACCEPT")
end

-- 5.4.8 needs this step between choosing a quest and the reward page.
-- Quests that cost money or currency are left to the player.
local function OnQuestProgress()
	if not Cfg("autoTurnIn") or TurnInSkipped() or not IsQuestCompletable() then
		return
	end
	if GetQuestMoneyToGet and (GetQuestMoneyToGet() or 0) > 0 then
		return
	end
	if GetNumQuestCurrencies and (GetNumQuestCurrencies() or 0) > 0 then
		return
	end
	CompleteQuest()
end

-- With more than one reward to choose from, the player picks.
local function OnQuestComplete()
	if not Cfg("autoTurnIn") or TurnInSkipped() then
		return
	end
	local numChoices = GetNumQuestChoices()
	if numChoices <= 1 then
		GetQuestReward(numChoices)
	end
end

local function InstallAutoQuests()
	local f = CreateFrame("Frame")
	f:SetScript("OnEvent", function(_, event)
		if event == "GOSSIP_SHOW" then
			QuestGossipShow()
		elseif event == "QUEST_GREETING" then
			OnQuestGreeting()
		elseif event == "QUEST_DETAIL" then
			OnQuestDetail()
		elseif event == "QUEST_ACCEPT_CONFIRM" then
			OnQuestAcceptConfirm()
		elseif event == "QUEST_ACCEPTED" then
			OnQuestAccepted()
		elseif event == "QUEST_PROGRESS" then
			OnQuestProgress()
		elseif event == "QUEST_COMPLETE" then
			OnQuestComplete()
		end
	end)
	f:RegisterEvent("GOSSIP_SHOW")
	f:RegisterEvent("QUEST_GREETING")
	f:RegisterEvent("QUEST_DETAIL")
	f:RegisterEvent("QUEST_ACCEPT_CONFIRM")
	f:RegisterEvent("QUEST_ACCEPTED")
	f:RegisterEvent("QUEST_PROGRESS")
	f:RegisterEvent("QUEST_COMPLETE")
end

-------------------------------------------------------------------------------
-- Quest Item Hotkey (retail): a hidden secure item button and an override
-- binding on the chosen key while a quest item exists. Override bindings never
-- touch the player's saved bindings. Binding writes are blocked in combat;
-- PLAYER_REGEN_ENABLED re-applies.
-------------------------------------------------------------------------------
-- First watched quest with a usable item, else the first one in the log.
local function ScanForQuestItem()
	local fallback = nil
	local num = GetNumQuestLogEntries() or 0
	for i = 1, num do
		local _, _, _, _, isHeader = GetQuestLogTitle(i)
		if not isHeader then
			local link = GetQuestLogSpecialItemInfo(i)
			if link then
				local name = link:match("%[(.-)%]")
				if name then
					if IsQuestWatched(i) then return name end
					fallback = fallback or name
				end
			end
		end
	end
	return fallback
end

local function InstallQuestItemHotkey()
	local btn = CreateFrame("Button", "EUI_QuestItemHotkeyBtn", UIParent, "SecureActionButtonTemplate")
	btn:SetSize(32, 32)
	btn:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	btn:SetAlpha(0)
	btn:EnableMouse(false)
	btn:RegisterForClicks("AnyUp")
	EQT.qItemBtn = btn

	local boundKey = nil
	local bindingDirty = true
	local selfWriteUntil = 0
	local inited = false
	local cachedName = nil
	local dirty = true

	local function ApplyBinding()
		if InCombatLockdown() then return end
		local key = Cfg("questItemHotkey")
		if key == "" then key = nil end
		-- Bind only while a quest item exists, or the key is eaten for nothing.
		local want = (key and btn:GetAttribute("item")) and key or nil
		if not bindingDirty and want == boundKey then return end
		bindingDirty = false
		selfWriteUntil = GetTime() + 0.5
		ClearOverrideBindings(btn)
		if want then
			SetOverrideBindingClick(btn, true, want, "EUI_QuestItemHotkeyBtn", "LeftButton")
		end
		boundKey = want
	end

	local function UpdateQuestItemAttribute()
		if InCombatLockdown() then return end
		if not Cfg("questItemHotkey") then return end
		if not dirty then return end
		dirty = false
		local found = ScanForQuestItem()
		if found ~= cachedName then
			cachedName = found
			btn:SetAttribute("item", found)
			ApplyBinding()
		end
	end

	local function ApplyQuestItemHotkey()
		if InCombatLockdown() then return end
		if not inited then
			inited = true
			btn:SetAttribute("type", "item")
		end
		dirty = true
		bindingDirty = true
		UpdateQuestItemAttribute()
		ApplyBinding()
	end
	EQT.ApplyQuestItemHotkey = ApplyQuestItemHotkey

	-- One scan per burst of quest log updates.
	local scanPending = false
	local function FlushScan()
		scanPending = false
		UpdateQuestItemAttribute()
	end

	local f = CreateFrame("Frame")
	f:RegisterEvent("QUEST_LOG_UPDATE")
	f:RegisterEvent("QUEST_ACCEPTED")
	f:RegisterEvent("UPDATE_BINDINGS")
	f:RegisterEvent("PLAYER_REGEN_ENABLED")
	f:RegisterEvent("PLAYER_ENTERING_WORLD")
	f:SetScript("OnEvent", function(_, event)
		if InCombatLockdown() then return end
		if event == "PLAYER_REGEN_ENABLED" or event == "PLAYER_ENTERING_WORLD" then
			ApplyQuestItemHotkey()
			return
		end
		if event == "UPDATE_BINDINGS" then
			-- Ours echoing back: ignore. Someone else's: lay the override again.
			if GetTime() < selfWriteUntil then return end
			bindingDirty = true
			ApplyBinding()
			return
		end
		if not Cfg("questItemHotkey") then return end
		dirty = true
		if not scanPending then
			scanPending = true
			P.After(0.3, FlushScan)
		end
	end)
end

-------------------------------------------------------------------------------
-- Entry point (ADDON_LOADED, before combat lockdown can apply)
-------------------------------------------------------------------------------
function EQT.InitQoL()
	InstallAutoQuests()
	InstallQuestItemHotkey()
end

function EQT.ResetQoL()
	wipe(preventNPC)
end
