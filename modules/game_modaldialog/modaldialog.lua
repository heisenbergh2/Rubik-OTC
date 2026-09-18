-- chunkname: @/game_modaldialog/modaldialog.lua

modalDialog = nil

local imbuementHiddenForFyiModal = false

function init()
	g_ui.importStyle("modaldialog")
	connect(g_game, {
		onModalDialog = onModalDialog,
		onGameEnd = destroyDialog
	})

	local dialog = rootWidget:recursiveGetChildById("modalDialog")

	if dialog then
		modalDialog = dialog
	end
end

function terminate()
	g_client.setInputLockWidget(nil)

	local hadHiddenImbue = imbuementHiddenForFyiModal

	if imbuementHiddenForFyiModal then
		imbuementHiddenForFyiModal = false

		local Im = modules.game_imbuing and modules.game_imbuing.Imbuement

		if Im and Im.tryShowAfterOverlay then
			Im:tryShowAfterOverlay()
		end
	end

	disconnect(g_game, {
		onModalDialog = onModalDialog,
		onGameEnd = destroyDialog
	})

	if modalDialog then
		modalDialog:destroy()

		modalDialog = nil
	end

	if not hadHiddenImbue then
		local Im = modules.game_imbuing and modules.game_imbuing.Imbuement

		if Im and Im.window and not Im.window:isDestroyed() and Im.window:isVisible() then
			g_client.setInputLockWidget(Im.window)
		end
	end
end

local function modalTitleIsForYourInformation(title)
	if not title or type(title) ~= "string" then
		return false
	end

	local tl = title:lower()

	return tl == "for your information" or tl == tr("For Your Information"):lower()
end

function destroyDialog()
	g_client.setInputLockWidget(nil)

	local hadHiddenImbue = imbuementHiddenForFyiModal

	if imbuementHiddenForFyiModal then
		imbuementHiddenForFyiModal = false

		local Im = modules.game_imbuing and modules.game_imbuing.Imbuement

		if Im and Im.tryShowAfterOverlay then
			Im:tryShowAfterOverlay()
		end
	end

	if modalDialog then
		modalDialog:destroy()

		modalDialog = nil
	end

	if not hadHiddenImbue then
		local Im = modules.game_imbuing and modules.game_imbuing.Imbuement

		if Im and Im.window and not Im.window:isDestroyed() and Im.window:isVisible() then
			g_client.setInputLockWidget(Im.window)
		end
	end
end

