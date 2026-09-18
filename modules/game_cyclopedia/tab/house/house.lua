-- chunkname: @/game_cyclopedia/tab/house/house.lua

local UI, setupHouseLayersPanelWheel, updateHouseLayerUI

local function getHouseAuctionListGrid()
	if not UI or not UI.ListBase or not UI.ListBase.AuctionList then
		return nil
	end

	return UI.ListBase.AuctionList.auctionListGrid
end

function showHouse()
	UI = g_ui.loadUI("house", contentContainer)

	UI:show()

	function UI.onDestroy()
		Cyclopedia.House.lastSelectedHouse = nil
		UI = nil
	end

	controllerCyclopedia.ui.MajorCharmsBase:setVisible(false)
	controllerCyclopedia.ui.GoldBase:setVisible(true)
	controllerCyclopedia.ui.BestiaryTrackerButton:setVisible(false)
	controllerCyclopedia.ui.MinorCharmsBase:setVisible(false)
	Cyclopedia.loadProtoHouses()
	UI.TopBase.StatesOption:clearOptions()

	for i = 1, #Cyclopedia.StateList do
		UI.TopBase.StatesOption:addOption(Cyclopedia.StateList[i].Title, i)
	end

	UI.TopBase.StatesOption.onOptionChange = Cyclopedia.houseChangeState

	UI.TopBase.CityOption:clearOptions()

	for i = 0, #Cyclopedia.CityList do
		UI.TopBase.CityOption:addOption(Cyclopedia.CityList[i].Title, i)
	end

	UI.TopBase.CityOption.onOptionChange = Cyclopedia.selectTown

	UI.TopBase.SortOption:clearOptions()

	for i = 1, #Cyclopedia.SortList do
		UI.TopBase.SortOption:addOption(Cyclopedia.SortList[i].Title, i)
	end

	UI.TopBase.SortOption.onOptionChange = Cyclopedia.houseSort

	Cyclopedia.houseFilter(UI.TopBase.HousesCheck)
	UI.bidArea:setVisible(false)
	UI.ListBase:setVisible(true)

	Cyclopedia.House.lastSelectedHouse = nil

	Cyclopedia.selectTown({
		data = 0
	})
	UI.TopBase.StatesOption:setOption("All States", true)
	UI.TopBase.CityOption:setOption("Own Houses", true)
	UI.TopBase.SortOption:setOption("Sort by name", true)

	Cyclopedia.House.lastTown = nil

	setupHouseLayersPanelWheel()
	Cyclopedia.requestHouseList("")
end

Cyclopedia.House = {}
Cyclopedia.House.Preview = {
	panX = 0,
	panY = 0,
	houseFloors = {}
}

local HOUSE_PREVIEW_PAN_STEP = 8
local MINIMAP_MIN_ZOOM = -1
local MINIMAP_MAX_ZOOM = 4
local HOUSE_PREVIEW_ZOOM_DEFAULT = 0.95
local HOUSE_PREVIEW_ZOOM_MIN = MINIMAP_MIN_ZOOM - 1
local HOUSE_PREVIEW_ZOOM_MAX = HOUSE_PREVIEW_ZOOM_DEFAULT + 1
local HOUSE_PREVIEW_TILE_SIZE_AT_ZOOM1 = 17
local HOUSE_PREVIEW_REFERENCE_ZOOM = 1
local MINIMAP_DRAW_MODE_CYCLOPEDIA = 1
local CYCLOPEDIA_VIEW_SURFACE = 0
local CYCLOPEDIA_VIEW_MAP = 1
local HOUSE_MINIMAP_DEFAULT_ZOOM = 4
local HOUSE_MINIMAP_MIN_ZOOM = 1
local HOUSE_MINIMAP_MAX_ZOOM = 5
local HOUSE_LAYER_FLOOR_MIN = 0
local HOUSE_LAYER_FLOOR_MAX = 15
local HOUSE_SURFACE_MAX_Z = 7
local HOUSE_LAYER_CLIP_WIDTH = 14
local HOUSE_LAYER_CLIP_HEIGHT = 67
local HOUSE_TRANSFER_MIN_PRICE = 1

local function formatHouseRentK(value)
	value = tonumber(value) or 0

	if value >= 1000 then
		return string.format("%d k", math.floor(value / 1000))
	end

	return tostring(value)
end

local function compareHouseNames(nameA, nameB)
	nameA = string.lower(nameA or "")
	nameB = string.lower(nameB or "")

	local indexA, indexB = 1, 1

	while indexA <= #nameA and indexB <= #nameB do
		local numberA = nameA:sub(indexA):match("^(%d+)")
		local numberB = nameB:sub(indexB):match("^(%d+)")

		if numberA and numberB then
			local valueA, valueB = tonumber(numberA), tonumber(numberB)

			if valueA ~= valueB then
				return valueA < valueB
			end

			indexA = indexA + #numberA
			indexB = indexB + #numberB
		else
			local charA = nameA:sub(indexA, indexA)
			local charB = nameB:sub(indexB, indexB)

			if charA ~= charB then
				return charA < charB
			end

			indexA = indexA + 1
			indexB = indexB + 1
		end
	end

	return #nameA < #nameB
end

local function getHouseMinimap()
	return UI and UI.LateralBase and UI.LateralBase.MapViewbase and UI.LateralBase.MapViewbase.houseMinimap
end

local function getHouseSpriteOverlay()
	return UI and UI.LateralBase and UI.LateralBase.MapViewbase and UI.LateralBase.MapViewbase.houseImage
end

local HOUSE_INLINE_ICON_SHEET = "/images/icons/store-icons-inline"
local HOUSE_RENTED_BY_YOU_ICON_CLIP = "234 0 13 13"
local HOUSE_SHOP_ICON_CLIP = "195 0 13 13"
local HOUSE_TRANSFER_OUT_ICON_CLIP = "208 0 13 13"
local HOUSE_TRANSFER_IN_ICON_CLIP = "221 0 13 13"
local HOUSE_OWNER_ICON_CLIP = "65 0 13 13"

local function createHouseInlineIcon(parent, imageClip, tooltip)
	if not parent then
		return nil
	end

	local icon = g_ui.createWidget("HouseIcon", parent)

	icon:setSize({
		height = 13,
		width = 13
	})
	icon:setImageSource(HOUSE_INLINE_ICON_SHEET)
	icon:setImageClip(imageClip)

	if icon.setImageSmooth then
		icon:setImageSmooth(true)
	end

	if tooltip then
		icon:setTooltip(tooltip)
	end

	return icon
end

local function houseHasOwner(data)
	if not data then
		return false
	end

	if data.rented or data.inTransfer then
		return true
	end

	return data.owner ~= nil and data.owner ~= "" and data.owner ~= "?"
end

local function createHouseStatusIcons(parent, data)
	if not parent or not data then
		return
	end

	if data.isYourOwner and data.inTransfer then
		createHouseInlineIcon(parent, HOUSE_OWNER_ICON_CLIP, "You own this house.")
		createHouseInlineIcon(parent, HOUSE_TRANSFER_OUT_ICON_CLIP, "You are transferring this house.")

		if data.shop then
			createHouseInlineIcon(parent, HOUSE_SHOP_ICON_CLIP, "This house is a shop.")
		end

		createHouseInlineIcon(parent, HOUSE_RENTED_BY_YOU_ICON_CLIP, "This house is rented.")

		return
	end

	if data.isTransferOwner then
		createHouseInlineIcon(parent, HOUSE_TRANSFER_IN_ICON_CLIP, "This house is being transferred to you.")

		if data.shop then
			createHouseInlineIcon(parent, HOUSE_SHOP_ICON_CLIP, "This house is a shop.")
		end

		createHouseInlineIcon(parent, HOUSE_RENTED_BY_YOU_ICON_CLIP, "This house is rented.")

		return
	end

	if data.isYourOwner then
		createHouseInlineIcon(parent, HOUSE_OWNER_ICON_CLIP, "You own this house.")

		if data.shop then
			createHouseInlineIcon(parent, HOUSE_SHOP_ICON_CLIP, "This house is a shop.")
		end

		createHouseInlineIcon(parent, HOUSE_RENTED_BY_YOU_ICON_CLIP, "This house is rented.")

		return
	end

	if houseHasOwner(data) then
		if data.shop then
			createHouseInlineIcon(parent, HOUSE_SHOP_ICON_CLIP, "This house is a shop.")
		end

		createHouseInlineIcon(parent, HOUSE_RENTED_BY_YOU_ICON_CLIP, "This house is rented.")

		return
	end

	if data.shop then
		createHouseInlineIcon(parent, HOUSE_SHOP_ICON_CLIP, "This house is a shop.")
	end
end

local function prefetchHouseMinimapChunks(x, y, fromZ)
	if not g_minimap or not g_minimap.isOfficialLoaded then
		return
	end

	if not g_minimap.isOfficialLoaded() then
		return
	end

	if not g_minimap.loadCyclopediaMapChunk then
		return
	end

	local toZ = 7

	if toZ < fromZ then
		return
	end

	for z = fromZ, toZ do
		for _, sf in ipairs({
			64,
			32,
			16
		}) do
			if g_minimap.loadCyclopediaMapChunk(x, y, z, sf, CYCLOPEDIA_VIEW_SURFACE) then
				break
			end
		end
	end
end

local function housePreviewZoomToScale(zoom)
	if zoom < 0 then
		return 1 / 2^math.abs(zoom)
	elseif zoom > 0 then
		return 2^zoom
	end

	return 1
end

local function getHousePreviewDefaultZoom()
	return HOUSE_PREVIEW_ZOOM_DEFAULT
end

local function getHousePreviewTileSize(zoom)
	local minimap = getHouseMinimap()

	if minimap and not minimap:isDestroyed() and minimap.getScale then
		return math.max(2, math.floor(minimap:getScale()))
	end

	local scale = housePreviewZoomToScale(zoom)
	local refScale = housePreviewZoomToScale(HOUSE_PREVIEW_REFERENCE_ZOOM)

	return math.max(2, math.floor(HOUSE_PREVIEW_TILE_SIZE_AT_ZOOM1 * scale / refScale))
end

local function getHouseEntranceZ(data)
	if data and data.position and data.position.z ~= nil then
		return math.max(HOUSE_LAYER_FLOOR_MIN, math.min(HOUSE_LAYER_FLOOR_MAX, data.position.z))
	end

	return nil
end

local function clampHouseFloor(z)
	if z == nil then
		return nil
	end

	return math.max(HOUSE_LAYER_FLOOR_MIN, math.min(HOUSE_LAYER_FLOOR_MAX, z))
end

local function getItemWorldZ(item, tiles, entranceZ)
	if not item then
		return nil
	end

	local relativeZ = item.z or 0

	if tiles and tiles.topLeftZ ~= nil then
		return clampHouseFloor(tiles.topLeftZ + relativeZ)
	end

	if entranceZ ~= nil then
		return clampHouseFloor(entranceZ + relativeZ)
	end

	return nil
end

local function houseLayerMarginTopForFloor(z)
	z = math.max(HOUSE_LAYER_FLOOR_MIN, math.min(HOUSE_LAYER_FLOOR_MAX, z))

	return (z + 1) * 4 - 4
end

local function getNextHouseFloorUp(currentFloor, houseFloors)
	if currentFloor == nil or not houseFloors then
		return nil
	end

	for floor = currentFloor - 1, HOUSE_LAYER_FLOOR_MIN, -1 do
		if houseFloors[floor] then
			return floor
		end
	end

	return nil
end

local function getNextHouseFloorDown(currentFloor, houseFloors)
	if currentFloor == nil then
		return nil
	end

	for floor = currentFloor + 1, HOUSE_LAYER_FLOOR_MAX do
		if houseFloors and houseFloors[floor] then
			return floor
		end
	end

	return nil
end

local function getHousePreviewVisibleFloors(currentFloor, houseFloors)
	local visible = {}

	if currentFloor == nil then
		return visible
	end

	if currentFloor > HOUSE_SURFACE_MAX_Z then
		visible[currentFloor] = true

		return visible
	end

	if not houseFloors or not next(houseFloors) then
		visible[currentFloor] = true

		return visible
	end

	for floor = currentFloor, HOUSE_SURFACE_MAX_Z do
		if houseFloors[floor] then
			visible[floor] = true
		end
	end

	return visible
end

local function getHouseLayersPanel()
	return UI and UI.LateralBase and UI.LateralBase.layersPanel
