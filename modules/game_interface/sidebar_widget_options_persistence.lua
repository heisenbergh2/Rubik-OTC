-- chunkname: @/game_interface/sidebar_widget_options_persistence.lua

SidebarWidgetOptionsPersistence = {}

local WIDGET_TYPE_TO_ID = {
	prey = "preyTracker",
	bosstiaryTracker = "BosstiaryTrackerWindow",
	battleList = "battleWindow",
	dropTracker = "dropTrackerMiniWindow",
	partyList = "partyWindow",
	bestiaryTracker = "BestiaryTrackerWindow",
	vip = "vipWindow",
	xpAnalyser = "xpAnalyserMiniWindow",
	skills = "skillWindow",
	partyHuntAnalyser = "phAnalyserMiniWindow",
	bossCooldown = "bossCdAnalyserMiniWindow",
	huntingSessionAnalyser = "huntingAnalyserMiniWindow",
	damageInputAnalyser = "inputAnalyserMiniWindow",
	impactAnalyser = "impactAnalyserMiniWindow",
	supplyAnalyser = "supplyAnalyserMiniWindow",
	lootAnalyser = "lootAnalyserMiniWindow",
	analyticsSelector = "analyserMiniWindow",
	helperStats = "helperStatsWindow",
	spellList = "spellListMiniWindow",
	unjustifiedPoints = "unjustifiedPointsWindow",
	questTracker = "QuestLogTracker",
	imbuementTracker = "imbuementTracker"
}
local WIDGET_TYPE_TO_MODULE = {
	prey = "game_prey",
	bosstiaryTracker = "game_cyclopedia",
	battleList = "game_battle",
	dropTracker = "game_analysers",
	partyList = "game_party",
	bestiaryTracker = "game_cyclopedia",
	vip = "game_viplist",
	xpAnalyser = "game_analysers",
	skills = "game_skills",
	partyHuntAnalyser = "game_analysers",
	bossCooldown = "game_analysers",
	huntingSessionAnalyser = "game_analysers",
	damageInputAnalyser = "game_analysers",
	impactAnalyser = "game_analysers",
	supplyAnalyser = "game_analysers",
	lootAnalyser = "game_analysers",
	analyticsSelector = "game_analysers",
	helperStats = "game_helper",
	spellList = "game_spelllist",
	unjustifiedPoints = "game_unjustifiedpoints",
	questTracker = "game_questlog",
	imbuementTracker = "game_imbuementtracker"
}
local SIMPLE_WIDGET_SECTIONS = {}
local OPTION_WIDGET_TYPES = {
	bossCdAnalyserOptions = "bossCooldown",
	dropTrackerAnalyserOptions = "dropTracker",
	xpAnalyserWidgetOptions = "xpAnalyser",
	unjustifiedPointsOptions = "unjustifiedPoints",
	supplyAnalyserWidgetOptions = "supplyAnalyser",
	spellListWidgetOptions = "spellList",
	questTrackerWidgetOptions = "questTracker",
	partyWidgetOptions = "partyList",
	partyHuntAnalyserOptions = "partyHuntAnalyser",
	lootAnalyserWidgetOptions = "lootAnalyser",
	impactAnalyserWidgetOptions = "impactAnalyser",
	huntingSessionAnalyserWidgetOptions = "huntingSessionAnalyser",
	helperStatsWidgetOptions = "helperStats",
	damageInputAnalyserWidgetOptions = "damageInputAnalyser",
	bosstiaryTrackerWidgetOptions = "bosstiaryTracker",
	bestiaryTrackerWidgetOptions = "bestiaryTracker",
	analyticsSelectorOptions = "analyticsSelector"
}
local STATIC_OPTION_DEFAULTS = {
	bossTrackerWidgetOptions = {},
	depotSearchWidgetOptions = {
		showLockerOnly = false
	},
	lootTrackerWidgetOptions = {},
	npcTradeOptions = {
		sortFieldWhenBuying = "name",
		showNameFilter = true,
		purchaseShoppingBagWhenBuying = false,
		ignoreCapacityWhenBuying = false,
		allowSellingEquippedItems = false,
		allowLargeTradesWithoutWarning = false,
		sortFieldWhenSelling = "amount"
	}
}
local providersRegistered = false

