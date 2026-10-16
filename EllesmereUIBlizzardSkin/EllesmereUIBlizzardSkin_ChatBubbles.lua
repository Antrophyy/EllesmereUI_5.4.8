-------------------------------------------------------------------------------
--  EllesmereUIBlizzardSkin_ChatBubbles.lua (5.4.8 port)
--  Chat Bubbles (chatBubbles.enabled, default off).
--
--  Like retail we ride on Blizzard's bubbles: their switches stay on, we hide
--  the bubble (alpha 0) and hang a styled frame of ours on it, which follows
--  the bubble over the speaker's head. What we draw is the bubble's own text.
--
--  5.4.8 differences from retail:
--   - No C_ChatBubbles: bubbles are unnamed children of WorldFrame, found by
--     their ChatBubble-Background texture (the classic method). The children
--     are only re-scanned when WorldFrame's child count changes, and the scan
--     only runs while a chat line waits for its bubble or a bubble is ours.
--   - Bubbles are never forbidden here, so ours also draw inside instances.
--     "Hide Chat Bubbles in Instances" still turns all bubbles off there.
--   - Blizzard has two switches: chatBubbles (say, yell, emote, NPC) and
--     chatBubblesParty (party and raid).
--   - No secret values.
--  ElvUI: stands down while ElvUI styles bubbles (E.private.general.chatBubbles).
--
--  Settings: EllesmereUIBlizzardSkinDB.chatBubbles (retail: profile.chatBubbles).
-------------------------------------------------------------------------------
local addonName = ...
local ns = EllesmereUI
local BS = ns.BlizzSkin
local WSkin = ns.WSkin

local floor, max, min = math.floor, math.max, math.min

local MIN_WIDTH = 40
local WHITE = BS.WHITE
local BUBBLE_TEX = "interface\\tooltips\\chatbubble-background"
-- How long a chat line waits for its bubble (seconds) and the scan step.
local SWEEP_STEP = 0.05
local LINE_TTL = 0.6

-- Blizzard's two bubble switches in 5.4.8.
local BLIZZ_CVARS = { "chatBubbles", "chatBubblesParty" }

-- Chat event -> the setting key that decides whether we draw it. Guild has
-- no bubbles. Instance chat sits with party.
local EVENT_CHANNEL = {
	CHAT_MSG_SAY = "say",
	CHAT_MSG_YELL = "yell",
	CHAT_MSG_PARTY = "party",
	CHAT_MSG_PARTY_LEADER = "party",
	CHAT_MSG_INSTANCE_CHAT = "party",
	CHAT_MSG_INSTANCE_CHAT_LEADER = "party",
	CHAT_MSG_RAID = "raid",
	CHAT_MSG_RAID_LEADER = "raid",
	CHAT_MSG_MONSTER_SAY = "npc",
	CHAT_MSG_MONSTER_YELL = "npc",
	CHAT_MSG_MONSTER_EMOTE = "npc",
	CHAT_MSG_MONSTER_PARTY = "npc",
	CHAT_MSG_MONSTER_WHISPER = "npc",
	CHAT_MSG_EMOTE = "emote",
}

local CB = {}
ns.ChatBubbles = CB
BS.ChatBubbles = CB

local DEFAULTS = {
	enabled = false,
	say = true, yell = true, party = true, raid = false, npc = true, emote = true,
	hideInInstances = false,
	padding = 8,
	maxWidth = 260,
	offsetY = 0,
	background = true,
	bgColor = { r = 0, g = 0, b = 0 },
	bgAlpha = 0.5,
	borderSize = 1,
	borderColor = { r = 0, g = 0, b = 0, a = 1 },
	-- "__global" = the Blizzard Skins module font; else a font file path.
	font = "__global",
	fontSize = 12,
	-- "__global" = the module outline; "none" = drop shadow; "outline"; "thick".
	outline = "__global",
	showName = {},
	nameAnchor = "TOPRIGHT",
	nameFontSize = 10,
	nameOffsetX = 0,
	nameOffsetY = 0,
	textColor = { r = 1, g = 1, b = 1 },
	followBlizzardColor = false,
}

function CB.Defaults()
	return DEFAULTS
end

local function DeepCopy(v)
	if type(v) ~= "table" then
		return v
	end
	local t = {}
	for k, x in pairs(v) do
		t[k] = DeepCopy(x)
	end
	return t
end

