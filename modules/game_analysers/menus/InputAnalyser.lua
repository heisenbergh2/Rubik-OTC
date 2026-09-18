-- chunkname: @/game_analysers/menus/InputAnalyser.lua

if not InputAnalyser then
	InputAnalyser = {
		monsterName = "",
		maxDPS = 0,
		total = 0,
		session = 0,
		launchTime = 0,
		sourceVisible = true,
		typesVisible = true,
		graphVisible = true,
		inputValues = {},
		damageTicks = {},
		damageEffect = {}
	}
	InputAnalyser.__index = InputAnalyser
end

local imageDir = "/modules/game_cyclopedia/images/bestiary/icons/monster-icon-%s-resist"
local effectsFiles = {
	[0] = "physical",
	"fire",
	"earth",
	"energy",
	"ice",
	"holy",
	"death",
	"healing",
	"drowning",
	"lifedrain",
	"manadrain",
	"agony",
	"agony"
}

local function applyDamageTypesAnchors(contentsPanel)
	if not contentsPanel.damageTypeLabel:isVisible() then
		return
	end

	local hasEffects = next(InputAnalyser.damageEffect) ~= nil

	contentsPanel.noDataLabel1:setVisible(not hasEffects)
	contentsPanel.dmgTypes:setVisible(hasEffects)
	contentsPanel.noDataLabel1:removeAnchor(AnchorTop)
	contentsPanel.noDataLabel1:addAnchor(AnchorTop, "damageTypeLabel", AnchorBottom)
	contentsPanel.noDataLabel1:setMarginTop(4)
	contentsPanel.dmgTypes:removeAnchor(AnchorTop)

	if hasEffects then
		contentsPanel.dmgTypes:addAnchor(AnchorTop, "damageTypeLabel", AnchorBottom)
		contentsPanel.dmgTypes:setMarginTop(5)
	else
		contentsPanel.dmgTypes:addAnchor(AnchorTop, "noDataLabel1", AnchorBottom)
		contentsPanel.dmgTypes:setMarginTop(0)
	end

	contentsPanel.separatorDmgType:removeAnchor(AnchorTop)

	if hasEffects then
		contentsPanel.separatorDmgType:addAnchor(AnchorTop, "dmgTypes", AnchorBottom)
	else
		contentsPanel.separatorDmgType:addAnchor(AnchorTop, "noDataLabel1", AnchorBottom)
	end

	contentsPanel.separatorDmgType:setMarginTop(7)
end

local function syncDamageSourcesEmptyState(contentsPanel)
	if not contentsPanel.damageSource:isVisible() then
		contentsPanel.noDataLabel2:setVisible(false)

		return
	end

	local emptyGlobal = table.empty(InputAnalyser.inputValues)

	contentsPanel.noDataLabel2:setVisible(emptyGlobal)
	contentsPanel.dmgSrc:setVisible(not emptyGlobal)
end

local function valueInSeconds(t)
	local d = 0
	local time = 0
	local now = g_clock.millis()

	if #t > 0 then
		local itemsToBeRemoved = 0

		for i, v in ipairs(t) do
			if now - v.tick <= 3000 then
				if time == 0 then
					time = v.tick
				end

				d = d + v.amount
			else
				itemsToBeRemoved = itemsToBeRemoved + 1
			end
		end

		for i = 1, itemsToBeRemoved do
			table.remove(t, 1)
		end
	end

	return math.ceil(d / ((now - time) / 1000))
end

function InputAnalyser:create()
	InputAnalyser.window = openedWindows.damageButton
	InputAnalyser.launchTime = g_clock.millis()
	InputAnalyser.session = 0
	InputAnalyser.total = 0
	InputAnalyser.maxDPS = 0
	InputAnalyser.monsterName = ""
	InputAnalyser.inputValues = {}
	InputAnalyser.damageEffect = {}
	InputAnalyser.damageTicks = {}
end

