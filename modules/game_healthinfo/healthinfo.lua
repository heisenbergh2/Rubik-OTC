-- chunkname: @/game_healthinfo/healthinfo.lua

local iconTopMenu
local SIDEBAR_HEIGHT_DELTA = 28
local sidebarHidden = false
local healthManaUpdateEvent

local function healthManaEvent()
	local player = g_game.getLocalPlayer()

	if not player then
		return
	end

	healthManaController.ui.health.text:setText(player:getHealth())
	healthManaController.ui.health.current:setWidth(math.max(0, math.ceil(healthManaController.ui.health.total:getWidth() * player:getHealth() / player:getMaxHealth())))
	healthManaController.ui.mana.text:setText(player:getMana())
	healthManaController.ui.mana.current:setWidth(math.max(0, math.ceil(healthManaController.ui.mana.total:getWidth() * player:getMana() / player:getMaxMana())))
end

local function scheduleHealthManaEvent()
	if healthManaUpdateEvent then
		return
	end

	healthManaUpdateEvent = addEvent(function()
		healthManaUpdateEvent = nil

		healthManaEvent()
	end)
end

healthManaController = Controller:new()

healthManaController:setUI("healthinfo", modules.game_interface.getMainRightPanel())

local function openSidebarStatusBarsOptionsMenu(mousePos)
	if not modules.client_options or not modules.client_options.getOption or not modules.client_options.setOption then
		return
	end

	local menu = g_ui.createWidget("PopupMenu")

	menu:setGameMenu(true)

	local customOn = modules.client_options.getOption("showCustomisableStatusBars")

	menu:addCheckBox(tr("Show Customisable Status Bars"), customOn, function(_, checked)
		modules.client_options.setOption("showCustomisableStatusBars", checked, true)
	end)

	local statusOn = modules.client_options.getOption("showStatusBars")

	menu:addCheckBox(tr("Show Status Bars"), statusOn, function(_, checked)
		modules.client_options.setOption("showStatusBars", checked, true)
	end)
	menu:setWidth(271)
	menu:display(mousePos)
end

local function onHealthManaPanelMousePress(_, mousePos, mouseButton)
	if mouseButton == MouseRightButton then
		openSidebarStatusBarsOptionsMenu(mousePos)

		return true
	end
end

local function bindSidebarStatusBarsMenuRecursive(widget)
	if not widget or widget:isDestroyed() then
		return
	end

	widget.onMousePress = onHealthManaPanelMousePress

	for _, child in pairs(widget:getChildren()) do
		bindSidebarStatusBarsMenuRecursive(child)
	end
end

function healthManaController:onInit()
	local panel = self.ui

	if not panel or panel:isDestroyed() then
		return
	end

	bindSidebarStatusBarsMenuRecursive(panel)
end

function healthManaController:onTerminate()
	if healthManaUpdateEvent then
		removeEvent(healthManaUpdateEvent)

		healthManaUpdateEvent = nil
	end

	if iconTopMenu then
		iconTopMenu:destroy()

		iconTopMenu = nil
	end
end

function healthManaController:onGameStart()
	healthManaController:registerEvents(LocalPlayer, {
		onHealthChange = scheduleHealthManaEvent,
		onManaChange = scheduleHealthManaEvent
	}):execute()
end

function extendedView(extendedView)
	if extendedView then
		if not iconTopMenu then
			iconTopMenu = modules.client_topmenu.addTopRightToggleButton("healthMana", tr("Show health"), "/images/topbuttons/healthinfo", toggle)

			iconTopMenu:setOn(healthManaController.ui:isVisible())
			healthManaController.ui:setBorderColor("black")
			healthManaController.ui:setBorderWidth(2)
		end
	else
		if iconTopMenu then
			iconTopMenu:destroy()

			iconTopMenu = nil
		end

		healthManaController.ui:setBorderColor("alpha")
		healthManaController.ui:setBorderWidth(0)

		local mainRightPanel = modules.game_interface.getMainRightPanel()

		if not mainRightPanel:hasChild(healthManaController.ui) then
			mainRightPanel:insertChild(2, healthManaController.ui)
		end

		healthManaController.ui:show()
	end

	healthManaController.ui.moveOnlyToMain = not extendedView
end

function toggle()
	if iconTopMenu:isOn() then
		healthManaController.ui:hide()
		iconTopMenu:setOn(false)
	else
		healthManaController.ui:show()
		iconTopMenu:setOn(true)
	end
end

function setSidebarVisible(visible)
	if not healthManaController or not healthManaController.ui or healthManaController.ui:isDestroyed() then
		return
	end

	healthManaController.ui:setVisible(visible)

	local shouldHide = not visible

	if shouldHide == sidebarHidden then
		return
	end

	sidebarHidden = shouldHide

	local mainRightPanel = modules.game_interface and modules.game_interface.getMainRightPanel and modules.game_interface.getMainRightPanel()

	if not mainRightPanel or mainRightPanel:isDestroyed() then
		return
	end

	local delta = shouldHide and -SIDEBAR_HEIGHT_DELTA or SIDEBAR_HEIGHT_DELTA

	mainRightPanel:setHeight(math.max(0, mainRightPanel:getHeight() + delta))
end
