-- chunkname: @/game_spelllist/spelllist.lua

t_spelllist = nil

local function getSpellListToggleButton()
	if modules.game_mainpanel and modules.game_mainpanel.getButton then
		local b = modules.game_mainpanel.getButton("spellListWidget")

		if b and not b:isDestroyed() then
			return b
		end
	end

	if modules.client_topmenu and modules.client_topmenu.getButton then
		local b = modules.client_topmenu.getButton("spellListWidget")

		if b and not b:isDestroyed() then
			return b
		end
	end

	return nil
end

local function syncSpellListButton()
	local btn = getSpellListToggleButton()

	if not btn then
		return
	end

	local on = false

	if t_spelllist and not t_spelllist:isDestroyed() then
		on = t_spelllist:isVisible()
	end

	btn:setOn(on)

	if btn.setTooltip then
		btn:setTooltip(tr(on and "Close Spell List" or "Open Spell List"))
	end
end

local spellListData = {}
local rootPanel, lastHighlightWidget, spellDragPreview, spellDragContext
local spellListConfig = {}
local player
local searchFilterText = ""
local spellListSearchActive = false
local spellListSearchOutsideHandler, selectedSpellData
local dropInWidgetsPatterns = {
	"^item$",
	"^spellButton%d*$",
	"^attackSpellButton%d*$",
	"^spellTrainingButton%d*$",
	"^hasteButton%d*$"
}

local function matchesPattern(id, patterns)
	for _, pattern in ipairs(patterns) do
		if string.match(id, pattern) then
			return true
		end
	end

	return false
end

local function getDragRoot()
	if rootPanel and not rootPanel:isDestroyed() then
		return rootPanel
	end

	if modules.game_interface and modules.game_interface.getRootPanel then
		return modules.game_interface.getRootPanel()
	end

	return g_ui.getRootWidget()
end

local function findActionSlotWidget(widget)
	local current = widget

	while current do
		if current:getClassName() == "UIActionSlot" then
			return current
		end

		current = current:getParent()
	end

	return nil
end

local function getMultiActionDropContext(actionSlot)
	if not actionSlot or actionSlot:isDestroyed() then
		return nil, nil
	end

	if actionSlot.multiActionIndex and actionSlot.parentSlot and not actionSlot.parentSlot:isDestroyed() then
		return actionSlot.parentSlot, actionSlot.multiActionIndex
	end

	return nil, nil
end

local function resetSpellDropHighlight()
	if not lastHighlightWidget or lastHighlightWidget:isDestroyed() then
		lastHighlightWidget = nil

		return
	end

	if lastHighlightWidget:getId() == "item" then
		lastHighlightWidget:setBorderWidth(0)
		lastHighlightWidget:setBorderColor("alpha")
	else
		lastHighlightWidget:setBorderColorTop("#1b1b1b")
		lastHighlightWidget:setBorderColorLeft("#1b1b1b")
		lastHighlightWidget:setBorderColorRight("#757575")
		lastHighlightWidget:setBorderColorBottom("#757575")
		lastHighlightWidget:setBorderWidth(1)
	end

	lastHighlightWidget = nil
end

local function ensureSpellDragPreview()
	if spellDragPreview and not spellDragPreview:isDestroyed() then
		return spellDragPreview
	end

	spellDragPreview = g_ui.createWidget("DraggableSpellIcon", g_ui.getRootWidget())

	spellDragPreview:setId("spellListDragPreview")
	spellDragPreview:setPhantom(true)
	spellDragPreview:setDraggable(false)
	spellDragPreview:setFocusable(false)
	spellDragPreview:setVisible(false)

	return spellDragPreview
end

local function destroySpellDragPreview()
	if spellDragPreview and not spellDragPreview:isDestroyed() then
		spellDragPreview:destroy()
	end

	spellDragPreview = nil
end

local function updateSpellDragPreviewPosition(mousePos)
	if not spellDragPreview or spellDragPreview:isDestroyed() or not mousePos then
		return
	end

	local size = spellDragPreview:getSize()
	local w = size and size.width or 32
	local h = size and size.height or 32

	spellDragPreview:setPosition({
		x = mousePos.x - math.floor(w / 2),
		y = mousePos.y - math.floor(h / 2)
	})
	spellDragPreview:raise()
end

