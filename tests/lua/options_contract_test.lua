local function read(path)
  local file = assert(io.open(path, 'rb'))
  local contents = file:read('*a')
  file:close()
  return contents:gsub('^\239\187\191', '')
end

local dataOptionsChunk = assert(loadstring(read('modules/client_options/data_options.lua'),
  '@modules/client_options/data_options.lua'))
local options = dataOptionsChunk()
assert(type(options.showAnimatedMouseCursor) == 'table', 'animated cursor option is missing')
assert(options.showAnimatedMouseCursor.value == true, 'animated cursor should default to enabled')
assert(options.showAnimatedMouseCursor.deferAction == true, 'cursor changes must follow Apply/Cancel semantics')
assert(type(options.hdGraphics) == 'table', 'xBRZ option is missing')
assert(options.hdGraphics.value == false, 'xBRZ should remain opt-in')
assert(options.hdGraphics.deferAction == true, 'xBRZ changes must follow Apply/Cancel semantics')

local spriteScale
g_sprites = {
  setScaleFactor = function(value) spriteScale = value end,
}
options.hdGraphics.action(true, options, nil, nil)
assert(spriteScale == 2, 'enabling xBRZ must request 2x sprite textures')
options.hdGraphics.action(false, options, nil, nil)
assert(spriteScale == 1, 'disabling xBRZ must restore native sprite textures')
g_sprites = nil

local cursorAnimations
options.showAnimatedMouseCursor.action(false, options, nil, {
  gameMapPanel = {
    setCursorAnimations = function(_, value) cursorAnimations = value end,
  },
})
assert(cursorAnimations == false, 'animated cursor action did not reach the map view')

assert(loadstring(read('modules/client_options/options.lua'), '@modules/client_options/options.lua'),
  'options.lua has invalid Lua 5.1 syntax')

local interface = read('modules/client_options/styles/interface/interface.otui')
local animatedBlock = assert(interface:match('id: showAnimatedMouseCursor(.-)id: animatedMouseCursorHelp'),
  'animated cursor widget is missing')
assert(not animatedBlock:match('enabled:%s*false'), 'animated cursor widget is still disabled')

local config = read('config.ini')
for _, key in ipairs({ 'widget', 'static%-text', 'animated%-text', 'creature%-text', 'item%-count' }) do
  assert(config:match('\n%s*' .. key .. '%s*='), 'active font setting is missing: ' .. key)
end

for _, fontPath in ipairs({
  'assets/fonts/verdana-8px-outline.otfont',
  'assets/fonts/verdana-8px-rounded.otfont',
}) do
  local font = read(fontPath)
  assert(font:match('\n%s*height:%s*11%s*\n'), fontPath .. ' height exceeds its atlas cell')
  assert(font:match('\n%s*glyph%-size:%s*12%s+11%s*\n'), fontPath .. ' glyph grid does not match its PNG atlas')
end

local oldVersionDirectory = io.open('assets/things/1530/assets.json.sha256', 'rb')
assert(not oldVersionDirectory, 'version-specific asset identifier should not be shipped')
local sharedIdentifier = assert(io.open('assets/things/assets.json.sha256', 'rb'),
  'shared asset identifier is missing')
sharedIdentifier:close()

local cyclopedia = read('modules/game_cyclopedia/game_cyclopedia.lua')
local cyclopediaUi = read('modules/game_cyclopedia/game_cyclopedia.otui')
local eagerUi = cyclopedia:find('controllerCyclopedia:setUI("game_cyclopedia")', 1, true)
local onInit = cyclopedia:find('function controllerCyclopedia:onInit()', 1, true)
assert(eagerUi and onInit and eagerUi > onInit,
  'Cyclopedia window path must be registered after the eager Controller init phase')
assert(cyclopedia:find('not ensureCyclopediaWindow()', 1, true),
  'Cyclopedia window is not loaded on first use')
assert(cyclopedia:find('Window loaded on demand in %d ms%s', 1, true),
  'Cyclopedia lazy window load is not measurable')
assert(not cyclopediaUi:find('@onEscape: toggle()', 1, true),
  'Cyclopedia Escape callback must not resolve another module global')
assert(not cyclopediaUi:find('@onClick: SelectWindow', 1, true),
  'Cyclopedia tab callbacks must use the sandbox module namespace')
assert(cyclopediaUi:find('@onEscape: modules.game_cyclopedia.toggle()', 1, true),
  'Cyclopedia Escape callback must be explicitly namespaced')

local helperModule = read('modules/game_helper/game_helper.otmod')
assert(not helperModule:find('%-%s*game_cyclopedia'),
  'game_helper must not force-load the optional Cyclopedia module')
assert(helperModule:find('helper_healer', 1, true) and helperModule:find('game_helper', 1, true),
  'game_helper must load the modular implementation')
assert(not helperModule:find('helper, knight', 1, true),
  'game_helper must not load the legacy monolithic implementation')

print('Options and packaging contract checks passed')
