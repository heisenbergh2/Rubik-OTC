-- chunkname: @/game_actionbar/logics/ActionBarLogic.lua

local BOTTOM_LOCK_WIDTH = 12
local BOTTOM_LOCK_MARGIN_TOP = 3
local BOTTOM_LOCK_MARGIN_RIGHT = 0
local BOTTOM_LOCK_SPEC = {
	{
		frameHeight = 34,
		source = "/images/game/actionbar/button-locked-vertical-one"
	},
	{
		frameHeight = 70,
		source = "/images/game/actionbar/button-locked-vertical-two"
	},
	{
		frameHeight = 106,
		source = "/images/game/actionbar/button-locked-vertical-three"
	}
}
local bottomLockStyleFixEvent
local LOCK_HOME_KEY = "_actionBarBottomLockHomeId"

local function bottomLockClipAt(lines, pressed)
	local spec = BOTTOM_LOCK_SPEC[lines]

	if not spec then
		return nil
	end

	local h = spec.frameHeight
	local x = isActionBarGroupLocked("bottom") and 24 or 0

	if pressed then
		x = x + 12
	end

	return string.format("%d 0 12 %d", x, h)
end

function applyBottomLockAppearance(pressedOverride, btnOpt)
	local btn = btnOpt or bottomLockButton

	if not btn or btn:isDestroyed() or not btn:isVisible() then
		return
	end

	btn:setImageOffset("0 0")

	if btn.setTextOffset then
		btn:setTextOffset("0 0")
	end

	local lines = btn.lockLineCount or 1
	local spec = BOTTOM_LOCK_SPEC[lines]

	if not spec then
		return
	end

	btn:setImageSource(spec.source)

	local pressed = pressedOverride

	if pressed == nil then
		pressed = btn._lockSkinPressed ~= nil and btn._lockSkinPressed or btn:isPressed()
	end

	local clip = bottomLockClipAt(lines, pressed)

	if clip then
		btn:setImageClip(clip)
	end
end

local function cancelBottomLockStyleFix()
	if bottomLockStyleFixEvent then
		removeEvent(bottomLockStyleFixEvent)

		bottomLockStyleFixEvent = nil
	end
end

local function wireBottomLockPressFeedback(btn)
	if not btn or btn:isDestroyed() then
		return
	end

	function btn.onStyleApply(widget, styleName, styleNode)
		cancelBottomLockStyleFix()
		applyBottomLockAppearance(nil, widget)

		bottomLockStyleFixEvent = scheduleEvent(function()
			bottomLockStyleFixEvent = nil

			if widget and not widget:isDestroyed() then
				applyBottomLockAppearance(nil, widget)
			end
		end, 0)
	end

	function btn.onMousePress(widget, mousePos, mouseButton)
		if mouseButton ~= MouseLeftButton then
			return false
		end

		bottomLockButton = widget
		widget._lockSkinPressed = true

		applyBottomLockAppearance(true, widget)

		return true
	end

	function btn.onMouseRelease(widget, mousePos, mouseButton)
		if mouseButton ~= MouseLeftButton then
			return false
		end

		cancelBottomLockStyleFix()

		bottomLockButton = widget
		widget._lockSkinPressed = false

		applyBottomLockAppearance(false, widget)

		return true
	end
end

