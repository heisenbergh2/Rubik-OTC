-- chunkname: @/client_topmenu/topmenu.lua

local topMenu, rightButtonsPanel, leftButtonsPanel, rightGameButtonsPanel, topLeftTogglesPanel, topLeftButtonsPanel, topLeftOnlinePlayersLabel, topLeftTwitchViewersLabel, topLeftTwitchStreamersLabel, topLeftYoutubeViewersLabel, topLeftYoutubeStreamersLabel, fpsLabel, pingLabel, topLeftYoutubeLink, topLeftTwitchLink
local url_discord = ""
local url_youtube = ""
local lastSyncValue = -1
local fpsEvent
local fpsMin = -1
local fpsMax = -1
local pingPanel, MainPingPanel, mainFpsPanel, fpsPanel2, PingWidget, pingImg, worldNameLabel, zoomInButton, zoomOutButton
local zoomLevel = 2
local managerAccountsButton, managerClientsButton, lastUpdatesButton
local lastUpdatesHighlightActive = false

function updateLastUpdatesHighlight(visible)
	lastUpdatesHighlightActive = visible == true

	if not lastUpdatesButton or lastUpdatesButton:isDestroyed() then
		return
	end

	local highlight = lastUpdatesButton:recursiveGetChildById("lastUpdatesHighlight")
	local flagNew = lastUpdatesButton:recursiveGetChildById("lastUpdatesFlagNew")
	local animation = lastUpdatesButton:recursiveGetChildById("lastUpdatesAnimation")

	if highlight then
		highlight:setVisible(lastUpdatesHighlightActive)
	end

	if flagNew then
		flagNew:setVisible(lastUpdatesHighlightActive)
	end

	if animation then
		animation:setVisible(lastUpdatesHighlightActive)
	end
end

local function addButton(id, description, icon, callback, panel, toggle, front, className)
	local class = className

	class = class or toggle and "MainToggleButton" or "Button"

	local button = panel:getChildById(id)

	if not button then
		button = g_ui.createWidget(class)

		if front then
			panel:insertChild(1, button)
		else
			panel:addChild(button)
		end
	end

	button:setId(id)
	button:setTooltip(description)

	if toggle then
		button:setIcon(resolvepath(icon, 3))
	else
		button:setText(description)
	end

	function button.onMouseRelease(widget, mousePos, mouseButton)
		if widget:containsPoint(mousePos) and mouseButton ~= MouseMidButton then
			callback()

			return true
		end
	end

	return button
end

local function updateZoomButtons()
	if zoomInButton then
		zoomInButton:setEnabled(zoomLevel < 6)
	end

	if zoomOutButton then
		zoomOutButton:setEnabled(zoomLevel > 1.5)
	end
end

local function setZoom(value)
	local oldValue = zoomLevel

	zoomLevel = math.max(1.5, math.min(6, value))

	modules.client_options.setOption("hudScale", zoomLevel)
	updateZoomButtons()

	return oldValue ~= zoomLevel
end

