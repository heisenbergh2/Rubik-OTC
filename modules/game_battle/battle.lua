-- chunkname: @/game_battle/battle.lua

local binaryTree = {}
local battleButtons = {}
local battleWindow, battleButton, battlePanel, mouseWidget, filterPanel, toggleFilterButton, lastBattleButtonSwitched
local hideButtons = {}
local BATTLE_HIDE_BUTTONS_FORMAT = 2
local BATTLE_HIDE_BUTTON_OPTIONS = {
	"hidePlayers",
	"hideNPCs",
	"hideMonsters",
	"hideSkulls",
	"hideParty",
	"hideKnights",
	"hidePaladins",
	"hideDruids",
	"hideSorcerers",
	"hideMonks",
	"hideSummons",
	"hideMembersOwnGuild"
}
local BATTLE_FILTER_BUTTON_TOOLTIPS = {
	hidePlayers = {
		show = "Show players",
		hide = "Hide players"
	},
	hideKnights = {
		show = "Show knights",
		hide = "Hide knights"
	},
	hidePaladins = {
		show = "Show paladins",
		hide = "Hide paladins"
	},
	hideDruids = {
		show = "Show druids",
		hide = "Hide druids"
	},
	hideSorcerers = {
		show = "Show sorcerers",
		hide = "Hide sorcerers"
	},
	hideMonks = {
		show = "Show monks",
		hide = "Hide monks"
	},
	hideSummons = {
		show = "Show summons",
		hide = "Hide summons"
	},
	hideNPCs = {
		show = "Show NPCs",
		hide = "Hide NPCs"
	},
	hideMonsters = {
		show = "Show monsters",
		hide = "Hide monsters"
	},
	hideSkulls = {
		show = "Show players without skull",
		hide = "Hide players without skull"
	},
	hideParty = {
		show = "Show party members",
		hide = "Hide party members"
	},
	hideMembersOwnGuild = {
		show = "Show own guild members",
		hide = "Hide own guild members"
	}
}
local BATTLE_FILTER_JSON_ORDER = {
	{
		json = "hidePlayers",
		id = "hidePlayers"
	},
	{
		json = "hideKnights",
		id = "hideKnights"
	},
	{
		json = "hidePaladins",
		id = "hidePaladins"
	},
	{
		json = "hideDruids",
		id = "hideDruids"
	},
	{
		json = "hideSorcerers",
		id = "hideSorcerers"
	},
	{
		json = "hideMonks",
		id = "hideMonks"
	},
	{
		json = "hidePlayerSummons",
		id = "hideSummons"
	},
	{
		json = "hideMembersOfOwnGuild",
		id = "hideMembersOwnGuild"
	},
	{
		json = "hidePartyMembers",
		id = "hideParty"
	},
	{
		json = "hideNonSkulledPlayers",
		id = "hideSkulls"
	},
	{
		json = "hideMonsters",
		id = "hideMonsters"
	},
	{
		json = "hideNPCs",
		id = "hideNPCs"
	}
}
local BATTLE_SORT_TYPE_TO_JSON = {
	distance = "byDistance",
	health = "byHitpoints",
	age = "byAge",
	name = "byName"
}
local eventOnCheckCreature
local eventsConnected = false
local syncBattleMainPanelButton

local function refreshBattleFilterButtonTooltip(button)
	if not button then
		return
	end

	local t = BATTLE_FILTER_BUTTON_TOOLTIPS[button:getId()]

	if not t then
		return
	end

	if button:isChecked() then
		button:setTooltip(tr(t.hide))
	else
		button:setTooltip(tr(t.show))
	end
end

local function battleFilterButtonOnHoverChange(button, hovered)
	refreshBattleFilterButtonTooltip(button)
	g_tooltip.onWidgetHoverChange(button, hovered)
end

local function refreshAllBattleFilterButtonTooltips(instance)
	if not instance or not instance.hideButtons then
		return
	end

	for _, name in ipairs(BATTLE_HIDE_BUTTON_OPTIONS) do
		local b = instance.hideButtons[name]

		if b then
			refreshBattleFilterButtonTooltip(b)
		end
	end
end

local function getBattleListScrollbarMarginTopWithFilters(filterPanel)
	local h = filterPanel and filterPanel:getHeight() or 0

	if h <= 0 then
		h = 46
	end

	return 17 + h - 1 + 1
end

local BATTLE_LIST_FILTERS_HIDDEN_CONTENTS_MARGIN_TOP = -3
local BATTLE_LIST_FILTERS_HIDDEN_SCROLLBAR_MARGIN_TOP = 15
local onBattleButtonHoverChange, onBattleButtonMousePress, onBattleButtonMouseRelease

BattleListInstance = nil
BattleButtonPool = nil

local function findBattleListCreatureButton(mousePos)
	local clicked = g_ui.getRootWidget():recursiveGetChildByPos(mousePos, false)

	while clicked do
		if clicked.isBattleButton and clicked.creature then
			return clicked
		end

		clicked = clicked:getParent()
	end

	return nil
end

local function isBattleListCreatureClick(mousePos)
	return findBattleListCreatureButton(mousePos) ~= nil
end

local function bindBattleButtonHandlers(widget)
	local label = widget:getChildById("label")

	if label then
		label:breakAnchors()
		label:addAnchor(AnchorLeft, "spacer", AnchorRight)
		label:addAnchor(AnchorRight, "iconsMonsterSlot3", AnchorLeft)
		label:addAnchor(AnchorTop, "creature", AnchorTop)
	end

	widget.onHoverChange = onBattleButtonHoverChange
	widget.onMousePress = onBattleButtonMousePress
	widget.onMouseRelease = onBattleButtonMouseRelease
end

function table.size(t)
	if type(t) ~= "table" then
		return 0
	end

	local count = 0

	for _ in pairs(t) do
		count = count + 1
	end

	return count
end

local BATTLE_FILTERS = {
	sortDescByName = false,
	sortAscByName = false,
	sortDescByHitPoints = false,
	sortAscByHitPoints = false,
	sortDescByDistance = false,
	sortAscByDistance = false,
	sortDescByDisplayTime = false,
	sortAscByDisplayTime = true
}
local BATTLE_JSON_TO_SORT_FLAG = {
	byNameAscending = "sortAscByName",
	byHitpointsDescending = "sortDescByHitPoints",
	byHitpointsAscending = "sortAscByHitPoints",
	byDistanceDescending = "sortDescByDistance",
	byDistanceAscending = "sortAscByDistance",
	byAgeDescending = "sortDescByDisplayTime",
	byAgeAscending = "sortAscByDisplayTime",
	byNameDescending = "sortDescByName"
}

local function getBattleListSection(id)
	if not SidebarPersistence or not SidebarPersistence.getSection then
		return nil
	end

	local section = SidebarPersistence.getSection("battleListsOptions")

	if type(section) ~= "table" then
		return nil
	end

	local entry = section[tostring(id)]

	if type(entry) == "table" then
		return entry
	end

	return nil
end

local function makeFiltersFromSortName(sortName)
	local filters = table.copy(BATTLE_FILTERS)

	for flag in pairs(filters) do
		filters[flag] = false
	end

	local flag = BATTLE_JSON_TO_SORT_FLAG[sortName] or "sortAscByDisplayTime"

	filters[flag] = true

	return filters
end

local BattleListManager = {
	nextId = 1,
	isRestoring = false,
	instances = {}
}

function BattleListManager:saveInstancesState()
	return
end

function BattleListManager:restoreInstancesState()
	return
end

function BattleListManager:getMainInstance()
	return self.instances[0]
end

function BattleListManager:createNewInstance(customName)
	local instance = BattleListInstance:new(self.nextId, customName)

	self.instances[self.nextId] = instance
	self.nextId = self.nextId + 1

	self:createWindowForInstance(instance)

	return instance
end