local function updateSpellDropHighlight(mousePos)
	local dragRoot = getDragRoot()

	if not dragRoot then
		resetSpellDropHighlight()

		return nil
	end

	local clickedWidget = dragRoot:recursiveGetChildByPos(mousePos, false)
	local dropTarget

	if clickedWidget then
		local actionSlot = findActionSlotWidget(clickedWidget)

		if actionSlot then
			dropTarget = actionSlot
		elseif matchesPattern(clickedWidget:getId(), dropInWidgetsPatterns) then
			dropTarget = clickedWidget
		end
	end

	if lastHighlightWidget == dropTarget then
		return dropTarget
	end

	resetSpellDropHighlight()

	if dropTarget then
		lastHighlightWidget = dropTarget

		lastHighlightWidget:setBorderWidth(1)
		lastHighlightWidget:setBorderColor("white")
	end

	return dropTarget
end

local function assignSpellToDropTarget(words, targetWidget)
	if not words or not targetWidget or targetWidget:isDestroyed() then
		return false
	end

	local actionSlot = findActionSlotWidget(targetWidget)

	if actionSlot then
		local actionbar = modules.game_actionbar

		if not actionbar then
			return false
		end

		local spell = Spells.getSpellByWords(words)

		if not spell then
			return false
		end

		local parentSlot, multiIndex = getMultiActionDropContext(actionSlot)

		if parentSlot then
			if spell.parameter then
				if actionbar.openSpellAssignWindowForDraggedSpell then
					actionbar.openSpellAssignWindowForDraggedSpell(parentSlot:getId(), words, multiIndex)
				end

				return true
			end

			if actionbar.commitMultiActionSubEntry then
				actionbar.commitMultiActionSubEntry(parentSlot, multiIndex, {
					autoSend = true,
					words = spell.words
				})

				return true
			end

			return false
		end

		if spell.parameter then
			if actionbar.openSpellAssignWindowForDraggedSpell then
				actionbar.openSpellAssignWindowForDraggedSpell(actionSlot:getId(), words)

				return true
			end

			return false
		end

		if actionbar.clearSlotActionContent then
			actionbar.clearSlotActionContent(actionSlot)
		end

		actionSlot.words = spell.words
		actionSlot.itemId = 469

		actionSlot:setItemId(469)

		actionSlot.parameter = nil

		if actionbar.loadSpell then
			actionbar.loadSpell(actionSlot)
		end

		if actionbar.saveActionBar then
			actionbar.saveActionBar()
		end

		return true
	end

	if matchesPattern(targetWidget:getId(), dropInWidgetsPatterns) then
		local helper = modules.game_helper

		if helper and type(helper.onDropSpell) == "function" then
			helper.onDropSpell(targetWidget, words)

			return true
		end
	end

	return false
end

local function cleanupSpellDrag()
	destroySpellDragPreview()

	if spellDragContext and spellDragContext.source and not spellDragContext.source:isDestroyed() then
		spellDragContext.source:setVisible(true)
	end

	spellDragContext = nil
end

local function setupSpellDragHandlers(dragImage, listRowWidget)
	function dragImage:onDragEnter(mousePos)
		spellDragContext = {
			source = self,
			listRow = listRowWidget,
			words = self.words
		}

		self:setVisible(false)

		local preview = ensureSpellDragPreview()

		preview:setImageSource(self:getImageSource())
		preview:setImageClip(self:getImageClip())
		preview:setVisible(true)
		updateSpellDragPreviewPosition(mousePos)
		updateSpellDropHighlight(mousePos)

		return true
	end

	function dragImage:onDragMove(mousePos)
		updateSpellDragPreviewPosition(mousePos)
		updateSpellDropHighlight(mousePos)

		return true
	end

	function dragImage:onDragLeave(droppedWidget, mousePos)
		local words = spellDragContext and spellDragContext.words or self.words
		local dropTarget = lastHighlightWidget

		cleanupSpellDrag()

		if dropTarget and not dropTarget:isDestroyed() then
			assignSpellToDropTarget(words, dropTarget)
		end

		resetSpellDropHighlight()

		return true
	end
end

local function isWidgetInSpellListSearch(widget)
	if not widget or not t_spelllist or t_spelllist:isDestroyed() then
		return false
	end

	local searchRow = t_spelllist:recursiveGetChildById("searchRow")

	if not searchRow or searchRow:isDestroyed() then
		return false
	end

	local current = widget

	while current do
		if current == searchRow then
			return true
		end

		if current == t_spelllist then
			return false
		end

		current = current:getParent()
	end

	return false
