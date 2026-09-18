-- chunkname: @/game_announcements/announcements_data.lua

AnnouncementsData = {
	syncInProgress = false,
	cache = {
		ptc = {}
	}
}

local CACHE_FILE = "/cache/game_announcements.json"
local BRA_TIMEZONE_OFFSET = -10800
local Util = AnnouncementsUtil

local function ensureCacheDir()
	if not g_resources.directoryExists("/cache") then
		pcall(g_resources.makeDir, "/cache")
	end
end

function AnnouncementsData.normalizeId(id)
	if id == nil then
		return nil
	end

	if type(id) == "number" then
		return id
	end

	if type(id) == "string" then
		local num = tonumber(id)

		if num then
			return num
		end
	end

	return id
end

function AnnouncementsData.isRead(news)
	return news and news.isread == true
end

local function normalizeItem(item)
	if not item or item.id == nil then
		return
	end

	item.id = AnnouncementsData.normalizeId(item.id)
	item.isread = AnnouncementsData.isRead(item)
end

local function buildReadStatus()
	local readById = {}

	for _, item in ipairs(AnnouncementsData.cache.ptc or {}) do
		if item and item.id ~= nil and AnnouncementsData.isRead(item) then
			readById[AnnouncementsData.normalizeId(item.id)] = true
		end
	end

	return readById
end

local function mergeItem(remoteItem, readById)
	local copy = {}

	for k, v in pairs(remoteItem) do
		if k ~= "isread" then
			copy[k] = v
		end
	end

	copy.id = AnnouncementsData.normalizeId(copy.id)
	copy.list = Util.normalizeList(copy.list)
	copy.isread = readById[copy.id] == true

	return copy
end

local function mergeRemote(remote)
	if type(remote) ~= "table" or type(remote.ptc) ~= "table" then
		return
	end

	local readById = buildReadStatus()
	local merged, seenIds = {}, {}

	for _, remoteItem in ipairs(remote.ptc) do
		if remoteItem and remoteItem.id ~= nil then
			local id = AnnouncementsData.normalizeId(remoteItem.id)

			if seenIds[id] then
				g_logger.warning("[game_announcements] duplicate id ignored: " .. tostring(id))
			else
				seenIds[id] = true

				table.insert(merged, mergeItem(remoteItem, readById))
			end
		end
	end

	AnnouncementsData.cache.ptc = merged
	AnnouncementsData.cache.isreturner = remote.isreturner
	AnnouncementsData.cache.lastupdatetimestamp = remote.lastupdatetimestamp
	AnnouncementsData.cache.maxeditdate = remote.maxeditdate

	AnnouncementsData.save()
end

function AnnouncementsData.load()
	ensureCacheDir()

	AnnouncementsData.cache = {
		ptc = {}
	}

	if not g_resources.fileExists(CACHE_FILE) then
		return
	end

	local ok, content = pcall(g_resources.readFileContents, CACHE_FILE)

	if not ok or not content or content == "" then
		return
	end

	local okDecode, data = pcall(json.decode, content)

	if okDecode and type(data) == "table" then
		AnnouncementsData.cache = {
			ptc = type(data.ptc) == "table" and data.ptc or {},
			isreturner = data.isreturner,
			lastupdatetimestamp = data.lastupdatetimestamp,
			maxeditdate = data.maxeditdate
		}

		for _, item in ipairs(AnnouncementsData.cache.ptc or {}) do
			normalizeItem(item)
		end
	end
end

function AnnouncementsData.save()
	ensureCacheDir()

	local ok, encoded = pcall(json.encode, AnnouncementsData.cache, 2)

	if ok then
		pcall(g_resources.writeFileContents, CACHE_FILE, encoded)
	end
end

function AnnouncementsData.setRead(news)
	if not news or AnnouncementsData.isRead(news) then
		return false
	end

	news.isread = true

	AnnouncementsData.save()

	return true
end

function AnnouncementsData.markRead(id)
	id = AnnouncementsData.normalizeId(id)

	for _, news in ipairs(AnnouncementsData.cache.ptc or {}) do
		if news and AnnouncementsData.normalizeId(news.id) == id then
			return AnnouncementsData.setRead(news)
		end
	end

	return false
end

function AnnouncementsData.getByCategory(category)
	local result = {}

	for _, news in ipairs(AnnouncementsData.cache.ptc or {}) do
		if news and news.category == category then
			table.insert(result, news)
		end
	end

	return result
end

function AnnouncementsData.hasUnread(categories)
	for _, news in ipairs(AnnouncementsData.cache.ptc or {}) do
		if news and not AnnouncementsData.isRead(news) and categories[news.category] then
			return true
		end
	end

	return false
end

function AnnouncementsData.categoryHasUnread(category)
	for _, news in ipairs(AnnouncementsData.cache.ptc or {}) do
		if news and news.category == category and not AnnouncementsData.isRead(news) then
			return true
		end
	end

	return false
end

local function getUrl()
	local url = "http://127.0.0.1/game_announcements.php"

	if Services and Services.gamenews and Services.gamenews ~= "" then
		url = Services.gamenews
	end

	return url:gsub("%.json$", ".php")
end

local function parseResponse(rawData, httpErr)
	if httpErr and httpErr ~= "" then
		return nil, httpErr
	end

	if type(rawData) ~= "string" or rawData == "" then
		return nil, "empty response"
	end

	local body = rawData

	if body:sub(1, 3) == "﻿" then
		body = body:sub(4)
	end

	if body:find("\r\n", 1, true) and not body:match("^%s*[{[]") then
		body = body:gsub("^[%x]+\r\n", "", 1)
	end

	body = body:gsub("\r\n[%x]+\r\n", "\r\n"):gsub("\r\n0\r\n\r\n.*$", ""):gsub("\r\n0\r\n$", "")

	local start = body:find("{", 1, true)

	if not start then
		return nil, "not JSON"
	end

	local text = body:sub(start)
	local ok, data = pcall(json.decode, text)

	if not ok then
		for i = #text, 1, -1 do
			if text:sub(i, i) == "}" then
				ok, data = pcall(json.decode, text:sub(1, i))

				if ok then
					break
				end
			end
		end
	end

	if not ok or type(data) ~= "table" or type(data.ptc) ~= "table" then
		return nil, "invalid JSON"
	end

	return data
end

function AnnouncementsData.sync(callback)
	HTTP.get(getUrl(), function(data, err)
		local remote, fetchErr = parseResponse(data, err)

		if fetchErr then
			if #(AnnouncementsData.cache.ptc or {}) == 0 then
				g_logger.warning("[game_announcements] fetch failed: " .. fetchErr)
			end
		else
			mergeRemote(remote)
		end

		if callback then
			callback()
		end
	end)
end

function AnnouncementsData.stopPolling()
	if AnnouncementsData.pollEvent then
		removeEvent(AnnouncementsData.pollEvent)

		AnnouncementsData.pollEvent = nil
	end
end

function AnnouncementsData.startPolling(intervalMs, callback)
	AnnouncementsData.stopPolling()

	AnnouncementsData.pollEvent = cycleEvent(function()
		if AnnouncementsData.syncInProgress then
			return
		end

		AnnouncementsData.syncInProgress = true

		AnnouncementsData.sync(function()
			AnnouncementsData.syncInProgress = false

			if callback then
				callback()
			end
		end)
	end, intervalMs)
end

function AnnouncementsData.formatDate(news)
	return Util.formatPublishDate(news, BRA_TIMEZONE_OFFSET)
end
