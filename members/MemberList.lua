local ADDON_NAME = 'FarmingPartyPlus'
local RELEASE_COUNT = 1
local NORMAL_LAYOUT = {
  farmerHeaderWidth = 185,
  bestHeaderOffset = 25,
  bestHeaderWidth = 180,
  totalHeaderOffset = 25,
  totalHeaderWidth = 100,
  farmerRowWidth = 170,
  bestRowOffset = 25,
  bestRowWidth = 180,
  totalRowOffset = 25,
  totalRowWidth = 100,
  inspectOffset = 10
}
local COMPACT_LAYOUT = {
  farmerHeaderWidth = 215,
  totalHeaderOffset = 10,
  totalHeaderWidth = 116,
  farmerRowWidth = 205,
  totalRowOffset = 10,
  totalRowWidth = 116
}
local WORLD_NAME = GetWorldName()

local listContainer
local members = {}
local saveData = {}
local Settings

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

local function FormatDisplayName(displayName)
  if displayName == nil or displayName == '' then
    return '@Unknown'
  end
  if zo_plainstrfind(displayName, '@') == 1 then
    return displayName
  end
  return '@' .. displayName
end

FarmingPartyPlusMemberList = ZO_Object:Subclass()

function FarmingPartyPlusMemberList:New()
  local obj = ZO_Object.New(self)
  obj:Initialize()
  return obj
end

function FarmingPartyPlusMemberList:Initialize()
  local defaults = { members = {} }
  local legacySaveData = ZO_SavedVars:New('FarmingPartyPlusMemberList_db', RELEASE_COUNT, nil, defaults)
  saveData = ZO_SavedVars:New('FarmingPartyPlusMemberList_db', RELEASE_COUNT, WORLD_NAME, defaults)
  if type(saveData.members) ~= 'table' then
    saveData.members = {}
  end
  if next(saveData.members) == nil and type(legacySaveData.members) == 'table' and next(legacySaveData.members) ~= nil then
    saveData.members = CopyTable(legacySaveData.members)
  end

  FarmingPartyPlus.Modules.Members = FarmingPartyPlusMembers:New(saveData)
  members = FarmingPartyPlus.Modules.Members

  listContainer = FarmingPartyPlusMembersWindow:GetNamedChild('List')
  Settings = FarmingPartyPlus.Settings

  FarmingPartyPlusMembersWindow:ClearAnchors()
  FarmingPartyPlusMembersWindow:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, Settings:Window().positionLeft, Settings:Window().positionTop)
  FarmingPartyPlusMembersWindow:SetDimensions(Settings:Window().width, Settings:Window().height)
  FarmingPartyPlusMembersWindow:SetHandler('OnResizeStop', function(...)
    self:WindowResizeHandler(...)
  end)
  FarmingPartyPlusMembersWindow.onResize = self.onResize

  self:SetWindowTransparency()
  self:SetWindowBackgroundTransparency()
  self:AddAllGroupMembers()
  self:SetupScrollList()
  self:ApplyCompactMode()
  self:UpdateScrollList()

  if Settings:Status() == Settings.TRACKING_STATUS.ENABLED then
    self:AddEventHandlers()
  end

  members:RegisterCallback('OnKeysUpdated', self.UpdateScrollList)
end

function FarmingPartyPlusMemberList:AddEventHandlers()
  EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_GROUP_MEMBER_JOINED, function(...)
    self:OnMemberJoined(...)
  end)
  EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_GROUP_MEMBER_LEFT, function(...)
    self:OnMemberLeft(...)
  end)
  EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_GROUP_MEMBER_CONNECTED_STATUS, function(...)
    self:RefreshOnlineStates()
  end)
  EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_GROUP_UPDATE, function(...)
    self:RefreshOnlineStates()
  end)
  Settings:ToggleStatusValue(Settings.TRACKING_STATUS.ENABLED)
end

