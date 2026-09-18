-- chunkname: @/game_offlinetraining/game_offlinetraining.lua

offlineTrainingWindow = nil

local function setSkillValue(id, value)
	if not offlineTrainingWindow or offlineTrainingWindow:isDestroyed() then
		return
	end

	local skill = offlineTrainingWindow:recursiveGetChildById(id)

	if not skill then
		return
	end

	local widget = skill:getChildById("value")

	if widget then
		widget:setText(value)
	end
end

local function setSkillPercent(id, percent, tooltip, color)
	if not offlineTrainingWindow or offlineTrainingWindow:isDestroyed() then
		return
	end

	local skill = offlineTrainingWindow:recursiveGetChildById(id)

	if not skill then
		return
	end

	local widget = skill:getChildById("percent")

	if not widget then
		return
	end

	widget:setVisible(true)
	widget:setPercent(skillPercentForBar(percent))

	if tooltip then
		widget:setTooltip(tooltip)
	end

	if color then
		widget:setBackgroundColor(color)
	end
end

local function skillPercentForBar(rawPercent)
	return math.floor((rawPercent or 0) / 100)
end

local function skillPercentToGoFormatted(rawPercent)
	return string.format("%.2f", 100 - (rawPercent or 0) / 100)
end

local function skillPercentToGoTooltip(rawPercent)
	return tr("You have %s percent to go", skillPercentToGoFormatted(rawPercent))
end

local function buildLoyaltySkillTooltipLine(total, base, loyaltyField)
	loyaltyField = loyaltyField or 0

	local loyaltyBonus = 0
	local itemBonus = 0

	if base < loyaltyField then
		loyaltyBonus = loyaltyField - base
		itemBonus = total - loyaltyField
	elseif loyaltyField > 0 and loyaltyField <= total - base then
		loyaltyBonus = loyaltyField
		itemBonus = total - base - loyaltyBonus
	else
		itemBonus = total - base
	end

	if itemBonus < 0 then
		itemBonus = 0
	end

	if loyaltyBonus < 0 then
		loyaltyBonus = 0
	end

	local line = string.format("%d = %d", total, base)

	if itemBonus > 0 then
		line = line .. " +" .. itemBonus
	end

	if loyaltyBonus > 0 then
		line = line .. string.format(" (+%d Loyalty)", loyaltyBonus)
	end

	return line
end

local function setSkillBase(id, value, baseValue, loyaltyField)
	if not offlineTrainingWindow or offlineTrainingWindow:isDestroyed() then
		return
	end

	if baseValue <= 0 or value < 0 then
		return
	end

	local skill = offlineTrainingWindow:recursiveGetChildById(id)

	if not skill then
		return
	end

	local widget = skill:getChildById("value")

	if not widget then
		return
	end

	if baseValue < value then
		widget:setColor("#44ad25")
		skill:setTooltip(buildLoyaltySkillTooltipLine(value, baseValue, loyaltyField))
	elseif value < baseValue then
		widget:setColor("#ff9854")
		skill:setTooltip(baseValue .. " " .. value - baseValue)
	else
		widget:setColor("#c0c0c0")
		skill:removeTooltip()
	end
end

local function updateAllSkills()
	local player = g_game.getLocalPlayer()

	if not player or not offlineTrainingWindow or offlineTrainingWindow:isDestroyed() then
		return
	end

	setSkillValue("magiclevel", player:getMagicLevel())
	setSkillPercent("magiclevel", player:getMagicLevelPercent(), skillPercentToGoTooltip(player:getMagicLevelPercent()))
	setSkillBase("magiclevel", player:getMagicLevel(), player:getBaseMagicLevel(), player.getMagicLoyalty and player:getMagicLoyalty() or 0)

	for i = Skill.Fist, Skill.Distance do
		local widgetId = "skillId" .. i

		setSkillValue(widgetId, player:getSkillLevel(i))
		setSkillPercent(widgetId, player:getSkillLevelPercent(i), skillPercentToGoTooltip(player:getSkillLevelPercent(i)))
		setSkillBase(widgetId, player:getSkillLevel(i), player:getSkillBaseLevel(i), player.getSkillLoyalty and player:getSkillLoyalty(i) or 0)
	end
end

function init()
	g_ui.importStyle("/game_skills/skills_widgets")
	g_ui.importStyle("game_offlinetraining")
	connect(g_game, {
		onGameEnd = destroyDialog,
		onModalOfflineTraining = onModalOfflineTraining
	})

	modules.game_offlinetraining.hide = hide
	modules.game_offlinetraining.cancel = cancel
	modules.game_offlinetraining.sendOfflineTraining = sendOfflineTraining
end

function terminate()
	disconnect(g_game, {
		onGameEnd = destroyDialog,
		onModalOfflineTraining = onModalOfflineTraining
	})
	destroyDialog()
end

function destroyDialog()
	if offlineTrainingWindow and not offlineTrainingWindow:isDestroyed() then
		g_modalManager.hide(offlineTrainingWindow)
		offlineTrainingWindow:destroy()

		offlineTrainingWindow = nil
	end
end

function hide()
	if offlineTrainingWindow and not offlineTrainingWindow:isDestroyed() then
		g_modalManager.hide(offlineTrainingWindow)
		offlineTrainingWindow:hide()
	end
end

function cancel()
	destroyDialog()
	g_game.sendOfflineTraining(0)
end

local function bindWindowHandlers()
	if not offlineTrainingWindow or offlineTrainingWindow:isDestroyed() then
		return
	end

	offlineTrainingWindow.onEscape = cancel

	function offlineTrainingWindow.onKeyDown(_, keyCode, keyboardModifiers)
		if keyboardModifiers == KeyboardNoModifier and keyCode == KeyEscape then
			cancel()

			return true
		end

		return false
	end

	local closeButton = offlineTrainingWindow:recursiveGetChildById("closeButton")

	if closeButton then
		closeButton.onClick = cancel
	end
end

function onModalOfflineTraining()
	if offlineTrainingWindow and not offlineTrainingWindow:isDestroyed() then
		offlineTrainingWindow:show()
	else
		offlineTrainingWindow = g_ui.createWidget("OfflineTrainingWindow", rootWidget)
	end

	updateAllSkills()
	bindWindowHandlers()
	g_modalManager.show(offlineTrainingWindow)
end

function sendOfflineTraining(skillId)
	g_game.sendOfflineTraining(skillId)
	destroyDialog()
end
