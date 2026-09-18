-- chunkname: @/game_analysers/menus/PartyHuntAnalyser.lua

if not PartyHuntAnalyser then
	PartyHuntAnalyser = {
		leader = false,
		balance = 0,
		supplies = 0,
		loot = 0,
		leaderID = 0,
		lootType = 0,
		session = 0,
		launchTime = 0,
		membersData = {},
		membersName = {}
	}
	PartyHuntAnalyser.__index = PartyHuntAnalyser
end

local packetSend = false

function PartyHuntAnalyser.create()
	PartyHuntAnalyser.launchTime = g_clock.millis()
	PartyHuntAnalyser.session = 0
	PartyHuntAnalyser.lootType = PriceTypeEnum.Market
	PartyHuntAnalyser.leaderID = 0
	PartyHuntAnalyser.leader = false
	PartyHuntAnalyser.loot = 0
	PartyHuntAnalyser.supplies = 0
	PartyHuntAnalyser.balance = 0
	PartyHuntAnalyser.event = nil
	PartyHuntAnalyser.membersData = {}
	PartyHuntAnalyser.membersName = {}
	PartyHuntAnalyser.window = openedWindows.partyButton
end

function PartyHuntAnalyser:startEvent()
	PartyHuntAnalyser.session = 0

	if PartyHuntAnalyser.event then
		PartyHuntAnalyser.event:cancel()
	end
end

function PartyHuntAnalyser:resetSessionData()
	PartyHuntAnalyser.session = 0
	PartyHuntAnalyser.loot = 0
	PartyHuntAnalyser.supplies = 0
	PartyHuntAnalyser.balance = 0

	for id, data in pairs(PartyHuntAnalyser.membersData) do
		PartyHuntAnalyser.membersData[id] = {
			0,
			0,
			0,
			0,
			data[5]
		}
	end

	PartyHuntAnalyser:updateWindow(true, true)
end

function PartyHuntAnalyser:removeStaleMemberWidgets()
	if not PartyHuntAnalyser.window then
		return
	end

	local contentsPanel = PartyHuntAnalyser.window.contentsPanel

	if not contentsPanel or not contentsPanel.party then
		return
	end

	for _, child in ipairs(contentsPanel.party:getChildren()) do
		local memberId = tonumber(child:getId())

		if memberId and not PartyHuntAnalyser.membersData[memberId] then
			child:destroy()
		end
	end
end

function PartyHuntAnalyser:reset()
	PartyHuntAnalyser.launchTime = g_clock.millis()
	PartyHuntAnalyser.session = 0
	PartyHuntAnalyser.lootType = PriceTypeEnum.Market
	PartyHuntAnalyser.leaderID = 0
	PartyHuntAnalyser.leader = false
	PartyHuntAnalyser.loot = 0
	PartyHuntAnalyser.supplies = 0
	PartyHuntAnalyser.balance = 0
	PartyHuntAnalyser.membersData = {}
	PartyHuntAnalyser.membersName = {}

	if PartyHuntAnalyser.event then
		PartyHuntAnalyser.event:cancel()
	end

	local contentsPanel = PartyHuntAnalyser.window:getChildById("contentsPanel")

	contentsPanel.party:destroyChildren()
	PartyHuntAnalyser:updateWindow(true, true)
end

