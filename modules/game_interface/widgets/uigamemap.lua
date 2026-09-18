-- chunkname: @/game_interface/widgets/uigamemap.lua

UIGameMap = extends(UIMap, "UIGameMap")

local mapDragPreviewItem

local function isDropTransparentWidget(widget)
	if not widget then
		return true
	end

	return widget:isPhantom() or widget:getId() == "modalBlocker"
end

local function ensureMapDragPreviewItem()
	if mapDragPreviewItem then
		return mapDragPreviewItem
	end

	mapDragPreviewItem = g_ui.createWidget("Item", rootWidget)

	mapDragPreviewItem:setId("mapDragPreviewItem")
	mapDragPreviewItem:setPhantom(true)
	mapDragPreviewItem:setFocusable(false)
	mapDragPreviewItem:setDraggable(false)
	mapDragPreviewItem:setVirtual(true)
	mapDragPreviewItem:setVisible(false)
	mapDragPreviewItem:setFixedItemSize(true)
	mapDragPreviewItem:setImageSource("")
	mapDragPreviewItem:setBorderWidth(0)
	mapDragPreviewItem:setPadding(0)
	mapDragPreviewItem:setOpacity(0.95)

	return mapDragPreviewItem
end

local function updateMapDragPreviewPosition(mousePos)
	if not mapDragPreviewItem or not mousePos then
		return
	end

	mapDragPreviewItem:setPosition({
		x = mousePos.x + 2,
		y = mousePos.y + 2
	})
	mapDragPreviewItem:raise()
end

local function isMapThingDraggableItem(thing)
	if not thing or not thing:isItem() then
		return false
	end

	if thing:isGround() then
		return false
	end

	if thing:isNotMoveable() then
		return false
	end

	return true
end

function UIGameMap.create()
	local gameMap = UIGameMap.internalCreate()

	gameMap:setKeepAspectRatio(true)
	gameMap:setVisibleDimension({
		width = 15,
		height = 11
	})
	gameMap:setDrawLights(true)

	return gameMap
end

function UIGameMap:onDragEnter(mousePos)
	local clickPos = self:getLastClickPosition()

	if not clickPos then
		return false
	end

	local clickTile = self:getTile(clickPos)

	if not clickTile then
		return false
	end

	local thing = clickTile:getTopMoveThing()

	if not thing then
		return false
	end

	local isDraggableThing = thing:isCreature() or thing:isItem() and isMapThingDraggableItem(thing)

	if not isDraggableThing then
		return false
	end

	if thing:isItem() then
		local preview = ensureMapDragPreviewItem()

		preview:setItem(thing)

		local quicklootIcon = preview:recursiveGetChildById("quickloot")

		if quicklootIcon then
			quicklootIcon:setVisible(false)
		end

		preview:setVisible(true)
		updateMapDragPreviewPosition(mousePos or g_window.getMousePosition())
	end

	self.currentDragThing = thing

	g_mouse.pushCursor("target")

	self.allowNextRelease = false

	return true
end

function UIGameMap:onDragLeave(droppedWidget, mousePos)
	self.currentDragThing = nil
	self.hoveredWho = nil

	g_mouse.popCursor("target")

	if mapDragPreviewItem then
		mapDragPreviewItem:setItem(nil)
		mapDragPreviewItem:setVisible(false)
	end

	return true
end

function UIGameMap:onDrop(widget, mousePos)
	if not self:canAcceptDrop(widget, mousePos) then
		return false
	end

	local tile = self:getTile(mousePos)

	if not tile then
		return false
	end

	local thing = widget.currentDragThing

	if not thing or thing == widget then
		return false
	end

	if type(thing.isItem) ~= "function" or type(thing.getPosition) ~= "function" or type(thing.getTile) ~= "function" then
		return false
	end

	local thingPos = thing:getPosition()

	if not thingPos then
		return false
	end

	local thingTile = thing:getTile()

	if thingPos.x ~= 65535 and not thingTile then
		return false
	end

	local toPos = tile:getPosition()

	if thingPos.x == toPos.x and thingPos.y == toPos.y and thingPos.z == toPos.z then
		return false
	end

	local actionbar = modules.game_actionbar

	if actionbar and actionbar.isEquipmentAssignBlockingItemMove and actionbar.isEquipmentAssignBlockingItemMove() then
		return false
	end

	if thing:isItem() and thing:getCount() > 1 then
		modules.game_interface.moveStackableItem(thing, toPos)
	else
		g_game.move(thing, toPos, 1)
	end

	return true
end

function UIGameMap:onDragMove(mousePos, mouseMoved)
	if self.currentDragThing and self.currentDragThing:isItem() then
		updateMapDragPreviewPosition(mousePos or g_window.getMousePosition())
	end

	return false
end

function UIGameMap:onMousePress()
	local actionbar = modules.game_actionbar

	if actionbar and actionbar.closeCurrentMultiActionPanel then
		actionbar.closeCurrentMultiActionPanel()
	end

	if not self:isDragging() then
		self.allowNextRelease = true
	end
end

function UIGameMap:onMouseMove(mousePos, mouseMoved)
	if g_mouse.isPressed(MouseLeftButton) and mouseMoved and (math.abs(mouseMoved.x) > 0 or math.abs(mouseMoved.y) > 0) then
		self.allowNextRelease = false
	end

	if self.currentDragThing and self.currentDragThing:isItem() then
		updateMapDragPreviewPosition(g_window.getMousePosition())
	end

	return false
end

function UIGameMap:onMouseRelease(mousePosition, mouseButton)
	if not self.allowNextRelease then
		return true
	end

	local autoWalkPos = self:getPosition(mousePosition)

	if not autoWalkPos then
		return false
	end

	local localPlayerPos = g_game.getLocalPlayer():getPosition()

	if autoWalkPos.z ~= localPlayerPos.z then
		local dz = autoWalkPos.z - localPlayerPos.z

		autoWalkPos.x = autoWalkPos.x + dz
		autoWalkPos.y = autoWalkPos.y + dz
		autoWalkPos.z = localPlayerPos.z
	end

	local lookThing, useThing, creatureThing, multiUseThing, attackCreature
	local tile = self:getTile(mousePosition)

	if tile then
		lookThing = tile:getTopLookThing()
		useThing = tile:getTopUseThing()
		creatureThing = tile:getTopCreature()
	end

	local autoWalkTile = g_map.getTile(autoWalkPos)

	if autoWalkTile then
		attackCreature = autoWalkTile:getTopCreature()
	end

	local ret = modules.game_interface.processMouseAction(mousePosition, mouseButton, autoWalkPos, lookThing, useThing, creatureThing, attackCreature)

	if ret then
		self.allowNextRelease = false
	end

	return ret
end

function UIGameMap:canAcceptDrop(widget, mousePos)
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