end

local function unregisterSpellListSearchOutsideClick()
	if not spellListSearchOutsideHandler then
		return
	end

	local root = g_ui.getRootWidget()

	if root and not root:isDestroyed() then
		disconnect(root, spellListSearchOutsideHandler)
	end

	spellListSearchOutsideHandler = nil
end

local function setSpellListSearchVisual(active)
	if not t_spelllist or t_spelllist:isDestroyed() then
		return
	end

	if active then
		t_spelllist:setBorderWidth(2)
		t_spelllist:setBorderColor("white")
	else
		t_spelllist:setBorderWidth(0)
	end
end

local function resetSpellListSearchState()
	spellListSearchActive = false

	unregisterSpellListSearchOutsideClick()
	setSpellListSearchVisual(false)

	if not t_spelllist or t_spelllist:isDestroyed() then
		return
	end

	pcall(function()
		t_spelllist:ungrabKeyboard()
	end)

	local search = t_spelllist:recursiveGetChildById("searchEdit")

	if search and not search:isDestroyed() then
		search:setCursorVisible(false)
	end
end

local function blurSpellListSearch()
	if not spellListSearchActive then
		return
	end

	resetSpellListSearchState()

	local root = getDragRoot()

	if root and not root:isDestroyed() then
		root:focus()
	end
end

local function registerSpellListSearchOutsideClick()
	unregisterSpellListSearchOutsideClick()

	local root = g_ui.getRootWidget()

	if not root or root:isDestroyed() then
		return
	end

	spellListSearchOutsideHandler = {
		onMousePress = function(rootWidget, mousePos, mouseButton)
			if not spellListSearchActive or mouseButton ~= MouseLeftButton then
				return false
			end

			local clicked = rootWidget:recursiveGetChildByPos(mousePos, false)

			if not isWidgetInSpellListSearch(clicked) then
				blurSpellListSearch()
			end

			return false
		end
	}

	connect(root, spellListSearchOutsideHandler)
end

local function applySpellListSearchFocus(moveCursorToEnd)
	if not spellListSearchActive or not t_spelllist or t_spelllist:isDestroyed() then
		return
	end

	local searchRow = t_spelllist:recursiveGetChildById("searchRow")
	local search = t_spelllist:recursiveGetChildById("searchEdit")

	if not search or search:isDestroyed() then
		return
	end

	local parent = t_spelllist:getParent()
	local dockedInSidebar = parent and not parent:isDestroyed() and parent:getClassName() == "UIMiniWindowContainer"

	if not dockedInSidebar then
		t_spelllist:raise()
	end

	t_spelllist:focus()
	pcall(function()
		t_spelllist:grabKeyboard()
	end)

	if searchRow and not searchRow:isDestroyed() then
		t_spelllist:focusChild(searchRow, KeyboardFocusReason)
		searchRow:focusChild(search, KeyboardFocusReason)
	else
		t_spelllist:focusChild(search, KeyboardFocusReason)
		search:focus()
	end

	search:setCursorVisible(true)
	search:blinkCursor()

	if moveCursorToEnd then
		search:setCursorPos(-1)
	end
end

local function focusSpellListSearch(moveCursorToEnd)
	if not t_spelllist or t_spelllist:isDestroyed() then
		return
	end

	local search = t_spelllist:recursiveGetChildById("searchEdit")

	if not search or search:isDestroyed() then
		return
	end

	spellListSearchActive = true

	setSpellListSearchVisual(true)
	registerSpellListSearchOutsideClick()
	applySpellListSearchFocus(moveCursorToEnd)
	scheduleEvent(function()
		applySpellListSearchFocus(moveCursorToEnd)
	end, 50)
end

local function setupSearchField()
	if not t_spelllist or t_spelllist:isDestroyed() then
		return
	end

	local searchRow = t_spelllist:recursiveGetChildById("searchRow")
	local search = t_spelllist:recursiveGetChildById("searchEdit")
	local clearBtn = t_spelllist:recursiveGetChildById("searchClearButton")

	if search then
		function search:onMousePress(mousePos, button)
			if button == MouseLeftButton then
				focusSpellListSearch(false)
			end

			return false
		end
	end

	if searchRow then
		searchRow:raise()
	end

	if clearBtn then
		clearBtn:raise()
	end

	if search then
		search:setCursorVisible(false)
	end