function InputAnalyser:reset()
	InputAnalyser.launchTime = g_clock.millis()
	InputAnalyser.session = 0
	InputAnalyser.total = 0
	InputAnalyser.maxDPS = 0
	InputAnalyser.monsterName = ""
	InputAnalyser.inputValues = {}
	InputAnalyser.damageEffect = {}
	InputAnalyser.damageTicks = {}

	analyserUIGraphReset(InputAnalyser.window.contentsPanel.graphPanel, nil, ANALYSER_GRAPH_CAPACITY_4_MIN)
	InputAnalyser:toggleDamageSource(false)

	local contentsPanel = InputAnalyser.window.contentsPanel

	contentsPanel.dmgTypes:destroyChildren()
	contentsPanel.dmgSrc:destroyChildren()
	InputAnalyser:updateWindow(true)
end

function InputAnalyser:updateWindow(ignoreVisible)
	if not InputAnalyser.window then
		return
	end

	if not InputAnalyser.window:isVisible() and not ignoreVisible then
		return
	end

	InputAnalyser:checkAnchos()

	local contentsPanel = InputAnalyser.window.contentsPanel
	local dps = tonumber(InputAnalyser.maxDPS) or 1

	contentsPanel.rcvDmg:setText(formatMoney(InputAnalyser.total, ","))
	contentsPanel.maxDps:setText(formatMoney(dps, ","))

	local count = 1
	local widgets = {}

	for effect, damage in pairs(InputAnalyser.damageEffect) do
		local widget = contentsPanel.dmgTypes:recursiveGetChildById(tostring(effect))

		widget = widget or g_ui.createWidget("DamagePanel", contentsPanel.dmgTypes)

		local percent = damage * 100 / InputAnalyser.total

		widget:setId(effect)
		widget.icon:setImageSource(string.format(imageDir, effectsFiles[effect]))
		widget.icon:setTooltip(getCombatName(effect))
		widget.desc:setText(formatMoney(damage, ",") .. " (" .. string.format("%.1f", percent) .. "%)")

		count = count + 1

		table.insert(widgets, {
			widget = widget,
			percent = percent
		})
	end

	table.sort(widgets, function(a, b)
		return a.percent > b.percent
	end)

	for index, item in ipairs(widgets) do
		contentsPanel.dmgTypes:moveChildToIndex(item.widget, index)
	end

	if next(InputAnalyser.damageEffect) ~= nil then
		contentsPanel.dmgTypes:setHeight(15 * count)
	else
		contentsPanel.dmgTypes:setHeight(1)
	end

	if count > 1 then
		local noData = contentsPanel.dmgTypes:recursiveGetChildById("nodata")

		if noData then
			noData:destroy()
		end
	end

	applyDamageTypesAnchors(contentsPanel)

	count = 1
	widgets = {}

	for monsterName, damageInfo in pairs(InputAnalyser.inputValues) do
		local damageMonster = 0

		for effect, damage in pairs(damageInfo) do
			damageMonster = damageMonster + damage
		end

		local widget = contentsPanel.dmgSrc:recursiveGetChildById(monsterName)

		widget = widget or g_ui.createWidget("DamageSourcePanel", contentsPanel.dmgSrc)
		count = count + 1

		widget:setId(monsterName)
		widget.name:setText(short_text(string.capitalize(monsterName), 17))
		widget:setTooltip(string.capitalize(monsterName))

		local percent = damageMonster * 100 / InputAnalyser.total

		widget.desc:setText(string.format("%.1f", percent) .. "%")

		function widget.onClick()
			if InputAnalyser.monsterName == monsterName then
				InputAnalyser.monsterName = ""

				InputAnalyser:toggleDamageSource(false)
			else
				InputAnalyser.monsterName = monsterName

				InputAnalyser:toggleDamageSource(true)
			end
		end

		table.insert(widgets, {
			widget = widget,
			percent = percent
		})
	end

	table.sort(widgets, function(a, b)
		return a.percent > b.percent
	end)

	for index, item in ipairs(widgets) do
		contentsPanel.dmgSrc:moveChildToIndex(item.widget, index)
	end

	if next(InputAnalyser.inputValues) == nil then
		contentsPanel.dmgSrc:setHeight(1)
	else
		contentsPanel.dmgSrc:setHeight(15 + 10 * count)
	end

	if count > 1 then
		local noData = contentsPanel.dmgSrc:recursiveGetChildById("nodata")

		if noData then
			noData:destroy()
		end
	end

	contentsPanel.dmgSourceTypes:destroyChildren()

	if InputAnalyser.inputValues[InputAnalyser.monsterName] then
		local count = 1

		for effect, damage in pairs(InputAnalyser.inputValues[InputAnalyser.monsterName]) do
			local widget = g_ui.createWidget("DamagePanel", contentsPanel.dmgSourceTypes)

			count = count + 1

			widget.icon:setImageSource(string.format(imageDir, effectsFiles[effect]))
			widget.icon:setTooltip(getCombatName(effect))

			local percent = damage * 100 / InputAnalyser.total

			widget.desc:setText(formatMoney(damage, ",") .. " (" .. string.format("%.1f", percent) .. "%)")
		end

		contentsPanel.dmgSourceTypes:setHeight(15 * count)
	elseif table.empty(InputAnalyser.inputValues) then
		contentsPanel.dmgSourceTypes:setHeight(1)
	end

	syncDamageSourcesEmptyState(contentsPanel)
	InputAnalyser:checkAnchos()
