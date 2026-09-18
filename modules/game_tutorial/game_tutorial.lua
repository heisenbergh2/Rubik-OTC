-- chunkname: @/game_tutorial/game_tutorial.lua

tutorialHintWindow = nil
tutorialVocationWindow = nil
tutorialMainlandWindow = nil
tutorialStartWindow = nil

local lockedTutorialWindow
local TUTORIAL_HINT_BASE_PATH = "/images/game/tutorial/"
local WORLD_MAP = {
	MAX_ZOOM = 1,
	MIN_ZOOM = 0.25,
	PIN_HEIGHT = 41,
	PIN_WIDTH = 126,
	PIN_TIP_Y = 15,
	PIN_TIP_X = 64,
	OFFSET_Y = 256,
	OFFSET_X = 129,
	ORIGIN_Y = 30976,
	ORIGIN_X = 31744,
	IMAGE = TUTORIAL_HINT_BASE_PATH .. "global-map-tutorial"
}
local mainlandPositionConn, mainlandMapWidgets, mainlandWorldMapPinUpdater

TutorialWorldMapView = extends(UIImageView, "TutorialWorldMapView")

function TutorialWorldMapView:move(x, y, centerX, centerY)
	UIImageView.move(self, x, y, centerX, centerY)

	if mainlandWorldMapPinUpdater then
		mainlandWorldMapPinUpdater()
	end
end

function TutorialWorldMapView:setZoom(zoom, x, y)
	UIImageView.setZoom(self, zoom, x, y)

	if mainlandWorldMapPinUpdater then
		mainlandWorldMapPinUpdater()
	end
end

_G.TutorialWorldMapView = TutorialWorldMapView

local TUTORIAL_TYPE = {
	VOCATION = "vocation",
	MAINLAND = "mainland",
	HINT = "hint",
	START = "start"
}
local VOCATION_STAGE_SIZES = {
	{
		960,
		445
	},
	{
		957,
		445
	}
}
local VOCATION_BG_COLOR_DEFAULT = "#ffffffb3"
local VOCATION_BG_COLOR_HOVER = "#ffffff"
local VOCATION_BORDER_IDLE = "/images/game/tutorial/button_startplaying_idle"
local VOCATION_BORDER_SELECTED = "/images/game/tutorial/button_startplaying_selected"
local VOCATION_SELECT_CLIP_IDLE = "0 0 108 20"
local VOCATION_SELECT_CLIP_SELECTED = "0 40 108 20"
local VOCATION_BUTTON_SIZE = "108 20"
local VOCATION_BORDER_SIZE = "120 33"
local VOCATION_BUTTON_MARGIN_LEFT = 6
local VOCATION_BUTTON_MARGIN_BOTTOM = 7
local VOCATION_CLIENT_IDS = {
	druid = 4,
	sorcerer = 3,
	paladin = 2,
	knight = 1,
	monk = 5
}
local VOCATION_HOVER_ENTRIES = {
	{
		highlightId = "vocationKnightHighlight",
		backgroundId = "vocationKnightBackground",
		slotId = "vocationKnight",
		confirmButtonId = "buttonConfirmKnight",
		confirmBorderId = "vocationKnightConfirmBorder",
		selectButtonId = "buttonSelectKnight",
		selectBorderId = "vocationKnightSelectBorder",
		containerId = "vocationKnightHover",
		clientVocationId = VOCATION_CLIENT_IDS.knight
	},
	{
		highlightId = "vocationSorcererHighlight",
		backgroundId = "vocationSorcererBackground",
		slotId = "vocationSorcerer",
		confirmButtonId = "buttonConfirmSorcerer",
		confirmBorderId = "vocationSorcererConfirmBorder",
		selectButtonId = "buttonSelectSorcerer",
		selectBorderId = "vocationSorcererSelectBorder",
		containerId = "vocationSorcererHover",
		clientVocationId = VOCATION_CLIENT_IDS.sorcerer
	},
	{
		highlightId = "vocationDruidHighlight",
		backgroundId = "vocationDruidBackground",
		slotId = "vocationDruid",
		confirmButtonId = "buttonConfirmDruid",
		confirmBorderId = "vocationDruidConfirmBorder",
		selectButtonId = "buttonSelectDruid",
		selectBorderId = "vocationDruidSelectBorder",
		containerId = "vocationDruidHover",
		clientVocationId = VOCATION_CLIENT_IDS.druid
	},
	{
		highlightId = "vocationPaladinHighlight",
		backgroundId = "vocationPaladinBackground",
		slotId = "vocationPaladin",
		confirmButtonId = "buttonConfirmPaladin",
		confirmBorderId = "vocationPaladinConfirmBorder",
		selectButtonId = "buttonSelectPaladin",
		selectBorderId = "vocationPaladinSelectBorder",
		containerId = "vocationPaladinHover",
		clientVocationId = VOCATION_CLIENT_IDS.paladin
	},
	{
		highlightId = "vocationMonkHighlight",
		backgroundId = "vocationMonkBackground",
		slotId = "vocationMonk",
		confirmButtonId = "buttonConfirmMonk",
		confirmBorderId = "vocationMonkConfirmBorder",
		selectButtonId = "buttonSelectMonk",
		selectBorderId = "vocationMonkSelectBorder",
		containerId = "vocationMonkHover",
		clientVocationId = VOCATION_CLIENT_IDS.monk
	}
}
local VOCATION_INFO_SLIDE = {
	DURATION_MS_DOWN = 150,
	DURATION_MS_UP = 500,
	MARGIN_HIDDEN = -227,
	MARGIN_VISIBLE = 0,
	STEP_MS = 10
}
local activeVocationHoverEntry, selectedVocationEntry