end

local function applyHouseMinimapMapAlign(minimap, viewFloor)
	if not minimap or minimap:isDestroyed() or not minimap.setMapAlignOffset then
		return
	end

	if viewFloor == nil or viewFloor > HOUSE_SURFACE_MAX_Z then
		minimap:setMapAlignOffset(0, 0)

		return
	end

	local referenceZ = Cyclopedia.House and Cyclopedia.House.Preview and Cyclopedia.House.Preview.baseZ
	local floorDelta = 0

	if referenceZ ~= nil and referenceZ < HOUSE_SURFACE_MAX_Z then
		floorDelta = HOUSE_SURFACE_MAX_Z - referenceZ
	end

	minimap:setMapAlignOffset(1 + floorDelta * 2, 1 + floorDelta)
end

local function getRenderedTilePos(item, tiles, referenceZ, itemWorldZ)
	local x = tiles.topLeftX + item.x
	local y = tiles.topLeftY + item.y

	referenceZ = referenceZ or HOUSE_SURFACE_MAX_Z

	if itemWorldZ ~= nil and itemWorldZ < referenceZ then
		local dz = referenceZ - itemWorldZ

		x = x - dz
		y = y - dz
	end

	return {
		x = x,
		y = y,
		z = itemWorldZ
	}
end

local function repositionHouseSprites(minimap)
	if not minimap or minimap:isDestroyed() then
		return
	end

	local cameraPos = minimap:getCameraPosition()

	if not cameraPos then
		return
	end

	local scale = minimap:getScale()
	local overlay = getHouseSpriteOverlay()
	local layer = overlay and not overlay:isDestroyed() and overlay:getChildById("houseSpriteLayer")

	if layer and not layer:isDestroyed() and layer._referenceCameraX then
		if layer._scale and layer._scale ~= scale then
			Cyclopedia.houseRefreshPreviewView()

			return
		end

		layer:setMarginLeft((layer._baseMarginLeft or 0) + (layer._referenceCameraX - cameraPos.x) * scale)
		layer:setMarginTop((layer._baseMarginTop or 0) + (layer._referenceCameraY - cameraPos.y) * scale)

		return
	end

	local minW = minimap:getWidth()
	local minH = minimap:getHeight()

	if minW <= 0 then
		minW = 186
	end

	if minH <= 0 then
		minH = 210
	end

	local cx = math.floor(minW / 2)
	local cy = math.floor(minH / 2)

	for i = 1, minimap:getChildCount() do
		local sprite = minimap:getChildByIndex(i)

		if sprite and sprite._worldX then
			local ws = sprite:getWidth()

			sprite:setMarginLeft(cx + (sprite._worldX - cameraPos.x + 1) * scale - ws)
			sprite:setMarginTop(cy + (sprite._worldY - cameraPos.y + 1) * scale - ws)
		end
	end
end

local function onHouseMinimapCameraChange(pos, oldPos)
	if not UI then
		return
	end

	local minimap = getHouseMinimap()

	if not minimap or minimap:isDestroyed() then
		return
	end

	repositionHouseSprites(minimap)
end

local function onHouseMinimapZoomChange(zoom, oldZoom)
	if not UI then
		return
	end

	local minimap = getHouseMinimap()

	if not minimap or minimap:isDestroyed() then
		return
	end

	local mapControls = UI.LateralBase.mapControls

	if mapControls then
		if mapControls.ZoomInButton then
			mapControls.ZoomInButton:setEnabled(zoom < HOUSE_MINIMAP_MAX_ZOOM)
		end

		if mapControls.ZoomOutButton then
			mapControls.ZoomOutButton:setEnabled(zoom > HOUSE_MINIMAP_MIN_ZOOM)
		end
	end

	local preview = Cyclopedia.House.Preview

	preview.panX = 0
	preview.panY = 0

	Cyclopedia.houseRefreshPreviewView()
end

local function initHouseMinimap(houseData)
	local minimap = getHouseMinimap()

	if not minimap or minimap:isDestroyed() then
		return
	end

	if minimap.setDrawMode then
		minimap:setDrawMode(MINIMAP_DRAW_MODE_CYCLOPEDIA)
	end

	minimap:setZoom(HOUSE_MINIMAP_DEFAULT_ZOOM)

	if houseData and houseData.position then
		local x = houseData.position.x or 0
		local y = houseData.position.y or 0
		local houseZ = houseData.position.z or 7
		local cameraZ = houseZ
		local isSurface = cameraZ <= 7

		if minimap.setCyclopediaViewMode then
			minimap:setCyclopediaViewMode(isSurface and CYCLOPEDIA_VIEW_SURFACE or CYCLOPEDIA_VIEW_MAP)
		end

		if minimap.setLevelSeparatorIntensity then
			minimap:setLevelSeparatorIntensity(cameraZ < 7 and 1 or -1)
		end

		minimap:setCameraPosition({
			x = x,
			y = y,
			z = cameraZ
		})

		Cyclopedia.House.Preview.entrancePos = {
			x = x,
			y = y,
			z = cameraZ
		}
		Cyclopedia.House.Preview.cameraZ = cameraZ

		if isSurface then
			prefetchHouseMinimapChunks(x, y, cameraZ)
		end

		applyHouseMinimapMapAlign(minimap, Cyclopedia.House.Preview.floor or cameraZ)
	end

	function minimap.onCameraPositionChange(widget, pos, oldPos)
		onHouseMinimapCameraChange(pos, oldPos)
	end

	function minimap.onZoomChange(widget, zoom, oldZoom)
		onHouseMinimapZoomChange(zoom, oldZoom)
	end

	minimap:setVisible(true)
end

local function hookHouseLayersPanelMouseWheel(widget, handler)
	if not widget or widget:isDestroyed() then
		return
	end

	widget.onMouseWheel = handler

	for _, child in ipairs(widget:getChildren()) do
		hookHouseLayersPanelMouseWheel(child, handler)
	end
end

function setupHouseLayersPanelWheel()
	local layersPanel = getHouseLayersPanel()

	if not layersPanel then
		return
	end

	hookHouseLayersPanelMouseWheel(layersPanel, function(widget, mousePos, direction)
		if direction == MouseWheelUp then
			Cyclopedia.houseUpLayer()
		elseif direction == MouseWheelDown then
			Cyclopedia.houseDownLayer()
		end

		return true
	end)
end

local function collectHouseWorldFloors(data, houseId)
	local entranceZ = getHouseEntranceZ(data)
	local floors = {}
	local topLeftZ

	if houseId and g_things and g_things.getHouseTilesData then
		local tiles = g_things.getHouseTilesData(houseId)

		if tiles then
			topLeftZ = tiles.topLeftZ

			if tiles.items then
				for _, item in ipairs(tiles.items) do
					local worldZ = getItemWorldZ(item, tiles, entranceZ)

					if worldZ ~= nil then
						floors[worldZ] = true
					end
				end
			end
		end
	end

	if not next(floors) and entranceZ ~= nil then
		floors[entranceZ] = true
	end

	return floors, entranceZ, topLeftZ
end

local function updateHouseLayerIndicatorClip(floor)
	local panel = getHouseLayersPanel()

	if not panel or not panel.LayerIndicator then
		return
	end

	panel.LayerIndicator:setVisible(floor ~= nil)

	if floor == nil then
		return
	end

	floor = math.max(HOUSE_LAYER_FLOOR_MIN, math.min(HOUSE_LAYER_FLOOR_MAX, floor))

	panel.LayerIndicator:setImageClip(string.format("%d 0 %d %d", floor * HOUSE_LAYER_CLIP_WIDTH, HOUSE_LAYER_CLIP_WIDTH, HOUSE_LAYER_CLIP_HEIGHT))
end

local function updateHouseLayerLocks(houseFloors)
	local panel = getHouseLayersPanel()

	if not panel or not panel.layerLocks then
		return
	end

	panel.layerLocks:destroyChildren()

	for floor = HOUSE_LAYER_FLOOR_MIN, HOUSE_LAYER_FLOOR_MAX do
		if not houseFloors or not houseFloors[floor] then
			local lock = g_ui.createWidget("UIWidget", panel.layerLocks)

			lock:setSize({
				width = HOUSE_LAYER_CLIP_WIDTH,
				height = HOUSE_LAYER_CLIP_HEIGHT
			})
			lock:breakAnchors()
			lock:addAnchor(AnchorLeft, "parent", AnchorLeft)
			lock:addAnchor(AnchorTop, "parent", AnchorTop)
			lock:setPhantom(true)
			lock:setImageSource("/images/automap/automap_indicator_maplayers_locked")
			lock:setImageClip(string.format("%d 0 %d %d", floor * HOUSE_LAYER_CLIP_WIDTH, HOUSE_LAYER_CLIP_WIDTH, HOUSE_LAYER_CLIP_HEIGHT))
		end
	end
end

local function updateHouseLayersMark(floor)
	local panel = getHouseLayersPanel()

	if not panel then
		return
	end

	local mark = panel.layersMark
	local line = panel.LayerLine

	if floor == nil then
		if mark then
			mark:setVisible(false)
			mark:setMarginTop(28)
		end

		if line then
			line:setVisible(false)
		end

		return
	end

	if line then
		line:setVisible(true)
	end

	if mark then
		mark:setVisible(true)
		mark:setMarginTop(houseLayerMarginTopForFloor(floor))
	end
end

function updateHouseLayerUI()
	local preview = Cyclopedia.House.Preview

	updateHouseLayersMark(preview.floor)
	updateHouseLayerIndicatorClip(preview.floor)
end

local function initHouseLayerState(data, houseId)
	local houseFloors, entranceZ, topLeftZ = collectHouseWorldFloors(data, houseId)

	if entranceZ == nil then
		return
	end

	local preview = Cyclopedia.House.Preview

	preview.baseZ = entranceZ
	preview.topLeftZ = topLeftZ
	preview.houseFloors = houseFloors
	preview.floor = entranceZ

	updateHouseLayerLocks(houseFloors)
	updateHouseLayerUI()
end

local function applyHousePreviewToImage(container)
	if not container then
		return
	end

	local preview = Cyclopedia.House.Preview

	container:breakAnchors()
	container:addAnchor(AnchorFill, "parent", AnchorFill)
	container:setMargin(1)

	if container.setClipping then
		container:setClipping(true)
	end

	container:setMarginLeft(1 + (preview.panX or 0))
	container:setMarginTop(1 + (preview.panY or 0))
end

function Cyclopedia.houseRefreshPreviewView()
	local widget = Cyclopedia.House.lastSelectedHouse

	if not widget or not widget.data or not UI then
		return
	end

	local preview = Cyclopedia.House.Preview
	local houseId = widget.data.id
	local imagePath = string.format("/game_cyclopedia/images/houses/%s.png", houseId)
	local mapViewbase = UI.LateralBase.MapViewbase
	local houseMinimap = mapViewbase.houseMinimap

	if houseMinimap and not houseMinimap:isDestroyed() then
		houseMinimap:destroyChildren()
	end

	mapViewbase.houseImage:destroyChildren()
	mapViewbase.houseImage:setImageSource("")

	if g_resources.fileExists(imagePath) and preview.floor == preview.baseZ then
		mapViewbase.noHouse:setVisible(false)
		mapViewbase.reload:setVisible(false)
		mapViewbase.houseImage:setVisible(true)
		mapViewbase.houseImage:setImageSource(imagePath)
		applyHousePreviewToImage(mapViewbase.houseImage)

		if houseMinimap then
			houseMinimap:setVisible(true)
		end
	elseif Cyclopedia.renderHouseFromProto(houseId) then
		mapViewbase.noHouse:setVisible(false)
		mapViewbase.reload:setVisible(false)
		mapViewbase.houseImage:setVisible(true)

		if houseMinimap then
			houseMinimap:setVisible(true)
		end
	else
		mapViewbase.noHouse:setVisible(true)
		mapViewbase.reload:setVisible(false)
		mapViewbase.houseImage:setVisible(false)

		if houseMinimap then
			houseMinimap:setVisible(false)
		end
	end
end

