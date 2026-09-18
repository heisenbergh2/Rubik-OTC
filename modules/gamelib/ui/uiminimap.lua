-- chunkname: @/gamelib/ui/uiminimap.lua

local bundledMarkerCache = {}
local sharedHiddenBundled, sharedHiddenBundledSet, sharedUserFlags
local activeMinimaps = {}
local syncingUserFlag = false
local BUNDLED_FLAG_CREATE_BATCH = 20

local function bundledMarkerKeyFromCoords(x, y, z)
	return (z * 65536 + x) * 65536 + y
end

local function flagKeyFromPos(pos)
	return bundledMarkerKeyFromCoords(pos.x, pos.y, pos.z)
end

local function userFlagKey(pos)
	return string.format("%d,%d,%d", pos.x, pos.y, pos.z)
end

local function rebuildHiddenBundledSet()
	sharedHiddenBundledSet = {}

	if not sharedHiddenBundled then
		return
	end

	for i = 1, #sharedHiddenBundled do
		local entry = sharedHiddenBundled[i]

		sharedHiddenBundledSet[bundledMarkerKeyFromCoords(entry.x, entry.y, entry.z)] = true
	end
end

local function getSharedHiddenBundled()
	if not sharedHiddenBundled then
		sharedHiddenBundled = {}

		local settings = g_settings.getNode("Minimap")

		if settings and settings.hiddenBundled then
			for _, entry in pairs(settings.hiddenBundled) do
				table.insert(sharedHiddenBundled, {
					x = entry.x,
					y = entry.y,
					z = entry.z
				})
			end
		end

		rebuildHiddenBundledSet()
	end

	return sharedHiddenBundled
end

local function getSharedHiddenBundledSet()
	getSharedHiddenBundled()

	return sharedHiddenBundledSet
end

