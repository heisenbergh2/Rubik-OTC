-- chunkname: @/corelib/outputmessage.lua

function OutputMessage:addData(data)
	if type(data) == "boolean" then
		self:addByte(NetworkMessageTypes.Boolean)
		self:addByte(booleantonumber(data))
	elseif type(data) == "number" then
		if math.isu8(data) then
			self:addByte(NetworkMessageTypes.U8)
			self:addByte(data)
		elseif math.isu16(data) then
			self:addByte(NetworkMessageTypes.U16)
			self:addU16(data)
		elseif math.isu32(data) then
			self:addByte(NetworkMessageTypes.U32)
			self:addU32(data)
		elseif math.isu64(data) then
			self:addByte(NetworkMessageTypes.U64)
			self:addU64(data)
		else
			self:addByte(NetworkMessageTypes.NumberString)
			self:addString(tostring(data))
		end
	elseif type(data) == "string" then
		self:addByte(NetworkMessageTypes.String)
		self:addString(data)
	elseif type(data) == "table" then
		self:addByte(NetworkMessageTypes.Table)
		self:addTable(data)
	else
		perror("Invalid data type " .. type(data))
	end
end

function OutputMessage:addTable(data)
	local size = 0
	local sizePos = self:getWritePos()

	self:addU16(size)

	local sizeSize = self:getWritePos() - sizePos

	for key, value in pairs(data) do
		self:addData(key)
		self:addData(value)

		size = size + 1
	end

	local currentPos = self:getWritePos()

	self:setWritePos(sizePos)
	self:addU16(size)
	self:setMessageSize(self:getMessageSize() - sizeSize)
	self:setWritePos(currentPos)
end

function OutputMessage:addColor(color)
	self:addByte(color.r)
	self:addByte(color.g)
	self:addByte(color.b)
	self:addByte(color.a)
end

function OutputMessage:addPosition(position)
	self:addU16(position.x)
	self:addU16(position.y)
	self:addByte(position.z)
end