function init()
	connect(g_game, {
		onGameStart = online,
		onGameEnd = offline,
		onPingBack = updatePing
	})
	connect(g_app, {
		onFps = updateFps
	})

	topMenu = g_ui.displayUI("topmenu")
	topLeftButtonsPanel = topMenu:getChildById("topLeftButtonsPanel")
	topLeftTogglesPanel = topMenu:getChildById("topLeftTogglesPanel")
	rightButtonsPanel = topMenu:getChildById("rightButtonsPanel")
	leftButtonsPanel = topMenu:getChildById("leftButtonsPanel")
	rightGameButtonsPanel = topMenu:getChildById("rightGameButtonsPanel")
	pingLabel = topMenu:getChildById("pingLabel")
	fpsLabel = topMenu:getChildById("fpsLabel")

	if not g_game.isOnline() then
		fpsLabel:hide()
		pingLabel:hide()
	end

	topLeftOnlinePlayersLabel = topMenu:recursiveGetChildById("topLeftOnlinePlayersLabel")
	topLeftTwitchStreamersLabel = topMenu:recursiveGetChildById("topLeftTwitchViewersLabel")
	topLeftTwitchStreamersLabel = topMenu:recursiveGetChildById("topLeftTwitchStreamersLabel")
	topLeftYoutubeViewersLabel = topMenu:recursiveGetChildById("topLeftYoutubeViewersLabel")
	topLeftYoutubeStreamersLabel = topMenu:recursiveGetChildById("topLeftYoutubeStreamersLabel")
	topLeftYoutubeLink = topMenu:recursiveGetChildById("youtubeIcon")
	topLeftTwitchLink = topMenu:recursiveGetChildById("discordIcon")

	if Services.websites then
		if not managerAccountsButton then
			managerAccountsButton = modules.client_topmenu.addTopRightRegularButton("hotkeysButton", tr("Manage Account"), nil, openManagerAccounts)
		end

		if not managerClientsButton then
			managerClientsButton = modules.client_topmenu.addTopRightRegularButton("clientsButton", tr("Manage Clients"), nil, openLauncher)
		end

		if not lastUpdatesButton then
			lastUpdatesButton = modules.client_topmenu.addTopRightBlueButton("lastUpdatesButton", tr("Last Updates"), nil, openLastUpdates, true)
		end
	end

	if g_platform.isMobile() then
		zoomInButton = modules.client_topmenu.addLeftToggleButton("zoomInButton", "Zoom In", "/images/topbuttons/zoomin", function()
			setZoom(zoomLevel + 0.5)
		end)
		zoomOutButton = modules.client_topmenu.addLeftToggleButton("zoomOutButton", "Zoom Out", "/images/topbuttons/zoomout", function()
			setZoom(zoomLevel - 0.5)
		end)

		updateZoomButtons()
	end

	if g_game.isOnline() then
		online()
	else
		topMenu:hide()
	end
end

function terminate()
	disconnect(g_game, {
		onGameStart = online,
		onGameEnd = offline,
		onPingBack = updatePing
	})
	disconnect(g_app, {
		onFps = updateFps
	})
	topMenu:destroy()

	if PingWidget and not PingWidget:isDestroyed() then
		PingWidget:destroy()

		PingWidget = nil
		worldNameLabel = nil
	end

	if managerAccountsButton and not managerAccountsButton:isDestroyed() then
		managerAccountsButton:destroy()

		managerAccountsButton = nil
	end

	if managerClientsButton and not managerClientsButton:isDestroyed() then
		managerClientsButton:destroy()

		managerClientsButton = nil
	end

	if lastUpdatesButton and not lastUpdatesButton:isDestroyed() then
		lastUpdatesButton:destroy()

		lastUpdatesButton = nil
	end

	lastUpdatesHighlightActive = false

	if g_platform.isMobile() then
		if zoomInButton and not zoomOutButton:isDestroyed() then
			zoomInButton:destroy()

			zoomInButton = nil
		end

		if zoomOutButton and not zoomOutButton:isDestroyed() then
			zoomOutButton:destroy()

			zoomOutButton = nil
		end
	end

	Keybind.delete("UI", "Toggle Top Menu")
end

function hide()
	topMenu:hide()
	modules.game_interface.getRootPanel():addAnchor(AnchorTop, "parent", AnchorTop)
end

function show()
	topMenu:show()
	topMenu:raise()
	topMenu:focus()

	if modules.game_interface.currentViewMode == 2 then
		modules.game_interface.getRootPanel():addAnchor(AnchorTop, "topMenu", AnchorBottom)
	end
end

local function refreshPingFpsWorldHud(showHudOverride)
	if not worldNameLabel or worldNameLabel:isDestroyed() then
		return
	end

	local row = PingWidget and not PingWidget:isDestroyed() and PingWidget:recursiveGetChildById("pingFpsWorldRow")

	if not g_game.isOnline() then
		worldNameLabel:setText("")
		worldNameLabel:hide()

		if row then
			row:hide()
		end

		return
	end

	local showHud = showHudOverride

	if showHud == nil then
		showHud = modules.client_options.getOption("showFps")
	end

	if not showHud then
		worldNameLabel:hide()

		if row then
			row:setVisible(false)
		end

		return
	end

	local w = g_game.getWorldName()

	if w and #w > 0 then
		worldNameLabel:setText(w)
		worldNameLabel:setTooltip(tr("World") .. ": " .. w)
	else
		worldNameLabel:setText("?")
		worldNameLabel:setTooltip(tr("World"))
	end

	worldNameLabel:show()

	if row then
		row:setVisible(true)
	end
