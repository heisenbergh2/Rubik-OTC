-- chunkname: @/gamelib/ui/uiitem.lua

local dragPreviewItem

local function ensureDragPreviewItem()
	if dragPreviewItem then
		return dragPreviewItem
	end

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

	return dragPreviewItem
end

local function updateDragPreviewPosition(mousePos)
	if not dragPreviewItem or not mousePos then
		return
	end

	dragPreviewItem:setPosition({
		x = mousePos.x + 2,
		y = mousePos.y + 2
	})
	dragPreviewItem:raise()
end

function UIItem:onDragEnter(mousePos)
	if self:isVirtual() then
		return false
	end

	local item = self:getItem()

	if not item then
		return false
	end

	local preview = ensureDragPreviewItem()

	preview:setItem(item)

	local quicklootIcon = preview:recursiveGetChildById("quickloot")

	if quicklootIcon then
		quicklootIcon:setVisible(false)
	end

	preview:setVisible(true)
	updateDragPreviewPosition(mousePos or g_window.getMousePosition())
	self:setBorderWidth(1)

	self.currentDragThing = item

	g_mouse.pushCursor("target")

	return true
end

function UIItem:onDragLeave(droppedWidget, mousePos)
	if self:isVirtual() then
		return false
	end

	self.currentDragThing = nil

	g_mouse.popCursor("target")
	self:setBorderWidth(0)

	self.hoveredWho = nil

	if dragPreviewItem then
		dragPreviewItem:setItem(nil)
		dragPreviewItem:setVisible(false)
	end

	return true
end

function UIItem:onDragMove(mousePos, mouseMoved)
	updateDragPreviewPosition(mousePos)

	return false
end

function UIItem:onDrop(widget, mousePos, forced)
	if not self:canAcceptDrop(widget, mousePos) and not forced then
		return false
	end

	local item = widget.currentDragThing

	if not item or not item:isItem() then
		return false
	end

	if self.selectable then
		if item:isPickupable() then
			self:setItem(Item.create(item:getId(), item:getCountOrSubType()))

			return true
		end

		return false
	end

	local toPos = self.position
	local itemPos = item:getPosition()

	if itemPos.x == toPos.x and itemPos.y == toPos.y and itemPos.z == toPos.z then
		return false
	end

	if item:getCount() > 1 then
		modules.game_interface.moveStackableItem(item, toPos)
	else
		g_game.move(item, toPos, 1)
	end

	self:setBorderWidth(0)

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

	if (classicControl == "classic" or classicControl == true) and not g_platform.isMobile() and (g_mouse.isPressed(MouseLeftButton) and mouseButton == MouseRightButton or g_mouse.isPressed(MouseRightButton) and mouseButton == MouseLeftButton) then
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
		elseif not child:isPhantom() then
			return false
		end
	end

	error("Widget " .. self:getId() .. " not in drop list.")

	return false
end

function UIItem:onClick(mousePos)
	if not self.selectable or not self.editable then
		return
	end

	if modules.game_itemselector then
		modules.game_itemselector.show(self)
	end
end

function UIItem:onItemChange()
	local tooltip

	if self:getItem() and self:getItem():getTooltip():len() > 0 then
		tooltip = self:getItem():getTooltip()
	end

	self:setTooltip(tooltip)

	local quicklootIcon = self:recursiveGetChildById("quickloot")

	if quicklootIcon then
		local iconTooltip = ""
		local item = self:getItem()

		if item and modules.game_quickloot and modules.game_quickloot.QuickLoot and modules.game_quickloot.QuickLoot.getQuickLootIconTooltip then
			iconTooltip = modules.game_quickloot.QuickLoot.getQuickLootIconTooltip(item:getQuickLootFlags(), item:getObtainLootFlags())
		end

		quicklootIcon:setTooltip(iconTooltip or "")
	end
end
