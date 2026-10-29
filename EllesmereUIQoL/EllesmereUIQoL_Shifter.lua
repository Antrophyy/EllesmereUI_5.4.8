-------------------------------------------------------------------------------
--  EllesmereUIQoL_Shifter.lua (5.4.8 port of the retail Shifter)
--
--  Shift + left drag moves a Blizzard window and saves the spot. Ctrl + drag
--  is a temporary move that resets when the window closes. Shift + scroll
--  zooms a window (saved), Ctrl + scroll zooms until it closes.
--  Loot windows (Loot Window, Bonus Roll, Group Loot, Alert Toasts) and the top center
--  world state text get Unlock Mode movers.
--
--  Same saved keys as retail, all in the EllesmereUIDB root:
--  shifterEnabled, shifterNoShift, shifterPositions, shifterScales,
--  shifterLootUnlock, shifterLootHideOverlays, shifterLootPositions,
--  shifterTopBarUnlock, shifterTopBarHideOverlay, shifterTopBarPos.
--
--  5.4.8 differences: the window list is the Mists one; the "Top Bar Event
--  Text" is WorldStateAlwaysUpFrame (Mists has no UI widget container); the
--  retail docking of companion windows beside a moved Character window is
--  not ported (Mists' panel manager places side panels itself). The world
--  map only zooms: Blizzard seats it per map size (screen sized when
--  maximized) and drags the small map from its own title bar.
-------------------------------------------------------------------------------
local addonName = ...
local ns = EllesmereUI

local floor, abs = math.floor, math.abs

-- Per-frame private data (retail GetFFD): never writes fields on Blizzard frames.
local ffdStore = setmetatable({}, { __mode = "k" })
local function GetFFD(frame)
	local t = ffdStore[frame]
	if not t then
		t = {}
		ffdStore[frame] = t
	end
	return t
end

local tempPos = {}    -- temporary positions per frame (cleared on hide)
local tempScale = {}  -- temporary scales per frame (cleared on hide)
local hookedFrames = {}

local eventFrame

-------------------------------------------------------------------------------
--  Frame registry (Mists windows)
-------------------------------------------------------------------------------
local PRELOADED = {
	"CharacterFrame",
	"SpellBookFrame",
	"FriendsFrame",
	"PVEFrame",
	"DressUpFrame",
	"BankFrame",
	"MailFrame",
	"GossipFrame",
	"QuestFrame",
	"QuestLogFrame",
	"QuestLogDetailFrame",
	"MerchantFrame",
	"ChatConfigFrame",
	"ItemTextFrame",
	"LFGDungeonReadyDialog",
	"GuildInviteFrame",
	"TabardFrame",
	"GuildRegistrarFrame",
	"PetitionFrame",
	"TaxiFrame",
	"LootFrame",
	"TradeFrame",
	"HelpFrame",
	"WorldStateScoreFrame",
	"RaidParentFrame",
	"PetStableFrame",
	"WorldMapFrame",
}

-- Zoom only: no Shifter drag or saved spot (Blizzard places these).
local SCALE_ONLY = {
	["WorldMapFrame"] = true,
}

local ADDON_FRAMES = {
	["Blizzard_AchievementUI"]      = { "AchievementFrame" },
	["Blizzard_ArchaeologyUI"]      = { "ArchaeologyFrame" },
	["Blizzard_AuctionUI"]          = { "AuctionFrame" },
	["Blizzard_BlackMarketUI"]      = { "BlackMarketFrame" },
	["Blizzard_Calendar"]           = { "CalendarFrame", "CalendarViewEventFrame" },
	["Blizzard_EncounterJournal"]   = { "EncounterJournal" },
	["Blizzard_GuildBankUI"]        = { "GuildBankFrame" },
	["Blizzard_GuildControlUI"]     = { "GuildControlUI" },
	["Blizzard_GuildUI"]            = { "GuildFrame" },
	["Blizzard_LookingForGuildUI"]  = { "LookingForGuildFrame" },
	["Blizzard_InspectUI"]          = { "InspectFrame" },
	["Blizzard_ItemAlterationUI"]   = { "TransmogrifyFrame" },
	["Blizzard_ItemSocketingUI"]    = { "ItemSocketingFrame" },
	["Blizzard_ItemUpgradeUI"]      = { "ItemUpgradeFrame" },
	["Blizzard_MacroUI"]            = { "MacroFrame" },
	["Blizzard_PetJournal"]         = { "PetJournalParent" },
	["Blizzard_PVPUI"]              = { "PVPUIFrame" },
	["Blizzard_ReforgingUI"]        = { "ReforgingFrame" },
	["Blizzard_TalentUI"]           = { "PlayerTalentFrame" },
	["Blizzard_TradeSkillUI"]       = { "TradeSkillFrame" },
	["Blizzard_TrainerUI"]          = { "ClassTrainerFrame" },
	["Blizzard_VoidStorageUI"]      = { "VoidStorageFrame" },
	["Blizzard_TimeManager"]        = { "TimeManagerFrame" },
	["Blizzard_BindingUI"]          = { "KeyBindingFrame" },
}

-- Extra drag handles on top of the frame body (a mouse-enabled child that
-- would otherwise swallow the drag).
local EXTRA_DRAG_TARGETS = {
	["AchievementFrame"] = function(frame) return _G.AchievementFrameHeader end,
}

-- 5.4.8 tab panes are mouse-enabled frames laid over the whole window
-- (PaperDollFrame, ReputationFrame, TokenFrame, ...), so the window itself
-- never gets the click. Mouse-enabled plain Frame children that reach the
-- window's top edge (title bar) drag it too.
local function CoversTitleBar(frame, child)
	if child:GetObjectType() ~= "Frame" or not child:IsMouseEnabled() then return false end
	local ft, ct = frame:GetTop(), child:GetTop()
	if not ft or not ct then
		-- Never-shown panes have no geometry yet: a single setAllPoints anchor
		-- on the window counts.
		local p, rel = child:GetPoint(1)
		return p == "TOPLEFT" and rel == frame
	end
	return ct >= ft - 30 and child:GetWidth() >= frame:GetWidth() * 0.5
end

-------------------------------------------------------------------------------
--  Saved data (EllesmereUIDB root, like retail)
-------------------------------------------------------------------------------
local function DB()
	if type(EllesmereUIDB) ~= "table" then EllesmereUIDB = {} end
	return EllesmereUIDB
end

local function IsEnabled()
	return DB().shifterEnabled and true or false
end

local function GetSavedPos(name)
	local db = DB()
	return db.shifterPositions and db.shifterPositions[name]
end

local function SavePos(name, point, relPoint, x, y)
	local db = DB()
	db.shifterPositions = db.shifterPositions or {}
	db.shifterPositions[name] = { point = point, relPoint = relPoint, x = x, y = y }
end

local function GetSavedScale(name)
	local db = DB()
	return db.shifterScales and db.shifterScales[name]
end

local function SaveScale(name, scale)
	local db = DB()
	db.shifterScales = db.shifterScales or {}
	db.shifterScales[name] = scale
end

-------------------------------------------------------------------------------
--  Combat queue (retail ns.CombatQueue.Defer)
-------------------------------------------------------------------------------
local combatQueue = {}
local combatFrame = CreateFrame("Frame")
combatFrame:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_REGEN_ENABLED")
	for key, fn in pairs(combatQueue) do
		combatQueue[key] = nil
		fn()
	end
end)
local function Defer(key, fn)
	combatQueue[key] = fn
	combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