end

function online()
	showGameButtons()
	addEvent(function()
		if modules.client_background and modules.client_background.isMapTransitionActive and modules.client_background.isMapTransitionActive() then
			offline()
			show()

			return
		end

		if modules.game_interface.currentViewMode ~= 2 and g_game.isOnline() then
			hide()
		end

		local showHud = modules.client_options.getOption("showFps")

		if not PingWidget then
			PingWidget = g_ui.loadUI("pingFps", modules.game_interface.getMapPanel())
			MainPingPanel = g_ui.createWidget("TestPingPanel", PingWidget:getChildByIndex(1))

			MainPingPanel:setId("ping")

			pingImg = MainPingPanel:getChildByIndex(1)
			pingPanel = MainPingPanel:getChildByIndex(2)
			mainFpsPanel = g_ui.createWidget("TestPingPanel", PingWidget:getChildByIndex(3))

			mainFpsPanel:setId("fps")

			fpsPanel2 = mainFpsPanel:getChildByIndex(2)

			fpsPanel2:setMarginBottom(12)
		end

		worldNameLabel = PingWidget:recursiveGetChildById("pingFpsWorldLabel")

		setStatsHudVisible(showHud)
		addEvent(function()
			reorderTopRightToggleButtons()
		end)

		if worldNameLabel then
			scheduleEvent(refreshPingFpsWorldHud, 100)
		end
	end)
end

function offline()
	hideGameButtons()
	fpsLabel:hide()
	pingLabel:hide()

	if pingPanel then
		pingPanel:hide()
		pingImg:hide()
	end

	if fpsPanel2 then
		fpsPanel2:hide()
	end

	refreshPingFpsWorldHud(false)

	fpsMin = -1
end

function updateFps(fps)
	if fpsLabel:isVisible() then
		local text = "FPS " .. fps

		if g_game.isOnline() then
			local vsync = modules.client_options.getOption("vsync")

			if fpsEvent == nil and lastSyncValue ~= vsync then
				fpsEvent = scheduleEvent(function()
					fpsMin = -1
					lastSyncValue = vsync
					fpsEvent = nil
				end, 2000)
			end

			if fpsMin == -1 then
				fpsMin = fps
				fpsMax = fps
			end

			if fps > fpsMax then
				fpsMax = fps
			end

			if fps < fpsMin then
				fpsMin = fps
			end

			local midFps = math.floor((fpsMin + fpsMax) / 2)

			fpsLabel:setTooltip("Min: " .. fpsMin .. "\nMid: " .. midFps .. "\nMax: " .. fpsMax)
		else
			fpsLabel:removeTooltip()
		end

		fpsLabel:setText(text)
	end

	local text = fps .. " fps"

	if fpsPanel2 and fpsPanel2:isVisible() and g_game.isOnline() then
		fpsPanel2:setText(text)
	end
end

function updatePing(ping)
	if pingLabel:isVisible() then
		local text = "Ping: "
		local color

		if ping < 0 then
			text = text .. "??"
			color = "yellow"
		else
			text = text .. ping .. " ms"
			color = ping >= 500 and "red" or ping >= 250 and "yellow" or "green"
		end

		pingLabel:setColor(color)
		pingLabel:setText(text)
	end

	if pingPanel and pingPanel:isVisible() then
		local text, imagen

		if ping < 0 then
			text = "High lag (??)"
			imagen = nil
		elseif ping >= 500 then
			text = "High lag (" .. ping .. " ms)"
			imagen = "/images/ui/high_ping"
		elseif ping >= 250 then
			text = "Medium lag (" .. ping .. " ms)"
			imagen = "/images/ui/medium_ping"
		else
			text = "Low lag (" .. ping .. " ms)"
			imagen = "/images/ui/low_ping"
		end

		pingImg:setImageSource(imagen)
		pingPanel:setText(text)
	end
end

function setStatsHudVisible(enable)
	local inGame = g_game.isOnline()
	local effective = enable and inGame
	local pingFeatureAvailable = g_game.getFeature(GameClientPing) or g_game.getFeature(GameExtendedClientPing)
	local showMapPing = effective and pingFeatureAvailable

	pingLabel:setVisible(showMapPing)

	if pingPanel then
		pingPanel:setVisible(showMapPing)
		pingImg:setVisible(showMapPing)
	end

	fpsLabel:setVisible(effective)

	if fpsPanel2 then
		fpsPanel2:setVisible(effective)
	end

	refreshPingFpsWorldHud(effective)