end

function onSearchEditClick()
	focusSpellListSearch(true)
end

function init()
	t_spelllist = g_ui.displayUI("spelllist")

	t_spelllist:setup()
	t_spelllist:hide()
	addEvent(setupSearchField)
	connect(g_game, {
		onGameStart = online,
		onGameEnd = offline
	})
	connect(LocalPlayer, {
		onSpellsChange = onSpellsChange,
		onLevelChange = onLevelChange
	})

	modules.game_spelllist = modules.game_spelllist or {}
	modules.game_spelllist.toggle = toggle
	modules.game_spelllist.refreshVirtueYellowBorders = refreshVirtueYellowBorders

	syncSpellListButton()
end

function terminate()
	cleanupSpellDrag()
	resetSpellDropHighlight()
	blurSpellListSearch()

	if t_spelllist then
		t_spelllist:destroy()

		t_spelllist = nil
	end

	disconnect(g_game, {
		onGameStart = online,
		onGameEnd = offline
	})
	disconnect(LocalPlayer, {
		onSpellsChange = onSpellsChange,
		onLevelChange = onLevelChange
	})

	if modules.game_spelllist then
		modules.game_spelllist.toggle = nil
	end
end

local function spellListMinHeightForPanel()
	local h = t_spelllist:getMinimumHeight()

	if not h or h <= 0 then
		return math.max(t_spelllist:getHeight(), 180)
	end

	return h
end

local function ensureSpellListMinHeight()
	if not t_spelllist or t_spelllist:isDestroyed() or t_spelllist:isOn() then
		return
	end

	local minHeight = t_spelllist:getMinimumHeight()

	if minHeight and minHeight > 0 and minHeight > t_spelllist:getHeight() then
		t_spelllist:setHeight(minHeight)
	end
end

local function ensureSpellListDocked()
	if not t_spelllist or t_spelllist:isDestroyed() then
		return
	end

	local root = g_ui.getRootWidget()
	local parent = t_spelllist:getParent()
	local docked = parent and parent ~= root and parent:getClassName() == "UIMiniWindowContainer"

	if docked then
		return
	end

	local panel = modules.game_interface.findContentPanelAvailable(t_spelllist, spellListMinHeightForPanel())

	panel = panel or modules.game_interface.getRightPanel()

	if not panel then
		return
	end

	panel:addChild(t_spelllist)

	if t_spelllist.fitOnParent then
		t_spelllist:fitOnParent()
	end
end

function toggle()
	if t_spelllist:isVisible() then
		t_spelllist:closeAndForgetLayout()
		syncSpellListButton()
	else
		ensureSpellListMinHeight()

		local parent = t_spelllist:getParent()
		local root = g_ui.getRootWidget()
		local docked = parent and parent ~= root and parent:getClassName() == "UIMiniWindowContainer"

		if not docked then
			local panel = modules.game_interface.findContentPanelAvailable(t_spelllist, spellListMinHeightForPanel())

			panel = panel or modules.game_interface.getRightPanel()

			if not panel then
				return
			end

			panel:addChild(t_spelllist)
		end

		t_spelllist:open()
		syncSpellListButton()
	end
end

function online()
	rootPanel = modules.game_interface.getRootPanel()
	player = g_game.getLocalPlayer()
	spellListConfig = {}

	if SidebarPersistence and SidebarPersistence.getSection then
		local section = SidebarPersistence.getSection("spellListWidgetOptions")

		if type(section) == "table" then
			for k, v in pairs(section) do
				if k ~= "contentHeight" and k ~= "contentMaximized" and k ~= "_jsonKeyOrder" then
					spellListConfig[k] = v
				end
			end
		end
	end

	local defaults = {
		showRuneSpells = true,
		showUnkownSpells = true,
		showSupportSpellGroup = true,
		showMonkSpells = true,
		showSorcererSpells = true,
		showPaladinSpells = true,
		showOnlyCurrentVocation = false,
		showOnlyCurrentLevel = false,
		showKnightSpells = true,
		showHealingSpellGroup = true,
		showDruidSpells = true,
		showAttackSpellGroup = true,
		showInstantSpells = true
	}

	for k, v in pairs(defaults) do
		if spellListConfig[k] == nil then
			spellListConfig[k] = v
		end
	end

	onConfigureList()

	if t_spelllist then
		t_spelllist:setupOnStart()
		ensureSpellListDocked()
		scheduleEvent(ensureSpellListDocked, 50)
		scheduleEvent(ensureSpellListDocked, 250)
		scheduleEvent(ensureSpellListMinHeight, 50)
	end

	syncSpellListButton()
	scheduleEvent(syncSpellListButton, 100)
	scheduleEvent(resetSpellListSearchState, 100)
	scheduleEvent(resetSpellListSearchState, 300)
