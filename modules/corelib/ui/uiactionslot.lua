-- chunkname: @/corelib/ui/uiactionslot.lua

UIActionSlot = extends(UIItem, "UIActionSlot")

function UIActionSlot.create()
	local slot = UIActionSlot.internalCreate()

	slot.itemId = nil
	slot.words = nil
	slot.text = nil
	slot.hotkey = nil
	slot.useType = nil
	slot.autoSend = nil
	slot.parameter = nil
	slot.getTier = nil

	return slot
end

function UIActionSlot:onStyleApply(styleName, styleNode)
	local m = modules.game_actionbar

	if m and m.refreshActionSlotFrameClip then
		m.refreshActionSlotFrameClip(self)
	end
end
