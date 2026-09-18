-- chunkname: @/client_styles/styles.lua

local resourceLoaders = {
	otui = g_ui.importStyle,
	otfont = g_fonts.importFont,
	otps = g_particles.importParticle
}

function init()
	local device = g_platform.getDevice()

	importResources("fonts", "otfont", device)
	importResources("styles", "otui", device)
	importResources("particles", "otps", device)
	g_mouse.loadCursors("/cursors/cursors")
	g_gameConfig.loadFonts()
end

function terminate()
	return
end

function importResources(dir, type, device)
	local path = "/" .. dir .. "/"
	local files = g_resources.listDirectoryFiles(path)

	if not files then
		return {}
	end

	local sorted = {}

	for _, file in pairs(files) do
		sorted[#sorted + 1] = file
	end

	table.sort(sorted)

	for _, file in ipairs(sorted) do
		if g_resources.isFileType(file, type) then
			resourceLoaders[type](path .. file)
		end
	end

	if device then
		local devicePath = g_platform.getDeviceShortName(device.type)

		if devicePath ~= "" then
			table.insertall(files, importResources(dir .. "/" .. devicePath, type))
		end

		local osPath = g_platform.getOsShortName(device.os)

		if osPath ~= "" then
			table.insertall(files, importResources(dir .. "/" .. osPath, type))
		end

		return
	end

	return files
end

function reloadParticles()
	g_particles.terminate()

	local device = g_platform.getDevice()

	importResources("particles", "otps", device)
end
