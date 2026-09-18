-- chunkname: @/game_store/auction_character.lua

local checksAuctionCharacterWindow, configAuctionCharacterWindow
local auctionCharacterWindowStep = 0
local auctionCharacterHeaderData
local auctionCharacterConfigPanel = "none"
local auctionCharacterItemsInventory, auctionCharacterItemsStore, auctionCharacterArguments
local auctionCharacterItemsSearchFilter = ""
local auctionCharacterHeaderSlots = {}
local auctionCharacterNextSlot = 1
local auctionCharacterHeaderArgumentSlots = {}
local auctionCharacterNextArgumentSlot = 1
local auctionCharacterArgumentListSelection
local auctionCharacterLastArgumentClick = {
	time = 0
}
local auctionCharacterListSelection
local auctionCharacterLastItemClick = {
	time = 0
}
local auctionCharacterItemsRefreshEvent, auctionCharacterSearchRefreshEvent
local auctionCharacterItemNameCache = {}
local auctionCharacterCalendarBaseTimestamp = 0
local auctionCharacterCalendarMonthIndex = 0
local auctionCharacterSelectedTimestamp, auctionCharacterCalendarDayCells, auctionCharacterCalendarGridCache
local auctionCharacterTimeComboSyncing = false
local updateAuctionCharacterEndDateLabels, refreshAuctionCharacterItemsList, updateAuctionCharacterHeaderItemSlot, updateAllAuctionCharacterHeaderItemSlots, updateAllAuctionCharacterArgumentSlots, fillAuctionCharacterArguments
local AUCTION_CALENDAR_CELL_COUNT = 42
local AUCTION_CALENDAR_MONTH_NAMES = {
	"Jan",
	"Feb",
	"Mar",
	"Apr",
	"May",
	"Jun",
	"Jul",
	"Aug",
	"Sep",
	"Oct",
	"Nov",
	"Dec"
}

local function getAuctionCharacterCalendarYearMonth()
	local baseTime = os.date("*t", auctionCharacterCalendarBaseTimestamp)
	local year = baseTime.year
	local month = baseTime.month + auctionCharacterCalendarMonthIndex

	while month > 12 do
		month = month - 12
		year = year + 1
	end

	while month < 1 do
		month = month + 12
		year = year - 1
	end

	return year, month
end

local function formatAuctionCharacterMonthYear(year, month)
	local monthName = AUCTION_CALENDAR_MONTH_NAMES[month] or "???"

	return string.format("%s %d", monthName, year)
end

local function getAuctionCharacterDaysInMonth(year, month)
	if month == 12 then
		return os.date("*t", os.time({
			month = 1,
			day = 0,
			hour = 12,
			year = year + 1
		})).day
	end

	return os.date("*t", os.time({
		day = 0,
		hour = 12,
		year = year,
		month = month + 1
	})).day
end

local function getAuctionCharacterMondayWeekday(year, month, day)
	local wday = os.date("*t", os.time({
		hour = 12,
		year = year,
		month = month,
		day = day
	})).wday

	if wday == 1 then
		return 7
	end

	return wday - 1
end

local function getAuctionCharacterCalendarRange()
	if not auctionCharacterHeaderData then
		return nil, nil
	end

	local dataMin = tonumber(auctionCharacterHeaderData.dataMin)
	local dataMax = tonumber(auctionCharacterHeaderData.dataMax)

	if not dataMin or not dataMax then
		return nil, nil
	end

	return dataMin, dataMax
end

local function isAuctionCharacterDayInSelectableRange(year, month, day)
	local dataMin, dataMax = getAuctionCharacterCalendarRange()

	if not dataMin or not dataMax then
		return true
	end

	local dayStart = os.time({
		hour = 0,
		min = 0,
		sec = 0,
		year = year,
		month = month,
		day = day
	})
	local dayEnd = os.time({
		hour = 23,
		min = 59,
		sec = 59,
		year = year,
		month = month,
		day = day
	})

	return dataMin <= dayEnd and dayStart <= dataMax
end

local AUCTION_CHARACTER_MINUTE_OPTIONS = {
	0,
	15,
	30,
	45
}

local function buildAuctionCharacterTimestamp(year, month, day, hour, min, sec)
	return os.time({
		year = year,
		month = month,
		day = day,
		hour = hour or 0,
		min = min or 0,
		sec = sec or 0
	})
end

local function buildAuctionCharacterTimestampForDay(year, month, day, referenceTimestamp)
	local reference = os.date("*t", referenceTimestamp or os.time())

	return buildAuctionCharacterTimestamp(year, month, day, reference.hour, reference.min, reference.sec)
end

local function isAuctionCharacterTimestampInRange(timestamp)
	local dataMin, dataMax = getAuctionCharacterCalendarRange()

	if not dataMin or not dataMax then
		return true
	end

	return dataMin <= timestamp and timestamp <= dataMax
end

local function clampAuctionCharacterSelectedTimestamp()
	local dataMin, dataMax = getAuctionCharacterCalendarRange()

	if not auctionCharacterSelectedTimestamp then
		return
	end

	if dataMin and dataMin > auctionCharacterSelectedTimestamp then
		auctionCharacterSelectedTimestamp = dataMin
	elseif dataMax and dataMax < auctionCharacterSelectedTimestamp then
		auctionCharacterSelectedTimestamp = dataMax
	end
end

local function getAuctionCharacterSelectedDateParts()
	if not auctionCharacterSelectedTimestamp then
		return nil
	end

	return os.date("*t", auctionCharacterSelectedTimestamp)
end

local function isAuctionCharacterHourValidForSelectedDay(hour)
	local parts = getAuctionCharacterSelectedDateParts()

	if not parts then
		return false
	end

	for _, minute in ipairs(AUCTION_CHARACTER_MINUTE_OPTIONS) do
		local timestamp = buildAuctionCharacterTimestamp(parts.year, parts.month, parts.day, hour, minute, parts.sec)

		if isAuctionCharacterTimestampInRange(timestamp) then
			return true
		end
	end

	return false
end

local function isAuctionCharacterMinuteValidForSelectedDayHour(minute)
	local parts = getAuctionCharacterSelectedDateParts()

	if not parts then
		return false
	end

	local timestamp = buildAuctionCharacterTimestamp(parts.year, parts.month, parts.day, parts.hour, minute, parts.sec)

	return isAuctionCharacterTimestampInRange(timestamp)
end

local function getAuctionCharacterHourCombo()
	if not configAuctionCharacterWindow or configAuctionCharacterWindow:isDestroyed() then
		return nil
	end

	return configAuctionCharacterWindow:recursiveGetChildById("selectHourOption")
end

local function getAuctionCharacterMinuteCombo()
	if not configAuctionCharacterWindow or configAuctionCharacterWindow:isDestroyed() then
		return nil
	end

	return configAuctionCharacterWindow:recursiveGetChildById("selectMinuteOption")
end

local function refreshAuctionCharacterHourCombo(dontSignal)
	local combo = getAuctionCharacterHourCombo()
	local parts = getAuctionCharacterSelectedDateParts()

	if not combo or combo:isDestroyed() or not parts then
		return
	end

	combo:clearOptions()

	for hour = 0, 23 do
		if isAuctionCharacterHourValidForSelectedDay(hour) then
			combo:addOption(string.format("%02d", hour), hour)
		end
	end

	clampAuctionCharacterSelectedTimestamp()

	parts = getAuctionCharacterSelectedDateParts()

	if not parts then
		return
	end

	if isAuctionCharacterHourValidForSelectedDay(parts.hour) then
		combo:setCurrentOptionByData(parts.hour, dontSignal)
	elseif combo:getOptionsCount() > 0 and combo.options[1] then
		local firstHour = combo.options[1].data

		auctionCharacterSelectedTimestamp = buildAuctionCharacterTimestamp(parts.year, parts.month, parts.day, firstHour, parts.min, parts.sec)

		clampAuctionCharacterSelectedTimestamp()
		combo:setCurrentOptionByData(firstHour, true)
	end
end

local function refreshAuctionCharacterMinuteCombo(dontSignal)
	local combo = getAuctionCharacterMinuteCombo()
	local parts = getAuctionCharacterSelectedDateParts()

	if not combo or combo:isDestroyed() or not parts then
		return
	end

	combo:clearOptions()

	for _, minute in ipairs(AUCTION_CHARACTER_MINUTE_OPTIONS) do
		if isAuctionCharacterMinuteValidForSelectedDayHour(minute) then
			combo:addOption(string.format("%02d", minute), minute)
		end
	end

	clampAuctionCharacterSelectedTimestamp()

	parts = getAuctionCharacterSelectedDateParts()

	if not parts then
		return
	end

	if isAuctionCharacterMinuteValidForSelectedDayHour(parts.min) then
		combo:setCurrentOptionByData(parts.min, dontSignal)
	elseif combo:getOptionsCount() > 0 and combo.options[1] then
		local firstMinute = combo.options[1].data

		auctionCharacterSelectedTimestamp = buildAuctionCharacterTimestamp(parts.year, parts.month, parts.day, parts.hour, firstMinute, parts.sec)

		clampAuctionCharacterSelectedTimestamp()
		combo:setCurrentOptionByData(firstMinute, true)
	end
