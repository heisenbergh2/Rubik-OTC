-- chunkname: @/mods/client_profiles/profiles.lua

local settings = {}

ChangedProfile = false

function init()
	connect(g_game, {
		onGameStart = online,
		onGameEnd = offline
	})
end

function terminate()
	disconnect(g_game, {
		onGameStart = online,
		onGameEnd = offline
	})
end

function online()
	ChangedProfile = false

	local index = getProfileFromStartupArgument()

	if index then
		setProfileOption(index)
	end

	load()

	if not index then
		setProfileOption(getProfileFromSettings() or 1)
	end

	if not g_resources.directoryExists("/settings/") then
		g_resources.makeDir("/settings/")
	end

	for i = 1, 10 do
		local path = "/settings/profile_" .. i

		if not g_resources.directoryExists(path) then
			g_resources.makeDir(path)
		end
	end
end

function setProfileOption(index)
	local currentProfile = g_settings.getNumber("profile")

	currentProfile = tostring(currentProfile)
	index = tostring(index)

	if currentProfile ~= index then
		ChangedProfile = true

		return modules.client_options.setOption("profile", index)
	end
end

function getProfileFromSettings()
	if not g_game.isOnline() then
		return
	end

	local index = g_game.getCharacterName()
	local savedData = settings[index]

	return savedData
end

function getProfileFromStartupArgument()
	local startupOptions = string.split(g_app.getStartupOptions(), " ")

	if #startupOptions < 2 then
		return false
	end

	for index, option in ipairs(startupOptions) do
		if option == "--profile" then
			local profileIndex = startupOptions[index + 1]

			if profileIndex == nil then
				return g_logger.info("Startup arguments incomplete: missing profile index.")
			end

			g_logger.info("Startup options: Forced profile: " .. profileIndex)

			return profileIndex
		end
	end

	return false
end

function getSettingsFilePath(fileNameWithFormat)
	local currentProfile = g_settings.getNumber("profile")

	return "/settings/profile_" .. currentProfile .. "/" .. fileNameWithFormat
end

function offline()
	onProfileChange(true)
end

function onProfileChange(offline)
	if not offline then
		if not g_game.isOnline() then
			return
		end

		scheduleEvent(collectiveReload, 100)
	end

	local currentProfile = g_settings.getNumber("profile")
	local index = g_game.getCharacterName()

	if index then
		settings[index] = currentProfile

		save()
	end
end

function collectiveReload()
	modules.game_topbar.refresh(true)
	modules.game_actionbar.refresh(true)
end

function load()
	local file = "/settings/profiles.json"

	if g_resources.fileExists(file) then
		local status, result = pcall(function()
			return json.decode(g_resources.readFileContents(file))
		end)

		if not status then
			return g_logger.warning("Error while reading profiles file. To fix this problem you can delete storage.json. Details: " .. result)
		end

		settings = result
	end
end

function save()
	local file = "/settings/profiles.json"
	local status, result = pcall(function()
		return json.encode(settings, 2)
	end)

	if not status then
		return g_logger.warning("Error while saving profile settings. Data won't be saved. Details: " .. result)
	end

	if result:len() > 104857600 then
		return g_logger.warning("Something went wrong, file is above 100MB, won't be saved")
	end

	g_resources.writeFileContents(file, result)
end