function onModalDialog(id, title, message, buttons, enterButton, escapeButton, choices, priority)
	if modalDialog then
		return
	end

	local defaultButton = enterButton
	local cancelButton = escapeButton

	if modalTitleIsForYourInformation(title) then
		local Im = modules.game_imbuing and modules.game_imbuing.Imbuement

		if Im and Im.tryHideForOverlay then
			imbuementHiddenForFyiModal = Im:tryHideForOverlay()
		end
	end

	modalDialog = g_ui.createWidget("ModalDialog", rootWidget)

	modalDialog:setMinHeight(100)

	local messageLabel = modalDialog:getChildById("messageLabel")
	local choiceList = modalDialog:getChildById("choiceList")
	local choiceScrollbar = modalDialog:getChildById("choiceScrollBar")
	local buttonsPanel = modalDialog:getChildById("buttonsPanel")

	modalDialog:setText(title)
	messageLabel:setText(message)

	if messageLabel.setFont then
		messageLabel:setFont("Verdana Bold-11px-new")
	end

	local labelHeight
	local useZebra = #choices >= 2

	for i = 1, #choices do
		local choiceId = choices[i][1]
		local choiceName = choices[i][2]
		local labelStyle = (not useZebra or i % 2 == 1) and "ChoiceListLabelOdd" or "ChoiceListLabelEven"
		local label = g_ui.createWidget(labelStyle, choiceList)

		label.choiceId = choiceId

		label:setText(choiceName)
		label:setPhantom(false)

		labelHeight = labelHeight or label:getHeight()
	end

	local choiceSeparator = modalDialog:getChildById("choiceSeparator")
	local additionalHeight = 0
	local listSeparatorGap = 0
	local visibleRows = 0
	local hasChoices = #choices > 0

	if hasChoices then
		choiceList:setVisible(true)
		choiceScrollbar:setVisible(true)

		visibleRows = math.min(modalDialog.maximumChoices, math.max(modalDialog.minimumChoices, #choices))
		listSeparatorGap = choiceList:getMarginBottom()

		local listContentHeight = visibleRows * labelHeight + choiceList:getPaddingTop() + choiceList:getPaddingBottom()

		choiceList:setHeight(listContentHeight)
		choiceList:setMarginBottom(0)
		choiceSeparator:breakAnchors()
		choiceSeparator:addAnchor(AnchorTop, "choiceList", AnchorBottom)
		choiceSeparator:setMarginTop(listSeparatorGap)
		choiceSeparator:setHeight(2)
		choiceSeparator:setFixedSize(true)
		choiceSeparator:addAnchor(AnchorLeft, "parent", AnchorLeft)
		choiceSeparator:addAnchor(AnchorRight, "parent", AnchorRight)

		additionalHeight = choiceList:getMarginTop() + listContentHeight + listSeparatorGap
	end

	if #choices > 0 then
		choiceList:focusChild(choiceList:getFirstChild())
	end

	local answered = false

	local function answer(buttonId, choice)
		if answered then
			return
		end

		answered = true

		g_game.answerModalDialog(id, buttonId, choice)
		destroyDialog()
	end

	local function currentChoiceId()
		local focusedChoice = choiceList:getFocusedChild()

		if focusedChoice then
			return focusedChoice.choiceId
		end

		return 255
	end

	for i = 1, #buttons do
		local buttonId = buttons[i][1]
		local buttonText = buttons[i][2]
		local button = g_ui.createWidget("ModalButton", buttonsPanel)

		button:setText(buttonText)
		button:setSize("43 20")
		button:setFixedSize(true)
		button:setTextOffset("0 1")

		if i < #buttons then
			button:setMarginRight(10)
		elseif i == #buttons then
			button:setMarginRight(-1)
		end

		function button:onClick()
			answer(buttonId, currentChoiceId())
		end
	end

	modalDialog:setWidth(modalDialog.maximumWidth)

	if messageLabel.resizeToText then
		messageLabel:resizeToText()
	end

	local messageHeight = math.max(14, messageLabel:getTextSize().height)
	local paddingTop = modalDialog:getPaddingTop()
	local paddingBottom = modalDialog:getPaddingBottom()
	local buttonsHeight = buttonsPanel:getHeight()
	local separatorBlock = hasChoices and 22 - listSeparatorGap or 22
	local modalHeight = paddingTop + messageHeight + 4 + separatorBlock + buttonsHeight + paddingBottom + additionalHeight

	if hasChoices and visibleRows > modalDialog.minimumChoices then
		modalHeight = modalHeight - 1
	end

	modalDialog:setHeight(math.max(100, modalHeight))

	if messageLabel.setFont then
		messageLabel:setFont("Verdana Bold-11px-new")
	end

	local function isRealButton(buttonId)
		if not buttonId then
			return false
		end

		for i = 1, #buttons do
			if buttons[i][1] == buttonId then
				return true
			end
		end

		return false
	end

	local enterButtonId = isRealButton(defaultButton) and defaultButton or buttons[1] and buttons[1][1]
	local escapeButtonId = isRealButton(cancelButton) and cancelButton or buttons[#buttons] and buttons[#buttons][1]

	local function enterFunc()
		answer(enterButtonId, currentChoiceId())
	end

	local function escapeFunc()
		answer(escapeButtonId, 255)
	end

	choiceList.onDoubleClick = enterFunc
	modalDialog.onEnter = enterFunc
	modalDialog.onEscape = escapeFunc

	function modalDialog:onKeyPress(keyCode, keyboardModifiers)
		if keyboardModifiers ~= KeyboardNoModifier then
			return false
		end

		if g_keyboard.isEnterKey(keyCode) then
			enterFunc()

			return true
		elseif keyCode == KeyEscape then
			escapeFunc()

			return true
		elseif keyCode == KeyDown then
			choiceList:focusNextChild(KeyboardFocusReason)

			return true
		elseif keyCode == KeyUp then
			choiceList:focusPreviousChild(KeyboardFocusReason)

			return true
		end

		return false
	end

	local dlgRef = modalDialog

	scheduleEvent(function()
		if not dlgRef or dlgRef:isDestroyed() then
			return
		end

		local ml = dlgRef:recursiveGetChildById("messageLabel")

		if ml and ml.setFont then
			ml:setFont("Verdana Bold-11-px-lowspace")
		end

		dlgRef:setMinHeight(100)
	end, 1)
	modalDialog:raise()
	modalDialog:focus()
	g_client.setInputLockWidget(modalDialog)
end