end

-------------------------------------------------------------------------------
--  Secure repositioning (protected frames): ClearAllPoints / SetPoint /
--  SetScale run inside a SecureHandler snippet so the frame is not tainted.
-------------------------------------------------------------------------------
local securePositioner = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")

local function SecureSetPoint(frame, point, relPoint, x, y)
	if InCombatLockdown() then return false end
	SecureHandlerSetFrameRef(securePositioner, "f", frame)
	securePositioner:SetAttribute("p", point)
	securePositioner:SetAttribute("rp", relPoint)
	securePositioner:SetAttribute("x", x)
	securePositioner:SetAttribute("y", y)
	SecureHandlerExecute(securePositioner, [[
		local f = self:GetFrameRef("f")
		if not f then return end
		f:ClearAllPoints()
		f:SetPoint(self:GetAttribute("p"), self:GetParent(), self:GetAttribute("rp"), self:GetAttribute("x"), self:GetAttribute("y"))
	]])
	return true
end

local function SecureSetScale(frame, scale)
	if InCombatLockdown() then return false end
	SecureHandlerSetFrameRef(securePositioner, "f", frame)
	securePositioner:SetAttribute("s", scale)
	SecureHandlerExecute(securePositioner, [[
		local f = self:GetFrameRef("f")
		if f then f:SetScale(self:GetAttribute("s")) end
	]])
	return true
end

local function ApplyPosition(frame, name)
	if InCombatLockdown() and frame:IsProtected() then return end
	local pos = tempPos[frame] or GetSavedPos(name)
	if not pos or not pos.point then return end
	local ffd = GetFFD(frame)
	ffd.ignoreSP = true
	if frame:IsProtected() then
		SecureSetPoint(frame, pos.point, pos.relPoint, pos.x, pos.y)
	else
		frame:ClearAllPoints()
		frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
	end
	ffd.ignoreSP = false
end

-------------------------------------------------------------------------------
--  Scaling (Shift + scroll = saved, Ctrl + scroll = temporary)
-------------------------------------------------------------------------------
local SCALE_MIN, SCALE_MAX, SCALE_STEP = 0.5, 2, 0.1

local function SetShifterScale(frame, scale)
	local ffd = GetFFD(frame)
	ffd.ignoreSS = true
	local ok
	if frame:IsProtected() then
		ok = SecureSetScale(frame, scale)
	else
		frame:SetScale(scale)
		ok = true
	end
	ffd.ignoreSS = false
	return ok
end

-- OnShow / init: temp > saved > original (if we scaled it before).
local function ApplyScale(frame, name)
	if InCombatLockdown() and frame:IsProtected() then return end
	local ffd = GetFFD(frame)
	local target = tempScale[frame] or GetSavedScale(name)
	if target then
		if ffd.origScale == nil then ffd.origScale = frame:GetScale() end
		ffd.scaled = true
	else
		if not (ffd.scaled and ffd.origScale) then return end
		target = ffd.origScale
		ffd.scaled = nil
	end
	if abs(frame:GetScale() - target) < 0.001 then return end
	SetShifterScale(frame, target)
end

-- Frame center as an offset from the UIParent center, in frame units.
local function CaptureCenter(frame)
	local fcx, fcy = frame:GetCenter()
	local ucx, ucy = UIParent:GetCenter()
	if not fcx or not ucx then return nil end
	local es = frame:GetEffectiveScale()
	local ues = UIParent:GetEffectiveScale()
	return (fcx * es - ucx * ues) / es, (fcy * es - ucy * ues) / es
