-- chunkname: @/mods/game_imbuing/t_imbui.lua

if not Imbuement then
	Imbuement = {
		bankGold = 0,
		awaitingFyiRestore = false,
		inventoryGold = 0
	}
	Imbuement.__index = Imbuement
end

Imbuement.MessageDialog = {
	PreyError = 21,
	PreyMessage = 20,
	ClearingCharmError = 11,
	ClearingCharmSuccess = 10,
	ImbuingStationNotFound = 3,
	ImbuementRollFailed = 2,
	ImbuementError = 1,
	ImbuementSuccess = 0
}

local self = Imbuement

function Imbuement.displayConfirmImbuingBox(title, message, buttons, onEnterCallback, onEscapeCallback, size)
	return displayModalHigh(title, message, buttons, onEnterCallback, onEscapeCallback, size, false)
end

function Imbuement.displayConfirmClearingBox(title, message, buttons, onEnterCallback, onEscapeCallback)
	return displayModalHigh(title, message, buttons, onEnterCallback, onEscapeCallback, nil, true)
end

function Imbuement.setLastImbuementItemPick(itemId, position, stackPos)
	if not itemId or not position then
		return
	end

	self.lastImbuementItemPick = {
		itemId = itemId,
		position = position,
		stackPos = stackPos or 0
	}
end

function Imbuement.onServerImbueAcknowledged(reselectMapItem, expectServerFyiModal)
	if expectServerFyiModal == nil then
		expectServerFyiModal = true
	end

	if expectServerFyiModal then
		self.awaitingFyiRestore = true
	end

	if reselectMapItem and self.lastImbuementItemPick and self.lastImbuementItemPick.itemId then
		local pick = self.lastImbuementItemPick

		scheduleEvent(function()
			if not g_game.isOnline() then
				return
			end

			if ImbuementItem.pendingReselectSlot ~= nil then
				ImbuementItem.restoreSlotAfterSetup = ImbuementItem.pendingReselectSlot
				ImbuementItem.pendingReselectSlot = nil
			end

			g_game.selectImbuementItem(pick.itemId, pick.position, pick.stackPos)
		end, 1)
	end
end

local IMBUEMENT_MENU_KEYS = {
	"selectItemOrScroll",
	"scrollImbue",
	"selectImbue",
	"clearImbue"
}
local IMBUEMENT_MENU_SIZES = {
	scrollImbue = "740 640",
	selectItemOrScroll = "740 388",
	clearImbue = "740 500",
	selectImbue = "740 500"
}

function Imbuement.init()
	self.window = g_ui.displayUI("t_imbui")

	self:hide()
	ImbuementSelection:startUp()

	self.selectItemOrScroll = self.window:recursiveGetChildById("selectItemOrScroll")
	self.scrollImbue = self.window:recursiveGetChildById("scrollImbue")
	self.selectImbue = self.window:recursiveGetChildById("selectImbue")
	self.clearImbue = self.window:recursiveGetChildById("clearImbue")

	connect(g_game, {
		onGameStart = self.offline,
		onGameEnd = self.offline,
		onOpenImbuementWindow = self.onOpenImbuementWindow,
		onImbuementItem = self.onImbuementItem,
		onImbuementScroll = self.onImbuementScroll,
		onResourceBalance = self.onResourceBalance,
		onCloseImbuementWindow = self.offline,
		onMessageDialog = self.onMessageDialog
	})
end

function Imbuement.terminate()
	self.awaitingFyiRestore = false

	disconnect(g_game, {
		onGameStart = self.offline,
		onGameEnd = self.offline,
		onOpenImbuementWindow = self.onOpenImbuementWindow,
		onImbuementItem = self.onImbuementItem,
		onImbuementScroll = self.onImbuementScroll,
		onResourceBalance = self.onResourceBalance,
		onCloseImbuementWindow = self.offline,
		onMessageDialog = self.onMessageDialog
	})

	if self.messageWindow then
		self.messageWindow:destroy()

		self.messageWindow = nil
	end

	self.lastImbuementItemPick = nil

	ImbuementItem:shutdown()
	ImbuementSelection:shutdown()
	ImbuementScroll:shutdown()

	if self.selectItemOrScroll then
		self.selectItemOrScroll:destroy()

		self.selectItemOrScroll = nil
	end

	if self.scrollImbue then
		self.scrollImbue:destroy()

		self.scrollImbue = nil
	end

	if self.selectImbue then
		self.selectImbue:destroy()

		self.selectImbue = nil
	end

	if self.clearImbue then
		self.clearImbue:destroy()

		self.clearImbue = nil
	end

	if self.window then
		self.window:destroy()

		self.window = nil
	end
end