local function mergeOptions(target, source)
	if type(target) ~= "table" or type(source) ~= "table" then
		return target
	end

	for key, value in pairs(source) do
		target[key] = value
	end

	return target
end

local function mergeSectionFromDocument(sectionKey, section)
	local existing = SidebarPersistence.getSection(sectionKey)

	if type(existing) == "table" then
		mergeOptions(section, existing)
	end
end

local WIDGET_TYPE_TO_SECTION = {
	prey = "preyWidgetOptions",
	bosstiaryTracker = "bosstiaryTrackerWidgetOptions",
	battleList = "battleListsOptions",
	dropTracker = "dropTrackerAnalyserOptions",
	partyList = "partyWidgetOptions",
	bestiaryTracker = "bestiaryTrackerWidgetOptions",
	vip = "vipWidgetOptions",
	xpAnalyser = "xpAnalyserWidgetOptions",
	skills = "skillsWidgetOptions",
	partyHuntAnalyser = "partyHuntAnalyserOptions",
	bossCooldown = "bossCdAnalyserOptions",
	huntingSessionAnalyser = "huntingSessionAnalyserWidgetOptions",
	damageInputAnalyser = "damageInputAnalyserWidgetOptions",
	impactAnalyser = "impactAnalyserWidgetOptions",
	lootAnalyser = "lootAnalyserWidgetOptions",
	analyticsSelector = "analyticsSelectorOptions",
	helperStats = "helperStatsWidgetOptions",
	spellList = "spellListWidgetOptions",
	unjustifiedPoints = "unjustifiedPointsOptions",
	questTracker = "questTrackerWidgetOptions",
	imbuementTracker = "imbuementTrackerWidgetOptions"
}

function SidebarWidgetOptionsPersistence.clearContainerOptions(containerId)
	if not SidebarPersistence or not SidebarPersistence.active then
		return
	end

	local section = SidebarPersistence.getSection("containersOptions")

	if type(section) == "table" then
		section[tostring(containerId)] = nil
	end
end

function SidebarWidgetOptionsPersistence.clearBattleListOptions(id)
	if not SidebarPersistence or not SidebarPersistence.active then
		return
	end

	local section = SidebarPersistence.getSection("battleListsOptions")

	if type(section) == "table" then
		section[tostring(id)] = nil
	end
end

function SidebarWidgetOptionsPersistence.clearWidgetOptionsById(widgetId)
	if not SidebarPersistence or not SidebarPersistence.active then
		return
	end

	if not SidebarLayoutState or not SidebarLayoutState.resolveTypeFromWidgetId then
		return
	end

	local widgetType, instance = SidebarLayoutState.resolveTypeFromWidgetId(widgetId)

	if not widgetType then
		return
	end

	if widgetType == "container" then
		SidebarWidgetOptionsPersistence.clearContainerOptions(instance)

		return
	end

	if widgetType == "battleList" then
		SidebarWidgetOptionsPersistence.clearBattleListOptions(instance)

		return
	end

	local sectionKey = WIDGET_TYPE_TO_SECTION[widgetType]

	if not sectionKey then
		return
	end

	local document = SidebarPersistence.document

	if type(document) == "table" then
		document[sectionKey] = nil
	end
end

local function ensureDefaultBaseOptions(section)
	if section.contentHeight == nil then
		section.contentHeight = 0
	end

	if section.contentMaximized == nil then
		section.contentMaximized = true
	end
end

local function ensureSimpleWidgetSections()
	if not CipImportMappings or not CipImportMappings.SIDEBAR_WIDGET_OPTIONS_KEYS then
		return
	end

	for widgetType, mapping in pairs(CipImportMappings.SIDEBAR_WIDGET_OPTIONS_KEYS) do
		if mapping.section and not mapping.useInstance then
			SIMPLE_WIDGET_SECTIONS[widgetType] = mapping.section

			if not OPTION_WIDGET_TYPES[mapping.section] then
				OPTION_WIDGET_TYPES[mapping.section] = widgetType
			end
		end
	end
end

