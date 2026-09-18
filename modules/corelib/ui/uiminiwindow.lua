-- chunkname: @/corelib/ui/uiminiwindow.lua

UIMiniWindow = extends(UIWindow, "UIMiniWindow")

local OPEN_HIGHLIGHT_COLOR = "#FFFFFF"
local OPEN_HIGHLIGHT_WIDTH = 2
local OPEN_HIGHLIGHT_HOLD_TIME = 90
local OPEN_HIGHLIGHT_FADE_TIME = 420
local OPEN_HIGHLIGHT_DEBOUNCE_TIME = 120
local OPEN_HIGHLIGHT_LOGIN_SUPPRESSION_TIME = 2000
local openHighlightEnabled = g_game.isOnline()
local openHighlightEnableEvent

connect(g_game, {
	onGameStart = function()
		openHighlightEnabled = false

		removeEvent(openHighlightEnableEvent)

		openHighlightEnableEvent = scheduleEvent(function()
			openHighlightEnableEvent = nil
			openHighlightEnabled = true
		end, OPEN_HIGHLIGHT_LOGIN_SUPPRESSION_TIME)
	end,
	onGameEnd = function()
		removeEvent(openHighlightEnableEvent)

		openHighlightEnableEvent = nil
		openHighlightEnabled = false
	end
})

local function clearOpenHighlight(miniwindow)
	removeEvent(miniwindow._openHighlightFadeEvent)
	removeEvent(miniwindow._openHighlightDestroyEvent)

	miniwindow._openHighlightFadeEvent = nil
	miniwindow._openHighlightDestroyEvent = nil

	local overlay = miniwindow._openHighlightOverlay

	if overlay then
		removeEvent(overlay.fadeEvent)

		overlay.fadeEvent = nil

		if not overlay:isDestroyed() then
			overlay:destroy()
		end

		miniwindow._openHighlightOverlay = nil
	end
end

local function playOpenHighlight(miniwindow)
	if not openHighlightEnabled or not g_game.isOnline() or miniwindow:isDestroyed() or not miniwindow:isVisible() then
		return
	end

	local now = g_clock.millis()
	local currentOverlay = miniwindow._openHighlightOverlay

	if currentOverlay and not currentOverlay:isDestroyed() and miniwindow._openHighlightLastStart and now - miniwindow._openHighlightLastStart < OPEN_HIGHLIGHT_DEBOUNCE_TIME then
		return
	end

	clearOpenHighlight(miniwindow)

	miniwindow._openHighlightLastStart = now

	local overlay = g_ui.createWidget("UIWidget", miniwindow)

	overlay:setId("miniwindowOpenHighlight")

	overlay._miniwindowOpenHighlight = true

	overlay:setPhantom(true)
	overlay:setFocusable(false)
	overlay:setBorderColor(OPEN_HIGHLIGHT_COLOR)
	overlay:setBorderWidth(OPEN_HIGHLIGHT_WIDTH)
	overlay:setOpacity(1)
	overlay:fill("parent")
	overlay:show()
	overlay:raise()

	miniwindow._openHighlightOverlay = overlay
	miniwindow._openHighlightFadeEvent = scheduleEvent(function()
		if miniwindow:isDestroyed() or overlay:isDestroyed() then
			return
		end

		miniwindow._openHighlightFadeEvent = nil

		g_effects.fadeOut(overlay, OPEN_HIGHLIGHT_FADE_TIME)
	end, OPEN_HIGHLIGHT_HOLD_TIME)
	miniwindow._openHighlightDestroyEvent = scheduleEvent(function()
		if miniwindow:isDestroyed() then
			return
		end

		miniwindow._openHighlightDestroyEvent = nil

		if miniwindow._openHighlightOverlay == overlay then
			removeEvent(overlay.fadeEvent)

			overlay.fadeEvent = nil

			if not overlay:isDestroyed() then
				overlay:destroy()
			end

			miniwindow._openHighlightOverlay = nil
		end
	end, OPEN_HIGHLIGHT_HOLD_TIME + OPEN_HIGHLIGHT_FADE_TIME + 60)
end

function UIMiniWindow:playOpenHighlight()
	playOpenHighlight(self)
end

function UIMiniWindow.create()
	local miniwindow = UIMiniWindow.internalCreate()

	miniwindow.UIMiniWindowContainer = true

	return miniwindow
end

