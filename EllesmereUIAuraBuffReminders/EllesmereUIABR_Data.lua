-------------------------------------------------------------------------------
--  EllesmereUIABR_Data.lua (5.4.8 port of the retail AuraBuff Reminders data)
--
--  Every spell / item list of the module in ONE table (P.DATA). Retail's
--  Midnight buffs, flasks and foods are replaced by Mists of Pandaria 5.4.8
--  data. IDs marked "unsure" were written from memory and not verified in
--  game; everything is looked up with GetSpellInfo / GetItemInfo at run time,
--  so a wrong ID only hides that one entry.
-------------------------------------------------------------------------------
local addonName, P = ...

local D = {}
P.DATA = D

-------------------------------------------------------------------------------
--  Raid buff categories (MoP: 8 categories, any provider satisfies one).
--  buffs = every aura that counts for the category.
-------------------------------------------------------------------------------
D.CATEGORIES = {
	stats = { name = "Stats", buffs = {
		1126,    -- Mark of the Wild (Druid)
		20217,   -- Blessing of Kings (Paladin)
		115921,  -- Legacy of the Emperor (Monk)
		117666,  -- Legacy of the Emperor (group aura) -- unsure
		90363,   -- Embrace of the Shale Spider (Hunter pet)
	} },
	stamina = { name = "Stamina", buffs = {
		21562,   -- Power Word: Fortitude (Priest)
		469,     -- Commanding Shout (Warrior)
		6307,    -- Blood Pact (Warlock Imp)
		109773,  -- Dark Intent (Warlock: spell power + stamina in MoP)
		90364,   -- Qiraji Fortitude (Hunter pet)
	} },
	attackPower = { name = "Attack Power", buffs = {
		6673,    -- Battle Shout (Warrior)
		57330,   -- Horn of Winter (Death Knight)
		19506,   -- Trueshot Aura (Hunter)
	} },
	spellPower = { name = "Spell Power", buffs = {
		1459,    -- Arcane Brilliance (Mage)
		61316,   -- Dalaran Brilliance (Mage)
		109773,  -- Dark Intent (Warlock)
		77747,   -- Burning Wrath (Shaman)
		126309,  -- Still Water (Hunter pet)
	} },
	attackSpeed = { name = "Attack Speed", buffs = {
		55610,   -- Unholy Aura (Death Knight)
		113742,  -- Swiftblade's Cunning (Rogue)
		30809,   -- Unleashed Rage (Shaman)
		128432,  -- Cackling Howl (Hunter pet)
		128433,  -- Serpent's Swiftness (Hunter pet)
	} },
	spellHaste = { name = "Spell Haste", buffs = {
		24907,   -- Moonkin Aura (Druid)
		15473,   -- Shadowform (Priest)
		49868,   -- Mind Quickening (Shadowform raid aura) -- unsure
		51470,   -- Elemental Oath (Shaman)
		135678,  -- Energizing Spores (Hunter pet) -- unsure
	} },
	crit = { name = "Critical Strike", buffs = {
		1459,    -- Arcane Brilliance (Mage)
		61316,   -- Dalaran Brilliance (Mage)
		17007,   -- Leader of the Pack (Druid)
		24932,   -- Leader of the Pack (aura) -- unsure
		116781,  -- Legacy of the White Tiger (Monk)
		24604,   -- Furious Howl (Hunter pet)
		90309,   -- Terrifying Roar (Hunter pet)
		126373,  -- Fearless Roar (Hunter pet)
		126309,  -- Still Water (Hunter pet)
	} },
	mastery = { name = "Mastery", buffs = {
		19740,   -- Blessing of Might (Paladin)
		116956,  -- Grace of Air (Shaman)
		93435,   -- Roar of Courage (Hunter pet)
		128997,  -- Spirit Beast Blessing (Hunter pet)
	} },
}
D.CATEGORY_ORDER = { "stats", "stamina", "attackPower", "spellPower", "attackSpeed", "spellHaste", "crit", "mastery" }