function Cyclopedia.houseResetPreview()
	local preview = Cyclopedia.House.Preview

	preview.panX = 0
	preview.panY = 0
	preview.zoom = getHousePreviewDefaultZoom()
	preview.floor = preview.baseZ

	local minimap = getHouseMinimap()

	if minimap and not minimap:isDestroyed() then
		if preview.entrancePos then
			local ep = preview.entrancePos
			local cz = ep.z

			minimap:setCameraPosition({
				x = ep.x,
				y = ep.y,
				z = cz
			})

			if minimap.setCyclopediaViewMode then
				minimap:setCyclopediaViewMode(cz <= 7 and CYCLOPEDIA_VIEW_SURFACE or CYCLOPEDIA_VIEW_MAP)
			end

			if minimap.setLevelSeparatorIntensity then
				minimap:setLevelSeparatorIntensity(cz < 7 and 1 or -1)
			end

			preview.cameraZ = cz
		end

		applyHouseMinimapMapAlign(minimap, preview.floor)
	end

	updateHouseLayerUI()
	Cyclopedia.houseRefreshPreviewView()
end

function Cyclopedia.houseRefreshPreview()
	Cyclopedia.houseRefreshPreviewView()
end

function Cyclopedia.houseOnClickRoseButton(dir)
	local minimap = getHouseMinimap()

	if minimap and not minimap:isDestroyed() then
		local pos = minimap:getCameraPosition()

		if not pos then
			return
		end

		local x, y, z = pos.x, pos.y, pos.z

		if dir == "north" then
			y = y - 1
		elseif dir == "south" then
			y = y + 1
		elseif dir == "east" then
			x = x + 1
		elseif dir == "west" then
			x = x - 1
		elseif dir == "north-east" then
			x = x + 1
			y = y - 1
		elseif dir == "south-east" then
			x = x + 1
			y = y + 1
		elseif dir == "south-west" then
			x = x - 1
			y = y + 1
		elseif dir == "north-west" then
			x = x - 1
			y = y - 1
		end

		minimap:setCameraPosition({
			x = x,
			y = y,
			z = z
		})

		return
	end

	local preview = Cyclopedia.House.Preview
	local step = HOUSE_PREVIEW_PAN_STEP

	if dir == "north" then
		preview.panY = preview.panY - step
	elseif dir == "south" then
		preview.panY = preview.panY + step
	elseif dir == "east" then
		preview.panX = preview.panX + step
	elseif dir == "west" then
		preview.panX = preview.panX - step
	elseif dir == "north-east" then
		preview.panX = preview.panX + step
		preview.panY = preview.panY - step
	elseif dir == "south-east" then
		preview.panX = preview.panX + step
		preview.panY = preview.panY + step
	elseif dir == "south-west" then
		preview.panX = preview.panX - step
		preview.panY = preview.panY + step
	elseif dir == "north-west" then
		preview.panX = preview.panX - step
		preview.panY = preview.panY - step
	end

	Cyclopedia.houseRefreshPreviewView()
end

function Cyclopedia.houseSetZoom(zoomIn)
	local minimap = getHouseMinimap()

	if minimap and not minimap:isDestroyed() then
		if zoomIn then
			minimap:zoomIn()
		else
			minimap:zoomOut()
		end

		return
	end

	local preview = Cyclopedia.House.Preview
	local zoom = preview.zoom or getHousePreviewDefaultZoom()

	if zoomIn then
		preview.zoom = math.min(HOUSE_PREVIEW_ZOOM_MAX, zoom + 1)
	else
		preview.zoom = math.max(HOUSE_PREVIEW_ZOOM_MIN, zoom - 1)
	end

	Cyclopedia.houseRefreshPreviewView()
end

function Cyclopedia.openSelectedHouseOnMap()
	local selectedHouse = Cyclopedia.House.lastSelectedHouse
	local position = selectedHouse and selectedHouse.data and selectedHouse.data.position

	if position then
		Cyclopedia.PendingMapPosition = {
			x = position.x or 0,
			y = position.y or 0,
			z = position.z or HOUSE_SURFACE_MAX_Z
		}
		Cyclopedia.PendingMapZoomDelta = 3
	end

	modules.game_cyclopedia.show("map")
end

local function updateHouseMinimapFloor(newFloor)
	local minimap = getHouseMinimap()

	if not minimap or minimap:isDestroyed() or not minimap:isVisible() then
		return
	end

	local cameraPos = minimap:getCameraPosition()

	if not cameraPos then
		return
	end

	local newCameraZ = newFloor
	local isSurface = newCameraZ <= 7

	if minimap.setCyclopediaViewMode then
		minimap:setCyclopediaViewMode(isSurface and CYCLOPEDIA_VIEW_SURFACE or CYCLOPEDIA_VIEW_MAP)
	end

	if minimap.setLevelSeparatorIntensity then
		minimap:setLevelSeparatorIntensity(newCameraZ < 7 and 1 or -1)
	end

	minimap:setCameraPosition({
		x = cameraPos.x,
		y = cameraPos.y,
		z = newCameraZ
	})

	Cyclopedia.House.Preview.cameraZ = newCameraZ

	if isSurface then
		prefetchHouseMinimapChunks(cameraPos.x, cameraPos.y, newCameraZ)
	end

	applyHouseMinimapMapAlign(minimap, newFloor)
end

function Cyclopedia.houseUpLayer()
	local preview = Cyclopedia.House.Preview
	local nextFloor = getNextHouseFloorUp(preview.floor, preview.houseFloors)

	if nextFloor == nil then
		return
	end

	preview.floor = nextFloor

	updateHouseLayerUI()
	updateHouseMinimapFloor(nextFloor)
	Cyclopedia.houseRefreshPreviewView()
end

function Cyclopedia.houseDownLayer()
	local preview = Cyclopedia.House.Preview
	local nextFloor = getNextHouseFloorDown(preview.floor, preview.houseFloors)

	if nextFloor == nil then
		return
	end

	preview.floor = nextFloor

	updateHouseLayerUI()
	updateHouseMinimapFloor(nextFloor)
	Cyclopedia.houseRefreshPreviewView()
end

Cyclopedia.StateList = {
	{
		Title = "All States"
	},
	{
		Title = "Auctioned"
	},
	{
		Title = "Rented"
	}
}
Cyclopedia.CityList = {
	[0] = {
		Title = "Own Houses"
	}
}
Cyclopedia.House.OwnedIds = Cyclopedia.House.OwnedIds or {}
Cyclopedia.House.ServerEntries = Cyclopedia.House.ServerEntries or {}
Cyclopedia.House.Info = Cyclopedia.House.Info or nil
Cyclopedia.HouseAction = {
	OPEN = 0,
	REJECT_TRANSFER = 7,
	ACCEPT_TRANSFER = 6,
	CANCEL_TRANSFER = 5,
	CANCEL_MOVEOUT = 4,
	TRANSFER = 3,
	MOVEOUT = 2,
	BID = 1
}
Cyclopedia.HouseState = {
	TRANSFER = 3,
	KEEP = 4,
	REGULAR = 2,
	UNRENTABLE = 1,
	AUCTION = 0
}

local function resetButtons()
	for _, id in ipairs({
		"bidButton",
		"transferButton",
		"moveOutButton",
		"keepHouseButton",
		"cancelTransfer",
		"acceptTransfer",
		"rejectTransfer"
	}) do
		local btn = UI.LateralBase:getChildById(id)

		if btn then
			btn:destroy()
		end
	end
end

local function resetSelectedInfo()
	local lateral = UI.LateralBase

	for _, id in ipairs({
		"yourLimitBidGold",
		"yourLimitBid",
		"yourLimitLabel",
		"highestBidLabel",
		"highestBid",
		"highestBidGold",
		"auctionBidderLabel",
		"auctionBidderValue",
		"auctionEndTimeLabel",
		"auctionEndTimeValue",
		"rentalTenantLabel",
		"rentalTenantValue",
		"rentalPaidUntilLabel",
		"rentalPaidUntilValue",
		"moveOutPendingLabel",
		"moveOutDateLabel",
		"moveOutDateValue",
		"subAuctionLabel",
		"subAuctionText",
		"transferOwnerLabel",
		"transferOwnerValue",
		"transferDateLabel",
		"transferDateValue",
		"transferLabel",
		"transferValue",
		"transferGold"
	}) do
		lateral[id]:setVisible(false)
	end
end

local function resetHouseSelectionPanel()
	local lateral = UI.LateralBase
	local mapBase = lateral.MapViewbase

	Cyclopedia.House.lastSelectedHouse = nil

	mapBase.noHouse:setVisible(true)
	mapBase.reload:setVisible(false)
	mapBase.houseImage:setVisible(false)
	mapBase.houseImage:destroyChildren()
	mapBase.houseImage:setImageSource("")
	lateral.AuctionLabel:setVisible(false)
	lateral.AuctionText:setVisible(false)
	lateral.icons:destroyChildren()
	resetSelectedInfo()
	resetButtons()

	local preview = Cyclopedia.House.Preview

	preview.floor = nil
	preview.baseZ = nil
	preview.topLeftZ = nil
	preview.houseFloors = {}
	preview.entrancePos = nil
	preview.cameraZ = nil

	updateHouseLayerLocks(nil)
	updateHouseLayersMark(nil)
	updateHouseLayerIndicatorClip(nil)

	local minimap = getHouseMinimap()

	if minimap and not minimap:isDestroyed() then
		minimap:destroyChildren()
		minimap:setVisible(false)
		applyHouseMinimapMapAlign(minimap, nil)
	end
end

local function updateHouseListEmptyState(isEmpty)
	local listBase = UI and UI.ListBase

	if not listBase then
		return
	end

	if listBase.AuctionList then
		listBase.AuctionList:setVisible(not isEmpty)
	end

	if listBase.AuctionListScrollbar then
		listBase.AuctionListScrollbar:setVisible(not isEmpty)
	end

	if listBase.NoResult then
		listBase.NoResult:setVisible(isEmpty)
	end
end

local function hookHouseRowClick(widget, row)
	if not widget or widget:isDestroyed() then
		return
	end

	for _, child in ipairs(widget:getChildren()) do
		function child.onClick()
			Cyclopedia.selectHouse(row)
		end

		hookHouseRowClick(child, row)
	end
end

local HOUSE_SUB_AREAS = {
	"bidArea",
	"moveOutArea",
	"keepHouseArea",
	"transferArea",
	"cancelHouseTransferArea",
	"acceptTransferHouse",
	"rejectTransferHouse"
}

local function closeHouseSubAreas(exceptArea)
	for _, id in ipairs(HOUSE_SUB_AREAS) do
		local area = UI and UI[id]

		if area and area ~= exceptArea then
			area:setVisible(false)
		end
	end
end

local function openSubArea(area)
	closeHouseSubAreas(area)
	UI.ListBase:setVisible(false)
	area:setVisible(true)
end

local function closeSubArea(area)
	closeHouseSubAreas()
	UI.ListBase:setVisible(true)
end

local function hideCyclopediaForConfirmation()
	if controllerCyclopedia and controllerCyclopedia.ui and controllerCyclopedia.ui:isVisible() then
		g_modalManager.hide(controllerCyclopedia.ui)
		controllerCyclopedia.ui:hide()

		if CyclopediaButton then
			CyclopediaButton:setOn(false)
		end

		return true
	end

	return false
end

local function showCyclopediaAfterConfirmation(restore)
	if restore and controllerCyclopedia and controllerCyclopedia.ui then
		controllerCyclopedia.ui:show()
		g_modalManager.show(controllerCyclopedia.ui)

		if CyclopediaButton then
			CyclopediaButton:setOn(true)
		end
	end
end

local function toggleCyclopedia(...)
	if Cyclopedia.Toggle then
		Cyclopedia.Toggle(...)
	end
end

function Cyclopedia.House.confirmAction(title, message, onYes)
	local w
	local restoreCyclopedia = hideCyclopediaForConfirmation()

	local function done()
		if w then
			w:destroy()

			w = nil
		end

		showCyclopediaAfterConfirmation(restoreCyclopedia)
	end

	local function confirm()
		if w then
			w:destroy()

			w = nil
		end

		Cyclopedia.House.restoreAfterActionResult = restoreCyclopedia

		if Cyclopedia.House.restoreAfterActionResultEvent then
			removeEvent(Cyclopedia.House.restoreAfterActionResultEvent)
		end

		Cyclopedia.House.restoreAfterActionResultEvent = scheduleEvent(function()
			local restore = Cyclopedia.House.restoreAfterActionResult

			Cyclopedia.House.restoreAfterActionResult = nil
			Cyclopedia.House.restoreAfterActionResultEvent = nil

			showCyclopediaAfterConfirmation(restore)
			Cyclopedia.houseRefresh()
		end, 300)

		scheduleEvent(function()
			onYes()
		end, 1)
	end

	local hasColoredText = type(message) == "string" and message:find("{.-, #%x+}") ~= nil
	local displayMessage = hasColoredText and message:gsub("{(.-), #%x+}", "%1") or message

	w = displayGeneralBox(title, displayMessage, {
		{
			text = tr("No"),
			callback = done
		},
		{
			text = tr("Yes"),
			callback = confirm
		},
		anchor = AnchorHorizontalCenter
	}, confirm, done)

	if hasColoredText and w.content then
		w.content:setColoredText(message)
	end