local filled = setmetatable({}, { __mode = "k" })
local function FillDefaults(t)
	if filled[t] then
		return t
	end
	filled[t] = true
	for k, v in pairs(DEFAULTS) do
		if t[k] == nil then
			t[k] = DeepCopy(v)
		end
	end
	return t
end

-- create = false answers nil while the feature was never touched.
function CB.DB(create)
	local root = BS.DB()
	local t = root.chatBubbles
	if type(t) ~= "table" then
		if not create then
			return nil
		end
		t = {}
		root.chatBubbles = t
	end
	return FillDefaults(t)
end

local function Cfg()
	return CB.DB(false) or DEFAULTS
end

-- ElvUI styles the bubbles itself unless its option is "disabled".
function CB.ElvUIOwns()
	local E = ElvUI and ElvUI[1]
	local g = E and E.private and E.private.general
	if not g then
		return false
	end
	return g.chatBubbles ~= nil and g.chatBubbles ~= "disabled"
end

local function Enabled()
	return Cfg().enabled == true and not CB.ElvUIOwns()
end

-------------------------------------------------------------------------------
--  Fonts
-------------------------------------------------------------------------------
local function FontPath(cfg)
	local key = cfg.font or DEFAULTS.font
	if key ~= "__global" and type(key) == "string" and key ~= "" then
		return key
	end
	return BS.FontPath() or STANDARD_TEXT_FONT
end

local function FontFlag(cfg)
	local mode = cfg.outline or DEFAULTS.outline
	if mode == "__global" then
		return BS.FontFlag() or ""
	end
	if mode == "outline" then
		return "OUTLINE"
	elseif mode == "thick" then
		return "THICKOUTLINE"
	end
	return ""
end

-- SetFont answers nil for a path that no longer resolves; fall back.
local function SafeSetFont(fs, path, size, flag)
	local ok, res = pcall(fs.SetFont, fs, path, size, flag)
	if not ok or res == false or not fs:GetFont() then
		fs:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, flag)
	end
	if flag == "" then
		fs:SetShadowOffset(1, -1)
		fs:SetShadowColor(0, 0, 0, 1)
	else
		fs:SetShadowOffset(0, 0)
	end
end

-------------------------------------------------------------------------------
--  Blizzard's bubble frames (children of WorldFrame)
-------------------------------------------------------------------------------
local known = {} -- list of bubble frames
local isBubble = setmetatable({}, { __mode = "k" }) -- frame -> true / false (checked)
local bubbleFS = setmetatable({}, { __mode = "k" }) -- frame -> its FontString
local seenAt = setmetatable({}, { __mode = "k" }) -- frame -> GetTime() it last appeared
local lastText = setmetatable({}, { __mode = "k" }) -- frame -> text when last looked at
local numChildren = 0

local function CheckBubble(frame)
	if isBubble[frame] ~= nil then
		return isBubble[frame]
	end
	local result = false
	local fs = nil
	if not (frame.GetName and frame:GetName()) and frame.GetRegions then
		local regions = { frame:GetRegions() }
		for i = 1, #regions do
			local r = regions[i]
			if r and r.IsObjectType then
				if r:IsObjectType("Texture") then
					local tex = r:GetTexture()
					if type(tex) == "string" and tex:lower() == BUBBLE_TEX then
						result = true
					end
				elseif r:IsObjectType("FontString") and not fs then
					fs = r
				end
			end
		end
	end
	if result and not fs then
		result = false
	end
	isBubble[frame] = result
	if result then
		bubbleFS[frame] = fs
	end
	return result
end

local HookBubble -- forward

