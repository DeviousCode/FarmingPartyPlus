local ADDON_NAME = 'FarmingPartyPlus'
local RELEASE_COUNT = 1

local listContainer
local members = {}
local saveData = {}
local Settings

FarmingPartyPlusMemberList = ZO_Object:Subclass()

function FarmingPartyPlusMemberList:New()
  local obj = ZO_Object.New(self)
  self:Initialize()
  return obj
end

function FarmingPartyPlusMemberList:Initialize()
  saveData = ZO_SavedVars:New('FarmingPartyPlusMemberList_db', RELEASE_COUNT, nil, { members = {} })
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
  Settings:ToggleStatusValue(Settings.TRACKING_STATUS.ENABLED)
end

function FarmingPartyPlusMemberList:RemoveEventHandlers()
  EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_GROUP_MEMBER_JOINED)
  EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_GROUP_MEMBER_LEFT)
  Settings:ToggleStatusValue(Settings.TRACKING_STATUS.DISABLED)
end

function FarmingPartyPlusMemberList:Finalize()
  Settings:Window().positionLeft = FarmingPartyPlusMembersWindow:GetLeft()
  Settings:Window().positionTop = FarmingPartyPlusMembersWindow:GetTop()
  Settings:Window().width = FarmingPartyPlusMembersWindow:GetWidth()
  Settings:Window().height = FarmingPartyPlusMembersWindow:GetHeight()
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
  ZO_ScrollList_Commit(listContainer)
end

function FarmingPartyPlusMemberList:OnMemberJoined()
  self:AddAllGroupMembers()
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
    member.id = memberKey
    memberArray[#memberArray + 1] = member
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
  GetControl(rowControl, 'FarmerId'):SetText(data.id)
  GetControl(rowControl, 'Farmer'):SetText(data.displayName)
  GetControl(rowControl, 'BestItemName'):SetText(data.bestItem.itemLink)
  GetControl(rowControl, 'TotalValue'):SetText(FarmingPartyPlus.FormatNumber(data.totalValue) .. 'g')
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

function FarmingPartyPlusMemberList:AddAllGroupMembers()
  for name, displayName in pairs(self:GetAllGroupMembers()) do
    if not members:HasMember(name) then
      members:SetMember(name, members:NewMember(name, displayName))
    end
  end
end

local function BuildScoreString(farmer)
  return farmer.displayName .. ': ' .. FarmingPartyPlus.FormatNumber(farmer.totalValue) .. 'g.'
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
  for _, farmer in ipairs(array) do
    farmingScores[#farmingScores + 1] = BuildScoreString(farmer)
  end
  StartChatInput(table.concat(farmingScores, ' '))
end
