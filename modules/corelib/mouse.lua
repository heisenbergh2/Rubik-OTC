-- chunkname: @/corelib/mouse.lua

function g_mouse.bindAutoPress(widget, callback, delay, button)
	local button = button or MouseLeftButton

	connect(widget, {
		onMousePress = function(widget, mousePos, mouseButton)
			if mouseButton ~= button then
				return false
			end

			local startTime = g_clock.millis()

			callback(widget, mousePos, mouseButton, 0)
			periodicalEvent(function()
				callback(widget, g_window.getMousePosition(), mouseButton, g_clock.millis() - startTime)
			end, function()
				return g_mouse.isPressed(mouseButton)
			end, 30, delay)

			return true
		end
	})
end

function g_mouse.bindPressMove(widget, callback)
	connect(widget, {
		onMouseMove = function(widget, mousePos, mouseMoved)
			if widget:isPressed() then
				callback(mousePos, mouseMoved)

				return true
			end
		end
	})
end

function g_mouse.bindMove(widget, callback)
	connect(widget, {
		onMouseMove = function(widget, mousePos, mouseMoved)
			callback(mousePos, mouseMoved)

			return true
		end
	})
end

function g_mouse.bindPress(widget, callback, button)
	connect(widget, {
		onMousePress = function(widget, mousePos, mouseButton)
			if not button or button == mouseButton then
				callback(mousePos, mouseButton)

				return true
			end

			return false
		end
	})
end

function g_mouse.bindOnDrop(widget, callback)
	connect(widget, {
		onDrop = function(widget, mousePos)
			callback(mousePos, mouseButton)

			return true
		end
	})
end

if not g_mouse.grabbedMouse then
	g_mouse.grabbedMouse = {}
end

function g_mouse.updateGrabber(widget, mouse)
	if not g_mouse.grabbedMouse[widget] then
		g_mouse.grabbedMouse[widget] = mouse
	else
		g_mouse.grabbedMouse[widget] = nil
	end
end

function g_mouse.clearGrabber()
	for widget, mouse in pairs(g_mouse.grabbedMouse) do
		if mouse ~= "" then
			g_mouse.popCursor(mouse)
		end

		widget:ungrabMouse()
	end

	g_mouse.grabbedMouse = {}
end

local MOUSE_HOTKEY_WHEEL_DESCS = {
	[MouseWheelUp] = "MouseWheelUp",
	[MouseWheelDown] = "MouseWheelDown"
}
local MOUSE_HOTKEY_BUTTON_DESCS = {
	[MouseMidButton] = "MouseMiddle",
	[Mouse4] = "Mouse4",
	[Mouse5] = "Mouse5",
	[Mouse6] = "Mouse6",
	[Mouse7] = "Mouse7",
	[Mouse8] = "Mouse8",
	[Mouse9] = "Mouse9",
	[Mouse10] = "Mouse10",
	[Mouse11] = "Mouse11",
	[Mouse12] = "Mouse12",
	[Mouse13] = "Mouse13",
	[Mouse14] = "Mouse14",
	[Mouse15] = "Mouse15",
	[Mouse16] = "Mouse16"
}
local MOUSE_HOTKEY_DESC_LOOKUP = {}

for _, desc in pairs(MOUSE_HOTKEY_WHEEL_DESCS) do
	MOUSE_HOTKEY_DESC_LOOKUP[desc] = true
end

for _, desc in pairs(MOUSE_HOTKEY_BUTTON_DESCS) do
	MOUSE_HOTKEY_DESC_LOOKUP[desc] = true
end

local MOUSE_HOTKEY_WHEEL_CALLBACKS = {}

local function isWheelBaseDesc(desc)
	return desc == "MouseWheelUp" or desc == "MouseWheelDown"
end

local function modifiersToHotkeyPrefix(keyboardModifiers)
	local parts = {}

	if bit.band(keyboardModifiers, KeyboardCtrlModifier) ~= 0 then
		table.insert(parts, "Ctrl")
	end

	if bit.band(keyboardModifiers, KeyboardAltModifier) ~= 0 then
		table.insert(parts, "Alt")
	end

	if bit.band(keyboardModifiers, KeyboardShiftModifier) ~= 0 then
		table.insert(parts, "Shift")
	end

	if #parts == 0 then
		return ""
	end

	return table.concat(parts, "+") .. "+"