end

function Cyclopedia.House.fillHouseSummary(panel, house)
	panel.name:setText(house.name)
	panel.size:setText(house.sqm .. " sqm")
	panel.beds:setText(house.beds)
	panel.rent:setText(formatHouseRentK(house.rent))

	if panel.paid and house.paidUntil then
		panel.paid:setText(os.date("%Y-%m-%d, %H:%M BRA", house.paidUntil))
	end
end

local function fillDateOptions(area, verifyCallback)
	local yearNumber = tonumber(os.date("%Y"))

	area.year.onOptionChange = nil
	area.month.onOptionChange = nil
	area.day.onOptionChange = nil

	area.year:clearOptions()
	area.year:addOption(yearNumber, 1, true)
	area.year:addOption(yearNumber + 1, 2, true)
	area.month:clearOptions()

	for i = 1, 12 do
		area.month:addOption(i, i, true)
	end

	area.day:clearOptions()

	local days = tonumber(os.date("%d", os.time({
		day = 0,
		year = yearNumber,
		month = os.date("%m") + 1
	})))

	for i = 1, days do
		area.day:addOption(i, i, true)
	end

	area.month:setOption(tonumber(os.date("%m")), true)
	area.day:setOption(tonumber(os.date("%d") + 1), true)

	area.year.onOptionChange = verifyCallback
	area.month.onOptionChange = verifyCallback
	area.day.onOptionChange = verifyCallback

	if verifyCallback then
		verifyCallback()
	end
end

local function mergeServerEntryIntoHouse(data, entry)
	data.state = entry.state or 0
	data.renovationFlag = entry.renovationFlag or 1
	data.owned = true
	data.belongsToCharacter = false
	data.hasBid = false
	data.isYourBid = false
	data.bidEnd = nil
	data.hightestBid = nil
	data.bidName = nil
	data.bidHolderLimit = nil
	data.canBid = entry.auctionDisabledId or 0
	data.rented = false
	data.paidUntil = nil
	data.owner = "?"
	data.isYourOwner = false
	data.inTransfer = false
	data.transferName = nil
	data.transferTime = 0
	data.transferValue = 0
	data.isTransferOwner = false
	data.canAcceptTransfer = entry.acceptIncomingTransferDisabledId or 0
	data.canRejectTransfer = entry.rejectIncomingTransferDisabledId or 0
	data.canCancelTransfer = entry.cancelTransferDisabledId or 0
	data.canMoveOut = entry.moveOutDisabledId or 0
	data.canCancelMoveOut = entry.cancelMoveOutDisabledId or 0
	data.acceptTransferDisabledId = entry.acceptTransferDisabledId or 0
	data.moveOutDate = nil

	if entry.state == Cyclopedia.HouseState.AUCTION then
		if entry.highestBidderName and entry.highestBidderName ~= "" then
			data.hasBid = true
			data.bidName = entry.highestBidderName
			data.bidEnd = entry.auctionEndDate
			data.hightestBid = entry.highestBid
		end

		data.isYourBid = entry.playerIsBidding == true

		if data.isYourBid then
			data.bidHolderLimit = entry.playerLimitBid
			data.belongsToCharacter = true
		end
	elseif entry.state == Cyclopedia.HouseState.REGULAR then
		data.rented = true
		data.owner = entry.ownerName or "?"
		data.paidUntil = entry.paidUntil
		data.isYourOwner = entry.isOwner == true

		if data.isYourOwner then
			data.belongsToCharacter = true
		end
	elseif entry.state == Cyclopedia.HouseState.TRANSFER then
		data.rented = true
		data.owner = entry.ownerName or "?"
		data.paidUntil = entry.paidUntil
		data.isYourOwner = entry.isOwner == true
		data.inTransfer = true
		data.transferTime = entry.transferDate or 0
		data.transferName = entry.transferTargetName
		data.transferValue = entry.transferPrice or 0
		data.isTransferOwner = entry.isTransferTarget == true

		if data.isYourOwner or data.isTransferOwner then
			data.belongsToCharacter = true
		end
	elseif entry.state == Cyclopedia.HouseState.KEEP then
		data.rented = true
		data.owner = entry.ownerName or "?"
		data.paidUntil = entry.paidUntil
		data.isYourOwner = entry.isOwner == true
		data.moveOutDate = entry.moveOutDate

		if data.isYourOwner then
			data.belongsToCharacter = true
		end
	elseif entry.state == Cyclopedia.HouseState.UNRENTABLE then
		data.rented = false
	end
end

function Cyclopedia.House.refreshFromServer()
	if not Cyclopedia.House.Data then
		return
	end

	local byId = {}

	for _, data in ipairs(Cyclopedia.House.Data) do
		byId[data.id] = data
		data.owned = false
	end

	for clientId, entry in pairs(Cyclopedia.House.ServerEntries) do
		local data = byId[clientId]

		if data then
			mergeServerEntryIntoHouse(data, entry)
		else
			local synthetic = {
				description = "",
				city = "",
				shop = false,
				visible = false,
				owned = true,
				rent = 0,
				beds = 0,
				sqm = 0,
				gh = false,
				id = clientId,
				name = entry.ownerName ~= "" and entry.ownerName or string.format("House #%d", clientId)
			}

			mergeServerEntryIntoHouse(synthetic, entry)
			table.insert(Cyclopedia.House.Data, synthetic)
		end
	end
end

function Cyclopedia.House.shouldShow(data, town, onlyGuildHall, stateFilter)
	if not data then
		return false
	end

	local ownHousesView = not town or town == ""

	if not ownHousesView and data.city ~= town then
		return false
	end

	if onlyGuildHall then
		if not data.gh then
			return false
		end
	elseif data.gh then
		return false
	end

	if ownHousesView then
		if data.belongsToCharacter ~= true then
			return false
		end
	elseif data.owned ~= true then
		return false
	end

	if stateFilter == 2 then
		if data.rented then
			return false
		end
	elseif stateFilter == 3 and not data.rented and not data.inTransfer then
		return false
	end

	return true
end

function Cyclopedia.House.refreshVisibility()
	if not Cyclopedia.House.Data or table.empty(Cyclopedia.House.Data) then
		if UI and UI.ListBase then
			Cyclopedia.reloadHouseList()
		end

		return
	end

	local onlyGuildHall = UI and UI.TopBase and UI.TopBase.GuildhallsCheck and UI.TopBase.GuildhallsCheck:isChecked() or false
	local town = Cyclopedia.House.lastTown
	local stateFilter

	if UI and UI.TopBase and UI.TopBase.StatesOption then
		local cur = UI.TopBase.StatesOption.getCurrentOption and UI.TopBase.StatesOption:getCurrentOption()

		if cur and cur.data then
			stateFilter = cur.data
		end
	end

	for _, data in ipairs(Cyclopedia.House.Data) do
		data.visible = Cyclopedia.House.shouldShow(data, town, onlyGuildHall, stateFilter)
	end

	if UI and UI.ListBase then
		Cyclopedia.reloadHouseList()
	end
end

function Cyclopedia.onCyclopediaHouseList(entries)
	if type(entries) ~= "table" then
		return
	end

	Cyclopedia.House.ServerEntries = {}

	for _, entry in ipairs(entries) do
		if entry.clientId and entry.clientId > 0 then
			Cyclopedia.House.ServerEntries[entry.clientId] = entry
		end
	end

	Cyclopedia.House.refreshFromServer()
	Cyclopedia.House.refreshVisibility()
end

function Cyclopedia.onCyclopediaHousesInfo(info)
	if type(info) ~= "table" then
		return
	end

	Cyclopedia.House.Info = info

	if type(info.availableHouseIds) == "table" then
		Cyclopedia.setOwnedHouseIds(info.availableHouseIds)
	end
end

function Cyclopedia.requestHouseList(cityName)
	if not g_game or not g_game.sendCyclopediaHouseAuction then
		return
	end

	local payload = ""

	if type(cityName) == "string" and cityName ~= "" then
		payload = string.lower(cityName)
	end

	g_game.sendCyclopediaHouseAuction(Cyclopedia.HouseAction.OPEN, 0, 0, 0, payload)
end

Cyclopedia.HouseActionErrors = {
	nil,
	"Your character does not belong to this world.",
	"Rookgaard / mainland mismatch.",
	"A character with this name does not exist.",
	"Your character is not the leader of a guild.",
	"Only guild leaders can bid on guildhalls.",
	nil,
	"This house is not in auction.",
	"The auction has already ended.",
	"Bid is below the minimum required.",
	"Your account already has a leading bid on another house.",
	"You reached the regular house limit for this account.",
	"A character of this account has already accepted a house transfer. You need to wait until the first transfer has been completed before you can transfer this house.",
	"You reached the guildhall limit for this account.",
	nil,
	nil,
	"Your bank balance is insufficient.",
	"A world transfer is pending on this character.",
	"A character with this name does not exist.",
	"This house is scheduled for renovation.",
	nil,
	"There is a pending transfer on your character."
}

local function describeActionError(action, result)
	local msg = Cyclopedia.HouseActionErrors[result]

	if msg then
		return msg
	end

	return string.format("Action %d failed (error %d).", action or -1, result or -1)
end

function Cyclopedia.onCyclopediaHouseActionResult(timestamp, action, result, hasBidExtra, bidExtra)
	if Cyclopedia.House.restoreAfterActionResultEvent then
		removeEvent(Cyclopedia.House.restoreAfterActionResultEvent)

		Cyclopedia.House.restoreAfterActionResultEvent = nil
	end

	if Cyclopedia.houseMessage(nil, action, result) then
		return
	end

	local restoreCyclopedia = Cyclopedia.House.restoreAfterActionResult

	Cyclopedia.House.restoreAfterActionResult = nil

	showCyclopediaAfterConfirmation(restoreCyclopedia)

	if result == 0 then
		if action == Cyclopedia.HouseAction.BID and hasBidExtra then
			local message = bidExtra == 0 and "Your bid was accepted and you are the leading bidder!" or "Your bid was accepted, but you are not the leading bidder."

			if modules.game_textmessage then
				modules.game_textmessage.displayGameMessage(message)
			end
		end
	else
		local message = describeActionError(action, result)

		if modules.game_textmessage then
			modules.game_textmessage.displayFailureMessage(message)
		else
			print(string.format("[Cyclopedia House] %s", message))
		end
	end
end

function Cyclopedia.loadProtoHouses()
	local houses = {}
	local cities = {}
	local protoHouses

	if g_things and g_things.getHouseList then
		protoHouses = g_things.getHouseList()
	end

	if not protoHouses or table.empty(protoHouses) then
		Cyclopedia.House.Data = {}

		return
	end

	for _, house in ipairs(protoHouses) do
		local cityName = house.city

		if cityName and cityName ~= "" and not cities[cityName] then
			cities[cityName] = true
		end

		table.insert(houses, {
			visible = false,
			canBid = 0,
			rented = false,
			isYourOwner = false,
			inTransfer = false,
			owner = "?",
			isYourBid = false,
			hasBid = false,
			transferValue = 0,
			owned = false,
			transferTime = 0,
			state = 0,
			isTransferOwner = false,
			canAcceptTransfer = 0,
			id = house.id,
			name = house.name or "",
			description = house.description or "",
			rent = house.rent or 0,
			beds = house.beds or 0,
			sqm = house.sqm or 0,
			gh = house.gh and true or false,
			shop = house.shop and true or false,
			city = cityName or "",
			position = house.position
		})
	end

	table.sort(houses, function(a, b)
		return compareHouseNames(a.name, b.name)
	end)

	Cyclopedia.House.Data = houses

	Cyclopedia.House.refreshFromServer()

	if Cyclopedia.House.OwnedIds then
		for _, data in ipairs(Cyclopedia.House.Data) do
			if Cyclopedia.House.OwnedIds[data.id] then
				data.owned = true
			end
		end
	end

	Cyclopedia.CityList = {
		[0] = {
			Title = "Own Houses"
		}
	}

	local sortedCities = {}

	for cityName in pairs(cities) do
		table.insert(sortedCities, cityName)
	end

	table.sort(sortedCities)

	for _, cityName in ipairs(sortedCities) do
		table.insert(Cyclopedia.CityList, {
			Title = cityName
		})
	end