local function collectTrackerSortOptions(section, widgetType)
	if widgetType ~= "bestiaryTracker" and widgetType ~= "bosstiaryTracker" then
		return
	end

	local trackerType = widgetType == "bosstiaryTracker" and "bosstiary" or "bestiary"

	if modules.game_cyclopedia and Cyclopedia and Cyclopedia.loadTrackerFilters then
		local filters = Cyclopedia.loadTrackerFilters(trackerType)

		if type(filters) == "table" then
			if filters.ShortByPercentage then
				section.sortKey = "completion"
			elseif filters.sortByKills then
				section.sortKey = "remaining"
			else
				section.sortKey = "name"
			end

			section.sortOrder = filters.sortByDescending and "descending" or "ascending"

			return
		end
	end

	section.sortKey = section.sortKey or "name"
	section.sortOrder = section.sortOrder or "ascending"
end

local function collectSpellListOptions(section)
	if modules.game_spelllist and modules.game_spelllist.getSpellListConfig then
		local config = modules.game_spelllist.getSpellListConfig()

		if type(config) == "table" then
			mergeOptions(section, config)
		end
	end
end

local function resolveWindowForSection(widgetType, instance)
	instance = instance or 0

	local window = SidebarWidgetOptions.resolveWindow(widgetType, instance)

	if window and not window:isDestroyed() then
		return window
	end

	local widgetId = WIDGET_TYPE_TO_ID[widgetType]
	local registryWidget = g_ui.loadedWidgetsById and g_ui.loadedWidgetsById[widgetId]

	if registryWidget and not registryWidget:isDestroyed() then
		return registryWidget
	end

	if widgetId then
		local moduleName = WIDGET_TYPE_TO_MODULE[widgetType]

		if moduleName then
			local module = modules[moduleName]

			if module and module[widgetId] and not module[widgetId]:isDestroyed() then
				return module[widgetId]
			end
		end
	end

	if SidebarLayoutState and SidebarLayoutState.getWidgets then
		for widgetId, data in pairs(SidebarLayoutState.getWidgets()) do
			if data.type == widgetType and (data.instance or 0) == instance then
				local rootWidget = g_ui.getRootWidget()

				window = rootWidget and rootWidget:recursiveGetChildById(widgetId)

				if window and not window:isDestroyed() then
					return window
				end
			end
		end
	end

	return nil
end

local function replaceSectionContents(section, data)
	if type(section) ~= "table" or type(data) ~= "table" then
		return
	end

	for key in pairs(section) do
		section[key] = nil
	end

	mergeOptions(section, data)
end

local function collectWidgetOptionsSection(sectionKey, widgetType, extraCollect)
	local section = {}
	local existing = SidebarPersistence.getSection(sectionKey)
	local window = resolveWindowForSection(widgetType, 0)
	local live = SidebarWidgetOptions.collectBaseOptions(window)

	if live then
		section.contentHeight = live.contentHeight
		section.contentMaximized = live.contentMaximized
	elseif type(existing) == "table" then
		section.contentHeight = existing.contentHeight
		section.contentMaximized = existing.contentMaximized
	end

	if type(existing) == "table" then
		for key, value in pairs(existing) do
			if key ~= "contentHeight" and key ~= "contentMaximized" and key ~= "_jsonKeyOrder" then
				section[key] = value
			end
		end
	end

	if extraCollect then
		extraCollect(section, widgetType)
	end

	ensureDefaultBaseOptions(section)

	return section
end

local function collectImbuementTrackerOptions()
	local section = collectWidgetOptionsSection("imbuementTrackerWidgetOptions", "imbuementTracker")
	local filters = {}

	if modules.game_imbuementtracker and modules.game_imbuementtracker.loadFilters then
		filters = modules.game_imbuementtracker.loadFilters()
	end

	section.showAlmostGone = filters.showLessThan1h == true
	section.showAlmostNew = filters.showBetween1hAnd3h == true
	section.showUsed = filters.showMoreThan3h == true
	section.showEmptySlots = filters.showNoImbuements == true

	return section
end

local function applyImbuementTrackerOptions(opts)
	local window = resolveWindowForSection("imbuementTracker", 0)

	SidebarWidgetOptions.applyBaseOptions(window, opts)

	if type(opts) ~= "table" or not modules.game_imbuementtracker then
		return
	end

	local filters = {
		showLessThan1h = opts.showAlmostGone == true,
		showBetween1hAnd3h = opts.showAlmostNew == true,
		showMoreThan3h = opts.showUsed == true,
		showNoImbuements = opts.showEmptySlots == true
	}

	if modules.game_imbuementtracker.applyFilters then
		modules.game_imbuementtracker.applyFilters(filters)
	end
