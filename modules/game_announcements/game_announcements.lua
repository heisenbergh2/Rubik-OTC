-- chunkname: @/game_announcements/game_announcements.lua

local Data = AnnouncementsData
local Util = AnnouncementsUtil
local window, closeButton
local tabButtons = {}
local sidebarList, scrollPanel, countdownEvent
local isActive = false
local canClose = false
local selectedTabIndex = 1
local selectedNewsId
local sidebarItems = {}
local COUNTDOWN_SECONDS = 5
local BUTTON_CLIP = "0 0 43 20"
local TAB_IDS = {
	"tabPtcUpdates",
	"tabServerUpdates"
}
local CATEGORIES = {
	"PTC UPDATES",
	"SERVER UPDATES"
}
local ACTIVE_CATEGORIES = {
	["PTC UPDATES"] = true,
	["SERVER UPDATES"] = true
}
local SECTION_GAP = 10
local HEADLINE_MARGIN = {
	{
		6,
		4
	},
	{
		7,
		5
	}
}
local BANNER_WRAP_ID = "announcementsBannerWrap"
local SYNC_POLL_INTERVAL_MS = 300000

local function getScrollContentWidth()
	if not scrollPanel or scrollPanel:isDestroyed() then
		return 640
	end

	local width = scrollPanel:getWidth() - scrollPanel:getPaddingLeft() - scrollPanel:getPaddingRight()
	local scrollbar = window and window:recursiveGetChildById("announcementsScrollBar")

	if scrollbar and not scrollbar:isDestroyed() then
		width = width - scrollbar:getWidth()
	end

	return math.max(1, width)
end

local function clearContentLines()
	if not scrollPanel or scrollPanel:isDestroyed() then
		return
	end

	for i = scrollPanel:getChildCount(), 1, -1 do
		local child = scrollPanel:getChildByIndex(i)

		if child and child:getId() ~= BANNER_WRAP_ID then
			child:destroy()
		end
	end
end

local function addContentSpacer()
	if not scrollPanel or scrollPanel:isDestroyed() then
		return
	end

	local spacer = g_ui.createWidget("UIWidget", scrollPanel)

	if spacer then
		spacer:setHeight(SECTION_GAP)
		spacer:setWidth(getScrollContentWidth())
		spacer:setPhantom(true)
	end
end

local function addContentLine(html, withIcon)
	local plain = Util.htmlToPlain(html)

	if plain == "" or not scrollPanel or scrollPanel:isDestroyed() then
		return
	end

	local row = g_ui.createWidget("AnnouncementsContentLine", scrollPanel)

	if not row then
		return
	end

	local text = row:recursiveGetChildById("text")
	local icon = row:recursiveGetChildById("icon")

	if not text then
		row:destroy()

		return
	end

	row:setWidth(getScrollContentWidth())

	if withIcon and icon then
		icon:setVisible(true)
		text:setMarginLeft(16)
	end

	text:setText(plain)
	row:setHeight(math.max(withIcon and 12 or 14, text:getTextSize().height + 2))
end

local function renderNewsContent(news, isRetry)
	if not scrollPanel or scrollPanel:isDestroyed() then
		return
	end

	if not isRetry and getScrollContentWidth() <= 1 then
		addEvent(function()
			renderNewsContent(news, true)
		end)

		return
	end

	clearContentLines()

	if not news then
		scrollPanel:updateLayout()

		return
	end

	local blocks = {}

	if news.firstmessage and news.firstmessage ~= "" then
		table.insert(blocks, {
			text = news.firstmessage
		})
	end

	local list = Util.normalizeList(news.list)

	if #list > 0 then
		table.insert(blocks, {
			list = list
		})
	end

	if news.lastmessage and news.lastmessage ~= "" then
		table.insert(blocks, {
			text = news.lastmessage
		})
	end

	for i, block in ipairs(blocks) do
		if i > 1 then
			addContentSpacer()
		end

		if block.text then
			addContentLine(block.text, false)
		else
			for _, item in ipairs(block.list) do
				addContentLine(item, true)
			end
		end
	end

	local dateText = Data.formatDate(news)

	if dateText then
		addContentSpacer()

		local row = g_ui.createWidget("AnnouncementsContentDate", scrollPanel)

		if row then
			row:setWidth(getScrollContentWidth())

			local label = row:recursiveGetChildById("date")

			if label then
				label:setText(dateText)
			end
		end
	end

	scrollPanel:updateLayout()
