-- chunkname: @/gamelib/textmessages.lua

local messageModeCallbacks = {}

function registerMessageMode(messageMode, callback)
	if not messageModeCallbacks[messageMode] then
		messageModeCallbacks[messageMode] = {}
	end

	table.insert(messageModeCallbacks[messageMode], callback)

	return true
end

function unregisterMessageMode(messageMode, callback)
	if not messageModeCallbacks[messageMode] then
		return false
	end

	return table.removevalue(messageModeCallbacks[messageMode], callback)
end

function g_textMessageForward(messageMode, message, channelId)
	if modules.game_textmessage and modules.game_textmessage.displayMessage then
		modules.game_textmessage.displayMessage(messageMode, message, channelId)

		return
	end

	if modules.game_console and modules.game_console.addText then
		modules.game_console.addText(message, {
			color = TextColors.lightblue
		}, tr("Server Log"))
	end
end

local earlyMessageModes = {
	MessageModes.Login,
	MessageModes.Game,
	MessageModes.Look,
	MessageModes.BoostedCreature
}

for _, mode in ipairs(earlyMessageModes) do
	registerMessageMode(mode, g_textMessageForward)
end

function g_game.onTextMessage(messageMode, message, channelId)
	local callbacks = messageModeCallbacks[messageMode]

	if not callbacks or #callbacks == 0 then
		g_textMessageForward(messageMode, message, channelId)

		return
	end

	for _, callback in pairs(callbacks) do
		callback(messageMode, message, channelId)
	end
end
