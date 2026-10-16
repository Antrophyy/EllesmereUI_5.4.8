-- Profile Sync (retail EllesmereUI_ProfileSync.lua): mirror groups,
-- per-module sync exclusions and the sync popup by the sidebar.
--
-- A module's sync group is a set of profiles that keep that module's
-- settings the same: EllesmereUIDB.syncedModules = { [folder] = {
-- [profileName] = true } } (retail key). The ACTIVE profile, when it is a
-- member, pushes its settings to the other members: when the profile is
-- stored (switch, import) and at logout / reload (PLAYER_LOGOUT, before the
-- SavedVariables are written). A profile outside a group never pushes in.
--
-- Exclusions: paths in the module SavedVariables that never sync (frame
-- positions and unlock sizes, private data), so every profile keeps its own
-- layout. Path segments are joined by "."; "*" stands for any key
-- ("profile.bars.*.growDirection"). Retail paths are relative to the retail
-- profile blob; here they are relative to the module SavedVariables (often
-- one level down, "profile.").
--
-- Mists differences: the active profile is the live SavedVariables, so a
-- sync that changes the active profile (a group started from another
-- profile's settings) writes the live table and asks to reload the UI.

local ns = EllesmereUI
local Kit = ns.PopupKit

local DeepCopy = ns.ProfileDeepCopy
local floor, min = math.floor, math.min

local function DB()
	if type(EllesmereUIDB) ~= "table" then
		EllesmereUIDB = {}
	end
	return EllesmereUIDB
end

local function Groups()
	local db = DB()
	if type(db.syncedModules) ~= "table" then
		db.syncedModules = {}
	end
	return db.syncedModules
end

---------------------------------------------------------------------------
-- Exclusions per module (Mists SavedVariables paths)
---------------------------------------------------------------------------
local syncExclusions = {}
ns._syncExclusions = syncExclusions

function ns.RegisterSyncExclusions(folder, keys)
	syncExclusions[folder] = syncExclusions[folder] or {}
	for _, k in ipairs(keys) do
		syncExclusions[folder][k] = true
	end
end

ns.RegisterSyncExclusions("EllesmereUIActionBars", {
	"profile.barPositions",
	"profile.bars.*.growDirection", "profile.bars.*.orientation",
	"profile.bars.*.buttonWidth", "profile.bars.*.buttonHeight",
	"profile.bars.*.targetWidth", "profile.bars.*.targetHeight",
	"profile.bars.*.width", "profile.bars.*.height",
	"profile.bars.*.overrideNumIcons", "profile.bars.*.overrideNumRows",
	"profile.bars.*.numIcons", "profile.bars.*.numRows",
})

ns.RegisterSyncExclusions("EllesmereUIUnitFrames", {
	"positions",
	"player.frameWidth", "player.healthHeight",
	"target.frameWidth", "target.healthHeight",
	"targettarget.frameWidth", "targettarget.healthHeight",
	"focustarget.frameWidth", "focustarget.healthHeight",
	"pet.frameWidth", "pet.healthHeight",
	"focus.frameWidth", "focus.healthHeight",
	"boss.frameWidth", "boss.healthHeight",
	"player.playerCastbarWidth", "player.playerCastbarHeight",
	-- Player Aura Bars
	"playerAuraBars.buffsPos", "playerAuraBars.debuffsPos",
	"playerAuraBars.customBuffBars.*.pos", "playerAuraBars.customDebuffBars.*.pos",
	"playerAuraBars.pabSpecBars.*.buffBars.*.pos", "playerAuraBars.pabSpecBars.*.debuffBars.*.pos",
})

ns.RegisterSyncExclusions("EllesmereUICooldownManager", {
	"profile.cdmBarPositions",
	"profile.cdmBars.bars.*.iconSize",
	"profile.cdmBars.bars.*.numRows",
	"profile.cdmBars.bars.*.anchorFirstRow",
	"profile.cdmBars.bars.*.rowGrowDirection",
	"profile.cdmBars.bars.*.spacing",
	"profile.cdmBars.bars.*.verticalOrientation",
	"profile.cdmBars.bars.*.anchorTo",
	"profile.cdmBars.bars.*.anchorPosition",
	"profile.cdmBars.bars.*.anchorOffsetX",
	"profile.cdmBars.bars.*.anchorOffsetY",
	"specProfiles.*.tbbPositions", -- Tracking Bars
})

ns.RegisterSyncExclusions("EllesmereUIResourceBars", {
	"profile.health.unlockPos", "profile.health.width", "profile.health.height",
	"profile.health.offsetX", "profile.health.offsetY", "profile.health.orientation",
	"profile.primary.unlockPos", "profile.primary.width", "profile.primary.height",
	"profile.primary.offsetX", "profile.primary.offsetY", "profile.primary.orientation",
	"profile.secondary.unlockPos", "profile.secondary.pipWidth", "profile.secondary.pipHeight",
	"profile.secondary.pipOrientation", "profile.secondary.offsetX", "profile.secondary.offsetY",
	"profile.castBar.unlockPos", "profile.castBar.width", "profile.castBar.height",
	"profile.castBar.anchorX", "profile.castBar.anchorY",
	"profile.gcdBar.unlockPos", "profile.gcdBar.width", "profile.gcdBar.height",
	"profile.gcdBar.anchorX", "profile.gcdBar.anchorY", "profile.gcdBar.orientation",
	"profile.totemBar.unlockPos", "profile.totemBar.orientation",
	"profile.general.anchorX", "profile.general.anchorY", "profile.general.orientation",
})

ns.RegisterSyncExclusions("EllesmereUIAuraBuffReminders", {
	"profile.unlockPos",
	"profile.display.xOffset", "profile.display.yOffset",
})

ns.RegisterSyncExclusions("EllesmereUIRaidFrames", {
	"profile.unlockPos", "profile.partyUnlockPos",
	"profile.healerMana.unlockPos",
	"profile.friendlyBoss.freePos", "profile.friendlyBoss.freeRect",
	"profile.extraFrames.freePos", "profile.extraFrames.freeRect",
	"profile.petFrames.freePos", "profile.petFrames.freeRect",
	"profile.petFrames.party_freePos", "profile.petFrames.party_freeRect",
	"profile.petFrames.raid_freePos", "profile.petFrames.raid_freeRect",
})

ns.RegisterSyncExclusions("EllesmereUIMythicTimer", {
	"standalonePos", "scale", "frameWidth",
	"tsb.pos", "tsb.width", "tsb.height",
	"tfb.*.pos", "tfb.*.width", "tfb.*.height",
	"runSummary.position",
})

-- QoL positions (Secondary Stats, FPS, cursor slice, alerts) stay per profile.
ns.RegisterSyncExclusions("EllesmereUIQoL", {
	"secondaryStatsPos", "fpsPos",
	"cursor.gcd.pos", "cursor.castCircle.pos",
	"battleRes.pos", "bloodlust.pos",
	"movementAlert.pos", "movementAlert.tsPos",
	"raidTools.pos", "raidTools.compactWidth", "raidTools.compactHeight",
	"selfCombatText.pos",
})

ns.RegisterSyncExclusions("EllesmereUIMinimap", {
	"profile.minimap.position",     -- unlock-element drag position
	"profile.minimap.btnPositions", -- per-button shift-drag offsets
})

ns.RegisterSyncExclusions("EllesmereUIChat", {
	"profile.chatPos",              -- unlock drag position
	"profile.chat.iconPositions",   -- per-sidebar-icon shift-drag offsets
})

ns.RegisterSyncExclusions("EllesmereUIDamageMeters", {
	"dm.standaloneTimerPos",
	"dm.windows.*.position", "dm.windows.*.width", "dm.windows.*.height",
	"spellHistory.iconPos", "spellHistory.barPos", "spellHistory.barWidth",
})

ns.RegisterSyncExclusions("EllesmereUIDataBars", {
	"profile.bars.*.savedPos",
	"profile.bars.*.length",
	"profile.bars.*.thickness",
	"profile.bars.*.snapEdge",
})

ns.RegisterSyncExclusions("EllesmereUIBags", {
	"profile.bagsPosition", "profile.bankPosition",
})

ns.RegisterSyncExclusions("EllesmereUIBlizzardSkin", { "tooltipFixedPos" })

ns.RegisterSyncExclusions("EllesmereUITopBar", {
	"pos",
	"qol.coTank.point", "qol.coTank.x", "qol.coTank.y", "qol.coTank.width", "qol.coTank.height",
	"qol.stealth.point", "qol.stealth.x", "qol.stealth.y", "qol.stealth.width", "qol.stealth.height",
	"qol.stealth.stancePoint", "qol.stealth.stanceX", "qol.stealth.stanceY",
	"qol.stealth.stanceWidth", "qol.stealth.stanceHeight",
})

ns.RegisterSyncExclusions("EllesmereUIInterruptTracker", { "point", "width" })
ns.RegisterSyncExclusions("EllesmereUIQuestTracker", { "pos" })
ns.RegisterSyncExclusions("EllesmereUIReforge", {
	"windowX", "windowY", "windowWidth", "windowHeight", "methodWindowX", "methodWindowY",
})

-- Modules whose Mists SavedVariables keep the retail profile blob under
-- "profile" (retail override paths need that prefix here).
local PROFILE_ROOT = {
	EllesmereUIActionBars = true, EllesmereUIRaidFrames = true, EllesmereUINameplates = true,
	EllesmereUIResourceBars = true, EllesmereUIBags = true, EllesmereUIDataBars = true,
	EllesmereUIChat = true, EllesmereUIMinimap = true, EllesmereUIAuraBuffReminders = true,
	EllesmereUICooldownManager = true,
}

-- Retail _SyncExclusionsWithOverrides: settings a spec / condition override
-- owns never sync (either profile's override store). Store entries:
-- { values = { [anyKey] = { [fkey] = value } } }, fkey = folder .. "\31" ..
-- path with "\30" between segments (retail). Stores are read from the
-- stored profile (prof.specOverrides / prof.condOverrides) or, when the
-- Spec Overrides port provides it, ns.SyncOverrideStores(profileName).
local function OverrideStores(profileName)
	if ns.SyncOverrideStores then
		local ok, list = pcall(ns.SyncOverrideStores, profileName)
		if ok and type(list) == "table" then
			return list
		end
	end
	local prof = type(DB().profiles) == "table" and DB().profiles[profileName]
	if type(prof) ~= "table" then
		return {}
	end
	return { prof.specOverrides, prof.condOverrides }
end

local function OverridePaths(folder, profileName, out)
	for _, store in pairs(OverrideStores(profileName)) do
		if type(store) == "table" then
			for _, entry in pairs(store) do
				local vals = type(entry) == "table" and entry.values
				if type(vals) == "table" then
					for _, m in pairs(vals) do
						if type(m) == "table" then
							for fkey in pairs(m) do
								if type(fkey) == "string" then
									local f, path = fkey:match("^([^\31]+)\31(.*)$")
									if f == folder and path and path ~= "" then
										path = path:gsub("\30", ".")
										if PROFILE_ROOT[folder] and path:sub(1, 8) ~= "profile." then
											path = "profile." .. path
										end
										out[path] = true
									end
								end
							end
						end
					end
				end
			end
		end
	end
end

-- Exclusion patterns for one copy: static list + private data + override
-- paths of both profiles. Returns a list of segment lists.
local function Patterns(folder, srcName, dstName)
	local set = {}
	for k in pairs(syncExclusions[folder] or {}) do
		set[k] = true
	end
	for _, k in ipairs(ns.PROFILE_PRIVATE and ns.PROFILE_PRIVATE[folder] or {}) do
		set[k] = true
	end
	pcall(OverridePaths, folder, srcName, set)
	pcall(OverridePaths, folder, dstName, set)
	local list = {}
	for path in pairs(set) do
		local segs = {}
		for seg in path:gmatch("[^%.]+") do
			segs[#segs + 1] = seg
		end
		list[#list + 1] = segs
	end
	return list
end
ns._SyncPatterns = Patterns

-- Makes dst equal to src except at excluded paths, which keep dst's values
-- (also when src lacks the key). Writes dst in place.
local function Mirror(src, dst, patterns)
	local function Split(k)
		local excluded, rest = false, nil
		local ks = tostring(k)
		for _, p in ipairs(patterns) do
			if p[1] == "*" or p[1] == ks then
				if #p == 1 then
					excluded = true
				else
					rest = rest or {}
					local sub = {}
					for i = 2, #p do
						sub[#sub + 1] = p[i]
					end
					rest[#rest + 1] = sub
				end
			end
		end
		return excluded, rest
	end
	for k, v in pairs(src) do
		local excluded, rest = Split(k)
		if not excluded then
			if type(v) == "table" and rest then
				if type(dst[k]) ~= "table" then
					dst[k] = {}
				end
				Mirror(v, dst[k], rest)
			else
				dst[k] = DeepCopy(v)
			end
		end
	end
	local gone = {}
	for k in pairs(dst) do
		if src[k] == nil then
			gone[#gone + 1] = k
		end
	end
	for _, k in ipairs(gone) do
		local excluded, rest = Split(k)
		if not excluded then
			if rest and type(dst[k]) == "table" then
				Mirror({}, dst[k], rest)
				if next(dst[k]) == nil then
					dst[k] = nil
				end
			else
				dst[k] = nil
			end
		end
	end
end
ns._SyncMirror = Mirror

---------------------------------------------------------------------------
-- Groups
---------------------------------------------------------------------------
function ns.GetSyncedProfiles(folder)
	local g = Groups()[folder]
	return type(g) == "table" and g or {}
end

function ns.IsProfileSynced(folder, profileName)
	return ns.GetSyncedProfiles(folder)[profileName] == true
end

function ns.IsModuleSynced(folder)
	return next(ns.GetSyncedProfiles(folder)) ~= nil
end

local function StoredBlob(name, folder, create)
	local profiles = DB().profiles
	local prof = type(profiles) == "table" and profiles[name]
	if type(prof) ~= "table" or prof.live then
		return nil
	end
	if type(prof.addons) ~= "table" then
		if not create then
			return nil
		end
		prof.addons = {}
	end
	if type(prof.addons[folder]) ~= "table" and create then
		prof.addons[folder] = {}
	end
	return prof.addons[folder]
end

-- Copies src (a module's settings) into every other member's stored profile.
local function PushTo(folder, src, srcName, targets)
	for name in pairs(targets) do
		if name ~= srcName then
			local dst = StoredBlob(name, folder, true)
			if dst then
				Mirror(src, dst, Patterns(folder, srcName, name))
			end
		end
	end
end

-- The live settings of a loaded module (without private data).
local function LiveBlob(folder)
	local entry = ns.ProfileAddonEntry(folder)
	if not entry or not ns.IsProfileAddonLoaded(folder) or type(_G[entry.svName]) ~= "table" then
		return nil
	end
	local copy = DeepCopy(_G[entry.svName])
	local patterns = {}
	for _, path in ipairs(ns.PROFILE_PRIVATE[folder] or {}) do
		local segs = {}
		for seg in path:gmatch("[^%.]+") do
			segs[#segs + 1] = seg
		end
		patterns[#patterns + 1] = segs
	end
	if #patterns > 0 then
		-- Mirror into an empty table drops the private paths.
		local clean = {}
		Mirror(copy, clean, patterns)
		return clean
	end
	return copy
end

-- Pushes every group the profile is a member of. The source is the live
-- settings for the active profile, else the stored ones.
function ns.SyncPushFrom(srcName)
	local active = ns.GetActiveProfileName()
	for folder, targets in pairs(Groups()) do
		if type(targets) == "table" and targets[srcName] then
			local src
			if srcName == active then
				src = LiveBlob(folder)
			else
				src = StoredBlob(srcName, folder, false)
			end
			if type(src) == "table" then
				PushTo(folder, src, srcName, targets)
			end
		end
	end
end

-- Equalizes a module across a group from one member ("seed"). Returns true
-- when the live (active) settings changed: a reload is needed.
function ns.SyncModuleFromProfile(folder, srcName, targets)
	local active = ns.GetActiveProfileName()
	local src
	if srcName == active then
		src = LiveBlob(folder)
	else
		src = StoredBlob(srcName, folder, false)
	end
	if type(src) ~= "table" then
		return false
	end
	src = DeepCopy(src)
	PushTo(folder, src, srcName, targets)
	if srcName ~= active and targets[active] then
		local entry = ns.ProfileAddonEntry(folder)
		local live = entry and ns.IsProfileAddonLoaded(folder) and _G[entry.svName]
		if type(live) == "table" then
			-- In place: the module keeps its table until the reload.
			Mirror(src, live, Patterns(folder, srcName, active))
			return true
		end
	end
	return false
end

---------------------------------------------------------------------------
-- Profile follow-up: rename / delete keep the groups right; the outgoing
-- profile pushes before a switch; the active one at logout / reload.
---------------------------------------------------------------------------
local refreshFns = {}
local function RefreshIcons()
	for _, fn in ipairs(refreshFns) do
		fn()
	end
end
ns.RefreshSyncIcons = RefreshIcons

if ns.RegisterProfileHook then
	ns.RegisterProfileHook("rename", function(oldName, newName)
		for _, targets in pairs(Groups()) do
			if type(targets) == "table" and targets[oldName] then
				targets[oldName] = nil
				targets[newName] = true
			end
		end
	end)
	ns.RegisterProfileHook("delete", function(name)
		for folder, targets in pairs(Groups()) do
			if type(targets) == "table" then
				targets[name] = nil
				-- A group of one is no group.
				local n = 0
				for _ in pairs(targets) do
					n = n + 1
				end
				if n < 2 then
					Groups()[folder] = nil
				end
			end
		end
	end)
	ns.RegisterProfileHook("leave", function(name)
		ns.SyncPushFrom(name)
	end)
	ns.RegisterProfileHook("change", RefreshIcons)
end

local logout = CreateFrame("Frame")
logout:RegisterEvent("PLAYER_LOGOUT")
logout:SetScript("OnEvent", function()
	if type(EllesmereUIDB) == "table" and type(EllesmereUIDB.syncedModules) == "table" then
		ns.SyncPushFrom(ns.GetActiveProfileName())
	end
end)

---------------------------------------------------------------------------
-- Sync popup: flush right of the sidebar, centered on the clicked sync
-- icon. One toggle row per profile; the button creates, updates or
-- disbands the group. New members: a confirm asks which profile the group
-- starts from (retail seed picker).
---------------------------------------------------------------------------
local SYNC_ICON = ns.MEDIA .. "icons\\sync"
local SYNC_ON = { 0x32 / 255, 0xbc / 255, 0x53 / 255 }

local syncPopup, seedFrame

local function MakeToggle(parent, get, set)
	local tg = CreateFrame("Button", nil, parent)
	tg:SetSize(30, 15)
	local track = Kit.Solid(tg, "BACKGROUND", 1, 1, 1, 0.12)
	track:SetAllPoints()
	local knob = Kit.Solid(tg, "ARTWORK", 1, 1, 1, 0.9)
	knob:SetSize(11, 11)
	function tg:Snap(on)
		knob:ClearAllPoints()
		if on then
			local r, g, b = Kit.Accent()
			track:SetTexture(r, g, b, 0.75)
			knob:SetPoint("RIGHT", tg, "RIGHT", -2, 0)
		else
			track:SetTexture(1, 1, 1, 0.12)
			knob:SetPoint("LEFT", tg, "LEFT", 2, 0)
		end
	end
	tg:SetScript("OnClick", function(self)
		set(not get())
		self:Snap(get())
	end)
	tg:Snap(get())
	return tg
end

-- Fresh content frame on a recycled shell (5.4.8 cannot unparent regions
-- reliably, so the content frame is replaced instead).
local function NewContent(shell)
	if shell.content then
		shell.content:Hide()
	end
	local c = CreateFrame("Frame", nil, shell)
	c:SetAllPoints()
	shell.content = c
	return c
end

local function ShowSeedConfirm(opts)
	if not seedFrame then
		local dimmer, box = Kit.Dimmer(nil, 40)
		box:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
		seedFrame = dimmer
	end
	local dimmer, box = seedFrame, seedFrame.box
	local W, PAD = 360, 18
	local c = NewContent(box)
	local cy = -PAD

	local title = Kit.Text(c, 14, 1, 1, 1, 0.9)
	title:SetPoint("TOP", c, "TOP", 0, cy)
	title:SetText(opts.hadGroup and "Update Sync Group" or "Create Sync Group")
	cy = cy - 30

	local msg = Kit.Text(c, 11, 1, 1, 1, 0.6)
	msg:SetPoint("TOP", c, "TOP", 0, cy)
	msg:SetWidth(W - PAD * 2)
	msg:SetJustifyH("CENTER")
	msg:SetText(format("All selected profiles will keep their %s settings in sync: changes made on any of them carry over to the others. Choose which profile's settings the group starts from.", opts.displayName))
	cy = cy - (msg:GetStringHeight() or 42) - 14

	local ddLabel = Kit.Text(c, 11, 1, 1, 1, 0.5)
	ddLabel:SetPoint("TOP", c, "TOP", 0, cy)
	ddLabel:SetText("Sync settings from:")
	cy = cy - 22

	-- "Dropdown": the chosen profile; a click opens the member list.
	local seed = opts.defaultSeed
	local dd = Kit.Button(c, 190, 26, "", false, 12)
	dd:SetPoint("TOP", c, "TOP", 0, cy)
	local arrow = Kit.Text(dd, 12, 1, 1, 1, 0.5)
	arrow:SetPoint("RIGHT", dd, "RIGHT", -8, 0)
	arrow:SetText("v")
	local function Label()
		dd.label:SetText(seed or "")
	end
	Label()
	local list = CreateFrame("Frame", nil, c)
	list:SetFrameLevel(dd:GetFrameLevel() + 10)
	list:SetPoint("TOP", dd, "BOTTOM", 0, -2)
	list:SetSize(190, #opts.memberOrder * 22 + 4)
	Kit.Solid(list, "BACKGROUND", 0.103, 0.095, 0.088, 0.98):SetAllPoints()
	Kit.Border(list, 1, 1, 1, 0.20)
	list:EnableMouse(true)
	list:Hide()
	for i, name in ipairs(opts.memberOrder) do
		local item = CreateFrame("Button", nil, list)
		item:SetSize(188, 22)
		item:SetPoint("TOPLEFT", list, "TOPLEFT", 1, -2 - (i - 1) * 22)
		local hl = Kit.Solid(item, "ARTWORK", 1, 1, 1, 0)
		hl:SetAllPoints()
		local lbl = Kit.Text(item, 12, 0.55, 0.60, 0.65, 1)
		lbl:SetPoint("LEFT", item, "LEFT", 10, 0)
		lbl:SetText(name)
		item:SetScript("OnEnter", function() hl:SetTexture(1, 1, 1, 0.08); lbl:SetTextColor(1, 1, 1, 1) end)
		item:SetScript("OnLeave", function() hl:SetTexture(1, 1, 1, 0); lbl:SetTextColor(0.55, 0.60, 0.65, 1) end)
		item:SetScript("OnClick", function()
			seed = name
			Label()
			list:Hide()
		end)
	end
	dd:SetScript("OnClick", function()
		list:SetShown(not list:IsShown())
	end)
	cy = cy - 26 - 14

	if opts.hasWarning then
		local warn = Kit.Text(c, 10, 0.92, 0.3, 0.3, 1)
		warn:SetPoint("TOP", c, "TOP", 0, cy)
		warn:SetWidth(W - PAD * 2)
		warn:SetJustifyH("CENTER")
		warn:SetText("Position and size settings are not synced and keep each profile's own values.")
		cy = cy - (warn:GetStringHeight() or 26) - 14
	end
	if opts.reloads then
		local note = Kit.Text(c, 10, 1, 1, 1, 0.45)
		note:SetPoint("TOP", c, "TOP", 0, cy)
		note:SetWidth(W - PAD * 2)
		note:SetJustifyH("CENTER")
		note:SetText("Starting from another profile changes your active profile: your UI reloads.")
		cy = cy - (note:GetStringHeight() or 26) - 14
	end

	local cancel = Kit.Button(c, 120, 26, "Cancel", false, 10)
	cancel:SetPoint("TOPRIGHT", c, "TOP", -6, cy)
	local confirm = Kit.Button(c, 120, 26, "Sync", true, 10)
	confirm:SetPoint("TOPLEFT", c, "TOP", 6, cy)
	cy = cy - 26

	box:SetSize(W, -cy + PAD)

	dimmer.onClose = opts.onCancel
	cancel:SetScript("OnClick", function()
		dimmer.Dismiss()
	end)
	confirm:SetScript("OnClick", function()
		dimmer:Hide()
		Groups()[opts.folder] = opts.targets
		local reload = seed and ns.SyncModuleFromProfile(opts.folder, seed, opts.targets)
		if opts.onDone then
			opts.onDone()
		end
		if reload and ns.ShowConfirmPopup then
			ns.ShowConfirmPopup({
				title = "Reload Required",
				message = format("Your active profile now has the %s settings of \"%s\". A UI reload is needed to apply them.", opts.displayName, seed),
				confirmText = "Reload Now",
				cancelText = "Later",
				reload = true,
			})
		end
	end)
	dimmer:Show()
end

function ns.CloseSyncPopup()
	if syncPopup then
		syncPopup:Hide()
	end
	if seedFrame then
		seedFrame:Hide()
	end
end

function ns.OpenSyncPopup(folder, displayName, anchorBtn)
	if seedFrame then
		seedFrame:Hide()
	end
	if syncPopup and syncPopup:IsShown() and syncPopup.folder == folder then
		syncPopup:Hide()
		return
	end
	local active = ns.GetActiveProfileName()
	local allProfiles = ns.GetProfileNames()
	if #allProfiles <= 1 then
		Kit.ShowTip(anchorBtn, "No other profiles to sync to")
		return
	end

	local POPUP_W, PAD, ROW_H, ROW_GAP, HEADER_H, SUBTITLE_H = 300, 16, 30, 2, 26, 30
	local popupH = PAD + HEADER_H + 7 + SUBTITLE_H + 14 + #allProfiles * (ROW_H + ROW_GAP) - ROW_GAP + 16 + 30 + PAD

	if not syncPopup then
		syncPopup = CreateFrame("Frame", nil, UIParent)
		syncPopup:SetFrameStrata("FULLSCREEN_DIALOG")
		syncPopup:SetFrameLevel(20)
		syncPopup:EnableMouse(true)
		Kit.Solid(syncPopup, "BACKGROUND", 17 / 255, 15 / 255, 12 / 255, 1):SetAllPoints()
		Kit.Border(syncPopup, 1, 1, 1, 0.15)
		syncPopup:Hide()
		-- Click away closes (retail OnUpdate poll).
		syncPopup:SetScript("OnUpdate", function(self)
			if IsMouseButtonDown("LeftButton") and not self:IsMouseOver()
				and not (self.anchor and self.anchor:IsMouseOver())
				and not (seedFrame and seedFrame:IsShown()) then
				self:Hide()
			end
		end)
	end
	local popup = syncPopup
	popup.folder = folder
	popup.anchor = anchorBtn
	popup:SetSize(POPUP_W, popupH)
	popup:ClearAllPoints()
	-- The sidebar row spans the sidebar: its right edge is the sidebar's.
	local row = anchorBtn and anchorBtn:GetParent()
	if row then
		popup:SetPoint("LEFT", row, "RIGHT", 0, 0)
	else
		popup:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
	end
	popup:SetClampedToScreen(true)
	local c = NewContent(popup)
	local r, g, b = Kit.Accent()

	local cy = -PAD
	local icon = c:CreateTexture(nil, "ARTWORK")
	icon:SetSize(19, 19)
	icon:SetPoint("TOPLEFT", c, "TOPLEFT", PAD - 1, cy + 1)
	icon:SetTexture(SYNC_ICON)
	if ns.IsModuleSynced(folder) then
		icon:SetVertexColor(r, g, b, 1)
	else
		icon:SetVertexColor(0.55, 0.55, 0.55, 1)
	end
	local title = Kit.Text(c, 14, 1, 1, 1, 0.9)
	title:SetPoint("TOP", c, "TOP", 0, cy - 1)
	title:SetText(format("%s Sync", displayName))
	cy = cy - HEADER_H - 7

	local subtitle = Kit.Text(c, 10, 1, 1, 1, 0.45)
	subtitle:SetPoint("TOP", c, "TOP", 0, cy)
	subtitle:SetWidth(POPUP_W - PAD * 2)
	subtitle:SetJustifyH("CENTER")
	subtitle:SetText("Syncing allows you to auto update all profiles whenever you change settings. This can be enabled per module.")
	cy = cy - SUBTITLE_H - 14

	local currentSynced = ns.GetSyncedProfiles(folder)
	local hadGroup = next(currentSynced) ~= nil
	local toggleState = {}
	local RefreshButton
	local accentHex = format("%02x%02x%02x", floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))

	for _, name in ipairs(allProfiles) do
		local rowBtn = CreateFrame("Button", nil, c)
		rowBtn:SetSize(POPUP_W - PAD * 2, ROW_H)
		rowBtn:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, cy)
		local rowBg = Kit.Solid(rowBtn, "BACKGROUND", 1, 1, 1, 0.05)
		rowBg:SetAllPoints()
		toggleState[name] = currentSynced[name] == true
		local tg = MakeToggle(rowBtn,
			function() return toggleState[name] end,
			function(v)
				toggleState[name] = v
				RefreshButton()
			end)
		tg:SetPoint("RIGHT", rowBtn, "RIGHT", -10, 0)
		rowBtn:SetScript("OnClick", function()
			toggleState[name] = not toggleState[name]
			tg:Snap(toggleState[name])
			RefreshButton()
		end)
		rowBtn:SetScript("OnEnter", function() rowBg:SetTexture(1, 1, 1, 0.08) end)
		rowBtn:SetScript("OnLeave", function() rowBg:SetTexture(1, 1, 1, 0.05) end)
		local lbl = Kit.Text(rowBtn, 12, 1, 1, 1, 0.85)
		lbl:SetPoint("LEFT", rowBtn, "LEFT", 10, 0)
		lbl:SetText(name == active and (name .. " |cff" .. accentHex .. "(active)|r") or name)
		cy = cy - ROW_H - ROW_GAP
	end
	cy = cy - (16 - ROW_GAP)

	local syncBtn = CreateFrame("Button", nil, c)
	syncBtn:SetSize(POPUP_W - PAD * 2, 30)
	syncBtn:SetPoint("TOP", c, "TOP", 0, cy)
	local sBg = Kit.Solid(syncBtn, "BACKGROUND", 1, 1, 1, 0.03)
	sBg:SetAllPoints()
	local sBrd = Kit.Border(syncBtn, r, g, b, 0.7)
	local sLbl = Kit.Text(syncBtn, 11, 1, 1, 1, 1)
	sLbl:SetPoint("CENTER")

	local function ApplyBtnState(dirty)
		syncBtn.dirty = dirty
		if dirty then
			sBg:SetTexture(r, g, b, 0.08)
			sBrd:SetColor(r, g, b, 0.7)
			sLbl:SetTextColor(r, g, b, 1)
		else
			sBg:SetTexture(1, 1, 1, 0.03)
			sBrd:SetColor(1, 1, 1, 0.15)
			sLbl:SetTextColor(1, 1, 1, 0.35)
		end
	end
	syncBtn:SetScript("OnEnter", function()
		if syncBtn.dirty then
			sBg:SetTexture(r, g, b, 0.18)
		end
	end)
	syncBtn:SetScript("OnLeave", function()
		ApplyBtnState(syncBtn.dirty)
		Kit.HideTip()
	end)
	RefreshButton = function()
		local count, dirty = 0, false
		for name, v in pairs(toggleState) do
			if v then
				count = count + 1
			end
			if v ~= (currentSynced[name] == true) then
				dirty = true
			end
		end
		if hadGroup and count == 0 then
			sLbl:SetText("Disband Sync Group")
		elseif hadGroup then
			sLbl:SetText("Update Sync Group")
		else
			sLbl:SetText("Create Sync Group")
		end
		ApplyBtnState(dirty)
	end
	RefreshButton()

	syncBtn:SetScript("OnClick", function()
		if not syncBtn.dirty then
			return
		end
		local targets, count, anyNew = {}, 0, false
		for name, on in pairs(toggleState) do
			if on then
				targets[name] = true
				count = count + 1
				if not currentSynced[name] then
					anyNew = true
				end
			end
		end
		if count == 0 then
			Groups()[folder] = nil
			popup:Hide()
			RefreshIcons()
			return
		end
		if count == 1 then
			Kit.ShowTip(syncBtn, "A sync group needs at least two profiles")
			return
		end
		if not anyNew then
			-- Only removals: nothing is overwritten, no confirm.
			Groups()[folder] = targets
			popup:Hide()
			RefreshIcons()
			return
		end
		local memberOrder = {}
		for _, name in ipairs(allProfiles) do
			if targets[name] then
				memberOrder[#memberOrder + 1] = name
			end
		end
		local defaultSeed
		if hadGroup then
			for _, name in ipairs(memberOrder) do
				if currentSynced[name] then
					defaultSeed = name
					break
				end
			end
		end
		defaultSeed = defaultSeed or (targets[active] and active) or memberOrder[1]
		ShowSeedConfirm({
			folder = folder,
			displayName = displayName,
			targets = targets,
			memberOrder = memberOrder,
			defaultSeed = defaultSeed,
			hadGroup = hadGroup,
			hasWarning = next(syncExclusions[folder] or {}) ~= nil,
			reloads = targets[active] and true or false,
			onDone = function()
				popup:Hide()
				RefreshIcons()
			end,
			onCancel = function()
				popup:Hide()
			end,
		})
	end)
	popup:Show()
end

---------------------------------------------------------------------------
-- Sidebar sync icon (EllesmereUIOptions CreateModuleRow calls this for every
-- module row). Green: the active profile is in this module's group; dim
-- white otherwise. Hidden when the module is not loaded or there is only
-- one profile.
---------------------------------------------------------------------------
local KEY_FOLDERS = {
	actionBars = "EllesmereUIActionBars", nameplates = "EllesmereUINameplates",
	unitFrames = "EllesmereUIUnitFrames", raidFrames = "EllesmereUIRaidFrames",
	resourceBars = "EllesmereUIResourceBars", qol = "EllesmereUIQoL",
	bags = "EllesmereUIBags", questTracker = "EllesmereUIQuestTracker",
	minimap = "EllesmereUIMinimap", damageMeters = "EllesmereUIDamageMeters",
	chat = "EllesmereUIChat", dataBars = "EllesmereUIDataBars",
	blizzardSkins = "EllesmereUIBlizzardSkin", topBar = "EllesmereUITopBar",
	interrupts = "EllesmereUIInterruptTracker", reforge = "EllesmereUIReforge",
	cdm = "EllesmereUICooldownManager", auraBuff = "EllesmereUIAuraBuffReminders",
	friends = "EllesmereUIFriends", EllesmereUIMythicTimer = "EllesmereUIMythicTimer",
	quickdraw = "EllesmereUIQuickdraw",
}

function ns.AttachSidebarSync(row, def)
	local folder = def and (def.syncFolder or KEY_FOLDERS[def.key])
	local entry = folder and ns.ProfileAddonEntry(folder)
	if not entry then
		return
	end
	local display = entry.display
	local btn = CreateFrame("Button", nil, row)
	btn:SetSize(15, 15)
	btn:SetPoint("RIGHT", row, "RIGHT", -20, 0)
	btn:SetFrameLevel(row:GetFrameLevel() + 5)
	local tex = btn:CreateTexture(nil, "ARTWORK")
	tex:SetAllPoints()
	tex:SetTexture(SYNC_ICON)
	local function Refresh()
		if not ns.IsProfileAddonLoaded(folder) or #ns.GetProfileNames() <= 1 then
			btn:Hide()
			return
		end
		btn:Show()
		if ns.IsProfileSynced(folder, ns.GetActiveProfileName()) then
			tex:SetVertexColor(SYNC_ON[1], SYNC_ON[2], SYNC_ON[3], 1)
		else
			tex:SetVertexColor(1, 1, 1, 0.5)
		end
	end
	btn:SetScript("OnEnter", function(self)
		local synced = ns.IsProfileSynced(folder, ns.GetActiveProfileName())
		if synced then
			tex:SetVertexColor(min(1, SYNC_ON[1] * 1.25), min(1, SYNC_ON[2] * 1.25), min(1, SYNC_ON[3] * 1.25), 1)
		else
			tex:SetVertexColor(1, 1, 1, 1)
		end
		Kit.ShowTip(self, synced and "Profile Synced" or ("Sync " .. display))
	end)
	btn:SetScript("OnLeave", function()
		Refresh()
		Kit.HideTip()
	end)
	btn:SetScript("OnClick", function(self)
		Kit.HideTip()
		ns.OpenSyncPopup(folder, display, self)
	end)
	row:HookScript("OnShow", Refresh)
	refreshFns[#refreshFns + 1] = Refresh
	Refresh()
	return btn
end
