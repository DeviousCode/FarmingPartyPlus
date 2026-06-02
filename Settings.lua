local ADDON_NAME = 'Farming Party Plus'
local ADDON_VERSION = '3.0.4'
local DEFAULT_MINIMUM_RECIPE_VALUE = 3000
local MINIMUM_RECIPE_VALUE = 100
local MAXIMUM_RECIPE_VALUE = 50000

local LAM2 = LibAddonMenu2

FarmingPartyPlusSettings = ZO_Object:Subclass()

local qualityChoiceValues = {
  ITEM_QUALITY_TRASH,
  ITEM_QUALITY_NORMAL,
  ITEM_QUALITY_MAGIC,
  ITEM_QUALITY_ARCANE,
  ITEM_QUALITY_ARTIFACT,
  ITEM_QUALITY_LEGENDARY
}

local qualityChoiceLabels = {'Trash', 'Normal', 'Fine', 'Superior', 'Epic', 'Legendary'}
local qualityValueByLabel = {}
for index, label in ipairs(qualityChoiceLabels) do
  qualityValueByLabel[label] = qualityChoiceValues[index]
end

local function ColoredHeader(text, color)
  return string.format('|c%s%s|r', color, text)
end

local function BuildWhitelistDefaults()
  local itemStates = {}
  for _, item in ipairs(FarmingPartyPlusItemCatalog.items) do
    itemStates[item.key] = item.defaultEnabled
  end
  return {
    enabled = true,
    items = itemStates,
    minimumRecipeValue = DEFAULT_MINIMUM_RECIPE_VALUE
  }
end

local function CopyTable(source)
  if type(source) ~= 'table' then
    return source
  end

  local copy = {}
  for key, value in pairs(source) do
    copy[key] = CopyTable(value)
  end
  return copy
end

FarmingPartyPlusSettings.TRACKING_STATUS = {
  ENABLED = 'ENABLED',
  DISABLED = 'DISABLED'
}

function FarmingPartyPlusSettings:New()
  local obj = ZO_Object.New(self)
  self:Initialize()
  return obj
end

