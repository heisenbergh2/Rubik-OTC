-- chunkname: @/game_interface/widgets/uiitem.lua

local dragPreviewItem
local dragPreviewIsActionSlot = false
local dragPreviewStyleName, hoveredActionTargetSlot

local function isDropTransparentWidget(widget)
	if not widget then
		return true
	end

	return widget:isPhantom() or widget:getId() == "modalBlocker"
end

local function resetDragPreviewWidget()
	if dragPreviewItem then
		dragPreviewItem:destroy()

		dragPreviewItem = nil
	end

	dragPreviewIsActionSlot = false
	dragPreviewStyleName = nil
end

local function isActionSlotWithContent(widget)
	if not widget or widget:isDestroyed() then
		return false
	end

	if widget:getClassName() ~= "UIActionSlot" then
		return false
	end

	if widget:getItem() then
		return true
	end

	if widget.words and widget.words ~= "" then
		return true
	end

	if widget.text and widget.text ~= "" then
		return true
	end

	if widget.passiveId then
		return true
	end

	if widget.itemId and widget.itemId > 0 then
		return true
	end

	if widget.equipments then
		return true
	end

	return false
end

local function clearHoveredActionTargetSlot()
	if hoveredActionTargetSlot then
		hoveredActionTargetSlot:setBorderWidth(0)
		hoveredActionTargetSlot:setBorderColor("alpha")

		hoveredActionTargetSlot = nil
	end
end

local function findParentActionSlot(widget)
	local current = widget

	while current do
		if current:getClassName() == "UIActionSlot" then
			return current
		end

		current = current:getParent()
	end

	return nil
end

local function updateHoveredActionTargetSlot(mousePos, sourceSlot)
	if not mousePos then
		clearHoveredActionTargetSlot()

		return
	end

	local hoveredWidget = rootWidget:recursiveGetChildByPos(mousePos, false)
	local hoveredSlot = findParentActionSlot(hoveredWidget)

	if hoveredSlot == sourceSlot then
		hoveredSlot = nil
	end

	if hoveredActionTargetSlot == hoveredSlot then
		return
	end

	clearHoveredActionTargetSlot()

	if hoveredSlot then
		hoveredSlot:setBorderWidth(1)
		hoveredSlot:setBorderColor("white")

		hoveredActionTargetSlot = hoveredSlot
	end
end

local function ensureDragPreviewItem(sourceWidget)
	local isActionSlot = sourceWidget and sourceWidget:getClassName() == "UIActionSlot"
	local styleName

	if isActionSlot then
		local ok, name = pcall(sourceWidget.getStyleName, sourceWidget)

		styleName = ok and name and name ~= "" and name or "ActionSlot"
	end

	if dragPreviewItem and not dragPreviewItem:isDestroyed() and dragPreviewIsActionSlot == isActionSlot and (not isActionSlot or dragPreviewStyleName == styleName) then
		return dragPreviewItem
	end

	resetDragPreviewWidget()

	if isActionSlot then
		dragPreviewItem = g_ui.createWidget(styleName, rootWidget)

		dragPreviewItem:setId("globalDragPreviewActionSlot")
		dragPreviewItem:breakAnchors()

		local size = sourceWidget:getSize()

		if size and size.width and size.height then
			dragPreviewItem:setSize(size)
		else
			dragPreviewItem:setSize({
				height = 34,
				width = 34
			})
		end

		dragPreviewItem:setFocusable(false)
		dragPreviewItem:setDraggable(false)
		dragPreviewItem:setPhantom(true)
		dragPreviewItem:setVisible(false)
		dragPreviewItem:setOpacity(0.95)

		dragPreviewStyleName = styleName
	else
		dragPreviewItem = g_ui.createWidget("Item", rootWidget)

		dragPreviewItem:setId("globalDragPreviewItem")
		dragPreviewItem:setPhantom(true)
		dragPreviewItem:setFocusable(false)
		dragPreviewItem:setDraggable(false)
		dragPreviewItem:setVirtual(true)
		dragPreviewItem:setVisible(false)
		dragPreviewItem:setFixedItemSize(true)
		dragPreviewItem:setImageSource("")
		dragPreviewItem:setBorderWidth(0)
		dragPreviewItem:setPadding(0)
		dragPreviewItem:setOpacity(0.95)
	end

	dragPreviewIsActionSlot = isActionSlot

	return dragPreviewItem
end

