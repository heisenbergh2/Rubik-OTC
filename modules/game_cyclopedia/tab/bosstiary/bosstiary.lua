-- chunkname: @/game_cyclopedia/tab/bosstiary/bosstiary.lua

local UI

function Cyclopedia.clearBosstiaryUI()
	if UI and UI.SearchEdit and not UI.SearchEdit:isDestroyed() then
		pcall(function()
			UI.SearchEdit:ungrabKeyboard()
		end)
	end

	UI = nil
end

function showBosstiary()
	Cyclopedia.clearBosstiaryUI()

	UI = g_ui.loadUI("bosstiary", contentContainer)

	function UI.onDestroy()
		UI = nil
	end

	UI:show()
	g_game.requestBosstiaryInfo()
	UI.FilterBase.BaneIcon:setTooltip("Bane\n\nFor unlocking a level, you will receive the following boss points:\nProwess: 5\nExpertise: 15\nMastery: 30")
	UI.FilterBase.ArchfoeIcon:setTooltip("Archfoe\n\nFor unlocking a level, you will receive the following boss points:\nProwess: 10\nExpertise: 30\nMastery: 60")
	UI.FilterBase.NemesisIcon:setTooltip("Nemesis\n\nFor unlocking a level, you will receive the following boss points:\nProwess: 10\nExpertise: 30\nMastery: 60")
	UI.StarBase.Info1:setTooltip("Once you have reached the Prowess level, you can assign the boss\nto a boss slot.")
	UI.StarBase.Info2:setTooltip("Once you have reached the Expertise Level, you can display the\nboss on a Podium of Vigour.")
	UI.StarBase.Info3:setTooltip("Once you have reached the Mastery Level, youl will receive an\nadditional 25% loot bonus when the boss is assigned to a boss slot.")
	controllerCyclopedia.ui.MajorCharmsBase:setVisible(false)
	controllerCyclopedia.ui.GoldBase:setVisible(false)
	controllerCyclopedia.ui.BestiaryTrackerButton:setVisible(false)
	controllerCyclopedia.ui.MinorCharmsBase:setVisible(false)
end

Cyclopedia.Bosstiary = {}
Cyclopedia._bosstiaryTrackerOverrides = Cyclopedia._bosstiaryTrackerOverrides or {}

function Cyclopedia.toggleBosstiaryTrackerCheck(widget, checked)
	if not widget or widget._suppressTrackerChange then
		return
	end

	local parent = widget:getParent()

	if not parent then
		return
	end

	local raceId = tonumber(parent:getId())

	if not raceId then
		return
	end

	g_game.sendStatusTrackerBestiary(raceId, checked)

	Cyclopedia._bosstiaryTrackerOverrides[raceId] = checked and 1 or 0

	if not checked then
		Cyclopedia.removeFromTracker(1, raceId)
	end

	if Cyclopedia.Bosstiary and Cyclopedia.Bosstiary.Creatures then
		for _, page in pairs(Cyclopedia.Bosstiary.Creatures) do
			for _, creature in ipairs(page) do
				if creature.raceId == raceId then
					creature.isTrackerActived = checked and 1 or 0
				end
			end
		end
	end
end

local CATEGORY = {
	BANE = 0,
	ARCHFOE = 1,
	NEMESIS = 2
}
local CONFIG = {
	[0] = {
		PROWESS = 25,
		EXPERTISE = 100,
		MASTERY = 300
	},
	{
		PROWESS = 5,
		EXPERTISE = 20,
		MASTERY = 60
	},
	{
		PROWESS = 1,
		EXPERTISE = 3,
		MASTERY = 5
	}
}

function Cyclopedia.setBosstiaryBossStars(widget, kills, config)
	local bronzeFill = widget.bronzeStar:getChildById("bronzeStarFill")

	if bronzeFill then
		bronzeFill:setVisible(kills >= config.PROWESS)
	end

	for i = 1, 2 do
		local fill = widget.silverStar:getChildById("silverStarFill" .. i)

		if fill then
			fill:setVisible(kills >= config.EXPERTISE)
		end
	end

	for i = 1, 3 do
		local fill = widget.goldStar:getChildById("goldStarFill" .. i)

		if fill then
			fill:setVisible(kills >= config.MASTERY)
		end
	end
end