end

function g_mouse.getBaseMouseHotkeyDesc(desc)
	if desc == nil or desc == "" then
		return nil
	end

	if type(desc) ~= "string" then
		desc = tostring(desc)
	end

	if MOUSE_HOTKEY_DESC_LOOKUP[desc] then
		return desc
	end

	local base = desc:match("([^+]+)$")

	if base and MOUSE_HOTKEY_DESC_LOOKUP[base] then
		return base
	end

	return nil
end

function g_mouse.applyModifierPrefix(baseDesc, keyboardModifiers)
	if not baseDesc then
		return nil
	end

	if keyboardModifiers == nil then
		keyboardModifiers = g_window.getKeyboardModifiers()
	end

	local prefix = modifiersToHotkeyPrefix(keyboardModifiers)

	if prefix == "" then
		return baseDesc
	end

	return prefix .. baseDesc
end

function g_mouse.buildMouseHotkeyDesc(mouseButton, keyboardModifiers)
	return g_mouse.applyModifierPrefix(MOUSE_HOTKEY_BUTTON_DESCS[mouseButton], keyboardModifiers)
end

function g_mouse.buildWheelHotkeyDesc(direction, keyboardModifiers)
	return g_mouse.applyModifierPrefix(MOUSE_HOTKEY_WHEEL_DESCS[direction], keyboardModifiers)
end

function g_mouse.dispatchWheelHotkey(direction)
	if g_ui.isMouseGrabbed() then
		return
	end

	if HotkeyUtils.areHotkeysDisabled() then
		return
	end

	local tick = g_clock.millis()

	if g_mouse._wheelDispatchTick == tick and g_mouse._wheelDispatchDir == direction then
		return
	end

	g_mouse._wheelDispatchTick = tick
	g_mouse._wheelDispatchDir = direction

	local desc = g_mouse.buildWheelHotkeyDesc(direction)

	if not desc then
		return
	end

	local callbacks = MOUSE_HOTKEY_WHEEL_CALLBACKS[desc]

	if not callbacks then
		return
	end

	for _, cb in ipairs(callbacks) do
		signalcall(cb, direction)
	end
end

local function ensureMouseWheelHotkeyDispatch(widget)
	if not widget or widget._mouseWheelHotkeyDispatchConnected then
		return
	end

	widget._mouseWheelHotkeyDispatchConnected = true

	connect(widget, {
		onMouseWheel = function(_, mousePos, direction)
			g_mouse.dispatchWheelHotkey(direction)

			return false
		end
	}, true)
end

local function ensureGlobalWheelHotkeyDispatch(widget)
	ensureMouseWheelHotkeyDispatch(widget or rootWidget)

	if modules.game_interface then
		if modules.game_interface.getRootPanel then
			ensureMouseWheelHotkeyDispatch(modules.game_interface.getRootPanel())
		end

		if modules.game_interface.getMapPanel then
			ensureMouseWheelHotkeyDispatch(modules.game_interface.getMapPanel())
		end
	end
end

function g_mouse.hookWidgetWheelHotkeys(widget, blockEvent)
	if not widget or widget._mouseWheelHotkeyHooked then
		return
	end

	widget._mouseWheelHotkeyHooked = true

	connect(widget, {
		onMouseWheel = function(_, mousePos, direction)
			g_mouse.dispatchWheelHotkey(direction)

			return blockEvent == true
		end
	}, true)
end

function g_mouse.isMouseHotkeyDesc(desc)
	return g_mouse.getBaseMouseHotkeyDesc(desc) ~= nil
end

function g_mouse.mouseButtonToHotkeyDesc(mouseButton, keyboardModifiers)
	return g_mouse.buildMouseHotkeyDesc(mouseButton, keyboardModifiers)
end

function g_mouse.wheelDirectionToHotkeyDesc(direction, keyboardModifiers)
	return g_mouse.buildWheelHotkeyDesc(direction, keyboardModifiers)
end

