-- chunkname: @/client_options/cip_import_mappings.lua

CipImportMappings = {}
CipImportMappings.OPTION_KEYS = {
	keyboardDelayMs = {
		type = "number",
		key = "hotkeyDelay"
	},
	autoChaseEnabled = {
		invert = true,
		key = "autoChaseOff",
		type = "bool"
	},
	actionBarShowBottom1 = {
		type = "bool",
		key = "actionBarShowBottom1"
	},
	actionBarShowBottom2 = {
		type = "bool",
		key = "actionBarShowBottom2"
	},
	actionBarShowBottom3 = {
		type = "bool",
		key = "actionBarShowBottom3"
	},
	actionBarShowLeft1 = {
		type = "bool",
		key = "actionBarShowLeft1"
	},
	actionBarShowLeft2 = {
		type = "bool",
		key = "actionBarShowLeft2"
	},
	actionBarShowLeft3 = {
		type = "bool",
		key = "actionBarShowLeft3"
	},
	actionBarShowRight1 = {
		type = "bool",
		key = "actionBarShowRight1"
	},
	actionBarShowRight2 = {
		type = "bool",
		key = "actionBarShowRight2"
	},
	actionBarShowRight3 = {
		type = "bool",
		key = "actionBarShowRight3"
	},
	actionBarBottomLocked = {
		type = "bool",
		key = "actionBarBottomLocked"
	},
	actionBarLeftLocked = {
		type = "bool",
		key = "actionBarLeftLocked"
	},
	actionBarRightLocked = {
		type = "bool",
		key = "actionBarRightLocked"
	},
	actionButtonShowHotkey = {
		type = "bool",
		key = "showAssignedHKButton"
	},
	actionButtonShowSpellParameters = {
		type = "bool",
		key = "showSpellParameters"
	},
	actionButtonShowAmount = {
		type = "bool",
		key = "showHKObjectsBars"
	},
	actionButtonShowCooldownNumbers = {
		type = "bool",
		key = "showTooltips"
	},
	vsyncEnabled = {
		type = "bool",
		key = "vsync"
	},
	frameRateLimit = {
		requires = "frameRateLimitEnabled",
		key = "backgroundFrameRate",
		type = "number"
	},
	frameRateLimitEnabled = {
		invert = true,
		key = "noFrameRateLimit",
		type = "bool"
	},
	antialiasingMode = {
		type = "number",
		key = "antialiasingMode"
	},
	alwaysTurnTowardsMoveDirection = {
		type = "bool",
		key = "alwaysTurnTowardsMovement"
	},
	creatureShowHealth = {
		type = "bool",
		key = "showOtherHealth"
	},
	creatureShowName = {
		type = "bool",
		key = "showOtherName"
	},
	creatureShowMarks = {
		type = "bool",
		key = "showOtherMarks"
	},
	playerShowHealth = {
		type = "bool",
		key = "showOwnHealth"
	},
	playerShowMana = {
		type = "bool",
		key = "showOwnMana"
	},
	playerShowName = {
		type = "bool",
		key = "showOwnName"
	},
	gameWindowShowOwnSpells = {
		type = "bool",
		key = "showSpells"
	},
	gameWindowShowOthersSpells = {
		type = "bool",
		key = "showSpellsOfOthers"
	},
	gameWindowShowHotkeyUsageMessages = {
		type = "bool",
		key = "showHotkeyUsageNotifications"
	},
	gameWindowShowMessages = {
		type = "bool",
		key = "consoleMessages"
	}
}
CipImportMappings.CONTROL_BUTTON_IDS = {
	compendiumDialog = "compendiumDialog",
	analyticsSelectorWidget = "analyticsSelectorWidget",
	questDialog = "questLogButton",
	bosstiaryDialog = "bosstiary",
	questTrackerWidget = "QuestLogTracker",
	bossslotsDialog = "bossSlot",
	manageShortcuts = "manageShortcuts",
	bosstiaryTrackerWidget = "bosstiarytrackerButton",
	unjustifiedPoinsWidget = "unjustifiedPointsButton",
	skillWheelDialog = "wheelButton",
	vipWidget = "vipListButton",
	partyWidget = "partyWidget",
	rewardWallDialog = "rewardWall",
	battleListWidget = "battleButton",
	taskboard = "taskBoard",
	skillsWidget = "skillsButton",
	weaponProficiency = "ProciencyButton",
	highscoresDialog = "highscoresButton",
	friendsDialog = "friendsDialog",
	exaltationForgeDialog = "forgeButton",
	imbuementTrackerWidget = "imbuementTrackerButton",
	bestiaryTrackerWidget = "trackerButton",
	cyclopediaDialog = "CyclopediaButton",
	preyDialog = "preyButton",
	spellListWidget = "spellListWidget",
	preyWidget = "preyButton"
}
CipImportMappings.USE_TYPE = {
	Use = "use",
	SelectUseTarget = "useWith",
	Equip = "equip",
	UseOnTarget = "useOnTarget",
	UseOnYourself = "useOnSelf"
}
CipImportMappings.USE_TYPE_TO_HOTKEY_ACTION = {
	Equip = HOTKEY_ACTION.EQUIP,
	Use = HOTKEY_ACTION.USE,
	UseOnYourself = HOTKEY_ACTION.USE_YOURSELF,
	UseOnTarget = HOTKEY_ACTION.USE_TARGET,
	SelectUseTarget = HOTKEY_ACTION.USE_CROSSHAIR
}
CipImportMappings.KEYBIND_ACTIONS = {
	AttackNextTarget = {
		"Battle List",
		"Attack Next Target"
	},
	Logout = {
		"Misc",
		"Logout"
	},
	NextChannel = {
		"Chat Channel",
		"Next Channel"
	},
	PreviousChannel = {
		"Chat Channel",
		"Previous Channel"
	},
	OpenChannelList = {
		"Chat Channel",
		"Open Channel List"
	},
	CloseCurrentChannel = {
		"Chat Channel",
		"Close Current Channel"
	},
	OpenHelpChannel = {
		"Chat Channel",
		"Open Help Channel"
	},
	ToggleBattlelist = {
		"Windows",
		"Show/hide battle list"
	},
	ShowQuestlog = {
		"Windows",
		"Show/hide quest Log"
	},
	ShowPrey = {
		"Dialogs",
		"Open Prey Dialog"
	},
	Bugreport = {
		"Dialogs",
		"Open Bug Report"
	},
	QuickLootAreaAtPlayer = {
		"Loot",
		"Quick Loot Nearby Corpses"
	},
	ChatModeTemporaryOn = {
		"Chat Mode",
		"Set to Chat On"
	},
	ToggleManualSortMode = {
		"Containers",
		"Toggle Manual Sort Mode"
	}
}
CipImportMappings.KEY_SEQUENCE_REPLACEMENTS = {
	Return = "Enter",
	Backtab = "BackTab"
}
CipImportMappings.PER_CHARACTER_FILES = {
	"wheelOfDestiny.json",
	"cyclopediaMapConfiguration.json",
	"xpanalyser.json",
	"impactanalyser.json",
	"damageinputanalyser.json",
	"gainandwaste.json",
	"huntingsessionanalyser.json",
	"itemtracking.json",
	"itemprices.json",
	"lootBlackWhitelist.json"
}
CipImportMappings.IGNORED_CHARACTER_FILES = {
	questtracking = true,
	aimattargetconfigurationstorage = true,
	statusBarData = true,
	outfitdialog = true,
	actionbars = true
}
CipImportMappings.SIDEBAR_SKIPPED_TYPES = {
	playerGuide = true,
	container = true
}
CipImportMappings.SIDEBAR_WIDGET_MAP = {
	battleList = {
		primaryInstance = 0,
		widgetId = "battleWindow"
	},
	skills = {
		widgetId = "skillWindow"
	},
	questTracker = {
		widgetId = "QuestLogTracker"
	},
	vip = {
		widgetId = "vipWindow"
	},
	vipList = {
		widgetId = "vipWindow"
	},
	partyList = {
		widgetId = "partyWindow"
	},
	unjustifiedPoints = {
		widgetId = "unjustifiedPointsWindow"
	},
	spellList = {
		widgetId = "spellListMiniWindow"
	},
	helperStats = {
		widgetId = "helperStatsWindow"
	},
	prey = {
		widgetId = "preyTracker"
	},
	imbuementTracker = {
		widgetId = "imbuementTracker"
	},
	bestiaryTracker = {
		widgetId = "BestiaryTrackerWindow"
	},
	bosstiaryTracker = {
		widgetId = "BosstiaryTrackerWindow"
	},
	analyticsSelector = {
		widgetId = "analyserMiniWindow"
	},
	lootAnalyser = {
		widgetId = "lootAnalyserMiniWindow"
	},
	supplyAnalyser = {
		widgetId = "supplyAnalyserMiniWindow"
	},
	impactAnalyser = {
		widgetId = "impactAnalyserMiniWindow"
	},
	damageInputAnalyser = {
		widgetId = "inputAnalyserMiniWindow"
	},
	huntingSessionAnalyser = {
		widgetId = "huntingAnalyserMiniWindow"
	},
	partyHuntAnalyser = {
		widgetId = "phAnalyserMiniWindow"
	},
	xpAnalyser = {
		widgetId = "xpAnalyserMiniWindow"
	}
}
CipImportMappings.SIDEBAR_WIDGET_OPTIONS_KEYS = {
	battleList = {
		section = "battleListsOptions",
		useInstance = true
	},
	skills = {
		section = "skillsWidgetOptions"
	},
	questTracker = {
		section = "questTrackerWidgetOptions"
	},
	vip = {
		section = "vipWidgetOptions"
	},
	partyList = {
		section = "partyWidgetOptions"
	},
	unjustifiedPoints = {
		section = "unjustifiedPointsOptions"
	},
	spellList = {
		section = "spellListWidgetOptions"
	},
	helperStats = {
		section = "helperStatsWidgetOptions"
	},
	prey = {
		section = "preyWidgetOptions"
	},
	imbuementTracker = {
		section = "imbuementTrackerWidgetOptions"
	},
	bestiaryTracker = {
		section = "bestiaryTrackerWidgetOptions"
	},
	bosstiaryTracker = {
		section = "bosstiaryTrackerWidgetOptions"
	},
	analyticsSelector = {
		section = "analyticsSelectorOptions"
	},
	lootAnalyser = {
		section = "lootAnalyserWidgetOptions"
	},
	supplyAnalyser = {
		section = "supplyAnalyserWidgetOptions"
	},
	impactAnalyser = {
		section = "impactAnalyserWidgetOptions"
	},
	damageInputAnalyser = {
		section = "damageInputAnalyserWidgetOptions"
	},
	huntingSessionAnalyser = {
		section = "huntingSessionAnalyserWidgetOptions"
	},
	partyHuntAnalyser = {
		section = "partyHuntAnalyserOptions"
	},
	xpAnalyser = {
		section = "xpAnalyserWidgetOptions"
	}
}

