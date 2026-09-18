-- chunkname: @/game_cooldown/cooldown.lua

local ProgressCallback = {
	finish = 2,
	update = 1
}

cooldownWindow = nil
contentsPanel = nil
cooldownPanel = nil
lastPlayer = nil
cooldown = {}
groupCooldown = {}

local SPELL_ICON_FILE = "/images/game/spells/spell-icons-20x20"
local SPELL_ICON_SIZE = 20

local function getSpellIconClip(clientIconId)
	if not clientIconId or clientIconId < 1 then
		return nil
	end

	local size = SPELL_ICON_SIZE

	return (clientIconId - 1) * size .. " 0 " .. size .. " " .. size
end

local function cancelCooldownEvent(progressRect)
	if not progressRect then
		return
	end

	if progressRect.event then
		removeEvent(progressRect.event)

		progressRect.event = nil
	end

	progressRect.callback = nil
	progressRect.cooldownEndTime = nil
	progressRect.cooldownDuration = nil
end

local function releaseProgressRect(progressRect)
	if not progressRect or progressRect:isDestroyed() then
		return
	end

	cancelCooldownEvent(progressRect)

	progressRect.icon = nil
end

local function isCooldownActive(progressRect)
	if not progressRect or progressRect:isDestroyed() then
		return false
	end

	local callback = progressRect.callback

	return callback ~= nil and callback[ProgressCallback.update] ~= nil
end

local function resetCooldownFillBar(progressRect)
	if not progressRect or progressRect:isDestroyed() then
		return
	end

	local bar = progressRect:getChildById("cooldownFillBar")

	if not bar then
		return
	end

	bar:setWidth(0)
	bar:setVisible(false)
end

local function setGroupIconOverlay(icon, visible)
	if not icon or icon:isDestroyed() then
		return
	end

	icon:setOn(not visible)

	local overlay = icon:getChildById("disabledOverlay")

	if overlay then
		overlay:setVisible(visible)
	end
end

local function getSpellCooldownEndTime(icon)
	if not icon or icon:isDestroyed() then
		return math.huge
	end

	local progressRect = icon:getChildById(icon:getId())

	if progressRect and progressRect.cooldownEndTime then
		return progressRect.cooldownEndTime
	end

	return math.huge
end

local function sortSpellCooldownIcons()
	if not cooldownPanel or cooldownPanel:isDestroyed() then
		return
	end

	local children = cooldownPanel:getChildren()

	if not children or #children <= 1 then
		return
	end

	local icons = {}

	for i = 1, #children do
		icons[i] = children[i]
	end

	table.sort(icons, function(a, b)
		local endA = getSpellCooldownEndTime(a)
		local endB = getSpellCooldownEndTime(b)

		if endA ~= endB then
			return endA < endB
		end

		return tostring(a:getId()) < tostring(b:getId())
	end)
	cooldownPanel:reorderChildren(icons)
end

function init()
	connect(g_game, {
		onGameEnd = offline,
		onGameStart = online,
		onSpellGroupCooldown = onSpellGroupCooldown,
		onSpellCooldown = onSpellCooldown
	})

	if modules.client_options.getOption("showSpellGroupCooldowns") then
		modules.client_options.setOption("showSpellGroupCooldowns", true)
	else
		modules.client_options.setOption("showSpellGroupCooldowns", false)
	end

	cooldownWindow = g_ui.loadUI("cooldown", modules.game_interface.getBottomPanel())
	contentsPanel = cooldownWindow:getChildById("contentsPanel2")
	cooldownPanel = contentsPanel:getChildById("cooldownPanel")

	for k, v in pairs(SpelllistSettings) do
		g_textures.preload(v.iconFile)
	end

	g_textures.preload(SpellGroupIconFile)
	g_textures.preload("/images/game/spells/slot-mini-spellicon")
	g_textures.preload(SPELL_ICON_FILE)

	if g_game.isOnline() then
		online()
	end
end

function terminate()
	disconnect(g_game, {
		onGameEnd = offline,
		onGameStart = online,
		onSpellGroupCooldown = onSpellGroupCooldown,
		onSpellCooldown = onSpellCooldown
	})

	if cooldownPanel then
		for _, icon in ipairs(cooldownPanel:getChildren()) do
			for _, child in ipairs(icon:getChildren()) do
				releaseProgressRect(child)
			end
		end
	end

	cooldownWindow:destroy()

	cooldownWindow = nil
	contentsPanel = nil
	cooldownPanel = nil
end