function BattleListManager:createWindowForInstance(instance)
	local newWindow = g_ui.loadUI("battle")

	instance.window = newWindow

	newWindow:setId("battleWindow_" .. instance.id)

	if instance.id ~= 0 then
		local miniwindowIcon = newWindow:recursiveGetChildById("miniwindowIcon")

		if miniwindowIcon then
			miniwindowIcon:setImageSource("/images/game/battle/icon-battlelist-secondary-widget")
		end
	end

	instance.panel = newWindow:recursiveGetChildById("battlePanel")
	instance.filterPanel = newWindow:recursiveGetChildById("filterPanel")
	instance.toggleFilterButton = newWindow:recursiveGetChildById("toggleFilterButton")

	local scrollbar = newWindow:getChildById("miniwindowScrollBar")

	if scrollbar then
		scrollbar:mergeStyle({
			["$!on"] = {}
		})
	end

	if not instance.toggleFilterButton then
		g_logger.info("Battle: toggleFilterButton not found in battle instance " .. instance.id .. " UI")
	end

	instance:updateTitle()

	local hideButtons = {}
	local options = {
		"hidePlayers",
		"hideNPCs",
		"hideMonsters",
		"hideSkulls",
		"hideParty",
		"hideKnights",
		"hidePaladins",
		"hideDruids",
		"hideSorcerers",
		"hideMonks",
		"hideSummons",
		"hideMembersOwnGuild"
	}

	for i, v in ipairs(options) do
		hideButtons[v] = newWindow:recursiveGetChildById(v)

		if hideButtons[v] then
			hideButtons[v].onClick = function(button)
				instance:onFilterButtonClick(button)
			end
			hideButtons[v].onHoverChange = battleFilterButtonOnHoverChange
		end
	end

	instance.hideButtons = hideButtons

	instance:loadHideButtonStates()

	local contextMenuButton = newWindow:recursiveGetChildById("contextMenuButton")

	if contextMenuButton then
		function contextMenuButton.onClick(widget, mousePos, mouseButton)
			return instance:showContextMenu(widget, mousePos, mouseButton)
		end
	end

	local newWindowButton = newWindow:recursiveGetChildById("newWindowButton")

	if newWindowButton then
		function newWindowButton.onClick()
			BattleListManager:createNewInstance()
		end
	end

	if instance.toggleFilterButton then
		function instance.toggleFilterButton.onClick()
			instance:toggleFilterPanel()
			restrictResize()

			local minHeight = 80

			if not instance:isHidingFilters() then
				minHeight = minHeight + 60
			end

			if minHeight > newWindow:getHeight() then
				newWindow:setHeight(minHeight)
			end
		end
	end

	function newWindow.onOpen()
		instance:onOpen()
	end

	function newWindow.onClose()
		instance:onClose()

		if instance.id ~= 0 then
			instance:destroy(false)
		end
	end

	function newWindow.onGeometryChange()
		if instance.id ~= 0 and not BattleListManager.isRestoring then
			BattleListManager:saveInstancesState()
		end
	end

	local lockButton = newWindow:getChildById("lockButton")

	if lockButton then
		local originalOnClick = lockButton.onClick

		function lockButton.onClick()
			if originalOnClick then
				originalOnClick()
			end

			if not BattleListManager.isRestoring then
				scheduleEvent(function()
					instance:saveLockState()

					if instance.id ~= 0 then
						BattleListManager:saveInstancesState()
					end
				end, 10)
			end
		end
	end

	function newWindow.onMousePress(widget, mousePos, button)
		if button == MouseRightButton then
			if isBattleListCreatureClick(mousePos) then
				return false
			end

			return instance:showContextMenu(widget, mousePos, button)
		end

		return false
	end

	newWindow:setContentMinimumHeight(80)

	local function restrictResize()
		local originalOnResize = newWindow.onResize

		function newWindow.onResize(...)
			if originalOnResize then
				originalOnResize(...)
			end

			local minHeight = 80

			if not instance:isHidingFilters() then
				minHeight = minHeight + 60
			end

			if minHeight > newWindow:getHeight() then
				newWindow:setHeight(minHeight)
			end
		end
	end

	restrictResize()

	local originalOnMinimize = newWindow.onMinimize
	local originalOnMaximize = newWindow.onMaximize

	function newWindow.onMinimize(...)
		if originalOnMinimize then
			originalOnMinimize(...)
		end

		newWindow.onResize = nil
	end

	function newWindow.onMaximize(...)
		if originalOnMaximize then
			originalOnMaximize(...)
		end

		restrictResize()
	end

	newWindow:setup()

	local panel = modules.game_interface.findContentPanelAvailable(newWindow, newWindow:getMinimumHeight())

	if panel then
		panel:addChild(newWindow)
		newWindow:open()
	end

	local scrollbar = newWindow:getChildById("miniwindowScrollBar")

	if scrollbar then
		local fp = newWindow:recursiveGetChildById("filterPanel")

		scrollbar:setMarginTop(getBattleListScrollbarMarginTopWithFilters(fp))
	end

	if g_game.isOnline() then
		instance:checkCreatures()
	end
end

function BattleListManager:getMainInstance()
	return self.instances[0]
end

function BattleListManager:getInstance(id)
	return self.instances[id]
end

function BattleListManager:getAllInstances()
	return self.instances
end

function BattleListManager:destroyInstance(id)
	local instance = self.instances[id]

	if instance then
		instance:destroy(false)
		self:removeSavedInstanceState(id)
	end
end

function BattleListManager:removeSavedInstanceState(id)
	local instancesData = g_settings.getNode("BattleListInstances") or {}

	if instancesData[tostring(id)] then
		instancesData[tostring(id)] = nil

		g_settings.mergeNode("BattleListInstances", instancesData)
	end
end

function BattleListManager:startPeriodicSave()
	self:stopPeriodicSave()

	self.autoSaveEvent = scheduleEvent(function()
		if g_game.isOnline() and not self.isRestoring then
			self:saveInstancesState()
			self:startPeriodicSave()
		end
	end, 30000)
end

function BattleListManager:stopPeriodicSave()
	if self.autoSaveEvent then
		removeEvent(self.autoSaveEvent)

		self.autoSaveEvent = nil
	end
end

BattleListInstance = {
	name = "Battle List",
	binaryTree = {},
	battleButtons = {},
	settings = {}
}

function BattleListInstance:new(id, customName)
	local instance = {}

	setmetatable(instance, {
		__index = self
	})

	instance.id = id or BattleListManager.nextId
	instance.binaryTree = {}
	instance.battleButtons = {}
	instance.lastBattleButtonSwitched = nil
	instance.lastAge = 0
	instance.name = customName or tr("Battle List")
	instance.settings = {
		sortOrder = "A",
		sortType = "name",
		hidingFilters = false,
		filters = table.copy(BATTLE_FILTERS),
		customName = instance.name
	}

	return instance
end

function BattleListInstance:getSettingsKey()
	return "BattleList_" .. self.id
end

function BattleListInstance:loadFilters()
	self.settings = self.settings or {}

	if type(self.settings.filters) ~= "table" then
		self.settings.filters = table.copy(BATTLE_FILTERS)
	end

	return self.settings.filters
end

function BattleListInstance:saveFilters()
	return
end

function BattleListInstance:saveHideButtonStates()
	return
end

function BattleListInstance:saveLockState()
	if self.window then
		local isLocked = self.window:getSettings("locked") or false
		local lockButton = self.window:getChildById("lockButton")

		if lockButton then
			isLocked = lockButton:isOn()
		end

		g_settings.mergeNode(self:getSettingsKey(), {
			isLocked = isLocked
		})
	end
end

function BattleListInstance:loadLockState()
	if not self.window then
		return false
	end

	local settings = g_settings.getNode(self:getSettingsKey())

	if settings and settings.isLocked ~= nil then
		local isLocked = settings.isLocked
		local lockButton = self.window:getChildById("lockButton")

		if isLocked then
			self.window:lock(true)

			if lockButton then
				lockButton:setOn(true)
			end
		else
			self.window:unlock(true)

			if lockButton then
				lockButton:setOn(false)
			end
		end

		return isLocked
	end

	return false
end

function BattleListInstance:loadHideButtonStates()
	local section = getBattleListSection(self.id)

	self.settings = self.settings or {}
	self.settings.filters = makeFiltersFromSortName(section and section.battleListSortOrder)

	if not self.hideButtons then
		return
	end

	local hiddenSet = {}

	if section and type(section.battleListFilters) == "table" then
		for _, name in ipairs(section.battleListFilters) do
			hiddenSet[name] = true
		end
	end

	for _, entry in ipairs(BATTLE_FILTER_JSON_ORDER) do
		local button = self.hideButtons[entry.id]

		if button and not button:isDestroyed() then
			button:setChecked(not hiddenSet[entry.json])
		end
	end

	refreshAllBattleFilterButtonTooltips(self)
end

function BattleListInstance:getFilter(filter)
	local filters = self:loadFilters()
	local value = filters[filter]

	if value ~= nil then
		return value
	end

	return BATTLE_FILTERS[filter] or false
end

function BattleListInstance:setFilter(filter)
	local filters = self:loadFilters()
	local value = filters[filter]

	if value == nil then
		value = BATTLE_FILTERS[filter]

		if value == nil then
			return false
		end
	end

	if filter:find("sortAscBy") or filter:find("sortDescBy") then
		for filterName, _ in pairs(BATTLE_FILTERS) do
			if filterName ~= filter and (filterName:find("sortAscBy") or filterName:find("sortDescBy")) then
				filters[filterName] = false
			end
		end
	end

	filters[filter] = not value

	scheduleEvent(function()
		self:checkCreatures()
	end, 50)

	return true
end

function BattleListInstance:getSortType()
	local filters = self:loadFilters()

	for filterName, isActive in pairs(filters) do
		if isActive and (filterName:find("sortAscBy") or filterName:find("sortDescBy")) then
			if filterName:find("DisplayTime") then
				return "age"
			elseif filterName:find("Distance") then
				return "distance"
			elseif filterName:find("HitPoints") then
				return "health"
			elseif filterName:find("Name") then
				return "name"
			end
		end
	end

	return "name"
end

function BattleListInstance:setSortType(state, oldSortType)
	local order = self:getSortOrder()

	self:reSort(oldSortType, state, order, order)
end

function BattleListInstance:getSortOrder()
	local filters = self:loadFilters()

	for filterName, isActive in pairs(filters) do
		if isActive and (filterName:find("sortAscBy") or filterName:find("sortDescBy")) then
			return filterName:find("sortAscBy") and "A" or "D"
		end
	end

	return "A"
end

