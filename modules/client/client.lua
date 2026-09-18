-- chunkname: @/client/client.lua

local musicFilename = "sounds/startup"
local musicChannel, startupLoadBox
local STARTUP_LOADING_DELAY_MS = 100

if g_sounds then
	musicChannel = g_sounds.getChannel(SoundChannels.Music)
end

local function hideLoginStartupUI()
	if modules.client_topmenu and modules.client_topmenu.hide then
		modules.client_topmenu.hide()
	end

	if g_modules.getModule("client_bottommenu") and g_modules.getModule("client_bottommenu"):isLoaded() and modules.client_bottommenu.hide then
		modules.client_bottommenu.hide()
	end

	if modules.client_background and modules.client_background.getBackground then
		local background = modules.client_background.getBackground()

		if background and background.serverLogo then
			background.serverLogo:hide()
		end
	end

	if EnterGame and EnterGame.hide then
		EnterGame.hide()
	end
end

local function showStartupLoadingBox()
	local box = g_ui.createWidget("MessageBoxWindow", rootWidget)

	box:setSize("250 60")
	box:setMarginTop(252)

	local holder = box:getChildById("holder")

	if holder then
		holder:destroy()
	end

	for _, child in pairs(box:recursiveGetChildrenByStyleName("HorizontalSeparator")) do
		child:destroy()
	end

	box:getChildById("title"):setText(tr("Please Wait"))

	local content = box:getChildById("content")

	content:setText(tr("Loading game files"))
	content:setMarginTop(27)

	if content.setFont then
		content:setFont("Verdana Bold-11px-new")
	end

	box:raise()
	box:focus()

	return box
end

local function destroyStartupLoadingBox()
	if startupLoadBox then
		startupLoadBox:destroy()

		startupLoadBox = nil
	end
end

function setMusic(filename)
	musicFilename = filename

	if not g_game.isOnline() then
		musicChannel:stop()
		musicChannel:enqueue(musicFilename, 3)
	end
end

function startup()
	if musicChannel then
		musicChannel:enqueue(musicFilename, 3)
		connect(g_game, {
			onGameStart = function()
				musicChannel:stop(3)
			end
		})
		connect(g_game, {
			onGameEnd = function()
				g_sounds.stopAll()
				musicChannel:enqueue(musicFilename, 3)
			end
		})
	end

	local errtitle, errmsg

	if g_graphics.getRenderer():lower():match("gdi generic") then
		errtitle = tr("Graphics card driver not detected")
		errmsg = tr("No graphics card detected, everything will be drawn using the CPU,\nthus the performance will be really bad.\nPlease update your graphics driver to have a better performance.")
	end

	local function proceedToEnterGame()
		if EnterGame.showPanels then
			EnterGame.showPanels()
		end

		EnterGame.firstShow()
	end

	local announcementsLoaded = modules.game_announcements ~= nil

	local function finishStartup()
		destroyStartupLoadingBox()

		if errmsg or errtitle then
			local msgbox = displayErrorBox(errtitle, errmsg)

			msgbox.onOk = proceedToEnterGame
		elseif not announcementsLoaded then
			proceedToEnterGame()
		else
			EnterGame.loadStartupData()
			proceedToEnterGame()

			if modules.game_announcements.onClientStartup then
				modules.game_announcements.onClientStartup()
			end
		end
	end

	hideLoginStartupUI()

	startupLoadBox = showStartupLoadingBox()

	scheduleEvent(finishStartup, STARTUP_LOADING_DELAY_MS)

	if g_sounds then
		g_sounds.setAudioEnabled(true)
		g_settings.set("enableAudio", true)
		g_sounds.getChannel(SoundChannels.Music):setEnabled(g_settings.getBoolean("enableMusicSound"))
	end
end

function init()
	connect(g_app, {
		onRun = startup
	})

	if musicChannel then
		g_sounds.preload(musicFilename)
	end
end

function terminate()
	disconnect(g_app, {
		onRun = startup
	})
end