end

function InputAnalyser:checkDPS()
	local curDPS = valueInSeconds(InputAnalyser.damageTicks)

	if not curDPS or not tonumber(curDPS) then
		curDPS = 0
	end

	InputAnalyser.curDPS = curDPS

	local lastDps = tonumber(InputAnalyser.maxDPS) or 1

	InputAnalyser.maxDPS = curDPS < InputAnalyser.maxDPS and InputAnalyser.maxDPS or curDPS

	if not tonumber(InputAnalyser.maxDPS) then
		InputAnalyser.maxDPS = lastDps
	end

	InputAnalyser.window.contentsPanel.maxDps:setText(formatMoney(InputAnalyser.maxDPS, ","))
	analyserUIGraphPushValue(InputAnalyser.window.contentsPanel.graphPanel, InputAnalyser.curDPS)
end

function InputAnalyser:addInputDamage(amount, effect, target)
	if not InputAnalyser.inputValues[target] then
		InputAnalyser.inputValues[target] = {}
	end

	if not InputAnalyser.inputValues[target][effect] then
		InputAnalyser.inputValues[target][effect] = 0
	end

	InputAnalyser.inputValues[target][effect] = InputAnalyser.inputValues[target][effect] + amount
	InputAnalyser.total = InputAnalyser.total + amount
	InputAnalyser.damageTicks[#InputAnalyser.damageTicks + 1] = {
		amount = amount,
		tick = g_clock.millis()
	}

	if not InputAnalyser.damageEffect[effect] then
		InputAnalyser.damageEffect[effect] = 0
	end

	InputAnalyser.damageEffect[effect] = InputAnalyser.damageEffect[effect] + amount
end

function InputAnalyser:toggleDamageSource(bool)
	local cp = InputAnalyser.window.contentsPanel

	cp.dmgSourceTypes:setVisible(bool)
	cp.damageSourceName:setText(string.capitalize(InputAnalyser.monsterName))
	cp.dmgSourceTypes:destroyChildren()

	if InputAnalyser.inputValues[InputAnalyser.monsterName] then
		local count = 1

		for effect, damage in pairs(InputAnalyser.inputValues[InputAnalyser.monsterName]) do
			local widget = g_ui.createWidget("DamagePanel", cp.dmgSourceTypes)

			count = count + 1

			widget.icon:setImageSource(string.format(imageDir, effectsFiles[effect]))
			widget.icon:setTooltip(getCombatName(effect))

			local percent = damage * 100 / InputAnalyser.total

			widget.desc:setText(formatMoney(damage, ",") .. " (" .. string.format("%.1f", percent) .. "%)")
		end

		cp.dmgSourceTypes:setHeight(15 * count)
	elseif table.empty(InputAnalyser.inputValues) then
		cp.dmgSourceTypes:setHeight(1)
	end

	syncDamageSourcesEmptyState(cp)
