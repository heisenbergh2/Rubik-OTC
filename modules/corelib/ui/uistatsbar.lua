-- chunkname: @/corelib/ui/uistatsbar.lua

UIStatsBar = extends(UIWidget, "UIStatsBar")

local function findDescendantById(root, wantId)
	if not root or not wantId then
		return nil
	end

	local id = root:getId()

	if id == wantId or tostring(id) == wantId then
		return root
	end

	local children = root:getChildren()

	if not children then
		return nil
	end

	for _, child in pairs(children) do
		local found = findDescendantById(child, wantId)

		if found then
			return found
		end
	end

	return nil
end

local function progressbarImagePath(self, baseId)
	if self.statsOrientation == "vertical" then
		return "/images/bars/" .. baseId .. "-vertical"
	end

	return "/images/bars/" .. baseId
end

local STATSBAR_XP_FILL_COLOR = "#c00000"
local STATSBAR_SKILL_FILL_COLOR = "#00c000"

local function bindStatsBarTextWidgets(self)
	self.textRow = findDescendantById(self, "textRow")
	self.valueLabel = findDescendantById(self, "statsbarManaValue")
	self.textEnd = findDescendantById(self, "statsbarManaEnd")
	self.manaShieldIcon = findDescendantById(self, "statsbarManaShieldIcon")

	if not self.valueLabel then
		self.valueLabel = findDescendantById(self, "text")
	end

	if not self.valueLabel then
		self.valueLabel = self:getChildById("text")
	end

	if not self.textRow then
		self.textRow = self:getChildById("textRow")
	end

	if self.textRow and not self.textEnd then
		self.textEnd = findDescendantById(self.textRow, "statsbarManaEnd")
	end

	if self.textRow and not self.manaShieldIcon then
		self.manaShieldIcon = findDescendantById(self.textRow, "statsbarManaShieldIcon")
	end
end

function UIStatsBar.create()
	local stats = UIStatsBar.internalCreate()

	stats.bar = stats:getChildById("bar")

	bindStatsBarTextWidgets(stats)

	function stats.onGeometryChange()
		stats:setValue(stats.currentValue, stats.currentTotal)
		stats:reloadBorder()
	end

	return stats
end

function UIStatsBar:reloadBorder()
	if not self.grade then
		if self.statsOrientation == "horizontal" then
			self.grade = self:getChildById("horizontalGrade")
		elseif self.statsOrientation == "vertical" then
			self.grade = self:getChildById("verticalGrade")
		end
	end

	for _, child in ipairs(self.grade:getChildren()) do
		if string.len(tostring(child:getId())) >= 6 and string.sub(tostring(child:getId()), 1, 6) == "grade_" then
			child:hide()
		end
	end

	if not self.statsGradeColor then
		self.grade:hide()

		return
	end

	self.grade:show()

	for _, child in ipairs(self.grade:getChildren()) do
		if string.len(child:getId()) >= 13 and string.sub(child:getId(), 1, 13) == "grade_border_" then
			child:show()
			child:setBackgroundColor(self.statsGradeColor)
		end
	end

	local markerOffset = 3

	for _, child in ipairs(self.grade:getChildren()) do
		if self.statsGrade == 3 then
			if child:getId() == "grade_left_1" then
				child:show()

				if self.statsOrientation == "horizontal" then
					child:setMarginLeft((self:getWidth() - 2) * 0.33 - markerOffset)
				else
					child:setMarginTop((self:getHeight() - 2) * 0.33 - markerOffset)
				end
			elseif child:getId() == "grade_right_1" then
				child:show()

				if self.statsOrientation == "horizontal" then
					child:setMarginRight((self:getWidth() - 2) * 0.33 - markerOffset)
				else
					child:setMarginBottom((self:getHeight() - 2) * 0.33 - markerOffset)
				end
			end
		elseif self.statsGrade == 4 then
			if child:getId() == "grade_left_1" then
				child:show()

				if self.statsOrientation == "horizontal" then
					child:setMarginLeft((self:getWidth() - 2) * 0.25 - markerOffset)
				else
					child:setMarginTop((self:getHeight() - 2) * 0.25 - markerOffset)
				end
			elseif child:getId() == "grade_left_2" then
				child:show()

				if self.statsOrientation == "horizontal" then
					child:setMarginLeft((self:getWidth() - 2) * 0.5 - markerOffset)
				else
					child:setMarginTop((self:getHeight() - 2) * 0.5 - markerOffset)
				end
			elseif child:getId() == "grade_right_1" then
				child:show()

				if self.statsOrientation == "horizontal" then
					child:setMarginRight((self:getWidth() - 2) * 0.25 - markerOffset)
				else
					child:setMarginBottom((self:getHeight() - 2) * 0.25 - markerOffset)
				end
			end
		end
	end
