-- chunkname: @/game_helper/helper_config.lua

HelperConfigTab = HelperConfigTab or {}
HelperConfigTab.DEFAULT_PROFILE_NAME = "Default"

local ctx, selectedProfileName
local currentLanguage = "en"
local suppressLanguageChange = false
local suppressQuickProfileChange = false
local profileInputBox
local QUICK_PROFILE_MAX_VISIBLE_ROWS = 7
local CONFIG_TEXT = {
	en = {
		delete = "Delete",
		save = "Save",
		savedProfiles = "Saved Profiles",
		no = "No",
		yes = "Yes",
		deleteConfirm = "Delete profile \"%s\"?",
		deletePreset = "Delete Preset",
		newPreset = "New Preset",
		new = "New",
		preset = "Preset:",
		sharedHotkey = "Target + Shooter Hotkey",
		generalSettings = "General Settings",
		autoSwitchHotkeyPreset = "Auto-Switch Hotkey Preset",
		load = "Load",
		autoSave = "Auto Save",
		language = "Language:",
		profileName = "Profile name:"
	},
	pt = {
		delete = "Excluir",
		save = "Salvar",
		savedProfiles = "Perfis Salvos",
		no = "Nao",
		yes = "Sim",
		deleteConfirm = "Excluir o perfil \"%s\"?",
		deletePreset = "Excluir Perfil",
		newPreset = "Novo Perfil",
		new = "Novo",
		preset = "Perfil:",
		sharedHotkey = "Hotkey do Target + Shooter",
		generalSettings = "Configuracoes Gerais",
		autoSwitchHotkeyPreset = "Troca Automatica de Preset de Hotkeys",
		load = "Carregar",
		autoSave = "Salvar Auto",
		language = "Idioma:",
		profileName = "Nome do perfil:"
	}
}

local function normalizeLanguage(language)
	return language == "pt" and "pt" or "en"
end

local function configText(key)
	local selected = CONFIG_TEXT[currentLanguage] or CONFIG_TEXT.en

	return selected[key] or CONFIG_TEXT.en[key] or key
end

local function setWidgetText(id, text)
	if not ctx or not ctx.getWidget then
		return
	end

	local target = ctx.getWidget(id)

	if target and target.setText then
		target:setText(text)
	end
end

local function trimProfileName(name)
	if not name then
		return ""
	end

	return tostring(name):match("^%s*(.-)%s*$") or ""
end

local function profileTr(text, name)
	return tr(text, tostring(name or ""))
end

local function getProfileNameFromItem(item)
	if not item then
		return ""
	end

	if item.profileName and item.profileName ~= "" then
		return item.profileName
	end

	local lbl = item:recursiveGetChildById("itemLabel")

	return lbl and lbl:getText() or ""
end

function HelperConfigTab.getSelectedProfileName()
	return selectedProfileName
end

function HelperConfigTab.setSelectedProfileName(name)
	selectedProfileName = trimProfileName(name)

	if selectedProfileName == "" then
		selectedProfileName = nil
	end
end

function HelperConfigTab.syncProfileNameEdit(name)
	if not ctx or not ctx.getWidget then
		return
	end

	local edit = ctx.getWidget("configsNameEdit")

	if edit then
		edit:setText(name or "")
	end
end

local function getProfileList()
	return ctx and ctx.getWidget("configsProfileList")
end

local function getQuickProfileCombo()
	return ctx and ctx.getWidget("quickProfileCombo")
end

local function getSortedProfileNames(data)
	local names = {}

	for name in pairs(data and data.profiles or {}) do
		if type(name) == "string" and name ~= "" then
			table.insert(names, name)
		end
	end

	table.sort(names, function(a, b)
		return a:lower() < b:lower()
	end)

	return names
end

local function profileExists(names, wanted)
	for _, name in ipairs(names or {}) do
		if name == wanted then
			return true
		end
	end

	return false
end

function HelperConfigTab.getQuickProfileName()
	local combo = getQuickProfileCombo()
	local option = combo and combo.getCurrentOption and combo:getCurrentOption() or nil

	return trimProfileName(option and (option.data or option.text) or "")
