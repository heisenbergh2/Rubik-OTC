-- chunkname: @/modulelib/htmlcssparser/ElementNode.lua

local Set = {}

Set.mt = {
	__index = Set
}

function Set:new(values)
	local instance = {}
	local isSet

	if getmetatable(values) == Set.mt then
		isSet = true
	end

	if type(values) == "table" then
		if not isSet and #values > 0 then
			for _, v in ipairs(values) do
				instance[v] = true
			end
		else
			for k in pairs(values) do
				instance[k] = true
			end
		end
	elseif values ~= nil then
		instance = {
			[values] = true
		}
	end

	return setmetatable(instance, Set.mt)
end

function Set:add(e)
	if e ~= nil then
		self[e] = true
	end

	return self
end

function Set:remove(e)
	if e ~= nil then
		self[e] = nil
	end

	return self
end

function Set:tolist()
	local res = {}

	for k in pairs(self) do
		table.insert(res, k)
	end

	return res
end

function Set.mt.__add(a, b)
	local res, a, b = Set:new(), Set:new(a), Set:new(b)

	for k in pairs(a) do
		res[k] = true
	end

	for k in pairs(b) do
		res[k] = true
	end

	return res
end

function Set.mt.__sub(a, b)
	local res, a, b = Set:new(), Set:new(a), Set:new(b)

	for k in pairs(a) do
		res[k] = true
	end

	for k in pairs(b) do
		res[k] = nil
	end

	return res
end

function Set.mt.__mul(a, b)
	local res, a, b = Set:new(), Set:new(a), Set:new(b)

	for k in pairs(a) do
		res[k] = b[k]
	end

	return res
end