end

function onInputExtra(mousePosition)
	if cancelNextRelease then
		cancelNextRelease = false

		return false
	end

	local graphVisible = InputAnalyser.window.contentsPanel.graphPanel:isVisible()
	local typesVisible = InputAnalyser.window.contentsPanel.damageTypeLabel:isVisible()
	local sourceVisible = InputAnalyser.window.contentsPanel.damageSource:isVisible()
	local menu = g_ui.createWidget("PopupMenu")

	menu:setGameMenu(true)
	menu:addOption(tr("Reset Data"), function()
		InputAnalyser:reset()
	end)
	menu:addSeparator()
	menu:addCheckBoxOption(tr("Show Damage Graph"), function()
		InputAnalyser:setDamageGraph(not graphVisible, true)
	end, "", graphVisible)
	menu:addCheckBoxOption(tr("Show Damage Types"), function()
		InputAnalyser:setDamageTypes(not typesVisible, true)
	end, "", typesVisible)
	menu:addCheckBoxOption(tr("Show Damage Sources"), function()
		InputAnalyser:setDamageSource(not sourceVisible, true)
	end, "", sourceVisible)
	menu:addSeparator()
	menu:addOption(tr("Copy to Clipboard"), function()
		InputAnalyser:clipboardData()
	end)
	menu:display(mousePosition)

	return true
end

function InputAnalyser:checkAnchos()
	if InputAnalyser.window.contentsPanel.graphPanel:isVisible() then
		InputAnalyser.window.contentsPanel.damageTypeLabel:addAnchor(AnchorTop, "separatorGraph", AnchorBottom)
	else
		InputAnalyser.window.contentsPanel.damageTypeLabel:addAnchor(AnchorTop, "separatorMaxDps", AnchorBottom)
	end

	if InputAnalyser.window.contentsPanel.damageTypeLabel:isVisible() then
		InputAnalyser.window.contentsPanel.damageSource:addAnchor(AnchorTop, "separatorDmgType", AnchorBottom)
	elseif InputAnalyser.window.contentsPanel.graphPanel:isVisible() then
		InputAnalyser.window.contentsPanel.damageSource:addAnchor(AnchorTop, "separatorGraph", AnchorBottom)
	else
		InputAnalyser.window.contentsPanel.damageSource:addAnchor(AnchorTop, "separatorMaxDps", AnchorBottom)
	end
end

function InputAnalyser:setDamageGraph(value, check)
	InputAnalyser.window.contentsPanel.graphPanel:setVisible(value)
	InputAnalyser.window.contentsPanel.horizontalGraph:setVisible(value)
	InputAnalyser.window.contentsPanel.separatorGraph:setVisible(value)

	InputAnalyser.graphVisible = value

	if check then
		InputAnalyser:checkAnchos()
	end
end

function InputAnalyser:setDamageTypes(value, check)
	InputAnalyser.typesVisible = value

	InputAnalyser.window.contentsPanel.damageTypeLabel:setVisible(value)
	InputAnalyser.window.contentsPanel.separatorDmgType:setVisible(value)

	if value then
		InputAnalyser:updateWindow(true)
	else
		InputAnalyser.window.contentsPanel.noDataLabel1:setVisible(false)
		InputAnalyser.window.contentsPanel.dmgTypes:setVisible(false)
	end

	if check then
		InputAnalyser:checkAnchos()
	end
end

function InputAnalyser:setDamageSource(value, check)
	local cp = InputAnalyser.window.contentsPanel

	cp.damageSource:setVisible(value)

	InputAnalyser.sourceVisible = value

	if not value then
		cp.dmgSrc:setVisible(false)
		cp.noDataLabel2:setVisible(false)
	end

	InputAnalyser:toggleDamageSource(value)

	if value then
		syncDamageSourcesEmptyState(cp)
	end

	if check then
		InputAnalyser:checkAnchos()
	end