end

local function collectContainersOptions()
	if SidebarLayoutState and SidebarLayoutState.syncFromPanels then
		SidebarLayoutState.syncFromPanels()
	end

	local options = {}
	local seen = {}

	local function collectForWindow(window, containerId)
		if not window or window:isDestroyed() or seen[containerId] then
			return
		end

		if not window:isVisible() then
			return
		end

		local opts = SidebarWidgetOptions.collectBaseOptions(window)

		if opts then
			options[tostring(containerId)] = opts
			seen[containerId] = true
		end
	end

	if g_game.getContainers then
		for _, container in pairs(g_game.getContainers()) do
			collectForWindow(container.window, container:getId())
		end
	end

	if SidebarLayoutState and SidebarLayoutState.getWidgets then
		for widgetId, data in pairs(SidebarLayoutState.getWidgets()) do
			if data.type == "container" then
				collectForWindow(SidebarWidgetOptions.resolveWindow("container", data.instance), data.instance)
			end
		end
	end

	for containerId, opts in pairs(options) do
		ensureDefaultBaseOptions(opts)
	end

	return options
end

local function collectStaticOptionSection(sectionKey)
	local section = {}

	mergeSectionFromDocument(sectionKey, section)

	local defaults = STATIC_OPTION_DEFAULTS[sectionKey]

	if type(defaults) == "table" then
		mergeOptions(section, defaults)
	end

	ensureDefaultBaseOptions(section)

	return section
end

local function collectPreyWidgetOptions()
	return collectWidgetOptionsSection("preyWidgetOptions", "prey")
end

local function collectSimpleWidgetOptions(widgetType)
	local sectionKey = SIMPLE_WIDGET_SECTIONS[widgetType]

	if not sectionKey then
		return nil
	end

	return collectWidgetOptionsSection(sectionKey, widgetType)
end

local function collectSkillsWidgetOptions()
	local section = collectWidgetOptionsSection("skillsWidgetOptions", "skills")
	local char = g_game.getCharacterName()

	if not char or char == "" then
		return section
	end

	local settings = g_settings.getNode("skills-hide")
	local charSettings = settings and settings[char]

	if type(charSettings) == "table" then
		if charSettings.defenceStats_visible ~= nil then
			section.defenceStatsVisible = charSettings.defenceStats_visible == true
		end

		if charSettings.offenceStats_visible ~= nil then
			section.offenceStatsVisible = charSettings.offenceStats_visible == true
		end

		if charSettings.miscStats_visible ~= nil then
			section.miscStatsVisible = charSettings.miscStats_visible == true
		end

		section.invisibleProgressBars = section.invisibleProgressBars or {}

		for key, value in pairs(charSettings) do
			if value == true and type(key) == "string" and key:match("^skill_%d+_visible$") then
				table.insert(section.invisibleProgressBars, key:gsub("_visible$", ""))
			end
		end
	end

	return section
end

local function collectBattleListsOptions()
	local options = {}

	mergeSectionFromDocument("battleListsOptions", options)

	if not modules.game_battle or not modules.game_battle.getBattleListManager then
		return options
	end

	local manager = modules.game_battle.getBattleListManager()

	for id, instance in pairs(manager.instances or {}) do
		if tonumber(id) and instance.window and not instance.window:isDestroyed() then
			local opts = SidebarWidgetOptions.collectBaseOptions(instance.window)

			if opts then
				opts.name = instance.getName and instance:getName() or ""
				opts.showFilters = instance.isHidingFilters and not instance:isHidingFilters() or false
				opts.isPartyView = false
				opts.isPrimary = tonumber(id) == 0
				opts.battleListFilters = instance.getHiddenFilterNames and instance:getHiddenFilterNames() or {}
				opts.battleListSortOrder = instance.getSortOrderName and instance:getSortOrderName() or "byAgeAscending"
				options[tostring(id)] = opts
			end
		end
	end

	return options
end