end

function hasUnreadNews()
	return Data.hasUnread(ACTIVE_CATEGORIES)
end

local function updateTopBarHighlight()
	if modules.client_topmenu and modules.client_topmenu.updateLastUpdatesHighlight then
		modules.client_topmenu.updateLastUpdatesHighlight(hasUnreadNews())
	end
end

function markNewsAsRead(id)
	return Data.markRead(id)
end

local function setNewsItemSelected(item, selected)
	local button = item and item:recursiveGetChildById("button")

	if not button or button:isDestroyed() then
		return
	end

	button:setChecked(selected)

	local headline = button:recursiveGetChildById("headline")

	if headline and not headline:isDestroyed() then
		local margin = HEADLINE_MARGIN[selected and 2 or 1]

		headline:setMarginLeft(margin[1])
		headline:setMarginTop(margin[2])
	end
end

local function updateTabVisuals()
	for i, tab in ipairs(tabButtons) do
		if tab and not tab:isDestroyed() then
			tab:setChecked(i == selectedTabIndex)

			local badge = tab:recursiveGetChildById("tabNewBadge")

			if badge then
				badge:setVisible(Data.categoryHasUnread(CATEGORIES[i]))
			end
		end
	end

	updateTopBarHighlight()
end

local function selectSidebarItem(widget, news)
	if not news then
		renderNewsContent(nil)
		updateTabVisuals()

		return
	end

	for _, itemWidget in ipairs(sidebarItems) do
		setNewsItemSelected(itemWidget, itemWidget == widget)
	end

	selectedNewsId = Data.normalizeId(news.id)

	renderNewsContent(news)
	Data.setRead(news)

	local badge = widget and widget:recursiveGetChildById("newBadge")

	if badge then
		badge:setVisible(not Data.isRead(news))
	end

	updateTabVisuals()
end

local function refreshSidebar()
	if not window or window:isDestroyed() or not sidebarList or sidebarList:isDestroyed() then
		return
	end

	sidebarList:destroyChildren()

	sidebarItems = {}

	local newsList = Data.getByCategory(CATEGORIES[selectedTabIndex])

	if #newsList == 0 then
		selectedNewsId = nil

		renderNewsContent(nil)
		updateTabVisuals()

		return
	end

	local selectedWidget, selectedNews

	for _, news in ipairs(newsList) do
		local item = g_ui.createWidget("AnnouncementsNewsItem", sidebarList)

		if item then
			local headline = item:recursiveGetChildById("headline")

			if headline then
				headline:setText(Util.htmlToPlain(news.headline or ""))
			end

			local badge = item:recursiveGetChildById("newBadge")

			if badge then
				local showBadge = not Data.isRead(news)

				badge:setVisible(showBadge)

				if showBadge then
					badge:raise()
				end
			end

			local button = item:recursiveGetChildById("button")

			if button then
				function button.onClick()
					selectSidebarItem(item, news)
				end
			end

			table.insert(sidebarItems, item)

			if Data.normalizeId(selectedNewsId) == Data.normalizeId(news.id) or not selectedNews then
				selectedWidget, selectedNews = item, news
			end
		end
	end

	if selectedNews then
		selectSidebarItem(selectedWidget, selectedNews)
	else
		renderNewsContent(nil)
		updateTabVisuals()
	end
end

local function onSyncComplete()
	updateTopBarHighlight()

	if isActive then
		refreshSidebar()
	end
end

local function selectTab(index)
	if index < 1 or index > #CATEGORIES or selectedTabIndex == index then
		return
	end

	selectedTabIndex = index
	selectedNewsId = nil

	updateTabVisuals()
	refreshSidebar()
end