function Cyclopedia.CreateBosstiaryCreature(data)
	if not data.visible then
		return
	end

	local widget = g_ui.createWidget("BosstiaryItem", UI.ListBase.BossList)

	widget:setId(data.raceId)

	local raceData = g_things.getRaceData(data.raceId)
	local icons = {
		[CATEGORY.BANE] = "/images/icons/icon-bosstiary-bane",
		[CATEGORY.ARCHFOE] = "/images/icons/icon-bosstiary-archfoe",
		[CATEGORY.NEMESIS] = "/images/icons/icon-bosstiary-nemesis"
	}

	local function format(string)
		if #string > 19 then
			return string:sub(1, 16) .. "..."
		else
			return string
		end
	end

	local fullText = ""

	if data.kills >= CONFIG[data.category].MASTERY then
		fullText = "(fully unlocked)"
	end

	widget.ProgressBorder1:setTooltip(string.format(" %d / %d %s", data.kills, CONFIG[data.category].PROWESS, fullText))
	widget.ProgressBorder2:setTooltip(string.format(" %d / %d %s", data.kills, CONFIG[data.category].EXPERTISE, fullText))
	widget.ProgressBorder3:setTooltip(string.format(" %d / %d %s", data.kills, CONFIG[data.category].MASTERY, fullText))
	Cyclopedia.setBosstiaryBossStars(widget, data.kills, CONFIG[data.category])
	widget.TypeIcon:setImageSource(icons[data.category])

	if data.category == CATEGORY.BANE then
		widget.TypeIcon:setTooltip("Bane\n\nFor unlocking a level, you will receive the following boss points:\nProwess: 5\nExpertise: 15\nMastery: 30")
	elseif data.category == CATEGORY.ARCHFOE then
		widget.TypeIcon:setTooltip("Archfoe\n\nFor unlocking a level, you will receive the following boss points:\nProwess: 10\nExpertise: 30\nMastery: 60")
	elseif data.category == CATEGORY.NEMESIS then
		widget.TypeIcon:setTooltip("Nemesis\n\nFor unlocking a level, you will receive the following boss points:\nProwess: 10\nExpertise: 30\nMastery: 60")
	end

	widget.ProgressValue:setText(data.kills)
	Cyclopedia.SetBestiaryProgress(46, widget.ProgressBack, widget.ProgressBack33, widget.ProgressBack55, data.kills, CONFIG[data.category].PROWESS, CONFIG[data.category].EXPERTISE, CONFIG[data.category].MASTERY, 47, 12)
	widget.Sprite:setOutfit(raceData.outfit)
	widget.Sprite:getCreature():setStaticWalking(1000)

	if data.unlocked then
		widget.Sprite:getCreature():setShader("")
		widget:setText(format(data.name))
		widget.TrackCheck:enable()

		local override = Cyclopedia._bosstiaryTrackerOverrides[data.raceId]
		local trackerActived = override ~= nil and override or data.isTrackerActived

		widget.TrackCheck._suppressTrackerChange = true

		widget.TrackCheck:setChecked(trackerActived == 1)

		widget.TrackCheck._suppressTrackerChange = false
	else
		widget.Sprite:getCreature():setShader("Outfit - cyclopedia-black")
		widget.TrackCheck:disable()
	end
end