local function collectVipWidgetOptions()
	local section = collectWidgetOptionsSection("vipWidgetOptions", "vip")

	if modules.game_viplist and modules.game_viplist.getVipWidgetConfig then
		local cfg = modules.game_viplist.getVipWidgetConfig()

		if type(cfg) == "table" then
			section.hideOfflineVips = cfg.hideOfflineVips == true
			section.showGrouped = cfg.showGrouped == true

			if type(cfg.vipSortOrder) == "string" then
				section.vipSortOrder = cfg.vipSortOrder
			end
		end
	end

	if type(section.vipSortOrder) ~= "string" then
		section.vipSortOrder = "byName"
	end

	ensureDefaultBaseOptions(section)

	return section
end

function SidebarWidgetOptionsPersistence.getContainerOptions(containerId)
	if not SidebarPersistence or not SidebarPersistence.active then
		return nil
	end

	local section = SidebarPersistence.getSection("containersOptions")

	if type(section) ~= "table" then
		return nil
	end

	return section[tostring(containerId)]
end

function SidebarWidgetOptionsPersistence.applyAll()
	if not SidebarPersistence or not SidebarPersistence.active then
		return
	end

	local preyOpts = SidebarPersistence.getSection("preyWidgetOptions")

	if type(preyOpts) == "table" then
		SidebarWidgetOptions.applyBaseOptions(resolveWindowForSection("prey", 0), preyOpts)
	end

	local imbuementOpts = SidebarPersistence.getSection("imbuementTrackerWidgetOptions")

	if type(imbuementOpts) == "table" then
		applyImbuementTrackerOptions(imbuementOpts)
	end

	local skillsOpts = SidebarPersistence.getSection("skillsWidgetOptions")

	if type(skillsOpts) == "table" then
		SidebarWidgetOptions.applyBaseOptions(resolveWindowForSection("skills", 0), skillsOpts)
	end

	local battleOpts = SidebarPersistence.getSection("battleListsOptions")

	if type(battleOpts) == "table" then
		for id, opts in pairs(battleOpts) do
			if type(opts) == "table" then
				SidebarWidgetOptions.applyBaseOptions(resolveWindowForSection("battleList", tonumber(id)), opts)
			end
		end
	end

	local vipOpts = SidebarPersistence.getSection("vipWidgetOptions")

	if type(vipOpts) == "table" then
		SidebarWidgetOptions.applyBaseOptions(resolveWindowForSection("vip", 0), vipOpts)
	end

	local partyOpts = SidebarPersistence.getSection("partyWidgetOptions")

	if type(partyOpts) == "table" then
		SidebarWidgetOptions.applyBaseOptions(resolveWindowForSection("partyList", 0), partyOpts)
	end

	local containersOpts = SidebarPersistence.getSection("containersOptions")

	if type(containersOpts) == "table" then
		for containerId, opts in pairs(containersOpts) do
			if type(opts) == "table" then
				SidebarWidgetOptions.applyBaseOptions(resolveWindowForSection("container", tonumber(containerId)), opts)
			end
		end
	end

	for widgetType, sectionKey in pairs(SIMPLE_WIDGET_SECTIONS) do
		if sectionKey ~= "preyWidgetOptions" and sectionKey ~= "imbuementTrackerWidgetOptions" and sectionKey ~= "skillsWidgetOptions" then
			local opts = SidebarPersistence.getSection(sectionKey)

			if type(opts) == "table" and not opts["0"] then
				SidebarWidgetOptions.applyBaseOptions(resolveWindowForSection(widgetType, 0), opts)
			end
		end
	end

	local dedicatedSectionsApply = {
		partyWidgetOptions = true,
		containersOptions = true,
		imbuementTrackerWidgetOptions = true,
		preyWidgetOptions = true,
		vipWidgetOptions = true,
		battleListsOptions = true,
		skillsWidgetOptions = true
	}

	for sectionKey, widgetType in pairs(OPTION_WIDGET_TYPES) do
		if not dedicatedSectionsApply[sectionKey] then
			local opts = SidebarPersistence.getSection(sectionKey)

			if type(opts) == "table" then
				SidebarWidgetOptions.applyBaseOptions(resolveWindowForSection(widgetType, 0), opts)
			end
		end
	end

	if SidebarWidgetsPersistence and SidebarWidgetsPersistence.getRuntimeWidgets then
		for widgetId, _ in pairs(SidebarWidgetsPersistence.getRuntimeWidgets()) do
			local widgetType, instance = SidebarLayoutState.resolveTypeFromWidgetId(widgetId)

			if widgetType then
				local window = resolveWindowForSection(widgetType, instance)

				if window and not window:isDestroyed() and not window:isVisible() and window.open then
					window:open(true)

					if SidebarLayoutState and SidebarLayoutState.noteWidgetPlacement then
						SidebarLayoutState.noteWidgetPlacement(window)
					end
				end
			end
		end
	end