end

local function syncAuctionCharacterTimeCombos(dontSignal)
	if not auctionCharacterSelectedTimestamp then
		return
	end

	auctionCharacterTimeComboSyncing = true

	clampAuctionCharacterSelectedTimestamp()
	refreshAuctionCharacterHourCombo(dontSignal)
	refreshAuctionCharacterMinuteCombo(dontSignal)

	auctionCharacterTimeComboSyncing = false
end

local function setAuctionCharacterSelectedTime(hour, minute)
	local parts = getAuctionCharacterSelectedDateParts()

	if not parts then
		return
	end

	auctionCharacterSelectedTimestamp = buildAuctionCharacterTimestamp(parts.year, parts.month, parts.day, hour, minute, parts.sec)

	clampAuctionCharacterSelectedTimestamp()
	syncAuctionCharacterTimeCombos(true)
end

local function isSameAuctionCharacterCalendarDay(timestampA, timestampB)
	if not timestampA or not timestampB then
		return false
	end

	local dayA = os.date("*t", timestampA)
	local dayB = os.date("*t", timestampB)

	return dayA.year == dayB.year and dayA.month == dayB.month and dayA.day == dayB.day
end

local function initAuctionCharacterCalendarFromHeaderData()
	local dataMin = select(1, getAuctionCharacterCalendarRange())

	if not dataMin then
		return
	end

	auctionCharacterCalendarBaseTimestamp = dataMin
	auctionCharacterCalendarMonthIndex = 0
	auctionCharacterSelectedTimestamp = dataMin
end

local function buildAuctionCharacterCalendarGrid(year, month)
	local daysInMonth = getAuctionCharacterDaysInMonth(year, month)
	local startOffset = getAuctionCharacterMondayWeekday(year, month, 1) - 1
	local prevMonth = month - 1
	local prevYear = year

	if prevMonth < 1 then
		prevMonth = 12
		prevYear = year - 1
	end

	local prevMonthDays = getAuctionCharacterDaysInMonth(prevYear, prevMonth)
	local nextMonth = month + 1
	local nextYear = year

	if nextMonth > 12 then
		nextMonth = 1
		nextYear = year + 1
	end

	local grid = {}

	for cellIndex = 1, AUCTION_CALENDAR_CELL_COUNT do
		local index = cellIndex - 1

		if index < startOffset then
			grid[cellIndex] = {
				inMonth = false,
				day = prevMonthDays - startOffset + index + 1,
				year = prevYear,
				month = prevMonth
			}
		elseif index < startOffset + daysInMonth then
			grid[cellIndex] = {
				inMonth = true,
				day = index - startOffset + 1,
				year = year,
				month = month
			}
		else
			grid[cellIndex] = {
				inMonth = false,
				day = index - startOffset - daysInMonth + 1,
				year = nextYear,
				month = nextMonth
			}
		end
	end

	return grid
end

local function getAuctionCharacterCalendarDayLabel(cell)
	if not cell or cell:isDestroyed() then
		return nil
	end

	return cell:getChildById("dayLabel")
end

local function getAuctionCharacterCalendarSelectionOverlay(cell)
	if not cell or cell:isDestroyed() then
		return nil
	end

	return cell:getChildById("selectionOverlay")
end

local function applyAuctionCharacterCalendarCellOffset(cell, cellIndex)
	local dayLabel = getAuctionCharacterCalendarDayLabel(cell)

	if not dayLabel or dayLabel:isDestroyed() then
		return
	end

	local index = cellIndex - 1
	local column = index % 7
	local row = math.floor(index / 7)
	local offsetX = column * 2

	if column >= 2 then
		offsetX = offsetX - 3
	end

	local offsetY = 0

	if row > 0 then
		offsetY = -(row + 1)
	end

	if row == 5 then
		offsetY = offsetY - 3
	end

	dayLabel:setTextOffset(string.format("%d %d", offsetX, offsetY))
end

local function bindAuctionCharacterCalendarCell(cell, cellIndex)
	if not cell or cell:isDestroyed() then
		return
	end

	function cell.onClick()
		onAuctionCharacterCalendarDayClick(cellIndex)
	end
end

local function applyAuctionCharacterCalendarCellStyle(cell, data)
	if not cell or cell:isDestroyed() or not data then
		return
	end

	local dayLabel = getAuctionCharacterCalendarDayLabel(cell)
	local selectionOverlay = getAuctionCharacterCalendarSelectionOverlay(cell)

	if not dayLabel or dayLabel:isDestroyed() then
		return
	end

	local selectable = isAuctionCharacterDayInSelectableRange(data.year, data.month, data.day)
	local cellTimestamp = buildAuctionCharacterTimestampForDay(data.year, data.month, data.day, auctionCharacterSelectedTimestamp or auctionCharacterCalendarBaseTimestamp)
	local selected = isSameAuctionCharacterCalendarDay(cellTimestamp, auctionCharacterSelectedTimestamp)

	if selected then
		dayLabel:setColor("#ffffff")

		if selectionOverlay and not selectionOverlay:isDestroyed() then
			selectionOverlay:setSize({
				width = 33,
				height = 24
			})
			selectionOverlay:setMarginLeft(11)
			selectionOverlay:setMarginTop(1)
			selectionOverlay:setBackgroundColor("#585858")
			selectionOverlay:setVisible(true)
		end
	elseif selectable then
		dayLabel:setColor("#c0c0c0")

		if selectionOverlay and not selectionOverlay:isDestroyed() then
			selectionOverlay:setVisible(false)
		end
	else
		dayLabel:setColor("#707070")

		if selectionOverlay and not selectionOverlay:isDestroyed() then
			selectionOverlay:setVisible(false)
		end
	end

	cell:setPhantom(not selectable)
	cell:setFocusable(selectable)

	cell.calendarYear = data.year
	cell.calendarMonth = data.month
	cell.calendarDay = data.day
end

local function ensureAuctionCharacterCalendarDayCells()
	if not configAuctionCharacterWindow or configAuctionCharacterWindow:isDestroyed() then
		return false
	end

	local panel = configAuctionCharacterWindow:recursiveGetChildById("calendarDaysPanel")

	if not panel or panel:isDestroyed() then
		return false
	end

	if auctionCharacterCalendarDayCells and #auctionCharacterCalendarDayCells == AUCTION_CALENDAR_CELL_COUNT then
		local first = auctionCharacterCalendarDayCells[1]
		local dayLabel = first and getAuctionCharacterCalendarDayLabel(first)

		if first and not first:isDestroyed() and dayLabel and not dayLabel:isDestroyed() then
			return true
		end
	end

	panel:destroyChildren()

	auctionCharacterCalendarDayCells = {}

	for cellIndex = 1, AUCTION_CALENDAR_CELL_COUNT do
		local cell = g_ui.createWidget("AuctionCalendarDayCell", panel)

		if cell then
			cell:setId("calendarDay" .. cellIndex)
			applyAuctionCharacterCalendarCellOffset(cell, cellIndex)
			bindAuctionCharacterCalendarCell(cell, cellIndex)

			auctionCharacterCalendarDayCells[cellIndex] = cell
		end
	end

	return #auctionCharacterCalendarDayCells == AUCTION_CALENDAR_CELL_COUNT
end

local function updateAuctionCharacterCalendarDays()
	if not ensureAuctionCharacterCalendarDayCells() then
		return
	end

	local year, month = getAuctionCharacterCalendarYearMonth()
	local grid = buildAuctionCharacterCalendarGrid(year, month)

	auctionCharacterCalendarGridCache = grid

	for cellIndex = 1, AUCTION_CALENDAR_CELL_COUNT do
		local cell = auctionCharacterCalendarDayCells[cellIndex]
		local data = grid[cellIndex]

		if cell and not cell:isDestroyed() and data then
			applyAuctionCharacterCalendarCellOffset(cell, cellIndex)

			local dayLabel = getAuctionCharacterCalendarDayLabel(cell)

			if dayLabel and not dayLabel:isDestroyed() then
				dayLabel:setText(tostring(data.day))
			end

			applyAuctionCharacterCalendarCellStyle(cell, data)
		end
	end
end

local function updateAuctionCharacterMonthYearLabel()
	if not configAuctionCharacterWindow or configAuctionCharacterWindow:isDestroyed() then
		return
	end

	local label = configAuctionCharacterWindow:recursiveGetChildById("mesEAnoLabel")

	if not label or label:isDestroyed() then
		return
	end

	local year, month = getAuctionCharacterCalendarYearMonth()

	label:setText(formatAuctionCharacterMonthYear(year, month))
end

local function updateAuctionCharacterCalendar()
	updateAuctionCharacterMonthYearLabel()
	updateAuctionCharacterCalendarDays()
end

local AUCTION_CHARACTER_CEST_OFFSET_SECONDS = 18000

local function formatAuctionCharacterEndDatePrimary(timestamp)
	return os.date("%Y-%m-%d, %H:%M", timestamp)
end