end

function HelperConfigTab.refreshQuickProfileCombo(preferredName)
	local combo = getQuickProfileCombo()

	if not combo or not ctx or not ctx.readHelperJSON then
		return
	end

	local data = ctx.readHelperJSON()
	local names = getSortedProfileNames(data)

	combo.menuScroll = #names > QUICK_PROFILE_MAX_VISIBLE_ROWS

	local activeName = trimProfileName(preferredName or data.activeProfile or "")

	if not profileExists(names, activeName) then
		if profileExists(names, HelperConfigTab.DEFAULT_PROFILE_NAME) then
			activeName = HelperConfigTab.DEFAULT_PROFILE_NAME
		else
			activeName = names[1] or ""
		end
	end

	suppressQuickProfileChange = true

	combo:clearOptions()

	for _, name in ipairs(names) do
		combo:addOption(name, name)
	end

	if activeName ~= "" then
		if combo.setCurrentOptionByData then
			combo:setCurrentOptionByData(activeName, true)
		else
			combo:setCurrentOption(activeName, true)
		end
	end

	suppressQuickProfileChange = false

	local saveButton = ctx.getWidget("quickProfileSaveButton")

	if saveButton then
		saveButton:setEnabled(activeName ~= "")
	end

	local deleteButton = ctx.getWidget("quickProfileDeleteButton")

	if deleteButton then
		deleteButton:setEnabled(activeName ~= "" and activeName ~= HelperConfigTab.DEFAULT_PROFILE_NAME)
	end
end

local function selectProfileListItem(name)
	if not ctx or not ctx.getWidget then
		return
	end

	local list = getProfileList()

	if not list then
		return
	end

	for _, child in ipairs(list:getChildren()) do
		if getProfileNameFromItem(child) == name then
			list:focusChild(child, KeyboardFocusReason)
			HelperConfigTab.setSelectedProfileName(name)
			HelperConfigTab.syncProfileNameEdit(name)

			return
		end
	end
end

local function onProfileItemSelected(item)
	if not item then
		return
	end

	local name = getProfileNameFromItem(item)

	if name == "" then
		return
	end

	HelperConfigTab.setSelectedProfileName(name)
	HelperConfigTab.syncProfileNameEdit(name)
end

function HelperConfigTab.refreshProfileList()
	if not ctx or not ctx.getWidget then
		return
	end

	local data = ctx.readHelperJSON()

	HelperConfigTab.refreshQuickProfileCombo(data.activeProfile)

	local list = getProfileList()

	if not list then
		return
	end

	list:destroyChildren()

	local names = getSortedProfileNames(data)

	for idx, name in ipairs(names) do
		local widgetType = idx % 2 == 1 and "ProfileListItemOdd" or "ProfileListItemEven"
		local item = g_ui.createWidget(widgetType, list)

		item.profileName = name

		item:setId("profileItem_" .. name:gsub("[^%w]", "_"))

		local lbl = item:recursiveGetChildById("itemLabel")

		if lbl then
			lbl:setText(name)
		end

		connect(item, {
			onFocusChange = function(self, focused)
				if focused then
					onProfileItemSelected(self)
				end
			end
		})
	end

	if selectedProfileName then
		selectProfileListItem(selectedProfileName)
	end
end

local function resolveProfileName(preferEdit)
	if not ctx or not ctx.getWidget then
		return selectedProfileName
	end

	if not preferEdit then
		local list = getProfileList()

		if list then
			local focused = list:getFocusedChild()

			if focused then
				local name = getProfileNameFromItem(focused)

				if name ~= "" then
					HelperConfigTab.setSelectedProfileName(name)

					return name
				end
			end
		end

		if selectedProfileName and selectedProfileName ~= "" then
			return selectedProfileName
		end
	end

	local edit = ctx.getWidget("configsNameEdit")
	local name = trimProfileName(edit and edit:getText() or "")

	if name ~= "" then
		HelperConfigTab.setSelectedProfileName(name)

		return name
	end

	return nil
end

function HelperConfigTab.isOtherProfileSelected()
	return selectedProfileName and selectedProfileName ~= "" and selectedProfileName ~= HelperConfigTab.DEFAULT_PROFILE_NAME