function FarmingPartyPlusMemberList:RemoveEventHandlers()
  EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_GROUP_MEMBER_JOINED)
  EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_GROUP_MEMBER_LEFT)
  EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_GROUP_MEMBER_CONNECTED_STATUS)
  EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_GROUP_UPDATE)
  Settings:ToggleStatusValue(Settings.TRACKING_STATUS.DISABLED)
end

function FarmingPartyPlusMemberList:Finalize()
  Settings:Window().positionLeft = FarmingPartyPlusMembersWindow:GetLeft()
  Settings:Window().positionTop = FarmingPartyPlusMembersWindow:GetTop()
  Settings:Window().width = FarmingPartyPlusMembersWindow:GetWidth()
  Settings:Window().height = FarmingPartyPlusMembersWindow:GetHeight()
  self:SaveCurrentDimensionsForMode(Settings:IsCompactMemberWindow())
  saveData.members = members:GetCleanMembers()
end

function FarmingPartyPlusMemberList:SetWindowTransparency(value)
  if value ~= nil then
    Settings:Window().transparency = value
  end
  FarmingPartyPlusMembersWindow:SetAlpha(Settings:Window().transparency / 100)
end

function FarmingPartyPlusMemberList:SetWindowBackgroundTransparency(value)
  if value ~= nil then
    Settings:Window().backgroundTransparency = value
  end
  FarmingPartyPlusMembersWindow:GetNamedChild('BG'):SetAlpha(Settings:Window().backgroundTransparency / 100)
end

function FarmingPartyPlusMemberList:WindowResizeHandler(control)
  local width, height = control:GetDimensions()
  Settings:Window().width = width
  Settings:Window().height = height
  self:SaveCurrentDimensionsForMode(Settings:IsCompactMemberWindow(), width, height)
  ZO_ScrollList_Commit(listContainer)
end

function FarmingPartyPlusMemberList:GetLayout()
  if Settings:IsCompactMemberWindow() then
    return COMPACT_LAYOUT
  end
  return NORMAL_LAYOUT
end

function FarmingPartyPlusMemberList:SaveCurrentDimensionsForMode(isCompact, width, height)
  local window = Settings:Window()
  local currentWidth = width or FarmingPartyPlusMembersWindow:GetWidth()
  local currentHeight = height or FarmingPartyPlusMembersWindow:GetHeight()
  if isCompact then
    window.compactWidth = currentWidth
    window.compactHeight = currentHeight
  else
    window.normalWidth = currentWidth
    window.normalHeight = currentHeight
  end
end

function FarmingPartyPlusMemberList:ApplyHeaderLayout(layout)
  local headers = FarmingPartyPlusMembersWindow:GetNamedChild('Headers')
  local farmerHeader = headers:GetNamedChild('Farmer')
  local bestItemHeader = headers:GetNamedChild('BestItemName')
  local totalValueHeader = headers:GetNamedChild('TotalValue')

  farmerHeader:SetWidth(layout.farmerHeaderWidth)
  bestItemHeader:SetHidden(Settings:IsCompactMemberWindow())
  bestItemHeader:ClearAnchors()
  totalValueHeader:ClearAnchors()

  if Settings:IsCompactMemberWindow() then
    totalValueHeader:SetAnchor(TOPLEFT, farmerHeader, TOPRIGHT, layout.totalHeaderOffset, 0)
  else
    bestItemHeader:SetAnchor(TOPLEFT, farmerHeader, TOPRIGHT, layout.bestHeaderOffset, 0)
    bestItemHeader:SetAnchor(BOTTOMLEFT, farmerHeader, BOTTOMRIGHT, layout.bestHeaderOffset, 0)
    bestItemHeader:SetWidth(layout.bestHeaderWidth)
    totalValueHeader:SetAnchor(TOPLEFT, bestItemHeader, TOPRIGHT, layout.totalHeaderOffset, 0)
  end

  totalValueHeader:SetWidth(layout.totalHeaderWidth)
end