-- Which categories a class can bring at all (casts, passives, pets). Used
-- for the receiver view and to pick the best blessing / shout.
D.CLASS_PROVIDES = {
	DRUID       = { stats = true, crit = true, spellHaste = true },
	PALADIN     = { stats = true, mastery = true },
	MONK        = { stats = true, crit = true },
	PRIEST      = { stamina = true, spellHaste = true },
	WARRIOR     = { attackPower = true, stamina = true },
	WARLOCK     = { stamina = true, spellPower = true },
	MAGE        = { spellPower = true, crit = true },
	DEATHKNIGHT = { attackPower = true, attackSpeed = true },
	HUNTER      = { attackPower = true },
	ROGUE       = { attackSpeed = true },
	SHAMAN      = { spellPower = true, mastery = true, attackSpeed = true, spellHaste = true },
}

-------------------------------------------------------------------------------
--  Raid buffs the player can cast (retail RAID_BUFFS, same "raidbuff:<key>"
--  model). cats = categories the cast fills. group = one active per caster
--  on a target (blessings, shouts): the collector shows only one of them.
-------------------------------------------------------------------------------
D.RAID_BUFFS = {
	{ key = "motw",   class = "DRUID",       name = "Mark of the Wild",          castSpell = 1126,   cats = { "stats" } },
	{ key = "bok",    class = "PALADIN",     name = "Blessing of Kings",         castSpell = 20217,  cats = { "stats" },   group = "blessing" },
	{ key = "bom",    class = "PALADIN",     name = "Blessing of Might",         castSpell = 19740,  cats = { "mastery" }, group = "blessing" },
	{ key = "loe",    class = "MONK",        name = "Legacy of the Emperor",     castSpell = 115921, cats = { "stats" } },
	{ key = "lowt",   class = "MONK",        name = "Legacy of the White Tiger", castSpell = 116781, cats = { "crit" } },
	{ key = "fort",   class = "PRIEST",      name = "Power Word: Fortitude",     castSpell = 21562,  cats = { "stamina" } },
	{ key = "ai",     class = "MAGE",        name = "Arcane Brilliance",         castSpell = 1459,   cats = { "spellPower", "crit" },
	  altCast = 61316 },  -- Dalaran Brilliance when known
	{ key = "di",     class = "WARLOCK",     name = "Dark Intent",               castSpell = 109773, cats = { "spellPower" }, benefit = "intellect" },
	{ key = "bshout", class = "WARRIOR",     name = "Battle Shout",              castSpell = 6673,   cats = { "attackPower" }, benefit = "attackPower", group = "shout" },
	{ key = "cshout", class = "WARRIOR",     name = "Commanding Shout",          castSpell = 469,    cats = { "stamina" },     group = "shout" },
	{ key = "how",    class = "DEATHKNIGHT", name = "Horn of Winter",            castSpell = 57330,  cats = { "attackPower" }, benefit = "attackPower" },
}

-- Stat-filtered buffs: classes / specs that use the stat.
D.BENEFIT_CLASSES = {
	intellect   = { MAGE = true, WARLOCK = true, PRIEST = true, DRUID = true, SHAMAN = true, MONK = true, PALADIN = true },
	attackPower = { WARRIOR = true, ROGUE = true, HUNTER = true, DEATHKNIGHT = true, PALADIN = true, MONK = true, DRUID = true, SHAMAN = true },
}