function CipImportMappings.sidebarParentIdForIndex(sidebarIndex)
	sidebarIndex = tonumber(sidebarIndex) or 0

	if sidebarIndex == 0 then
		return "gameRightPanel"
	elseif sidebarIndex == 1 then
		return "gameLeftPanel"
	elseif sidebarIndex == 2 then
		return "gameLeftExtraPanel"
	elseif sidebarIndex == 3 then
		return "gameRightExtraPanel"
	end

	return "gameRightPanel"
end

function CipImportMappings.resolveSidebarWidgetId(widgetType, instance)
	if CipImportMappings.SIDEBAR_SKIPPED_TYPES[widgetType] then
		return nil
	end

	local mapping = CipImportMappings.SIDEBAR_WIDGET_MAP[widgetType]

	if not mapping then
		return nil
	end

	if mapping.primaryInstance ~= nil then
		instance = instance or 0

		if instance ~= mapping.primaryInstance then
			return nil
		end
	end

	return mapping.widgetId
end

function CipImportMappings.widgetSettingsFromSidebarsOptions(sidebars, widgetType, instance)
	local optsKey = CipImportMappings.SIDEBAR_WIDGET_OPTIONS_KEYS[widgetType]

	if not optsKey then
		return {}
	end

	local section = sidebars[optsKey.section]

	if type(section) ~= "table" then
		return {}
	end

	local opts = section

	if optsKey.useInstance then
		opts = section[tostring(instance or 0)]
	end

	if type(opts) ~= "table" then
		return {}
	end

	local settings = {}

	if type(opts.contentHeight) == "number" and opts.contentHeight > 0 then
		settings.height = opts.contentHeight
	end

	if opts.contentMaximized == false then
		settings.minimized = true
	elseif opts.contentMaximized == true then
		settings.minimized = false
	end

	return settings
