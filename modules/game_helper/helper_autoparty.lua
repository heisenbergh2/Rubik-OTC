-- chunkname: @/game_helper/helper_autoparty.lua

HelperAutoParty = HelperAutoParty or {}

local ctx
local sendList = {
	"",
	"",
	"",
	""
}
local acceptLeader = ""
local autoPartySettingsWindow, checkEvent
local applyingFields = false
local CHECK_INTERVAL_MS = 1500
local SHIELD_INVITED_YOU = 1
local textMessageCallback

local function widget(id)
	return ctx and ctx.getWidget(id)
end

local function trimString(str)
	if not str then
		return ""
	end

	return (tostring(str):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function isHelperEnabled()
	local checkbox = widget("checkbox")

	return checkbox and checkbox:isChecked() or false
end

local function isAutoPartyEnabled()
	local check = widget("toolsAutoPartyCheckBox")

	return check and check:isChecked() or false
end

local function isAutoAcceptEnabled()
	local check = widget("toolsAutoPartyAcceptCheckBox")

	return check and check:isChecked() or false
end

local function tryAcceptPendingInvite()
	if not isHelperEnabled() or not isAutoAcceptEnabled() then
		return
	end

	local leader = trimString(acceptLeader)

	if leader == "" then
		return
	end

	local localPlayer = g_game.getLocalPlayer()

	if not localPlayer then
		return
	end

	local specs = g_map.getSpectators(localPlayer:getPosition(), false)

	if not specs then
		return
	end

	local leaderLower = leader:lower()

	for _, spec in ipairs(specs) do
		if spec and spec ~= localPlayer and spec.getShield and spec.getName and spec.isPlayer and spec:isPlayer() and spec:getName():lower() == leaderLower and spec:getShield() == SHIELD_INVITED_YOU then
			if g_game.partyJoin then
				g_game.partyJoin(spec:getId())
			end

			break
		end
	end
end

local function onAutoPartyTextMessage(messageMode, message)
	if not isHelperEnabled() or not isAutoAcceptEnabled() then
		return
	end

	if not message or type(message) ~= "string" then
		return
	end

	local msgClean = message:gsub("^%d+:%d+%s+", "")
	local msgLower = msgClean:lower()
	local isInvite = msgLower:find("invited you to") or msgLower:find("convidou você para") or msgLower:find("convidou voce para")

	if not isInvite then
		return
	end

	local leader = trimString(acceptLeader)

	if leader == "" then
		return
	end

	local inviterName = msgClean:match("^%s*(.-)%s+has%s+invited") or msgClean:match("^%s*(.-)%s+convidou")

	if not inviterName or inviterName == "" then
		inviterName = msgClean:match("^%s*([^%s]+)")
	end

	if not inviterName or inviterName == "" then
		return
	end

	inviterName = trimString(inviterName)

	if inviterName:lower() ~= leader:lower() then
		return
	end

	local creature

	pcall(function()
		local localPlayer = g_game.getLocalPlayer()

		if not localPlayer then
			return
		end

		local specs = g_map.getSpectators(localPlayer:getPosition(), false)

		if not specs then
			return
		end

		local nameLower = inviterName:lower()

		for _, spec in ipairs(specs) do
			if spec and spec ~= localPlayer and spec.getName and spec:getName():lower() == nameLower and spec.isPlayer and spec:isPlayer() then
				creature = spec

				break
			end
		end
	end)

	if creature and not creature:isRemoved() and g_game and g_game.partyJoin then
		scheduleEvent(function()
			if creature and not creature:isRemoved() then
				g_game.partyJoin(creature:getId())
			end
		end, 100)
	end
end

local function runCheck()
	if not isHelperEnabled() or not isAutoPartyEnabled() then
		return
	end

	local localPlayer = g_game.getLocalPlayer()

	if not localPlayer then
		return
	end

	local myName = localPlayer:getName():lower()

	for i = 1, 4 do
		local name = trimString(sendList[i])

		if name ~= "" and name:lower() ~= myName then
			local specs = g_map.getSpectators(localPlayer:getPosition(), false)

			if specs then
				for _, creature in ipairs(specs) do
					if creature and creature:isPlayer() and not creature:isLocalPlayer() and creature:getName():lower() == name:lower() then
						local shield = creature:getShield()

						if shield == 0 then
							if g_game.partyInvite then
								g_game.partyInvite(creature:getId())
							end

							return
						end
					end
				end
			end
		end
	end
end

local function startCheckCycle()
	if checkEvent then
		return
	end

	checkEvent = cycleEvent(function()
		local ok, err = pcall(runCheck)

		if not ok and g_logger and g_logger.error then
			g_logger.error("[helper_autoparty] runCheck error: " .. tostring(err))
		end
	end, CHECK_INTERVAL_MS)
end

local function stopCheckCycle()
	if checkEvent then
		removeEvent(checkEvent)

		checkEvent = nil
	end
end

local function closeSettingsWindow()
	if autoPartySettingsWindow and not autoPartySettingsWindow:isDestroyed() then
		autoPartySettingsWindow:destroy()
	end

	autoPartySettingsWindow = nil
end

local function syncFieldsFromWidgets()
	for i = 1, 4 do
		local w = widget("autoPartySend" .. i)

		if w and w.getText then
			sendList[i] = trimString(w:getText() or "")
		end
	end

	local acceptEdit = widget("autoPartyAcceptEdit")

	if acceptEdit and acceptEdit.getText then
		acceptLeader = trimString(acceptEdit:getText() or "")
	end
end

local function applyFieldsToWidgets()
	applyingFields = true

	for i = 1, 4 do
		local w = widget("autoPartySend" .. i)

		if w and w.setText then
			w:setText(sendList[i] or "")
		end
	end

	local acceptEdit = widget("autoPartyAcceptEdit")

	if acceptEdit and acceptEdit.setText then
		acceptEdit:setText(acceptLeader or "")
	end

	applyingFields = false
end

local function hideAllTextEditCursors()
	for i = 1, 4 do
		local w = widget("autoPartySend" .. i)

		if w and w.setCursorVisible then
			w:setCursorVisible(false)
		end
	end

	local acceptEdit = widget("autoPartyAcceptEdit")

	if acceptEdit and acceptEdit.setCursorVisible then
		acceptEdit:setCursorVisible(false)
	end
end

function HelperAutoParty.init(pctx)
	ctx = pctx

	startCheckCycle()

	if registerMessageMode then
		textMessageCallback = onAutoPartyTextMessage

		for mode = 1, 50 do
			registerMessageMode(mode, textMessageCallback)
		end
	end
end

function HelperAutoParty.onShow()
	return
end

function HelperAutoParty.onHide()
	hideAllTextEditCursors()
end

function HelperAutoParty.terminate()
	hideAllTextEditCursors()
	stopCheckCycle()
	closeSettingsWindow()

	if textMessageCallback and unregisterMessageMode then
		for mode = 1, 50 do
			unregisterMessageMode(mode, textMessageCallback)
		end

		textMessageCallback = nil
	end
end

function HelperAutoParty.collectConfig(config)
	config.autoParty = config.autoParty or {}

	if not applyingFields and (not ctx or not ctx.isLoadingConfig or not ctx.isLoadingConfig()) then
		syncFieldsFromWidgets()
	end

	local enableCheck = widget("toolsAutoPartyCheckBox")
	local acceptCheck = widget("toolsAutoPartyAcceptCheckBox")

	config.autoParty.enabled = enableCheck and enableCheck:isChecked() or false
	config.autoParty.acceptEnabled = acceptCheck and acceptCheck:isChecked() or false
	config.autoParty.sendList = {}

	for i = 1, 4 do
		config.autoParty.sendList[i] = sendList[i] or ""
	end

	config.autoParty.acceptLeader = acceptLeader or ""
end

function HelperAutoParty.loadFromConfig(config)
	local data = config.autoParty or {}
	local enableCheck = widget("toolsAutoPartyCheckBox")
	local acceptCheck = widget("toolsAutoPartyAcceptCheckBox")

	if enableCheck then
		enableCheck:setChecked(data.enabled == true)
	end

	if acceptCheck then
		acceptCheck:setChecked(data.acceptEnabled == true)
	end

	for i = 1, 4 do
		sendList[i] = type(data.sendList) == "table" and trimString(data.sendList[i] or "") or ""
	end

	acceptLeader = trimString(data.acceptLeader or "")

	applyFieldsToWidgets()
end

function HelperAutoParty:onEnableChange(checked)
	if ctx and ctx.saveConfig then
		ctx.saveConfig()
	end
end

function HelperAutoParty:onAcceptChange(checked)
	if ctx and ctx.saveConfig then
		ctx.saveConfig()
	end

	if checked then
		scheduleEvent(tryAcceptPendingInvite, 200)
	end
end

function HelperAutoParty.openSettings()
	closeSettingsWindow()

	if modules.game_helper and modules.game_helper.showTab then
		modules.game_helper.showTab("party")
	end

	local first = widget("autoPartySend1")

	if first and first.focus then
		first:focus()
	end
end

function HelperAutoParty.onSettingsTextChange()
	if applyingFields or ctx and ctx.isLoadingConfig and ctx.isLoadingConfig() then
		return
	end

	syncFieldsFromWidgets()

	if ctx and ctx.saveConfig then
		ctx.saveConfig()
	end

	scheduleEvent(tryAcceptPendingInvite, 200)
end

function HelperAutoParty.focusTextEdit(edit)
	hideAllTextEditCursors()

	if edit and edit.setCursorVisible then
		edit:setCursorVisible(true)
	end
end