end

function Cyclopedia.setOwnedHouseIds(ids)
	local set = {}

	if type(ids) == "table" then
		for _, id in ipairs(ids) do
			set[id] = true
		end
	end

	Cyclopedia.House.OwnedIds = set

	if Cyclopedia.House.Data then
		for _, data in ipairs(Cyclopedia.House.Data) do
			data.owned = set[data.id] == true
		end

		if UI and UI.TopBase and UI.TopBase.HousesCheck then
			local active = UI.TopBase.GuildhallsCheck and UI.TopBase.GuildhallsCheck:isChecked() and UI.TopBase.GuildhallsCheck or UI.TopBase.HousesCheck

			Cyclopedia.houseFilter(active)
		end
	end
end

Cyclopedia.SortList = {
	{
		Title = "Sort by name"
	},
	{
		Title = "Sort by size"
	},
	{
		Title = "Sort by rent"
	},
	{
		Title = "Sort by bid"
	},
	{
		Title = "Sort by auction end"
	}
}

function Cyclopedia.houseChangeState(widget)
	Cyclopedia.House.lastChangeState = widget

	Cyclopedia.House.refreshVisibility()
end

function Cyclopedia.houseMessage(houseId, type, message)
	local confirmWindow
	local restoreCyclopedia = hideCyclopediaForConfirmation() or Cyclopedia.House.restoreAfterActionResult

	local function yesCallback()
		if confirmWindow then
			confirmWindow:destroy()

			confirmWindow = nil
		end

		showCyclopediaAfterConfirmation(restoreCyclopedia)
	end

	if type == 1 then
		if message == 0 then
			if not confirmWindow then
				confirmWindow = displayGeneralBox(tr("Summary"), tr("Your bid was successfull. You are currently holding the highest bid."), {
					{
						text = tr("Ok"),
						callback = yesCallback
					},
					anchor = AnchorHorizontalCenter
				}, yesCallback)

				UI.ListBase:setVisible(true)
				UI.bidArea:setVisible(false)
				toggleCyclopedia(true, false)
			end
		elseif message == 17 then
			confirmWindow = displayGeneralBox(tr("Summary"), tr("Bid failed.\nYour character's bank acocunt balance is too low to pay the bid and the rent for the first month."), {
				{
					text = tr("Ok"),
					callback = yesCallback
				},
				anchor = AnchorHorizontalCenter
			}, yesCallback)

			UI.ListBase:setVisible(true)
			UI.bidArea:setVisible(false)
			toggleCyclopedia(true, false)
		end
	elseif type == 2 then
		if message == 0 then
			confirmWindow = displayGeneralBox(tr("Summary"), tr("You have sucessfully iniated your move out."), {
				{
					text = tr("Ok"),
					callback = yesCallback
				},
				anchor = AnchorHorizontalCenter
			}, yesCallback)

			UI.moveOutArea:setVisible(false)
			UI.ListBase:setVisible(true)
			Cyclopedia.houseRefresh()
			toggleCyclopedia(true, false)
		end
	elseif type == 4 then
		if message == 0 then
			confirmWindow = displayGeneralBox(tr("Summary"), tr("You have sucessfully cancelled your move out. You will keep the house."), {
				{
					text = tr("Ok"),
					callback = yesCallback
				},
				anchor = AnchorHorizontalCenter
			}, yesCallback)

			UI.keepHouseArea:setVisible(false)
			UI.ListBase:setVisible(true)
			Cyclopedia.houseRefresh()
			toggleCyclopedia(true, false)
		end
	elseif type == 3 then
		if message == 0 then
			confirmWindow = displayGeneralBox(tr("Summary"), tr("You have sucessfully initiated the transfer of your house."), {
				{
					text = tr("Ok"),
					callback = yesCallback
				},
				anchor = AnchorHorizontalCenter
			}, yesCallback)

			UI.transferArea:setVisible(false)
			UI.ListBase:setVisible(true)
			toggleCyclopedia(true, false)
		elseif message ~= 0 then
			confirmWindow = displayGeneralBox(tr("Summary"), tr("Setting up a house transfer failed.\n%s", describeActionError(type, message)), {
				{
					text = tr("Ok"),
					callback = yesCallback
				},
				anchor = AnchorHorizontalCenter
			}, yesCallback)

			UI.transferArea:setVisible(false)
			UI.ListBase:setVisible(true)
			toggleCyclopedia(true, false)
		end
	elseif type == 5 then
		if message == 0 then
			confirmWindow = displayGeneralBox(tr("Summary"), tr("You have sucessfully cancelled the transfer. You will keep the house."), {
				{
					text = tr("Ok"),
					callback = yesCallback
				},
				anchor = AnchorHorizontalCenter
			}, yesCallback)

			UI.cancelHouseTransferArea:setVisible(false)
			UI.ListBase:setVisible(true)
			toggleCyclopedia(true, false)
		end
	elseif type == 6 then
		if message == 0 then
			confirmWindow = displayGeneralBox(tr("Summary"), tr("You have sucessfully accepted the transfer."), {
				{
					text = tr("Ok"),
					callback = yesCallback
				},
				anchor = AnchorHorizontalCenter
			}, yesCallback)

			UI.acceptTransferHouse:setVisible(false)
			UI.ListBase:setVisible(true)
			toggleCyclopedia(true, false)
		end
	elseif type == 7 then
		if message == 0 then
			confirmWindow = displayGeneralBox(tr("Summary"), tr("You rejected the house transfer sucessfully. The old owner will keep the house."), {
				{
					text = tr("Ok"),
					callback = yesCallback
				},
				anchor = AnchorHorizontalCenter
			}, yesCallback)

			UI.rejectTransferHouse:setVisible(false)
			UI.ListBase:setVisible(true)
			toggleCyclopedia(true, false)
		else
			confirmWindow = displayGeneralBox(tr("Summary"), tr("Rejecting the transfer failed.\nYou may not rent any new houses as long as your account is frozen."), {
				{
					text = tr("Ok"),
					callback = yesCallback
				},
				anchor = AnchorHorizontalCenter
			}, yesCallback)

			UI.rejectTransferHouse:setVisible(false)
			UI.ListBase:setVisible(true)
			toggleCyclopedia(true, false)
		end
	end

	if confirmWindow then
		if Cyclopedia.House.restoreAfterActionResultEvent then
			removeEvent(Cyclopedia.House.restoreAfterActionResultEvent)

			Cyclopedia.House.restoreAfterActionResultEvent = nil
		end

		Cyclopedia.House.restoreAfterActionResult = nil
	end

	return confirmWindow ~= nil
end

function Cyclopedia.houseSort(widget, text, type)
	if not Cyclopedia.House.Data then
		return
	end

	if type == 1 then
		table.sort(Cyclopedia.House.Data, function(a, b)
			return compareHouseNames(a.name, b.name)
		end)
	elseif type == 2 then
		table.sort(Cyclopedia.House.Data, function(a, b)
			return (a.sqm or 0) < (b.sqm or 0)
		end)
	elseif type == 3 then
		table.sort(Cyclopedia.House.Data, function(a, b)
			return (a.rent or 0) < (b.rent or 0)
		end)
	elseif type == 4 then
		table.sort(Cyclopedia.House.Data, function(a, b)
			if a.hasBid ~= b.hasBid then
				return a.hasBid
			end

			return false
		end)
	elseif type == 5 then
		table.sort(Cyclopedia.House.Data, function(a, b)
			return (a.bidEnd or 0) < (b.bidEnd or 0)
		end)
	end

	Cyclopedia.reloadHouseList()
end

function Cyclopedia.houseFilter(widget)
	local id = widget:getId()
	local brother = id == "HousesCheck" and UI.TopBase.GuildhallsCheck or UI.TopBase.HousesCheck

	brother:setChecked(false)
	widget:setChecked(true)
	Cyclopedia.House.refreshVisibility()
end

function Cyclopedia.reloadHouseList()
	local lateral = UI.LateralBase
	local mapBase = lateral.MapViewbase

	updateHouseListEmptyState(false)

	if not table.empty(Cyclopedia.House.Data) then
		mapBase.noHouse:setVisible(false)
		mapBase.houseImage:setVisible(false)
		mapBase.reload:setVisible(true)
		lateral.AuctionLabel:setVisible(true)
		lateral.AuctionText:setVisible(true)

		local auctionListGrid = getHouseAuctionListGrid()

		if not auctionListGrid then
			return
		end

		auctionListGrid:destroyChildren()

		for _, data in ipairs(Cyclopedia.House.Data) do
			if data.visible then
				local widget = g_ui.createWidget("House", auctionListGrid)

				widget.data = data

				widget:setId(data.id)
				widget:setText(data.name)
				widget.sizeColumn.sizeValue:setText(data.sqm .. " sqm")
				widget.bedsColumn.bedsText:setColoredText("{Max. Beds: , #909090}{" .. tostring(data.beds) .. ", #C0C0C0}")
				widget.rentColumn.rentValue:setText(formatHouseRentK(data.rent))

				if data.state == Cyclopedia.HouseState.AUCTION then
					widget.statusState:setVisible(true)
					widget.statusState:setText("auctioned")

					if data.hasBid then
						local function format(timestamp)
							local diff = timestamp - os.time()
							local hour = math.floor(diff / 3600)
							local minutes = math.floor(diff % 3600 / 60)

							return string.format("%02dh %02dmin", hour, minutes)
						end

						widget.statusDetail:setText(string.format(" (Bid: %s Ends in: %s)", data.hightestBid, format(data.bidEnd)))
					else
						widget.statusDetail:setText(" (no bid yet)")
					end
				elseif data.state == Cyclopedia.HouseState.REGULAR or data.state == Cyclopedia.HouseState.TRANSFER or data.state == Cyclopedia.HouseState.KEEP then
					widget.statusState:setText("")
					widget.statusDetail:setText("scheduled for renovation")
				end

				if data.description ~= "" then
					local icon = g_ui.createWidget("HouseIcon", widget.icons)

					icon:setTooltip(data.description)
				end

				widget.onClick = Cyclopedia.selectHouse

				createHouseStatusIcons(widget.icons, data)
				hookHouseRowClick(widget, widget)
			end
		end

		if auctionListGrid:getChildCount() == 0 then
			updateHouseListEmptyState(true)
			resetHouseSelectionPanel()

			return
		end

		if Cyclopedia.House.lastSelectedHouse then
			local last = auctionListGrid:getChildById(Cyclopedia.House.lastSelectedHouse:getId())

			last = last or auctionListGrid:getChildByIndex(1)

			Cyclopedia.selectHouse(last)
		else
			Cyclopedia.selectHouse(auctionListGrid:getChildByIndex(1))
		end
	else
		local auctionListGrid = getHouseAuctionListGrid()

		if auctionListGrid then
			auctionListGrid:destroyChildren()
		end

		updateHouseListEmptyState(true)
		resetHouseSelectionPanel()
	end
end