function PartyHuntAnalyser:updateWindow(updateMembers, ignoreVisible)
	if not PartyHuntAnalyser.window:isVisible() and not ignoreVisible then
		return
	end

	local contentsPanel = PartyHuntAnalyser.window.contentsPanel

	contentsPanel.lootType:setText(PartyHuntAnalyser.lootType == PriceTypeEnum.Market and "Market" or "Leader")

	local duration = math.max(1, PartyHuntAnalyser.session)
	local hours = math.floor(duration / 3600)
	local minutes = math.floor(duration % 3600 / 60)

	contentsPanel.session:setText(string.format("%02d:%02dh", hours, minutes))

	if not updateMembers then
		return
	end

	local lootTotal = 0
	local supplyTotal = 0
	local c = 0
	local membersSorted = {}

	for id, _ in pairs(PartyHuntAnalyser.membersData) do
		local name = PartyHuntAnalyser.membersName[id] or "Unknow"

		table.insert(membersSorted, {
			id = id,
			name = name
		})
	end

	table.sort(membersSorted, function(a, b)
		return string.lower(a.name) < string.lower(b.name)
	end)

	for idx, member in ipairs(membersSorted) do
		local id = member.id
		local data = PartyHuntAnalyser.membersData[id]
		local widget = contentsPanel.party:getChildById(id)

		widget = widget or g_ui.createWidget("Info", contentsPanel.party)
		c = c + 1
		lootTotal = lootTotal + data[1]
		supplyTotal = supplyTotal + data[2]

		local playerBalance = data[1] - data[2]
		local playerName = PartyHuntAnalyser.membersName[id] or "Unknow"
		local leaderPt = widget:getChildById("leaderPt")
		local nameLabel = widget:getChildById("name")

		nameLabel:breakAnchors()
		nameLabel:addAnchor(AnchorTop, "parent", AnchorTop)

		if id == PartyHuntAnalyser.leaderID then
			leaderPt:setVisible(true)
			nameLabel:addAnchor(AnchorLeft, "leaderPt", AnchorRight)
			nameLabel:setMarginLeft(2)
		else
			leaderPt:setVisible(false)
			nameLabel:addAnchor(AnchorLeft, "parent", AnchorLeft)
			nameLabel:setMarginLeft(0)
		end

		nameLabel:setText(playerName)

		if not data[5] then
			nameLabel:setColor("$var-cip-inactive-color")
		elseif id == PartyHuntAnalyser.leaderID then
			nameLabel:setColor("$var-text-cip-color-yellow")
		else
			nameLabel:setColor("$var-text-cip-color")
		end

		widget.balance:setText(comma_value(playerBalance))
		widget.balance:setColor(playerBalance >= 0 and "$var-text-cip-color-green" or "$var-text-cip-color-orange")
		widget.damage:setText(comma_value(data[3]))
		widget.healing:setText(comma_value(data[4]))
		widget:setId(id)

		local tooltipMessage = {}

		setStringColor(tooltipMessage, tr("Loot: %s ", comma_value(data[1])), "#3f3f3f")
		setStringColor(tooltipMessage, "$\n", "yellow")
		setStringColor(tooltipMessage, tr("Supplies: %s ", comma_value(data[2])), "#3f3f3f")
		setStringColor(tooltipMessage, "$\n", "yellow")
		setStringColor(tooltipMessage, tr("Balance: %s ", comma_value(playerBalance)), "#3f3f3f")
		setStringColor(tooltipMessage, "$", "yellow")
		widget.balance:setTooltip(tooltipMessage)
	end

	PartyHuntAnalyser:removeStaleMemberWidgets()

	for idx, member in ipairs(membersSorted) do
		local w = contentsPanel.party:getChildById(member.id)

		if w then
			contentsPanel.party:moveChildToIndex(w, idx)
		end
	end

	if contentsPanel.party.updateLayout then
		contentsPanel.party:updateLayout()
	end

	contentsPanel.party:setHeight(40 + c * 65)

	local balance = lootTotal - supplyTotal

	PartyHuntAnalyser.loot = lootTotal
	PartyHuntAnalyser.supplies = supplyTotal
	PartyHuntAnalyser.balance = balance

	contentsPanel.loot:setText(formatMoney(lootTotal, ","))
	contentsPanel.supplies:setText(formatMoney(supplyTotal, ","))
	contentsPanel.balance:setText(comma_value(balance))
	contentsPanel.balance:setColor(balance >= 0 and "$var-text-cip-color-green" or "$var-text-cip-color-orange")
end

function PartyHuntAnalyser:onPartyAnalyzer(startTime, leaderID, lootType, membersData, membersName)
	if membersName and next(membersName) then
		PartyHuntAnalyser.membersName = membersName
	end

	if next(membersData) == nil and next(PartyHuntAnalyser.membersData) ~= nil then
		local resetData = {}

		for id, data in pairs(PartyHuntAnalyser.membersData) do
			resetData[id] = {
				0,
				0,
				0,
				0,
				data[5]
			}
		end

		membersData = resetData
	end

	PartyHuntAnalyser.session = startTime
	PartyHuntAnalyser.leaderID = leaderID
	PartyHuntAnalyser.lootType = lootType
	PartyHuntAnalyser.membersData = membersData

	if PartyHuntAnalyser.event then
		PartyHuntAnalyser.event:cancel()
	end

	PartyHuntAnalyser.event = cycleEvent(function()
		if not g_game.isOnline() then
			return
		end

		PartyHuntAnalyser.session = PartyHuntAnalyser.session + 1

		PartyHuntAnalyser:updateWindow(false, true)
	end, 1000)

	PartyHuntAnalyser:updateWindow(true, true)

	PartyHuntAnalyser.leader = g_game.getLocalPlayer():getId() == leaderID
