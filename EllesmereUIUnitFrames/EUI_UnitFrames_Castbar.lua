-- EllesmereUI Unit Frames for 5.4.8: cast bars (player mini bar, target,
-- focus, boss). Tan fill, grey when not interruptible, orange while your
-- interrupt is on cooldown, a white tick where it comes back.

local addonName = ...
local ns = EllesmereUI
local UF = ns.UF

local min, max = math.min, math.max
local format = format
local GetTime = GetTime

-- Your interrupt spell (first known one of your class), refreshed on spell changes.
local kickSpell
function UF.RefreshKickSpell()
	kickSpell = nil
	local list = UF.INTERRUPTS[select(2, UnitClass("player"))]
	if not list then
		return
	end
	for _, id in ipairs(list) do
		if IsSpellKnown(id) or IsSpellKnown(id, true) then
			kickSpell = id
			return
		end
	end
end

-- Seconds until your interrupt is ready (0 = ready, nil = you have none).
local function KickRemaining()
	if not kickSpell then
		return nil
	end
	local start, duration = GetSpellCooldown(kickSpell)
	if not start or start == 0 or duration <= 1.5 then
		return 0
	end
	return max(0, start + duration - GetTime())
end

local function FillColor(frame, s)
	if frame.unitKey == "player" and s.castbarClassColored then
		return UF.PlayerClassColor()
	end
	local c = s.castbarFillColor or UF.db.castbarColor
	return c.r, c.g, c.b
end

local function IsKickUnit(frame)
	return frame.unitKey == "target" or frame.unitKey == "focus" or frame.isBoss
end

local function Paint(frame)
	local holder = frame.Castbar
	local s = frame.settings
	local bar = holder.bar
	local tex = bar:GetStatusBarTexture()
	local alpha = (s.castFillOpacity or 100) / 100
	local r, g, b = FillColor(frame, s)
	holder.tick:Hide()
	holder.mid:Hide()
	if IsKickUnit(frame) and holder.casting and not holder.notInterruptible then
		local remaining = KickRemaining()
		if remaining and remaining > 0 then
			local c = s.castbarInterruptReadyColor or { r = 0.92, g = 0.35, b = 0.20 }
			r, g, b = c.r, c.g, c.b
			-- Tick / mid-cast segment where the interrupt comes back.
			local total = holder.endTime - holder.startTime
			if total > 0 then
				local now = GetTime()
				local readyAt = now + remaining
				local pos = (readyAt - holder.startTime) / total
				if holder.channel then
					pos = (holder.endTime - readyAt) / total
				end
				if pos > 0 and pos < 1 then
					local w = bar:GetWidth()
					local x = s.castReverseFill and (w * (1 - pos)) or (w * pos)
					if s.castbarKickTickEnabled ~= false then
						holder.tick:ClearAllPoints()
						holder.tick:SetPoint("CENTER", bar, "LEFT", x, 0)
						holder.tick:Show()
					end
					if s.castbarInterruptMidCastEnabled then
						local mc = s.castbarInterruptMidCastColor or { r = 0.318, g = 0.820, b = 0.357 }
						holder.mid:ClearAllPoints()
						local forward = not holder.channel
						if s.castReverseFill then
							forward = not forward
						end
						if forward then
							holder.mid:SetPoint("TOPLEFT", bar, "TOPLEFT", x, 0)
							holder.mid:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT")
						else
							holder.mid:SetPoint("TOPLEFT", bar, "TOPLEFT")
							holder.mid:SetPoint("BOTTOMRIGHT", bar, "BOTTOMLEFT", x, 0)
						end
						holder.mid:SetVertexColor(mc.r, mc.g, mc.b, 0.6 * alpha)
						holder.mid:Show()
					end
				end
			end
		end
	end
	tex:SetVertexColor(r, g, b, alpha)
	if holder.notInterruptible and frame.unitKey ~= "player" then
		local c = s.castbarUninterruptibleColor or { r = 0.5, g = 0.5, b = 0.5 }
		holder.uninterruptible:SetVertexColor(c.r, c.g, c.b, alpha)
		holder.uninterruptible:Show()
	else
		holder.uninterruptible:Hide()
	end
end

local function OnUpdate(holder, elapsed)
	local frame = holder.frame
	local now = GetTime()
	if holder.preview then
		return
	end
	if not holder.casting then
		return
	end
	local total = holder.endTime - holder.startTime
	if total <= 0 then
		return
	end
	local value
	if holder.channel then
		value = (holder.endTime - now) / total
	else
		value = (now - holder.startTime) / total
	end
	if now >= holder.endTime + 0.1 then
		UF.CastStop(frame)
		return
	end
	holder.bar:SetValue(min(1, max(0, value)))
	if holder.time:IsShown() then
		local left = max(0, holder.endTime - now)
		if holder.delay and holder.delay > 0 then
			holder.time:SetText(format("%.1f|cffff0000%s%.2f|r", left, holder.channel and "-" or "+", holder.delay))
		else
			holder.time:SetText(format("%.1f", left))
		end
	end
	holder.paintTimer = (holder.paintTimer or 0) + elapsed
	if holder.paintTimer > 0.1 then
		holder.paintTimer = 0
		Paint(frame)
	end