end

function HelperConfigTab.getProfileNameForAutoSave()
	if not ctx or not ctx.isAutoSaveEnabled or not ctx.isAutoSaveEnabled() then
		return nil
	end

	if not ctx.readHelperJSON then
		return nil
	end

	local data = ctx.readHelperJSON()
	local activeName = trimProfileName(data.activeProfile)

	if activeName ~= "" and type(data.profiles) == "table" and type(data.profiles[activeName]) == "table" then
		return activeName
	end

	return HelperConfigTab.DEFAULT_PROFILE_NAME
end

function HelperConfigTab.selectProfileInList(name)
	if not name or name == "" then
		return
	end

	selectProfileListItem(name)
end

function HelperConfigTab.initProfilesPanel()
	local list = getProfileList()

	if list then
		connect(list, {
			onChildFocusChange = function(_, focusedChild)
				onProfileItemSelected(focusedChild)
			end
		})
	end

	local data = ctx.readHelperJSON()

	HelperConfigTab.setLanguage(data.language, false)
	HelperConfigTab.setSelectedProfileName(data.activeProfile)
	HelperConfigTab.syncProfileNameEdit(selectedProfileName or "")

	if ctx.applyAutoSavePreferenceToCheckbox then
		ctx.applyAutoSavePreferenceToCheckbox(data.autoSaveEnabled ~= false)
	end

	HelperConfigTab.refreshAutoSwitchHotkeyPreset()
	HelperConfigTab.refreshProfileList()
end

function HelperConfigTab.initQuickProfileBar()
	local combo = getQuickProfileCombo()

	if not combo then
		return
	end

	function combo.onOptionChange(_, text, data)
		if suppressQuickProfileChange then
			return
		end

		local name = trimProfileName(data or text)

		if name == "" then
			return
		end

		HelperConfigTab.loadProfile(name)
	end
end

function HelperConfigTab.getLanguage()
	return currentLanguage
end

function HelperConfigTab.toggleLanguage()
	HelperConfigTab.setLanguage(currentLanguage == "pt" and "en" or "pt", true)
end

function HelperConfigTab.refreshLanguage(language)
	currentLanguage = normalizeLanguage(language or currentLanguage)

	setWidgetText("configsProfilesTitle", configText("savedProfiles"))
	setWidgetText("configsLoadBtn", configText("load"))
	setWidgetText("configsSaveBtn", configText("save"))
	setWidgetText("configsDeleteBtn", configText("delete"))
	setWidgetText("configsNameLabel", configText("profileName"))
	setWidgetText("configsLanguageLabel", configText("language"))
	setWidgetText("configsAutoSaveLabel", configText("autoSave"))
	setWidgetText("configsAutoSwitchHotkeyPresetLabel", configText("autoSwitchHotkeyPreset"))
	setWidgetText("configsGeneralSection", configText("generalSettings"))
	setWidgetText("configsSharedHotkeyLabel", configText("sharedHotkey"))
	setWidgetText("quickProfileLabel", configText("preset"))
	setWidgetText("quickProfileNewButton", configText("new"))
	setWidgetText("quickProfileSaveButton", configText("save"))
	setWidgetText("quickProfileDeleteButton", configText("delete"))

	local combo = ctx and ctx.getWidget and ctx.getWidget("configsLanguageCombo") or nil

	if combo and combo.clearOptions and combo.addOption then
		suppressLanguageChange = true

		combo:clearOptions()
		combo:addOption("English", "en")
		combo:addOption("Portugues", "pt")

		if combo.setCurrentOptionByData then
			combo:setCurrentOptionByData(currentLanguage, true)
		else
			combo:setCurrentOption(currentLanguage == "pt" and "Portugues" or "English", true)
		end

		suppressLanguageChange = false
	end
end