local function formatAuctionCharacterEndDateSecondary(primaryTimestamp)
	return os.date("%Y-%m-%d, %H:%M CEST", primaryTimestamp + AUCTION_CHARACTER_CEST_OFFSET_SECONDS)
end

local function formatAuctionCharacterEndDateLabel3Text()
	local parts = getAuctionCharacterSelectedDateParts()

	if not parts then
		return ""
	end

	return string.format("%04d-%02d-%02d, %02d:%02d", parts.year, parts.month, parts.day, parts.hour, parts.min)
end

local function formatAuctionCharacterDateConfigRangeText(dataMin, dataMax)
	return string.format("%s and %s.", formatAuctionCharacterEndDatePrimary(dataMin), formatAuctionCharacterEndDatePrimary(dataMax))
end

local function updateAuctionCharacterDateConfigLabel()
	if not configAuctionCharacterWindow or configAuctionCharacterWindow:isDestroyed() then
		return
	end

	local label = configAuctionCharacterWindow:recursiveGetChildById("dateConfigLabel")

	if not label or label:isDestroyed() then
		return
	end

	local dataMin, dataMax = getAuctionCharacterCalendarRange()

	if not dataMin or not dataMax then
		return
	end

	label:setText(formatAuctionCharacterDateConfigRangeText(dataMin, dataMax))
end

function updateAuctionCharacterEndDateLabels()
	if not configAuctionCharacterWindow or configAuctionCharacterWindow:isDestroyed() then
		return
	end

	if not auctionCharacterSelectedTimestamp then
		return
	end

	local label3 = configAuctionCharacterWindow:recursiveGetChildById("label3")
	local label4 = configAuctionCharacterWindow:recursiveGetChildById("label4")

	if label3 and not label3:isDestroyed() then
		label3:setText(formatAuctionCharacterEndDateLabel3Text())
	end

	if label4 and not label4:isDestroyed() then
		label4:setText(formatAuctionCharacterEndDateSecondary(auctionCharacterSelectedTimestamp))
	end
end

function onAuctionCharacterCalendarDayClick(cellIndex)
	local data = auctionCharacterCalendarGridCache and auctionCharacterCalendarGridCache[cellIndex]

	if not data then
		return
	end

	if not isAuctionCharacterDayInSelectableRange(data.year, data.month, data.day) then
		return
	end

	auctionCharacterSelectedTimestamp = buildAuctionCharacterTimestampForDay(data.year, data.month, data.day, auctionCharacterSelectedTimestamp or auctionCharacterCalendarBaseTimestamp)

	clampAuctionCharacterSelectedTimestamp()
	updateAuctionCharacterCalendarDays()
	syncAuctionCharacterTimeCombos(true)
end

local function bindAuctionCharacterTimeComboHandlers()
	local hourCombo = getAuctionCharacterHourCombo()
	local minuteCombo = getAuctionCharacterMinuteCombo()

	if hourCombo and not hourCombo:isDestroyed() then
		function hourCombo.onOptionChange(_, _, data)
			onSelectHourOptionChange(data)
		end
	end

	if minuteCombo and not minuteCombo:isDestroyed() then
		function minuteCombo.onOptionChange(_, _, data)
			onSelectMinuteOptionChange(data)
		end
	end
end

function onSelectHourOptionChange(hour)
	if auctionCharacterTimeComboSyncing then
		return
	end

	hour = tonumber(hour)

	if hour == nil then
		return
	end

	local parts = getAuctionCharacterSelectedDateParts()

	if not parts then
		return
	end

	setAuctionCharacterSelectedTime(hour, parts.min)
end

function onSelectMinuteOptionChange(minute)
	if auctionCharacterTimeComboSyncing then
		return
	end

	minute = tonumber(minute)

	if minute == nil then
		return
	end

	local parts = getAuctionCharacterSelectedDateParts()

	if not parts then
		return
	end

	setAuctionCharacterSelectedTime(parts.hour, minute)
end

function onClickOnBackDate()
	auctionCharacterCalendarMonthIndex = auctionCharacterCalendarMonthIndex - 1

	updateAuctionCharacterCalendar()
end

function onClickOnNextDate()
	auctionCharacterCalendarMonthIndex = auctionCharacterCalendarMonthIndex + 1

	updateAuctionCharacterCalendar()
end

local function isChecksAuctionWindowOpen()
	return checksAuctionCharacterWindow and not checksAuctionCharacterWindow:isDestroyed() and checksAuctionCharacterWindow:isVisible()
end

local function isConfigAuctionWindowOpen()
	return configAuctionCharacterWindow and not configAuctionCharacterWindow:isDestroyed() and configAuctionCharacterWindow:isVisible()
end

local function isAuctionCharacterWindowOpen()
	return isChecksAuctionWindowOpen() or isConfigAuctionWindowOpen()
end

local function destroyChecksAuctionCharacterWindow()
	if checksAuctionCharacterWindow then
		if not checksAuctionCharacterWindow:isDestroyed() then
			checksAuctionCharacterWindow:destroy()
		end

		checksAuctionCharacterWindow = nil
	end
end

local function destroyConfigAuctionCharacterWindow()
	if configAuctionCharacterWindow then
		if not configAuctionCharacterWindow:isDestroyed() then
			configAuctionCharacterWindow:destroy()
		end

		configAuctionCharacterWindow = nil
	end
end

local function destroyAllAuctionCharacterWindows()
	destroyChecksAuctionCharacterWindow()
	destroyConfigAuctionCharacterWindow()

	auctionCharacterWindowStep = 0
	auctionCharacterHeaderData = nil
	auctionCharacterConfigPanel = "none"
	auctionCharacterItemsInventory = nil
	auctionCharacterItemsStore = nil
	auctionCharacterItemsSearchFilter = ""
	auctionCharacterHeaderSlots = {}
	auctionCharacterNextSlot = 1
	auctionCharacterHeaderArgumentSlots = {}
	auctionCharacterNextArgumentSlot = 1
	auctionCharacterArgumentListSelection = nil
	auctionCharacterLastArgumentClick.row = nil
	auctionCharacterLastArgumentClick.time = 0
	auctionCharacterArguments = nil
	auctionCharacterListSelection = nil
	auctionCharacterLastItemClick.box = nil
	auctionCharacterLastItemClick.time = 0
	auctionCharacterItemNameCache = {}
	auctionCharacterCalendarMonthIndex = 0
	auctionCharacterCalendarBaseTimestamp = 0
	auctionCharacterSelectedTimestamp = nil
	auctionCharacterCalendarDayCells = nil
	auctionCharacterCalendarGridCache = nil

	if auctionCharacterItemsRefreshEvent then
		removeEvent(auctionCharacterItemsRefreshEvent)

		auctionCharacterItemsRefreshEvent = nil
	end

	if auctionCharacterSearchRefreshEvent then
		removeEvent(auctionCharacterSearchRefreshEvent)

		auctionCharacterSearchRefreshEvent = nil
	end
end

local function closeAuctionCharacterWindow()
	destroyAllAuctionCharacterWindows()

	if modules.game_store and modules.game_store.showStoreAfterAuction then
		modules.game_store.showStoreAfterAuction()
	end
end

local function hideAuctionCharacterWindow(window)
	if window and not window:isDestroyed() then
		window:hide()
		g_modalManager.hide(window)
	end
end

local function showAuctionCharacterWindow(window)
	if not window or window:isDestroyed() then
		return
	end

	window:show()
	window:raise()
	window:focus()

	window.onEscape = closeAuctionCharacterWindow

	g_modalManager.show(window)
end

local function showAuctionCharacterStep1()
	hideAuctionCharacterWindow(configAuctionCharacterWindow)

	if checksAuctionCharacterWindow and not checksAuctionCharacterWindow:isDestroyed() then
		showAuctionCharacterWindow(checksAuctionCharacterWindow)
	end

	auctionCharacterWindowStep = 1
end

local function updateAuctionCharacterConfigOutfit()
	if not configAuctionCharacterWindow or configAuctionCharacterWindow:isDestroyed() then
		return
	end

	local outfitWidget = configAuctionCharacterWindow.headerWindow and configAuctionCharacterWindow.headerWindow.Outfit

	if not outfitWidget then
		return
	end

	local player = g_game.getLocalPlayer()

	if not player then
		return
	end

	outfitWidget:setOutfit(player:getOutfit())
	outfitWidget:getCreature():setStaticWalking(1000)
end

local AUCTION_MIN_OFFER_PRICE = 56
local AUCTION_OFFER_PRICE_COLOR_OK = "#FFFFFF"
local AUCTION_OFFER_PRICE_COLOR_LOW = "#F75F5F"

local function updateAuctionOffertPriceColor(edit)
	if not edit or edit:isDestroyed() then
		return
	end

	local value = tonumber(edit:getText())

	if value and value < AUCTION_MIN_OFFER_PRICE then
		edit:setColor(AUCTION_OFFER_PRICE_COLOR_LOW)
	else
		edit:setColor(AUCTION_OFFER_PRICE_COLOR_OK)
	end
end

