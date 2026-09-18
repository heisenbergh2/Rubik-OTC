-- chunkname: @/corelib/sidebar_widget_options.lua

SidebarWidgetOptions = {}
SidebarLayoutState = {
	widgets = {}
}

local WIDGET_ID_TO_TYPE = {}
local WIDGET_TYPE_TO_ID = {
	xpAnalyser = "xpAnalyserMiniWindow",
	supplyAnalyser = "supplyAnalyserMiniWindow",
	dropTracker = "dropTrackerMiniWindow",
	lootAnalyser = "lootAnalyserMiniWindow",
	bossCooldown = "bossCdAnalyserMiniWindow",
	analyticsSelector = "analyserMiniWindow",
	minimap = "mainmappanel",
	questTracker = "QuestLogTracker",
	imbuementTracker = "imbuementTracker",
	partyHuntAnalyser = "phAnalyserMiniWindow",
	prey = "preyTracker",
	huntingSessionAnalyser = "huntingAnalyserMiniWindow",
	vip = "vipWindow",
	damageInputAnalyser = "inputAnalyserMiniWindow",
	skills = "skillWindow",
	impactAnalyser = "impactAnalyserMiniWindow"
}
local WIDGET_ID_FALLBACKS = {
	skillWindow = {
		"skills",
		0
	},
	battleWindow = {
		"battleList",
		0
	},
	vipWindow = {
		"vip",
		0
	},
	partyWindow = {
		"partyList",
		0
	},
	unjustifiedPointsWindow = {
		"unjustifiedPoints",
		0
	},
	preyTracker = {
		"prey",
		0
	},
	imbuementTracker = {
		"imbuementTracker",
		0
	},
	QuestLogTracker = {
		"questTracker",
		0
	},
	spellListMiniWindow = {
		"spellList",
		0
	},
	helperStatsWindow = {
		"helperStats",
		0
	},
	analyserMiniWindow = {
		"analyticsSelector",
		0
	},
	lootAnalyserMiniWindow = {
		"lootAnalyser",
		0
	},
	supplyAnalyserMiniWindow = {
		"supplyAnalyser",
		0
	},
	impactAnalyserMiniWindow = {
		"impactAnalyser",
		0
	},
	inputAnalyserMiniWindow = {
		"damageInputAnalyser",
		0
	},
	huntingAnalyserMiniWindow = {
		"huntingSessionAnalyser",
		0
	},
	phAnalyserMiniWindow = {
		"partyHuntAnalyser",
		0
	},
	xpAnalyserMiniWindow = {
		"xpAnalyser",
		0
	},
	BestiaryTrackerWindow = {
		"bestiaryTracker",
		0
	},
	BosstiaryTrackerWindow = {
		"bosstiaryTracker",
		0
	},
	dropTrackerMiniWindow = {
		"dropTracker",
		0
	},
	bossCdAnalyserMiniWindow = {
		"bossCooldown",
		0
	},
	mainmappanel = {
		"minimap",
		0
	}
}

local function ensureWidgetIdToTypeMap()
	if not CipImportMappings or not CipImportMappings.SIDEBAR_WIDGET_MAP then
		return
	end

	for widgetType, mapping in pairs(CipImportMappings.SIDEBAR_WIDGET_MAP) do
		if mapping.widgetId and not WIDGET_ID_TO_TYPE[mapping.widgetId] then
			WIDGET_ID_TO_TYPE[mapping.widgetId] = {
				type = widgetType,
				primaryInstance = mapping.primaryInstance
			}
		end
	end
end

function SidebarLayoutState.canonicalParentId(panelId)
	if type(panelId) ~= "string" then
		return panelId
	end

	if panelId:find("^gameLeftExtraPanel") then
		return panelId:match("^(gameLeftExtraPanel_%d+)$") or "gameLeftExtraPanel"
	end

	if panelId:find("^gameRightExtraPanel") then
		return panelId:match("^(gameRightExtraPanel_%d+)$") or "gameRightExtraPanel"
	end

	return panelId
end