function BattleListInstance:setSortOrder(state, oldSortOrder)
	self:reSort(false, false, oldSortOrder, state)
end

function BattleListInstance:isSortAsc()
	return self:getSortOrder() == "A"
end

function BattleListInstance:isSortDesc()
	return self:getSortOrder() == "D"
end

function BattleListInstance:getHiddenFilterNames()
	local names = {}
	local buttons = self.hideButtons

	for _, entry in ipairs(BATTLE_FILTER_JSON_ORDER) do
		local checked = true

		if buttons then
			local button = buttons[entry.id]

			if button and not button:isDestroyed() then
				checked = button:isChecked()
			end
		end

		if not checked then
			names[#names + 1] = entry.json
		end
	end

	return names
end

function BattleListInstance:getSortOrderName()
	local base = BATTLE_SORT_TYPE_TO_JSON[self:getSortType()] or "byName"

	return base .. (self:isSortDesc() and "Descending" or "Ascending")
end

function BattleListInstance:getName()
	local settings = g_settings.getNode(self:getSettingsKey())

	if settings and settings.customName then
		return settings.customName
	end

	return tr("Battle List")
end

function BattleListInstance:setName(name)
	local settings = g_settings.getNode(self:getSettingsKey()) or {}

	settings.customName = (name == nil or name == "") and tr("Battle List") or name

	g_settings.mergeNode(self:getSettingsKey(), settings)
	self:updateTitle()

	if self.id ~= 0 and not BattleListManager.isRestoring then
		BattleListManager:saveInstancesState()
	end
end

function BattleListInstance:updateTitle()
	if self.window then
		local titleLabel = self.window:recursiveGetChildById("miniwindowTitle")

		if titleLabel then
			local title = self:getName()

			if string.len(title) > 11 then
				title = string.sub(title, 1, 8) .. "..."
			end

			titleLabel:setText(title)
		end
	end
end

function BattleListInstance:clearAllConfigurations()
	local settingsKey = self:getSettingsKey()
	local settings = g_settings.getNode(settingsKey)

	if settings then
		g_settings.mergeNode(settingsKey, {})
	end

	self.settings = {
		sortOrder = "A",
		sortType = "name",
		hidingFilters = false,
		filters = table.copy(BATTLE_FILTERS),
		customName = tr("Battle List")
	}

	if self.hideButtons then
		for _, button in pairs(self.hideButtons) do
			if button then
				button:setChecked(true)
			end
		end

		refreshAllBattleFilterButtonTooltips(self)
	end

	self:updateTitle()

	if self.filterPanel and not self.filterPanel:isVisible() then
		self:showFilterPanel()
	end

	if self.window then
		self.window:unlock()
	end

	self:checkCreatures()
end

function BattleListInstance:destroy(saveSettings)
	if not saveSettings then
		local settingsKey = self:getSettingsKey()
		local settings = g_settings.getNode(settingsKey)

		if settings then
			g_settings.mergeNode(settingsKey, {})
		end

		if self.id ~= 0 then
			BattleListManager:removeSavedInstanceState(self.id)
		end
	else
		self:saveFilters()
		self:saveHideButtonStates()
		self:saveLockState()
	end

	for _, v in pairs(self.battleButtons) do
		BattleButtonPool:release(v)
	end

	self.binaryTree = {}
	self.battleButtons = {}
	self.lastBattleButtonSwitched = nil
	self.settings = nil

	if self.window and self.id ~= 0 then
		self.window:destroy()

		self.window = nil
	end

	self.panel = nil
	self.filterPanel = nil
	self.toggleFilterButton = nil
	self.hideButtons = nil
	BattleListManager.instances[self.id] = nil
end

function BattleListInstance:onFilterButtonClick(button)
	button:setChecked(not button:isChecked())
	refreshBattleFilterButtonTooltip(button)
	self:saveHideButtonStates()
	self:checkCreatures()
end

function BattleListInstance:showContextMenu(widget, mousePos, mouseButton)
	local menu = g_ui.createWidget("BattleListSubMenu")

	menu:setGameMenu(true)

	for _, choice in ipairs(menu:getChildren()) do
		local choiceId = choice:getId()

		if choiceId and choiceId ~= "HorizontalSeparator" then
			if choiceId == "editBattleListName" or choiceId == "openNewBattleList" then
				function choice.onClick()
					self:onMenuAction(choiceId)
					menu:destroy()
				end
			else
				local filterValue = self:getFilter(choiceId)

				choice:setChecked(filterValue)

				function choice.onCheckChange()
					self:onMenuAction(choiceId)
					menu:destroy()
				end
			end
		end
	end

	local buttonPos = widget:getPosition()
	local buttonSize = widget:getSize()
	local menuWidth = menu:getWidth()
	local buttonCenterX = buttonPos.x + buttonSize.width / 2
	local buttonCenterY = buttonPos.y + buttonSize.height / 2
	local menuX = buttonCenterX - menuWidth
	local menuY = buttonCenterY

	if mousePos and mousePos.x and mousePos.y then
		menu:display(mousePos)
	else
		menu:display({
			x = menuX,
			y = menuY
		})
	end

	return true
end

function BattleListInstance:onMenuAction(actionId)
	if actionId == "editBattleListName" then
		self:openEditNameDialog()
	elseif actionId == "openNewBattleList" then
		BattleListManager:createNewInstance()
	else
		self:setFilter(actionId)
	end
end

function BattleListInstance:openEditNameDialog()
	local currentName = self:getName()

	if currentName == tr("Battle List") then
		currentName = ""
	end

	local changeListNameWindow = g_ui.displayUI("style/changeListName")

	changeListNameWindow:show()

	local nameInput = changeListNameWindow:getChildById("newBattleListName")

	nameInput:setText(currentName)
	nameInput:focus()
	nameInput:selectAll()

	local function closeWindow()
		nameInput:setText("")
		changeListNameWindow:setVisible(false)
		changeListNameWindow:destroy()
	end

	function changeListNameWindow.buttonOk.onClick()
		local newName = nameInput:getText()

		self:setName(newName)
		closeWindow()
	end

	changeListNameWindow.closeButton.onClick = closeWindow
	changeListNameWindow.onEscape = closeWindow

	function nameInput.onKeyDown(widget, keyCode, keyboardModifiers)
		if g_keyboard.isEnterKey(keyCode) then
			changeListNameWindow.buttonOk.onClick()

			return true
		elseif keyCode == KeyEscape then
			closeWindow()

			return true
		end

		return false
	end
end

function BattleListInstance:toggleFilterPanel()
	if self.filterPanel:isVisible() then
		self:hideFilterPanel()
	else
		self:showFilterPanel()
	end
end

function BattleListInstance:hideFilterPanel()
	self.filterPanel.originalHeight = self.filterPanel:getHeight()

	self.filterPanel:setHeight(0)

	if self.toggleFilterButton then
		self.toggleFilterButton:getParent():setMarginTop(0)
		self.toggleFilterButton:setOn(false)
	end

	self:setHidingFilters(true)

	local HorizontalSeparator = self.window:recursiveGetChildById("HorizontalSeparator")

	if HorizontalSeparator then
		HorizontalSeparator:setVisible(false)
	end

	self.filterPanel:setVisible(false)

	local contentsPanel = self.window:recursiveGetChildById("contentsPanel")

	if contentsPanel then
		contentsPanel:setMarginTop(BATTLE_LIST_FILTERS_HIDDEN_CONTENTS_MARGIN_TOP)
	end

	local scrollbar = self.window:getChildById("miniwindowScrollBar")

	if scrollbar then
		scrollbar:setMarginTop(BATTLE_LIST_FILTERS_HIDDEN_SCROLLBAR_MARGIN_TOP)
	end

	if self.window.onResize then
		local function restrictResize()
			function self.window.onResize()
				local minHeight = 80

				if not self:isHidingFilters() then
					minHeight = minHeight + 60
				end

				if minHeight > self.window:getHeight() then
					self.window:setHeight(minHeight)
				end
			end
		end

		restrictResize()
	end
end

function BattleListInstance:showFilterPanel()
	if self.toggleFilterButton then
		self.toggleFilterButton:getParent():setMarginTop()
		self.toggleFilterButton:setOn(true)
	end

	if not self.filterPanel.originalHeight then
		self.filterPanel.originalHeight = 40
	end

	self.filterPanel:setHeight(self.filterPanel.originalHeight)
	self:setHidingFilters(false)

	local HorizontalSeparator = self.window:recursiveGetChildById("HorizontalSeparator")

	if HorizontalSeparator then
		HorizontalSeparator:setVisible(true)
	end

	self.filterPanel:setVisible(true)

	local contentsPanel = self.window:recursiveGetChildById("contentsPanel")

	if contentsPanel then
		contentsPanel:setMarginTop(0)
	end

	local scrollbar = self.window:getChildById("miniwindowScrollBar")

	if scrollbar then
		scrollbar:setMarginTop(getBattleListScrollbarMarginTopWithFilters(self.filterPanel))
	end

	if self.window.onResize then
		local function restrictResize()
			function self.window.onResize()
				local minHeight = 80

				if not self:isHidingFilters() then
					minHeight = minHeight + 60
				end

				if minHeight > self.window:getHeight() then
					self.window:setHeight(minHeight)
				end
			end
		end

		restrictResize()
	end
end

function BattleListInstance:setHidingFilters(state)
	local settings = {}

	settings.hidingFilters = state

	g_settings.mergeNode(self:getSettingsKey(), settings)
end

function BattleListInstance:isHidingFilters()
	local settings = g_settings.getNode(self:getSettingsKey())

	if not settings then
		return false
	end

	return settings.hidingFilters
end

function BattleListInstance:onOpen()
	if g_game.isOnline() then
		connecting()
	end

	local filters = self:loadFilters()
	local hasAnySortFilter = false

	for filterName, isActive in pairs(filters) do
		if isActive and (filterName:find("sortAscBy") or filterName:find("sortDescBy")) then
			hasAnySortFilter = true

			break
		end
	end

	if not hasAnySortFilter then
		filters.sortAscByDisplayTime = true

		g_settings.mergeNode(self:getSettingsKey(), {
			filters = filters
		})
		scheduleEvent(function()
			self:checkCreatures()
		end, 100)
	end
end

function BattleListInstance:onClose()
	return
end

function BattleListInstance:checkCreatures()
	if not self.panel or not g_game.isOnline() then
		return false
	end

	self.panel:disableUpdateTemporarily()

	local player = g_game.getLocalPlayer()

	if not player then
		return false
	end

	local position = player:getPosition()

	if not position then
		return false
	end

	self:removeAllCreatures()

	local spectators = modules.game_interface.getMapPanel():getSpectators()
	local sortType = self:getSortType()
	local sortOrder = self:getSortOrder()

	for _, creature in ipairs(spectators) do
		if self:doCreatureFitFilters(creature) then
			self:addCreature(creature, sortType)
		end
	end
end

function BattleListInstance:doCreatureFitFilters(creature)
	if creature:isLocalPlayer() then
		return false
	end

	if creature:isDead() then
		return false
	end

	if creature:getHealthPercent() <= 0 then
		return false
	end

	local pos = creature:getPosition()

	if not pos then
		return false
	end

	local localPlayer = g_game.getLocalPlayer()

	if not localPlayer then
		return false
	end

	local position = localPlayer:getPosition()

	if not position then
		return false
	end

	if pos.z ~= localPlayer:getPosition().z or not creature:canBeSeen() then
		return false
	end

	for i, v in pairs(self.hideButtons or {}) do
		if not v:isChecked() and (i == "hidePlayers" and creature:isPlayer() or i == "hideNPCs" and creature:isNpc() or i == "hideMonsters" and creature:isMonster() or i == "hideSkulls" and creature:isPlayer() and creature:getSkull() == SkullNone or i == "hideParty" and creature:isPlayer() and (function()
			local shield = creature:getShield()

			return shield and (shield == ShieldYellow or shield == ShieldYellowSharedExp or shield == ShieldYellowNoSharedExp or shield == ShieldBlue or shield == ShieldBlueNoSharedExpBlink or shield == ShieldBlueSharedExp or shield == ShieldYellowNoSharedExpBlink)
		end)() or i == "hideKnights" and creature:isPlayer() and creature:isKnight() or i == "hidePaladins" and creature:isPlayer() and creature:isPaladin() or i == "hideDruids" and creature:isPlayer() and creature:isDruid() or i == "hideSorcerers" and creature:isPlayer() and creature:isSorcerer() or i == "hideMonks" and creature:isPlayer() and creature:isMonk() or i == "hideSummons" and creature:isMonster() and (function()
			local masterId = creature:getMasterId()

			return masterId and masterId > 0
		end)() or i == "hideMembersOwnGuild" and creature:isPlayer() and creature:getEmblem() == localPlayer:getEmblem() and creature:getEmblem() ~= EmblemNone) then
			return false
		end
	end

	return true
end

local lastAge = 0

function BattleListInstance:addCreature(creature, sortType)
	local creatureId = creature:getId()
	local battleButton = self.battleButtons[creatureId]

	if battleButton then
		if battleButton.creature then
			battleButton:update()
		end
	else
		if creature:getPosition() == nil then
			return
		end

		local newCreature = {}

		newCreature.id = creatureId
		newCreature.name = creature:getName():lower()
		newCreature.healthpercent = creature:getHealthPercent()
		newCreature.distance = getDistanceBetween(g_game.getLocalPlayer():getPosition(), creature:getPosition())
		newCreature.age = self.lastAge + 1
		self.lastAge = self.lastAge + 1

		local newIndex = binaryInsert(self.binaryTree, newCreature, BSComparatorSortType, sortType, true)

		battleButton = BattleButtonPool:get()

		battleButton:setup(creature, true)

		battleButton.data = {}

		for i, v in pairs(newCreature) do
			battleButton.data[i] = v
		end

		self.battleButtons[creatureId] = battleButton

		if creature == g_game.getAttackingCreature() then
			battleButton.isTarget = true

			if battleButton.creature then
				battleButton:update()
			end
		end

		if creature == g_game.getFollowingCreature() then
			battleButton.isFollowed = true

			if battleButton.creature then
				battleButton:update()
			end
		end

		if self:isSortAsc() then
			self.panel:insertChild(newIndex, battleButton)
		else
			self.panel:insertChild(#self.binaryTree - newIndex + 1, battleButton)
		end
	end

	battleButton:setVisible(canBeSeen(creature))
	self.panel:getLayout():update()
end

function BattleListInstance:removeAllCreatures()
	self:removeCreature(false, true)
end

function BattleListInstance:removeCreature(creature, all)
	if all then
		self.binaryTree = {}
		self.lastBattleButtonSwitched = nil

		for _, v in pairs(self.battleButtons) do
			BattleButtonPool:release(v)
		end

		self.battleButtons = {}

		return true
	end

	local creatureId = creature:getId()
	local battleButton = self.battleButtons[creatureId]

	if battleButton then
		if self.lastBattleButtonSwitched == battleButton then
			self.lastBattleButtonSwitched = nil
		end

		local sortType = self:getSortType()
		local valuetoSearch = self:getAttributeByOrderType(battleButton, sortType)

		assert(valuetoSearch, "Could not find information (data) in sent battleButton")

		valuetoSearch.id = creatureId

		local index = binarySearch(self.binaryTree, valuetoSearch, BSComparatorSortType, sortType, creatureId)

		if index == nil or creatureId ~= self.binaryTree[index].id then
			for i, entry in ipairs(self.binaryTree) do
				if entry.id == creatureId then
					index = i

					break
				end
			end
		end

		if index ~= nil and creatureId == self.binaryTree[index].id then
			local creatureListSize = #self.binaryTree

			if index < creatureListSize then
				for i = index, creatureListSize - 1 do
					local tmp = self.binaryTree[i]

					self.binaryTree[i] = self.binaryTree[i + 1]
					self.binaryTree[i + 1] = tmp
				end
			end

			self.binaryTree[creatureListSize] = nil

			BattleButtonPool:release(battleButton)

			self.battleButtons[creatureId] = nil

			return true
		end
	end

	return false
end

function BattleListInstance:getAttributeByOrderType(battleButton, orderType)
	if battleButton.data then
		local battleButton = battleButton.data

		if orderType == "distance" then
			return {
				distance = battleButton.distance
			}
		elseif orderType == "health" then
			return {
				healthpercent = battleButton.healthpercent
			}
		elseif orderType == "age" then
			return {
				age = battleButton.age
			}
		else
			return {
				name = battleButton.name
			}
		end
	end

	return false
end

function BattleListInstance:correctBattleButtons(sortOrder)
	self.panel:disableUpdateTemporarily()

	local sortOrder = sortOrder or self:getSortOrder()
	local start = sortOrder == "A" and 1 or #self.binaryTree
	local finish = #self.binaryTree - start + 1
	local increment = start <= finish and 1 or -1
	local index = 1

	for i = start, finish, increment do
		local v = self.binaryTree[i]
		local battleButton = self.battleButtons[v.id]

		if battleButton ~= nil then
			self.panel:moveChildToIndex(battleButton, index)

			index = index + 1
		end
	end

	return true
end

function BattleListInstance:reSort(oldSortType, newSortType, oldSortOrder, newSortOrder)
	if #self.binaryTree > 1 then
		if newSortType and newSortType ~= oldSortType then
			self:checkCreatures()
		end

		if newSortOrder then
			self:correctBattleButtons(newSortOrder)
		end
	end

	return true
end

function BattleListInstance:swap(index, newIndex)
	local highest = newIndex
	local lowest = index

	if newIndex < index then
		highest = index
		lowest = newIndex
	end

	local tmp = self.binaryTree[lowest]

	self.binaryTree[lowest] = self.binaryTree[highest]
	self.binaryTree[highest] = tmp
end

function loadFilters()
	local settings = g_settings.getNode("BattleList")

	if not settings or not settings.filters then
		return BATTLE_FILTERS
	end

	return settings.filters
end

function saveFilters()
	g_settings.mergeNode("BattleList", {
		filters = loadFilters()
	})
end

function getBattleListName()
	local settings = g_settings.getNode("BattleList")

	if settings and settings.customName then
		return settings.customName
	end

	return tr("Battle List")
end

function setBattleListName(name)
	local settings = g_settings.getNode("BattleList") or {}

	settings.customName = (name == nil or name == "") and tr("Battle List") or name

	g_settings.mergeNode("BattleList", settings)
	updateBattleListTitle()
end

function updateBattleListTitle()
	if battleWindow then
		local titleLabel = battleWindow:recursiveGetChildById("miniwindowTitle")

		if titleLabel then
			local title = getBattleListName()

			if string.len(title) > 11 then
				title = string.sub(title, 1, 8) .. "..."
			end

			titleLabel:setText(title)
		end
	end
end

function getFilter(filter)
	local mainInstance = BattleListManager:getMainInstance()

	if mainInstance then
		return mainInstance:getFilter(filter)
	end

	local filters = loadFilters()

	return filters[filter] ~= nil and filters[filter] or BATTLE_FILTERS[filter] or false
end

function setFilter(filter)
	local filters = loadFilters()
	local value = filters[filter]

	if value == nil then
		value = BATTLE_FILTERS[filter]

		if value == nil then
			return false
		end
	end

	if filter:find("sortAscBy") or filter:find("sortDescBy") then
		for filterName, _ in pairs(BATTLE_FILTERS) do
			if filterName ~= filter and (filterName:find("sortAscBy") or filterName:find("sortDescBy")) then
				filters[filterName] = false
			end
		end
	end

	filters[filter] = not value

	g_settings.mergeNode("BattleList", {
		filters = filters
	})

	return true
end

function connecting()
	if eventsConnected then
		return true
	end

	BattleListManager.config = BattleListManager.config or {}

	function BattleListManager.config.handleLocalPlayerMove(instance, newPos, oldPos, sortType)
		if oldPos and newPos and newPos.z ~= oldPos.z then
			addEvent(function()
				instance:checkCreatures()
			end)
		elseif oldPos and newPos and (newPos.x ~= oldPos.x or newPos.y ~= oldPos.y) then
			if #instance.binaryTree > 0 and sortType == "distance" then
				for i, v in ipairs(instance.binaryTree) do
					local oldDistance = v.distance
					local battleButton = instance.battleButtons[v.id]
					local mob = battleButton.creature or g_map.getCreatureById(v.id)

					if mob and mob:getPosition() then
						local newDistance = getDistanceBetween(newPos, mob:getPosition())

						if oldDistance ~= newDistance then
							v.distance = newDistance
							battleButton.data.distance = newDistance
						end
					end
				end

				table.sort(instance.binaryTree, function(a, b)
					return BSComparatorSortType(a, b, "distance", true) == 1
				end)
				instance:correctBattleButtons()
			end

			for _, v in pairs(instance.battleButtons) do
				local mob = v.creature

				if mob and mob:getPosition() then
					v:setVisible(canBeSeen(mob))
				end
			end
		end
	end

	function BattleListManager.config.handleCreatureMove(instance, creature, newPos, oldPos, sortType)
		local creatureId = creature:getId()
		local battleButton = instance.battleButtons[creatureId]
		local fit = instance:doCreatureFitFilters(creature)

		if battleButton == nil then
			if fit then
				instance:addCreature(creature, sortType)
			end
		elseif not fit and newPos then
			instance:removeCreature(creature)
		elseif fit then
			if oldPos and newPos and (newPos.x ~= oldPos.x or newPos.y ~= oldPos.y) and sortType == "distance" then
				local localPlayer = g_game.getLocalPlayer()
				local newDistance = getDistanceBetween(localPlayer:getPosition(), newPos)
				local oldDistance = battleButton.data.distance
				local index = binarySearch(instance.binaryTree, {
					distance = oldDistance,
					id = creatureId
				}, BSComparatorSortType, "distance", true)

				if index ~= nil and creatureId == instance.binaryTree[index].id then
					instance.binaryTree[index].distance = newDistance
					battleButton.data.distance = newDistance

					if oldDistance < newDistance then
						if index < #instance.binaryTree then
							for i = index, #instance.binaryTree - 1 do
								local a = instance.binaryTree[i]
								local b = instance.binaryTree[i + 1]

								if a.distance > b.distance or a.distance == b.distance and a.id > b.id then
									instance:swap(i, i + 1)
								end
							end
						end
					elseif newDistance < oldDistance then
						battleButton:setVisible(canBeSeen(creature))

						if index > 1 then
							for i = index, 2, -1 do
								local a = instance.binaryTree[i - 1]
								local b = instance.binaryTree[i]

								if a.distance > b.distance or a.distance == b.distance and a.id > b.id then
									instance:swap(i - 1, i)
								end
							end
						end
					end

					instance:correctBattleButtons()
				end
			end

			instance:addCreature(creature)
		end
	end

	function BattleListManager.config.shouldRemoveOnDisappear()
		return true
	end

	for _, m in ipairs(CreatureListEventHub.managers) do
		if m == BattleListManager then
			eventsConnected = true

			CreatureListEventHub.connect()

			return true
		end
	end

	table.insert(CreatureListEventHub.managers, BattleListManager)
	CreatureListEventHub.connect()

	eventsConnected = true

	return true
end

function disconnecting(gameEvent)
	if not eventsConnected then
		return true
	end

	CreatureListEventHub.disconnect()

	eventsConnected = false

	return true
end

function init()
	if not ObjectPool then
		BattleButtonPool = {
			get = function()
				local widget = g_ui.createWidget("BattleButton")

				widget:show()
				widget:setOn(true)
				bindBattleButtonHandlers(widget)

				return widget
			end,
			release = function(obj)
				if obj and obj:getParent() then
					obj:getParent():removeChild(obj)
				end
			end
		}
	else
		BattleButtonPool = ObjectPool.new(function()
			local widget = g_ui.createWidget("BattleButton")

			widget:show()
			widget:setOn(true)
			bindBattleButtonHandlers(widget)

			return widget
		end, function(obj)
			if obj.data then
				obj.data = nil
			end

			if lastBattleButtonSwitched == obj then
				lastBattleButtonSwitched = nil
			end

			obj:resetState()

			local parent = obj:getParent()

			if parent then
				parent:removeChild(obj)
			end
		end)
	end

	g_ui.importStyle("battlebutton")

	battleButton = modules.game_mainpanel.addToggleButton("battleButton", tr("Open Battle List"), "/images/options/button_battle_list", toggle, false, 2)
	battleWindow = g_ui.loadUI("battle")
	BattleListManager.nextId = 1

	local mainInstance = BattleListInstance:new(0, tr("Battle List"))

	mainInstance.window = battleWindow
	mainInstance.panel = battleWindow:recursiveGetChildById("battlePanel")
	mainInstance.filterPanel = battleWindow:recursiveGetChildById("filterPanel")
	mainInstance.toggleFilterButton = battleWindow:recursiveGetChildById("toggleFilterButton")

	if not mainInstance.toggleFilterButton then
		g_logger.info("Battle: toggleFilterButton not found in battle window UI")
	end

	BattleListManager.instances[0] = mainInstance
	battlePanel = mainInstance.panel
	filterPanel = mainInstance.filterPanel
	toggleFilterButton = mainInstance.toggleFilterButton

	Keybind.new("Windows", "Show/hide battle list", "Ctrl+B", "")
	Keybind.bind("Windows", "Show/hide battle list", {
		{
			type = KEY_DOWN,
			callback = toggle
		}
	})
	Keybind.new("Battle List", "Attack Next Target", {
		[CHAT_MODE.ON] = "",
		[CHAT_MODE.OFF] = "Space"
	}, "")
	Keybind.bind("Battle List", "Attack Next Target", {
		{
			type = KEY_DOWN,
			callback = function()
				if not g_game.isOnline() then
					return
				end

				attackNext()
			end
		}
	})

	local scrollbar = battleWindow:getChildById("miniwindowScrollBar")

	if scrollbar then
		scrollbar:mergeStyle({
			["$!on"] = {}
		})
	end

	HorizontalSeparator = battleWindow:recursiveGetChildById("HorizontalSeparator")
	contentsPanel = battleWindow:recursiveGetChildById("contentsPanel")
	miniwindowScrollBar = battleWindow:getChildById("miniwindowScrollBar")

	local settings = g_settings.getNode(mainInstance:getSettingsKey())

	if settings and settings.hidingFilters then
		mainInstance:hideFilterPanel()
	else
		local scrollbar = battleWindow:getChildById("miniwindowScrollBar")

		if scrollbar then
			local fp = battleWindow:recursiveGetChildById("filterPanel")

			scrollbar:setMarginTop(getBattleListScrollbarMarginTopWithFilters(fp))
		end
	end

	local options = {
		"hidePlayers",
		"hideNPCs",
		"hideMonsters",
		"hideSkulls",
		"hideParty",
		"hideKnights",
		"hidePaladins",
		"hideDruids",
		"hideSorcerers",
		"hideMonks",
		"hideSummons",
		"hideMembersOwnGuild"
	}

	for i, v in ipairs(options) do
		hideButtons[v] = battleWindow:recursiveGetChildById(v)
	end

	mainInstance.hideButtons = hideButtons

	mainInstance:loadHideButtonStates()

	for _, v in ipairs(options) do
		local b = hideButtons[v]

		if b then
			b.onHoverChange = battleFilterButtonOnHoverChange
		end
	end

	mainInstance:loadLockState()

	local mainLockButton = battleWindow:getChildById("lockButton")

	if mainLockButton then
		local originalOnClick = mainLockButton.onClick

		function mainLockButton.onClick()
			if originalOnClick then
				originalOnClick()
			end

			scheduleEvent(function()
				mainInstance:saveLockState()
			end, 10)
		end
	end

	mouseWidget = g_ui.createWidget("UIButton")

	mouseWidget:setVisible(false)
	mouseWidget:setFocusable(false)

	mouseWidget.cancelNextRelease = false

	connect(g_game, {
		onAttackingCreatureChange = onAttack,
		onFollowingCreatureChange = onFollow,
		onHoveredCreatureChange = onHoveredCreatureChange,
		onGameEnd = onGameEnd,
		onGameStart = onGameStart
	})

	local contextMenuButton = battleWindow:recursiveGetChildById("contextMenuButton")

	if contextMenuButton then
		function contextMenuButton.onClick(widget, mousePos, mouseButton)
			return mainInstance:showContextMenu(widget, mousePos, mouseButton)
		end
	end

	local newWindowButton = battleWindow:recursiveGetChildById("newWindowButton")

	if newWindowButton then
		function newWindowButton.onClick()
			BattleListManager:createNewInstance()
		end
	end

	battleWindow:setContentMinimumHeight(80)

	local function restrictResize()
		local originalOnResize = battleWindow.onResize

		function battleWindow.onResize(...)
			if originalOnResize then
				originalOnResize(...)
			end

			local minHeight = 80

			if not mainInstance:isHidingFilters() then
				minHeight = minHeight + 60
			end

			if minHeight > battleWindow:getHeight() then
				battleWindow:setHeight(minHeight)
			end
		end
	end

	if mainInstance.toggleFilterButton then
		function mainInstance.toggleFilterButton.onClick()
			mainInstance:toggleFilterPanel()
			restrictResize()

			local minHeight = 80

			if not mainInstance:isHidingFilters() then
				minHeight = minHeight + 60
			end

			if minHeight > battleWindow:getHeight() then
				battleWindow:setHeight(minHeight)
			end
		end
	end

	restrictResize()

	local originalOnMinimize = battleWindow.onMinimize
	local originalOnMaximize = battleWindow.onMaximize

	function battleWindow.onMinimize(...)
		if originalOnMinimize then
			originalOnMinimize(...)
		end

		battleWindow.onResize = nil
	end

	function battleWindow.onMaximize(...)
		if originalOnMaximize then
			originalOnMaximize(...)
		end

		restrictResize()
	end

	battleWindow:setup()
	updateBattleListTitle()

	function battleWindow.onMousePress(widget, mousePos, button)
		if button == MouseRightButton then
			if isBattleListCreatureClick(mousePos) then
				return false
			end

			return mainInstance:showContextMenu(widget, mousePos, button)
		end

		return false
	end

	if g_game.isOnline() then
		battleWindow:setupOnStart()
	end

	syncBattleMainPanelButton()
end

function BSComparator(a, b)
	return b < a and -1 or a < b and 1 or 0
end

function BSComparatorSortType(a, b, sortType, id)
	local comparatorA, comparatorB

	if sortType == "distance" then
		comparatorA, comparatorB = a.distance, type(b) == "table" and b.distance or b
	elseif sortType == "health" then
		comparatorA, comparatorB = a.healthpercent, type(b) == "table" and b.healthpercent or b
	elseif sortType == "age" then
		comparatorA, comparatorB = a.age, type(b) == "table" and b.age or b
	elseif sortType == "name" then
		comparatorA, comparatorB = a.name:lower(), type(b) == "table" and b.name:lower() or b
	end

	if comparatorA == nil or comparatorB == nil then
		return 0
	end

	if comparatorB < comparatorA then
		return -1
	elseif comparatorA < comparatorB then
		return 1
	else
		if id and b and b.id then
			return a.id > b.id and -1 or a.id < b.id and 1 or 0
		end

		return 0
	end
end

function binarySearch(tbl, value, comparator, ...)
	comparator = comparator or BSComparator

	local mini, maxi = 1, #tbl

	while mini <= maxi do
		local mid = math.floor((maxi + mini) / 2)
		local tmp_value = comparator(tbl[mid], value, ...)

		if tmp_value == 0 then
			return mid
		elseif tmp_value < 0 then
			maxi = mid - 1
		else
			mini = mid + 1
		end
	end

	return nil
end

function binaryInsert(tbl, value, comparator, ...)
	comparator = comparator or BSComparator

	local mini, maxi = 1, #tbl
	local state, mid = 0, 1

	while mini <= maxi do
		mid = math.floor((maxi + mini) / 2)

		if comparator(tbl[mid], value, ...) < 0 then
			maxi, state = mid - 1, 0
		else
			mini, state = mid + 1, 1
		end
	end

	table.insert(tbl, mid + state, value)

	return mid + state
end

function onGameStart()
	battleWindow:setupOnStart()

	if g_game.isOnline() then
		connecting()
	end

	updateBattleListTitle()

	local mainInstance = BattleListManager.instances[0]

	if mainInstance then
		mainInstance:loadLockState()
	end

	for _, instance in pairs(BattleListManager.instances) do
		if instance.window then
			instance.window:setupOnStart()
		end

		instance:loadHideButtonStates()
		instance:updateTitle()
	end

	BattleListManager:restoreInstancesState()
	BattleListManager:startPeriodicSave()
	scheduleEvent(function()
		for _, instance in pairs(BattleListManager.instances) do
			instance:checkCreatures()
		end
	end, 500)
end

function onGameEnd()
	if battleWindow and battleWindow.save then
		if SidebarLayoutState and SidebarLayoutState.noteWidgetPlacement then
			SidebarLayoutState.noteWidgetPlacement(battleWindow)
		end

		battleWindow:saveSelfIndex()

		if battleWindow:isResizeable() and not battleWindow:isOn() then
			battleWindow:setSettings({
				height = battleWindow:getHeight()
			})
		end
	end

	BattleListManager:stopPeriodicSave()

	if not SidebarPersistence or not SidebarPersistence.lastSessionActive then
		battleWindow:setParent(nil, true)
	end

	removeAllCreatures()
	saveFilters()
	BattleListManager:saveInstancesState()

	for _, instance in pairs(BattleListManager.instances) do
		instance:removeAllCreatures()

		if instance.id ~= 0 and instance.window then
			if SidebarLayoutState and SidebarLayoutState.noteWidgetPlacement then
				SidebarLayoutState.noteWidgetPlacement(instance.window)
			end

			if not SidebarPersistence or not SidebarPersistence.lastSessionActive then
				instance.window:setParent(nil, true)
			end
		end
	end

	disconnecting()
end

function getSortType()
	local settings = g_settings.getNode("BattleList")

	if not settings or not settings.sortType then
		return "name"
	end

	return settings.sortType
end

function setSortType(state, oldSortType)
	local settings = {}

	settings.sortType = state

	g_settings.mergeNode("BattleList", settings)

	local mainInstance = BattleListManager.instances[0]

	if mainInstance then
		local order = mainInstance:getSortOrder()

		mainInstance:reSort(oldSortType, state, order, order)
	end
end

function onZoomChange()
	removeEvent(eventOnCheckCreature)

	eventOnCheckCreature = scheduleEvent(function()
		for _, instance in pairs(BattleListManager.instances) do
			instance:checkCreatures()
		end
	end, 1000)
end

function onChangeSortType(comboBox, option)
	local loption = option:lower()
	local oldType = getSortType()

	if loption ~= oldType then
		setSortType(loption, oldType)
	end
end

function getSortOrder()
	local settings = g_settings.getNode("BattleList")

	if not settings then
		return "A"
	end

	return settings.sortOrder
end

function setSortOrder(state, oldSortOrder)
	local settings = {}

	settings.sortOrder = state

	g_settings.mergeNode("BattleList", settings)

	local mainInstance = BattleListManager.instances[0]

	if mainInstance then
		mainInstance:reSort(false, false, oldSortOrder, state)
	end
end

function isSortAsc()
	return getSortOrder() == "A"
end

function isSortDesc()
	return getSortOrder() == "D"
end

function onChangeSortOrder(comboBox, option)
	local soption = option:sub(1, 1)
	local oldOrder = getSortOrder()

	if soption ~= oldOrder then
		setSortOrder(option:sub(1, 1), oldOrder)
	end
end

function checkCreatures()
	eventOnCheckCreature = nil

	if not g_game.isOnline() then
		return false
	end

	local player = g_game.getLocalPlayer()

	if not player then
		return false
	end

	local position = player:getPosition()

	if not position then
		return false
	end

	for _, instance in pairs(BattleListManager.instances) do
		if instance.panel then
			instance:checkCreatures()
		end
	end
end

function doCreatureFitFilters(creature)
	local mainInstance = BattleListManager.instances[0]

	if mainInstance then
		return mainInstance:doCreatureFitFilters(creature)
	end

	return false
end

function onFilterButtonClick(button)
	button:setChecked(not button:isChecked())
	refreshBattleFilterButtonTooltip(button)

	local mainInstance = BattleListManager.instances[0]

	if mainInstance then
		mainInstance:saveHideButtonStates()
	end

	for _, instance in pairs(BattleListManager.instances) do
		instance:checkCreatures()
	end
end

function canBeSeen(creature)
	return creature and creature:canBeSeen() and creature:getPosition() and modules.game_interface.getMapPanel():isInRange(creature:getPosition())
end

function getDistanceBetween(p1, p2)
	if p2 == nil then
		p2 = {
			y = 0,
			x = 0
		}
	end

	local xd = math.abs(p1.x - p2.x)
	local yd = math.abs(p1.y - p2.y)

	if xd > 0 then
		xd = xd - 1
	end

	if yd > 0 then
		yd = yd - 1
	end

	return xd + yd
end

local function getAttributeByOrderType(battleButton, orderType)
	if battleButton.data then
		local battleButton = battleButton.data

		if orderType == "distance" then
			return {
				distance = battleButton.distance
			}
		elseif orderType == "health" then
			return {
				healthpercent = battleButton.healthpercent
			}
		elseif orderType == "age" then
			return {
				age = battleButton.age
			}
		else
			return {
				name = battleButton.name
			}
		end
	end

	return false
end

local lastAge = 0

function addCreature(creature, sortType)
	local mainInstance = BattleListManager.instances[0]

	if mainInstance then
		mainInstance:addCreature(creature, sortType)
	end
end

function removeAllCreatures()
	local mainInstance = BattleListManager.instances[0]

	if mainInstance then
		mainInstance:removeAllCreatures()
	end
end

function removeCreature(creature, all)
	local mainInstance = BattleListManager.instances[0]

	if mainInstance then
		return mainInstance:removeCreature(creature, all)
	end

	return false
end

function isHidingFilters()
	local settings = g_settings.getNode("BattleList")

	if not settings then
		return false
	end

	return settings.hidingFilters
end

function setHidingFilters(state)
	settings = {}
	settings.hidingFilters = state

	g_settings.mergeNode("BattleList", settings)
end

function hideFilterPanel()
	local mainInstance = BattleListManager:getMainInstance()

	if mainInstance then
		mainInstance:hideFilterPanel()
	end
end

function showFilterPanel()
	local mainInstance = BattleListManager:getMainInstance()

	if mainInstance then
		mainInstance:showFilterPanel()
	end
end

function toggleFilterPanel()
	local mainInstance = BattleListManager:getMainInstance()

	if mainInstance then
		mainInstance:toggleFilterPanel()
	end
end

function attackNext(previous)
	if not g_game.isOnline() then
		return false
	end

	if not eventsConnected then
		connecting()
	end

	local mainInstance = BattleListManager.instances[0]

	if not mainInstance then
		return false
	end

	if not mainInstance.binaryTree or #mainInstance.binaryTree == 0 then
		mainInstance:checkCreatures()
	end

	local foundTarget = false
	local firstElement, lastElement, prevElement, nextElement
	local sortOrder = mainInstance:getSortOrder()
	local start = sortOrder == "A" and 1 or #mainInstance.binaryTree
	local finish = #mainInstance.binaryTree - start + 1
	local increment = start <= finish and 1 or -1

	for i = start, finish, increment do
		local entry = mainInstance.binaryTree[i]
		local battleButton = entry and mainInstance.battleButtons[entry.id]

		if battleButton and battleButton.creature and canBeSeen(battleButton.creature) then
			firstElement = firstElement or battleButton
			lastElement = battleButton

			if battleButton.isTarget then
				foundTarget = true
			elseif foundTarget and not nextElement then
				nextElement = battleButton
			elseif not foundTarget then
				prevElement = battleButton
			end
		end
	end

	if foundTarget then
		if previous then
			if prevElement then
				g_game.attack(prevElement.creature)
			else
				g_game.attack(lastElement.creature)
			end
		elseif nextElement then
			g_game.attack(nextElement.creature)
		else
			g_game.attack(firstElement.creature)
		end
	elseif firstElement then
		g_game.attack(firstElement.creature)
	else
		return false
	end

	return true
end

function onAttack(creature)
	for _, instance in pairs(BattleListManager.instances) do
		if creature then
			local battleButton = instance.battleButtons[creature:getId()]

			if battleButton then
				for _, otherBattleButton in pairs(instance.battleButtons) do
					local isTarget = otherBattleButton == battleButton

					if otherBattleButton.isTarget ~= isTarget then
						otherBattleButton.isTarget = isTarget

						updateBattleButton(otherBattleButton)
					end
				end
			end
		else
			for _, battleButton in pairs(instance.battleButtons) do
				if battleButton.isTarget then
					battleButton.isTarget = false

					updateBattleButton(battleButton)
				end
			end
		end
	end
end

function onFollow(creature)
	for _, instance in pairs(BattleListManager.instances) do
		for _, battleButton in pairs(instance.battleButtons) do
			local isFollowed = creature and battleButton.creature == creature or false

			if battleButton.isFollowed ~= isFollowed then
				battleButton.isFollowed = isFollowed

				updateBattleButton(battleButton)
			end
		end
	end
end

function onCreatureOutfitChange(creature, outfit, oldOutfit)
	for _, instance in pairs(BattleListManager.instances) do
		local battleButton = instance.battleButtons[creature:getId()]
		local fit = instance:doCreatureFitFilters(creature)

		if battleButton ~= nil and not fit then
			instance:removeCreature(creature)
		elseif battleButton == nil and fit then
			instance:addCreature(creature)
		end
	end
end

function updateCreatureSkull(creature, skullId)
	for _, instance in pairs(BattleListManager.instances) do
		local battleButton = instance.battleButtons[creature:getId()]

		if battleButton then
			battleButton:updateSkull(skullId)
		end
	end
end

function updateCreatureEmblem(creature, emblemId)
	for _, instance in pairs(BattleListManager.instances) do
		local battleButton = instance.battleButtons[creature:getId()]

		if battleButton then
			battleButton:updateEmblem(emblemId)
		end
	end
end

function onCreaturePositionChange(creature, newPos, oldPos)
	local localPlayer = g_game.getLocalPlayer()

	if not localPlayer then
		return false
	end

	local position = localPlayer:getPosition()

	if not position then
		return false
	end

	for _, instance in pairs(BattleListManager.instances) do
		if instance.panel then
			instance.panel:disableUpdateTemporarily()

			local sortType = instance:getSortType()

			if creature:isLocalPlayer() then
				if oldPos and newPos and newPos.z ~= oldPos.z then
					addEvent(function()
						instance:checkCreatures()
					end)
				elseif oldPos and newPos and (newPos.x ~= oldPos.x or newPos.y ~= oldPos.y) then
					if #instance.binaryTree > 0 and sortType == "distance" then
						for i, v in ipairs(instance.binaryTree) do
							local oldDistance = v.distance
							local battleButton = instance.battleButtons[v.id]
							local mob = battleButton.creature or g_map.getCreatureById(v.id)
							local newDistance = getDistanceBetween(newPos, mob:getPosition())

							if oldDistance ~= newDistance then
								v.distance = newDistance
								battleButton.data.distance = newDistance
							end
						end

						table.sort(instance.binaryTree, function(a, b)
							return BSComparatorSortType(a, b, "distance", true) == 1
						end)
						instance:correctBattleButtons()
					end

					for i, v in pairs(instance.battleButtons) do
						local mob = v.creature

						if mob and mob:getPosition() then
							v:setVisible(canBeSeen(mob))
						end
					end
				end
			else
				local creatureId = creature:getId()
				local battleButton = instance.battleButtons[creatureId]
				local fit = instance:doCreatureFitFilters(creature)

				if battleButton == nil then
					if fit then
						instance:addCreature(creature, sortType)
					end
				elseif not fit and newPos then
					instance:removeCreature(creature)
				elseif fit then
					if oldPos and newPos and (newPos.x ~= oldPos.x or newPos.y ~= oldPos.y) and sortType == "distance" then
						local localPlayer = g_game.getLocalPlayer()
						local newDistance = getDistanceBetween(localPlayer:getPosition(), newPos)
						local oldDistance = battleButton.data.distance
						local index = binarySearch(instance.binaryTree, {
							distance = oldDistance,
							id = creatureId
						}, BSComparatorSortType, "distance", true)

						if index ~= nil and creatureId == instance.binaryTree[index].id then
							instance.binaryTree[index].distance = newDistance
							battleButton.data.distance = newDistance

							if oldDistance < newDistance then
								if index < #instance.binaryTree then
									for i = index, #instance.binaryTree - 1 do
										local a = instance.binaryTree[i]
										local b = instance.binaryTree[i + 1]

										if a.distance > b.distance or a.distance == b.distance and a.id > b.id then
											instance:swap(i, i + 1)
										end
									end
								end
							elseif newDistance < oldDistance then
								battleButton:setVisible(canBeSeen(creature))

								if index > 1 then
									for i = index, 2, -1 do
										local a = instance.binaryTree[i - 1]
										local b = instance.binaryTree[i]

										if a.distance > b.distance or a.distance == b.distance and a.id > b.id then
											instance:swap(i - 1, i)
										end
									end
								end
							end

							instance:correctBattleButtons()
						else
							assert(index ~= nil, "Not able to update Position Change. Creature: " .. creature:getName() .. " id " .. creatureId .. " not found in binary search using " .. sortType .. " to find value " .. oldDistance .. ".\n")
						end
					end

					instance:addCreature(creature)
				end
			end
		end
	end
end

function onCreatureHealthPercentChange(creature, healthPercent, oldHealthPercent)
	for _, instance in pairs(BattleListManager.instances) do
		do
			local creatureId = creature:getId()
			local battleButton = instance.battleButtons[creatureId]

			if battleButton then
				local sortType = instance:getSortType()
				local newHealthPercent = healthPercent or 0
				local previousHealthPercent = oldHealthPercent

				if previousHealthPercent == nil and battleButton.data then
					previousHealthPercent = battleButton.data.healthpercent
				end

				if previousHealthPercent == nil then
					previousHealthPercent = newHealthPercent
				end

				if newHealthPercent <= 0 then
					instance:removeCreature(creature)
				else
					if battleButton.setLifeBarPercent then
						battleButton:setLifeBarPercent(newHealthPercent)
					end

					if battleButton.data then
						battleButton.data.healthpercent = newHealthPercent
					end

					if sortType == "health" then
						if newHealthPercent == previousHealthPercent then
							goto label_164_0
						end

						local index = binarySearch(instance.binaryTree, {
							healthpercent = previousHealthPercent,
							id = creatureId
						}, BSComparatorSortType, "health", true)

						if index ~= nil and creatureId == instance.binaryTree[index].id then
							instance.binaryTree[index].healthpercent = newHealthPercent

							if previousHealthPercent < newHealthPercent then
								if index < #instance.binaryTree then
									for i = index, #instance.binaryTree - 1 do
										local a = instance.binaryTree[i]
										local b = instance.binaryTree[i + 1]

										if a.healthpercent > b.healthpercent or a.healthpercent == b.healthpercent and a.id > b.id then
											local tmp = instance.binaryTree[i]

											instance.binaryTree[i] = instance.binaryTree[i + 1]
											instance.binaryTree[i + 1] = tmp
										end
									end
								end
							elseif newHealthPercent < previousHealthPercent and index > 1 then
								for i = index, 2, -1 do
									local a = instance.binaryTree[i - 1]
									local b = instance.binaryTree[i]

									if a.healthpercent > b.healthpercent or a.healthpercent == b.healthpercent and a.id > b.id then
										local tmp = instance.binaryTree[i - 1]

										instance.binaryTree[i - 1] = instance.binaryTree[i]
										instance.binaryTree[i] = tmp
									end
								end
							end

							instance:correctBattleButtons()
						end
					end

					if battleButton.creature then
						battleButton:update()
					end
				end
			end
		end

		::label_164_0::
	end
end

function onCreatureAppear(creature)
	if creature:isLocalPlayer() then
		addEvent(updateStaticSquare)
	end

	for _, instance in pairs(BattleListManager.instances) do
		local sortType = instance:getSortType()

		if instance:doCreatureFitFilters(creature) then
			instance:addCreature(creature, sortType)
		end
	end
end

function onCreatureDisappear(creature)
	for _, instance in pairs(BattleListManager.instances) do
		instance:removeCreature(creature)
	end
end

function onBattleButtonMousePress(self, mousePosition, mouseButton)
	if mouseButton == MouseRightButton and not g_mouse.isPressed(MouseLeftButton) and self.creature then
		modules.game_interface.createBattleListCreatureMenu(mousePosition, self.creature)

		return true
	end

	return false
end

function onBattleButtonMouseRelease(self, mousePosition, mouseButton)
	if mouseWidget.cancelNextRelease then
		mouseWidget.cancelNextRelease = false

		return false
	end

	if g_mouse.isPressed(MouseLeftButton) and mouseButton == MouseRightButton or g_mouse.isPressed(MouseRightButton) and mouseButton == MouseLeftButton then
		mouseWidget.cancelNextRelease = true

		g_game.look(self.creature, true)

		return true
	elseif mouseButton == MouseLeftButton and g_keyboard.isShiftPressed() then
		g_game.look(self.creature, true)

		return true
	elseif mouseButton == MouseLeftButton and not g_mouse.isPressed(MouseRightButton) then
		if self.isTarget then
			g_game.cancelAttack()
		else
			g_game.attack(self.creature)
		end

		return true
	end

	return false
end

function updateStaticSquare(battleButton)
	if g_game.refreshAttackTargetMarks then
		g_game.refreshAttackTargetMarks()
	end

	for _, instance in pairs(BattleListManager.instances) do
		for _, battleButton in pairs(instance.battleButtons) do
			if battleButton.isTarget and battleButton.creature then
				battleButton:update()
			end
		end
	end
end

function updateBattleButton(battleButton)
	if not battleButton or not battleButton.creature then
		return
	end

	battleButton:update()

	if battleButton.isTarget then
		local currentCreatureId = battleButton.creature:getId()

		for _, instance in pairs(BattleListManager.instances) do
			for _, otherBattleButton in pairs(instance.battleButtons) do
				if otherBattleButton ~= battleButton and otherBattleButton.isTarget and otherBattleButton.creature and otherBattleButton.creature:getId() ~= currentCreatureId then
					otherBattleButton.isTarget = false

					otherBattleButton:update()
				end
			end
		end

		lastBattleButtonSwitched = battleButton
	end

	if battleButton.isFollowed then
		local currentCreatureId = battleButton.creature:getId()

		for _, instance in pairs(BattleListManager.instances) do
			for _, otherBattleButton in pairs(instance.battleButtons) do
				if otherBattleButton ~= battleButton and otherBattleButton.isFollowed and otherBattleButton.creature and otherBattleButton.creature:getId() ~= currentCreatureId then
					otherBattleButton.isFollowed = false

					otherBattleButton:update()
				end
			end
		end

		lastBattleButtonSwitched = battleButton
	end

	if lastBattleButtonSwitched and not lastBattleButtonSwitched.creature then
		lastBattleButtonSwitched = nil
	end
end

function onBattleButtonHoverChange(battleButton, hovered)
	if battleButton.isBattleButton then
		CreatureList.onButtonHoverChange(battleButton, hovered)
	end
end

function onHoveredCreatureChange(creature)
	CreatureList.syncHoveredCreature(BattleListManager, creature)
end

function syncBattleMainPanelButton()
	if SidebarWidgetOptions and SidebarWidgetOptions.syncToggleButton then
		SidebarWidgetOptions.syncToggleButton(battleWindow, battleButton, "Open Battle List", "Close Battle List")

		return
	end

	if not battleButton or battleButton:isDestroyed() then
		return
	end

	local on = false

	if battleWindow and not battleWindow:isDestroyed() then
		on = battleWindow:isVisible()
	end

	battleButton:setOn(on)

	if battleButton.setTooltip then
		battleButton:setTooltip(tr(on and "Close Battle List" or "Open Battle List"))
	end
end

function onOpen()
	syncBattleMainPanelButton()
	connecting()

	local mainInstance = BattleListManager.instances[0]

	if mainInstance then
		local filters = mainInstance:loadFilters()
		local hasAnySortFilter = false

		for filterName, isActive in pairs(filters) do
			if isActive and (filterName:find("sortAscBy") or filterName:find("sortDescBy")) then
				hasAnySortFilter = true

				break
			end
		end

		if not hasAnySortFilter then
			filters.sortAscByDisplayTime = true

			g_settings.mergeNode(mainInstance:getSettingsKey(), {
				filters = filters
			})
			scheduleEvent(function()
				mainInstance:checkCreatures()
			end, 100)
		end
	end
end

function onClose()
	syncBattleMainPanelButton()
end

function toggle()
	if battleButton:isOn() then
		battleWindow:closeAndForgetLayout()
	else
		if g_game.isOnline() then
			connecting()
		end

		if not battleWindow:getParent() then
			local panel = modules.game_interface.findContentPanelAvailable(battleWindow, battleWindow:getMinimumHeight())

			if not panel then
				return
			end

			panel:addChild(battleWindow)
		end

		battleWindow:open()
		battleWindow:saveParent()
	end

	syncBattleMainPanelButton()
end

function getBattleListManager()
	return BattleListManager
end

function terminate()
	BattleListManager:saveInstancesState()

	local mainInstance = BattleListManager.instances[0]

	if mainInstance then
		mainInstance:saveLockState()
		mainInstance:saveFilters()
		mainInstance:saveHideButtonStates()
	end

	for _, instance in pairs(BattleListManager.instances) do
		instance:destroy(true)
	end

	BattleListManager.instances = {}
	binaryTree = {}
	battleButtons = {}
	hideButtons = {}

	if battleButton then
		battleButton:destroy()

		battleButton = nil
	end

	if battleWindow then
		battleWindow:destroy()

		battleWindow = nil
	end

	if mouseWidget then
		mouseWidget:destroy()

		mouseWidget = nil
	end

	battlePanel = nil
	battleButton = nil
	battleWindow = nil
	mouseWidget = nil
	filterPanel = nil
	toggleFilterButton = nil

	Keybind.delete("Windows", "Show/hide battle list")
	Keybind.delete("Battle List", "Attack Next Target")
	disconnect(g_game, {
		onAttackingCreatureChange = onAttack,
		onFollowingCreatureChange = onFollow,
		onHoveredCreatureChange = onHoveredCreatureChange,
		onGameEnd = onGameEnd,
		onGameStart = onGameStart
	})
	disconnecting()

	eventsConnected = false
end