local function setupAuctionOffertPriceEdit()
	if not configAuctionCharacterWindow or configAuctionCharacterWindow:isDestroyed() then
		return
	end

	local edit = configAuctionCharacterWindow.headerWindow and configAuctionCharacterWindow.headerWindow.offertPriceEdit

	if not edit then
		return
	end

	edit:setValidCharacters("0123456789")

	function edit:onTextChange(text, oldText)
		if text ~= "" and not tonumber(text) then
			self:setText(oldText or "")

			text = self:getText()
		end

		updateAuctionOffertPriceColor(self)
	end

	updateAuctionOffertPriceColor(edit)
end

local AUCTION_WORLD_TYPE_NAMES = {
	[0] = "Open PvP",
	"Optional PvP",
	"Hardcore PvP",
	"Retro Open PvP",
	"Retro Hardcore PvP"
}

local function getAuctionVocationName(vocationId)
	if g_game.getVocationName then
		local vocationName = g_game.getVocationName(vocationId)

		if vocationName and vocationName ~= "None" then
			return tr(vocationName)
		end
	end

	return tr("Unknown")
end

local function getAuctionWorldTypeName(worldTypeId)
	return tr(AUCTION_WORLD_TYPE_NAMES[worldTypeId] or "Unknown")
end

local function formatAuctionCharacterHeaderText(name, level, vocation, worldType)
	return string.format("%s (%d) | %s | %s", name or "", level or 0, getAuctionVocationName(vocation), getAuctionWorldTypeName(worldType))
end

local function updateAuctionCharacterHeaderWindow()
	if not auctionCharacterHeaderData then
		return
	end

	if not configAuctionCharacterWindow or configAuctionCharacterWindow:isDestroyed() then
		return
	end

	local headerWindow = configAuctionCharacterWindow.headerWindow

	if not headerWindow then
		return
	end

	local data = auctionCharacterHeaderData

	headerWindow:setText(formatAuctionCharacterHeaderText(data.name, data.level, data.vocation, data.worldType))
end

local function getAuctionConfigBodyPanels()
	if not configAuctionCharacterWindow or configAuctionCharacterWindow:isDestroyed() then
		return nil
	end

	return {
		none = configAuctionCharacterWindow.panelNone,
		item = configAuctionCharacterWindow.panelSelectItem,
		date = configAuctionCharacterWindow.panelSelectDate,
		argument = configAuctionCharacterWindow.panelSelectArgument,
		confirmation = configAuctionCharacterWindow.panelConfirmation
	}
end

function showAuctionCharacterConfigPanel(panelKey)
	local panels = getAuctionConfigBodyPanels()

	if not panels then
		return
	end

	for key, panel in pairs(panels) do
		if panel and not panel:isDestroyed() then
			panel:setVisible(key == panelKey)
		end
	end

	auctionCharacterConfigPanel = panelKey

	if configAuctionCharacterWindow and not configAuctionCharacterWindow:isDestroyed() then
		if configAuctionCharacterWindow.panelNone and not configAuctionCharacterWindow.panelNone:isDestroyed() then
			configAuctionCharacterWindow.panelNone:setVisible(panelKey == "none")
		end

		if configAuctionCharacterWindow.panelSelectItem and not configAuctionCharacterWindow.panelSelectItem:isDestroyed() then
			configAuctionCharacterWindow.panelSelectItem:setVisible(panelKey == "item")
		end

		if configAuctionCharacterWindow.panelSelectDate and not configAuctionCharacterWindow.panelSelectDate:isDestroyed() then
			configAuctionCharacterWindow.panelSelectDate:setVisible(panelKey == "date")
		end

		if configAuctionCharacterWindow.panelSelectArgument and not configAuctionCharacterWindow.panelSelectArgument:isDestroyed() then
			configAuctionCharacterWindow.panelSelectArgument:setVisible(panelKey == "argument")
		end

		if configAuctionCharacterWindow.panelConfirmation and not configAuctionCharacterWindow.panelConfirmation:isDestroyed() then
			configAuctionCharacterWindow.panelConfirmation:setVisible(panelKey == "confirmation")
		end

		local isMainConfig = panelKey == "none"
		local isConfirmation = panelKey == "confirmation"

		if configAuctionCharacterWindow.exitButton then
			configAuctionCharacterWindow.exitButton:setVisible(isMainConfig or isConfirmation)
		end

		if configAuctionCharacterWindow.nextButton then
			configAuctionCharacterWindow.nextButton:setVisible(isMainConfig)
		end

		if configAuctionCharacterWindow.previousButton then
			configAuctionCharacterWindow.previousButton:setVisible(isMainConfig or isConfirmation)
		end

		if configAuctionCharacterWindow.backButton then
			configAuctionCharacterWindow.backButton:setVisible(not isMainConfig and not isConfirmation)
		end

		if configAuctionCharacterWindow.OkButton then
			configAuctionCharacterWindow.OkButton:setVisible(not isMainConfig and not isConfirmation)
		end

		if configAuctionCharacterWindow.confirmationButton then
			configAuctionCharacterWindow.confirmationButton:setVisible(isConfirmation)
		end

		local showHeaderChains = panelKey == "item" or panelKey == "date" or panelKey == "argument" or panelKey == "confirmation"
		local buttonsToShow = {
			"chainSelectItem1",
			"chainSelectItem2",
			"chainSelectItem3",
			"chainSelectItem4",
			"chainSelectArgument1",
			"chainSelectArgument2",
			"chainSelectArgument3",
			"chainSelectArgument4",
			"chainSelectArgument5",
			"chainSelectEndAuctionDate"
		}

		for _, btnId in ipairs(buttonsToShow) do
			local btn = configAuctionCharacterWindow:recursiveGetChildById(btnId)

			if btn and not btn:isDestroyed() then
				btn:setVisible(showHeaderChains)
			end
		end

		local labelsToColor = {
			"label1",
			"label2",
			"label3",
			"label4",
			"labelHour",
			"labelHourCEST",
			"offertPriceEdit"
		}

		for _, labelId in ipairs(labelsToColor) do
			local label = configAuctionCharacterWindow:recursiveGetChildById(labelId)

			if label and not label:isDestroyed() then
				if labelId == "offertPriceEdit" then
					label:setEditable(isMainConfig)
					label:setFocusable(isMainConfig)
				end

				if isMainConfig then
					if labelId == "label3" or labelId == "offertPriceEdit" then
						label:setColor("#FFFFFF")
					else
						label:setColor("#c0c0c0")
					end
				else
					label:setColor("#707070")
				end
			end
		end

		if updateAllAuctionCharacterArgumentSlots then
			updateAllAuctionCharacterArgumentSlots()
		end
	end
end

local function showAuctionCharacterStep2()
	if not checksAuctionCharacterWindow or checksAuctionCharacterWindow:isDestroyed() then
		return
	end

	hideAuctionCharacterWindow(checksAuctionCharacterWindow)

	if not configAuctionCharacterWindow or configAuctionCharacterWindow:isDestroyed() then
		configAuctionCharacterWindow = g_ui.createWidget("ConfigAuctionCharacterWindow", g_ui.getRootWidget())
	end

	if not configAuctionCharacterWindow then
		return
	end

	if configAuctionCharacterWindow.previousButton then
		configAuctionCharacterWindow.previousButton:setEnabled(true)
	end

	configAuctionCharacterWindow:setText(tr("Character Auction Settings (2/3)"))
	showAuctionCharacterWindow(configAuctionCharacterWindow)
	updateAuctionCharacterTransferableBalance()
	updateAuctionCharacterConfigOutfit()
	setupAuctionOffertPriceEdit()
	updateAuctionCharacterHeaderWindow()
	updateAuctionCharacterEndDateLabels()
	updateAuctionCharacterDateConfigLabel()
	bindAuctionCharacterTimeComboHandlers()
	updateAllAuctionCharacterHeaderItemSlots()
	updateAllAuctionCharacterArgumentSlots()
	showAuctionCharacterConfigPanel("none")

	auctionCharacterWindowStep = 2
end

function showPanelConfirmation()
	if not configAuctionCharacterWindow or configAuctionCharacterWindow:isDestroyed() then
		return
	end

	configAuctionCharacterWindow:setText(tr("Character Auction Settings (3/3)"))
	showAuctionCharacterConfigPanel("confirmation")

	auctionCharacterWindowStep = 3
end

function restoreAuctionCharacterStep2()
	if not configAuctionCharacterWindow or configAuctionCharacterWindow:isDestroyed() then
		return
	end

	configAuctionCharacterWindow:setText(tr("Character Auction Settings (2/3)"))
	showAuctionCharacterConfigPanel("none")

	auctionCharacterWindowStep = 2
end

function sendNextAuctionCharacter()
	if auctionCharacterWindowStep == 1 then
		showAuctionCharacterStep2()
	elseif auctionCharacterWindowStep == 2 then
		if auctionCharacterConfigPanel ~= "none" then
			showAuctionCharacterConfigPanel("none")

			return
		end

		showPanelConfirmation()
	end
end

function sendPreviousAuctionCharacter()
	if auctionCharacterWindowStep == 3 then
		restoreAuctionCharacterStep2()
	elseif auctionCharacterWindowStep == 2 then
		if auctionCharacterConfigPanel ~= "none" then
			showAuctionCharacterConfigPanel("none")

			return
		end

		showAuctionCharacterStep1()
	end