end

local function ApplyScaleStep(frame, name, delta, mode)
	if InCombatLockdown() and frame:IsProtected() then return end
	local ffd = GetFFD(frame)
	if ffd.origScale == nil then ffd.origScale = frame:GetScale() end
	local oldS = frame:GetScale()
	local cur = tempScale[frame] or GetSavedScale(name) or oldS
	local new = floor((cur + SCALE_STEP * delta) * 100 + 0.5) / 100
	if new < SCALE_MIN then new = SCALE_MIN elseif new > SCALE_MAX then new = SCALE_MAX end
	if new == cur and abs(oldS - new) < 0.005 then return end
	if not SetShifterScale(frame, new) then return end
	ffd.scaled = true

	if SCALE_ONLY[name] then
		if mode == "save" then
			SaveScale(name, new)
			tempScale[frame] = nil
		else
			tempScale[frame] = new
		end
		return
	end

	-- Keep the window in place: offsets are in frame units, so rescale them.
	local ratio = oldS / new
	if mode == "save" then
		SaveScale(name, new)
		tempScale[frame] = nil
		local saved = GetSavedPos(name)
		if saved then
			SavePos(name, saved.point, saved.relPoint, saved.x * ratio, saved.y * ratio)
		elseif not tempPos[frame] then
			local cx, cy = CaptureCenter(frame)
			if cx then SavePos(name, "CENTER", "CENTER", cx, cy) end
		end
		if tempPos[frame] then
			tempPos[frame].x = tempPos[frame].x * ratio
			tempPos[frame].y = tempPos[frame].y * ratio
		end
	else
		tempScale[frame] = new
		if tempPos[frame] then
			tempPos[frame].x = tempPos[frame].x * ratio
			tempPos[frame].y = tempPos[frame].y * ratio
		else
			local saved = GetSavedPos(name)
			if saved then
				tempPos[frame] = { point = saved.point, relPoint = saved.relPoint, x = saved.x * ratio, y = saved.y * ratio }
			else
				local cx, cy = CaptureCenter(frame)
				if cx then tempPos[frame] = { point = "CENTER", relPoint = "CENTER", x = cx, y = cy } end
			end
		end
	end
	ApplyPosition(frame, name)
end

-------------------------------------------------------------------------------
--  Scroll-wheel overlay: one frame of ours sits over the hovered window
--  while Shift / Ctrl is held and takes the wheel (no Blizzard frame gets
--  EnableMouseWheel). Clicks pass through (EnableMouse false).
-------------------------------------------------------------------------------
local wheelTarget, wheelTargetName
local wheelOverlay = CreateFrame("Frame", nil, UIParent)
wheelOverlay:Hide()
wheelOverlay:EnableMouse(false)
wheelOverlay:EnableMouseWheel(true)
wheelOverlay:SetFrameStrata("TOOLTIP")

local WheelArm = { shown = 0 }

-- Topmost window under the mouse (the world map can sit over others).
local STRATA_RANK = { BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5,
	FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8 }

local function FindWheelTarget()
	local best, bestName, bestRank, bestLevel
	for i = 1, #hookedFrames do
		local e = hookedFrames[i]
		local f = e.frame
		if f:IsVisible() and f:IsMouseOver() then
			local rank = STRATA_RANK[f:GetFrameStrata()] or 0
			local level = f:GetFrameLevel()
			if not best or rank > bestRank or (rank == bestRank and level > bestLevel) then
				best, bestName, bestRank, bestLevel = f, e.name, rank, level
			end
		end
	end
	return best, bestName
end

local function UpdateWheelOverlay()
	if WheelArm.shown == 0 or not (IsEnabled() and (IsShiftKeyDown() or IsControlKeyDown())) then
		wheelTarget, wheelTargetName = nil, nil
		wheelOverlay:Hide()
		return
	end
	local f, name = FindWheelTarget()
	wheelTarget, wheelTargetName = f, name
	wheelOverlay:ClearAllPoints()
	if f then
		wheelOverlay:SetAllPoints(f)
		wheelOverlay:EnableMouseWheel(true)
	else
		-- Parked but shown: the OnUpdate keeps looking for a window under the mouse.
		wheelOverlay:SetSize(1, 1)
		wheelOverlay:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", -20, -20)
		wheelOverlay:EnableMouseWheel(false)
	end
	wheelOverlay:Show()
end

do
	local acc = 0
	wheelOverlay:SetScript("OnUpdate", function(_, elapsed)
		acc = acc + elapsed
		if acc < 0.1 then return end
		acc = 0
		UpdateWheelOverlay()
	end)
end

wheelOverlay:SetScript("OnMouseWheel", function(_, delta)
	local frame, name = wheelTarget, wheelTargetName
	if not frame or not IsEnabled() then return end
	if IsShiftKeyDown() then
		ApplyScaleStep(frame, name, delta, "save")
	elseif IsControlKeyDown() then
		ApplyScaleStep(frame, name, delta, "temp")
	end
end)

WheelArm.Sync = function()
	if not eventFrame then return end
	if WheelArm.shown > 0 and IsEnabled() then
		eventFrame:RegisterEvent("MODIFIER_STATE_CHANGED")
	else
		eventFrame:UnregisterEvent("MODIFIER_STATE_CHANGED")
	end
	UpdateWheelOverlay()
end

WheelArm.Note = function(delta)
	local was = WheelArm.shown
	local now = was + delta
	if now < 0 then now = 0 end
	WheelArm.shown = now
	if (was == 0) ~= (now == 0) then WheelArm.Sync() end
