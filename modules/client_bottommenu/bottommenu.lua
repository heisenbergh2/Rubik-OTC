-- chunkname: @/client_bottommenu/bottommenu.lua

local bottomMenu, calendarWindow, activeScheduleEvent, upcomingScheduleEvent, eventSchedulerYears, calendarCurrentMonth, calendarPrevButton, calendarNextButton, calendarCurrentDate, showOffWindow, eventSchedulerTimestamp, eventSchedulerCalendar, eventSchedulerCalendarYearIndex, eventSchedulerCalendarMonth, boostedWindow, monsterOutfit, monsterImage, bossOutfit, bossImage, eventScheduleButton
local BOOSTED_WALK_SPEED = 1000
local default_info = {
	{
		description = "If you have checked 'Ask Before Buying Products', a confirmation dialog will open up whenever you try to buy something via the Store.\nIf you uncheck that box, a click on 'Buy Now' will get you the selected product without any delay.",
		Title = "General Game Options",
		image = "images/randomhint"
	}
}

function init()
	g_ui.importStyle("calendar")

	bottomMenu = g_ui.displayUI("bottommenu")
	calendarWindow = g_ui.createWidget("CalendarGrid", rootWidget)

	local calendarWidget = calendarWindow:recursiveGetChildById("calendarWidget")

	if calendarWidget then
		calendarWidget:setFixedSize(true)
	end

	calendarCurrentMonth = calendarWindow:recursiveGetChildById("calendarCurrentMonth")
	calendarCurrentDate = calendarWindow:recursiveGetChildById("calendarCurrentDate")
	calendarPrevButton = calendarWindow:recursiveGetChildById("calendarPrevButton")
	calendarNextButton = calendarWindow:recursiveGetChildById("calendarNextButton")

	calendarWindow:hide()

	showOffWindow = bottomMenu:recursiveGetChildById("showOffWindow")
	showOffWindow.title = showOffWindow:recursiveGetChildById("showOffWindowText")

	local eventsContainer = bottomMenu:recursiveGetChildById("eventsContainer")

	if eventsContainer then
		eventsContainer:setFixedSize(true)
	end

	activeScheduleEvent = bottomMenu:recursiveGetChildById("activeScheduleEvent")
	upcomingScheduleEvent = bottomMenu:recursiveGetChildById("upcomingScheduleEvent")

	if activeScheduleEvent then
		activeScheduleEvent.scheduleFillColor = "#585858ff"

		activeScheduleEvent:applyScheduleFillColor()

		local content = activeScheduleEvent:getChildById("content")

		if content then
			content:setMarginRight(0)
		end
	end

	if upcomingScheduleEvent then
		local content = upcomingScheduleEvent:getChildById("content")

		if content then
			content:setMarginRight(0)
		end

		upcomingScheduleEvent._cellFillColor = "#414141ff"

		upcomingScheduleEvent:applyMonthCellStyle(false, false)
	end

	eventSchedulerCalendarYearIndex = 1
	eventSchedulerCalendarMonth = tonumber(os.date("%m"))
	boostedWindow = bottomMenu:recursiveGetChildById("boostedWindow")
	monsterOutfit = boostedWindow:recursiveGetChildById("creature")
	bossOutfit = boostedWindow:recursiveGetChildById("boss")

	if default_info then
		local scrollable = showOffWindow:recursiveGetChildById("contentsPanel")
		local widget = g_ui.createWidget("ShowOffWidget", scrollable)
		local description = widget:recursiveGetChildById("description")
		local image = widget:recursiveGetChildById("image")

		math.randomseed(os.time())

		local randomIndex = math.random(1, #default_info)
		local randomItem = default_info[randomIndex]

		showOffWindow.title:setText(tr(randomItem.Title))
		image:setImageSource(randomItem.image)
		description:setText(tr(randomItem.description))
		monsterOutfit:setVisible(false)
		bossOutfit:setVisible(false)
		widget:resize(widget:getWidth(), description:getHeight())

		monsterImage = boostedWindow:recursiveGetChildById("monsterImage")
		bossImage = boostedWindow:recursiveGetChildById("bossImage")

		monsterImage:setImageSource("images/icon-questionmark")
		monsterImage:setVisible(true)
		bossImage:setImageSource("images/icon-questionmark")
		bossImage:setVisible(true)
	end

	connect(g_game, {
		onGameStart = onGameStart,
		onGameEnd = onGameEnd
	})

	if g_game.isOnline() then
		hide()
		onGameStart()
	else
		hide()
	end
end

function onGameStart()
	if not modules.game_mainpanel or eventScheduleButton then
		return
	end

	eventScheduleButton = modules.game_mainpanel.addToggleButton("eventScheduleButton", tr("Open Event Schedule"), "/images/options/button_calendar", onClickOnCalendar, false, 22)

	if modules.client_options and modules.client_options.refreshShortcuts then
		modules.client_options.refreshShortcuts()
	end
end

function onGameEnd()
	if calendarWindow and not calendarWindow:isHidden() then
		onClickCloseCalendar()
	end
end

function terminate()
	disconnect(g_game, {
		onGameStart = onGameStart,
		onGameEnd = onGameEnd
	})

	if eventScheduleButton then
		eventScheduleButton:destroy()

		eventScheduleButton = nil
	end

	g_modalManager.hide(calendarWindow)
	bottomMenu:destroy()
	calendarWindow:destroy()
end

function hide()
	bottomMenu:hide()
	bottomMenu:lower()

	if not calendarWindow:isHidden() then
		onClickCloseCalendar()
	end
end

function show()
	bottomMenu:show()
	bottomMenu:raise()
end

function setShowOffData(data)
	local widget = g_ui.createWidget("ShowOffWidget", showOffWindow)
	local image = widget:recursiveGetChildById("image")

	if data.image and data.image:sub(1, 4):lower() == "http" then
		HTTP.downloadImage(data.image, function(path, err)
			if err then
				g_logger.warning("HTTP error: " .. err .. " - " .. data.image)

				return
			end

			image:setImageSource(path)
		end)
	else
		image:setImage(data.image)
	end

	local description = widget:recursiveGetChildById("description")

	showOffWindow.title:setText(tr(data.title))
	description:setText(tr(data.description))
end

function onClickOnCalendar()
	if eventSchedulerYears == nil or #eventSchedulerYears == 0 then
		return
	end

	calendarWindow:show()
	calendarWindow:raise()
	g_modalManager.show(calendarWindow)
	calendarWindow:centerIn("parent")
	calendarWindow:removeAnchor(AnchorHorizontalCenter)
	calendarWindow:removeAnchor(AnchorVerticalCenter)
	reloadEventsSchedulerCurrentPage()

	if eventScheduleButton then
		eventScheduleButton:setOn(true)
	end

	if activeScheduleEvent then
		activeScheduleEvent:applyScheduleFillColor()
	end
end

function onClickCloseCalendar()
	g_modalManager.hide(calendarWindow)
	calendarWindow:hide()
	calendarWindow:lower()

	if eventScheduleButton then
		eventScheduleButton:setOn(false)
	end

	if activeScheduleEvent then
		activeScheduleEvent:applyScheduleFillColor()
	end
end

function setEventsSchedulerTimestamp(time)
	eventSchedulerTimestamp = time

	calendarCurrentDate:setText(os.date("%Y-%m-%d, %H:%M BRA", eventSchedulerTimestamp))
end

function getCalendarEventWidgetByDay(day, month, year, weekOffset, forceLine)
	local weekIndex = getDayOfWeek(day, month, year)
	local row = calendarWindow:recursiveGetChildById("row" .. weekIndex)

	if not row then
		return nil
	end

	local lineIndex

	if forceLine ~= nil then
		lineIndex = forceLine
	else
		lineIndex = math.floor((weekOffset + day - 1) / 7)
	end

	local line = row:recursiveGetChildById("line" .. lineIndex)

	if not line then
		return nil
	end

	return line
end

local function isCalendarToday(day, month, year)
	if not day or not month or not year then
		return false
	end

	local now = os.time()

	return day == tonumber(os.date("%d", now)) and month == tonumber(os.date("%m", now)) and year == tonumber(os.date("%Y", now))
end

function reloadEventsSchedulerCurrentPage()
	local firstDayOffset = getDayOfWeek(1)

	if firstDayOffset == 0 then
		firstDayOffset = 7
	end

	local weekOffset = firstDayOffset - 1

	if weekOffset > 0 then
		local previousYearIndex = eventSchedulerCalendarYearIndex
		local previousMonth = eventSchedulerCalendarMonth

		if previousMonth == 1 then
			previousYearIndex = previousYearIndex - 1
			previousMonth = 12
		else
			previousMonth = previousMonth - 1
		end

		if previousYearIndex >= 0 then
			local previousDays = eventSchedulerYears[previousYearIndex][previousMonth]
			local amountsLeft = weekOffset
			local i = #previousDays

			while amountsLeft > 0 do
				local previousYear = tonumber(os.date("%Y", os.time())) + (previousYearIndex - 1)
				local widget = getCalendarEventWidgetByDay(i, previousMonth, previousYear, weekOffset, 0)

				if widget then
					widget:clearEvents()

					widget.dayOfTheWeek = i

					widget:recursiveGetChildById("dayAndSeason"):setOn(true)
					widget:recursiveGetChildById("day"):setText(i)
					widget:recursiveGetChildById("day"):setWidth(string.len(widget:recursiveGetChildById("day"):getText()) * 10)
					widget:applyMonthCellStyle(false, isCalendarToday(i, previousMonth, previousYear))

					for _, event in ipairs(previousDays[i]) do
						widget:addScheduleEvent(event, false, nil)
					end
				end

				amountsLeft = amountsLeft - 1
				i = i - 1
			end
		end
	end

	local days = eventSchedulerYears[eventSchedulerCalendarYearIndex][eventSchedulerCalendarMonth]
	local lastDayOffset = getDayOfWeek(#days)

	if lastDayOffset == 0 then
		lastDayOffset = 7
	end

	local nextWeekOffset = 7 - lastDayOffset
	local nextYearIndex = eventSchedulerCalendarYearIndex
	local nextMonth = eventSchedulerCalendarMonth

	if nextMonth == 12 then
		nextYearIndex = nextYearIndex + 1
		nextMonth = 1
	else
		nextMonth = nextMonth + 1
	end

	if nextYearIndex <= 2 then
		local nextDays = eventSchedulerYears[nextYearIndex][nextMonth]
		local amountsLeft = nextWeekOffset
		local i = 1
		local forceLine = 4

		if firstDayOffset >= 5 then
			forceLine = 5
		end

		if firstDayOffset <= 5 then
			amountsLeft = amountsLeft + 7
		end

		while amountsLeft > 0 do
			if forceLine == 4 and amountsLeft == 7 then
				forceLine = 5
			end

			local nextYear = tonumber(os.date("%Y", os.time())) + (nextYearIndex - 1)
			local widget = getCalendarEventWidgetByDay(i, nextMonth, nextYear, nextWeekOffset, forceLine)

			if widget then
				widget:clearEvents()

				widget.dayOfTheWeek = i

				widget:recursiveGetChildById("dayAndSeason"):setOn(true)
				widget:recursiveGetChildById("day"):setText(i)
				widget:recursiveGetChildById("day"):setWidth(string.len(widget:recursiveGetChildById("day"):getText()) * 10)
				widget:applyMonthCellStyle(false, isCalendarToday(i, nextMonth, nextYear))

				for _, event in ipairs(nextDays[i]) do
					widget:addScheduleEvent(event, false, nil)
				end
			end

			amountsLeft = amountsLeft - 1
			i = i + 1
		end
	end

	local viewedYear = tonumber(os.date("%Y", os.time())) + (eventSchedulerCalendarYearIndex - 1)

	for day, events in ipairs(days) do
		local widget = getCalendarEventWidgetByDay(day, nil, nil, weekOffset, nil)

		if widget then
			widget:clearEvents()

			widget.dayOfTheWeek = day

			widget:recursiveGetChildById("dayAndSeason"):setOn(true)
			widget:recursiveGetChildById("day"):setText(tr(day))
			widget:recursiveGetChildById("day"):setWidth(string.len(widget:recursiveGetChildById("day"):getText()) * 10)
			widget:applyMonthCellStyle(true, isCalendarToday(day, eventSchedulerCalendarMonth, viewedYear))

			for _, event in ipairs(events) do
				widget:addScheduleEvent(event, true, nil)
			end
		end
	end

	calendarCurrentMonth:setText(os.date("%B", os.time({
		year = 2023,
		day = 1,
		month = eventSchedulerCalendarMonth
	})) .. " " .. tonumber(os.date("%Y", os.time())) + (eventSchedulerCalendarYearIndex - 1))
end

local function sortCalendarDayEventsByStartTime(calendar)
	if not calendar then
		return
	end

	for month = 1, 12 do
		local monthDays = calendar[month]

		if not monthDays then
			-- block empty
		else
			for dayNum = 1, 31 do
				local events = monthDays[dayNum]

				if events and #events > 1 then
					table.sort(events, function(a, b)
						return (a.startTimestamp or 0) < (b.startTimestamp or 0)
					end)
				end
			end
		end
	end
end

function reloadEventsSchedulerCalender()
	eventSchedulerYears = {}

	table.insert(eventSchedulerYears, createCalendar(tonumber(os.date("%Y", os.time()))))
	table.insert(eventSchedulerYears, createCalendar(tonumber(os.date("%Y", os.time())) + 1))

	if eventSchedulerCalendar == nil or #eventSchedulerCalendar == 0 then
		return
	end

	local function convertStringToTime(dateString)
		if type(dateString) ~= "string" then
			return nil
		end

		local year, month, day, hour, min, sec = dateString:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")

		if not year then
			return nil
		end

		return os.time({
			year = tonumber(year),
			month = tonumber(month),
			day = tonumber(day),
			hour = tonumber(hour),
			min = tonumber(min),
			sec = tonumber(sec)
		})
	end

	local function toTimestamp(value)
		if type(value) == "number" then
			return value
		end

		if type(value) == "string" then
			return convertStringToTime(value) or tonumber(value)
		end

		if type(value) == "table" then
			if value.date then
				return convertStringToTime(value.date) or tonumber(value.date)
			end

			if value.timestamp then
				return tonumber(value.timestamp)
			end
		end

		return nil
	end

	local now = os.time()
	local upcomingWindow = 432000
	local activeEvents = {}
	local upcomingEvents = {}

	for _, info in ipairs(eventSchedulerCalendar) do
		local startTimestamp = toTimestamp(info.startdate)
		local endTimestamp = toTimestamp(info.enddate)

		if not startTimestamp or not endTimestamp then
			-- block empty
		else
			local eventData = {
				lastDay = false,
				firstDay = false,
				active = info.colorlight .. "ff",
				inactive = info.colordark .. "ff",
				description = info.description,
				priority = info.displaypriority,
				season = info.isseasonal,
				name = info.name,
				special = info.specialevent
			}

			if startTimestamp <= now and now <= endTimestamp then
				table.insert(activeEvents, eventData)
			elseif now < startTimestamp and startTimestamp <= now + upcomingWindow then
				table.insert(upcomingEvents, eventData)
			end

			local days = getCalendarDays(startTimestamp, endTimestamp)

			for index, day in ipairs(days) do
				table.insert(day, {
					active = info.colorlight .. "ff",
					inactive = info.colordark .. "ff",
					description = info.description,
					priority = info.displaypriority,
					season = info.isseasonal,
					name = info.name,
					special = info.specialevent,
					startTimestamp = startTimestamp,
					firstDay = index == 1,
					lastDay = index == #days
				})
			end
		end
	end

	for _, yearCalendar in ipairs(eventSchedulerYears) do
		sortCalendarDayEventsByStartTime(yearCalendar)
	end

	activeScheduleEvent:clearEvents()

	for _, event in ipairs(activeEvents) do
		activeScheduleEvent:addScheduleEvent(event, true, onClickOnCalendar)
	end

	upcomingScheduleEvent:clearEvents()

	for _, event in ipairs(upcomingEvents) do
		upcomingScheduleEvent:addScheduleEvent(event, false, onClickOnCalendar)
	end

	if activeScheduleEvent then
		activeScheduleEvent:applyScheduleFillColor()
	end

	if upcomingScheduleEvent and upcomingScheduleEvent._cellFillColor then
		upcomingScheduleEvent:applyMonthCellStyle(false, false)
	end
end

function setEventsSchedulerCalender(calender)
	eventSchedulerCalendar = calender

	reloadEventsSchedulerCalender()

	if eventSchedulerYears and #eventSchedulerYears > 0 then
		reloadEventsSchedulerCurrentPage()
	end
end

function createCalendar(year)
	local calendar = {}

	for month = 1, 12 do
		calendar[month] = {}

		local daysInMonth = 31

		if month == 2 then
			if year % 4 == 0 and year % 100 ~= 0 or year % 400 == 0 then
				daysInMonth = 29
			else
				daysInMonth = 28
			end
		elseif month == 4 or month == 6 or month == 9 or month == 11 then
			daysInMonth = 30
		end

		for day = 1, daysInMonth do
			calendar[month][day] = {}
		end
	end

	return calendar
end

function getCalendarDays(startTimestamp, endTimestamp)
	local currentYear = tonumber(os.date("%Y", os.time()))
	local startYear = tonumber(os.date("%Y", startTimestamp))
	local endYear = tonumber(os.date("%Y", endTimestamp))
	local daysInRange = {}

	if startYear ~= currentYear and startYear ~= currentYear + 1 then
		return daysInRange
	end

	if endYear ~= currentYear and endYear ~= currentYear + 1 then
		return daysInRange
	end

	local startMonth = tonumber(os.date("%m", startTimestamp))
	local startDay = tonumber(os.date("%d", startTimestamp))
	local endMonth = tonumber(os.date("%m", endTimestamp))
	local endDay = tonumber(os.date("%d", endTimestamp))

	if startYear == currentYear then
		for month = startMonth, endMonth do
			local startLoop = 1
			local endLoop = 31

			if month == startMonth then
				startLoop = startDay
			end

			if month == endMonth then
				endLoop = endDay
			end

			if eventSchedulerYears[1][month] then
				for day = startLoop, endLoop do
					if eventSchedulerYears[1][month][day] then
						table.insert(daysInRange, eventSchedulerYears[1][month][day])
					end
				end
			end
		end
	else
		for month = startMonth, 12 do
			local startLoop = 1
			local endLoop = 31

			if month == startMonth then
				startLoop = startDay
			end

			if month == endMonth then
				endLoop = endDay
			end

			if eventSchedulerYears[1][month] then
				for day = startLoop, endLoop do
					if eventSchedulerYears[1][month][day] then
						table.insert(daysInRange, eventSchedulerYears[1][month][day])
					end
				end
			end
		end

		for month = 1, endMonth do
			local startLoop = 1
			local endLoop = 31

			if month == startMonth then
				startLoop = startDay
			end

			if month == endMonth then
				endLoop = endDay
			end

			if eventSchedulerYears[2][month] then
				for day = startLoop, endLoop do
					if eventSchedulerYears[2][month][day] then
						table.insert(daysInRange, eventSchedulerYears[2][month][day])
					end
				end
			end
		end
	end

	return daysInRange
end

function getDayOfWeek(day, month, year)
	year = year or tonumber(os.date("%Y", os.time())) + (eventSchedulerCalendarYearIndex - 1)
	month = month or eventSchedulerCalendarMonth

	local timestamp = os.time({
		year = year,
		month = month,
		day = day
	})
	local weekday = tonumber(os.date("%w", timestamp))

	return weekday
end

function onClickOnPreviousCalendar()
	if eventSchedulerCalendarMonth == 1 then
		if eventSchedulerCalendarYearIndex == 1 then
			return
		end

		eventSchedulerCalendarMonth = 12
		eventSchedulerCalendarYearIndex = eventSchedulerCalendarYearIndex - 1
	else
		eventSchedulerCalendarMonth = eventSchedulerCalendarMonth - 1
	end

	calendarNextButton:setEnabled(true)

	if eventSchedulerCalendarYearIndex == 1 and eventSchedulerCalendarMonth == tonumber(os.date("%m", os.time())) - 1 then
		calendarPrevButton:setEnabled(false)
	else
		calendarPrevButton:setEnabled(true)
	end

	reloadEventsSchedulerCurrentPage()
end

function onClickOnNextCalendar()
	if eventSchedulerCalendarMonth == 12 then
		if eventSchedulerCalendarYearIndex == 2 then
			return
		end

		eventSchedulerCalendarMonth = 1
		eventSchedulerCalendarYearIndex = eventSchedulerCalendarYearIndex + 1
	else
		eventSchedulerCalendarMonth = eventSchedulerCalendarMonth + 1
	end

	calendarPrevButton:setEnabled(true)

	if eventSchedulerCalendarYearIndex == 2 and eventSchedulerCalendarMonth == tonumber(os.date("%m", os.time())) - 1 then
		calendarNextButton:setEnabled(false)
	else
		calendarNextButton:setEnabled(true)
	end

	reloadEventsSchedulerCurrentPage()
end

local function startBoostedAnimation(outfitWidget)
	local creature = outfitWidget and outfitWidget:getCreature()

	if not creature then
		return
	end

	creature:setAnimate(true)
	creature:setStaticWalking(BOOSTED_WALK_SPEED)
end

local function applyToBoostedSlot(raceId, outfitWidget, imageWidget, fileName)
	if not raceId then
		return
	end

	local raceData = g_things.getRaceData(raceId)

	if raceData.raceId == 0 then
		local msg = string.format("[%s] Creature with race id %s was not found.", fileName, raceId)

		g_logger.warning(msg)

		return
	end

	outfitWidget:setOutfit(raceData.outfit)
	outfitWidget:setVisible(true)
	imageWidget:setVisible(false)
	startBoostedAnimation(outfitWidget)
end

function setBoostedCreatureAndBoss(data)
	if not modules.game_things.isLoaded() then
		return
	end

	local fileName = "bottommenu.lua"

	applyToBoostedSlot(data.creatureraceid or data.raceid, monsterOutfit, monsterImage, fileName)
	applyToBoostedSlot(data.bossraceid, bossOutfit, bossImage, fileName)
end