function Cyclopedia.loadHouseList(data, other)
	if Cyclopedia.House.ignore then
		Cyclopedia.House.ignore = false

		return
	end

	local houses = {}

	if not table.empty(data) then
		for i = 0, #data do
			local value = data[i]
			local house = HOUSE[value.houseId]

			if house then
				local isGuildHall = house.GH > 0 and true or false
				local data_t = {
					id = value.houseId,
					name = house.name,
					description = house.description,
					rent = house.rent,
					beds = house.beds,
					sqm = house.sqm,
					gh = isGuildHall,
					shop = house.shop > 0 and true or false,
					visible = not isGuildHall,
					state = value.state,
					owner = other[i].owner and other[i].owner or "?",
					isYourBid = data[i].bidHolderLimit and data[i].bidHolderLimit > 0 and true or false,
					hasBid = data[i].bidEnd and data[i].bidEnd > 0 and true or false,
					bidEnd = data[i].bidEnd or nil,
					hightestBid = data[i].hightestBid or nil,
					bidName = other[i].bidName or nil,
					bidHolderLimit = data[i].bidHolderLimit or nil,
					canBid = data[i].selfCanBid,
					rented = data[i].state == Cyclopedia.HouseState.REGULAR or data[i].state == Cyclopedia.HouseState.KEEP,
					paidUntil = data[i].paidUntil or nil,
					isYourOwner = other[i].owner and other[i].owner:lower() == g_game.getLocalPlayer():getName():lower() or false,
					inTransfer = data[i].state == Cyclopedia.HouseState.TRANSFER,
					moveOutDate = data[i].moveOutDate or data[i].time or nil,
					transferName = other[i].transferPlayer or nil,
					transferTime = data[i].time or 0,
					transferValue = data[i].transferValue or 0,
					isTransferOwner = data[i].hasTransferOwner and data[i].hasTransferOwner > 0 and true or false,
					canAcceptTransfer = data[i].canAcceptTransfer or 0
				}

				table.insert(houses, data_t)
			end
		end
	else
		local auctionListGrid = getHouseAuctionListGrid()

		if auctionListGrid then
			auctionListGrid:destroyChildren()
		end
	end

	table.sort(houses, function(a, b)
		return compareHouseNames(a.name, b.name)
	end)

	Cyclopedia.House.Data = houses

	Cyclopedia.reloadHouseList()
end

function Cyclopedia.selectTown(widget, text, type)
	local previousTown = Cyclopedia.House.lastTown

	if type ~= 0 then
		Cyclopedia.House.lastTown = text
	else
		Cyclopedia.House.lastTown = ""
	end

	if previousTown ~= Cyclopedia.House.lastTown then
		Cyclopedia.requestHouseList(Cyclopedia.House.lastTown)
	end

	Cyclopedia.House.refreshVisibility()
end

function Cyclopedia.selectHouse(widget)
	if not widget then
		return
	end

	local last = Cyclopedia.House.lastSelectedHouse
	local isNewHouse = not last or last:getId() ~= widget:getId()

	if isNewHouse then
		local preview = Cyclopedia.House.Preview

		preview.panX = 0
		preview.panY = 0
		preview.zoom = getHousePreviewDefaultZoom()

		initHouseLayerState(widget.data, widget.data.id)
		initHouseMinimap(widget.data)
	end

	local parent = widget:getParent()

	for i = 1, parent:getChildCount() do
		parent:getChildByIndex(i):setChecked(false)
	end

	local lateral = UI.LateralBase

	lateral.icons:destroyChildren()
	createHouseStatusIcons(lateral.icons, widget.data)

	if widget.data.description ~= "" then
		local icon = g_ui.createWidget("HouseIcon", lateral.icons)

		icon:setTooltip(widget.data.description)
	end

	resetButtons()
	resetSelectedInfo()

	if widget.data.hasBid then
		lateral.AuctionLabel:setText("Auction")
		lateral.AuctionText:setVisible(false)

		local formattedDate = os.date("%b %d, %H:%M", widget.data.bidEnd)
		local date = string.format("%s %s", formattedDate, "BRA")

		lateral.auctionBidderLabel:setVisible(true)
		lateral.auctionBidderValue:setVisible(true)
		lateral.auctionBidderValue:setText(widget.data.bidName)
		lateral.auctionEndTimeLabel:setVisible(true)
		lateral.auctionEndTimeValue:setVisible(true)
		lateral.auctionEndTimeValue:setText(date)
		lateral.highestBidLabel:setVisible(true)
		lateral.highestBid:setVisible(true)
		lateral.highestBidGold:setVisible(true)
		lateral.highestBid:setText(comma_value(widget.data.hightestBid))

		if widget.data.isYourBid then
			lateral.yourLimitLabel:setVisible(true)
			lateral.yourLimitBid:setVisible(true)
			lateral.yourLimitBid:setText(comma_value(widget.data.bidHolderLimit))
			lateral.yourLimitBidGold:setVisible(true)
		end
	elseif widget.data.rented or widget.data.inTransfer then
		local formattedDate = os.date("%b %d, %H:%M", widget.data.paidUntil)
		local date = string.format("%s %s", formattedDate, "BRA")

		lateral.AuctionLabel:setText("Rental Details")
		lateral.AuctionText:setVisible(false)
		lateral.rentalTenantLabel:setVisible(true)
		lateral.rentalTenantValue:setVisible(true)
		lateral.rentalPaidUntilLabel:setVisible(true)
		lateral.rentalPaidUntilValue:setVisible(true)
		lateral.rentalTenantValue:setText(widget.data.owner)
		lateral.rentalPaidUntilValue:setText(date)

		local moveOutDate = tonumber(widget.data.moveOutDate) or 0
		local hasMoveOutPending = moveOutDate > 0

		if hasMoveOutPending then
			formattedDate = os.date("%b %d, %H:%M", moveOutDate)
			date = string.format("%s %s", formattedDate, "BRA")

			lateral.moveOutPendingLabel:setVisible(true)
			lateral.moveOutDateLabel:setVisible(true)
			lateral.moveOutDateValue:setVisible(true)
			lateral.moveOutDateValue:setText(date)
		end

		if widget.data.inTransfer then
			formattedDate = os.date("%b %d, %H:%M", widget.data.transferTime)
			date = string.format("%s %s", formattedDate, "BRA")

			lateral.subAuctionLabel:breakAnchors()
			lateral.subAuctionLabel:addAnchor(AnchorLeft, "MapViewbase", AnchorLeft)
			lateral.subAuctionLabel:addAnchor(AnchorTop, hasMoveOutPending and "moveOutDateLabel" or "rentalPaidUntilLabel", AnchorBottom)
			lateral.subAuctionLabel:setMarginTop(5)
			lateral.subAuctionLabel:setVisible(true)
			lateral.transferOwnerLabel:setVisible(true)
			lateral.transferOwnerValue:setVisible(true)
			lateral.transferOwnerValue:setText(widget.data.transferName)
			lateral.transferDateLabel:setVisible(true)
			lateral.transferDateValue:setVisible(true)
			lateral.transferDateValue:setText(date)
			lateral.transferLabel:setVisible(true)
			lateral.transferValue:setVisible(true)
			lateral.transferGold:setVisible(true)
			lateral.transferValue:setText(comma_value(widget.data.transferValue))
		end
	else
		lateral.AuctionLabel:setText("Auction")
		lateral.AuctionText:setVisible(true)
		lateral.AuctionText:setText("There is no bid so far.\nBe the first to bid on this house.")
	end

	if widget.data.inTransfer then
		if widget.data.isTransferOwner then
			local rejectBtn = g_ui.createWidget("Button", lateral)

			rejectBtn:setId("rejectTransfer")
			rejectBtn:setText("Reject Transfer")
			rejectBtn:setColor("#C0C0C0")
			rejectBtn:setWidth(86)
			rejectBtn:setHeight(20)
			rejectBtn:addAnchor(AnchorBottom, "parent", AnchorBottom)
			rejectBtn:addAnchor(AnchorRight, "parent", AnchorRight)
			rejectBtn:setMarginRight(7)
			rejectBtn:setMarginBottom(7)
			rejectBtn:setTextOffset(topoint("0 0"))

			rejectBtn.onClick = Cyclopedia.rejectTransfer

			local acceptBtn = g_ui.createWidget("Button", lateral)

			acceptBtn:setId("acceptTransfer")
			acceptBtn:setText("Accept Transfer")
			acceptBtn:setColor("#C0C0C0")
			acceptBtn:setWidth(86)
			acceptBtn:setHeight(20)
			acceptBtn:addAnchor(AnchorTop, "prev", AnchorTop)
			acceptBtn:addAnchor(AnchorRight, "prev", AnchorLeft)
			acceptBtn:setMarginRight(5)
			acceptBtn:setTextOffset(topoint("0 0"))

			acceptBtn.onClick = Cyclopedia.acceptTransfer

			acceptBtn:setEnabled(widget.data.canAcceptTransfer == 0)
		elseif widget.data.isYourOwner then
			local btn = g_ui.createWidget("Button", lateral)

			btn:setId("cancelTransfer")
			btn:setText("Cancel Transfer")
			btn:setColor("#C0C0C0")
			btn:setWidth(86)
			btn:setHeight(20)
			btn:addAnchor(AnchorBottom, "parent", AnchorBottom)
			btn:addAnchor(AnchorRight, "parent", AnchorRight)
			btn:setMarginRight(7)
			btn:setMarginBottom(7)
			btn:setTextOffset(topoint("0 0"))

			btn.onClick = Cyclopedia.cancelTransfer
		end
	elseif widget.data.rented then
		if widget.data.isYourOwner then
			local moveOutDate = tonumber(widget.data.moveOutDate) or 0

			if moveOutDate > 0 then
				local btn = g_ui.createWidget("HouseActionButton", lateral)

				btn:setId("keepHouseButton")
				btn:setText("Keep House")
				btn:setColor("#C0C0C0")
				btn:setWidth(72)
				btn:setHeight(20)
				btn:addAnchor(AnchorBottom, "parent", AnchorBottom)
				btn:addAnchor(AnchorRight, "parent", AnchorRight)
				btn:setMarginRight(7)
				btn:setMarginBottom(7)
				btn:setTextOffset(topoint("0 0"))

				btn.onClick = Cyclopedia.keepHouse

				btn:setEnabled(widget.data.canCancelMoveOut == 0)
			else
				local btn = g_ui.createWidget("HouseActionButton", lateral)

				btn:setId("transferButton")
				btn:setText("Transfer")
				btn:setColor("#C0C0C0")
				btn:setWidth(64)
				btn:setHeight(20)
				btn:addAnchor(AnchorBottom, "parent", AnchorBottom)
				btn:addAnchor(AnchorRight, "parent", AnchorRight)
				btn:setMarginRight(7)
				btn:setMarginBottom(7)
				btn:setTextOffset(topoint("0 0"))

				btn.onClick = Cyclopedia.transferHouse
				btn = g_ui.createWidget("HouseActionButton", lateral)

				btn:setId("moveOutButton")
				btn:setText("Move Out")
				btn:setColor("#C0C0C0")
				btn:setWidth(64)
				btn:setHeight(20)
				btn:addAnchor(AnchorTop, "prev", AnchorTop)
				btn:addAnchor(AnchorRight, "prev", AnchorLeft)
				btn:setMarginRight(6)
				btn:setTextOffset(topoint("0 0"))

				btn.onClick = Cyclopedia.moveOutHouse
			end
		end
	else
		local btn = g_ui.createWidget("HouseActionButton", lateral)

		btn:setId("bidButton")
		btn:setText("Bid")
		btn:setColor("#C0C0C0")
		btn:setWidth(64)
		btn:setHeight(20)
		btn:addAnchor(AnchorBottom, "parent", AnchorBottom)
		btn:addAnchor(AnchorRight, "parent", AnchorRight)
		btn:setMarginRight(7)
		btn:setMarginBottom(7)

		btn.onClick = Cyclopedia.bidHouse

		if widget.data.canBid == 0 then
			btn:setEnabled(true)
			btn:setTooltip("")
		elseif widget.data.canBid == 11 then
			btn:setTooltip("A character of your account already holds the highest bid for \nanother house. You may olny bid for one house at the same time.")
			btn:setTooltipAlign(AlignTopLeft)
			btn:setEnabled(false)
		else
			btn:setEnabled(false)
			btn:setTooltip("")
		end
	end

	widget:setChecked(true)

	local mapBase = lateral.MapViewbase

	mapBase.noHouse:setVisible(false)
	mapBase.reload:setVisible(true)
	mapBase.houseImage:setVisible(false)
	mapBase.houseImage:destroyChildren()
	mapBase.houseImage:setImageSource("")

	Cyclopedia.House.lastSelectedHouse = widget

	Cyclopedia.houseRefreshPreviewView()
end

function Cyclopedia.rejectTransfer()
	local house = Cyclopedia.House.lastSelectedHouse.data
	local transferTime = os.date("%Y-%m-%d, %H:%M BRA", house.transferTime)

	openSubArea(UI.rejectTransferHouse)

	function UI.rejectTransferHouse.cancel.onClick()
		closeSubArea(UI.rejectTransferHouse)
	end

	function UI.rejectTransferHouse.transfer:onClick()
		Cyclopedia.House.confirmAction(tr("Confirm House Action"), tr("Do you really want to reject the transfer for the house '%s' offered by %s?\nYou will not get the house. %s will keep the house and can set up a new transfer anytime.", house.name, house.owner, house.owner), function()
			g_game.sendCyclopediaHouseAuction(Cyclopedia.HouseAction.REJECT_TRANSFER, house.id, 0, 0, "")
			UI.TopBase.StatesOption:setOption("All States", true)
			UI.TopBase.SortOption:setOption("Sort by name", true)
		end)
	end

	Cyclopedia.House.fillHouseSummary(UI.rejectTransferHouse, house)
	UI.rejectTransferHouse.owner:setText(house.transferName)
	UI.rejectTransferHouse.transferDate:setText(transferTime)
	UI.rejectTransferHouse.transferPrice:setText(comma_value(house.transferValue))