-------------------------------------------------------------------------------
--  Auras (retail AURAS): class self-buffs, stances, forms, presences.
--    buffIDs   = auras that satisfy it (player buff check)
--    stance    = spell IDs of shapeshift forms that satisfy it (stance bar)
--    anyForm   = any active shapeshift form satisfies it
--    castFn    = picks the spell to cast (by spec), else castSpell
--    check     = "ownOnGroup" (own cast on a group member) / "ownGroupOrSelf"
-------------------------------------------------------------------------------
D.AURAS = {
	-- Warrior stances (Arms / Fury: Battle or Berserker, Protection: Defensive)
	{ key = "battle_stance", class = "WARRIOR", name = "Battle Stance",    castSpell = 2457, specs = { 71, 72 }, stance = { 2457, 2458 } },
	{ key = "def_stance",    class = "WARRIOR", name = "Defensive Stance", castSpell = 71,   specs = { 73 },     stance = { 71 } },
	-- Priest
	{ key = "shadowform", class = "PRIEST", name = "Shadowform", castSpell = 15473, specs = { 258 }, buffIDs = { 15473 } },
	{ key = "inner_fire", class = "PRIEST", name = "Inner Fire", castSpell = 588,   buffIDs = { 588, 73413 } },  -- or Inner Will
	-- Paladin
	{ key = "righteous_fury", class = "PALADIN", name = "Righteous Fury", castSpell = 25780, specs = { 66 }, buffIDs = { 25780 } },
	{ key = "bol", class = "PALADIN", name = "Beacon of Light", castSpell = 53563, specs = { 65 }, buffIDs = { 53563 },
	  check = "ownOnGroup", requireInstanceGroup = true },
	-- Druid
	{ key = "moonkin",    class = "DRUID", name = "Moonkin Form", castSpell = 24858,  specs = { 102 }, buffIDs = { 24858 } },
	{ key = "symbiotic",  class = "DRUID", name = "Symbiosis",    castSpell = 110309, buffIDs = { 110309 },
	  requireGroup = true, nameFallback = true },  -- caster-side buff ID unsure: the name check backs it up
	-- Death Knight presences
	{ key = "blood_presence",  class = "DEATHKNIGHT", name = "Blood Presence",  castSpell = 48263, specs = { 250 }, stance = { 48263 } },
	{ key = "frost_presence",  class = "DEATHKNIGHT", name = "Frost Presence",  castSpell = 48266, specs = { 251 }, stance = { 48266 } },
	{ key = "unholy_presence", class = "DEATHKNIGHT", name = "Unholy Presence", castSpell = 48265, specs = { 252 }, stance = { 48265 } },
	-- Monk stances
	{ key = "ox_stance",      class = "MONK", name = "Stance of the Sturdy Ox",   castSpell = 115069, specs = { 268 }, stance = { 115069 } },
	{ key = "tiger_stance",   class = "MONK", name = "Stance of the Fierce Tiger", castSpell = 103985, specs = { 269 }, stance = { 103985 } },
	{ key = "serpent_stance", class = "MONK", name = "Stance of the Wise Serpent", castSpell = 115070, specs = { 270 }, stance = { 115070 } },
	-- Hunter aspects (any aspect counts, so travelling with Cheetah / Pack never nags)
	{ key = "aspect", class = "HUNTER", name = "Aspect of the Hawk", castSpell = 13165, castFn = "hunterAspect",
	  buffIDs = { 13165, 109260, 5118, 13159, 82661 } },
	-- Mage armors (cast by spec: Arcane = Mage Armor, Fire = Molten, Frost = Frost Armor)
	{ key = "mage_armor", class = "MAGE", name = "Molten Armor", castSpell = 30482, castFn = "mageArmor",
	  buffIDs = { 30482, 7302, 6117 } },
	-- Warlock
	{ key = "soulstone", class = "WARLOCK", name = "Soulstone", castSpell = 20707, buffIDs = { 20707 },
	  check = "ownGroupOrSelf" },
}

D.HUNTER_ASPECTS = { 109260, 13165 }   -- Iron Hawk (talent) first, then Hawk
D.MAGE_ARMOR_BY_SPEC = { [62] = 6117, [63] = 30482, [64] = 7302 }