end

-------------------------------------------------------------------------------
--  Cursor drag for protected frames (StartMoving would taint them)
-------------------------------------------------------------------------------
local secureDrag = {}
local secureDragUpdater = CreateFrame("Frame")
secureDragUpdater:Hide()

local function StopSecureDrag()
	secureDragUpdater:Hide()
	local frame = secureDrag.frame
	if not frame then return end
	if secureDrag.curX then
		if secureDrag.mode == "save" then
			SavePos(secureDrag.name, "CENTER", "CENTER", secureDrag.curX, secureDrag.curY)
			tempPos[frame] = nil
		else
			tempPos[frame] = { point = "CENTER", relPoint = "CENTER", x = secureDrag.curX, y = secureDrag.curY }
		end
	end
	secureDrag.frame = nil
end

secureDragUpdater:SetScript("OnUpdate", function()
	local frame = secureDrag.frame
	if not frame then secureDragUpdater:Hide(); return end
	if InCombatLockdown() then StopSecureDrag(); return end
	local cx, cy = GetCursorPosition()
	local es = frame:GetEffectiveScale()
	local ues = UIParent:GetEffectiveScale()
	local ucx, ucy = UIParent:GetCenter()
	local nx = secureDrag.startX + (cx - secureDrag.cursorX)
	local ny = secureDrag.startY + (cy - secureDrag.cursorY)
	local sw, sh = GetScreenWidth() * ues, GetScreenHeight() * ues
	if nx < 0 then nx = 0 elseif nx > sw then nx = sw end
	if ny < 0 then ny = 0 elseif ny > sh then ny = sh end
	local x = (nx - ucx * ues) / es
	local y = (ny - ucy * ues) / es
	secureDrag.curX, secureDrag.curY = x, y
	local ffd = GetFFD(frame)
	ffd.ignoreSP = true
	SecureSetPoint(frame, "CENTER", "CENTER", x, y)
	ffd.ignoreSP = false
end)

local function StartSecureDrag(frame, name, mode)
	local fcx, fcy = frame:GetCenter()
	if not fcx then return end
	local es = frame:GetEffectiveScale()
	secureDrag.frame = frame
	secureDrag.name = name
	secureDrag.mode = mode
	secureDrag.cursorX, secureDrag.cursorY = GetCursorPosition()
	secureDrag.startX, secureDrag.startY = fcx * es, fcy * es
	secureDrag.curX, secureDrag.curY = nil, nil
	secureDragUpdater:Show()
end

