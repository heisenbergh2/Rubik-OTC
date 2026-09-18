-- chunkname: @/game_interface/sidebar_panels_persistence.lua

SidebarPanelsPersistence = {}

local SECTION_PANELS_ORDER = "sidebarPanelsMangerOptions"
local SECTION_PANELS_OPTIONS = "sidebarPanelsOptions"
local PANEL_TYPE_BY_WIDGET_ID = {
	mainhealthmanapanel = "hitpointManabar",
	mainmappanel = "minimap",
	maininventorypanel = "inventoryStatus",
	mainoptionspanel = "buttons"
}
local WIDGET_ID_BY_PANEL_TYPE = {
	minimap = "mainmappanel",
	hitpointManabar = "mainhealthmanapanel",
	buttons = "mainoptionspanel",
	inventoryStatus = "maininventorypanel"
}
local applyScheduled = false

local function getMainRightPanel()
	if not modules.game_interface or not modules.game_interface.getMainRightPanel then
		return nil
	end

	local panel = modules.game_interface.getMainRightPanel()

	if panel and not panel:isDestroyed() then
		return panel
	end

	return nil
end

function SidebarPanelsPersistence.collectPanelsOrder()
	local mainPanel = getMainRightPanel()

	if not mainPanel then
		return nil
	end

	local order = {}

	for _, child in ipairs(mainPanel:getChildren()) do
		if child.panelHeight ~= nil then
			local panelType = PANEL_TYPE_BY_WIDGET_ID[child:getId()]

			if panelType then
				table.insert(order, panelType)
			end
		end
	end

	if #order == 0 then
		return nil
	end

	return {
		panelsOrder = order
	}
end

function SidebarPanelsPersistence.applyPanelsOrder(section)
	if type(section) ~= "table" or type(section.panelsOrder) ~= "table" or #section.panelsOrder == 0 then
		return
	end

	local mainPanel = getMainRightPanel()

	if not mainPanel then
		return
	end

	local widgetsByType = {}

	for _, child in ipairs(mainPanel:getChildren()) do
		local panelType = PANEL_TYPE_BY_WIDGET_ID[child:getId()]

		if panelType then
			widgetsByType[panelType] = child
		end
	end

	local index = 1

	for _, panelType in ipairs(section.panelsOrder) do
		local widget = widgetsByType[panelType]

		if widget and not widget:isDestroyed() then
			mainPanel:moveChildToIndex(widget, index)

			index = index + 1
		end
	end

	if modules.game_mainpanel and modules.game_mainpanel.reloadMainPanelSizes then
		modules.game_mainpanel.reloadMainPanelSizes()
	end
end

function SidebarPanelsPersistence.collectPanelsOptions()
	local options = {}

	if modules.game_mainpanel and modules.game_mainpanel.getControlButtonsVisible then
		options.controlButtonsVisible = modules.game_mainpanel.getControlButtonsVisible()
	end

	if modules.game_inventory and modules.game_inventory.getInventoryMinimized then
		options.minimizeInventory = modules.game_inventory.getInventoryMinimized()
	end

	if modules.game_inventory and modules.game_inventory.getChaseModeEnabled then
		options.chaseModeEnabled = modules.game_inventory.getChaseModeEnabled()
	end

	if modules.game_minimap and modules.game_minimap.getMinimapZoomLevel then
		local zoom = modules.game_minimap.getMinimapZoomLevel()

		if type(zoom) == "number" then
			options.minimapZoomLevel = zoom
		end
	end

	if modules.game_mainpanel and modules.game_mainpanel.getShortcutOrder then
		local shortcutOrder = modules.game_mainpanel.getShortcutOrder()

		if type(shortcutOrder) == "table" then
			options.shortcutOrder = shortcutOrder
		end
	end

	if table.empty(options) then
		return nil
	end

	return options
end

function SidebarPanelsPersistence.applyPanelsOptions(section)
	if type(section) ~= "table" then
		return
	end

	if section.controlButtonsVisible ~= nil and modules.game_mainpanel and modules.game_mainpanel.setControlButtonsVisible then
		modules.game_mainpanel.setControlButtonsVisible(section.controlButtonsVisible == true)
	end

	if section.minimizeInventory ~= nil and modules.game_inventory and modules.game_inventory.setInventoryMinimized then
		modules.game_inventory.setInventoryMinimized(section.minimizeInventory == true)
	end

	if section.chaseModeEnabled ~= nil and modules.game_inventory and modules.game_inventory.setChaseModeEnabled then
		modules.game_inventory.setChaseModeEnabled(section.chaseModeEnabled == true)
	end

	if type(section.minimapZoomLevel) == "number" and modules.game_minimap and modules.game_minimap.setMinimapZoomLevel then
		modules.game_minimap.setMinimapZoomLevel(section.minimapZoomLevel)
	end

	if type(section.shortcutOrder) == "table" and modules.game_mainpanel and modules.game_mainpanel.applyShortcutOrder then
		modules.game_mainpanel.applyShortcutOrder(section.shortcutOrder)
	end
end

function SidebarPanelsPersistence.applyAll()
	if not SidebarPersistence or not SidebarPersistence.active then
		return
	end

	SidebarPanelsPersistence.applyPanelsOrder(SidebarPersistence.getSection(SECTION_PANELS_ORDER))
	SidebarPanelsPersistence.applyPanelsOptions(SidebarPersistence.getSection(SECTION_PANELS_OPTIONS))
end

function SidebarPanelsPersistence.scheduleApply()
	if applyScheduled then
		return
	end

	applyScheduled = true

	addEvent(function()
		applyScheduled = false

		SidebarPanelsPersistence.applyAll()
	end)
end

function SidebarPanelsPersistence.register()
	if not SidebarPersistence or not SidebarPersistence.registerProvider then
		return
	end

	SidebarPersistence.registerProvider(SECTION_PANELS_ORDER, {
		collect = function(section)
			local data = SidebarPanelsPersistence.collectPanelsOrder()

			if not data then
				return
			end

			section.panelsOrder = data.panelsOrder
		end
	})
	SidebarPersistence.registerProvider(SECTION_PANELS_OPTIONS, {
		collect = function(section)
			local data = SidebarPanelsPersistence.collectPanelsOptions()

			if not data then
				return
			end

			for key, value in pairs(data) do
				section[key] = value
			end
		end
	})
end

connect(g_game, {
	onGameStart = function()
		SidebarPanelsPersistence.applyAll()
	end
})
SidebarPanelsPersistence.register()
