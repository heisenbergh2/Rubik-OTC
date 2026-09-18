-- Exercise the real loading-screen lifecycle without a renderer or server.
local events, callbacks, messages = {}, {}, {}
local now, online, ready, hidden, closed = 0, false, false, false, 0
local background = {
  setImageSource = function() end, lower = function() end,
  show = function() hidden = false end,
  hide = function() hidden = true end,
  destroy = function() end
}
local panel = { isDestroyed = function() return false end,
  isReadyToDisplay = function() return ready end }
local env = setmetatable({
  g_clock = { realMillis = function() return now end },
  g_game = { isOnline = function() return online end },
  g_ui = { displayUI = function() return background end },
  g_logger = { info = function(s) messages[#messages + 1] = s end,
    warning = function(s) messages[#messages + 1] = s end },
  g_modules = { getModule = function() return nil end },
  modules = { game_interface = { getMapPanel = function() return panel end } },
  CharacterList = { destroyLoadBox = function() closed = closed + 1 end },
  connect = function(_, handlers) for k, v in pairs(handlers) do callbacks[k] = v end end,
  disconnect = function(_, handlers) for k in pairs(handlers) do callbacks[k] = nil end end,
  scheduleEvent = function(fn) local event = { fn = fn }; events[#events + 1] = event; return event end,
  removeEvent = function(event) event.cancelled = true end
}, { __index = _G })
local file = assert(io.open('modules/client_background/background.lua', 'rb'))
local source = file:read('*a'):gsub('^\239\187\191', '')
file:close()
local chunk = assert(loadstring(source, '@modules/client_background/background.lua'))
setfenv(chunk, env)()
local function poll()
  local event = table.remove(events, 1)
  assert(event and not event.cancelled)
  event.fn()
end
env.init()
online = true
callbacks.onGameStart()
poll()
assert(not hidden and closed == 0, 'loading curtain must wait for actual map frames')
ready = true
now = 100
poll()
assert(hidden and closed == 1, 'ready map must release the connecting modal')
ready = false
callbacks.onGameStart()
now = 10100
poll()
assert(hidden and closed == 2, 'map timeout must release the connecting modal')
assert(table.concat(messages, '\n'):find('timeout=true', 1, true))
callbacks.onGameStart()
env.terminate()
assert(events[#events].cancelled, 'termination must cancel readiness polling')
assert(not callbacks.onGameStart)
print('Login transition tests passed')
