-- chunkname: @/gamelib/wheeldestiny.lua

WheelDestiny = {}
WheelDestiny.Sides = {
	topLeft = {
		child = {
			1,
			7,
			2,
			13,
			8,
			3,
			14,
			9,
			15
		},
		perks = {
			{
				text = "Gift of Life\nAllows you to survive an\notherwise fatal blow.",
				largeClip = 0,
				revelation = "Gift of Life"
			},
			{
				text = "Gift of Life\nAllows you to survive an\notherwise fatal blow.",
				largeClip = 0,
				revelation = "Gift of Life"
			},
			{
				text = "Gift of Life\nAllows you to survive an\notherwise fatal blow.",
				largeClip = 0,
				revelation = "Gift of Life"
			},
			{
				text = "Gift of Life\nAllows you to survive an\notherwise fatal blow.",
				largeClip = 0,
				revelation = "Gift of Life"
			},
			{
				text = "Gift of Life\nAllows you to survive an\notherwise fatal blow.",
				largeClip = 0,
				revelation = "Gift of Life"
			}
		}
	},
	topRight = {
		child = {
			6,
			5,
			12,
			11,
			4,
			10,
			18,
			17,
			16
		},
		perks = {
			{
				text = "Executioner's Throw\nThrowing attack that deals\nmassive damage to\nenemies with low hit\npoints.",
				largeClip = 1,
				revelation = "Executioner's ..."
			},
			{
				text = "Divine Grenade\nDeploy a powerful delayed\neffect that deals holy\ndamage.",
				largeClip = 4,
				revelation = "Divine Grenade"
			},
			{
				text = "Beam Mastery\nBoosts all of your beam\nspells and unlocks a beam\nspell that deals death\ndamage.",
				largeClip = 7,
				revelation = "Beam Mastery"
			},
			{
				text = "Blessing Of the Grove\nIncreases your healing if\nthe target's missing hit\npoints is below certain\nthresholds.",
				largeClip = 11,
				revelation = "Blessing Of the..."
			},
			{
				text = "Spiritual Outburst\nA powerful spell that\nconsumes Harmony to release\na massive chain attack.",
				largeClip = 13,
				revelation = "Spiritual Outburst"
			}
		}
	},
	bottomLeft = {
		child = {
			21,
			20,
			27,
			19,
			26,
			33,
			25,
			32,
			31
		},
		perks = {
			{
				text = "Combat Mastery\nImprove your combat\nprowess based on the\nequipment you use.",
				largeClip = 2,
				revelation = "Combat Mastery"
			},
			{
				text = "Divine Empowerment\nThis support spell creates\na field that increases your\ndealt damage.",
				largeClip = 5,
				revelation = "Divine Empow..."
			},
			{
				text = "Drain Body\nImprove your crippling\nspells by adding mana or\nlife leech to them.",
				largeClip = 8,
				revelation = "Drain Body"
			},
			{
				text = "Twin Bursts\nPowerful ring spell that\ndeals ice or earth damage\nthat is enchanced against\ntargets with high hit points.",
				largeClip = 10,
				revelation = "Twin Bursts"
			},
			{
				text = "Ascetic\nImprove all spenders and\nallows mantra to improve the\ndamage of your attacks.",
				largeClip = 14,
				revelation = "Ascetic"
			}
		}
	},
	bottomRight = {
		child = {
			22,
			23,
			28,
			34,
			29,
			24,
			30,
			35,
			36
		},
		perks = {
			{
				text = "Avatar of Steel\nTransforms you into a\npowerful form that reeduces\ndamage taken and\nincreases damage dealt.",
				largeClip = 3,
				revelation = "Avatar of Steel"
			},
			{
				text = "Avatar of Light\nTransforms you into a\npowerful form that reeduces\ndamage taken and\nincreases damage dealt.",
				largeClip = 6,
				revelation = "Avatar of Light"
			},
			{
				text = "Avatar of Storm\nTransforms you into a\npowerful form that reeduces\ndamage taken and\nincreases damage dealt.",
				largeClip = 9,
				revelation = "Avatar of Storm"
			},
			{
				text = "Avatar of Nature\nTransforms you into a\npowerful form that reeduces\ndamage taken and\nincreases damage dealt.",
				largeClip = 12,
				revelation = "Avatar of Nature"
			},
			{
				text = "Avatar of Balance\nTransforms you into a\npowerful form that reduces\ndamage taken and increases\ndamage dealt.",
				largeClip = 15,
				revelation = "Avatar of Balance"
			}
		}
	}
}
WheelDestiny.Slots = {
	{
		max = 200,
		min = 0,
		brothers = {
			7,
			2
		},
		dependency = {},
		perk = {}
	},
	{
		max = 150,
		min = 0,
		brothers = {
			8,
			3,
			7
		},
		dependency = {
			1
		},
		perk = {}
	},
	{
		max = 100,
		min = 0,
		brothers = {
			9,
			8,
			4
		},
		dependency = {
			2
		},
		perk = {}
	},
	{
		max = 100,
		min = 0,
		brothers = {
			10,
			3,
			11
		},
		dependency = {
			5
		},
		perk = {}
	},
	{
		max = 150,
		min = 0,
		brothers = {
			4,
			11,
			12
		},
		dependency = {
			6
		},
		perk = {}
	},
	{
		max = 200,
		min = 0,
		brothers = {
			5,
			12
		},
		dependency = {},
		perk = {}
	},
	{
		max = 150,
		min = 0,
		brothers = {
			13,
			8,
			2
		},
		dependency = {
			1
		},
		perk = {}
	},
	{
		max = 100,
		min = 0,
		brothers = {
			14,
			9,
			3,
			13
		},
		dependency = {
			7,
			2
		},
		perk = {}
	},
	{
		max = 75,
		min = 0,
		brothers = {
			15,
			14,
			10
		},
		dependency = {
			3,
			8
		},
		perk = {}
	},
	{
		max = 75,
		min = 0,
		brothers = {
			16,
			17,
			9
		},
		dependency = {
			4,
			11
		},
		perk = {}
	},
	{
		max = 100,
		min = 0,
		brothers = {
			10,
			17,
			4,
			18
		},
		dependency = {
			5,
			12
		},
		perk = {}
	},
	{
		max = 150,
		min = 0,
		brothers = {
			11,
			18,
			5
		},
		dependency = {
			6
		},
		perk = {}
	},
	{
		max = 100,
		min = 0,
		brothers = {
			14,
			19,
			8
		},
		dependency = {
			7
		},
		perk = {}
	},
	{
		max = 75,
		min = 0,
		brothers = {
			15,
			9,
			20
		},
		dependency = {
			13,
			8
		},
		perk = {}
	},
	{
		max = 50,
		min = 0,
		brothers = {},
		dependency = {
			14,
			9
		},
		perk = {}
	},
	{
		max = 50,
		min = 0,
		brothers = {},
		dependency = {
			10,
			17
		},
		perk = {}
	},
	{
		max = 75,
		min = 0,
		brothers = {
			16,
			23,
			10
		},
		dependency = {
			11,
			18
		},
		perk = {}
	},
	{
		max = 100,
		min = 0,
		brothers = {
			17,
			11,
			24
		},
		dependency = {
			12
		},
		perk = {}
	},
	{
		max = 100,
		min = 0,
		brothers = {
			20,
			13,
			26
		},
		dependency = {
			25
		},
		perk = {}
	},
	{
		max = 75,
		min = 0,
		brothers = {
			21,
			14,
			27
		},
		dependency = {
			19,
			26
		},
		perk = {}
	},
	{
		max = 50,
		min = 0,
		brothers = {},
		dependency = {
			20,
			27
		},
		perk = {}
	},
	{
		max = 50,
		min = 0,
		brothers = {},
		dependency = {
			28,
			23
		},
		perk = {}
	},
	{
		max = 75,
		min = 0,
		brothers = {
			22,
			17,
			28
		},
		dependency = {
			24,
			29
		},
		perk = {}
	},
	{
		max = 100,
		min = 0,
		brothers = {
			23,
			29,
			18
		},
		dependency = {
			30
		},
		perk = {}
	},
	{
		max = 150,
		min = 0,
		brothers = {
			19,
			26,
			32
		},
		dependency = {
			31
		},
		perk = {}
	},
	{
		max = 100,
		min = 0,
		brothers = {
			20,
			27,
			19,
			33
		},
		dependency = {
			25,
			32
		},
		perk = {}
	},
	{
		max = 75,
		min = 0,
		brothers = {
			21,
			20,
			28
		},
		dependency = {
			26,
			33
		},
		perk = {}
	},
	{
		max = 75,
		min = 0,
		brothers = {
			22,
			27,
			23
		},
		dependency = {
			34,
			29
		},
		perk = {}
	},
	{
		max = 100,
		min = 0,
		brothers = {
			28,
			23,
			24,
			34
		},
		dependency = {
			35,
			30
		},
		perk = {}
	},
	{
		max = 150,
		min = 0,
		brothers = {
			29,
			24,
			35
		},
		dependency = {
			36
		},
		perk = {}
	},
	{
		max = 200,
		min = 0,
		brothers = {
			25,
			32
		},
		dependency = {},
		perk = {}
	},
	{
		max = 150,
		min = 0,
		brothers = {
			25,
			26,
			33
		},
		dependency = {
			31
		},
		perk = {}
	},
	{
		max = 100,
		min = 0,
		brothers = {
			27,
			26,
			34
		},
		dependency = {
			32
		},
		perk = {}
	},
	{
		max = 100,
		min = 0,
		brothers = {
			28,
			33,
			29
		},
		dependency = {
			35
		},
		perk = {}
	},
	{
		max = 150,
		min = 0,
		brothers = {
			34,
			29,
			30
		},
		dependency = {
			36
		},
		perk = {}
	},
	{
		max = 200,
		min = 0,
		brothers = {
			35,
			30
		},
		dependency = {},
		perk = {}
	}
}
WheelDestiny.SocketsTier = {
	[0] = {
		{
			enabled = 1,
			disabled = 13
		},
		{
			enabled = 2,
			disabled = 14
		},
		{
			enabled = 3,
			disabled = 15
		}
	},
	{
		{
			enabled = 4,
			disabled = 16
		},
		{
			enabled = 5,
			disabled = 17
		},
		{
			enabled = 6,
			disabled = 18
		}
	},
	{
		{
			enabled = 7,
			disabled = 19
		},
		{
			enabled = 8,
			disabled = 20
		},
		{
			enabled = 9,
			disabled = 21
		}
	},
	{
		{
			enabled = 10,
			disabled = 22
		},
		{
			enabled = 11,
			disabled = 23
		},
		{
			enabled = 12,
			disabled = 24
		}
	}
}
WheelDestiny.GemSlots = {
	[15] = {
		index = 1,
		affinity = 0
	},
	[3] = {
		index = 2,
		affinity = 0
	},
	[7] = {
		index = 3,
		affinity = 0
	},
	[10] = {
		index = 1,
		affinity = 1
	},
	[18] = {
		index = 2,
		affinity = 1
	},
	[5] = {
		index = 3,
		affinity = 1
	},
	[27] = {
		index = 1,
		affinity = 2
	},
	[19] = {
		index = 2,
		affinity = 2
	},
	[32] = {
		index = 3,
		affinity = 2
	},
	[22] = {
		index = 1,
		affinity = 3
	},
	[34] = {
		index = 2,
		affinity = 3
	},
	[30] = {
		index = 3,
		affinity = 3
	}
}
WheelDestiny.MediumPerkInfos = {
	{
		FormatType = "PlusFullPercent",
		Name = "Fire Resistance",
		LongInfo = "",
		SummaryPriority = 3
	},
	{
		FormatType = "PlusFullPercent",
		Name = "Energy Resistance",
		LongInfo = "",
		SummaryPriority = 3
	},
	{
		FormatType = "PlusFullPercent",
		Name = "Ice Resistance",
		LongInfo = "",
		SummaryPriority = 3
	},
	{
		FormatType = "PlusFullPercent",
		Name = "Earth Resistance",
		LongInfo = "",
		SummaryPriority = 3
	},
	{
		FormatType = "SpecialFormat",
		Name = "Holy and Death Resistance",
		LongInfo = "",
		SummaryPriority = 2
	},
	{
		FormatType = "PlusPercentWithTwoFloatingpoints",
		Name = "Mana Leech",
		LongInfo = "",
		SummaryPriority = 4
	},
	{
		FormatType = "PlusPercentWithTwoFloatingpoints",
		Name = "Life Leech",
		LongInfo = "",
		SummaryPriority = 4
	},
	{
		FormatType = "PlusInteger",
		Name = "Weapon Skill Boost",
		LongInfo = "Applies to sword, axe and club fighting",
		SummaryPriority = 0
	},
	{
		FormatType = "NoEffectDisplay",
		Name = "Battle Instinct",
		LongInfo = "Gain +6 shielding and +1 sword/axe/club fighting when 5 creatures are on adjacent squares.\nFor each additional creature, up to a maximum of 8, you get +6 shielding and +1 sword/axe/club fighting more.",
		SummaryPriority = 0
	},
	{
		FormatType = "NoEffectDisplay",
		Name = "Battle Healing",
		LongInfo = "For each creature challenged, you will heal yourself for a small amount. This amount scales with your shielding skill. Heals for double the amount if you have less than 60% of your hit points and triple the amount if you have less than 30% of your hit points.",
		SummaryPriority = 0
	},
	{
		Name = "Augmented Fierce Berserk|Aug. Fierce Berserk",
		Aug2Info = "+10% Base Damage",
		FormatType = "RomanNumerals",
		Aug1Info = "-30 Mana Cost",
		SummaryPriority = 1
	},
	{
		Name = "Augmented Intense Wound Cleansing|Aug. Intense Wound Cleansing",
		Aug2Info = "-300s Cooldown",
		FormatType = "RomanNumerals",
		Aug1Info = "+125% Base Healing",
		SummaryPriority = 1
	},
	{
		Name = "Augmented Front Sweep|Aug. Front Sweep",
		Aug2Info = "+14% Base Damage",
		FormatType = "RomanNumerals",
		Aug1Info = "Adds 5% life leech to this spell",
		SummaryPriority = 1
	},
	{
		Name = "Augmented Groundshaker|Aug. Groundshaker",
		Aug2Info = "-2s Cooldown",
		FormatType = "RomanNumerals",
		Aug1Info = "+12.5% Base Damage",
		SummaryPriority = 1
	},
	{
		Name = "Augmented Shield Slam|Aug. Shield Slam",
		Aug2Info = "+25% Damage Reduction (75% total)",
		FormatType = "RomanNumerals",
		Aug1Info = "+15% Life Leech",
		SummaryPriority = 1
	},
	{
		FormatType = "PlusInteger",
		Name = "Distance Skill Boost",
		LongInfo = "",
		SummaryPriority = 0
	},
	{
		FormatType = "NoEffectDisplay",
		Name = "Ballistic Mastery",
		LongInfo = "The critical extra damage for attacks with a crossbow is increased by 10%.\nWhile wielding a bow your attacks and spells treat the targets physical and holy sensitivity as being 2% higher.",
		SummaryPriority = 0
	},
	{
		FormatType = "NoEffectDisplay",
		Name = "Ballistic Mastery",
		LongInfo = "Gain +3 distance fighting while no monster is within 1 squares. Otherwise gain +3 holy magic level and +3 healing magic level.",
		SummaryPriority = 0
	},
	{
		Name = "Augmented Divine Caldera|Aug. Divine Caldera",
		Aug2Info = "+8.5% Base Damage",
		FormatType = "RomanNumerals",
		Aug1Info = "-20 Mana Cost",
		SummaryPriority = 1
	},
	{
		Name = "Augmented Divine Barrage|Aug. Divine Barrage",
		Aug2Info = "+15% Base Damage",
		FormatType = "RomanNumerals",
		Aug1Info = "+10% Base Damage",
		SummaryPriority = 1
	},
	{
		Name = "Augmented Divine Dazzle|Aug. Divine Dazzle",
		Aug2Info = "Duration increased; -4s Cooldown",
		FormatType = "RomanNumerals",
		Aug1Info = "Jumps to +1 additional target",
		SummaryPriority = 1
	},
	{
		Name = "Augmented Strong Ethereal Spear|Aug. Strong Ethereal Spear",
		Aug2Info = "+380% Base Damage",
		FormatType = "RomanNumerals",
		Aug1Info = "-2s Cooldown",
		SummaryPriority = 1
	},
	{
		Name = "Augmented Ethereal Barrage|Aug. Ethereal Barrage",
		Aug2Info = "+10% Critical Chance",
		FormatType = "RomanNumerals",
		Aug1Info = "+10% Life Leech",
		SummaryPriority = 1
	},
	{
		FormatType = "NoEffectDisplay",
		Name = "Focus Mastery",
		LongInfo = "Increases the damage of your next damage spell by 35% within 12 seconds after casting a focus spell.",
		SummaryPriority = 0
	},
	{
		Name = "Augmented Great Fire Wave|Aug. Great Fire Wave",
		Aug2Info = "+5% Base Damage",
		FormatType = "RomanNumerals",
		Aug1Info = "Adds 15% critical extra damage for this spell and grants a 10% chance (non-cumulative) for a critical hit.",
		SummaryPriority = 1
	},
	{
		Name = "Augmented Energy Wave|Aug. Energy Wave",
		Aug2Info = "Affected area enlarged",
		FormatType = "RomanNumerals",
		Aug1Info = "+5% Base Damage",
		SummaryPriority = 1
	},
	{
		Name = "Augmented Special Spells|Aug. Special Spells",
		Aug2Info = "Damage reduction increased by +1%",
		FormatType = "RomanNumerals",
		Aug1Info = "Affected area enlarged",
		SummaryPriority = 1
	},
	{
		Name = "Augmented Focus Spells|Aug. Focus Spells",
		Aug2Info = "-4s Cooldown; Focus secondary group cooldown -4s for Hell's Core and Rage of the Skies",
		FormatType = "RomanNumerals",
		Aug1Info = "+5% Base Damage for Hell's Core and Rage of the Skies",
		SummaryPriority = 1
	},
	{
		FormatType = "NoEffectDisplay",
		Name = "Healing Link",
		LongInfo = "If you heal someone with Nature's Embrace or Heal Friend, you also heal yourself for 10% of the applied healing.",
		SummaryPriority = 0
	},
	{
		Name = "Augmented Forked Spells|Aug. Forked Spells",
		Aug2Info = "Adds +1 target",
		FormatType = "RomanNumerals",
		Aug1Info = "-2s Cooldown",
		SummaryPriority = 1
	},
	{
		Name = "Augmented Terra Wave|Aug. Terra Wave",
		Aug2Info = "Adds 5% life leech to this spell",
		FormatType = "RomanNumerals",
		Aug1Info = "+6.5% Base Damage",
		SummaryPriority = 1
	},
	{
		Name = "Augmented Strong Ice Wave|Aug. Strong Ice Wave",
		Aug2Info = "Affected area enlarged",
		FormatType = "RomanNumerals",
		Aug1Info = "+6% Base Damage",
		SummaryPriority = 1
	},
	{
		Name = "Augmented Mass Healing|Aug. Mass Healing",
		Aug2Info = "Affected area enlarged",
		FormatType = "RomanNumerals",
		Aug1Info = "+4% Base Healing",
		SummaryPriority = 1
	},
	{
		Name = "Augmented Heal Friend|Aug. Heal Friend",
		Aug2Info = "+6% Base Healing",
		FormatType = "RomanNumerals",
		Aug1Info = "+4% Base Healing",
		SummaryPriority = 1
	},
	{
		FormatType = "PlusInteger",
		Name = "Magic Skill Boost",
		LongInfo = "",
		SummaryPriority = 0
	},
	{
		FormatType = "NoEffectDisplay",
		Name = "Runic Mastery",
		LongInfo = "If you use a rune, you have a 25% chance of increasing your magic level by 10%, or by 20% if you use a rune that can be created by your vocation.",
		SummaryPriority = 0
	},
	{
		Name = "Augmented Death Echo|Aug. Death Echo",
		Aug2Info = "-6s Cooldown",
		FormatType = "RomanNumerals",
		Aug1Info = "Enhanced effect",
		SummaryPriority = 1
	},
	{
		FormatType = "RomanNumerals",
		Name = "Vessel Resonance Top Left|VR Top Left",
		LongInfo = "Each level of Vessel Resonance unlocks equivalent Gem Mods in its domain. If the Vessel Resonance matches the gem quality, a damage and healing bonus is granted.",
		SummaryPriority = 4
	},
	{
		FormatType = "RomanNumerals",
		Name = "Vessel Resonance Top Right|VR Top Right",
		LongInfo = "Each level of Vessel Resonance unlocks equivalent Gem Mods in its domain. If the Vessel Resonance matches the gem quality, a damage and healing bonus is granted.",
		SummaryPriority = 4
	},
	{
		FormatType = "RomanNumerals",
		Name = "Vessel Resonance Bottom Left|VR Bottom Left",
		LongInfo = "Each level of Vessel Resonance unlocks equivalent Gem Mods in its domain. If the Vessel Resonance matches the gem quality, a damage and healing bonus is granted.",
		SummaryPriority = 4
	},
	{
		FormatType = "RomanNumerals",
		Name = "Vessel Resonance Bottom Right|VR Bottom Right",
		LongInfo = "Each level of Vessel Resonance unlocks equivalent Gem Mods in its domain. If the Vessel Resonance matches the gem quality, a damage and healing bonus is granted.",
		SummaryPriority = 4
	},
	{
		FormatType = "NoEffectDisplay",
		Name = "Sanctuary",
		LongInfo = "Consuming Harmony creates a field lasting 5 seconds, increasing your damage and healing done by 2% for each Harmony consumed.",
		SummaryPriority = 0
	},
	{
		FormatType = "NoEffectDisplay",
		Name = "Guiding Presence",
		LongInfo = "Gain an aura that shares 50% of your mantra with members of your group.",
		SummaryPriority = 0
	},
	{
		FormatType = "PlusInteger",
		Name = "Fist Fighting Skill Boost",
		LongInfo = "",
		SummaryPriority = 0
	},
	{
		Name = "Augmented Thousand Fist Blows|Aug. Thousand Fist Blows",
		Aug2Info = "Adds 25% critical extra damage for this spell and grants a 10% chance (non-cumulative) for a critical hit.",
		FormatType = "RomanNumerals",
		Aug1Info = "Adds 3% mana leech to this spell",
		SummaryPriority = 1
	},
	{
		Name = "Augmented Mass Spirit Mend|Aug. Mass Spirit Mend",
		Aug2Info = "Affected area enlarged",
		FormatType = "RomanNumerals",
		Aug1Info = "+8% Base Healing",
		SummaryPriority = 1
	},
	{
		Name = "Augmented Mystic Repulse|Aug. Mystic Repulse",
		Aug2Info = "+40% Base Damage",
		FormatType = "RomanNumerals",
		Aug1Info = "-4s Cooldown",
		SummaryPriority = 1
	},
	{
		Name = "Augmented Chained Penance|Aug. Chained Penance",
		Aug2Info = "Jumps to +1 additional target",
		FormatType = "RomanNumerals",
		Aug1Info = "Jumps to +1 additional target",
		SummaryPriority = 1
	},
	{
		Name = "Augmented Flurry of Blows|Aug. Flurry of Blows",
		Aug2Info = "+12% Base Damage",
		FormatType = "RomanNumerals",
		Aug1Info = "Adds 5% life leech to this spell",
		SummaryPriority = 1
	},
	GeneralInfo = "The Conviction Perk is unlocked when the maximum number of\npromotion points for this slice has been assigned.\n\nMost Conviction Perks can be found more than once within the\nWheel of Destiny. When they are unlocked, their effect adds up.",
	DisplayName = "Conviction Perk",
	AugGeneralInfo = "The Conviction Perk is unlocked when the maximum number of\npromotion points for this slice has been assigned.\n\nThere are always two identical Augmentations within the Wheel of\nDestiny. Regardless of the order of unlocking, bonus I will always\nbe available before bonus II."
}
WDHit = 1
WDMana = 2
WDCap = 3
WDMit = 4
WheelDestiny.Dedications = {
	[WDHit] = {
		text = "Hit Points"
	},
	[WDMana] = {
		text = "Mana"
	},
	[WDCap] = {
		text = "Capacity"
	},
	[WDMit] = {
		text = "Mitigation Multiplier",
		percent = true
	}
}
WheelDestiny.INFO_DEDICATIONS = 1
WheelDestiny.INFO_CONVICTIONS = 2
WheelDestiny.MIN_VOCATION = 1
WheelDestiny.MAX_VOCATION = 5
WheelDestiny.INFO_CONVICTION_MEDIUM = 2