local function getBundledMarkerCache(path)
	if bundledMarkerCache[path] then
		return bundledMarkerCache[path]
	end

	if not g_resources.fileExists(path) then
		bundledMarkerCache[path] = {
			total = 0,
			data = {},
			byFloor = {}
		}

		return bundledMarkerCache[path]
	end

	local ok, markers = pcall(function()
		return json.decode(g_resources.readFileContents(path))
	end)

	if not ok or type(markers) ~= "table" then
		bundledMarkerCache[path] = {
			total = 0,
			data = {},
			byFloor = {}
		}

		return bundledMarkerCache[path]
	end

	local byFloor = {}
	local total = 0

	for _, marker in ipairs(markers) do
		if type(marker) == "table" and marker.x and marker.y and marker.z ~= nil and marker.icon ~= nil then
			local z = tonumber(marker.z)

			if z then
				marker._key = bundledMarkerKeyFromCoords(marker.x, marker.y, z)
				byFloor[z] = byFloor[z] or {}
				byFloor[z][#byFloor[z] + 1] = marker
				total = total + 1
			end
		end
	end

	bundledMarkerCache[path] = {
		data = markers,
		byFloor = byFloor,
		total = total
	}

	return bundledMarkerCache[path]
end

local function getSharedUserFlags()
	if not sharedUserFlags then
		sharedUserFlags = {}

		local settings = g_settings.getNode("Minimap")

		if settings and settings.flags then
			for _, flag in pairs(settings.flags) do
				local pos = flag.position

				if pos and pos.x and pos.y and pos.z ~= nil then
					sharedUserFlags[userFlagKey(pos)] = {
						position = {
							x = pos.x,
							y = pos.y,
							z = pos.z
						},
						icon = flag.icon,
						description = flag.description or ""
					}
				end
			end
		end
	end

	return sharedUserFlags
end

local function persistMinimapSettings()
	local hudMinimap = modules.game_minimap and modules.game_minimap.getMiniMapUi and modules.game_minimap.getMiniMapUi()

	if hudMinimap and not hudMinimap:isDestroyed() then
		hudMinimap:save()

		return
	end

	local settings = {
		flags = {},
		hiddenBundled = getSharedHiddenBundled()
	}

	for _, flag in pairs(getSharedUserFlags()) do
		table.insert(settings.flags, flag)
	end

	g_settings.setNode("Minimap", settings)
end

local function syncBundledMarkerHiddenOnAllMinimaps(pos)
	for _, minimap in ipairs(activeMinimaps) do
		if minimap and not minimap:isDestroyed() then
			local key = minimap:bundledMarkerKey(pos)
			local widget = minimap._bundledFlagWidgets and minimap._bundledFlagWidgets[key]

			if widget and not widget:isDestroyed() then
				widget:destroy()

				minimap._bundledFlagWidgets[key] = nil
			end
		end
	end
end

local function syncUserFlagOnAllMinimaps(pos, icon, description, sourceMinimap)
	syncingUserFlag = true

	for _, minimap in ipairs(activeMinimaps) do
		if minimap ~= sourceMinimap and not minimap:isDestroyed() and not minimap:getFlag(pos) then
			minimap:addFlag(pos, icon, description, false, false)
		end
	end

	syncingUserFlag = false
end

local function syncUserFlagUpdateOnAllMinimaps(pos, icon, description, sourceFlag)
	for _, minimap in ipairs(activeMinimaps) do
		if minimap and not minimap:isDestroyed() then
			local flag = minimap:getFlag(pos)

			if flag and flag ~= sourceFlag and not flag.bundled and not flag:isDestroyed() then
				minimap:updateFlag(flag, icon, description)
			end
		end
	end
end

local function removeSharedUserFlag(pos)
	if not pos then
		return
	end

	getSharedUserFlags()[userFlagKey(pos)] = nil
end

local function syncUserFlagRemovedOnAllMinimaps(pos)
	for _, minimap in ipairs(activeMinimaps) do
		if minimap and not minimap:isDestroyed() then
			local flag = minimap:getFlag(pos)

			if flag and not flag.bundled and not flag:isDestroyed() then
				flag:destroy()
			end
		end
	end
end

local VocationsNames = {
	"Knight",
	"Paladin",
	"Sorcerer",
	"Druid",
	"Monk",
	nil,
	nil,
	nil,
	nil,
	nil,
	"Elite Knight",
	"Royal Paladin",
	"Master Sorcerer",
	"Elder Druid",
	"Exalted Monk"
}

function UIMinimap:onCreate()
	self.autowalk = true
end

function UIMinimap:onSetup()
	table.insert(activeMinimaps, self)

	self.flagWindow = nil
	self.floorUpWidget = self:getChildById("floorUpButton")
	self.floorDownWidget = self:getChildById("floorDownButton")
	self.zoomInWidget = self:getChildById("zoomInButton")
	self.zoomOutWidget = self:getChildById("zoomOutButton")
	self.flags = {}
	self._flagsByKey = {}
	self.partyMembers = {}
	self.fullMapView = false
	self.zoomMinimap = 1
	self.zoomFullmap = 0
	self.alternatives = {}

	function self.onAddAutomapFlag(pos, icon, description)
		self:addFlag(pos, icon, description)
	end

	function self.onRemoveAutomapFlag(pos, icon, description)
		self:removeFlag(pos, icon, description)
	end

	connect(g_game, {
		onAddAutomapFlag = self.onAddAutomapFlag,
		onRemoveAutomapFlag = self.onRemoveAutomapFlag
	})
end

function UIMinimap:onDestroy()
	if self._smoothZoomEvent then
		removeEvent(self._smoothZoomEvent)

		self._smoothZoomEvent = nil
	end

	table.removevalue(activeMinimaps, self)

	for _, member in pairs(self.partyMembers) do
		if member.widget and not member.widget:isDestroyed() then
			member.widget:destroy()
		end
	end

	self.partyMembers = {}

	for _, widget in pairs(self.alternatives) do
		widget:destroy()
	end

	self.alternatives = {}

	disconnect(g_game, {
		onAddAutomapFlag = self.onAddAutomapFlag,
		onRemoveAutomapFlag = self.onRemoveAutomapFlag
	})
	self:destroyFlagWindow()

	self.flags = {}
	self._flagsByKey = nil
end

function UIMinimap:onVisibilityChange()
	if not self:isVisible() then
		self:destroyFlagWindow()
	end
end

function UIMinimap:isCyclopediaMap()
	local parent = self:getParent()

	return parent and parent:getId() == "MapBase"
end

local function positionCrossAtTile(minimap, cross, displayPos)
	cross:breakAnchors()
	minimap:anchorPosition(cross, AnchorRight, displayPos, AnchorHorizontalCenter)
	minimap:anchorPosition(cross, AnchorBottom, displayPos, AnchorVerticalCenter)
end

function UIMinimap:updateCrossVisibility()
	local cross = self.cross

	if not cross or not cross.pos then
		return
	end

	local cameraPos = self:getCameraPosition()

	if not cameraPos then
		cross:hide()

		return
	end

	local playerZ = cross.pos.z
	local viewZ = cameraPos.z
	local displayPos = {
		x = cross.pos.x,
		y = cross.pos.y,
		z = viewZ
	}

	if not self:isCyclopediaMap() then
		if viewZ ~= playerZ then
			cross:hide()

			return
		end

		cross:setOpacity(1)
		cross:show()
		positionCrossAtTile(self, cross, displayPos)

		return
	end

	if viewZ < 0 or viewZ > 15 then
		cross:hide()

		return
	end

	if playerZ >= 8 then
		if viewZ ~= playerZ then
			cross:hide()

			return
		end

		cross:setOpacity(1)
	else
		if viewZ > 7 then
			cross:hide()

			return
		end

		cross:setOpacity(viewZ == playerZ and 1 or 0.5)
	end

	cross:show()
	positionCrossAtTile(self, cross, displayPos)
end

function UIMinimap:updatePartyMemberVisibility(member)
	if not member or not member.widget or member.widget:isDestroyed() or not member.pos then
		return
	end

	local cameraPos = self:getCameraPosition()

	if not cameraPos or member.pos.z ~= cameraPos.z then
		member.widget:hide()

		return
	end

	local displayPos = {
		x = member.pos.x,
		y = member.pos.y,
		z = cameraPos.z
	}

	member.widget:show()
	self:centerInPosition(member.widget, displayPos)
end

function UIMinimap:bundledMarkerKey(pos)
	return bundledMarkerKeyFromCoords(pos.x, pos.y, pos.z)
end

function UIMinimap:scheduleBundledFlagsRefresh()
	if self._bundledRefreshScheduled then
		return
	end

	self._bundledRefreshScheduled = true

	addEvent(function()
		if self:isDestroyed() then
			return
		end

		self._bundledRefreshScheduled = false

		self:refreshBundledFlags()
	end)
end

function UIMinimap:getVisibleTileBounds()
	local cameraPos = self:getCameraPosition()

	if not cameraPos then
		return nil
	end

	local padding = self:getPaddingRect()

	if not padding or padding.width <= 0 or padding.height <= 0 then
		return nil
	end

	local topLeft = self:getTilePosition({
		x = padding.x,
		y = padding.y
	})
	local bottomRight = self:getTilePosition({
		x = padding.x + padding.width - 1,
		y = padding.y + padding.height - 1
	})

	if not topLeft or not bottomRight then
		return nil
	end

	local margin = 4

	return {
		minX = math.min(topLeft.x, bottomRight.x) - margin,
		maxX = math.max(topLeft.x, bottomRight.x) + margin,
		minY = math.min(topLeft.y, bottomRight.y) - margin,
		maxY = math.max(topLeft.y, bottomRight.y) + margin,
		z = cameraPos.z
	}
end

function UIMinimap:clearBundledFlags()
	if self._bundledFlagWidgets then
		for _, widget in pairs(self._bundledFlagWidgets) do
			if widget and not widget:isDestroyed() then
				widget:destroy()
			end
		end
	end

	self._bundledFlagWidgets = {}
end

function UIMinimap:loadBundledMarkerData(path)
	if self._bundledMarkerByFloor then
		return #self._bundledMarkerData
	end

	local cache = getBundledMarkerCache(path)

	self._bundledMarkerData = cache.data
	self._bundledMarkerByFloor = cache.byFloor
	self._bundledFlagWidgets = self._bundledFlagWidgets or {}

	return cache.total
end

function UIMinimap:cancelBundledFlagCreate()
	if self._bundledCreateEvent then
		removeEvent(self._bundledCreateEvent)

		self._bundledCreateEvent = nil
	end

	self._bundledCreateQueue = nil
end

function UIMinimap:processBundledCreateBatch()
	self._bundledCreateEvent = nil

	if self:isDestroyed() then
		return
	end

	local queue = self._bundledCreateQueue

	if not queue or #queue == 0 then
		self._bundledCreateQueue = nil

		return
	end

	local layout = self:getLayout()

	if layout then
		layout:disableUpdates()
	end

	local processed = 0

	while processed < BUNDLED_FLAG_CREATE_BATCH and #queue > 0 do
		local item = table.remove(queue, 1)
		local marker = item.marker
		local key = item.key
		local pos = {
			x = marker.x,
			y = marker.y,
			z = marker.z
		}

		if not self:getFlag(pos) then
			self:addFlag(pos, marker.icon, marker.description or "", false, true)

			local widget = self:getFlag(pos)

			if widget then
				self._bundledFlagWidgets[key] = widget
			end
		else
			self._bundledFlagWidgets[key] = self:getFlag(pos)
		end

		processed = processed + 1
	end

	if layout then
		layout:enableUpdates()
		layout:update()
	end

	if #queue > 0 then
		local selfRef = self

		self._bundledCreateEvent = addEvent(function()
			selfRef:processBundledCreateBatch()
		end)
	else
		self._bundledCreateQueue = nil
	end
end

function UIMinimap:refreshBundledFlags()
	if not self._bundledMarkerByFloor then
		return 0
	end

	local bounds = self:getVisibleTileBounds()

	if not bounds then
		return 0
	end

	local floorZ = tonumber(bounds.z)

	if not floorZ then
		return 0
	end

	local scale = self:getScale() or 1
	local refreshKey = string.format("%d:%d:%d:%d:%d:%.2f", bounds.minX, bounds.maxX, bounds.minY, bounds.maxY, floorZ, scale)

	if self._lastBundledRefreshKey == refreshKey and not self._bundledCreateQueue then
		return 0
	end

	self._lastBundledRefreshKey = refreshKey

	self:cancelBundledFlagCreate()

	local floorMarkers = self._bundledMarkerByFloor[floorZ] or {}
	local hiddenSet = getSharedHiddenBundledSet()
	local minX = bounds.minX
	local maxX = bounds.maxX
	local minY = bounds.minY
	local maxY = bounds.maxY
	local needed = {}

	for i = 1, #floorMarkers do
		local marker = floorMarkers[i]
		local mx = marker.x
		local my = marker.y

		if minX <= mx and mx <= maxX and minY <= my and my <= maxY then
			local key = marker._key

			if not hiddenSet[key] then
				needed[key] = marker
			end
		end
	end

	local layout = self:getLayout()

	if layout then
		layout:disableUpdates()
	end

	for key, widget in pairs(self._bundledFlagWidgets) do
		if not needed[key] then
			if widget and not widget:isDestroyed() then
				widget:destroy()
			end

			self._bundledFlagWidgets[key] = nil
		end
	end

	if layout then
		layout:enableUpdates()
		layout:update()
	end

	local createQueue = {}

	for key, marker in pairs(needed) do
		local widget = self._bundledFlagWidgets[key]

		if not widget or widget:isDestroyed() then
			local pos = {
				x = marker.x,
				y = marker.y,
				z = marker.z
			}
			local existingFlag = self:getFlag(pos)

			if existingFlag then
				self._bundledFlagWidgets[key] = existingFlag
			else
				createQueue[#createQueue + 1] = {
					key = key,
					marker = marker
				}
			end
		end
	end

	if #createQueue > 0 then
		self._bundledCreateQueue = createQueue

		self:processBundledCreateBatch()
	end

	return #createQueue
end

function UIMinimap:onCameraPositionChange(cameraPos)
	self:updateCrossVisibility()

	for _, member in pairs(self.partyMembers) do
		self:updatePartyMemberVisibility(member)
	end

	self:scheduleBundledFlagsRefresh()
end

function UIMinimap:hideFloor()
	self.floorUpWidget:hide()
	self.floorDownWidget:hide()
end

function UIMinimap:hideZoom()
	self.zoomInWidget:hide()
	self.zoomOutWidget:hide()
end

function UIMinimap:disableAutoWalk()
	self.autowalk = false
end

function UIMinimap:isBundledHidden(pos)
	if not pos then
		return false
	end

	return getSharedHiddenBundledSet()[bundledMarkerKeyFromCoords(pos.x, pos.y, pos.z)] == true
end

function UIMinimap:hideBundledMarker(pos)
	if not pos then
		return
	end

	local key = bundledMarkerKeyFromCoords(pos.x, pos.y, pos.z)

	if getSharedHiddenBundledSet()[key] then
		return
	end

	table.insert(getSharedHiddenBundled(), {
		x = pos.x,
		y = pos.y,
		z = pos.z
	})

	sharedHiddenBundledSet[key] = true

	syncBundledMarkerHiddenOnAllMinimaps(pos)
end

function UIMinimap:load()
	getSharedHiddenBundled()

	syncingUserFlag = true

	for _, flag in pairs(getSharedUserFlags()) do
		if not self:getFlag(flag.position) then
			self:addFlagLocal(flag.position, flag.icon, flag.description, false, false)
		end
	end

	syncingUserFlag = false

	local settings = g_settings.getNode("Minimap")

	if settings then
		self.zoomFullmap = settings.zoomFull or self.zoomMinimap
	end
end

function UIMinimap:save()
	local settings = {
		flags = {},
		hiddenBundled = getSharedHiddenBundled()
	}

	for _, flag in pairs(getSharedUserFlags()) do
		table.insert(settings.flags, flag)
	end

	settings.zoomFull = self.zoomFullmap

	g_settings.setNode("Minimap", settings)
end

local function onFlagMouseRelease(widget, pos, button)
	if button == MouseLeftButton then
		local player = g_game.getLocalPlayer()

		if Position.distance(player:getPosition(), widget.pos) > 250 then
			modules.game_textmessage.displayStatusMessage(tr("Destination is out of range."))

			return false
		end

		if widget:getParent().autowalk then
			player:autoWalk(widget.pos)
		end

		return true
	elseif button == MouseRightButton then
		local minimap = widget:getParent()
		local menu = g_ui.createWidget("PopupMenu")

		menu:setGameMenu(true)
		menu:addOption(tr("Edit Mark"), function()
			minimap:createFlagWindow(widget.pos, widget)
		end)
		menu:addOption(tr("Delete Mark"), function()
			if widget.bundled then
				minimap:hideBundledMarker(widget.pos)

				if minimap._bundledFlagWidgets then
					minimap._bundledFlagWidgets[minimap:bundledMarkerKey(widget.pos)] = nil
				end

				widget:destroy()
			else
				removeSharedUserFlag(widget.pos)
				syncUserFlagRemovedOnAllMinimaps(widget.pos)
				persistMinimapSettings()
			end
		end)
		menu:display(pos)

		return true
	end

	return false
end

function UIMinimap:setCrossPosition(pos)
	local cross = self.cross

	if not self.cross then
		cross = g_ui.createWidget("MinimapCross", self)

		if self:getParent():getId() == "MapBase" then
			cross:setIcon("/game_cyclopedia/images/icon-map-player-red")
		else
			cross:setIcon("/game_cyclopedia/images/icon-map-player-green")
		end

		self.cross = cross
	end

	if not pos then
		cross.pos = nil

		cross:breakAnchors()
		cross:hide()

		return
	end

	cross.pos = {
		x = pos.x,
		y = pos.y,
		z = pos.z
	}

	cross:setTooltip(tr("You are here"))
	self:updateCrossVisibility()
end

function UIMinimap:setPartyMemberPosition(playerName, vocationId, pos, isLeader)
	if not playerName or playerName == "" or not pos then
		return
	end

	local member = self.partyMembers[playerName]

	if not member then
		local marker = g_ui.createWidget("MinimapCross", self)

		member = {
			widget = marker,
			pos = pos,
			vocationId = vocationId,
			isLeader = isLeader
		}
		self.partyMembers[playerName] = member
	end

	member.pos = {
		x = pos.x,
		y = pos.y,
		z = pos.z
	}
	member.vocationId = vocationId
	member.isLeader = isLeader

	if member.widget and not member.widget:isDestroyed() then
		member.widget:setIcon(isLeader and "/game_cyclopedia/images/icon-map-leader_player" or "/game_cyclopedia/images/icon-map-other_player")
		self:updatePartyMemberVisibility(member)
	end

	local vocationName = ""

	if member.vocationId and VocationsNames then
		local voc = VocationsNames[member.vocationId]

		if voc then
			vocationName = voc
		end
	end

	local tooltipText = vocationName ~= "" and vocationName .. "\n" .. tr(playerName) .. (isLeader and "\n" .. tr("Leader") or "") or ""

	member.widget:setTooltip(tooltipText)
end

function UIMinimap:removePartyMember(playerName)
	local member = self.partyMembers[playerName]

	if not member then
		return
	end

	if member.widget and not member.widget:isDestroyed() then
		member.widget:destroy()
	end

	self.partyMembers[playerName] = nil
end

function UIMinimap:clearPartyMembers()
	for name, member in pairs(self.partyMembers) do
		if member.widget and not member.widget:isDestroyed() then
			member.widget:destroy()
		end

		self.partyMembers[name] = nil
	end
end

function UIMinimap:addFlagLocal(pos, icon, description, temporary, bundled)
	if not pos or not icon then
		return
	end

	if bundled and self:isBundledHidden(pos) then
		return
	end

	local flag = self:getFlag(pos)

	if flag or not icon then
		return
	end

	temporary = temporary or false
	bundled = bundled or false
	flag = g_ui.createWidget("MinimapFlag")

	self:insertChild(1, flag)

	flag.pos = pos
	flag.description = description
	flag.icon = icon
	flag.temporary = temporary
	flag.bundled = bundled

	if type(tonumber(icon)) == "number" then
		flag:setIcon("/images/game/minimap/flag" .. icon)
	else
		flag:setIcon(resolvepath(icon, 1))
	end

	flag:setTooltip(description)

	flag.onMouseRelease = onFlagMouseRelease

	function flag.onDestroy()
		table.removevalue(self.flags, flag)

		if self._flagsByKey and flag.pos then
			self._flagsByKey[flagKeyFromPos(flag.pos)] = nil
		end
	end

	table.insert(self.flags, flag)

	self._flagsByKey[flagKeyFromPos(pos)] = flag

	self:centerInPosition(flag, pos)
end

function UIMinimap:addFlag(pos, icon, description, temporary, bundled)
	if not pos or not icon then
		return
	end

	if self:getFlag(pos) then
		return
	end

	temporary = temporary or false
	bundled = bundled or false

	self:addFlagLocal(pos, icon, description, temporary, bundled)

	if not temporary and not bundled and not syncingUserFlag then
		getSharedUserFlags()[userFlagKey(pos)] = {
			position = {
				x = pos.x,
				y = pos.y,
				z = pos.z
			},
			icon = icon,
			description = description or ""
		}

		syncUserFlagOnAllMinimaps(pos, icon, description, self)
		persistMinimapSettings()
	end
end

function UIMinimap:addAlternativeWidget(widget, pos, maxZoom)
	widget.pos = pos
	widget.maxZoom = maxZoom or 0
	widget.minZoom = minZoom

	table.insert(self.alternatives, widget)
end

function UIMinimap:setAlternativeWidgetsVisible(show)
	local layout = self:getLayout()

	layout:disableUpdates()

	for _, widget in pairs(self.alternatives) do
		if show then
			self:insertChild(1, widget)
			self:centerInPosition(widget, widget.pos)
		else
			self:removeChild(widget)
		end
	end

	layout:enableUpdates()
	layout:update()
end

function UIMinimap:onZoomChange(zoom)
	if self.fullMapView then
		self.zoomFullmap = zoom
	else
		self.zoomMinimap = zoom
	end

	self:scheduleBundledFlagsRefresh()

	for _, widget in pairs(self.alternatives) do
		if (not widget.minZoom or zoom <= widget.minZoom) and zoom >= widget.maxZoom then
			widget:show()
		else
			widget:hide()
		end
	end
end

function UIMinimap:getFlag(pos)
	if not pos then
		return nil
	end

	local index = self._flagsByKey

	if index then
		local flag = index[flagKeyFromPos(pos)]

		if flag and not flag:isDestroyed() then
			return flag
		end
	end

	for _, flag in pairs(self.flags) do
		if flag.pos and flag.pos.x == pos.x and flag.pos.y == pos.y and flag.pos.z == pos.z then
			if index then
				index[flagKeyFromPos(pos)] = flag
			end

			return flag
		end
	end

	return nil
end

function UIMinimap:removeFlag(pos, icon, description)
	local flag = self:getFlag(pos)

	if flag then
		flag:destroy()
	end
end

function UIMinimap:updateFlag(flag, icon, description)
	if not flag or flag:isDestroyed() then
		return
	end

	flag.icon = icon
	flag.description = description

	flag:setTooltip(description)

	if type(tonumber(icon)) == "number" then
		flag:setIcon("/images/game/minimap/flag" .. icon)
	else
		flag:setIcon(resolvepath(icon, 1))
	end

	if not flag.bundled and not flag.temporary then
		getSharedUserFlags()[userFlagKey(flag.pos)] = {
			position = {
				x = flag.pos.x,
				y = flag.pos.y,
				z = flag.pos.z
			},
			icon = icon,
			description = description or ""
		}

		syncUserFlagUpdateOnAllMinimaps(flag.pos, icon, description, flag)
		persistMinimapSettings()
	end
end

function UIMinimap:reset()
	local player = g_game.getLocalPlayer()

	if player then
		self:setCameraPosition(player:getPosition())
	end
end

function UIMinimap:move(x, y)
	local cameraPos = self:getCameraPosition()
	local scale = self:getScale()

	if scale > 1 then
		scale = 1
	end

	local dx = x / scale
	local dy = y / scale
	local pos = {
		x = cameraPos.x - dx,
		y = cameraPos.y - dy,
		z = cameraPos.z
	}

	self:setCameraPosition(pos)
end

function UIMinimap:smoothZoomBy(step, mousePos)
	if not self.setScale or step == 0 then
		return step > 0 and self:zoomIn() or self:zoomOut()
	end

	local targetZoom = self:getZoom() + step

	if targetZoom < self:getMinZoom() or targetZoom > self:getMaxZoom() then
		return false
	end

	if self._smoothZoomEvent then
		removeEvent(self._smoothZoomEvent)

		self._smoothZoomEvent = nil
	end

	if self.endSmoothZoom then
		self:endSmoothZoom()
	end

	local startScale = self:getScale()

	if self.beginSmoothZoom then
		self:beginSmoothZoom(mousePos or {
			x = -1,
			y = -1
		})
	end

	if not self:setZoom(targetZoom) then
		if self.endSmoothZoom then
			self:endSmoothZoom()
		end

		return false
	end

	local targetScale = self:getScale()

	self:setScale(startScale)

	if self.onSmoothZoomScaleChange then
		self:onSmoothZoomScaleChange(self:getScale())
	end

	local startedAt = g_clock.millis()
	local duration = 300

	local function animate()
		if self:isDestroyed() then
			return
		end

		local progress = math.min(1, (g_clock.millis() - startedAt) / duration)
		local eased = progress * progress * progress * (progress * (progress * 6 - 15) + 10)

		self:setScale(startScale * math.pow(targetScale / startScale, eased))

		if self.onSmoothZoomScaleChange then
			self:onSmoothZoomScaleChange(self:getScale())
		end

		if progress < 1 then
			self._smoothZoomEvent = scheduleEvent(animate, 16)
		else
			self:setScale(targetScale)

			if self.endSmoothZoom then
				self:endSmoothZoom()
			end

			if self.onSmoothZoomScaleChange then
				self:onSmoothZoomScaleChange(self:getScale())
			end

			self._smoothZoomEvent = nil
		end
	end

	self._smoothZoomEvent = scheduleEvent(animate, 16)

	return true
end

function UIMinimap:onMouseWheel(mousePos, direction)
	local keyboardModifiers = g_keyboard.getModifiers()

	if direction == MouseWheelUp and keyboardModifiers == KeyboardNoModifier then
		if self:isCyclopediaMap() then
			self:smoothZoomBy(1, mousePos)

			return true
		end

		self:zoomIn()
	elseif direction == MouseWheelDown and keyboardModifiers == KeyboardNoModifier then
		if self:isCyclopediaMap() then
			self:smoothZoomBy(-1, mousePos)

			return true
		end

		self:zoomOut()
	elseif direction == MouseWheelDown and keyboardModifiers == KeyboardCtrlModifier then
		self:floorUp(1)

		return true
	elseif direction == MouseWheelUp and keyboardModifiers == KeyboardCtrlModifier then
		self:floorDown(1)

		return true
	end

	return false
end

function UIMinimap:onMousePress(pos, button)
	if not self:isDragging() then
		self.allowNextRelease = true
	end
end

function UIMinimap:onMouseRelease(pos, button)
	if not self.allowNextRelease then
		return true
	end

	self.allowNextRelease = false

	local mapPos = self:getTilePosition(pos)

	if not mapPos then
		return false
	end

	if button == MouseLeftButton then
		local player = g_game.getLocalPlayer()

		if g_game.getClientVersion() > 1288 and g_keyboard.isCtrlPressed() and g_keyboard.isShiftPressed() then
			return g_game.sendGmTeleport(mapPos)
		end

		if Position.distance(player:getPosition(), mapPos) > 250 then
			modules.game_textmessage.displayStatusMessage(tr("Destination is out of range."))

			return false
		end

		if self.autowalk then
			player:autoWalk(mapPos)
		end

		return true
	elseif button == MouseRightButton then
		local menu = g_ui.createWidget("PopupMenu")

		menu:setGameMenu(true)
		menu:addOption(tr("Create Mark"), function()
			self:createFlagWindow(mapPos)
		end)
		menu:display(pos)

		return true
	end

	return false
end

function UIMinimap:onDragEnter(pos)
	self.dragReference = pos
	self.dragCameraReference = self:getCameraPosition()

	return true
end

function UIMinimap:onDragMove(pos, moved)
	local scale = self:getScale()
	local dx = (self.dragReference.x - pos.x) / scale
	local dy = (self.dragReference.y - pos.y) / scale
	local pos = {
		x = self.dragCameraReference.x + dx,
		y = self.dragCameraReference.y + dy,
		z = self.dragCameraReference.z
	}

	self:setCameraPosition(pos)

	return true
end

function UIMinimap:onDragLeave(widget, pos)
	return true
end

function UIMinimap:onStyleApply(styleName, styleNode)
	for name, value in pairs(styleNode) do
		if name == "autowalk" then
			self.autowalk = value
		end
	end
end

function UIMinimap:createFlagWindow(pos, existingFlag)
	if self.flagWindow then
		return
	end

	if not pos then
		return
	end

	self.flagWindow = g_ui.createWidget("MinimapFlagWindow", rootWidget)

	self.flagWindow:setText(tr(existingFlag and "Edit Mark" or "Create Mark"))

	local description = self.flagWindow:getChildById("description")
	local okButton = self.flagWindow:getChildById("okButton")
	local cancelButton = self.flagWindow:getChildById("cancelButton")
	local flagRadioGroup = UIRadioGroup.create()

	for i = 0, 19 do
		local flagButton = self.flagWindow:getChildById("flag" .. i)

		flagButton.icon = i

		flagRadioGroup:addWidget(flagButton)
	end

	if existingFlag then
		description:setText(existingFlag.description or "")

		local icon = tonumber(existingFlag.icon)

		if icon then
			local flagButton = self.flagWindow:getChildById("flag" .. icon)

			if flagButton then
				flagRadioGroup:selectWidget(flagButton, true)
			end
		end
	else
		flagRadioGroup:selectWidget(flagRadioGroup:getFirstWidget())
	end

	local function successFunc()
		local icon = flagRadioGroup:getSelectedWidget().icon
		local text = description:getText()

		if existingFlag then
			self:updateFlag(existingFlag, icon, text)
		else
			self:addFlag(pos, icon, text)
		end

		self:destroyFlagWindow()
	end

	local function cancelFunc()
		self:destroyFlagWindow()
	end

	okButton.onClick = successFunc
	cancelButton.onClick = cancelFunc
	self.flagWindow.onEnter = successFunc
	self.flagWindow.onEscape = cancelFunc

	function self.flagWindow.onDestroy()
		flagRadioGroup:destroy()
	end
end

function UIMinimap:destroyFlagWindow()
	if self.flagWindow then
		self.flagWindow:destroy()

		self.flagWindow = nil
	end
end