function UIMiniWindow:open(dontSave)
	if self.save and (not self:getParent() or self:getParent():isDestroyed()) and SidebarPersistence and SidebarPersistence.active and modules.game_interface and modules.game_interface.getMiniWindowSidebarPanelsInOrder then
		local panels = modules.game_interface.getMiniWindowSidebarPanelsInOrder()
		local lastPanel
		local placed = false

		for _, panel in ipairs(panels) do
			if not panel:isDestroyed() then
				lastPanel = panel

				if panel:fits(self, 44, 0) >= 0 then
					panel:addChild(self)

					placed = true

					break
				end
			end
		end

		if not placed and lastPanel and not lastPanel:isDestroyed() then
			lastPanel:addChild(self)

			local panelRef = lastPanel

			addEvent(function()
				if panelRef and not panelRef:isDestroyed() and type(panelRef.fitAll) == "function" then
					panelRef:fitAll(self)
				end
			end)
		end
	end

	self:setVisible(true)

	if not self._restoringOnStart then
		self:playOpenHighlight()
	end

	if not dontSave then
		self:setSettings({
			closed = false
		})
	end

	local parent = self:getParent()

	if parent and parent.isHorizontalPanel and type(parent.redistributeChildrenWidths) == "function" then
		parent:redistributeChildrenWidths()
	end

	if parent and parent:getClassName() == "UIMiniWindowContainer" and type(parent.scheduleSidebarFreeSpaceRefresh) == "function" then
		parent:scheduleSidebarFreeSpaceRefresh()
	end

	if SidebarLayoutState and SidebarLayoutState.noteWidgetPlacement then
		SidebarLayoutState.noteWidgetPlacement(self)
	end

	if self.save and SidebarWidgetsPersistence and SidebarWidgetsPersistence.scheduleFullOrderRestore then
		SidebarWidgetsPersistence.scheduleFullOrderRestore()
	end

	signalcall(self.onOpen, self)
end

function UIMiniWindow:close(dontSave)
	if not self:isExplicitlyVisible() then
		return
	end

	clearOpenHighlight(self)
	self:setVisible(false)

	if not dontSave then
		self:setSettings({
			closed = true
		})
	end

	local parent = self:getParent()

	if parent and parent.isHorizontalPanel and type(parent.redistributeChildrenWidths) == "function" then
		parent:redistributeChildrenWidths()
	end

	if parent and parent:getClassName() == "UIMiniWindowContainer" and type(parent.refreshSidebarFreeSpace) == "function" then
		parent:refreshSidebarFreeSpace()
	end

	signalcall(self.onClose, self)

	if SidebarLayoutState and SidebarLayoutState.noteWidgetPlacement then
		SidebarLayoutState.noteWidgetPlacement(self)
	end

	if self.save and SidebarPersistence and SidebarPersistence.active then
		local p = self:getParent()

		if p and not p:isDestroyed() and p:getClassName() == "UIMiniWindowContainer" then
			p:removeChild(self)

			local panelRef = p

			addEvent(function()
				if panelRef and not panelRef:isDestroyed() and type(panelRef.refreshSidebarFreeSpace) == "function" then
					panelRef:refreshSidebarFreeSpace()
				end
			end)
		end
	end
end

function UIMiniWindow:minimize(dontSave)
	self:setOn(true)

	local minimizeButton = self:getChildById("minimizeButton")

	if minimizeButton then
		minimizeButton:setOn(true)
	end

	self.maximizedHeight = self:getHeight()

	local minimizedHeight = self.minimizedHeight or 19

	self._minimizedHiddenWidgets = {}

	local selfY = self:getY()

	for _, child in ipairs(self:getChildren()) do
		if child:isExplicitlyVisible() and not child._miniwindowOpenHighlight then
			local relativeBottom = child:getY() - selfY + child:getHeight()

			if minimizedHeight < relativeBottom then
				child:hide()
				table.insert(self._minimizedHiddenWidgets, child)
			end
		end
	end

	self:setHeight(minimizedHeight)

	local miniborder = self:recursiveGetChildById("miniborder")

	if miniborder then
		miniborder:setVisible(false)
	end

	if not dontSave then
		self:setSettings({
			minimized = true
		})
	end

	local parent = self:getParent()

	if parent and parent:getClassName() == "UIMiniWindowContainer" and type(parent.refreshSidebarFreeSpace) == "function" then
		parent:refreshSidebarFreeSpace()
	end

	signalcall(self.onMinimize, self)
end

function UIMiniWindow:maximize(dontSave)
	self:setOn(false)

	local minimizeButton = self:getChildById("minimizeButton")

	if minimizeButton then
		minimizeButton:setOn(false)
	end

	if self._minimizedHiddenWidgets then
		for _, child in ipairs(self._minimizedHiddenWidgets) do
			if child and not child:isDestroyed() then
				child:show()
			end
		end

		self._minimizedHiddenWidgets = nil
	else
		local contentsPanel = self:getChildById("contentsPanel")

		if contentsPanel then
			contentsPanel:show()
		end

		local scrollBar = self:getChildById("miniwindowScrollBar")

		if scrollBar then
			scrollBar:show()
		end

		local bottomResizeBorder = self:getChildById("bottomResizeBorder")

		if bottomResizeBorder then
			bottomResizeBorder:show()
		end
	end

	self:setHeight(self:getSettings("height") or self.maximizedHeight)

	local miniborder = self:recursiveGetChildById("miniborder")

	if miniborder then
		miniborder:setVisible(true)
	end

	if not dontSave then
		self:setSettings({
			minimized = false
		})
	end

	local parent = self:getParent()

	if parent and parent:getClassName() == "UIMiniWindowContainer" then
		parent:fitAll(self)

		if type(parent.scheduleSidebarFreeSpaceRefresh) == "function" then
			parent:scheduleSidebarFreeSpaceRefresh()
		end
	end

	signalcall(self.onMaximize, self)
end

