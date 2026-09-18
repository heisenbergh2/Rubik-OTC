-- chunkname: @/game_announcements/announcements_util.lua

AnnouncementsUtil = {}

local HTML_ENTITIES = {
	amp = "&",
	Ograve = "\xD2",
	Igrave = "\xCC",
	Ugrave = "\xD9",
	Egrave = "\xC8",
	Acirc = "\xC2",
	Agrave = "\xC0",
	Ecirc = "\xCA",
	Uacute = "\xDA",
	Icirc = "\xCE",
	Oacute = "\xD3",
	Ocirc = "\xD4",
	Iacute = "\xCD",
	Ucirc = "\xDB",
	Eacute = "\xC9",
	Atilde = "\xC3",
	Aacute = "\xC1",
	Ntilde = "\xD1",
	ccedil = "\xE7",
	Otilde = "\xD5",
	otilde = "\xF5",
	Ccedil = "\xC7",
	ntilde = "\xF1",
	auml = "\xE4",
	atilde = "\xE3",
	euml = "\xEB",
	ucirc = "\xFB",
	iuml = "\xEF",
	ocirc = "\xF4",
	ouml = "\xF6",
	icirc = "\xEE",
	uuml = "\xFC",
	ecirc = "\xEA",
	Auml = "\xC4",
	acirc = "\xE2",
	Euml = "\xCB",
	ugrave = "\xF9",
	Iuml = "\xCF",
	ograve = "\xF2",
	Ouml = "\xD6",
	igrave = "\xEC",
	Uuml = "\xDC",
	egrave = "\xE8",
	nbsp = " ",
	agrave = "\xE0",
	uacute = "\xFA",
	oacute = "\xF3",
	iacute = "\xED",
	eacute = "\xE9",
	aacute = "\xE1",
	apos = "'",
	quot = "\"",
	gt = ">",
	lt = "<"
}

local function utf8ToLatin1(str)
	if not str or str == "" then
		return ""
	end

	local out, i, len = {}, 1, #str

	while i <= len do
		local c = str:byte(i)

		if c >= 32 and c < 128 or c == 13 or c == 10 or c == 9 then
			out[#out + 1] = string.char(c)
			i = i + 1
		elseif c == 194 or c == 195 then
			if i < len then
				local c2 = str:byte(i + 1)

				out[#out + 1] = string.char(c == 194 and c2 or c2 + 64)
				i = i + 2
			else
				i = i + 1
			end
		else
			i = i + 1

			while i <= len and str:byte(i) >= 128 and str:byte(i) < 192 do
				i = i + 1
			end
		end
	end

	return table.concat(out)
end

function AnnouncementsUtil.htmlToPlain(html)
	if not html or html == "" then
		return ""
	end

	html = html:gsub("<[bB][rR]%s*/?>", "\n")
	html = html:gsub("&#(%d+);", function(code)
		local n = tonumber(code)

		return n and n >= 0 and n <= 255 and string.char(n) or ""
	end)
	html = html:gsub("&#x([%x]+);", function(hex)
		local n = tonumber(hex, 16)

		return n and n >= 0 and n <= 255 and string.char(n) or ""
	end)
	html = html:gsub("&(%a+);", function(name)
		return HTML_ENTITIES[name] or "&" .. name .. ";"
	end)
	html = html:gsub("</?[bB]>", "")
	html = html:gsub("<[^>]+>", "")

	return utf8ToLatin1(html)
end

function AnnouncementsUtil.normalizeList(list)
	local items = {}

	if type(list) ~= "table" then
		return items
	end

	local iter = #list > 0 and ipairs or pairs

	for _, value in iter(list) do
		if type(value) == "string" and value ~= "" then
			table.insert(items, value)
		end
	end

	return items
end

function AnnouncementsUtil.formatPublishDate(news, timezoneOffset)
	local timestamp = news and (news.publishdate or news.timestamp)

	if type(timestamp) ~= "number" or timestamp <= 0 then
		return nil
	end

	if timestamp > 9999999999 then
		timestamp = math.floor(timestamp / 1000)
	end

	return os.date("!%Y/%m/%d, %H:%M", timestamp + timezoneOffset) .. " BRA"
end