local function makeArrivalInThaisTutorial()
	return {
		title = "Arrival in Thais",
		type = TUTORIAL_TYPE.HINT,
		image = TUTORIAL_HINT_BASE_PATH .. "hint_07_arrivalmain.png",
		size = {
			582,
			487
		},
		imageSize = {
			550,
			400
		}
	}
end

local TUTORIALS = {
	{
		title = "Alternative Controls",
		type = TUTORIAL_TYPE.HINT,
		image = TUTORIAL_HINT_BASE_PATH .. "hint_01_alternativecontrols.png",
		size = {
			432,
			427
		},
		imageSize = {
			400,
			340
		}
	},
	{
		title = "Welcome to Newhaven",
		type = TUTORIAL_TYPE.VOCATION,
		size = {
			960,
			445
		}
	},
	{
		title = "Combat Basics",
		type = TUTORIAL_TYPE.HINT,
		image = TUTORIAL_HINT_BASE_PATH .. "hint_03_vocationknight.png",
		size = {
			432,
			487
		},
		imageSize = {
			400,
			400
		}
	},
	{
		title = "Combat Basics",
		type = TUTORIAL_TYPE.HINT,
		image = TUTORIAL_HINT_BASE_PATH .. "hint_04_vocationpaladin.png",
		size = {
			432,
			487
		},
		imageSize = {
			400,
			400
		}
	},
	{
		title = "Combat Basics",
		type = TUTORIAL_TYPE.HINT,
		image = TUTORIAL_HINT_BASE_PATH .. "hint_05_vocationsorcerer.png",
		size = {
			432,
			487
		},
		imageSize = {
			400,
			400
		}
	},
	{
		title = "Combat Basics",
		type = TUTORIAL_TYPE.HINT,
		image = TUTORIAL_HINT_BASE_PATH .. "hint_06_vocationdruid.png",
		size = {
			432,
			487
		},
		imageSize = {
			400,
			400
		}
	},
	makeArrivalInThaisTutorial(),
	makeArrivalInThaisTutorial(),
	makeArrivalInThaisTutorial(),
	makeArrivalInThaisTutorial(),
	{
		title = "Combat Basics",
		type = TUTORIAL_TYPE.HINT,
		image = TUTORIAL_HINT_BASE_PATH .. "hint_11_vocationmonk.png",
		size = {
			432,
			487
		},
		imageSize = {
			400,
			400
		}
	},
	[13] = {
		title = "Welcome to Tibia",
		type = TUTORIAL_TYPE.MAINLAND,
		size = {
			907,
			505
		}
	},
	[14] = {
		title = "The World Awaits",
		type = TUTORIAL_TYPE.START,
		size = {
			886,
			419
		}
	}
}

local function getTutorialConfig(tutorialId)
	return TUTORIALS[tutorialId]
end