end

function UIStatsBar:onStyleApply(styleName, styleNode)
	for name, value in pairs(styleNode) do
		if name == "statsbar-type" then
			self.statsType = value
		elseif name == "statsbar-size" then
			self.statsSize = value
		elseif name == "statsbar-text" then
			self.showText = value ~= false and value ~= "false" and value ~= 0 and value ~= "0"
		elseif name == "statsbar-orientation" then
			self.statsOrientation = value
		elseif name == "statsbar-grade" then
			self.statsGrade = value
		elseif name == "statsbar-gradecolor" then
			self.statsGradeColor = value
		end
	end

	bindStatsBarTextWidgets(self)
end

function UIStatsBar:setValue(value, total)
	bindStatsBarTextWidgets(self)

	local canDrawBar = value ~= nil and total ~= nil and total ~= 0 and self.statsType and self.statsSize and self.statsOrientation and self.bar

	if canDrawBar then
		value = math.min(total, math.max(0, value))
		self.currentValue = value
		self.currentTotal = total

		if self.statsOrientation == "horizontal" then
			local maxW = math.max(0, self:getWidth() - 2)
			local w = maxW * value / total
			local roundedW = math.max(0, math.min(maxW, math.floor(w + 0.5)))

			if roundedW <= 0 then
				self.bar:setWidth(0)
				self.bar:hide()
			else
				self.bar:setWidth(roundedW)
				self.bar:show()
			end
		elseif self.statsOrientation == "vertical" then
			local maxH = math.max(0, self:getHeight() - 2)
			local h = maxH * value / total
			local roundedH = math.max(0, math.min(maxH, math.floor(h + 0.5)))

			if roundedH <= 0 then
				self.bar:setHeight(0)
				self.bar:hide()
			else
				self.bar:setHeight(roundedH)
				self.bar:show()
			end
		else
			canDrawBar = false
		end
	end

	if canDrawBar then
		local percent = math.floor(value * 100 / total)
		local sizeKey = tostring(self.statsSize)

		if self.statsType == "experience" then
			self.bar:setImageSource("")
			self.bar:setImageColor("white")
			self.bar:setBackgroundColor(STATSBAR_XP_FILL_COLOR)
		elseif self.statsType == "skill" then
			self.bar:setImageSource("")
			self.bar:setImageColor("white")
			self.bar:setBackgroundColor(STATSBAR_SKILL_FILL_COLOR)
		else
			self.bar:setBackgroundColor("alpha")
			self.bar:setImageColor("white")

			if self.statsType == "health" then
				if sizeKey == "grey_large" then
					self.bar:setImageSource(progressbarImagePath(self, "progressbar-grey-large"))
				else
					local band = "4"

					if percent > 95 then
						band = "100"
					elseif percent > 60 then
						band = "95"
					elseif percent > 30 then
						band = "60"
					elseif percent > 10 then
						band = "30"
					elseif percent > 4 then
						band = "10"
					end

					self.bar:setImageSource(progressbarImagePath(self, "progressbar-" .. sizeKey .. "-" .. band))
				end
			elseif self.statsType == "mana" then
				self.bar:setImageSource(progressbarImagePath(self, "progressbar-blue-" .. sizeKey))
			elseif self.statsType == "manashield" then
				self.bar:setImageSource(progressbarImagePath(self, "progressbar-manashield-" .. sizeKey))
			end
		end
	end

	if not self.valueLabel then
		return
	end

	local showNumbers = self.showText ~= false

	if showNumbers then
		if self.textRow then
			self.textRow:show()
			self.textRow:raise()
		end

		self.valueLabel:show()

		if self.manaDisplayLineMain then
			self.valueLabel:setText(self.manaDisplayLineMain)

			if self.textEnd then
				self.textEnd:setText(")")
				self.textEnd:show()
			end

			if self.manaShieldIcon then
				self.manaShieldIcon:show()
			end
		elseif self.manaShieldText then
			self.valueLabel:setText(self.manaShieldText)

			if self.textEnd then
				self.textEnd:hide()
			end

			if self.manaShieldIcon then
				self.manaShieldIcon:hide()
			end
		elseif canDrawBar then
			self.valueLabel:setText(value .. "/" .. total)

			if self.textEnd then
				self.textEnd:hide()
			end

			if self.manaShieldIcon then
				self.manaShieldIcon:hide()
			end
		end
	else
		self.valueLabel:hide()

		if self.textRow then
			self.textRow:hide()
		end

		if self.textEnd then
			self.textEnd:hide()
		end

		if self.manaShieldIcon then
			self.manaShieldIcon:hide()
		end
	end
end
