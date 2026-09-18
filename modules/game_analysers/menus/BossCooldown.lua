-- chunkname: @/game_analysers/menus/BossCooldown.lua

if not BossCooldown then
	BossCooldown = {
		search = "",
		lastUiSecond = 0,
		entries = {},
		widgets = {}
	}
	BossCooldown.__index = BossCooldown
end

local function raceLabel(raceId)
	local ok, data = pcall(function()
		return g_things.getRaceData(raceId)
	end)

	if ok and data and data.name and data.name ~= "" then
		return data.name
	end

	return string.format("#%s", tostring(raceId))
end

local function normalizeUntil(raw)
	raw = tonumber(raw) or 0

	if raw < 1 then
		return os.time()
	end

	if raw >= 1000000000 then
		return raw
	end

	return os.time() + raw
end

local function entryHasCooldown(entry, now)
	return entry.untilTs > (now or os.time())
end

local function sortBossEntries(entries)
	local now = os.time()

	table.sort(entries, function(a, b)
		local aOnCd = entryHasCooldown(a, now)
		local bOnCd = entryHasCooldown(b, now)

		if aOnCd ~= bOnCd then
			return aOnCd
		end

		local na, nb = a.name:lower(), b.name:lower()

		if na ~= nb then
			return na < nb
		end

		return a.bossId < b.bossId
	end)
end

local function formatRemain(sec)
	sec = math.max(0, math.floor(sec))

	if sec <= 0 then
		return tr("No Cooldown"), "$var-text-cip-color"
	end

	if sec <= 60 then
		return sec .. "s", "$var-text-cip-color-orange"
	end

	local d = math.floor(sec / 86400)
	local h = math.floor(sec % 86400 / 3600)
	local m = math.floor(sec % 3600 / 60)

	if d > 0 then
		return string.format("%dd %02dh %02dm", d, h, m), "$var-text-cip-color-orange"
	end

	return string.format("%02dh %02dm", h, m), "$var-text-cip-color-orange"
end

local function fitBossCreature(widget, outfit)
	if not widget.setCreatureSize or not g_things.getCreatureBoundingBox then
		return
	end

	local creature = widget:getCreature()
	local outfitId = tonumber(outfit and outfit.type) or 0

	if not creature or not creature.getExactSize or outfitId <= 0 then
		return
	end

	local direction = creature:getDirection()
	local zPattern = (tonumber(outfit.mount) or 0) > 0 and 1 or 0
	local boundsOk, bounds = pcall(function()
		return g_things.getCreatureBoundingBox(outfitId, 0, direction, zPattern)
	end)
	local sizeOk, exactSize = pcall(function()
		return creature:getExactSize()
	end)

	if not boundsOk or type(bounds) ~= "table" or not sizeOk then
		return
	end

	exactSize = tonumber(exactSize) or 0

	local visualSize = math.max(tonumber(bounds.width) or 0, tonumber(bounds.height) or 0)

	if exactSize <= 0 or visualSize <= exactSize then
		return
	end

	local spriteSize = tonumber(g_gameConfig.getSpriteSize()) or 32
	local percentageBase = math.max(exactSize, spriteSize * 2)

	widget:setCreatureSize(math.min(255, math.ceil(visualSize * 100 / percentageBase)))
end

function BossCooldown.create()
	BossCooldown.window = openedWindows.bossButton
end

function BossCooldown:reset()
	self.search = ""
	self.entries = {}
	self.widgets = {}

	self:rebuild()
end

function BossCooldown:setupCooldown(rows)
	self.entries = {}

	if type(rows) ~= "table" then
		self:rebuild()

		return
	end

	for _, row in pairs(rows) do
		if type(row) == "table" and row[1] then
			local rid = tonumber(row[1])
			local raw = tonumber(row[2])

			if rid then
				self.entries[#self.entries + 1] = {
					bossId = rid,
					untilTs = normalizeUntil(raw),
					name = raceLabel(rid)
				}
			end
		end
	end

	self:rebuild()
end