function Set.mt.__tostring(set)
	local list = {
		"{"
	}

	for k in pairs(set) do
		list[#list + 1] = tostring(k)
		list[#list + 1] = ", "
	end

	list[#list] = "}"

	return table.concat(list)
end

local ElementNode = {}

ElementNode.mt = {
	__index = ElementNode
}

function ElementNode:new(index, nameortext, node, descend, openstart, openend)
	local instance = {
		level = 0,
		index = index,
		name = nameortext and nameortext:lower() or nameortext,
		nodes = {},
		_openstart = openstart,
		_openend = openend,
		_closestart = openstart,
		_closeend = openend,
		attributes = {},
		classes = {},
		deepernodes = Set:new(),
		deeperelements = {},
		deeperattributes = {},
		deeperids = {},
		deeperclasses = {}
	}

	if not node then
		instance.name = "root"
		instance.root = instance
		instance._text = nameortext

		local length = string.len(nameortext)

		instance._openstart, instance._openend = 1, length
		instance._closestart, instance._closeend = 1, length
	elseif descend then
		instance.root = node.root
		instance.parent = node
		instance.level = node.level + 1

		table.insert(node.nodes, instance)
	else
		instance.root = node.root
		instance.parent = node.parent or node
		instance.level = node.level

		table.insert(node.parent and node.parent.nodes or node.nodes, instance)
	end

	return setmetatable(instance, ElementNode.mt)
end

function ElementNode:gettext()
	return string.sub(self.root._text, self._openstart, self._closeend)
end

function ElementNode:settext(c)
	self.root._text = c
end

function ElementNode:textonly()
	return (self:gettext():gsub("<[^>]*>", ""))
end

function ElementNode:getcontent()
	return string.sub(self.root._text, self._openend + 1, self._closestart - 1)
end

function ElementNode:addattribute(k, v)
	self.attributes[k] = v

	if string.lower(k) == "id" then
		self.id = v
	elseif string.lower(k) == "class" then
		for class in string.gmatch(v, "%S+") do
			table.insert(self.classes, class:lower())
		end
	end
end

local function insert(table, name, node)
	table[name] = table[name] or Set:new()

	table[name]:add(node)
end

function ElementNode:close(closestart, closeend)
	if closestart and closeend then
		self._closestart, self._closeend = closestart, closeend
	end

	local node = self

	while true do
		node = node.parent

		if not node then
			break
		end

		node.deepernodes:add(self)
		insert(node.deeperelements, self.name, self)

		for k in pairs(self.attributes) do
			insert(node.deeperattributes, k, self)
		end

		if self.id then
			insert(node.deeperids, self.id, self)
		end

		for _, v in ipairs(self.classes) do
			insert(node.deeperclasses, v, self)
		end
	end
end

local function escape(s)
	return string.gsub(s, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%" .. "%1")
end

local function find(self, s)
	if not s or type(s) ~= "string" or s == "" then
		return Set:new()
	end

	s = s:lower()

	local splited = s:split(",")

	if #splited > 1 then
		s = splited[1]
	end

	local sets = {
		[""] = self.deeperelements,
		["["] = self.deeperattributes,
		["#"] = self.deeperids,
		["."] = self.deeperclasses
	}

	local function match(t, w)
		local m, e, v

		if t == "[" then
			w, m, e, v = string.match(w, "([^=|%*~%$!%^]+)" .. "([|%*~%$!%^]?)" .. "(=?)" .. "(.*)")
		end

		local matched = Set:new(sets[t][w])

		if e == "=" then
			if #v < 2 then
				v = "'" .. v .. "'"
			end

			v = string.sub(v, 2, #v - 1)

			if m == "!" then
				matched = Set:new(self.deepernodes)
			end

			for node in pairs(matched) do
				local a = node.attributes[w]

				if m == "" and a ~= v then
					matched:remove(node)
				elseif m == "!" and a == v then
					matched:remove(node)
				elseif m == "|" and string.match(a, "^[^-]*") ~= v then
					matched:remove(node)
				elseif m == "*" and string.match(a, escape(v)) ~= v then
					matched:remove(node)
				elseif m == "~" then
					matched:remove(node)

					for word in string.gmatch(a, "%S+") do
						if word == v then
							matched:add(node)

							break
						end
					end
				elseif m == "^" and string.match(a, "^" .. escape(v)) ~= v then
					matched:remove(node)
				elseif m == "$" and string.match(a, escape(v) .. "$") ~= v then
					matched:remove(node)
				end
			end
		end

		return matched
	end

	local subjects, resultset, childrenonly = Set:new({
		self
	})

	for part in string.gmatch(s, "%S+") do
		repeat
			if part == ">" then
				childrenonly = true

				break
			end

			resultset = Set:new()

			for subject in pairs(subjects) do
				local star = subject.deepernodes

				if childrenonly then
					star = Set:new(subject.nodes)
				end

				resultset = resultset + star
			end

			childrenonly = false

			if part == "*" then
				break
			end

			local excludes, filter = Set:new()
			local start, pos = 0, 0

			while true do
				local switch, stype, name, eq, quote

				start, pos, switch, stype, name, eq, quote = string.find(part, "(%(?%)?)" .. "([:%[#.]?)" .. "([%w-_\\]+)" .. "([|%*~%$!%^]?=?)" .. "(['\"]?)", pos + 1)

				if not name then
					break
				end

				repeat
					if stype == ":" then
						filter = name

						break
					end

					if switch == ")" then
						filter = nil
					end

					if stype == "[" and quote ~= "" then
						local value

						start, pos, value = string.find(part, "(%b" .. quote .. quote .. ")]", pos)
						name = name .. eq .. value
					end

					local matched = match(stype, name)

					if filter == "not" then
						excludes = excludes + matched

						break
					end

					resultset = resultset * matched

					break
				until true
			end

			resultset = resultset - excludes
			subjects = Set:new(resultset)

			break
		until true
	end

	resultset = resultset:tolist()

	for i, q in pairs(splited) do
		if i > 1 then
			table.insertall(resultset, find(self, q:gsub("[\n\r]", "")))
		end
	end

	table.sort(resultset, function(a, b)
		return a.index < b.index
	end)

	return resultset
end

function ElementNode:find(s)
	return find(self, s)
end

function ElementNode:findWidgets(s)
	local els = find(self, s)
	local widgets = {}

	for _, el in pairs(els) do
		if el.widget then
			table.insert(widgets, el.widget)
		end
	end

	return widgets
end

ElementNode.mt.__call = select

return ElementNode
