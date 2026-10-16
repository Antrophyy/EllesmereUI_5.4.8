-- EllesmereUI Quality of Life for 5.4.8: the runtime of the retail Macro
-- Factory (EUI_MacroFactory.lua). The settings window draws the icons
-- (EllesmereUIOptions\EUI_QoL_MacroFactory_Options.lua); this file holds the
-- macro list, writes the EUI_* macros and keeps the item macros up to date.
--
-- Saved settings: EllesmereUIQoLDB.macroFactory[macroName] (retail keeps them
-- on the account table EllesmereUIDB.macroFactory, which retail profiles do
-- not export; here they are part of the QoL profile, so they export/import).
--   showTooltip = false      -> no #showtooltip line (absent = on)
--   opt1..optN = false       -> item option off (absent = on)
--   order = { 3, 1, 2, ... } -> item priority (drag to reorder)
--   autoMark / announce      -> Set Focus extras (absent = off)
--   markIcon = 1..8          -> Set Focus marker (absent = Skull)
--
-- Changes for 5.4.8:
--   * Mists items and spells (retail Midnight ones do not exist). Spells are
--     stored by ID and the macro gets the client's own spell name.
--   * No ping in 5.4.8: the Set Focus "Ping Focus" option is left out.
--   * Auto Mark Focus uses SetRaidTarget through /run: retail "/tm ~N" (do not
--     replace a marker someone else set) is a 12.0.7 macro extension.
--   * No [known:] macro option and no /cqs: the macros that need them
--     (Soulburn Healthstone, Presence of Mind /cqs) are changed or left out.
--   * Macros are never created, deleted or edited in combat; item macros
--     that change in combat are written when combat ends.
--   * When the 36 account macros are full, the macro is made as a character
--     macro (18 slots) instead of failing.
--   * The bag watcher runs from login (retail only after the settings page
--     was built), so item macros stay right without opening the settings.

local ns = EllesmereUI
local Q = ns.QoL
if not Q then
	return
end

local MF = {}
ns.MacroFactory = MF

local pairs, ipairs, type, tonumber, tostring = pairs, ipairs, type, tonumber, tostring

local FOCUS_DEFAULT_MARK = 8 -- Skull
MF.FOCUS_DEFAULT_MARK = FOCUS_DEFAULT_MARK

-- TexCoords into UI-RaidTargetingIcons, in marker order 1-8 (Star .. Skull).
MF.MARK_COORDS = {
	{ 0.00, 0.25, 0.00, 0.25 }, { 0.25, 0.50, 0.00, 0.25 },
	{ 0.50, 0.75, 0.00, 0.25 }, { 0.75, 1.00, 0.00, 0.25 },
	{ 0.00, 0.25, 0.25, 0.50 }, { 0.25, 0.50, 0.25, 0.50 },
	{ 0.50, 0.75, 0.25, 0.50 }, { 0.75, 1.00, 0.25, 0.50 },
}

