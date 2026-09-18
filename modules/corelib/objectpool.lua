-- chunkname: @/corelib/objectpool.lua

ObjectPool = {}
ObjectPool.__index = ObjectPool

function ObjectPool.new(createFunc, resetFunc)
	return setmetatable({
		create = createFunc,
		reset = resetFunc,
		pool = {}
	}, ObjectPool)
end

function ObjectPool:get()
	local obj = table.remove(self.pool)

	obj = obj or self.create()

	return obj
end

function ObjectPool:release(obj)
	if self.reset then
		self.reset(obj)
	end

	table.insert(self.pool, obj)
end

function ObjectPool:clear()
	self.pool = {}
end