local function getTutorialType(tutorialId)
	local config = getTutorialConfig(tutorialId)

	return config and config.type or TUTORIAL_TYPE.HINT
end

local function applyHintImage(hintImage, imagePath, imageSize)
	hintImage:setImageSource(imagePath)

	local width = imageSize and imageSize[1] or hintImage:getImageTextureWidth()
	local height = imageSize and imageSize[2] or hintImage:getImageTextureHeight()

	if width <= 0 or height <= 0 then
		return
	end

	hintImage:setImageSize({
		width = width,
		height = height
	})
	hintImage:setSize(string.format("%d %d", width, height))
end

local function resolveHintImagePath(hintKey)
	local directoryPath = TUTORIAL_HINT_BASE_PATH .. hintKey

	if g_resources.directoryExists(directoryPath) then
		local files = g_resources.listDirectoryFiles(directoryPath)

		table.sort(files)

		if #files > 0 then
			return directoryPath .. "/" .. files[1]
		end
	end

	local imagePath = directoryPath .. ".png"

	if g_resources.fileExists(imagePath) then
		return imagePath
	end

	return nil
end

local function unlockTutorialModal(window)
	if window and not window:isDestroyed() then
		if g_modalManager then
			g_modalManager.hide(window)
		end

		window:hide()
	end

	if lockedTutorialWindow == window then
		lockedTutorialWindow = nil

		g_client.setInputLockWidget(nil)
	end
end

local function lockTutorialModal(window)
	if not window or window:isDestroyed() then
		return
	end

	if lockedTutorialWindow and lockedTutorialWindow ~= window and not lockedTutorialWindow:isDestroyed() then
		unlockTutorialModal(lockedTutorialWindow)
	end

	window:raise()
	window:show()

	if g_modalManager then
		g_modalManager.show(window)
	end

	g_client.setInputLockWidget(window)

	lockedTutorialWindow = window

	if window == tutorialVocationWindow then
		function window.onEscape()
			return true
		end
	end
end

local function hideTutorialHintWindow()
	unlockTutorialModal(tutorialHintWindow)

	if not tutorialHintWindow or tutorialHintWindow:isDestroyed() then
		tutorialHintWindow = nil
	end
end

local function cancelVocationHoverAnimation(hoverContainer)
	if not hoverContainer or hoverContainer:isDestroyed() then
		return
	end

	if hoverContainer.__slideEvent then
		removeEvent(hoverContainer.__slideEvent)

		hoverContainer.__slideEvent = nil
	end
end

local function setVocationHighlightVisible(highlightWidget, visible)
	if not highlightWidget or highlightWidget:isDestroyed() then
		return
	end

	if visible then
		highlightWidget:show()
	else
		highlightWidget:hide()
	end
end

local function applyVocationBackgroundTint(background, hovered)
	if not background or background:isDestroyed() then
		return
	end

	background:setImageColor(hovered and VOCATION_BG_COLOR_HOVER or VOCATION_BG_COLOR_DEFAULT)
end

local function animateVocationInfoSlide(infoContainer, show)
	cancelVocationHoverAnimation(infoContainer)

	if not infoContainer or infoContainer:isDestroyed() then
		return
	end

	local fromMargin = infoContainer:getMarginBottom()
	local toMargin = show and VOCATION_INFO_SLIDE.MARGIN_VISIBLE or VOCATION_INFO_SLIDE.MARGIN_HIDDEN
	local duration = show and VOCATION_INFO_SLIDE.DURATION_MS_UP or VOCATION_INFO_SLIDE.DURATION_MS_DOWN
	local elapsed = 0

	if show then
		infoContainer:show()
	end

	local function step()
		elapsed = elapsed + VOCATION_INFO_SLIDE.STEP_MS

		local progress = math.min(elapsed / duration, 1)

		progress = 1 - (1 - progress) * (1 - progress)

		local margin = math.floor(fromMargin + (toMargin - fromMargin) * progress)

		infoContainer:setMarginBottom(margin)

		if elapsed < duration then
			infoContainer.__slideEvent = scheduleEvent(step, VOCATION_INFO_SLIDE.STEP_MS)

			return
		end

		infoContainer:setMarginBottom(toMargin)

		infoContainer.__slideEvent = nil

		if not show then
			infoContainer:hide()
		end
	end

	step()