local function updateDragPreviewPosition(mousePos)
	if not dragPreviewItem or not mousePos then
		return
	end

	if dragPreviewIsActionSlot then
		local size = dragPreviewItem:getSize()
		local w = size and size.width or 34
		local h = size and size.height or 34

		dragPreviewItem:setPosition({
			x = mousePos.x - math.floor(w / 2),
			y = mousePos.y - math.floor(h / 2)
		})
	else
		dragPreviewItem:setPosition({
			x = mousePos.x + 2,
			y = mousePos.y + 2
		})
	end

	dragPreviewItem:raise()
end

function UIItem:onDragEnter(mousePos)
	if self:isVirtual() then
		return false
	end

	local item = self:getItem()
	local actionSlotDrag = isActionSlotWithContent(self)

	if not item and not actionSlotDrag then
		return false
	end

	local preview = ensureDragPreviewItem(self)

	if dragPreviewIsActionSlot then
		local actionbar = modules.game_actionbar

		if actionbar and actionbar.applyDragPreviewFromSlot then
			actionbar.applyDragPreviewFromSlot(self, preview)
		elseif item then
			preview:setItem(item)
		end

		if actionbar and actionbar.hideSourceSlotForDrag then
			actionbar.hideSourceSlotForDrag(self)
		end
	else
		preview:setItem(item)

		local quicklootIcon = preview:recursiveGetChildById("quickloot")

		if quicklootIcon then
			quicklootIcon:setVisible(false)
		end
	end

	preview:setVisible(true)
	updateDragPreviewPosition(mousePos or g_window.getMousePosition())
	self:setBorderWidth(1)

	self.currentDragThing = item or self

	if not actionSlotDrag then
		g_mouse.pushCursor("target")

		self.dragCursorPushed = true
	else
		self.dragCursorPushed = false
	end

	return true
end

function UIItem:onDragLeave(droppedWidget, mousePos)
	if self:isVirtual() then
		return false
	end

	self.currentDragThing = nil

	if self.dragCursorPushed then
		g_mouse.popCursor("target")

		self.dragCursorPushed = false
	end

	self:setBorderWidth(0)

	self.hoveredWho = nil

	if dragPreviewItem and not dragPreviewItem:isDestroyed() then
		if dragPreviewIsActionSlot then
			local actionbar = modules.game_actionbar

			if actionbar and actionbar.clearDragPreviewSlot then
				actionbar.clearDragPreviewSlot(dragPreviewItem)
			else
				dragPreviewItem:setItem(nil)
			end
		else
			dragPreviewItem:setItem(nil)
		end

		dragPreviewItem:setVisible(false)
	end

	local actionbar = modules.game_actionbar

	if actionbar and actionbar.restoreSourceSlotAfterDrag then
		actionbar.restoreSourceSlotAfterDrag(self)
	end

	clearHoveredActionTargetSlot()

	return true
end

function UIItem:onDragMove(mousePos, mouseMoved)
	updateDragPreviewPosition(mousePos)

	if dragPreviewIsActionSlot then
		updateHoveredActionTargetSlot(mousePos, self)
	else
		local hoveredWidget = rootWidget:recursiveGetChildByPos(mousePos, false)
		local hoveredSlot = findParentActionSlot(hoveredWidget)

		if hoveredSlot then
			updateHoveredActionTargetSlot(mousePos, self)
		else
			clearHoveredActionTargetSlot()
		end
	end

	return false
end

