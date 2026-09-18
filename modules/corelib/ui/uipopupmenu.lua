-- chunkname: @/corelib/ui/uipopupmenu.lua

UIPopupMenu = extends(UIWidget, "UIPopupMenu")

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

function UIPopupMenu.create()
	local menu = UIPopupMenu.internalCreate()
	local layout = UIVerticalLayout.create(menu)

	layout:setFitChildren(true)
	menu:setLayout(layout)

	menu.isGameMenu = false

	return menu
end

function UIPopupMenu:display(pos)
	if self:getChildCount() == 0 then
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

function UIPopupMenu:onGeometryChange(newRect, oldRect)
	local parent = self:getParent()

	if not parent then
		return
	end

	local ymax = parent:getY() + parent:getHeight()
	local xmax = parent:getX() + parent:getWidth()

	if ymax < newRect.y + newRect.height then
		local newy = ymax - newRect.height

		if newy > 0 and ymax > newy + newRect.height then
			self:setY(newy)
		end
	end

	if xmax < newRect.x + newRect.width then
		local newx = xmax - newRect.width

		if newx > 0 and xmax > newx + newRect.width then
			self:setX(newx)
		end
	end

	self:bindRectToParent()
end

local DEFAULT_SHORTCUT_TEXT_OFFSET = {
	y = 1,
	x = -1
}

local function applyShortcutLabelOffset(shortcutLabel, textOffset)
	textOffset = textOffset or DEFAULT_SHORTCUT_TEXT_OFFSET

	shortcutLabel:setTextOffset({
		x = textOffset.x or textOffset[1] or 0,
		y = textOffset.y or textOffset[2] or 0
	})
end

function UIPopupMenu:addOption(optionName, optionCallback, shortcut, disabled, options)
	options = options or {}

	local optionWidget = g_ui.createWidget(self:getStyleName() .. "Button", self)

	function optionWidget.onClick(widget)
		self:destroy()
		optionCallback(self:getPosition())
	end

	optionWidget:setText(optionName)

	local width = optionWidget:getTextSize().width + optionWidget:getMarginLeft() + optionWidget:getMarginRight() + 15

	if shortcut then
		local shortcutText = shortcut

		if type(shortcut) == "table" then
			shortcutText = shortcut.text or shortcut[1]
		end

		local shortcutLabel = g_ui.createWidget(self:getStyleName() .. "ShortcutLabel", optionWidget)

		shortcutLabel:setText(shortcutText)

		local shortcutColor = options.shortcutColor

		shortcutColor = type(shortcut) == "table" and (shortcut.color or shortcut[2]) or shortcutColor

		if shortcutColor then
			shortcutLabel:setColor(shortcutColor)
		end

		applyShortcutLabelOffset(shortcutLabel, options.shortcutTextOffset)

		width = width + shortcutLabel:getTextSize().width + shortcutLabel:getMarginLeft() + shortcutLabel:getMarginRight()
	end

	optionWidget:setEnabled(not disabled)

	local minWidth = options.minWidth or 190

	self:setWidth(math.max(minWidth, math.max(self:getWidth(), width)))

	return optionWidget
end

function UIPopupMenu:addSeparator()
	g_ui.createWidget(self:getStyleName() .. "Separator", self)
end

function UIPopupMenu:addText(text)
	local optionWidget = g_ui.createWidget("PopupScrollMenuShortcutLabel", self)

	optionWidget:setText(text)

	local width = optionWidget:getTextSize().width + optionWidget:getMarginLeft() + optionWidget:getMarginRight() + 15

	self:setWidth(math.max(self:getWidth(), width))
end

function UIPopupMenu:addCheckBox(text, checked, callback)
	local checkBox = g_ui.createWidget(self:getStyleName() .. "CheckBox", self)

	checkBox:setText(text)
	checkBox:setChecked(checked or false)

	function checkBox.onClick()
		checkBox:setChecked(not checkBox:isChecked())
		self:destroy()
		callback(checkBox, checkBox:isChecked())
	end

	local width = checkBox:getTextSize().width + checkBox:getMarginLeft() + checkBox:getMarginRight() + 30

	self:setWidth(math.max(self:getWidth(), width))

	return checkBox
end

function UIPopupMenu:setGameMenu(state)
	self.isGameMenu = state
end

function UIPopupMenu:onDestroy()
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

function UIPopupMenu:onMousePress(mousePos, mouseButton)
	if not self:containsPoint(mousePos) then
		self:destroy()
	end

	return true
end

function UIPopupMenu:onKeyPress(keyCode, keyboardModifiers)
	if keyCode == KeyEscape then
		self:destroy()

		return true
	end

	return false
end

function UIPopupMenu:addCheckBoxOption(optionName, optionCallback, shortcut, checked)
	local optionWidget = g_ui.createWidget(self:getStyleName() .. "CheckBox", self)

	function optionWidget.onClick(widget)
		optionCallback()
		self:destroy()
	end

	optionWidget:setText(optionName)
	optionWidget:setChecked(checked)

	local width = optionWidget:getTextSize().width + optionWidget:getMarginLeft() + optionWidget:getMarginRight() + 50

	if shortcut then
		local shortcutLabel = g_ui.createWidget(self:getStyleName() .. "ShortcutLabel", optionWidget)

		shortcutLabel:setText(shortcut)
		applyShortcutLabelOffset(shortcutLabel)

		width = width + shortcutLabel:getTextSize().width + shortcutLabel:getMarginLeft() + shortcutLabel:getMarginRight()
	end

	self:setWidth(math.max(self:getWidth(), width))

	return optionWidget
end

local function onRootGeometryUpdate()
	if currentMenu then
		currentMenu:destroy()
	end
end

local function onGameEnd()
	if currentMenu and currentMenu.isGameMenu then
		currentMenu:destroy()
	end
end

connect(rootWidget, {
	onGeometryChange = onRootGeometryUpdate
})
connect(g_game, {
	onGameEnd = onGameEnd
})