end

function toggleAuctionCharacter()
	if not controllerShop.ui then
		return
	end

	if isAuctionCharacterWindowOpen() then
		closeAuctionCharacterWindow()

		return
	end

	hideStoreForCharacterBazaar()
	destroyAllAuctionCharacterWindows()

	checksAuctionCharacterWindow = g_ui.createWidget("ChecksAuctionCharacterWindow", g_ui.getRootWidget())

	if not checksAuctionCharacterWindow then
		return
	end

	g_game.getBaseInformationForAuctionCharacter()

	if checksAuctionCharacterWindow.nextButton then
		checksAuctionCharacterWindow.nextButton:setEnabled(false)
	end

	showAuctionCharacterWindow(checksAuctionCharacterWindow)
	updateAuctionCharacterTransferableBalance()

	auctionCharacterWindowStep = 1
end

local function fillAuctionCharacterRequirements(requirements)
	if not checksAuctionCharacterWindow or checksAuctionCharacterWindow:isDestroyed() then
		return
	end

	local mainBody = checksAuctionCharacterWindow.mainBody
	local list = mainBody and mainBody.auctionChecksList

	if not list then
		return
	end

	list:destroyChildren()

	local allSatisfied = #requirements > 0

	for _, requirement in ipairs(requirements) do
		if requirement[2] ~= 1 then
			allSatisfied = false
		end

		local text = requirement[1]

		if text and text ~= "" then
			local satisfied = requirement[2] == 1
			local row = g_ui.createWidget("AuctionCharacterCheckRow", list)

			if row then
				row.statusIcon:setImageSource(satisfied and "/modules/game_store/images/icon-yes" or "/modules/game_store/images/icon-no")
				row.requirementText:setText(text)

				local textSize = row.requirementText:getTextSize()

				if textSize and textSize.height > 14 then
					row:setHeight(textSize.height + 2)
				end
			end
		end
	end

	local nextButton = checksAuctionCharacterWindow.nextButton

	if nextButton then
		nextButton:setEnabled(allSatisfied)
	end
end

function onAuctionCharacterCheckRequirements(requirements, name, level, vocation, worldType, dataMin, dataMax, lowestBidValue)
	auctionCharacterHeaderData = {
		name = name,
		level = level,
		vocation = vocation,
		worldType = worldType,
		dataMin = tonumber(dataMin),
		dataMax = tonumber(dataMax),
		lowestBidValue = lowestBidValue
	}

	initAuctionCharacterCalendarFromHeaderData()
	fillAuctionCharacterRequirements(requirements)
	updateAuctionCharacterHeaderWindow()
	updateAuctionCharacterEndDateLabels()
	updateAuctionCharacterDateConfigLabel()
end

local function parseAuctionCharacterItemEntry(entry)
	if type(entry) ~= "table" then
		return nil
	end

	local itemId = tonumber(entry[1])
	local tier = tonumber(entry[2]) or 0
	local count = tonumber(entry[3]) or 1

	if not itemId or itemId == 0 then
		return nil
	end

	return {
		id = itemId,
		tier = tier,
		count = count
	}
end

local function getAuctionCharacterItemName(itemId)
	local cached = auctionCharacterItemNameCache[itemId]

	if cached then
		return cached
	end

	local thingType = g_things.getThingType(itemId, ThingCategoryItem)
	local name = ""

	if thingType and thingType.getName then
		name = thingType:getName() or ""
	end

	auctionCharacterItemNameCache[itemId] = name

	return name
end

local function isAuctionCharacterItemPanelActive()
	return auctionCharacterConfigPanel == "item" and configAuctionCharacterWindow and not configAuctionCharacterWindow:isDestroyed() and configAuctionCharacterWindow:isVisible()
end

local function scheduleAuctionCharacterItemsRefresh()
	if not isAuctionCharacterItemPanelActive() then
		return
	end

	if auctionCharacterItemsRefreshEvent then
		removeEvent(auctionCharacterItemsRefreshEvent)
	end

	auctionCharacterItemsRefreshEvent = scheduleEvent(function()
		auctionCharacterItemsRefreshEvent = nil

		refreshAuctionCharacterItemsList()
	end, 50)
end

local function getAuctionCharacterSelectItemsPanel()
	if not configAuctionCharacterWindow or configAuctionCharacterWindow:isDestroyed() then
		return nil
	end

	local panelSelectItem = configAuctionCharacterWindow.panelSelectItem

	if not panelSelectItem or panelSelectItem:isDestroyed() then
		return nil
	end

	return panelSelectItem:recursiveGetChildById("selectItemsPanel")
end