function UIMiniWindow:setup()
	self:getChildById("closeButton").onClick = function()
		self:closeAndForgetLayout()
	end
	self:getChildById("minimizeButton").onClick = function()
		if self:isOn() then
			self:maximize()
		else
			self:minimize()
		end
	end

	local lockButton = self:getChildById("lockButton")

	if lockButton then
		function lockButton.onClick()
			if self:isDraggable() then
				self:lock()
			else
				self:unlock()
			end
		end
	end

	self:getChildById("miniwindowTopBar").onDoubleClick = function()
		if self:isOn() then
			self:maximize()
		else
			self:minimize()
		end
	end
end

function UIMiniWindow:setupOnStart()
	self._restoringOnStart = true

	local char = g_game.getCharacterName()

	if not char or #char == 0 then
		self._restoringOnStart = nil

		return
	end

	if SidebarPersistence and SidebarPersistence.active then
		self.miniLoaded = true

		if SidebarLayoutState and SidebarLayoutState.noteWidgetPlacement then
			SidebarLayoutState.noteWidgetPlacement(self)
		end

		self._restoringOnStart = nil

		return
	end

	local oldParent = self:getParent()

	if self:getId() == "battleWindow" or self:getId() == "QuestLogTracker" then
		self:open(true)
	end

	local newParent = self:getParent()

	if not oldParent and not newParent then
		oldParent = modules.game_interface.getRightPanel()

		self:setParent(oldParent)
	end

	self.miniLoaded = true

	if self.save then
		if oldParent and oldParent:getClassName() == "UIMiniWindowContainer" then
			addEvent(function()
				oldParent:order()
			end)
		end

		local currentParent = self:getParent()

		if currentParent and currentParent:getClassName() == "UIMiniWindowContainer" and currentParent ~= oldParent then
			addEvent(function()
				currentParent:order()
			end)
		end
	end

	self:fitOnParent()

	if self:getId() == "botWindow" then
		local parent = self:getParent()
		local parentId = parent:getId()

		if (parentId == "gameLeftPanel" or parentId == "gameLeftExtraPanel" or parentId == "gameRightExtraPanel") and parent:isVisible() then
			parent:setWidth(190)
		end
	end

	self._restoringOnStart = nil
end

function UIMiniWindow:onVisibilityChange(visible)
	self:fitOnParent()
end

local DROP_HIGHLIGHT_COLOR = "#FFFFFF"
local DROP_HIGHLIGHT_WIDTH = 2
local SIDEBAR_DRAG_PLACEHOLDER_IMAGE = "/images/ui/2pixel_up_frame_borderimage_dark"
local SIDEBAR_DRAG_PLACEHOLDER_BORDER = 2

local function canDropOnContainer(widget, container)
	if container.onlyPhantomDrop and not widget.moveOnlyToMain then
		return false
	end

	if widget.moveOnlyToMain and not container.onlyPhantomDrop and (not widget.allowHorizontalDrop or not container.isHorizontalPanel) then
		return false
	end

	if widget.moveOnlyToSideBars and container.onlyPhantomDrop then
		return false
	end

	return true
end

local function destroySidebarDragPlaceholder(widget)
	local placeholder = widget._sidebarDragPlaceholder

	if placeholder then
		if not placeholder:isDestroyed() then
			placeholder:destroy()
		end

		widget._sidebarDragPlaceholder = nil
	end
end

local function createSidebarDragPlaceholder(widget, container, index)
	destroySidebarDragPlaceholder(widget)

	local placeholder = g_ui.createWidget("UIWidget")

	placeholder:setId("sidebarDragPlaceholder")

	placeholder._sidebarDragPlaceholder = true

	placeholder:setPhantom(true)
	placeholder:setFocusable(false)
	placeholder:setImageSource(SIDEBAR_DRAG_PLACEHOLDER_IMAGE)
	placeholder:setImageBorder(SIDEBAR_DRAG_PLACEHOLDER_BORDER)
	placeholder:setWidth(widget:getWidth())
	placeholder:setHeight(widget:getHeight())
	container:insertChild(index, placeholder)

	widget._sidebarDragPlaceholder = placeholder

	if type(container.scheduleSidebarFreeSpaceRefresh) == "function" then
		container:scheduleSidebarFreeSpaceRefresh()
	end
end

local function moveSidebarDragPlaceholder(widget, container, newIndex)
	local placeholder = widget._sidebarDragPlaceholder

	if not placeholder or placeholder:isDestroyed() then
		return
	end

	local oldContainer = placeholder:getParent()

	if oldContainer and not oldContainer:isDestroyed() then
		oldContainer:removeChild(placeholder)

		if type(oldContainer.scheduleSidebarFreeSpaceRefresh) == "function" then
			oldContainer:scheduleSidebarFreeSpaceRefresh()
		end
	end

	container:insertChild(newIndex, placeholder)

	if type(container.scheduleSidebarFreeSpaceRefresh) == "function" then
		container:scheduleSidebarFreeSpaceRefresh()
	end
end

local function destroyDropHighlightOverlay(widget)
	local overlay = widget._dropHighlightOverlay

	if overlay then
		if not overlay:isDestroyed() then
			overlay:destroy()
		end

		widget._dropHighlightOverlay = nil
	end
end

local function clearDropHighlight(widget)
	destroyDropHighlightOverlay(widget)

	widget._highlightedDropTarget = nil
