-- chunkname: @/mods/game_memorial/memorial.lua

local OPCODE = 176
local window, list, btnGolden, btnRoyal, golden, royal

local function readNames(msg)
	local t = {}

	for i = 1, msg:getU16() do
		t[i] = msg:getString()
	end

	return t
end

local function addLabel(text, mt, ml)
	if ml and ml > 0 then
		local row = g_ui.createWidget("MEIndentedLabelRow", list)

		if mt then
			row:setMarginTop(mt)
		end

		row:recursiveGetChildById("indentSpacer"):setWidth(ml)

		local label = row:recursiveGetChildById("label")

		label:setText(text)
		row:setHeight(label:getHeight())

		return
	end

	local lbl = g_ui.createWidget("MEListLabel", list)

	if mt then
		lbl:setMarginTop(mt)
	end

	lbl:setText(text)
end

local function populateList(info, title, empty, isRoyal)
	list:destroyChildren()

	local hasAny = #info.base > 0 or #info.addon1 > 0 or #info.addon2 > 0

	addLabel(hasAny and title or empty, 1)

	local function sectionLabel(kind, price, mt, ml)
		if isRoyal then
			return tr("%s for %s Silver Tokens and %s Gold Tokens:", kind, formatMoney(price.silver), formatMoney(price.gold))
		end

		return tr("%s for %s gold:", kind, formatMoney(price))
	end

	if #info.addon2 > 0 then
		addLabel(sectionLabel("Full Outfit", info.price2), 13, 41)

		for _, name in ipairs(info.addon2) do
			addLabel("- " .. name, 0, 57)
		end
	end

	if #info.addon1 > 0 then
		addLabel(sectionLabel("With One Addon", info.price1), 13, 41)

		for _, name in ipairs(info.addon1) do
			addLabel("- " .. name, 0, 57)
		end
	end

	if #info.base > 0 then
		addLabel(sectionLabel("Basic Outfit", info.price0), 13, 41)

		for _, name in ipairs(info.base) do
			addLabel("- " .. name, 0, 57)
		end
	end
end

local function showMemorialWindow()
	if not window then
		return
	end

	window:show()
	window:raise()
	window:focus()

	if g_modalManager then
		g_modalManager.show(window)
	end
end

local function ensureWindow()
	if window then
		return true
	end

	window = g_ui.loadUI("memorial", g_ui.getRootWidget())

	if not window then
		return false
	end

	list = window:recursiveGetChildById("contentTextList")
	btnGolden = window:recursiveGetChildById("goldenOutfitButton")
	btnRoyal = window:recursiveGetChildById("royalCostumeButton")

	window:hide()

	return true
end

local function onPacket(_, msg)
	local p0 = msg:getU32()
	local p1 = msg:getU32() + p0
	local p2 = msg:getU32()

	golden = {
		price0 = p0,
		price1 = p1,
		price2 = p2,
		base = readNames(msg),
		addon1 = readNames(msg),
		addon2 = readNames(msg)
	}

	local royalPrices = {}

	for i = 1, 3 do
		royalPrices[i] = {
			silver = msg:getU16(),
			gold = msg:getU16()
		}
	end

	royal = {
		price0 = royalPrices[1],
		price1 = royalPrices[2],
		price2 = royalPrices[3],
		base = readNames(msg),
		addon1 = readNames(msg),
		addon2 = readNames(msg)
	}

	if not ensureWindow() then
		return
	end

	showMemorialWindow()
	selectGoldenPanel()
end

function init()
	ProtocolGame.registerOpcode(OPCODE, onPacket)
	connect(g_game, {
		onGameStart = closeMemorial,
		onGameEnd = closeMemorial
	})
end

function terminate()
	ProtocolGame.unregisterOpcode(OPCODE)
	disconnect(g_game, {
		onGameStart = closeMemorial,
		onGameEnd = closeMemorial
	})

	if window then
		if g_modalManager then
			g_modalManager.hide(window)
		end

		window:destroy()

		window = nil
	end
end

function closeMemorial()
	if not window then
		return
	end

	if g_modalManager then
		g_modalManager.hide(window)
	end

	window:hide()
end

function selectGoldenPanel()
	populateList(golden, "The following characters have spent a fortune on a Golden Outfit:", "The Golden Outfit has not been acquired by anyone yet.", false)
	btnGolden:setChecked(true)
	btnRoyal:setChecked(false)
end

function selectRoyalPanel()
	populateList(royal, "The following characters have spent a fortune on a Royal Costume:", "The Royal Costume has not been acquired by anyone yet.", true)
	btnRoyal:setChecked(true)
	btnGolden:setChecked(false)
end
