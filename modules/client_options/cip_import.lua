-- chunkname: @/client_options/cip_import.lua

CipImport = CipImport or {}

local pendingConverted, confirmWindow

local function clearPending()
	pendingConverted = nil
end

local function closeConfirmWindow()
	if confirmWindow and not confirmWindow:isDestroyed() then
		confirmWindow:destroy()
	end

	confirmWindow = nil
end

local function restartClientAfterImport()
	if controller and controller.scheduleEvent then
		controller:scheduleEvent(function()
			g_app.restart()
		end, 1000)
	else
		scheduleEvent(function()
			g_app.restart()
		end, 1000)
	end
end

local function applyImport()
	if not pendingConverted then
		return
	end

	local converted = pendingConverted

	clearPending()
	closeConfirmWindow()

	local ok, message = CipImportApplier.apply(converted)

	if ok then
		displayInfoBox(tr("Import CIP Options"), message)
		restartClientAfterImport()
	else
		displayErrorBox(tr("Import CIP Options"), message or tr("Import failed."))
	end
end

local function cancelImport()
	clearPending()
	closeConfirmWindow()
end

local function showImportConfirmation(converted, stats)
	clearPending()

	pendingConverted = converted

	local preview = CipImportConverter.buildPreviewText(converted, stats)

	confirmWindow = displayGeneralBox(tr("Import CIP Options"), preview, {
		{
			text = tr("Import"),
			callback = applyImport
		},
		{
			text = tr("Cancel"),
			callback = cancelImport
		}
	})
end

local function isValidImportPath(path)
	if path:lower():match("%.zip$") then
		return true
	end

	if g_platform.isDirectory and g_platform.isDirectory(path) then
		return true
	end

	return false
end

local function processSelectedPath(path)
	if not path or path == "" then
		return
	end

	path = path:gsub("\\", "/"):gsub("/+$", "")

	if not isValidImportPath(path) then
		displayErrorBox(tr("Import CIP Options"), tr("Select a .zip backup file or a folder containing conf/clientoptions.json."))

		return
	end

	local backup, err = CipImportReader.open(path)

	if not backup then
		displayErrorBox(tr("Import CIP Options"), tr("Failed to read backup: %s", tostring(err)))

		return
	end

	local converted, stats = CipImportConverter.convertBackup(backup)

	if not converted then
		displayErrorBox(tr("Import CIP Options"), tr("No compatible settings found in the selected backup."))

		return
	end

	showImportConfirmation(converted, stats)
end

function onCipImportFileSelected(path)
	processSelectedPath(path)
end

CipImport.onFileSelected = onCipImportFileSelected

function openCipImportDialog()
	if g_platform.openFileDialogAsync then
		g_platform.openFileDialogAsync(tr("Select import file..."), "zip")

		return
	end

	if not g_platform.openFileDialog then
		displayErrorBox(tr("Import CIP Options"), tr("File picker is not available. Rebuild the client with the latest changes."))

		return
	end

	processSelectedPath(g_platform.openFileDialog(tr("Select import file..."), "zip"))
end

function closeCipImportDialog()
	clearPending()
	closeConfirmWindow()
end

function browseCipImportFile()
	openCipImportDialog()
end

function browseCipImportFolder()
	openCipImportDialog()
end

function previewCipImport()
	openCipImportDialog()
end

function confirmCipImport()
	if pendingConverted then
		applyImport()
	end
end

if g_game then
	connect(g_game, {
		onGameStart = function()
			local player = g_game.getLocalPlayer()

			if player then
				g_logger.info(string.format("[login] player id=%s name=%s", tostring(player:getId()), g_game.getCharacterName() or "?"))
			end

			if CipImportApplier then
				if CipImportApplier.applyPendingSidebars then
					CipImportApplier.applyPendingSidebars()
				end

				if CipImportApplier.applyPendingActionBar then
					CipImportApplier.applyPendingActionBar()
				end

				if CipImportApplier.applyClientJsonBridgeOnLogin then
					CipImportApplier.applyClientJsonBridgeOnLogin()
				end
			end
		end
	}, true)
end
