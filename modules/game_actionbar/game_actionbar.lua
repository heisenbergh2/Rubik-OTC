-- chunkname: @/game_actionbar/game_actionbar.lua

HOTKEY_USE = nil
HOTKEY_USEONSELF = 1
HOTKEY_USEONTARGET = 2
HOTKEY_USEWITH = 3

local maxSlots = 50
local SIDE_BAR_TOTAL_SLOTS = 36
local SIDE_BAR_VISIBLE_SLOTS = 18
local SIDE_BAR_SLOT_PITCH = 37
local SIDE_BAR_VISIBLE_HEIGHT = SIDE_BAR_VISIBLE_SLOTS * 34 + (SIDE_BAR_VISIBLE_SLOTS - 1) * 3
local SIDE_BAR_HEIGHT = 22 + SIDE_BAR_VISIBLE_HEIGHT + 22

SIDE_BAR_WIDTH = 36
SIDE_BAR_SPACING = 0
actionBarLocks = {
	right = false,
	left = false,
	bottom = false
}
isLocked = false
NUM_BARS = 9
BAR_BOTTOM_1 = 1
BAR_BOTTOM_2 = 2
BAR_BOTTOM_3 = 3
BAR_LEFT_1 = 4
BAR_LEFT_2 = 5
BAR_LEFT_3 = 6
BAR_RIGHT_1 = 7
BAR_RIGHT_2 = 8
BAR_RIGHT_3 = 9
actionBars = {}
actionBarPanels = {}
actionBar = nil
actionBarPanel = nil
actionBarPreparedPreset = nil
actionBarPreloadEvent = nil
bottomPanel = nil
bottomLockButton = nil
slotToEdit = nil
spellAssignWindow = nil
spellsPanel = nil
spellAssignPreferredSpellOverride = nil

local spellAssignFocusParameterOnOpen = false

externalAssignSlot = nil
externalAssignSlotId = nil
spellAssignListFilter = nil
onExternalSpellAssignApplied = nil
onExternalObjectAssignApplied = nil
onExternalTextAssignApplied = nil
cyclopediaSpellAssign = nil
cyclopediaSpellAssignReturnWindow = nil
textAssignWindow = nil
equipmentAssignWindow = nil
equipmentAssignIconWindow = nil

local equipmentAssignDraft, equipmentAssignPickInvSlot
local equipmentAssignHiddenForPick = false
local equipmentAssignHiddenForIconPicker = false
local equipmentAssignIconIndex = 0
local equipmentAssignDescription = ""
local equipmentAssignIconPickerRevertIndex = 0
local equipmentAssignIconPickerRevertDescription = ""
local equipmentAssignTypeIndex = 0
local equipmentAssignTypePickerRevertIndex = 0
local equipmentAssignTypeRadioGroup
local EQUIPMENT_TYPE_ICON_BASE = "/game_cyclopedia/images/bestiary/icons/monster-icon-"
local EQUIPMENT_TYPE_OPTIONS = {
	"energy-resist",
	"earth-resist",
	"fire-resist",
	"lifedrain-resist",
	"manadrain-resist",
	"ice-resist",
	"holy-resist",
	"death-resist",
	"spellcaster",
	"armor",
	"physical-resist",
	"melee",
	"ranged",
	"speed",
	"noattack"
}
local EQUIPMENT_TYPE_MAX_INDEX = #EQUIPMENT_TYPE_OPTIONS
local EQUIPMENT_SLOT_DECOR_ICON_SIZE = {
	height = 9,
	width = 9
}
local EQUIPMENT_ICONS_SHEET = "/images/game/spells/equipment-icons"
local EQUIPMENT_ICON_SIZE = 32
local EQUIPMENT_ICON_UNDETERMINED_INDEX = 0
local EQUIPMENT_ICON_PICKER_COUNT = 6
local EQUIPMENT_ICON_MAX_INDEX = EQUIPMENT_ICON_PICKER_COUNT
local normalizeEquipmentIconIndex, isEquipmentIconDeterminedOnSlot, resolvePickItemAtMouse, findGameMapWidgetAtClick, isEquippableActionBarItem, isValidActionBarObjectItem, serializeEquipmentsForJson, normalizeEquipmentsFromSetting, startEquipmentSetActionCooldownVisual, refreshAllSmartModeSlots, updateSmartModeAssignLayout, updateSmartModeAssignCheckboxState

objectAssignWindow = nil
objectAssignHiddenForPick = false
mouseGrabberWidget = nil
actionRadioGroup = nil
editHotkeyWindow = nil
editHotkeyOverlay = nil
editHotkeyPendingCombo = ""
hotkeyPauseDepth = 0
actionBarBatchDepth = 0
missedSlotToEdit = nil
itemDragRetry = nil
slotReassign = nil
multiActionEditIndex = nil
cooldown = {}
groupCooldown = {}
virtuesYellowBorderSpellIds = {}

local managedVirtueYellowBorderSpellIds = {}
local managedVirtueYellowBorderSelection = {}

VIRTUE_YELLOW_BORDER_IMAGE = "/assets/images/game/actionbar/border_activespell"

local ACTIONBAR_ITEM_MULTI_CD_KEY = "itemShared"
local slotGrayRefreshEvent

slotGrayFullRefreshPending = false
slotGrayStatsPendingSlots = {}
slotGrayInventoryRefreshPending = false

function isVirtueYellowBorderActive(spellId)
	if not spellId or spellId <= 0 then
		return false
	end

	if managedVirtueYellowBorderSpellIds[spellId] then
		return managedVirtueYellowBorderSelection[spellId] == true
	end

	return virtuesYellowBorderSpellIds[spellId] == true
end

local function resolveBorderSpellId(incomingId)
	if not incomingId or incomingId <= 0 then
		return nil
	end

	local spell = Spells.getSpellByClientId(incomingId)

	if spell then
		return spell.id
	end

	return incomingId
end

local function registerVirtueBorderSpellId(incomingId)
	local spellId = resolveBorderSpellId(incomingId)

	if spellId then
		virtuesYellowBorderSpellIds[spellId] = true
	end
end

function slotSpellMatchesVirtueBorder(spell)
	return spell and isVirtueYellowBorderActive(spell.id)
end

function refreshActionSlotVirtueBorder(slot)
	if not slot or slot:isDestroyed() then
		return
	end

	local overlay = slot:recursiveGetChildById("activeSpell")

	if not overlay then
		return
	end

	local show = false

	if slot.words and slot.words ~= "" then
		local spell = Spells.getSpellByWords(slot.words)

		if slotSpellMatchesVirtueBorder(spell) then
			show = true
		end
	end

	if show then
		overlay:setImageSource(VIRTUE_YELLOW_BORDER_IMAGE)
		overlay:show()

		if overlay.raise then
			overlay:raise()
		end
	else
		overlay:hide()
	end
end

function refreshAllVirtueYellowBorders()
	for barId = 1, NUM_BARS do
		local panel = actionBarPanels[barId]

		if panel then
			for _, slot in pairs(panel:getChildren()) do
				refreshActionSlotVirtueBorder(slot)
			end
		end
	end

	if refreshMultiActionPanelVirtueBorders then
		refreshMultiActionPanelVirtueBorders()
	end
end

function onVirtuesYellowBorder(spellIds)
	virtuesYellowBorderSpellIds = {}

	if spellIds then
		if type(spellIds) == "table" then
			for _, incomingId in ipairs(spellIds) do
				registerVirtueBorderSpellId(incomingId)
			end
		elseif type(spellIds) == "number" then
			registerVirtueBorderSpellId(spellIds)
		end
	end

	refreshAllVirtueYellowBorders()

	local spellList = modules.game_spelllist

	if spellList and spellList.refreshVirtueYellowBorders then
		spellList.refreshVirtueYellowBorders()
	end
end

function setManagedVirtueYellowBorderSpellIds(selectedSpellIds, managedSpellIds)
	managedVirtueYellowBorderSpellIds = {}
	managedVirtueYellowBorderSelection = {}

	if type(managedSpellIds) == "table" then
		for _, incomingId in ipairs(managedSpellIds) do
			local spellId = resolveBorderSpellId(incomingId)

			if spellId then
				managedVirtueYellowBorderSpellIds[spellId] = true
			end
		end
	end

	if type(selectedSpellIds) == "table" then
		for _, incomingId in ipairs(selectedSpellIds) do
			local spellId = resolveBorderSpellId(incomingId)

			if spellId and managedVirtueYellowBorderSpellIds[spellId] then
				managedVirtueYellowBorderSelection[spellId] = true
			end
		end
	end

	refreshAllVirtueYellowBorders()

	local spellList = modules.game_spelllist

	if spellList and spellList.refreshVirtueYellowBorders then
		spellList.refreshVirtueYellowBorders()
	end
end

modules.game_actionbar = modules.game_actionbar or {}
modules.game_actionbar.slotSpellMatchesVirtueBorder = slotSpellMatchesVirtueBorder
modules.game_actionbar.isVirtueYellowBorderActive = isVirtueYellowBorderActive
modules.game_actionbar.refreshAllVirtueYellowBorders = refreshAllVirtueYellowBorders
modules.game_actionbar.setManagedVirtueYellowBorderSpellIds = setManagedVirtueYellowBorderSpellIds

local syncSlotHotkeyMirror

local function actionSlotItemTier(slot)
	if g_game.getFeature(GameThingUpgradeClassification) then
		local stored = slot.getTier

		if type(stored) == "number" then
			return stored
		end
	end

	return 0
end

local function playerHasActionBarItem(slot)
	local player = g_game.getLocalPlayer()

	if not player then
		return true
	end

	if not slot.itemId or slot.itemId <= 0 then
		return true
	end

	return getActionBarInventoryDisplayCount(slot.itemId, actionSlotItemTier(slot), player) > 0
end

local EQUIPMENT_ASSIGN_BACKPACK_SLOT = InventorySlotBack

local function isEquipmentAssignVisualBackpackSlot(invSlot)
	return invSlot == EQUIPMENT_ASSIGN_BACKPACK_SLOT
end

local function isActionSlotEquip(slot)
	return slot and slot.useType == "equip"
end

function normalizeEquipmentIconIndex(index)
	if type(index) ~= "number" then
		return EQUIPMENT_ICON_UNDETERMINED_INDEX
	end

	return math.max(EQUIPMENT_ICON_UNDETERMINED_INDEX, math.min(EQUIPMENT_ICON_MAX_INDEX, math.floor(index)))
end

function isEquipmentIconDeterminedOnSlot(slot)
	return type(slot.equipmentIconIndex) == "number" and normalizeEquipmentIconIndex(slot.equipmentIconIndex) > EQUIPMENT_ICON_UNDETERMINED_INDEX
end

local function slotHasEquipmentSet(slot)
	if not isActionSlotEquip(slot) then
		return false
	end

	if slot.equipments ~= nil or isEquipmentIconDeterminedOnSlot(slot) then
		return true
	end

	return slot.itemId and slot.itemId > 0
end

local function equipmentEntryFromItem(item)
	if not item then
		return nil
	end

	local entry = {
		itemId = item:getId()
	}

	if g_game.getFeature(GameThingUpgradeClassification) then
		entry.getTier = item:getTier()
	end

	if item:isFluidContainer() then
		entry.subType = item:getSubType()
	end

	return entry
end

local function equipmentEntryToItem(entry)
	if not entry or not entry.itemId or entry.itemId <= 0 then
		return nil
	end

	local item = Item.create(entry.itemId)

	if not item then
		return nil
	end

	if entry.getTier then
		item:setTier(entry.getTier)
	end

	if entry.subType then
		item:setSubType(entry.subType)
	end

	return item
end

local function equipmentAssignDisplayEntry(equipments)
	if not equipments then
		return nil
	end

	local order = {
		InventorySlotBody,
		InventorySlotHead,
		InventorySlotLeg,
		InventorySlotFeet,
		InventorySlotNeck,
		InventorySlotLeft,
		InventorySlotRight,
		InventorySlotFinger,
		InventorySlotAmmo
	}

	for _, invSlot in ipairs(order) do
		local entry = equipments[invSlot]

		if entry and entry.itemId and entry.itemId > 0 then
			return entry
		end
	end

	for _, entry in pairs(equipments) do
		if entry and entry.itemId and entry.itemId > 0 then
			return entry
		end
	end

	return nil
end

local function copyEquipmentAssignDraft(source)
	equipmentAssignDraft = {}

	if not source then
		return
	end

	for invSlot, entry in pairs(source) do
		if not isEquipmentAssignVisualBackpackSlot(invSlot) and entry and entry.itemId and entry.itemId > 0 then
			equipmentAssignDraft[invSlot] = {
				itemId = entry.itemId,
				getTier = entry.getTier,
				subType = entry.subType
			}
		end
	end
end

local function isActionSlotEquipmentPreset(slot)
	if not isActionSlotEquip(slot) then
		return false
	end

	if slot.equipments ~= nil then
		return true
	end

	return isEquipmentIconDeterminedOnSlot(slot)
end

local function isEquipmentAssignIconDetermined()
	return normalizeEquipmentIconIndex(equipmentAssignIconIndex) > EQUIPMENT_ICON_UNDETERMINED_INDEX
end

local function normalizeEquipmentTypeIndex(index)
	if type(index) ~= "number" then
		return 0
	end

	return math.max(0, math.min(EQUIPMENT_TYPE_MAX_INDEX, math.floor(index)))
end

local function destroyEquipmentAssignTypeRadioGroup()
	if equipmentAssignTypeRadioGroup then
		equipmentAssignTypeRadioGroup:destroy()

		equipmentAssignTypeRadioGroup = nil
	end
end

local refreshAssignActionSlotPreview

local function setupEquipmentAssignTypePicker()
	if not equipmentAssignIconWindow or equipmentAssignIconWindow:isDestroyed() then
		return
	end

	local panel = equipmentAssignIconWindow:recursiveGetChildById("typeButtonsPanel")

	if not panel then
		return
	end

	destroyEquipmentAssignTypeRadioGroup()
	panel:destroyChildren()

	equipmentAssignTypeRadioGroup = UIRadioGroup.create()

	local selectedWidget

	for typeIndex = 0, EQUIPMENT_TYPE_MAX_INDEX do
		local btn = g_ui.createWidget("EquipmentTypeButton", panel)

		btn.typeIndex = typeIndex

		if typeIndex > 0 then
			local suffix = EQUIPMENT_TYPE_OPTIONS[typeIndex]

			if suffix then
				local icon = btn:getChildById("typeIcon")

				icon:setImageSource(EQUIPMENT_TYPE_ICON_BASE .. suffix)
				icon:show()
			end
		end

		equipmentAssignTypeRadioGroup:addWidget(btn)

		if typeIndex == equipmentAssignTypeIndex then
			selectedWidget = btn
		end
	end

	if selectedWidget then
		equipmentAssignTypeRadioGroup:selectWidget(selectedWidget, true)
	end

	function equipmentAssignTypeRadioGroup.onSelectionChange(_, selected)
		if selected and selected.typeIndex ~= nil then
			equipmentAssignTypeIndex = selected.typeIndex
		else
			equipmentAssignTypeIndex = 0
		end

		refreshAssignActionSlotPreview()
	end
end

local function equipmentIconClip(index)
	local i = normalizeEquipmentIconIndex(index)

	return string.format("%d 0 %d %d", i * EQUIPMENT_ICON_SIZE, EQUIPMENT_ICON_SIZE, EQUIPMENT_ICON_SIZE)
end

local function applyEquipmentIconToWidget(widget, index)
	if not widget or widget:isDestroyed() then
		return
	end

	widget:setImageSource(EQUIPMENT_ICONS_SHEET)
	widget:setImageSize(tosize("32 32"))
	widget:setImageClip(equipmentIconClip(index))
	widget:show()
end

local function equipmentTypeIconSource(typeIndex)
	typeIndex = normalizeEquipmentTypeIndex(typeIndex)

	if typeIndex <= 0 then
		return nil
	end

	local suffix = EQUIPMENT_TYPE_OPTIONS[typeIndex]

	if not suffix then
		return nil
	end

	return EQUIPMENT_TYPE_ICON_BASE .. suffix
end

local function ensureEquipmentTypeIconWidget(slot)
	if not slot or slot:isDestroyed() then
		return nil
	end

	local icon = slot:getChildById("equipmentTypeIcon")

	if icon and not icon:isDestroyed() then
		return icon
	end

	icon = g_ui.createWidget("UIWidget", slot)

	icon:setId("equipmentTypeIcon")
	icon:setSize(EQUIPMENT_SLOT_DECOR_ICON_SIZE)
	icon:addAnchor(AnchorBottom, "parent", AnchorBottom)
	icon:addAnchor(AnchorLeft, "parent", AnchorLeft)
	icon:setMarginLeft(1)
	icon:setMarginBottom(1)
	icon:setPhantom(true)
	icon:setFocusable(false)
	icon:setVisible(false)

	return icon
end

function refreshActionSlotEquipmentTypeIcon(slot)
	if not slot or slot:isDestroyed() then
		return
	end

	local icon = ensureEquipmentTypeIconWidget(slot)

	if not icon then
		return
	end

	if not isActionSlotEquipmentPreset(slot) then
		icon:setVisible(false)

		return
	end

	local src = equipmentTypeIconSource(slot.equipmentTypeIndex)

	if not src then
		icon:setVisible(false)

		return
	end

	icon:setImageSource(src)
	icon:setImageSize(EQUIPMENT_SLOT_DECOR_ICON_SIZE)

	local multi = slot:getChildById("multiIcon")

	if multi and not multi:isDestroyed() and multi:isVisible() then
		icon:setMarginLeft(12)
	else
		icon:setMarginLeft(1)
	end

	icon:show()

	if icon.raise then
		icon:raise()
	end
end

local function refreshActionSlotEquipmentDecorations(slot)
	refreshActionSlotEquipmentTypeIcon(slot)
end

function loadEquipmentSetDisplay(slot)
	if not slot or slot:isDestroyed() then
		return
	end

	local spellIcon = slot:getChildById("spellIcon")

	if spellIcon then
		if isEquipmentIconDeterminedOnSlot(slot) then
			applyEquipmentIconToWidget(spellIcon, slot.equipmentIconIndex)
		else
			spellIcon:hide()
			spellIcon:setImageSource("")
		end
	end

	slot:setItemId(0)

	local textWidget = slot:getChildById("text")

	if textWidget then
		textWidget:setText("")
	end

	slot:setBorderWidth(0)
	refreshActionSlotEquipmentDecorations(slot)
	refreshActionSlotTooltip(slot)
	updateSlotGray(slot)
	refreshActionSlotInventoryQuantity(slot)
	applyActionSlotFrame(slot)
	maybeSetupHotkeysAfterSlotLoad()
end

function clearSlotActionContent(slot)
	if not slot or slot:isDestroyed() then
		return
	end

	if clearSlotMultiActions then
		clearSlotMultiActions(slot)
	end

	local spellIcon = slot:getChildById("spellIcon")

	if spellIcon then
		spellIcon:hide()
		spellIcon:setImageSource("")
	end

	if slot.clearItem then
		slot:clearItem()
	end

	slot:setText("")

	slot.itemId = nil
	slot.subType = nil
	slot.words = nil
	slot.text = nil
	slot.useType = nil
	slot.getTier = nil
	slot.passiveId = nil
	slot.equipments = nil
	slot.equipmentIconIndex = nil
	slot.equipmentDescription = nil
	slot.equipmentTypeIndex = nil
	slot.parameter = nil
	slot.crossHairMode = nil
	slot.autoSend = nil
	slot.smartMode = nil
	slot.smartBaseItemId = nil
	slot._smartEquipPending = nil

	local tier = slot:getChildById("tier")

	if tier then
		tier:setVisible(false)
	end

	local txt = slot:getChildById("text")

	if txt then
		txt:setText("")
	end

	local gray = slot:getChildById("gray")

	if gray then
		gray:setVisible(false)
	end

	refreshActionSlotVirtueBorder(slot)
	refreshActionSlotEquipmentDecorations(slot)
	refreshActionSlotTooltip(slot)
	refreshActionSlotInventoryQuantity(slot)
	applyActionSlotFrame(slot)
end

local function copyEquipmentAssignMetaFromSlot(actionSlot)
	if actionSlot then
		equipmentAssignIconIndex = normalizeEquipmentIconIndex(actionSlot.equipmentIconIndex)
		equipmentAssignDescription = actionSlot.equipmentDescription or ""
		equipmentAssignTypeIndex = normalizeEquipmentTypeIndex(actionSlot.equipmentTypeIndex)
	else
		equipmentAssignIconIndex = EQUIPMENT_ICON_UNDETERMINED_INDEX
		equipmentAssignDescription = ""
		equipmentAssignTypeIndex = 0
	end
end

function refreshAssignActionSlotPreview()
	if not equipmentAssignWindow or equipmentAssignWindow:isDestroyed() then
		return
	end

	local slotWidget = equipmentAssignWindow:recursiveGetChildById("assignActionSlot")

	if not slotWidget then
		return
	end

	local icon = slotWidget:recursiveGetChildById("equipmentSlotIcon")

	applyEquipmentIconToWidget(icon, equipmentAssignIconIndex)

	local typeIcon = slotWidget:recursiveGetChildById("equipmentTypeIcon")

	if typeIcon then
		local src = equipmentTypeIconSource(equipmentAssignTypeIndex)

		if src then
			typeIcon:setImageSource(src)
			typeIcon:setImageSize(EQUIPMENT_SLOT_DECOR_ICON_SIZE)
			typeIcon:show()
		else
			typeIcon:setVisible(false)
		end
	end
end

local function refreshEquipmentAssignIconPickerSelection()
	if not equipmentAssignIconWindow or equipmentAssignIconWindow:isDestroyed() then
		return
	end

	local panel = equipmentAssignIconWindow:recursiveGetChildById("iconScrollPanel")

	if not panel then
		return
	end

	for _, child in pairs(panel:getChildren()) do
		if child.iconIndex ~= nil then
			child:setImageSource("/images/game/actionbar/slot-actionbar-filled")
			child:setImageSize(tosize("34 34"))

			if child.iconIndex == equipmentAssignIconIndex then
				child:setImageClip("0 34 34 34")
			else
				child:setImageClip("0 0 34 34")
			end
		end
	end
end

local function setupEquipmentAssignIconPicker()
	if not equipmentAssignIconWindow or equipmentAssignIconWindow:isDestroyed() then
		return
	end

	local panel = equipmentAssignIconWindow:recursiveGetChildById("iconScrollPanel")

	if not panel then
		return
	end

	panel:destroyChildren()

	for i = 1, EQUIPMENT_ICON_PICKER_COUNT do
		local btn = g_ui.createWidget("EquipmentIconPickerOption", panel)

		btn.iconIndex = i

		local iconWidget = btn:getChildById("icon")

		applyEquipmentIconToWidget(iconWidget, i)

		function btn.onClick()
			equipmentAssignIconIndex = i

			refreshEquipmentAssignIconPickerSelection()
			refreshAssignActionSlotPreview()
			equipmentAssignUpdateButtons()
		end
	end

	refreshEquipmentAssignIconPickerSelection()
end

local function commitEquipmentAssignIconPicker()
	local edit = equipmentAssignIconWindow and equipmentAssignIconWindow:recursiveGetChildById("descriptionTextEdit")

	if edit then
		equipmentAssignDescription = edit:getText() or ""
	end

	if equipmentAssignTypeRadioGroup then
		local selected = equipmentAssignTypeRadioGroup:getSelectedWidget()

		if selected and selected.typeIndex ~= nil then
			equipmentAssignTypeIndex = selected.typeIndex
		end
	end

	refreshAssignActionSlotPreview()
	equipmentAssignUpdateButtons()
end

local function forEachEquipmentAssignSlot(callback)
	if not equipmentAssignWindow or equipmentAssignWindow:isDestroyed() then
		return
	end

	local panel = equipmentAssignWindow:recursiveGetChildById("equipmentPanel")

	if not panel then
		return
	end

	for _, child in ipairs(panel:getChildren()) do
		local invSlot = child.inventorySlot

		if invSlot then
			callback(child, invSlot)
		end
	end
end

local function equipmentAssignItemHasRarityFrame(item)
	if not item or not g_game.getFeature(GameColorizedLootValue) then
		return false
	end

	if modules.client_options.getOption("framesRarity") == "none" then
		return false
	end

	return (item:getMeanPrice() or 0) >= 50
end

local function clearEquipmentAssignItemFrame(itemWidget)
	itemWidget:setImageSource("")
	itemWidget:setImageClip("0 0 0 0")
end

local function applyEquipmentAssignItemRarity(itemWidget, item)
	if equipmentAssignItemHasRarityFrame(item) then
		ItemsDatabase.setRarityItem(itemWidget, item)

		return
	end

	ItemsDatabase.setRarityItem(itemWidget, nil)
	clearEquipmentAssignItemFrame(itemWidget)
end

local function clearEquipmentAssignSlotItemWidget(itemWidget)
	itemWidget:setItem(nil)
	ItemsDatabase.setTier(itemWidget, 0)
	ItemsDatabase.setBigTier(itemWidget, 0)
	applyEquipmentAssignItemRarity(itemWidget, nil)
end

EAssign = {}

function EAssign.getMarketCategory(item)
	local md = item.getMarketData and item:getMarketData()

	return md and md.category
end

function EAssign.isDualWielding(item)
	if not item then
		return false
	end

	local thingType = g_things.getThingType(item:getId(), ThingCategoryItem)

	return thingType and thingType:isDualWielding()
end

function EAssign.isQuiver(item)
	if not item then
		return false
	end

	local cat = EAssign.getMarketCategory(item)

	return MarketCategory and cat == MarketCategory.Quivers
end

function EAssign.isBowOrCrossbow(item)
	if not item then
		return false
	end

	local cat = EAssign.getMarketCategory(item)

	if not MarketCategory or cat ~= MarketCategory.DistanceWeapons then
		return false
	end

	return item:getClothSlot() == InventorySlotOther
end

function EAssign.isShield(item)
	if not item or EAssign.isQuiver(item) then
		return false
	end

	if item:getClothSlot() == InventorySlotRight then
		return true
	end

	local cat = EAssign.getMarketCategory(item)

	return MarketCategory and cat == MarketCategory.Shields
end

function EAssign.getWeaponMarketSlots(item)
	local cat = EAssign.getMarketCategory(item)

	if cat and MarketCategoryWeapons and MarketCategoryWeapons[cat] then
		return MarketCategoryWeapons[cat].slots
	end

	return nil
end

function EAssign.weaponHandFlags(item)
	local slots = EAssign.getWeaponMarketSlots(item)

	if not slots then
		return false, false
	end

	local canOneHand, canTwoHand = false, false

	for _, allowed in ipairs(slots) do
		if allowed == InventorySlotLeft then
			canOneHand = true
		elseif allowed == 255 or allowed == InventorySlotOther then
			canTwoHand = true
		end
	end

	return canOneHand, canTwoHand
end

function EAssign.blocksShieldSlot(item)
	if not item or EAssign.isShield(item) then
		return false
	end

	if EAssign.isBowOrCrossbow(item) then
		return false
	end

	if EAssign.isDualWielding(item) then
		return true
	end

	local canOneHand, canTwoHand = EAssign.weaponHandFlags(item)

	if canTwoHand and not canOneHand then
		return true
	end

	if item:getClothSlot() == InventorySlotOther then
		return true
	end

	return false
end

function EAssign.draftLeftHandItem()
	local entry = equipmentAssignDraft and equipmentAssignDraft[InventorySlotLeft]

	return entry and equipmentEntryToItem(entry) or nil
end

function EAssign.resolveRightSlotEntry(rightEntry)
	if rightEntry and rightEntry.itemId and rightEntry.itemId > 0 then
		return rightEntry, false
	end

	local leftItem = EAssign.draftLeftHandItem()

	if leftItem and EAssign.isDualWielding(leftItem) then
		return equipmentAssignDraft[InventorySlotLeft], true
	end

	return nil, false
end

function EAssign.reconcileHandSlots()
	if not equipmentAssignDraft then
		return
	end

	local leftItem = EAssign.draftLeftHandItem()
	local rightEntry = equipmentAssignDraft[InventorySlotRight]

	if not rightEntry then
		return
	end

	local rightItem = equipmentEntryToItem(rightEntry)

	if leftItem and EAssign.isDualWielding(leftItem) then
		equipmentAssignDraft[InventorySlotRight] = nil

		return
	end

	if leftItem and EAssign.blocksShieldSlot(leftItem) then
		equipmentAssignDraft[InventorySlotRight] = nil

		return
	end

	if rightItem and leftItem and EAssign.isBowOrCrossbow(leftItem) and EAssign.isShield(rightItem) then
		equipmentAssignDraft[InventorySlotRight] = nil
	end
end

local function refreshEquipmentAssignSlotWidget(slotWidget, entry)
	local itemWidget = slotWidget:getChildById("equippedItem")
	local slotIcon = slotWidget:getChildById("slotIcon")

	if not itemWidget then
		return
	end

	local invSlot = slotWidget.inventorySlot
	local mirrorShieldSlot = false

	if invSlot == InventorySlotRight then
		entry, mirrorShieldSlot = EAssign.resolveRightSlotEntry(entry)
	end

	local item = equipmentEntryToItem(entry)

	if item then
		if mirrorShieldSlot then
			local mirrored = item:clone()

			itemWidget:setItem(mirrored)

			item = mirrored
		else
			itemWidget:setItem(item)
		end

		itemWidget:setMirrorHorizontal(mirrorShieldSlot)

		if invSlot == InventorySlotRight then
			if mirrorShieldSlot then
				slotWidget:setOpacity(0.6)
				itemWidget:setOpacity(0.6)
			else
				slotWidget:setOpacity(1)
				itemWidget:setOpacity(1)
			end
		end

		applyEquipmentAssignItemRarity(itemWidget, item)
		ItemsDatabase.setTier(itemWidget, 0)
		ItemsDatabase.setBigTier(itemWidget, item)

		if not equipmentAssignItemHasRarityFrame(item) then
			clearEquipmentAssignItemFrame(itemWidget)
		end

		local quicklootIcon = itemWidget:recursiveGetChildById("quickloot")

		if quicklootIcon then
			quicklootIcon:setVisible(false)
		end

		if slotIcon then
			slotIcon:setVisible(false)
		end
	else
		itemWidget:setMirrorHorizontal(false)

		if invSlot == InventorySlotRight then
			slotWidget:setOpacity(1)
			itemWidget:setOpacity(1)
		end

		clearEquipmentAssignSlotItemWidget(itemWidget)

		if slotIcon then
			slotIcon:setVisible(true)
			slotIcon:raise()
		end
	end
end

