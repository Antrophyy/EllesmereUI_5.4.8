-------------------------------------------------------------------------------
--  EllesmereUIChat_Text.lua  (5.4.8 port: the text parts of retail's
--  EllesmereUIChat_Engine.lua, EllesmereUIChat_SessionHistory.lua and the
--  module root)
--
--  Every chat frame's AddMessage goes through here: Shortened Channel Names,
--  Timestamp All Messages, the Copy Chat buffer, Remember Last Chat Lines and
--  the idle fade wake. Message filters add clickable URLs and Class Colored
--  Names. Also: Timestamps (showTimestamps CVar), Whisper Sound, link
--  tooltips on hover.
-------------------------------------------------------------------------------
local _, P = ...
local ns = EllesmereUI
local ECHAT = P.ECHAT
local DB = P.DB
local FD = P.FD

local floor, min, max = math.floor, math.min, math.max

local COPY_LINES = 500
local restoring = false

-------------------------------------------------------------------------------
--  Chat type ids (ChatTypeInfo[type].id, the 5th AddMessage argument)
-------------------------------------------------------------------------------
local function IdSet(types)
	local set = {}
	for _, t in ipairs(types) do
		local info = ChatTypeInfo and ChatTypeInfo[t]
		if info and info.id then
			set[info.id] = true
		end
	end
	return set
end

local CHANNEL_TYPES = {}
for i = 1, 10 do
	CHANNEL_TYPES[i] = "CHANNEL" .. i
end

