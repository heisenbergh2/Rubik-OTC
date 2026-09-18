-- chunkname: @/game_wheel/classes/icons.lua

KNIGHT = 1
PALADIN = 2
SORCERER = 3
DRUID = 4
MONK = 5
MediumPerkIconNames = {
	[0] = "Fire Resistance",
	"Energy Resistance",
	"Ice Resistance",
	"Earth Resistance",
	"Holy and Death Resistance",
	"Mana Leech",
	"Life Leech",
	"Weapon Skill Boost",
	"Battle Instinct",
	"Battle Healing",
	"Augmented Fierce Berserk|Aug. Fierce Berserk",
	"Augmented Intense Wound Cleansing|Aug. Intense Wound Cleansing",
	"Augmented Front Sweep|Aug. Front Sweep",
	"Augmented Groundshaker|Aug. Groundshaker",
	"Augmented Shield Slam|Aug. Shield Slam",
	"Distance Skill Boost",
	"Ballistic Mastery",
	"Ballistic Mastery",
	"Augmented Divine Caldera|Aug. Divine Caldera",
	"Augmented Divine Barrage|Aug. Divine Barrage",
	"Augmented Divine Dazzle|Aug. Divine Dazzle",
	"Augmented Strong Ethereal Spear|Aug. Strong Ethereal Spear",
	"Augmented Ethereal Barrage|Aug. Ethereal Barrage",
	"Focus Mastery",
	"Augmented Great Fire Wave|Aug. Great Fire Wave",
	"Augmented Energy Wave|Aug. Energy Wave",
	"Augmented Special Spells|Aug. Special Spells",
	"Augmented Focus Spells|Aug. Focus Spells",
	"Healing Link",
	"Augmented Forked Spells|Aug. Forked Spells",
	"Augmented Terra Wave|Aug. Terra Wave",
	"Augmented Strong Ice Wave|Aug. Strong Ice Wave",
	"Augmented Mass Healing|Aug. Mass Healing",
	"Augmented Heal Friend|Aug. Heal Friend",
	"Magic Skill Boost",
	"Runic Mastery",
	"Augmented Death Echo|Aug. Death Echo",
	"Vessel Resonance Top Left|VR Top Left",
	"Vessel Resonance Top Right|VR Top Right",
	"Vessel Resonance Bottom Left|VR Bottom Left",
	"Vessel Resonance Bottom Right|VR Bottom Right",
	"Sanctuary",
	"Guiding Presence",
	"Fist Fighting Skill Boost",
	"Augmented Thousand Fist Blows|Aug. Thousand Fist Blows",
	"Augmented Mass Spirit Mend|Aug. Mass Spirit Mend",
	"Augmented Mystic Repulse|Aug. Mystic Repulse",
	"Augmented Chained Penance|Aug. Chained Penance",
	"Augmented Flurry of Blows|Aug. Flurry of Blows"
}

function mediumPerkIconRect(iconIndex)
	return iconIndex * 30 .. " 0 30 30"
end

function getSupremeModIconClip(modID)
	return modID * 35 .. " 0 35 35"
end

