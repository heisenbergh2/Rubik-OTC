-- chunkname: @/gamelib/creature.lua

NpcIconNone = 0
NpcIconChat = 1
NpcIconTrade = 2
NpcIconSail = 5
NpcIconHireling = 7
CreatureTypePlayer = 0
CreatureTypeMonster = 1
CreatureTypeNpc = 2
CreatureTypeSummonOwn = 3
CreatureTypeSummonOther = 4
CreatureTypeHidden = 5
VocationsClient = {
	None = 0,
	ExaltedMonk = 15,
	ElderDruid = 14,
	MasterSorcerer = 13,
	RoyalPaladin = 12,
	EliteKnight = 11,
	Monk = 5,
	Druid = 4,
	Sorcerer = 3,
	Paladin = 2,
	Knight = 1
}

function getNextSkullId(skullId)
	if skullId == SkullRed or skullId == SkullBlack then
		return SkullBlack
	end

	return SkullRed
end

function getSkullImagePath(skullId)
	local path = "/images/game/creatures/creature-state-flags"
	local clip

	clip = skullId == SkullYellow and "11 11 11 11" or skullId == SkullGreen and "22 11 11 11" or skullId == SkullWhite and "33 11 11 11" or skullId == SkullRed and "44 11 11 11" or skullId == SkullBlack and "55 11 11 11" or skullId == SkullOrange and "66 11 11 11" or "0 11 11 11"

	return path, clip
end

function getSkullHudImagePath(skullId)
	local path = "/images/game/creatures/hud/flags/playerkiller"
	local clip

	if skullId == SkullYellow then
		clip = "0 0 11 11"
	elseif skullId == SkullGreen then
		clip = "11 0 11 11"
	elseif skullId == SkullWhite then
		clip = "22 0 11 11"
	elseif skullId == SkullRed then
		clip = "33 0 11 11"
	elseif skullId == SkullBlack then
		clip = "44 0 11 11"
	elseif skullId == SkullOrange then
		clip = "55 0 11 11"
	else
		path = nil
	end

	return path, clip
end

function getShieldImagePath(shieldId)
	local path = "/images/game/creatures/creature-state-flags"
	local clip

	clip = shieldId == ShieldWhiteYellow and "11 0 11 11" or shieldId == ShieldWhiteBlue and "22 0 11 11" or shieldId == ShieldBlue and "33 0 11 11" or shieldId == ShieldYellow and "44 0 11 11" or shieldId == ShieldBlueSharedExp and "55 0 11 11" or shieldId == ShieldYellowSharedExp and "66 0 11 11" or (shieldId == ShieldBlueNoSharedExpBlink or shieldId == ShieldBlueNoSharedExp) and "77 0 11 11" or (shieldId == ShieldYellowNoSharedExpBlink or shieldId == ShieldYellowNoSharedExp) and "88 0 11 11" or shieldId == ShieldGray and "99 0 11 11" or "0 0 11 11"

	return path, clip
end

function getEmblemImagePath(emblemId)
	local path = "/images/game/creatures/creature-state-flags"
	local clip

	clip = emblemId == EmblemGreen and "11 22 11 11" or emblemId == EmblemRed and "22 22 11 11" or emblemId == EmblemBlue and "33 22 11 11" or emblemId == EmblemMember and "44 22 11 11" or emblemId == EmblemOther and "55 22 11 11" or "0 22 11 11"

	return path, clip
end

function getTypeImagePath(creatureType)
	local path = "/images/game/creatures/creature-state-flags"
	local clip

	clip = creatureType == CreatureTypeSummonOwn and "11 33 11 11" or creatureType == CreatureTypeSummonOther and "22 33 11 11" or "0 33 11 11"

	return path, clip
end

function getIconImagePath(iconId)
	local path = "/images/game/creatures/hud/flags/npc-categories"
	local clip

	if iconId == NpcIconChat then
		clip = "0 0 18 18"
	elseif iconId == NpcIconTrade then
		clip = "18 0 18 18"
	elseif iconId == NpcIconSail then
		clip = "36 0 18 18"
	elseif iconId == NpcIconHireling then
		clip = "54 0 18 18"
	else
		path = nil
	end

	return path, clip
end

function getIconsImagePath(category)
	if category == 1 then
		return "/images/game/creatures/hud/flags/modifications"
	end

	return "/images/game/creatures/hud/flags/quests"
end

function Creature:onIconsChange(icon, category, count, hideCount)
	local imagePath = getIconsImagePath(category)

	if imagePath then
		local clipX = (icon - 1) * 11

		self:setIconsTexture(imagePath, torect(clipX .. " 0 11 11"), count, hideCount == 1)
	end
end

function Creature:onSkullChange(skullId)
	local imagePath, clip = getSkullImagePath(skullId)

	self:setSkullTexture(imagePath, torect(clip))
end

function Creature:onShieldChange(shieldId)
	local imagePath, clip = getShieldImagePath(shieldId)

	self:setShieldTexture(imagePath, torect(clip))
end

function Creature:onManaPercentChange(manaPercent, oldManaPercent)
	return
end

function Creature:onShowStatusChange(showStatus)
	return
end

function Creature:onVocationChange(vocation, oldVocation)
	return
end

function Creature:onEmblemChange(emblemId)
	local imagePath, clip = getEmblemImagePath(emblemId)

	self:setEmblemTexture(imagePath, torect(clip))
end

function Creature:onTypeChange(typeId)
	local imagePath, clip = getTypeImagePath(typeId)

	self:setTypeTexture(imagePath, torect(clip))
end

function Creature:onIconChange(iconId)
	local imagePath, clip = getIconImagePath(iconId)

	if imagePath then
		self:setIconTexture(imagePath, torect(clip))
	end
end

function Creature:isHireling()
	return self:isNpc() and self:getIcon() == NpcIconHireling
end

function Creature:isDruid()
	local vocation = self:getVocation()

	return vocation == VocationsClient.Druid or vocation == VocationsClient.ElderDruid
end

function Creature:isSorcerer()
	local vocation = self:getVocation()

	return vocation == VocationsClient.Sorcerer or vocation == VocationsClient.MasterSorcerer
end

function Creature:isPaladin()
	local vocation = self:getVocation()

	return vocation == VocationsClient.Paladin or vocation == VocationsClient.RoyalPaladin
end

function Creature:isKnight()
	local vocation = self:getVocation()

	return vocation == VocationsClient.Knight or vocation == VocationsClient.EliteKnight
end

function Creature:isMonk()
	local vocation = self:getVocation()

	return vocation == VocationsClient.Monk or vocation == VocationsClient.ExaltedMonk
end