end

local function applyDropHighlight(widget, container)
	if widget._highlightedDropTarget == container then
		return
	end

	clearDropHighlight(widget)

	if not container or container:isDestroyed() then
		return
	end

	local parent = container:getParent()

	if not parent or parent:isDestroyed() then
		return
	end

	local overlay = g_ui.createWidget("UIWidget", parent)

	overlay:setPhantom(true)
	overlay:setFocusable(false)
	overlay:setBorderColor(DROP_HIGHLIGHT_COLOR)
	overlay:setBorderWidth(DROP_HIGHLIGHT_WIDTH)
	overlay:setPosition(container:getPosition())
	overlay:setSize(container:getSize())
	overlay:raise()

	if widget:getParent() == parent and not widget:isDestroyed() then
		widget:raise()
	end

	widget._dropHighlightOverlay = overlay
	widget._highlightedDropTarget = container
end

local function findDropTargetContainer(widget, panel, mousePos)
	if not panel then
		return nil
	end

	local children = panel:getChildren()

	for i = 1, #children do
		local child = children[i]

		if child ~= widget and child:isVisible() and child:getClassName() == "UIMiniWindowContainer" and child:containsPoint(mousePos) then
			if canDropOnContainer(widget, child) then
				return child
			end

			return nil
		end
	end

	return nil
end

local function isMainPanelDropTarget(widget, mousePos)
	if widget and type(widget.isDestroyed) == "function" and not widget:isDestroyed() then
		if widget.onlyPhantomDrop or widget.moveOnlyToMain then
			return true
		end

		if modules.game_interface and modules.game_interface.getMainRightPanel then
			local mainPanel = modules.game_interface.getMainRightPanel()

			if mainPanel and not mainPanel:isDestroyed() then
				local current = widget

				while current and not current:isDestroyed() do
					if current == mainPanel then
						return true
					end

					current = current:getParent()
				end
			end
		end
	end

	if mousePos and modules.game_interface and modules.game_interface.getMainRightPanel then
		local mainPanel = modules.game_interface.getMainRightPanel()

		if mainPanel and not mainPanel:isDestroyed() and mainPanel:containsPoint(mousePos) then
			return true
		end
	end

	return false
end

local function appendToDefaultSidebar(widget)
	if not modules.game_interface or not modules.game_interface.getRightPanel then
		return false
	end

	local sidebar = modules.game_interface.getRightPanel()

	if not sidebar or sidebar:isDestroyed() then
		return false
	end

	local virtualParent = widget:getParent()

	if virtualParent and not virtualParent:isDestroyed() then
		virtualParent:removeChild(widget)
	end

	sidebar:addChild(widget)
	sidebar:fitAll(widget)

	if type(sidebar.scheduleSidebarFreeSpaceRefresh) == "function" then
		sidebar:scheduleSidebarFreeSpaceRefresh()
	end

	return true
end

function UIMiniWindow:onDragEnter(mousePos)
	local parent = self:getParent()

	if not parent then
		return false
	end

	self.oldParentDragLast = nil
	self._fromSidebar = false

	if parent:getClassName() == "UIMiniWindowContainer" then
		self._fromSidebar = true
		self.oldParentDrag = parent

		local rawIndex = parent:getChildIndex(self)

		self.oldParentDragIndex = rawIndex

		local children = parent:getChildren()
		local saveableCount = 0
		local saveIndex

		for i = 1, #children do
			local c = children[i]

			if c:isVisible() and not c._sidebarFreeSpaceWidget and not c._sidebarDragPlaceholder then
				saveableCount = saveableCount + 1

				if c == self then
					saveIndex = saveableCount
				end
			end
		end

		self.oldParentDragLast = saveIndex and saveIndex == saveableCount or false

		local containerParent = parent:getParent()

		parent:removeChild(self)

		if not parent.onlyPhantomDrop then
			createSidebarDragPlaceholder(self, parent, self.oldParentDragIndex)
		end

		containerParent:addChild(self)
		parent:saveChildren()

		if parent.isHorizontalPanel and type(parent.redistributeChildrenWidths) == "function" then
			parent:redistributeChildrenWidths()
		end

		if type(parent.scheduleSidebarFreeSpaceRefresh) == "function" then
			parent:scheduleSidebarFreeSpaceRefresh()
		end
	end

	local oldPos = self:getPosition()

	self.movingReference = {
		x = mousePos.x - oldPos.x,
		y = mousePos.y - oldPos.y
	}

	self:setPosition(oldPos)

	self.free = true

	return true
end