end

function Cyclopedia.acceptTransfer()
	local house = Cyclopedia.House.lastSelectedHouse.data
	local transferTime = os.date("%Y-%m-%d, %H:%M BRA", house.transferTime)

	openSubArea(UI.acceptTransferHouse)

	function UI.acceptTransferHouse.cancel.onClick()
		closeSubArea(UI.acceptTransferHouse)
	end

	function UI.acceptTransferHouse.transfer:onClick()
		Cyclopedia.House.confirmAction(tr("Confirm House Action"), tr("Do you want to accept the house transfer offered by %s for the property '%s'?\nThe transfer is scheduled for %s.\nThe transfer price was set to %s.\n\nMake sure to have enough gold in your bank account to pay the costs for this house transfer and the next rent.\nRemember to edit the door rights as only the guest list will be reset after the transfer!", house.owner, house.name, transferTime, comma_value(house.transferValue)), function()
			g_game.sendCyclopediaHouseAuction(Cyclopedia.HouseAction.ACCEPT_TRANSFER, house.id, 0, 0, "")
			UI.TopBase.StatesOption:setOption("All States", true)
			UI.TopBase.SortOption:setOption("Sort by name", true)
		end)
	end

	Cyclopedia.House.fillHouseSummary(UI.acceptTransferHouse, house)
	UI.acceptTransferHouse.owner:setText(house.transferName)
	UI.acceptTransferHouse.transferDate:setText(transferTime)
	UI.acceptTransferHouse.transferPrice:setText(comma_value(house.transferValue))
end

function Cyclopedia.cancelTransfer()
	local house = Cyclopedia.House.lastSelectedHouse.data
	local transferTime = os.date("%Y-%m-%d, %H:%M BRA", house.transferTime)

	openSubArea(UI.cancelHouseTransferArea)

	function UI.cancelHouseTransferArea.cancel.onClick()
		closeSubArea(UI.cancelHouseTransferArea)
	end

	function UI.cancelHouseTransferArea.transfer:onClick()
		Cyclopedia.House.confirmAction(tr("Confirm House Action"), tr("Do you really want to keep your house '%s'?\nYou will no longer transfer the house to %s on %s.", house.name, house.transferName, transferTime), function()
			g_game.sendCyclopediaHouseAuction(Cyclopedia.HouseAction.CANCEL_TRANSFER, house.id, 0, 0, "")

			Cyclopedia.House.ignore = true

			UI.TopBase.StatesOption:setOption("All States", true)
			UI.TopBase.SortOption:setOption("Sort by name", true)
		end)
	end

	Cyclopedia.House.fillHouseSummary(UI.cancelHouseTransferArea, house)
	UI.cancelHouseTransferArea.owner:setText(house.transferName)
	UI.cancelHouseTransferArea.transferDate:setText(transferTime)
	UI.cancelHouseTransferArea.transferPrice:setText(comma_value(house.transferValue))
end

function Cyclopedia.transferHouse()
	if UI.moveOutArea:isVisible() then
		UI.moveOutArea:setVisible(false)
	end

	if UI.keepHouseArea:isVisible() then
		UI.keepHouseArea:setVisible(false)
	end

	local house = Cyclopedia.House.lastSelectedHouse.data
	local isGuildhallTransfer = house.gh == true
	local guildhallTransferInfo = UI.transferArea:recursiveGetChildById("guildhallTransferInfo")
	local guildhallTransferInfoRead = UI.transferArea:recursiveGetChildById("guildhallTransferInfoRead")
	local errorGuildhallTransferInfoRead = UI.transferArea:recursiveGetChildById("errorGuildhallTransferInfoRead")

	local function getSelectedTransferDate()
		local yearOption = UI.transferArea.year:getCurrentOption()
		local monthOption = UI.transferArea.month:getCurrentOption()
		local dayOption = UI.transferArea.day:getCurrentOption()

		if not yearOption or not monthOption or not dayOption then
			return nil
		end

		return os.time({
			year = tonumber(yearOption.text),
			month = tonumber(monthOption.text),
			day = tonumber(dayOption.text)
		})
	end

	local function updateTransferButton()
		local ts = getSelectedTransferDate()
		local validDate = ts and ts >= os.time(os.date("!*t"))
		local ownerText = UI.transferArea.owner:getText()
		local priceText = UI.transferArea.price:getText()
		local price = tonumber(priceText)
		local validName = ownerText ~= ""
		local validPrice = priceText ~= "" and price ~= nil and price >= HOUSE_TRANSFER_MIN_PRICE
		local validGuildhallInfo = not isGuildhallTransfer or guildhallTransferInfoRead and guildhallTransferInfoRead:isChecked()

		UI.transferArea.error:setVisible(not validDate)
		UI.transferArea.errorName:setVisible(not validName)
		UI.transferArea.errorPrice:setVisible(not validPrice)

		if errorGuildhallTransferInfoRead then
			errorGuildhallTransferInfoRead:setVisible(not validGuildhallInfo)
		end

		UI.transferArea.transfer:setEnabled(validDate and validName and validPrice and validGuildhallInfo)
	end

	local function verify(widget, text, type)
		updateTransferButton()
	end

	local function verifyName(widget, text, oldText)
		updateTransferButton()
	end

	openSubArea(UI.transferArea)

	if guildhallTransferInfo then
		guildhallTransferInfo:setVisible(isGuildhallTransfer)
		guildhallTransferInfo:setHeight(isGuildhallTransfer and 36 or 0)
	end

	if guildhallTransferInfoRead then
		guildhallTransferInfoRead:setChecked(false)

		guildhallTransferInfoRead.onCheckChange = updateTransferButton
	end

	function UI.transferArea.cancel.onClick()
		closeSubArea(UI.transferArea)
	end

	function UI.transferArea.transfer:onClick()
		local transfer = UI.transferArea.owner:getText()
		local value = tonumber(UI.transferArea.price:getText())
		local ts = getSelectedTransferDate()

		if not ts or not value or value < HOUSE_TRANSFER_MIN_PRICE then
			return
		end

		Cyclopedia.House.confirmAction(tr("Confirm House Action"), "{Do you really want to transfer your house '" .. house.name .. "' to " .. transfer .. "?\nThe transfer is scheduled for " .. os.date("%Y-%m-%d, %H:%M BRA", ts) .. ".\nYou have set the transfer price to " .. comma_value(value) .. ", #C0C0C0}" .. "{$, #FFFFFF}" .. "{.\n\nThe transfer will only take place if " .. transfer .. " accepts it!.\n\nPlease take all your personal belongings out of the house before the daily server save on the day you move\nout. Everything that remains in the house becomes the property of the new owner after the transfer. The only\nexception are items which have been purchased in the Store. They will be wrapped back up and sent to your\ninbox., #C0C0C0}", function()
			g_game.sendCyclopediaHouseAuction(Cyclopedia.HouseAction.TRANSFER, house.id, ts, value, transfer)

			Cyclopedia.House.ignore = true

			UI.TopBase.StatesOption:setOption("All States", true)
			UI.TopBase.SortOption:setOption("Sort by name", true)
		end)
	end

	Cyclopedia.House.fillHouseSummary(UI.transferArea, house)
	fillDateOptions(UI.transferArea, verify)

	UI.transferArea.owner.onTextChange = verifyName

	UI.transferArea.owner:setText("")
	verifyName(UI.transferArea.owner, "", "")
	UI.transferArea.price:setText(HOUSE_TRANSFER_MIN_PRICE)

	function UI.transferArea.price:onTextChange(text, oldText)
		local n = tonumber(text)

		if text ~= "" and type(n) ~= "number" then
			self:setText(oldText)
		end

		updateTransferButton()
	end

	updateTransferButton()
end

function Cyclopedia.moveOutHouse()
	if UI.transferArea:isVisible() then
		UI.transferArea:setVisible(false)
	end

	if UI.keepHouseArea:isVisible() then
		UI.keepHouseArea:setVisible(false)
	end

	local house = Cyclopedia.House.lastSelectedHouse.data

	local function getSelectedMoveOutDate()
		local yearOption = UI.moveOutArea.year:getCurrentOption()
		local monthOption = UI.moveOutArea.month:getCurrentOption()
		local dayOption = UI.moveOutArea.day:getCurrentOption()

		if not yearOption or not monthOption or not dayOption then
			return nil
		end

		return os.time({
			year = tonumber(yearOption.text),
			month = tonumber(monthOption.text),
			day = tonumber(dayOption.text)
		})
	end

	local function verify(widget, text, type)
		local ts = getSelectedMoveOutDate()
		local valid = ts and ts >= os.time(os.date("!*t"))

		UI.moveOutArea.move:setEnabled(valid)
		UI.moveOutArea.error:setVisible(not valid)
	end

	openSubArea(UI.moveOutArea)

	function UI.moveOutArea.cancel.onClick()
		closeSubArea(UI.moveOutArea)
	end

	function UI.moveOutArea.move:onClick()
		local ts = getSelectedMoveOutDate()

		if not ts then
			return
		end

		Cyclopedia.House.confirmAction(tr("Confirm House Action"), tr("Do you really want to move out of the house '%s'?\nClick on 'Yes' to move out on %s.", house.name, os.date("%Y-%m-%d, %H:%M BRA", ts)), function()
			g_game.sendCyclopediaHouseAuction(Cyclopedia.HouseAction.MOVEOUT, house.id, ts, 0, "")
		end)
	end

	Cyclopedia.House.fillHouseSummary(UI.moveOutArea, house)
	fillDateOptions(UI.moveOutArea, verify)
end

function Cyclopedia.keepHouse()
	if UI.transferArea:isVisible() then
		UI.transferArea:setVisible(false)
	end

	if UI.moveOutArea:isVisible() then
		UI.moveOutArea:setVisible(false)
	end

	local house = Cyclopedia.House.lastSelectedHouse.data
	local moveOutDate = tonumber(house.moveOutDate) or 0

	openSubArea(UI.keepHouseArea)

	function UI.keepHouseArea.cancel.onClick()
		closeSubArea(UI.keepHouseArea)
	end

	function UI.keepHouseArea.keep.onClick()
		Cyclopedia.House.confirmAction(tr("Confirm House Action"), tr("Do you want to cancel your move out from the house '%s'?\nClick on 'Yes' to keep the house.", house.name), function()
			g_game.sendCyclopediaHouseAuction(Cyclopedia.HouseAction.CANCEL_MOVEOUT, house.id, 0, 0, "")
		end)
	end

	Cyclopedia.House.fillHouseSummary(UI.keepHouseArea, house)
	UI.keepHouseArea.moveDate:setText(moveOutDate > 0 and os.date("%Y-%m-%d, %H:%M BRA", moveOutDate) or "-")
end