end

local function SetIcon(frame, texture)
	local holder = frame.Castbar
	holder.icon.tex:SetTexture(texture)
	local c = UF.CastSettings(frame)
	local p = frame.Portrait
	if c.iconOnPortrait and p:IsShown() then
		p.castIcon:SetTexture(texture)
		p.castIcon:SetShown(texture ~= nil)
	else
		p.castIcon:Hide()
	end
end

local function SetTexts(frame, name)
	local holder = frame.Castbar
	local s = frame.settings
	local targetName
	local tunit = frame.unit .. "target"
	if UnitExists(tunit) and not UnitIsUnit(tunit, frame.unit) then
		targetName = UF.Hex(UF.UnitColor(tunit)) .. UnitName(tunit) .. "|r"
	end
	if s.castCombineNameTarget and targetName and not frame.isBoss then
		holder.name:SetText(name .. " - " .. targetName)
	else
		holder.name:SetText(name or "")
	end
	holder.target:SetText(targetName or "")
end

function UF.CastStart(frame)
	local holder = frame.Castbar
	if not holder or not holder.enabled then
		return
	end
	local unit = frame.unit
	local name, _, text, texture, startMS, endMS, _, castID, notInterruptible = UnitCastingInfo(unit)
	local channel = false
	if not name then
		name, _, text, texture, startMS, endMS, _, notInterruptible = UnitChannelInfo(unit)
		channel = name and true or false
		castID = nil
	end
	if not name then
		UF.CastStop(frame)
		return
	end
	holder.frame = frame
	holder.casting = true
	holder.preview = nil
	holder.channel = channel
	holder.castID = castID
	holder.startTime = startMS / 1000
	holder.endTime = endMS / 1000
	holder.delay = 0
	holder.notInterruptible = notInterruptible and true or false
	SetIcon(frame, texture)
	SetTexts(frame, name)
	holder:SetScript("OnUpdate", OnUpdate)
	holder:Show()
	Paint(frame)
	OnUpdate(holder, 0)
end

function UF.CastDelayed(frame)
	local holder = frame.Castbar
	if not holder or not holder.casting then
		return
	end
	local name, _, _, _, startMS, endMS
	if holder.channel then
		name, _, _, _, startMS, endMS = UnitChannelInfo(frame.unit)
	else
		name, _, _, _, startMS, endMS = UnitCastingInfo(frame.unit)
	end
	if not name then
		return
	end
	local newEnd = endMS / 1000
	holder.delay = (holder.delay or 0) + math.abs(newEnd - holder.endTime)
	holder.startTime = startMS / 1000
	holder.endTime = newEnd
end

function UF.CastStop(frame, castID)
	local holder = frame.Castbar
	if not holder then
		return
	end
	if castID and holder.castID and castID ~= holder.castID then
		return
	end
	holder.casting = false
	holder.notInterruptible = false
	holder:SetScript("OnUpdate", nil)
	holder.tick:Hide()
	holder.mid:Hide()
	holder.uninterruptible:Hide()
	frame.Portrait.castIcon:Hide()
	if holder.preview then
		return
	end
	if holder.hideWhenIdle ~= false then
		holder:Hide()
	else
		holder.bar:SetValue(0)
		holder.name:SetText("")
		holder.time:SetText("")
		holder.target:SetText("")
		holder.icon.tex:SetTexture(nil)
	end
end

function UF.CastInterruptible(frame, notInterruptible)
	local holder = frame.Castbar
	if holder and holder.casting then
		holder.notInterruptible = notInterruptible
		Paint(frame)
	end
end

-- Full refresh (unit changed, settings changed, preview).
function UF.CastUpdate(frame)
	local holder = frame.Castbar
	if not holder then
		return
	end
	holder.frame = frame
	if not holder.enabled then
		holder.preview = nil
		holder:Hide()
		frame.Portrait.castIcon:Hide()
		return
	end
	if UF.IsFake(frame) or (frame.preview and not UnitCastingInfo(frame.unit) and not UnitChannelInfo(frame.unit)) then
		-- Fake cast so the settings can be seen.
		holder.preview = true
		holder.casting = false
		holder:SetScript("OnUpdate", nil)
		local data = UF.PreviewData(frame)
		holder.bar:SetValue(data.cast)
		holder.notInterruptible = false
		local name, _, icon = GetSpellInfo(frame.isBoss and 5143 or 118)
		SetIcon(frame, icon)
		holder.name:SetText(name or "Polymorph")
		holder.target:SetText(UF.Hex(UF.PlayerClassColor()) .. (UnitName("player") or "") .. "|r")
		holder.time:SetText(format("%.1f", 1.5 * (1 - data.cast)))
		local tex = holder.bar:GetStatusBarTexture()
		local r, g, b = FillColor(frame, frame.settings)
		tex:SetVertexColor(r, g, b, (frame.settings.castFillOpacity or 100) / 100)
		holder.uninterruptible:Hide()
		holder.tick:Hide()
		holder.mid:Hide()
		holder:Show()
		return
	end
	holder.preview = nil
	if UnitCastingInfo(frame.unit) or UnitChannelInfo(frame.unit) then
		UF.CastStart(frame)
	else
		UF.CastStop(frame)
	end
end