end

function getLeaderLootType()
	return PartyHuntAnalyser.lootType
end

local function isPartyHuntLeader(player)
	if not player then
		return false
	end

	return player:isPartyLeader() or PartyHuntAnalyser.leaderID > 0 and player:getId() == PartyHuntAnalyser.leaderID
end

function isLeaderParty()
	return isPartyHuntLeader(g_game.getLocalPlayer())
end

local function getSplitMembers()
	local members = {}

	for id, data in pairs(PartyHuntAnalyser.membersData) do
		if data[5] ~= false then
			table.insert(members, {
				id = id,
				name = PartyHuntAnalyser.membersName[id] or "Unknow",
				loot = data[1] or 0,
				supplies = data[2] or 0
			})
		end
	end

	if #members == 0 then
		for id, data in pairs(PartyHuntAnalyser.membersData) do
			table.insert(members, {
				id = id,
				name = PartyHuntAnalyser.membersName[id] or "Unknow",
				loot = data[1] or 0,
				supplies = data[2] or 0
			})
		end
	end

	table.sort(members, function(a, b)
		return string.lower(a.name) < string.lower(b.name)
	end)

	return members
end

local function generateLootSplitText()
	local members = getSplitMembers()

	if #members == 0 then
		return nil
	end

	local totalBalance = 0

	for _, member in ipairs(members) do
		member.balance = member.loot - member.supplies
		totalBalance = totalBalance + member.balance
	end

	local memberCount = #members
	local fairShareBase = math.floor(totalBalance / memberCount)
	local remainder = totalBalance - fairShareBase * memberCount
	local payers = {}
	local receivers = {}

	for i, member in ipairs(members) do
		local fairShare = fairShareBase + (i <= remainder and 1 or 0)
		local delta = member.balance - fairShare

		if delta > 0 then
			table.insert(payers, {
				name = member.name,
				amount = delta
			})
		elseif delta < 0 then
			table.insert(receivers, {
				name = member.name,
				amount = -delta
			})
		end
	end

	local function sortByAmountDesc(a, b)
		return a.amount > b.amount
	end

	table.sort(payers, sortByAmountDesc)
	table.sort(receivers, sortByAmountDesc)

	local lines = {}
	local payerIndex = 1
	local receiverIndex = 1

	while payerIndex <= #payers and receiverIndex <= #receivers do
		local payer = payers[payerIndex]
		local receiver = receivers[receiverIndex]
		local transferAmount = math.min(payer.amount, receiver.amount)

		if transferAmount > 0 then
			lines[#lines + 1] = string.format("%s should pay %s gp to %s. (transfer %d to %s)", payer.name, comma_value(transferAmount), receiver.name, transferAmount, receiver.name)
		end

		payer.amount = payer.amount - transferAmount
		receiver.amount = receiver.amount - transferAmount

		if payer.amount == 0 then
			payerIndex = payerIndex + 1
		end

		if receiver.amount == 0 then
			receiverIndex = receiverIndex + 1
		end
	end

	lines[#lines + 1] = string.format("Total balance: %s gp", comma_value(totalBalance))
	lines[#lines + 1] = string.format("Number of people: %d", memberCount)
	lines[#lines + 1] = string.format("Balance per person: %s gp", comma_value(fairShareBase))

	return table.concat(lines, "\n")
end

function onPartyHuntExtra(mousePosition)
	if cancelNextRelease then
		cancelNextRelease = false

		return false
	end

	local player = g_game.getLocalPlayer()

	if not player then
		return false
	end

	local menu = g_ui.createWidget("PopupMenu")

	menu:setGameMenu(true)

	if isPartyHuntLeader(player) then
		local lootType = PartyHuntAnalyser.lootType == PriceTypeEnum.Market and "Leader" or "Market"

		menu:addOption(tr("Reset Data of Current Party Session"), function()
			g_game.sendPartyResetSession()
			PartyHuntAnalyser:resetSessionData()
		end)
		menu:addOption(tr("Use %s Prices", lootType), function()
			g_game.sendPartyLootType(PartyHuntAnalyser.lootType == PriceTypeEnum.Market and PriceTypeEnum.Leader or PriceTypeEnum.Market)

			if PartyHuntAnalyser.lootType == PriceTypeEnum.Market and modules.game_cyclopedia and modules.game_cyclopedia.CyclopediaItems and modules.game_cyclopedia.CyclopediaItems.sendPartyLootItems then
				modules.game_cyclopedia.CyclopediaItems.sendPartyLootItems()
			end
		end)
		menu:addSeparator()
	elseif player:getShield() == ShieldNone then
		menu:addOption(tr("Reset Data of Last Session"), function()
			PartyHuntAnalyser:reset()
		end)
	end

	menu:addOption(tr("Copy to Clipboard"), function()
		PartyHuntAnalyser:clipboardData()
	end)
	menu:addOption(tr("Copy to LootSplitter"), function()
		PartyHuntAnalyser:lootSplitter()
	end)
	menu:display(mousePosition)

	return true
end

local function generatePartyText()
	local duration = math.max(1, PartyHuntAnalyser.session)
	local hours = math.floor(duration / 3600)
	local minutes = math.floor(duration % 3600 / 60)
	local lines = {}

	if PartyHuntAnalyser.session > 0 then
		lines[#lines + 1] = "Session data: From " .. os.date("%Y-%m-%d, %H:%M:%S", os.time() - PartyHuntAnalyser.session) .. " to " .. os.date("%Y-%m-%d, %H:%M:%S")
	end

	lines[#lines + 1] = "Session: " .. string.format("%02d:%02dh", hours, minutes)
	lines[#lines + 1] = "Loot Type: " .. (PartyHuntAnalyser.lootType ~= PriceTypeEnum.Market and "Leader" or "Market")
	lines[#lines + 1] = "Loot: " .. comma_value(PartyHuntAnalyser.loot)
	lines[#lines + 1] = "Supplies: " .. comma_value(PartyHuntAnalyser.supplies)
	lines[#lines + 1] = "Balance: " .. comma_value(PartyHuntAnalyser.balance)

	for id, data in pairs(PartyHuntAnalyser.membersData) do
		local playerName = PartyHuntAnalyser.membersName[id] or "Unknow"

		lines[#lines + 1] = playerName .. (id == PartyHuntAnalyser.leaderID and " (Leader)" or "")
		lines[#lines + 1] = "\tLoot: " .. comma_value(data[1])
		lines[#lines + 1] = "\tSupplies: " .. comma_value(data[2])
		lines[#lines + 1] = "\tBalance: " .. comma_value(data[1] - data[2])
		lines[#lines + 1] = "\tDamage: " .. comma_value(data[3])
		lines[#lines + 1] = "\tHealing: " .. comma_value(data[4])
	end

	return table.concat(lines, "\n")
end

function PartyHuntAnalyser:clipboardData()
	g_window.setClipboardText(generatePartyText())
end

function PartyHuntAnalyser:lootSplitter()
	local text = generateLootSplitText()

	if not text or text == "" then
		g_logger.warning("game_analysers: nenhum membro disponivel para dividir o loot.")

		return
	end

	g_window.setClipboardText(text)
	g_logger.info("game_analysers: divisao de loot copiada para a area de transferencia.")
end

function onShieldChange(creature, shieldId)
	if creature == g_game.getLocalPlayer() then
		if creature:isPartyLeader() and not packetSend then
			PartyHuntAnalyser.leader = true
			packetSend = true

			g_game.sendPartyLootPrice({})
		elseif shieldId == 0 and packetSend then
			PartyHuntAnalyser.leader = false
			packetSend = false
			PartyHuntAnalyser.session = 0

			if PartyHuntAnalyser.event then
				PartyHuntAnalyser.event:cancel()
			end
		end
	end
end

function onPartyMembersChange(self, members)
	if #members == 0 then
		PartyHuntAnalyser:reset()

		local contentsPanel = PartyHuntAnalyser.window.contentsPanel

		if contentsPanel then
			contentsPanel.party:destroyChildren()
			contentsPanel.party:setHeight(65)
		end
	end
end
