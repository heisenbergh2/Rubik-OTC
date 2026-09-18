-- chunkname: @/corelib/globals.lua

rootWidget = g_ui.getRootWidget()
modules = package.loaded
G = G or {}

local _dbginfo = debug and debug.getinfo
local _nativeAddEvent = g_dispatcher.addEvent
local _nativeScheduleEvent = g_dispatcher.scheduleEvent
local _nativeCycleEvent = g_dispatcher.cycleEvent
local _setNextEventSource = g_dispatcher.setNextEventSource
local _hasNextEventSource = g_dispatcher.hasNextEventSource
local _setActiveEventSource = g_dispatcher.setActiveEventSource
local _skipSourcePatterns = {
	"corelib/globals%.lua",
	"modulelib/controller%.lua"
}
local _genericSourceNames = {
	action = true,
	callback = true
}

local function _isGenericSourceName(name)
	if not name or name == "" then
		return true
	end

	if _genericSourceNames[name] then
		return true
	end

	if name:sub(1, 1) == "(" and name:sub(-1) == ")" then
		return true
	end

	return false
end

local function _hasValidLine(info)
	return info and type(info.currentline) == "number" and info.currentline > 0
end

local function _shouldSkipEventSource(info)
	if not info or not info.short_src then
		return true
	end

	if info.what == "C" then
		return true
	end

	local src = info.short_src

	for _, pattern in ipairs(_skipSourcePatterns) do
		if src:find(pattern) then
			return true
		end
	end

	return false
end

local function _formatEventSource(info)
	if not info or not info.short_src then
		return nil
	end

	local src = info.short_src

	if _hasValidLine(info) then
		if not _isGenericSourceName(info.name) then
			return string.format("%s:%s:%d", src, info.name, info.currentline)
		end

		return string.format("%s:%d", src, info.currentline)
	end

	if not _isGenericSourceName(info.name) then
		return string.format("%s:%s:?", src, info.name)
	end

	return nil
end

local function _captureFunctionSource(fn)
	if not _dbginfo or type(fn) ~= "function" then
		return nil
	end

	local ok, info = pcall(_dbginfo, fn, "Snl")

	if not ok or not info then
		return nil
	end

	return _formatEventSource(info)
end

local function _captureEventSource(startLevel, stopLevel)
	if not _dbginfo then
		return nil
	end

	startLevel = startLevel or 3
	stopLevel = stopLevel or 20

	local fallback

	for level = startLevel, stopLevel do
		local ok, info = pcall(_dbginfo, level, "Snl")

		if not ok or not info then
			break
		end

		if not _shouldSkipEventSource(info) then
			local formatted = _formatEventSource(info)

			if formatted then
				if _hasValidLine(info) then
					return formatted
				end

				fallback = fallback or formatted
			end
		end
	end

	return fallback
end

local function _tagEventSourceIfUnset()
	if not _setNextEventSource then
		return
	end

	if _hasNextEventSource and _hasNextEventSource() then
		return
	end

	_setNextEventSource(_captureEventSource(3, 12) or "?")
end

local function _wrapEventCallback(callback)
	if type(callback) ~= "function" then
		return callback
	end

	return function()
		if _setActiveEventSource then
			_setActiveEventSource(_captureFunctionSource(callback) or _captureEventSource(3, 20) or "")
		end

		local ok, err = pcall(callback)

		if not ok then
			error(err, 0)
		end
	end
end

function scheduleEvent(callback, delay)
	_tagEventSourceIfUnset()

	callback = _wrapEventCallback(callback)

	local event = _nativeScheduleEvent(callback, delay)

	event._callback = callback

	return event
end

function addEvent(callback, front)
	_tagEventSourceIfUnset()

	callback = _wrapEventCallback(callback)

	local event = _nativeAddEvent(callback, front)

	event._callback = callback

	return event
end

function cycleEvent(callback, interval)
	_tagEventSourceIfUnset()

	callback = _wrapEventCallback(callback)

	local event = _nativeCycleEvent(callback, interval)

	event._callback = callback

	return event
end

g_dispatcher.addEvent = addEvent
g_dispatcher.scheduleEvent = scheduleEvent
g_dispatcher.cycleEvent = cycleEvent

function periodicalEvent(eventFunc, conditionFunc, delay, autoRepeatDelay)
	delay = delay or 30
	autoRepeatDelay = autoRepeatDelay or delay

	local func

	function func()
		if conditionFunc and not conditionFunc() then
			func = nil

			return
		end

		eventFunc()
		scheduleEvent(func, delay)
	end

	scheduleEvent(function()
		func()
	end, autoRepeatDelay)
end

function removeEvent(event)
	if event then
		event:cancel()

		event._callback = nil
	end
end

function flushGameSettingsOnLogout()
	if not g_game.isOnline() then
		g_settings.save()
	end
end
