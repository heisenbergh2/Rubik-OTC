-- chunkname: @/gamelib/market.lua

MarketMaxAmount = 2000
MarketMaxAmountStackable = 64000
MarketMaxPrice = 999999999
MarketMaxOffers = 100
MarketAction = {
	Sell = 1,
	Buy = 0
}
MarketRequest = {
	OldMyHistory = 65535,
	OldMyOffers = 65534,
	BrowseItem = 3,
	MyOffers = 2,
	MyHistory = 1
}
MarketOfferState = {
	Active = 0,
	AcceptedEx = 255,
	Accepted = 3,
	Expired = 2,
	Cancelled = 1
}
MarketOfferStateString = {
	[0] = "active",
	"cancelled",
	"expired",
	"accepted",
	[255] = "acceptedEx"
}
MarketCategory = {
	MetaWeapons = 255,
	WeaponsAll = 32,
	Unassigned = 31,
	Gold = 30,
	Unknown4 = 29,
	Unknown3 = 28,
	FistWeapons = 27,
	SoulCore = 26,
	Quivers = 25,
	CreatureProducs = 24,
	TibiaCoins = 23,
	PremiumScrolls = 22,
	WandsRods = 21,
	Swords = 20,
	DistanceWeapons = 19,
	Clubs = 18,
	Axes = 17,
	Ammunition = 16,
	Valuables = 15,
	Tools = 14,
	Shields = 13,
	Runes = 12,
	Rings = 11,
	Potions = 10,
	Others = 9,
	Legs = 8,
	HelmetsHats = 7,
	Food = 6,
	Decoration = 5,
	Containers = 4,
	Boots = 3,
	Amulets = 2,
	Armors = 1,
	All = 0
}
MarketDetailNames = {
	"Armor: ",
	"Attack: ",
	"Capacity: ",
	"Defence: ",
	"Description: ",
	"Expires after: ",
	"Protection: ",
	"Minimum Required Level: ",
	"Minimum Required Magic Level: ",
	"Vocations: ",
	"Spell: ",
	"Skill Boost: ",
	"Charges: ",
	"Weapon Type: ",
	"Weight: ",
	"Augments: ",
	"Imbuement Slots: ",
	"Magic Shield Capacity: ",
	"Cleave: ",
	"Damage Reflection: ",
	"Perfect Shot: ",
	"Classification: ",
	"Elemental Bound: ",
	"Mantra: ",
	"Imbuement Effect: ",
	"Tier: "
}
MarketCategory.First = MarketCategory.Armors
MarketCategory.Last = MarketCategory.TibiaCoins
MarketCategoryWeapons = {
	[MarketCategory.Ammunition] = {
		slots = {
			255
		}
	},
	[MarketCategory.Axes] = {
		slots = {
			255,
			InventorySlotOther,
			InventorySlotLeft
		}
	},
	[MarketCategory.Clubs] = {
		slots = {
			255,
			InventorySlotOther,
			InventorySlotLeft
		}
	},
	[MarketCategory.DistanceWeapons] = {
		slots = {
			255,
			InventorySlotOther,
			InventorySlotLeft
		}
	},
	[MarketCategory.Swords] = {
		slots = {
			255,
			InventorySlotOther,
			InventorySlotLeft
		}
	},
	[MarketCategory.WandsRods] = {
		slots = {
			255,
			InventorySlotOther,
			InventorySlotLeft
		}
	}
}
MarketCategoryStrings = {
	[0] = "All",
	"Armors",
	"Amulets",
	"Boots",
	"Containers",
	"Decoration",
	"Food",
	"Helmets and Hats",
	"Legs",
	"Others",
	"Potions",
	"Rings",
	"Runes",
	"Shields",
	"Tools",
	"Valuables",
	"Ammunition",
	"Axes",
	"Clubs",
	"Distance Weapons",
	"Swords",
	"Wands and Rods",
	"Premium Scrolls",
	"Tibia Coins",
	[255] = "Weapons"
}

function getMarketCategoryName(id)
	if table.haskey(MarketCategoryStrings, id) then
		return MarketCategoryStrings[id]
	end
end

function getMarketCategoryId(name)
	local id = table.find(MarketCategoryStrings, name)

	if id then
		return id
	end
end

MarketItemDescription = {
	CurrentTier = 23,
	UpgradeClassification = 22,
	Perfect = 21,
	Reflection = 20,
	Cleave = 19,
	MagicShield = 18,
	ImbuingSlots = 17,
	Augment = 16,
	Weight = 15,
	WeaponName = 14,
	Charges = 13,
	Ability = 12,
	Rune = 11,
	Vocation = 10,
	MinMagicLevel = 9,
	MinLevel = 8,
	Combat = 7,
	DecayTime = 6,
	General = 5,
	Defense = 4,
	Container = 3,
	Attack = 2,
	Armor = 1
}
MarketItemDescription.First = MarketItemDescription.Armor
MarketItemDescription.Last = MarketItemDescription.CurrentTier
MarketItemDescriptionStrings = {
	"Armor",
	"Attack",
	"Container",
	"Defense",
	"Description",
	"Use Time",
	"Combat",
	"Min Level",
	"Min Magic Level",
	"Vocation",
	"Rune",
	"Ability",
	"Charges",
	"Weapon Type",
	"Weight",
	"Augment",
	"Imbuing Slots",
	"Magic Shield",
	"Cleave",
	"Reflection",
	"Perfect Show",
	"Upgrade Classification",
	"Elemental Bond",
	"Mantra",
	"Imbuement Effect",
	"Tier"
}

function getMarketDescriptionName(id)
	if table.haskey(MarketItemDescriptionStrings, id) then
		return MarketItemDescriptionStrings[id]
	end
end

function getMarketDescriptionId(name)
	local id = table.find(MarketItemDescriptionStrings, name)

	if id then
		return id
	end
end

MarketSlotFilters = {
	[255] = "Any",
	[InventorySlotOther] = "Two-Handed",
	[InventorySlotLeft] = "One-Handed"
}
MarketFilters = {
	Level = 2,
	Depot = 3,
	SearchAll = 4,
	Vocation = 1
}
MarketFilters.First = MarketFilters.Vocation
MarketFilters.Last = MarketFilters.Depot

function getMarketSlotFilterId(name)
	local id = table.find(MarketSlotFilters, name)

	if id then
		return id
	end
end

function getMarketSlotFilterName(id)
	if table.haskey(MarketSlotFilters, id) then
		return MarketSlotFilters[id]
	end
end

function getCoinStepValue(itemId)
	if itemId == 22118 then
		return 25
	end

	return 1
end
