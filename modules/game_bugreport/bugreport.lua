-- chunkname: @/game_bugreport/bugreport.lua

HOTKEY = "Ctrl+Z"
BUG_CATEGORY_MAP = 0
BUG_REPORT_MAX_LENGTH = 500
bugReportWindow = nil
bugTextEdit = nil
bugCategoryList = nil

local bugCategories = {
	{
		name = "Map",
		type = 0,
		color = "#484848"
	},
	{
		name = "Typo",
		type = 1,
		color = "#414141"
	},
	{
		name = "Technical",
		type = 2,
		color = "#484848"
	},
	{
		name = "Other",
		type = 3,
		color = "#414141"
	}
}
local category = 0
local reportPosition

local function isValidMapPosition(position)
	return position and type(position.x) == "number" and type(position.y) == "number" and type(position.z) == "number" and position.x ~= 65535
end

local function selectCategoryByType(categoryType)
	if not bugCategoryList then
		return
	end

	for _, child in ipairs(bugCategoryList:getChildren()) do
		if child.categoryType == categoryType then
			child:focus()

			category = categoryType

			return
		end
	end
end

local function refreshBugCategoryList()
	if not bugCategoryList then
		return
	end

	bugCategoryList:destroyChildren()

	local labels = {}

	for _, cat in ipairs(bugCategories) do
		local label = g_ui.createWidget("BugReportListLabel", bugCategoryList)

		label:setText(cat.name)
		label:setBackgroundColor(cat.color)

		label.originalColor = cat.color
		label.categoryType = cat.type

		table.insert(labels, label)

		function label.onFocusChange(widget, focused)
			if focused then
				category = widget.categoryType

				for _, otherLabel in ipairs(labels) do
					if otherLabel ~= widget then
						otherLabel:setBackgroundColor(otherLabel.originalColor)
					end
				end
			else
				widget:setBackgroundColor(widget.originalColor)
			end
		end
	end

	local first = bugCategoryList:getChildByIndex(1)

	if first then
		first:focus()

		category = first.categoryType
	end
end

function init()
	g_ui.importStyle("bugreport")

	bugReportWindow = g_ui.createWidget("BugReportWindow", rootWidget)

	bugReportWindow:hide()

	bugTextEdit = bugReportWindow:getChildById("bugTextEdit")
	bugCategoryList = bugReportWindow:getChildById("bugCategory")

	refreshBugCategoryList()
	Keybind.new("Dialogs", "Open Bug Report", HOTKEY, "")
	Keybind.bind("Dialogs", "Open Bug Report", {
		{
			type = KEY_DOWN,
			callback = function()
				show()
			end
		}
	}, modules.game_interface.getRootPanel())
end

function terminate()
	Keybind.delete("Dialogs", "Open Bug Report")
	bugReportWindow:destroy()
end

function doReport()
	local text = bugTextEdit:getText()

	if #text > BUG_REPORT_MAX_LENGTH then
		modules.game_textmessage.displayFailureMessage(tr("Message is too long."))

		return
	end

	local position = {
		z = 0,
		y = 0,
		x = 0
	}

	if category == BUG_CATEGORY_MAP then
		local player = g_game.getLocalPlayer()

		position = reportPosition or player and player:getPosition() or position
	end

	g_game.reportBug(category, text, position)

	reportPosition = nil

	bugReportWindow:hide()
end

function show(position)
	if g_game.isOnline() then
		if not isValidMapPosition(position) then
			position = nil
		end

		reportPosition = position

		bugTextEdit:setText("")
		refreshBugCategoryList()

		if position then
			selectCategoryByType(BUG_CATEGORY_MAP)
		end

		bugReportWindow:show()
		bugReportWindow:raise()
		bugReportWindow:focus()
	end
end

function showCoordinateReport(position)
	show(position)
end

function setReportText(text)
	if bugTextEdit then
		bugTextEdit:setText(text or "")
	end
end