end

function offline()
	spellListData = {}
	rootPanel = nil

	cleanupSpellDrag()
	resetSpellDropHighlight()
	blurSpellListSearch()

	if SidebarPersistence and SidebarPersistence.active and type(SidebarPersistence.document) == "table" then
		local section = SidebarPersistence.document.spellListWidgetOptions

		if type(section) ~= "table" then
			section = {}
			SidebarPersistence.document.spellListWidgetOptions = section
		end

		for k, v in pairs(spellListConfig) do
			section[k] = v
		end
	end

	spellListConfig = {}

	if t_spelllist then
		t_spelllist:close(true)
	end
end

function onSpellListWindowOpen()
	setupSearchField()
	resetSpellListSearchState()
	ensureSpellListMinHeight()
	syncSpellListButton()
end

function onSpellListWindowClose()
	blurSpellListSearch()
	syncSpellListButton()
end

function onSearchTextChange(widget)
	searchFilterText = widget:getText()

	onConfigureList()
end

function onSearchClear()
	if not t_spelllist or t_spelllist:isDestroyed() then
		return
	end

	local search = t_spelllist:recursiveGetChildById("searchEdit")

	if not search then
		return
	end

	search:setText("")
	onSearchTextChange(search)

	if spellListSearchActive then
		applySpellListSearchFocus(true)
	end
end

function move(panel, height, minimized)
	t_spelllist:setParent(panel)
	t_spelllist:open()

	if minimized then
		t_spelllist:setHeight(height)
		t_spelllist:minimize()
	else
		t_spelllist:maximize()
		t_spelllist:setHeight(height)
	end

	return t_spelllist
end

function getSpellListData()
	return spellListData
end

function onSpellsChange(player, list)
	spellListData = {}

	for _, spellId in pairs(list) do
		local spell = Spells.getSpellByClientId(spellId)

		if spell then
			spell.name = Spells.getSpellNameByWords(spell.words)
			spellListData[tostring(spellId)] = spell
		end
	end

	if not table.empty(spellListData) then
		onConfigureList()
	end
end

function onUpdateSpellListLevel()
	local player = g_game.getLocalPlayer()
	local list = t_spelllist:recursiveGetChildById("contentsPanel")

	for _, widget in pairs(list:getChildren()) do
		local disabled = widget:recursiveGetChildById("gray")

		disabled:setVisible(player:getLevel() < widget.spellData.level)
	end
end

