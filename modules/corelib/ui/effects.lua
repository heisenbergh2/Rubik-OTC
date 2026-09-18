-- chunkname: @/corelib/ui/effects.lua

g_effects = {}

function g_effects.fadeIn(widget, time, elapsed)
	elapsed = elapsed or 0
	time = time or 300

	widget:setOpacity(math.min(elapsed / time, 1))
	removeEvent(widget.fadeEvent)

	if elapsed < time then
		removeEvent(widget.fadeEvent)

		widget.fadeEvent = scheduleEvent(function()
			g_effects.fadeIn(widget, time, elapsed + 30)
		end, 30)
	else
		widget.fadeEvent = nil
	end
end

function g_effects.fadeOut(widget, time, elapsed)
	elapsed = elapsed or 0
	time = time or 300
	elapsed = math.max((1 - widget:getOpacity()) * time, elapsed)

	removeEvent(widget.fadeEvent)
	widget:setOpacity(math.max((time - elapsed) / time, 0))

	if elapsed < time then
		widget.fadeEvent = scheduleEvent(function()
			g_effects.fadeOut(widget, time, elapsed + 30)
		end, 30)
	else
		widget.fadeEvent = nil
	end
end

function g_effects.cancelFade(widget)
	removeEvent(widget.fadeEvent)

	widget.fadeEvent = nil
end

function g_effects.startBlink(widget, duration, interval, clickCancel)
	duration = duration or 0
	interval = interval or 500
	clickCancel = clickCancel or true

	removeEvent(widget.blinkEvent)
	removeEvent(widget.blinkStopEvent)

	widget.blinkEvent = cycleEvent(function()
		widget:setOn(not widget:isOn())
	end, interval)

	if duration > 0 then
		widget.blinkStopEvent = scheduleEvent(function()
			g_effects.stopBlink(widget)
		end, duration)
	end

	connect(widget, {
		onClick = g_effects.stopBlink
	})
end

function g_effects.stopBlink(widget)
	disconnect(widget, {
		onClick = g_effects.stopBlink
	})
	removeEvent(widget.blinkEvent)
	removeEvent(widget.blinkStopEvent)

	widget.blinkEvent = nil
	widget.blinkStopEvent = nil

	widget:setOn(false)
end