function loadIcon(iconId)
	local spell, profile, spellName = Spells.getSpellByIcon(iconId)

	if not spellName then
		print("[WARNING] loadIcon: empty spellName for tfs spell id: " .. iconId)

		return
	end

	if not profile then
		print("[WARNING] loadIcon: empty profile for tfs spell id: " .. iconId)

		return
	end

	local clientIconId = Spells.getClientId(spellName)

	if not clientIconId then
		print("[WARNING] loadIcon: empty clientIconId for tfs spell id: " .. iconId)

		return
	end

	local icon = cooldownPanel:getChildById(iconId)

	if not icon then
		icon = g_ui.createWidget("SpellIcon")

		icon:setId(iconId)
	end

	local iconImage = icon:getChildById("icon")
	local clip = getSpellIconClip(clientIconId)

	if iconImage and clip then
		iconImage:setImageSource(SPELL_ICON_FILE)
		iconImage:setImageClip(clip)
	else
		print("[WARNING] loadIcon: empty spell icon for tfs spell id: " .. iconId)

		icon = nil
	end

	return icon
end

function onMiniWindowOpen()
	modules.client_options.setOption("showSpellGroupCooldowns", true)
end

function onMiniWindowClose()
	modules.client_options.setOption("showSpellGroupCooldowns", false)
end

function refreshConsoleAnchor()
	local console = modules.game_console and modules.game_console.consolePanel

	if not console or not cooldownWindow or cooldownWindow:isDestroyed() then
		return
	end

	console:removeAnchor(AnchorTop)
	console:addAnchor(AnchorTop, cooldownWindow:getId(), AnchorBottom)
end

function online()
	refreshConsoleAnchor()

	if not g_game.getFeature(GameSpellList) then
		modules.client_options.setOption("showSpellGroupCooldowns", false)

		return
	end

	if not lastPlayer or lastPlayer ~= g_game.getCharacterName() then
		refresh()

		lastPlayer = g_game.getCharacterName()
	end
end

function offline()
	local console = modules.game_console.consolePanel

	if console then
		console:removeAnchor(AnchorTop)
		console:fill("parent")
	end

	if contentsPanel then
		for _, child in ipairs(contentsPanel:getChildren()) do
			local id = child:getId()

			if id and id:sub(1, 12) == "progressRect" then
				cancelCooldownEvent(child)
				child:setPercent(100)
				resetCooldownFillBar(child)
			elseif id and id:sub(1, 9) == "groupIcon" then
				setGroupIconOverlay(child, true)
			end
		end
	end

	if cooldownPanel then
		for _, icon in ipairs(cooldownPanel:getChildren()) do
			for _, child in ipairs(icon:getChildren()) do
				releaseProgressRect(child)
			end
		end
	end

	cooldown = {}
	groupCooldown = {}
end

function refresh()
	if cooldownPanel then
		for _, icon in ipairs(cooldownPanel:getChildren()) do
			for _, child in ipairs(icon:getChildren()) do
				releaseProgressRect(child)
			end
		end

		cooldownPanel:destroyChildren()
	end

	cooldown = {}
end

function removeCooldown(progressRect)
	if not progressRect or progressRect:isDestroyed() then
		return
	end

	local icon = progressRect.icon

	releaseProgressRect(progressRect)

	if icon and not icon:isDestroyed() then
		icon:destroy()
	end
end

function turnOffCooldown(progressRect)
	if not progressRect or progressRect:isDestroyed() then
		return
	end

	cancelCooldownEvent(progressRect)
	progressRect:setPercent(100)
	resetCooldownFillBar(progressRect)

	if progressRect.icon then
		setGroupIconOverlay(progressRect.icon, true)

		progressRect.icon = nil
	end
end

function initCooldown(progressRect, updateCallback, finishCallback, duration)
	progressRect:setPercent(0)

	if duration and duration > 0 then
		progressRect.cooldownEndTime = g_clock.millis() + duration
		progressRect.cooldownDuration = duration
	else
		progressRect.cooldownEndTime = nil
		progressRect.cooldownDuration = nil
	end

	updateCooldownBar(progressRect)

	progressRect.callback = {}
	progressRect.callback[ProgressCallback.update] = updateCallback
	progressRect.callback[ProgressCallback.finish] = finishCallback

	updateCallback()
end

function updateCooldownBar(progressRect)
	local bar = progressRect:getChildById("cooldownFillBar")

	if not bar then
		return
	end

	local percent = progressRect:getPercent()
	local remainingPercent = 100 - percent

	if remainingPercent <= 0.01 then
		resetCooldownFillBar(progressRect)

		return
	end

	local width = math.max(progressRect:getWidth() - 2, 0)
	local barWidth = math.floor(width * remainingPercent / 100 + 0.0001)

	barWidth = math.max(0, math.min(width, barWidth))

	if barWidth <= 0 then
		resetCooldownFillBar(progressRect)

		return
	end

	bar:setWidth(barWidth)
	bar:setVisible(true)