end

function setPlayersOnline(value)
	topLeftOnlinePlayersLabel:setText(value .. " " .. tr("Players online"))
end

function setTwitchStreams(value)
	topLeftTwitchStreamersLabel:setText(value)
end

function setTwitchViewers(value)
	topLeftTwitchViewersLabel:setText(value)
end

function setYoutubeStreams(value)
	topLeftYoutubeStreamersLabel:setText(value)
end

function setYoutubeViewers(value)
	topLeftYoutubeViewersLabel:setText(value)
end

function setLinkYoutube(value)
	url_youtube = value

	function topLeftYoutubeLink.onClick()
		if url_youtube then
			g_platform.openUrl(url_youtube)
		end
	end
end

function setLinkTwitch(value)
	url_discord = value

	function topLeftTwitchLink.onClick()
		if url_discord then
			g_platform.openUrl(url_discord)
		end
	end
end

function addLeftButton(id, description, icon, callback, front)
	return addButton(id, description, icon, callback, leftButtonsPanel, false, front)
end

function addLeftToggleButton(id, description, icon, callback, front)
	return addButton(id, description, icon, callback, leftButtonsPanel, true, front)
end

function addRightButton(id, description, icon, callback, front)
	return addButton(id, description, icon, callback, topLeftTogglesPanel, false, front)
end

function addRightToggleButton(id, description, icon, callback, front)
	return addButton(id, description, icon, callback, rightButtonsPanel, true, front)
end

function addLeftGameButton(id, description, icon, callback, front, index)
	if not g_modules.getModule("game_mainpanel"):isLoaded() then
		scheduleEvent(function()
			return modules.game_mainpanel.addSpecialToggleButton(id, description, icon, callback, front, index)
		end, 100)
	else
		return modules.game_mainpanel.addSpecialToggleButton(id, description, icon, callback, front, index)
	end
end

function addLeftGameToggleButton(id, description, icon, callback, front, index)
	if not g_modules.getModule("game_mainpanel"):isLoaded() then
		scheduleEvent(function()
			return modules.game_mainpanel.addSpecialToggleButton(id, description, icon, callback, front, index)
		end, 100)
	else
		return modules.game_mainpanel.addSpecialToggleButton(id, description, icon, callback, front, index)
	end
end

function addRightGameButton(id, description, icon, callback, front, index)
	if not g_modules.getModule("game_mainpanel"):isLoaded() then
		scheduleEvent(function()
			return modules.game_mainpanel.addToggleButton(id, description, icon, callback, front, index)
		end, 100)
	else
		return modules.game_mainpanel.addToggleButton(id, description, icon, callback, front, index)
	end
end

function addRightGameToggleButton(id, description, icon, callback, front, index)
	if not g_modules.getModule("game_mainpanel"):isLoaded() then
		scheduleEvent(function()
			return modules.game_mainpanel.addToggleButton(id, description, icon, callback, front, index)
		end, 100)
	else
		return modules.game_mainpanel.addToggleButton(id, description, icon, callback, front, index)
	end
end

function addTopRightRegularButton(id, description, icon, callback, front)
	return addButton(id, description, icon, callback, topLeftButtonsPanel, false, front)
end

function addTopRightBlueButton(id, description, icon, callback, front)
	return addButton(id, description, icon, callback, topLeftButtonsPanel, false, front, "TopBarBlueButton")
end

function addTopRightToggleButton(id, description, icon, callback, front)
	return addButton(id, description, icon, callback, topLeftTogglesPanel, true, front)
end

function showGameButtons()
	rightGameButtonsPanel:show()
end

function hideGameButtons()
	rightGameButtonsPanel:hide()
end

function getButton(id)
	return topMenu:recursiveGetChildById(id)
end

function getTopMenu()
	return topMenu
end

function getRightGameButtonsPanel()
	return topLeftTogglesPanel
end