function UIMiniWindow:onDragLeave(droppedWidget, mousePos)
	self.oldParentDragLast = nil

	clearDropHighlight(self)

	if self.movedWidget then
		self.setMovedChildMargin(self.movedOldMargin or 0)

		self.movedWidget = nil
		self.setMovedChildMargin = nil
		self.movedOldMargin = nil
		self.movedIndex = nil
	end

	local function bounceBackToOrigin()
		if not self.oldParentDrag or self.oldParentDrag:isDestroyed() then
			return false
		end

		local virtualParent = self:getParent()

		if virtualParent then
			virtualParent:removeChild(self)
		end

		self.oldParentDrag:insertChild(self.oldParentDragIndex or 1, self)

		self.movedWidget = nil

		if self.oldParentDrag.isHorizontalPanel and type(self.oldParentDrag.redistributeChildrenWidths) == "function" then
			self.oldParentDrag:redistributeChildrenWidths()
		end

		return true
	end

	local needsBounce = false

	if self.moveOnlyToMain or droppedWidget and droppedWidget.onlyPhantomDrop then
		local widgetAllowsHorizontal = self.allowHorizontalDrop and droppedWidget and droppedWidget.isHorizontalPanel

		if not widgetAllowsHorizontal and (not droppedWidget or self.moveOnlyToMain and not droppedWidget.onlyPhantomDrop or not self.moveOnlyToMain and droppedWidget.onlyPhantomDrop) then
			needsBounce = true
		end
	end

	if not needsBounce and self._fromSidebar then
		local currentParent = self:getParent()
		local landedOnSidebar = currentParent and currentParent:getClassName() == "UIMiniWindowContainer"

		if not landedOnSidebar then
			needsBounce = true
		end
	end

	if needsBounce then
		if self._fromSidebar and not self.moveOnlyToMain and isMainPanelDropTarget(droppedWidget, mousePos) then
			if not appendToDefaultSidebar(self) then
				bounceBackToOrigin()
			end
		else
			bounceBackToOrigin()
		end
	end

	local placeholderParent = self._sidebarDragPlaceholder and self._sidebarDragPlaceholder:getParent()

	destroySidebarDragPlaceholder(self)

	if placeholderParent and not placeholderParent:isDestroyed() and placeholderParent.isHorizontalPanel and type(placeholderParent.redistributeChildrenWidths) == "function" then
		placeholderParent:redistributeChildrenWidths()
	end

	if placeholderParent and not placeholderParent:isDestroyed() and type(placeholderParent.scheduleSidebarFreeSpaceRefresh) == "function" then
		placeholderParent:scheduleSidebarFreeSpaceRefresh()
	end

	local currentParent = self:getParent()

	if currentParent and currentParent:getClassName() == "UIMiniWindowContainer" and type(currentParent.scheduleSidebarFreeSpaceRefresh) == "function" then
		currentParent:scheduleSidebarFreeSpaceRefresh()
	end

	self._fromSidebar = false

	self:saveParent(self:getParent())

	return true
end