end

function CipImportMappings.convertSidebarsToCharMiniWindows(sidebars)
	if type(sidebars) ~= "table" then
		return nil
	end

	local manager = sidebars.sidebarWidgetsMangerOptions

	if type(manager) ~= "table" then
		return nil
	end

	local orderPerSidebar = manager.openWidgetsOrderPerSidebar

	if type(orderPerSidebar) ~= "table" then
		return nil
	end

	local result = {}

	for sidebarIndex, widgetList in ipairs(orderPerSidebar) do
		if type(widgetList) == "table" then
			local parentId = CipImportMappings.sidebarParentIdForIndex(sidebarIndex - 1)
			local slotIndex = 0

			for _, widget in ipairs(widgetList) do
				if type(widget) == "table" and type(widget.type) == "string" then
					local widgetType = widget.type
					local instance = widget.instance
					local widgetId = CipImportMappings.resolveSidebarWidgetId(widgetType, instance)

					if widgetId and not result[widgetId] then
						slotIndex = slotIndex + 1

						local settings = CipImportMappings.widgetSettingsFromSidebarsOptions(sidebars, widgetType, instance)

						settings.parentId = parentId
						settings.index = slotIndex
						settings.closed = false
						result[widgetId] = settings
					end
				end
			end
		end
	end

	if table.empty(result) then
		return nil
	end

	return result