function reorderTopRightToggleButtons()
	if not topLeftTogglesPanel or topLeftTogglesPanel:isDestroyed() then
		return
	end

	local orderIds = {
		"audioButton",
		"optionsButton",
		"logoutButton"
	}
	local byId = {}

	for _, ch in ipairs(topLeftTogglesPanel:getChildren()) do
		local id = ch:getId()

		if id and id ~= "" then
			byId[id] = ch
		end
	end

	local out, used = {}, {}

	for _, id in ipairs(orderIds) do
		local w = byId[id]

		if w then
			out[#out + 1] = w
			used[w] = true
		end
	end

	local rest = {}

	for id, w in pairs(byId) do
		if not used[w] then
			rest[#rest + 1] = id
		end
	end

	table.sort(rest)

	for _, id in ipairs(rest) do
		out[#out + 1] = byId[id]
	end

	if #out > 0 then
		topLeftTogglesPanel:reorderChildren(out)
	end
end

function toggle()
	if not topMenu then
		return
	end

	if topMenu:isVisible() then
		hide()
	else
		show()
	end
end

local LAUNCHER_EXECUTABLE = "Tibia.exe"
local LAUNCHER_DEFAULT_MARKER = "default"
local LAUNCHER_MAX_DIR_LEVELS = 6

local function trimTrailingSlash(path)
	path = path:gsub("\\", "/")

	while path:sub(-1) == "/" do
		path = path:sub(1, -2)
	end

	return path
end

local function getParentPath(path, levels)
	path = trimTrailingSlash(path)

	for _ = 1, levels do
		local parentPath = path:match("^(.*)/[^/]*$")

		if not parentPath then
			return nil
		end

		path = parentPath
	end

	return path
end

local function tryRemoveDefaultMarker(dir)
	if not dir then
		return
	end

	local defaultPath = dir .. "/" .. LAUNCHER_DEFAULT_MARKER

	if g_platform.fileExists(defaultPath) then
		g_platform.removeFile(defaultPath)
	end
end

local function getLauncherPath()
	local workDir = g_resources.getWorkDir()

	if not workDir then
		return nil
	end

	for levels = 1, LAUNCHER_MAX_DIR_LEVELS do
		local root = getParentPath(workDir, levels)

		if root then
			tryRemoveDefaultMarker(root)

			local candidate = root .. "/" .. LAUNCHER_EXECUTABLE

			if g_platform.fileExists(candidate) then
				return candidate
			end
		end
	end

	return nil
end

function openManagerAccounts()
	if Services.websites then
		g_platform.openUrl(Services.websites)
	end
end

function openLastUpdates()
	if modules.game_announcements and modules.game_announcements.show then
		modules.game_announcements.show()
	end
end

function openLauncher()
	if not g_platform.isDesktop() then
		return
	end

	local launcherPath = getLauncherPath()

	if not launcherPath then
		displayErrorBox(tr("Error"), "Launcher not found")

		return
	end

	g_platform.spawnProcess(launcherPath, {})
	scheduleEvent(exit, 10)
end

function extendedView(extendedView)
	if not topMenu then
		return
	end

	topMenu:breakAnchors()

	if extendedView then
		topMenu:show()
		topMenu:addAnchor(AnchorLeft, "parent", AnchorLeft)
		topMenu:addAnchor(AnchorRight, "parent", AnchorRight)
		modules.game_interface.getRootPanel():addAnchor(AnchorTop, "topMenu", AnchorBottom)
		pingLabel:setVisible(false)
		fpsLabel:setVisible(false)
		topMenu.topLeftOnlinePlayers:hide()
		topMenu.topLeftTwitch:setWidth(0)
		topMenu.topLeftYoutube:setWidth(0)
		topMenu.topLeftTwitch:hide()
		topMenu.topLeftYoutube:hide()
	else
		if g_game.isOnline() then
			topMenu:hide()
		end

		topMenu:addAnchor(AnchorHorizontalCenter, "parent", AnchorHorizontalCenter)
		modules.game_interface.getRootPanel():addAnchor(AnchorTop, "parent", AnchorTop)
		topMenu:setWidth(1020)
		topMenu.topLeftTwitch:setWidth(110)
		topMenu.topLeftYoutube:setWidth(100)
		topMenu.topLeftOnlinePlayers:show()
		topMenu.topLeftTwitch:show()
		topMenu.topLeftYoutube:show()
	end
end