-------------------------------------------------------------------------------
--  Class specials (retail "consumables" section keys)
-------------------------------------------------------------------------------
-- Rogue poisons (MoP: one lethal + one non-lethal, both are 1 h self buffs).
D.ROGUE_POISONS = {
	{ key = "deadly",    name = "Deadly Poison",       castSpell = 2823,   cat = "lethal" },
	{ key = "wound",     name = "Wound Poison",        castSpell = 8679,   cat = "lethal" },
	{ key = "crippling", name = "Crippling Poison",    castSpell = 3408,   cat = "nonlethal" },
	{ key = "numbing",   name = "Mind-numbing Poison", castSpell = 5761,   cat = "nonlethal" },
	{ key = "leeching",  name = "Leeching Poison",     castSpell = 108211, cat = "nonlethal" },
	{ key = "paralytic", name = "Paralytic Poison",    castSpell = 108215, cat = "nonlethal" },
}

-- Paladin seals (retail section: Paladin Rites). Seals are stance-bar forms;
-- any active seal satisfies the reminder. bySpec = the seal to cast.
D.PALADIN_SEALS = {
	{ key = "seal_truth",         name = "Seal of Truth",         castSpell = 31801 },
	{ key = "seal_righteousness", name = "Seal of Righteousness", castSpell = 20154 },
	{ key = "seal_insight",       name = "Seal of Insight",       castSpell = 20165 },
	{ key = "seal_justice",       name = "Seal of Justice",       castSpell = 20164 },
}
D.SEAL_BY_SPEC = { [65] = "seal_insight", [66] = "seal_insight", [70] = "seal_truth" }

-- Shaman weapon imbues (GetWeaponEnchantInfo: 5.4.8 has no enchant id, so a
-- slot only knows "has a temporary enchant"). slot by spec: which weapon the
-- imbue belongs on.
D.SHAMAN_IMBUES = {
	{ key = "windfury",    name = "Windfury Weapon",    castSpell = 8232 },
	{ key = "flametongue", name = "Flametongue Weapon", castSpell = 8024 },
	{ key = "earthliving", name = "Earthliving Weapon", castSpell = 51730 },
	{ key = "frostbrand",  name = "Frostbrand Weapon",  castSpell = 8033 },
	{ key = "rockbiter",   name = "Rockbiter Weapon",   castSpell = 8017 },
}
D.IMBUE_BY_SPEC = {
	[262] = { mh = "flametongue" },                     -- Elemental
	[263] = { mh = "windfury", oh = "flametongue" },    -- Enhancement
	[264] = { mh = "earthliving" },                     -- Restoration
}

-- Shaman shields: shield_basic = Lightning / Water Shield on self (Resto
-- casts Water Shield); es_ally = own Earth Shield on a group member.
D.SHAMAN_SHIELDS = {
	{ key = "shield_basic", name = "Shield", castSpell = 324, buffIDs = { 324, 52127 } },
	{ key = "es_ally", name = "Earth Shield (Ally)", castSpell = 974, buffIDs = { 974 } },
}
D.WATER_SHIELD = 52127

-- Warlock demons (Wrong Demon check). family = English creature family
-- names (5.4.8 UnitCreatureFamily returns the name only), sup = the Grimoire
-- of Supremacy summon.
D.WARLOCK_PETS = {
	{ key = "felguard",   name = "Felguard",   castSpell = 30146, sup = 112870, families = { Felguard = true, Wrathguard = true } },
	{ key = "imp",        name = "Imp",        castSpell = 688,   sup = 112866, families = { Imp = true, ["Fel Imp"] = true } },
	{ key = "voidwalker", name = "Voidwalker", castSpell = 697,   sup = 112867, families = { Voidwalker = true, Voidlord = true } },
	{ key = "sayaad",     name = "Succubus",   castSpell = 712,   sup = 112868, families = { Succubus = true, Shivarra = true } },
	{ key = "felhunter",  name = "Felhunter",  castSpell = 691,   sup = 112869, families = { Felhunter = true, Observer = true } },
}
D.GRIMOIRE_OF_SACRIFICE = 108503

-- Permanent pets
D.PET_CLASSES = { HUNTER = true, WARLOCK = true, DEATHKNIGHT = true, MAGE = true }
D.CALL_PET = 883
D.RAISE_DEAD = 46584
D.WATER_ELEMENTAL = 31687