function UIMiniWindow:onDragMove(mousePos, mouseMoved)
	local moved = UIWindow.onDragMove(self, mousePos, mouseMoved)

	if self.moveOnlyToMain and not self.allowHorizontalDrop and self.oldParentDrag and not self.oldParentDrag:isDestroyed() then
		local cRect = self.oldParentDrag:getPaddingRect()
		local wSize = self:getSize()
		local lockedX = cRect.x
		local minY = cRect.y
		local maxY = cRect.y + math.max(0, cRect.height - wSize.height)
		local clampedY = math.max(minY, math.min(self:getY(), maxY))

		if lockedX ~= self:getX() or clampedY ~= self:getY() then
			self:setPosition({
				x = lockedX,
				y = clampedY
			})
		end
	end

	local panel = self:getParent()

	if not panel then
		clearDropHighlight(self)

		return moved
	end

	local highlightedDropTarget = findDropTargetContainer(self, panel, mousePos)

	applyDropHighlight(self, highlightedDropTarget)

	local dragTop = self:getY()
	local dragBottom = self:getY() + self:getHeight()
	local dy = mouseMoved.y
	local placeholder = self._sidebarDragPlaceholder
	local placeholderContainer = placeholder and not placeholder:isDestroyed() and placeholder:getParent()
	local phParentId = placeholderContainer and not placeholderContainer:isDestroyed() and placeholderContainer:getParent() and placeholderContainer:getParent():getId()

	if placeholderContainer and not placeholderContainer:isDestroyed() and not placeholderContainer.onlyPhantomDrop and not self.moveOnlyToMain and self.oldParentDrag == placeholderContainer and (highlightedDropTarget == placeholderContainer or not highlightedDropTarget) and phParentId then
		local siblings = placeholderContainer:getChildren()
		local pIdx

		for i = 1, #siblings do
			if siblings[i] == placeholder then
				pIdx = i

				break
			end
		end

		if pIdx and dy ~= 0 then
			local prevDragTop = dragTop - dy
			local prevDragBottom = dragBottom - dy

			local function skip(child)
				return not child or child._sidebarFreeSpaceWidget or child._sidebarDragPlaceholder or not child:isVisible()
			end

			if dy > 0 then
				local nextIdx = pIdx + 1

				while nextIdx <= #siblings do
					local candidate = siblings[nextIdx]

					if not skip(candidate) then
						local nextMid = candidate:getY() + candidate:getHeight() / 2

						if prevDragBottom <= nextMid and nextMid < dragBottom then
							moveSidebarDragPlaceholder(self, placeholderContainer, nextIdx)
						end

						break
					end

					nextIdx = nextIdx + 1
				end
			else
				local prevIdx = pIdx - 1

				while prevIdx >= 1 do
					local candidate = siblings[prevIdx]

					if not skip(candidate) then
						local prevMid = candidate:getY() + candidate:getHeight() / 2

						if prevMid <= prevDragTop and dragTop < prevMid then
							moveSidebarDragPlaceholder(self, placeholderContainer, prevIdx)
						end

						break
					end

					prevIdx = prevIdx - 1
				end
			end
		end
	end

	local prevDragTop = dragTop - mouseMoved.y
	local prevDragBottom = prevDragTop + self:getHeight()
	local STRADDLE_PAD = 8

	local function dropSlotAboveStraddle(dragT, dragB, midY)
		if dragB <= midY - STRADDLE_PAD then
			return true
		end

		if dragT >= midY + STRADDLE_PAD then
			return false
		end

		return midY - dragT >= dragB - midY
	end

	local function slotAboveTarget(dragT, dragB, midY, deltaY)
		if deltaY > 0 then
			return dragB <= midY
		elseif deltaY < 0 then
			return dragT < midY
		end

		return dropSlotAboveStraddle(dragT, dragB, midY)
	end

	local overAnyWidget = false

	local function applyMovedMargin(child, movedIndex)
		overAnyWidget = true

		if child == self.movedWidget and self.movedIndex == movedIndex then
			return
		end

		if self.movedWidget then
			self.setMovedChildMargin(self.movedOldMargin or 0)

			self.setMovedChildMargin = nil
		end

		if movedIndex == 0 then
			self.movedOldMargin = child:getMarginTop()

			function self.setMovedChildMargin(v)
				child:setMarginTop(v)
			end
		else
			self.movedOldMargin = child:getMarginBottom()

			function self.setMovedChildMargin(v)
				child:setMarginBottom(v)
			end
		end

		self.movedWidget = child
		self.movedIndex = movedIndex

		self.setMovedChildMargin(self:getHeight())
	end

	if self.moveOnlyToMain and self.oldParentDrag and not self.oldParentDrag:isDestroyed() and self.oldParentDrag:getParent() == panel then
		local siblings = self.oldParentDrag:getChildren()
		local candidate, candidateIndex

		if dy ~= 0 then
			for i = dy < 0 and #siblings or 1, dy < 0 and 1 or #siblings, dy < 0 and -1 or 1 do
				local child = siblings[i]

				if child ~= self and not child._sidebarDragPlaceholder and not child._sidebarFreeSpaceWidget and child:isVisible() then
					local center = child:getY() + child:getHeight() / 2
					local abovePrev = slotAboveTarget(prevDragTop, prevDragBottom, center, dy)
					local aboveNow = slotAboveTarget(dragTop, dragBottom, center, dy)

					if not abovePrev and aboveNow then
						candidate = child
						candidateIndex = 0

						break
					elseif abovePrev and not aboveNow then
						candidate = child
						candidateIndex = 1

						break
					end
				end
			end
		end

		if candidate then
			applyMovedMargin(candidate, candidateIndex)
		elseif self.movedWidget and self.movedWidget:getParent() == self.oldParentDrag then
			overAnyWidget = true
		end
	end

	local children = rootWidget:recursiveGetChildrenByMarginPos(mousePos)

	if not overAnyWidget then
		for i = 1, #children do
			local child = children[i]

			if child ~= self and not child._sidebarDragPlaceholder and not child._sidebarFreeSpaceWidget and child:getParent():getClassName() == "UIMiniWindowContainer" then
				local container = child:getParent()

				if container:getParent() == panel and container ~= placeholderContainer and (not self._fromSidebar or container == self.oldParentDrag) and canDropOnContainer(self, container) then
					local cchildren = container:getChildren()
					local childSaveIndex
					local childSaveCount = 0

					for n = 1, #cchildren do
						local cc = cchildren[n]

						if cc:isVisible() and not cc._sidebarFreeSpaceWidget and not cc._sidebarDragPlaceholder then
							childSaveCount = childSaveCount + 1

							if cc == child then
								childSaveIndex = childSaveCount
							end
						end
					end

					local childIndex = childSaveIndex or container:getChildIndex(child)
					local stableChildY = child:getY()

					if child == self.movedWidget and self.movedIndex == 0 then
						local mt = child:getMarginTop()
						local baseMt = self.movedOldMargin or 0

						stableChildY = child:getY() - (mt - baseMt)
					end

					local childCenterPanel = container:getY() + stableChildY + child:getHeight() / 2
					local aboveNow = slotAboveTarget(dragTop, dragBottom, childCenterPanel, dy)
					local abovePrev = slotAboveTarget(prevDragTop, prevDragBottom, childCenterPanel, dy)
					local skipRedundantAbove = self.oldParentDrag and container == self.oldParentDrag and self.oldParentDragIndex == 1 and childIndex == 1 and aboveNow
					local skipRedundantBelow = self.oldParentDrag and container == self.oldParentDrag and self.oldParentDragLast and childIndex == childSaveCount and not aboveNow

					if skipRedundantAbove or skipRedundantBelow then
						if self.movedWidget then
							self.setMovedChildMargin(self.movedOldMargin or 0)

							self.setMovedChildMargin = nil
							self.movedWidget = nil
							self.movedOldMargin = nil
							self.movedIndex = nil
						end
					else
						if child == self.movedWidget and aboveNow == abovePrev then
							overAnyWidget = true

							break
						end

						applyMovedMargin(child, aboveNow and 0 or 1)

						break
					end
				end
			end
		end
	end

	if not overAnyWidget and self.movedWidget then
		self.setMovedChildMargin(self.movedOldMargin or 0)

		self.movedWidget = nil
	end

	return moved
