-- chunkname: @/game_screenshot/game_screenshot.lua

local AUTO_SCREENSHOTS_ENABLED = false
local CLIENT_EVENT_TYPE_SIMPLE = 1
local CLIENT_EVENT_TYPE_ACHIEVEMENT = 2
local CLIENT_EVENT_TYPE_LEVEL = 4
local CLIENT_EVENT_TYPE_SKILL = 5
local CLIENT_EVENT_TYPE_BESTIARY = 6
local CLIENT_EVENT_BOSSDEFEATED = 1
local CLIENT_EVENT_DEATHPVE = 2
local CLIENT_EVENT_DEATHPVP = 3
local CLIENT_EVENT_PLAYERKILLASSIST = 4
local CLIENT_EVENT_PLAYERKILL = 5
local CLIENT_EVENT_PLAYERATTACKING = 6
local CLIENT_EVENT_TREASUREFOUND = 7
local CLIENT_EVENT_GIFTOFLIFE = 8
local AutoScreenshotEvents = {
	{
		enableDefault = true,
		label = "Level Up",
		optionKey = "levelUp"
	},
	{
		enableDefault = true,
		label = "Skill Up",
		optionKey = "skillUp"
	},
	{
		enableDefault = true,
		label = "Achievement",
		optionKey = "achievement"
	},
	{
		enableDefault = false,
		label = "Bestiary Entry Unlocked",
		optionKey = "bestiaryUnlocked"
	},
	{
		enableDefault = false,
		label = "Bestiary Entry Completed",
		optionKey = "bestiaryCompleted"
	},
	{
		enableDefault = false,
		label = "Treasure Found",
		optionKey = "treasureFound"
	},
	{
		enableDefault = false,
		label = "Valuable Loot",
		optionKey = "valuableLoot"
	},
	{
		enableDefault = false,
		label = "Boss Defeated",
		optionKey = "bossDefeated"
	},
	{
		enableDefault = true,
		label = "Death PvE",
		optionKey = "deathPvE"
	},
	{
		enableDefault = false,
		label = "Death PvP",
		optionKey = "deathPvP"
	},
	{
		enableDefault = false,
		label = "Player Kill",
		optionKey = "playerKill"
	},
	{
		enableDefault = false,
		label = "Player Kill Assist",
		optionKey = "playerKillAssist"
	},
	{
		enableDefault = false,
		label = "Player Attacking",
		optionKey = "playerAttacking"
	},
	{
		enableDefault = false,
		label = "Highest Damage Dealt",
		optionKey = "highestDamage"
	},
	{
		enableDefault = false,
		label = "Highest Healing Done",
		optionKey = "highestHealing"
	},
	{
		enableDefault = false,
		label = "Low Health",
		optionKey = "lowHealth"
	},
	{
		enableDefault = true,
		label = "Gift of Life Triggered",
		optionKey = "giftOfLife"
	}
}
local SIMPLE_EVENT_SCREENSHOTS = {
	[CLIENT_EVENT_BOSSDEFEATED] = {
		"bossDefeated",
		"BossDefeated"
	},
	[CLIENT_EVENT_DEATHPVE] = {
		"deathPvE",
		"DeathPvE"
	},
	[CLIENT_EVENT_DEATHPVP] = {
		"deathPvP",
		"DeathPvP"
	},
	[CLIENT_EVENT_PLAYERKILLASSIST] = {
		"playerKillAssist",
		"PlayerKillAssist"
	},
	[CLIENT_EVENT_PLAYERKILL] = {
		"playerKill",
		"PlayerKill"
	},
	[CLIENT_EVENT_PLAYERATTACKING] = {
		"playerAttacking",
		"PlayerAttacking"
	},
	[CLIENT_EVENT_TREASUREFOUND] = {
		"treasureFound",
		"TreasureFound"
	},
	[CLIENT_EVENT_GIFTOFLIFE] = {
		"giftOfLife",
		"GiftOfLifeTriggered"
	}
}
local autoScreenshotDir = "/auto_screenshots"

screenshotController = Controller:new()

local function ensureScreenshotDir()
	if not g_resources.directoryExists(autoScreenshotDir) then
		g_resources.makeDir(autoScreenshotDir)
	end
