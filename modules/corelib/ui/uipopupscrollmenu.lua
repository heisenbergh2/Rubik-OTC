-- chunkname: @/corelib/ui/uipopupscrollmenu.lua

UIPopupScrollMenu = extends(UIWidget, "UIPopupScrollMenu")

local currentMenu

local function releaseMouseGrabUnderCursor()
	if not g_ui.isMouseGrabbed() then
		return nil
	end

	local widget = rootWidget:recursiveGetChildByPos(g_window.getMousePosition(), false)

	while widget do
		widget:ungrabMouse()

		if not g_ui.isMouseGrabbed() then
			return widget
		end

		widget = widget:getParent()
	end

	return nil
end

function UIPopupScrollMenu.create()
	local menu = UIPopupScrollMenu.internalCreate()
	local scrollArea = g_ui.createWidget("UIScrollArea", menu)

	scrollArea:setLayout(UIVerticalLayout.create(menu))
	scrollArea:setId("scrollArea")

	function scrollArea.onMouseWheel(_, mousePos, direction)
		return menu:onMouseWheel(mousePos, direction)
	end

	local scrollBar = g_ui.createWidget("VerticalQtScrollBar", menu)

	scrollBar:setId("scrollBar")

	scrollBar.pixelsScroll = false

	scrollBar:addAnchor(AnchorRight, "parent", AnchorRight)
	scrollBar:addAnchor(AnchorTop, "parent", AnchorTop)
	scrollBar:addAnchor(AnchorBottom, "parent", AnchorBottom)
	scrollArea:addAnchor(AnchorLeft, "parent", AnchorLeft)
	scrollArea:addAnchor(AnchorTop, "parent", AnchorTop)
	scrollArea:addAnchor(AnchorBottom, "parent", AnchorBottom)
	scrollArea:addAnchor(AnchorRight, "next", AnchorLeft)
	scrollArea:setVerticalScrollBar(scrollBar)

	menu.scrollArea = scrollArea
	menu.scrollBar = scrollBar

	return menu
end

function UIPopupScrollMenu:setScrollbarStep(step)
	self.scrollBar:setStep(step)
end

function UIPopupScrollMenu:display(pos)
	if self.scrollArea:getChildCount() == 0 then
		self:destroy()

		return
	end

	self.previousMouseReceiver = releaseMouseGrabUnderCursor()

	if g_ui.isMouseGrabbed() then
		self:destroy()

		return
	end

	if currentMenu then
		currentMenu:destroy()
	end

	if pos == nil then
		pos = g_window.getMousePosition()
	end

	rootWidget:addChild(self)
	self:setPosition(pos)
	self:grabMouse()
	self:focus()
	self:grabKeyboard()

	currentMenu = self
end

function UIPopupScrollMenu:onGeometryChange(newRect, oldRect)
	local parent = self:getParent()

	if not parent then
		return
	end

	local ymax = parent:getY() + parent:getHeight()
	local xmax = parent:getX() + parent:getWidth()

	if ymax < newRect.y + newRect.height then
		local newy = newRect.y - newRect.height

		if newy > 0 and ymax > newy + newRect.height then
			self:setY(newy)
		end
	end

	if xmax < newRect.x + newRect.width then
		local newx = newRect.x - newRect.width

		if newx > 0 and xmax > newx + newRect.width then
			self:setX(newx)
		end
	end

	self:bindRectToParent()
end

function UIPopupScrollMenu:addOption(optionName, optionCallback, shortcut)
	local optionWidget = g_ui.createWidget(self:getStyleName() .. "Button", self.scrollArea)

	function optionWidget.onClick(widget)
		self:destroy()
		optionCallback()
	end

	function optionWidget.onMouseWheel(_, mousePos, direction)
		return self:onMouseWheel(mousePos, direction)
	end

	optionWidget:setText(optionName)

	local width = optionWidget:getTextSize().width + optionWidget:getMarginLeft() + optionWidget:getMarginRight() + 15

	if shortcut then
		local shortcutLabel = g_ui.createWidget(self:getStyleName() .. "ShortcutLabel", optionWidget)

		shortcutLabel:setText(shortcut)

		width = width + shortcutLabel:getTextSize().width + shortcutLabel:getMarginLeft() + shortcutLabel:getMarginRight()
	end

	self:setWidth(math.max(self:getWidth(), width))
end

function UIPopupScrollMenu:addSeparator()
	g_ui.createWidget(self:getStyleName() .. "Separator", self.scrollArea)
end

function UIPopupScrollMenu:onDestroy()
	if currentMenu == self then
		currentMenu = nil
	end

	self:ungrabMouse()
	self:ungrabKeyboard()

	if self.previousMouseReceiver and not self.previousMouseReceiver:isDestroyed() then
		self.previousMouseReceiver:grabMouse()

		self.previousMouseReceiver = nil
	end
end

function UIPopupScrollMenu:onMousePress(mousePos, mouseButton)
	if not self:containsPoint(mousePos) then
		self:destroy()
	end

	return true
end

function UIPopupScrollMenu:onMouseWheel(mousePos, direction)
	if not self:containsPoint(mousePos) then
		return false
	end

	local value = self.scrollBar:getValue()
	local step = self.scrollBar.getStep and self.scrollBar:getStep() or 1

	if direction == MouseWheelUp then
		self.scrollBar:setValue(value - step)
	elseif direction == MouseWheelDown then
		self.scrollBar:setValue(value + step)
	end

	return true
end

function UIPopupScrollMenu:onKeyPress(keyCode, keyboardModifiers)
	if keyCode == KeyEscape then
		self:destroy()

		return true
	end

	return false
end

local function onRootGeometryUpdate()
	if currentMenu then
		currentMenu:destroy()
	end
end

connect(rootWidget, {
	onGeometryChange = onRootGeometryUpdate
})
