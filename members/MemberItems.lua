local listContainer
local memberKey = zo_strformat(SI_UNIT_NAME, GetUnitName('player'))
local members = {}
local Settings

FarmingPartyPlusMemberItems = ZO_Object:Subclass()

function FarmingPartyPlusMemberItems:New()
  local obj = ZO_Object.New(self)
  obj:Initialize()
  return obj
end

function FarmingPartyPlusMemberItems:Initialize()
  members = FarmingPartyPlus.Modules.Members
  Settings = FarmingPartyPlus.Settings
  listContainer = FarmingPartyPlusMemberItemsWindow:GetNamedChild('List')

  FarmingPartyPlusMemberItemsWindow:ClearAnchors()
  FarmingPartyPlusMemberItemsWindow:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, Settings:ItemsWindow().positionLeft, Settings:ItemsWindow().positionTop)
  FarmingPartyPlusMemberItemsWindow:SetDimensions(Settings:ItemsWindow().width, Settings:ItemsWindow().height)
  FarmingPartyPlusMemberItemsWindow:SetHandler('OnResizeStop', function(...)
    self:WindowResizeHandler(...)
  end)
  FarmingPartyPlusMemberItemsWindow.onResize = self.onResize

  self:SetWindowTransparency()
  self:SetWindowBackgroundTransparency()
  self:SetTitle()
  self:SetupScrollList()
  self:UpdateScrollList()

  members:RegisterCallback('OnKeysUpdated', self.UpdateScrollList)
end

function FarmingPartyPlusMemberItems:Finalize()
  Settings:ItemsWindow().positionLeft = FarmingPartyPlusMemberItemsWindow:GetLeft()
  Settings:ItemsWindow().positionTop = FarmingPartyPlusMemberItemsWindow:GetTop()
  Settings:ItemsWindow().width = FarmingPartyPlusMemberItemsWindow:GetWidth()
  Settings:ItemsWindow().height = FarmingPartyPlusMemberItemsWindow:GetHeight()
end

function FarmingPartyPlusMemberItems:SetupScrollList()
  ZO_ScrollList_AddResizeOnScreenResize(listContainer)
  ZO_ScrollList_AddDataType(listContainer, FarmingPartyPlus.DataTypes.MEMBER_ITEM, 'FarmingPartyPlusItemDataRow', 20, function(listControl, data)
    self:SetupItemRow(listControl, data)
  end)
end

function FarmingPartyPlusMemberItems:UpdateScrollList()
  ZO_ScrollList_Clear(listContainer)
  local member = members:GetMember(memberKey)
  if member == nil then
    return
  end

  local memberItemArray = {}
  for key, value in pairs(members:GetItemsForMember(memberKey)) do
    memberItemArray[#memberItemArray + 1] = {
      itemLink = key,
      count = value.count,
      value = value.value,
      totalValue = value.totalValue
    }
  end

  table.sort(memberItemArray, function(left, right)
    if left.totalValue == right.totalValue then
      return left.itemLink < right.itemLink
    end
    return left.totalValue > right.totalValue
  end)

  local scrollData = ZO_ScrollList_GetDataList(listContainer)
  for _, item in ipairs(memberItemArray) do
    scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(FarmingPartyPlus.DataTypes.MEMBER_ITEM, { rawData = item })
  end
  ZO_ScrollList_Commit(listContainer)
end

function FarmingPartyPlusMemberItems:SetupItemRow(rowControl, rowData)
  local data = rowData.rawData
  GetControl(rowControl, 'ItemName'):SetText(data.itemLink)
  GetControl(rowControl, 'Count'):SetText(data.count)
  GetControl(rowControl, 'TotalValue'):SetText(FarmingPartyPlus.FormatNumber(data.totalValue) .. 'g')
end

function FarmingPartyPlusMemberItems.onResize()
  ZO_ScrollList_Commit(listContainer)
end

function FarmingPartyPlusMemberItems:WindowResizeHandler(control)
  Settings:ItemsWindow().width = control:GetWidth()
  Settings:ItemsWindow().height = control:GetHeight()
  ZO_ScrollList_Commit(listContainer)
end

function FarmingPartyPlusMemberItems:SetAndToggle(key)
  if memberKey == key then
    FarmingPartyPlusMemberItems:ToggleWindow()
  else
    memberKey = key
    self:SetTitle()
    self:OpenWindow()
    self:UpdateScrollList()
  end
end

function FarmingPartyPlusMemberItems:SetTitle()
  local title = FarmingPartyPlusMemberItemsWindow:GetNamedChild('Title')
  local member = members:GetMember(memberKey)
  if member ~= nil then
    title:SetText(member.displayName .. "'s Farmed Items")
  end
end

function FarmingPartyPlusMemberItems:ToggleWindow()
  FarmingPartyPlusMemberItemsWindow:SetHidden(not FarmingPartyPlusMemberItemsWindow:IsHidden())
end

function FarmingPartyPlusMemberItems:OpenWindow()
  FarmingPartyPlusMemberItemsWindow:SetHidden(false)
end

function FarmingPartyPlusMemberItems:SetWindowTransparency(value)
  if value ~= nil then
    Settings:ItemsWindow().transparency = value
  end
  FarmingPartyPlusMemberItemsWindow:SetAlpha(Settings:ItemsWindow().transparency / 100)
end

function FarmingPartyPlusMemberItems:SetWindowBackgroundTransparency(value)
  if value ~= nil then
    Settings:ItemsWindow().backgroundTransparency = value
  end
  FarmingPartyPlusMemberItemsWindow:GetNamedChild('BG'):SetAlpha(Settings:ItemsWindow().backgroundTransparency / 100)
end