function WheelDestiny.CreateDedicationInfo(data)
	local result = {}

	result.text = data.id
	result.quantity = data.quantity
	result.percent = WheelDestiny.Dedications[data.id].percent or false

	return result
end

function WheelDestiny.CreateConvictionInfo(data, convType)
	if convType == WheelDestiny.INFO_CONVICTION_MEDIUM then
		local perkInfo = WheelDestiny.MediumPerkInfos[data.id]
		local result = {}
		local name = perkInfo.Name

		if string.find(perkInfo.Name, "|") then
			local sepName = perkInfo.Name:split("|")

			name = sepName[1]

			if name:len() >= 27 then
				result.longName = sepName[1]
				name = sepName[2]
			end
		end

		if perkInfo.LongInfo then
			result.text = name .. "\n" .. perkInfo.LongInfo
		else
			result.text = name
		end

		result.priority = perkInfo.SummaryPriority
		result.quantity = data.quantity

		if result.quantity and result.quantity < 1 then
			result.percent = true
		end

		return result
	end

	return {
		text = "",
		priority = 0
	}
end

function WheelDestiny.CreateConvictionAug(augId, data)
	local result = {}

	result.augmentation = augId
	result.text = data

	return result
end

function WheelDestiny.AddSlotData(slot, vocation, data)
	if not WheelDestiny.Slots[slot].perk[vocation] then
		WheelDestiny.Slots[slot].perk[vocation] = {}
	end

	WheelDestiny.Slots[slot].perk[vocation].mediumClip = data.icon
	WheelDestiny.Slots[slot].perk[vocation].smallClip = data.subIcon

	if not WheelDestiny.Slots[slot].perk[vocation].dedications then
		WheelDestiny.Slots[slot].perk[vocation].dedications = {}
		WheelDestiny.Slots[slot].perk[vocation].convictions = {}
	end

	local perkData = data.perkData

	if perkData.convictions and perkData.convictions.medium then
		for conv = 1, #perkData.convictions.medium do
			table.insert(WheelDestiny.Slots[slot].perk[vocation].convictions, WheelDestiny.CreateConvictionInfo(perkData.convictions.medium[conv], WheelDestiny.INFO_CONVICTION_MEDIUM))

			local convId = perkData.convictions.medium[conv].id

			if WheelDestiny.MediumPerkInfos[convId].Aug1Info then
				for i = 1, 2 do
					if WheelDestiny.MediumPerkInfos[convId]["Aug" .. i .. "Info"] then
						table.insert(WheelDestiny.Slots[slot].perk[vocation].convictions, WheelDestiny.CreateConvictionAug(i, WheelDestiny.MediumPerkInfos[convId]["Aug" .. i .. "Info"]))
					end
				end
			end
		end
	end

	if perkData.dedications then
		for ded = 1, #perkData.dedications do
			table.insert(WheelDestiny.Slots[slot].perk[vocation].dedications, WheelDestiny.CreateDedicationInfo(perkData.dedications[ded]))
		end
	end