-------------------------------------------------------------------------------
--  Consumables (Mists of Pandaria 5.4.8)
-------------------------------------------------------------------------------
D.FLASK_ITEMS = {
	{ key = "spring_blossoms", name = "Flask of Spring Blossoms", stat = "AGI", items = { 76084 }, buffID = 105689 },
	{ key = "warm_sun",        name = "Flask of the Warm Sun",    stat = "INT", items = { 76085 }, buffID = 105691 },
	{ key = "winters_bite",    name = "Flask of Winter's Bite",   stat = "STR", items = { 76088 }, buffID = 105696 },
	{ key = "earth",           name = "Flask of the Earth",       stat = "STA", items = { 76087 }, buffID = 105694 },
	{ key = "falling_leaves",  name = "Flask of Falling Leaves",  stat = "SPI", items = { 76086 }, buffID = 105693 },
	{ key = "alchemists",      name = "Alchemist's Flask",        stat = "ANY", items = { 75525 }, buffID = 79639 },
	{ key = "crystal_insanity", name = "Crystal of Insanity",     stat = "ANY", items = { 86569 }, buffID = 127230 },  -- unsure buff id
}
-- Extra auras that count as "flasked" (Alchemist's Flask by stat).
D.FLASK_EXTRA_BUFFS = { 79638, 79639, 79640 }

-- Food: any "Well Fed" buff satisfies it. 300-stat foods first.
D.FOOD_ITEMS = {
	{ key = "black_pepper_ribs",   itemID = 74646, name = "Black Pepper Ribs and Shrimp", stat = "STR" },
	{ key = "sea_mist_noodles",    itemID = 74648, name = "Sea Mist Rice Noodles",        stat = "AGI" },
	{ key = "mogu_fish_stew",      itemID = 74650, name = "Mogu Fish Stew",               stat = "INT" },
	{ key = "steamed_crab",        itemID = 74653, name = "Steamed Crab Surprise",        stat = "SPI" },
	{ key = "chun_tian_rolls",     itemID = 74656, name = "Chun Tian Spring Rolls",       stat = "STA" },
	-- 250-stat foods -- unsure item IDs
	{ key = "tiger_steak",         itemID = 74642, name = "Charbroiled Tiger Steak",      stat = "STR" },
	{ key = "sauteed_carrots",     itemID = 74643, name = "Sauteed Carrots",              stat = "AGI" },
	{ key = "swirling_mist_soup",  itemID = 74644, name = "Swirling Mist Soup",           stat = "INT" },
	{ key = "valley_stir_fry",     itemID = 74647, name = "Valley Stir Fry",              stat = "AGI" },
	{ key = "braised_turtle",      itemID = 74649, name = "Braised Turtle",               stat = "INT" },
	{ key = "fire_spirit_salmon",  itemID = 74652, name = "Fire Spirit Salmon",           stat = "SPI" },
	{ key = "twin_fish_platter",   itemID = 74655, name = "Twin Fish Platter",            stat = "STA" },
}
D.WELL_FED_SPELL = 19705        -- "Well Fed" (name source, localized)
D.FOOD_SPELLS = { 433, 104934 } -- "Food" eating auras (name source) -- 104934 unsure

D.HEALTHSTONE_ITEM = 5512
D.HEALTHSTONE_ICON = "Interface\\Icons\\INV_Stone_04"
D.RUNEFORGING = 53428
D.RUNEFORGE_ICON = "Interface\\Icons\\Spell_DeathKnight_FrozenRuneWeapon"
D.PET_ICON = "Interface\\Icons\\Ability_Hunter_BeastCall"
D.WARLOCK_PET_ICON = "Interface\\Icons\\Spell_Shadow_SummonImp"
D.FOOD_ICON = "Interface\\Icons\\INV_Misc_Food_15"
D.FLASK_ICON = "Interface\\Icons\\INV_Alchemy_Potion_06"
D.EATING_ICON = "Interface\\Icons\\INV_Misc_Fork&Knife"

-------------------------------------------------------------------------------
--  Talent reminder zones (Mists of Pandaria instances by GetInstanceInfo name)
-------------------------------------------------------------------------------
D.TALENT_ZONES = {
	{ name = "Mogu'shan Vaults",            type = "raid" },
	{ name = "Heart of Fear",               type = "raid" },
	{ name = "Terrace of Endless Spring",   type = "raid" },
	{ name = "Throne of Thunder",           type = "raid" },
	{ name = "Siege of Orgrimmar",          type = "raid" },

	{ name = "Temple of the Jade Serpent",  type = "dungeon" },
	{ name = "Stormstout Brewery",          type = "dungeon" },
	{ name = "Shado-Pan Monastery",         type = "dungeon" },
	{ name = "Mogu'shan Palace",            type = "dungeon" },
	{ name = "Gate of the Setting Sun",     type = "dungeon" },
	{ name = "Siege of Niuzao Temple",      type = "dungeon" },
	{ name = "Scarlet Halls",               type = "dungeon" },
	{ name = "Scarlet Monastery",           type = "dungeon" },
	{ name = "Scholomance",                 type = "dungeon" },

	{ name = "Nagrand Arena",               type = "pvp" },
	{ name = "Blade's Edge Arena",          type = "pvp" },
	{ name = "Ruins of Lordaeron",          type = "pvp" },
	{ name = "Dalaran Arena",               type = "pvp" },
	{ name = "The Ring of Valor",           type = "pvp" },
	{ name = "Tol'viron Arena",             type = "pvp" },
	{ name = "The Tiger's Peak",            type = "pvp" },
	{ name = "Warsong Gulch",               type = "pvp" },
	{ name = "Arathi Basin",                type = "pvp" },
	{ name = "Alterac Valley",              type = "pvp" },
	{ name = "Eye of the Storm",            type = "pvp" },
	{ name = "Strand of the Ancients",      type = "pvp" },
	{ name = "Isle of Conquest",            type = "pvp" },
	{ name = "Twin Peaks",                  type = "pvp" },
	{ name = "The Battle for Gilneas",      type = "pvp" },
	{ name = "Silvershard Mines",           type = "pvp" },
	{ name = "Temple of Kotmogu",           type = "pvp" },
	{ name = "Deepwind Gorge",              type = "pvp" },
	{ name = "Wintergrasp",                 type = "pvp" },
	{ name = "Tol Barad",                   type = "pvp" },
}

-------------------------------------------------------------------------------
--  Reminder sounds (retail EllesmereUI alert sound catalogue, own copies)
-------------------------------------------------------------------------------
D.SOUND_FILES = {
	airhorn = "AirHorn.ogg", banana = "BananaPeelSlip.ogg", bikehorn = "BikeHorn.ogg",
	bite = "Bite.ogg", boxing = "BoxingArenaSound.ogg", catmeow = "CatMeow.ogg",
	catmeow2 = "CatMeow2.ogg", gunshot = "FrontalsGunshot.wav", glass = "Glass.mp3",
	kaching = "Kaching.ogg", phone = "Phone.ogg", robotblip = "RobotBlip.ogg",
	sonar = "Sonar.ogg", siren = "WarningSiren.ogg", water = "WaterDrop.ogg",
	wilhelm = "Wilhelm.ogg",
}
D.SOUND_NAMES = {
	none = "None", airhorn = "Air Horn", banana = "Banana Peel Slip",
	bikehorn = "Bike Horn", bite = "Bite", boxing = "Boxing Arena",
	catmeow = "Cat Meow", catmeow2 = "Cat Meow 2", gunshot = "Frontals Gunshot",
	glass = "Glass", kaching = "Kaching", phone = "Phone", robotblip = "Robot Blip",
	sonar = "Sonar", siren = "Warning Siren", water = "Water Drop", wilhelm = "Wilhelm",
}
D.SOUND_ORDER = {
	"none", "airhorn", "banana", "bikehorn", "bite", "boxing", "catmeow",
	"catmeow2", "gunshot", "glass", "kaching", "phone", "robotblip", "sonar",
	"siren", "water", "wilhelm",
}