end

function InputAnalyser:clipboardData()
	local text = "Received Damage"

	text = text .. "\nTotal: " .. formatMoney(InputAnalyser.total, ",")
	text = text .. "\nMax-DPS: " .. formatMoney(InputAnalyser.maxDPS, ",")
	text = text .. "\nDamage Types"

	if table.empty(InputAnalyser.inputValues) then
		text = text .. "\n\tNo Data"
	else
		local count = 1

		for effect, damage in pairs(InputAnalyser.damageEffect) do
			local percent = damage * 100 / InputAnalyser.total

			text = text .. "\n\t" .. getCombatName(effect) .. " " .. formatMoney(damage, ",") .. " (" .. string.format("%.1f", percent) .. "%)"
		end
	end

	text = text .. "\nDamage Sources"

	if table.empty(InputAnalyser.inputValues) then
		text = text .. "\n\tNo Data"
	else
		for monsterName, damageInfo in pairs(InputAnalyser.inputValues) do
			local damageMonster = 0

			for effect, damage in pairs(damageInfo) do
				damageMonster = damageMonster + damage
			end

			local percent = damageMonster * 100 / InputAnalyser.total

			text = text .. "\n\t" .. string.capitalize(monsterName) .. " " .. formatMoney(damageMonster, ",") .. " (" .. string.format("%.1f", percent) .. "%)"
		end
	end

	if InputAnalyser.inputValues[InputAnalyser.monsterName] then
		text = text .. "\n" .. string.capitalize(InputAnalyser.monsterName)

		for effect, damage in pairs(InputAnalyser.inputValues[InputAnalyser.monsterName]) do
			local percent = damage * 100 / InputAnalyser.total

			text = text .. "\n\t" .. getCombatName(effect) .. " " .. formatMoney(damage, ",") .. " (" .. string.format("%.1f", percent) .. "%)"
		end
	end

	g_window.setClipboardText(text)
end

function InputAnalyser:damageGraphIsVisible()
	return InputAnalyser.graphVisible
end

function InputAnalyser:damageTypesIsVisible()
	return InputAnalyser.typesVisible
end

function InputAnalyser:damageSourceIsVisible()
	return InputAnalyser.sourceVisible
end

function InputAnalyser:loadConfigJson()
	local config = {
		showDamageTypes = true,
		showDamageSources = true,
		showDamageGraph = true,
		showSessionValues = false
	}
	local player = g_game.getLocalPlayer()

	if not player then
		return
	end

	local file = "/characterdata/" .. player:getId() .. "/damageinputanalyser.json"

	if g_resources.fileExists(file) then
		local status, result = pcall(function()
			return json.decode(g_resources.readFileContents(file))
		end)

		if not status then
			return g_logger.error("Error while reading characterdata file. Details: " .. result)
		end

		config = result
	end

	InputAnalyser:setDamageGraph(config.showDamageGraph, false)
	InputAnalyser:setDamageSource(config.showDamageSources, false)
	InputAnalyser:setDamageTypes(config.showDamageTypes, false)
	InputAnalyser:checkAnchos()
end

function InputAnalyser:saveConfigJson()
	if not LoadedPlayer:isLoaded() then
		return
	end

	local config = {
		showSessionValues = false,
		showDamageGraph = InputAnalyser:damageGraphIsVisible(),
		showDamageSources = InputAnalyser:damageSourceIsVisible(),
		showDamageTypes = InputAnalyser:damageTypesIsVisible()
	}
	local file = "/characterdata/" .. LoadedPlayer:getId() .. "/damageinputanalyser.json"
	local status, result = pcall(function()
		return json.encode(config, 2)
	end)

	if not status then
		return g_logger.error("Error while saving profile itemsData. Data won't be saved. Details: " .. result)
	end

	if result:len() > 104857600 then
		return g_logger.error("Something went wrong, file is above 100MB, won't be saved")
	end

	g_resources.writeFileContents(file, result)
end
