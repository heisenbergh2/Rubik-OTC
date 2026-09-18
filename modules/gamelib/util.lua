-- chunkname: @/gamelib/util.lua

function postostring(pos)
	return pos.x .. " " .. pos.y .. " " .. pos.z
end

function dirtostring(dir)
	for k, v in pairs(Directions) do
		if v == dir then
			return k
		end
	end
end

function comma_value(n)
	local left, num, right = string.match(n, "^([^%d]*%d)(%d*)(.-)$")

	return left .. num:reverse():gsub("(%d%d%d)", "%1,"):reverse() .. right
end

function formatMoney(amount, separator)
	local patternSeparator = string.format("%%1%s%%2", separator)
	local formatted = amount

	repeat
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", patternSeparator)
	until k == 0

	return formatted
end

function convertLongGold(amount, shortValue, normalized)
	local fomarType = 0

	if normalized and amount >= 1000000 then
		amount = math.floor(amount / 1000000)
		fomarType = 1
	elseif normalized and amount >= 10000 then
		amount = math.floor(amount / 1000)
		fomarType = 2
	elseif shortValue and amount > 10000000 then
		fomarType = 1
		amount = math.floor(amount / 1000000)
	elseif shortValue and amount > 1000000 then
		fomarType = 2
		amount = math.floor(amount / 1000)
	elseif amount > 999999999 then
		fomarType = 1
		amount = math.floor(amount / 1000000)
	elseif amount > 99999999 then
		fomarType = 2
		amount = math.floor(amount / 1000)
	end

	local formatted = amount

	repeat
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
	until k == 0

	if fomarType == 1 then
		formatted = formatted .. " kk"
	elseif fomarType == 2 then
		formatted = formatted .. " k"
	end

	return formatted
end

function formatTimeBySeconds(totalSeconds)
	local hours = math.floor(totalSeconds / 3600)
	local remainingSeconds = totalSeconds % 3600
	local minutes = math.floor(remainingSeconds / 60)

	return string.format("%02d:%02d", hours, minutes)
end

function formatTimeByMinutes(totalMinutes)
	local totalSeconds = totalMinutes * 60
	local hours = math.floor(totalSeconds / 3600)
	local remainingSeconds = totalSeconds % 3600
	local minutes = math.floor(remainingSeconds / 60)

	return string.format("%02d:%02d", hours, minutes)
end

function getVocationSt(id)
	if id == 1 then
		return "K0"
	elseif id == 2 then
		return "P0"
	elseif id == 3 then
		return "S0"
	elseif id == 4 then
		return "D0"
	elseif id == 5 then
		return "MO"
	end

	return "N"
end

function translateVocation(id)
	if id == 1 or id == 11 then
		return 8
	elseif id == 2 or id == 12 then
		return 7
	elseif id == 3 or id == 13 then
		return 5
	elseif id == 4 or id == 14 then
		return 6
	elseif id == 5 or id == 15 then
		return 9
	end

	return 0
end

function translateWheelVocation(id)
	if id == 1 or id == 11 then
		return 1
	elseif id == 2 or id == 12 then
		return 2
	elseif id == 3 or id == 13 then
		return 3
	elseif id == 4 or id == 14 then
		return 4
	elseif id == 5 or id == 15 then
		return 5
	end

	return 0
end

function translateVocationName(id)
	if id == 1 or id == 11 then
		return "Knight"
	elseif id == 2 or id == 12 then
		return "Paladin"
	elseif id == 3 or id == 13 then
		return "Sorcerer"
	elseif id == 4 or id == 14 then
		return "Druid"
	elseif id == 5 or id == 15 then
		return "Monk"
	end

	return "Rookie"
end

function wrapTextByWords(str, n)
	local result = {}
	local i = 1

	while i <= #str do
		local chunk = str:sub(i, i + n - 1)

		if n > #chunk then
			table.insert(result, chunk)

			break
		end

		local breakAt = chunk:match("^.*()[%s,%.;:!?%-]")

		if breakAt and breakAt > 1 then
			local chunk = str:sub(i, i + breakAt - 1)

			chunk = chunk:gsub("[%s,%.;:!?%-]+$", "")

			table.insert(result, chunk)

			i = i + breakAt
		else
			table.insert(result, chunk)

			i = i + n
		end
	end

	return table.concat(result, "\n")
end

function matchText(input, target)
	input = input:lower()
	target = target:lower()

	if input == target then
		return true
	end

	if #input >= 1 and target:find(input, 1, true) then
		return true
	end

	return false
end

function getFrameClip(id, frameWidth, frameHeight, framesPerRow)
	if id == 0 then
		return {
			y = 0,
			x = 0,
			width = frameWidth,
			height = frameHeight
		}
	end

	local adjustedId = id
	local row = math.floor(adjustedId / framesPerRow)
	local col = adjustedId % framesPerRow

	return {
		x = col * frameWidth,
		y = row * frameHeight,
		width = frameWidth,
		height = frameHeight
	}
end

function getFramePosition(id, frameWidth, frameHeight, fpr)
	local frameWidth = 64
	local frameHeight = 64
	local framesPerRow = 21

	if id == 0 then
		return "0 0"
	end

	local adjustedId = id - 1
	local row = math.floor(adjustedId / fpr) + 1
	local col = adjustedId % fpr

	return col * frameWidth .. " " .. row * frameHeight
end

function convertGold(amount, shortValue)
	local formatType = 0

	if shortValue and amount > 9999999999 then
		formatType = 1
		amount = math.floor(amount / 1000)
	end

	local formatted = amount

	repeat
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
	until k == 0

	if formatType == 1 then
		formatted = formatted .. " k"
	end

	return formatted
end

function short_text(text, chars_limit)
	if not text then
		return ""
	end

	chars_limit = chars_limit or 20

	if chars_limit >= string.len(text) then
		return text
	end

	return string.sub(text, 1, chars_limit - 3) .. "..."
end

function getTotalMoney()
	local player = g_game.getLocalPlayer()

	return player and player:getTotalMoney() or 0
end

function math.cround(value, rd)
	local _round = math.floor(value / rd)

	return _round * rd
end

function getHealthColorByPercent(percent)
	if percent > 95 then
		return "#00C000"
	elseif percent > 60 then
		return "#60C060"
	elseif percent > 30 then
		return "#C0C000"
	elseif percent > 10 then
		return "#C03030"
	elseif percent > 4 then
		return "#C00000"
	else
		return "#600000"
	end
end

function getHealthColorByPercentWithAlpha(percent, alpha)
	alpha = alpha or "BF"

	return getHealthColorByPercent(percent) .. alpha
end