function FarmingPartyPlusSettings:Initialize()
  local defaults = {
    excludeFromTracking = {
      gear = false,
      motifs = false
    },
    minimumLootQuality = qualityChoiceValues[1],
    trackGroupLoot = true,
    trackSelfLoot = true,
    displayOnWindow = true,
    displayOnChat = true,
    displayOwnLoot = true,
    displayGroupLoot = true,
    displayLootValue = true,
    manualHighscoreReset = true,
    lootWhitelist = BuildWhitelistDefaults(),
    whitelistProfiles = {},
    window = {
      transparency = 100,
      backgroundTransparency = 100,
      positionLeft = 0,
      positionTop = 0,
      width = 650,
      height = 150
    },
    itemsWindow = {
      transparency = 100,
      backgroundTransparency = 100,
      positionLeft = 0,
      positionTop = 150,
      width = 650,
      height = 150
    },
    filterWindow = {
      positionLeft = 100,
      positionTop = 100,
      width = 760,
      height = 620
    },
    logWindow = {
      backgroundTransparency = 100,
      positionLeft = 0,
      positionTop = 300,
      width = 400,
      height = 80,
      showTimestamp = true,
      timestampFormat = '[MM.DD.YYYY HH:mm:ss]'
    },
    status = self.TRACKING_STATUS.ENABLED,
    resetStatusOnLogout = false,
    chatPrefix = 'FARMING SCORES:',
    valueDecimals = 2
  }

  self.settings = ZO_SavedVars:New('FarmingPartyPlusSettings_db', 1, nil, defaults)
  self:NormalizeWhitelistSettings()

  FarmingPartyPlusWindow:SetHandler(
    'OnResizeStop',
    function(...)
      FarmingPartyPlus:WindowResizeHandler(...)
    end
  )

  local sceneFragment = ZO_HUDFadeSceneFragment:New(FarmingPartyPlusWindow)
  sceneFragment:SetConditional(function()
    return self:DisplayOnWindow()
  end)
  HUD_SCENE:AddFragment(sceneFragment)
  HUD_UI_SCENE:AddFragment(sceneFragment)

  self:SetWindowValues()

  local panelData = {
    type = 'panel',
    name = ADDON_NAME,
    displayName = ADDON_NAME,
    author = 'DeviousCode',
    version = ADDON_VERSION,
    slashCommand = '/fpp',
    registerForRefresh = true,
    registerForDefaults = true
  }

  LAM2:RegisterAddonPanel('FarmingPartyPlusPanel', panelData)

  local optionsTable = {
    {
      type = 'header',
      name = ColoredHeader('Tracking Mode', 'D9B45A'),
      width = 'full'
    },
    {
      type = 'checkbox',
      name = 'Use item whitelist mode',
      tooltip = 'Only count the selected whitelist items. This is the clean node-farming mode.',
      getFunc = function()
        return self:UseWhitelistMode()
      end,
      setFunc = function(value)
        self:SetWhitelistMode(value)
      end,
      width = 'full'
    },
    {
      type = 'button',
      name = 'Open item whitelist',
      tooltip = 'Open the Farming Party Plus item toggle grid.',
      func = function()
        FarmingPartyPlus.Modules.FilterWindow:OpenWindow()
      end,
      width = 'full'
    },
    {
      type = 'description',
      text = 'Whitelist mode is best for farming events. Legacy mode uses the quality and category filters below.',
      width = 'full'
    },
    {
      type = 'description',
      text = '|cCC4444Note: some setting changes fully persist after /reloadui, logout, or exit. This addon will not force a reload.|r',
      width = 'full'
    },
    {
      type = 'dropdown',
      name = 'Minimum Item Quality',
      choices = qualityChoiceLabels,
      choicesValues = qualityChoiceValues,
      tooltip = 'Used when whitelist mode is off.',
      getFunc = function()
        return self:MinimumLootQuality()
      end,
      setFunc = function(value)
        self:ToggleMinimumLootQuality(value)
      end,
      width = 'full'
    },
    {
      type = 'header',
      name = ColoredHeader('Loot Sources', '6BC4B2'),
      width = 'full'
    },
    {
      type = 'checkbox',
      name = 'Self',
      tooltip = 'Track items looted by you.',
      getFunc = function()
        return self:TrackSelfLoot()
      end,
      setFunc = function(value)
        self:ToggleTrackSelfLoot(value)
      end,
      width = 'full'
    },
    {
      type = 'checkbox',
      name = 'Group members',
      tooltip = 'Track items looted by group members.',
      getFunc = function()
        return self:TrackGroupLoot()
      end,
      setFunc = function(value)
        self:ToggleTrackGroupLoot(value)
      end,
      width = 'full'
    },
    {
      type = 'checkbox',
      name = 'Disable tracking on logout',
      tooltip = 'This will cause tracking to be disabled on every logout.',
      getFunc = function()
        return self:ResetStatusOnLogout()
      end,
      setFunc = function(value)
        self:ToggleResetStatusOnLogout(value)
      end,
      width = 'full'
    },
    {
      type = 'header',
      name = ColoredHeader('Legacy Filters', '9D8CFF'),
      width = 'full'
    },
    {
      type = 'checkbox',
      name = 'Gear',
      tooltip = 'Track gear items when whitelist mode is off.',
      getFunc = function()
        return self:TrackGearLoot()
      end,
      setFunc = function(value)
        self:ToggleTrackGearLoot(value)
      end,
      width = 'full'
    },
    {
      type = 'checkbox',
      name = 'Motifs',
      tooltip = 'Track motifs when whitelist mode is off.',
      getFunc = function()
        return self:TrackMotifLoot()
      end,
      setFunc = function(value)
        self:ToggleTrackMotifLoot(value)
      end,
      width = 'full'
    },
    {
      type = 'header',
      name = ColoredHeader('Display', 'E07A5F'),
      width = 'full'
    },
    {
      type = 'checkbox',
      name = 'Log own loot',
      tooltip = 'Show or hide the loot you get.',
      getFunc = function()
        return self:DisplayOwnLoot()
      end,
      setFunc = function(value)
        self:ToggleOwnLoot(value)
      end,
      width = 'full'
    },
    {
      type = 'checkbox',
      name = 'Log group loot',
      tooltip = 'Show or hide the loot group members get.',
      getFunc = function()
        return self:DisplayGroupLoot()
      end,
      setFunc = function(value)
        self:ToggleGroupLootDisplay(value)
      end,
      width = 'full'
    },
    {
      type = 'checkbox',
      name = 'Show loot value',
      tooltip = 'Show or hide loot value on chat/window.',
      getFunc = function()
        return self:DisplayLootValue()
      end,
      setFunc = function(value)
        self:ToggleLootValue(value)
      end,
      width = 'full'
    },
    {
      type = 'checkbox',
      name = 'Log to chat',
      tooltip = 'Show or hide loot on chat.',
      getFunc = function()
        return self:DisplayInChat()
      end,
      setFunc = function(value)
        self:ToggleOnChat(value)
      end,
      width = 'full'
    },
    {
      type = 'checkbox',
      name = 'Log to loot window',
      tooltip = 'Show or hide loot on the loot window.',
      getFunc = function()
        return self:DisplayOnWindow()
      end,
      setFunc = function(value)
        self:ToggleOnWindow(value)
      end,
      width = 'full'
    },
    {
      type = 'checkbox',
      name = 'Show timestamp on loot window',
      tooltip = 'Show or hide timestamp on the window.',
      getFunc = function()
        return self:ShowWindowTimestamp()
      end,
      setFunc = function(value)
        self:SetShowWindowTimestamp(value)
      end,
      width = 'full'
    },
    {
      type = 'editbox',
      name = 'Timestamp Format',
      tooltip = 'Change the format of the loot window timestamp.',
      getFunc = function()
        return self:GetSettings().logWindow.timestampFormat
      end,
      setFunc = function(value)
        self:SetTimestampFormat(value)
      end,
      width = 'full'
    },
    {
      type = 'slider',
      name = 'Value decimal places',
      min = 0,
      max = 2,
      step = 1,
      tooltip = 'Decimal places to show for item values.',
      getFunc = function()
        return self:ValueDecimals()
      end,
      setFunc = function(value)
        self:SetValueDecimals(value)
      end,
      width = 'full'
    },
    {
      type = 'header',
      name = ColoredHeader('Windows', '4DA3FF'),
      width = 'full'
    },
    {
      type = 'slider',
      name = 'Loot window background opacity',
      tooltip = 'Change the opacity of the background of the loot window.',
      min = 0,
      max = 100,
      step = 5,
      getFunc = function()
        return self:GetSettings().logWindow.backgroundTransparency
      end,
      setFunc = function(value)
        self:SetWindowBackgroundTransparency(value)
      end,
      width = 'full'
    },
    {
      type = 'slider',
      name = 'Member window background opacity',
      tooltip = 'Change the opacity of the background of the member window.',
      min = 0,
      max = 100,
      step = 5,
      getFunc = function()
        return self:GetSettings().window.backgroundTransparency
      end,
      setFunc = function(value)
        FarmingPartyPlus.Modules.MemberList:SetWindowBackgroundTransparency(value)
      end,
      width = 'full'
    },
    {
      type = 'slider',
      name = 'Member window opacity',
      tooltip = 'Change the opacity of the member window.',
      min = 0,
      max = 100,
      step = 5,
      getFunc = function()
        return self:GetSettings().window.transparency
      end,
      setFunc = function(value)
        FarmingPartyPlus.Modules.MemberList:SetWindowTransparency(value)
      end,
      width = 'full'
    },
    {
      type = 'slider',
      name = 'Member items window background opacity',
      tooltip = 'Change the opacity of the background of the member items window.',
      min = 0,
      max = 100,
      step = 5,
      getFunc = function()
        return self:GetSettings().itemsWindow.backgroundTransparency
      end,
      setFunc = function(value)
        FarmingPartyPlus.Modules.MemberItems:SetWindowBackgroundTransparency(value)
      end,
      width = 'full'
    },
    {
      type = 'slider',
      name = 'Member items window opacity',
      tooltip = 'Change the opacity of the member items window.',
      min = 0,
      max = 100,
      step = 5,
      getFunc = function()
        return self:GetSettings().itemsWindow.transparency
      end,
      setFunc = function(value)
        FarmingPartyPlus.Modules.MemberItems:SetWindowTransparency(value)
      end,
      width = 'full'
    },
    {
      type = 'header',
      name = ColoredHeader('Chat', '7BC96F'),
      width = 'full'
    },
    {
      type = 'editbox',
      name = 'Scores to Chat Prefix',
      tooltip = "Change the text that's output before scores when using /fppc.",
      getFunc = function()
        return self:ChatPrefix()
      end,
      setFunc = function(value)
        self:SetChatPrefix(value)
      end,
      width = 'full'
    }
  }

  LAM2:RegisterOptionControls('FarmingPartyPlusPanel', optionsTable)