end

function CipImportMappings.normalizeKeySequence(keysequence)
	if type(keysequence) ~= "string" or keysequence == "" then
		return nil
	end

	local key = CipImportMappings.KEY_SEQUENCE_REPLACEMENTS[keysequence] or keysequence

	return key
end

function CipImportMappings.isValidKeyCombo(key)
	if type(key) ~= "string" or key == "" then
		return false
	end

	key = CipImportMappings.normalizeKeySequence(key)

	if not key or key == "" then
		return false
	end

	if not retranslateKeyComboDesc then
		return true
	end

	local ok, translated = pcall(retranslateKeyComboDesc, key)

	return ok and translated ~= nil and translated ~= ""
end

function CipImportMappings.slotIdFor(barId, buttonIndex)
	barId = tonumber(barId)
	buttonIndex = tonumber(buttonIndex)

	if not barId or not buttonIndex or barId < 1 or barId > 9 or buttonIndex < 1 then
		return nil
	end

	if barId == 1 then
		return "slot" .. buttonIndex
	end

	return "bar" .. barId .. "_slot" .. buttonIndex
end

function CipImportMappings.parseTriggerActionButton(actionName)
	if type(actionName) ~= "string" then
		return nil, nil
	end

	local barId, buttonIndex = actionName:match("^TriggerActionButton_(%d+)%.(%d+)$")

	return barId, buttonIndex
end

function CipImportMappings.isValidItemId(itemId)
	if type(itemId) ~= "number" or itemId <= 0 then
		return false
	end

	if not g_things or not g_things.getThingType then
		return true
	end

	local thingType = g_things.getThingType(itemId, ThingCategoryItem)

	return thingType ~= nil
end