function HelperConfigTab.setLanguage(language, persist)
	currentLanguage = normalizeLanguage(language)

	if ctx and ctx.applyLanguage then
		ctx.applyLanguage(currentLanguage)
	else
		HelperConfigTab.refreshLanguage(currentLanguage)
	end

	if persist == false or not ctx or not ctx.readHelperJSON or not ctx.writeHelperJSON then
		return
	end

	if ctx.isLoadingConfig and ctx.isLoadingConfig() then
		return
	end

	local data = ctx.readHelperJSON()

	if data.language ~= currentLanguage then
		data.language = currentLanguage

		ctx.writeHelperJSON(data)
	end
end

function HelperConfigTab.initLanguageSelector()
	local combo = ctx and ctx.getWidget and ctx.getWidget("configsLanguageCombo") or nil

	if not combo then
		return
	end

	function combo.onOptionChange(_, _, data)
		if suppressLanguageChange or not data then
			return
		end

		HelperConfigTab.setLanguage(data, true)
	end

	HelperConfigTab.refreshLanguage(currentLanguage)
end

function HelperConfigTab.openProfileWindow()
	if ctx.openHelperWindow then
		ctx.openHelperWindow()
	end

	HelperConfigTab.refreshProfileList()
end

function HelperConfigTab.saveProfile(explicitName)
	if not ctx or not ctx.getWidget then
		return
	end

	local name = explicitName ~= nil and trimProfileName(explicitName) or resolveProfileName(true)

	if not name or name == "" then
		if ctx.log then
			ctx.log("info", "[PROFILE] Save aborted (empty name): " .. tostring(name))
		end

		if ctx.showMessage then
			ctx.showMessage(true, tr("Profile name cannot be empty."))
		end

		return
	end

	if ctx.log then
		ctx.log("info", "[PROFILE] Saving: " .. tostring(name))
	end

	if ctx.cancelAutoSave then
		ctx.cancelAutoSave()
	end

	local data = ctx.readHelperJSON()

	data.profiles = data.profiles or {}

	local isOverwrite = data.profiles[name] ~= nil
	local snapshot = ctx.collectConfig()

	data.profiles[name] = ctx.copyConfig(snapshot)
	data.current = ctx.copyConfig(snapshot)
	data.activeProfile = name

	if ctx.isAutoSaveEnabled then
		data.autoSaveEnabled = ctx.isAutoSaveEnabled()
	end

	if not ctx.writeHelperJSON(data) then
		if ctx.showMessage then
			ctx.showMessage(true, tr("Failed to save profile."))
		end

		if ctx.log then
			ctx.log("error", "Save profile failed for \"" .. tostring(name) .. "\".")
		end

		return
	end

	if ctx.applyConfigSnapshot then
		ctx.applyConfigSnapshot(snapshot)
	end

	HelperConfigTab.setSelectedProfileName(name)
	HelperConfigTab.refreshProfileList()
	HelperConfigTab.syncProfileNameEdit(name)

	if ctx.log then
		ctx.log("info", "Profile saved: \"" .. tostring(name) .. "\".")
	end

	if ctx.showMessage then
		if isOverwrite then
			ctx.showMessage(false, profileTr("Profile \"%s\" updated.", name))
		else
			ctx.showMessage(false, profileTr("Profile \"%s\" created.", name))
		end
	end
end