-------------------------------------------------------------------------------
--  Hook one window
-------------------------------------------------------------------------------
local function HookFrame(frame, name)
	local ffd = GetFFD(frame)
	if ffd.hooked then return end
	ffd.hooked = true
	hookedFrames[#hookedFrames + 1] = { frame = frame, name = name }

	frame:HookScript("OnShow", function() WheelArm.Note(1) end)
	frame:HookScript("OnHide", function() WheelArm.Note(-1) end)
	if frame:IsShown() then WheelArm.Note(1) end

	if SCALE_ONLY[name] then
		frame:HookScript("OnShow", function()
			if IsEnabled() then ApplyScale(frame, name) end
		end)
		frame:HookScript("OnHide", function()
			if IsEnabled() then tempScale[frame] = nil end
		end)
		hooksecurefunc(frame, "SetScale", function()
			if not IsEnabled() or ffd.ignoreSS then return end
			if tempScale[frame] or GetSavedScale(name) then ApplyScale(frame, name) end
		end)
		if frame:IsVisible() then ApplyScale(frame, name) end
		return
	end

	if not frame:IsProtected() then
		frame:SetMovable(true)
		frame:SetClampedToScreen(true)
	end

	local dragging  -- unprotected frames: "save" | "temp" | nil

	local function AttachDrag(dragTarget)
		if not dragTarget or not dragTarget.HookScript then return end
		dragTarget:HookScript("OnMouseDown", function(_, button)
			if not IsEnabled() or button ~= "LeftButton" then return end
			if InCombatLockdown() and frame:IsProtected() then return end
			local mode
			if IsShiftKeyDown() or DB().shifterNoShift then
				mode = "save"
			elseif IsControlKeyDown() then
				mode = "temp"
			else
				return
			end
			if frame:IsProtected() then
				StartSecureDrag(frame, name, mode)
			else
				dragging = mode
				frame:StartMoving()
			end
		end)
		dragTarget:HookScript("OnMouseUp", function(_, button)
			if button ~= "LeftButton" then return end
			if frame:IsProtected() then
				if secureDrag.frame == frame then StopSecureDrag() end
				return
			end
			if not dragging then return end
			frame:StopMovingOrSizing()
			frame:SetUserPlaced(false)
			local p, _, rp, x, y = frame:GetPoint(1)
			if p then
				if dragging == "save" then
					SavePos(name, p, rp, x, y)
					tempPos[frame] = nil
				else
					tempPos[frame] = { point = p, relPoint = rp, x = x, y = y }
				end
			end
			dragging = nil
		end)
	end

	AttachDrag(frame)
	local extra = EXTRA_DRAG_TARGETS[name]
	if extra then AttachDrag(extra(frame)) end

	local attached = {}
	local function AttachPanes()
		local children = { frame:GetChildren() }
		for i = 1, #children do
			local child = children[i]
			if not attached[child] and CoversTitleBar(frame, child) then
				attached[child] = true
				AttachDrag(child)
			end
		end
	end
	AttachPanes()
	frame:HookScript("OnShow", AttachPanes)

	frame:HookScript("OnShow", function()
		if not IsEnabled() then return end
		ApplyScale(frame, name)
		ApplyPosition(frame, name)
	end)
	frame:HookScript("OnHide", function()
		if not IsEnabled() then return end
		if secureDrag.frame == frame then StopSecureDrag() end
		tempPos[frame] = nil
		tempScale[frame] = nil
	end)

	-- The Mists panel manager (UpdateUIPanelPositions) re-anchors windows:
	-- put a moved window back right after.
	hooksecurefunc(frame, "SetPoint", function()
		if not IsEnabled() or ffd.ignoreSP then return end
		if secureDrag.frame == frame or dragging then return end
		if InCombatLockdown() and frame:IsProtected() then return end
		if tempPos[frame] or GetSavedPos(name) then
			ApplyPosition(frame, name)
		end
	end)
	hooksecurefunc(frame, "SetScale", function()
		if not IsEnabled() or ffd.ignoreSS then return end
		if InCombatLockdown() and frame:IsProtected() then return end
		if tempScale[frame] or GetSavedScale(name) then
			ApplyScale(frame, name)
		end
	end)

	if frame:IsVisible() then
		ApplyScale(frame, name)
		ApplyPosition(frame, name)
	end
end

local function TryHook(name)
	local frame = _G[name]
	if type(frame) == "table" and frame.HookScript and frame.IsProtected then
		HookFrame(frame, name)
	end
end

-------------------------------------------------------------------------------
--  Loot windows through Unlock Mode movers. The mover drags a hidden proxy;
--  the saved spot is pushed onto the Blizzard frame and put back whenever
--  Blizzard re-anchors it. ignoreFramePositionManager opts GroupLootContainer
--  out of UIParent_ManageFramePositions (5.4.8 UIParent.lua checks it too).
-------------------------------------------------------------------------------
local LOOT_WINDOWS = {
	{ name = "BonusRollFrame",     key = "EUI_BonusRoll",   label = "Bonus Roll",   order = 640, defW = 270, defH = 100, defY = 240 },
	{ name = "GroupLootContainer", key = "EUI_GroupLoot",   label = "Group Loot",   order = 641, defW = 300, defH = 80,  defY = 340 },
	{ name = "AlertFrame",         key = "EUI_AlertToasts", label = "Alert Toasts", order = 642, defW = 300, defH = 100, defY = 160, fixedSize = true },
}

local lootProxies = {}
local lootHooked = {}

local function LootEnabled()
	return DB().shifterLootUnlock and true or false
end

local function GetLootPos(name)
	local db = DB()
	return db.shifterLootPositions and db.shifterLootPositions[name]
end

local function SaveLootPos(name, point, relPoint, x, y)
	local db = DB()
	db.shifterLootPositions = db.shifterLootPositions or {}
	db.shifterLootPositions[name] = { point = point, relPoint = relPoint, x = x, y = y }
end

local function LootFrame(name)
	local frame = _G[name]
	if type(frame) ~= "table" or not frame.HookScript then return nil end
	if frame.IsForbidden and frame:IsForbidden() then return nil end
	if frame:IsProtected() then return nil end
	return frame
end

local function ApplyLootPos(name)
	if not LootEnabled() then return end
	local pos = GetLootPos(name)
	if not pos then return end
	local frame = LootFrame(name)
	if not frame then return end
	local ffd = GetFFD(frame)
	if ffd.lootIgnoreSP then return end
	ffd.lootIgnoreSP = true
	frame.ignoreFramePositionManager = true
	frame:ClearAllPoints()
	frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
	ffd.lootIgnoreSP = false
	-- Toasts stack from AlertFrame: re-stack them on the new spot.
	if name == "AlertFrame" and AlertFrame_FixAnchors then
		AlertFrame_FixAnchors()
	end
end

local function HookLootWindow(name)
	if lootHooked[name] then return end
	local frame = LootFrame(name)
	if not frame then return end
	lootHooked[name] = true
	hooksecurefunc(frame, "SetPoint", function()
		if GetFFD(frame).lootIgnoreSP then return end
		ApplyLootPos(name)
	end)
	frame:HookScript("OnShow", function()
		ApplyLootPos(name)
	end)
end

local function EnsureLootProxy(info)
	local proxy = lootProxies[info.name]
	if proxy then return proxy end
	proxy = CreateFrame("Frame", nil, UIParent)
	proxy:Hide()
	proxy:SetSize(info.defW, info.defH)
	local pos = GetLootPos(info.name)
	if pos then
		proxy:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
	else
		proxy:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, info.defY)
	end
	lootProxies[info.name] = proxy
	return proxy
end

local function InitLootWindows()
	for i = 1, #LOOT_WINDOWS do
		local name = LOOT_WINDOWS[i].name
		HookLootWindow(name)
		-- AlertFrame is a hidden anchor in Mists: apply it right away.
		if LootFrame(name) and (name == "AlertFrame" or _G[name]:IsVisible()) then
			ApplyLootPos(name)
		end
	end
end