function FarmingPartyPlusMemberList:ApplyRowLayout(rowControl, layout)
  local bestItemControl = GetControl(rowControl, 'BestItemName')
  local farmerButton = GetControl(rowControl, 'FarmerButton')
  local totalValueLabel = GetControl(rowControl, 'TotalValue')
  local inspectButton = GetControl(rowControl, 'InspectButton')

  farmerButton:SetWidth(layout.farmerRowWidth)
  bestItemControl:SetHidden(Settings:IsCompactMemberWindow())
  inspectButton:SetHidden(Settings:IsCompactMemberWindow())
  bestItemControl:ClearAnchors()
  totalValueLabel:ClearAnchors()

  if Settings:IsCompactMemberWindow() then
    totalValueLabel:SetAnchor(TOPLEFT, farmerButton, TOPRIGHT, layout.totalRowOffset, 0)
    totalValueLabel:SetAnchor(BOTTOMLEFT, farmerButton, BOTTOMRIGHT, layout.totalRowOffset, 0)
  else
    bestItemControl:SetAnchor(TOPLEFT, farmerButton, TOPRIGHT, layout.bestRowOffset, -3)
    bestItemControl:SetAnchor(BOTTOMLEFT, farmerButton, BOTTOMRIGHT, layout.bestRowOffset, 3)
    bestItemControl:SetWidth(layout.bestRowWidth)
    totalValueLabel:SetAnchor(TOPLEFT, bestItemControl, TOPRIGHT, layout.totalRowOffset, 0)
    totalValueLabel:SetAnchor(BOTTOMLEFT, bestItemControl, BOTTOMRIGHT, layout.totalRowOffset, 0)
    inspectButton:ClearAnchors()
    inspectButton:SetAnchor(LEFT, totalValueLabel, RIGHT, layout.inspectOffset, 0)
  end

  totalValueLabel:SetWidth(layout.totalRowWidth)
end

function FarmingPartyPlusMemberList:ApplyCompactMode()
  local windowSettings = Settings:Window()
  local layout = self:GetLayout()

  FarmingPartyPlusMembersWindow:SetDimensions(windowSettings.width, windowSettings.height)
  self:ApplyHeaderLayout(layout)
  ZO_ScrollList_Commit(listContainer)
end

function FarmingPartyPlusMemberList:OnMemberJoined()
  self:AddAllGroupMembers()
  self:RefreshOnlineStates()
end

function FarmingPartyPlusMemberList:OnMemberLeft(event, memberName, reason, wasLocalPlayer)
  if not wasLocalPlayer then
    local name = zo_strformat(SI_UNIT_NAME, memberName)
    members:DeleteMember(name)
  else
    local playerName = GetUnitName('player')
    for _, memberKey in ipairs(members:GetKeys()) do
      if memberKey ~= playerName then
        members:DeleteMember(memberKey)
      end
    end
  end
  self:RefreshOnlineStates()
end

function FarmingPartyPlusMemberList:SetupScrollList()
  ZO_ScrollList_AddResizeOnScreenResize(listContainer)
  ZO_ScrollList_AddDataType(listContainer, FarmingPartyPlus.DataTypes.MEMBER, 'FarmingPartyPlusMemberDataRow', 20, function(listControl, data)
    self:SetupMemberRow(listControl, data)
  end)
end

function FarmingPartyPlusMemberList:UpdateScrollList()
  local scrollData = ZO_ScrollList_GetDataList(listContainer)
  ZO_ScrollList_Clear(listContainer)

  local memberArray = {}
  for _, memberKey in ipairs(members:GetKeys()) do
    local member = members:GetMember(memberKey)
    memberArray[#memberArray + 1] = {
      id = memberKey,
      bestItem = member.bestItem,
      totalValue = member.totalValue,
      items = member.items,
      displayName = member.displayName,
      helperActive = member.helperActive,
      isOnline = member.isOnline ~= false
    }
  end

  table.sort(memberArray, function(left, right)
    if left.totalValue == right.totalValue then
      return left.displayName < right.displayName
    end
    return left.totalValue > right.totalValue
  end)

  for _, member in ipairs(memberArray) do
    scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(FarmingPartyPlus.DataTypes.MEMBER, { rawData = member })
  end

  ZO_ScrollList_Commit(listContainer)