function BossCooldown:rebuild()
	if not self.window or self.window:isDestroyed() then
		return
	end

	local contents = self.window.contentsPanel
	local bosses = contents.bosses

	bosses:destroyChildren()

	self.widgets = {}

	sortBossEntries(self.entries)

	local q = (self.search or ""):lower()
	local n = 0

	for _, e in ipairs(self.entries) do
		local w = g_ui.createWidget("BossInfo", bosses)
		local creatureW = w:getChildById("creature")

		if creatureW then
			local raceData = g_things.getRaceData(e.bossId)

			if raceData and raceData.outfit and raceData.raceId ~= 0 then
				creatureW:setOutfit(raceData.outfit)

				if creatureW.setFixedCreatureSize then
					creatureW:setFixedCreatureSize(false)
				end

				if creatureW.setCenter then
					creatureW:setCenter(true)
				end

				if creatureW.setCenterByBoundingBox then
					creatureW:setCenterByBoundingBox(true)
				end

				fitBossCreature(creatureW, raceData.outfit)

				if creatureW.setBaseScale then
					-- block empty
				end

				creatureW:setVisible(true)
			else
				creatureW:setVisible(false)
			end
		end

		w.bossName:setText(short_text(string.capitalize(e.name), 18))
		w:setTooltip(e.name)

		function w.onClick()
			local B = modules.game_cyclopedia and modules.game_cyclopedia.Bosstiary

			if B and B.onSideButtonRedirect then
				B.onSideButtonRedirect(e.name)
			end
		end

		w.entry = e
		w.bossId = e.bossId

		local vis = q == "" or #q < 2 or e.name:lower():find(q, 1, true) ~= nil

		w:setVisible(vis)

		if vis then
			n = n + 1
		end

		self.widgets[#self.widgets + 1] = w
	end

	for idx, w in ipairs(self.widgets) do
		if w and bosses.moveChildToIndex then
			bosses:moveChildToIndex(w, idx)
		end
	end

	if bosses.updateLayout then
		bosses:updateLayout()
	end

	bosses:setHeight(math.max(40, 8 + n * 38))

	self.lastUiSecond = -1

	self:refreshTexts()
end

function BossCooldown:updateWindow()
	self:rebuild()
end

function BossCooldown:checkTicks()
	local t = os.time()

	if t == self.lastUiSecond then
		return
	end

	self.lastUiSecond = t

	self:refreshTexts()
end

function BossCooldown:reorderWidgets()
	if not self.window or self.window:isDestroyed() then
		return
	end

	local bosses = self.window.contentsPanel.bosses

	sortBossEntries(self.entries)

	for idx, e in ipairs(self.entries) do
		for _, w in ipairs(self.widgets) do
			if w.bossId == e.bossId and bosses.moveChildToIndex then
				bosses:moveChildToIndex(w, idx)

				break
			end
		end
	end

	if bosses.updateLayout then
		bosses:updateLayout()
	end
end

function BossCooldown:refreshTexts()
	self:reorderWidgets()

	local q = (self.search or ""):lower()

	for _, w in ipairs(self.widgets) do
		local e = w.entry

		if e then
			local vis = q == "" or #q < 2 or e.name:lower():find(q, 1, true) ~= nil

			w:setVisible(vis)

			local txt, col = formatRemain(e.untilTs - os.time())

			w.bossNCooldown:setText(txt)
			w.bossNCooldown:setColor(col)
		end
	end
end

function checkBossSearch(text)
	if #text <= 1 then
		BossCooldown.search = ""
	else
		BossCooldown.search = text
	end

	BossCooldown:refreshTexts()
end

function clearSearch()
	BossCooldown.search = ""

	local st = BossCooldown.window and BossCooldown.window.contentsPanel and BossCooldown.window.contentsPanel.searchText

	if st then
		st:setText("", false)
	end

	BossCooldown:refreshTexts()
end

function BossCooldown:hasCooldown(raceId)
	for _, e in ipairs(self.entries) do
		if e.bossId == raceId then
			return e.name, e.untilTs
		end
	end

	return "", -1
end

function BossCooldown:getCooldown(raceId)
	for _, e in ipairs(self.entries) do
		if e.bossId == raceId and e.untilTs > os.time() then
			return select(1, formatRemain(e.untilTs - os.time()))
		end
	end

	return ""
end