local function RegisterLootUnlockElements()
	local MK = ns.MakeUnlockElement
	if not MK or not ns.RegisterUnlockElements then return end
	local elements = {}
	for i = 1, #LOOT_WINDOWS do
		local info = LOOT_WINDOWS[i]
		elements[#elements + 1] = MK({
			key = info.key,
			label = info.label,
			group = "Quality of Life",
			order = info.order,
			noResize = true,
			noAnchorTarget = true,
			noAnchorTo = true,
			noSizeMatchTarget = true,
			moverBg = { r = 0.165, g = 0.11, b = 0.055 },
			-- "Hide Unlock Mode Overlays" (shifterLootHideOverlays): the movers
			-- stay out of Unlock Mode, the saved positions keep applying.
			isHidden = function()
				return not LootEnabled() or not _G[info.name] or DB().shifterLootHideOverlays and true or false
			end,
			getFrame = function() return EnsureLootProxy(info) end,
			getSize = function()
				if info.fixedSize then return info.defW, info.defH end
				local frame = _G[info.name]
				local w = frame and frame.GetWidth and frame:GetWidth() or 0
				local h = frame and frame.GetHeight and frame:GetHeight() or 0
				if not w or w < 20 then w = info.defW end
				if not h or h < 20 then h = info.defH end
				return w, h
			end,
			savePos = function(_, point, relPoint, x, y)
				SaveLootPos(info.name, point, relPoint, x, y)
				local proxy = EnsureLootProxy(info)
				proxy:ClearAllPoints()
				proxy:SetPoint(point, UIParent, relPoint, x, y)
				HookLootWindow(info.name)
				ApplyLootPos(info.name)
			end,
			loadPos = function()
				local pos = GetLootPos(info.name)
				if pos then
					return { point = pos.point, relPoint = pos.relPoint, x = pos.x, y = pos.y }
				end
				return nil
			end,
			clearPos = function()
				local db = DB()
				if db.shifterLootPositions then db.shifterLootPositions[info.name] = nil end
				local proxy = lootProxies[info.name]
				if proxy then
					proxy:ClearAllPoints()
					proxy:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, info.defY)
				end
				local frame = LootFrame(info.name)
				if frame then frame.ignoreFramePositionManager = nil end
			end,
			applyPos = function()
				local pos = GetLootPos(info.name)
				local proxy = EnsureLootProxy(info)
				proxy:ClearAllPoints()
				if pos then
					proxy:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
				else
					proxy:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, info.defY)
				end
				ApplyLootPos(info.name)
			end,
		})
	end
	ns:RegisterUnlockElements(elements, addonName)
end

-------------------------------------------------------------------------------
--  Loot Window (LootFrame) through an Unlock Mode mover. Not in retail (there
--  Shift + drag moves it). Same saved key as the Shifter drag
--  (shifterPositions.LootFrame), so both ways stay in sync, but the spot is
--  applied even with Shifter off. LootFrame is an unprotected "left" UI panel:
--  the panel manager and lootUnderMouse re-anchor it, the SetPoint hook puts
--  it back.
-------------------------------------------------------------------------------
local LOOTWIN_NAME, LOOTWIN_KEY = "LootFrame", "EUI_LootWindow"
local LOOTWIN_DEFW, LOOTWIN_DEFH = 190, 360
local lootWinProxy
local lootWinHooked = false

local function ApplyLootWindowPos()
	local pos = GetSavedPos(LOOTWIN_NAME)
	if not pos or not pos.point then return end
	local frame = LootFrame(LOOTWIN_NAME)
	if not frame then return end
	local ffd = GetFFD(frame)
	if ffd.lootWinIgnoreSP then return end
	ffd.lootWinIgnoreSP = true
	frame:ClearAllPoints()
	frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
	ffd.lootWinIgnoreSP = false
end

local function HookLootWindowFrame()
	if lootWinHooked then return end
	local frame = LootFrame(LOOTWIN_NAME)
	if not frame then return end
	lootWinHooked = true
	hooksecurefunc(frame, "SetPoint", function()
		if GetFFD(frame).lootWinIgnoreSP then return end
		ApplyLootWindowPos()
	end)
	frame:HookScript("OnShow", ApplyLootWindowPos)
	-- Safety net: our LOOT_OPENED runs after LootFrame's own handler
	-- (registered later), then once more on the next frame, so whatever
	-- placed the window during the show (panel manager, loot under mouse)
	-- is overridden.
	local nextFrame = CreateFrame("Frame")
	nextFrame:Hide()
	nextFrame:SetScript("OnUpdate", function(self)
		self:Hide()
		if frame:IsShown() then ApplyLootWindowPos() end
	end)
	local ev = CreateFrame("Frame")
	ev:RegisterEvent("LOOT_OPENED")
	ev:SetScript("OnEvent", function()
		if not frame:IsShown() then return end
		ApplyLootWindowPos()
		nextFrame:Show()
	end)
end

local function PlaceLootWindowProxy()
	local proxy = lootWinProxy
	proxy:ClearAllPoints()
	local pos = GetSavedPos(LOOTWIN_NAME)
	if pos and pos.point then
		proxy:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
	else
		-- Default spot of the Mists loot panel (left UI panel slot).
		proxy:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -116)
	end
end

local function EnsureLootWindowProxy()
	if lootWinProxy then return lootWinProxy end
	lootWinProxy = CreateFrame("Frame", nil, UIParent)
	lootWinProxy:Hide()
	lootWinProxy:SetSize(LOOTWIN_DEFW, LOOTWIN_DEFH)
	PlaceLootWindowProxy()
	return lootWinProxy
end

