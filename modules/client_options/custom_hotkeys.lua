-- chunkname: @/client_options/custom_hotkeys.lua

local hookedApplyOptions, hookedCancelOptions

function init_custom_hotkeys()
	if not CustomHotkeys or not CustomHotkeys.init then
		g_logger.error("Custom Hotkeys module failed to load")

		return
	end

	local ok, err = pcall(function()
		CustomHotkeys.init()
	end)

	if not ok then
		g_logger.error("Custom Hotkeys init failed: " .. tostring(err))

		return
	end

	if type(applyOptions) ~= "function" or type(cancelOptions) ~= "function" then
		return
	end

	hookedApplyOptions = applyOptions

	function applyOptions()
		if CustomHotkeys.applyPending then
			CustomHotkeys.applyPending()
		end

		hookedApplyOptions()
	end

	hookedCancelOptions = cancelOptions

	function cancelOptions()
		if CustomHotkeys.revertPending then
			CustomHotkeys.revertPending()
		end

		hookedCancelOptions()
	end
end

function terminate_custom_hotkeys()
	if hookedApplyOptions then
		applyOptions = hookedApplyOptions
		hookedApplyOptions = nil
	end

	if hookedCancelOptions then
		cancelOptions = hookedCancelOptions
		hookedCancelOptions = nil
	end

	CustomHotkeys.terminate()
end

function updateCustomHotkeys()
	if CustomHotkeys and CustomHotkeys.refreshPanel then
		CustomHotkeys.refreshPanel()
	end
end

function cancelKeyEditWindow()
	if CustomHotkeys and CustomHotkeys.cancelKeyEditWindow then
		CustomHotkeys.cancelKeyEditWindow()
	end
end
