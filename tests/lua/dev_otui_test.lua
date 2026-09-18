-- Headless adapter for the upstream editor's parser and edit-safety self-test.
-- This does not replace exercising the renderer and file writes in the client.
local function loadScript(path)
  local file = assert(io.open(path, 'rb'))
  local source = file:read('*a')
  file:close()
  source = source:gsub('^\239\187\191', '')
  return assert(loadstring(source, '@' .. path))()
end
loadScript('modules/corelib/string.lua')
loadScript('modules/dev_otui/otml.lua')

local statusText = ''
local label = {
  setText = function(_, text) statusText = text end,
  getText = function() return statusText end,
  setColor = function() end,
  setTooltip = function() end,
}
g_ui = { displayUI = function()
  return { hide = function() end, recursiveGetChildById = function() return label end }
end }
g_settings = { getString = function() return '' end }
g_logger = { warning = function() end }
g_resources = { readFileContents = function(path) error('Missing fixture: ' .. path) end }
modules = { client_topmenu = { addTopRightToggleButton = function()
  return { setOn = function() end }
end } }
Keybind = { new = function() end, bind = function() end }
tr = function(text) return text end

loadScript('modules/dev_otui/dev_otui.lua')
init()
assert(selfTest(), 'OTUI editor self-test failed')

-- Closing, loading, reloading, and file watching must not silently discard
-- edits that only exist in the live preview/property panel.
local editorFile = assert(io.open('modules/dev_otui/dev_otui.lua', 'rb'))
local editorSource = editorFile:read('*a')
editorFile:close()
assert(editorSource:find('local function hasPendingEdits()', 1, true),
  'OTUI editor has no pending-edit detector')
assert(editorSource:find("displayGeneralBox('Discard preview changes?'", 1, true),
  'OTUI editor has no discard confirmation')
assert(editorSource:find('The file changed on disk while preview edits are pending.', 1, true),
  'OTUI auto-reload may silently discard preview edits')

-- Preserve CRLF, comments, multiline callbacks, and a missing final newline.
for _, eol in ipairs({ '\n', '\r\n' }) do
  for _, trailing in ipairs({ '', eol }) do
    local fixture = table.concat({
      '# keep comment', 'MainWindow', '  @onClick: |',
      '    local x = "value: text"', '    print(x)',
      '  Button', '    id: ok', '    text: OK',
    }, eol) .. trailing
    assert(Otml.serialize(Otml.parse(fixture)) == fixture, 'OTML round-trip changed bytes')
  end
end
print('OTUI editor headless checks passed')
