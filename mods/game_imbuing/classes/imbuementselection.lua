-- chunkname: @/mods/game_imbuing/classes/imbuementselection.lua

if not ImbuementSelection then
	ImbuementSelection = {}
end

ImbuementSelection.__index = ImbuementSelection

local self = ImbuementSelection

function ImbuementSelection.startUp()
	self.pickItem = g_ui.createWidget("UIWidget")

	self.pickItem:setVisible(false)
	self.pickItem:setFocusable(false)

	self.pickItem.onMouseRelease = self.onChooseItemMouseRelease
end

function ImbuementSelection:shutdown()
	if self.pickItem then
		self.pickItem:destroy()

		self.pickItem = nil
	end
end

function ImbuementSelection:selectItem()
	if not self.pickItem then
		self:startUp()
	end

	if g_ui.isMouseGrabbed() then
		return
	end

	g_mouse.updateGrabber(self.pickItem, "target")
	self.pickItem:grabMouse()
	g_mouse.pushCursor("target")
end

function ImbuementSelection.onChooseItemMouseRelease(widget, mousePosition, mouseButton)
	local item

	if mouseButton == MouseLeftButton then
		local clickedWidget = modules.game_interface.getRootPanel():recursiveGetChildByPos(mousePosition, false)

		if clickedWidget then
			if clickedWidget:getClassName() == "UIGameMap" then
				local tile = clickedWidget:getTile(mousePosition)

				if tile then
					local thing = tile:getTopMoveThing()

					if thing and thing:isItem() then
						item = thing
					end
				end
			elseif clickedWidget:getClassName() == "UIItem" and not clickedWidget:isVirtual() then
				item = clickedWidget:getItem()
			end
		end
	end

	if item and item:isPickupable() then
		Imbuement.setLastImbuementItemPick(item:getId(), item:getPosition(), item:getStackPos())
		g_game.selectImbuementItem(item:getId(), item:getPosition(), item:getStackPos())
	else
		modules.game_textmessage.displayFailureMessage(tr("Sorry, not possible."))
	end

	Imbuement:show()
	g_mouse.updateGrabber(self.pickItem, "target")
	self.pickItem:ungrabMouse()
	g_mouse.popCursor("target")

	return true
end