function Imbuement.online()
	self:hide()

	if self.messageWindow then
		self.messageWindow:destroy()

		self.messageWindow = nil
	end

	self.lastImbuementItemPick = nil
	self.awaitingFyiRestore = false
end

function Imbuement.offline()
	self:hide()
	ImbuementItem:shutdown()
	ImbuementScroll:shutdown()

	if self.messageWindow then
		self.messageWindow:destroy()

		self.messageWindow = nil
	end

	self.lastImbuementItemPick = nil
	self.awaitingFyiRestore = false
end

function Imbuement.show()
	self.awaitingFyiRestore = false

	self.window:show(true)
	self.window:raise()
	self.window:focus()

	if self.messageWindow then
		self.messageWindow:destroy()

		self.messageWindow = nil
	end

	g_modalManager.show(self.window)
end

function Imbuement.hide()
	g_modalManager.hide(self.window)
	self.window:hide()
end

function Imbuement.tryHideForOverlay()
	if not self.window or self.window:isDestroyed() then
		return false
	end

	local needRestore = self.awaitingFyiRestore

	if self.window:isVisible() then
		self:hide()

		needRestore = true
	end

	return needRestore
end

function Imbuement.tryShowAfterOverlay()
	self.awaitingFyiRestore = false

	if ImbuementItem and ImbuementItem.reservedReturnSlot ~= nil then
		ImbuementItem.reservedReturnSlot = nil
	end

	if not g_game.isOnline() or not self.window or self.window:isDestroyed() then
		return
	end

	self:show()
end

function Imbuement.close()
	if g_game.isOnline() then
		g_game.closeImbuingWindow()
	end

	self.awaitingFyiRestore = false

	if ImbuementItem and ImbuementItem.reservedReturnSlot ~= nil then
		ImbuementItem.reservedReturnSlot = nil
	end

	g_modalManager.hide(self.window)
	self.window:hide()
end

function Imbuement:toggleMenu(menu)
	for _, key in ipairs(IMBUEMENT_MENU_KEYS) do
		local panel = self[key]

		if key == menu then
			panel:show()

			local sizeStr = IMBUEMENT_MENU_SIZES[key]

			if sizeStr then
				self.window:setSize(tosize(sizeStr))
			elseif panel.main_window_size then
				self.window:setSize(panel.main_window_size)
			end
		else
			panel:hide()
		end
	end
end

function Imbuement.onOpenImbuementWindow()
	if self.messageWindow and not self.messageWindow:isDestroyed() then
		g_game.requestResource(ResourceBank)
		g_game.requestResource(ResourceInventary)

		return
	end

	self:show()
	g_game.requestResource(ResourceBank)
	g_game.requestResource(ResourceInventary)
	self:toggleMenu("selectItemOrScroll")
end

function Imbuement.onImbuementItem(itemId, tier, slots, activeSlots, availableImbuements, needItems)
	local pending = ImbuementItem.pendingClientInfo

	if not pending and not self.awaitingFyiRestore and self.window and not self.window:isDestroyed() and not self.window:isVisible() then
		self:show()
	end

	self:toggleMenu("selectImbue")
	ImbuementItem.setup(itemId, tier, slots, activeSlots, availableImbuements, needItems)
end

function Imbuement.onImbuementScroll(availableImbuements, needItems)
	self:toggleMenu("scrollImbue")
	ImbuementScroll.setup(availableImbuements, needItems)
end

function Imbuement.onSelectItem()
	self:hide()
	ImbuementSelection:selectItem()
end

function Imbuement.onSelectScroll()
	g_game.selectImbuementScroll()
end

function Imbuement.onResourceBalance(type, balance)
	local player = g_game.getLocalPlayer()
	local bankMoney = player:getResourceBalance(ResourceBank)
	local characterMoney = player:getResourceBalance(ResourceInventary)

	self.bankGold = bankMoney or 0
	self.inventoryGold = characterMoney or 0

	if type == 0 or type == 1 then
		self.window.contentPanel.gold.text:setText(comma_value(self.bankGold + self.inventoryGold))
	end
end

function Imbuement.onMessageDialog(type, content)
	if type > Imbuement.MessageDialog.ImbuingStationNotFound or not self.window:isVisible() then
		return
	end

	self:hide()

	local message = content or ""

	if self.messageWindow then
		self.messageWindow:destroy()

		self.messageWindow = nil
	end

	local function confirm()
		g_modalManager.hide(self.messageWindow)
		self.messageWindow:destroy()

		self.messageWindow = nil

		Imbuement.show()
	end

	self.messageWindow = displayGeneralBox(tr("Message Dialog"), content, {
		{
			text = tr("Ok"),
			callback = confirm
		}
	}, confirm, confirm)

	g_modalManager.show(self.messageWindow)
end