function SidebarLayoutState.resolveTypeFromWidgetId(widgetId)
	if type(widgetId) ~= "string" then
		return nil
	end

	local containerId = widgetId:match("^container(%d+)$")

	if containerId then
		return "container", tonumber(containerId)
	end

	local battleInstance = widgetId:match("^battleWindow_(%d+)$")

	if battleInstance then
		return "battleList", tonumber(battleInstance)
	end

	if widgetId == "battleWindow" then
		return "battleList", 0
	end

	local fallback = WIDGET_ID_FALLBACKS[widgetId]

	if fallback then
		return fallback[1], fallback[2]
	end

	ensureWidgetIdToTypeMap()

	local mapping = WIDGET_ID_TO_TYPE[widgetId]

	if mapping then
		return mapping.type, mapping.primaryInstance or 0
	end

	return nil
end

local function isSidebarParentId(parentId)
	if not parentId then
		return false
	end

	if parentId == "gameRightTopPanel" or parentId == "gameLeftTopPanel" then
		return true
	end

	if modules.game_interface and modules.game_interface.isGameSidePanelId then
		return modules.game_interface.isGameSidePanelId(parentId)
	end

	return parentId == "gameRightPanel" or parentId == "gameLeftPanel" or parentId:find("^gameLeftExtraPanel") ~= nil or parentId:find("^gameRightExtraPanel") ~= nil
end

function SidebarLayoutState.clear()
	SidebarLayoutState.widgets = {}
end