function EAssign.refreshHandSlotWidgets()
	forEachEquipmentAssignSlot(function(widget, slotId)
		if slotId == InventorySlotLeft or slotId == InventorySlotRight then
			local entry = equipmentAssignDraft and equipmentAssignDraft[slotId]

			refreshEquipmentAssignSlotWidget(widget, entry)
		end
	end)
end

local function refreshEquipmentAssignBackpackSlot()
	if not equipmentAssignWindow or equipmentAssignWindow:isDestroyed() then
		return
	end

	local backSlot = equipmentAssignWindow:recursiveGetChildById("backSlot")

	if not backSlot then
		return
	end

	local player = g_game.getLocalPlayer()
	local entry = player and equipmentEntryFromItem(player:getInventoryItem(EQUIPMENT_ASSIGN_BACKPACK_SLOT))

	refreshEquipmentAssignSlotWidget(backSlot, entry)
end

local function refreshAllEquipmentAssignSlots()
	EAssign.reconcileHandSlots()
	forEachEquipmentAssignSlot(function(widget, invSlot)
		if isEquipmentAssignVisualBackpackSlot(invSlot) then
			return
		end

		local entry = equipmentAssignDraft and equipmentAssignDraft[invSlot] or nil

		refreshEquipmentAssignSlotWidget(widget, entry)
	end)
	refreshEquipmentAssignBackpackSlot()
end

function equipmentAssignUpdateButtons()
	if not equipmentAssignWindow or equipmentAssignWindow:isDestroyed() then
		return
	end

	local okBtn = equipmentAssignWindow:getChildById("okButton")
	local applyBtn = equipmentAssignWindow:getChildById("applyButton")
	local canSave = isEquipmentAssignIconDetermined()

	if okBtn then
		okBtn:setEnabled(canSave)
	end

	if applyBtn then
		applyBtn:setEnabled(canSave)
	end
end

function equipmentAssignCopyCurrentSet()
	local player = g_game.getLocalPlayer()

	if not player then
		return
	end

	equipmentAssignDraft = {}

	forEachEquipmentAssignSlot(function(widget, invSlot)
		if isEquipmentAssignVisualBackpackSlot(invSlot) then
			return
		end

		local entry = equipmentEntryFromItem(player:getInventoryItem(invSlot))

		if entry then
			equipmentAssignDraft[invSlot] = entry
		end
	end)
	refreshAllEquipmentAssignSlots()
	equipmentAssignUpdateButtons()
end

local function itemFitsEquipmentAssignSlot(item, invSlot)
	if not item or isEquipmentAssignVisualBackpackSlot(invSlot) then
		return false
	end

	if not isEquippableActionBarItem(item) then
		return false
	end

	local clothSlot = item:getClothSlot()

	if clothSlot == InventorySlotBack then
		return false
	end

	if invSlot == InventorySlotRight then
		local leftItem = EAssign.draftLeftHandItem()

		if leftItem and EAssign.isBowOrCrossbow(leftItem) then
			return EAssign.isQuiver(item)
		end

		if EAssign.isQuiver(item) then
			return not leftItem or not EAssign.blocksShieldSlot(leftItem)
		end

		if not EAssign.isShield(item) then
			return false
		end

		return not leftItem or not EAssign.blocksShieldSlot(leftItem)
	end

	if invSlot == InventorySlotLeft then
		if EAssign.isShield(item) then
			return false
		end

		if EAssign.isDualWielding(item) then
			return true
		end

		if clothSlot > 0 then
			return clothSlot == invSlot
		end

		local weaponSlots = EAssign.getWeaponMarketSlots(item)

		if weaponSlots then
			if #weaponSlots == 1 and weaponSlots[1] == 255 then
				return false
			end

			local canOneHand, canTwoHand = EAssign.weaponHandFlags(item)

			return canOneHand or canTwoHand
		end

		local cat = EAssign.getMarketCategory(item)

		if MarketCategory and (cat == MarketCategory.FistWeapons or cat == MarketCategory.Quivers) then
			return true
		end

		local thingType = g_things.getThingType(item:getId(), ThingCategoryItem)

		if thingType and thingType.isCloth and thingType:isCloth() then
			return true
		end

		return false
	end

	if clothSlot > 0 then
		return clothSlot == invSlot
	end

	return false
end

local function equipmentAssignDraggedItem(draggingWidget)
	if not draggingWidget or draggingWidget:getClassName() ~= "UIItem" or draggingWidget:isVirtual() then
		return nil
	end

	local item = draggingWidget.currentDragThing

	if item and item.isItem and item:isItem() then
		return item
	end

	return nil
end

local function equipmentAssignSetSlotItem(invSlot, item, slotWidget)
	if isEquipmentAssignVisualBackpackSlot(invSlot) or not item then
		return false
	end

	if not itemFitsEquipmentAssignSlot(item, invSlot) then
		if invSlot == InventorySlotRight and EAssign.isQuiver(item) and EAssign.draftLeftHandItem() and EAssign.blocksShieldSlot(EAssign.draftLeftHandItem()) then
			modules.game_textmessage.displayFailureMessage(tr("You cannot use a quiver while wielding a two-handed weapon."))
		elseif invSlot == InventorySlotRight and EAssign.isShield(item) and EAssign.draftLeftHandItem() and EAssign.isBowOrCrossbow(EAssign.draftLeftHandItem()) then
			modules.game_textmessage.displayFailureMessage(tr("You cannot use a shield while wielding a bow or crossbow."))
		elseif invSlot == InventorySlotRight and EAssign.isShield(item) and EAssign.draftLeftHandItem() and EAssign.blocksShieldSlot(EAssign.draftLeftHandItem()) then
			modules.game_textmessage.displayFailureMessage(tr("You cannot use a shield while wielding a two-handed weapon."))
		else
			modules.game_textmessage.displayFailureMessage(tr("This item is not suitable for this equipment slot."))
		end

		return false
	end

	equipmentAssignDraft = equipmentAssignDraft or {}
	equipmentAssignDraft[invSlot] = equipmentEntryFromItem(item)

	EAssign.reconcileHandSlots()

	if invSlot == InventorySlotLeft or invSlot == InventorySlotRight then
		EAssign.refreshHandSlotWidgets()
	elseif slotWidget then
		refreshEquipmentAssignSlotWidget(slotWidget, equipmentAssignDraft[invSlot])
	else
		forEachEquipmentAssignSlot(function(widget, slotId)
			if slotId == invSlot then
				refreshEquipmentAssignSlotWidget(widget, equipmentAssignDraft[invSlot])
			end
		end)
	end

	equipmentAssignUpdateButtons()

	return true
end

local function onEquipmentAssignSlotDrop(slotWidget, draggedWidget, mousePos, invSlot)
	if isEquipmentAssignVisualBackpackSlot(invSlot) then
		return false
	end

	local item = equipmentAssignDraggedItem(draggedWidget)

	if not item then
		return false
	end

	if equipmentAssignSetSlotItem(invSlot, item, slotWidget) then
		slotWidget:setBorderWidth(0)

		if draggedWidget then
			draggedWidget:setBorderWidth(0)
		end

		return true
	end

	return false
end

local function onEquipmentAssignSlotHoverChange(slotWidget, hovered, invSlot)
	if UIWidget.onHoverChange then
		UIWidget.onHoverChange(slotWidget, hovered)
	end

	if isEquipmentAssignVisualBackpackSlot(invSlot) then
		return
	end

	local draggingWidget = g_ui.getDraggingWidget()
	local item = equipmentAssignDraggedItem(draggingWidget)

	if hovered and item and itemFitsEquipmentAssignSlot(item, invSlot) then
		slotWidget:setBorderWidth(1)
		slotWidget:setBorderColor("#ffffff")
	else
		slotWidget:setBorderWidth(0)
	end
end

local function restoreEquipmentAssignWindowAfterPick()
	if not equipmentAssignHiddenForPick then
		return
	end

	equipmentAssignHiddenForPick = false

	if equipmentAssignWindow and not equipmentAssignWindow:isDestroyed() then
		equipmentAssignWindow:show()
		equipmentAssignWindow:raise()
		equipmentAssignWindow:focus()
	end
end

local function startEquipmentAssignChooseItem(invSlot)
	if not equipmentAssignWindow or equipmentAssignWindow:isDestroyed() or isEquipmentAssignVisualBackpackSlot(invSlot) or g_ui.isMouseGrabbed() then
		return
	end

	equipmentAssignPickInvSlot = invSlot

	equipmentAssignWindow:hide()

	equipmentAssignHiddenForPick = true

	mouseGrabberWidget:grabMouse()
	g_mouse.pushCursor("target")
end

local function onEquipmentAssignChooseItemMouseRelease(self, mousePosition, mouseButton)
	local invSlot = equipmentAssignPickInvSlot

	equipmentAssignPickInvSlot = nil

	local item

	if mouseButton == MouseLeftButton then
		item = resolvePickItemAtMouse(mousePosition)

		if item and not itemFitsEquipmentAssignSlot(item, invSlot) then
			modules.game_textmessage.displayFailureMessage(tr("This item is not suitable for this equipment slot."))

			item = nil
		end
	end

	if item then
		equipmentAssignSetSlotItem(invSlot, item, nil)
	end

	restoreEquipmentAssignWindowAfterPick()
	g_mouse.popCursor("target")
	self:ungrabMouse()

	return true
end

local function equipmentAssignRemoveSlot(invSlot)
	if isEquipmentAssignVisualBackpackSlot(invSlot) then
		return
	end

	if not equipmentAssignDraft then
		equipmentAssignDraft = {}
	end

	equipmentAssignDraft[invSlot] = nil

	if invSlot == InventorySlotLeft or invSlot == InventorySlotRight then
		EAssign.refreshHandSlotWidgets()
	else
		forEachEquipmentAssignSlot(function(widget, slotId)
			if slotId == invSlot then
				refreshEquipmentAssignSlotWidget(widget, nil)
			end
		end)
	end

	equipmentAssignUpdateButtons()
end

local function onEquipmentAssignSlotMouseRelease(widget, mousePos, mouseButton, invSlot)
	if mouseButton ~= MouseRightButton or isEquipmentAssignVisualBackpackSlot(invSlot) then
		return false
	end

	local menu = g_ui.createWidget("GamePopupMenu")

	menu:addOption(tr("Select Equipment"), function()
		startEquipmentAssignChooseItem(invSlot)
	end)

	local entry = equipmentAssignDraft and equipmentAssignDraft[invSlot]

	if entry and entry.itemId and entry.itemId > 0 then
		menu:addOption(tr("Remove Equipment"), function()
			equipmentAssignRemoveSlot(invSlot)
		end)
	end

	menu:display(mousePos)

	return true
end

local function setupEquipmentAssignSlotHandlers()
	forEachEquipmentAssignSlot(function(widget, invSlot)
		if isEquipmentAssignVisualBackpackSlot(invSlot) then
			widget.onMouseRelease = nil
			widget.onDrop = nil
			widget.onHoverChange = nil

			return
		end

		function widget.onMouseRelease(w, mousePos, button)
			return onEquipmentAssignSlotMouseRelease(w, mousePos, button, invSlot)
		end

		function widget:onDrop(draggedWidget, mousePos)
			return onEquipmentAssignSlotDrop(widget, draggedWidget, mousePos, invSlot)
		end

		function widget:onHoverChange(hovered)
			onEquipmentAssignSlotHoverChange(widget, hovered, invSlot)
		end

		local equippedItem = widget:recursiveGetChildById("equippedItem")

		if equippedItem then
			function equippedItem:onDrop(draggedWidget, mousePos)
				return onEquipmentAssignSlotDrop(widget, draggedWidget, mousePos, invSlot)
			end

			function equippedItem:onHoverChange(hovered)
				onEquipmentAssignSlotHoverChange(widget, hovered, invSlot)
			end
		end
	end)
end

local function actionSlotEquippedItemMatches(item, itemId, tier)
	if not item or item:getId() ~= itemId then
		return false
	end

	if g_game.getFeature(GameThingUpgradeClassification) then
		local itemTier = item.getTier and item:getTier() or 0

		return itemTier == (tier or 0)
	end

	return true
end

local function actionSlotHasEquipmentSetEntries(slot)
	if not slot or not slot.equipments then
		return false
	end

	for invSlot, entry in pairs(slot.equipments) do
		if not isEquipmentAssignVisualBackpackSlot(invSlot) and entry and entry.itemId and entry.itemId > 0 then
			return true
		end
	end

	return false
end

local EQUIPMENT_SET_EQUIP_ORDER = {
	InventorySlotHead,
	InventorySlotNeck,
	InventorySlotBody,
	InventorySlotRight,
	InventorySlotLeft,
	InventorySlotLeg,
	InventorySlotFeet,
	InventorySlotFinger,
	InventorySlotAmmo
}
local EQUIPMENT_SET_COOLDOWN_MS = 1000
local EQUIPMENT_SET_CD_PROGRESS_ID = "progressEquipmentSet"
local EQUIPMENT_SET_SHARED_CD_KEY = "equipmentSetShared"
local equipmentSetSharedCooldownUntil

local function equipmentSetCooldownGroupId()
	return EQUIPMENT_SET_SHARED_CD_KEY
end

local function forEachEquipmentSetActionSlot(callback)
	if not callback then
		return
	end

	for barId = 1, NUM_BARS do
		local panel = actionBarPanels[barId]

		if panel then
			for _, slot in pairs(panel:getChildren()) do
				if isActionSlotEquipmentPreset(slot) then
					callback(slot)
				end
			end
		end
	end
end

local function isEquipmentSetActionOnCooldown(slot)
	if not isActionSlotEquipmentPreset(slot) then
		return false
	end

	return equipmentSetSharedCooldownUntil and g_clock.millis() < equipmentSetSharedCooldownUntil
end

local function startEquipmentSetActionCooldown()
	equipmentSetSharedCooldownUntil = g_clock.millis() + EQUIPMENT_SET_COOLDOWN_MS

	forEachEquipmentSetActionSlot(function(slot)
		slot._equipmentSetCooldownUntil = equipmentSetSharedCooldownUntil

		if startEquipmentSetActionCooldownVisual then
			startEquipmentSetActionCooldownVisual(slot)
		end
	end)
end

local function actionSlotPresetEntryMatchesEquipped(player, invSlot, entry)
	if not player or not entry or not entry.itemId or entry.itemId <= 0 then
		return true
	end

	return actionSlotEquippedItemMatches(player:getInventoryItem(invSlot), entry.itemId, entry.getTier or 0)
end

local function actionSlotPresetEntryForSlot(slot, invSlot)
	if not slot or not slot.equipments then
		return nil
	end

	local entry = slot.equipments[invSlot]

	if entry and entry.itemId and entry.itemId > 0 then
		return entry
	end

	return nil
end

local function actionSlotEquipmentSetNeedsEquip(slot)
	if not isActionSlotEquipmentPreset(slot) then
		return false
	end

	local player = g_game.getLocalPlayer()

	if not player or not player.getInventoryItem then
		return false
	end

	for _, invSlot in ipairs(EQUIPMENT_SET_EQUIP_ORDER) do
		local entry = actionSlotPresetEntryForSlot(slot, invSlot)

		if entry and not actionSlotPresetEntryMatchesEquipped(player, invSlot, entry) then
			return true
		end

		if not entry then
			local equipped = player:getInventoryItem(invSlot)

			if equipped then
				return true
			end
		end
	end

	return false
end

local function isActionSlotEquipSetActive(slot)
	if not isActionSlotEquipmentPreset(slot) then
		return false
	end

	local player = g_game.getLocalPlayer()

	if not player or not player.getInventoryItem then
		return false
	end

	for _, invSlot in ipairs(EQUIPMENT_SET_EQUIP_ORDER) do
		local entry = actionSlotPresetEntryForSlot(slot, invSlot)

		if entry then
			if not actionSlotPresetEntryMatchesEquipped(player, invSlot, entry) then
				return false
			end
		elseif player:getInventoryItem(invSlot) then
			return false
		end
	end

	return true
end

local function isActionSlotEquipEquipped(slot)
	if not isActionSlotEquip(slot) then
		return false
	end

	if isActionSlotEquipmentPreset(slot) then
		return isActionSlotEquipSetActive(slot)
	end

	if not slot.itemId or slot.itemId <= 0 then
		return false
	end

	local player = g_game.getLocalPlayer()

	if not player or not player.getInventoryItem then
		return false
	end

	local itemId = slot.itemId
	local tier = actionSlotItemTier(slot)
	local first = InventorySlotFirst or 1
	local last = InventorySlotLast or 10

	for i = first, last do
		if actionSlotEquippedItemMatches(player:getInventoryItem(i), itemId, tier) then
			return true
		end
	end

	return false
end

local function refreshSpellAssignPreviewIfOpen()
	if not spellAssignWindow or not spellsPanel then
		return
	end

	local fc = spellsPanel:getFocusedChild()

	if fc then
		updatePreviewSpell(fc)
	end
end

local function scheduleSlotGrayRefresh(fullRefresh)
	slotGrayFullRefreshPending = slotGrayFullRefreshPending or fullRefresh == true

	if slotGrayRefreshEvent then
		return
	end

	slotGrayRefreshEvent = scheduleEvent(function()
		slotGrayRefreshEvent = nil

		local runFullRefresh = slotGrayFullRefreshPending
		local runInventoryRefresh = slotGrayInventoryRefreshPending
		local runStatsRefresh = next(slotGrayStatsPendingSlots) ~= nil

		slotGrayFullRefreshPending = false
		slotGrayInventoryRefreshPending = false

		if runFullRefresh then
			slotGrayStatsPendingSlots = {}

			updateSlotsVocation()

			if refreshAllSmartModeSlots then
				refreshAllSmartModeSlots()
			end

			refreshSpellAssignPreviewIfOpen()
			refreshAllEquipmentAssignSlots()
		else
			if runInventoryRefresh and updateInventoryDependentActionSlots then
				updateInventoryDependentActionSlots()
			end

			if runStatsRefresh and updateStatsDependentSlotGray then
				updateStatsDependentSlotGray()
			end
		end

		if runFullRefresh or runStatsRefresh and spellAssignWindow then
			refreshAssignSpellListGrayOverlays()
		end
	end, 50)
end

function scheduleFullSlotGrayRefresh()
	scheduleSlotGrayRefresh(true)
end

function scheduleInventorySlotGrayRefresh()
	slotGrayInventoryRefreshPending = true

	scheduleSlotGrayRefresh(false)
end

local function onLocalPlayerManaChange(player, mana, maxMana, oldMana, oldMaxMana)
	local currentMana = tonumber(mana)
	local previousMana = tonumber(oldMana)

	if not currentMana or not previousMana or currentMana == previousMana then
		return
	end

	local crossedThreshold = false

	for i = 1, NUM_BARS do
		local panel = actionBarPanels[i]

		if panel then
			for _, slot in pairs(panel:getChildren()) do
				local manaCost = slot.grayManaCost

				if manaCost and manaCost > 0 and (previousMana < manaCost and manaCost <= currentMana or manaCost <= previousMana and currentMana < manaCost) then
					slotGrayStatsPendingSlots[slot] = true
					crossedThreshold = true
				end
			end
		end
	end

	if crossedThreshold then
		scheduleSlotGrayRefresh(false)
	end
end

local function playerMeetsSpellLevelForAssign(spell)
	if not spell then
		return false
	end

	local player = g_game.getLocalPlayer()

	if not player then
		return true
	end

	if spell.level and player:getLevel() < spell.level then
		return false
	end

	return true
end

local function spellPassesAssignLearntFilter(spell)
	if not spell then
		return false
	end

	return canUseSpell(spell) and playerMeetsSpellLevelForAssign(spell)
end

local SPELL_PARAM_MAX_WIDTH_PX = 34