local function RegisterLootWindowUnlockElement()
	local MK = ns.MakeUnlockElement
	if not MK or not ns.RegisterUnlockElements then return end
	ns:RegisterUnlockElements({
		MK({
			key = LOOTWIN_KEY,
			label = "Loot Window",
			group = "Quality of Life",
			order = 639,
			noResize = true,
			noAnchorTarget = true,
			noAnchorTo = true,
			noSizeMatchTarget = true,
			moverBg = { r = 0.165, g = 0.11, b = 0.055 },
			isHidden = function() return not _G[LOOTWIN_NAME] end,
			getFrame = EnsureLootWindowProxy,
			getSize = function()
				local frame = _G[LOOTWIN_NAME]
				local w = frame and frame:GetWidth() or 0
				local h = frame and frame:GetHeight() or 0
				if not w or w < 20 then w = LOOTWIN_DEFW end
				if not h or h < 20 then h = LOOTWIN_DEFH end
				return w, h
			end,
			savePos = function(_, point, relPoint, x, y)
				SavePos(LOOTWIN_NAME, point, relPoint, x, y)
				EnsureLootWindowProxy()
				PlaceLootWindowProxy()
				HookLootWindowFrame()
				ApplyLootWindowPos()
			end,
			loadPos = function()
				local pos = GetSavedPos(LOOTWIN_NAME)
				if pos and pos.point then
					return { point = pos.point, relPoint = pos.relPoint, x = pos.x, y = pos.y }
				end
				return nil
			end,
			clearPos = function()
				local db = DB()
				if db.shifterPositions then db.shifterPositions[LOOTWIN_NAME] = nil end
				if lootWinProxy then PlaceLootWindowProxy() end
			end,
			applyPos = function()
				EnsureLootWindowProxy()
				PlaceLootWindowProxy()
				ApplyLootWindowPos()
			end,
		}),
	}, addonName)
end

-------------------------------------------------------------------------------
--  Top Bar Event Text: the top center world state frame of Mists
--  (WorldStateAlwaysUpFrame: battleground scores, scenario / event texts).
-------------------------------------------------------------------------------
local TOPBAR_NAME = "WorldStateAlwaysUpFrame"
local TOPBAR_KEY, TOPBAR_LABEL = "EUI_TopBarEventText", "Top Bar Event Text"
local TOPBAR_DEFW, TOPBAR_DEFH, TOPBAR_DEFY = 400, 60, -120

local topBarProxy
local topBarHooked = false

local function TopBarEnabled()
	return DB().shifterTopBarUnlock and true or false
end

local function GetTopBarPos()
	return DB().shifterTopBarPos
end

local function TopBarFrame()
	local frame = _G[TOPBAR_NAME]
	if type(frame) ~= "table" or not frame.HookScript then return nil end
	if frame.IsForbidden and frame:IsForbidden() then return nil end
	return frame
end

local function ApplyTopBarPos()
	if not TopBarEnabled() then return end
	local pos = GetTopBarPos()
	if not pos then return end
	local frame = TopBarFrame()
	if not frame then return end
	local ffd = GetFFD(frame)
	if ffd.topIgnoreSP then return end
	if frame:IsProtected() and InCombatLockdown() then
		Defer("ShifterTopBar", ApplyTopBarPos)
		return
	end
	ffd.topIgnoreSP = true
	frame.ignoreFramePositionManager = true
	if frame:IsProtected() then
		SecureSetPoint(frame, pos.point, pos.relPoint, pos.x, pos.y)
	else
		frame:ClearAllPoints()
		frame:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
	end
	ffd.topIgnoreSP = false
end

local function HookTopBar()
	if topBarHooked then return end
	local frame = TopBarFrame()
	if not frame then return end
	topBarHooked = true
	hooksecurefunc(frame, "SetPoint", function()
		if GetFFD(frame).topIgnoreSP then return end
		ApplyTopBarPos()
	end)
	frame:HookScript("OnShow", ApplyTopBarPos)
end

local function TopBarDefaultPoint(proxy)
	proxy:SetPoint("TOP", UIParent, "TOP", 0, TOPBAR_DEFY)
end

local function EnsureTopBarProxy()
	if topBarProxy then return topBarProxy end
	topBarProxy = CreateFrame("Frame", nil, UIParent)
	topBarProxy:Hide()
	topBarProxy:SetSize(TOPBAR_DEFW, TOPBAR_DEFH)
	local pos = GetTopBarPos()
	if pos then
		topBarProxy:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
	else
		TopBarDefaultPoint(topBarProxy)
	end
	return topBarProxy
end

local function RegisterTopBarUnlockElement()
	local MK = ns.MakeUnlockElement
	if not MK or not ns.RegisterUnlockElements then return end
	ns:RegisterUnlockElements({
		MK({
			key = TOPBAR_KEY,
			label = TOPBAR_LABEL,
			group = "Quality of Life",
			order = 643,
			noResize = true,
			noAnchorTarget = true,
			noAnchorTo = true,
			noSizeMatchTarget = true,
			moverBg = { r = 0.165, g = 0.11, b = 0.055 },
			subtitle = "Disable the Top Bar Event Text overlay in Shifter once done positioning",
			isHidden = function()
				if not TopBarEnabled() or not _G[TOPBAR_NAME] then return true end
				return DB().shifterTopBarHideOverlay and true or false
			end,
			getFrame = EnsureTopBarProxy,
			getSize = function() return TOPBAR_DEFW, TOPBAR_DEFH end,
			savePos = function(_, point, relPoint, x, y)
				DB().shifterTopBarPos = { point = point, relPoint = relPoint, x = x, y = y }
				local proxy = EnsureTopBarProxy()
				proxy:ClearAllPoints()
				proxy:SetPoint(point, UIParent, relPoint, x, y)
				HookTopBar()
				ApplyTopBarPos()
			end,
			loadPos = function()
				local pos = GetTopBarPos()
				if pos then
					return { point = pos.point, relPoint = pos.relPoint, x = pos.x, y = pos.y }
				end
				return nil
			end,
			clearPos = function()
				DB().shifterTopBarPos = nil
				if topBarProxy then
					topBarProxy:ClearAllPoints()
					TopBarDefaultPoint(topBarProxy)
				end
				local frame = TopBarFrame()
				if frame then frame.ignoreFramePositionManager = nil end
			end,
			applyPos = function()
				local pos = GetTopBarPos()
				local proxy = EnsureTopBarProxy()
				proxy:ClearAllPoints()
				if pos then
					proxy:SetPoint(pos.point, UIParent, pos.relPoint, pos.x, pos.y)
				else
					TopBarDefaultPoint(proxy)
				end
				ApplyTopBarPos()
			end,
		}),
	}, addonName)