do
	local A = {
		CLEAR_ICON = "/modules/game_store/images/clear-item",
		SLOT_COUNT = 5,
		SELECT_ICON = "/modules/game_store/images/select-item-12x12",
		ROW_COLOR_SELECTED = "#585858",
		LABEL_COLOR_EMPTY = "#c0c0c0",
		ROW_COLOR_B = "#414141",
		LABEL_COLOR_FILLED = "#FFFFFF",
		ROW_COLOR_A = "#484848",
		ICON_COUNT = 15,
		ICON_SIZE = 10,
		LABEL_COLOR_PANEL = "#707070",
		HIGHLIGHTS_ICON = "/images/game/creatures/icons-charactertrade-highlights",
		ENTRY_HEIGHT = 16,
		ENTRIES_MARGIN = 2,
		SEPARATOR_HEIGHT = 2,
		TITLE_HEIGHT = 19
	}
	local updateAuctionCharacterArgumentSlot

	local function getAuctionCharacterSelectArgumentsPanel()
		if not configAuctionCharacterWindow or configAuctionCharacterWindow:isDestroyed() then
			return nil
		end

		local panelSelectArgument = configAuctionCharacterWindow.panelSelectArgument

		if not panelSelectArgument or panelSelectArgument:isDestroyed() then
			return nil
		end

		return panelSelectArgument:recursiveGetChildById("selectArgumentsPanel")
	end

	local function isAuctionCharacterArgumentPanelActive()
		return auctionCharacterConfigPanel == "argument" and configAuctionCharacterWindow and not configAuctionCharacterWindow:isDestroyed() and configAuctionCharacterWindow.panelSelectArgument and not configAuctionCharacterWindow.panelSelectArgument:isDestroyed() and configAuctionCharacterWindow.panelSelectArgument:isVisible()
	end

	local function getAuctionCharacterArgumentLabelColor(hasSlotData)
		if auctionCharacterConfigPanel and auctionCharacterConfigPanel ~= "none" then
			return A.LABEL_COLOR_PANEL
		end

		if hasSlotData then
			return A.LABEL_COLOR_FILLED
		end

		return A.LABEL_COLOR_EMPTY
	end

	local function getAuctionCharacterArgumentIconIndex(argumentId)
		local index = tonumber(argumentId) or 0

		if index < 0 then
			index = 0
		elseif index >= A.ICON_COUNT then
			index = 0
		end

		return index
	end

	local function getAuctionCharacterArgumentIconClip(argumentId)
		local index = getAuctionCharacterArgumentIconIndex(argumentId)

		return torect(string.format("%d 0 %d %d", index * A.ICON_SIZE, A.ICON_SIZE, A.ICON_SIZE))
	end

	local function applyAuctionCharacterArgumentIcon(widget, argumentId, displaySize)
		if not widget or widget:isDestroyed() then
			return
		end

		displaySize = displaySize or A.ICON_SIZE

		widget:setImageFixedRatio(false)
		widget:setImageSource(A.HIGHLIGHTS_ICON)
		widget:setImageClip(getAuctionCharacterArgumentIconClip(argumentId))
		widget:setSize({
			width = displaySize,
			height = displaySize
		})
		widget:setImageSize({
			width = displaySize,
			height = displaySize
		})
	end

	local function getAuctionCharacterArgumentRowHeight(entryCount)
		return A.TITLE_HEIGHT + A.SEPARATOR_HEIGHT + A.ENTRIES_MARGIN + entryCount * A.ENTRY_HEIGHT
	end

	local function applyAuctionCharacterArgumentEntryIcon(entryIcon, argumentId)
		applyAuctionCharacterArgumentIcon(entryIcon, argumentId)
	end

	local function copyAuctionCharacterArgumentData(entryData)
		if not entryData then
			return nil
		end

		return {
			argumentId = entryData.argumentId,
			argumentTitle = entryData.argumentTitle,
			entryIndex = entryData.entryIndex,
			value = entryData.value
		}
	end

	local function isSameAuctionCharacterArgumentEntry(a, b)
		if not a or not b then
			return false
		end

		return a.argumentId == b.argumentId and a.entryIndex == b.entryIndex
	end

	local function isAuctionCharacterArgumentEntryAssigned(entryData)
		for slotIndex = 1, A.SLOT_COUNT do
			if isSameAuctionCharacterArgumentEntry(auctionCharacterHeaderArgumentSlots[slotIndex], entryData) then
				return true
			end
		end

		return false
	end

	local function getAuctionCharacterArgumentRowColor(rowIndex, selected)
		if selected then
			return A.ROW_COLOR_SELECTED
		end

		if rowIndex % 2 == 0 then
			return A.ROW_COLOR_B
		end

		return A.ROW_COLOR_A
	end

	local function setAuctionCharacterArgumentEntryRowSelected(entryRow, selected, rowIndex)
		if not entryRow or entryRow:isDestroyed() then
			return
		end

		entryRow:setBackgroundColor(getAuctionCharacterArgumentRowColor(rowIndex, selected))
	end

	local function clearAuctionCharacterArgumentListSelection(argumentsPanel)
		if not argumentsPanel or argumentsPanel:isDestroyed() then
			return
		end

		for _, groupRow in ipairs(argumentsPanel:getChildren()) do
			local entriesPanel = groupRow:getChildById("argumentEntries")

			if entriesPanel and not entriesPanel:isDestroyed() then
				for _, entryRow in ipairs(entriesPanel:getChildren()) do
					setAuctionCharacterArgumentEntryRowSelected(entryRow, false, entryRow.argumentRowIndex or 1)
				end
			end
		end
	end

	local function selectAuctionCharacterArgumentInList(entryRow, entryData, rowIndex)
		local argumentsPanel = getAuctionCharacterSelectArgumentsPanel()

		clearAuctionCharacterArgumentListSelection(argumentsPanel)
		setAuctionCharacterArgumentEntryRowSelected(entryRow, true, rowIndex)

		auctionCharacterArgumentListSelection = copyAuctionCharacterArgumentData(entryData)
	end

	local function syncAuctionCharacterNextArgumentSlot()
		for slotIndex = 1, A.SLOT_COUNT do
			if not auctionCharacterHeaderArgumentSlots[slotIndex] then
				auctionCharacterNextArgumentSlot = slotIndex

				return
			end
		end

		auctionCharacterNextArgumentSlot = 1
	end

	local function assignAuctionCharacterArgumentToNextSlot(entryData)
		if not entryData then
			return false
		end

		if isAuctionCharacterArgumentEntryAssigned(entryData) then
			return false
		end

		local slotIndex = auctionCharacterNextArgumentSlot

		auctionCharacterHeaderArgumentSlots[slotIndex] = copyAuctionCharacterArgumentData(entryData)

		updateAuctionCharacterArgumentSlot(slotIndex)
		syncAuctionCharacterNextArgumentSlot()

		auctionCharacterArgumentListSelection = nil

		showAuctionCharacterConfigPanel("none")

		return true
	end

	local function confirmAuctionCharacterArgumentFromList(entryData)
		if not entryData then
			return
		end

		assignAuctionCharacterArgumentToNextSlot(entryData)
	end

	local function bindAuctionCharacterArgumentEntryRow(entryRow, entryData, rowIndex)
		entryRow.argumentRowIndex = rowIndex
		entryRow.argumentEntryData = copyAuctionCharacterArgumentData(entryData)

		setAuctionCharacterArgumentEntryRowSelected(entryRow, false, rowIndex)
		g_mouse.bindPress(entryRow, function()
			local now = g_clock.millis()

			if auctionCharacterLastArgumentClick.row == entryRow and now - auctionCharacterLastArgumentClick.time <= 350 then
				auctionCharacterLastArgumentClick.row = nil
				auctionCharacterLastArgumentClick.time = 0

				selectAuctionCharacterArgumentInList(entryRow, entryData, rowIndex)
				confirmAuctionCharacterArgumentFromList(entryData)

				return
			end

			auctionCharacterLastArgumentClick.row = entryRow
			auctionCharacterLastArgumentClick.time = now

			selectAuctionCharacterArgumentInList(entryRow, entryData, rowIndex)
		end, MouseLeftButton)
	end

	function updateAuctionCharacterArgumentSlot(slotIndex)
		if not configAuctionCharacterWindow or configAuctionCharacterWindow:isDestroyed() then
			return
		end

		local headerWindow = configAuctionCharacterWindow.headerWindow

		if not headerWindow or headerWindow:isDestroyed() then
			return
		end

		local button = headerWindow:recursiveGetChildById("selectArgument" .. slotIndex)
		local icon = headerWindow:recursiveGetChildById("selectArgument" .. slotIndex .. "Icon")
		local label = headerWindow:recursiveGetChildById("selectArgument" .. slotIndex .. "Label")

		if not button or button:isDestroyed() then
			return
		end

		local slotData = auctionCharacterHeaderArgumentSlots[slotIndex]

		if slotData then
			button:setImageSource(A.CLEAR_ICON)
			button:setImageClip("0 0 12 12")

			function button.onClick()
				clearAuctionCharacterArgument(slotIndex)
			end

			button:setTooltip(tr("Remove argument"))

			if icon and not icon:isDestroyed() then
				icon:setVisible(true)
				icon:setSize({
					width = A.ICON_SIZE,
					height = A.ICON_SIZE
				})
				applyAuctionCharacterArgumentIcon(icon, slotData.argumentId)
			end

			if label and not label:isDestroyed() then
				label:setText(slotData.value or "")
				label:setColor(getAuctionCharacterArgumentLabelColor(true))
			end
		else
			button:setImageSource(A.SELECT_ICON)
			button:setImageClip("0 0 12 12")

			function button.onClick()
				selectArgumentAuctionCharacter()
			end

			button:setTooltip(tr("Select an outstanding feature of your character"))

			if icon and not icon:isDestroyed() then
				icon:setVisible(false)
				icon:setSize({
					width = 0,
					height = A.ICON_SIZE
				})
			end

			if label and not label:isDestroyed() then
				label:setText(tr("Add sales argument #%d", slotIndex))
				label:setColor(getAuctionCharacterArgumentLabelColor(false))
			end
		end
	end

	function updateAllAuctionCharacterArgumentSlots()
		for slotIndex = 1, A.SLOT_COUNT do
			updateAuctionCharacterArgumentSlot(slotIndex)
		end
	end

	function fillAuctionCharacterArguments()
		if not isAuctionCharacterArgumentPanelActive() then
			return
		end

		local argumentsPanel = getAuctionCharacterSelectArgumentsPanel()

		if not argumentsPanel or argumentsPanel:isDestroyed() then
			return
		end

		argumentsPanel:destroyChildren()

		if type(auctionCharacterArguments) ~= "table" then
			return
		end

		local listSelection = auctionCharacterArgumentListSelection
		local globalRowIndex = 0

		for _, argument in ipairs(auctionCharacterArguments) do
			local entries = argument.entries or {}
			local visibleEntries = {}

			for _, entry in ipairs(entries) do
				local value = entry.value

				if type(value) == "string" then
					value = value:match("^%s*(.-)%s*$")
				end

				if value and value ~= "" then
					local entryData = {
						argumentId = argument.id,
						argumentTitle = argument.title,
						entryIndex = entry.index,
						value = value
					}

					if not isAuctionCharacterArgumentEntryAssigned(entryData) then
						visibleEntries[#visibleEntries + 1] = entryData
					end
				end
			end

			if #visibleEntries > 0 then
				local row = g_ui.createWidget("RowAuctionCharacterArgument", argumentsPanel)

				if not row then
					break
				end

				local titleLabel = row:getChildById("argumentTitle")

				if titleLabel then
					titleLabel:setText(argument.title or "")
				end

				local entriesPanel = row:getChildById("argumentEntries")

				if entriesPanel then
					entriesPanel:setHeight(#visibleEntries * A.ENTRY_HEIGHT)

					for _, entryData in ipairs(visibleEntries) do
						globalRowIndex = globalRowIndex + 1

						local entryRow = g_ui.createWidget("RowAuctionCharacterArgumentEntry", entriesPanel)

						if entryRow then
							local entryIcon = entryRow:getChildById("entryIcon")
							local entryText = entryRow:getChildById("entryText")

							applyAuctionCharacterArgumentEntryIcon(entryIcon, entryData.argumentId)

							if entryText then
								entryText:setText(entryData.value or "")
							end

							bindAuctionCharacterArgumentEntryRow(entryRow, entryData, globalRowIndex)

							if listSelection and isSameAuctionCharacterArgumentEntry(listSelection, entryData) then
								setAuctionCharacterArgumentEntryRowSelected(entryRow, true, globalRowIndex)
							end
						end
					end
				end

				row:setHeight(getAuctionCharacterArgumentRowHeight(#visibleEntries))
			end
		end
	end

	function clearAuctionCharacterArgument(slotIndex)
		slotIndex = tonumber(slotIndex)

		if not slotIndex or slotIndex < 1 or slotIndex > A.SLOT_COUNT then
			return
		end

		if not auctionCharacterHeaderArgumentSlots[slotIndex] then
			return
		end

		for i = slotIndex, A.SLOT_COUNT - 1 do
			auctionCharacterHeaderArgumentSlots[i] = auctionCharacterHeaderArgumentSlots[i + 1]
		end

		auctionCharacterHeaderArgumentSlots[A.SLOT_COUNT] = nil

		updateAllAuctionCharacterArgumentSlots()
		syncAuctionCharacterNextArgumentSlot()

		if isAuctionCharacterArgumentPanelActive() then
			fillAuctionCharacterArguments()
		end
	end

	function selectArgumentAuctionCharacter()
		showAuctionCharacterConfigPanel("argument")

		if auctionCharacterArguments then
			fillAuctionCharacterArguments()
		end
	end

	function confirmAuctionCharacterArgumentSelection()
		if not auctionCharacterArgumentListSelection then
			return
		end

		confirmAuctionCharacterArgumentFromList(auctionCharacterArgumentListSelection)
	end

	function selectArgument(index)
		selectArgumentAuctionCharacter()
	end

	function searchArgumentsAuctionCharacter(text)
		return
	end
end

local function collectAuctionCharacterItems()
	local merged = {}

	local function appendList(list, source)
		if type(list) ~= "table" then
			return
		end

		for _, entry in ipairs(list) do
			local item = parseAuctionCharacterItemEntry(entry)

			if item then
				item.source = source
				merged[#merged + 1] = item
			end
		end
	end

	appendList(auctionCharacterItemsInventory, "inventory")
	appendList(auctionCharacterItemsStore, "store")
	table.sort(merged, function(a, b)
		local nameA = getAuctionCharacterItemName(a.id):lower()
		local nameB = getAuctionCharacterItemName(b.id):lower()

		if nameA == nameB then
			if a.tier == b.tier then
				return a.id < b.id
			end

			return a.tier < b.tier
		end

		return nameA < nameB
	end)

	return merged
end

local function isSameAuctionCharacterItem(a, b)
	if not a or not b then
		return false
	end

	return a.id == b.id and (a.tier or 0) == (b.tier or 0)
end

local function copyAuctionCharacterItemData(itemData)
	if not itemData then
		return nil
	end

	return {
		id = itemData.id,
		tier = itemData.tier or 0,
		count = itemData.count or 1,
		source = itemData.source
	}
end

local function removeAuctionCharacterItemFromPool(itemData)
	local lists = {}

	if itemData.source == "store" then
		lists = {
			auctionCharacterItemsStore
		}
	elseif itemData.source == "inventory" then
		lists = {
			auctionCharacterItemsInventory
		}
	else
		lists = {
			auctionCharacterItemsInventory,
			auctionCharacterItemsStore
		}
	end

	for _, list in ipairs(lists) do
		if type(list) == "table" then
			for i, entry in ipairs(list) do
				local parsed = parseAuctionCharacterItemEntry(entry)

				if isSameAuctionCharacterItem(parsed, itemData) then
					table.remove(list, i)

					return true
				end
			end
		end
	end

	return false
end

local function returnAuctionCharacterItemToPool(itemData)
	if not itemData then
		return
	end

	local list

	if itemData.source == "store" then
		if not auctionCharacterItemsStore then
			auctionCharacterItemsStore = {}
		end

		list = auctionCharacterItemsStore
	else
		if not auctionCharacterItemsInventory then
			auctionCharacterItemsInventory = {}
		end

		list = auctionCharacterItemsInventory
	end

	table.insert(list, {
		itemData.id,
		itemData.tier or 0,
		itemData.count or 1
	})
end

function updateAuctionCharacterHeaderItemSlot(slotIndex)
	if not configAuctionCharacterWindow or configAuctionCharacterWindow:isDestroyed() then
		return
	end

	local headerWindow = configAuctionCharacterWindow.headerWindow

	if not headerWindow or headerWindow:isDestroyed() then
		return
	end

	local button = headerWindow:recursiveGetChildById("selectItem" .. slotIndex)
	local display = headerWindow:recursiveGetChildById("headerItemDisplay" .. slotIndex)
	local clearButton = headerWindow:recursiveGetChildById("clearItemButton" .. slotIndex)

	if not button or button:isDestroyed() then
		return
	end

	local itemData = auctionCharacterHeaderSlots[slotIndex]

	if itemData and display and not display:isDestroyed() then
		local item = Item.create(itemData.id)

		if item then
			if itemData.tier and itemData.tier > 0 and item.setTier then
				item:setTier(itemData.tier)
			end

			if itemData.count and itemData.count > 1 and item.setCount then
				item:setCount(itemData.count)
			end

			display:setItem(item)

			if itemData.count and itemData.count > 1 and display.setItemCount then
				display:setItemCount(itemData.count)
			end

			if ItemsDatabase then
				ItemsDatabase.setRarityItem(display, item, nil, true)
				ItemsDatabase.setTier(display, item)
			end
		end

		display:setVisible(true)
		button:setImageClip("0 0 34 34")
		button:setFocusable(false)
		button:setPhantom(true)

		if clearButton and not clearButton:isDestroyed() then
			clearButton:setVisible(true)
			clearButton:setFocusable(true)
			clearButton:setPhantom(false)
		end
	else
		if display and not display:isDestroyed() then
			display:setItem(nil)
			display:setVisible(false)
		end

		button:setImageClip("0 0 34 34")
		button:setFocusable(true)
		button:setPhantom(false)

		if clearButton and not clearButton:isDestroyed() then
			clearButton:setVisible(false)
			clearButton:setFocusable(false)
		end
	end
end

function updateAllAuctionCharacterHeaderItemSlots()
	for slotIndex = 1, 4 do
		updateAuctionCharacterHeaderItemSlot(slotIndex)
	end
end

local function syncAuctionCharacterNextSlot()
	for slotIndex = 1, 4 do
		if not auctionCharacterHeaderSlots[slotIndex] then
			auctionCharacterNextSlot = slotIndex

			return
		end
	end

	auctionCharacterNextSlot = 1
end

local function assignAuctionCharacterItemToNextSlot(itemData)
	if not itemData then
		return false
	end

	local slot = auctionCharacterNextSlot
	local oldItem = auctionCharacterHeaderSlots[slot]

	if oldItem then
		returnAuctionCharacterItemToPool(oldItem)
	end

	if not removeAuctionCharacterItemFromPool(itemData) then
		return false
	end

	auctionCharacterHeaderSlots[slot] = copyAuctionCharacterItemData(itemData)

	updateAuctionCharacterHeaderItemSlot(slot)
	syncAuctionCharacterNextSlot()

	auctionCharacterListSelection = nil

	showAuctionCharacterConfigPanel("none")

	return true
end

local function confirmAuctionCharacterItemFromList(itemData)
	if not itemData then
		return
	end

	assignAuctionCharacterItemToNextSlot(itemData)
end

local function setAuctionCharacterItemBoxSelected(itemBox, selected)
	if not itemBox or itemBox:isDestroyed() then
		return
	end

	if itemBox.setChecked then
		itemBox:setChecked(selected)
	end

	local overlay = itemBox:getChildById("selectionOverlay")

	if not overlay or overlay:isDestroyed() then
		return
	end

	if selected then
		overlay:setBorderWidthTop(1)
		overlay:setBorderWidthRight(1)
		overlay:setBorderWidthBottom(1)
		overlay:setBorderWidthLeft(1)
		overlay:setBorderColor("#ffffff")
	else
		overlay:setBorderWidth(0)
	end
end

local function clearAuctionCharacterItemListSelection(itemsPanel)
	if not itemsPanel then
		return
	end

	for _, child in ipairs(itemsPanel:getChildren()) do
		setAuctionCharacterItemBoxSelected(child, false)
	end
end

local function selectAuctionCharacterItemInList(itemBox, itemData)
	local itemsPanel = getAuctionCharacterSelectItemsPanel()

	clearAuctionCharacterItemListSelection(itemsPanel)
	setAuctionCharacterItemBoxSelected(itemBox, true)

	auctionCharacterListSelection = copyAuctionCharacterItemData(itemData)
end

local function bindAuctionCharacterItemBox(itemBox, itemData)
	g_mouse.bindPress(itemBox, function()
		local now = g_clock.millis()

		if auctionCharacterLastItemClick.box == itemBox and now - auctionCharacterLastItemClick.time <= 350 then
			auctionCharacterLastItemClick.box = nil
			auctionCharacterLastItemClick.time = 0

			selectAuctionCharacterItemInList(itemBox, itemData)
			confirmAuctionCharacterItemFromList(itemData)

			return
		end

		auctionCharacterLastItemClick.box = itemBox
		auctionCharacterLastItemClick.time = now

		selectAuctionCharacterItemInList(itemBox, itemData)
	end, MouseLeftButton)
end

function refreshAuctionCharacterItemsList(searchFilter)
	if searchFilter ~= nil then
		auctionCharacterItemsSearchFilter = searchFilter:lower()
	end

	if not isAuctionCharacterItemPanelActive() then
		return
	end

	local itemsPanel = getAuctionCharacterSelectItemsPanel()

	if not itemsPanel or itemsPanel:isDestroyed() then
		return
	end

	itemsPanel:destroyChildren()

	local filter = auctionCharacterItemsSearchFilter or ""
	local listSelection = auctionCharacterListSelection

	for _, itemData in ipairs(collectAuctionCharacterItems()) do
		local itemName = getAuctionCharacterItemName(itemData.id)

		if filter == "" or itemName:lower():find(filter, 1, true) then
			local itemBox = g_ui.createWidget("AuctionCharacterItemBox", itemsPanel)

			if not itemBox then
				break
			end

			local slotItem = itemBox:getChildById("item")

			if slotItem then
				local item = Item.create(itemData.id)

				if item then
					if itemData.tier and itemData.tier > 0 and item.setTier then
						item:setTier(itemData.tier)
					end

					if itemData.count and itemData.count > 1 and item.setCount then
						item:setCount(itemData.count)
					end

					slotItem:setItem(item)

					if itemData.count and itemData.count > 1 and slotItem.setItemCount then
						slotItem:setItemCount(itemData.count)
					end

					if ItemsDatabase then
						ItemsDatabase.setRarityItem(slotItem, item, nil, true)
						ItemsDatabase.setTier(slotItem, item)
					end
				end
			end

			if itemName ~= "" then
				itemBox:setTooltip(itemName)
			end

			bindAuctionCharacterItemBox(itemBox, itemData)

			if isSameAuctionCharacterItem(listSelection, itemData) then
				setAuctionCharacterItemBoxSelected(itemBox, true)
			end
		end
	end
end

function onAuctionCharacterItemsInventory(items)
	auctionCharacterItemsInventory = items

	scheduleAuctionCharacterItemsRefresh()
end

function onAuctionCharacterItemsStore(items)
	auctionCharacterItemsStore = items

	scheduleAuctionCharacterItemsRefresh()
end

function onAuctionCharacterArguments(arguments)
	local grouped = {}

	for _, entry in ipairs(arguments) do
		local argumentId = tonumber(entry[1])
		local argumentTitle = entry[2]
		local entryIndex = tonumber(entry[3])
		local entryValue = entry[4]

		if argumentId then
			local argument = grouped[argumentId]

			if not argument then
				argument = {
					id = argumentId,
					title = argumentTitle,
					entries = {}
				}
				grouped[argumentId] = argument
			end

			table.insert(argument.entries, {
				index = entryIndex,
				value = entryValue
			})
		end
	end

	auctionCharacterArguments = {}

	for _, argument in pairs(grouped) do
		table.sort(argument.entries, function(a, b)
			return (a.index or 0) < (b.index or 0)
		end)
		table.insert(auctionCharacterArguments, argument)
	end

	table.sort(auctionCharacterArguments, function(a, b)
		local titleA = (a.title or ""):lower()
		local titleB = (b.title or ""):lower()

		if titleA == titleB then
			return (a.id or 0) < (b.id or 0)
		end

		return titleA < titleB
	end)
	fillAuctionCharacterArguments()
end

function searchItemsAuctionCharacter(text)
	if auctionCharacterSearchRefreshEvent then
		removeEvent(auctionCharacterSearchRefreshEvent)
	end

	auctionCharacterSearchRefreshEvent = scheduleEvent(function()
		auctionCharacterSearchRefreshEvent = nil

		refreshAuctionCharacterItemsList(text or "")
	end, 150)
end

function clearAuctionCharacterItem(slotIndex)
	slotIndex = tonumber(slotIndex)

	if not slotIndex or slotIndex < 1 or slotIndex > 4 then
		return
	end

	local itemData = auctionCharacterHeaderSlots[slotIndex]

	if not itemData then
		return
	end

	returnAuctionCharacterItemToPool(itemData)

	for i = slotIndex, 3 do
		auctionCharacterHeaderSlots[i] = auctionCharacterHeaderSlots[i + 1]
	end

	auctionCharacterHeaderSlots[4] = nil

	updateAllAuctionCharacterHeaderItemSlots()
	syncAuctionCharacterNextSlot()

	if isAuctionCharacterItemPanelActive() then
		scheduleAuctionCharacterItemsRefresh()
	end
end

function selectItemAuctionCharacter()
	showAuctionCharacterConfigPanel("item")

	if auctionCharacterItemsInventory and auctionCharacterItemsStore then
		scheduleAuctionCharacterItemsRefresh()
	end
end

function confirmAuctionCharacterItemSelection()
	if not auctionCharacterListSelection then
		return
	end

	confirmAuctionCharacterItemFromList(auctionCharacterListSelection)
end

function selectEndAuctionDate()
	initAuctionCharacterCalendarFromHeaderData()
	showAuctionCharacterConfigPanel("date")
	bindAuctionCharacterTimeComboHandlers()
	updateAuctionCharacterDateConfigLabel()
	updateAuctionCharacterCalendar()
	syncAuctionCharacterTimeCombos(true)
end

function confirmAuctionCharacterDateSelection()
	if auctionCharacterSelectedTimestamp then
		updateAuctionCharacterEndDateLabels()
	end

	showAuctionCharacterConfigPanel("none")
end

function confirmAuctionCharacterConfigOk()
	if auctionCharacterConfigPanel == "item" then
		confirmAuctionCharacterItemSelection()
	elseif auctionCharacterConfigPanel == "argument" then
		confirmAuctionCharacterArgumentSelection()
	elseif auctionCharacterConfigPanel == "date" then
		confirmAuctionCharacterDateSelection()
	else
		showAuctionCharacterConfigPanel("none")
	end
end

function confirmAuctionCharacter()
	if not AUCTION_MIN_OFFER_PRICE then
		print("[Erro] Variável AUCTION_MIN_OFFER_PRICE não existe.")

		return
	end

	if not configAuctionCharacterWindow then
		print("[Erro] configAuctionCharacterWindow não existe.")

		return
	end

	if not auctionCharacterHeaderSlots then
		print("[Erro] auctionCharacterHeaderSlots não existe.")

		return
	end

	if not auctionCharacterHeaderArgumentSlots then
		print("[Erro] auctionCharacterHeaderArgumentSlots não existe.")

		return
	end

	if not g_game or not g_game.sendCharacterAuction then
		print("[Erro] g_game ou g_game.sendCharacterAuction não existe.")

		return
	end

	local startBid = AUCTION_MIN_OFFER_PRICE

	if configAuctionCharacterWindow and not configAuctionCharacterWindow:isDestroyed() then
		if not configAuctionCharacterWindow.headerWindow then
			print("[Erro] headerWindow não existe em configAuctionCharacterWindow.")

			return
		end

		local edit = configAuctionCharacterWindow.headerWindow.offertPriceEdit

		if not edit then
			print("[Erro] offertPriceEdit não existe em headerWindow.")

			return
		end

		local value = tonumber(edit:getText())

		if not value then
			print("[Erro] Valor do campo de preço inicial inválido ou vazio.")

			return
		end

		if value < AUCTION_MIN_OFFER_PRICE then
			print("[Erro] Valor do lance inicial abaixo do mínimo permitido.")

			return
		end

		if value == 0 then
			print("[Erro] Valor do lance inicial não pode ser zero.")

			return
		end

		startBid = value
	else
		print("[Erro] Janela principal de configuração do leilão não está aberta ou foi destruída.")

		return
	end

	local endTimestamp = auctionCharacterSelectedTimestamp

	if not endTimestamp then
		if not auctionCharacterHeaderData then
			print("[Erro] auctionCharacterHeaderData não existe.")

			return
		end

		if not auctionCharacterHeaderData.dataMin then
			print("[Erro] auctionCharacterHeaderData.dataMin não existe.")

			return
		end

		endTimestamp = tonumber(auctionCharacterHeaderData.dataMin)

		if not endTimestamp or endTimestamp == 0 then
			print("[Erro] Timestamp de término do leilão inválido (zero ou nulo).")

			return
		end
	end

	if endTimestamp == 0 then
		print("[Erro] Timestamp de término do leilão não pode ser zero.")

		return
	end

	local inventoryItems = {}
	local storeItems = {}

	for slotIndex = 1, 4 do
		local itemData = auctionCharacterHeaderSlots[slotIndex]

		if itemData then
			if not itemData.id then
				print("[Erro] Slot de item #" .. slotIndex .. " não possui id.")

				return
			end

			if itemData.id == 0 then
				print("[Erro] Slot de item #" .. slotIndex .. " id não pode ser zero.")

				return
			end

			local tier = itemData.tier or 0

			if itemData.source == "store" then
				storeItems[itemData.id] = tier
			else
				inventoryItems[itemData.id] = tier
			end
		end
	end

	local arguments = {}

	for slotIndex = 1, 5 do
		local argumentData = auctionCharacterHeaderArgumentSlots[slotIndex]

		if argumentData then
			if not argumentData.entryIndex then
				print("[Erro] Argumento de slot #" .. slotIndex .. " sem entryIndex.")

				return
			end

			if argumentData.entryIndex == 0 then
				print("[Erro] entryIndex do argumento de slot #" .. slotIndex .. " não pode ser zero.")

				return
			end

			table.insert(arguments, argumentData.entryIndex)
		end
	end

	if startBid == 0 then
		print("[Erro] startBid não pode ser zero.")

		return
	end

	if endTimestamp == 0 then
		print("[Erro] endTimestamp não pode ser zero.")

		return
	end

	g_game.sendCharacterAuction({
		startBid = startBid,
		endTimestamp = endTimestamp,
		inventoryItems = inventoryItems,
		storeItems = storeItems,
		arguments = arguments
	})
	destroyAllAuctionCharacterWindows()
	hide()
end