local function getMouseHotkeyUnbindArgs(arg1, arg2)
	local callback, widget

	if type(arg1) == "function" then
		callback = arg1
	elseif type(arg2) == "function" then
		callback = arg2
	end

	if type(arg1) == "userdata" then
		widget = arg1
	elseif type(arg2) == "userdata" then
		widget = arg2
	end

	widget = widget or rootWidget

	return callback, widget
end

local function ensureMouseHotkeyHandlers(widget)
	if widget._mouseHotkeyPressConnected then
		return
	end

	widget._mouseHotkeyPressConnected = true
	widget._mouseHotkeyPressCombos = widget._mouseHotkeyPressCombos or {}

	connect(widget, {
		onMousePress = function(w, mousePos, mouseButton)
			if HotkeyUtils.areHotkeysDisabled() then
				return false
			end

			local desc = g_mouse.buildMouseHotkeyDesc(mouseButton)

			if not desc then
				return false
			end

			local callbacks = w._mouseHotkeyPressCombos[desc]

			if not callbacks then
				return false
			end

			for _, cb in ipairs(callbacks) do
				signalcall(cb, w, mousePos, mouseButton)
			end

			return false
		end
	}, true)
end

function g_mouse.bindHotkeyPress(hotkeyDesc, callback, widget)
	if not g_mouse.isMouseHotkeyDesc(hotkeyDesc) or type(callback) ~= "function" then
		return
	end

	local baseDesc = g_mouse.getBaseMouseHotkeyDesc(hotkeyDesc)

	if isWheelBaseDesc(baseDesc) then
		MOUSE_HOTKEY_WHEEL_CALLBACKS[hotkeyDesc] = MOUSE_HOTKEY_WHEEL_CALLBACKS[hotkeyDesc] or {}

		table.insert(MOUSE_HOTKEY_WHEEL_CALLBACKS[hotkeyDesc], callback)
		ensureGlobalWheelHotkeyDispatch(widget)

		return
	end

	widget = widget or rootWidget

	ensureMouseHotkeyHandlers(widget)

	widget._mouseHotkeyPressCombos[hotkeyDesc] = widget._mouseHotkeyPressCombos[hotkeyDesc] or {}

	table.insert(widget._mouseHotkeyPressCombos[hotkeyDesc], callback)
end

local function removeMouseHotkeyCallback(list, callback)
	if not list then
		return
	end

	if callback then
		for i = #list, 1, -1 do
			if list[i] == callback then
				table.remove(list, i)
			end
		end
	else
		for i = #list, 1, -1 do
			table.remove(list, i)
		end
	end
end

function g_mouse.unbindHotkeyPress(hotkeyDesc, arg1, arg2)
	if not g_mouse.isMouseHotkeyDesc(hotkeyDesc) then
		return
	end

	local callback = type(arg1) == "function" and arg1 or type(arg2) == "function" and arg2 or nil
	local baseDesc = g_mouse.getBaseMouseHotkeyDesc(hotkeyDesc)

	if isWheelBaseDesc(baseDesc) then
		removeMouseHotkeyCallback(MOUSE_HOTKEY_WHEEL_CALLBACKS[hotkeyDesc], callback)

		return
	end

	local _, widget = getMouseHotkeyUnbindArgs(arg1, arg2)

	if not widget._mouseHotkeyPressConnected then
		return
	end

	removeMouseHotkeyCallback(widget._mouseHotkeyPressCombos and widget._mouseHotkeyPressCombos[hotkeyDesc], callback)
end

function g_mouse.bindComboHotkeyPress(combo, callback, widget)
	if combo == nil or combo == "" or type(callback) ~= "function" then
		return
	end

	if g_mouse.isMouseHotkeyDesc(combo) then
		g_mouse.bindHotkeyPress(combo, callback, widget or rootWidget)
	else
		g_keyboard.bindKeyPress(combo, callback, widget)
	end
end

function g_mouse.unbindComboHotkeyPress(combo, widget)
	if combo == nil or combo == "" then
		return
	end

	if g_mouse.isMouseHotkeyDesc(combo) then
		g_mouse.unbindHotkeyPress(combo, widget or rootWidget)
	else
		g_keyboard.unbindKeyPress(combo, widget)
	end
end