end

WheelDestiny.AddSlotData(1, VocationsClient.Knight, {
	subIcon = 2,
	icon = 8,
	perkData = {
		dedications = {
			{
				quantity = 3,
				id = WDHit
			},
			{
				quantity = 1,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 9
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(2, VocationsClient.Knight, {
	subIcon = 4,
	icon = 5,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 6,
					quantity = 0.75
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(3, VocationsClient.Knight, {
	subIcon = 0,
	icon = 37,
	perkData = {
		dedications = {
			{
				quantity = 3,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 38
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(4, VocationsClient.Knight, {
	subIcon = 1,
	icon = 7,
	perkData = {
		dedications = {
			{
				quantity = 1,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 8,
					quantity = 1
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(5, VocationsClient.Knight, {
	subIcon = 0,
	icon = 38,
	perkData = {
		dedications = {
			{
				quantity = 3,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 39
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(6, VocationsClient.Knight, {
	subIcon = 2,
	icon = 12,
	perkData = {
		dedications = {
			{
				quantity = 3,
				id = WDHit
			},
			{
				quantity = 1,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 13
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(7, VocationsClient.Knight, {
	subIcon = 4,
	icon = 37,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 38
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(8, VocationsClient.Knight, {
	subIcon = 0,
	icon = 14,
	perkData = {
		dedications = {
			{
				quantity = 3,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 14
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(9, VocationsClient.Knight, {
	subIcon = 1,
	icon = 6,
	perkData = {
		dedications = {
			{
				quantity = 1,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 7,
					quantity = 0.75
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(10, VocationsClient.Knight, {
	subIcon = 3,
	icon = 38,
	perkData = {
		dedications = {
			{
				quantity = 5,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 39
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(11, VocationsClient.Knight, {
	subIcon = 1,
	icon = 13,
	perkData = {
		dedications = {
			{
				quantity = 1,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 15
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(12, VocationsClient.Knight, {
	subIcon = 0,
	icon = 5,
	perkData = {
		dedications = {
			{
				quantity = 3,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 6,
					quantity = 0.25
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(13, VocationsClient.Knight, {
	subIcon = 0,
	icon = 11,
	perkData = {
		dedications = {
			{
				quantity = 3,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 12
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(14, VocationsClient.Knight, {
	subIcon = 1,
	icon = 7,
	perkData = {
		dedications = {
			{
				quantity = 1,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 8,
					quantity = 1
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(15, VocationsClient.Knight, {
	subIcon = 3,
	icon = 37,
	perkData = {
		dedications = {
			{
				quantity = 5,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 38
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(16, VocationsClient.Knight, {
	subIcon = 4,
	icon = 10,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 11
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(17, VocationsClient.Knight, {
	subIcon = 3,
	icon = 6,
	perkData = {
		dedications = {
			{
				quantity = 5,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 7,
					quantity = 0.75
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(18, VocationsClient.Knight, {
	subIcon = 1,
	icon = 38,
	perkData = {
		dedications = {
			{
				quantity = 1,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 39
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(19, VocationsClient.Knight, {
	subIcon = 4,
	icon = 39,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 40
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(20, VocationsClient.Knight, {
	subIcon = 0,
	icon = 5,
	perkData = {
		dedications = {
			{
				quantity = 3,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 6,
					quantity = 0.25
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(21, VocationsClient.Knight, {
	subIcon = 1,
	icon = 12,
	perkData = {
		dedications = {
			{
				quantity = 1,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 13
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(22, VocationsClient.Knight, {
	subIcon = 0,
	icon = 40,
	perkData = {
		dedications = {
			{
				quantity = 3,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 41
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(23, VocationsClient.Knight, {
	subIcon = 4,
	icon = 7,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 8
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(24, VocationsClient.Knight, {
	subIcon = 3,
	icon = 14,
	perkData = {
		dedications = {
			{
				quantity = 5,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 14
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(25, VocationsClient.Knight, {
	subIcon = 3,
	icon = 6,
	perkData = {
		dedications = {
			{
				quantity = 5,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 7,
					quantity = 0.75
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(26, VocationsClient.Knight, {
	subIcon = 4,
	icon = 13,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 15
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(27, VocationsClient.Knight, {
	subIcon = 0,
	icon = 39,
	perkData = {
		dedications = {
			{
				quantity = 3,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 40
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(28, VocationsClient.Knight, {
	subIcon = 4,
	icon = 5,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 6,
					quantity = 0.25
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(29, VocationsClient.Knight, {
	subIcon = 3,
	icon = 11,
	perkData = {
		dedications = {
			{
				quantity = 5,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 12
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(30, VocationsClient.Knight, {
	subIcon = 1,
	icon = 40,
	perkData = {
		dedications = {
			{
				quantity = 1,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 41
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(31, VocationsClient.Knight, {
	subIcon = 2,
	icon = 10,
	perkData = {
		dedications = {
			{
				quantity = 3,
				id = WDHit
			},
			{
				quantity = 1,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 11
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(32, VocationsClient.Knight, {
	subIcon = 3,
	icon = 39,
	perkData = {
		dedications = {
			{
				quantity = 5,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 40
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(33, VocationsClient.Knight, {
	subIcon = 4,
	icon = 7,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 8
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(34, VocationsClient.Knight, {
	subIcon = 3,
	icon = 40,
	perkData = {
		dedications = {
			{
				quantity = 5,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 41
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(35, VocationsClient.Knight, {
	subIcon = 1,
	icon = 6,
	perkData = {
		dedications = {
			{
				quantity = 1,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 7,
					quantity = 0.75
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(36, VocationsClient.Knight, {
	subIcon = 2,
	icon = 9,
	perkData = {
		dedications = {
			{
				quantity = 3,
				id = WDHit
			},
			{
				quantity = 1,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 10
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(1, VocationsClient.Paladin, {
	subIcon = 2,
	icon = 17,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDHit
			},
			{
				quantity = 3,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 18
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(2, VocationsClient.Paladin, {
	subIcon = 4,
	icon = 5,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 6,
					quantity = 0.25
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(3, VocationsClient.Paladin, {
	subIcon = 0,
	icon = 37,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 38
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(4, VocationsClient.Paladin, {
	subIcon = 1,
	icon = 15,
	perkData = {
		dedications = {
			{
				quantity = 3,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 16,
					quantity = 1
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(5, VocationsClient.Paladin, {
	subIcon = 0,
	icon = 38,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 39
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(6, VocationsClient.Paladin, {
	subIcon = 2,
	icon = 22,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDHit
			},
			{
				quantity = 3,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 23
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(7, VocationsClient.Paladin, {
	subIcon = 4,
	icon = 37,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 38
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(8, VocationsClient.Paladin, {
	subIcon = 0,
	icon = 21,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 39
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(9, VocationsClient.Paladin, {
	subIcon = 1,
	icon = 6,
	perkData = {
		dedications = {
			{
				quantity = 3,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 7,
					quantity = 0.75
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(10, VocationsClient.Paladin, {
	subIcon = 3,
	icon = 38,
	perkData = {
		dedications = {
			{
				quantity = 4,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 39
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(11, VocationsClient.Paladin, {
	subIcon = 1,
	icon = 20,
	perkData = {
		dedications = {
			{
				quantity = 3,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 21
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(12, VocationsClient.Paladin, {
	subIcon = 0,
	icon = 5,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 6,
					quantity = 0.25
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(13, VocationsClient.Paladin, {
	subIcon = 0,
	icon = 19,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 20
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(14, VocationsClient.Paladin, {
	subIcon = 1,
	icon = 15,
	perkData = {
		dedications = {
			{
				quantity = 3,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 16,
					quantity = 1
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(15, VocationsClient.Paladin, {
	subIcon = 3,
	icon = 37,
	perkData = {
		dedications = {
			{
				quantity = 4,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 38
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(16, VocationsClient.Paladin, {
	subIcon = 4,
	icon = 18,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 19
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(17, VocationsClient.Paladin, {
	subIcon = 3,
	icon = 6,
	perkData = {
		dedications = {
			{
				quantity = 4,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 7,
					quantity = 0.75
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(18, VocationsClient.Paladin, {
	subIcon = 1,
	icon = 38,
	perkData = {
		dedications = {
			{
				quantity = 3,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 39
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(19, VocationsClient.Paladin, {
	subIcon = 4,
	icon = 39,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 40
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(20, VocationsClient.Paladin, {
	subIcon = 0,
	icon = 5,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 6,
					quantity = 0.25
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(21, VocationsClient.Paladin, {
	subIcon = 1,
	icon = 22,
	perkData = {
		dedications = {
			{
				quantity = 3,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 23
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(22, VocationsClient.Paladin, {
	subIcon = 0,
	icon = 40,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 41
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(23, VocationsClient.Paladin, {
	subIcon = 4,
	icon = 15,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 16,
					quantity = 1
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(24, VocationsClient.Paladin, {
	subIcon = 3,
	icon = 21,
	perkData = {
		dedications = {
			{
				quantity = 4,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 22
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(25, VocationsClient.Paladin, {
	subIcon = 3,
	icon = 6,
	perkData = {
		dedications = {
			{
				quantity = 4,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 7,
					quantity = 0.75
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(26, VocationsClient.Paladin, {
	subIcon = 4,
	icon = 20,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 21
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(27, VocationsClient.Paladin, {
	subIcon = 0,
	icon = 39,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 40
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(28, VocationsClient.Paladin, {
	subIcon = 4,
	icon = 5,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 6,
					quantity = 0.25
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(29, VocationsClient.Paladin, {
	subIcon = 3,
	icon = 19,
	perkData = {
		dedications = {
			{
				quantity = 4,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 20
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(30, VocationsClient.Paladin, {
	subIcon = 1,
	icon = 40,
	perkData = {
		dedications = {
			{
				quantity = 3,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 41
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(31, VocationsClient.Paladin, {
	subIcon = 2,
	icon = 18,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDHit
			},
			{
				quantity = 3,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 19
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(32, VocationsClient.Paladin, {
	subIcon = 3,
	icon = 39,
	perkData = {
		dedications = {
			{
				quantity = 4,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 40
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(33, VocationsClient.Paladin, {
	subIcon = 4,
	icon = 15,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 16,
					quantity = 1
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(34, VocationsClient.Paladin, {
	subIcon = 3,
	icon = 40,
	perkData = {
		dedications = {
			{
				quantity = 4,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 41
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(35, VocationsClient.Paladin, {
	subIcon = 1,
	icon = 6,
	perkData = {
		dedications = {
			{
				quantity = 3,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 7,
					quantity = 0.75
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(36, VocationsClient.Paladin, {
	subIcon = 2,
	icon = 16,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDHit
			},
			{
				quantity = 3,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 17
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(1, VocationsClient.Sorcerer, {
	subIcon = 2,
	icon = 35,
	perkData = {
		dedications = {
			{
				quantity = 1,
				id = WDHit
			},
			{
				quantity = 6,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 36
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(2, VocationsClient.Sorcerer, {
	subIcon = 4,
	icon = 5,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 6,
					quantity = 0.25
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(3, VocationsClient.Sorcerer, {
	subIcon = 0,
	icon = 37,
	perkData = {
		dedications = {
			{
				quantity = 1,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 38
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(4, VocationsClient.Sorcerer, {
	subIcon = 1,
	icon = 34,
	perkData = {
		dedications = {
			{
				quantity = 6,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 35,
					quantity = 1
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(5, VocationsClient.Sorcerer, {
	subIcon = 0,
	icon = 38,
	perkData = {
		dedications = {
			{
				quantity = 1,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 39
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(6, VocationsClient.Sorcerer, {
	subIcon = 2,
	icon = 27,
	perkData = {
		dedications = {
			{
				quantity = 1,
				id = WDHit
			},
			{
				quantity = 6,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 28
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(7, VocationsClient.Sorcerer, {
	subIcon = 4,
	icon = 37,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 38
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(8, VocationsClient.Sorcerer, {
	subIcon = 0,
	icon = 26,
	perkData = {
		dedications = {
			{
				quantity = 1,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 37
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(9, VocationsClient.Sorcerer, {
	subIcon = 1,
	icon = 6,
	perkData = {
		dedications = {
			{
				quantity = 6,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 7,
					quantity = 0.75
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(10, VocationsClient.Sorcerer, {
	subIcon = 3,
	icon = 38,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 39
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(11, VocationsClient.Sorcerer, {
	subIcon = 1,
	icon = 36,
	perkData = {
		dedications = {
			{
				quantity = 6,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 27
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(12, VocationsClient.Sorcerer, {
	subIcon = 0,
	icon = 5,
	perkData = {
		dedications = {
			{
				quantity = 1,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 6,
					quantity = 0.25
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(13, VocationsClient.Sorcerer, {
	subIcon = 0,
	icon = 25,
	perkData = {
		dedications = {
			{
				quantity = 1,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 26
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(14, VocationsClient.Sorcerer, {
	subIcon = 1,
	icon = 34,
	perkData = {
		dedications = {
			{
				quantity = 6,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 35,
					quantity = 1
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(15, VocationsClient.Sorcerer, {
	subIcon = 3,
	icon = 37,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 38
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(16, VocationsClient.Sorcerer, {
	subIcon = 4,
	icon = 24,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 25
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(17, VocationsClient.Sorcerer, {
	subIcon = 3,
	icon = 6,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 7,
					quantity = 0.75
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(18, VocationsClient.Sorcerer, {
	subIcon = 1,
	icon = 38,
	perkData = {
		dedications = {
			{
				quantity = 6,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 39
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(19, VocationsClient.Sorcerer, {
	subIcon = 4,
	icon = 39,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 40
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(20, VocationsClient.Sorcerer, {
	subIcon = 0,
	icon = 5,
	perkData = {
		dedications = {
			{
				quantity = 1,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 6,
					quantity = 0.25
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(21, VocationsClient.Sorcerer, {
	subIcon = 1,
	icon = 27,
	perkData = {
		dedications = {
			{
				quantity = 6,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 28
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(22, VocationsClient.Sorcerer, {
	subIcon = 0,
	icon = 40,
	perkData = {
		dedications = {
			{
				quantity = 1,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 41
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(23, VocationsClient.Sorcerer, {
	subIcon = 4,
	icon = 34,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 35,
					quantity = 1
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(24, VocationsClient.Sorcerer, {
	subIcon = 3,
	icon = 26,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 37
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(25, VocationsClient.Sorcerer, {
	subIcon = 3,
	icon = 6,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 7,
					quantity = 0.75
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(26, VocationsClient.Sorcerer, {
	subIcon = 4,
	icon = 36,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 27
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(27, VocationsClient.Sorcerer, {
	subIcon = 0,
	icon = 39,
	perkData = {
		dedications = {
			{
				quantity = 1,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 40
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(28, VocationsClient.Sorcerer, {
	subIcon = 4,
	icon = 5,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 6,
					quantity = 0.25
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(29, VocationsClient.Sorcerer, {
	subIcon = 3,
	icon = 25,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 26
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(30, VocationsClient.Sorcerer, {
	subIcon = 1,
	icon = 40,
	perkData = {
		dedications = {
			{
				quantity = 6,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 41
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(31, VocationsClient.Sorcerer, {
	subIcon = 2,
	icon = 24,
	perkData = {
		dedications = {
			{
				quantity = 1,
				id = WDHit
			},
			{
				quantity = 6,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 25
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(32, VocationsClient.Sorcerer, {
	subIcon = 3,
	icon = 39,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 40
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(33, VocationsClient.Sorcerer, {
	subIcon = 4,
	icon = 34,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 35,
					quantity = 1
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(34, VocationsClient.Sorcerer, {
	subIcon = 3,
	icon = 40,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 41
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(35, VocationsClient.Sorcerer, {
	subIcon = 1,
	icon = 6,
	perkData = {
		dedications = {
			{
				quantity = 6,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 7,
					quantity = 0.75
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(36, VocationsClient.Sorcerer, {
	subIcon = 2,
	icon = 23,
	perkData = {
		dedications = {
			{
				quantity = 1,
				id = WDHit
			},
			{
				quantity = 6,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 24
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(1, VocationsClient.Druid, {
	subIcon = 2,
	icon = 28,
	perkData = {
		dedications = {
			{
				quantity = 1,
				id = WDHit
			},
			{
				quantity = 6,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 29
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(2, VocationsClient.Druid, {
	subIcon = 4,
	icon = 5,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 6,
					quantity = 0.25
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(3, VocationsClient.Druid, {
	subIcon = 0,
	icon = 37,
	perkData = {
		dedications = {
			{
				quantity = 1,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 38
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(4, VocationsClient.Druid, {
	subIcon = 1,
	icon = 34,
	perkData = {
		dedications = {
			{
				quantity = 6,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 35,
					quantity = 1
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(5, VocationsClient.Druid, {
	subIcon = 0,
	icon = 38,
	perkData = {
		dedications = {
			{
				quantity = 1,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 39
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(6, VocationsClient.Druid, {
	subIcon = 2,
	icon = 29,
	perkData = {
		dedications = {
			{
				quantity = 1,
				id = WDHit
			},
			{
				quantity = 6,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 30
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(7, VocationsClient.Druid, {
	subIcon = 4,
	icon = 37,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 38
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(8, VocationsClient.Druid, {
	subIcon = 0,
	icon = 32,
	perkData = {
		dedications = {
			{
				quantity = 1,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 33
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(9, VocationsClient.Druid, {
	subIcon = 1,
	icon = 6,
	perkData = {
		dedications = {
			{
				quantity = 6,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 7,
					quantity = 0.75
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(10, VocationsClient.Druid, {
	subIcon = 3,
	icon = 38,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 39
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(11, VocationsClient.Druid, {
	subIcon = 1,
	icon = 33,
	perkData = {
		dedications = {
			{
				quantity = 6,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 34
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(12, VocationsClient.Druid, {
	subIcon = 0,
	icon = 5,
	perkData = {
		dedications = {
			{
				quantity = 1,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 6,
					quantity = 0.25
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(13, VocationsClient.Druid, {
	subIcon = 0,
	icon = 30,
	perkData = {
		dedications = {
			{
				quantity = 1,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 31
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(14, VocationsClient.Druid, {
	subIcon = 1,
	icon = 34,
	perkData = {
		dedications = {
			{
				quantity = 6,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 35,
					quantity = 1
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(15, VocationsClient.Druid, {
	subIcon = 3,
	icon = 37,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 38
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(16, VocationsClient.Druid, {
	subIcon = 4,
	icon = 31,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 32
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(17, VocationsClient.Druid, {
	subIcon = 3,
	icon = 6,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 7,
					quantity = 0.75
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(18, VocationsClient.Druid, {
	subIcon = 1,
	icon = 38,
	perkData = {
		dedications = {
			{
				quantity = 6,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 39
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(19, VocationsClient.Druid, {
	subIcon = 4,
	icon = 39,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 40
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(20, VocationsClient.Druid, {
	subIcon = 0,
	icon = 5,
	perkData = {
		dedications = {
			{
				quantity = 1,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 6,
					quantity = 0.25
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(21, VocationsClient.Druid, {
	subIcon = 1,
	icon = 29,
	perkData = {
		dedications = {
			{
				quantity = 6,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 30
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(22, VocationsClient.Druid, {
	subIcon = 0,
	icon = 40,
	perkData = {
		dedications = {
			{
				quantity = 1,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 41
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(23, VocationsClient.Druid, {
	subIcon = 4,
	icon = 34,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 35,
					quantity = 1
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(24, VocationsClient.Druid, {
	subIcon = 3,
	icon = 32,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 33
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(25, VocationsClient.Druid, {
	subIcon = 3,
	icon = 6,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 7,
					quantity = 0.75
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(26, VocationsClient.Druid, {
	subIcon = 4,
	icon = 33,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 34
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(27, VocationsClient.Druid, {
	subIcon = 0,
	icon = 39,
	perkData = {
		dedications = {
			{
				quantity = 1,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 40
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(28, VocationsClient.Druid, {
	subIcon = 4,
	icon = 5,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 6,
					quantity = 0.25
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(29, VocationsClient.Druid, {
	subIcon = 3,
	icon = 30,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 31
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(30, VocationsClient.Druid, {
	subIcon = 1,
	icon = 40,
	perkData = {
		dedications = {
			{
				quantity = 6,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 41
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(31, VocationsClient.Druid, {
	subIcon = 2,
	icon = 31,
	perkData = {
		dedications = {
			{
				quantity = 1,
				id = WDHit
			},
			{
				quantity = 6,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 32
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(32, VocationsClient.Druid, {
	subIcon = 3,
	icon = 39,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 40
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(33, VocationsClient.Druid, {
	subIcon = 4,
	icon = 34,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 35,
					quantity = 1
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(34, VocationsClient.Druid, {
	subIcon = 3,
	icon = 40,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 41
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(35, VocationsClient.Druid, {
	subIcon = 1,
	icon = 6,
	perkData = {
		dedications = {
			{
				quantity = 6,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 7,
					quantity = 0.75
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(36, VocationsClient.Druid, {
	subIcon = 2,
	icon = 35,
	perkData = {
		dedications = {
			{
				quantity = 1,
				id = WDHit
			},
			{
				quantity = 6,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 36
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(1, VocationsClient.Monk, {
	subIcon = 2,
	icon = 42,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDHit
			},
			{
				quantity = 2,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 43
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(2, VocationsClient.Monk, {
	subIcon = 4,
	icon = 5,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 6,
					quantity = 0.25
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(3, VocationsClient.Monk, {
	subIcon = 0,
	icon = 37,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 38
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(4, VocationsClient.Monk, {
	subIcon = 1,
	icon = 43,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 44,
					quantity = 1
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(5, VocationsClient.Monk, {
	subIcon = 0,
	icon = 38,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 39
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(6, VocationsClient.Monk, {
	subIcon = 2,
	icon = 47,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDHit
			},
			{
				quantity = 2,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 45
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(7, VocationsClient.Monk, {
	subIcon = 4,
	icon = 37,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 38
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(8, VocationsClient.Monk, {
	subIcon = 0,
	icon = 45,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 46
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(9, VocationsClient.Monk, {
	subIcon = 1,
	icon = 6,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 6,
					quantity = 0.75
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(10, VocationsClient.Monk, {
	subIcon = 3,
	icon = 38,
	perkData = {
		dedications = {
			{
				quantity = 5,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 39
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(11, VocationsClient.Monk, {
	subIcon = 1,
	icon = 46,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 47
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(12, VocationsClient.Monk, {
	subIcon = 0,
	icon = 5,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 6,
					quantity = 0.25
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(13, VocationsClient.Monk, {
	subIcon = 0,
	icon = 48,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 48
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(14, VocationsClient.Monk, {
	subIcon = 1,
	icon = 43,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 44,
					quantity = 1
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(15, VocationsClient.Monk, {
	subIcon = 3,
	icon = 37,
	perkData = {
		dedications = {
			{
				quantity = 5,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 38
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(16, VocationsClient.Monk, {
	subIcon = 4,
	icon = 44,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 49
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(17, VocationsClient.Monk, {
	subIcon = 3,
	icon = 6,
	perkData = {
		dedications = {
			{
				quantity = 5,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 6,
					quantity = 0.75
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(18, VocationsClient.Monk, {
	subIcon = 1,
	icon = 38,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 39
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(19, VocationsClient.Monk, {
	subIcon = 4,
	icon = 39,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 40
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(20, VocationsClient.Monk, {
	subIcon = 0,
	icon = 5,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 6,
					quantity = 0.25
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(21, VocationsClient.Monk, {
	subIcon = 1,
	icon = 47,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 45
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(22, VocationsClient.Monk, {
	subIcon = 0,
	icon = 40,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 41
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(23, VocationsClient.Monk, {
	subIcon = 4,
	icon = 43,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 44,
					quantity = 1
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(24, VocationsClient.Monk, {
	subIcon = 3,
	icon = 45,
	perkData = {
		dedications = {
			{
				quantity = 5,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 46
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(25, VocationsClient.Monk, {
	subIcon = 3,
	icon = 6,
	perkData = {
		dedications = {
			{
				quantity = 5,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 6,
					quantity = 0.75
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(26, VocationsClient.Monk, {
	subIcon = 4,
	icon = 46,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 47
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(27, VocationsClient.Monk, {
	subIcon = 0,
	icon = 39,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDHit
			}
		},
		convictions = {
			medium = {
				{
					id = 40
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(28, VocationsClient.Monk, {
	subIcon = 4,
	icon = 5,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 6,
					quantity = 0.25
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(29, VocationsClient.Monk, {
	subIcon = 3,
	icon = 48,
	perkData = {
		dedications = {
			{
				quantity = 5,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 48
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(30, VocationsClient.Monk, {
	subIcon = 1,
	icon = 40,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 41
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(31, VocationsClient.Monk, {
	subIcon = 2,
	icon = 44,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDHit
			},
			{
				quantity = 2,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 49
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(32, VocationsClient.Monk, {
	subIcon = 3,
	icon = 39,
	perkData = {
		dedications = {
			{
				quantity = 5,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 40
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(33, VocationsClient.Monk, {
	subIcon = 4,
	icon = 43,
	perkData = {
		dedications = {
			{
				quantity = 0.03,
				id = WDMit
			}
		},
		convictions = {
			medium = {
				{
					id = 44,
					quantity = 1
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(34, VocationsClient.Monk, {
	subIcon = 3,
	icon = 40,
	perkData = {
		dedications = {
			{
				quantity = 5,
				id = WDCap
			}
		},
		convictions = {
			medium = {
				{
					id = 41
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(35, VocationsClient.Monk, {
	subIcon = 1,
	icon = 6,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 6,
					quantity = 0.75
				}
			}
		}
	}
})
WheelDestiny.AddSlotData(36, VocationsClient.Monk, {
	subIcon = 2,
	icon = 41,
	perkData = {
		dedications = {
			{
				quantity = 2,
				id = WDHit
			},
			{
				quantity = 2,
				id = WDMana
			}
		},
		convictions = {
			medium = {
				{
					id = 44
				}
			}
		}
	}
})
