-- chunkname: @/game_analysers/menus/AnalyserSession.lua

if not AnalyserSession then
	AnalyserSession = {
		startUnix = 0,
		startMs = 0
	}
	AnalyserSession.__index = AnalyserSession
end

local SESSION_STABILIZE_TIME = 900000
local SESSION_STABILIZE_FACTOR = 0.485

function AnalyserSession:reset()
	self.startMs = g_clock.millis()
	self.startUnix = os.time()
end

function AnalyserSession:isActive()
	return self.startMs > 0 and self.startUnix > 0
end

function AnalyserSession:elapsedMs()
	if self.startMs <= 0 then
		return 0
	end

	return math.max(1, g_clock.millis() - self.startMs)
end

function AnalyserSession:durationSeconds()
	if self.startUnix <= 0 then
		return 0
	end

	return math.max(0, os.time() - self.startUnix)
end

function AnalyserSession:perHourFromTotal(total)
	local amount = tonumber(total) or 0

	if amount <= 0 then
		return 0
	end

	if not self:isActive() then
		return 0
	end

	local elapsed = self:elapsedMs()

	if elapsed <= 0 then
		return 0
	end

	local usedElapsed = elapsed

	if elapsed < SESSION_STABILIZE_TIME then
		usedElapsed = elapsed + (SESSION_STABILIZE_TIME - elapsed) * SESSION_STABILIZE_FACTOR
	end

	return math.floor(amount * 3600000 / usedElapsed)
end