end

local function hideVocationInfoSlide(infoContainer, instant)
	if not infoContainer or infoContainer:isDestroyed() then
		return
	end

	cancelVocationHoverAnimation(infoContainer)

	if instant then
		infoContainer:hide()
		infoContainer:setMarginBottom(VOCATION_INFO_SLIDE.MARGIN_HIDDEN)

		return
	end

	animateVocationInfoSlide(infoContainer, false)
end

local function findVocationHoverEntryAt()
	if not tutorialVocationWindow or tutorialVocationWindow:isDestroyed() then
		return nil
	end

	local stage2 = tutorialVocationWindow:recursiveGetChildById("vocationStage2")

	if not stage2 or not stage2:isExplicitlyVisible() then
		return nil
	end

	local mousePos = g_window.getMousePosition()

	for _, entry in ipairs(VOCATION_HOVER_ENTRIES) do
		local slot = tutorialVocationWindow:recursiveGetChildById(entry.slotId)

		if slot and slot:isExplicitlyVisible() and slot:containsPoint(mousePos) then
			return entry
		end
	end

	return nil
end

local function setVocationSelectState(entry, selected)
	if not tutorialVocationWindow or tutorialVocationWindow:isDestroyed() or not entry then
		return
	end

	local selectBorder = tutorialVocationWindow:recursiveGetChildById(entry.selectBorderId)
	local selectButton = tutorialVocationWindow:recursiveGetChildById(entry.selectButtonId)
	local confirmBorder = tutorialVocationWindow:recursiveGetChildById(entry.confirmBorderId)

	if selectButton and not selectButton:isDestroyed() then
		selectButton:setSize(VOCATION_BUTTON_SIZE)
		selectButton:setMarginLeft(VOCATION_BUTTON_MARGIN_LEFT)
		selectButton:setMarginBottom(VOCATION_BUTTON_MARGIN_BOTTOM)
		selectButton:setChecked(selected)
		selectButton:setImageClip(selected and VOCATION_SELECT_CLIP_SELECTED or VOCATION_SELECT_CLIP_IDLE)
	end

	if selectBorder and not selectBorder:isDestroyed() then
		selectBorder:setSize(VOCATION_BORDER_SIZE)
		selectBorder:setImageSource(selected and VOCATION_BORDER_SELECTED or VOCATION_BORDER_IDLE)
	end

	local confirmButton = tutorialVocationWindow:recursiveGetChildById(entry.confirmButtonId)

	if confirmButton and not confirmButton:isDestroyed() then
		confirmButton:setSize(VOCATION_BUTTON_SIZE)
		confirmButton:setMarginLeft(VOCATION_BUTTON_MARGIN_LEFT)
		confirmButton:setMarginBottom(VOCATION_BUTTON_MARGIN_BOTTOM)
	end

	if confirmBorder and not confirmBorder:isDestroyed() then
		confirmBorder:setSize(VOCATION_BORDER_SIZE)
	end

	if confirmBorder and not confirmBorder:isDestroyed() then
		if selected then
			confirmBorder:show()
		else
			confirmBorder:hide()
		end
	end
end

local function resetVocationSelection()
	if selectedVocationEntry then
		setVocationSelectState(selectedVocationEntry, false)

		selectedVocationEntry = nil
	end
end

local function resetVocationHoverState()
	activeVocationHoverEntry = nil

	resetVocationSelection()

	if not tutorialVocationWindow or tutorialVocationWindow:isDestroyed() then
		return
	end

	for _, entry in ipairs(VOCATION_HOVER_ENTRIES) do
		local background = tutorialVocationWindow:recursiveGetChildById(entry.backgroundId)
		local infoContainer = tutorialVocationWindow:recursiveGetChildById(entry.containerId)
		local highlightWidget = tutorialVocationWindow:recursiveGetChildById(entry.highlightId)

		applyVocationBackgroundTint(background, false)

		if infoContainer then
			hideVocationInfoSlide(infoContainer, true)
		end

		setVocationHighlightVisible(highlightWidget, false)
	end
end