end

function FarmingPartyPlusMemberList:SetupMemberRow(rowControl, rowData)
  rowControl.data = rowData
  local data = rowData.rawData
  self:ApplyRowLayout(rowControl, self:GetLayout())
  GetControl(rowControl, 'FarmerId'):SetText(data.id)
  local helperIcon = GetControl(rowControl, 'HelperStatusIcon')
  local isLocalPlayer = data.id == zo_strformat(SI_UNIT_NAME, GetUnitName('player'))
  local isOnline = data.isOnline ~= false
  if isLocalPlayer then
    helperIcon:SetText('H')
    if isOnline then
      helperIcon:SetColor(0.45, 0.95, 0.55, 1)
      helperIcon:SetAlpha(1)
    else
      helperIcon:SetColor(0.60, 0.60, 0.60, 1)
      helperIcon:SetAlpha(0.75)
    end
  elseif data.helperActive then
    helperIcon:SetText('*')
    if isOnline then
      helperIcon:SetColor(0.45, 0.95, 0.55, 1)
      helperIcon:SetAlpha(1)
    else
      helperIcon:SetColor(0.60, 0.60, 0.60, 1)
      helperIcon:SetAlpha(0.75)
    end
  else
    helperIcon:SetText('*')
    helperIcon:SetColor(0.70, 0.70, 0.70, 1)
    helperIcon:SetAlpha(isOnline and 0.65 or 0.35)
  end
  local farmerButton = GetControl(rowControl, 'FarmerButton')
  farmerButton:SetText(FormatDisplayName(data.displayName))
  if isOnline then
    farmerButton:SetNormalFontColor(0.36, 0.80, 1.00, 1)
    farmerButton:SetMouseOverFontColor(0.60, 0.90, 1.00, 1)
    farmerButton:SetPressedFontColor(0.25, 0.65, 0.92, 1)
  else
    farmerButton:SetNormalFontColor(0.62, 0.62, 0.62, 1)
    farmerButton:SetMouseOverFontColor(0.74, 0.74, 0.74, 1)
    farmerButton:SetPressedFontColor(0.52, 0.52, 0.52, 1)
  end
  GetControl(rowControl, 'BestItemName'):SetText(data.bestItem.itemLink)
  local totalValueLabel = GetControl(rowControl, 'TotalValue')
  totalValueLabel:SetHorizontalAlignment(Settings:IsCompactMemberWindow() and TEXT_ALIGN_CENTER or TEXT_ALIGN_RIGHT)
  if isOnline then
    totalValueLabel:SetColor(1, 1, 1, 1)
  else
    totalValueLabel:SetColor(0.62, 0.62, 0.62, 1)
  end
  totalValueLabel:SetText(FarmingPartyPlus.FormatNumber(data.totalValue) .. 'g')
end

function FarmingPartyPlusMemberList.onResize()
  ZO_ScrollList_Commit(listContainer)
end

function FarmingPartyPlusMemberList:ToggleMembersWindow()
  FarmingPartyPlusMembersWindow:SetHidden(not FarmingPartyPlusMembersWindow:IsHidden())
end

function FarmingPartyPlusMemberList:Reset()
  members:DeleteAllMembers()
  self:AddAllGroupMembers()
  self:RefreshOnlineStates()
end

function FarmingPartyPlusMemberList:GetAllGroupMembers()
  local countMembers = GetGroupSize()
  local rawMembers = {}
  local playerName = zo_strformat(SI_UNIT_NAME, GetUnitName('player'))
  rawMembers[playerName] = UndecorateDisplayName(GetDisplayName('player'))

  for i = 1, countMembers do
    local unitTag = GetGroupUnitTagByIndex(i)
    if unitTag then
      local name = zo_strformat(SI_UNIT_NAME, GetUnitName(unitTag))
      if name ~= playerName then
        rawMembers[name] = UndecorateDisplayName(GetUnitDisplayName(unitTag))
      end
    end
  end
  return rawMembers