local function ellipsizeSpellParameterLabelText(lbl, text)
	if not lbl or not text or text == "" then
		return ""
	end

	lbl:setText(text)

	local sz = lbl:getTextSize()

	if not sz or sz.width <= SPELL_PARAM_MAX_WIDTH_PX then
		return text
	end

	local dots = "..."

	lbl:setText(dots)

	local dotSz = lbl:getTextSize()
	local dotsW = dotSz and dotSz.width or SPELL_PARAM_MAX_WIDTH_PX
	local budget = SPELL_PARAM_MAX_WIDTH_PX - dotsW

	if budget <= 0 then
		return dots
	end

	local lo, hi = 1, #text
	local best = ""

	while lo <= hi do
		local mid = math.floor((lo + hi) / 2)
		local sub = string.sub(text, 1, mid)

		lbl:setText(sub)

		local w = lbl:getTextSize().width

		if w <= budget then
			best = sub
			lo = mid + 1
		else
			hi = mid - 1
		end
	end

	if best == "" then
		return dots
	end

	local out = best .. dots

	lbl:setText(out)

	local guard = 0

	while best ~= "" and lbl:getTextSize().width > SPELL_PARAM_MAX_WIDTH_PX and guard < 64 do
		best = string.sub(best, 1, #best - 1)
		out = best ~= "" and best .. dots or dots

		lbl:setText(out)

		guard = guard + 1
	end

	return out
end

local function refreshActionSlotSpellParameter(slot)
	if not slot or slot:isDestroyed() then
		return
	end

	local lbl = slot:recursiveGetChildById("spellParameter")

	if not lbl then
		return
	end

	if slot.words and slot.words ~= "" then
		local spell = Spells.getSpellByWords(slot.words)

		if spell and spell.parameter then
			local p = slot.parameter
			local s = p ~= nil and tostring(p):gsub("^%s+", ""):gsub("%s+$", "") or ""

			if s ~= "" then
				lbl:setVisible(true)
				lbl:setText(ellipsizeSpellParameterLabelText(lbl, s))

				return
			end
		end
	end

	lbl:setVisible(false)
	lbl:setText("")
end

function refreshActionSlotInventoryQuantity(slot)
	if not slot or slot:isDestroyed() then
		return
	end

	local lbl = slot:getChildById("count")

	local function hideCountLabel()
		if lbl then
			lbl:setVisible(false)
			lbl:setText("")
		end
	end

	if slot.text or slot.passiveId then
		hideCountLabel()
		refreshActionSlotSpellParameter(slot)

		return
	end

	if slot.words and slot.words ~= "" then
		hideCountLabel()
		refreshActionSlotSpellParameter(slot)

		return
	end

	if isActionSlotEquip(slot) and isActionSlotEquipmentPreset(slot) then
		hideCountLabel()
		refreshActionSlotSpellParameter(slot)

		return
	end

	if not slot.itemId or slot.itemId <= 0 then
		hideCountLabel()
		refreshActionSlotSpellParameter(slot)

		return
	end

	local player = g_game.getLocalPlayer()
	local n = 0

	if player then
		n = getActionBarInventoryDisplayCount(slot.itemId, actionSlotItemTier(slot), player)
	end

	if not lbl then
		return
	end

	local show = slot._actionBarShowCount == true

	lbl:setVisible(show)

	if show then
		lbl:setText(tostring(n))
	else
		lbl:setText("")
	end

	refreshActionSlotSpellParameter(slot)
end

local ProgressCallback = {
	finish = 2,
	update = 1
}

local function isBottomBar(barId)
	return barId and barId >= BAR_BOTTOM_1 and barId <= BAR_BOTTOM_3
end

local function isLeftBar(barId)
	return barId and barId >= BAR_LEFT_1 and barId <= BAR_LEFT_3
end

local function isRightBar(barId)
	return barId and barId >= BAR_RIGHT_1 and barId <= BAR_RIGHT_3
end

local function isSideBar(barId)
	return isLeftBar(barId) or isRightBar(barId)
end

function normalizeSideBarChildOrder(side)
	local order

	if side == "left" then
		order = {
			BAR_LEFT_3,
			BAR_LEFT_2,
			BAR_LEFT_1
		}
	elseif side == "right" then
		order = {
			BAR_RIGHT_1,
			BAR_RIGHT_2,
			BAR_RIGHT_3
		}
	else
		return
	end

	for _, bid in ipairs(order) do
		local b = actionBars[bid]

		if b and not b:isDestroyed() then
			b:raise()
		end
	end
end

function actionBarLockGroupForBar(barId)
	if isLeftBar(barId) then
		return "left"
	elseif isRightBar(barId) then
		return "right"
	end

	return "bottom"
end

function isActionBarGroupLocked(group)
	if not actionBarLocks then
		return isLocked
	end

	return actionBarLocks[group or "bottom"] == true
end

function isActionBarLocked(barId)
	if not barId then
		return false
	end

	return isActionBarGroupLocked(actionBarLockGroupForBar(barId))
end

local function slotsForBar(barId)
	return isSideBar(barId) and SIDE_BAR_TOTAL_SLOTS or maxSlots
end

function barWidgetChild(bar, id)
	if not bar or bar:isDestroyed() or not id then
		return nil
	end

	if bar.recursiveGetChildById then
		return bar:recursiveGetChildById(id)
	end

	return bar:getChildById(id)
end

local SLOT_IMG_EMPTY = "/images/game/actionbar/slot-actionbar-empty"
local SLOT_IMG_FILLED = "/images/game/actionbar/slot-actionbar-filled"
local SLOT_CLIP_EMPTY = "0 0 0 0"
local SLOT_CLIP_FILLED_NORMAL = "0 0 34 34"
local SLOT_CLIP_FILLED_PRESSED = "0 34 34 34"

local function refreshActionSlotFilledClip(slot)
	if not slot or slot:isDestroyed() or not slot._actionBarFilledFrame then
		return
	end

	if slot.passiveId ~= nil then
		slot:setImageClip(SLOT_CLIP_FILLED_PRESSED)
	elseif slot._helperAssignPreview then
		slot:setImageClip(SLOT_CLIP_FILLED_NORMAL)
	elseif slot:isPressed() or not isActionSlotEquipmentPreset(slot) and isActionSlotEquipEquipped(slot) then
		slot:setImageClip(SLOT_CLIP_FILLED_PRESSED)
	else
		slot:setImageClip(SLOT_CLIP_FILLED_NORMAL)
	end
end

function applyActionSlotFrame(slot)
	if not slot or slot:isDestroyed() then
		return
	end

	local hasText = slot.text and slot.text ~= ""
	local hasItem = slot:getItem() ~= nil
	local hasSpell = slot.words ~= nil and slot.words ~= ""
	local hasPassive = slot.passiveId ~= nil
	local hasEquipmentPreset = isActionSlotEquipmentPreset(slot)

	if hasText or hasItem or hasSpell or hasPassive or hasEquipmentPreset then
		slot:setImageSource(SLOT_IMG_FILLED)

		slot._actionBarFilledFrame = true

		refreshActionSlotFilledClip(slot)
	else
		slot:setImageSource(SLOT_IMG_EMPTY)
		slot:setImageClip(SLOT_CLIP_EMPTY)

		slot._actionBarFilledFrame = false
	end

	syncSlotHotkeyMirror(slot)
end

function refreshActionSlotFrameClip(slot)
	if not slot or slot:isDestroyed() then
		return
	end

	refreshActionSlotFilledClip(slot)
end

local function anchorGroupCooldownBelowBottomStack()
	local cd = modules.game_cooldown and modules.game_cooldown.cooldownWindow

	if not cd or cd:isDestroyed() then
		return
	end

	cd:removeAnchor(AnchorTop)
	cd:setMarginTop(1)

	if modules.game_interface and modules.game_interface.isBottomStatsBarDockActive and modules.game_interface.isBottomStatsBarDockActive() then
		local statsPanel = modules.game_interface.getGameBottomStatsBar and modules.game_interface.getGameBottomStatsBar()
		local totalMargin = 0

		if statsPanel and not statsPanel:isDestroyed() then
			totalMargin = statsPanel:getMarginTop() + statsPanel:getHeight()
		end

		cd:addAnchor(AnchorTop, "parent", AnchorTop)
		cd:setMarginTop(math.max(0, totalMargin - 6))
	else
		local anchorBar

		for barId = BAR_BOTTOM_3, BAR_BOTTOM_1, -1 do
			local bar = actionBars[barId]

			if bar and not bar:isDestroyed() and bar:isVisible() and bar:getHeight() > 0 then
				anchorBar = bar

				break
			end
		end

		if anchorBar then
			cd:addAnchor(AnchorTop, anchorBar:getId(), AnchorBottom)
			cd:setMarginTop(1)
		else
			cd:addAnchor(AnchorTop, "parent", AnchorTop)
		end
	end

	if modules.game_cooldown and modules.game_cooldown.refreshConsoleAnchor then
		modules.game_cooldown.refreshConsoleAnchor()
	end
end

function refreshBottomCooldownDock()
	anchorGroupCooldownBelowBottomStack()
end

function slotIdFor(barId, i)
	if barId == BAR_BOTTOM_1 then
		return "slot" .. i
	end

	return "bar" .. barId .. "_slot" .. i
end

local function clearExternalSpellAssignContext()
	externalAssignSlot = nil
	externalAssignSlotId = nil
	spellAssignListFilter = nil
	onExternalSpellAssignApplied = nil
	onExternalObjectAssignApplied = nil
	onExternalTextAssignApplied = nil
end

function openHelperSpellAssignWindow(slotWidget, slotId, filterFn, onAppliedFn)
	if not slotWidget or not slotId then
		return
	end

	if spellAssignWindow and not spellAssignWindow:isDestroyed() then
		closeSpellAssignWindow()
	end

	externalAssignSlot = slotWidget
	externalAssignSlotId = slotId
	spellAssignListFilter = filterFn
	onExternalSpellAssignApplied = onAppliedFn
	slotToEdit = slotId

	if slotWidget.words and slotWidget.words ~= "" then
		spellAssignPreferredSpellOverride = Spells.getSpellNameByWords(slotWidget.words:lower():trim())
	else
		spellAssignPreferredSpellOverride = nil
	end

	openSpellAssignWindow()
end

function findSlotById(slotId)
	if not slotId then
		return nil, nil
	end

	if externalAssignSlotId and slotId == externalAssignSlotId and externalAssignSlot then
		return externalAssignSlot, nil
	end

	for i = 1, NUM_BARS do
		local panel = actionBarPanels[i]

		if panel then
			local s = panel:getChildById(slotId)

			if s then
				return s, i
			end
		end
	end

	return nil, nil
end

local function slotBarAndIndexFromSlotId(slotId)
	if not slotId then
		return nil, nil
	end

	local only = slotId:match("^slot(%d+)$")

	if only then
		return BAR_BOTTOM_1, tonumber(only)
	end

	local bid, idx = slotId:match("^bar(%d+)_slot(%d+)$")

	if bid and idx then
		return tonumber(bid), tonumber(idx)
	end

	return nil, nil
end

function getSlotBarId(slotId)
	local barId = slotBarAndIndexFromSlotId(slotId)

	return barId
end

local function actionBarRegionTitle(barId)
	if not barId then
		return tr("Action Bar")
	end

	if barId >= BAR_BOTTOM_1 and barId <= BAR_BOTTOM_3 then
		return tr("Bottom Action Bar")
	end

	if barId >= BAR_LEFT_1 and barId <= BAR_LEFT_3 then
		return tr("Left Action Bar")
	end

	if barId >= BAR_RIGHT_1 and barId <= BAR_RIGHT_3 then
		return tr("Right Action Bar")
	end

	return tr("Action Bar")
end

local function actionBarSlotCoordinateBarNumber(barId)
	if barId >= BAR_BOTTOM_1 and barId <= BAR_BOTTOM_3 then
		return barId
	end

	if barId == BAR_LEFT_3 then
		return 4
	end

	if barId == BAR_LEFT_2 then
		return 5
	end

	if barId == BAR_LEFT_1 then
		return 6
	end

	if barId == BAR_RIGHT_1 then
		return 7
	end

	if barId == BAR_RIGHT_2 then
		return 8
	end

	if barId == BAR_RIGHT_3 then
		return 9
	end

	return barId
end

local function actionBarDisplayNumber(barId)
	return actionBarSlotCoordinateBarNumber(barId)
end

local function setObjectAssignWindowTitle()
	if not objectAssignWindow then
		return
	end

	local slot = slotToEdit and findSlotById(slotToEdit) or nil
	local isEdit = slot and slot.itemId and slot.itemId > 0
	local barId, slotIdx = slotBarAndIndexFromSlotId(slotToEdit)

	if barId and slotIdx then
		local barNum = actionBarDisplayNumber(barId)

		if isEdit then
			objectAssignWindow:setText(tr("Edit Object to Action Button %d.%02d", barNum, slotIdx))
		else
			objectAssignWindow:setText(tr("Assign Object to Action Button %d.%02d", barNum, slotIdx))
		end
	else
		objectAssignWindow:setText(tr(isEdit and "Edit Object" or "Assign Object"))
	end
end

local function setTextAssignWindowTitle()
	if not textAssignWindow then
		return
	end

	local slot = slotToEdit and findSlotById(slotToEdit) or nil
	local isEdit = slot and slot.text and slot.text ~= ""
	local barId, slotIdx = slotBarAndIndexFromSlotId(slotToEdit)

	if barId and slotIdx then
		local barNum = actionBarDisplayNumber(barId)

		if isEdit then
			textAssignWindow:setText(tr("Edit Text to Action Button %d.%02d", barNum, slotIdx))
		else
			textAssignWindow:setText(tr("Assign Text to Action Button %d.%02d", barNum, slotIdx))
		end
	else
		textAssignWindow:setText(tr(isEdit and "Edit Text" or "Assign Text"))
	end
end

local function setSpellAssignWindowTitle()
	if not spellAssignWindow then
		return
	end

	local slot = slotToEdit and findSlotById(slotToEdit) or nil
	local isEdit = slot and slot.words and slot.words ~= ""
	local barId, slotIdx = slotBarAndIndexFromSlotId(slotToEdit)

	if barId and slotIdx then
		local barNum = actionBarDisplayNumber(barId)

		if isEdit then
			spellAssignWindow:setText(tr("Edit Spell to Action Button %d.%02d", barNum, slotIdx))
		else
			spellAssignWindow:setText(tr("Assign Spell to Action Button %d.%02d", barNum, slotIdx))
		end
	else
		spellAssignWindow:setText(tr(isEdit and "Edit Spell" or "Assign Spell"))
	end
end

function getSlotHotkeyForChatMode(slot, chatOn)
	if not slot then
		return ""
	end

	if chatOn == nil then
		chatOn = modules.game_console and modules.game_console.isChatEnabled and modules.game_console.isChatEnabled()
	end

	local raw

	if chatOn then
		raw = slot.hotkeyChatOn
	else
		raw = slot.hotkeyChatOff
	end

	if raw == nil or raw == "" then
		return ""
	end

	return type(raw) == "string" and raw or tostring(raw)
end

local USE_TYPE_ACTION_LABELS = {
	useAtCursor = "Use this object at Cursor Position",
	useOnTarget = "Use this object on Target",
	equip = "Equip this object",
	useOnSelf = "Use this object on Yourself",
	use = "Use this object",
	useWith = "Use this object with Crosshair"
}

local function formatSpellExhaustionTooltip(ms)
	if type(ms) ~= "number" or ms <= 0 then
		return "0s"
	end

	local sec = math.floor(ms / 1000)

	if sec >= 3600 and sec % 3600 == 0 then
		return string.format("%dh", sec / 3600)
	end

	if sec >= 60 and sec % 60 == 0 then
		return string.format("%dmin", sec / 60)
	end

	return string.format("%ds", sec)
end

local function actionSlotHotkeyTooltipText(slot)
	local hk = getSlotHotkeyForChatMode(slot)

	if hk == nil or hk == "" then
		return "None"
	end

	local shown = ActionBarHotkeyLogic.formatHotkeyTooltipText(hk)

	if shown == nil or shown == "" then
		return hk
	end

	return shown
end

local function actionSlotHasAssignedAction(slot)
	if not slot then
		return false
	end

	if slot.words and slot.words ~= "" then
		return true
	end

	if slot.text and slot.text ~= "" then
		return true
	end

	if slot.passiveId then
		return true
	end

	if isActionSlotEquipmentPreset(slot) then
		return true
	end

	if slot.itemId and slot.itemId > 0 and slot.useType then
		return true
	end

	if slotHasMultiActions and slotHasMultiActions(slot) then
		return true
	end

	return false
end

local function buildActionSlotTooltip(slot)
	if not slot then
		return ""
	end

	local barId, slotIdx = slotBarAndIndexFromSlotId(slot:getId())
	local header = "Action Button"

	if barId and slotIdx then
		header = string.format("Action Button %d.%d", actionBarDisplayNumber(barId), slotIdx)
	end

	local hotkeyLine = "Hotkeys: " .. actionSlotHotkeyTooltipText(slot)

	if not actionSlotHasAssignedAction(slot) then
		return header .. "\n\nAction: None\n" .. hotkeyLine
	end

	if slot.passiveId and PassiveAbilities[slot.passiveId] then
		return header .. "\n\nPassive Ability: " .. PassiveAbilities[slot.passiveId].name .. "\n" .. hotkeyLine
	end

	if slot.words and slot.words ~= "" then
		local spell, _, spellName = Spells.getSpellByWords(slot.words)
		local displayName = spellName or spell and spell.name or slot.words
		local lines = {
			"Action: Cast " .. displayName,
			"Formula: " .. slot.words
		}

		if spell and spell.exhaustion then
			table.insert(lines, "Cooldown: " .. formatSpellExhaustionTooltip(spell.exhaustion))
		end

		if spell and spell.mana then
			table.insert(lines, "Mana: " .. tostring(spell.mana))
		end

		table.insert(lines, hotkeyLine)

		return header .. "\n\n" .. table.concat(lines, "\n")
	end

	if slot.text and slot.text ~= "" then
		return header .. "\n\nAction: Say \"" .. slot.text .. "\"\nAuto sent: " .. (slot.autoSend and "Yes" or "No") .. "\n" .. hotkeyLine
	end

	if isActionSlotEquipmentPreset(slot) then
		local actionText = "Equip equipment set"

		if slot.equipmentDescription and slot.equipmentDescription ~= "" then
			actionText = slot.equipmentDescription
		end

		return header .. "\n\nAction: " .. actionText .. "\n" .. hotkeyLine
	end

	if slotHasMultiActions and slotHasMultiActions(slot) then
		return header .. "\n\nAction: Multi-Action\n" .. hotkeyLine
	end

	if slot.itemId and slot.itemId > 0 and slot.useType then
		local actionLabel = USE_TYPE_ACTION_LABELS[slot.useType] or "Use this object"
		local amount = 0
		local player = g_game.getLocalPlayer()

		if player then
			amount = player:getInventoryCount(slot.itemId, actionSlotItemTier(slot))
		end

		return header .. "\n\nAction: " .. actionLabel .. "\nAmount: " .. tostring(amount) .. "\n" .. hotkeyLine
	end

	return header .. "\n\nAction: None\n" .. hotkeyLine
end

function refreshActionSlotTooltip(slot)
	if not slot or slot:isDestroyed() or not slot.setTooltip then
		return
	end

	if modules.client_options and modules.client_options.getOption("actionTooltip") == false then
		slot:setTooltip("")

		return
	end

	slot:setTooltip(buildActionSlotTooltip(slot))
end

local function applyHotkeyKeyLabel(slot, combo)
	local key = slot:getChildById("key")

	if key then
		key:setText(ActionBarHotkeyLogic.formatHotkeySlotText(combo))
	end
end

function syncSlotHotkeyMirror(slot)
	local hk = getSlotHotkeyForChatMode(slot)

	slot.hotkey = hk

	applyHotkeyKeyLabel(slot, hk)
	refreshActionSlotTooltip(slot)
end

local function refreshAllSlotsHotkeyMirror()
	for i = 1, NUM_BARS do
		local panel = actionBarPanels[i]

		if panel then
			for _, slot in pairs(panel:getChildren()) do
				syncSlotHotkeyMirror(slot)
			end
		end
	end
end

local function coerceStoredHotkeyField(v, fallback)
	local x = v

	if x == nil then
		x = fallback
	end

	if x == nil then
		return ""
	end

	return type(x) == "string" and x or tostring(x)
end

local function initDefaultHotkeysFirstBottomBarSlot(slot, indexInBar)
	if indexInBar >= 1 and indexInBar <= 12 then
		local def = "F" .. tostring(indexInBar)

		slot.hotkeyChatOn = def
		slot.hotkeyChatOff = def
	else
		slot.hotkeyChatOn = ""
		slot.hotkeyChatOff = ""
	end

	syncSlotHotkeyMirror(slot)
end

local function applyLoadedSlotHotkeys(slot, setting)
	local legacy = setting.hotkey

	if setting.hotkeyChatOn ~= nil or setting.hotkeyChatOff ~= nil or legacy ~= nil then
		slot.hotkeyChatOn = coerceStoredHotkeyField(setting.hotkeyChatOn, legacy)
		slot.hotkeyChatOff = coerceStoredHotkeyField(setting.hotkeyChatOff, legacy)
	end

	syncSlotHotkeyMirror(slot)
end

local function applySavedSlotSetting(slot, setting)
	if not slot or not setting then
		return
	end

	applyLoadedSlotHotkeys(slot, setting)

	local hasMulti = setting.multiActions and not table.empty(setting.multiActions)

	if hasMulti and loadSlotMultiActions then
		loadSlotMultiActions(slot, setting.multiActions)

		return
	end

	if initMultiActionSlot then
		initMultiActionSlot(slot)
	end

	slot.itemId = setting.itemId

	slot:setItemId(setting.itemId)

	slot.subType = setting.subType
	slot.words = setting.words
	slot.text = setting.text
	slot.useType = setting.useType
	slot.autoSend = setting.autoSend
	slot.parameter = setting.parameter
	slot.crossHairMode = type(setting.crossHairMode) == "string" and setting.crossHairMode or nil

	local tier = setting.getTier

	slot.getTier = type(tier) == "number" and tier or nil
	slot.passiveId = setting.passiveId
	slot.equipmentIconIndex = type(setting.equipmentIconIndex) == "number" and normalizeEquipmentIconIndex(setting.equipmentIconIndex) or nil
	slot.equipmentDescription = setting.equipmentDescription or ""
	slot.equipmentTypeIndex = type(setting.equipmentTypeIndex) == "number" and normalizeEquipmentTypeIndex(setting.equipmentTypeIndex) or 0
	slot.smartMode = setting.smartMode == true and true or nil
	slot.smartBaseItemId = type(setting.smartBaseItemId) == "number" and setting.smartBaseItemId or nil
	slot.equipments = normalizeEquipmentsFromSetting(setting.equipments)

	ItemsDatabase.setTier(slot, slot.getTier)

	if slot.words then
		loadSpell(slot)
	elseif slot.text then
		loadText(slot)
	elseif slot.passiveId then
		loadPassive(slot)
	elseif slot.useType == "equip" then
		if isEquipmentIconDeterminedOnSlot(slot) or slot.equipments ~= nil then
			slot.equipments = slot.equipments or {}

			local display = equipmentAssignDisplayEntry(slot.equipments)

			if display then
				slot.itemId = display.itemId
				slot.getTier = display.getTier
				slot.subType = display.subType
			else
				slot.itemId = 0
				slot.getTier = nil
				slot.subType = nil
			end

			loadEquipmentSetDisplay(slot)
		elseif slot.itemId and slot.itemId > 0 then
			slot.equipments = nil
			slot.equipmentIconIndex = nil
			slot.equipmentDescription = nil
			slot.equipmentTypeIndex = nil

			loadObject(slot)
		end
	elseif slot.itemId and slot.itemId > 0 then
		loadObject(slot)
	end
end

function maybeSetupHotkeysAfterSlotLoad()
	if actionBarBatchDepth <= 0 then
		setupHotkeys()
	end
end

local function applyPresetSlotsToActionBar(slots)
	if not slots then
		return
	end

	for slotKey, setting in pairs(slots) do
		local slot = findSlotById(slotKey)

		if slot then
			applySavedSlotSetting(slot, setting)
		end
	end
end

local function jsonScalar(value)
	local t = type(value)

	if t == "number" or t == "string" or t == "boolean" then
		return value
	end

	return nil
end

function serializeEquipmentsForJson(equipments)
	if not equipments then
		return nil
	end

	local out = {}

	for invSlot, entry in pairs(equipments) do
		if type(invSlot) == "number" and entry and entry.itemId and entry.itemId > 0 and not isEquipmentAssignVisualBackpackSlot(invSlot) then
			out[tostring(invSlot)] = {
				itemId = entry.itemId,
				getTier = type(entry.getTier) == "number" and entry.getTier or nil,
				subType = type(entry.subType) == "number" and entry.subType or nil
			}
		end
	end

	return out
end

function normalizeEquipmentsFromSetting(equipments)
	if equipments == nil then
		return nil
	end

	if type(equipments) ~= "table" then
		return nil
	end

	local out = {}

	for k, entry in pairs(equipments) do
		if type(entry) == "table" and type(entry.itemId) == "number" and entry.itemId > 0 then
			local invSlot = type(k) == "number" and k or tonumber(k)

			if invSlot and not isEquipmentAssignVisualBackpackSlot(invSlot) then
				out[invSlot] = {
					itemId = entry.itemId,
					getTier = type(entry.getTier) == "number" and entry.getTier or nil,
					subType = type(entry.subType) == "number" and entry.subType or nil
				}
			end
		end
	end

	return out
end

local function serializeSlotToSetting(slot)
	local tier = slot.getTier

	if type(tier) ~= "number" then
		tier = nil
	end

	local hotkeyOn = slot.hotkeyChatOn
	local hotkeyOff = slot.hotkeyChatOff

	if type(hotkeyOn) ~= "string" then
		hotkeyOn = ""
	end

	if type(hotkeyOff) ~= "string" then
		hotkeyOff = ""
	end

	return {
		hotkeyChatOn = hotkeyOn,
		hotkeyChatOff = hotkeyOff,
		autoSend = slot.autoSend == true and true or (slot.autoSend ~= false or true) and nil,
		itemId = type(slot.itemId) == "number" and slot.itemId or nil,
		subType = type(slot.subType) == "number" and slot.subType or nil,
		useType = jsonScalar(slot.useType),
		text = jsonScalar(slot.text),
		words = jsonScalar(slot.words),
		parameter = jsonScalar(slot.parameter),
		crossHairMode = type(slot.crossHairMode) == "string" and slot.crossHairMode or nil,
		getTier = tier,
		passiveId = type(slot.passiveId) == "number" and slot.passiveId or nil,
		multiActions = serializeSlotMultiActions and serializeSlotMultiActions(slot) or nil,
		equipments = slot.equipments ~= nil and serializeEquipmentsForJson(slot.equipments) or nil,
		equipmentIconIndex = type(slot.equipmentIconIndex) == "number" and normalizeEquipmentIconIndex(slot.equipmentIconIndex) or nil,
		equipmentDescription = jsonScalar(slot.equipmentDescription),
		equipmentTypeIndex = type(slot.equipmentTypeIndex) == "number" and normalizeEquipmentTypeIndex(slot.equipmentTypeIndex) or nil,
		smartMode = slot.smartMode == true and true or nil,
		smartBaseItemId = type(slot.smartBaseItemId) == "number" and slot.smartBaseItemId or nil
	}
end

local function collectCharacterActionBarSlots()
	local hotkeys = {}

	for i = 1, NUM_BARS do
		local panel = actionBarPanels[i]

		if panel then
			for _, slot in ipairs(panel:getChildren()) do
				hotkeys[slot:getId()] = serializeSlotToSetting(slot)
			end
		end
	end

	return hotkeys
end

local function loadActionBarSettingsForCurrentPreset()
	return getActionBarSlotsForPreset(getActionBarDefaultPresetName())
end

function getCurrentSlot()
	local s = findSlotById(slotToEdit)

	return s
end

local function updateSideContainerWidths()
	local leftContainer = modules.game_interface.getActionBarLeftPanel and modules.game_interface.getActionBarLeftPanel()
	local rightContainer = modules.game_interface.getActionBarRightPanel and modules.game_interface.getActionBarRightPanel()

	if leftContainer and not leftContainer:isDestroyed() then
		local w = 0
		local visibleBars = 0

		for _, barId in ipairs({
			BAR_LEFT_1,
			BAR_LEFT_2,
			BAR_LEFT_3
		}) do
			local bar = actionBars[barId]

			if bar and not bar:isDestroyed() and bar:getWidth() > 0 then
				w = w + SIDE_BAR_WIDTH
				visibleBars = visibleBars + 1
			end
		end

		if visibleBars > 1 then
			w = w + SIDE_BAR_SPACING * (visibleBars - 1)
		end

		leftContainer:setWidth(w)
		leftContainer:setVisible(w > 0)
		leftContainer:setPhantom(true)
		leftContainer:setImageSource("/images/ui/background")
		leftContainer:setImageRepeated(true)

		local layout = leftContainer:getLayout()

		if layout and layout.setSpacing then
			layout:setSpacing(SIDE_BAR_SPACING)
		end
	end

	if rightContainer and not rightContainer:isDestroyed() then
		local w = 0
		local visibleBars = 0

		for _, barId in ipairs({
			BAR_RIGHT_1,
			BAR_RIGHT_2,
			BAR_RIGHT_3
		}) do
			local bar = actionBars[barId]

			if bar and not bar:isDestroyed() and bar:getWidth() > 0 then
				w = w + SIDE_BAR_WIDTH
				visibleBars = visibleBars + 1
			end
		end

		if visibleBars > 1 then
			w = w + SIDE_BAR_SPACING * (visibleBars - 1)
		end

		rightContainer:setWidth(w)
		rightContainer:setVisible(w > 0)
		rightContainer:setPhantom(true)
		rightContainer:setImageSource("/images/ui/background")
		rightContainer:setImageRepeated(true)

		local layout = rightContainer:getLayout()

		if layout and layout.setSpacing then
			layout:setSpacing(SIDE_BAR_SPACING)
		end
	end

	if modules.game_interface and modules.game_interface.applyBottomSplitterLayoutHeight then
		modules.game_interface.applyBottomSplitterLayoutHeight()
	end

	if modules.game_interface and modules.game_interface.refreshSidebarLayout then
		modules.game_interface.refreshSidebarLayout()
		scheduleEvent(function()
			if modules.game_interface and modules.game_interface.refreshSidebarLayout then
				modules.game_interface.refreshSidebarLayout()
			end
		end, 0)
	end
end

local function sideTopButtonsOffset()
	local offset = 54

	if g_settings.getString("statsbar_placement") ~= "top" then
		return offset
	end

	local topStatsBar = modules.game_interface.getGameTopStatsBar and modules.game_interface.getGameTopStatsBar()

	if topStatsBar and not topStatsBar:isDestroyed() and topStatsBar:isVisible() then
		offset = math.max(offset, topStatsBar:getHeight())
	end

	return offset
end

function refreshSideActionBarOffsets()
	local offset = sideTopButtonsOffset()

	for _, barId in ipairs({
		BAR_LEFT_1,
		BAR_LEFT_2,
		BAR_LEFT_3,
		BAR_RIGHT_1,
		BAR_RIGHT_2,
		BAR_RIGHT_3
	}) do
		local bar = actionBars[barId]

		if bar and not bar:isDestroyed() then
			local prevBtn = barWidgetChild(bar, "prevButton")

			if prevBtn then
				prevBtn:setMarginTop(offset)
			end
		end
	end
end

local function bottomBarStackAnchorTarget(barId)
	if barId <= BAR_BOTTOM_1 then
		return "parent", AnchorTop
	end

	for prev = barId - 1, BAR_BOTTOM_1, -1 do
		local b = actionBars[prev]

		if b and not b:isDestroyed() and b:isVisible() and b:getHeight() > 0 then
			return b:getId(), AnchorBottom
		end
	end

	return "parent", AnchorTop
end

local function applyBottomAnchors()
	for _, bid in ipairs({
		BAR_BOTTOM_1,
		BAR_BOTTOM_2,
		BAR_BOTTOM_3
	}) do
		local bar = actionBars[bid]

		if bar and not bar:isDestroyed() then
			bar:breakAnchors()
			bar:addAnchor(AnchorLeft, "parent", AnchorLeft)
			bar:addAnchor(AnchorRight, "parent", AnchorRight)

			local targetId, targetEdge = bottomBarStackAnchorTarget(bid)

			bar:addAnchor(AnchorTop, targetId, targetEdge)
		end
	end

	layoutBottomLockButton()
	anchorGroupCooldownBelowBottomStack()
end

local function setupSlotsForPanel(barId, panel)
	local template = isSideBar(barId) and "ActionSlotV" or "ActionSlot"
	local slotCount = slotsForBar(barId)

	for i = 1, slotCount do
		local sid = slotIdFor(barId, i)
		local slot = g_ui.createWidget(template, panel)

		slot:setId(sid)

		slot._actionBarId = barId

		if initMultiActionSlot then
			initMultiActionSlot(slot)
		end

		slot:setVisible(true)

		slot.itemId = nil
		slot.subType = nil
		slot.words = nil
		slot.text = nil
		slot.useType = nil
		slot.getTier = nil

		if barId == BAR_BOTTOM_1 then
			initDefaultHotkeysFirstBottomBarSlot(slot, i)
		else
			slot.hotkeyChatOn = ""
			slot.hotkeyChatOff = ""
			slot.hotkey = ""

			syncSlotHotkeyMirror(slot)
		end

		g_mouse.bindPress(slot, function()
			slotToEdit = sid
		end, MouseLeftButton)
		g_mouse.bindPress(slot, function()
			createMenu(sid)
		end, MouseRightButton)

		if not isActionBarLocked(barId) then
			g_mouse.bindOnDrop(slot, function()
				local pressed = g_ui.getPressedWidget()

				if pressed and pressed ~= slot and pressed.multiActionIndex and pressed.parentSlot and handleDropFromMultiSubSlotOntoSlot then
					handleDropFromMultiSubSlotOntoSlot(pressed, sid)

					return
				end

				if slotToEdit == sid then
					slotReassign = sid
				end

				onDropFunc(sid)
			end)
		end

		if i == 1 then
			slot:breakAnchors()

			if isSideBar(barId) then
				slot:addAnchor(AnchorTop, "parent", AnchorTop)
				slot:addAnchor(AnchorLeft, "parent", AnchorLeft)
			else
				slot:addAnchor(AnchorLeft, "parent", AnchorLeft)
				slot:addAnchor(AnchorTop, "parent", AnchorTop)
				slot:setMarginLeft(2)
			end
		end
	end
end

function actionBarPanelHasExpectedSlots(barId, panel)
	if not panel or panel:isDestroyed() then
		return false
	end

	local slotCount = slotsForBar(barId)
	local children = panel:getChildren()

	if #children ~= slotCount then
		return false
	end

	for i = 1, slotCount do
		if not panel:getChildById(slotIdFor(barId, i)) then
			return false
		end
	end

	return true
end

function ensureActionBarPanelSlots(barId, panel)
	if actionBarPanelHasExpectedSlots(barId, panel) then
		return false
	end

	panel:destroyChildren()
	setupSlotsForPanel(barId, panel)

	return true
end

local function loadSavedSlotsForBar(barId)
	if not actionBarPanels[barId] then
		return
	end

	local hotkeys = loadActionBarSettingsForCurrentPreset()

	if not hotkeys then
		return
	end

	for slotKey, setting in pairs(hotkeys) do
		local slot = actionBarPanels[barId]:getChildById(slotKey)

		if slot then
			applySavedSlotSetting(slot, setting)
		end
	end
end

local function ensureBarLoaded(barId)
	if actionBars[barId] then
		return actionBars[barId]
	end

	if not bottomPanel then
		bottomPanel = modules.game_interface.getBottomPanel()
	end

	local ok, bar

	if isSideBar(barId) then
		local container

		if isLeftBar(barId) then
			container = modules.game_interface.getActionBarLeftPanel and modules.game_interface.getActionBarLeftPanel()
		else
			container = modules.game_interface.getActionBarRightPanel and modules.game_interface.getActionBarRightPanel()
		end

		if not container then
			return nil
		end

		ok, bar = pcall(g_ui.loadUI, "game_actionbar_side", container)
	else
		ok, bar = pcall(g_ui.loadUI, "game_actionbar", bottomPanel)
	end

	if not ok or not bar then
		return nil
	end

	bar:setId("actionBar" .. barId)
	bar:setVisible(false)

	if isSideBar(barId) then
		bar:setWidth(0)
		bar:setImageSource("/images/ui/background")
		bar:setImageRepeated(true)
		bar:setClipping(false)
	else
		bar:setHeight(0)
	end

	actionBars[barId] = bar
	actionBarPanels[barId] = barWidgetChild(bar, "actionBarPanel")

	if actionBarPanels[barId] then
		actionBarPanels[barId].onMouseWheel = function()
			return true
		end
	end

	if isSideBar(barId) then
		local vScroll = barWidgetChild(bar, "verticalScroll")

		if vScroll then
			function vScroll.onMouseWheel()
				return true
			end
		end
	else
		local hScroll = barWidgetChild(bar, "horizontalScroll")

		if hScroll then
			function hScroll.onMouseWheel()
				return true
			end
		end
	end

	if isBottomBar(barId) then
		applyBottomAnchors()
	end

	if isSideBar(barId) then
		local SIDEBAR_BUTTON_OFFSET = sideTopButtonsOffset()
		local sideContentMarginLeft = isRightBar(barId) and 2 or 0
		local topButtonsMarginLeft = isRightBar(barId) and 2 or 0
		local bottomButtonsMarginRight = isLeftBar(barId) and 2 or 0
		local prevBtn = barWidgetChild(bar, "prevButton")

		if prevBtn then
			prevBtn:setMarginTop(SIDEBAR_BUTTON_OFFSET)
			prevBtn:setMarginLeft(topButtonsMarginLeft)
		end

		local lockBtn = barWidgetChild(bar, "sideLockButton")

		if lockBtn then
			lockBtn:setMarginLeft(sideContentMarginLeft)
			lockBtn:setMarginBottom(1)
		end

		local nextBtn = barWidgetChild(bar, "nextButton")

		if nextBtn then
			nextBtn:setMarginBottom(1)
		end

		local nextSkipBtn = barWidgetChild(bar, "nextSkipButton")

		if nextSkipBtn then
			nextSkipBtn:setMarginRight(bottomButtonsMarginRight)
			nextSkipBtn:setMarginBottom(1)
		end

		local panel = barWidgetChild(bar, "actionBarPanel")

		if panel then
			panel:setMarginTop(0)
			panel:setMarginLeft(sideContentMarginLeft)
		end

		local vScroll = barWidgetChild(bar, "verticalScroll")

		if vScroll then
			vScroll:setMarginTop(0)
		end
	end

	if isLeftBar(barId) then
		normalizeSideBarChildOrder("left")
	elseif isRightBar(barId) then
		normalizeSideBarChildOrder("right")
	end

	if actionBarPanels[barId] then
		ensureActionBarPanelSlots(barId, actionBarPanels[barId])

		if g_game.isOnline() then
			loadSavedSlotsForBar(barId)
			setupHotkeys()
		end
	end

	return bar
end

function init()
	if initMultiActionStyles then
		initMultiActionStyles()
	end

	bottomPanel = modules.game_interface.getBottomPanel()
	actionBars[BAR_BOTTOM_1] = g_ui.loadUI("game_actionbar", bottomPanel)

	actionBars[BAR_BOTTOM_1]:setId("actionBar1")

	actionBarPanels[BAR_BOTTOM_1] = barWidgetChild(actionBars[BAR_BOTTOM_1], "actionBarPanel")
	actionBar = actionBars[BAR_BOTTOM_1]
	actionBarPanel = actionBarPanels[BAR_BOTTOM_1]

	if actionBarPanel then
		function actionBarPanel.onMouseWheel()
			return true
		end

		ensureActionBarPanelSlots(BAR_BOTTOM_1, actionBarPanel)
	end

	local hScroll1 = barWidgetChild(actionBars[BAR_BOTTOM_1], "horizontalScroll")

	if hScroll1 then
		function hScroll1.onMouseWheel()
			return true
		end
	end

	setupBottomLockButton()

	actionBarPreloadEvent = scheduleEvent(function()
		actionBarPreloadEvent = nil

		if prepareActionBarForLogin then
			prepareActionBarForLogin()
		end
	end, 300)
	mouseGrabberWidget = g_ui.createWidget("UIWidget")

	mouseGrabberWidget:setVisible(false)
	mouseGrabberWidget:setFocusable(false)

	mouseGrabberWidget.onMouseRelease = onChooseItemMouseRelease

	if g_game.isOnline() then
		addEvent(function()
			online()
			setupActionBar()
			loadActionBar()
		end)
	end

	connect(g_game, {
		onGameStart = online,
		onGameEnd = offline,
		onSpellGroupCooldown = onSpellGroupCooldown,
		onSpellCooldown = onSpellCooldown,
		onMultiUseCooldown = onMultiUseCooldown,
		onVirtuesYellowBorder = onVirtuesYellowBorder
	})
	connect(LocalPlayer, {
		onInventoryChange = scheduleFullSlotGrayRefresh,
		onInventoryCountChange = scheduleInventorySlotGrayRefresh,
		onManaChange = onLocalPlayerManaChange,
		onLevelChange = scheduleFullSlotGrayRefresh
	})
	connect(Container, {
		onAddItem = scheduleInventorySlotGrayRefresh,
		onUpdateItem = scheduleInventorySlotGrayRefresh,
		onRemoveItem = scheduleInventorySlotGrayRefresh
	})

	if Keybind then
		function Keybind.isKeyComboUsedOnActionBar(keyCombo, chatMode)
			if not keyCombo or keyCombo == "" then
				return false
			end

			return isKeyComboUsedOnActionBar(keyCombo, chatMode == CHAT_MODE.ON)
		end

		function Keybind.clearActionBarHotkeyConflicts(keyCombo, chatMode)
			if not keyCombo or keyCombo == "" then
				return false
			end

			return clearActionBarHotkeyConflicts(keyCombo, chatMode == CHAT_MODE.ON)
		end
	end

	modules.game_actionbar.replaceActionBarPresetSlots = replaceActionBarPresetSlots
	modules.game_actionbar.invalidateActionBarSettingsCache = invalidateActionBarSettingsCache
	modules.game_actionbar.markPresetsMigrationComplete = markActionBarPresetsMigrationComplete
	modules.game_actionbar.loadActionBar = loadActionBar
	modules.game_actionbar.reloadActionBarForPreset = reloadActionBarForPreset
	modules.game_actionbar.copyActionBarPreset = copyActionBarPreset
	modules.game_actionbar.renameActionBarPreset = renameActionBarPreset
	modules.game_actionbar.removeActionBarPreset = removeActionBarPreset
	modules.game_actionbar.onHotkeyPresetChanged = onHotkeyPresetChanged
end

function terminate()
	if actionBarPreloadEvent then
		removeEvent(actionBarPreloadEvent)

		actionBarPreloadEvent = nil
	end

	if terminateMultiAction then
		terminateMultiAction()
	end

	if bottomLockPressDeferredEvent then
		removeEvent(bottomLockPressDeferredEvent)

		bottomLockPressDeferredEvent = nil
	end

	if slotGrayRefreshEvent then
		removeEvent(slotGrayRefreshEvent)

		slotGrayRefreshEvent = nil
	end

	slotGrayFullRefreshPending = false
	slotGrayStatsPendingSlots = {}
	slotGrayInventoryRefreshPending = false

	disconnect(LocalPlayer, {
		onInventoryChange = scheduleFullSlotGrayRefresh,
		onInventoryCountChange = scheduleInventorySlotGrayRefresh,
		onManaChange = onLocalPlayerManaChange,
		onLevelChange = scheduleFullSlotGrayRefresh
	})
	disconnect(Container, {
		onAddItem = scheduleInventorySlotGrayRefresh,
		onUpdateItem = scheduleInventorySlotGrayRefresh,
		onRemoveItem = scheduleInventorySlotGrayRefresh
	})

	bottomLockButton = nil
	slotToEdit = nil
	slotReassign = nil
	missedSlotToEdit = nil

	for i = 1, NUM_BARS do
		if actionBars[i] then
			actionBars[i]:destroy()

			actionBars[i] = nil
			actionBarPanels[i] = nil
		end
	end

	actionBar = nil
	actionBarPanel = nil

	mouseGrabberWidget:destroy()
	disconnect(g_game, {
		onGameStart = online,
		onGameEnd = offline,
		onSpellGroupCooldown = onSpellGroupCooldown,
		onSpellCooldown = onSpellCooldown,
		onMultiUseCooldown = onMultiUseCooldown,
		onVirtuesYellowBorder = onVirtuesYellowBorder
	})

	if spellAssignWindow then
		closeSpellAssignWindow()
	end

	if objectAssignWindow then
		closeObjectAssignWindow()
	end

	if textAssignWindow then
		closeTextAssignWindow()
	end

	if equipmentAssignWindow then
		closeEquipmentAssignWindow()
	end

	if editHotkeyWindow then
		closeEditHotkeyWindow()
	end

	if spellsPanel then
		disconnect(spellsPanel, {
			onChildFocusChange = function(self, focusedChild)
				if focusedChild == nil then
					return
				end

				updatePreviewSpell(focusedChild)
			end
		})
	end
end

function online()
	invalidateActionBarSettingsCache()
	anchorGroupCooldownBelowBottomStack()

	slotToEdit = nil
	slotReassign = nil
	missedSlotToEdit = nil

	if terminateMultiAction then
		terminateMultiAction()
	end

	addEvent(function()
		local startedAt = g_clock.realMillis()

		setupActionBar()

		if g_settings.getBoolean("autoSwitchPreset") then
			local name = g_game.getCharacterName()

			if name and name ~= "" and Keybind.presetToIndex and Keybind.presetToIndex[name] then
				if Keybind.currentPreset ~= name then
					Keybind.selectPreset(name)
					updateSlotsVocation()

					return
				end
			elseif name and name ~= "" then
				g_logger.info(string.format("[login] autoSwitchPreset: no preset named \"%s\" (current=%s)", name, Keybind.currentPreset or "?"))
			end
		end

		local presetName = Keybind.currentPreset
		local reusedPreparedPreset = actionBarPreparedPreset == presetName

		if reusedPreparedPreset then
			setupHotkeys()
			applyClientOptionsToActionBar()
			refreshAllVirtueYellowBorders()
			updateSlotsVocation()
		else
			reloadActionBarForPreset(presetName, nil)
		end

		g_logger.info(string.format("[login] actionbar ready in %d ms (preloaded=%s)", g_clock.realMillis() - startedAt, tostring(reusedPreparedPreset)))
	end)
end

function offline()
	if closeCurrentMultiActionPanel then
		closeCurrentMultiActionPanel()
	end

	virtuesYellowBorderSpellIds = {}
	managedVirtueYellowBorderSpellIds = {}
	managedVirtueYellowBorderSelection = {}

	if not g_settings or not g_settings.getBoolean("cip_import_skip_session_save") then
		saveActionBar()
	end

	unbindHotkeys()
	invalidateActionBarSettingsCache()
end

local DRAG_PREVIEW_CHILD_IDS = {
	"count",
	"tier",
	"spellIcon",
	"gray",
	"text",
	"spellParameter",
	"multiIcon",
	"equipmentTypeIcon",
	"activeSpell"
}

local function copyDragPreviewChild(srcChild, dstChild)
	if not srcChild or not dstChild then
		return
	end

	if srcChild:isDestroyed() or dstChild:isDestroyed() then
		return
	end

	local visible = srcChild:isVisible()

	dstChild:setVisible(visible)

	if not visible then
		if dstChild.setText then
			pcall(dstChild.setText, dstChild, "")
		end

		return
	end

	if srcChild.getText and dstChild.setText then
		local ok, txt = pcall(srcChild.getText, srcChild)

		if ok and txt ~= nil then
			dstChild:setText(txt)
		end
	end

	local imgSrc = srcChild:getImageSource()

	if imgSrc and imgSrc ~= "" then
		dstChild:setImageSource(imgSrc)

		local clip = srcChild:getImageClip()

		if clip then
			dstChild:setImageClip(clip)
		end
	end

	if srcChild.getMarginLeft and dstChild.setMarginLeft then
		local ok2, m = pcall(srcChild.getMarginLeft, srcChild)

		if ok2 and type(m) == "number" then
			dstChild:setMarginLeft(m)
		end
	end
end

function applyDragPreviewFromSlot(sourceSlot, previewSlot)
	if not sourceSlot or not previewSlot then
		return
	end

	if sourceSlot:isDestroyed() or previewSlot:isDestroyed() then
		return
	end

	previewSlot:setImageSource(sourceSlot:getImageSource())

	local sourceImage = sourceSlot:getImageSource()

	if sourceSlot._actionBarFilledFrame or sourceImage == SLOT_IMG_FILLED then
		previewSlot:setImageClip(SLOT_CLIP_FILLED_NORMAL)
	else
		local frameClip = sourceSlot:getImageClip()

		if frameClip then
			previewSlot:setImageClip(frameClip)
		end
	end

	local srcItem = sourceSlot:getItem()

	if srcItem then
		previewSlot:setItem(srcItem)
	else
		previewSlot:setItem(nil)
	end

	for _, id in ipairs(DRAG_PREVIEW_CHILD_IDS) do
		copyDragPreviewChild(sourceSlot:getChildById(id), previewSlot:getChildById(id))
	end

	previewSlot.words = sourceSlot.words
	previewSlot.parameter = sourceSlot.parameter
	previewSlot.itemId = sourceSlot.itemId
	previewSlot.subType = sourceSlot.subType
	previewSlot.useType = sourceSlot.useType
	previewSlot.getTier = sourceSlot.getTier
	previewSlot.text = sourceSlot.text
	previewSlot.multiActions = sourceSlot.multiActions

	if clearSlotProgressWidgets then
		clearSlotProgressWidgets(previewSlot)
	end

	if refreshMultiActionSlotCooldownDisplay then
		refreshMultiActionSlotCooldownDisplay(previewSlot, false)
	end
end

function hideSourceSlotForDrag(sourceSlot)
	if not sourceSlot or sourceSlot:isDestroyed() then
		return
	end

	if sourceSlot._multiPanelOpen and closeCurrentMultiActionPanel then
		closeCurrentMultiActionPanel()
	end

	local existing = sourceSlot._dragSourceOverlay

	if existing and not existing:isDestroyed() then
		return
	end

	local rootW = rootWidget or g_ui.getRootWidget()

	if not rootW then
		return
	end

	local overlay = g_ui.createWidget("UIWidget", rootW)

	overlay:setId("dragSourceOverlay")
	overlay:setPhantom(true)
	overlay:setFocusable(false)
	overlay:setDraggable(false)
	overlay:setSize(sourceSlot:getSize())
	overlay:setPosition(sourceSlot:getPosition())
	overlay:setImageSource(SLOT_IMG_EMPTY)
	overlay:setImageSize({
		height = 34,
		width = 34
	})
	overlay:setImageClip(SLOT_CLIP_EMPTY)
	overlay:setBackgroundColor("#1a1a1aff")
	overlay:setBorderWidth(1)
	overlay:setBorderColor("#ffffff")
	overlay:raise()

	local srcKey = sourceSlot:getChildById("key")

	if srcKey and not srcKey:isDestroyed() and srcKey:isVisible() then
		local keyText = ""
		local ok, txt = pcall(srcKey.getText, srcKey)

		if ok and type(txt) == "string" then
			keyText = txt
		end

		if keyText ~= "" then
			local keyLabel = g_ui.createWidget("UILabel", overlay)

			keyLabel:setId("key")
			keyLabel:setPhantom(true)
			keyLabel:setFocusable(false)
			keyLabel:setDraggable(false)
			keyLabel:setFont("Verdana-8px-outline")
			keyLabel:setColor("#ffffff")
			keyLabel:setTextAutoResize(true)
			keyLabel:setText(keyText)
			keyLabel:addAnchor(AnchorTop, "parent", AnchorTop)
			keyLabel:addAnchor(AnchorRight, "parent", AnchorRight)
			keyLabel:setMarginRight(1)
		end
	end

	sourceSlot._dragSourceOverlay = overlay
end

function restoreSourceSlotAfterDrag(sourceSlot)
	if not sourceSlot or sourceSlot:isDestroyed() then
		return
	end

	local overlay = sourceSlot._dragSourceOverlay

	if overlay and not overlay:isDestroyed() then
		overlay:destroy()
	end

	sourceSlot._dragSourceOverlay = nil

	refreshActionSlotVirtueBorder(sourceSlot)
end

function clearDragPreviewSlot(previewSlot)
	if not previewSlot or previewSlot:isDestroyed() then
		return
	end

	previewSlot:setItem(nil)

	for _, id in ipairs(DRAG_PREVIEW_CHILD_IDS) do
		local child = previewSlot:getChildById(id)

		if child and not child:isDestroyed() then
			child:setVisible(false)

			if child.setText then
				pcall(child.setText, child, "")
			end
		end
	end

	if clearSlotProgressWidgets then
		clearSlotProgressWidgets(previewSlot)
	end

	previewSlot.words = nil
	previewSlot.parameter = nil
	previewSlot.itemId = nil
	previewSlot.subType = nil
	previewSlot.useType = nil
	previewSlot.getTier = nil
	previewSlot.text = nil
	previewSlot.multiActions = nil
end

local function clearCopiedSlotMultiActions(slot)
	if detachMultiActionFromSlot then
		detachMultiActionFromSlot(slot)

		return
	end

	slot.multiActions = nil

	local icon = slot:getChildById("multiIcon")

	if icon then
		icon:setVisible(false)
	end
end

local function copySlotMultiActions(fromSlot, toSlot)
	if not toSlot then
		return
	end

	if slotHasMultiActions and slotHasMultiActions(fromSlot) and serializeSlotMultiActions and loadSlotMultiActions then
		local copiedMultiActions = serializeSlotMultiActions(fromSlot)

		if copiedMultiActions then
			loadSlotMultiActions(toSlot, copiedMultiActions)

			return
		end
	end

	clearCopiedSlotMultiActions(toSlot)
end

local function copySlotEquipmentPreset(fromSlot, toSlot)
	if not toSlot then
		return
	end

	if not isActionSlotEquipmentPreset(fromSlot) then
		toSlot.equipments = nil
		toSlot.equipmentIconIndex = nil
		toSlot.equipmentDescription = nil
		toSlot.equipmentTypeIndex = nil

		return
	end

	if serializeEquipmentsForJson and normalizeEquipmentsFromSetting then
		toSlot.equipments = normalizeEquipmentsFromSetting(serializeEquipmentsForJson(fromSlot.equipments))
	else
		toSlot.equipments = nil
	end

	if fromSlot.equipments ~= nil and toSlot.equipments == nil then
		toSlot.equipments = {}
	end

	toSlot.equipmentIconIndex = type(fromSlot.equipmentIconIndex) == "number" and normalizeEquipmentIconIndex(fromSlot.equipmentIconIndex) or nil
	toSlot.equipmentDescription = fromSlot.equipmentDescription or ""
	toSlot.equipmentTypeIndex = type(fromSlot.equipmentTypeIndex) == "number" and normalizeEquipmentTypeIndex(fromSlot.equipmentTypeIndex) or 0
end

function copySlot(fromSlotId, toSlotId, visible)
	local fromSlot, fromBar = findSlotById(fromSlotId)

	if not fromSlot then
		return
	end

	local tmpslot = findSlotById(toSlotId)
	local destAlreadyExisted = tmpslot ~= nil
	local savedHotkeyOn, savedHotkeyOff

	if destAlreadyExisted then
		savedHotkeyOn = tmpslot.hotkeyChatOn or ""
		savedHotkeyOff = tmpslot.hotkeyChatOff or ""
	end

	if not tmpslot then
		local panel = actionBarPanels[fromBar]
		local template = isSideBar(fromBar) and "ActionSlotV" or "ActionSlot"

		tmpslot = g_ui.createWidget(template, panel)

		tmpslot:setId(toSlotId)
	end

	tmpslot:setVisible(visible)
	tmpslot:setImageSource(fromSlot:getImageSource())
	tmpslot:setImageClip(fromSlot:getImageClip())

	local tmpItem = fromSlot:getItem()

	if tmpItem then
		tmpslot:setItem(tmpItem)
	else
		tmpslot:setItem(nil)
	end

	tmpslot:setText(fromSlot:getText())

	tmpslot.autoSend = fromSlot.autoSend
	tmpslot.itemId = fromSlot.itemId
	tmpslot.subType = fromSlot.subType
	tmpslot.words = fromSlot.words
	tmpslot.text = fromSlot.text
	tmpslot.parameter = fromSlot.parameter
	tmpslot.useType = fromSlot.useType
	tmpslot.getTier = fromSlot.getTier
	tmpslot.passiveId = fromSlot.passiveId
	tmpslot.smartMode = fromSlot.smartMode
	tmpslot.smartBaseItemId = fromSlot.smartBaseItemId

	copySlotEquipmentPreset(fromSlot, tmpslot)

	if destAlreadyExisted then
		tmpslot.hotkeyChatOn = savedHotkeyOn
		tmpslot.hotkeyChatOff = savedHotkeyOff
	else
		tmpslot.hotkeyChatOn = fromSlot.hotkeyChatOn or ""
		tmpslot.hotkeyChatOff = fromSlot.hotkeyChatOff or ""
	end

	syncSlotHotkeyMirror(tmpslot)
	tmpslot:getChildById("text"):setText(fromSlot:getChildById("text"):getText())
	tmpslot:setTooltip(fromSlot:getTooltip())

	local toSpellIcon = tmpslot:getChildById("spellIcon")

	if toSpellIcon then
		toSpellIcon:hide()
		toSpellIcon:setImageSource("")
	end

	if tmpslot.words and tmpslot.words ~= "" and toSpellIcon then
		local spell, profile, spellName = Spells.getSpellByWords(tmpslot.words)

		if spellName and profile then
			local iconId = tonumber(Spells.getClientId(spellName))

			toSpellIcon:setImageSource(Spells.getIconFileByProfile(profile))
			toSpellIcon:setImageClip(Spells.getImageClip(iconId, profile))
			toSpellIcon:show()
		end
	elseif tmpslot.passiveId and toSpellIcon then
		local passiveData = PassiveAbilities[tmpslot.passiveId]

		if passiveData then
			toSpellIcon:setImageSource(passiveData.icon)
			toSpellIcon:setImageClip("0 0 32 32")
			toSpellIcon:show()
		end
	end

	copySlotMultiActions(fromSlot, tmpslot)

	if isActionSlotEquipmentPreset(tmpslot) then
		loadEquipmentSetDisplay(tmpslot)
	end

	applyActionSlotFrame(tmpslot)
	updateSlotGray(tmpslot)
	refreshActionSlotVirtueBorder(tmpslot)
	ItemsDatabase.setTier(tmpslot, tmpslot.getTier or 0)
end

function onDropFunc(slotId)
	if isActionBarLocked(getSlotBarId(slotId)) then
		return
	end

	if slotReassign then
		local fromSlotId = slotToEdit
		local toSlotId = slotId
		local fromSlot = findSlotById(fromSlotId)
		local toSlot = findSlotById(toSlotId)

		if fromSlot and toSlot then
			local tmpslotid = "slot" .. maxSlots + 1

			copySlot(fromSlotId, tmpslotid, false)
			copySlot(toSlotId, fromSlotId, true)
			copySlot(tmpslotid, toSlotId, true)

			local tmpWidget = findSlotById(tmpslotid)

			if tmpWidget and not tmpWidget:isDestroyed() then
				tmpWidget:destroy()
			else
				clearSlotById(tmpslotid)
			end

			updateSlotsVocation()

			if refreshMultiActionSlotCooldownDisplay then
				local refreshedFrom = findSlotById(fromSlotId)
				local refreshedTo = findSlotById(toSlotId)

				if refreshedFrom then
					clearSlotProgressWidgets(refreshedFrom)

					if slotHasMultiActions and slotHasMultiActions(refreshedFrom) and syncMultiActionSlot then
						syncMultiActionSlot(refreshedFrom)
					else
						refreshMultiActionSlotCooldownDisplay(refreshedFrom, false)
					end
				end

				if refreshedTo then
					clearSlotProgressWidgets(refreshedTo)

					if slotHasMultiActions and slotHasMultiActions(refreshedTo) and syncMultiActionSlot then
						syncMultiActionSlot(refreshedTo)
					else
						refreshMultiActionSlotCooldownDisplay(refreshedTo, false)
					end
				end
			end
		end

		slotReassign = nil
		slotToEdit = nil
	end

	slotToEdit = slotId

	if itemDragRetry and missedSlotToEdit then
		local widget1 = missedSlotToEdit[1]
		local mousePos1 = missedSlotToEdit[2]
		local item1 = missedSlotToEdit[3]

		if widget1 and mousePos1 and item1 then
			onChooseItemByDrag(widget1, mousePos1, item1)
		end

		itemDragRetry = nil
		missedSlotToEdit = nil
	end

	setupHotkeys()
end

function setupActionBar()
	for barId = 1, NUM_BARS do
		local panel = actionBarPanels[barId]

		if panel then
			ensureActionBarPanelSlots(barId, panel)
		end
	end
end

local function assignOrEditMenuLabel(assignLabel, editLabel, hasAssigned)
	return hasAssigned and editLabel or assignLabel
end

function createMenu(slotId)
	local menu = g_ui.createWidget("GamePopupMenu")

	menu:setWidth(195)

	slotToEdit = slotId

	local slotForMenu = findSlotById(slotId)
	local slotHasSpell = slotForMenu and slotForMenu.words and slotForMenu.words ~= ""
	local slotIsEquipPreset = slotForMenu and isActionSlotEquipmentPreset(slotForMenu)
	local slotHasObject = slotForMenu and not slotIsEquipPreset and slotForMenu.useType and slotForMenu.itemId and slotForMenu.itemId > 0
	local slotHasText = slotForMenu and slotForMenu.text and slotForMenu.text ~= ""
	local slotHasPassive = slotForMenu and slotForMenu.passiveId ~= nil
	local slotHasHotkey = slotForMenu and ((slotForMenu.hotkeyChatOn or "") ~= "" or (slotForMenu.hotkeyChatOff or "") ~= "")
	local slotHasMulti = slotForMenu and slotHasMultiActions and slotHasMultiActions(slotForMenu)
	local slotMultiPanelOpen = slotForMenu and slotForMenu._multiPanelOpen
	local spellMenuLabel = not slotHasMulti and assignOrEditMenuLabel("Assign Spell", "Edit Spell", slotHasSpell) or "Assign Spell"
	local objectMenuLabel = not slotHasMulti and assignOrEditMenuLabel("Assign Object", "Edit Object", slotHasObject) or "Assign Object"
	local textMenuLabel = not slotHasMulti and assignOrEditMenuLabel("Assign Text", "Edit Text", slotHasText) or "Assign Text"
	local passiveMenuLabel = not slotHasMulti and assignOrEditMenuLabel("Assign Passive Ability", "Edit Passive Ability", slotHasPassive) or "Assign Passive Ability"
	local hotkeyMenuLabel = assignOrEditMenuLabel(tr("Assign Hotkey"), tr("Edit Hotkey"), slotHasHotkey)

	menu:addOption(spellMenuLabel, function()
		openSpellAssignWindow()
	end)
	menu:addOption(objectMenuLabel, function()
		if slotHasMulti then
			startChooseItem()
			openObjectAssignWindow()
		elseif slotHasObject then
			local slot = findSlotById(slotToEdit)

			if slot and slot.itemId and slot.itemId > 0 then
				openObjectAssignWindow()

				local item = slot.subType and Item.create(slot.itemId, slot.subType) or Item.create(slot.itemId)

				populateObjectAssignWindowFromItem(item, slot.useType, actionSlotItemTier(slot), {
					smartMode = slot.smartMode,
					smartBaseItemId = slot.smartBaseItemId
				})
			else
				startChooseItem()
				openObjectAssignWindow()
			end
		else
			startChooseItem()
			openObjectAssignWindow()
		end
	end)
	menu:addOption(textMenuLabel, function()
		openTextAssignWindow()
	end)
	menu:addOption(passiveMenuLabel, function()
		assignPassive(slotId)
	end)

	local multiMenuLabel

	if slotMultiPanelOpen then
		multiMenuLabel = tr("Close Multi-Action")
	else
		multiMenuLabel = assignOrEditMenuLabel(tr("Assign Multi-Action"), tr("Edit Multi-Action"), slotHasMulti)
	end

	menu:addOption(multiMenuLabel, function()
		if slotMultiPanelOpen and closeCurrentMultiActionPanel then
			closeCurrentMultiActionPanel()
		elseif assignMultiAction then
			local targetSlot = findSlotById(slotId)

			if targetSlot and not slotHasMulti and (targetSlot.passiveId ~= nil or isActionSlotEquipmentPreset(targetSlot)) then
				clearSlotActionContent(targetSlot)
			end

			assignMultiAction(slotId)
		end
	end)

	local equipmentMenuLabel

	if slotHasMulti then
		equipmentMenuLabel = tr("Assign Equipments")
	else
		equipmentMenuLabel = assignOrEditMenuLabel(tr("Assign Equipments"), tr("Edit Equipments"), slotIsEquipPreset)
	end

	menu:addOption(equipmentMenuLabel, function()
		openEquipmentAssignWindow()
	end)
	menu:addOption(hotkeyMenuLabel, function()
		openEditHotkeyWindow()
	end)

	local actionSlot = findSlotById(slotToEdit)
	local slotHasEquipPreset = actionSlot and isActionSlotEquipmentPreset(actionSlot)

	if actionSlot and (actionSlot.itemId or actionSlot.words or actionSlot.text or actionSlot.useType or slotHasHotkey or actionSlot.passiveId or slotHasMulti or slotHasEquipPreset) then
		menu:addSeparator()
		menu:addOption("Clear Action", function()
			clearSlot()
			setupHotkeys()
			saveActionBar()
		end)
	end

	menu:display()
end

CastMode = {
	_radioUpdating = false,
	panelMargin = 6,
	panelHeight = 45,
	ids = {
		"castWithCrosshairRadio",
		"castAtCursorRadio",
		"castAtTargetRadio"
	},
	byRadio = {
		castAtCursorRadio = "cursor",
		castWithCrosshairRadio = "crosshair",
		castAtTargetRadio = "target"
	},
	toRadio = {
		cursor = "castAtCursorRadio",
		crosshair = "castWithCrosshairRadio",
		target = "castAtTargetRadio"
	},
	validModes = {
		cursor = true,
		crosshair = true,
		target = true
	}
}

local function normalizeCrossHairMode(mode)
	if type(mode) == "string" and CastMode.validModes[mode] then
		return mode
	end

	return "crosshair"
end

CrosshairCast = {}

function CastMode.getPanel()
	if not spellAssignWindow or spellAssignWindow:isDestroyed() then
		return nil
	end

	local panel = spellAssignWindow:getChildById("castModePanel")

	if not panel or panel:isDestroyed() then
		return nil
	end

	return panel
end

function CastMode.setSelection(mode)
	local panel = CastMode.getPanel()

	if not panel then
		return
	end

	local selectedRadioId = CastMode.toRadio[normalizeCrossHairMode(mode)] or CastMode.toRadio.crosshair

	CastMode._radioUpdating = true

	for _, radioId in ipairs(CastMode.ids) do
		local radio = panel:getChildById(radioId)

		if radio and not radio:isDestroyed() then
			radio:setChecked(radioId == selectedRadioId)
		end
	end

	CastMode._radioUpdating = false
end

function CastMode.getSelected()
	local panel = CastMode.getPanel()

	if not panel then
		return "crosshair"
	end

	for _, radioId in ipairs(CastMode.ids) do
		local radio = panel:getChildById(radioId)

		if radio and not radio:isDestroyed() and radio:isChecked() then
			return normalizeCrossHairMode(CastMode.byRadio[radioId])
		end
	end

	return "crosshair"
end

function CastMode.setVisible(visible)
	local panel = CastMode.getPanel()

	if not panel or not spellAssignWindow or spellAssignWindow:isDestroyed() then
		return
	end

	local spellsListFrame = spellAssignWindow:getChildById("spellsListFrame")

	if not spellsListFrame or spellsListFrame:isDestroyed() then
		return
	end

	local wasVisible = panel:isVisible()

	if visible == wasVisible then
		return
	end

	if CastMode._spellsListBaseHeight == nil then
		CastMode._spellsListBaseHeight = spellsListFrame:getHeight()
	end

	local delta = CastMode.panelHeight + CastMode.panelMargin

	if visible then
		panel:setHeight(CastMode.panelHeight)
		panel:setMarginTop(CastMode.panelMargin)
		panel:setVisible(true)
		spellsListFrame:setHeight(math.max(120, CastMode._spellsListBaseHeight - delta))
	else
		panel:setVisible(false)
		panel:setHeight(0)
		panel:setMarginTop(0)
		spellsListFrame:setHeight(CastMode._spellsListBaseHeight)
	end
end

function CastMode.setupRadios()
	local panel = CastMode.getPanel()

	if not panel then
		return
	end

	for _, radioId in ipairs(CastMode.ids) do
		local radio = panel:getChildById(radioId)

		if radio and not radio:isDestroyed() then
			function radio.onClick(widget)
				if CastMode._radioUpdating or not widget or widget:isDestroyed() then
					return
				end

				CastMode._radioUpdating = true

				for _, id in ipairs(CastMode.ids) do
					local other = panel:getChildById(id)

					if other and not other:isDestroyed() then
						other:setChecked(other == widget)
					end
				end

				CastMode._radioUpdating = false
			end
		end
	end
end

function openSpellAssignWindow()
	if spellAssignWindow and not spellAssignWindow:isDestroyed() then
		closeSpellAssignWindow()
	end

	local uiFile = externalAssignSlotId and "/game_helper/assign_helper" or "assign_spell"

	spellAssignWindow = g_ui.loadUI(uiFile, g_ui.getRootWidget())

	setSpellAssignWindowTitle()

	spellsPanel = spellAssignWindow:recursiveGetChildById("spellsPanel")
	CastMode._spellsListBaseHeight = nil
	CastMode._previewSpellKey = nil

	CastMode.setupRadios()
	CastMode.setSelection("crosshair")
	CastMode.setVisible(false)
	addEvent(function()
		initializeSpelllist()
	end)
	spellAssignWindow:raise()
	spellAssignWindow:focus()

	if not spellAssignFocusParameterOnOpen then
		spellAssignWindow:recursiveGetChildById("filterTextEdit"):focus()
	end

	spellAssignWindow.hotkeyBlock = HotkeyUtils.createHotkeyBlock("spell_assign_window")
end

function openSpellAssignWindowForDraggedSpell(slotId, words, multiIndex)
	if not slotId or not words or words == "" then
		return
	end

	local normalizedWords = words:lower():trim()
	local spell = Spells.getSpellByWords(normalizedWords)

	if not spell or not spell.parameter then
		return
	end

	slotToEdit = slotId
	multiActionEditIndex = multiIndex or nil
	spellAssignPreferredSpellOverride = Spells.getSpellNameByWords(normalizedWords)
	spellAssignFocusParameterOnOpen = true

	openSpellAssignWindow()
end

function closeSpellAssignWindow()
	spellAssignPreferredSpellOverride = nil
	spellAssignFocusParameterOnOpen = false
	multiActionEditIndex = nil

	clearExternalSpellAssignContext()

	CastMode._spellsListBaseHeight = nil
	CastMode._previewSpellKey = nil

	if spellAssignWindow and not spellAssignWindow:isDestroyed() then
		spellAssignWindow:destroy()
	end

	spellAssignWindow = nil
	spellsPanel = nil
end

local function getSpellAssignPreferredSpellName()
	if spellAssignPreferredSpellOverride then
		return spellAssignPreferredSpellOverride
	end

	local slot = slotToEdit and findSlotById(slotToEdit)

	if not slot or not slot.words or slot.words == "" then
		return nil
	end

	return Spells.getSpellNameByWords(slot.words:lower():trim())
end

local function syncSpellAssignParameterFieldFromSlot(focusedChild)
	if not spellAssignWindow or not focusedChild then
		return
	end

	local paramEdit = spellAssignWindow:getChildById("parameterTextEdit")

	if not paramEdit then
		return
	end

	local preferred = getSpellAssignPreferredSpellName()
	local slot = slotToEdit and findSlotById(slotToEdit)

	if preferred and focusedChild:getId() == preferred and slot then
		paramEdit:setText(slot.parameter or "")
	else
		paramEdit:setText("")
	end
end

local function pickSpellAssignListFocusWidget()
	if not spellsPanel then
		return nil
	end

	local preferredName = getSpellAssignPreferredSpellName()

	if preferredName then
		for _, child in ipairs(spellsPanel:getChildren()) do
			if child:getId() == preferredName and child:isVisible() then
				return child
			end
		end
	end

	for _, child in ipairs(spellsPanel:getChildren()) do
		if child:isVisible() then
			return child
		end
	end

	return nil
end

function initializeSpelllist()
	g_keyboard.bindKeyPress("Down", function()
		spellsPanel:focusNextChild(KeyboardFocusReason)
	end, spellAssignWindow)
	g_keyboard.bindKeyPress("Up", function()
		spellsPanel:focusPreviousChild(KeyboardFocusReason)
	end, spellAssignWindow)

	local vocId = 0
	local player = g_game.getLocalPlayer()

	if player then
		vocId = translateVocation(player:getVocation())
	end

	for spellProfile, _ in pairs(SpelllistSettings) do
		local sortedSpells = Spells.getSpellNamesSortedForVocation(vocId, spellProfile)

		for _, spell in ipairs(sortedSpells) do
			local info = SpellInfo[spellProfile][spell]

			if info and (not spellAssignListFilter or spellAssignListFilter(spell, info)) then
				local tmpLabel = g_ui.createWidget("SpellListLabel", spellsPanel)

				tmpLabel:setId(spell)
				tmpLabel:setPhantom(false)

				tmpLabel._filterWords = info.words:lower()
				tmpLabel._filterName = spell:lower()

				local spellNameWidget = tmpLabel:getChildById("spellName")
				local spellWordsWidget = tmpLabel:getChildById("spellWords")
				local spellLevelWidget = tmpLabel:getChildById("spellLevel")
				local spellIconWidget = tmpLabel:getChildById("spellIcon")

				spellNameWidget:setText(spell)
				spellWordsWidget:setText(info.words)

				if spellLevelWidget then
					spellLevelWidget:setText(tr("Level:") .. " " .. tostring(info.level or 0))
				end

				local iconId = SpellIcons[info.id]

				tmpLabel:setHeight(SpelllistSettings[spellProfile].iconSize.height + 2)

				tmpLabel.defaultHeight = tmpLabel:getHeight()

				spellIconWidget:setImageSource(SpelllistSettings[spellProfile].iconFile)

				local clip = iconId and Spells.getImageClip(iconId, spellProfile)

				if clip then
					spellIconWidget:setImageClip(clip)
				end

				spellIconWidget:setImageSize(tosize(SpelllistSettings[spellProfile].iconSize.width .. " " .. SpelllistSettings[spellProfile].iconSize.height))

				local groupIconWidget = tmpLabel:getChildById("groupCooldownIcon")

				if groupIconWidget then
					local gid = Spells.getPrimaryGroupId(info)
					local clip = gid and Spells.getSpellGroupIconClip(gid)

					if clip then
						groupIconWidget:setImageSource(SpellGroupIconFile)
						groupIconWidget:setImageClip(clip)
						groupIconWidget:setVisible(true)
					else
						groupIconWidget:setVisible(false)
					end
				end

				local spellIconGray = tmpLabel:getChildById("spellIconGray")

				if spellIconGray then
					spellIconGray:setVisible(not spellPassesAssignLearntFilter(info))
				end

				connect(tmpLabel, {
					onFocusChange = function(widget, focused)
						local c = focused and "#ffffff" or "#c0c0c0"

						widget:getChildById("spellName"):setColor(c)
						widget:getChildById("spellWords"):setColor(c)

						local lvl = widget:getChildById("spellLevel")

						if lvl then
							lvl:setColor(c)
						end
					end
				})
			end
		end
	end

	connect(spellsPanel, {
		onChildFocusChange = function(self, focusedChild)
			if focusedChild == nil then
				return
			end

			updatePreviewSpell(focusedChild)
			syncSpellAssignParameterFieldFromSlot(focusedChild)
		end
	})

	local learntCb = spellAssignWindow:recursiveGetChildById("onlyShowLearntSpellsCheckBox")

	if learntCb then
		connect(learntCb, {
			onCheckChange = function()
				local edit = spellAssignWindow:recursiveGetChildById("filterTextEdit")

				filterSpells(edit and edit:getText() or "")
			end
		})
	end

	filterSpells("")

	local toFocus = pickSpellAssignListFocusWidget()

	if toFocus then
		spellsPanel:focusChild(toFocus, KeyboardFocusReason)

		local sn = toFocus:getChildById("spellName")
		local sw = toFocus:getChildById("spellWords")
		local sl = toFocus:getChildById("spellLevel")

		if sn and sw then
			sn:setColor("#ffffff")
			sw:setColor("#ffffff")
		end

		if sl then
			sl:setColor("#ffffff")
		end
	end

	if spellAssignFocusParameterOnOpen then
		spellAssignFocusParameterOnOpen = false
		spellAssignPreferredSpellOverride = nil

		local paramEdit = spellAssignWindow:getChildById("parameterTextEdit")

		if paramEdit and paramEdit:isFocusable() and paramEdit:isEditable() then
			paramEdit:focus()
		else
			local filterEdit = spellAssignWindow:recursiveGetChildById("filterTextEdit")

			if filterEdit then
				filterEdit:focus()
			end
		end
	end
end

local function updateSpellAssignParameterField(spell)
	if not spellAssignWindow then
		return
	end

	local paramEdit = spellAssignWindow:getChildById("parameterTextEdit")

	if not paramEdit then
		return
	end

	local paramLabel = spellAssignWindow:getChildById("parameterLabel")
	local canEditParam = spell and spell.parameter
	local placeholder = ""

	if canEditParam then
		local ph = Spells.getParameterPlaceholder(spell)

		if ph then
			placeholder = "\"" .. ph .. "\""
		end
	end

	if paramEdit then
		paramEdit:setEditable(canEditParam)
		paramEdit:setFocusable(canEditParam)
		paramEdit:setCursorVisible(canEditParam)
		paramEdit:setPlaceholder(placeholder)
	end

	if paramLabel then
		paramLabel:setColor(canEditParam and "#c0c0c0" or "#707070")
	end

	local hasCrossHair = Spells.hasCrossHairTarget(spell)

	CastMode.setVisible(hasCrossHair)

	if hasCrossHair then
		local spellKey = spell and spell.name or nil

		if spellKey ~= CastMode._previewSpellKey then
			CastMode._previewSpellKey = spellKey

			local slot = slotToEdit and findSlotById(slotToEdit) or nil
			local savedMode = normalizeCrossHairMode(slot and slot.crossHairMode or "crosshair")

			CastMode.setSelection(savedMode)
		end
	else
		CastMode._previewSpellKey = nil

		CastMode.setSelection("crosshair")
	end
end

function spellAssignPreviewNoSpellSelected()
	if not spellAssignWindow then
		return
	end

	local previewPanel = spellAssignWindow:getChildById("spellPreview")

	if not previewPanel then
		return
	end

	local icon = previewPanel:getChildById("previewSpellIcon")

	if icon then
		icon:setVisible(false)
	end

	local nameLabel = previewPanel:getChildById("previewSpellName")
	local wordsLabel = previewPanel:getChildById("previewSpellWords")

	if nameLabel then
		nameLabel:setMarginLeft(-27)
		nameLabel:setText(tr("No spell selected"))
	end

	if wordsLabel then
		wordsLabel:setText("")
	end

	local previewGray = previewPanel:getChildById("previewSpellGray")

	if previewGray then
		previewGray:setVisible(false)
	end

	local previewItemBg = previewPanel:getChildById("previewItemBackground")

	if previewItemBg then
		previewItemBg:setVisible(false)
	end

	local previewItemIcon = previewPanel:getChildById("previewItemIcon")

	if previewItemIcon then
		previewItemIcon:setVisible(false)
	end

	updateSpellAssignParameterField(nil)
end

function updatePreviewSpell(focusedChild)
	local spellName = focusedChild:getId()
	local spell = Spells.getSpellByName(spellName)
	local profile = Spells.getSpellProfileByName(spellName)
	local iconId = spell and SpellIcons[spell.id] or tonumber(Spells.getClientId(spellName))
	local previewPanel = spellAssignWindow:getChildById("spellPreview")

	if previewPanel then
		local icon = previewPanel:getChildById("previewSpellIcon")

		if icon then
			icon:setVisible(true)

			if iconId and profile and SpelllistSettings[profile] then
				icon:setImageSource(SpelllistSettings[profile].iconFile)

				local clip = Spells.getImageClip(iconId, profile)

				if clip then
					icon:setImageClip(clip)
				end
			end
		end

		local nameLabel = previewPanel:getChildById("previewSpellName")

		if nameLabel then
			nameLabel:setMarginLeft(5)
			nameLabel:setText(spellName)
		end

		local previewWords = previewPanel:getChildById("previewSpellWords")

		if previewWords then
			previewWords:setText(spell and spell.words or "")
		end

		local previewGray = previewPanel:getChildById("previewSpellGray")

		if previewGray then
			previewGray:setVisible(spell ~= nil and not spellPassesAssignLearntFilter(spell))
		end

		local previewItemBg = previewPanel:getChildById("previewItemBackground")

		if previewItemBg then
			previewItemBg:setVisible(false)
		end

		local previewItemIcon = previewPanel:getChildById("previewItemIcon")

		if previewItemIcon then
			previewItemIcon:setVisible(false)
		end
	end

	updateSpellAssignParameterField(spell)
end

function spellAssignApply(closeAfter)
	local focusedChild = spellsPanel:getFocusedChild()

	if not focusedChild then
		return
	end

	local spellName = focusedChild:getId()
	local spell = Spells.getSpellByName(spellName)

	if not spell then
		return
	end

	local slot = findSlotById(slotToEdit)

	if not slot then
		return
	end

	if multiActionEditIndex then
		local param

		if spell.parameter then
			local paramEdit = spellAssignWindow:getChildById("parameterTextEdit")

			if paramEdit then
				param = paramEdit:getText():gsub("\"", "")
			end
		end

		commitMultiActionSubEntry(slot, multiActionEditIndex, {
			autoSend = true,
			words = spell.words,
			parameter = param
		})

		if closeAfter then
			multiActionEditIndex = nil
		end

		return
	end

	clearSlot()

	slot.words = spell.words
	slot.itemId = 469

	slot:setItemId(469)

	local paramEdit = spellAssignWindow and spellAssignWindow:getChildById("parameterTextEdit")

	if spell.parameter and paramEdit then
		slot.parameter = paramEdit:getText():gsub("\"", "")
	else
		slot.parameter = nil
	end

	if Spells.hasCrossHairTarget(spell) then
		slot.crossHairMode = normalizeCrossHairMode(CastMode.getSelected())
	else
		slot.crossHairMode = nil
	end

	loadSpell(slot)

	if externalAssignSlotId and slotToEdit == externalAssignSlotId then
		if onExternalSpellAssignApplied then
			onExternalSpellAssignApplied(slot)
		end

		return
	end
end

function spellAssignOk()
	spellAssignApply(true)
	closeSpellAssignWindow()
end

function resolveCyclopediaSpellAssignSlotAtMouse(mousePosition)
	local root = modules.game_interface.getRootPanel()
	local widget = root and root:recursiveGetChildByPos(mousePosition, false) or nil

	while widget do
		if widget._actionBarId and widget.getId then
			local slot = findSlotById(widget:getId())

			if slot == widget then
				return slot
			end
		end

		widget = widget:getParent()
	end

	return nil
end

function finishCyclopediaSpellSlotAssign()
	local returnWindow = cyclopediaSpellAssignReturnWindow

	cyclopediaSpellAssign = nil
	cyclopediaSpellAssignReturnWindow = nil

	if mouseGrabberWidget then
		mouseGrabberWidget:ungrabMouse()
	end

	g_mouse.popCursor("target")

	if returnWindow and modules.game_cyclopedia and modules.game_cyclopedia.toggle then
		modules.game_cyclopedia.toggle(returnWindow)
	end
end

function applyCyclopediaSpellToActionSlot(slot)
	local spell = cyclopediaSpellAssign

	finishCyclopediaSpellSlotAssign()

	if not slot or not spell then
		return false
	end

	slotToEdit = slot:getId()

	clearSlot()

	slot.words = spell.words
	slot.itemId = 469

	slot:setItemId(469)

	slot.parameter = nil

	loadSpell(slot)

	return true
end

function onCyclopediaSpellAssignMouseRelease(self, mousePosition, mouseButton)
	if mouseButton ~= MouseLeftButton then
		finishCyclopediaSpellSlotAssign()

		return true
	end

	local slot = resolveCyclopediaSpellAssignSlotAtMouse(mousePosition)

	if not slot then
		if modules.game_textmessage then
			modules.game_textmessage.displayFailureMessage(tr("Select an action bar slot."))
		end

		finishCyclopediaSpellSlotAssign()

		return true
	end

	applyCyclopediaSpellToActionSlot(slot)

	return true
end

function startCyclopediaSpellSlotAssign(spellName, spellWords, returnWindow)
	local spell

	if spellWords and spellWords ~= "" then
		spell = Spells.getSpellByWords(spellWords)
	end

	if not spell and spellName and spellName ~= "" then
		spell = Spells.getSpellByName(spellName)
	end

	if not spell or not mouseGrabberWidget then
		if modules.game_textmessage then
			modules.game_textmessage.displayFailureMessage(tr("This spell cannot be assigned to the action bar."))
		end

		return false
	end

	if cyclopediaSpellAssign then
		finishCyclopediaSpellSlotAssign()
	end

	cyclopediaSpellAssign = spell
	cyclopediaSpellAssignReturnWindow = returnWindow

	mouseGrabberWidget:grabMouse()
	g_mouse.pushCursor("target")

	return true
end

function clearSlot()
	local slot = findSlotById(slotToEdit)

	if not slot then
		return
	end

	if slotHasMultiActions and slotHasMultiActions(slot) and clearSlotMultiActions then
		clearSlotMultiActions(slot)
	end

	clearSlotActionContent(slot)
end

function clearSlotById(slotId)
	local slot = findSlotById(slotId)

	if not slot then
		return
	end

	clearSlotActionContent(slot)

	slot.hotkeyChatOn = ""
	slot.hotkeyChatOff = ""

	syncSlotHotkeyMirror(slot)
	refreshActionSlotInventoryQuantity(slot)
	applyActionSlotFrame(slot)
end

function clearHotkey()
	local slot = findSlotById(slotToEdit)

	if not slot then
		return
	end

	slot.hotkeyChatOn = ""
	slot.hotkeyChatOff = ""

	syncSlotHotkeyMirror(slot)
	setupHotkeys()
	saveActionBar()
end

function isEquipmentAssignBlockingItemMove()
	return equipmentAssignWindow ~= nil and not equipmentAssignWindow:isDestroyed()
end

function openEquipmentAssignWindow()
	if equipmentAssignWindow then
		closeEquipmentAssignWindow()
	end

	equipmentAssignWindow = g_ui.loadUI("assign_equipment", g_ui.getRootWidget())

	if equipmentAssignWindow then
		equipmentAssignWindow:breakAnchors()
		equipmentAssignWindow:centerIn("parent")
	end

	equipmentAssignWindow:raise()
	equipmentAssignWindow:focus()

	equipmentAssignWindow.hotkeyBlock = HotkeyUtils.createHotkeyBlock("equipment_assign_window")

	local actionSlot = findSlotById(slotToEdit)

	copyEquipmentAssignDraft(actionSlot and actionSlot.equipments or nil)
	copyEquipmentAssignMetaFromSlot(actionSlot)
	refreshAllEquipmentAssignSlots()
	setupEquipmentAssignSlotHandlers()
	refreshAssignActionSlotPreview()
	equipmentAssignUpdateButtons()
end

function openEquipmentAssignIconWindow()
	if not equipmentAssignWindow or equipmentAssignWindow:isDestroyed() then
		return
	end

	if equipmentAssignIconWindow then
		closeEquipmentAssignIconWindow(false)
	end

	equipmentAssignIconPickerRevertIndex = equipmentAssignIconIndex
	equipmentAssignIconPickerRevertDescription = equipmentAssignDescription
	equipmentAssignTypePickerRevertIndex = equipmentAssignTypeIndex

	equipmentAssignWindow:hide()

	equipmentAssignHiddenForIconPicker = true
	equipmentAssignIconWindow = g_ui.loadUI("assign_equipment_icon", g_ui.getRootWidget())

	if not equipmentAssignIconWindow then
		equipmentAssignHiddenForIconPicker = false

		equipmentAssignWindow:show()

		return
	end

	equipmentAssignIconWindow:raise()
	equipmentAssignIconWindow:focus()

	equipmentAssignIconWindow.hotkeyBlock = HotkeyUtils.createHotkeyBlock("equipment_assign_icon_window")

	local edit = equipmentAssignIconWindow:recursiveGetChildById("descriptionTextEdit")

	if edit then
		edit:setText(equipmentAssignDescription or "")
	end

	setupEquipmentAssignIconPicker()
	setupEquipmentAssignTypePicker()
end

function closeEquipmentAssignIconWindow(revert)
	if not equipmentAssignIconWindow then
		return
	end

	if revert then
		equipmentAssignIconIndex = equipmentAssignIconPickerRevertIndex
		equipmentAssignDescription = equipmentAssignIconPickerRevertDescription
		equipmentAssignTypeIndex = equipmentAssignTypePickerRevertIndex

		refreshAssignActionSlotPreview()
		equipmentAssignUpdateButtons()
	end

	destroyEquipmentAssignTypeRadioGroup()
	equipmentAssignIconWindow:destroy()

	equipmentAssignIconWindow = nil

	if equipmentAssignHiddenForIconPicker then
		equipmentAssignHiddenForIconPicker = false

		if equipmentAssignWindow and not equipmentAssignWindow:isDestroyed() then
			equipmentAssignWindow:show()
			equipmentAssignWindow:raise()
			equipmentAssignWindow:focus()
		end
	end
end

function equipmentAssignIconApply()
	if not equipmentAssignIconWindow then
		return
	end

	commitEquipmentAssignIconPicker()
end

function equipmentAssignIconOk()
	equipmentAssignIconApply()
	closeEquipmentAssignIconWindow(false)
end

function closeEquipmentAssignWindow()
	if not equipmentAssignWindow then
		return
	end

	closeEquipmentAssignIconWindow(false)

	if equipmentAssignPickInvSlot ~= nil then
		equipmentAssignPickInvSlot = nil

		if mouseGrabberWidget and not mouseGrabberWidget:isDestroyed() then
			mouseGrabberWidget:ungrabMouse()
		end

		g_mouse.popCursor("target")
	end

	equipmentAssignHiddenForPick = false
	equipmentAssignHiddenForIconPicker = false

	equipmentAssignWindow:destroy()

	equipmentAssignWindow = nil
	equipmentAssignDraft = nil
end

function equipmentAssignApply()
	applyEquipmentAssign(false)
end

function equipmentAssignOk()
	applyEquipmentAssign(true)
end

function applyEquipmentAssign(closeAfter)
	local slot = findSlotById(slotToEdit)

	if not slot then
		if closeAfter then
			closeEquipmentAssignWindow()
		end

		return
	end

	if not isEquipmentAssignIconDetermined() then
		return
	end

	if clearSlotMultiActions then
		clearSlotMultiActions(slot)
	end

	local icon = slot:getChildById("spellIcon")

	if icon then
		icon:hide()
		icon:setImageSource("")
	end

	slot.words = nil
	slot.grayManaCost = nil
	slot.text = nil
	slot.passiveId = nil
	slot.parameter = nil
	slot.equipments = {}

	for invSlot, entry in pairs(equipmentAssignDraft or {}) do
		if not isEquipmentAssignVisualBackpackSlot(invSlot) and entry and entry.itemId and entry.itemId > 0 then
			slot.equipments[invSlot] = {
				itemId = entry.itemId,
				getTier = entry.getTier,
				subType = entry.subType
			}
		end
	end

	slot.useType = "equip"

	local display = equipmentAssignDisplayEntry(equipmentAssignDraft)

	if display then
		slot.itemId = display.itemId
		slot.getTier = display.getTier
		slot.subType = display.subType
	else
		slot.itemId = 0
		slot.getTier = nil
		slot.subType = nil
	end

	slot.equipmentIconIndex = normalizeEquipmentIconIndex(equipmentAssignIconIndex)
	slot.equipmentDescription = equipmentAssignDescription or ""
	slot.equipmentTypeIndex = normalizeEquipmentTypeIndex(equipmentAssignTypeIndex)

	loadEquipmentSetDisplay(slot)
	setupHotkeys()
	saveActionBar()

	if closeAfter then
		closeEquipmentAssignWindow()
	end
end

function openTextAssignWindow()
	textAssignWindow = g_ui.loadUI("assign_text", g_ui.getRootWidget())

	local slot = findSlotById(slotToEdit)
	local textEdit = textAssignWindow:getChildById("textToSendTextEdit")
	local sendAutoBox = textAssignWindow:recursiveGetChildById("sendAutomaticallyCheckBox")

	if multiActionEditIndex and slot and slot.multiActions and slot.multiActions[multiActionEditIndex] then
		local data = slot.multiActions[multiActionEditIndex]

		if textEdit then
			textEdit:setText(data.text or data.words or "")
		end

		if sendAutoBox then
			sendAutoBox:setChecked(data.autoSend ~= false)
		end
	elseif slot and slot.text and slot.text ~= "" then
		if textEdit then
			textEdit:setText(slot.text)
		end

		if sendAutoBox then
			sendAutoBox:setChecked(slot.autoSend ~= false)
		end
	else
		if textEdit then
			textEdit:setText("")
		end

		if sendAutoBox then
			sendAutoBox:setChecked(true)
		end
	end

	setTextAssignWindowTitle()
	textAssignWindow:raise()
	textAssignWindow:focus()

	if textEdit then
		textEdit:focus()
		textEdit:setCursorPos(-1)
	end

	textAssignWindow.hotkeyBlock = HotkeyUtils.createHotkeyBlock("text_assign_window")

	if g_client.setInputLockWidget then
		g_client.setInputLockWidget(textAssignWindow)
	end

	textAssignUpdateButtons()
end

function textAssignUpdateButtons()
	if not textAssignWindow then
		return
	end

	local edit = textAssignWindow:getChildById("textToSendTextEdit")
	local okBtn = textAssignWindow:getChildById("okButton")
	local applyBtn = textAssignWindow:getChildById("applyButton")
	local hasText = edit and edit:getText():trim() ~= ""

	if okBtn then
		okBtn:setEnabled(hasText)
	end

	if applyBtn then
		applyBtn:setEnabled(hasText)
	end
end

function assignPassive(slotId)
	local window = g_ui.loadUI("assign_passive", g_ui.getRootWidget())

	g_client.setInputLockWidget(window)
	window:raise()
	scheduleEvent(function()
		window:focus()
	end, 50)

	do
		local slotForTitle = findSlotById(slotId)
		local isEditPassive = slotForTitle and slotForTitle.passiveId ~= nil
		local barId, slotIdx = slotBarAndIndexFromSlotId(slotId)

		if barId and slotIdx then
			local barNum = actionBarDisplayNumber(barId)

			if isEditPassive then
				window:setText(tr("Edit Passive to Action Button %d.%02d", barNum, slotIdx))
			else
				window:setText(tr("Assign Passive to Action Button %d.%02d", barNum, slotIdx))
			end
		else
			window:setText(tr(isEditPassive and "Edit Passive" or "Assign Passive"))
		end
	end

	local selectedPassiveId
	local passiveList = window.contentPanel.passiveList
	local passiveIds = {}

	for id in pairs(PassiveAbilities) do
		table.insert(passiveIds, id)
	end

	table.sort(passiveIds)

	local function applyPassiveAssignFocus(focusedChild)
		if not focusedChild then
			return
		end

		selectedPassiveId = tonumber(focusedChild:getId())

		for _, child in ipairs(passiveList:getChildren()) do
			if child.setChecked then
				child:setChecked(child == focusedChild)
			end
		end

		window.contentPanel.preview.previewLabel:setText(focusedChild:getText())
		window.contentPanel.preview.previewIcon:setImageSource(focusedChild.source)
		window.contentPanel.preview.previewIcon:setImageClip("0 0 32 32")
		passiveList:ensureChildVisible(focusedChild)
	end

	for _, id in ipairs(passiveIds) do
		local passiveData = PassiveAbilities[id]
		local widget = g_ui.createWidget("PassivePreview", passiveList)

		widget:setId(id)
		widget:setText(passiveData.name)
		widget.image:setImageSource(passiveData.icon)
		widget.image:setImageClip("0 0 32 32")

		widget.source = passiveData.icon
	end

	function passiveList:onChildFocusChange(focusedChild)
		applyPassiveAssignFocus(focusedChild)
	end

	local children = passiveList:getChildren()

	if children and #children > 0 then
		window.contentPanel.preview.previewLabel:setColor("$var-text-cip-color")
		scheduleEvent(function()
			if window:isDestroyed() then
				return
			end

			local first = passiveList:getChildren()[1]

			if first then
				applyPassiveAssignFocus(first)
				passiveList:focusChild(first, KeyboardFocusReason)
			end
		end, 1)
	end

	local function okFunc(destroy)
		if not selectedPassiveId then
			return
		end

		local passiveData = PassiveAbilities[selectedPassiveId]

		if not passiveData then
			return
		end

		clearSlot()

		local slot = findSlotById(slotToEdit)

		if not slot then
			return
		end

		slot.passiveId = selectedPassiveId
		slot.itemId = 469

		slot:setItemId(469)

		local icon = slot:getChildById("spellIcon")

		if icon then
			icon:setImageSource(passiveData.icon)
			icon:setImageClip("0 0 32 32")
			icon:show()
		end

		loadPassive(slot)

		if destroy then
			g_client.setInputLockWidget(nil)
			window:destroy()
		end
	end

	local function cancelFunc()
		g_client.setInputLockWidget(nil)
		window:destroy()
	end

	function window.contentPanel.buttonOk.onClick()
		okFunc(true)
	end

	function window.contentPanel.buttonApply.onClick()
		okFunc(false)
	end

	window.contentPanel.buttonClose.onClick = cancelFunc

	function window.onEnter()
		okFunc(true)
	end

	window.onEscape = cancelFunc
end

function closeTextAssignWindow()
	if textAssignWindow then
		if textAssignWindow.hotkeyBlock then
			textAssignWindow.hotkeyBlock.release()

			textAssignWindow.hotkeyBlock = nil
		end

		if g_client.setInputLockWidget then
			g_client.setInputLockWidget(nil)
		end

		textAssignWindow:destroy()
	end

	textAssignWindow = nil
end

function textAssignApply()
	applyTextAssign(false)
end

function textAssignOk()
	applyTextAssign(true)
end

function applyTextAssign(closeAfter)
	local text = textAssignWindow:getChildById("textToSendTextEdit"):getText()

	if text == "" then
		return
	end

	local autoSend = textAssignWindow:recursiveGetChildById("sendAutomaticallyCheckBox"):isChecked()

	if externalAssignSlotId and slotToEdit == externalAssignSlotId then
		if onExternalTextAssignApplied then
			onExternalTextAssignApplied(text, autoSend)
		end

		if closeAfter then
			closeTextAssignWindow()
		end

		return
	end

	local checkForParameter = text:split(" \"")
	local name, parameter

	if #checkForParameter == 2 then
		name = checkForParameter[1]
		parameter = checkForParameter[2]
	else
		name = text
	end

	local spell, profile, spellName = Spells.getSpellByWords(name)
	local slot = findSlotById(slotToEdit)

	if not slot then
		closeTextAssignWindow()

		return
	end

	if multiActionEditIndex then
		if spellName then
			commitMultiActionSubEntry(slot, multiActionEditIndex, {
				words = spell.words,
				parameter = parameter and spell.parameter and parameter or nil,
				autoSend = textAssignWindow:recursiveGetChildById("sendAutomaticallyCheckBox"):isChecked()
			})
		else
			commitMultiActionSubEntry(slot, multiActionEditIndex, {
				text = text,
				autoSend = textAssignWindow:recursiveGetChildById("sendAutomaticallyCheckBox"):isChecked()
			})
		end

		if closeAfter then
			multiActionEditIndex = nil

			closeTextAssignWindow()
		end

		return
	end

	if spellName then
		clearSlot()

		slot.words = spell.words
		slot.itemId = 469

		slot:setItemId(469)

		if parameter and spell.parameter then
			slot.parameter = parameter
		else
			slot.parameter = nil
		end

		loadSpell(slot)
	else
		clearSlot()
		slot:getChildById("text"):setText(text)

		while slot:getChildById("text"):getTextSize().height > 30 do
			local subString = slot:getChildById("text"):getText()

			subString = string.sub(subString, 1, #subString - 1)

			slot:getChildById("text"):setText(subString)
		end

		slot.text = text
		slot.itemId = 469

		slot:setItemId(469)

		slot.autoSend = textAssignWindow:recursiveGetChildById("sendAutomaticallyCheckBox"):isChecked()

		loadText(slot)
	end

	if closeAfter then
		closeTextAssignWindow()
	end
end

function openObjectAssignWindow()
	if objectAssignWindow ~= nil then
		objectAssignWindow:destroy()
	end

	objectAssignWindow = g_ui.loadUI("assign_object", g_ui.getRootWidget())
	actionRadioGroup = UIRadioGroup.create()

	actionRadioGroup:addWidget(objectAssignWindow:getChildById("useOnYourselfCheckbox"))
	actionRadioGroup:addWidget(objectAssignWindow:getChildById("useOnTargetCheckbox"))
	actionRadioGroup:addWidget(objectAssignWindow:getChildById("useWithCrosshairCheckbox"))
	actionRadioGroup:addWidget(objectAssignWindow:getChildById("useCursorPositionCheckbox"))
	actionRadioGroup:addWidget(objectAssignWindow:getChildById("equipCheckbox"))
	actionRadioGroup:addWidget(objectAssignWindow:getChildById("useCheckbox"))

	function actionRadioGroup.onSelectionChange()
		if not objectAssignWindow then
			return
		end

		local previewItem = objectAssignWindow:recursiveGetChildById("previewItem")
		local item = previewItem and previewItem:getItem()

		if item then
			updateSmartModeAssignCheckboxState(item, objectAssignWindow._smartModeAssignContext)
		end
	end

	objectAssignWindow:setVisible(false)
	setObjectAssignWindowTitle()
end

function closeObjectAssignWindow()
	objectAssignHiddenForPick = false

	if objectAssignWindow and not objectAssignWindow:isDestroyed() then
		objectAssignWindow:destroy()
	end

	objectAssignWindow = nil
	actionRadioGroup = nil
end

local ASSIGN_OBJECT_CB_ENABLED = "#c0c0c0"
local ASSIGN_OBJECT_CB_DISABLED = "#707070"

local function itemHasDurationDecay(item)
	if not item then
		return false
	end

	return item:hasClockExpire() or item:hasExpire() or item:hasExpireStop()
end

local function itemIdHasDurationDecay(itemId)
	if not itemId or itemId <= 0 then
		return false
	end

	local tt = g_things.getThingType(itemId, ThingCategoryItem)

	if not tt then
		return false
	end

	return tt:hasClockExpire() or tt:hasExpire() or tt:hasExpireStop()
end

local function getClothSlotForItemId(itemId)
	if not itemId or itemId <= 0 then
		return 0
	end

	local item = Item.create(itemId)

	return item and item:getClothSlot() or 0
end

local function smartModeItemMatchesBase(baseId, itemId)
	if not baseId or not itemId or baseId <= 0 or itemId <= 0 then
		return false
	end

	if baseId == itemId then
		return true
	end

	local baseTT = g_things.getThingType(baseId, ThingCategoryItem)
	local itemTT = g_things.getThingType(itemId, ThingCategoryItem)

	if not baseTT or not itemTT then
		return false
	end

	local baseName = baseTT:getName()

	if baseName and baseName ~= "" and baseName == itemTT:getName() then
		return true
	end

	local baseMd = baseTT.getMarketData and baseTT:getMarketData()
	local itemMd = itemTT.getMarketData and itemTT:getMarketData()

	return baseMd and itemMd and baseMd.name and baseMd.name ~= "" and baseMd.name == itemMd.name
end

function getActionBarInventoryDisplayCount(itemId, tier, player)
	player = player or g_game.getLocalPlayer()

	if not player or not itemId or itemId <= 0 then
		return 0
	end

	tier = tier or 0

	local count = player:getInventoryCount(itemId, tier)
	local equipped = player:getInventoryItem(InventorySlotFinger)

	if not equipped or equipped:getId() == itemId then
		return count
	end

	local itemType = g_things.getThingType(itemId, ThingCategoryItem)

	if not itemType then
		return count
	end

	local marketData = itemType.getMarketData and itemType:getMarketData()
	local isRing = itemType:getClothSlot() == InventorySlotFinger or MarketCategory and marketData and marketData.category == MarketCategory.Rings

	if not isRing or not smartModeItemMatchesBase(itemId, equipped:getId()) then
		return count
	end

	if g_game.getFeature(GameThingUpgradeClassification) then
		local equippedTier = equipped.getTier and equipped:getTier() or 0

		if equippedTier ~= tier then
			return count
		end
	end

	return count + 1
end

local function smartModeItemMatchesEntry(entry, itemId)
	local baseId = entry.smartBaseItemId or entry.itemId

	if smartModeItemMatchesBase(baseId, itemId) then
		return true
	end

	if entry.itemId and entry.itemId ~= baseId then
		return smartModeItemMatchesBase(entry.itemId, itemId)
	end

	return false
end

function updateSmartModeAssignLayout(smartVisible)
	if not objectAssignWindow then
		return
	end

	local useCb = objectAssignWindow:getChildById("useCheckbox")
	local equipCb = objectAssignWindow:getChildById("equipCheckbox")
	local smartCb = objectAssignWindow:getChildById("smartModeCheckbox")

	if not useCb or not equipCb then
		return
	end

	useCb:breakAnchors()
	useCb:addAnchor(AnchorLeft, equipCb:getId(), AnchorLeft)
	useCb:setMarginTop(6)

	if smartVisible and smartCb and smartCb:isVisible() then
		useCb:addAnchor(AnchorTop, smartCb:getId(), AnchorBottom)
	else
		useCb:addAnchor(AnchorTop, equipCb:getId(), AnchorBottom)
	end

	objectAssignWindow:updateLayout()
end

function updateSmartModeAssignCheckboxState(item, assignContext)
	if not objectAssignWindow or not item then
		return
	end

	local smartCb = objectAssignWindow:getChildById("smartModeCheckbox")
	local equipCb = objectAssignWindow:getChildById("equipCheckbox")

	if not smartCb or not equipCb then
		return
	end

	local baseItemId = assignContext and type(assignContext.smartBaseItemId) == "number" and assignContext.smartBaseItemId or item:getId()
	local showSmart = isEquippableActionBarItem(item) and itemIdHasDurationDecay(baseItemId)

	smartCb:setVisible(showSmart)

	if not showSmart then
		smartCb:setChecked(false)
		smartCb:setEnabled(false)
		updateSmartModeAssignLayout(false)

		return
	end

	local equipSelected = equipCb:isChecked()

	smartCb:setEnabled(equipSelected)
	smartCb:setColor(equipSelected and ASSIGN_OBJECT_CB_ENABLED or ASSIGN_OBJECT_CB_DISABLED)

	if assignContext and assignContext.smartMode == true then
		smartCb:setChecked(true)
	elseif assignContext and assignContext.smartMode == false then
		smartCb:setChecked(false)
	end

	updateSmartModeAssignLayout(true)
end

local function readSmartModeFromAssignWindow(item, useType, assignContext)
	if useType ~= "equip" or not item then
		return false, nil
	end

	local baseItemId = assignContext and type(assignContext.smartBaseItemId) == "number" and assignContext.smartBaseItemId or item:getId()

	if not itemIdHasDurationDecay(baseItemId) then
		return false, nil
	end

	local smartCb = objectAssignWindow and objectAssignWindow:getChildById("smartModeCheckbox")

	if not smartCb or not smartCb:isVisible() or not smartCb:isChecked() then
		return false, nil
	end

	return true, baseItemId
end

local function refreshSmartModeEntry(entry, player)
	if not entry or not player or not entry.smartMode or entry.useType ~= "equip" then
		return false
	end

	if not entry.itemId or entry.itemId <= 0 then
		return false
	end

	local baseId = entry.smartBaseItemId or entry.itemId
	local clothSlot = getClothSlotForItemId(baseId)

	if not clothSlot or clothSlot <= 0 then
		return false
	end

	local equipped = player:getInventoryItem(clothSlot)
	local changed = false

	if equipped then
		local eqId = equipped:getId()

		if smartModeItemMatchesEntry(entry, eqId) then
			if eqId ~= entry.itemId then
				if not entry.smartBaseItemId then
					entry.smartBaseItemId = baseId
				end

				entry.itemId = eqId
				changed = true
			end
		elseif entry.itemId ~= baseId then
			entry.itemId = baseId
			changed = true
		end

		entry._smartEquipPending = nil
	elseif entry.smartBaseItemId and entry.itemId ~= entry.smartBaseItemId then
		entry.itemId = entry.smartBaseItemId
		changed = true
		entry._smartEquipPending = nil
	end

	return changed
end

local function refreshSmartModeSlot(slot)
	if not slot then
		return false
	end

	local player = g_game.getLocalPlayer()

	if not player then
		return false
	end

	if isActionSlotEquipmentPreset(slot) then
		return false
	end

	local changed = false

	if slotHasMultiActions and slotHasMultiActions(slot) and slot.multiActions then
		for i = 1, 3 do
			local entry = slot.multiActions[i]

			if entry and refreshSmartModeEntry(entry, player) then
				changed = true
			end
		end

		if changed and syncMultiActionSlot then
			syncMultiActionSlot(slot)
		end
	elseif slot.smartMode and refreshSmartModeEntry(slot, player) then
		loadObject(slot)
		applyActionSlotFrame(slot)

		changed = true
	end

	return changed
end

function refreshAllSmartModeSlots()
	local player = g_game.getLocalPlayer()

	if not player then
		return
	end

	local anyChanged = false

	for barId = 1, NUM_BARS do
		local panel = actionBarPanels[barId]

		if panel then
			for _, slot in pairs(panel:getChildren()) do
				if refreshSmartModeSlot(slot) then
					anyChanged = true
				end
			end
		end
	end

	if anyChanged then
		saveActionBar()
	end
end

local function styleAssignObjectCheckbox(id, enabled)
	local cb = objectAssignWindow:getChildById(id)

	if not cb then
		return
	end

	cb:setEnabled(enabled)
	cb:setColor(enabled and ASSIGN_OBJECT_CB_ENABLED or ASSIGN_OBJECT_CB_DISABLED)
end

function isEquippableActionBarItem(item)
	if not item then
		return false
	end

	local clothSlot = item:getClothSlot()

	if clothSlot == InventorySlotBack then
		return false
	end

	if clothSlot > 0 then
		return true
	end

	local md = item.getMarketData and item:getMarketData()

	if md and md.category then
		local cat = md.category

		if MarketCategoryWeapons and MarketCategoryWeapons[cat] then
			return true
		end

		if MarketCategory and (cat == MarketCategory.FistWeapons or cat == MarketCategory.Quivers or cat == MarketCategory.Shields) then
			return true
		end
	end

	local thingType = g_things.getThingType(item:getId(), ThingCategoryItem)

	if thingType and thingType.isCloth and thingType:isCloth() then
		return true
	end

	return false
end

function isValidActionBarObjectItem(item, fromMap)
	if not item or not item.getId then
		return false
	end

	local itemId = item:getId()

	if not itemId or itemId <= 0 then
		return false
	end

	local thingType = g_things.getThingType(itemId, ThingCategoryItem)

	if not thingType then
		return false
	end

	if thingType.isGround and thingType:isGround() then
		return false
	end

	if thingType.isGroundBorder and thingType:isGroundBorder() then
		return false
	end

	if thingType.isFullGround and thingType:isFullGround() then
		return false
	end

	if not thingType.isPickupable or not thingType:isPickupable() then
		return false
	end

	if not fromMap then
		return true
	end

	if isEquippableActionBarItem(item) then
		return true
	end

	if thingType.isUsable and thingType:isUsable() then
		return true
	end

	if thingType.isMultiUse and thingType:isMultiUse() then
		return true
	end

	if thingType.isContainer and thingType:isContainer() then
		return true
	end

	if thingType.isMarketable and thingType:isMarketable() then
		return true
	end

	return false
end

function populateObjectAssignWindowFromItem(item, preferredUseType, tierOverride, assignContext)
	if not objectAssignWindow or not item then
		return
	end

	objectAssignWindow._smartModeAssignContext = assignContext

	setObjectAssignWindowTitle()

	local preview = objectAssignWindow:recursiveGetChildById("previewItem")

	preview:setItemId(item:getId())

	local tier = tierOverride ~= nil and tierOverride or item:getTier()

	ItemsDatabase.setTier(preview, 0)
	ItemsDatabase.setBigTier(preview, tier)

	preview.auxTier = tier

	preview:setItemCount(1)

	local defaultWidget
	local equippable = isEquippableActionBarItem(item)
	local multiUse = item:isMultiUse()

	if equippable and multiUse then
		styleAssignObjectCheckbox("useOnYourselfCheckbox", true)
		styleAssignObjectCheckbox("useOnTargetCheckbox", true)
		styleAssignObjectCheckbox("useWithCrosshairCheckbox", true)
		styleAssignObjectCheckbox("useCursorPositionCheckbox", true)
		styleAssignObjectCheckbox("equipCheckbox", true)
		styleAssignObjectCheckbox("useCheckbox", false)

		defaultWidget = objectAssignWindow:getChildById("equipCheckbox")
	elseif equippable then
		styleAssignObjectCheckbox("equipCheckbox", true)
		styleAssignObjectCheckbox("useCheckbox", true)
		styleAssignObjectCheckbox("useOnYourselfCheckbox", false)
		styleAssignObjectCheckbox("useOnTargetCheckbox", false)
		styleAssignObjectCheckbox("useWithCrosshairCheckbox", false)
		styleAssignObjectCheckbox("useCursorPositionCheckbox", false)

		defaultWidget = objectAssignWindow:getChildById("equipCheckbox")
	elseif multiUse then
		styleAssignObjectCheckbox("useOnYourselfCheckbox", true)
		styleAssignObjectCheckbox("useOnTargetCheckbox", true)
		styleAssignObjectCheckbox("useWithCrosshairCheckbox", true)
		styleAssignObjectCheckbox("useCursorPositionCheckbox", true)
		styleAssignObjectCheckbox("equipCheckbox", false)
		styleAssignObjectCheckbox("useCheckbox", false)

		defaultWidget = objectAssignWindow:getChildById("useOnYourselfCheckbox")
	else
		styleAssignObjectCheckbox("useCheckbox", true)
		styleAssignObjectCheckbox("equipCheckbox", false)
		styleAssignObjectCheckbox("useOnYourselfCheckbox", false)
		styleAssignObjectCheckbox("useOnTargetCheckbox", false)
		styleAssignObjectCheckbox("useWithCrosshairCheckbox", false)
		styleAssignObjectCheckbox("useCursorPositionCheckbox", false)

		defaultWidget = objectAssignWindow:getChildById("useCheckbox")
	end

	local preferredMap = {
		useAtCursor = "useCursorPositionCheckbox",
		useOnTarget = "useOnTargetCheckbox",
		equip = "equipCheckbox",
		useOnSelf = "useOnYourselfCheckbox",
		use = "useCheckbox",
		useWith = "useWithCrosshairCheckbox"
	}
	local chosen = defaultWidget

	if preferredUseType then
		local prefId = preferredMap[preferredUseType]

		if prefId then
			local prefW = objectAssignWindow:getChildById(prefId)

			if prefW and prefW:isEnabled() then
				chosen = prefW
			end
		end
	end

	if chosen then
		actionRadioGroup:selectWidget(chosen)
	end

	updateSmartModeAssignCheckboxState(item, assignContext)

	if not objectAssignWindow:isVisible() then
		objectAssignWindow:show()
	end

	local smartCb = objectAssignWindow:getChildById("smartModeCheckbox")

	updateSmartModeAssignLayout(smartCb and smartCb:isVisible())
	objectAssignWindow:raise()
	objectAssignWindow:focus()
end

function findGameMapWidgetAtClick(clickedWidget)
	if not clickedWidget then
		return nil
	end

	if clickedWidget:getClassName() == "UIGameMap" then
		return clickedWidget
	end

	local w = clickedWidget

	while w do
		if w:getClassName() == "UIGameMap" then
			return w
		end

		w = w:getParent()
	end

	return nil
end

function resolvePickItemAtMouse(mousePosition)
	local root = modules.game_interface.getRootPanel()

	if not root then
		return nil
	end

	local clickedWidget = root:recursiveGetChildByPos(mousePosition, false)

	if not clickedWidget then
		return nil
	end

	if clickedWidget:getClassName() == "UIItem" and not clickedWidget:isVirtual() then
		local invItem = clickedWidget:getItem()

		if isValidActionBarObjectItem(invItem, false) then
			return invItem
		end

		return nil
	end

	local mapWidget = findGameMapWidgetAtClick(clickedWidget)

	if mapWidget and mapWidget.getTile then
		local tile = mapWidget:getTile(mousePosition)

		if tile then
			local thing = tile:getTopMoveThing()

			if thing and thing.isItem and thing:isItem() and isValidActionBarObjectItem(thing, true) then
				return thing
			end
		end
	end

	return nil
end

local function restoreObjectAssignWindowAfterPick()
	if not objectAssignHiddenForPick then
		return
	end

	objectAssignHiddenForPick = false

	if objectAssignWindow and not objectAssignWindow:isDestroyed() then
		objectAssignWindow:show()

		local smartCb = objectAssignWindow:getChildById("smartModeCheckbox")

		updateSmartModeAssignLayout(smartCb and smartCb:isVisible())
		objectAssignWindow:raise()
		objectAssignWindow:focus()
	end
end

function startChooseItem()
	if g_ui.isMouseGrabbed() then
		return
	end

	if objectAssignWindow and not objectAssignWindow:isDestroyed() and objectAssignWindow:isVisible() then
		objectAssignWindow:hide()

		objectAssignHiddenForPick = true
	end

	mouseGrabberWidget:grabMouse()
	g_mouse.pushCursor("target")
end

local function applyObjectAssign(closeAfter)
	local item = objectAssignWindow:recursiveGetChildById("previewItem"):getItem()

	if not item then
		return
	end

	local slot = findSlotById(slotToEdit)

	if not slot then
		closeObjectAssignWindow()

		return
	end

	local useType = "use"

	if objectAssignWindow:getChildById("equipCheckbox"):isChecked() then
		useType = "equip"
	elseif objectAssignWindow:getChildById("useCheckbox"):isChecked() then
		useType = "use"
	elseif objectAssignWindow:getChildById("useOnYourselfCheckbox"):isChecked() then
		useType = "useOnSelf"
	elseif objectAssignWindow:getChildById("useOnTargetCheckbox"):isChecked() then
		useType = "useOnTarget"
	elseif objectAssignWindow:getChildById("useWithCrosshairCheckbox"):isChecked() then
		useType = "useWith"
	elseif objectAssignWindow:getChildById("useCursorPositionCheckbox"):isChecked() then
		useType = "useAtCursor"
	end

	local smartMode, smartBaseItemId = readSmartModeFromAssignWindow(item, useType, objectAssignWindow and objectAssignWindow._smartModeAssignContext)

	if externalAssignSlotId and slotToEdit == externalAssignSlotId then
		slot.itemId = item:getId()
		slot.useType = useType
		slot.getTier = objectAssignWindow:recursiveGetChildById("previewItem").auxTier

		if item:isFluidContainer() then
			slot.subType = item:getSubType()
		else
			slot.subType = nil
		end

		if onExternalObjectAssignApplied then
			onExternalObjectAssignApplied(slot)
		end

		if closeAfter then
			closeObjectAssignWindow()
		end

		return
	end

	if multiActionEditIndex then
		local subType

		if item:isFluidContainer() then
			subType = item:getSubType()
		end

		commitMultiActionSubEntry(slot, multiActionEditIndex, {
			itemId = item:getId(),
			subType = subType,
			useType = useType,
			getTier = objectAssignWindow:recursiveGetChildById("previewItem").auxTier,
			smartMode = smartMode and true or nil,
			smartBaseItemId = smartBaseItemId
		})
		refreshSmartModeSlot(slot)

		if closeAfter then
			multiActionEditIndex = nil

			closeObjectAssignWindow()
		end

		return
	end

	clearSlot()
	slot:setItem(item)
	slot:setBorderWidth(0)

	slot.itemId = item:getId()
	slot.getTier = objectAssignWindow:recursiveGetChildById("previewItem").auxTier

	ItemsDatabase.setTier(slot, slot.getTier)

	if item:isFluidContainer() then
		slot.subType = item:getSubType()
	end

	slot.useType = useType
	slot.smartMode = smartMode and true or nil
	slot.smartBaseItemId = smartBaseItemId

	updateSlotGray(slot)
	refreshActionSlotInventoryQuantity(slot)
	applyActionSlotFrame(slot)
	refreshSmartModeSlot(slot)
	setupHotkeys()

	if closeAfter then
		closeObjectAssignWindow()
	end
end

function objectAssignApply()
	applyObjectAssign(false)
end

function objectAssignOk()
	applyObjectAssign(true)
end

function objectAssignAccept()
	objectAssignOk()
end

function onChooseItemMouseRelease(self, mousePosition, mouseButton)
	if CrosshairCast.isActive() then
		return onSpellCrosshairMouseRelease(self, mousePosition, mouseButton)
	end

	if cyclopediaSpellAssign then
		return onCyclopediaSpellAssignMouseRelease(self, mousePosition, mouseButton)
	end

	if equipmentAssignPickInvSlot ~= nil then
		return onEquipmentAssignChooseItemMouseRelease(self, mousePosition, mouseButton)
	end

	local item
	local hadMapClick = false

	if mouseButton == MouseLeftButton then
		local root = modules.game_interface.getRootPanel()
		local clickedWidget = root and root:recursiveGetChildByPos(mousePosition, false)

		if clickedWidget and findGameMapWidgetAtClick(clickedWidget) then
			hadMapClick = true
		end

		item = resolvePickItemAtMouse(mousePosition)

		if hadMapClick and not item and objectAssignHiddenForPick then
			modules.game_textmessage.displayFailureMessage(tr("Sorry, not possible."))
		end
	end

	if item and (slotToEdit or objectAssignHiddenForPick) then
		objectAssignHiddenForPick = false

		populateObjectAssignWindowFromItem(item)
	else
		restoreObjectAssignWindowAfterPick()
	end

	g_mouse.popCursor("target")
	self:ungrabMouse()

	return true
end

function onChooseItemByDrag(self, mousePosition, item)
	if slotToEdit and isActionBarLocked(getSlotBarId(slotToEdit)) then
		return
	end

	if item and slotToEdit then
		openObjectAssignWindow()
		populateObjectAssignWindowFromItem(item)
	elseif not slotToEdit then
		itemDragRetry = true
		missedSlotToEdit = {
			self,
			mousePosition,
			item
		}
	end
end

function onDragReassign(self, item)
	slotReassign = self
end

function openEditHotkeyWindow()
	local rootW = g_ui.getRootWidget()

	editHotkeyOverlay = g_ui.createWidget("UIWidget", rootW)

	editHotkeyOverlay:setId("editHotkeyCaptureOverlay")
	editHotkeyOverlay:setFocusable(true)
	editHotkeyOverlay:setDraggable(false)
	editHotkeyOverlay:addAnchor(AnchorLeft, "parent", AnchorLeft)
	editHotkeyOverlay:addAnchor(AnchorRight, "parent", AnchorRight)
	editHotkeyOverlay:addAnchor(AnchorTop, "parent", AnchorTop)
	editHotkeyOverlay:addAnchor(AnchorBottom, "parent", AnchorBottom)

	editHotkeyWindow = g_ui.loadUI("assign_hotkey", editHotkeyOverlay)

	editHotkeyWindow:breakAnchors()
	editHotkeyWindow:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
	editHotkeyWindow:addAnchor(AnchorVerticalCenter, "parent", AnchorVerticalCenter)

	local chatModeLabel = editHotkeyWindow:recursiveGetChildById("chatMode")

	if chatModeLabel and modules.game_console and modules.game_console.isChatEnabled then
		local chatOn = modules.game_console.isChatEnabled()

		chatModeLabel:setText(chatOn and tr("Mode: \"Chat On\"") or tr("Mode: \"Chat Off\""))
	end

	local instrLabel = editHotkeyWindow:recursiveGetChildById("hotkeyInstructionLabel")
	local barId, slotIdx = slotBarAndIndexFromSlotId(slotToEdit)

	if barId and slotIdx then
		local region = actionBarRegionTitle(barId)
		local barNum = actionBarDisplayNumber(barId)

		editHotkeyWindow:setText(tr("Edit Hotkey for \"%s: Action Button %d.%d\"", region, barNum, slotIdx))

		if instrLabel then
			instrLabel:setText(tr("Click \"Ok\" to assign the hotkey. Click \"Clear\" to remove the hotkey from \"%s: Action Button %d.%d\".", region, barNum, slotIdx))
		end
	else
		editHotkeyWindow:setText(tr("Edit Hotkey"))

		if instrLabel then
			instrLabel:setText(tr("Click \"Ok\" to assign the hotkey. Click \"Clear\" to remove the hotkey."))
		end
	end

	local slotBeingEdited = findSlotById(slotToEdit)
	local existingCombo = ""

	if slotBeingEdited then
		existingCombo = getSlotHotkeyForChatMode(slotBeingEdited)
	end

	editHotkeyPendingCombo = existingCombo

	local comboLabel = editHotkeyWindow:recursiveGetChildById("comboPreview")

	if comboLabel then
		comboLabel:setText(tr("%s", existingCombo))
		comboLabel:resizeToText()
	end

	local errPreview = editHotkeyWindow:recursiveGetChildById("errorLabel")

	ActionBarHotkeyLogic.updateHotkeyCaptureUI(editHotkeyWindow, existingCombo, slotToEdit)
	editHotkeyOverlay:grabMouse()
	editHotkeyWindow:grabKeyboard()

	editHotkeyWindow.onKeyDown = hotkeyCapture

	function editHotkeyOverlay.onMousePress(_, mousePos, mouseButton)
		return hotkeyCaptureMousePress(editHotkeyWindow, mousePos, mouseButton)
	end

	function editHotkeyOverlay.onMouseWheel(_, mousePos, direction)
		return hotkeyCaptureMouseWheel(editHotkeyWindow, mousePos, direction)
	end

	function editHotkeyWindow.onMousePress(_, mousePos, mouseButton)
		return hotkeyCaptureMousePress(editHotkeyWindow, mousePos, mouseButton)
	end

	function editHotkeyWindow.onMouseWheel(_, mousePos, direction)
		return hotkeyCaptureMouseWheel(editHotkeyWindow, mousePos, direction)
	end

	editHotkeyOverlay:raise()
	editHotkeyWindow:raise()
	editHotkeyWindow:focus()

	editHotkeyWindow.hotkeyBlock = HotkeyUtils.createHotkeyBlock("edit_hotkey_window")
end

function closeEditHotkeyWindow()
	if editHotkeyOverlay then
		editHotkeyOverlay:ungrabMouse()
		editHotkeyOverlay:destroy()
	end

	editHotkeyOverlay = nil
	editHotkeyWindow = nil
	editHotkeyPendingCombo = ""
end

function unbindHotkeys()
	for i = 1, NUM_BARS do
		local panel = actionBarPanels[i]

		if panel then
			for _, slot in pairs(panel:getChildren()) do
				local a = slot.hotkeyChatOn
				local b = slot.hotkeyChatOff

				if a == nil or a == "" then
					a = ""
				elseif type(a) ~= "string" then
					a = tostring(a)
				end

				if b == nil or b == "" then
					b = ""
				elseif type(b) ~= "string" then
					b = tostring(b)
				end

				if a ~= "" then
					g_mouse.unbindComboHotkeyPress(a, modules.game_interface and modules.game_interface.getRootPanel())
				end

				if b ~= "" and b ~= a then
					g_mouse.unbindComboHotkeyPress(b, modules.game_interface and modules.game_interface.getRootPanel())
				end
			end
		end
	end
end

local function actionBarResolveSourceItem(slot)
	local tier = slot.getTier or 0

	if g_game.getClientVersion() < 780 or slot.subType then
		return g_game.findPlayerItem(slot.itemId, slot.subType or -1, tier)
	end

	return nil
end

local function actionBarPerformInventoryUseWith(slot, toThing)
	if not toThing then
		return
	end

	local invItem = actionBarResolveSourceItem(slot)

	if g_game.getClientVersion() >= 780 and not slot.subType then
		g_game.useInventoryItemWith(slot.itemId, toThing)
	elseif invItem then
		g_game.useWith(invItem, toThing)
	else
		local item = Item.create(slot.itemId)

		if not item then
			return
		end

		if slot.subType then
			item:setSubType(slot.subType)
		end

		if slot.getTier then
			item:setTier(slot.getTier)
		end

		g_game.useWith(item, toThing)
	end
end

local function actionBarPickTileTargetForUseWith(tile, logicItem)
	if not tile or not logicItem then
		return nil
	end

	local target

	if logicItem:isFluidContainer() or logicItem:isMultiUse() then
		target = tile:getTopMultiUseThing()
	else
		target = tile:getTopUseThing()
	end

	target = target or tile:getTopCreature()

	return target
end

local function actionBarUseItemAtCursor(slot)
	if not slot or not slot.itemId then
		return
	end

	local mousePos = g_window.getMousePosition()
	local root = modules.game_interface.getRootPanel()

	if not root then
		return
	end

	local leaf = root:recursiveGetChildByPos(mousePos, false)
	local mapWidget = leaf

	while mapWidget and mapWidget:getClassName() ~= "UIGameMap" do
		mapWidget = mapWidget:getParent()
	end

	local logicItem = actionBarResolveSourceItem(slot)

	if not logicItem then
		logicItem = Item.create(slot.itemId)

		if not logicItem then
			return
		end

		if slot.subType then
			logicItem:setSubType(slot.subType)
		end

		if slot.getTier then
			logicItem:setTier(slot.getTier)
		end
	end

	if mapWidget then
		local tile = mapWidget:getTile(mousePos)

		if not tile then
			return
		end

		local target = actionBarPickTileTargetForUseWith(tile, logicItem)

		if target then
			actionBarPerformInventoryUseWith(slot, target)
		end

		return
	end

	if leaf then
		local cn = leaf:getClassName()

		if cn == "UIItem" and not leaf:isVirtual() then
			local targetItem = leaf:getItem()

			if targetItem then
				actionBarPerformInventoryUseWith(slot, targetItem)
			end

			return
		end

		if cn == "UICreatureButton" then
			local creature = leaf:getCreature()

			if creature then
				actionBarPerformInventoryUseWith(slot, creature)
			end
		end
	end
end

local function actionSlotSpellStillOnCooldown(slot)
	if not slot then
		return false
	end

	if slot.words and slot.words ~= "" then
		local spell = Spells.getSpellByWords(slot.words)

		if not spell then
			return false
		end

		if getMultiActionCooldownRemaining then
			local spellRem, groupRem = getMultiActionCooldownRemaining(spell)

			if spellRem > 0 or groupRem > 0 then
				return true
			end
		end

		local spellCd = cooldown[spell.id]

		if spellCd and spellCd > 0 then
			return true
		end

		if spell.group then
			for groupId, _ in pairs(spell.group) do
				if groupCooldown[groupId] then
					return true
				end
			end
		end

		return false
	end

	return false
end

function CrosshairCast.isActive()
	return CrosshairCast.activeWords ~= nil
end

function CrosshairCast.getMapTilePositionAt(pos)
	local gameInterface = modules.game_interface

	if not gameInterface or not gameInterface.getRootPanel then
		return nil
	end

	local root = gameInterface.getRootPanel()

	if not root then
		return nil
	end

	local node = root:recursiveGetChildByPos(pos, false)

	while node and node:getClassName() ~= "UIGameMap" do
		node = node:getParent()
	end

	if not node then
		return nil
	end

	local tile = node:getTile(pos)

	if not tile then
		return nil
	end

	return tile:getPosition()
end

function CrosshairCast.finish()
	CrosshairCast.activeWords = nil

	if mouseGrabberWidget and not mouseGrabberWidget:isDestroyed() then
		mouseGrabberWidget:ungrabMouse()
	end

	if g_mouse and g_mouse.popCursor then
		g_mouse.popCursor("target")
	end
end

function CrosshairCast.start(words)
	if not words or words == "" then
		return
	end

	if not mouseGrabberWidget or mouseGrabberWidget:isDestroyed() then
		return
	end

	if g_ui.isMouseGrabbed and g_ui.isMouseGrabbed() then
		return
	end

	CrosshairCast.activeWords = words

	mouseGrabberWidget:grabMouse()

	if g_mouse and g_mouse.pushCursor then
		g_mouse.pushCursor("target")
	end
end

function CrosshairCast.castWithMode(words, mode)
	if not words or words == "" then
		return
	end

	if type(words) ~= "string" then
		words = tostring(words)
	end

	if not g_game.talkSpell then
		g_game.talk(words)

		return
	end

	mode = normalizeCrossHairMode(mode)

	if mode == "cursor" then
		local tilePos = CrosshairCast.getMapTilePositionAt(g_window.getMousePosition())

		if tilePos then
			g_game.talkSpell(words, 2, tilePos)
		end
	elseif mode == "target" then
		g_game.talkSpell(words, 3, {
			x = 0,
			z = 0,
			y = 0
		})
	else
		CrosshairCast.start(words)
	end
end

function onSpellCrosshairMouseRelease(self, mousePosition, mouseButton)
	local words = CrosshairCast.activeWords

	CrosshairCast.finish()

	if mouseButton ~= MouseLeftButton then
		return true
	end

	if not words or words == "" then
		return true
	end

	local pos = CrosshairCast.getMapTilePositionAt(mousePosition)

	if pos and g_game.talkSpell then
		g_game.talkSpell(words, 1, pos)
	end

	return true
end

function executeActionSlot(slot, fromKeyboard)
	if closeCurrentMultiActionPanel then
		closeCurrentMultiActionPanel()
	end

	if slot.itemId and slot.useType then
		if slot.useType == "use" then
			HotkeyUtils.executeHotkeyItem(HOTKEY_USE, slot.itemId, slot.subType)
		elseif slot.useType == "useOnTarget" then
			HotkeyUtils.executeHotkeyItem(HOTKEY_USEONTARGET, slot.itemId, slot.subType)
		elseif slot.useType == "useWith" then
			HotkeyUtils.executeHotkeyItem(HOTKEY_USEWITH, slot.itemId, slot.subType)
		elseif slot.useType == "useOnSelf" then
			HotkeyUtils.executeHotkeyItem(HOTKEY_USEONSELF, slot.itemId, slot.subType)
		elseif slot.useType == "equip" then
			if isActionSlotEquipmentPreset(slot) then
				if actionSlotEquipmentSetNeedsEquip(slot) then
					local player = g_game.getLocalPlayer()

					if player then
						for _, invSlot in ipairs(EQUIPMENT_SET_EQUIP_ORDER) do
							if not actionSlotPresetEntryForSlot(slot, invSlot) then
								local equipped = player:getInventoryItem(invSlot)

								if equipped then
									local tier = equipped.getTier and equipped:getTier() or 0

									g_game.equipItemId(equipped:getId(), tier)
								end
							end
						end

						for _, invSlot in ipairs(EQUIPMENT_SET_EQUIP_ORDER) do
							local entry = actionSlotPresetEntryForSlot(slot, invSlot)

							if entry and not actionSlotPresetEntryMatchesEquipped(player, invSlot, entry) then
								g_game.equipItemId(entry.itemId, entry.getTier or 0)
							end
						end
					end
				end

				startEquipmentSetActionCooldown()
			elseif slot.itemId and slot.itemId > 0 then
				local player = g_game.getLocalPlayer()

				if player then
					local tier = actionSlotItemTier(slot)

					if player:getInventoryCount(slot.itemId, tier) > 0 or isActionSlotEquipEquipped(slot) then
						if slot.smartMode then
							slot._smartEquipPending = true

							if slotHasMultiActions and slotHasMultiActions(slot) and slot._activeMultiIndex and slot.multiActions then
								local entry = slot.multiActions[slot._activeMultiIndex]

								if entry then
									entry._smartEquipPending = true
								end
							end
						end

						g_game.equipItemId(slot.itemId, tier)
					end
				end
			end
		elseif slot.useType == "useAtCursor" then
			actionBarUseItemAtCursor(slot)
		end
	elseif slot.words and slot.words ~= "" then
		local words = slot.parameter and slot.parameter ~= "" and slot.words .. " \"" .. slot.parameter or slot.words
		local spell = Spells.getSpellByWords and Spells.getSpellByWords(slot.words) or nil

		if spell and Spells.hasCrossHairTarget(spell) then
			CrosshairCast.castWithMode(words, normalizeCrossHairMode(slot.crossHairMode))
		else
			g_game.talk(words)
		end
	elseif slot.text then
		if slot.autoSend then
			if fromKeyboard or modules.game_console.isChatEnabled() then
				modules.game_console.sendMessage(slot.text)
			else
				g_game.talk(slot.text)
			end
		elseif fromKeyboard then
			scheduleEvent(function()
				if not modules.game_console.isChatEnabled() then
					modules.game_console.switchChatOnCall()
				end

				modules.game_console.setTextEditText(slot.text)
			end, 1)
		else
			if not modules.game_console.isChatEnabled() then
				modules.game_console.switchChatOnCall()
			end

			modules.game_console.setTextEditText(slot.text)
		end
	end
end

local function tryExecuteActionSlot(slot, fromKeyboard)
	if not slot then
		return
	end

	local isEquip = isActionSlotEquip(slot)

	if isEquip and isActionSlotEquipmentPreset(slot) and isEquipmentSetActionOnCooldown(slot) then
		return
	end

	if slotHasMultiActions and slotHasMultiActions(slot) and executeMultiActionSlot and executeMultiActionSlot(slot, fromKeyboard) then
		if syncMultiActionSlot then
			syncMultiActionSlot(slot)
		end

		return
	end

	if slot.words and slot.words ~= "" and actionSlotSpellStillOnCooldown(slot) then
		executeActionSlot(slot, fromKeyboard)

		return
	end

	executeActionSlot(slot, fromKeyboard)

	if isEquip then
		refreshActionSlotFrameClip(slot)
	end
end

local function bindSlotHotkey(slot)
	function slot.onMouseRelease()
		tryExecuteActionSlot(slot, false)
	end

	if slot.hotkey and slot.hotkey ~= "" then
		g_mouse.bindComboHotkeyPress(slot.hotkey, function()
			if not HotkeyUtils.canPerformKeyCombo(slot.hotkey) then
				return
			end

			if not HotkeyUtils.tryAcquireHotkeyCooldown(slot.hotkey) then
				return
			end

			tryExecuteActionSlot(slot, true)
		end, modules.game_interface and modules.game_interface.getRootPanel())
	end
end

function setupHotkeys()
	updateScrollButtons()
	unbindHotkeys()
	refreshAllSlotsHotkeyMirror()

	if hotkeyPauseDepth > 0 then
		return
	end

	for i = 1, NUM_BARS do
		local panel = actionBarPanels[i]

		if panel then
			for _, slot in pairs(panel:getChildren()) do
				bindSlotHotkey(slot)
			end
		end
	end

	if modules.game_console and modules.game_console.syncMovingKeys then
		modules.game_console.syncMovingKeys()
	end
end

function pauseHotkeys()
	hotkeyPauseDepth = hotkeyPauseDepth + 1

	if hotkeyPauseDepth == 1 then
		unbindHotkeys()
	end
end

function resumeHotkeys()
	if hotkeyPauseDepth <= 0 then
		return
	end

	hotkeyPauseDepth = hotkeyPauseDepth - 1

	if hotkeyPauseDepth == 0 and not HotkeyUtils.areHotkeysDisabled() then
		setupHotkeys()
	end
end

function forceResumeHotkeys()
	hotkeyPauseDepth = 0

	if not HotkeyUtils.areHotkeysDisabled() then
		setupHotkeys()
	end
end

function isKeyComboUsedOnActionBar(keyCombo, chatOn)
	if not keyCombo or keyCombo == "" then
		return false
	end

	if chatOn == nil then
		chatOn = modules.game_console and modules.game_console.isChatEnabled and modules.game_console.isChatEnabled()
	end

	for i = 1, NUM_BARS do
		local panel = actionBarPanels[i]

		if panel then
			for _, slot in pairs(panel:getChildren()) do
				if getSlotHotkeyForChatMode(slot, chatOn) == keyCombo then
					return true
				end
			end
		end
	end

	return false
end

function clearActionBarHotkeyConflicts(keyCombo, chatOn)
	if not keyCombo or keyCombo == "" then
		return false
	end

	if chatOn == nil then
		chatOn = modules.game_console and modules.game_console.isChatEnabled and modules.game_console.isChatEnabled()
	end

	local cleared = false

	for i = 1, NUM_BARS do
		local panel = actionBarPanels[i]

		if panel then
			for _, slot in pairs(panel:getChildren()) do
				if getSlotHotkeyForChatMode(slot, chatOn) == keyCombo then
					if chatOn then
						slot.hotkeyChatOn = ""
					else
						slot.hotkeyChatOff = ""
					end

					syncSlotHotkeyMirror(slot)

					cleared = true
				end
			end
		end
	end

	if cleared then
		unbindHotkeys()
		setupHotkeys()
		saveActionBar()
	end

	return cleared
end

function checkHotkey(hotkey, excludeSlotId)
	if not hotkey or hotkey == "" then
		return false
	end

	for i = 1, NUM_BARS do
		local panel = actionBarPanels[i]

		if panel then
			for _, k in pairs(panel:getChildren()) do
				if excludeSlotId and k:getId() == excludeSlotId then
					-- block empty
				elseif getSlotHotkeyForChatMode(k) == hotkey then
					return true
				end
			end
		end
	end

	return false
end

function hotkeyCapture(assignWindow, keyCode, keyboardModifiers, keyText)
	local keyCombo = determineKeyComboDesc(keyCode, keyboardModifiers, keyText)

	ActionBarHotkeyLogic.updateHotkeyCaptureUI(assignWindow, keyCombo, slotToEdit)

	return true
end

function hotkeyCaptureMousePress(assignWindow, mousePos, mouseButton)
	if mouseButton == MouseLeftButton or mouseButton == MouseRightButton then
		return false
	end

	local keyCombo = g_mouse.mouseButtonToHotkeyDesc(mouseButton)

	if not keyCombo then
		return false
	end

	ActionBarHotkeyLogic.updateHotkeyCaptureUI(assignWindow, keyCombo, slotToEdit)

	return true
end

function hotkeyCaptureMouseWheel(assignWindow, mousePos, direction)
	local keyCombo = g_mouse.wheelDirectionToHotkeyDesc(direction)

	if not keyCombo then
		return false
	end

	ActionBarHotkeyLogic.updateHotkeyCaptureUI(assignWindow, keyCombo, slotToEdit)

	return true
end

function hotkeyClear(assignWindow)
	local slot = findSlotById(slotToEdit)

	if slot then
		if modules.game_console.isChatEnabled() then
			slot.hotkeyChatOn = ""
		else
			slot.hotkeyChatOff = ""
		end

		syncSlotHotkeyMirror(slot)
		setupHotkeys()
		saveActionBar()
	end

	if assignWindow == editHotkeyWindow then
		closeEditHotkeyWindow()

		return
	end

	editHotkeyPendingCombo = ""

	local comboPreview = assignWindow:recursiveGetChildById("comboPreview")

	if comboPreview then
		comboPreview:setText(tr(""))
		comboPreview:resizeToText()
	end
end

function hotkeyCaptureOk(assignWindow)
	local keyCombo = editHotkeyPendingCombo

	if type(keyCombo) ~= "string" then
		keyCombo = keyCombo ~= nil and tostring(keyCombo) or ""
	end

	if keyCombo == "" then
		return
	end

	if g_keyboard.isReservedMovementHotkey(keyCombo) then
		return
	end

	local slot = findSlotById(slotToEdit)

	if not slot then
		if assignWindow == editHotkeyWindow then
			closeEditHotkeyWindow()

			return
		end

		assignWindow:destroy()

		return
	end

	if checkHotkey(keyCombo, slotToEdit) then
		local chatOn = modules.game_console.isChatEnabled()

		for i = 1, NUM_BARS do
			local panel = actionBarPanels[i]

			if panel then
				for _, k in pairs(panel:getChildren()) do
					if k:getId() ~= slotToEdit and getSlotHotkeyForChatMode(k) == keyCombo then
						if chatOn then
							k.hotkeyChatOn = ""
						else
							k.hotkeyChatOff = ""
						end

						syncSlotHotkeyMirror(k)
					end
				end
			end
		end
	end

	local chatMode = modules.game_console.isChatEnabled() and CHAT_MODE.ON or CHAT_MODE.OFF
	local clearedCustom = false

	if Keybind and Keybind.clearCustomHotkeyConflicts then
		clearedCustom = Keybind.clearCustomHotkeyConflicts(keyCombo, chatMode)
	elseif CustomHotkeyManager and CustomHotkeyManager.clearKeyComboConflicts then
		clearedCustom = CustomHotkeyManager.clearKeyComboConflicts(keyCombo, chatMode)
	end

	if clearedCustom and CustomHotkeys and CustomHotkeys.refreshPanel then
		CustomHotkeys.refreshPanel()
	end

	unbindHotkeys()

	if modules.game_console.isChatEnabled() then
		slot.hotkeyChatOn = keyCombo or ""
	else
		slot.hotkeyChatOff = keyCombo or ""
	end

	syncSlotHotkeyMirror(slot)
	setupHotkeys()
	saveActionBar()

	if assignWindow == editHotkeyWindow then
		closeEditHotkeyWindow()

		return
	end

	assignWindow:destroy()
end

function saveActionBar()
	if actionBarBatchDepth > 0 then
		return
	end

	local preset = getActionBarDefaultPresetName()

	if not preset or preset == "" then
		return
	end

	saveActionBarSlotsForPreset(preset, collectCharacterActionBarSlots())
end

function canUseSpell(spell)
	if not spell or not spell.vocations then
		return true
	end

	local player = g_game.getLocalPlayer()

	if not player then
		return true
	end

	local vocation = translateVocation(player:getVocation())

	return table.contains(spell.vocations, vocation)
end

local function playerMeetsSpellLevelAndMana(spell)
	if not spell then
		return false
	end

	local player = g_game.getLocalPlayer()

	if not player then
		return true
	end

	if spell.level and player:getLevel() < spell.level then
		return false
	end

	if spell.mana and player:getMana() < spell.mana then
		return false
	end

	return true
end

function refreshAssignSpellListGrayOverlays()
	if not spellsPanel then
		return
	end

	for _, row in pairs(spellsPanel:getChildren()) do
		local spellName = row:getId()
		local spell = spellName and spellName ~= "" and Spells.getSpellByName(spellName) or nil
		local gray = row:getChildById("spellIconGray")

		if gray then
			gray:setVisible(spell ~= nil and not spellPassesAssignLearntFilter(spell))
		end
	end
end

function updateSlotGray(slot)
	local grayPanel = slot:getChildById("gray")

	if not grayPanel then
		return
	end

	local show = false

	slot.grayManaCost = nil

	if slot.words then
		local spell = Spells.getSpellByWords(slot.words)
		local manaCost = spell and tonumber(spell.mana) or nil

		slot.grayManaCost = manaCost and manaCost > 0 and manaCost or nil

		local vocOk = canUseSpell(spell)
		local statsOk = playerMeetsSpellLevelAndMana(spell)

		show = not vocOk or not statsOk
	elseif slot.passiveId then
		show = not PassiveAbilityUnlockedInWheel(slot.passiveId)
	elseif slot.text then
		show = false
	elseif isActionSlotEquipmentPreset(slot) then
		show = false
	elseif slot.itemId and slot.itemId > 0 then
		show = not playerHasActionBarItem(slot)
	end

	grayPanel:setVisible(show)
end

function updateSlotsVocation()
	for i = 1, NUM_BARS do
		local panel = actionBarPanels[i]

		if panel then
			for _, slot in pairs(panel:getChildren()) do
				updateSlotGray(slot)
				refreshActionSlotInventoryQuantity(slot)
				refreshActionSlotEquipmentDecorations(slot)
				refreshActionSlotFrameClip(slot)
			end
		end
	end

	local mab = modules.game_actionbar

	if mab and mab.refreshOpenMultiActionPanelInventory then
		mab.refreshOpenMultiActionPanelInventory()
	end
end

function updateInventoryDependentActionSlots()
	local smartModeChanged = false

	for i = 1, NUM_BARS do
		local panel = actionBarPanels[i]

		if panel then
			for _, slot in pairs(panel:getChildren()) do
				local hasMultiActions = slotHasMultiActions and slotHasMultiActions(slot)

				if (slot.smartMode or hasMultiActions) and refreshSmartModeSlot(slot) then
					smartModeChanged = true
				end

				local hasInventoryItem = slot.itemId and slot.itemId > 0 and not slot.words and not slot.text and not slot.passiveId and not isActionSlotEquipmentPreset(slot)

				if hasInventoryItem then
					updateSlotGray(slot)
					refreshActionSlotInventoryQuantity(slot)
				end
			end
		end
	end

	if smartModeChanged then
		saveActionBar()
	end

	local mab = modules.game_actionbar

	if mab and mab.refreshOpenMultiActionPanelInventory then
		mab.refreshOpenMultiActionPanelInventory()
	end
end

function updateStatsDependentSlotGray()
	local pendingSlots = slotGrayStatsPendingSlots

	slotGrayStatsPendingSlots = {}

	for slot in pairs(pendingSlots) do
		if slot and not slot:isDestroyed() and slot.words and slot.words ~= "" then
			updateSlotGray(slot)
		end
	end
end

function loadSpell(slot)
	local spell, profile, spellName = Spells.getSpellByWords(slot.words)

	if not spell then
		return
	end

	iconId = tonumber(Spells.getClientId(spellName))

	local icon = slot:getChildById("spellIcon")

	if icon then
		icon:setImageSource(Spells.getIconFileByProfile(profile))
		icon:setImageClip(Spells.getImageClip(iconId, profile))
		icon:show()
	end

	slot:getChildById("text"):setText("")
	slot:setBorderWidth(0)
	refreshActionSlotEquipmentDecorations(slot)
	updateSlotGray(slot)
	applyActionSlotFrame(slot)
	maybeSetupHotkeysAfterSlotLoad()
	refreshActionSlotInventoryQuantity(slot)
	refreshActionSlotTooltip(slot)
	refreshActionSlotVirtueBorder(slot)
end

function loadObject(slot)
	local icon = slot:getChildById("spellIcon")

	if icon then
		icon:hide()
		icon:setImageSource("")
	end

	refreshActionSlotEquipmentDecorations(slot)
	slot:setItemId(slot.itemId)
	slot:getChildById("text"):setText("")
	slot:setBorderWidth(0)
	ItemsDatabase.setTier(slot, slot.getTier)
	updateSlotGray(slot)
	refreshActionSlotInventoryQuantity(slot)
	applyActionSlotFrame(slot)
	maybeSetupHotkeysAfterSlotLoad()
	refreshActionSlotTooltip(slot)
end

function loadPassive(slot)
	local passiveData = PassiveAbilities[slot.passiveId]

	if passiveData then
		local icon = slot:getChildById("spellIcon")

		if icon then
			icon:setImageSource(passiveData.icon)
			icon:setImageClip("0 0 32 32")
			icon:show()
		end

		slot:getChildById("text"):setText("")
		slot:setBorderWidth(0)
		refreshActionSlotEquipmentDecorations(slot)
		updateSlotGray(slot)
		applyActionSlotFrame(slot)
		maybeSetupHotkeysAfterSlotLoad()
		refreshActionSlotTooltip(slot)
	end
end

function loadText(slot)
	local icon = slot:getChildById("spellIcon")

	if icon then
		icon:hide()
		icon:setImageSource("")
	end

	refreshActionSlotEquipmentDecorations(slot)
	slot:getChildById("text"):setText(slot.text)

	while slot:getChildById("text"):getTextSize().height > 30 do
		local subString = slot:getChildById("text"):getText()

		subString = string.sub(subString, 1, #subString - 1)

		slot:getChildById("text"):setText(subString)
	end

	applyActionSlotFrame(slot)
	maybeSetupHotkeysAfterSlotLoad()
	refreshActionSlotTooltip(slot)
end

function loadActionBar()
	unbindHotkeys()

	local hotkeys, migrated = loadActionBarSettingsForCurrentPreset()

	beginActionBarBatch()
	applyPresetSlotsToActionBar(hotkeys)
	endActionBarBatch()

	if migrated then
		saveActionBar()
	end

	setupHotkeys()
	applyClientOptionsToActionBar()
	refreshAllVirtueYellowBorders()

	if refreshAllSmartModeSlots then
		refreshAllSmartModeSlots()
	end
end

function setBarVisible(barId, visible)
	local bar = actionBars[barId]

	if not bar then
		if not visible then
			return
		end

		local ok, result = pcall(ensureBarLoaded, barId)

		if not ok or not result then
			return
		end

		bar = result
	end

	if not bar or bar:isDestroyed() then
		actionBars[barId] = nil
		actionBarPanels[barId] = nil

		return
	end

	if visible then
		if isSideBar(barId) then
			bar:setWidth(SIDE_BAR_WIDTH)
			updateSideContainerWidths()
			bar:show()
			layoutSideLockButton(isLeftBar(barId) and "left" or "right")
		else
			bar:setHeight(37)
			bar:show()
		end

		updateScrollButtonsForBar(bar)
	else
		if isSideBar(barId) then
			bar:setWidth(0)
		else
			bar:setHeight(0)
		end

		bar:hide()

		if isSideBar(barId) then
			updateSideContainerWidths()
			layoutSideLockButton(isLeftBar(barId) and "left" or "right")
		end
	end

	if isBottomBar(barId) then
		applyBottomAnchors()
		refreshBottomCooldownDock()

		if modules.game_interface and modules.game_interface.refreshStatsBarDockLayout then
			modules.game_interface.refreshStatsBarDockLayout()
		end
	end
end

function setActionBarVisible(visible)
	setBarVisible(BAR_BOTTOM_1, visible)
end

function setBottomBarGroupVisible(allEnabled, bar1, bar2, bar3)
	if not allEnabled then
		setBarVisible(BAR_BOTTOM_1, false)
		setBarVisible(BAR_BOTTOM_2, false)
		setBarVisible(BAR_BOTTOM_3, false)

		return
	end

	setBarVisible(BAR_BOTTOM_1, bar1 == true)
	setBarVisible(BAR_BOTTOM_2, bar2 == true)
	setBarVisible(BAR_BOTTOM_3, bar3 == true)
end

function setLeftBarGroupVisible(allEnabled, bar1, bar2, bar3)
	if not allEnabled then
		setBarVisible(BAR_LEFT_1, false)
		setBarVisible(BAR_LEFT_2, false)
		setBarVisible(BAR_LEFT_3, false)

		return
	end

	setBarVisible(BAR_LEFT_1, bar1 == true)
	setBarVisible(BAR_LEFT_2, bar2 == true)
	setBarVisible(BAR_LEFT_3, bar3 == true)
	normalizeSideBarChildOrder("left")
end

function setRightBarGroupVisible(allEnabled, bar1, bar2, bar3)
	if not allEnabled then
		setBarVisible(BAR_RIGHT_1, false)
		setBarVisible(BAR_RIGHT_2, false)
		setBarVisible(BAR_RIGHT_3, false)

		return
	end

	setBarVisible(BAR_RIGHT_1, bar1 == true)
	setBarVisible(BAR_RIGHT_2, bar2 == true)
	setBarVisible(BAR_RIGHT_3, bar3 == true)
	normalizeSideBarChildOrder("right")
end

function configureActionBar(id, enabled)
	if not id or type(id) ~= "string" then
		return
	end

	if not modules.client_options then
		return
	end

	if id:find("actionBarShowBottom", 1, true) then
		local b1 = modules.client_options.getOption("actionBarShowBottom1")
		local b2 = modules.client_options.getOption("actionBarShowBottom2")
		local b3 = modules.client_options.getOption("actionBarShowBottom3")

		if id == "actionBarShowBottom1" then
			b1 = enabled
		end

		if id == "actionBarShowBottom2" then
			b2 = enabled
		end

		if id == "actionBarShowBottom3" then
			b3 = enabled
		end

		local allOn = modules.client_options.getOption("allActionBar13")

		setBottomBarGroupVisible(allOn, b1, b2, b3)
	elseif id:find("actionBarShowLeft", 1, true) then
		local c1 = modules.client_options.getOption("actionBarShowLeft1")
		local c2 = modules.client_options.getOption("actionBarShowLeft2")
		local c3 = modules.client_options.getOption("actionBarShowLeft3")

		if id == "actionBarShowLeft1" then
			c1 = enabled
		end

		if id == "actionBarShowLeft2" then
			c2 = enabled
		end

		if id == "actionBarShowLeft3" then
			c3 = enabled
		end

		local allOn = modules.client_options.getOption("allActionBar46")

		setLeftBarGroupVisible(allOn, c1, c2, c3)
	elseif id:find("actionBarShowRight", 1, true) then
		local c1 = modules.client_options.getOption("actionBarShowRight1")
		local c2 = modules.client_options.getOption("actionBarShowRight2")
		local c3 = modules.client_options.getOption("actionBarShowRight3")

		if id == "actionBarShowRight1" then
			c1 = enabled
		end

		if id == "actionBarShowRight2" then
			c2 = enabled
		end

		if id == "actionBarShowRight3" then
			c3 = enabled
		end

		local allOn = modules.client_options.getOption("allActionBar79")

		setRightBarGroupVisible(allOn, c1, c2, c3)
	end
end

local function shouldShowGraphicalCooldown()
	if not modules or not modules.client_options then
		return true
	end

	return modules.client_options.getOption("graphicalCooldown") ~= false
end

local function shouldShowCooldownSeconds()
	if not modules or not modules.client_options then
		return true
	end

	return modules.client_options.getOption("cooldownSecond") ~= false
end

function clearCooldownVisuals()
	for i = 1, NUM_BARS do
		local panel = actionBarPanels[i]

		if panel then
			for _, slot in pairs(panel:getChildren()) do
				slot._equipmentSetCooldownUntil = nil

				for __, ch in pairs(slot:getChildren()) do
					local cid = ch:getId()

					if cid and tostring(cid):sub(1, 8) == "progress" then
						ch:destroy()
					end
				end
			end
		end
	end

	cooldown = {}
	groupCooldown = {}
	equipmentSetSharedCooldownUntil = nil
end

function toggleCooldownOption()
	if not shouldShowGraphicalCooldown() then
		clearCooldownVisuals()
	end
end

function updateVisibleOptions(opt, value)
	reapplyAllSlotDisplayOpts()
end

function reapplyAllSlotDisplayOpts()
	if not modules or not modules.client_options then
		return
	end

	local showKey = modules.client_options.getOption("showAssignedHKButton") ~= false
	local showCount = modules.client_options.getOption("showHKObjectsBars") ~= false
	local showTT = modules.client_options.getOption("actionTooltip") ~= false

	for barId = 1, NUM_BARS do
		local panel = actionBarPanels[barId]

		if panel then
			for _, slot in pairs(panel:getChildren()) do
				local k = slot:getChildById("key")

				if k then
					k:setVisible(showKey)
				end

				pcall(function()
					slot:setShowCount(showCount)
				end)

				slot._actionBarShowCount = showCount

				pcall(function()
					slot:setShowItemCount(false)
				end)
				refreshActionSlotInventoryQuantity(slot)

				if not showTT then
					if slot.setTooltip then
						slot:setTooltip("")
					end
				else
					refreshActionSlotTooltip(slot)
				end
			end
		end
	end

	local mab = modules.game_actionbar

	if mab and mab.reapplyMultiSubSlotDisplayOpts then
		mab.reapplyMultiSubSlotDisplayOpts()
	end

	refreshAllSlotsHotkeyMirror()
end

function applyClientOptionsToActionBar()
	if not actionBar or not modules or not modules.client_options then
		return
	end

	local allBottom = modules.client_options.getOption("allActionBar13")

	if allBottom == nil then
		allBottom = true
	end

	local b1 = modules.client_options.getOption("actionBarShowBottom1")
	local b2 = modules.client_options.getOption("actionBarShowBottom2")
	local b3 = modules.client_options.getOption("actionBarShowBottom3")

	if b1 == nil then
		b1 = true
	end

	setBottomBarGroupVisible(allBottom, b1, b2, b3)

	local allLeft = modules.client_options.getOption("allActionBar46")

	if allLeft == nil then
		allLeft = false
	end

	setLeftBarGroupVisible(allLeft, modules.client_options.getOption("actionBarShowLeft1"), modules.client_options.getOption("actionBarShowLeft2"), modules.client_options.getOption("actionBarShowLeft3"))

	local allRight = modules.client_options.getOption("allActionBar79")

	if allRight == nil then
		allRight = false
	end

	setRightBarGroupVisible(allRight, modules.client_options.getOption("actionBarShowRight1"), modules.client_options.getOption("actionBarShowRight2"), modules.client_options.getOption("actionBarShowRight3"))
	normalizeSideBarChildOrder("left")
	normalizeSideBarChildOrder("right")
	reapplyAllSlotDisplayOpts()

	if not shouldShowGraphicalCooldown() then
		clearCooldownVisuals()
	end
end

function round(n)
	return n % 1 >= 0.5 and math.ceil(n) or math.floor(n)
end

multiActionCooldownSyncLock = false

local function syncMultiActionFromCooldownWidget(widget)
	if multiActionCooldownSyncLock or not widget or widget:isDestroyed() or not syncMultiActionSlot then
		return
	end

	local target = widget

	if not slotHasMultiActions or not slotHasMultiActions(target) then
		target = widget.parentSlot
	end

	if not target or target:isDestroyed() or not slotHasMultiActions(target) then
		return
	end

	if updateMultiSlotState then
		updateMultiSlotState(target, true)
	end

	if refreshMultiActionPanel and target._multiPanelOpen then
		refreshMultiActionPanel(target)
	end

	if refreshMultiActionPanelCooldowns then
		refreshMultiActionPanelCooldowns(target, false)
	end
end

function resolveCooldownProgressState(totalDuration, remainingMs)
	local total = totalDuration

	if not total or total <= 0 then
		total = remainingMs > 0 and remainingMs or 1
	end

	remainingMs = math.max(0, remainingMs or 0)
	total = math.max(total, remainingMs)

	local elapsed = total - remainingMs
	local count = math.max(0, math.floor(elapsed / 100 + 0.5))
	local maxCount = math.max(1, math.floor(total / 100 + 0.5))

	if maxCount <= count then
		count = math.max(0, maxCount - 1)
	end

	local percent = math.min(99, count * 10000 / total)

	return total, remainingMs, count, percent
end

function updateCooldown(progressRect, duration, spellId, count)
	if not progressRect or progressRect:isDestroyed() or not spellId or not duration or duration <= 0 then
		return
	end

	count = count or 0

	local percent = math.min(100, count * 10000 / duration)

	progressRect:setPercent(percent)

	local remainingMs = duration * (1 - percent / 100)

	remainingMs = math.max(0, remainingMs)

	if shouldShowCooldownSeconds() and remainingMs > 0 then
		progressRect:setText(string.format("%.1f", remainingMs / 1000))
		progressRect:setTextOffset("-1 0")
	else
		progressRect:setText("")
	end

	if percent < 100 then
		removeEvent(progressRect.event)

		cooldown[spellId] = duration - count * 100
		progressRect.event = scheduleEvent(function()
			updateCooldown(progressRect, duration, spellId, count + 1)
		end, 100)
	else
		cooldown[spellId] = nil

		local slotItem = progressRect.item

		if progressRect and not progressRect:isDestroyed() then
			removeEvent(progressRect.event)

			progressRect.event = nil

			progressRect:setPercent(0)
			progressRect:setText("")
			progressRect:hide()
		end

		if slotItem and not multiActionCooldownSyncLock then
			scheduleEvent(function()
				if not slotItem or slotItem:isDestroyed() then
					return
				end

				if slotHasMultiActions and slotHasMultiActions(slotItem) and updateMultiSlotState then
					multiActionCooldownSyncLock = true

					updateMultiSlotState(slotItem, true)

					multiActionCooldownSyncLock = false
				elseif syncMultiActionSlot then
					syncMultiActionSlot(slotItem)
				end
			end, 0)
		end
	end
end

local function layoutActionBarCooldownProgress(progressRect)
	progressRect:breakAnchors()
	progressRect:setSize(tosize("32 32"))
	progressRect:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
	progressRect:addAnchor(AnchorVerticalCenter, "parent", AnchorVerticalCenter)
end

function raiseMultiActionMarkerAboveCooldown(slot)
	if not slot or slot:isDestroyed() then
		return
	end

	local icon = slot:getChildById("multiIcon")

	if icon and not icon:isDestroyed() and icon:isVisible() and icon.raise then
		icon:raise()
	end
end

local function raiseEquipmentSlotDecorIconsAboveCooldown(slot)
	if not slot or slot:isDestroyed() then
		return
	end

	local icon = slot:getChildById("equipmentTypeIcon")

	if icon and not icon:isDestroyed() and icon:isVisible() and icon.raise then
		icon:raise()
	end
end

local function raiseActionBarCooldownProgress(slot, progressRect)
	if progressRect and progressRect.raise then
		progressRect:raise()
	end

	raiseMultiActionMarkerAboveCooldown(slot)
	raiseEquipmentSlotDecorIconsAboveCooldown(slot)
end

function clearSlotProgressWidgets(slot)
	for _, ch in pairs(slot:getChildren()) do
		local cid = ch:getId()

		if cid and tostring(cid):sub(1, 8) == "progress" then
			if ch.event then
				removeEvent(ch.event)

				ch.event = nil
			end

			ch:destroy()
		end
	end
end

local function applyCooldownOverlayToSlot(slot, overlay, onlyIfMissing)
	if not overlay or overlay.remaining <= 0 then
		clearSlotProgressWidgets(slot)

		return
	end

	if onlyIfMissing and overlay.progressId and slot:recursiveGetChildById(overlay.progressId) then
		return
	end

	clearSlotProgressWidgets(slot)

	if overlay.useGroupCooldown and overlay.groupId then
		groupCooldown[overlay.groupId] = true
	elseif overlay.spellId then
		cooldown[overlay.spellId] = overlay.remaining
	end

	local totalDuration = overlay.totalDuration
	local remainingMs = overlay.remainingMs

	if not totalDuration or totalDuration <= 0 then
		totalDuration = overlay.remaining
		remainingMs = overlay.remaining
	end

	local total, rem, tickCount, initialPercent = resolveCooldownProgressState(totalDuration, remainingMs)
	local progressRect = slot:recursiveGetChildById(overlay.progressId)

	if progressRect and not progressRect:isDestroyed() then
		removeEvent(progressRect.event)

		progressRect.event = nil
	else
		progressRect = g_ui.createWidget("ActionBarCooldownProgress", slot)

		progressRect:setId(overlay.progressId)
	end

	progressRect.item = slot

	layoutActionBarCooldownProgress(progressRect)
	raiseActionBarCooldownProgress(slot, progressRect)
	progressRect:setPercent(initialPercent)
	progressRect:show()

	if overlay.useGroupCooldown and overlay.groupId then
		updateGroupCooldown(progressRect, total, overlay.groupId, tickCount)
	elseif overlay.spellId then
		updateCooldown(progressRect, total, overlay.spellId, tickCount)
	end
end

function refreshMultiActionSlotCooldownDisplay(slot, onlyIfMissing)
	if not slot or slot:isDestroyed() then
		return
	end

	if not shouldShowGraphicalCooldown() then
		return
	end

	if not getMultiActionCooldownRemaining then
		return
	end

	local remaining = 0
	local progressId
	local useGroupCooldown = false
	local groupId, spellId, spell

	if slot.words and slot.words ~= "" then
		spell = Spells.getSpellByWords(slot.words)

		if not spell then
			clearSlotProgressWidgets(slot)

			return
		end

		local spellRem, groupRem = getMultiActionCooldownRemaining(spell)

		remaining = math.max(spellRem, groupRem)
		useGroupCooldown = spellRem < groupRem

		if useGroupCooldown then
			groupId = getMultiActionActiveGroupId and getMultiActionActiveGroupId(spell)

			if not groupId then
				useGroupCooldown = false
			else
				progressId = "progress" .. groupId
			end
		end

		if not useGroupCooldown then
			spellId = spell.id
			progressId = "progress" .. spellId
		end
	elseif slot.itemId and slot.itemId > 0 and slot.useType and slot.useType ~= "equip" then
		local runeSpell = getRuneUsageSpell and getRuneUsageSpell(slot.itemId) or Spells.getRuneSpellByItem(slot.itemId)

		if runeSpell then
			local spellRem, groupRem = getMultiActionCooldownRemaining(runeSpell)

			remaining = math.max(spellRem, groupRem)
			useGroupCooldown = spellRem < groupRem

			if useGroupCooldown then
				groupId = getMultiActionActiveGroupId and getMultiActionActiveGroupId(runeSpell)

				if groupId then
					progressId = "progress" .. groupId
				else
					useGroupCooldown = false
				end
			end

			if not useGroupCooldown then
				spellId = runeSpell.id
				progressId = "progress" .. spellId
			end
		else
			if shouldPaintItemMultiCdOnMainSlot and not shouldPaintItemMultiCdOnMainSlot(slot) then
				clearSlotProgressWidgets(slot)

				return
			end

			remaining = getItemMultiUseCooldownRemaining and getItemMultiUseCooldownRemaining() or 0

			if remaining > 0 and remaining < 100 and clearItemMultiUseCooldownCache then
				clearItemMultiUseCooldownCache()

				remaining = 0
			end

			if remaining > 0 then
				groupId = ACTIONBAR_ITEM_MULTI_CD_KEY
				progressId = "progress" .. groupId
				useGroupCooldown = true
			end
		end
	else
		clearSlotProgressWidgets(slot)

		return
	end

	if remaining <= 0 then
		clearSlotProgressWidgets(slot)

		return
	end

	if onlyIfMissing and progressId and slot:recursiveGetChildById(progressId) then
		return
	end

	clearSlotProgressWidgets(slot)

	if useGroupCooldown then
		groupCooldown[groupId] = true
	elseif spellId then
		cooldown[spellId] = remaining
	end

	local totalDuration, remainingMs = remaining, remaining

	if spell then
		if useGroupCooldown and getMultiActionGroupCooldownTiming then
			totalDuration, remainingMs = getMultiActionGroupCooldownTiming(spell)
		elseif getMultiActionSpellCooldownTiming then
			totalDuration, remainingMs = getMultiActionSpellCooldownTiming(spell.id)
		end
	elseif slot.itemId and slot.itemId > 0 then
		local runeSpell = getRuneUsageSpell and getRuneUsageSpell(slot.itemId) or Spells.getRuneSpellByItem(slot.itemId)

		if runeSpell then
			if useGroupCooldown and getMultiActionGroupCooldownTiming then
				totalDuration, remainingMs = getMultiActionGroupCooldownTiming(runeSpell)
			elseif getMultiActionSpellCooldownTiming then
				totalDuration, remainingMs = getMultiActionSpellCooldownTiming(runeSpell.id)
			end
		elseif getMultiActionItemCooldownTiming then
			totalDuration, remainingMs = getMultiActionItemCooldownTiming()
		end
	end

	if not totalDuration or totalDuration <= 0 then
		totalDuration = remaining
		remainingMs = remaining
	end

	local total, rem, tickCount, initialPercent = resolveCooldownProgressState(totalDuration, remainingMs)
	local progressRect = slot:recursiveGetChildById(progressId)

	if progressRect and not progressRect:isDestroyed() then
		removeEvent(progressRect.event)

		progressRect.event = nil
	else
		progressRect = g_ui.createWidget("ActionBarCooldownProgress", slot)

		progressRect:setId(progressId)
	end

	progressRect.item = slot

	layoutActionBarCooldownProgress(progressRect)
	raiseActionBarCooldownProgress(slot, progressRect)
	progressRect:setPercent(initialPercent)
	progressRect:show()

	multiActionCooldownSyncLock = true

	if useGroupCooldown then
		updateGroupCooldown(progressRect, total, groupId, tickCount)
	elseif spellId then
		updateCooldown(progressRect, total, spellId, tickCount)
	end

	multiActionCooldownSyncLock = false
end

function refreshMultiActionSlotCooldownDisplayIfNeeded(slot)
	refreshMultiActionSlotCooldownDisplay(slot, true)
end

function updateGroupCooldown(progressRect, duration, groupId, count)
	if not progressRect or progressRect:isDestroyed() or not groupId or not duration or duration <= 0 then
		return
	end

	count = count or 0

	local percent = math.min(100, count * 10000 / duration)

	progressRect:setPercent(percent)

	local remainingMs = duration * (1 - percent / 100)

	remainingMs = math.max(0, remainingMs)

	if shouldShowCooldownSeconds() and remainingMs > 0 then
		progressRect:setText(string.format("%.1f", remainingMs / 1000))
	else
		progressRect:setText("")
	end

	if percent < 100 then
		removeEvent(progressRect.event)

		progressRect.event = scheduleEvent(function()
			updateGroupCooldown(progressRect, duration, groupId, count + 1)
		end, 100)
	else
		groupCooldown[groupId] = nil

		local slotItem = progressRect.item

		if progressRect and not progressRect:isDestroyed() then
			removeEvent(progressRect.event)

			progressRect.event = nil

			progressRect:setPercent(0)
			progressRect:setText("")
			progressRect:hide()
		end

		if groupId == ACTIONBAR_ITEM_MULTI_CD_KEY and onMultiActionItemMultiUseCooldown then
			onMultiActionItemMultiUseCooldown(0)

			return
		end

		if slotItem and not multiActionCooldownSyncLock then
			scheduleEvent(function()
				if not slotItem or slotItem:isDestroyed() then
					return
				end

				if slotHasMultiActions and slotHasMultiActions(slotItem) and updateMultiSlotState then
					multiActionCooldownSyncLock = true

					updateMultiSlotState(slotItem, true)

					multiActionCooldownSyncLock = false
				elseif syncMultiActionSlot then
					syncMultiActionSlot(slotItem)
				end
			end, 0)
		end
	end
end

function startEquipmentSetActionCooldownVisual(slot)
	if not slot or slot:isDestroyed() or not isActionSlotEquipmentPreset(slot) then
		return
	end

	if not shouldShowGraphicalCooldown() then
		return
	end

	local groupId = equipmentSetCooldownGroupId()
	local duration = EQUIPMENT_SET_COOLDOWN_MS
	local progressRect = slot:recursiveGetChildById(EQUIPMENT_SET_CD_PROGRESS_ID)

	if not progressRect then
		progressRect = g_ui.createWidget("ActionBarCooldownProgress", slot)

		progressRect:setId(EQUIPMENT_SET_CD_PROGRESS_ID)

		progressRect.item = slot

		layoutActionBarCooldownProgress(progressRect)
		raiseActionBarCooldownProgress(slot, progressRect)
	else
		removeEvent(progressRect.event)
		layoutActionBarCooldownProgress(progressRect)
		progressRect:setPercent(0)
		progressRect:show()
		raiseActionBarCooldownProgress(slot, progressRect)
	end

	groupCooldown[groupId] = true

	local total, rem, tickCount, initialPercent = resolveCooldownProgressState(duration, duration)

	progressRect:setPercent(initialPercent)
	updateGroupCooldown(progressRect, total, groupId, tickCount)
end

function onMultiUseCooldown(duration)
	if onMultiActionItemMultiUseCooldown then
		onMultiActionItemMultiUseCooldown(duration)
	end

	if not shouldShowGraphicalCooldown() then
		return
	end

	local key = ACTIONBAR_ITEM_MULTI_CD_KEY
	local progressWidgetId = "progress" .. key

	if not duration or duration <= 0 then
		groupCooldown[key] = nil

		for barId = 1, NUM_BARS do
			local panel = actionBarPanels[barId]

			if panel then
				for _, slot in pairs(panel:getChildren()) do
					local pr = slot:recursiveGetChildById(progressWidgetId)

					if pr then
						removeEvent(pr.event)
						pr:destroy()
					end
				end
			end
		end

		return
	end

	for barId = 1, NUM_BARS do
		local panel = actionBarPanels[barId]

		if panel then
			for _, slot in pairs(panel:getChildren()) do
				if slotHasMultiActions and slotHasMultiActions(slot) then
					-- block empty
				else
					local isSpellSlot = slot.words and slot.words ~= ""

					if isSpellSlot or slot.passiveId or not slot.itemId or not (slot.itemId > 0) or slot.useType == "equip" or getRuneUsageSpell and getRuneUsageSpell(slot.itemId) then
						-- block empty
					else
						local progressRect = slot:recursiveGetChildById(progressWidgetId)

						if not progressRect then
							progressRect = g_ui.createWidget("ActionBarCooldownProgress", slot)

							progressRect:setId(progressWidgetId)

							progressRect.item = slot

							layoutActionBarCooldownProgress(progressRect)
							raiseActionBarCooldownProgress(slot, progressRect)
						else
							layoutActionBarCooldownProgress(progressRect)
							progressRect:setPercent(0)
							progressRect:show()
							raiseActionBarCooldownProgress(slot, progressRect)
						end

						local total, rem, tickCount, initialPercent = resolveCooldownProgressState(duration, duration)

						progressRect:setPercent(initialPercent)
						updateGroupCooldown(progressRect, total, key, tickCount)

						groupCooldown[key] = true
					end
				end
			end
		end
	end
end

function onSpellCooldown(spellId, duration)
	if onMultiActionSpellCooldown then
		onMultiActionSpellCooldown(spellId, duration)
	end

	if not shouldShowGraphicalCooldown() then
		return true
	end

	local spell, profile, spellName = Spells.getSpellByIcon(spellId)

	if not spell then
		print("[WARNING] Can not set cooldown on spell with id: " .. spellId)

		return true
	end

	for barId = 1, NUM_BARS do
		local panel = actionBarPanels[barId]

		if panel then
			for _, k in pairs(panel:getChildren()) do
				if slotHasMultiActions and slotHasMultiActions(k) then
					-- block empty
				else
					local runeSpell = k.itemId and k.itemId > 0 and getRuneUsageSpell and getRuneUsageSpell(k.itemId)

					if k.words == spell.words or spell.clientId and spell.clientId == k.itemId or runeSpell and runeSpell.id == spell.id then
						local slot = k
						local progressRect = slot:recursiveGetChildById("progress" .. spell.id)

						if not progressRect then
							progressRect = g_ui.createWidget("ActionBarCooldownProgress", slot)

							progressRect:setId("progress" .. spell.id)

							progressRect.item = slot

							layoutActionBarCooldownProgress(progressRect)

							if progressRect.raise then
								progressRect:raise()
							end
						else
							layoutActionBarCooldownProgress(progressRect)
							progressRect:setPercent(0)
							progressRect:show()

							if progressRect.raise then
								progressRect:raise()
							end
						end

						local function updateFunc()
							updateCooldown(progressRect, duration, spell.id, 0)
						end

						progressRect:setPercent(0)
						updateFunc()

						cooldown[spell.id] = duration
					end
				end
			end
		end
	end
end

function onSpellGroupCooldown(groupId, duration)
	if onMultiActionSpellGroupCooldown then
		onMultiActionSpellGroupCooldown(groupId, duration)
	end

	if not shouldShowGraphicalCooldown() then
		return
	end

	for barId = 1, NUM_BARS do
		local panel = actionBarPanels[barId]

		if panel then
			for _, k in pairs(panel:getChildren()) do
				if slotHasMultiActions and slotHasMultiActions(k) then
					-- block empty
				else
					local spell, profile, spellName

					if k.words and k.words ~= "" then
						spell, profile, spellName = Spells.getSpellByWords(k.words)
					elseif k.itemId and k.itemId > 0 and getRuneUsageSpell then
						spell = getRuneUsageSpell(k.itemId)
					else
						spell = nil
					end

					if spell and spell.group[groupId] ~= nil then
						local continue = false

						if not cooldown[spell.id] or cooldown[spell.id] and duration > cooldown[spell.id] then
							local oldProgressBar = k:recursiveGetChildById("progress" .. spell.id)

							if oldProgressBar then
								cooldown[spell.id] = nil

								oldProgressBar:hide()
							end

							continue = true
						elseif cooldown[spell.id] and duration <= cooldown[spell.id] then
							continue = false
						end

						if continue then
							local slot = k
							local progressRect = slot:recursiveGetChildById("progress" .. groupId)

							if not progressRect then
								progressRect = g_ui.createWidget("ActionBarCooldownProgress", slot)

								progressRect:setId("progress" .. groupId)

								progressRect.item = slot

								layoutActionBarCooldownProgress(progressRect)

								if progressRect.raise then
									progressRect:raise()
								end
							else
								layoutActionBarCooldownProgress(progressRect)
								progressRect:setPercent(0)
								progressRect:show()

								if progressRect.raise then
									progressRect:raise()
								end
							end

							local function updateFunc()
								updateGroupCooldown(progressRect, duration, groupId)
							end

							progressRect:setPercent(0)
							updateFunc()

							groupCooldown[groupId] = true
						end
					end
				end
			end
		end
	end
end

function getSpellAssignFilterText()
	if not spellAssignWindow or spellAssignWindow:isDestroyed() then
		return ""
	end

	local edit = spellAssignWindow:recursiveGetChildById("filterTextEdit")

	return edit and edit:getText() or ""
end

function clearSpellFilter()
	if not spellAssignWindow then
		return
	end

	local edit = spellAssignWindow:recursiveGetChildById("filterTextEdit")

	if edit then
		edit:setText("")
		filterSpells("")
		edit:focus()
	end
end

function filterSpells(text)
	if not spellsPanel then
		return
	end

	text = text or ""

	local onlyLearnt = false

	if spellAssignWindow then
		local learntCb = spellAssignWindow:recursiveGetChildById("onlyShowLearntSpellsCheckBox")

		onlyLearnt = learntCb and learntCb:isChecked() or false
	end

	local textFilterActive = #text > 0
	local textLower = textFilterActive and text:lower() or ""

	for _, spellListLabel in pairs(spellsPanel:getChildren()) do
		local visible = true

		if onlyLearnt then
			local spellName = spellListLabel:getId()
			local spell = spellName and spellName ~= "" and Spells.getSpellByName(spellName) or nil

			if not spellPassesAssignLearntFilter(spell) then
				visible = false
			end
		end

		if visible and textFilterActive then
			local rawName = spellListLabel._filterName
			local rawWords = spellListLabel._filterWords
			local labelName = type(rawName) == "string" and rawName:lower() or ""
			local labelWords = type(rawWords) == "string" and rawWords:lower() or ""

			if not string.find(labelName, textLower, 1, true) and not string.find(labelWords, textLower, 1, true) then
				visible = false
			end
		end

		if visible then
			showSpell(spellListLabel)
		else
			hideSpell(spellListLabel)
		end
	end

	local firstVisible

	for _, child in ipairs(spellsPanel:getChildren()) do
		if child:isVisible() then
			firstVisible = child

			break
		end
	end

	if not firstVisible then
		spellAssignPreviewNoSpellSelected()

		return
	end

	if not textFilterActive then
		local filterEdit = spellAssignWindow and spellAssignWindow:recursiveGetChildById("filterTextEdit")
		local typingInFilter = filterEdit and filterEdit:isFocused()
		local focusTarget = pickSpellAssignListFocusWidget() or firstVisible

		spellsPanel:focusChild(focusTarget, KeyboardFocusReason)

		local sn = focusTarget:getChildById("spellName")
		local sw = focusTarget:getChildById("spellWords")
		local sl = focusTarget:getChildById("spellLevel")

		if sn and sw then
			sn:setColor("#ffffff")
			sw:setColor("#ffffff")
		end

		if sl then
			sl:setColor("#ffffff")
		end

		updatePreviewSpell(focusTarget)
		syncSpellAssignParameterFieldFromSlot(focusTarget)

		if typingInFilter and filterEdit then
			filterEdit:focus()
		end

		return
	end

	local focused = spellsPanel:getFocusedChild()

	if focused and focused:isVisible() then
		updatePreviewSpell(focused)
		syncSpellAssignParameterFieldFromSlot(focused)
	else
		spellsPanel:focusChild(firstVisible, KeyboardFocusReason)

		local sn = firstVisible:getChildById("spellName")
		local sw = firstVisible:getChildById("spellWords")
		local sl = firstVisible:getChildById("spellLevel")

		if sn and sw then
			sn:setColor("#ffffff")
			sw:setColor("#ffffff")
		end

		if sl then
			sl:setColor("#ffffff")
		end

		updatePreviewSpell(firstVisible)
		syncSpellAssignParameterFieldFromSlot(firstVisible)
	end
end

function hideSpell(spellListLabel)
	if spellListLabel:isVisible() then
		spellListLabel:hide()
		spellListLabel:setHeight(0)
	end
end

function showSpell(spellListLabel)
	if not spellListLabel:isVisible() then
		local h = spellListLabel.defaultHeight

		if type(h) ~= "number" then
			h = 34
		end

		spellListLabel:setHeight(h)
		spellListLabel:show()
	end
end

function onDecrementHorizontalScroll(bar, value)
	bar = bar or actionBar

	if not bar or bar:isDestroyed() then
		return
	end

	local panel = barWidgetChild(bar, "actionBarPanel")
	local horizontalScroll = barWidgetChild(bar, "horizontalScroll")

	if not panel or not horizontalScroll then
		return
	end

	if value == 999 then
		value = math.floor(panel:getWidth() / 36) * 36
	end

	local nextBtn = barWidgetChild(bar, "nextButton")
	local nextSkip = barWidgetChild(bar, "nextSkipButton")

	if nextBtn then
		nextBtn:setEnabled(true)
	end

	if nextSkip then
		nextSkip:setEnabled(true)
	end

	local prevBtn = barWidgetChild(bar, "prevButton")
	local prevSkip = barWidgetChild(bar, "prevSkipButton")

	if horizontalScroll:getValue() - value <= horizontalScroll:getMinimum() then
		if prevBtn then
			prevBtn:setEnabled(false)
		end

		if prevSkip then
			prevSkip:setEnabled(false)
		end
	else
		if prevBtn then
			prevBtn:setEnabled(true)
		end

		if prevSkip then
			prevSkip:setEnabled(true)
		end
	end

	horizontalScroll:decrement(value)
end

function onIncrementHorizontalScroll(bar, value)
	bar = bar or actionBar

	if not bar or bar:isDestroyed() then
		return
	end

	local panel = barWidgetChild(bar, "actionBarPanel")
	local horizontalScroll = barWidgetChild(bar, "horizontalScroll")

	if not panel or not horizontalScroll then
		return
	end

	if value == 999 then
		value = math.floor(panel:getWidth() / 36) * 36
	end

	local prevBtn = barWidgetChild(bar, "prevButton")
	local prevSkip = barWidgetChild(bar, "prevSkipButton")

	if prevBtn then
		prevBtn:setEnabled(true)
	end

	if prevSkip then
		prevSkip:setEnabled(true)
	end

	local nextBtn = barWidgetChild(bar, "nextButton")
	local nextSkip = barWidgetChild(bar, "nextSkipButton")

	if horizontalScroll:getValue() + value >= horizontalScroll:getMaximum() then
		if nextBtn then
			nextBtn:setEnabled(false)
		end

		if nextSkip then
			nextSkip:setEnabled(false)
		end
	else
		if nextBtn then
			nextBtn:setEnabled(true)
		end

		if nextSkip then
			nextSkip:setEnabled(true)
		end
	end

	horizontalScroll:increment(value)
end

function onDecrementVerticalScroll(bar, value)
	if not bar or bar:isDestroyed() then
		return
	end

	local scroll = barWidgetChild(bar, "verticalScroll")

	if not scroll then
		return
	end

	value = value or SIDE_BAR_SLOT_PITCH

	local newVal

	if value == 999 then
		newVal = scroll:getMinimum()
	else
		newVal = math.max(scroll:getMinimum(), scroll:getValue() - value)
	end

	scroll:setValue(newVal)
	updateScrollButtonsForBar(bar)
end

function onIncrementVerticalScroll(bar, value)
	if not bar or bar:isDestroyed() then
		return
	end

	local scroll = barWidgetChild(bar, "verticalScroll")

	if not scroll then
		return
	end

	value = value or SIDE_BAR_SLOT_PITCH

	local newVal

	if value == 999 then
		newVal = scroll:getMaximum()
	else
		newVal = math.min(scroll:getMaximum(), scroll:getValue() + value)
	end

	scroll:setValue(newVal)
	updateScrollButtonsForBar(bar)
end

function getLocked(group)
	return isActionBarGroupLocked(group or "bottom")
end

function setLocked(v, group)
	group = group or "bottom"
	actionBarLocks[group] = not not v
	isLocked = isActionBarGroupLocked("bottom")

	if group == "bottom" then
		applyBottomLockAppearance(false, bottomLockButton)
	elseif group == "left" then
		layoutSideLockButton("left")
	elseif group == "right" then
		layoutSideLockButton("right")
	else
		applyBottomLockAppearance(false, bottomLockButton)
		layoutSideLockButton("left")
		layoutSideLockButton("right")
	end
end

function getPanelActionbar()
	return actionBar
end

local function clearSlotData(slot)
	clearSlotActionContent(slot)

	local sid = slot:getId()
	local idxBottom = sid and tonumber(sid:match("^slot(%d+)$"))

	if idxBottom then
		initDefaultHotkeysFirstBottomBarSlot(slot, idxBottom)
	else
		slot.hotkeyChatOn = ""
		slot.hotkeyChatOff = ""
		slot.hotkey = ""

		local key = slot:getChildById("key")

		if key then
			key:setText("")
		end
	end
end

function resetAction(barId)
	if not barId or not actionBarPanels[barId] then
		return
	end

	unbindHotkeys()

	for _, slot in pairs(actionBarPanels[barId]:getChildren()) do
		clearSlotData(slot)
	end

	setupHotkeys()
	saveActionBar()
end

function resetActionBars()
	unbindHotkeys()

	for i = 1, NUM_BARS do
		local panel = actionBarPanels[i]

		if panel then
			for _, slot in pairs(panel:getChildren()) do
				clearSlotData(slot)
			end
		end
	end

	setupHotkeys()
	saveActionBar()
end

local function clearAllActionBarSlotsWithoutSave()
	for i = 1, NUM_BARS do
		local panel = actionBarPanels[i]

		if panel then
			for _, slot in pairs(panel:getChildren()) do
				clearSlotData(slot)
			end
		end
	end
end

function prepareActionBarForLogin()
	if g_game.isOnline() then
		return
	end

	local presetName = getActionBarDefaultPresetName()

	if not presetName or presetName == "" or actionBarPreparedPreset == presetName then
		return
	end

	local startedAt = g_clock.realMillis()
	local storedSlots = getActionBarSlotsForPreset(presetName)

	setupActionBar()
	applyClientOptionsToActionBar()
	setupActionBar()
	beginActionBarBatch()
	clearAllActionBarSlotsWithoutSave()
	applyPresetSlotsToActionBar(storedSlots)
	endActionBarBatch()

	actionBarPreparedPreset = presetName

	g_logger.info(string.format("[login] actionbar preset %s preloaded in %d ms", presetName, g_clock.realMillis() - startedAt))
end

function reloadActionBarForPreset(presetName, previousPreset)
	if not g_game.isOnline() then
		return
	end

	if not actionBarPanels or not actionBarPanels[BAR_BOTTOM_1] then
		return
	end

	if not presetName or presetName == "" then
		return
	end

	if previousPreset and previousPreset ~= "" and previousPreset ~= presetName then
		saveActionBarSlotsForPreset(previousPreset, collectCharacterActionBarSlots())
	end

	local storedSlots = getActionBarSlotsForPreset(presetName)
	local storedCount = countActionBarSlotsWithContent(storedSlots)

	beginActionBarBatch()
	unbindHotkeys()
	clearAllActionBarSlotsWithoutSave()
	applyPresetSlotsToActionBar(storedSlots)
	endActionBarBatch()
	setupHotkeys()
	applyClientOptionsToActionBar()
	refreshAllVirtueYellowBorders()
	updateSlotsVocation()

	actionBarPreparedPreset = presetName

	g_logger.info(string.format("[actionbar] reload preset=%s storedSlots=%d", presetName, storedCount))
end

function onHotkeyPresetChanged(newPreset, oldPreset)
	if not g_game.isOnline() then
		return
	end

	if not actionBarPanels or not actionBarPanels[BAR_BOTTOM_1] then
		return
	end

	reloadActionBarForPreset(newPreset, oldPreset)
end