function HelperConfigTab.loadProfile(explicitName)
	if not ctx or not ctx.getWidget then
		return
	end

	local name = explicitName ~= nil and trimProfileName(explicitName) or resolveProfileName(false)

	if not name or name == "" then
		if ctx.log then
			ctx.log("info", "[PROFILE] Load aborted (none selected): " .. tostring(name))
		end

		if ctx.showMessage then
			ctx.showMessage(true, tr("Select a profile to load."))
		end

		return
	end

	if ctx.log then
		ctx.log("info", "[PROFILE] Loading: " .. tostring(name))
	end

	if ctx.flushAutoSave then
		ctx.flushAutoSave()
	elseif ctx.cancelAutoSave then
		ctx.cancelAutoSave()
	end

	local data = ctx.readHelperJSON()
	local config = data.profiles and data.profiles[name]

	if type(config) ~= "table" then
		if ctx.showMessage then
			ctx.showMessage(true, profileTr("Profile \"%s\" not found.", name))
		end

		if ctx.log then
			ctx.log("error", "Load profile failed, not found: \"" .. tostring(name) .. "\".")
		end

		HelperConfigTab.refreshProfileList()

		return
	end

	local snapshot = ctx.copyConfig(config)

	data.current = ctx.copyConfig(snapshot)
	data.activeProfile = name

	if not ctx.writeHelperJSON(data) then
		if ctx.showMessage then
			ctx.showMessage(true, tr("Failed to load profile."))
		end

		if ctx.log then
			ctx.log("error", "Load profile failed to write JSON: \"" .. tostring(name) .. "\".")
		end

		HelperConfigTab.refreshQuickProfileCombo(data.activeProfile)

		return
	end

	if ctx.applyConfig then
		ctx.applyConfig(snapshot)
	end

	HelperConfigTab.setSelectedProfileName(name)
	HelperConfigTab.syncProfileNameEdit(name)

	if ctx.applyAutoSavePreferenceToCheckbox then
		ctx.applyAutoSavePreferenceToCheckbox(data.autoSaveEnabled ~= false)
	end

	HelperConfigTab.refreshProfileList()

	if ctx.log then
		ctx.log("info", "Profile loaded: \"" .. tostring(name) .. "\".")
	end

	if ctx.showMessage then
		ctx.showMessage(false, profileTr("Profile \"%s\" loaded.", name))
	end
end

function HelperConfigTab.deleteProfile(explicitName)
	if not ctx or not ctx.getWidget then
		return
	end

	local name = explicitName ~= nil and trimProfileName(explicitName) or resolveProfileName(false)

	if not name or name == "" then
		if ctx.log then
			ctx.log("info", "[PROFILE] Delete aborted (none selected): " .. tostring(name))
		end

		if ctx.showMessage then
			ctx.showMessage(true, tr("Select a profile to delete."))
		end

		return
	end

	if name == HelperConfigTab.DEFAULT_PROFILE_NAME then
		if ctx.showMessage then
			ctx.showMessage(true, tr("The Default profile cannot be deleted."))
		end

		return
	end

	if ctx.log then
		ctx.log("info", "[PROFILE] Deleting: " .. tostring(name))
	end

	if ctx.flushAutoSave then
		ctx.flushAutoSave()
	elseif ctx.cancelAutoSave then
		ctx.cancelAutoSave()
	end

	local data = ctx.readHelperJSON()

	if type(data.profiles) ~= "table" or data.profiles[name] == nil then
		if ctx.showMessage then
			ctx.showMessage(true, profileTr("Profile \"%s\" not found.", name))
		end

		if ctx.log then
			ctx.log("error", "Delete profile failed, not found: \"" .. tostring(name) .. "\".")
		end

		HelperConfigTab.refreshProfileList()

		return
	end

	local wasActive = data.activeProfile == name

	data.profiles[name] = nil

	local fallbackName = data.activeProfile

	if wasActive or type(data.profiles[fallbackName]) ~= "table" then
		fallbackName = HelperConfigTab.DEFAULT_PROFILE_NAME
	end

	local fallbackConfig = type(data.profiles[fallbackName]) == "table" and ctx.copyConfig(data.profiles[fallbackName]) or {}

	if wasActive then
		data.activeProfile = fallbackName
		data.current = ctx.copyConfig(fallbackConfig)
	end

	if not ctx.writeHelperJSON(data) then
		if ctx.showMessage then
			ctx.showMessage(true, tr("Failed to delete profile."))
		end

		if ctx.log then
			ctx.log("error", "Delete profile failed to write JSON: \"" .. tostring(name) .. "\".")
		end

		return
	end

	if ctx.log then
		ctx.log("info", "Profile deleted: \"" .. tostring(name) .. "\".")
	end

	if ctx.showMessage then
		ctx.showMessage(false, profileTr("Profile \"%s\" deleted.", name))
	end

	if wasActive and ctx.applyConfig then
		ctx.applyConfig(fallbackConfig)
	end

	HelperConfigTab.setSelectedProfileName(fallbackName)
	HelperConfigTab.syncProfileNameEdit(fallbackName or "")
	HelperConfigTab.refreshProfileList()
end