end

local function getScreenshotDirPath()
	ensureScreenshotDir()

	local writeDir = g_resources.getWriteDir():gsub("[/\\]+$", "")

	return writeDir:gsub("/", "\\") .. "\\auto_screenshots"
end

local function showScreenshotSavedMessage(eventName)
	if not eventName or not modules.game_textmessage or not modules.game_textmessage.displayStatusMessage then
		return
	end

	modules.game_textmessage.displayStatusMessage(tr("Screenshot for event %s has been saved to location '%s'.", eventName, getScreenshotDirPath()))
end

local function getScreenshotOption(key)
	if modules.client_options and modules.client_options.getOption then
		local value = modules.client_options.getOption(key)

		if value ~= nil then
			return value
		end
	end

	return false
end

local function triggerAutoScreenshot(optionKey, labelSuffix)
	if not getScreenshotOption("enableAutoScreenshots") then
		return
	end

	if not getScreenshotOption(optionKey) then
		return
	end

	local player = g_game.getLocalPlayer()

	if not player then
		return
	end

	local name = player:getName() or "player"
	local level = player:getLevel() or 1
	local screenshotName = name .. level .. "_" .. labelSuffix:gsub("%s+", "") .. "_" .. os.date("%Y%m%d%H%M%S") .. ".png"

	takeScreenshot(autoScreenshotDir .. "/" .. screenshotName, labelSuffix)
end

local function onClientEvent(eventType, ...)
	if eventType == CLIENT_EVENT_TYPE_SIMPLE then
		local simpleType = select(1, ...)
		local entry = SIMPLE_EVENT_SCREENSHOTS[simpleType]

		if entry then
			triggerAutoScreenshot(entry[1], entry[2])
		end

		return
	end

	if eventType == CLIENT_EVENT_TYPE_ACHIEVEMENT then
		triggerAutoScreenshot("achievement", "Achievement")

		return
	end

	if eventType == CLIENT_EVENT_TYPE_LEVEL then
		triggerAutoScreenshot("levelUp", "LevelUp")

		return
	end

	if eventType == CLIENT_EVENT_TYPE_SKILL then
		triggerAutoScreenshot("skillUp", "SkillUp")

		return
	end

	if eventType == CLIENT_EVENT_TYPE_BESTIARY then
		local progressLevel = select(2, ...) or 0

		if progressLevel == 0 then
			triggerAutoScreenshot("bestiaryUnlocked", "BestiaryEntryUnlocked")
		elseif progressLevel >= 3 then
			triggerAutoScreenshot("bestiaryCompleted", "BestiaryEntryCompleted")
		end
	end
end

function screenshotController:onInit()
	return
end

function screenshotController:onTerminate()
	AutoScreenshotEvents = {}
end

function screenshotController:onGameStart()
	if g_game.getClientVersion() < 1180 then
		return
	end

	ensureScreenshotDir()
	screenshotController:registerEvents(g_game, {
		onClientEvent = onClientEvent
	})
end

function screenshotController:onGameEnd()
	return
end

function resetValues()
	if not modules.client_options or not modules.client_options.setOption then
		return
	end

	modules.client_options.setOption("enableAutoScreenshots", true, true)
	modules.client_options.setOption("onlyCaptureGameWindow", false, true)
	modules.client_options.setOption("keepBacklog", false, true)

	for _, screenshotEvent in ipairs(AutoScreenshotEvents) do
		modules.client_options.setOption(screenshotEvent.optionKey, screenshotEvent.enableDefault, true)
	end
end

function takeScreenshot(name, eventName)
	if not AUTO_SCREENSHOTS_ENABLED then
		return
	end

	if not g_game.isOnline() then
		return
	end

	ensureScreenshotDir()
	screenshotController:scheduleEvent(function()
		if getScreenshotOption("onlyCaptureGameWindow") then
			g_app.doMapScreenshot(name)
		else
			g_app.doScreenshot(name)
		end

		showScreenshotSavedMessage(eventName)
	end, 50, "screenshotScheduleEvent")
end

function OpenFolder()
	g_platform.openDir(getScreenshotDirPath())
end