end

function FarmingPartyPlusMemberList:RemoveMissingMembers(currentGroupMembers)
  for name in pairs(members:GetMembers()) do
    if currentGroupMembers[name] == nil then
      members:DeleteMember(name)
    end
  end
end

function FarmingPartyPlusMemberList:PruneMissingMembers()
  self:RemoveMissingMembers(self:GetAllGroupMembers())
end

function FarmingPartyPlusMemberList:SyncGroupMembers(currentGroupMembers)
  self:RemoveMissingMembers(currentGroupMembers)
  for name, displayName in pairs(currentGroupMembers) do
    if not members:HasMember(name) then
      members:SetMember(name, members:NewMember(name, displayName))
    else
      members:UpdateDisplayName(name, displayName)
    end
  end
end

function FarmingPartyPlusMemberList:AddAllGroupMembers()
  self:SyncGroupMembers(self:GetAllGroupMembers())
end

function FarmingPartyPlusMemberList:RefreshOnlineStates()
  local onlineByMemberKey = {}
  local localPlayerKey = zo_strformat(SI_UNIT_NAME, GetUnitName('player'))
  if localPlayerKey ~= '' then
    onlineByMemberKey[localPlayerKey] = true
  end

  for i = 1, GetGroupSize() do
    local unitTag = GetGroupUnitTagByIndex(i)
    if unitTag ~= nil and DoesUnitExist(unitTag) then
      local memberKey = zo_strformat(SI_UNIT_NAME, GetUnitName(unitTag))
      if memberKey ~= '' then
        onlineByMemberKey[memberKey] = IsUnitOnline(unitTag)
      end
    end
  end

  for _, memberKey in ipairs(members:GetKeys()) do
    members:SetOnlineState(memberKey, onlineByMemberKey[memberKey] == true)
  end
end

function FarmingPartyPlusMemberList:MarkHelperActive(characterName, displayName)
  if displayName ~= nil then
    local memberKey = members:GetMemberKeyByDisplayName(displayName)
    if memberKey ~= nil then
      members:SetHelperActive(memberKey, true)
      return
    end
  end

  local normalizedCharacterName = zo_strformat(SI_UNIT_NAME, characterName or '')
  if normalizedCharacterName ~= '' and members:HasMember(normalizedCharacterName) then
    members:SetHelperActive(normalizedCharacterName, true)
    return
  end

  self:AddAllGroupMembers()
  if displayName ~= nil then
    local memberKey = members:GetMemberKeyByDisplayName(displayName)
    if memberKey ~= nil then
      members:SetHelperActive(memberKey, true)
      return
    end
  end

  if normalizedCharacterName ~= '' and members:HasMember(normalizedCharacterName) then
    members:SetHelperActive(normalizedCharacterName, true)
    return
  end
end

local function BuildScoreString(rank, farmer)
  return string.format('%d. %s %sg', rank, FormatDisplayName(farmer.displayName), FarmingPartyPlus.FormatNumber(farmer.totalValue))
end

function FarmingPartyPlusMemberList:PrintScoresToChat()
  local array = {}
  for _, memberKey in ipairs(members:GetKeys()) do
    local member = members:GetMember(memberKey)
    array[#array + 1] = {
      name = memberKey,
      totalValue = member.totalValue,
      displayName = member.displayName
    }
  end

  table.sort(array, function(left, right)
    return left.totalValue > right.totalValue
  end)

  local farmingScores = { [1] = Settings:ChatPrefix() }
  for index, farmer in ipairs(array) do
    farmingScores[#farmingScores + 1] = BuildScoreString(index, farmer)
  end
  StartChatInput(table.concat(farmingScores, ' '))
end