local function WithChannels(list)
	for _, t in ipairs(CHANNEL_TYPES) do
		list[#list + 1] = t
	end
	return list
end

-- Player chat that wakes the idle fade (whispers wake it from their event).
local WAKE_TYPES = WithChannels({ "SAY", "YELL", "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING",
	"INSTANCE_CHAT", "INSTANCE_CHAT_LEADER", "GUILD", "OFFICER", "CHANNEL" })
-- Player chat, remembered even during the login grace period.
local CAPTURE_TYPES = WithChannels({ "SAY", "YELL", "EMOTE", "TEXT_EMOTE", "PARTY", "PARTY_LEADER", "GUILD", "OFFICER",
	"CHANNEL", "RAID", "RAID_LEADER", "RAID_WARNING", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER", "WHISPER",
	"WHISPER_INFORM", "BN_WHISPER", "BN_WHISPER_INFORM" })
local wakeIds, captureIds

local function Ids()
	if not wakeIds then
		wakeIds = IdSet(WAKE_TYPES)
		captureIds = IdSet(CAPTURE_TYPES)
	end
	return wakeIds, captureIds
end

local function IsCombatLogFrame(cf)
	if cf == _G.COMBATLOG then
		return true
	end
	if IsCombatLog then
		local ok, r = pcall(IsCombatLog, cf)
		if ok and r then
			return true
		end
	end
	return false
end

-------------------------------------------------------------------------------
--  Shortened Channel Names: on the channel link keyword, the label in the
--  client language (leader / guide variants keep their own letters).
-------------------------------------------------------------------------------
local abbrevOn, abbrevLetters = false, false

local function LeaderLabel(label, key)
	local s = _G[key]
	return s and label == s
end

local function ShortName(keyword, label)
	local k = keyword:upper()
	if k == "PARTY" then
		if LeaderLabel(label, "CHAT_MSG_PARTY_LEADER") then
			return "PL"
		elseif LeaderLabel(label, "CHAT_MSG_PARTY_GUIDE") then
			return "PG"
		end
		return "P"
	elseif k == "RAID" then
		if LeaderLabel(label, "CHAT_MSG_RAID_LEADER") then
			return "RL"
		end
		return "R"
	elseif k == "INSTANCE_CHAT" then
		if LeaderLabel(label, "CHAT_MSG_INSTANCE_CHAT_LEADER") then
			return "IL"
		end
		return "I"
	elseif k == "GUILD" then
		return "G"
	elseif k == "OFFICER" then
		return "O"
	elseif k == "BATTLEGROUND" then
		return "BG"
	end
	local num = keyword:match("^channel:(%d+)$")
	if num then
		if abbrevLetters then
			-- World channels by name ("2. Trade - City" -> T); others keep the number.
			local name = label:match("^%d+%.%s*(.-)%s*$") or label
			name = (name:gsub("%s%-%s.*", "")):lower():gsub("%s", "")
			local letters = ({ general = "Ge", trade = "T", localdefense = "LD", worlddefense = "WD",
				lookingforgroup = "LFG" })[name]
			if letters then
				return letters
			end
		end
		return num
	end
	return nil
end

local function AbbreviateChannelText(text)
	if not text:find("|Hchannel:", 1, true) then
		return text
	end
	return (text:gsub("|Hchannel:([^|]+)|h%[([^%]]*)%]|h", function(keyword, label)
		local short = ShortName(keyword, label)
		if not short then
			return nil
		end
		return "|Hchannel:" .. keyword .. "|h[" .. short .. "]|h"
	end))
end

function ECHAT.EngineSetChannelAbbrev(on)
	abbrevOn = on == true
end
function ECHAT.EngineSetChannelAbbrevLetters(on)
	abbrevLetters = on == true
end
-- Retail rebuilds its own message frames; Blizzard's keep what they showed.
function ECHAT.EngineQueueRebuildAll() end

-------------------------------------------------------------------------------
--  Timestamps
-------------------------------------------------------------------------------
local function HasTimestampPrefix(msg)
	return msg:find("^%d%d?:%d%d:%d%d%s*[AP]M%s") ~= nil
		or msg:find("^%d%d?:%d%d:%d%d%s") ~= nil
		or msg:find("^%d%d?:%d%d%s*[AP]M%s") ~= nil
		or msg:find("^%d%d?:%d%d%s") ~= nil
end

local function StripTimestampPrefix(msg)
	local rest = msg:match("^%d%d?:%d%d:%d%d%s*[AP]M%s+(.+)$")
		or msg:match("^%d%d?:%d%d:%d%d%s+(.+)$")
		or msg:match("^%d%d?:%d%d%s*[AP]M%s+(.+)$")
		or msg:match("^%d%d?:%d%d%s+(.+)$")
	return (rest and rest ~= "") and rest or msg
end

-- The format in use: ours, Blizzard's, or nil (none).
local function EffectiveFormat()
	local fmt = DB().timestampFormat or "%I:%M "
	if fmt == "none" then
		return nil
	elseif fmt == "__blizzard" then
		local f = CHAT_TIMESTAMP_FORMAT
		return (type(f) == "string" and f ~= "" and f ~= "none") and f or nil
	end
	return fmt
end

local function Stamp(fmt, when)
	local ok, ts = pcall(date, fmt, when and floor(when) or nil)
	if ok and type(ts) == "string" then
		return ts
	end
	return ""
end

-- Blizzard stamps player chat from the showTimestamps CVar (and its
-- CHAT_TIMESTAMP_FORMAT copy); "Use Blizzard Setting" leaves both alone.
function ECHAT.ApplyTimestampCVar()
	local fmt = DB().timestampFormat or "%I:%M "
	if fmt == "__blizzard" then
		return
	end
	if ns.SetCVarSafe then
		ns.SetCVarSafe("showTimestamps", fmt)
	else
		SetCVar("showTimestamps", fmt)
	end
	CHAT_TIMESTAMP_FORMAT = (fmt ~= "none") and fmt or nil
end

-------------------------------------------------------------------------------
--  Class Colored Names (names of group members in Say / Yell / Party / Raid
--  message text; sender names stay Blizzard's)
-------------------------------------------------------------------------------
local CCN_EVENTS = {
	"CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
	"CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
}
local ccnOn = false
local ROSTER = {}

local function RosterAdd(unit)
	if not UnitExists(unit) then
		return
	end
	local name = UnitName(unit)
	if type(name) ~= "string" or name == "" then
		return
	end
	local _, class = UnitClass(unit)
	local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
	if c then
		ROSTER[name:lower()] = format("ff%02x%02x%02x", floor(c.r * 255 + 0.5), floor(c.g * 255 + 0.5), floor(c.b * 255 + 0.5))
	end
end

local function RebuildRoster()
	wipe(ROSTER)
	if IsInRaid() then
		for i = 1, GetNumGroupMembers() do
			RosterAdd("raid" .. i)
		end
	else
		RosterAdd("player")
		for i = 1, 4 do
			RosterAdd("party" .. i)
		end
	end
end

local rosterFrame = CreateFrame("Frame")
rosterFrame:SetScript("OnEvent", function()
	P.After(0, RebuildRoster)
end)

function ECHAT.EngineSetClassColorNames(on)
	ccnOn = on == true
	if ccnOn then
		rosterFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
		rosterFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
		RebuildRoster()
	else
		rosterFrame:UnregisterAllEvents()
		wipe(ROSTER)
	end
end
function ECHAT.ApplyClassColorNames(on)
	ECHAT.EngineSetClassColorNames(on)
end

-- Escape spans the name scan never touches (colors, links incl. label,
-- textures, escaped pipes).
local function CollectProtected(text, ps, pe)
	local n, pos = 0, 1
	while true do
		local p = text:find("|", pos, true)
		if not p then
			break
		end
		local c = text:sub(p + 1, p + 1)
		local e = nil
		if c == "c" then
			e = p + 9
		elseif c == "r" then
			e = p + 1
		elseif c == "H" then
			local h1 = text:find("|h", p + 2, true)
			local h2 = h1 and text:find("|h", h1 + 2, true)
			e = (h2 and h2 + 1) or (h1 and h1 + 1) or (p + 1)
		elseif c == "T" then
			local close = text:find("|t", p + 2, true)
			e = (close and close + 1) or (p + 1)
		elseif c == "|" then
			e = p + 1
		else
			pos = p + 1
		end
		if e then
			n = n + 1
			ps[n] = p
			pe[n] = e
			pos = e + 1
		end
	end
	return n
end

local function IsBoundary(text, idx)
	if idx < 1 or idx > #text then
		return true
	end
	local b = text:byte(idx)
	if b >= 128 then
		return false
	end
	if (b >= 48 and b <= 57) or (b >= 65 and b <= 90) or (b >= 97 and b <= 122) then
		return false
	end
	return true
end

local function ColorRosterNames(text)
	if next(ROSTER) == nil then
		return text
	end
	local lower = text:lower()
	local ps, pe = {}, {}
	local nProt = CollectProtected(text, ps, pe)
	local hits = {}
	for nameLow, colorStr in pairs(ROSTER) do
		local from = 1
		while true do
			local s = lower:find(nameLow, from, true)
			if not s then
				break
			end
			local e = s + #nameLow - 1
			from = e + 1
			if IsBoundary(text, s - 1) and IsBoundary(text, e + 1) then
				local blocked = false
				for i = 1, nProt do
					if s <= pe[i] and e >= ps[i] then
						blocked = true
						break
					end
				end
				if not blocked then
					hits[#hits + 1] = { s = s, e = e, c = colorStr }
				end
			end
		end
	end
	if #hits == 0 then
		return text
	end
	table.sort(hits, function(a, b) return a.s < b.s end)
	local out, pos = {}, 1
	for _, h in ipairs(hits) do
		if h.s >= pos then
			out[#out + 1] = text:sub(pos, h.s - 1)
			out[#out + 1] = "|c" .. h.c .. text:sub(h.s, h.e) .. "|r"
			pos = h.e + 1
		end
	end
	out[#out + 1] = text:sub(pos)
	return table.concat(out)
end

local function CCNFilter(self, event, msg, ...)
	if not ccnOn or type(msg) ~= "string" then
		return false
	end
	local colored = ColorRosterNames(msg)
	if colored ~= msg then
		return false, colored, ...
	end
	return false
end

-------------------------------------------------------------------------------
--  Clickable URLs (|Heuiurl:...|h, opens the URL copy popup)
-------------------------------------------------------------------------------
local URL_PATTERNS = {
	"%f[%S](%a[%w+.-]+://%S+)",
	"^(%a[%w+.-]+://%S+)",
	"%f[%S](www%.[-%w_%%]+%.%a%a+/%S+)",
	"^(www%.[-%w_%%]+%.%a%a+/%S+)",
	"%f[%S](www%.[-%w_%%]+%.%a%a+)",
	"^(www%.[-%w_%%]+%.%a%a+)",
}
local URL_EVENTS = {
	"CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
	"CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER", "CHAT_MSG_RAID",
	"CHAT_MSG_RAID_LEADER", "CHAT_MSG_INSTANCE_CHAT",
	"CHAT_MSG_INSTANCE_CHAT_LEADER", "CHAT_MSG_WHISPER",
	"CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_BN_WHISPER",
	"CHAT_MSG_BN_WHISPER_INFORM", "CHAT_MSG_CHANNEL",
}

local function WrapURLs(text)
	local r, g, b = P.Accent()
	local sub = "|cff" .. P.Hex(r, g, b) .. "|Heuiurl:%1|h[%1]|h|r"
	for _, p in ipairs(URL_PATTERNS) do
		text = text:gsub(p, sub)
	end
	return text
end

local function UrlFilter(self, event, msg, ...)
	if type(msg) ~= "string" or not (msg:find("://", 1, true) or msg:find("www.", 1, true)) then
		return false
	end
	return false, WrapURLs(msg), ...
end

if ItemRefTooltip then
	local orig = ItemRefTooltip.SetHyperlink
	ItemRefTooltip.SetHyperlink = function(self, link, ...)
		if type(link) == "string" and link:sub(1, 7) == "euiurl:" then
			self:Hide()
			if ECHAT.ShowUrlPopup then
				ECHAT.ShowUrlPopup(link:sub(8))
			end
			return
		end
		return orig(self, link, ...)
	end
end

-------------------------------------------------------------------------------
--  Link tooltips on hover (off while Hide Tooltip on Hover is on)
-------------------------------------------------------------------------------
local TOOLTIP_LINK_TYPES = {
	achievement = true, currency = true, enchant = true, glyph = true,
	instancelock = true, item = true, quest = true, spell = true, talent = true,
}
local linkEntered

local function OnHyperlinkEnter(self, link)
	if DB().hideTooltipOnHover or type(link) ~= "string" then
		return
	end
	local kind = link:match("^([^:]+)")
	if TOOLTIP_LINK_TYPES[kind] then
		GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
		GameTooltip:SetHyperlink(link)
		GameTooltip:Show()
		linkEntered = self
	end
end

local function OnHyperlinkLeave()
	if linkEntered then
		linkEntered = nil
		GameTooltip:Hide()
	end
end

-------------------------------------------------------------------------------
--  Remember Last Chat Lines (EllesmereUIChatScrollDB, per character)
-------------------------------------------------------------------------------
local function HistorySV()
	local sv = EllesmereUIChatScrollDB
	if type(sv) ~= "table" then
		sv = {}
		EllesmereUIChatScrollDB = sv
	end
	if type(sv.lines) ~= "table" then
		sv.lines = {}
	end
	sv.sessionLog = nil
	return sv
end

local function MaxLines()
	return min(500, max(10, DB().persistChatHistoryMaxLines or 100))
end

local function TrackFrame(cf)
	if cf.isTemporary or IsCombatLogFrame(cf) then
		return nil
	end
	local id = cf:GetID()
	if not id or id < 1 or id > (NUM_CHAT_WINDOWS or 10) then
		return nil
	end
	return id
end

-- 5.4.8 has no chat restrictions, so every line a window shows is kept, in
-- instances too. Right after login / reload only player chat is kept, so the
-- welcome text, MOTD and addon load prints that repeat every time are not.
local LOGIN_GRACE_SEC = 5
local captureFrom = math.huge
local skipIds

local function Skipped(id)
	if not skipIds then
		skipIds = IdSet({ "CHANNEL_NOTICE", "CHANNEL_NOTICE_USER" })
	end
	return id and skipIds[id]
end

local function CaptureHistory(cf, msg, r, g, b, id)
	if DB().persistChatHistory ~= true or Skipped(id) then
		return
	end
	if GetTime() < captureFrom then
		local _, capture = Ids()
		if not (id and capture[id]) then
			return
		end
	end
	local fid = TrackFrame(cf)
	if not fid then
		return
	end
	local list = HistorySV().lines
	local lines = list[fid]
	if not lines then
		lines = {}
		list[fid] = lines
	end
	if #msg > 4096 then
		msg = msg:sub(1, 4096)
	end
	lines[#lines + 1] = { m = StripTimestampPrefix(msg), r = r, g = g, b = b, id = id, t = time() }
	local cap = MaxLines()
	while #lines > cap do
		table.remove(lines, 1)
	end
end

local function RestoreHistory()
	captureFrom = GetTime() + LOGIN_GRACE_SEC
	if DB().persistChatHistory ~= true then
		return
	end
	local list = HistorySV().lines
	local fmt = EffectiveFormat()
	local cap = MaxLines()
	restoring = true
	for fid, lines in pairs(list) do
		local cf = _G["ChatFrame" .. fid]
		if cf and type(lines) == "table" and not IsCombatLogFrame(cf) then
			while #lines > cap do
				table.remove(lines, 1)
			end
			for _, e in ipairs(lines) do
				if type(e.m) == "string" then
					local text = fmt and (Stamp(fmt, e.t) .. e.m) or e.m
					local ok, err = pcall(cf.AddMessage, cf, text, e.r, e.g, e.b, e.id)
					if not ok then
						geterrorhandler()(err)
					end
				end
			end
		end
	end
	restoring = false
end

function ECHAT.OnSessionHistoryToggled(on)
	if not on then
		HistorySV().lines = {}
	end
end
ECHAT.InitChatSessionHistory = function() end

-------------------------------------------------------------------------------
--  AddMessage: transforms, copy buffer, history, idle wake
-------------------------------------------------------------------------------
local function Transform(cf, msg)
	if IsCombatLogFrame(cf) then
		return msg
	end
	if abbrevOn then
		msg = AbbreviateChannelText(msg)
	end
	if DB().timestampAll == true and not HasTimestampPrefix(msg) then
		local fmt = EffectiveFormat()
		if fmt then
			msg = Stamp(fmt) .. msg
		end
	end
	return msg
end

-------------------------------------------------------------------------------
--  Icon fade: 5.4.8 draws icons in chat text (raid markers, role icons) at
--  full alpha whatever the chat frame's alpha, so while chat is faded the
--  window's lines are re-added with each icon's vertex color scaled down
--  (and dropped when chat is fully hidden).
-------------------------------------------------------------------------------
local iconDim = 1

local function DimIcon(spec)
	local f = { strsplit(":", spec) }
	if iconDim <= 0.05 then
		return ""
	end
	local h = f[2] or "0"
	local w = f[3] or h
	local x, y = f[4] or "0", f[5] or "0"
	local tw, th, l, r, t, b = f[6], f[7], f[8], f[9], f[10], f[11]
	if not (tw and th and l and r and t and b) then
		tw, th, l, r, t, b = "100", "100", "0", "100", "0", "100"
	end
	local function C(v)
		return floor((tonumber(v) or 255) * iconDim + 0.5)
	end
	return "|T" .. table.concat({ f[1], h, w, x, y, tw, th, l, r, t, b, C(f[12]), C(f[13]), C(f[14]) }, ":") .. "|t"
end

local function DimIcons(text)
	if iconDim >= 1 or not text:find("|T", 1, true) then
		return text
	end
	return (text:gsub("(|+)T([^|]*)|t", function(pipes, spec)
		if #pipes % 2 == 0 then
			return nil
		end
		return pipes:sub(2) .. DimIcon(spec)
	end))
end

local function RebuildLines(cf, d)
	local n = d.count
	if cf.GetMaxLines then
		n = min(n, cf:GetMaxLines())
	end
	local hasIcon = false
	for i = 1, n do
		local line = d.lines[(d.head - i) % COPY_LINES + 1]
		if line and line:find("|T", 1, true) then
			hasIcon = true
			break
		end
	end
	if not hasIcon then
		return
	end
	local offset = cf.GetCurrentScroll and cf:GetCurrentScroll()
	cf:Clear()
	for i = n, 1, -1 do
		local k = (d.head - i) % COPY_LINES + 1
		local c = d.colors[k]
		d.orig(cf, DimIcons(d.lines[k]), c and c[1], c and c[2], c and c[3], c and c[4])
	end
	if offset and offset > 0 and cf.SetScrollOffset then
		cf:SetScrollOffset(offset)
	end
end

-- level: the chat alpha the icons should match (1 = untouched).
function ECHAT.SetIconDim(level)
	level = floor(max(0, min(1, level)) * 20 + 0.5) / 20
	if level == iconDim then
		return
	end
	iconDim = level
	P.ForEachChatFrame(function(cf)
		local d = FD(cf)
		if d.orig and d.count > 0 and not IsCombatLogFrame(cf) then
			RebuildLines(cf, d)
		end
	end)
end

function ECHAT.GetIconDim()
	return iconDim
end

function ECHAT.HookChatFrameText(cf)
	local d = FD(cf)
	if d.textHooked then
		return
	end
	d.textHooked = true
	-- Copy buffer: a ring of the last COPY_LINES lines (the combat log is busy).
	d.lines = {}
	d.colors = {}
	d.head = 0
	d.count = 0
	local orig = cf.AddMessage
	d.orig = orig
	cf.AddMessage = function(self, msg, r, g, b, id, ...)
		if type(msg) == "string" then
			if not restoring then
				msg = Transform(self, msg)
			end
			d.head = d.head % COPY_LINES + 1
			d.lines[d.head] = msg
			local c = d.colors[d.head] or {}
			c[1], c[2], c[3], c[4] = r, g, b, id
			d.colors[d.head] = c
			if d.count < COPY_LINES then
				d.count = d.count + 1
			end
			if not restoring then
				CaptureHistory(self, msg, r, g, b, id)
				local wake = Ids()
				if id and wake[id] and self:IsShown() and ECHAT.OnActiveMessage then
					ECHAT.OnActiveMessage()
				end
			end
			if iconDim < 1 and not IsCombatLogFrame(self) then
				return orig(self, DimIcons(msg), r, g, b, id, ...)
			end
		end
		return orig(self, msg, r, g, b, id, ...)
	end
	cf:HookScript("OnHyperlinkEnter", OnHyperlinkEnter)
	cf:HookScript("OnHyperlinkLeave", OnHyperlinkLeave)
	if ECHAT.ApplyWhisperMute then
		ECHAT.ApplyWhisperMute()
	end
end

-- Copy Chat: the window's lines, links shown as their text, colors kept.
function ECHAT.ReadChatText(cf)
	cf = cf or ChatFrame1
	local d = FD(cf)
	if not d.lines or (d.count or 0) == 0 then
		return ""
	end
	local out = {}
	local first = d.head - d.count
	for i = 1, d.count do
		local line = d.lines[(first + i - 1) % COPY_LINES + 1]
		local ok, s = pcall(P.StripUIEscapes, line)
		if ok and s then
			out[#out + 1] = s
		end
	end
	return table.concat(out, "\n")
end

-------------------------------------------------------------------------------
--  Whisper Sound: "Blizzard Default" keeps Blizzard's, "None" plays nothing,
--  any other sound replaces it (Blizzard's is held back through the chat
--  frame's tell timer, 5.4.8 has no MuteSoundFile).
-------------------------------------------------------------------------------
local SOUND_FILES = {
	airhorn = "AirHorn.ogg", banana = "BananaPeelSlip.ogg", bikehorn = "BikeHorn.ogg",
	bite = "Bite.ogg", boxing = "BoxingArenaSound.ogg", catmeow = "CatMeow.ogg",
	catmeow2 = "CatMeow2.ogg", gunshot = "FrontalsGunshot.wav", glass = "Glass.mp3",
	kaching = "Kaching.ogg", phone = "Phone.ogg", robotblip = "RobotBlip.ogg",
	sonar = "Sonar.ogg", siren = "WarningSiren.ogg", water = "WaterDrop.ogg",
	wilhelm = "Wilhelm.ogg",
}
local SOUND_NAMES = {
	none = "Blizzard Default", mute = "None", airhorn = "Air Horn", banana = "Banana Peel Slip",
	bikehorn = "Bike Horn", bite = "Bite", boxing = "Boxing Arena",
	catmeow = "Cat Meow", catmeow2 = "Cat Meow 2", gunshot = "Frontals Gunshot",
	glass = "Glass", kaching = "Kaching", phone = "Phone", robotblip = "Robot Blip",
	sonar = "Sonar", siren = "Warning Siren", water = "Water Drop", wilhelm = "Wilhelm",
}
local SOUND_ORDER = {
	"none", "mute", "airhorn", "banana", "bikehorn", "bite", "boxing", "catmeow",
	"catmeow2", "gunshot", "glass", "kaching", "phone", "robotblip", "sonar",
	"siren", "water", "wilhelm",
}
ECHAT.WHISPER_SOUND_PATHS = {}
for k, f in pairs(SOUND_FILES) do
	ECHAT.WHISPER_SOUND_PATHS[k] = P.MEDIA .. "sounds\\" .. f
end
ECHAT.WHISPER_SOUND_NAMES = SOUND_NAMES
ECHAT.WHISPER_SOUND_ORDER = SOUND_ORDER

-- SharedMedia sounds after ours.
function ECHAT.AppendSharedMediaSounds()
	if ECHAT.smSoundsAdded then
		return
	end
	local ok, LSM = pcall(function() return LibStub and LibStub("LibSharedMedia-3.0", true) end)
	if not ok or not LSM or not LSM.HashTable then
		return
	end
	ECHAT.smSoundsAdded = true
	local extra = {}
	for name, path in pairs(LSM:HashTable("sound") or {}) do
		if type(path) == "string" and path ~= "" and name ~= "None" then
			extra[#extra + 1] = name
			ECHAT.WHISPER_SOUND_PATHS["sm:" .. name] = path
			SOUND_NAMES["sm:" .. name] = name
		end
	end
	table.sort(extra, function(a, b) return a:lower() < b:lower() end)
	for _, name in ipairs(extra) do
		SOUND_ORDER[#SOUND_ORDER + 1] = "sm:" .. name
	end
end

local FAR = 1e10
local whisperMuted = false

function ECHAT.ApplyWhisperMute()
	local key = DB().whisperSoundKey
	whisperMuted = key ~= nil and key ~= "none"
	P.ForEachChatFrame(function(cf)
		if whisperMuted then
			cf.tellTimer = FAR
		elseif cf.tellTimer == FAR then
			cf.tellTimer = GetTime()
		end
	end)
end

hooksecurefunc("ChatFrame_MessageEventHandler", function(self, event)
	if whisperMuted and (event == "CHAT_MSG_WHISPER" or event == "CHAT_MSG_BN_WHISPER") then
		self.tellTimer = FAR
	end
end)

do
	local throttle = 0
	local f = CreateFrame("Frame")
	f:RegisterEvent("CHAT_MSG_WHISPER")
	f:RegisterEvent("CHAT_MSG_BN_WHISPER")
	f:SetScript("OnEvent", function()
		if not P.started then
			return
		end
		if ECHAT.OnActiveMessage then
			ECHAT.OnActiveMessage()
		end
		local key = DB().whisperSoundKey
		if not key or key == "none" or key == "mute" then
			return
		end
		local now = GetTime()
		if now - throttle < 5 then
			return
		end
		throttle = now
		local path = ECHAT.WHISPER_SOUND_PATHS[key]
		if path then
			PlaySoundFile(path, "Master")
		end
	end)
end

-------------------------------------------------------------------------------
--  Settings -> text state
-------------------------------------------------------------------------------
local filtersAdded = false
function ECHAT.ApplyTextSettings()
	local cfg = DB()
	ECHAT.EngineSetChannelAbbrev(cfg.abbreviateChannels == true)
	ECHAT.EngineSetChannelAbbrevLetters(cfg.abbreviateChannelLetters == true)
	if (cfg.classColorNames == true) ~= ccnOn then
		ECHAT.EngineSetClassColorNames(cfg.classColorNames == true)
	end
	ECHAT.ApplyTimestampCVar()
	ECHAT.ApplyWhisperMute()
	if not filtersAdded then
		filtersAdded = true
		for _, ev in ipairs(URL_EVENTS) do
			ChatFrame_AddMessageEventFilter(ev, UrlFilter)
		end
		for _, ev in ipairs(CCN_EVENTS) do
			ChatFrame_AddMessageEventFilter(ev, CCNFilter)
		end
	end
end

-- Remembered lines go in at start, right after the chat frames are skinned
-- (before the login messages).
ECHAT.RestoreHistory = RestoreHistory