local function raiseVocationActionButtons()
	if not tutorialVocationWindow or tutorialVocationWindow:isDestroyed() then
		return
	end

	for _, entry in ipairs(VOCATION_HOVER_ENTRIES) do
		for _, borderId in ipairs({
			entry.confirmBorderId,
			entry.selectBorderId
		}) do
			local border = tutorialVocationWindow:recursiveGetChildById(borderId)

			if border then
				border:raise()
			end
		end

		for _, buttonId in ipairs({
			entry.confirmButtonId,
			entry.selectButtonId
		}) do
			local button = tutorialVocationWindow:recursiveGetChildById(buttonId)

			if button then
				button:raise()
			end
		end
	end
end

function onVocationSelectClicked(selectButton)
	if not selectButton or selectButton:isDestroyed() then
		return
	end

	local buttonId = selectButton:getId()
	local entry

	for _, hoverEntry in ipairs(VOCATION_HOVER_ENTRIES) do
		if hoverEntry.selectButtonId == buttonId then
			entry = hoverEntry

			break
		end
	end

	if not entry then
		return
	end

	if selectedVocationEntry == entry then
		return
	end

	resetVocationSelection()

	selectedVocationEntry = entry

	setVocationSelectState(entry, true)
	raiseVocationActionButtons()
end

function onVocationConfirmClicked(confirmButton)
	if not confirmButton or confirmButton:isDestroyed() then
		return
	end

	if not g_game.isOnline() then
		return
	end

	local buttonId = confirmButton:getId()
	local entry

	for _, hoverEntry in ipairs(VOCATION_HOVER_ENTRIES) do
		if hoverEntry.confirmButtonId == buttonId then
			entry = hoverEntry

			break
		end
	end

	if not entry or selectedVocationEntry ~= entry or not entry.clientVocationId then
		return
	end

	g_game.sendSelectVocation(entry.clientVocationId)
	hide()
end

local function gameToWorldMapPixel(pos)
	return pos.x - WORLD_MAP.ORIGIN_X + WORLD_MAP.OFFSET_X, pos.y - WORLD_MAP.ORIGIN_Y + WORLD_MAP.OFFSET_Y
end

local function updateMainlandWorldMapPin()
	if not mainlandMapWidgets then
		return
	end

	local mapView = mainlandMapWidgets.mapView
	local pin = mainlandMapWidgets.pin

	if not mapView or mapView:isDestroyed() or not pin or pin:isDestroyed() then
		return
	end

	local player = g_game.getLocalPlayer()
	local pos = player and player:getPosition()

	if not pos then
		pin:hide()

		return
	end

	local mapPixelX, mapPixelY = gameToWorldMapPixel(pos)
	local zoom = mapView.zoom or 1
	local pinX = mapView:getX() + mapView:getImageOffsetX() + mapPixelX * zoom - WORLD_MAP.PIN_TIP_X
	local pinY = mapView:getY() + mapView:getImageOffsetY() + mapPixelY * zoom - WORLD_MAP.PIN_TIP_Y

	pin:breakAnchors()
	pin:setPosition({
		x = pinX,
		y = pinY
	})
	pin:show()
end

local function applyMainlandWorldMapCenter()
	if not mainlandMapWidgets then
		return
	end

	local mapView = mainlandMapWidgets.mapView

	if not mapView or mapView:isDestroyed() then
		return
	end

	if mapView:getImageTextureWidth() <= 0 then
		return
	end

	local player = g_game.getLocalPlayer()
	local pos = player and player:getPosition()

	if pos then
		local mapPixelX, mapPixelY = gameToWorldMapPixel(pos)

		mapView:move(mapPixelX, mapPixelY)
	else
		mapView:center()
	end
end

local function scheduleMainlandWorldMapPinSync()
	addEvent(function()
		if not mainlandMapWidgets then
			return
		end

		local mapView = mainlandMapWidgets.mapView

		if not mapView or mapView:isDestroyed() then
			return
		end

		local viewport = mapView:getParent()

		if viewport and not viewport:isDestroyed() then
			viewport:updateLayout()
		end

		applyMainlandWorldMapCenter()
	end)
end

local function teardownMainlandWorldMap()
	if mainlandPositionConn then
		disconnect(LocalPlayer, mainlandPositionConn)

		mainlandPositionConn = nil
	end

	mainlandWorldMapPinUpdater = nil
	mainlandMapWidgets = nil
end