function CipImportMappings.convertActionSettingToSlot(setting)
	if type(setting) ~= "table" then
		return nil
	end

	if setting.chatText and setting.chatText ~= "" then
		local text = setting.chatText
		local words = text:lower():gsub("^%s+", ""):gsub("%s+$", "")

		if Spells and Spells.getSpellByWords and Spells.getSpellByWords(words) then
			local slot = {
				words = words
			}

			if setting.sendAutomatically then
				slot.autoSend = true
			end

			return slot
		end

		local slot = {
			text = text
		}

		if setting.sendAutomatically then
			slot.autoSend = true
		end

		return slot
	end

	if setting.useObject then
		if not CipImportMappings.isValidItemId(setting.useObject) then
			return nil
		end

		local slot = {
			itemId = setting.useObject,
			useType = CipImportMappings.USE_TYPE[setting.useType] or "use"
		}

		if type(setting.upgradeTier) == "number" and setting.upgradeTier > 0 then
			slot.getTier = setting.upgradeTier
		end

		if setting.useEquipSmartMode then
			slot.smartMode = true
		end

		return slot
	end

	return nil
end

function CipImportMappings.convertActionSettingToHotkey(setting)
	if type(setting) ~= "table" then
		return nil, nil
	end

	if setting.chatText and setting.chatText ~= "" then
		local action = setting.sendAutomatically and HOTKEY_ACTION.TEXT_AUTO or HOTKEY_ACTION.TEXT

		return action, {
			text = setting.chatText
		}
	end

	if setting.useObject then
		if not CipImportMappings.isValidItemId(setting.useObject) then
			return nil, nil
		end

		local action = CipImportMappings.USE_TYPE_TO_HOTKEY_ACTION[setting.useType] or HOTKEY_ACTION.USE

		return action, {
			itemId = setting.useObject
		}
	end

	if setting.action then
		local mapping = CipImportMappings.KEYBIND_ACTIONS[setting.action]

		if mapping then
			return "keybind", mapping
		end
	end

	return nil, nil
end

CipImportMappings.BRIDGE_CHARACTER_FILES = {
	"questtracking.json",
	"outfitdialog.json"
}
CipImportMappings.OTCLIENT_PRESERVED_SETTINGS = {
	"game_helper_data.json",
	"outfit.json",
	"questtracking.json",
	"npc_modal.json"
}

function CipImportMappings.convertQuestTrackingToOtClient(cipData, charNameLower)
	if type(cipData) ~= "table" then
		return nil
	end

	local result = {}

	if type(cipData.options) == "table" then
		if cipData.options.autoTrackNewQuests ~= nil then
			result.autoTrackNewQuests = cipData.options.autoTrackNewQuests
		end

		if cipData.options.autoUntrackCompletedQuests ~= nil then
			result.autoUntrackCompleted = cipData.options.autoUntrackCompletedQuests
		end
	end

	if charNameLower and charNameLower ~= "" and type(cipData.trackedQuests) == "table" then
		local tracked = {}

		for _, entry in ipairs(cipData.trackedQuests) do
			if type(entry) == "table" then
				local missionId = entry.missionId or entry.mission or entry.id
				local questId = entry.questId or entry.quest or entry.questLineId
				local missionName = entry.missionName or entry.name or entry.title or ""
				local missionDesc = entry.missionDescription or entry.description or missionName

				if missionId then
					table.insert(tracked, {
						tonumber(missionId),
						tostring(missionName),
						tostring(missionDesc),
						questId and tonumber(questId) or nil
					})
				end
			end
		end

		if #tracked > 0 then
			result[charNameLower] = tracked
		end
	end

	if table.empty(result) then
		return nil
	end

	return result
end

function CipImportMappings.convertOutfitDialogToOtClient(cipData)
	if type(cipData) ~= "table" then
		return nil
	end

	local presets = cipData.customiseCharacterPresets

	if type(presets) ~= "table" or #presets == 0 then
		return nil
	end

	local convertedPresets = {}

	for index, preset in ipairs(presets) do
		if type(preset) == "table" and not table.empty(preset) then
			convertedPresets[index] = preset
		end
	end

	if #convertedPresets == 0 then
		return nil
	end

	return {
		cipImportedPresets = convertedPresets,
		configureShowOffSocketPresets = cipData.configureShowOffSocketPresets
	}
end
