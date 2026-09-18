-- chunkname: @/modulelib/htmlcssparser/luacs.lua

local parser = {}

parser.__index = parser

function parser.new()
	parser.imports = {}
	parser.objects = {
		type = "cssroot",
		children = {}
	}
	parser.strings = {}

	return setmetatable({}, parser)
end

function parser:parse(text, filename)
	self.text = text

	self:parse_blocks()

	return self.cssom
end

function parser:get_imports()
	local imports = {}

	for filename, _ in pairs(self.imports) do
		imports[#imports + 1] = filename
	end

	return imports
end

function parser:import(filename, CSS)
	self.imports[filename] = CSS:get_objects()
end

function parser:get_objects()
	return self.objects
end

function parser:parse_blocks()
	local objects = self.objects

	self.text = self:parse_strings(self.text)
	self.text = self:delete_comments(self.text)

	local newobjects = self:parse_statements(self.text)

	for _, obj in ipairs(newobjects) do
		table.insert(objects, obj)
	end
end

function parser:parse_strings(text)
	local function replace_string(s)
		local count = #self.strings + 1

		self.strings[count] = s:sub(2, -2)

		return "%%" .. count
	end

	local text = text:gsub("(%b'')", replace_string)

	text = text:gsub("(%b\"\")", replace_string)

	return text
end

function parser:delete_comments(text)
	return text:gsub("/%*.-%*/", " ")
end

function parser:parse_statements(text)
	local pos = 0
	local objects = {}
	local startpos, obj, at

	while pos do
		startpos, pos, at = string.find(text, "(@?)%w+", pos + 1)

		if startpos then
			if at == "@" then
				obj, pos = self:parse_at_rule(text, startpos - 1)
			else
				obj, pos = self:parse_rule(text, startpos - 1)
			end

			table.insert(objects, obj)
		end
	end

	return objects
end

function parser:parse_at_rule(text, startpos)
	local _, _, brace_or_semicolon = string.find(text, "([;{])", startpos)

	if brace_or_semicolon == ";" then
		local startpos, pos, statement = string.find(text, "(.-);", startpos)

		return {
			type = "at_statement",
			statement = statement
		}, pos
	else
		local startpos, pos, statement, block = string.find(text, "(.-)(%b{})", startpos)

		return {
			type = "at_statement",
			statement = statement,
			block = block
		}, pos
	end
end

function parser:parse_rule(text, startpos)
	local startpos, pos, selector, block = string.find(text, "(.-)(%b{})", startpos)
	local obj = {
		type = "rule",
		selector = self:parse_selector(selector),
		declarations = self:parse_declarations(block:sub(2, -2))
	}

	return obj, pos
end

function parser:parse_selector(selector)
	return selector
end

function parser:parse_declarations(declarations)
	local rules = string.explode(declarations, ";")
	local properties = {}

	for _, rule in ipairs(rules) do
		local property, value = rule:match("%s*(.+)%s*:%s*(.+)%s*")

		if property then
			properties[property] = value
		end
	end

	return properties
end

CssParse = parser