function HelperConfigTab.newQuickProfile()
	if not UIInputBox or not UIInputBox.create then
		if ctx and ctx.showMessage then
			ctx.showMessage(true, tr("Profile name input is unavailable."))
		end

		return
	end

	if profileInputBox and not profileInputBox:isDestroyed() then
		profileInputBox:destroy()
	end

	local inputBox

	inputBox = UIInputBox.create(configText("newPreset"), function(name)
		HelperConfigTab.saveProfile(name)
	end, function()
		profileInputBox = nil
	end)
	profileInputBox = inputBox

	local nameLabel = inputBox:addLabel(configText("profileName"))
	local nameEdit = inputBox:addLineEdit(nil, nil, 48)

	if nameLabel then
		nameLabel:setStyle("HelperProfileInputLabel")
		nameLabel:resizeToText()
	end

	if nameEdit then
		nameEdit:setStyle("HelperProfileInputLineEdit")
	end

	inputBox:display()
	inputBox:setStyle("HelperProfileInputBox")

	function inputBox.onDestroy()
		if profileInputBox == inputBox then
			profileInputBox = nil
		end
	end

	if nameEdit then
		nameEdit:focus()
	end
end

function HelperConfigTab.saveQuickProfile()
	local name = HelperConfigTab.getQuickProfileName()

	if name == "" then
		HelperConfigTab.newQuickProfile()

		return
	end

	HelperConfigTab.saveProfile(name)
end

function HelperConfigTab.deleteQuickProfile()
	local name = HelperConfigTab.getQuickProfileName()

	if name == "" or name == HelperConfigTab.DEFAULT_PROFILE_NAME then
		HelperConfigTab.deleteProfile(name)

		return
	end

	if not displayGeneralBox then
		HelperConfigTab.deleteProfile(name)

		return
	end

	local confirmBox

	local function closeConfirm()
		if confirmBox and not confirmBox:isDestroyed() then
			confirmBox:destroy()
		end

		confirmBox = nil
	end

	local function confirmDelete()
		closeConfirm()
		HelperConfigTab.deleteProfile(name)
	end

	confirmBox = displayGeneralBox(configText("deletePreset"), string.format(configText("deleteConfirm"), name), {
		{
			text = configText("yes"),
			callback = confirmDelete
		},
		{
			text = configText("no"),
			callback = closeConfirm
		}
	}, confirmDelete, closeConfirm)
end

function HelperConfigTab.init(pctx)
	ctx = pctx

	HelperConfigTab.initLanguageSelector()
	HelperConfigTab.initQuickProfileBar()
	HelperConfigTab.initProfilesPanel()
end

function HelperConfigTab.refreshAutoSwitchHotkeyPreset()
	if not ctx or not ctx.isAutoSwitchHotkeyPresetEnabled or not ctx.applyAutoSwitchHotkeyPresetToCheckbox then
		return
	end

	ctx.applyAutoSwitchHotkeyPresetToCheckbox(ctx.isAutoSwitchHotkeyPresetEnabled())
end

function HelperConfigTab.onShow()
	HelperConfigTab.refreshAutoSwitchHotkeyPreset()
	HelperConfigTab.refreshProfileList()
end

function HelperConfigTab.onHide()
	return
end

function HelperConfigTab.terminate()
	if profileInputBox and not profileInputBox:isDestroyed() then
		profileInputBox:destroy()
	end

	profileInputBox = nil
	selectedProfileName = nil
	currentLanguage = "en"
	suppressLanguageChange = false
	suppressQuickProfileChange = false
end

function HelperConfigTab.collectConfig(config)
	if ctx and ctx.isAutoSaveEnabled then
		config.autoSaveEnabled = ctx.isAutoSaveEnabled()
	end

	config.strictPzAuto = nil
	config.sharedCombatHotkey = tostring(config.sharedCombatHotkey or "")
	config.allowSharedCombatHotkey = nil
end

function HelperConfigTab.loadFromConfig(config)
	config = config or {}
	config.strictPzAuto = nil
	config.sharedCombatHotkey = tostring(config.sharedCombatHotkey or "")
	config.allowSharedCombatHotkey = nil
end