local function getSpellsSortedByName()
	local sorted = {}

	for _, spell in pairs(spellListData) do
		sorted[#sorted + 1] = spell
	end

	table.sort(sorted, function(a, b)
		return (a.name or ""):lower() < (b.name or ""):lower()
	end)

	return sorted
end

local VIRTUE_YELLOW_BORDER_IMAGE = "/assets/images/game/actionbar/border_activespell"

local function spellMatchesVirtueBorder(spell)
	if not spell then
		return false
	end

	local actionBar = modules.game_actionbar

	if actionBar and actionBar.slotSpellMatchesVirtueBorder then
		return actionBar.slotSpellMatchesVirtueBorder(spell)
	end

	return false
end

function refreshVirtueYellowBorders()
	if not t_spelllist or t_spelllist:isDestroyed() then
		return
	end

	local list = t_spelllist:recursiveGetChildById("contentsPanel")

	if not list then
		return
	end

	for _, widget in pairs(list:getChildren()) do
		local overlay = widget:recursiveGetChildById("activeSpell")

		if overlay and widget.spellData then
			if spellMatchesVirtueBorder(widget.spellData) then
				overlay:setImageSource(VIRTUE_YELLOW_BORDER_IMAGE)
				overlay:show()

				if overlay.raise then
					overlay:raise()
				end
			else
				overlay:hide()
			end
		end
	end
end

function onConfigureList()
	local player = g_game.getLocalPlayer()
	local list = t_spelllist:recursiveGetChildById("contentsPanel")

	list.onChildFocusChange = nil

	list:destroyChildren()

	for _, spell in ipairs(getSpellsSortedByName()) do
		if not matchFilter(spell) then
			-- block empty
		else
			local icon = SpellIcons[spell.id]

			if not icon then
				-- block empty
			else
				local widget = g_ui.createWidget("SpellListData", list)
				local image = widget:recursiveGetChildById("fixedImage")
				local dragImage = widget:recursiveGetChildById("moveableImage")
				local name = widget:recursiveGetChildById("name")
				local words = widget:recursiveGetChildById("words")
				local disabled = widget:recursiveGetChildById("gray")

				setupSpellDragHandlers(dragImage, widget)

				widget.spellData = spell
				dragImage.words = spell.words

				local clip = Spells.getImageClipNormal(icon, "Default")

				image:setImageClip(clip)
				dragImage:setImageClip(clip)
				name:setText(short_text(spell.name, 15))

				if #spell.name > 15 then
					name:setTooltip(spell.name)
				end

				words:setText(short_text(spell.words, 17))

				if #spell.words > 17 then
					words:setTooltip(spell.words)
				end

				disabled:setVisible(player:getLevel() < spell.level)
			end
		end
	end

	refreshVirtueYellowBorders()
	onSelectedSpell(list, list:getFirstChild(), nil)

	list.onChildFocusChange = onSelectedSpell
end

local function updateShowMoreButton(enabled)
	if not t_spelllist or t_spelllist:isDestroyed() then
		return
	end

	local showMoreButton = t_spelllist:recursiveGetChildById("showMoreButton")

	if showMoreButton then
		showMoreButton:setEnabled(enabled == true)
	end
end

function onSelectedSpell(list, focused, oldFocus)
	if not focused then
		selectedSpellData = nil

		updateShowMoreButton(false)

		return
	end

	selectedSpellData = focused.spellData

	updateShowMoreButton(selectedSpellData ~= nil)

	if oldFocus then
		oldFocus:setBackgroundColor("alpha")
		oldFocus:recursiveGetChildById("words"):setColor("#c0c0c0")
		oldFocus:recursiveGetChildById("name"):setColor("#c0c0c0")
	end

	focused:setBackgroundColor("#80808059")
	focused:recursiveGetChildById("words"):setColor("#f4f4f4")
	focused:recursiveGetChildById("name"):setColor("#f4f4f4")
	t_spelllist:recursiveGetChildById("spellName"):setText(short_text(focused.spellData.name, 19))
	t_spelllist:recursiveGetChildById("spellName"):setTooltip("")

	if #focused.spellData.name > 18 then
		t_spelllist:recursiveGetChildById("spellName"):setTooltip(focused.spellData.name)
	end

	t_spelllist:recursiveGetChildById("formula"):setText(focused.spellData.words)
	t_spelllist:recursiveGetChildById("type"):setText(focused.spellData.type)
	t_spelllist:recursiveGetChildById("mana"):setText(tr("%s / %s", focused.spellData.mana, focused.spellData.soul))
	t_spelllist:recursiveGetChildById("lvlMin"):setText(focused.spellData.level)

	local cooldownTime = focused.spellData.exhaustion / 1000
	local cooldownDesc = cooldownTime > 60 and cooldownTime / 60 .. "min 0s" or cooldownTime .. "s"
	local groupDesc = ""
	local vocationDesc = ""

	for i, v in pairs(focused.spellData.group) do
		cooldownDesc = cooldownDesc .. " / " .. v / 1000 .. "s"
		groupDesc = groupDesc .. SpellGroups[i] .. ", "
	end

	t_spelllist:recursiveGetChildById("cooldown"):setText(short_text(cooldownDesc, 10))
	t_spelllist:recursiveGetChildById("cooldown"):setTooltip("")

	if #cooldownDesc > 10 then
		t_spelllist:recursiveGetChildById("cooldown"):setTooltip(cooldownDesc)
	end

	groupDesc = string.sub(groupDesc, 1, -3)

	t_spelllist:recursiveGetChildById("group"):setTooltip("")
	t_spelllist:recursiveGetChildById("group"):setText(short_text(groupDesc, 9))

	if #cooldownDesc > 9 then
		t_spelllist:recursiveGetChildById("group"):setTooltip(groupDesc)
	end

	local index = 1

	for _, v in pairs(focused.spellData.vocations) do
		local name = VocationNames[v]

		if name then
			vocationDesc = vocationDesc .. name .. ", "
		end
	end

	vocationDesc = string.sub(vocationDesc, 1, -3)

	if #focused.spellData.vocations == 8 then
		vocationDesc = "All"
	end

	t_spelllist:recursiveGetChildById("vocation"):setText(short_text(vocationDesc, 10))
	t_spelllist:recursiveGetChildById("vocation"):setTooltip("")

	if #vocationDesc > 9 then
		t_spelllist:recursiveGetChildById("vocation"):setTooltip(vocationDesc)
	end
end

function onShowMore()
	if not selectedSpellData or not selectedSpellData.id then
		return
	end

	local cyclopedia = modules.game_cyclopedia
	local api = cyclopedia and cyclopedia.Cyclopedia

	if not api or not api.openSpellInMagicalArchives then
		return
	end

	api.openSpellInMagicalArchives(selectedSpellData.id)
end

function onExtraMenu()
	local mousePosition = g_window.getMousePosition()

	if cancelNextRelease then
		cancelNextRelease = false

		return false
	end

	local menu = g_ui.createWidget("PopupMenu")

	menu:setGameMenu(true)
	menu:addCheckBoxOption("Character Vocation", function()
		setSpellOption("showOnlyCurrentVocation", not getSpellOption("showOnlyCurrentVocation"))
		onConfigureList()
	end, "", spellListConfig.showOnlyCurrentVocation)
	menu:addCheckBoxOption("Character Level", function()
		setSpellOption("showOnlyCurrentLevel", not getSpellOption("showOnlyCurrentLevel"))
		onConfigureList()
	end, "", spellListConfig.showOnlyCurrentLevel)
	menu:addCheckBoxOption("Learnt Spells", function()
		setSpellOption("showUnkownSpells", not getSpellOption("showUnkownSpells"))
		onConfigureList()
	end, "", spellListConfig.showUnkownSpells)
	menu:addSeparator()
	menu:addCheckBoxOption("Druid", function()
		setSpellOption("showDruidSpells", not getSpellOption("showDruidSpells"))
		onConfigureList()
	end, "", spellListConfig.showDruidSpells)
	menu:addCheckBoxOption("Knight", function()
		setSpellOption("showKnightSpells", not getSpellOption("showKnightSpells"))
		onConfigureList()
	end, "", spellListConfig.showKnightSpells)
	menu:addCheckBoxOption("Paladin", function()
		setSpellOption("showPaladinSpells", not getSpellOption("showPaladinSpells"))
		onConfigureList()
	end, "", spellListConfig.showPaladinSpells)
	menu:addCheckBoxOption("Sorcerer", function()
		setSpellOption("showSorcererSpells", not getSpellOption("showSorcererSpells"))
		onConfigureList()
	end, "", spellListConfig.showSorcererSpells)
	menu:addCheckBoxOption("Monk", function()
		setSpellOption("showMonkSpells", not getSpellOption("showMonkSpells"))
		onConfigureList()
	end, "", spellListConfig.showMonkSpells)
	menu:addCheckBoxOption("All Vocations", function()
		checkAllVocations()
		onConfigureList()
	end, "", canCheckAllVocations())
	menu:addSeparator()
	menu:addCheckBoxOption("Attack", function()
		setSpellOption("showAttackSpellGroup", not getSpellOption("showAttackSpellGroup"))
		onConfigureList()
	end, "", spellListConfig.showAttackSpellGroup)
	menu:addCheckBoxOption("Healing", function()
		setSpellOption("showHealingSpellGroup", not getSpellOption("showHealingSpellGroup"))
		onConfigureList()
	end, "", spellListConfig.showHealingSpellGroup)
	menu:addCheckBoxOption("Support", function()
		setSpellOption("showSupportSpellGroup", not getSpellOption("showSupportSpellGroup"))
		onConfigureList()
	end, "", spellListConfig.showSupportSpellGroup)
	menu:addCheckBoxOption("All Spell Groups", function()
		checkAllGroups()
		onConfigureList()
	end, "", canCheckAllGroups())
	menu:addSeparator()
	menu:addCheckBoxOption("Rune Spells", function()
		setSpellOption("showRuneSpells", not getSpellOption("showRuneSpells"))
		onConfigureList()
	end, "", spellListConfig.showRuneSpells)
	menu:addCheckBoxOption("Instant Spells", function()
		setSpellOption("showInstantSpells", not getSpellOption("showInstantSpells"))
		onConfigureList()
	end, "", spellListConfig.showInstantSpells)
	menu:display(mousePosition)

	return true
end

function matchFilter(spell)
	if searchFilterText ~= "" then
		local search = searchFilterText:lower()
		local name = (spell.name or ""):lower()
		local words = (spell.words or ""):lower()

		if not name:find(search, 1, true) and not words:find(search, 1, true) then
			return false
		end
	end

	local player = g_game.getLocalPlayer()

	if getSpellOption("showOnlyCurrentVocation") and spell.vocations and not table.contains(spell.vocations, translateVocation(player:getVocation())) then
		return false
	end

	if getSpellOption("showOnlyCurrentLevel") and player:getLevel() < spell.level then
		return false
	end

	if not canCheckAllVocations() then
		if not getSpellOption("showDruidSpells") and spell.vocations and table.contains(spell.vocations, translateVocation(14)) then
			return false
		end

		if not getSpellOption("showKnightSpells") and spell.vocations and table.contains(spell.vocations, translateVocation(11)) then
			return false
		end

		if not getSpellOption("showSorcererSpells") and spell.vocations and table.contains(spell.vocations, translateVocation(13)) then
			return false
		end

		if not getSpellOption("showPaladinSpells") and spell.vocations and table.contains(spell.vocations, translateVocation(12)) then
			return false
		end

		if not getSpellOption("showMonkSpells") and spell.vocations and table.contains(spell.vocations, translateVocation(15)) then
			return false
		end
	end

	if not canCheckAllGroups() then
		local list = {
			{
				name = "showAttackSpellGroup",
				type = "Attack"
			},
			{
				name = "showHealingSpellGroup",
				type = "Healing"
			},
			{
				name = "showSupportSpellGroup",
				type = "Support"
			}
		}

		for _, k in pairs(list) do
			if not getSpellOption(k.name) then
				local found = false

				for i, v in pairs(spell.group) do
					if SpellGroups[i] == k.type then
						found = true

						break
					end
				end

				if found then
					return false
				end
			end
		end
	end

	return true
end

function setSpellOption(option, value)
	spellListConfig[option] = value
end

function getSpellOption(option)
	return spellListConfig[option]
end

function getSpellListConfig()
	local copy = {}

	for k, v in pairs(spellListConfig) do
		copy[k] = v
	end

	return copy
end

function canCheckAllVocations()
	local druid = getSpellOption("showDruidSpells")
	local knight = getSpellOption("showKnightSpells")
	local paladin = getSpellOption("showPaladinSpells")
	local sorcerer = getSpellOption("showSorcererSpells")
	local monk = getSpellOption("showMonkSpells")

	return druid and knight and paladin and sorcerer and monk
end

function canCheckAllGroups()
	local attack = getSpellOption("showAttackSpellGroup")
	local healing = getSpellOption("showHealingSpellGroup")
	local support = getSpellOption("showSupportSpellGroup")

	return attack and healing and support
end

function checkAllVocations()
	local canCheck = not canCheckAllVocations()

	setSpellOption("showDruidSpells", canCheck)
	setSpellOption("showKnightSpells", canCheck)
	setSpellOption("showPaladinSpells", canCheck)
	setSpellOption("showSorcererSpells", canCheck)
	setSpellOption("showMonkSpells", canCheck)
end

function checkAllGroups()
	local canCheck = not canCheckAllGroups()

	setSpellOption("showAttackSpellGroup", canCheck)
	setSpellOption("showHealingSpellGroup", canCheck)
	setSpellOption("showSupportSpellGroup", canCheck)
end

function onLevelChange(localPlayer, level, levelPercent, oldLevel, oldLevelPercent)
	if level ~= oldLevel then
		onUpdateSpellListLevel()
	end
end