---------------------------------------------------------------------------
-- General macros
---------------------------------------------------------------------------
MF.GENERAL_DEFS = {
	{
		name = "EUI_Potion",
		icon = "Interface\\Icons\\inv_potion_54",
		label = "Potion",
		checkboxes = {
			{ key = "opt1", label = "Potion of the Jade Serpent", items = { 76093 } },
			{ key = "opt2", label = "Virmen's Bite",              items = { 76089 } },
			{ key = "opt3", label = "Potion of Mogu Power",       items = { 76095 } },
			{ key = "opt4", label = "Master Mana Potion",         items = { 76098 } },
		},
	},
	{
		-- Retail: Recuperate out of combat, potions in combat. 5.4.8 has no
		-- Recuperate: Healthstone first, then Master Healing Potion.
		name = "EUI_Health",
		icon = "Interface\\Icons\\INV_Stone_04",
		label = "Healthstone / Potion",
		fixedBody = "/use item:5512\n/use item:76097",
		fixedTooltip = "item:5512",
	},
	{
		name = "EUI_Food",
		icon = "Interface\\Icons\\inv_misc_food_73cinnamonroll",
		label = "Food",
		checkboxes = {
			{ key = "opt1", label = "Conjured Mana Buns",           items = { 80618 } },
			{ key = "opt2", label = "Conjured Mana Pudding",        items = { 80610 } },
			{ key = "opt3", label = "Black Pepper Ribs and Shrimp", items = { 74646 } },
			{ key = "opt4", label = "Sea Mist Rice Noodles",        items = { 74648 } },
			{ key = "opt5", label = "Mogu Fish Stew",               items = { 74650 } },
			{ key = "opt6", label = "Steamed Crab Surprise",        items = { 74653 } },
			{ key = "opt7", label = "Chun Tian Spring Rolls",       items = { 74656 } },
		},
	},
	{
		name = "EUI_Trinket1",
		icon = "Interface\\Icons\\inv_jewelry_trinketpvp_01",
		label = "Trinket 1",
		fixedBody = "/use 13",
		fixedTooltip = "13",
	},
	{
		name = "EUI_Trinket2",
		icon = "Interface\\Icons\\inv_jewelry_trinketpvp_02",
		label = "Trinket 2",
		fixedBody = "/use 14",
		fixedTooltip = "14",
	},
	{
		name = "EUI_Focus",
		icon = "Interface\\Icons\\Ability_Hunter_FocusedAim",
		macroIcon = "Ability_Hunter_FocusedAim",
		label = "Set Focus",
		fixedBody = "/focus [@mouseover,exists,nodead] []",
		-- Each toggle stands alone; with both off the body is the plain /focus.
		extraToggles = {
			{ key = "autoMark", label = "Auto Mark Focus" },
			{ key = "announce", label = "Announce Focus" },
		},
		-- Pick the marker whenever; it only matters once Auto Mark is on.
		extraChoices = {
			{ key = "markIcon", label = "Focus Marker", default = FOCUS_DEFAULT_MARK },
		},
		extraBody = function(db)
			if not (db.autoMark or db.announce) then return nil end
			-- Every line after this acts on the focus: stop when none was set.
			local lines = { "/stopmacro [@focus,noexists]" }
			local mark = db.markIcon
			if not MF.MARK_COORDS[mark] then mark = FOCUS_DEFAULT_MARK end
			if db.autoMark then
				-- Only when the focus has no marker yet (retail "/tm ~N").
				lines[#lines + 1] = "/run if not GetRaidTargetIndex(\"focus\") then SetRaidTarget(\"focus\"," .. mark .. ") end"
			end
			if db.announce then
				-- %f = the focus name. The marker is only named when Auto Mark is on.
				local focusWord = ns.L("Focus") or "Focus"
				lines[#lines + 1] = db.autoMark
					and ("/p " .. focusWord .. ": {rt" .. mark .. "} %f")
					or ("/p " .. focusWord .. ": %f")
			end
			return table.concat(lines, "\n")
		end,
	},
}

---------------------------------------------------------------------------
-- Spec macros (keyed by specID; the 5.4.8 spec IDs are the retail ones).
-- {n} = the client name of def.spells[n]. Button icons come from the first
-- spell when no icon is given. Retail macros of spells that 5.4.8 does not
-- have (Demon Hunter, Evoker, Reaper's Mark, Meteor, Harpoon, ...) are left
-- out; spells that 5.4.8 casts on a unit instead of the ground use the focus.
---------------------------------------------------------------------------
local function mergeMacros(...)
	local t = {}
	for i = 1, select("#", ...) do
		local src = select(i, ...)
		if src then for _, v in ipairs(src) do t[#t + 1] = v end end
	end
	return t
end

local HARM = "/cast [@focus,harm,nodead][] {1}"
local HELP = "/cast [@focus,help,nodead][] {1}"
local CURSOR = "/cast [@cursor] {1}"

-- Death Knight (250 Blood, 251 Frost, 252 Unholy)
local DK_GEN = {
	{ name = "EUI_MindFreeze", label = "Mind Freeze\n(Focus)", spells = { 47528 }, fixedBody = HARM, fixedTooltip = "{1}" },
	{ name = "EUI_Strangulate", label = "Strangulate\n(Focus)", spells = { 47476 }, fixedBody = HARM, fixedTooltip = "{1}" },
	{ name = "EUI_Asphyxiate", label = "Asphyxiate\n(Focus)", spells = { 108194 }, fixedBody = HARM, fixedTooltip = "{1}" },
	{ name = "EUI_DnDCursor", label = "Death and Decay\n(Cursor)", spells = { 43265 }, fixedBody = CURSOR, fixedTooltip = "{1}" },
}
local DK_BLOOD = {
	-- 5.4.8 Gorefiend's Grasp is cast on a unit (friend or foe), not the ground.
	{ name = "EUI_Gorefiend", label = "Gorefiend's Grasp\n(Focus)", spells = { 108199 }, fixedBody = "/cast [@focus,exists,nodead][] {1}", fixedTooltip = "{1}" },
}
local DK_FROST = {
	{ name = "EUI_PFObliterate", label = "PF Obliterate", spells = { 51271, 49020, 46584 }, fixedBody = "/cast {1}\n/cast {2}\n/cast {3}" },
}
local DK_UNHOLY = {
	{ name = "EUI_PetSwap", label = "Pet Target\nSwap", spells = { 47482 }, fixedBody = "/cast {1}\n/petattack\n/startattack" }, -- Leap (ghoul)
	{ name = "EUI_PetMove", label = "Pet Move", spells = { 63560 }, fixedBody = "/petmoveto", fixedTooltip = "{1}" }, -- tooltip: Dark Transformation
	{ name = "EUI_PetResummon", label = "Pet Resummon", spells = { 46584 }, fixedBody = "/script PetDismiss()\n/cast [nopet] {1}" }, -- Raise Dead
}

-- Druid (102 Balance, 103 Feral, 104 Guardian, 105 Restoration)
local DRUID_GEN = {
	{ name = "EUI_UrsolVortex", label = "Ursol's Vortex\n(Cursor)", spells = { 102793 }, fixedBody = CURSOR },
	{ name = "EUI_Innervate", label = "Innervate\n(Focus)", spells = { 29166 }, fixedBody = HELP, fixedTooltip = "{1}" },
}
local DRUID_DECURSE = {
	{ name = "EUI_RemoveCorr", label = "Remove Corruption\n(Focus)", spells = { 2782 }, fixedBody = HELP, fixedTooltip = "{1}" },
}
local DRUID_BAL = {
	{ name = "EUI_SolarBeam", label = "Solar Beam\n(Focus)", spells = { 78675 }, fixedBody = HARM, fixedTooltip = "{1}" },
	{ name = "EUI_Hurricane", label = "Hurricane\n(Cursor)", spells = { 16914 }, fixedBody = CURSOR, fixedTooltip = "{1}" },
}
local DRUID_FERAL = {
	{ name = "EUI_SkullBash", label = "Skull Bash\n(Focus)", spells = { 106839 }, fixedBody = HARM, fixedTooltip = "{1}" },
}
local DRUID_RESTO = {
	{ name = "EUI_Ironbark", label = "Ironbark\n(Focus)", spells = { 102342 }, fixedBody = HELP, fixedTooltip = "{1}" },
	{ name = "EUI_InnervateMe", label = "Innervate\n(Player)", spells = { 29166 }, fixedBody = "/cast [@player] {1}" },
	{ name = "EUI_NaturesCure", label = "Nature's Cure\n(Focus)", spells = { 88423 }, fixedBody = HELP, fixedTooltip = "{1}" },
}

-- Hunter (253 Beast Mastery, 254 Marksmanship, 255 Survival)
local HUNTER_GEN = {
	{ name = "EUI_CounterShot", label = "Counter Shot\n(Focus)", spells = { 147362 }, fixedBody = HARM, fixedTooltip = "{1}" },
	{ name = "EUI_Deterrence", label = "Cancel/Cast\nDeterrence", spells = { 19263 }, fixedBody = "/cancelaura {1}\n/cast {1}", fixedTooltip = "{1}" },
	{ name = "EUI_Misdirection", label = "Misdirection\n(Focus)", spells = { 34477 }, fixedBody = "/cast [@focus,help,nodead][@pet,exists] {1}", fixedTooltip = "{1}" },
	-- Traps are thrown with Trap Launcher on ("!" keeps it from toggling off).
	{ name = "EUI_FreezeTrap", label = "Freezing Trap\n(Cursor)", spells = { 1499, 77769 }, fixedBody = "/cast !{2}\n/cast [@cursor] {1}", fixedTooltip = "{1}" },
	{ name = "EUI_IceTrap", label = "Ice Trap\n(Cursor)", spells = { 13809, 77769 }, fixedBody = "/cast !{2}\n/cast [@cursor] {1}", fixedTooltip = "{1}" },
	{ name = "EUI_FlareCursor", label = "Flare\n(Cursor)", spells = { 1543 }, fixedBody = CURSOR, fixedTooltip = "{1}" },
	{ name = "EUI_BindingShot", label = "Binding Shot\n(Cursor)", spells = { 109248 }, fixedBody = CURSOR, fixedTooltip = "{1}" },
}
local HUNTER_BM = {
	{ name = "EUI_RoarOfSac", label = "Roar of\nSacrifice", spells = { 53480, 34477 }, fixedBody = "/target [@focus,help,nodead]\n/cast {1}\n/targetlasttarget\n/cast [@pet] {2}", fixedTooltip = "{1}" },
	{ name = "EUI_SpiritMend", label = "Spirit Mend", spells = { 90361 }, fixedBody = "/cast [@target,help,nodead][@mouseover,help,nodead][@player] {1}", fixedTooltip = "{1}" },
}

-- Mage (62 Arcane, 63 Fire, 64 Frost)
local MAGE_GEN = {
	{ name = "EUI_Counterspell", label = "Counterspell\n(Focus)", spells = { 2139 }, fixedBody = HARM, fixedTooltip = "{1}" },
	{ name = "EUI_Spellsteal", label = "Spellsteal\n(Focus)", spells = { 30449 }, fixedBody = HARM, fixedTooltip = "{1}" },
	{ name = "EUI_RemoveCurse", label = "Remove Curse\n(Focus)", spells = { 475 }, fixedBody = HELP, fixedTooltip = "{1}" },
}
local MAGE_ARCANE = {
	{ name = "EUI_PoMBlast", label = "Presence of Mind\nArcane Blast", spells = { 12043, 30451 }, fixedBody = "/cast {1}\n/cast {2}" },
}
local MAGE_FIRE = {
	{ name = "EUI_Flamestrike", label = "Flamestrike\n(Cursor)", spells = { 2120 }, fixedBody = CURSOR },
}
local MAGE_FROST_SPEC = {
	{ name = "EUI_Blizzard", label = "Blizzard\n(Cursor)", spells = { 10 }, fixedBody = CURSOR },
}

-- Monk (268 Brewmaster, 269 Windwalker, 270 Mistweaver)
local MONK_GEN = {
	{ name = "EUI_Detox", label = "Detox\n(Focus)", spells = { 115450 }, fixedBody = HELP, fixedTooltip = "{1}" },
	{ name = "EUI_TigersLust", label = "Tiger's Lust\n(Focus)", spells = { 116841 }, fixedBody = HELP, fixedTooltip = "{1}" },
	-- 5.4.8 Ring of Peace is cast on an ally, not the ground.
	{ name = "EUI_RingOfPeace", label = "Ring of Peace\n(Focus)", spells = { 116844 }, fixedBody = HELP, fixedTooltip = "{1}" },
}
local MONK_SPEAR = {
	{ name = "EUI_SpearHand", label = "Spear Hand Strike\n(Focus)", spells = { 116705 }, fixedBody = HARM, fixedTooltip = "{1}" },
}
local MONK_BREW = {
	{ name = "EUI_BlackOx", label = "Black Ox Statue\n(Cursor)", spells = { 115315 }, fixedBody = CURSOR },
}
local MONK_MW = {
	{ name = "EUI_LifeCocoon", label = "Life Cocoon\n(Focus)", spells = { 116849 }, fixedBody = HELP, fixedTooltip = "{1}" },
	{ name = "EUI_JadeSerpent", label = "Jade Serpent\nStatue (Cursor)", spells = { 115313 }, fixedBody = CURSOR, fixedTooltip = "{1}" },
}

-- Paladin (65 Holy, 66 Protection, 70 Retribution). Retail "Blessing of"
-- spells are "Hand of" spells in 5.4.8.
local PALA_GEN = {
	{ name = "EUI_BoFreedom", label = "Hand of\nFreedom (Focus)", spells = { 1044 }, fixedBody = HELP, fixedTooltip = "{1}" },
	{ name = "EUI_BoProtection", label = "Hand of\nProtection (Focus)", spells = { 1022 }, fixedBody = HELP, fixedTooltip = "{1}" },
	{ name = "EUI_DivineShield", label = "Divine Shield\nCancel/Cast", spells = { 642 }, fixedBody = "/stopcasting\n/cancelaura {1}\n/cast {1}", fixedTooltip = "{1}" },
	{ name = "EUI_ToTLoH", label = "Lay on Hands\n(Target of Target)", spells = { 633 }, fixedBody = "/cast [@targettarget] {1}" },
	{ name = "EUI_Cleanse", label = "Cleanse\n(Focus)", spells = { 4987 }, fixedBody = HELP, fixedTooltip = "{1}" },
	{ name = "EUI_LayOnHands", label = "Lay on Hands\n(Focus)", spells = { 633 }, fixedBody = HELP, fixedTooltip = "{1}" },
}
local PALA_REBUKE = {
	{ name = "EUI_Rebuke", label = "Rebuke\n(Focus)", spells = { 96231 }, fixedBody = HARM, fixedTooltip = "{1}" },
}

-- Priest (256 Discipline, 257 Holy, 258 Shadow). Power Infusion is
-- self-only in 5.4.8 and Shadow has no Purify Disease: both left out.
local PRIEST_GEN = {
	{ name = "EUI_DispelMagic", label = "Dispel Magic\n(Focus)", spells = { 528 }, fixedBody = HARM, fixedTooltip = "{1}" },
	{ name = "EUI_LeapOfFaith", label = "Leap of Faith\n(Focus)", spells = { 73325 }, fixedBody = HELP, fixedTooltip = "{1}" },
	{ name = "EUI_MassDispel", label = "Mass Dispel\n(Cursor)", spells = { 32375 }, fixedBody = CURSOR, fixedTooltip = "{1}" },
	{ name = "EUI_FeatherSelf", label = "Angelic Feather\n(Self)", spells = { 121536 }, fixedBody = "/cast [@player] {1}\n/stopspelltarget", fixedTooltip = "{1}" },
	{ name = "EUI_FeatherCur", label = "Angelic Feather\n(Cursor)", spells = { 121536 }, fixedBody = "/cast [@cursor] {1}\n/stopspelltarget", fixedTooltip = "{1}" },
}
local PRIEST_PURIFY = {
	{ name = "EUI_Purify", label = "Purify\n(Focus)", spells = { 527 }, fixedBody = HELP, fixedTooltip = "{1}" },
}
local PRIEST_DISC = {
	{ name = "EUI_PainSuppress", label = "Pain Suppression\n(Focus)", spells = { 33206 }, fixedBody = HELP, fixedTooltip = "{1}" },
	{ name = "EUI_PWBarrier", label = "PW: Barrier\n(Cursor)", spells = { 62618 }, fixedBody = CURSOR, fixedTooltip = "{1}" },
}
local PRIEST_HOLY = {
	{ name = "EUI_GuardSpirit", label = "Guardian Spirit\n(Focus)", spells = { 47788 }, fixedBody = HELP, fixedTooltip = "{1}" },
}
local PRIEST_SHADOW = {
	{ name = "EUI_Silence", label = "Silence\n(Focus)", spells = { 15487 }, fixedBody = HARM, fixedTooltip = "{1}" },
}

-- Rogue (259 Assassination, 260 Combat, 261 Subtlety)
local ROGUE_GEN = {
	{ name = "EUI_Kick", label = "Kick\n(Focus)", spells = { 1766 }, fixedBody = HARM, fixedTooltip = "{1}" },
	{ name = "EUI_Tricks", label = "Tricks of Trade\n(Focus)", spells = { 57934 }, fixedBody = HELP, fixedTooltip = "{1}" },
	{ name = "EUI_Distract", label = "Distract\n(Cursor)", spells = { 1725 }, fixedBody = CURSOR, fixedTooltip = "{1}" },
}
local ROGUE_SUB = {
	{ name = "EUI_EasyStealth", label = "Easy Stealth", spells = { 51713, 1784 }, fixedBody = "/cancelaura [nocombat] {1}\n/cast !{2}", fixedTooltip = "{2}" }, -- Shadow Dance / Stealth
}

-- Shaman (262 Elemental, 263 Enhancement, 264 Restoration). 5.4.8 totems
-- drop at the shaman's feet, so the retail cursor totems are left out.
local SHAMAN_GEN = {
	{ name = "EUI_WindShear", label = "Wind Shear\n(Focus)", spells = { 57994 }, fixedBody = HARM, fixedTooltip = "{1}" },
	{ name = "EUI_Purge", label = "Purge\n(Focus)", spells = { 370 }, fixedBody = HARM, fixedTooltip = "{1}" },
}
local SHAMAN_CLEANSE = {
	{ name = "EUI_CleanseSpir", label = "Cleanse Spirit\n(Focus)", spells = { 51886 }, fixedBody = HELP, fixedTooltip = "{1}" },
}
local SHAMAN_ELE = {
	{ name = "EUI_Earthquake", label = "Earthquake\n(Cursor)", spells = { 61882 }, fixedBody = CURSOR, fixedTooltip = "{1}" },
}
local SHAMAN_ENH = {
	{ name = "EUI_TotemMove", label = "Auto Totem Move\nfor Totemic", spells = { 17364, 108287 }, fixedBody = "/cast {1}\n/cast [@player] {2}" }, -- Stormstrike / Totemic Projection
}
local SHAMAN_RESTO = {
	{ name = "EUI_HealingRain", label = "Healing Rain\n(Cursor)", spells = { 73920 }, fixedBody = CURSOR, fixedTooltip = "{1}" },
	{ name = "EUI_PurifySpirit", label = "Purify Spirit\n(Focus)", spells = { 77130 }, fixedBody = HELP, fixedTooltip = "{1}" },
}

-- Warlock (265 Affliction, 266 Demonology, 267 Destruction)
local LOCK_GEN = {
	{ name = "EUI_Shadowfury", label = "Shadowfury\n(Cursor)", spells = { 30283 }, fixedBody = CURSOR },
	{ name = "EUI_Gateway", label = "Demonic Gateway\n(Cursor)", spells = { 111771 }, fixedBody = CURSOR },
}
local LOCK_DEMO = {
	{ name = "EUI_AxeToss", label = "Axe Toss\n(Focus)", spells = { 89766 }, fixedBody = HARM, fixedTooltip = "{1}" }, -- Felguard
}
local LOCK_DESTRO = {
	{ name = "EUI_Havoc", label = "Havoc\n(Focus)", spells = { 80240 }, fixedBody = HARM, fixedTooltip = "{1}" },
	{ name = "EUI_Infernal", label = "Summon Infernal\n(Cursor)", spells = { 1122 }, fixedBody = CURSOR },
	{ name = "EUI_RainOfFire", label = "Rain of Fire\n(Cursor)", spells = { 5740 }, fixedBody = CURSOR },
}

-- Warrior (71 Arms, 72 Fury, 73 Protection)
local WARRIOR_GEN = {
	{ name = "EUI_Pummel", label = "Pummel\n(Focus)", spells = { 6552 }, fixedBody = HARM, fixedTooltip = "{1}" },
	{ name = "EUI_Intervene", label = "Intervene\n(Focus)", spells = { 3411 }, fixedBody = HELP, fixedTooltip = "{1}" },
	{ name = "EUI_HeroicLeap", label = "Heroic Leap\n(Cursor)", spells = { 6544 }, fixedBody = CURSOR, fixedTooltip = "{1}" },
}

MF.SPEC_DEFS = {
	[250] = mergeMacros(DK_BLOOD, DK_GEN),
	[251] = mergeMacros(DK_FROST, DK_GEN),
	[252] = mergeMacros(DK_UNHOLY, DK_GEN),
	[102] = mergeMacros(DRUID_BAL, DRUID_GEN, DRUID_DECURSE),
	[103] = mergeMacros(DRUID_FERAL, DRUID_GEN, DRUID_DECURSE),
	[104] = mergeMacros(DRUID_FERAL, DRUID_GEN, DRUID_DECURSE),
	[105] = mergeMacros(DRUID_RESTO, DRUID_GEN),
	[253] = mergeMacros(HUNTER_BM, HUNTER_GEN),
	[254] = mergeMacros(HUNTER_GEN),
	[255] = mergeMacros(HUNTER_GEN),
	[62]  = mergeMacros(MAGE_ARCANE, MAGE_GEN),
	[63]  = mergeMacros(MAGE_FIRE, MAGE_GEN),
	[64]  = mergeMacros(MAGE_FROST_SPEC, MAGE_GEN),
	[268] = mergeMacros(MONK_SPEAR, MONK_BREW, MONK_GEN),
	[269] = mergeMacros(MONK_SPEAR, MONK_GEN),
	[270] = mergeMacros(MONK_MW, MONK_GEN),
	[65]  = mergeMacros(PALA_GEN),
	[66]  = mergeMacros(PALA_REBUKE, PALA_GEN),
	[70]  = mergeMacros(PALA_REBUKE, PALA_GEN),
	[256] = mergeMacros(PRIEST_DISC, PRIEST_PURIFY, PRIEST_GEN),
	[257] = mergeMacros(PRIEST_HOLY, PRIEST_PURIFY, PRIEST_GEN),
	[258] = mergeMacros(PRIEST_SHADOW, PRIEST_GEN),
	[259] = mergeMacros(ROGUE_GEN),
	[260] = mergeMacros(ROGUE_GEN),
	[261] = mergeMacros(ROGUE_SUB, ROGUE_GEN),
	[262] = mergeMacros(SHAMAN_ELE, SHAMAN_GEN, SHAMAN_CLEANSE),
	[263] = mergeMacros(SHAMAN_ENH, SHAMAN_GEN, SHAMAN_CLEANSE),
	[264] = mergeMacros(SHAMAN_RESTO, SHAMAN_GEN),
	[265] = mergeMacros(LOCK_GEN),
	[266] = mergeMacros(LOCK_DEMO, LOCK_GEN),
	[267] = mergeMacros(LOCK_DESTRO, LOCK_GEN),
	[71]  = mergeMacros(WARRIOR_GEN),
	[72]  = mergeMacros(WARRIOR_GEN),
	[73]  = mergeMacros(WARRIOR_GEN),
}

-- Every def by macro name (combat queue, inventory updates).
local function FindDef(name)
	for _, def in ipairs(MF.GENERAL_DEFS) do
		if def.name == name then return def end
	end
	for _, list in pairs(MF.SPEC_DEFS) do
		for _, def in ipairs(list) do
			if def.name == name then return def end
		end
	end
end
MF.FindDef = FindDef

---------------------------------------------------------------------------
-- Spec
---------------------------------------------------------------------------
function MF.ActiveSpec()
	local idx = GetSpecialization and GetSpecialization()
	if not idx then return nil end
	local id, name = GetSpecializationInfo(idx)
	return id, name
end

function MF.SpecDefs(specID)
	return specID and MF.SPEC_DEFS[specID] or {}
end

---------------------------------------------------------------------------
-- Saved settings
---------------------------------------------------------------------------
function MF.GetDB(macroName)
	local q = Q.DB()
	if type(q.macroFactory) ~= "table" then q.macroFactory = {} end
	local all = q.macroFactory
	if type(all[macroName]) ~= "table" then all[macroName] = {} end
	return all[macroName]
end

-- Item options in priority order (db.order, else list order).
local function Ordered(def, db)
	local cbs = def.checkboxes
	local order = db.order
	if type(order) ~= "table" or #order < #cbs then
		order = {}
		for i = 1, #cbs do order[i] = i end
	end
	return order
end
MF.Ordered = Ordered

---------------------------------------------------------------------------
-- Names and icons (5.4.8 item / spell data is read right away; an item that
-- is not cached yet shows the English label until GET_ITEM_INFO_RECEIVED).
---------------------------------------------------------------------------
function MF.OptionName(opt)
	local ids = opt.items
	if ids and #ids == 1 then
		local n = GetItemInfo(ids[1])
		if n then return n end
	end
	return ns.L(opt.label)
end

local function SpellName(id)
	local name = GetSpellInfo(id)
	return name
end

-- Icon of the settings button: first enabled item, equipped trinket, or
-- the first spell; else the def's own icon.
function MF.ButtonIcon(def)
	local icon
	if def.checkboxes then
		local db = MF.GetDB(def.name)
		for _, idx in ipairs(Ordered(def, db)) do
			local cb = def.checkboxes[idx]
			if cb and db[cb.key] ~= false and cb.items and cb.items[1] then
				icon = GetItemIcon(cb.items[1])
				if icon then break end
			end
		end
	elseif def.fixedTooltip and tonumber(def.fixedTooltip) then
		icon = GetInventoryItemTexture("player", tonumber(def.fixedTooltip))
	elseif def.spells and def.spells[1] and not def.icon then
		icon = GetSpellTexture(def.spells[1])
	end
	return icon or def.icon or "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- Icon stored on the WoW macro (a texture name, no path). Single-spell and
-- item macros keep the "?" so #showtooltip picks the icon; combo macros
-- with no tooltip get their first spell's icon.
local function MacroIcon(def)
	if def.macroIcon then return def.macroIcon end
	if def.spells and def.fixedBody and not def.fixedTooltip then
		local tex = def.spells[1] and GetSpellTexture(def.spells[1])
		if type(tex) == "string" then
			return tex:match("([^\\/]+)$") or tex
		end
	end
	return "INV_MISC_QUESTIONMARK"
end

---------------------------------------------------------------------------
-- Macro text
---------------------------------------------------------------------------
local function FirstItemInBags(def, db)
	if not def.checkboxes then return nil end
	for _, idx in ipairs(Ordered(def, db)) do
		local cb = def.checkboxes[idx]
		if cb and db[cb.key] ~= false then
			for _, itemID in ipairs(cb.items) do
				if (GetItemCount(itemID) or 0) > 0 then
					return itemID
				end
			end
		end
	end
	return nil
end

-- {n} -> client name of spells[n]. nil when a spell ID is unknown.
local function ResolveSpellTokens(text, spells)
	if not text then return nil end
	if not spells or not text:find("{%d+}") then return text end
	local missing = false
	local out = text:gsub("{(%d+)}", function(n)
		local id = spells[tonumber(n)]
		if not id then return "{" .. n .. "}" end
		local name = SpellName(id)
		if name then return name end
		missing = true
		return ""
	end)
	if missing then return nil end
	return out
end

-- Full macro text; nil = cannot be built (do not write anything).
function MF.BuildBody(def, db)
	db = db or MF.GetDB(def.name)
	if def.checkboxes then
		local items, firstItemID = {}, nil
		for _, idx in ipairs(Ordered(def, db)) do
			local cb = def.checkboxes[idx]
			if cb and db[cb.key] ~= false then
				for _, itemID in ipairs(cb.items) do
					firstItemID = firstItemID or itemID
					items[#items + 1] = itemID
				end
			end
		end
		if #items == 0 then return "" end
		local body = ""
		if db.showTooltip ~= false then
			local tipID = FirstItemInBags(def, db) or firstItemID
			if tipID then body = "#showtooltip item:" .. tipID .. "\n" end
		end
		local lines = {}
		for _, itemID in ipairs(items) do
			lines[#lines + 1] = "/use item:" .. itemID
		end
		return body .. table.concat(lines, "\n")
	elseif def.fixedBody then
		local fbody = ResolveSpellTokens(def.fixedBody, def.spells)
		if fbody == nil then return nil end
		local body = ""
		if db.showTooltip ~= false and def.fixedTooltip then
			local tip = ResolveSpellTokens(def.fixedTooltip, def.spells)
			if tip == nil then return nil end
			body = "#showtooltip " .. tip .. "\n"
		elseif db.showTooltip ~= false then
			body = "#showtooltip\n"
		end
		if def.extraBody then
			local extra = def.extraBody(db)
			if extra and extra ~= "" then
				return body .. fbody .. "\n" .. extra
			end
		end
		return body .. fbody
	end
	return ""
end

---------------------------------------------------------------------------
-- Writing macros
---------------------------------------------------------------------------
local function MacroIndex(name)
	local idx = GetMacroIndexByName(name)
	if idx and idx ~= 0 then return idx end
	return nil
end

function MF.Exists(def)
	return MacroIndex(def.name) ~= nil
end

-- Last item seen in bags per item macro (rewrite only when it changes).
local lastItem = {}
local pending = {}
local waitFrame = CreateFrame("Frame")

-- Create the macro. Returns true, or false + a reason ("combat", "full",
-- "data").
function MF.Create(def)
	if InCombatLockdown() then return false, "combat" end
	if MF.Exists(def) then return true end
	local db = MF.GetDB(def.name)
	local body = MF.BuildBody(def, db)
	if body == nil then return false, "data" end
	-- 36 account + 18 character macros in 5.4.8 (the constants live in the
	-- load-on-demand Blizzard_MacroUI).
	local numAccount, numChar = GetNumMacros()
	local perCharacter = nil
	if (numAccount or 0) >= (MAX_ACCOUNT_MACROS or 36) then
		if (numChar or 0) >= (MAX_CHARACTER_MACROS or 18) then
			return false, "full"
		end
		perCharacter = 1
	end
	CreateMacro(def.name, MacroIcon(def), body, perCharacter)
	lastItem[def.name] = FirstItemInBags(def, db)
	return true
end

function MF.Delete(def)
	if InCombatLockdown() then return false, "combat" end
	local idx = MacroIndex(def.name)
	if idx then DeleteMacro(idx) end
	return true
end

-- Rewrite an existing macro after a setting changed; in combat, after it.
function MF.Update(def)
	if not MacroIndex(def.name) then return end
	if InCombatLockdown() then
		pending[def.name] = true
		waitFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
		return
	end
	local body = MF.BuildBody(def, MF.GetDB(def.name))
	local idx = MacroIndex(def.name)
	if body and idx then EditMacro(idx, nil, nil, body) end
end

local function ProcessPending()
	for name in pairs(pending) do
		pending[name] = nil
		local def = FindDef(name)
		if def then MF.Update(def) end
	end
end

-- Item macros follow the bags: the #showtooltip item is the first one owned.
local function UpdateItemMacros()
	if InCombatLockdown() then return end
	for _, def in ipairs(MF.GENERAL_DEFS) do
		if def.checkboxes and MacroIndex(def.name) then
			local now = FirstItemInBags(def, MF.GetDB(def.name))
			if now ~= lastItem[def.name] then
				lastItem[def.name] = now
				MF.Update(def)
			end
		end
	end
end
MF.UpdateItemMacros = UpdateItemMacros

-- Short message for a failed create / delete.
function MF.Explain(reason)
	if reason == "combat" then
		Q.Print(ns.L("Macros cannot be changed in combat."))
	elseif reason == "full" then
		Q.Print(ns.L("No free macro slots (36 account, 18 character)."))
	elseif reason == "data" then
		Q.Print(ns.L("This macro uses a spell this client does not know."))
	end
end

---------------------------------------------------------------------------
-- Events: bags (throttled), end of combat, login, spec change
---------------------------------------------------------------------------
MF.specListeners = {}
local bagPending = false
waitFrame:SetScript("OnEvent", function(self, event, unit)
	if event == "PLAYER_REGEN_ENABLED" then
		self:UnregisterEvent("PLAYER_REGEN_ENABLED")
		ProcessPending()
		UpdateItemMacros()
	elseif event == "PLAYER_ENTERING_WORLD" then
		Q.After(1, UpdateItemMacros)
	elseif event == "BAG_UPDATE" then
		if not bagPending then
			bagPending = true
			Q.After(0.5, function()
				bagPending = false
				if InCombatLockdown() then
					-- Written when combat ends.
					waitFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
				else
					UpdateItemMacros()
				end
			end)
		end
	elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
		if unit and unit ~= "player" then return end
		for _, fn in ipairs(MF.specListeners) do
			local ok, err = pcall(fn)
			if not ok and geterrorhandler then geterrorhandler()(err) end
		end
	end
end)
waitFrame:RegisterEvent("BAG_UPDATE")
waitFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
waitFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