local function setupMainlandWorldMap()
	teardownMainlandWorldMap()

	if not tutorialMainlandWindow or tutorialMainlandWindow:isDestroyed() then
		return
	end

	local viewport = tutorialMainlandWindow:recursiveGetChildById("realMapViewport")
	local mapView = viewport and viewport:getChildById("realMap")
	local pin = viewport and viewport:getChildById("worldMapPin")

	if not mapView or not pin then
		return
	end

	mainlandMapWidgets = {
		mapView = mapView,
		pin = pin
	}
	mainlandWorldMapPinUpdater = updateMainlandWorldMapPin

	if viewport and not viewport:isDestroyed() then
		viewport:updateLayout()
	end

	mapView.minZoom = WORLD_MAP.MIN_ZOOM
	mapView.maxZoom = WORLD_MAP.MAX_ZOOM
	mapView.alignRight = true

	mapView:setImageSource(WORLD_MAP.IMAGE)
	mapView:setZoom(WORLD_MAP.MAX_ZOOM)
	applyMainlandWorldMapCenter()
	scheduleMainlandWorldMapPinSync()

	mainlandPositionConn = connect(LocalPlayer, {
		onPositionChange = updateMainlandWorldMapPin
	})
end

local function hideTutorialMainlandWindow()
	teardownMainlandWorldMap()
	unlockTutorialModal(tutorialMainlandWindow)

	if not tutorialMainlandWindow or tutorialMainlandWindow:isDestroyed() then
		tutorialMainlandWindow = nil
	end
end

local function hideTutorialStartWindow()
	unlockTutorialModal(tutorialStartWindow)

	if not tutorialStartWindow or tutorialStartWindow:isDestroyed() then
		tutorialStartWindow = nil
	end
end

local function hideTutorialVocationWindow()
	resetVocationHoverState()
	unlockTutorialModal(tutorialVocationWindow)

	if not tutorialVocationWindow or tutorialVocationWindow:isDestroyed() then
		tutorialVocationWindow = nil
	end
end

local function setVocationHoverActive(entry, active)
	if not tutorialVocationWindow or tutorialVocationWindow:isDestroyed() then
		return
	end

	local background = tutorialVocationWindow:recursiveGetChildById(entry.backgroundId)
	local infoContainer = tutorialVocationWindow:recursiveGetChildById(entry.containerId)
	local highlightWidget = tutorialVocationWindow:recursiveGetChildById(entry.highlightId)

	if active then
		if selectedVocationEntry then
			resetVocationSelection()
		end

		if activeVocationHoverEntry and activeVocationHoverEntry ~= entry then
			setVocationHoverActive(activeVocationHoverEntry, false)
		end

		activeVocationHoverEntry = entry

		applyVocationBackgroundTint(background, true)

		if infoContainer and not infoContainer:isDestroyed() then
			animateVocationInfoSlide(infoContainer, true)
		end

		setVocationHighlightVisible(highlightWidget, true)

		if highlightWidget and not highlightWidget:isDestroyed() then
			highlightWidget:raise()
		end

		raiseVocationActionButtons()

		return
	end

	if activeVocationHoverEntry == entry then
		activeVocationHoverEntry = nil
	end

	applyVocationBackgroundTint(background, false)
	setVocationHighlightVisible(highlightWidget, false)

	if infoContainer and not infoContainer:isDestroyed() then
		hideVocationInfoSlide(infoContainer, false)
	end

	if selectedVocationEntry == entry then
		resetVocationSelection()
	else
		setVocationSelectState(entry, false)
	end
end

local function updateVocationHoverAt()
	if not tutorialVocationWindow or tutorialVocationWindow:isDestroyed() then
		return
	end

	local stage2 = tutorialVocationWindow:recursiveGetChildById("vocationStage2")

	if not stage2 or not stage2:isExplicitlyVisible() then
		if activeVocationHoverEntry then
			setVocationHoverActive(activeVocationHoverEntry, false)

			activeVocationHoverEntry = nil
		end

		return
	end

	local entry = findVocationHoverEntryAt()

	if entry == activeVocationHoverEntry then
		return
	end

	if activeVocationHoverEntry then
		setVocationHoverActive(activeVocationHoverEntry, false)
	end

	if entry then
		setVocationHoverActive(entry, true)
	end
end