local function setupTabs()
	tabButtons = {}

	for i, tabId in ipairs(TAB_IDS) do
		local tab = window:recursiveGetChildById(tabId)

		if tab then
			tabButtons[i] = tab

			local tabIndex = i

			function tab.onClick()
				selectTab(tabIndex)
			end
		end
	end

	selectedTabIndex = 1
	selectedNewsId = nil

	updateTabVisuals()
end

local function stopCountdown()
	if countdownEvent then
		removeEvent(countdownEvent)

		countdownEvent = nil
	end
end

local function closeAnnouncements()
	if not canClose or not window or window:isDestroyed() then
		return
	end

	stopCountdown()

	if g_modalManager then
		g_modalManager.hide(window)
	end

	window:hide()

	isActive = false
	canClose = false
end

local function startCountdown()
	stopCountdown()

	canClose = false

	if not closeButton or closeButton:isDestroyed() then
		canClose = true

		return
	end

	local remaining = COUNTDOWN_SECONDS

	local function tick()
		if not closeButton or closeButton:isDestroyed() then
			canClose = true

			return
		end

		if remaining > 0 then
			closeButton:setText(string.format("(%ds)", remaining))
			closeButton:setEnabled(false)
			closeButton:setImageClip(BUTTON_CLIP)

			remaining = remaining - 1
			countdownEvent = scheduleEvent(tick, 1000)

			return
		end

		closeButton:setText(tr("Close"))
		closeButton:setEnabled(true)
		closeButton:setImageClip(BUTTON_CLIP)

		canClose = true
	end

	tick()
end

local function bindWindow()
	sidebarList = window:recursiveGetChildById("announcementsSidebarList")
	scrollPanel = window:recursiveGetChildById("announcementsScrollPanel")
end

local function createWindow()
	if window and not window:isDestroyed() then
		bindWindow()

		return true
	end

	local ok, widget = pcall(g_ui.createWidget, "AnnouncementsWindow", rootWidget)

	if not ok or not widget then
		g_logger.error("[game_announcements] failed to create window: " .. tostring(widget))

		return false
	end

	window = widget
	closeButton = window:recursiveGetChildById("buttonClose")

	bindWindow()

	function window.onEscape()
		if canClose then
			closeAnnouncements()
		end

		return true
	end

	if closeButton then
		closeButton.onClick = closeAnnouncements
	end

	return true
end

local function showAnnouncements(skipCountdown)
	if not createWindow() then
		return
	end

	isActive = true

	window:show()

	if g_modalManager then
		g_modalManager.show(window)
	else
		window:raise()
		window:focus()
	end

	setupTabs()

	if skipCountdown then
		stopCountdown()

		canClose = true

		if closeButton and not closeButton:isDestroyed() then
			closeButton:setText(tr("Close"))
			closeButton:setEnabled(true)
			closeButton:setImageClip(BUTTON_CLIP)
		end
	else
		startCountdown()
	end

	addEvent(function()
		if isActive and window and not window:isDestroyed() then
			refreshSidebar()
		end
	end)
end

function show()
	Data.load()
	updateTopBarHighlight()
	showAnnouncements(true)
	addEvent(function()
		Data.sync(onSyncComplete)
	end)
end

function onClientStartup()
	Data.load()
	updateTopBarHighlight()

	if hasUnreadNews() then
		addEvent(showAnnouncements)
	end

	addEvent(function()
		Data.sync(function()
			onSyncComplete()

			if not isActive and hasUnreadNews() then
				addEvent(showAnnouncements)
			end
		end)
	end)
	Data.startPolling(SYNC_POLL_INTERVAL_MS, onSyncComplete)
end

function init()
	g_ui.importStyle("announcements")

	isActive = false
end

function terminate()
	stopCountdown()
	Data.stopPolling()

	Data.syncInProgress = false

	if window and not window:isDestroyed() then
		if g_modalManager then
			g_modalManager.hide(window)
		end

		window:destroy()
	end

	window = nil
	closeButton = nil
	sidebarList = nil
	scrollPanel = nil
	tabButtons = {}
	sidebarItems = {}
	isActive = false
	canClose = false
	selectedNewsId = nil
end

function isBlockingLogin()
	return false
end