end

function FarmingPartyPlus:WindowResizeHandler(control)
  local width, height = control:GetDimensions()
  FarmingPartyPlus.Settings:GetSettings().logWindow.width = width
  FarmingPartyPlus.Settings:GetSettings().logWindow.height = height
  local textBuffer = FarmingPartyPlusWindow:GetNamedChild('Buffer')
  textBuffer:SetHeight(height)
  textBuffer:SetWidth(width)
end

function FarmingPartyPlusSettings:NormalizeWhitelistSettings()
  local whitelist = self.settings.lootWhitelist
  if whitelist.items == nil then
    whitelist.items = {}
  end
  if whitelist.minimumRecipeValue == nil then
    whitelist.minimumRecipeValue = DEFAULT_MINIMUM_RECIPE_VALUE
  end
  whitelist.minimumRecipeValue = zo_clamp(tonumber(whitelist.minimumRecipeValue) or DEFAULT_MINIMUM_RECIPE_VALUE, MINIMUM_RECIPE_VALUE, MAXIMUM_RECIPE_VALUE)
  for _, item in ipairs(FarmingPartyPlusItemCatalog.items) do
    if whitelist.items[item.key] == nil then
      whitelist.items[item.key] = item.defaultEnabled
    end
  end
end

function FarmingPartyPlusSettings:GetSettings()
  return self.settings