end

function SidebarWidgetOptionsPersistence.syncAllButtons()
	if not SidebarWidgetOptions or not SidebarWidgetOptions.forEachPlacedWidget then
		return
	end

	SidebarWidgetOptions.forEachPlacedWidget(function(widget)
		if widget and not widget:isDestroyed() and widget:isExplicitlyVisible() then
			signalcall(widget.onOpen, widget)
		end
	end)
end

function SidebarWidgetOptionsPersistence.scheduleApply()
	addEvent(function()
		SidebarWidgetOptionsPersistence.applyAll()

		if modules.game_containers and modules.game_containers.scheduleContainersLayoutRestore then
			modules.game_containers.scheduleContainersLayoutRestore()
		end

		scheduleEvent(function()
			SidebarWidgetOptionsPersistence.syncAllButtons()
		end, 50)
	end)
end

function SidebarWidgetOptionsPersistence.registerProviders()
	if providersRegistered then
		return
	end

	if not SidebarPersistence or not SidebarPersistence.registerProvider then
		return
	end

	ensureSimpleWidgetSections()

	providersRegistered = true

	SidebarPersistence.registerProvider("containersOptions", {
		alwaysInclude = true,
		collect = function(section)
			local data = collectContainersOptions()

			for key, value in pairs(data) do
				section[key] = value
			end
		end
	})
	SidebarPersistence.registerProvider("preyWidgetOptions", {
		collect = function(section)
			mergeOptions(section, collectPreyWidgetOptions())
		end
	})
	SidebarPersistence.registerProvider("imbuementTrackerWidgetOptions", {
		collect = function(section)
			mergeOptions(section, collectImbuementTrackerOptions())
		end
	})
	SidebarPersistence.registerProvider("skillsWidgetOptions", {
		collect = function(section)
			replaceSectionContents(section, collectSkillsWidgetOptions())
		end
	})
	SidebarPersistence.registerProvider("vipWidgetOptions", {
		collect = function(section)
			mergeOptions(section, collectVipWidgetOptions())
		end
	})
	SidebarPersistence.registerProvider("battleListsOptions", {
		collect = function(section)
			local data = collectBattleListsOptions()

			for key, value in pairs(data) do
				section[key] = value
			end
		end
	})

	local dedicatedSections = {
		containersOptions = true,
		imbuementTrackerWidgetOptions = true,
		preyWidgetOptions = true,
		vipWidgetOptions = true,
		battleListsOptions = true,
		skillsWidgetOptions = true
	}

	for sectionKey, widgetType in pairs(OPTION_WIDGET_TYPES) do
		if not dedicatedSections[sectionKey] then
			SidebarPersistence.registerProvider(sectionKey, {
				collect = function(section)
					local extra

					if sectionKey == "spellListWidgetOptions" then
						extra = collectSpellListOptions
					elseif sectionKey == "bestiaryTrackerWidgetOptions" or sectionKey == "bosstiaryTrackerWidgetOptions" then
						extra = collectTrackerSortOptions
					end

					mergeOptions(section, collectWidgetOptionsSection(sectionKey, widgetType, extra))
				end
			})
		end
	end

	for sectionKey in pairs(STATIC_OPTION_DEFAULTS) do
		SidebarPersistence.registerProvider(sectionKey, {
			collect = function(section)
				mergeOptions(section, collectStaticOptionSection(sectionKey))
			end
		})
	end
end

function SidebarWidgetOptionsPersistence.register()
	SidebarWidgetOptionsPersistence.registerProviders()
end

SidebarWidgetOptionsPersistence.registerProviders()
connect(g_game, {
	onGameStart = function()
		SidebarWidgetOptionsPersistence.registerProviders()
	end
})