function Cyclopedia.bidHouse(widget)
	if UI.transferArea:isVisible() then
		UI.transferArea:setVisible(false)
	end

	if UI.moveOutArea:isVisible() then
		UI.moveOutArea:setVisible(false)
	end

	if UI.keepHouseArea:isVisible() then
		UI.keepHouseArea:setVisible(false)
	end

	local house = Cyclopedia.House.lastSelectedHouse.data
	local time = os.date("%Y-%m-%d, %H:%M BRA", house.bidEnd)

	openSubArea(UI.bidArea)
	UI.bidArea.name:setText(house.name)
	UI.bidArea.size:setText(house.sqm .. " sqm")
	UI.bidArea.beds:setText(house.beds)
	UI.bidArea.rent:setText(formatHouseRentK(house.rent))

	if house.hasBid then
		UI.bidArea.hightestBidder:setVisible(true)
		UI.bidArea.hightestBidder_value:setVisible(true)
		UI.bidArea.hightestBidder_value:setText(house.bidName)
		UI.bidArea.endTime:setVisible(true)
		UI.bidArea.endTime_value:setVisible(true)
		UI.bidArea.endTime_value:setText(time)
		UI.bidArea.bidHighestBid:setVisible(true)
		UI.bidArea.bidHighestBid_value:setVisible(true)
		UI.bidArea.bidHighestBid_value:setText(comma_value(house.hightestBid))
		UI.bidArea.bidHighestBid_gold:setVisible(true)
		UI.bidArea.yourLimit:setVisible(house.bidHolderLimit ~= nil)
		UI.bidArea.yourLimit_value:setVisible(house.bidHolderLimit ~= nil)
		UI.bidArea.yourLimit_gold:setVisible(house.bidHolderLimit ~= nil)

		if house.bidHolderLimit then
			UI.bidArea.yourLimit_value:setText(comma_value(house.bidHolderLimit))
		end

		UI.bidArea.soFar:setVisible(false)
	else
		UI.bidArea.hightestBidder:setVisible(false)
		UI.bidArea.hightestBidder_value:setVisible(false)
		UI.bidArea.endTime:setVisible(false)
		UI.bidArea.endTime_value:setVisible(false)
		UI.bidArea.bidHighestBid:setVisible(false)
		UI.bidArea.bidHighestBid_value:setVisible(false)
		UI.bidArea.bidHighestBid_gold:setVisible(false)
		UI.bidArea.yourLimit:setVisible(false)
		UI.bidArea.yourLimit_value:setVisible(false)
		UI.bidArea.yourLimit_gold:setVisible(false)
		UI.bidArea.soFar:setVisible(true)
	end

	if UI.bidArea:getChildById("bidArea") then
		UI.bidArea:getChildById("bidArea"):destroy()
	end

	local bidArea = g_ui.createWidget("HouseBidArea", UI.bidArea)

	bidArea:setId("bidArea")

	local bidAreaTopAnchor = house.hasBid and (house.bidHolderLimit and "yourLimit" or "bidHighestBid") or "soFar"

	bidArea:addAnchor(AnchorTop, bidAreaTopAnchor, AnchorBottom)
	bidArea:addAnchor(AnchorLeft, "parent", AnchorLeft)
	bidArea:addAnchor(AnchorRight, "parent", AnchorRight)
	bidArea:setMarginTop(house.hasBid and 4 or 5)

	local function updateBidState(text)
		local value = tonumber(text)
		local empty = text == ""

		bidArea.errorBid:setVisible(empty)
		bidArea.textEdit:setTextAlign(empty and AlignLeft or AlignRight)
		UI.bidArea.bid:setEnabled(not empty and value ~= nil and value > 0)
	end

	local initialBidLimit = ""

	if house.bidHolderLimit and house.bidHolderLimit > 0 then
		initialBidLimit = tostring(house.bidHolderLimit)
	end

	bidArea.textEdit:setText(initialBidLimit)

	function bidArea.textEdit:onTextChange(text, oldText)
		local n = tonumber(text)

		if text ~= "" and type(n) ~= "number" then
			self:setText(oldText)

			return
		end

		updateBidState(text)
	end

	updateBidState(bidArea.textEdit:getText())

	if house.hasBid then
		bidArea.information:setColoredText("{When the auction ends at " .. time .. ", the\nwinning bid plus the rent for the first month ( " .. formatHouseRentK(house.rent) .. ", #C0C0C0}" .. "{$, #FFFFFF}" .. "{) will\nbe debited to your bank account., #C0C0C0}")
	else
		bidArea.information:setColoredText("{When the auction ends, the winning bid plus the rent for\nthe first month( " .. formatHouseRentK(house.rent) .. ", #C0C0C0}" .. "{$, #FFFFFF}" .. "{) will de debited yo your bank\naccount., #C0C0C0}")
	end

	function UI.bidArea.cancel.onClick()
		closeSubArea(UI.bidArea)
	end

	function UI.bidArea.bid:onClick()
		local value = tonumber(bidArea.textEdit:getText())

		if not value or value <= 0 then
			return
		end

		Cyclopedia.House.confirmAction(tr("Confirm House Action"), "{Do you really want to bid on the house '" .. house.name .. "'\nYour have set your bid limit to " .. comma_value(value) .. ", #C0C0C0}" .. "{$, #FFFFFF}" .. "{.\nWhen the auction ends, the winning bid plus the rent of " .. formatHouseRentK(house.rent) .. ", #C0C0C0}" .. "{$, #FFFFFF}" .. "{ for the first month will be debited from your bank\naccount., #C0C0C0}", function()
			g_game.sendCyclopediaHouseAuction(Cyclopedia.HouseAction.BID, house.id, 0, value, "")
		end)
	end
end

function Cyclopedia.houseRefresh()
	if Cyclopedia.House.refreshEvent then
		return
	end

	local town = Cyclopedia.House.lastTown or ""

	Cyclopedia.requestHouseList(town)

	Cyclopedia.House.refreshEvent = scheduleEvent(function()
		if Cyclopedia.House.lastChangeState then
			Cyclopedia.houseChangeState(Cyclopedia.House.lastChangeState)
		else
			Cyclopedia.House.refreshVisibility()
		end

		Cyclopedia.House.refreshEvent = nil
	end, 100)
end

function Cyclopedia.renderHouseFromProto(houseId)
	if not g_things or not g_things.hasHouseTilesData then
		return false
	end

	if not g_things.hasHouseTilesData(houseId) then
		return false
	end

	if g_things.prefetchHouseSprites then
		g_things.prefetchHouseSprites(houseId)
	end

	local tiles = g_things.getHouseTilesData(houseId)

	if not tiles or not tiles.items or #tiles.items == 0 then
		return false
	end

	local sizeX = tiles.sizeX or 0
	local sizeY = tiles.sizeY or 0

	if sizeX <= 0 or sizeY <= 0 then
		return false
	end

	local houseMinimap = getHouseMinimap()

	if not houseMinimap or houseMinimap:isDestroyed() then
		return false
	end

	local spriteOverlay = getHouseSpriteOverlay()

	if not spriteOverlay or spriteOverlay:isDestroyed() then
		return false
	end

	local preview = Cyclopedia.House.Preview
	local entranceZ = preview.baseZ
	local currentFloor = preview.floor

	houseMinimap:destroyChildren()
	spriteOverlay:destroyChildren()
	spriteOverlay:setImageSource("")
	spriteOverlay:setVisible(true)
	spriteOverlay:breakAnchors()
	spriteOverlay:addAnchor(AnchorFill, "parent", AnchorFill)
	spriteOverlay:setMargin(1)

	if spriteOverlay.setClipping then
		spriteOverlay:setClipping(true)
	end

	local minimapScale = houseMinimap:getScale()
	local cameraPos = houseMinimap:getCameraPosition()

	if not cameraPos then
		return false
	end

	local minW = houseMinimap:getWidth()
	local minH = houseMinimap:getHeight()

	if minW <= 0 then
		minW = 186
	end

	if minH <= 0 then
		minH = 210
	end

	local cx = math.floor(minW / 2)
	local cy = math.floor(minH / 2)
	local spriteSize = 32

	if g_gameConfig and g_gameConfig.getSpriteSize then
		local s = g_gameConfig:getSpriteSize()

		if s and s > 0 then
			spriteSize = s
		end
	end

	local thingTypeCache = {}

	local function resolveThingType(clientId)
		if not clientId or clientId <= 0 then
			return nil
		end

		local cached = thingTypeCache[clientId]

		if cached ~= nil then
			return cached or nil
		end

		local tt

		if g_things and g_things.getThingType then
			tt = g_things.getThingType(clientId, ThingCategoryItem)
		end

		thingTypeCache[clientId] = tt or false

		return tt
	end

	local sortedItems = {}

	for index, item in ipairs(tiles.items) do
		item._proto = index

		table.insert(sortedItems, item)
	end

	table.sort(sortedItems, function(a, b)
		local worldZa = getItemWorldZ(a, tiles, entranceZ) or 0
		local worldZb = getItemWorldZ(b, tiles, entranceZ) or 0

		if worldZa ~= worldZb then
			return worldZb < worldZa
		end

		if a.y ~= b.y then
			return a.y < b.y
		end

		if a.x ~= b.x then
			return a.x < b.x
		end

		local sa = a.stackIndex or 0
		local sb = b.stackIndex or 0

		if sa ~= sb then
			return sa < sb
		end

		return (a._proto or 0) < (b._proto or 0)
	end)

	local visibleFloors = getHousePreviewVisibleFloors(currentFloor, preview.houseFloors)
	local renderItems = {}
	local boundsLeft, boundsTop, boundsRight, boundsBottom

	for _, item in ipairs(sortedItems) do
		local worldZ = getItemWorldZ(item, tiles, entranceZ)

		if worldZ == nil or not visibleFloors[worldZ] then
			-- block empty
		elseif item.clientId and item.clientId > 0 then
			local tt = resolveThingType(item.clientId)
			local exactPixels = spriteSize

			if tt and tt.getExactSize then
				local ep = tt:getExactSize()

				if ep and ep > 0 then
					exactPixels = math.max(spriteSize, ep)
				end
			end

			local widgetSize = math.max(1, math.floor(exactPixels * minimapScale / spriteSize))
			local tilePos = getRenderedTilePos(item, tiles, entranceZ, worldZ)
			local left = cx + (tilePos.x - cameraPos.x + 1) * minimapScale - widgetSize
			local top = cy + (tilePos.y - cameraPos.y + 1) * minimapScale - widgetSize

			table.insert(renderItems, {
				clientId = item.clientId,
				widgetSize = widgetSize,
				left = left,
				top = top
			})

			boundsLeft = boundsLeft and math.min(boundsLeft, left) or left
			boundsTop = boundsTop and math.min(boundsTop, top) or top
			boundsRight = boundsRight and math.max(boundsRight, left + widgetSize) or left + widgetSize
			boundsBottom = boundsBottom and math.max(boundsBottom, top + widgetSize) or top + widgetSize
		end
	end

	if #renderItems == 0 then
		houseMinimap:destroyChildren()
		spriteOverlay:destroyChildren()

		return false
	end

	local layerPadding = math.max(32, math.floor(minimapScale * 2))

	boundsLeft = math.floor(boundsLeft - layerPadding)
	boundsTop = math.floor(boundsTop - layerPadding)
	boundsRight = math.ceil(boundsRight + layerPadding)
	boundsBottom = math.ceil(boundsBottom + layerPadding)

	local spriteLayer = g_ui.createWidget("UIWidget", spriteOverlay)

	spriteLayer:setId("houseSpriteLayer")
	spriteLayer:setPhantom(true)
	spriteLayer:setSize({
		width = math.max(1, boundsRight - boundsLeft),
		height = math.max(1, boundsBottom - boundsTop)
	})
	spriteLayer:breakAnchors()
	spriteLayer:addAnchor(AnchorTop, "parent", AnchorTop)
	spriteLayer:addAnchor(AnchorLeft, "parent", AnchorLeft)
	spriteLayer:setMarginLeft(boundsLeft)
	spriteLayer:setMarginTop(boundsTop)

	spriteLayer._referenceCameraX = cameraPos.x
	spriteLayer._referenceCameraY = cameraPos.y
	spriteLayer._baseMarginLeft = boundsLeft
	spriteLayer._baseMarginTop = boundsTop
	spriteLayer._scale = minimapScale

	local rendered = 0

	for _, renderItem in ipairs(renderItems) do
		local sprite = g_ui.createWidget("HousePreviewTile", spriteLayer)

		sprite:setVirtual(true)
		sprite:setItemVisible(true)
		sprite:setFixedItemSize(true)

		if sprite.setItemSmooth then
			sprite:setItemSmooth(true)
		end

		sprite:setSize({
			width = renderItem.widgetSize,
			height = renderItem.widgetSize
		})
		sprite:breakAnchors()
		sprite:addAnchor(AnchorTop, "parent", AnchorTop)
		sprite:addAnchor(AnchorLeft, "parent", AnchorLeft)
		sprite:setMarginLeft(renderItem.left - boundsLeft)
		sprite:setMarginTop(renderItem.top - boundsTop)

		local ok = pcall(function()
			sprite:setItemId(renderItem.clientId)
		end)

		if ok then
			rendered = rendered + 1
		else
			sprite:destroy()
		end
	end

	if rendered == 0 then
		houseMinimap:destroyChildren()
		spriteOverlay:destroyChildren()

		return false
	end

	return true
end