function UIItem:onDrop(widget, mousePos, forced)
	self:setBorderWidth(0)

	if not forced and not self:canAcceptDrop(widget, mousePos) then
		return false
	end

	local fromActionSlot = widget and widget:getClassName() == "UIActionSlot"
	local item = widget.currentDragThing
	local hasItem = item ~= nil and item ~= widget

	if not hasItem and not fromActionSlot then
		return false
	end

	if hasItem and (not item.isItem or not item:isItem()) then
		return false
	end

	if widget and widget.multiActionIndex and widget.parentSlot then
		return false
	end

	local itemPos = hasItem and item:getPosition() or nil
	local itemTile = hasItem and item:getTile() or nil
	local toPos = self.position

	if not toPos and self:getParent() and self:getParent().slotPosition then
		toPos = self:getParent().slotPosition
	end

	if self.selectable then
		if hasItem and item:isPickupable() then
			self:setItem(Item.create(item:getId(), item:getCountOrSubType()))

			return true
		end

		return false
	end

	if not itemPos or not toPos then
		local pressedWidget = g_ui.getPressedWidget()
		local rootWidget = g_ui.getRootWidget()

		if pressedWidget and rootWidget then
			local parentWidget = pressedWidget:getParent()
			local mousePosWidget = g_ui.getRootWidget():recursiveGetChildByPos(mousePos, false)

			if parentWidget and mousePosWidget then
				local mousePosWidgetParent = mousePosWidget:getParent()
				local pId = mousePosWidgetParent and mousePosWidgetParent.getId and mousePosWidgetParent:getId() or ""
				local isActionBarSlotPanel = pId == "actionBarPanel" or type(pId) == "string" and pId:sub(1, 11) == "sideABPanel"

				if mousePosWidgetParent and isActionBarSlotPanel then
					local parId = parentWidget and parentWidget.getId and parentWidget:getId() or ""
					local fromAb = parId == "actionBarPanel" or type(parId) == "string" and parId:sub(1, 11) == "sideABPanel"

					if not itemPos and fromAb then
						modules.game_actionbar.onDragReassign(widget, hasItem and item or nil)
					elseif hasItem and not toPos and not fromAb then
						modules.game_actionbar.onChooseItemByDrag(self, mousePos, item)
					end
				end
			end
		end

		return false
	end

	if itemPos.x ~= 65535 and not itemTile then
		return false
	end

	if itemPos.x == toPos.x and itemPos.y == toPos.y and itemPos.z == toPos.z then
		return false
	end

	local actionbar = modules.game_actionbar

	if actionbar and actionbar.isEquipmentAssignBlockingItemMove and actionbar.isEquipmentAssignBlockingItemMove() then
		return false
	end

	if item:getCount() > 1 then
		modules.game_interface.moveStackableItem(item, toPos)
	else
		g_game.move(item, toPos, 1)
	end

	return true
end

function UIItem:onDestroy()
	if self == g_ui.getDraggingWidget() and self.hoveredWho then
		self.hoveredWho:setBorderWidth(0)
	end

	if self.hoveredWho then
		self.hoveredWho = nil
	end
end

function UIItem:onHoverChange(hovered)
	UIWidget.onHoverChange(self, hovered)

	if self:isVirtual() or not self:isDraggable() then
		return
	end

	local draggingWidget = g_ui.getDraggingWidget()

	if draggingWidget and self ~= draggingWidget then
		local gotMap = draggingWidget:getClassName() == "UIGameMap"
		local gotItem = draggingWidget:getClassName() == "UIItem" and not draggingWidget:isVirtual()

		if hovered and (gotItem or gotMap) then
			self:setBorderWidth(1)

			draggingWidget.hoveredWho = self
		else
			self:setBorderWidth(0)

			draggingWidget.hoveredWho = nil
		end
	end

	if g_game.getFeature(GameItemTooltipV8) then
		local tooltip = ""

		local function splitTextIntoLines(text, maxLineLength)
			local words = {}

			for word in text:gmatch("%S+") do
				table.insert(words, word)
			end

			local lines = {}
			local currentLine = words[1]

			for i = 2, #words do
				if maxLineLength < currentLine:len() + 1 + words[i]:len() then
					table.insert(lines, currentLine)

					currentLine = words[i]
				else
					currentLine = currentLine .. " " .. words[i]
				end
			end

			table.insert(lines, currentLine)

			return table.concat(lines, "\n")
		end

		if self:getItem() and self:getItem():getTooltip():len() > 0 then
			tooltip = splitTextIntoLines(self:getItem():getTooltip(), 80)

			if tooltip then
				self:setTooltip(tooltip)
			end
		end
	end
end

function UIItem:onMouseRelease(mousePosition, mouseButton)
	if self.cancelNextRelease then
		self.cancelNextRelease = false

		return true
	end

	if self:isVirtual() then
		return false
	end

	local item = self:getItem()

	if not item or not self:containsPoint(mousePosition) then
		return false
	end

	local classicControl = modules.client_options.getOption("classicControl")

	if (classicControl == "classic" or classicControl == true) and (g_mouse.isPressed(MouseLeftButton) and mouseButton == MouseRightButton or g_mouse.isPressed(MouseRightButton) and mouseButton == MouseLeftButton) then
		g_game.look(item)

		self.cancelNextRelease = true

		return true
	elseif modules.game_interface.processMouseAction(mousePosition, mouseButton, nil, item, item, nil, nil) then
		return true
	end

	return false
end

function UIItem:canAcceptDrop(widget, mousePos)
	if not self.selectable and (self:isVirtual() or not self:isDraggable()) then
		return false
	end

	if not widget or not widget.currentDragThing then
		return false
	end

	local children = rootWidget:recursiveGetChildrenByPos(mousePos)

	for i = 1, #children do
		local child = children[i]

		if child == self then
			return true
		elseif not isDropTransparentWidget(child) then
			return false
		end
	end

	error("Widget " .. self:getId() .. " not in drop list.")

	return false
end
