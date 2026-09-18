-- chunkname: @/game_attachedeffects/attachedeffects.lua

local function onAttach(effect, owner)
	local category, thingId = AttachedEffectManager.getDataThing(owner)
	local config = AttachedEffectManager.getConfig(effect:getId(), category, thingId)

	if not config then
		return
	end

	if config.isThingConfig then
		AttachedEffectManager.executeThingConfig(effect, category, thingId)
	end

	if config.onAttach then
		config.onAttach(effect, owner, config.__onAttach)
	end
end

local function onDetach(effect, oldOwner)
	local category, thingId = AttachedEffectManager.getDataThing(oldOwner)
	local config = AttachedEffectManager.getConfig(effect:getId(), category, thingId)

	if not config then
		return
	end

	if config.onDetach then
		config.onDetach(effect, oldOwner, config.__onDetach)
	end
end

local function onOutfitChange(creature, outfit, oldOutfit)
	for _i, effect in pairs(creature:getAttachedEffects()) do
		AttachedEffectManager.executeThingConfig(effect, ThingCategoryCreature, outfit.type)
	end
end

controller = Controller:new()

function controller:onGameStart()
	controller:registerEvents(LocalPlayer, {
		onOutfitChange = onOutfitChange
	})
	controller:registerEvents(Creature, {
		onOutfitChange = onOutfitChange
	})
	controller:registerEvents(AttachedEffect, {
		onAttach = onAttach,
		onDetach = onDetach
	})
end

function controller:onGameEnd()
	return
end

function controller:onTerminate()
	g_attachedEffects.clear()
end

function getCategory(id)
	return AttachedEffectManager.get(id).thingCategory
end

function getTexture(id)
	if AttachedEffectManager.get(id).thingCategory == 5 then
		return AttachedEffectManager.get(id).thingId
	end
end

function getName(id)
	if type(id) == "number" then
		return AttachedEffectManager.get(id).name
	else
		return "None"
	end
end

function thingId(id)
	if type(id) == "number" then
		return AttachedEffectManager.get(id).thingId
	else
		return "None"
	end
end