end

function FarmingPartyPlusSettings:GetWhitelistProfiles()
  if self.settings.whitelistProfiles == nil then
    self.settings.whitelistProfiles = {}
  end
  return self.settings.whitelistProfiles
end

function FarmingPartyPlusSettings:MinimumLootQuality()
  local value = self.settings.minimumLootQuality
  if type(value) == 'string' then
    value = qualityValueByLabel[value] or tonumber(value) or ITEM_QUALITY_TRASH
    self.settings.minimumLootQuality = value
  end
  return value
end

function FarmingPartyPlusSettings:TrackMotifLoot()
  return not self.settings.excludeFromTracking.motifs
end

function FarmingPartyPlusSettings:TrackGearLoot()
  return not self.settings.excludeFromTracking.gear
end

function FarmingPartyPlusSettings:TrackGroupLoot()
  return self.settings.trackGroupLoot
end

function FarmingPartyPlusSettings:TrackSelfLoot()
  return self.settings.trackSelfLoot
end

function FarmingPartyPlusSettings:DisplayInChat()
  return self.settings.displayOnChat
end

function FarmingPartyPlusSettings:DisplayOnWindow()
  return self.settings.displayOnWindow
end

function FarmingPartyPlusSettings:DisplayOwnLoot()
  return self.settings.displayOwnLoot
end

function FarmingPartyPlusSettings:DisplayGroupLoot()
  return self.settings.displayGroupLoot
end

function FarmingPartyPlusSettings:DisplayLootValue()
  return self.settings.displayLootValue
end

function FarmingPartyPlusSettings:ChatPrefix()
  return self.settings.chatPrefix
end

function FarmingPartyPlusSettings:Status()
  return self.settings.status
end

function FarmingPartyPlusSettings:ResetStatusOnLogout()
  return self.settings.resetStatusOnLogout
end

function FarmingPartyPlusSettings:Window()
  return self.settings.window
end

function FarmingPartyPlusSettings:ItemsWindow()
  return self.settings.itemsWindow
end

function FarmingPartyPlusSettings:FilterWindow()
  return self.settings.filterWindow
end

function FarmingPartyPlusSettings:ValueDecimals()
  return self.settings.valueDecimals
end

function FarmingPartyPlusSettings:UseWhitelistMode()
  return self.settings.lootWhitelist.enabled
end

