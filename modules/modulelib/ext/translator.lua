-- chunkname: @/modulelib/ext/translator.lua

local IMG_ATTR_TRANSLATED = {
	["border-top"] = "image-border-top",
	border = "image-border",
	color = "image-color",
	["auto-resize"] = "image-auto-resize",
	smooth = "image-smooth",
	["individual-animation"] = "image-individual-animation",
	repeated = "image-repeated",
	src = "image-source",
	["fixed-ratio"] = "image-fixed-ratio",
	clip = "image-clip",
	rect = "image-rect",
	size = "image-size",
	height = "image-height",
	width = "image-width",
	offset = "image-offset",
	["offset-y"] = "image-offset-y",
	["offset-x"] = "image-offset-x",
	["border-left"] = "image-border-left",
	["border-bottom"] = "image-border-bottom",
	["border-right"] = "image-border-right"
}

local function translateStyleName(styleName, el)
	if styleName == "select" then
		return "QtComboBox"
	end

	if styleName == "hr" then
		return "HorizontalSeparator"
	end

	if styleName == "input" then
		if el.attributes.type == "checkbox" or el.attributes.type == "radio" then
			return "QtCheckBox"
		end

		return "TextEdit"
	end

	if styleName == "textarea" then
		return "MultilineTextEdit"
	end

	return styleName
end

local function translateAttribute(styleName, tagName, attr)
	if attr == "*style" then
		return "*mergeStyle"
	end

	if attr == "*if" then
		return "*visible"
	end

	if styleName ~= "CheckBox" and styleName ~= "ComboBox" then
		if attr == "*value" then
			return "*text"
		end

		if attr == "value" then
			return "text"
		end
	end

	if tagName == "img" then
		local newAttr = IMG_ATTR_TRANSLATED[attr]

		if newAttr then
			return newAttr
		end
	end

	return attr
end

return translateStyleName, translateAttribute
