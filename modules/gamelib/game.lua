-- chunkname: @/gamelib/game.lua

function g_game.getRsa()
	return G.currentRsa
end

function g_game.findPlayerItem(itemId, subType, tier)
	local localPlayer = g_game.getLocalPlayer()

	if localPlayer then
		for slot = InventorySlotFirst, InventorySlotLast do
			local item = localPlayer:getInventoryItem(slot)

			if item and item:getId() == itemId and (subType == -1 or item:getSubType() == subType) then
				return item
			end
		end
	end

	return g_game.findItemInContainers(itemId, subType, tier or 0)
end

function g_game.chooseRsa(host)
	if G.currentRsa ~= CIPSOFT_RSA and G.currentRsa ~= OTSERV_RSA then
		return
	end

	g_game.setRsa(OTSERV_RSA)
end

function g_game.setRsa(rsa, e)
	e = e or "65537"

	g_crypt.rsaSetPublicKey(rsa, e)

	G.currentRsa = rsa
end

function g_game.isOfficialTibia()
	return G.currentRsa == CIPSOFT_RSA
end

function g_game.getSupportedClients()
	return {
		740,
		741,
		750,
		755,
		760,
		770,
		772,
		780,
		781,
		782,
		790,
		792,
		800,
		810,
		811,
		820,
		821,
		822,
		830,
		831,
		840,
		842,
		850,
		853,
		854,
		855,
		857,
		860,
		861,
		862,
		870,
		871,
		900,
		910,
		920,
		931,
		940,
		943,
		944,
		951,
		952,
		953,
		954,
		960,
		961,
		963,
		970,
		971,
		972,
		973,
		980,
		981,
		982,
		983,
		984,
		985,
		986,
		1000,
		1001,
		1002,
		1010,
		1011,
		1012,
		1013,
		1020,
		1021,
		1022,
		1030,
		1031,
		1032,
		1033,
		1034,
		1035,
		1036,
		1037,
		1038,
		1039,
		1040,
		1041,
		1050,
		1051,
		1052,
		1053,
		1054,
		1055,
		1056,
		1057,
		1058,
		1059,
		1060,
		1061,
		1062,
		1063,
		1064,
		1070,
		1071,
		1072,
		1073,
		1074,
		1075,
		1076,
		1080,
		1081,
		1082,
		1090,
		1091,
		1092,
		1093,
		1094,
		1095,
		1096,
		1097,
		1098,
		1099,
		1100,
		1281,
		1285,
		1286,
		1287,
		1291,
		1300,
		1310,
		1311,
		1314,
		1316,
		1320,
		1321,
		1322,
		1332,
		1334,
		1336,
		1337,
		1340,
		1400,
		1405,
		1410,
		1412,
		1500,
		1501,
		1503,
		1510,
		1511,
		1520,
		1521
	}
end

function g_game.getClientProtocolVersion(client)
	local clients = {
		[982] = 974,
		[985] = 977,
		[981] = 973,
		[983] = 975,
		[1001] = 979,
		[1002] = 980,
		[984] = 976,
		[986] = 978,
		[980] = 971
	}

	return clients[client] or client
end

if not G.currentRsa then
	g_game.setRsa(OTSERV_RSA)
end

function g_game.getItemFrame(value)
	local frame = 0

	if value > 0 and value <= 999 then
		frame = 1
	elseif value > 999 and value <= 9999 then
		frame = 2
	elseif value > 9999 and value <= 99999 then
		frame = 3
	elseif value > 99999 and value <= 999999 then
		frame = 4
	elseif value > 1000000 then
		frame = 5
	end

	return frame
end

function g_game.getRectFrame(frame)
	if frame == 1 then
		return "0 0 32 32"
	elseif frame == 2 then
		return "32 0 32 32"
	elseif frame == 3 then
		return "64 0 32 32"
	elseif frame == 4 then
		return "96 0 32 32"
	elseif frame == 5 then
		return "128 0 32 32"
	elseif frame == 6 then
		return "160 0 32 32"
	end
end

function g_game.getVocationName(vocationId)
	if vocationId == 1 then
		return "Knight"
	elseif vocationId == 2 then
		return "Paladin"
	elseif vocationId == 3 then
		return "Sorcerer"
	elseif vocationId == 4 then
		return "Druid"
	elseif vocationId == 5 then
		return "Monk"
	elseif vocationId == 11 then
		return "Elite Knight"
	elseif vocationId == 12 then
		return "Royal Paladin"
	elseif vocationId == 13 then
		return "Master Sorcerer"
	elseif vocationId == 14 then
		return "Elder Druid"
	elseif vocationId == 15 then
		return "Exalted Monk"
	else
		return "None"
	end
end

function g_game.requestSelectCharacterTitle(titleId)
	titleId = tonumber(titleId) or 0

	if titleId < 0 then
		return
	end

	if g_game.getClientVersion and g_game.getClientVersion() < 1412 then
		return
	end

	if g_game.requestSetCharacterTitle then
		g_game.requestSetCharacterTitle(titleId)
	end
end

function g_game.onOtcToggle(opCode, enabled)
	return
end