local function bindVocationHoverMouseTracking()
	if not tutorialVocationWindow or tutorialVocationWindow:isDestroyed() then
		return
	end

	if tutorialVocationWindow.__vocationHoverMouseBound then
		return
	end

	tutorialVocationWindow.__vocationHoverMouseBound = true

	function tutorialVocationWindow.onMouseMove()
		updateVocationHoverAt()
	end
end

local function setupVocationBackgroundHovers()
	if not tutorialVocationWindow or tutorialVocationWindow:isDestroyed() then
		return
	end

	raiseVocationActionButtons()

	for _, entry in ipairs(VOCATION_HOVER_ENTRIES) do
		local background = tutorialVocationWindow:recursiveGetChildById(entry.backgroundId)
		local infoContainer = tutorialVocationWindow:recursiveGetChildById(entry.containerId)
		local highlightWidget = tutorialVocationWindow:recursiveGetChildById(entry.highlightId)
		local selectButton = tutorialVocationWindow:recursiveGetChildById(entry.selectButtonId)
		local confirmButton = tutorialVocationWindow:recursiveGetChildById(entry.confirmButtonId)

		if infoContainer then
			infoContainer:setMarginBottom(VOCATION_INFO_SLIDE.MARGIN_HIDDEN)
			infoContainer:hide()
		end

		setVocationHighlightVisible(highlightWidget, false)
		applyVocationBackgroundTint(background, false)
		setVocationSelectState(entry, false)

		if selectButton and not selectButton.__vocationSelectBound then
			selectButton.__vocationSelectBound = true

			function selectButton.onClick(widget)
				onVocationSelectClicked(widget)
			end
		end

		if confirmButton and not confirmButton.__vocationConfirmBound then
			confirmButton.__vocationConfirmBound = true

			function confirmButton.onClick(widget)
				onVocationConfirmClicked(widget)
			end
		end
	end

	bindVocationHoverMouseTracking()
end

local function resetVocationBackgroundTints()
	if not tutorialVocationWindow or tutorialVocationWindow:isDestroyed() then
		return
	end

	for _, entry in ipairs(VOCATION_HOVER_ENTRIES) do
		local background = tutorialVocationWindow:recursiveGetChildById(entry.backgroundId)

		if background then
			applyVocationBackgroundTint(background, false)
		end
	end

	resetVocationHoverState()
end

function showVocationStage(stage)
	if not tutorialVocationWindow or tutorialVocationWindow:isDestroyed() then
		return
	end

	local stageSize = VOCATION_STAGE_SIZES[stage]

	if stageSize then
		tutorialVocationWindow:setSize(string.format("%d %d", stageSize[1], stageSize[2]))
	end

	local stage1 = tutorialVocationWindow:recursiveGetChildById("vocationStage1")
	local stage2 = tutorialVocationWindow:recursiveGetChildById("vocationStage2")

	if stage1 then
		stage1:setVisible(stage == 1)
	end

	if stage2 then
		stage2:setVisible(stage == 2)
	end

	if stage == 1 then
		resetVocationSelection()
	else
		setupVocationBackgroundHovers()
		resetVocationBackgroundTints()
	end
end

local function setupTutorialLogo(window)
	if not window or window:isDestroyed() then
		return
	end

	local logo = window:getChildById("logoBackdropCrest")

	if not logo or logo:isDestroyed() then
		return
	end

	logo:setMarginTop(-69)
	logo:show()
	logo:raise()
end

local function setupVocationLogo()
	setupTutorialLogo(tutorialVocationWindow)
end

local function showTutorialStart(tutorialId)
	hideTutorialHintWindow()
	hideTutorialVocationWindow()
	hideTutorialMainlandWindow()

	local config = getTutorialConfig(tutorialId)

	if not config then
		return
	end

	if not tutorialStartWindow or tutorialStartWindow:isDestroyed() then
		tutorialStartWindow = g_ui.createWidget("TutorialStartWindow", rootWidget)
	end

	if config.size then
		tutorialStartWindow:setSize(string.format("%d %d", config.size[1], config.size[2]))
	end

	setupTutorialLogo(tutorialStartWindow)
	lockTutorialModal(tutorialStartWindow)
end