end

function UIMiniWindow:onMousePress()
	local parent = self:getParent()

	if not parent then
		return false
	end

	if parent:getClassName() ~= "UIMiniWindowContainer" then
		self:raise()

		return true
	end
end

function UIMiniWindow:onFocusChange(focused)
	if not focused then
		return
	end

	local parent = self:getParent()

	if parent and parent:getClassName() ~= "UIMiniWindowContainer" then
		self:raise()
	end
end

function UIMiniWindow:resizeWithinContainer(parent, height)
	local children = parent:getChildren()
	local selfIndex

	for i = 1, #children do
		if children[i] == self then
			selfIndex = i

			break
		end
	end

	if not selfIndex then
		return
	end

	local aboveHeight = 0
	local belowChildren = {}
	local belowCurTotal = 0
	local belowMinTotal = 0

	for i = 1, #children do
		local c = children[i]

		if c ~= self and c:isVisible() and not c._sidebarFreeSpaceWidget and not c._sidebarDragPlaceholder then
			if i < selfIndex then
				aboveHeight = aboveHeight + c:getHeight()
			else
				local curH = c:getHeight()
				local effMin = curH

				if c.isResizeable and c:isResizeable() then
					effMin = math.min(curH, c:getMinimumHeight() or 0)
				end

				belowChildren[#belowChildren + 1] = c
				belowCurTotal = belowCurTotal + curH
				belowMinTotal = belowMinTotal + effMin
			end
		end
	end

	local containerInner = parent:getHeight() - parent:getPaddingTop() - parent:getPaddingBottom()
	local minH = self:getMinimumHeight() or 0
	local maxSelf = containerInner - aboveHeight - belowMinTotal
	local target = math.max(minH, math.min(height, maxSelf))

	if target ~= height then
		self:setHeight(target)

		return
	end

	local overflow = aboveHeight + target + belowCurTotal - containerInner

	for i = #belowChildren, 1, -1 do
		if overflow <= 0 then
			break
		end

		local c = belowChildren[i]

		if c.isResizeable and c:isResizeable() then
			local curH = c:getHeight()
			local cMin = c:getMinimumHeight() or 0
			local canShrink = math.max(0, curH - cMin)

			if canShrink > 0 then
				local reduce = math.min(canShrink, overflow)

				c:setHeight(curH - reduce)

				overflow = overflow - reduce
			end
		end
	end
end

function UIMiniWindow:onHeightChange(height)
	local resizeBorder = self:getChildById("bottomResizeBorder")
	local isDraggingResize = resizeBorder and resizeBorder:isPressed()

	if not self:isOn() and not isDraggingResize then
		self:setSettings({
			height = height
		})
	end

	local parent = self:getParent()
	local inContainer = parent and parent:getClassName() == "UIMiniWindowContainer"

	if inContainer and parent._resizingActive then
		return
	end

	if isDraggingResize and inContainer then
		parent._resizingActive = true

		self:resizeWithinContainer(parent, height)

		parent._resizingActive = nil
	else
		self:fitOnParent()
	end

	if inContainer and type(parent.refreshSidebarFreeSpace) == "function" then
		parent:refreshSidebarFreeSpace()
	end
end

function UIMiniWindow:getSettings(name)
	return nil
end

function UIMiniWindow:setSettings(data)
	return
end

function UIMiniWindow:eraseSettings(data)
	return
end

function UIMiniWindow:saveParent(parent)
	parent = parent or self:getParent()

	if parent then
		if parent:getClassName() == "UIMiniWindowContainer" then
			parent:saveChildren()
		else
			self:saveParentPosition(parent:getId(), self:getPosition())
		end

		if self._lastSavedContainer ~= parent then
			self._lastSavedContainer = parent

			signalcall(self.onContainerChanged, self, parent)
		end

		if SidebarLayoutState and SidebarLayoutState.noteWidgetPlacement then
			SidebarLayoutState.noteWidgetPlacement(self)
		end
	end
end

function UIMiniWindow:saveSelfIndex()
	if not self.save then
		return
	end

	local parent = self:getParent()

	if not parent then
		return
	end

	if parent:getClassName() == "UIMiniWindowContainer" then
		local children = parent:getChildren()
		local idx = 0

		for i = 1, #children do
			if children[i].save then
				idx = idx + 1
			end

			if children[i] == self then
				self:saveParentIndex(parent:getId(), idx)

				return
			end
		end
	else
		self:saveParentPosition(parent:getId(), self:getPosition())
	end
end

function UIMiniWindow:clearSavedLayout()
	self.miniIndex = nil
	self.miniLoaded = nil
end

function UIMiniWindow:closeAndForgetLayout()
	if not self:isExplicitlyVisible() then
		return
	end

	local parent = self:getParent()
	local keepInSidebar = false

	if parent and not parent:isDestroyed() and modules.game_interface and modules.game_interface.isGameSidePanelId and modules.game_interface.isGameSidePanelId(parent:getId()) then
		keepInSidebar = true
	end

	if parent and (parent:getId() == "gameRightTopPanel" or parent:getId() == "gameLeftTopPanel") then
		keepInSidebar = true
	end

	if keepInSidebar then
		self:close(true)

		if SidebarLayoutState and SidebarLayoutState.noteWidgetPlacement then
			SidebarLayoutState.noteWidgetPlacement(self)
		end

		return
	end

	self:clearSavedLayout()

	if SidebarWidgetOptionsPersistence and SidebarWidgetOptionsPersistence.clearWidgetOptionsById then
		SidebarWidgetOptionsPersistence.clearWidgetOptionsById(self:getId())
	end

	local parent = self:getParent()

	if parent and not parent:isDestroyed() then
		parent:removeChild(self)

		if parent:getClassName() == "UIMiniWindowContainer" and type(parent.refreshSidebarFreeSpace) == "function" then
			parent:refreshSidebarFreeSpace()
		end
	end

	self:close()
end

function UIMiniWindow:saveParentPosition(parentId, position)
	local selfSettings = {}

	selfSettings.parentId = parentId
	selfSettings.position = pointtostring(position)

	self:setSettings(selfSettings)
end

function UIMiniWindow:saveParentIndex(parentId, index)
	local selfSettings = {}

	selfSettings.parentId = parentId
	selfSettings.index = index

	self:setSettings(selfSettings)

	self.miniIndex = index

	if SidebarLayoutState and SidebarLayoutState.noteWidgetPlacement then
		SidebarLayoutState.noteWidgetPlacement(self)
	end
end

function UIMiniWindow:disableResize()
	self:getChildById("bottomResizeBorder"):disable()
end

function UIMiniWindow:enableResize()
	self:getChildById("bottomResizeBorder"):enable()
end

function UIMiniWindow:fitOnParent()
	local parent = self:getParent()

	if self:isVisible() and parent and parent:getClassName() == "UIMiniWindowContainer" then
		parent:fitAll(self)
	end
end

function UIMiniWindow:setParent(parent, dontsave)
	UIWidget.setParent(self, parent)

	if not dontsave then
		self:saveParent(parent)
	end

	self:fitOnParent()
end

function UIMiniWindow:setHeight(height)
	UIWidget.setHeight(self, height)
	signalcall(self.onHeightChange, self, height)
end

function UIMiniWindow:setContentHeight(height)
	local contentsPanel = self:getChildById("contentsPanel")
	local minHeight = contentsPanel:getMarginTop() + contentsPanel:getMarginBottom() + contentsPanel:getPaddingTop() + contentsPanel:getPaddingBottom()
	local resizeBorder = self:getChildById("bottomResizeBorder")

	resizeBorder:setParentSize(minHeight + height)
end

function UIMiniWindow:setContentMinimumHeight(height)
	local contentsPanel = self:getChildById("contentsPanel")
	local minHeight = contentsPanel:getMarginTop() + contentsPanel:getMarginBottom() + contentsPanel:getPaddingTop() + contentsPanel:getPaddingBottom()
	local resizeBorder = self:getChildById("bottomResizeBorder")

	resizeBorder:setMinimum(minHeight + height)
end

function UIMiniWindow:setContentMaximumHeight(height)
	local contentsPanel = self:getChildById("contentsPanel")
	local minHeight = contentsPanel:getMarginTop() + contentsPanel:getMarginBottom() + contentsPanel:getPaddingTop() + contentsPanel:getPaddingBottom()
	local resizeBorder = self:getChildById("bottomResizeBorder")

	resizeBorder:setMaximum(minHeight + height)
end

function UIMiniWindow:getMinimumHeight()
	local resizeBorder = self:getChildById("bottomResizeBorder")

	return resizeBorder:getMinimum()
end

function UIMiniWindow:getMaximumHeight()
	local resizeBorder = self:getChildById("bottomResizeBorder")

	return resizeBorder:getMaximum()
end

function UIMiniWindow:modifyMaximumHeight(height)
	local resizeBorder = self:getChildById("bottomResizeBorder")
	local newHeight = resizeBorder:getMaximum() + height
	local curHeight = self:getHeight()

	resizeBorder:setMaximum(newHeight)

	if newHeight < curHeight or newHeight - height == curHeight then
		self:setHeight(newHeight)
	end
end

function UIMiniWindow:isResizeable()
	local resizeBorder = self:getChildById("bottomResizeBorder")

	if not resizeBorder then
		return false
	end

	return resizeBorder:isExplicitlyVisible() and resizeBorder:isEnabled()
end

function UIMiniWindow:setLockedState(locked, dontSave)
	local lockButton = self:getChildById("lockButton")

	if lockButton then
		lockButton:setOn(locked)
	end

	self:setDraggable(not locked)

	if not dontSave then
		self:setSettings({
			locked = locked
		})
	end

	signalcall(self.onLockChange, self)
end

function UIMiniWindow:lock(dontSave)
	self:setLockedState(true, dontSave)
end

function UIMiniWindow:unlock(dontSave)
	self:setLockedState(false, dontSave)
end