function SidebarLayoutState.syncFromPanels()
	if not modules.game_interface then
		return
	end

	local panels = {}
	local seen = {}

	local function visitPanel(panel)
		if not panel or panel:isDestroyed() or seen[panel] then
			return
		end

		seen[panel] = true
		panels[#panels + 1] = panel
	end

	if modules.game_interface.getMiniWindowSidebarPanelsInOrder then
		for _, panel in ipairs(modules.game_interface.getMiniWindowSidebarPanelsInOrder()) do
			visitPanel(panel)
		end
	end

	if modules.game_interface.getHorizontalSidebarPanelsInStorageOrder then
		for _, panel in ipairs(modules.game_interface.getHorizontalSidebarPanelsInStorageOrder()) do
			visitPanel(panel)
		end
	end

	if #panels == 0 and modules.game_interface.getRightPanel then
		visitPanel(modules.game_interface.getRightPanel())
	end

	for _, panel in ipairs(panels) do
		for _, child in ipairs(panel:getChildren()) do
			if child.save and not child:isDestroyed() and SidebarLayoutState.shouldTrackWidget(child) then
				SidebarLayoutState.noteWidgetPlacement(child)
			end
		end
	end

	if g_game and g_game.getContainers then
		for _, container in pairs(g_game.getContainers()) do
			if container.window and not container.window:isDestroyed() and SidebarLayoutState.shouldTrackWidget(container.window) then
				SidebarLayoutState.noteWidgetPlacement(container.window)
			end
		end
	end
end

function SidebarLayoutState.getWidgets()
	return SidebarLayoutState.widgets
end

function SidebarLayoutState.shouldTrackWidget(widget)
	if not widget or widget:isDestroyed() or not widget.getId then
		return false
	end

	return SidebarWidgetOptions.isDockedInSidebar(widget)
end

function SidebarLayoutState.pruneUntrackedWidgets()
	local rootWidget = g_ui.getRootWidget()

	if not rootWidget then
		return
	end

	for widgetId in pairs(SidebarLayoutState.widgets) do
		local widget = rootWidget:recursiveGetChildById(widgetId)

		if not widget or widget:isDestroyed() or not SidebarWidgetOptions.isDockedInSidebar(widget) then
			SidebarLayoutState.widgets[widgetId] = nil
		end
	end
end

function SidebarLayoutState.noteWidgetPlacement(widget)
	if not widget or widget:isDestroyed() or not widget.save or not widget.getId then
		return
	end

	local widgetId = widget:getId()
	local parent = widget:getParent()

	if not parent or parent:isDestroyed() then
		SidebarLayoutState.widgets[widgetId] = nil

		return
	end

	local parentId = parent:getId()

	if not isSidebarParentId(parentId) then
		SidebarLayoutState.widgets[widgetId] = nil

		return
	end

	if not SidebarLayoutState.shouldTrackWidget(widget) then
		return
	end

	local index = widget.miniIndex

	if not index and parent:getClassName() == "UIMiniWindowContainer" then
		local children = parent:getChildren()
		local idx = 0

		for i = 1, #children do
			if children[i].save then
				idx = idx + 1
			end

			if children[i] == widget then
				index = idx

				break
			end
		end
	end

	local widgetType, instance = SidebarLayoutState.resolveTypeFromWidgetId(widgetId)

	if not widgetType then
		return
	end

	SidebarLayoutState.widgets[widgetId] = {
		type = widgetType,
		instance = instance or 0,
		parentId = SidebarLayoutState.canonicalParentId(parentId),
		index = index or 1
	}
end

local function appendWidgetEntry(widgets, seen, widgetType, instance, index)
	local key = widgetType .. ":" .. tostring(instance or 0)

	if seen[key] then
		return
	end

	seen[key] = true

	local entry = {
		type = widgetType,
		_index = index or #widgets + 1
	}

	if widgetType == "container" or instance and instance ~= 0 then
		entry.instance = instance or 0
	end

	table.insert(widgets, entry)
end

local function collectWidgetsInPanel(panel, parentId)
	local widgets = {}
	local seen = {}

	if parentId then
		local canonicalId = SidebarLayoutState.canonicalParentId(parentId)

		for _, data in pairs(SidebarLayoutState.widgets) do
			if SidebarLayoutState.canonicalParentId(data.parentId) == canonicalId then
				appendWidgetEntry(widgets, seen, data.type, data.instance, data.index)
			end
		end
	end

	table.sort(widgets, function(a, b)
		return (a._index or 0) < (b._index or 0)
	end)

	for i = 1, #widgets do
		widgets[i]._index = nil
	end

	return widgets
end

local function getVerticalPanelsForCollect()
	local panels = {}
	local seen = {}

	local function addPanel(panel, parentId)
		if not panel or panel:isDestroyed() or seen[parentId] then
			return
		end

		seen[parentId] = true
		panels[#panels + 1] = {
			panel = panel,
			parentId = parentId
		}
	end

	if modules.game_interface and modules.game_interface.getVerticalSidebarPanelsInStorageOrder then
		for _, panel in ipairs(modules.game_interface.getVerticalSidebarPanelsInStorageOrder()) do
			addPanel(panel, SidebarLayoutState.canonicalParentId(panel:getId()))
		end
	end

	local parentOrder = {
		"gameRightPanel",
		"gameRightExtraPanel",
		"gameLeftPanel",
		"gameLeftExtraPanel"
	}

	for i = 2, 20 do
		parentOrder[#parentOrder + 1] = "gameRightExtraPanel_" .. i
		parentOrder[#parentOrder + 1] = "gameLeftExtraPanel_" .. i
	end

	for _, parentId in ipairs(parentOrder) do
		if not seen[parentId] then
			for _, data in pairs(SidebarLayoutState.widgets) do
				if data.parentId == parentId then
					local rootWidget = g_ui.getRootWidget()
					local panel = rootWidget and rootWidget:recursiveGetChildById(parentId)

					addPanel(panel, parentId)

					break
				end
			end
		end
	end

	if not seen.gameRightPanel and modules.game_interface and modules.game_interface.getRightPanel then
		addPanel(modules.game_interface.getRightPanel(), "gameRightPanel")
	end

	return panels
end

function SidebarLayoutState.collectVerticalWidgetOrder()
	local orderPerSidebar = {}

	for _, entry in ipairs(getVerticalPanelsForCollect()) do
		orderPerSidebar[#orderPerSidebar + 1] = collectWidgetsInPanel(entry.panel, entry.parentId)
	end

	if #orderPerSidebar == 0 and modules.game_interface and modules.game_interface.getRightPanel then
		local panel = modules.game_interface.getRightPanel()

		if panel and not panel:isDestroyed() then
			orderPerSidebar[1] = collectWidgetsInPanel(panel, "gameRightPanel")
		end
	end

	return orderPerSidebar
end

function SidebarLayoutState.collectHorizontalWidgetOrder()
	local orderPerSidebar = {}

	if modules.game_interface and modules.game_interface.getHorizontalSidebarPanelsInStorageOrder then
		for _, panel in ipairs(modules.game_interface.getHorizontalSidebarPanelsInStorageOrder()) do
			if panel and not panel:isDestroyed() then
				orderPerSidebar[#orderPerSidebar + 1] = collectWidgetsInPanel(panel, panel:getId())
			end
		end
	end

	return orderPerSidebar
end

function SidebarWidgetOptions.measureContentHeight(window)
	if not window or window:isDestroyed() then
		return 0
	end

	local resizeBorder = window:getChildById("bottomResizeBorder")

	if resizeBorder then
		local contentsPanel = window:getChildById("contentsPanel")
		local chrome = 0

		if contentsPanel then
			chrome = contentsPanel:getMarginTop() + contentsPanel:getMarginBottom() + contentsPanel:getPaddingTop() + contentsPanel:getPaddingBottom()
		end

		local measured = math.max(0, resizeBorder:getParentSize() - chrome)

		if measured > 0 then
			return measured
		end

		if window:isExplicitlyVisible() and not window:isOn() then
			local parentSize = resizeBorder:getParentSize()

			if parentSize and chrome < parentSize then
				return math.max(0, parentSize - chrome)
			end
		end
	end

	if window.maximizedHeight and window.maximizedHeight > 0 then
		return window.maximizedHeight
	end

	if window:isExplicitlyVisible() and not window:isOn() and window.getHeight then
		local contentsPanel = window:getChildById("contentsPanel")

		if contentsPanel then
			local chrome = contentsPanel:getMarginTop() + contentsPanel:getMarginBottom() + contentsPanel:getPaddingTop() + contentsPanel:getPaddingBottom()

			return math.max(0, window:getHeight() - chrome)
		end

		return math.max(0, window:getHeight())
	end

	return 0
end

function SidebarWidgetOptions.collectBaseOptions(window)
	if not window or window:isDestroyed() then
		return nil
	end

	local opts = {}

	if not window:isExplicitlyVisible() then
		opts.contentHeight = 0
		opts.contentMaximized = true

		return opts
	end

	if window:isOn() then
		opts.contentMaximized = false

		local chrome = 0
		local contentsPanel = window:getChildById("contentsPanel")

		if contentsPanel then
			chrome = contentsPanel:getMarginTop() + contentsPanel:getMarginBottom() + contentsPanel:getPaddingTop() + contentsPanel:getPaddingBottom()
		end

		if window.maximizedHeight and chrome < window.maximizedHeight then
			opts.contentHeight = window.maximizedHeight - chrome
		else
			opts.contentHeight = 0
		end

		return opts
	end

	opts.contentMaximized = true
	opts.contentHeight = SidebarWidgetOptions.measureContentHeight(window)

	return opts
end

function SidebarWidgetOptions.applyBaseOptions(window, opts)
	if not window or window:isDestroyed() or type(opts) ~= "table" then
		return
	end

	local forceOpen = false

	if window.save and modules.game_interface and modules.game_interface.SidebarWidgetsPersistence and modules.game_interface.SidebarWidgetsPersistence.getWidgetPlacement then
		forceOpen = modules.game_interface.SidebarWidgetsPersistence.getWidgetPlacement(window:getId()) ~= nil
	end

	if opts.contentHeight == 0 and opts.contentMaximized == true and not forceOpen then
		if window:isVisible() then
			window:close(true)
		end

		return
	end

	local wasHidden = not window:isVisible()

	if wasHidden and window.open then
		window:open(true)

		local w = window

		addEvent(function()
			if w and not w:isDestroyed() and w:isExplicitlyVisible() then
				signalcall(w.onOpen, w)
			end
		end)
	end

	local wid = window.getId and window:getId() or "?"

	if opts.contentHeight == 0 and opts.contentMaximized == true and not forceOpen then
		if window:isVisible() then
			window:close(true)
		end

		return
	end

	local contentsPanel = window:getChildById("contentsPanel")
	local chrome = 0

	if contentsPanel then
		chrome = contentsPanel:getMarginTop() + contentsPanel:getMarginBottom() + contentsPanel:getPaddingTop() + contentsPanel:getPaddingBottom()
	end

	local desiredMaxHeight

	if type(opts.contentHeight) == "number" and opts.contentHeight > 0 then
		desiredMaxHeight = opts.contentHeight + chrome
		window.maximizedHeight = desiredMaxHeight
	end

	if opts.contentMaximized == false then
		if window:isVisible() and not window:isOn() then
			window:minimize(true)
		end
	elseif opts.contentMaximized == true and window:isOn() then
		window:maximize(true)
	end

	if opts.contentMaximized == true and type(opts.contentHeight) == "number" and opts.contentHeight > 0 and not window:isOn() then
		if window.setContentHeight then
			window:setContentHeight(opts.contentHeight)
		elseif window:isResizeable() then
			window:setHeight(opts.contentHeight)
		end

		window.maximizedHeight = window:getHeight()
	end

	if SidebarLayoutState and SidebarLayoutState.noteWidgetPlacement then
		SidebarLayoutState.noteWidgetPlacement(window)
	end
end

function SidebarWidgetOptions.resolveWindow(widgetType, instance)
	local rootWidget = g_ui.getRootWidget()

	if not rootWidget then
		return nil
	end

	if widgetType == "container" then
		return rootWidget:recursiveGetChildById("container" .. tostring(instance or 0))
	end

	if widgetType == "battleList" then
		instance = tonumber(instance) or 0

		if instance == 0 then
			return rootWidget:recursiveGetChildById("battleWindow")
		end

		return rootWidget:recursiveGetChildById("battleWindow_" .. instance)
	end

	if widgetType == "bestiaryTracker" then
		return rootWidget:recursiveGetChildById("BestiaryTrackerWindow")
	end

	if widgetType == "bosstiaryTracker" then
		return rootWidget:recursiveGetChildById("BosstiaryTrackerWindow")
	end

	if widgetType == "partyList" then
		return rootWidget:recursiveGetChildById("partyWindow")
	end

	if widgetType == "unjustifiedPoints" then
		return rootWidget:recursiveGetChildById("unjustifiedPointsWindow")
	end

	if widgetType == "spellList" then
		return rootWidget:recursiveGetChildById("spellListMiniWindow")
	end

	if widgetType == "helperStats" then
		return rootWidget:recursiveGetChildById("helperStatsWindow")
	end

	local widgetId = WIDGET_TYPE_TO_ID[widgetType]

	if widgetId then
		return rootWidget:recursiveGetChildById(widgetId)
	end

	if CipImportMappings and CipImportMappings.resolveSidebarWidgetId then
		local widgetId = CipImportMappings.resolveSidebarWidgetId(widgetType, instance)

		if widgetId then
			return rootWidget:recursiveGetChildById(widgetId)
		end
	end

	return nil
end

function SidebarWidgetOptions.forEachPlacedWidget(callback)
	if type(callback) ~= "function" then
		return
	end

	local seen = {}

	for widgetId, data in pairs(SidebarLayoutState.widgets) do
		if not seen[widgetId] then
			seen[widgetId] = true

			local rootWidget = g_ui.getRootWidget()
			local widget = rootWidget and rootWidget:recursiveGetChildById(widgetId)

			if widget and not widget:isDestroyed() then
				callback(widget, widgetId, data)
			end
		end
	end

	if not modules.game_interface then
		return
	end

	local function visitPanel(panel)
		if not panel or panel:isDestroyed() then
			return
		end

		for _, child in ipairs(panel:getChildren()) do
			if child.save and not child:isDestroyed() then
				local widgetId = child:getId()

				if widgetId and not seen[widgetId] then
					seen[widgetId] = true

					callback(child, widgetId)
				end
			end
		end
	end

	for _, entry in ipairs(getVerticalPanelsForCollect()) do
		visitPanel(entry.panel)
	end

	if modules.game_interface.getHorizontalSidebarPanelsInStorageOrder then
		for _, panel in ipairs(modules.game_interface.getHorizontalSidebarPanelsInStorageOrder()) do
			visitPanel(panel)
		end
	end
end

function SidebarWidgetOptions.isDockedInSidebar(window)
	if not window or window:isDestroyed() or not window:isExplicitlyVisible() then
		return false
	end

	local parent = window:getParent()

	if not parent or parent:isDestroyed() then
		return false
	end

	local parentId = parent:getId()

	if parentId == "gameRightTopPanel" or parentId == "gameLeftTopPanel" then
		return true
	end

	if modules.game_interface and modules.game_interface.isGameSidePanelId then
		return modules.game_interface.isGameSidePanelId(parentId)
	end

	return parentId == "gameRightPanel" or parentId == "gameLeftPanel" or parentId:find("^gameLeftExtraPanel") ~= nil or parentId:find("^gameRightExtraPanel") ~= nil
end

function SidebarWidgetOptions.syncToggleButton(window, button, openTooltip, closeTooltip)
	if not button or button:isDestroyed() then
		return
	end

	local on = SidebarWidgetOptions.isDockedInSidebar(window)

	button:setOn(on)

	if button.setTooltip and openTooltip and closeTooltip then
		button:setTooltip(tr(on and closeTooltip or openTooltip))
	end
end

function SidebarWidgetOptions.widgetTypeFromId(widgetId)
	return SidebarLayoutState.resolveTypeFromWidgetId(widgetId)
end
