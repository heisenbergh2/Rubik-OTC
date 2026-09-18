-- chunkname: @/corelib/ui/uicalendar.lua

UICalendar = extends(UIWidget, "UICalendar")

local MONTH_TEXT_CURRENT = "#c0c0c0"
local MONTH_TEXT_OTHER = "#909090"
local MONTH_FILL_CURRENT = "#484848ff"
local MONTH_FILL_OTHER = "#414141ff"
local MONTH_FILL_HIGHLIGHT = "#585858ff"

function UICalendar.create(title, okCallback, cancelCallback)
	local calendar = UICalendar.internalCreate()

	return calendar
end

local function lockFillBackground(cell, color)
	local fill = cell:recursiveGetChildById("fill")

	if not fill or not color then
		return
	end

	fill:setOn(false)
	fill:setBackgroundColor(color)

	if fill._calendarFillLocked then
		return
	end

	fill._calendarFillLocked = true

	connect(fill, {
		onStyleApply = function(widget)
			widget:setOn(false)
			widget:setBackgroundColor(cell.scheduleFillColor or cell._cellFillColor)
		end
	})

	if not cell._calendarFillLocked then
		cell._calendarFillLocked = true

		connect(cell, {
			onStyleApply = function()
				lockFillBackground(cell, cell.scheduleFillColor or cell._cellFillColor)
			end
		})
	end
end

function UICalendar:onSetup()
	if not self.scheduleFillColor then
		self:setOn(self:isEnabled())
	else
		self:setOn(false)
	end

	for _, children in ipairs(self:getChildren()) do
		if self.disableLeftBright ~= nil then
			children.disableLeftBright = self.disableLeftBright
		end

		if self.weekName ~= nil then
			children.weekName = self.weekName
		end

		if self.dayOfTheWeek ~= nil then
			children.dayOfTheWeek = self.dayOfTheWeek
		end

		if self:getParent() and self:getParent().dayOfTheWeek ~= nil then
			self.dayOfTheWeek = self:getParent().dayOfTheWeek
		end

		if self:getParent() and self:getParent().disableLeftBright ~= nil then
			self.disableLeftBright = self:getParent().disableLeftBright
		end

		if self:getParent() and self:getParent().weekName ~= nil then
			self.weekName = self:getParent().weekName
		end

		if self.hideRightSeparator ~= nil then
			children.hideRightSeparator = self.hideRightSeparator
		end

		if self:getParent() and self:getParent().hideRightSeparator ~= nil then
			self.hideRightSeparator = self:getParent().hideRightSeparator
		end

		if children:getId() == "week" and children.weekName ~= nil then
			children:setText(children.weekName)
		elseif children:getId() == "brightColumn" then
			children:setOn(not self.disableLeftBright)
		elseif children:getId() == "columnRightSeparator" then
			children:setVisible(not self.hideRightSeparator)
		elseif children:getId() == "dayAndSeason" then
			for _, innerChildren in ipairs(children:getChildren()) do
				if innerChildren:getId() == "day" then
					if self.dayOfTheWeek ~= nil then
						innerChildren:setOn(true)
						innerChildren:setWidth(string.len(innerChildren:getText()) * 10)
					else
						innerChildren:setOn(false)
					end
				end
			end
		elseif children:getId() == "fill" then
			local color = self.scheduleFillColor or self._cellFillColor

			if color then
				lockFillBackground(self, color)
			end
		else
			children:setOn(self:isEnabled())
		end
	end
end

function UICalendar:onStyleApply(styleName, styleNode)
	local color = self.scheduleFillColor or self._cellFillColor

	if color then
		lockFillBackground(self, color)
	end
end

function UICalendar:applyScheduleFillColor()
	if self.scheduleFillColor then
		lockFillBackground(self, self.scheduleFillColor)
	end
end

function UICalendar:applyMonthCellStyle(isCurrentMonth, isToday)
	if self.scheduleFillColor then
		return
	end

	isToday = isToday or false
	self._cellFillColor = isToday and MONTH_FILL_HIGHLIGHT or isCurrentMonth and MONTH_FILL_CURRENT or MONTH_FILL_OTHER

	lockFillBackground(self, self._cellFillColor)

	local day = self:recursiveGetChildById("day")

	if day then
		day:setColor((isCurrentMonth or isToday) and MONTH_TEXT_CURRENT or MONTH_TEXT_OTHER)
	end
end

function UICalendar:addScheduleEvent(event, active, onClick)
	local content = self:getChildById("content")

	if not content then
		return
	end

	if #content:getChildren() == 4 then
		return
	end

	local widget = g_ui.createWidget("CalendarEvent", content)

	if onClick then
		connect(widget, {
			onClick = function()
				onClick()
			end
		})
	end

	if event.season then
		widget:getParent():getParent():recursiveGetChildById("dayAndSeason"):setOn(true)
		widget:getParent():getParent():recursiveGetChildById("season"):setOn(true)
	end

	if active then
		widget:setBackgroundColor(event.active)
	else
		widget:setBackgroundColor(event.inactive)
	end

	if #content:getChildren() == 1 then
		widget:addAnchor(AnchorTop, "parent", AnchorTop)
		widget:setMarginTop(0)
	else
		widget:addAnchor(AnchorTop, "prev", AnchorBottom)
		widget:setMarginTop(3)
	end

	local special = {}

	table.insert(special, {
		header = event.name .. ":",
		info = event.description
	})
	widget:setSpecialToolTip(special)

	widget.text = widget:getChildById("text")

	local eventText = event.name

	if event.firstDay or event.lastDay then
		eventText = "*" .. eventText

		if string.len(eventText) > 13 then
			eventText = string.sub(eventText, 1, 13) .. "..."
		end
	elseif string.len(eventText) > 13 then
		eventText = string.sub(eventText, 1, 13) .. "..."
	end

	widget.text:setText(eventText)
	widget.text:setColor(active and MONTH_TEXT_CURRENT or MONTH_TEXT_OTHER)
	widget.text:setOpacity(1)
end

function UICalendar:clearEvents()
	local content = self:getChildById("content")

	if not content then
		return
	end

	content:destroyChildren()
	self:recursiveGetChildById("season"):setOn(false)
	self:recursiveGetChildById("dayAndSeason"):setOn(false)
end