local function returnAllBottomLocksFromBottomPanel()
	local panel = bottomPanel

	if not panel or panel:isDestroyed() then
		return
	end

	local children = panel:getChildren()

	if not children then
		return
	end

	local orphans = {}

	for _, w in pairs(children) do
		if w and not w:isDestroyed() and w:getId() == "bottomLockButton" then
			orphans[#orphans + 1] = w
		end
	end

	for _, w in ipairs(orphans) do
		local hid = w[LOCK_HOME_KEY]
		local home = hid and actionBars[hid]

		if not home or home:isDestroyed() then
			home = nil

			for bid = BAR_BOTTOM_1, BAR_BOTTOM_3 do
				local b = actionBars[bid]

				if b and not b:isDestroyed() and not barWidgetChild(b, "bottomLockButton") then
					home = b

					break
				end
			end
		end

		if home and not home:isDestroyed() then
			w:breakAnchors()
			w:setParent(home)
			w:addAnchor(AnchorTop, "parent", AnchorTop)
			w:addAnchor(AnchorRight, "parent", AnchorRight)
			w:setMarginTop(BOTTOM_LOCK_MARGIN_TOP)
			w:setMarginRight(BOTTOM_LOCK_MARGIN_RIGHT)
			w:hide()

			w[LOCK_HOME_KEY] = nil
		end
	end
end

function layoutBottomLockButton()
	returnAllBottomLocksFromBottomPanel()

	local visibleBars = {}

	for barId = BAR_BOTTOM_1, BAR_BOTTOM_3 do
		local bar = actionBars[barId]

		if bar and not bar:isDestroyed() and bar:isVisible() and bar:getHeight() > 0 then
			table.insert(visibleBars, bar)
		end
	end

	for barId = BAR_BOTTOM_1, BAR_BOTTOM_3 do
		local bar = actionBars[barId]

		if bar and not bar:isDestroyed() then
			local b = barWidgetChild(bar, "bottomLockButton")

			if b then
				b:hide()
			end
		end
	end

	local n = #visibleBars

	if n == 0 then
		bottomLockButton = nil

		return
	end

	local hostBar = visibleBars[1]
	local hostBarId

	for barId = BAR_BOTTOM_1, BAR_BOTTOM_3 do
		local bar = actionBars[barId]

		if bar and not bar:isDestroyed() and bar:isVisible() and bar:getHeight() > 0 then
			hostBarId = barId

			break
		end
	end

	local btn = barWidgetChild(hostBar, "bottomLockButton")

	if not btn or btn:isDestroyed() or not hostBarId then
		bottomLockButton = nil

		return
	end

	local panel = bottomPanel

	bottomLockButton = btn
	btn.lockLineCount = math.min(n, 3)

	local spec = BOTTOM_LOCK_SPEC[btn.lockLineCount]

	if spec then
		btn:setHeight(spec.frameHeight)
		btn:setWidth(BOTTOM_LOCK_WIDTH)
	end

	if panel and not panel:isDestroyed() then
		btn:breakAnchors()
		btn:setParent(panel)

		btn[LOCK_HOME_KEY] = hostBarId

		btn:addAnchor(AnchorTop, hostBar:getId(), AnchorTop)
		btn:addAnchor(AnchorRight, hostBar:getId(), AnchorRight)
		btn:setMarginTop(BOTTOM_LOCK_MARGIN_TOP)
		btn:setMarginRight(BOTTOM_LOCK_MARGIN_RIGHT)
		panel:raiseChild(btn)
	else
		btn[LOCK_HOME_KEY] = nil

		btn:breakAnchors()
		btn:setParent(hostBar)
		btn:addAnchor(AnchorTop, "parent", AnchorTop)
		btn:addAnchor(AnchorRight, "parent", AnchorRight)
		btn:setMarginTop(BOTTOM_LOCK_MARGIN_TOP)
		btn:setMarginRight(BOTTOM_LOCK_MARGIN_RIGHT)
		hostBar:raiseChild(btn)
	end

	btn:show()
	wireBottomLockPressFeedback(btn)
	applyBottomLockAppearance(false, btn)
end

function setupBottomLockButton()
	if not bottomPanel or bottomPanel:isDestroyed() then
		return
	end

	local bar = actionBars[BAR_BOTTOM_1]

	if not bar or bar:isDestroyed() then
		return
	end

	bottomLockButton = barWidgetChild(bar, "bottomLockButton")

	if not bottomLockButton then
		return
	end

	layoutBottomLockButton()
end

local SIDE_LOCK_HEIGHT = 16
local SIDE_LOCK_SPEC = {
	{
		frameWidth = 34,
		source = "/assets/images/game/actionbar/button-locked-horizontal-one"
	},
	{
		frameWidth = 70,
		source = "/assets/images/game/actionbar/button-locked-horizontal-two"
	},
	{
		frameWidth = 106,
		source = "/assets/images/game/actionbar/button-locked-horizontal-three"
	}
}

sideLockButtonLeft = nil
sideLockButtonRight = nil

local sideLockPressed = {
	left = false,
	right = false
}

local function sideLockClipAt(bars, pressed)
	local spec = SIDE_LOCK_SPEC[bars]

	if not spec then
		return nil
	end

	local x = 0
	local w = spec.frameWidth
	local y = 0

	if pressed then
		y = y + 16
	end

	return string.format("%d %d %d 16", x, y, w)
end

function applySideLockAppearance(pressedOverride, btn)
	if not btn or btn:isDestroyed() or not btn:isVisible() then
		return
	end

	local bars = btn.lockBarCount or 1
	local spec = SIDE_LOCK_SPEC[bars]

	if not spec then
		return
	end

	btn:setImageSource(spec.source)

	local pressed = pressedOverride

	if pressed == nil then
		local group = btn.lockGroup

		pressed = group and sideLockPressed[group] or btn._lockSkinPressed ~= nil and btn._lockSkinPressed or btn:isPressed()
	end

	local clip = sideLockClipAt(bars, pressed)
	local locked = isActionBarGroupLocked(btn.lockGroup)

	if btn.lockSegmentIndex then
		local x = (btn.lockSegmentIndex - 1) * 36
		local w = math.min(36, spec.frameWidth - x)
		local y = locked and 32 or 0

		if pressed then
			y = y + 16
		end

		clip = string.format("%d %d %d 16", x, y, w)
	else
		local y = locked and 32 or 0

		if pressed then
			y = y + 16
		end

		clip = string.format("0 %d %d 16", y, spec.frameWidth)
	end

	if clip then
		btn:setImageClip(clip)
	end
end

local function applySideLockGroupAppearance(group, pressedOverride)
	local ids

	if group == "left" then
		ids = {
			BAR_LEFT_1,
			BAR_LEFT_2,
			BAR_LEFT_3
		}
	elseif group == "right" then
		ids = {
			BAR_RIGHT_1,
			BAR_RIGHT_2,
			BAR_RIGHT_3
		}
	else
		return
	end

	for _, bid in ipairs(ids) do
		local bar = actionBars[bid]

		if bar and not bar:isDestroyed() then
			local btn = barWidgetChild(bar, "sideLockButton")

			if btn and not btn:isDestroyed() and btn:isVisible() then
				applySideLockAppearance(pressedOverride, btn)
			end
		end
	end
end

local function wireSideLockPressFeedback(btn, onActive)
	if not btn or btn:isDestroyed() then
		return
	end

	function btn.onStyleApply(widget, styleName, styleNode)
		applySideLockAppearance(nil, widget)
	end

	function btn.onMousePress(widget, mousePos, mouseButton)
		if mouseButton ~= MouseLeftButton then
			return false
		end

		onActive(widget)

		widget._lockSkinPressed = true

		if widget.lockGroup then
			sideLockPressed[widget.lockGroup] = true

			applySideLockGroupAppearance(widget.lockGroup, true)
		else
			applySideLockAppearance(true, widget)
		end

		return true
	end

	function btn.onMouseRelease(widget, mousePos, mouseButton)
		if mouseButton ~= MouseLeftButton then
			return false
		end

		onActive(widget)

		widget._lockSkinPressed = false

		if widget.lockGroup then
			sideLockPressed[widget.lockGroup] = false

			applySideLockGroupAppearance(widget.lockGroup, false)
		else
			applySideLockAppearance(false, widget)
		end

		return true
	end
end

function layoutSideLockButton(side)
	local isLeftSide = side == "left"
	local visualOrder

	if isLeftSide then
		visualOrder = {
			BAR_LEFT_3,
			BAR_LEFT_2,
			BAR_LEFT_1
		}
	else
		visualOrder = {
			BAR_RIGHT_1,
			BAR_RIGHT_2,
			BAR_RIGHT_3
		}
	end

	for _, bid in ipairs(visualOrder) do
		local bar = actionBars[bid]

		if bar and not bar:isDestroyed() then
			local b = barWidgetChild(bar, "sideLockButton")

			if b then
				b:hide()
			end
		end
	end

	local visibleBars = {}

	for _, bid in ipairs(visualOrder) do
		local bar = actionBars[bid]

		if bar and not bar:isDestroyed() and bar:getWidth() > 0 then
			table.insert(visibleBars, bar)
		end
	end

	local n = #visibleBars

	if n == 0 then
		if isLeftSide then
			sideLockButtonLeft = nil
		else
			sideLockButtonRight = nil
		end

		return
	end

	local firstButton

	for index, bar in ipairs(visibleBars) do
		local btn = barWidgetChild(bar, "sideLockButton")

		if btn and not btn:isDestroyed() then
			btn.lockBarCount = math.min(n, 3)
			btn.lockSegmentIndex = n > 1 and index or nil
			btn.lockGroup = isLeftSide and "left" or "right"

			function btn.onClick(widget)
				local group = widget.lockGroup or isLeftSide and "left" or "right"

				setLocked(not getLocked(group), group)
			end

			if btn.lockSegmentIndex then
				local spec = SIDE_LOCK_SPEC[btn.lockBarCount]
				local x = (btn.lockSegmentIndex - 1) * 36

				btn:setWidth(spec and math.min(36, spec.frameWidth - x) or 34)
				btn:setMarginLeft(isLeftSide and 0 or 2)
			else
				btn:setWidth(34)
			end

			btn:setHeight(SIDE_LOCK_HEIGHT)
			btn:setMarginBottom(1)
			btn:show()

			if isLeftSide then
				wireSideLockPressFeedback(btn, function(w)
					sideLockButtonLeft = w
				end)
			else
				wireSideLockPressFeedback(btn, function(w)
					sideLockButtonRight = w
				end)
			end

			applySideLockAppearance(false, btn)

			firstButton = firstButton or btn
		end
	end

	if isLeftSide then
		sideLockButtonLeft = firstButton
	else
		sideLockButtonRight = firstButton
	end
end

function updateScrollButtonsForBar(bar)
	if not bar or bar:isDestroyed() then
		return
	end

	local horizontalScroll = barWidgetChild(bar, "horizontalScroll")
	local verticalScroll = barWidgetChild(bar, "verticalScroll")
	local scroll = horizontalScroll or verticalScroll

	if not scroll then
		return
	end

	local prevBtn = barWidgetChild(bar, "prevButton")
	local prevSkip = barWidgetChild(bar, "prevSkipButton")
	local nextBtn = barWidgetChild(bar, "nextButton")
	local nextSkip = barWidgetChild(bar, "nextSkipButton")
	local atMax = scroll:getValue() >= scroll:getMaximum()
	local atMin = scroll:getValue() <= scroll:getMinimum()

	if nextBtn then
		nextBtn:setEnabled(not atMax)
	end

	if nextSkip then
		nextSkip:setEnabled(not atMax)
	end

	if prevBtn then
		prevBtn:setEnabled(not atMin)
	end

	if prevSkip then
		prevSkip:setEnabled(not atMin)
	end
end

function updateScrollButtons()
	for barId = 1, NUM_BARS do
		updateScrollButtonsForBar(actionBars[barId])
	end
end

ActionBarHotkeyLogic = {}

local HOTKEY_OVERWRITE_TEXT = tr("This hotkey is already in use and will be overwritten.")

function ActionBarHotkeyLogic.formatHotkeyDisplayText(combo)
	if combo == nil or combo == "" then
		return ""
	end

	local text = combo

	if type(text) ~= "string" then
		text = tostring(text)
	end

	local function mouseBaseShort(base)
		if base == "MouseWheelUp" then
			return "M:"
		end

		if base == "MouseWheelDown" then
			return "M;"
		end

		if base == "MouseMiddle" then
			return "M3"
		end

		local mouseNum = base:match("^Mouse(%d+)$")

		if mouseNum then
			return "M" .. mouseNum
		end

		return base
	end

	if g_mouse and g_mouse.getBaseMouseHotkeyDesc then
		local mouseBase = g_mouse.getBaseMouseHotkeyDesc(text)

		if mouseBase then
			local modPart = text:sub(1, #text - #mouseBase)

			if modPart:sub(-1) == "+" then
				modPart = modPart:sub(1, -2)
			end

			local modShort = modPart

			if modShort ~= "" then
				modShort = modShort:gsub("Shift", "S"):gsub("Alt", "A"):gsub("Ctrl", "C"):gsub("+", "")
			end

			return modShort .. mouseBaseShort(mouseBase)
		end
	end

	if text == "MouseWheelUp" then
		return "M:"
	end

	if text == "MouseWheelDown" then
		return "M;"
	end

	if text == "MouseMiddle" then
		return "M3"
	end

	local mouseNum = text:match("^Mouse(%d+)$")

	if mouseNum then
		return "M" .. mouseNum
	end

	return g_keyboard.formatHotkeyDisplayText(text)
end

function ActionBarHotkeyLogic.formatHotkeyTooltipText(combo)
	if combo == nil or combo == "" then
		return ""
	end

	local text = combo

	if type(text) ~= "string" then
		text = tostring(text)
	end

	if g_mouse and g_mouse.getBaseMouseHotkeyDesc and g_mouse.getBaseMouseHotkeyDesc(text) then
		return text
	end

	if text == "MouseWheelUp" or text == "MouseWheelDown" or text == "MouseMiddle" or text:match("^Mouse(%d+)$") then
		return text
	end

	return g_keyboard.formatHotkeyTooltipText(text)
end

function ActionBarHotkeyLogic.formatHotkeySlotText(combo)
	return g_keyboard.truncateHotkeySlotText(ActionBarHotkeyLogic.formatHotkeyDisplayText(combo))
end

function ActionBarHotkeyLogic.updateHotkeyCaptureUI(assignWindow, keyCombo, excludeSlotId)
	assignWindow:raise()
	assignWindow:focus()

	local comboPreview = assignWindow:recursiveGetChildById("comboPreview")
	local errorLabel = editHotkeyWindow and editHotkeyWindow:recursiveGetChildById("errorLabel")
	local applyButton = editHotkeyWindow and editHotkeyWindow:recursiveGetChildById("applyButton")

	keyCombo = keyCombo or ""
	editHotkeyPendingCombo = keyCombo

	if comboPreview then
		comboPreview:setText(tr("%s", keyCombo))
		comboPreview:resizeToText()
	end

	local forbidden = g_keyboard.isReservedMovementHotkey(keyCombo)
	local inUse = keyCombo ~= "" and checkHotkey(keyCombo, excludeSlotId)

	if not inUse and keyCombo ~= "" then
		local chatMode = modules.game_console and modules.game_console.isChatEnabled and modules.game_console.isChatEnabled() and CHAT_MODE.ON or CHAT_MODE.OFF

		if Keybind and Keybind.isKeyComboUsedOnCustomHotkeys then
			inUse = Keybind.isKeyComboUsedOnCustomHotkeys(keyCombo, chatMode)
		elseif CustomHotkeyManager and CustomHotkeyManager.isKeyComboUsed then
			inUse = CustomHotkeyManager.isKeyComboUsed(keyCombo, nil, chatMode)
		end
	end

	if errorLabel then
		if forbidden then
			errorLabel:setText(g_keyboard.getReservedHotkeyErrorText())
			errorLabel:setVisible(true)
		elseif inUse then
			errorLabel:setText(HOTKEY_OVERWRITE_TEXT)
			errorLabel:setVisible(true)
		else
			errorLabel:setVisible(false)
		end
	end

	if applyButton then
		applyButton:setEnabled(keyCombo ~= "" and not forbidden)
	end
end