end

function updateCooldown(progressRect, duration)
	if not isCooldownActive(progressRect) then
		return
	end

	local endTime = progressRect.cooldownEndTime
	local totalDuration = progressRect.cooldownDuration or duration

	if endTime and totalDuration and totalDuration > 0 then
		local remaining = endTime - g_clock.millis()

		if remaining <= 0 then
			progressRect:setPercent(100)
			updateCooldownBar(progressRect)

			local finishCallback = progressRect.callback[ProgressCallback.finish]

			cancelCooldownEvent(progressRect)

			if finishCallback then
				finishCallback()
			end

			return
		end

		local elapsed = totalDuration - remaining
		local percent = elapsed * 100 / totalDuration

		if elapsed <= 0 then
			percent = 0
		end

		progressRect:setPercent(math.min(100, math.max(0, percent)))
	else
		progressRect:setPercent(progressRect:getPercent() + 10000 / duration)
	end

	updateCooldownBar(progressRect)

	if progressRect:getPercent() < 99.99 then
		removeEvent(progressRect.event)

		progressRect.event = scheduleEvent(function()
			if progressRect:isDestroyed() or not isCooldownActive(progressRect) then
				return
			end

			progressRect.callback[ProgressCallback.update]()
		end, 100)
	else
		progressRect:setPercent(100)
		updateCooldownBar(progressRect)

		local finishCallback = progressRect.callback[ProgressCallback.finish]

		cancelCooldownEvent(progressRect)

		if finishCallback then
			finishCallback()
		end
	end
end

function isGroupCooldownIconActive(groupId)
	return groupCooldown[groupId]
end

function isCooldownIconActive(iconId)
	return cooldown[iconId]
end

function onSpellCooldown(iconId, duration)
	if not cooldownWindow:isVisible() then
		return
	end

	local icon = loadIcon(iconId)

	if not icon then
		print("[WARNING] Can not load cooldown icon on spell with id: " .. iconId)

		return
	end

	icon:setParent(cooldownPanel)

	local progressRect = icon:getChildById(iconId)

	if not progressRect then
		progressRect = g_ui.createWidget("SpellProgressRect", icon)

		progressRect:setId(iconId)

		progressRect.icon = icon

		progressRect:fill("parent")
	else
		cancelCooldownEvent(progressRect)
		progressRect:setPercent(0)
	end

	local function updateFunc()
		local rect = icon:getChildById(iconId)

		if rect and not rect:isDestroyed() then
			updateCooldown(rect, duration)
		end
	end

	local function finishFunc()
		local rect = icon:getChildById(iconId)

		if rect and not rect:isDestroyed() then
			removeCooldown(rect)
		elseif icon and not icon:isDestroyed() then
			icon:destroy()
		end

		cooldown[iconId] = false
	end

	initCooldown(progressRect, updateFunc, finishFunc, duration)
	setGroupIconOverlay(icon, false)

	cooldown[iconId] = true

	sortSpellCooldownIcons()
end

function onSpellGroupCooldown(groupId, duration)
	if not cooldownWindow:isVisible() then
		return
	end

	if not SpellGroups[groupId] then
		return
	end

	local icon = contentsPanel:getChildById("groupIcon" .. SpellGroups[groupId])
	local progressRect = contentsPanel:getChildById("progressRect" .. SpellGroups[groupId])

	if icon then
		removeEvent(icon.event)
	end

	if progressRect then
		progressRect.icon = icon

		cancelCooldownEvent(progressRect)

		local function updateFunc()
			updateCooldown(progressRect, duration)
		end

		local function finishFunc()
			turnOffCooldown(progressRect)

			groupCooldown[groupId] = false
		end

		initCooldown(progressRect, updateFunc, finishFunc, duration)

		if icon then
			setGroupIconOverlay(icon, false)
		end

		groupCooldown[groupId] = true
	end
end

function setSpellGroupCooldownsVisible(visible)
	if visible then
		cooldownWindow:setHeight(26)
		cooldownWindow:show()
	else
		cooldownWindow:hide()
		cooldownWindow:setHeight(0)
	end

	if modules.game_actionbar and modules.game_actionbar.refreshBottomCooldownDock then
		modules.game_actionbar.refreshBottomCooldownDock()
	end

	refreshConsoleAnchor()

	if modules.game_interface and modules.game_interface.applyBottomSplitterLayoutHeight then
		modules.game_interface.applyBottomSplitterLayoutHeight()
	end
end
