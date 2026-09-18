-- chunkname: @/client_options/cip_import_reader.lua

CipImportReader = {}

local function normalizePath(path)
	if type(path) ~= "string" then
		return nil
	end

	path = path:gsub("\\", "/"):gsub("/+$", "")

	if path == "" then
		return nil
	end

	return path
end

local function joinPath(base, child)
	base = normalizePath(base)
	child = tostring(child or ""):gsub("\\", "/")
	child = child:gsub("^/+", "")

	if not base or base == "" then
		return child
	end

	if child == "" then
		return base
	end

	return base .. "/" .. child
end

local function pathEndsWithZip(path)
	return type(path) == "string" and path:lower():match("%.zip$") ~= nil
end

local function readJsonFile(path)
	if not g_platform.fileExists(path) then
		return nil, "file not found"
	end

	local contents = g_platform.readLocalFile(path)

	if not contents or contents == "" then
		return nil, "empty file"
	end

	local ok, data = pcall(function()
		return json.decode(contents)
	end)

	if not ok or type(data) ~= "table" then
		return nil, "invalid json"
	end

	return data
end

function CipImportReader.resolveRoot(sourcePath)
	sourcePath = normalizePath(sourcePath)

	if not sourcePath then
		return nil, "invalid path"
	end

	local root = sourcePath
	local tempDir

	if pathEndsWithZip(sourcePath) then
		if not g_platform.fileExists(sourcePath) then
			return nil, "zip file not found"
		end

		tempDir = joinPath(g_platform.getTempPath(), "otc-cip-import-" .. tostring(os.time()))

		if not g_platform.extractZip(sourcePath, tempDir) then
			return nil, "failed to extract zip"
		end

		root = tempDir
	elseif not g_platform.isDirectory(sourcePath) then
		return nil, "path is not a directory or zip file"
	end

	local confPath = joinPath(root, "conf/clientoptions.json")

	if not g_platform.fileExists(confPath) then
		local entries = g_platform.listLocalDirectory(root, false)

		for _, entry in ipairs(entries or {}) do
			local name = entry:match("([^/]+)$")

			if name and g_platform.isDirectory(entry) then
				local nestedConf = joinPath(entry, "conf/clientoptions.json")

				if g_platform.fileExists(nestedConf) then
					root = entry
					confPath = nestedConf

					break
				end
			end
		end
	end

	if not g_platform.fileExists(confPath) then
		return nil, "conf/clientoptions.json not found"
	end

	return {
		root = root,
		confPath = confPath,
		tempDir = tempDir
	}
end

function CipImportReader.listCharacterIds(root)
	local ids = {}
	local charRoot = joinPath(root, "characterdata")

	if not g_platform.isDirectory(charRoot) then
		return ids
	end

	local entries = g_platform.listLocalDirectory(charRoot, false)

	for _, entry in ipairs(entries or {}) do
		if g_platform.isDirectory(entry) then
			local name = entry:match("([^/]+)$")

			if name and name:match("^%d+$") then
				table.insert(ids, name)
			end
		end
	end

	table.sort(ids)

	return ids
end

function CipImportReader.readClientOptions(confPath)
	return readJsonFile(confPath)
end

function CipImportReader.readCharacterFile(root, characterId, fileName)
	if not characterId or not fileName then
		return nil
	end

	local path = joinPath(root, "characterdata/" .. characterId .. "/" .. fileName)
	local data, err = readJsonFile(path)

	if not data then
		return nil, err
	end

	return data
end

function CipImportReader.getLoggedInCharacterId()
	local player = g_game.getLocalPlayer()

	if player then
		return tostring(player:getId())
	end

	return nil
end

function CipImportReader.readAllCharacterData(root, characterIds)
	local allCharacterData = {}

	if type(characterIds) ~= "table" or #characterIds == 0 then
		return allCharacterData
	end

	local filesToRead = {
		"sidebars.json"
	}

	for _, fileName in ipairs(CipImportMappings.PER_CHARACTER_FILES) do
		table.insert(filesToRead, fileName)
	end

	if CipImportMappings.BRIDGE_CHARACTER_FILES then
		for _, fileName in ipairs(CipImportMappings.BRIDGE_CHARACTER_FILES) do
			table.insert(filesToRead, fileName)
		end
	end

	for _, id in ipairs(characterIds) do
		local charData = {}

		for _, fileName in ipairs(filesToRead) do
			local data = CipImportReader.readCharacterFile(root, id, fileName)

			if data then
				charData[fileName] = data
			end
		end

		if not table.empty(charData) then
			allCharacterData[id] = charData
		end
	end

	return allCharacterData
end

function CipImportReader.open(sourcePath)
	local resolved, err = CipImportReader.resolveRoot(sourcePath)

	if not resolved then
		return nil, err
	end

	local clientOptions, optionsErr = CipImportReader.readClientOptions(resolved.confPath)

	if not clientOptions then
		return nil, optionsErr or "failed to read clientoptions.json"
	end

	local characterIds = CipImportReader.listCharacterIds(resolved.root)
	local playerId = CipImportReader.getLoggedInCharacterId()
	local characterFound = false

	if playerId then
		for _, id in ipairs(characterIds) do
			if id == playerId then
				characterFound = true

				break
			end
		end
	end

	local allCharacterData = CipImportReader.readAllCharacterData(resolved.root, characterIds)

	return {
		root = resolved.root,
		tempDir = resolved.tempDir,
		clientOptions = clientOptions,
		version = clientOptions.clientOptionsVersion,
		characterIds = characterIds,
		playerId = playerId,
		characterFound = characterFound,
		allCharacterData = allCharacterData
	}
end
