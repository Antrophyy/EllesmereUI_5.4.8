-- Avoidable damage spells (5.4.8) for the Avoidable Damage Taken meter type.
-- Damage a group player takes from one of these spells counts as avoidable.
--   true        = avoidable for everyone
--   "nontank"   = avoidable for players who are not tanks (frontal attacks)
--   "nontarget" = avoidable for everyone except the player the cast targets
-- IDs come from the DBM 5.4.8 boss modules or from memory; the spell log
-- (EllesmereUIDamageMetersSpellLog, see the engine) is used to correct them.

local ns = EllesmereUI
ns.EDMAvoidable = {
	-- Siege of Orgrimmar ------------------------------------------------
	-- Immerseus
	[143297] = true, -- Sha Splash
	[143412] = true, -- Swirl
	[143436] = "nontank", -- Corrosive Blast
	-- Fallen Protectors
	[144357] = true, -- Defiled Ground
	[143959] = true, -- Defiled Ground (tank pool)
	[144367] = true, -- Noxious Poison
	[143009] = true, -- Corruption Kick
	[144397] = "nontank", -- Vengeful Strikes
	-- Norushen
	[145227] = true, -- Blind Hatred
	[144482] = true, -- Tear Reality
	[146703] = true, -- Bottomless Pit
	[144628] = true, -- Titanic Smash
	-- Sha of Pride
	[144911] = true, -- Bursting Pride
	[144788] = true, -- Self-Reflection
	-- Galakras
	[146764] = true, -- Flame Arrows
	[147705] = true, -- Poison Cloud
	[147825] = true, -- Muzzle Spray
	[147688] = true, -- Arcing Smash
	-- Iron Juggernaut
	[144218] = true, -- Borer Drill
	[144498] = true, -- Explosive Tar
	[144918] = true, -- Cutter Laser
	[144556] = true, -- Mortar Barrage
	[144356] = true, -- Ricochet
	-- Kor'kron Dark Shaman
	[144064] = true, -- Foulness
	[144029] = true, -- Toxic Tornado
	[144072] = true, -- Ashen Wall
	[144334] = true, -- Iron Tomb
	[143993] = true, -- Foul Geyser
	[144090] = "nontarget", -- Foul Stream
	-- General Nazgrim
	[143873] = true, -- Ravager
	[143500] = true, -- Heroic Shockwave
	[143712] = true, -- Aftershock
	-- Malkorok
	[143805] = true, -- Arcing Smash
	[142816] = true, -- Breath of Y'Shaarj
	-- Spoils of Pandaria
	[145716] = true, -- Blazing Charge
	[145748] = true, -- Bubbling Amber
	[146257] = true, -- Path of Blossoms
	[146182] = true, -- Gusting Crane Kick
	[145285] = true, -- Encapsulated Pheromones
	-- Thok the Bloodthirsty
	[143784] = true, -- Burning Blood (pool)
	[143428] = true, -- Tail Lash
	[143426] = "nontank", -- Fearsome Roar
	[143780] = "nontank", -- Acid Breath
	[143773] = "nontank", -- Freezing Breath
	[143767] = "nontank", -- Scorching Breath
	-- Siegecrafter Blackfuse
	[143856] = true, -- Superheated
	[143327] = true, -- Sawblade
	[143867] = true, -- Disintegration Laser
	[143642] = true, -- Shockwave Missile
	[144210] = true, -- Death from Above
	-- Paragons of the Klaxxi
	[143735] = true, -- Caustic Amber
	[143701] = true, -- Whirling
	[142809] = true, -- Fiery Edge
	[143243] = true, -- Rapid Fire
	[148676] = true, -- Reave
	[142726] = true, [142727] = true, [142728] = true, [142729] = true, [142730] = true, -- Catalysts
	-- Garrosh Hellscream
	[144798] = true, -- Exploding Iron Star
	[144762] = true, -- Desecrated
	[144969] = true, -- Annihilate
}