end

local function InitTopBar()
	HookTopBar()
	if TopBarFrame() then ApplyTopBarPos() end
end

local function DisableTopBar()
	local frame = TopBarFrame()
	if frame then frame.ignoreFramePositionManager = nil end
end

-------------------------------------------------------------------------------
--  Init
-------------------------------------------------------------------------------
local pendingAddons = {}
eventFrame = CreateFrame("Frame")

local function InitShifter()
	for i = 1, #PRELOADED do
		TryHook(PRELOADED[i])
	end
	for addon, frames in pairs(ADDON_FRAMES) do
		if IsAddOnLoaded(addon) then
			for i = 1, #frames do TryHook(frames[i]) end
		else
			pendingAddons[addon] = frames
		end
	end
	if next(pendingAddons) then
		eventFrame:RegisterEvent("ADDON_LOADED")
	end
	WheelArm.Sync()
end

local function ShutdownShifter()
	eventFrame:UnregisterEvent("MODIFIER_STATE_CHANGED")
	UpdateWheelOverlay()
end

local function DisableLootWindows()
	for i = 1, #LOOT_WINDOWS do
		local frame = LootFrame(LOOT_WINDOWS[i].name)
		if frame then frame.ignoreFramePositionManager = nil end
	end
end

-- Positions and zoom of every window (the options reset button reloads after).
local function ResetPositions()
	local db = DB()
	db.shifterPositions = nil
	db.shifterLootPositions = nil
	db.shifterTopBarPos = nil
	db.shifterScales = nil
	wipe(tempPos)
	wipe(tempScale)
end

-- Retail names for the options page.
ns._InitShifter = InitShifter
ns._ShutdownShifter = ShutdownShifter
ns._ResetShifterPositions = ResetPositions
ns._InitShifterLootWindows = InitLootWindows
ns._DisableShifterLootWindows = DisableLootWindows
ns._InitShifterTopBar = InitTopBar
ns._DisableShifterTopBar = DisableTopBar

-- Settings window: toggles only store the value; this follows them.
local applied = { enabled = false, loot = false, top = false }
local loggedIn = false
ns.applyHooks = ns.applyHooks or {}
tinsert(ns.applyHooks, function()
	if not loggedIn then return end
	local en, loot, top = IsEnabled(), LootEnabled(), TopBarEnabled()
	if en ~= applied.enabled then
		if en then InitShifter() else ShutdownShifter() end
		applied.enabled = en
	end
	if loot ~= applied.loot then
		if loot then InitLootWindows() else DisableLootWindows() end
		applied.loot = loot
	end
	if top ~= applied.top then
		if top then InitTopBar() else DisableTopBar() end
		applied.top = top
	end
end)

-- First login: the user's retail Shifter settings (retail EllesmereUIDB root).
local function SeedRetail()
	local db = DB()
	if db.shifterSeeded then return end
	db.shifterSeeded = true
	if db.shifterEnabled == nil then db.shifterEnabled = true end
	if db.shifterLootUnlock == nil then db.shifterLootUnlock = true end
	if db.shifterLootHideOverlays == nil then db.shifterLootHideOverlays = true end
	if db.shifterLootPositions == nil then
		db.shifterLootPositions = {
			GroupLootContainer = { point = "CENTER", relPoint = "CENTER", x = -819, y = 305 },
			BonusRollFrame = { point = "CENTER", relPoint = "CENTER", x = 445, y = 237 },
			AlertFrame = { point = "CENTER", relPoint = "CENTER", x = -819, y = 215 },
		}
	end
	if db.shifterTopBarPos == nil then
		db.shifterTopBarPos = { point = "CENTER", relPoint = "CENTER", x = 0, y = 642 }
	end
end

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
	if event == "PLAYER_LOGIN" then
		self:UnregisterEvent("PLAYER_LOGIN")
		SeedRetail()
		loggedIn = true
		applied.enabled, applied.loot, applied.top = IsEnabled(), LootEnabled(), TopBarEnabled()
		if applied.enabled then InitShifter() end
		RegisterLootUnlockElements()
		if applied.loot then InitLootWindows() end
		RegisterLootWindowUnlockElement()
		HookLootWindowFrame()
		RegisterTopBarUnlockElement()
		if applied.top then InitTopBar() end
	elseif event == "ADDON_LOADED" then
		local frames = pendingAddons[arg1]
		if frames then
			pendingAddons[arg1] = nil
			for i = 1, #frames do TryHook(frames[i]) end
			if not next(pendingAddons) then
				self:UnregisterEvent("ADDON_LOADED")
			end
		end
	elseif event == "MODIFIER_STATE_CHANGED" then
		UpdateWheelOverlay()
	end
end)