function FarmingPartyPlusSettings:SetWhitelistMode(value)
  self.settings.lootWhitelist.enabled = value
end

function FarmingPartyPlusSettings:IsWhitelistedItem(itemKey)
  self:NormalizeWhitelistSettings()
  if self.settings.lootWhitelist.items[itemKey] == true then
    return true
  end

  local normalizedKeys = {
    itemKey
  }

  if zo_plainstrfind(itemKey, 'raw ') == 1 then
    normalizedKeys[#normalizedKeys + 1] = zo_strsub(itemKey, 5)
  end
  if zo_plainstrfind(itemKey, 'rough ') == 1 then
    normalizedKeys[#normalizedKeys + 1] = zo_strsub(itemKey, 7)
  end

  for _, normalizedKey in ipairs(normalizedKeys) do
    if self.settings.lootWhitelist.items[normalizedKey] == true then
      return true
    end
  end

  return false
end

function FarmingPartyPlusSettings:IsWhitelistRuleEnabled(ruleKey)
  self:NormalizeWhitelistSettings()
  return self.settings.lootWhitelist.items[ruleKey] == true
end

function FarmingPartyPlusSettings:SetWhitelistedItem(itemKey, value)
  self:NormalizeWhitelistSettings()
  self.settings.lootWhitelist.items[itemKey] = value
end

function FarmingPartyPlusSettings:MinimumRecipeValue()
  self:NormalizeWhitelistSettings()
  return self.settings.lootWhitelist.minimumRecipeValue
end

function FarmingPartyPlusSettings:SetMinimumRecipeValue(value)
  self:NormalizeWhitelistSettings()
  self.settings.lootWhitelist.minimumRecipeValue = zo_clamp(tonumber(value) or DEFAULT_MINIMUM_RECIPE_VALUE, MINIMUM_RECIPE_VALUE, MAXIMUM_RECIPE_VALUE)
end

function FarmingPartyPlusSettings:AdjustMinimumRecipeValue(delta)
  self:SetMinimumRecipeValue(self:MinimumRecipeValue() + (tonumber(delta) or 0))
end

function FarmingPartyPlusSettings:GetWhitelistProfileNames()
  local names = {}
  for profileName in pairs(self:GetWhitelistProfiles()) do
    names[#names + 1] = profileName
  end
  table.sort(names, function(left, right)
    return zo_strlower(left) < zo_strlower(right)
  end)
  return names
end

function FarmingPartyPlusSettings:SaveWhitelistProfile(profileName)
  if profileName == nil or profileName == '' then
    return false
  end

  self:NormalizeWhitelistSettings()
  self:GetWhitelistProfiles()[profileName] = CopyTable(self.settings.lootWhitelist)
  return true
end

function FarmingPartyPlusSettings:DeleteWhitelistProfile(profileName)
  if profileName == nil or profileName == '' then
    return false
  end

  local profiles = self:GetWhitelistProfiles()
  if profiles[profileName] == nil then
    return false
  end

  profiles[profileName] = nil
  return true
end

function FarmingPartyPlusSettings:LoadWhitelistProfile(profileName)
  local profile = self:GetWhitelistProfiles()[profileName]
  if profile == nil then
    return false
  end

  self.settings.lootWhitelist = CopyTable(profile)
  self:NormalizeWhitelistSettings()
  return true
end

function FarmingPartyPlusSettings:ToggleAllWhitelistItems(value)
  for _, item in ipairs(FarmingPartyPlusItemCatalog.items) do
    self.settings.lootWhitelist.items[item.key] = value
  end
end

function FarmingPartyPlusSettings:ToggleWhitelistCategory(categoryKey, value)
  for _, item in ipairs(FarmingPartyPlusItemCatalog.items) do
    if item.category == categoryKey then
      self.settings.lootWhitelist.items[item.key] = value
    end
  end
end

function FarmingPartyPlusSettings:MoveStart()
  FarmingPartyPlusWindowBG:SetAlpha(1)
end

function FarmingPartyPlusSettings:MoveStop()
  FarmingPartyPlusWindowBG:SetAlpha(self.settings.logWindow.backgroundTransparency / 100)
  self.settings.logWindow.positionLeft = math.floor(FarmingPartyPlusWindow:GetLeft())
  self.settings.logWindow.positionTop = math.floor(FarmingPartyPlusWindow:GetTop())
end

function FarmingPartyPlusSettings:SetWindowValues()
  local left = self.settings.logWindow.positionLeft
  local top = self.settings.logWindow.positionTop
  local height = self.settings.logWindow.height
  local width = self.settings.logWindow.width
  local display = self.settings.displayOnWindow

  FarmingPartyPlusWindow:ClearAnchors()
  FarmingPartyPlusWindow:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
  FarmingPartyPlusWindow:SetDimensions(width, height)
  FarmingPartyPlusWindow:GetNamedChild('BG'):SetAlpha(self.settings.logWindow.backgroundTransparency / 100)
  FarmingPartyPlusWindow:SetHidden(not display)

  FarmingPartyPlusWindowBuffer:ClearAnchors()
  FarmingPartyPlusWindowBuffer:SetAnchor(TOPLEFT, FarmingPartyPlusWindow, TOPLEFT, 0, 0)
  FarmingPartyPlusWindowBuffer:SetWidth(width)
  FarmingPartyPlusWindowBuffer:SetHeight(height)

  local face = ZoFontEditChat:GetFontInfo()
  local fontSize = GetChatFontSize()
  local decoration = (fontSize <= 14 and 'soft-shadow-thin' or 'soft-shadow-thick')
  FarmingPartyPlusWindowBuffer:SetFont(zo_strjoin('|', face, fontSize, decoration))
end

function FarmingPartyPlusSettings:SetWindowBackgroundTransparency(value)
  if value ~= nil then
    self.settings.logWindow.backgroundTransparency = value
  end
  FarmingPartyPlusWindow:GetNamedChild('BG'):SetAlpha(self.settings.logWindow.backgroundTransparency / 100)
end

function FarmingPartyPlusSettings:ToggleMinimumLootQuality(value)
  if type(value) == 'string' then
    value = qualityValueByLabel[value] or tonumber(value) or ITEM_QUALITY_TRASH
  end
  self.settings.minimumLootQuality = tonumber(value) or ITEM_QUALITY_TRASH
end

function FarmingPartyPlusSettings:ToggleTrackMotifLoot(value)
  self.settings.excludeFromTracking.motifs = not value
end

function FarmingPartyPlusSettings:ToggleTrackGearLoot(value)
  self.settings.excludeFromTracking.gear = not value
end

function FarmingPartyPlusSettings:ToggleTrackGroupLoot(value)
  self.settings.trackGroupLoot = value
end

function FarmingPartyPlusSettings:ToggleTrackSelfLoot(value)
  self.settings.trackSelfLoot = value
end

function FarmingPartyPlusSettings:ToggleOnChat(value)
  self.settings.displayOnChat = value
end

function FarmingPartyPlusSettings:ToggleOnWindow(value)
  self.settings.displayOnWindow = value
  self:SetWindowValues()
end

function FarmingPartyPlusSettings:ToggleLootWindow()
  self:ToggleOnWindow(not self:DisplayOnWindow())
end

function FarmingPartyPlusSettings:ToggleOwnLoot(value)
  self.settings.displayOwnLoot = value
end

function FarmingPartyPlusSettings:ToggleGroupLootDisplay(value)
  self.settings.displayGroupLoot = value
end

function FarmingPartyPlusSettings:ToggleLootValue(value)
  self.settings.displayLootValue = value
end

function FarmingPartyPlusSettings:ToggleStatusValue(value)
  self.settings.status = value
end

function FarmingPartyPlusSettings:ToggleResetStatusOnLogout(value)
  self.settings.resetStatusOnLogout = value
end

function FarmingPartyPlusSettings:SetChatPrefix(value)
  self.settings.chatPrefix = value
end

function FarmingPartyPlusSettings:SetTimestampFormat(value)
  self.settings.logWindow.timestampFormat = value
end

function FarmingPartyPlusSettings:ShowWindowTimestamp()
  return self.settings.logWindow.showTimestamp
end

function FarmingPartyPlusSettings:SetShowWindowTimestamp(value)
  self.settings.logWindow.showTimestamp = value
end

function FarmingPartyPlusSettings:SetValueDecimals(value)
  self.settings.valueDecimals = value
end