local function showTutorialMainland(tutorialId)
	hideTutorialHintWindow()
	hideTutorialVocationWindow()
	hideTutorialStartWindow()

	local config = getTutorialConfig(tutorialId)

	if not config then
		return
	end

	if not tutorialMainlandWindow or tutorialMainlandWindow:isDestroyed() then
		tutorialMainlandWindow = g_ui.createWidget("TutorialMainlandWindow", rootWidget)
	end

	if config.size then
		tutorialMainlandWindow:setSize(string.format("%d %d", config.size[1], config.size[2]))
	end

	setupTutorialLogo(tutorialMainlandWindow)
	lockTutorialModal(tutorialMainlandWindow)
	addEvent(function()
		if tutorialMainlandWindow and not tutorialMainlandWindow:isDestroyed() and tutorialMainlandWindow:isVisible() then
			setupMainlandWorldMap()
		end
	end)
end

local function showTutorialVocation()
	hideTutorialHintWindow()
	hideTutorialMainlandWindow()
	hideTutorialStartWindow()

	if not tutorialVocationWindow or tutorialVocationWindow:isDestroyed() then
		tutorialVocationWindow = g_ui.createWidget("TutorialVocationWindow", rootWidget)
	end

	setupVocationLogo()
	setupVocationBackgroundHovers()
	showVocationStage(1)
	lockTutorialModal(tutorialVocationWindow)
end

local function showTutorialHint(tutorialId)
	hideTutorialVocationWindow()
	hideTutorialMainlandWindow()
	hideTutorialStartWindow()

	local config = TUTORIALS[tutorialId]

	if not config then
		return
	end

	local imagePath = config.image or resolveHintImagePath(config.hintKey)

	if not imagePath or not g_resources.fileExists(imagePath) then
		g_logger.warning(string.format("game_tutorial: image not found for tutorial id %s", tutorialId))

		return
	end

	if not tutorialHintWindow or tutorialHintWindow:isDestroyed() then
		tutorialHintWindow = g_ui.createWidget("TutorialPopupWindow", rootWidget)
	end

	tutorialHintWindow:setText(tr(config.title))

	if config.size then
		tutorialHintWindow:setSize(string.format("%d %d", config.size[1], config.size[2]))
	end

	local hintImage = tutorialHintWindow:recursiveGetChildById("hintImage")

	if hintImage then
		applyHintImage(hintImage, imagePath, config.imageSize)
	end

	lockTutorialModal(tutorialHintWindow)
end

function hide()
	resetVocationHoverState()
	hideTutorialHintWindow()
	hideTutorialVocationWindow()
	hideTutorialMainlandWindow()
	hideTutorialStartWindow()
end

function show(tutorialId)
	local tutorialType = getTutorialType(tutorialId)

	if tutorialType == TUTORIAL_TYPE.VOCATION then
		showTutorialVocation()

		return
	end

	if tutorialType == TUTORIAL_TYPE.MAINLAND then
		showTutorialMainland(tutorialId)

		return
	end

	if tutorialType == TUTORIAL_TYPE.START then
		showTutorialStart(tutorialId)

		return
	end

	showTutorialHint(tutorialId)
end

local function onTutorialHint(tutorialId)
	show(tutorialId)
end

function init()
	g_ui.importStyle("tutorial_popup")
	g_ui.importStyle("tutorial_vocation")
	g_ui.importStyle("tutorial_mainland")
	g_ui.importStyle("tutorial_start")
	connect(g_game, {
		onTutorialHint = onTutorialHint,
		onGameEnd = hide
	})
end

function terminate()
	disconnect(g_game, {
		onTutorialHint = onTutorialHint,
		onGameEnd = hide
	})
	hide()

	if tutorialHintWindow and not tutorialHintWindow:isDestroyed() then
		tutorialHintWindow:destroy()
	end

	if tutorialVocationWindow and not tutorialVocationWindow:isDestroyed() then
		tutorialVocationWindow:destroy()
	end

	if tutorialMainlandWindow and not tutorialMainlandWindow:isDestroyed() then
		tutorialMainlandWindow:destroy()
	end

	if tutorialStartWindow and not tutorialStartWindow:isDestroyed() then
		tutorialStartWindow:destroy()
	end

	tutorialHintWindow = nil
	tutorialVocationWindow = nil
	tutorialMainlandWindow = nil
	tutorialStartWindow = nil
	lockedTutorialWindow = nil
end