-- New WorldFrame children only (the count grows as Blizzard builds bubbles).
local function ScanNew()
	local count = WorldFrame:GetNumChildren() or 0
	if count == numChildren then
		return
	end
	local kids = { WorldFrame:GetChildren() }
	for i = 1, #kids do
		local f = kids[i]
		if f and isBubble[f] == nil and CheckBubble(f) then
			known[#known + 1] = f
			HookBubble(f)
			if f:IsShown() then
				seenAt[f] = GetTime()
			end
		end
	end
	numChildren = count
end

local function BubbleText(frame)
	local fs = bubbleFS[frame]
	return fs and fs:GetText()
end

-------------------------------------------------------------------------------
--  Our frames
-------------------------------------------------------------------------------
local ours = {} -- Blizzard bubble -> our frame
local pool = {}
local pending = {} -- chat lines waiting for their bubble

local function NewBubble()
	local f = CreateFrame("Frame", nil, UIParent)
	f:SetFrameStrata("HIGH")
	f:SetFrameLevel(150)
	f:EnableMouse(false)
	f:Hide()
	f.bg = f:CreateTexture(nil, "BACKGROUND")
	f.bg:SetTexture(WHITE)
	f.bg:SetAllPoints(f)
	f.text = f:CreateFontString(nil, "ARTWORK")
	f.text:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 12, "")
	f.text:SetJustifyH("CENTER")
	f.text:SetJustifyV("MIDDLE")
	f.text:SetWordWrap(true)
	if f.text.SetNonSpaceWrap then
		f.text:SetNonSpaceWrap(true)
	end
	f.text:SetPoint("CENTER", f, "CENTER", 0, 0)
	f.name = f:CreateFontString(nil, "ARTWORK")
	f.name:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", 10, "")
	f.name:SetJustifyH("RIGHT")
	f.name:SetWordWrap(false)
	f.name:Hide()
	return f
end

local function Acquire()
	local f = table.remove(pool)
	if not f then
		f = NewBubble()
	end
	f.inUse = true
	return f
end