function Cyclopedia.LoadBosstiaryCreatures(data)
	if not UI then
		return
	end

	local maxCategoriesPerPage = 8

	Cyclopedia.Bosstiary.Creatures = {}
	Cyclopedia.Bosstiary.NotVisibleCreatures = {}
	Cyclopedia.Bosstiary.Page = 1
	Cyclopedia.Bosstiary.TotalPages = math.ceil(#data / maxCategoriesPerPage)

	UI.PageValue:setText(string.format("%d / %d", Cyclopedia.Bosstiary.Page, Cyclopedia.Bosstiary.TotalPages))

	local page = 1

	Cyclopedia.Bosstiary.Creatures[page] = {}

	local validCreatures = {}

	for i, dataEntry in ipairs(data) do
		local raceData = g_things.getRaceData(dataEntry.raceId)
		local creature = {
			visible = true,
			raceId = dataEntry.raceId,
			name = raceData and raceData.name or "?",
			kills = dataEntry.kills,
			category = dataEntry.category,
			isTrackerActived = dataEntry.isTrackerActived,
			unlocked = dataEntry.kills > 0 and true or false
		}

		table.insert(validCreatures, creature)
	end

	table.sort(validCreatures, function(a, b)
		if a.name == "?" and b.name ~= "?" then
			return false
		elseif a.name ~= "?" and b.name == "?" then
			return true
		elseif a.unlocked and not b.unlocked then
			return true
		elseif not a.unlocked and b.unlocked then
			return false
		else
			return a.name < b.name
		end
	end)

	for i = 1, #validCreatures do
		local creature = validCreatures[i]

		if creature.visible then
			table.insert(Cyclopedia.Bosstiary.Creatures[page], creature)
		else
			table.insert(Cyclopedia.Bosstiary.NotVisibleCreatures[page], creature)
		end

		if i % maxCategoriesPerPage == 0 and i < #validCreatures then
			page = page + 1
			Cyclopedia.Bosstiary.Creatures[page] = {}
		end
	end

	Cyclopedia.LoadBosstiaryCreature(Cyclopedia.Bosstiary.Page)
	Cyclopedia.verifyBosstiaryButtons()
	Cyclopedia.applyPendingBosstiaryShortcut()
end

function Cyclopedia.applyPendingBosstiaryShortcut()
	local raceId = Cyclopedia._pendingBosstiaryRaceId

	if not raceId or not UI then
		return false
	end

	if not Cyclopedia.Bosstiary.Creatures or #Cyclopedia.Bosstiary.Creatures == 0 then
		return false
	end

	local raceData = g_things.getRaceData(raceId)

	if not raceData or not raceData.name or raceData.name == "" then
		return false
	end

	Cyclopedia._pendingBosstiaryRaceId = nil

	local searchText = raceData.name

	if UI.SearchEdit then
		UI.SearchEdit:setText(searchText)
	end

	Cyclopedia.BosstiarySearchText(searchText)

	return true
end

function Cyclopedia.focusBosstiaryRaceId(raceId)
	if not raceId or not UI or not Cyclopedia.Bosstiary.Creatures then
		return false
	end

	for page = 1, #Cyclopedia.Bosstiary.Creatures do
		local creatures = Cyclopedia.Bosstiary.Creatures[page]

		if creatures then
			for _, creature in ipairs(creatures) do
				if creature.raceId == raceId then
					Cyclopedia.Bosstiary.Page = page

					Cyclopedia.LoadBosstiaryCreature(page)
					Cyclopedia.verifyBosstiaryButtons()

					return true
				end
			end
		end
	end

	return false
end

function Cyclopedia.LoadBosstiaryCreature(page)
	if not Cyclopedia.Bosstiary.Creatures[page] then
		return
	end

	UI.ListBase.BossList:destroyChildren()

	for _, data in ipairs(Cyclopedia.Bosstiary.Creatures[page]) do
		Cyclopedia.CreateBosstiaryCreature(data)
	end
end

function Cyclopedia.verifyBosstiaryButtons()
	local page = Cyclopedia.Bosstiary.Page
	local totalPages = Cyclopedia.Bosstiary.TotalPages

	local function updateButtonState(button, condition)
		if condition then
			button:enable()
		else
			button:disable()
		end
	end

	local function updatePageValue(currentPage, maxPages)
		UI.PageValue:setText(string.format("%d / %d", currentPage, maxPages))
	end

	updateButtonState(UI.PrevPageButton, page > 1)
	updateButtonState(UI.NextPageButton, page < totalPages)
	updatePageValue(page, totalPages)
end

function Cyclopedia.changeBosstiaryPage(prev, next)
	if next then
		Cyclopedia.Bosstiary.Page = Cyclopedia.Bosstiary.Page + 1
	end

	if prev then
		Cyclopedia.Bosstiary.Page = Cyclopedia.Bosstiary.Page - 1
	end

	Cyclopedia.LoadBosstiaryCreature(Cyclopedia.Bosstiary.Page)
	Cyclopedia.verifyBosstiaryButtons()
end

function Cyclopedia.BosstiarySearchText(text, clear)
	local allCreatures = {}

	if clear then
		UI.SearchEdit:setText("")
	end

	for _, creatures in ipairs(Cyclopedia.Bosstiary.Creatures) do
		for _, creature in ipairs(creatures) do
			table.insert(allCreatures, creature)
		end
	end

	for _, creature in ipairs(Cyclopedia.Bosstiary.NotVisibleCreatures) do
		table.insert(allCreatures, creature)
	end

	if text ~= "" then
		for _, creature in ipairs(allCreatures) do
			if not creature.unlocked then
				creature.visible = false
			elseif string.find(creature.name:lower(), text:lower()) == nil then
				creature.visible = false
			else
				creature.visible = true
			end
		end
	else
		for _, creature in ipairs(allCreatures) do
			creature.visible = true
		end
	end

	Cyclopedia.ReadjustPages()
end

function Cyclopedia.changeBosstiaryFilter(widget, isCheck)
	widget:setChecked(not isCheck)

	local id = widget:getId()
	local allCreatures = {}

	for _, creatures in ipairs(Cyclopedia.Bosstiary.Creatures) do
		for _, creature in ipairs(creatures) do
			table.insert(allCreatures, creature)
		end
	end

	for _, creature in ipairs(Cyclopedia.Bosstiary.NotVisibleCreatures) do
		table.insert(allCreatures, creature)
	end

	for _, creature in ipairs(allCreatures) do
		if id == "BaneCheck" then
			if creature.category == CATEGORY.BANE then
				creature.visible = widget:isChecked()
			end
		elseif id == "ArchfoeCheck" then
			if creature.category == CATEGORY.ARCHFOE then
				creature.visible = widget:isChecked()
			end
		elseif id == "NemesisCheck" then
			if creature.category == CATEGORY.NEMESIS then
				creature.visible = widget:isChecked()
			end
		elseif id == "NoKillsCheck" then
			if creature.kills < 1 then
				creature.visible = widget:isChecked()
			end
		elseif id == "FewKillsCheck" then
			if creature.kills ~= 0 and creature.kills < CONFIG[creature.category].PROWESS then
				creature.visible = widget:isChecked()
			end
		elseif id == "ProwessCheck" then
			if creature.kills ~= 0 and creature.kills >= CONFIG[creature.category].PROWESS and creature.kills <= CONFIG[creature.category].EXPERTISE then
				creature.visible = widget:isChecked()
			end
		elseif id == "ExpertiseCheck" then
			if creature.kills ~= 0 and creature.kills >= CONFIG[creature.category].EXPERTISE and creature.kills <= CONFIG[creature.category].MASTERY then
				creature.visible = widget:isChecked()
			end
		elseif id == "MasteryCheck" and creature.kills ~= 0 and creature.kills >= CONFIG[creature.category].MASTERY then
			creature.visible = widget:isChecked()
		end
	end

	Cyclopedia.ReadjustPages()
end

function Cyclopedia.ReadjustPages()
	local maxCategoriesPerPage = 8
	local allCreatures = {}

	for _, creatures in ipairs(Cyclopedia.Bosstiary.Creatures) do
		for _, creature in ipairs(creatures) do
			table.insert(allCreatures, creature)
		end
	end

	for _, creature in ipairs(Cyclopedia.Bosstiary.NotVisibleCreatures) do
		table.insert(allCreatures, creature)
	end

	table.sort(allCreatures, function(a, b)
		if a.name == "?" and b.name ~= "?" then
			return false
		elseif a.name ~= "?" and b.name == "?" then
			return true
		elseif a.unlocked and not b.unlocked then
			return true
		elseif not a.unlocked and b.unlocked then
			return false
		else
			return a.name < b.name
		end
	end)

	Cyclopedia.Bosstiary.Creatures = {}
	Cyclopedia.Bosstiary.NotVisibleCreatures = {}

	local page = 1

	Cyclopedia.Bosstiary.Creatures[page] = {}

	for i, creature in ipairs(allCreatures) do
		if creature.visible then
			table.insert(Cyclopedia.Bosstiary.Creatures[page], creature)

			if #Cyclopedia.Bosstiary.Creatures[page] == maxCategoriesPerPage then
				page = page + 1
				Cyclopedia.Bosstiary.Creatures[page] = {}
			end
		else
			table.insert(Cyclopedia.Bosstiary.NotVisibleCreatures, creature)
		end
	end

	local totalVisible = 0

	for _, pageCreatures in ipairs(Cyclopedia.Bosstiary.Creatures) do
		totalVisible = totalVisible + #pageCreatures
	end

	Cyclopedia.Bosstiary.TotalPages = math.ceil(totalVisible / maxCategoriesPerPage)

	if Cyclopedia.Bosstiary.Page > Cyclopedia.Bosstiary.TotalPages then
		Cyclopedia.Bosstiary.Page = 1
	end

	UI.PageValue:setText(string.format("%d / %d", Cyclopedia.Bosstiary.Page, Cyclopedia.Bosstiary.TotalPages))
	Cyclopedia.LoadBosstiaryCreature(Cyclopedia.Bosstiary.Page)
	Cyclopedia.verifyBosstiaryButtons()
end