GemEnums = {
	GREATER = 2,
	GUARDIAN = 1,
	LESSER = 0
}
GemDomains = {
	ACQUA = 2,
	RED = 1,
	GREEN = 0,
	PURPLE = 3
}
GemVocations = {
	[KNIGHT] = {
		[GemEnums.LESSER] = {
			name = "Lesser Guardian Gem (x 0)",
			id = 44602
		},
		[GemEnums.GUARDIAN] = {
			name = "Guardian Gem (x 0)",
			id = 44603
		},
		[GemEnums.GREATER] = {
			name = "Greater Guardian Gem (x 0)",
			id = 44604
		}
	},
	[PALADIN] = {
		[GemEnums.LESSER] = {
			name = "Lesser Marksman Gem (x 0)",
			id = 44605
		},
		[GemEnums.GUARDIAN] = {
			name = "Marksman Gem (x 0)",
			id = 44606
		},
		[GemEnums.GREATER] = {
			name = "Greater Marksman Gem (x 0)",
			id = 44607
		}
	},
	[SORCERER] = {
		[GemEnums.LESSER] = {
			name = "Lesser Sage Gem (x 0)",
			id = 44608
		},
		[GemEnums.GUARDIAN] = {
			name = "Sage Gem (x 0)",
			id = 44609
		},
		[GemEnums.GREATER] = {
			name = "Greater Sage Gem (x 0)",
			id = 44610
		}
	},
	[DRUID] = {
		[GemEnums.LESSER] = {
			name = "Lesser Mystic Gem (x 0)",
			id = 44611
		},
		[GemEnums.GUARDIAN] = {
			name = "Mystic Gem (x 0)",
			id = 44612
		},
		[GemEnums.GREATER] = {
			name = "Greater Mystic Gem (x 0)",
			id = 44613
		}
	},
	[MONK] = {
		[GemEnums.LESSER] = {
			name = "Lesser Spiritualist Gem (x 0)",
			id = 49371
		},
		[GemEnums.GUARDIAN] = {
			name = "Spiritualist Gem (x 0)",
			id = 49372
		},
		[GemEnums.GREATER] = {
			name = "Greater Spiritualist Gem (x 0)",
			id = 49373
		}
	}
}
RegularGemDescription = {
	[0] = {
		bonus1 = 1,
		type1 = "defense",
		text = "Physical Resistance"
	},
	{
		bonus1 = 1,
		type1 = "defense",
		text = "Holy Resistance"
	},
	{
		bonus1 = 1,
		type1 = "defense",
		text = "Death Resistance"
	},
	{
		bonus1 = 2,
		type1 = "defense",
		text = "Fire Resistance"
	},
	{
		bonus1 = 2,
		type1 = "defense",
		text = "Earth Resistance"
	},
	{
		bonus1 = 2,
		type1 = "defense",
		text = "Ice Resistance"
	},
	{
		bonus1 = 2,
		type1 = "defense",
		text = "Energy Resistance"
	},
	{
		type2 = "defense",
		bonus1 = 1.5,
		type1 = "defense",
		bonus2 = -1,
		text = "Holy Resistance\n-1% Death Resistance"
	},
	{
		type2 = "defense",
		bonus1 = 1.5,
		type1 = "defense",
		bonus2 = -1,
		text = "Death Resistance\n-1% Holy Resistance"
	},
	{
		type2 = "defense",
		bonus1 = 1,
		type1 = "defense",
		bonus2 = 1,
		text = "Fire Resistance\nEarth Resistance"
	},
	{
		type2 = "defense",
		bonus1 = 1,
		type1 = "defense",
		bonus2 = 1,
		text = "Fire Resistance\nIce Resistance"
	},
	{
		type2 = "defense",
		bonus1 = 1,
		type1 = "defense",
		bonus2 = 1,
		text = "Fire Resistance\nEnergy Resistance"
	},
	{
		type2 = "defense",
		bonus1 = 1,
		type1 = "defense",
		bonus2 = 1,
		text = "Earth Resistance\nIce Resistance"
	},
	{
		type2 = "defense",
		bonus1 = 1,
		type1 = "defense",
		bonus2 = 1,
		text = "Earth Resistance\nEnergy Resistance"
	},
	{
		type2 = "defense",
		bonus1 = 1,
		type1 = "defense",
		bonus2 = 1,
		text = "Ice Resistance\nEnergy Resistance"
	},
	{
		type2 = "defense",
		bonus1 = 3,
		type1 = "defense",
		bonus2 = -1,
		text = "Fire Resistance\n-2% Earth Resistance"
	},
	{
		type2 = "defense",
		bonus1 = 3,
		type1 = "defense",
		bonus2 = -1,
		text = "Fire Resistance\n-2% Ice Resistance"
	},
	{
		type2 = "defense",
		bonus1 = 3,
		type1 = "defense",
		bonus2 = -1,
		text = "Fire Resistance\n-2% Energy Resistance"
	},
	{
		type2 = "defense",
		bonus1 = 3,
		type1 = "defense",
		bonus2 = -1,
		text = "Earth Resistance\n-2% Fire Resistance"
	},
	{
		type2 = "defense",
		bonus1 = 3,
		type1 = "defense",
		bonus2 = -1,
		text = "Earth Resistance\n-2% Ice Resistance"
	},
	{
		type2 = "defense",
		bonus1 = 3,
		type1 = "defense",
		bonus2 = -1,
		text = "Earth Resistance\n-2% Energy Resistance"
	},
	{
		type2 = "defense",
		bonus1 = 3,
		type1 = "defense",
		bonus2 = -1,
		text = "Ice Resistance\n-2% Earth Resistance"
	},
	{
		type2 = "defense",
		bonus1 = 3,
		type1 = "defense",
		bonus2 = -1,
		text = "Ice Resistance\n-2% Fire Resistance"
	},
	{
		type2 = "defense",
		bonus1 = 3,
		type1 = "defense",
		bonus2 = -1,
		text = "Ice Resistance\n-2% Energy Resistance"
	},
	{
		type2 = "defense",
		bonus1 = 3,
		type1 = "defense",
		bonus2 = -1,
		text = "Energy Resistance\n-2% Earth Resistance"
	},
	{
		type2 = "defense",
		bonus1 = 3,
		type1 = "defense",
		bonus2 = -1,
		text = "Energy Resistance\n-2% Ice Resistance"
	},
	{
		type2 = "defense",
		bonus1 = 3,
		type1 = "defense",
		bonus2 = -1,
		text = "Energy Resistance\n-2% Fire Resistance"
	},
	{
		bonus1 = 3,
		type1 = "defense",
		text = "Mana Drain Resistance"
	},
	{
		bonus1 = 3,
		type1 = "defense",
		text = "Life Drain Resistance"
	},
	{
		type2 = "defense",
		bonus1 = 3,
		type1 = "defense",
		bonus2 = 3,
		text = "Mana Drain Resistance\nLife Drain Resistance"
	},
	{
		bonus1 = 5,
		type1 = "mitigation",
		tooltip = "Increases your mitigation multiplicatively.",
		text = "Mitigation Multiplier"
	},
	{
		type1 = "mana",
		step = 100,
		text = "+@ Hit Points"
	},
	{
		type2 = "capacity",
		type1 = "mana",
		step = 50,
		text = "+@ Mana\n+# Capacity"
	},
	{
		type2 = "defense",
		type1 = "mana",
		step = 50,
		text = "+@ Mana\nFire Resistance"
	},
	{
		type2 = "defense",
		type1 = "mana",
		step = 50,
		text = "+@ Mana\nEnergy Resistance"
	},
	{
		type2 = "defense",
		type1 = "mana",
		step = 50,
		text = "+@ Mana\nEarth Resistance"
	},
	{
		type2 = "defense",
		type1 = "mana",
		step = 50,
		text = "+@ Mana\nIce Resistance"
	},
	{
		type1 = "mana",
		step = 100,
		text = "+@ Mana"
	},
	{
		type2 = "defense",
		type1 = "life",
		step = 50,
		text = "+@ Hit Points\nFire Resistance"
	},
	{
		type2 = "defense",
		type1 = "life",
		step = 50,
		text = "+@ Hit Points\nEnergy Resistance"
	},
	{
		type2 = "defense",
		type1 = "life",
		step = 50,
		text = "+@ Hit Points\nEarth Resistance"
	},
	{
		type2 = "defense",
		type1 = "life",
		step = 50,
		text = "+@ Hit Points\nIce Resistance"
	},
	{
		type2 = "mana",
		type1 = "life",
		step = 50,
		text = "+@ Hit Points\n+# Mana"
	},
	{
		type2 = "capacity",
		type1 = "life",
		step = 50,
		text = "+@ Hit Points\n+# Capacity"
	},
	{
		type2 = "defense",
		type1 = "capacity",
		step = 50,
		text = "+@ Capacity\nFire Resistance"
	},
	{
		type2 = "defense",
		type1 = "capacity",
		step = 50,
		text = "+@ Capacity\nEnergy Resistance"
	},
	{
		type2 = "defense",
		type1 = "capacity",
		step = 50,
		text = "+@ Capacity\nEarth Resistance"
	},
	{
		type2 = "defense",
		type1 = "capacity",
		step = 50,
		text = "+@ Capacity\nIce Resistance"
	},
	{
		type1 = "capacity",
		step = 100,
		text = "+@ Capacity"
	}
}
SupremeGemDescription = {
	[0] = {
		text = "+0.28% Dodge"
	},
	{
		text = "+2% Critical Extra Damage"
	},
	{
		text = "+2% Life Leech"
	},
	{
		text = "+0.8% Mana Leech"
	},
	{
		tooltip = "+%s%% Base Healing",
		text = "Aug. Ultimate Healing\n+5% Base Healing"
	},
	{
		tooltip = "The Revelation Mastery bonus counts towards the promotion points\ndistributed in the domain of the corresponding Revelation Perk.",
		extraPoints = 150,
		domain = 1,
		text = "RM Gift of Life"
	},
	{
		tooltip = "-900s Cooldown",
		text = "? Aug. Avatar of Steel\n-900s Cooldown"
	},
	{
		tooltip = "-2s Cooldown",
		text = "? Aug. Executioner's Throw\n-2s Cooldown"
	},
	{
		tooltip = "+%s%% Base Damage",
		text = "? Aug. Executioner's Throw\n+6% Base Damage"
	},
	{
		tooltip = "Adds %s%% critical extra damage for this spell and grant a 10%%\nchance (non-cumulative) for a critical hit.",
		text = "? Aug. Executioner's Throw\n+12% Critical Extra Damage"
	},
	{
		tooltip = "+%s%% Base Damage",
		text = "? Aug. Fierce Berserk\n+5% Base Damage"
	},
	{
		tooltip = "Adds %s%% critical extra damage for this spell and grant a 10%%\nchance (non-cumulative) for a critical hit.",
		text = "? Aug. Fierce Berserk\n+8% Critical Extra Damage"
	},
	{
		tooltip = "+%s%% Base Damage",
		text = "? Aug. Berserk\n+5% Base Damage"
	},
	{
		tooltip = "Adds %s%% critical extra damage for this spell and grant a 10%%\nchance (non-cumulative) for a critical hit.",
		text = "? Aug. Berserk\n+12% Critical Extra Damage"
	},
	{
		tooltip = "+%s%% Base Damage",
		text = "? Aug. Front Sweep\n+8% Base Damage"
	},
	{
		tooltip = "Adds %s%% critical extra damage for this spell and grant a 10%%\nchance (non-cumulative) for a critical hit.",
		text = "? Aug. Front Sweep\n12% Critical Extra Damage"
	},
	{
		tooltip = "+%s%% Base Damage",
		text = "? Aug. Groundshaker\n+6.5% Base Damage"
	},
	{
		tooltip = "Adds %s%% critical extra damage for this spell and grant a 10%%\nchance (non-cumulative) for a critical hit.",
		text = "? Aug. Groundshaker\n12% Critical Extra Damage"
	},
	{
		tooltip = "+%s%% Base Damage",
		text = "? Aug. Annihilation\n+12% Base Damage"
	},
	{
		tooltip = "Adds %s%% critical extra damage for this spell and grant a 10%%\nchance (non-cumulative) for a critical hit.",
		text = "? Aug. Annihilation\n15% Critical Extra Damage"
	},
	{
		tooltip = "+%s%% Base Healing",
		text = "? Aug. Fair Wound Cleasing\n+10% Base Healing"
	},
	{
		tooltip = "The Revelation Mastery bonus counts towards the promotion points\ndistributed in the domain of the corresponding Revelation Perk.",
		extraPoints = 150,
		domain = 4,
		text = "RM Avatar of Steel"
	},
	{
		tooltip = "The Revelation Mastery bonus counts towards the promotion points\ndistributed in the domain of the corresponding Revelation Perk.",
		extraPoints = 150,
		domain = 2,
		text = "RM Executioner's Throw"
	},
	{
		tooltip = "The Revelation Mastery bonus counts towards the promotion points\ndistributed in the domain of the corresponding Revelation Perk.",
		extraPoints = 150,
		domain = 3,
		text = "RM Combat Mastery"
	},
	{
		tooltip = "-900s Cooldown",
		text = "? Aug. Avatar of Light\n-900s Cooldown"
	},
	{
		tooltip = "-4s Cooldown",
		text = "? Aug. Divine Dazzle\n-4s Cooldown"
	},
	{
		tooltip = "+%s%% Base Damage",
		text = "? Aug. Divine Grenade\n+6% Base Damage"
	},
	{
		tooltip = "Adds %s%% critical extra damage for this spell and grant a 10%%\nchance (non-cumulative) for a critical hit.",
		text = "? Aug. Divine Grenade\n12% Critical Extra Damage"
	},
	{
		tooltip = "+%s%% Base Damage",
		text = "? Aug. Divine Caldera\n+5% Base Damage"
	},
	{
		tooltip = "Adds %s%% critical extra damage for this spell and grant a 10%%\nchance (non-cumulative) for a critical hit.",
		text = "? Aug. Divine Caldera\n8% Critical Extra Damage"
	},
	{
		tooltip = "+%s%% Base Damage",
		text = "? Aug. Divine Barrage\n+8% Base Damage"
	},
	{
		tooltip = "Adds %s%% critical extra damage for this spell and grant a 10%%\nchance (non-cumulative) for a critical hit.",
		text = "? Aug. Divine Barrage\n12% Critical Extra Damage"
	},
	{
		tooltip = "+%s%% Base Damage",
		text = "? Aug. Ethereal Barrage\n+10% Base Damage"
	},
	{
		tooltip = "Adds %s%% critical extra damage for this spell and grant a 10%%\nchance (non-cumulative) for a critical hit.",
		text = "? Aug. Ethereal Barrage\n15% Critical Extra Damage"
	},
	{
		tooltip = "+%s%% Base Damage",
		text = "? Aug. Strong Ethereal Spear\n+8% Base Damage"
	},
	{
		tooltip = "Adds %s%% critical extra damage for this spell and grant a 10%%\nchance (non-cumulative) for a critical hit.",
		text = "? Aug. Strong Ethereal Spear\n12% Critical Extra Damage"
	},
	{
		tooltip = "-6s Cooldown",
		text = "? Aug. Divine Empowerment\n-3s Cooldown"
	},
	{
		tooltip = "-2s Cooldown",
		text = "? Aug. Divine Grenade\n-1s Cooldown"
	},
	{
		tooltip = "+6 Base Healing",
		text = "? Aug. Salvation\n+6 Base Healing"
	},
	{
		tooltip = "The Revelation Mastery bonus counts towards the promotion points\ndistributed in the domain of the corresponding Revelation Perk.",
		extraPoints = 150,
		domain = 4,
		text = "RM Avatar of Light"
	},
	{
		tooltip = "The Revelation Mastery bonus counts towards the promotion points\ndistributed in the domain of the corresponding Revelation Perk.",
		extraPoints = 150,
		domain = 2,
		text = "RM Divine Grenade"
	},
	{
		tooltip = "The Revelation Mastery bonus counts towards the promotion points\ndistributed in the domain of the corresponding Revelation Perk.",
		extraPoints = 150,
		domain = 3,
		text = "RM Divine Empowerment"
	},
	{
		tooltip = "-900s Cooldown",
		text = "? Aug. Avatar of Storm\n-300s Cooldown"
	},
	{
		tooltip = "-1s Cooldown",
		text = "? Aug. Energy Wave\n-1s Cooldown"
	},
	{
		tooltip = "+%s%% Base Damage",
		text = "? Aug. Great Death Beam\n+10% Base Damage"
	},
	{
		tooltip = "Adds %s%% critical extra damage for this spell and grant a 10%%\nchance (non-cumulative) for a critical hit.",
		text = "? Aug. Great Death Beam\n+15% Critical Extra Damage"
	},
	{
		tooltip = "+%s%% Base Damage",
		text = "? Aug. Hell's Core\n+8% Base Damage"
	},
	{
		tooltip = "Adds %s%% critical extra damage for this spell and grant a 10%%\nchance (non-cumulative) for a critical hit.",
		text = "? Aug. Hell's Core\n+12% Critical Extra Damage"
	},
	{
		tooltip = "+%s%% Base Damage",
		text = "? Aug. Energy Wave\n5% Base Damage"
	},
	{
		tooltip = "Adds %s%% critical extra damage for this spell and grant a 10%%nchance (non-cumulative) for a critical hit.",
		text = "? Aug. Energy Wave\n+12% Critical Extra Damage"
	},
	{
		tooltip = "+%s%% Base Damage",
		text = "? Aug. Great Fire Wave\n5% Base Damage"
	},
	{
		tooltip = "Adds %s%% critical extra damage for this spell and grant a 10%%\nchance (non-cumulative) for a critical hit.",
		text = "? Aug. Great Fire Wave\n+8% Critical Extra Damage"
	},
	{
		tooltip = "+%s%% Base Damage",
		text = "? Aug. Rage of the Skies\n+8% Base Damage"
	},
	{
		tooltip = "Adds %s%% critical extra damage for this spell and grant a 10%%\nchance (non-cumulative) for a critical hit.",
		text = "? Aug. Rage of the Skies\n+12% Critical Extra Damage"
	},
	{
		tooltip = "+%s%% Base Damage",
		text = "? Aug. Great Energy Beam\n+10% Base Damage"
	},
	{
		tooltip = "Adds %s%% critical extra damage for this spell and grant a 10%%\nchance (non-cumulative) for a critical hit.",
		text = "? Aug. Great Energy Beam\n+15% Critical Extra Damage"
	},
	{
		tooltip = "The Revelation Mastery bonus counts towards the promotion points\ndistributed in the domain of the corresponding Revelation Perk.",
		extraPoints = 150,
		domain = 4,
		text = "RM Avatar of Storm"
	},
	{
		tooltip = "The Revelation Mastery bonus counts towards the promotion points\ndistributed in the domain of the corresponding Revelation Perk.",
		extraPoints = 150,
		domain = 2,
		text = "RM Beaam Mastery"
	},
	{
		tooltip = "The Revelation Mastery bonus counts towards the promotion points\ndistributed in the domain of the corresponding Revelation Perk.",
		extraPoints = 150,
		domain = 3,
		text = "RM Drain Body"
	},
	{
		tooltip = "-900s Cooldown",
		text = "? Aug. Avatar of Nature\n-900s Cooldown"
	},
	{
		tooltip = "-10s Cooldown",
		text = "? Aug. Nature's Embrace\n-10s Cooldown"
	},
	{
		tooltip = "+%s%% Base Damage",
		text = "? Aug. Terra Burst\n+7% Base Damage"
	},
	{
		tooltip = "Adds %s%% critical extra damage for this spell and grant a 10%%\nchance (non-cumulative) for a critical hit.",
		text = "? Aug. Terra Burst\n+12% Critical Extra Damage"
	},
	{
		tooltip = "+%s%% Base Damage",
		text = "? Aug. Ice Burst\n+7% Base Damage"
	},
	{
		tooltip = "Adds %s%% critical extra damage for this spell and grant a 10%%\nchance (non-cumulative) for a critical hit.",
		text = "? Aug. Ice Burst\n+12% Critical Extra Damage"
	},
	{
		tooltip = "+%s%% Base Damage",
		text = "? Aug. Eternal Winter\n+8% Base Damage"
	},
	{
		tooltip = "Adds %s%% critical extra damage for this spell and grant a 10%%\nchance (non-cumulative) for a critical hit.",
		text = "? Aug. Eternal Winter\n+12% Critical Extra Damage"
	},
	{
		tooltip = "+%s%% Base Damage",
		text = "? Aug. Terra Wave\n+5% Base Damage"
	},
	{
		tooltip = "Adds %s%% critical extra damage for this spell and grant a 10%%\nchance (non-cumulative) for a critical hit.",
		text = "? Aug. Terra Wave\n+12% Critical Extra Damage"
	},
	{
		tooltip = "+%s%% Base Damage",
		text = "? Aug. Strong Ice Wave\n+8% Base Damage"
	},
	{
		tooltip = "Adds %s%% critical extra damage for this spell and grant a 10%%\nchance (non-cumulative) for a critical hit.",
		text = "? Aug. Strong Ice Wave\n+15% Critical Extra Damage"
	},
	{
		tooltip = "+%s%% Base Healing",
		text = "? Aug. Heal Friend\n+5% Base Healing"
	},
	{
		tooltip = "+%s%% Base Healing",
		text = "? Aug. Mass Healing\n+5% Base Healing"
	},
	{
		tooltip = "The Revelation Mastery bonus counts towards the promotion points\ndistributed in the domain of the corresponding Revelation Perk.",
		extraPoints = 150,
		domain = 4,
		text = "RM Avatar of Nature"
	},
	{
		tooltip = "The Revelation Mastery bonus counts towards the promotion points\ndistributed in the domain of the corresponding Revelation Perk.",
		extraPoints = 150,
		domain = 2,
		text = "RM Blessing of the Groove"
	},
	{
		tooltip = "The Revelation Mastery bonus counts towards the promotion points\ndistributed in the domain of the corresponding Revelation Perk.",
		extraPoints = 150,
		domain = 3,
		text = "RM Twin Burst"
	},
	{
		tooltip = "-900s Cooldown",
		text = "? Aug. Avatar of Balance\n-900s Cooldown"
	},
	{
		tooltip = "+%s%% Base Healing",
		text = "? Aug. Spirit Mend\n+9% Base Healing"
	},
	{
		tooltip = "+%s%% Base Damage",
		text = "? Aug. Spiritual Outburst\n+5% Base Damage"
	},
	{
		tooltip = "Adds %s%% critical extra damage for this spell and grant a 10%%\nchance (non-cumulative) for a critical hit.",
		text = "? Aug. Spiritual Outburst\n+8% Critical Extra Damage"
	},
	{
		tooltip = "+%s%% Base Damage",
		text = "? Aug. Forceful Uppercut\n+10% Base Damage"
	},
	{
		tooltip = "Adds %s%% critical extra damage for this spell and grant a 10%%\nchance (non-cumulative) for a critical hit.",
		text = "? Aug. Forceful Uppercut\n+8% Critical Extra Damage"
	},
	{
		tooltip = "+%s%% Base Damage",
		text = "? Aug. Flurry of Blows\n+6.5% Base Damage"
	},
	{
		tooltip = "Adds %s%% critical extra damage for this spell and grant a 10%%\nchance (non-cumulative) for a critical hit.",
		text = "? Aug. Flurry of Blows\n+8% Critical Extra Damage"
	},
	{
		tooltip = "+%s%% Base Damage",
		text = "? Aug. Greater Flurry of Blows\n+5% Base Damage"
	},
	{
		tooltip = "Adds %s%% critical extra damage for this spell and grant a 10%%\nchance (non-cumulative) for a critical hit.",
		text = "? Aug. Greater Flurry of Blows\n+8% Critical Extra Damage"
	},
	{
		tooltip = "+%s%% Base Damage",
		text = "? Aug. Sweeping Takedown\n+5% Base Damage"
	},
	{
		tooltip = "Adds %s%% critical extra damage for this spell and grant a 10%%\nchance (non-cumulative) for a critical hit.",
		text = "? Aug. Sweeping Takedown\n+8% Critical Extra Damage"
	},
	{
		tooltip = "-150s Cooldown",
		text = "? Aug. Focus Serenity\n-150s Cooldown"
	},
	{
		tooltip = "-30s Cooldown",
		text = "? Aug. Focus Harmony\n-30s Cooldown"
	},
	{
		tooltip = "+%s%% Base Healing",
		text = "? Aug. Mass Spirit Mend\n+5% Base Healing"
	},
	{
		tooltip = "The Revelation Mastery bonus counts towards the promotion points\ndistributed in the domain of the corresponding Revelation Perk.",
		extraPoints = 150,
		domain = 4,
		text = "RM Avatar of Balance"
	},
	{
		tooltip = "The Revelation Mastery bonus counts towards the promotion points\ndistributed in the domain of the corresponding Revelation Perk.",
		extraPoints = 150,
		domain = 2,
		text = "RM Spiritual Outburst"
	},
	{
		tooltip = "The Revelation Mastery bonus counts towards the promotion points\ndistributed in the domain of the corresponding Revelation Perk.",
		extraPoints = 150,
		domain = 3,
		text = "RM Ascetic"
	}
}
lesserResources = {
	[0] = {
		fragment = 5,
		price = 2000000
	},
	{
		fragment = 15,
		price = 5000000
	},
	{
		fragment = 30,
		price = 30000000
	}
}
greaterResources = {
	[0] = {
		fragment = 5,
		price = 5000000
	},
	{
		fragment = 15,
		price = 12500000
	},
	{
		fragment = 30,
		price = 75000000
	}
}
bonusStep = {
	[KNIGHT] = {
		capacity = 5,
		life = 3,
		mana = 1
	},
	[PALADIN] = {
		capacity = 4,
		life = 2,
		mana = 3
	},
	[SORCERER] = {
		capacity = 2,
		life = 1,
		mana = 6
	},
	[DRUID] = {
		capacity = 2,
		life = 1,
		mana = 6
	},
	[MONK] = {
		capacity = 4,
		life = 2,
		mana = 2
	}
}
FlatSupremeMods = {
	[0] = {
		baseI = 0.28,
		tooltip = "+%s%% Dodge",
		desc = "Dodge"
	},
	{
		baseI = 2,
		tooltip = "+%s%% Critical Extra Damage",
		desc = "Critical Extra Damage"
	},
	{
		baseI = 2,
		tooltip = "+%s%% Life Leech",
		desc = "Life Leech"
	},
	{
		baseI = 0.8,
		tooltip = "+%s%% Mana Leech",
		desc = "Mana Leech"
	},
	{
		desc = "Aug. Ultimate Healing",
		baseI = 5,
		tooltip = "+%s%% Base Healing",
		showDesc = true
	},
	{
		desc = "Revelation Mastery",
		domain = 0,
		tooltip = "+%s Gift of Life",
		baseI = 150,
		showDesc = true
	}
}
BasicMods = {
	[0] = {
		tooltip = "+%s%% Physical Resistance",
		baseI = 1
	},
	{
		tooltip = "+%s%% Holy Resistance",
		baseI = 1
	},
	{
		tooltip = "+%s%% Death Resistance",
		baseI = 1
	},
	{
		tooltip = "+%s%% Fire Resistance",
		baseI = 2
	},
	{
		tooltip = "+%s%% Earth Resistance",
		baseI = 2
	},
	{
		tooltip = "+%s%% Ice Resistance",
		baseI = 2
	},
	{
		tooltip = "+%s%% Energy Resistance",
		baseI = 2
	},
	{
		tooltip = "+%s%% Holy Resistance\n-1%% Death Resistance",
		baseI = 1.5
	},
	{
		tooltip = "+%s%% Death Resistance\n-1%% Holy Resistance",
		baseI = 1.5
	},
	{
		baseII = 1,
		baseI = 1,
		tooltip = "+%s%% Fire Resistance\n+%s%% Earth Resistance"
	},
	{
		baseII = 1,
		baseI = 1,
		tooltip = "+%s%% Fire Resistance\n+%s%% Ice Resistance"
	},
	{
		baseII = 1,
		baseI = 1,
		tooltip = "+%s%% Fire Resistance\n+%s%% Energy Resistance"
	},
	{
		baseII = 1,
		baseI = 1,
		tooltip = "+%s%% Earth Resistance\n+%s%% Ice Resistance"
	},
	{
		baseII = 1,
		baseI = 1,
		tooltip = "+%s%% Earth Resistance\n+%s%% Energy Resistance"
	},
	{
		baseII = 1,
		baseI = 1,
		tooltip = "+%s%% Ice Resistance\n+%s%% Energy Resistance"
	},
	{
		baseII = -2,
		baseI = 3,
		tooltip = "+%s%% Fire Resistance\n-2%% Earth Resistance"
	},
	{
		baseII = -2,
		baseI = 3,
		tooltip = "+%s%% Fire Resistance\n-2%% Ice Resistance"
	},
	{
		baseII = -2,
		baseI = 3,
		tooltip = "+%s%% Fire Resistance\n-2%% Energy Resistance"
	},
	{
		baseII = -2,
		baseI = 3,
		tooltip = "+%s%% Earth Resistance\n-2%% Fire Resistance"
	},
	{
		baseII = -2,
		baseI = 3,
		tooltip = "+%s%% Earth Resistance\n-2%% Ice Resistance"
	},
	{
		baseII = -2,
		baseI = 3,
		tooltip = "+%s%% Earth Resistance\n-2%% Energy Resistance"
	},
	{
		baseII = -2,
		baseI = 3,
		tooltip = "+%s%% Ice Resistance\n-2%% Earth Resistance"
	},
	{
		baseII = -2,
		baseI = 3,
		tooltip = "+%s%% Ice Resistance\n-2%% Fire Resistance"
	},
	{
		baseII = -2,
		baseI = 3,
		tooltip = "+%s%% Ice Resistance\n-2%% Energy Resistance"
	},
	{
		baseII = -2,
		baseI = 3,
		tooltip = "+%s%% Energy Resistance\n-2%% Earth Resistance"
	},
	{
		baseII = -2,
		baseI = 3,
		tooltip = "+%s%% Energy Resistance\n-2%% Ice Resistance"
	},
	{
		baseII = -2,
		baseI = 3,
		tooltip = "+%s%% Energy Resistance\n-2%% Fire Resistance"
	},
	{
		tooltip = "+%s%% Mana Drain Resistance",
		baseI = 3
	},
	{
		tooltip = "+%s%% Life Drain Resistance",
		baseI = 3
	},
	{
		baseII = 1.5,
		baseI = 1.5,
		tooltip = "+%s%% Mana Drain Resistance\n+%s%% Life Drain Resistance"
	},
	{
		tooltip = "+%s%% Mitigation Multiplier",
		baseI = 5
	},
	{
		tooltip = "+%s Hit Points",
		stepTypeI = "health",
		baseStepI = 100
	},
	[33] = {
		baseII = 1,
		stepTypeI = "mana",
		baseStepI = 50,
		tooltip = "+%s Mana\n+%s%% Fire Resistance"
	},
	[34] = {
		baseII = 1,
		stepTypeI = "mana",
		baseStepI = 50,
		tooltip = "+%s Mana\n+%s%% Energy Resistance"
	},
	[35] = {
		baseII = 1,
		stepTypeI = "mana",
		baseStepI = 50,
		tooltip = "+%s Mana\n+%s%% Earth Resistance"
	},
	[36] = {
		baseII = 1,
		stepTypeI = "mana",
		baseStepI = 50,
		tooltip = "+%s Mana\n+%s%% Ice Resistance"
	},
	[37] = {
		tooltip = "+%s Mana",
		stepTypeI = "mana",
		baseStepI = 100
	},
	[38] = {
		baseII = 1,
		stepTypeI = "health",
		baseStepI = 50,
		tooltip = "+%s Health\n+%s%% Fire Resistance"
	},
	[39] = {
		baseII = 1,
		stepTypeI = "health",
		baseStepI = 50,
		tooltip = "+%s Health\n+%s%% Energy Resistance"
	},
	[40] = {
		baseII = 1,
		stepTypeI = "health",
		baseStepI = 50,
		tooltip = "+%s Health\n+%s%% Earth Resistance"
	},
	[41] = {
		baseII = 1,
		stepTypeI = "health",
		baseStepI = 50,
		tooltip = "+%s Health\n+%s%% Ice Resistance"
	},
	[44] = {
		baseII = 1,
		stepTypeI = "capacity",
		baseStepI = 50,
		tooltip = "+%s Capacity\n+%s%% Fire Resistance"
	},
	[45] = {
		baseII = 1,
		stepTypeI = "capacity",
		baseStepI = 50,
		tooltip = "+%s Capacity\n+%s%% Energy Resistance"
	},
	[46] = {
		baseII = 1,
		stepTypeI = "capacity",
		baseStepI = 50,
		tooltip = "+%s Capacity\n+%s%% Earth Resistance"
	},
	[47] = {
		baseII = 1,
		stepTypeI = "capacity",
		baseStepI = 50,
		tooltip = "+%s Capacity\n+%s%% Ice Resistance"
	},
	[48] = {
		tooltip = "+%s Capacity",
		stepTypeI = "capacity",
		baseStepI = 100
	}
}
VocationSupremeMods = {
	[8] = {
		[6] = {
			desc = "Aug. Avatar of Steel",
			baseII = 0.33,
			type = "cooldown",
			tooltip = "-900s Cooldown\n+%s%% Momentum",
			showDesc = true
		},
		[7] = {
			desc = "Aug. Executioner's Throw",
			baseII = 0.33,
			type = "cooldown",
			tooltip = "-2s Cooldown\n+%s%% Momentum",
			showDesc = true
		},
		[8] = {
			desc = "Aug. Executioner's Throw",
			baseI = 6,
			tooltip = "+%s%% Base Damage",
			showDesc = true
		},
		[9] = {
			desc = "Aug. Executioner's Throw",
			baseI = 12,
			tooltip = "+%s%% Critical Extra Damage",
			showDesc = true
		},
		[10] = {
			desc = "Aug. Fierce Berserk",
			baseI = 5,
			tooltip = "+%s%% Base Damage",
			showDesc = true
		},
		[11] = {
			desc = "Aug. Fierce Berserk",
			baseI = 8,
			tooltip = "+%s%% Critical Extra Damage",
			showDesc = true
		},
		[12] = {
			desc = "Aug. Berserk",
			baseI = 5,
			tooltip = "+%s%% Base Damage",
			showDesc = true
		},
		[13] = {
			desc = "Aug. Berserk",
			baseI = 12,
			tooltip = "+%s%% Critical Extra Damage",
			showDesc = true
		},
		[14] = {
			desc = "Aug. Front Sweep",
			baseI = 8,
			tooltip = "+%s%% Base Damage",
			showDesc = true
		},
		[15] = {
			desc = "Aug. Front Sweep",
			baseI = 12,
			tooltip = "+%s%% Critical Extra Damage",
			showDesc = true
		},
		[16] = {
			desc = "Aug. Groundshaker",
			baseI = 6.5,
			tooltip = "+%s%% Base Damage",
			showDesc = true
		},
		[17] = {
			desc = "Aug. Groundshaker",
			baseI = 12,
			tooltip = "+%s%% Critical Extra Damage",
			showDesc = true
		},
		[18] = {
			desc = "Aug. Annihilation",
			baseI = 12,
			tooltip = "+%s%% Base Damage",
			showDesc = true
		},
		[19] = {
			desc = "Aug. Annihilation",
			baseI = 15,
			tooltip = "+%s%% Critical Extra Damage",
			showDesc = true
		},
		[20] = {
			desc = "Aug. Fair Wound Cleansing",
			baseI = 10,
			tooltip = "+%s%% Base Healing",
			showDesc = true
		},
		[21] = {
			desc = "Revelation Mastery",
			domain = 3,
			tooltip = "+%s Avatar of Steel",
			baseI = 150,
			showDesc = true
		},
		[22] = {
			desc = "Revelation Mastery",
			domain = 1,
			tooltip = "+%s Executioner's Throw",
			baseI = 150,
			showDesc = true
		},
		[23] = {
			desc = "Revelation Mastery",
			domain = 2,
			tooltip = "+%s Combat Mastery",
			baseI = 150,
			showDesc = true
		}
	},
	[7] = {
		[24] = {
			desc = "Aug. Avatar of Light",
			baseII = 0.33,
			type = "cooldown",
			tooltip = "-900s Cooldown\n+%s%% Momentum",
			showDesc = true
		},
		[25] = {
			desc = "Aug. Divine Dazzle",
			baseII = 0.33,
			type = "cooldown",
			tooltip = "-4s Cooldown\n+%s%% Momentum",
			showDesc = true
		},
		[26] = {
			desc = "Aug. Divine Grenade",
			baseI = 6,
			tooltip = "+%s%% Base Damage",
			showDesc = true
		},
		[27] = {
			desc = "Aug. Divine Grenade",
			baseI = 12,
			tooltip = "+%s%% Critical Extra Damage",
			showDesc = true
		},
		[28] = {
			desc = "Aug. Divine Caldera",
			baseI = 5,
			tooltip = "+%s%% Base Damage",
			showDesc = true
		},
		[29] = {
			desc = "Aug. Divine Caldera",
			baseI = 8,
			tooltip = "+%s%% Critical Extra Damage",
			showDesc = true
		},
		[30] = {
			desc = "Aug. Divine Barrage",
			baseI = 8,
			tooltip = "+%s%% Base Damage",
			showDesc = true
		},
		[31] = {
			desc = "Aug. Divine Barrage",
			baseI = 12,
			tooltip = "+%s%% Critical Extra Damage",
			showDesc = true
		},
		[32] = {
			desc = "Aug. Ethereal Barrage",
			baseI = 10,
			tooltip = "+%s%% Base Damage",
			showDesc = true
		},
		[33] = {
			desc = "Aug. Ethereal Barrage",
			baseI = 15,
			tooltip = "+%s%% Critical Extra Damage",
			showDesc = true
		},
		[34] = {
			desc = "Aug. Strong Ethereal Spear",
			baseI = 8,
			tooltip = "+%s%% Base Damage",
			showDesc = true
		},
		[35] = {
			desc = "Aug. Strong Ethereal Spear",
			baseI = 12,
			tooltip = "+%s%% Critical Extra Damage",
			showDesc = true
		},
		[36] = {
			desc = "Aug. Divine Empowerment",
			baseII = 0.33,
			type = "cooldown",
			tooltip = "-6s Cooldown\n+%s%% Momentum",
			showDesc = true
		},
		[37] = {
			desc = "Aug. Divine Grenade",
			baseII = 0.33,
			type = "cooldown",
			tooltip = "-2s Cooldown\n+%s%% Momentum",
			showDesc = true
		},
		[38] = {
			desc = "Aug. Salvation",
			baseI = 6,
			tooltip = "+%s%% Base Healing",
			showDesc = true
		},
		[39] = {
			desc = "Revelation Mastery",
			domain = 3,
			tooltip = "+%s Avatar of Light",
			baseI = 150,
			showDesc = true
		},
		[40] = {
			desc = "Revelation Mastery",
			domain = 1,
			tooltip = "+%s Divine Grenade",
			baseI = 150,
			showDesc = true
		},
		[41] = {
			desc = "Revelation Mastery",
			domain = 2,
			tooltip = "+%s Divine Empowerment",
			baseI = 150,
			showDesc = true
		}
	},
	[5] = {
		[42] = {
			desc = "Aug. Avatar of Storm",
			baseII = 0.33,
			type = "cooldown",
			tooltip = "-900s Cooldown\n+%s%% Momentum",
			showDesc = true
		},
		[43] = {
			desc = "Aug. Energy Wave",
			baseII = 0.33,
			type = "cooldown",
			tooltip = "-1s Cooldown\n+%s%% Momentum",
			showDesc = true
		},
		[44] = {
			desc = "Aug. Great Death Beam",
			baseI = 10,
			tooltip = "+%s%% Base Damage",
			showDesc = true
		},
		[45] = {
			desc = "Aug. Great Death Beam",
			baseI = 15,
			tooltip = "+%s%% Critical Extra Damage",
			showDesc = true
		},
		[46] = {
			desc = "Aug. Hell's Core",
			baseI = 8,
			tooltip = "+%s%% Base Damage",
			showDesc = true
		},
		[47] = {
			desc = "Aug. Hell's Core",
			baseI = 12,
			tooltip = "+%s%% Critical Extra Damage",
			showDesc = true
		},
		[48] = {
			desc = "Aug. Energy Wave",
			baseI = 5,
			tooltip = "+%s%% Base Damage",
			showDesc = true
		},
		[49] = {
			desc = "Aug. Energy Wave",
			baseI = 12,
			tooltip = "+%s%% Critical Extra Damage",
			showDesc = true
		},
		[50] = {
			desc = "Aug. Great Fire Wave",
			baseI = 5,
			tooltip = "+%s%% Base Damage",
			showDesc = true
		},
		[51] = {
			desc = "Aug. Great Fire Wave",
			baseI = 8,
			tooltip = "+%s%% Critical Extra Damage",
			showDesc = true
		},
		[52] = {
			desc = "Aug. Rage of the Skies",
			baseI = 8,
			tooltip = "+%s%% Base Damage",
			showDesc = true
		},
		[53] = {
			desc = "Aug. Rage of the Skies",
			baseI = 12,
			tooltip = "+%s%% Critical Extra Damage",
			showDesc = true
		},
		[54] = {
			desc = "Aug. Great Energy Beam",
			baseI = 10,
			tooltip = "+%s%% Base Damage",
			showDesc = true
		},
		[55] = {
			desc = "Aug. Great Energy Beam",
			baseI = 15,
			tooltip = "+%s%% Critical Extra Damage",
			showDesc = true
		},
		[56] = {
			desc = "Revelation Mastery",
			domain = 3,
			tooltip = "+%s Avatar of Storm",
			baseI = 150,
			showDesc = true
		},
		[57] = {
			desc = "Revelation Mastery",
			domain = 1,
			tooltip = "+%s Beam Mastery",
			baseI = 150,
			showDesc = true
		},
		[58] = {
			desc = "Revelation Mastery",
			domain = 2,
			tooltip = "+%s Drain Body",
			baseI = 150,
			showDesc = true
		}
	},
	[6] = {
		[59] = {
			desc = "Aug. Avatar of Nature",
			baseII = 0.33,
			type = "cooldown",
			tooltip = "-900s Cooldown\n+%s%% Momentum",
			showDesc = true
		},
		[60] = {
			desc = "Aug. Nature's Embrace",
			baseII = 0.33,
			type = "cooldown",
			tooltip = "-10s Cooldown\n+%s%% Momentum",
			showDesc = true
		},
		[61] = {
			desc = "Aug. Terra Burst",
			baseI = 7,
			tooltip = "+%s%% Base Damage",
			showDesc = true
		},
		[62] = {
			desc = "Aug. Terra Burst",
			baseI = 12,
			tooltip = "+%s%% Critical Extra Damage",
			showDesc = true
		},
		[63] = {
			desc = "Aug. Ice Burst",
			baseI = 7,
			tooltip = "+%s%% Base Damage",
			showDesc = true
		},
		[64] = {
			desc = "Aug. Ice Burst",
			baseI = 12,
			tooltip = "+%s%% Critical Extra Damage",
			showDesc = true
		},
		[65] = {
			desc = "Aug. Eternal Winter",
			baseI = 8,
			tooltip = "+%s%% Base Damage",
			showDesc = true
		},
		[66] = {
			desc = "Aug. Eternal Winter",
			baseI = 12,
			tooltip = "+%s%% Critical Extra Damage",
			showDesc = true
		},
		[67] = {
			desc = "Aug. Terra Wave",
			baseI = 5,
			tooltip = "+%s%% Base Damage",
			showDesc = true
		},
		[68] = {
			desc = "Aug. Terra Wave",
			baseI = 12,
			tooltip = "+%s%% Critical Extra Damage",
			showDesc = true
		},
		[69] = {
			desc = "Aug. Strong Ice Wave",
			baseI = 8,
			tooltip = "+%s%% Base Damage",
			showDesc = true
		},
		[70] = {
			desc = "Aug. Strong Ice Wave",
			baseI = 15,
			tooltip = "+%s%% Critical Extra Damage",
			showDesc = true
		},
		[71] = {
			desc = "Aug. Heal Friend",
			baseI = 5,
			tooltip = "+%s%% Base Healing",
			showDesc = true
		},
		[72] = {
			desc = "Aug. Mass Healing",
			baseI = 5,
			tooltip = "+%s%% Base Healing",
			showDesc = true
		},
		[73] = {
			desc = "Revelation Mastery",
			domain = 3,
			tooltip = "+%s Avatar of Nature",
			baseI = 150,
			showDesc = true
		},
		[74] = {
			desc = "Revelation Mastery",
			domain = 1,
			tooltip = "+%s Blessing of the Grove",
			baseI = 150,
			showDesc = true
		},
		[75] = {
			desc = "Revelation Mastery",
			domain = 2,
			tooltip = "+%s Twin Bursts",
			baseI = 150,
			showDesc = true
		}
	},
	[9] = {
		[76] = {
			desc = "Aug. Avatar of Balance",
			baseII = 0.33,
			type = "cooldown",
			tooltip = "-900s Cooldown\n+%s%% Momentum",
			showDesc = true
		},
		[77] = {
			desc = "Aug. Spirit Mend",
			baseI = 6,
			tooltip = "+%s%% Base Healing",
			showDesc = true
		},
		[78] = {
			desc = "Aug. Spiritual Outburst",
			baseI = 5,
			tooltip = "+%s%% Base Damage",
			showDesc = true
		},
		[79] = {
			desc = "Aug. Spiritual Outburst",
			baseI = 8,
			tooltip = "+%s%% Critical Extra Damage",
			showDesc = true
		},
		[80] = {
			desc = "Aug. Forceful Uppercut",
			baseI = 10,
			tooltip = "+%s%% Base Damage",
			showDesc = true
		},
		[81] = {
			desc = "Aug. Forceful Uppercut",
			baseI = 8,
			tooltip = "+%s%% Critical Extra Damage",
			showDesc = true
		},
		[82] = {
			desc = "Aug. Flurry of Blows",
			baseI = 6.5,
			tooltip = "+%s%% Base Damage",
			showDesc = true
		},
		[83] = {
			desc = "Aug. Flurry of Blows",
			baseI = 8,
			tooltip = "+%s%% Critical Extra Damage",
			showDesc = true
		},
		[84] = {
			desc = "Aug. Greater Flurry of Blows",
			baseI = 5,
			tooltip = "+%s%% Base Damage",
			showDesc = true
		},
		[85] = {
			desc = "Aug. Greater Flurry of Blows",
			baseI = 8,
			tooltip = "+%s%% Critical Extra Damage",
			showDesc = true
		},
		[86] = {
			desc = "Aug. Sweeping Takedown",
			baseI = 5,
			tooltip = "+%s%% Base Damage",
			showDesc = true
		},
		[87] = {
			desc = "Aug. Sweeping Takedown",
			baseI = 8,
			tooltip = "+%s%% Critical Extra Damage",
			showDesc = true
		},
		[88] = {
			desc = "Aug. Focus Serenity",
			baseII = 0.33,
			type = "cooldown",
			tooltip = "-150s Cooldown\n+%s%% Momentum",
			showDesc = true
		},
		[89] = {
			desc = "Aug. Focus Harmony",
			baseII = 0.33,
			type = "cooldown",
			tooltip = "-30s Cooldown\n+%s%% Momentum",
			showDesc = true
		},
		[90] = {
			desc = "Aug. Mass Spirit Mend",
			baseI = 5,
			tooltip = "+%s%% Base Healing",
			showDesc = true
		},
		[91] = {
			desc = "Revelation Mastery",
			domain = 3,
			tooltip = "+%s Avatar of Balance",
			baseI = 150,
			showDesc = true
		},
		[92] = {
			desc = "Revelation Mastery",
			domain = 1,
			tooltip = "+%s Spiritual Outburst",
			baseI = 150,
			showDesc = true
		},
		[93] = {
			desc = "Revelation Mastery",
			domain = 2,
			tooltip = "+%s Ascetic",
			baseI = 150,
			showDesc = true
		}
	}
}
GemStaticTooltips = {
	[0] = "You need at least %s gold to reveal gems of this quality.",
	"You have no unrevealed gems of this quality.",
	"You have no unrevealed gems of this quality.\nYou must be inside a temple to reveal gems.",
	"You can carry a maximum of 225 revealed gems. Destroy some to reveal more."
}
GemRevealPrice = {
	[GemEnums.LESSER] = 125000,
	[GemEnums.GUARDIAN] = 1000000,
	[GemEnums.GREATER] = 6000000
}
GemSwitchPrice = {
	[GemEnums.LESSER] = 125000,
	[GemEnums.GUARDIAN] = 250000,
	[GemEnums.GREATER] = 500000
}
VesselIndex = {
	[GemDomains.GREEN] = {
		2,
		6,
		14
	},
	[GemDomains.RED] = {
		4,
		9,
		17
	},
	[GemDomains.ACQUA] = {
		18,
		26,
		31
	},
	[GemDomains.PURPLE] = {
		21,
		29,
		33
	}
}
WheelIcons = {
	[KNIGHT] = {
		{
			miniIconRect = "32 0 16 16",
			iconRect = "240 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "150 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "1110 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "210 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "1140 0 30 30"
		},
		{
			miniIconRect = "32 0 16 16",
			iconRect = "360 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "1110 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "420 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "180 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "1140 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "390 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "150 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "330 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "210 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "1110 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "300 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "180 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "1140 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "1170 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "150 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "360 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "1200 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "210 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "420 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "180 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "390 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "1170 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "150 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "330 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "1200 0 30 30"
		},
		{
			miniIconRect = "32 0 16 16",
			iconRect = "300 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "1170 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "210 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "1200 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "180 0 30 30"
		},
		{
			miniIconRect = "32 0 16 16",
			iconRect = "270 0 30 30"
		}
	},
	[PALADIN] = {
		{
			miniIconRect = "32 0 16 16",
			iconRect = "510 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "150 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "1110 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "450 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "1140 0 30 30"
		},
		{
			miniIconRect = "32 0 16 16",
			iconRect = "660 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "1110 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "630 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "180 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "1140 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "600 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "150 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "570 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "450 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "1110 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "540 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "180 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "1140 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "1170 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "150 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "660 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "1200 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "450 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "630 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "180 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "600 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "1170 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "150 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "570 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "1200 0 30 30"
		},
		{
			miniIconRect = "32 0 16 16",
			iconRect = "540 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "1170 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "450 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "1200 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "180 0 30 30"
		},
		{
			miniIconRect = "32 0 16 16",
			iconRect = "480 0 30 30"
		}
	},
	[SORCERER] = {
		{
			miniIconRect = "32 0 16 16",
			iconRect = "1050 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "150 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "1110 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "1020 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "1140 0 30 30"
		},
		{
			miniIconRect = "32 0 16 16",
			iconRect = "810 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "1110 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "780 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "180 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "1140 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "1080 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "150 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "750 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "1020 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "1110 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "720 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "180 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "1140 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "1170 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "150 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "810 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "1200 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "1020 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "780 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "180 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "1080 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "1170 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "150 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "750 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "1200 0 30 30"
		},
		{
			miniIconRect = "32 0 16 16",
			iconRect = "720 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "1170 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "1020 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "1200 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "180 0 30 30"
		},
		{
			miniIconRect = "32 0 16 16",
			iconRect = "690 0 30 30"
		}
	},
	[DRUID] = {
		{
			miniIconRect = "32 0 16 16",
			iconRect = "840 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "150 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "1110 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "1020 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "1140 0 30 30"
		},
		{
			miniIconRect = "32 0 16 16",
			iconRect = "870 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "1110 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "960 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "180 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "1140 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "990 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "150 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "900 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "1020 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "1110 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "930 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "180 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "1140 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "1170 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "150 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "870 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "1200 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "1020 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "960 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "180 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "990 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "1170 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "150 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "900 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "1200 0 30 30"
		},
		{
			miniIconRect = "32 0 16 16",
			iconRect = "930 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "1170 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "1020 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "1200 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "180 0 30 30"
		},
		{
			miniIconRect = "32 0 16 16",
			iconRect = "1050 0 30 30"
		}
	},
	[MONK] = {
		{
			miniIconRect = "32 0 16 16",
			iconRect = "1260 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "150 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "1110 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "1290 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "1140 0 30 30"
		},
		{
			miniIconRect = "32 0 16 16",
			iconRect = "1410 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "1110 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "1350 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "180 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "1140 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "1380 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "150 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "1440 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "1290 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "1110 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "1320 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "180 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "1140 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "1170 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "150 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "1410 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "1200 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "1290 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "1350 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "180 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "1380 0 30 30"
		},
		{
			miniIconRect = "0 0 16 16",
			iconRect = "1170 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "150 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "1440 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "1200 0 30 30"
		},
		{
			miniIconRect = "32 0 16 16",
			iconRect = "1320 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "1170 0 30 30"
		},
		{
			miniIconRect = "64 0 16 16",
			iconRect = "1290 0 30 30"
		},
		{
			miniIconRect = "48 0 16 16",
			iconRect = "1200 0 30 30"
		},
		{
			miniIconRect = "16 0 16 16",
			iconRect = "180 0 30 30"
		},
		{
			miniIconRect = "32 0 16 16",
			iconRect = "1230 0 30 30"
		}
	}
}