local function Release(f)
	if not f.inUse then
		return
	end
	f.inUse = false
	if f.outer then
		ours[f.outer] = nil
		f.outer = nil
	end
	f:ClearAllPoints()
	f:Hide()
	f.blizzR, f.blizzG, f.blizzB = nil, nil, nil
	f.speaker, f.channel, f.shownText = nil, nil, nil
	pool[#pool + 1] = f
end

-- Hand Blizzard's bubble back.
local function ReleaseBlizz(outer)
	local f = ours[outer]
	if not f then
		return
	end
	Release(f)
	outer:SetAlpha(1)
end

local function ReleaseAll()
	for outer in pairs(ours) do
		ReleaseBlizz(outer)
	end
end

-- Size the text: natural width capped at maxWidth, then the wrapped height.
local function MeasureText(fs, maxWidth)
	fs:SetWidth(maxWidth)
	local w = fs:GetStringWidth() or maxWidth
	if w > maxWidth then
		w = maxWidth
	end
	if w < MIN_WIDTH then
		w = MIN_WIDTH
	end
	w = floor(w + 0.5) + 1
	if w > maxWidth then
		w = maxWidth
	end
	fs:SetWidth(w)
	local h = fs:GetStringHeight() or 12
	if h < 1 then
		h = 1
	end
	return w, floor(h + 0.5) + 1
end

-- Appearance and geometry in one pass.
local function Layout(f, cfg)
	local d = DEFAULTS
	local bgc = cfg.bgColor or d.bgColor
	f.bg:SetVertexColor(bgc.r or 0, bgc.g or 0, bgc.b or 0,
		cfg.background == false and 0 or (cfg.bgAlpha or d.bgAlpha or 0))

	local bc = cfg.borderColor or d.borderColor
	local size = cfg.borderSize or d.borderSize or 0
	if size > 0 then
		local c = BS.PP.CreateBorder(f, bc.r or 0, bc.g or 0, bc.b or 0, bc.a or 1, size, "OVERLAY", 7)
		BS.PP.SetBorderColor(f, bc.r or 0, bc.g or 0, bc.b or 0, bc.a or 1)
		BS.PP.SetBorderSize(f, size)
		c:Show()
	else
		local c = BS.PP.GetBorder(f)
		if c then
			c:Hide()
		end
	end

	local path = FontPath(cfg)
	local flag = FontFlag(cfg)
	local fontSize = cfg.fontSize or d.fontSize or 12
	SafeSetFont(f.text, path, fontSize, flag)
	local tc = cfg.textColor or d.textColor
	local tr, tg, tb = tc.r or 1, tc.g or 1, tc.b or 1
	if cfg.followBlizzardColor == true and f.blizzR then
		tr, tg, tb = f.blizzR, f.blizzG, f.blizzB
	end
	f.text:SetTextColor(tr, tg, tb, 1)

	local nameW, nameH = 0, 0
	local names = cfg.showName
	if f.speaker and type(names) == "table" and names[f.channel] == true then
		local nameSize = cfg.nameFontSize or d.nameFontSize
		SafeSetFont(f.name, path, nameSize, flag)
		f.name:SetTextColor(tr, tg, tb, 0.8)
		f.name:SetText(f.speaker)
		nameW = floor((f.name:GetStringWidth() or 0) + 0.5) + 1
		nameH = nameSize + 2
		f.name:Show()
	else
		f.name:Hide()
	end

	local padding = cfg.padding or d.padding or 0
	local maxWidth = cfg.maxWidth or d.maxWidth or 260
	local w, h = MeasureText(f.text, maxWidth)
	if nameW > maxWidth then
		nameW = maxWidth
	end
	if nameW > w then
		w = nameW
	end
	local anchor = cfg.nameAnchor or d.nameAnchor
	local bottom = anchor:find("BOTTOM") ~= nil
	local nx = anchor:find("LEFT") and padding or (anchor:find("RIGHT") and -padding or 0)
	local ny = bottom and padding or -padding
	f.name:SetWidth(max(1, nameW))
	f.name:SetJustifyH(anchor:find("LEFT") and "LEFT" or (anchor:find("RIGHT") and "RIGHT" or "CENTER"))
	f.name:ClearAllPoints()
	f.name:SetPoint(anchor, f, anchor, nx + (cfg.nameOffsetX or 0), ny + (cfg.nameOffsetY or 0))
	f.text:ClearAllPoints()
	f.text:SetPoint("CENTER", f, "CENTER", 0, bottom and nameH / 2 or -nameH / 2)
	f:SetSize(w + padding * 2, h + nameH + padding * 2)
end

local function Anchor(f, cfg)
	f:ClearAllPoints()
	f:SetPoint("CENTER", f.outer, "CENTER", 0, cfg.offsetY or DEFAULTS.offsetY or 0)
end

-------------------------------------------------------------------------------
--  Claiming a bubble
-------------------------------------------------------------------------------
local function Claim(outer, text, line)
	local cfg = Cfg()
	local f = ours[outer]
	if not f then
		f = Acquire()
		f.outer = outer
		ours[outer] = f
	end
	local fs = bubbleFS[outer]
	if fs then
		f.blizzR, f.blizzG, f.blizzB = fs:GetTextColor()
	end
	f.speaker, f.channel = line.speaker, line.channel
	f.shownText = text
	lastText[outer] = text
	f.text:SetText(text)
	f:SetAlpha(0)
	f:Show()
	Layout(f, cfg)
	Anchor(f, cfg)
	f:SetAlpha(1)
	outer:SetAlpha(0)
end

-- Which waiting line this bubble shows (exact text first, then contains).
-- A bubble that has shown the same text since before the line came cannot be
-- the bubble of that line.
local function MatchPending(outer, text)
	if type(text) ~= "string" or text == "" then
		return nil
	end
	local fresh = lastText[outer] ~= text
	local at = seenAt[outer] or 0
	for pass = 1, 2 do
		for i = 1, #pending do
			local line = pending[i]
			if fresh or at >= line.at - 0.05 then
				if pass == 1 and text == line.text then
					return i
				elseif pass == 2 and text:find(line.text, 1, true) then
					return i
				end
			end
		end
	end
	return nil
end

local function TryClaim(outer)
	if #pending == 0 or not outer:IsShown() then
		return
	end
	local text = BubbleText(outer)
	local idx = MatchPending(outer, text)
	if idx then
		local line = table.remove(pending, idx)
		Claim(outer, text, line)
	end
end

local active = false
local suspended = false -- hidden in an instance (Hide Chat Bubbles in Instances)
local eventFrame
local ticking = false

local function StopTicker()
	if ticking then
		ticking = false
		eventFrame:SetScript("OnUpdate", nil)
	end
end

local Sweep -- forward

local acc = 0
local function OnUpdate(_, elapsed)
	acc = acc + elapsed
	if acc < SWEEP_STEP then
		return
	end
	acc = 0
	Sweep()
end

local function StartTicker()
	if not ticking and eventFrame then
		ticking = true
		acc = 0
		eventFrame:SetScript("OnUpdate", OnUpdate)
	end
end

function Sweep()
	if not active or suspended then
		wipe(pending)
		ReleaseAll()
		StopTicker()
		return
	end
	ScanNew()
	local now = GetTime()
	-- New bubbles for waiting lines.
	if #pending > 0 then
		for i = 1, #known do
			local outer = known[i]
			if not ours[outer] and outer:IsShown() then
				TryClaim(outer)
			end
		end
		for i = #pending, 1, -1 do
			if now - pending[i].at > LINE_TTL then
				table.remove(pending, i)
			end
		end
	end
	-- Our bubbles follow Blizzard's text; a bubble reused for a line we do not
	-- draw is handed back.
	for outer, f in pairs(ours) do
		if not outer:IsShown() then
			ReleaseBlizz(outer)
		else
			local text = BubbleText(outer)
			if text ~= f.shownText then
				local idx = MatchPending(outer, text)
				if idx then
					Claim(outer, text, table.remove(pending, idx))
				elseif #pending == 0 then
					ReleaseBlizz(outer)
				end
			end
		end
	end
	-- Remember what unclaimed bubbles show (see MatchPending).
	for i = 1, #known do
		local outer = known[i]
		if not ours[outer] then
			lastText[outer] = outer:IsShown() and BubbleText(outer) or nil
		end
	end
	if #pending == 0 and not next(ours) then
		StopTicker()
	end
end

local function OnBubbleShow(outer)
	seenAt[outer] = GetTime()
	if active and not suspended and #pending > 0 and not ours[outer] then
		TryClaim(outer)
	end
end

local function OnBubbleHide(outer)
	if ours[outer] then
		ReleaseBlizz(outer)
	end
	lastText[outer] = nil
end

local hooked = setmetatable({}, { __mode = "k" })
function HookBubble(outer)
	if hooked[outer] then
		return
	end
	hooked[outer] = true
	outer:HookScript("OnShow", OnBubbleShow)
	outer:HookScript("OnHide", OnBubbleHide)
end

-------------------------------------------------------------------------------
--  Blizzard's switches (CVars). The player's values are kept in memory only
--  and handed back when the feature is turned off and at logout.
-------------------------------------------------------------------------------
local savedCVars, heldCVars

local function InInstance()
	local inInst, iType = IsInInstance()
	return inInst and iType ~= "none" or false
end

local function RestoreCVars()
	if not savedCVars or not heldCVars then
		return
	end
	for _, name in ipairs(BLIZZ_CVARS) do
		if heldCVars[name] then
			heldCVars[name] = nil
			local prev = savedCVars[name]
			if prev and GetCVar(name) ~= prev then
				SetCVar(name, prev)
			end
		end
	end
end

local function ForgetCVars()
	savedCVars, heldCVars = nil, nil
end

local function ApplyCVar(name, target)
	savedCVars = savedCVars or {}
	heldCVars = heldCVars or {}
	local cur = GetCVar(name)
	if target then
		if not heldCVars[name] then
			savedCVars[name] = cur
			heldCVars[name] = true
		end
		if cur ~= target then
			SetCVar(name, target)
		end
	elseif heldCVars[name] then
		heldCVars[name] = nil
		local prev = savedCVars[name]
		if prev and cur ~= prev then
			SetCVar(name, prev)
		end
	end
end

local function AssertCVars()
	local cfg = Cfg()
	if not Enabled() then
		suspended = false
		RestoreCVars()
		ForgetCVars()
		return
	end
	local inInst = InInstance()
	suspended = inInst and cfg.hideInInstances == true
	if suspended then
		for _, name in ipairs(BLIZZ_CVARS) do
			ApplyCVar(name, "0")
		end
		return
	end
	local main = cfg.say == true or cfg.yell == true or cfg.npc == true or cfg.emote == true
	local group = cfg.party == true or cfg.raid == true
	ApplyCVar("chatBubbles", main and "1" or nil)
	ApplyCVar("chatBubblesParty", group and "1" or nil)
end

-------------------------------------------------------------------------------
--  Events
-------------------------------------------------------------------------------
local function OnEvent(_, event, ...)
	if event == "PLAYER_LOGOUT" then
		RestoreCVars()
		ForgetCVars()
		ReleaseAll()
		return
	end
	if event == "PLAYER_ENTERING_WORLD" then
		AssertCVars()
		if suspended then
			wipe(pending)
			ReleaseAll()
		end
		return
	end
	local channel = EVENT_CHANNEL[event]
	if not channel or suspended then
		return
	end
	local cfg = Cfg()
	if cfg[channel] ~= true then
		return
	end
	local text, sender = ...
	if type(text) ~= "string" or text == "" then
		return
	end
	local speaker = nil
	if type(sender) == "string" and sender ~= "" then
		speaker = Ambiguate and Ambiguate(sender, "short") or sender
	end
	pending[#pending + 1] = { text = text, at = GetTime(), speaker = speaker, channel = channel }
	-- The bubble may already exist (built before the event was dispatched).
	Sweep()
	if #pending > 0 or next(ours) then
		StartTicker()
	end
end

local CHAT_EVENTS = {}
for event in pairs(EVENT_CHANNEL) do
	CHAT_EVENTS[#CHAT_EVENTS + 1] = event
end
table.sort(CHAT_EVENTS)
local registeredChat = {}

local function EnsureFrame()
	if not eventFrame then
		eventFrame = CreateFrame("Frame")
		eventFrame:SetScript("OnEvent", OnEvent)
	end
	return eventFrame
end

local function SyncChatEvents(cfg)
	for i = 1, #CHAT_EVENTS do
		local event = CHAT_EVENTS[i]
		local want = cfg ~= nil and cfg[EVENT_CHANNEL[event]] == true
		if want ~= (registeredChat[event] == true) then
			if want then
				eventFrame:RegisterEvent(event)
				registeredChat[event] = true
			else
				eventFrame:UnregisterEvent(event)
				registeredChat[event] = nil
			end
		end
	end
end

local function SetActive(on)
	if not on then
		if not active then
			return
		end
		active = false
		eventFrame:UnregisterAllEvents()
		-- The hand-back at logout stays armed while we hold a switch.
		eventFrame:RegisterEvent("PLAYER_LOGOUT")
		wipe(registeredChat)
		wipe(pending)
		ReleaseAll()
		StopTicker()
		return
	end
	EnsureFrame()
	if not active then
		active = true
		eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
		eventFrame:RegisterEvent("PLAYER_LOGOUT")
		ScanNew()
	end
	SyncChatEvents(Cfg())
end

-------------------------------------------------------------------------------
--  Public entry points
-------------------------------------------------------------------------------
local preview, previewOnResize

local function UpdatePreview(force)
	if not preview or not (force or preview:IsVisible()) then
		return
	end
	local cfg = Cfg()
	local names = cfg.showName
	preview.channel = "say"
	preview.speaker = nil
	if type(names) == "table" and next(names) then
		preview.speaker = UnitName("player")
		for k, v in pairs(names) do
			if v == true then
				preview.channel = k
				break
			end
		end
	end
	Layout(preview, cfg)
	if previewOnResize then
		previewOnResize(preview:GetHeight())
	end
end

-- Options preview: one of our own frames, styled by the same Layout.
function CB.ShowPreview(parent, onResize)
	if not preview then
		preview = NewBubble()
		preview.text:SetText("The quick brown fox jumps over the lazy dog.")
	end
	preview:SetParent(parent)
	preview:SetFrameStrata(parent:GetFrameStrata())
	preview:SetFrameLevel(parent:GetFrameLevel() + 5)
	preview:ClearAllPoints()
	preview:SetPoint("CENTER", parent, "CENTER", 0, 0)
	preview:Show()
	previewOnResize = nil
	UpdatePreview(true)
	previewOnResize = onResize
	return preview
end

-- Appearance only: re-style what is on screen.
function CB.RefreshStyle()
	UpdatePreview()
	if not active or suspended then
		return
	end
	local cfg = Cfg()
	for _, f in pairs(ours) do
		Layout(f, cfg)
		Anchor(f, cfg)
	end
end

-- Party / raid ticks are seeded from Blizzard's party switch the first time
-- the feature is enabled.
local function SeedChannels(cfg)
	if not cfg or cfg.seeded == true then
		return
	end
	cfg.seeded = true
	local on = GetCVar("chatBubblesParty") == "1"
	cfg.party = on
	cfg.raid = on
end

-- Structural pass: whether we draw, which events, which switches we hold.
function CB.Refresh()
	UpdatePreview()
	local on = Enabled()
	if on then
		SeedChannels(CB.DB(false))
	end
	if on or active then
		SetActive(on)
	end
	AssertCVars()
	if not on then
		return
	end
	if suspended then
		wipe(pending)
		ReleaseAll()
		return
	end
	CB.RefreshStyle()
end

BS.OnLogin(function()
	CB.Refresh()
end)

-- Settings changes (Blizzard Skins apply) re-run the structural pass.
BS.OnApply(function()
	CB.Refresh()
end)
