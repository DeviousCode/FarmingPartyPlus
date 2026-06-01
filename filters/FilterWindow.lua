local listContainer
local Settings
local CATEGORY_ORDER = { 'ore', 'wood', 'cloth', 'jewelry', 'alchemy', 'enchanting', 'provisioning', 'baitCommon', 'baitRare', 'fishing', 'furnishing' }

FarmingPartyPlusFilterWindow = ZO_Object:Subclass()

local function UpdateItemButton(button, itemData)
  local isEnabled = Settings:IsWhitelistedItem(itemData.key)
  button.itemData = itemData
  button:SetHidden(false)
  button:SetText((isEnabled and '[ON] ' or '[OFF] ') .. itemData.name)
  if isEnabled then
    button:SetNormalFontColor(0.20, 0.90, 0.45, 1)
  else
    button:SetNormalFontColor(0.80, 0.80, 0.80, 1)
  end
end

function FarmingPartyPlusFilterWindow:New()
  local obj = ZO_Object.New(self)
  self:Initialize()
  return obj
end

function FarmingPartyPlusFilterWindow:Initialize()
  Settings = FarmingPartyPlus.Settings
  listContainer = FarmingPartyPlusItemFilterWindow:GetNamedChild('List')

  FarmingPartyPlusItemFilterWindow:ClearAnchors()
  FarmingPartyPlusItemFilterWindow:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, Settings:FilterWindow().positionLeft, Settings:FilterWindow().positionTop)
  FarmingPartyPlusItemFilterWindow:SetDimensions(Settings:FilterWindow().width, Settings:FilterWindow().height)
  FarmingPartyPlusItemFilterWindow:SetHandler('OnMoveStop', function()
    self:SavePosition()
  end)
  FarmingPartyPlusItemFilterWindow:SetHandler('OnResizeStop', function(...)
    self:WindowResizeHandler(...)
  end)

  self:SetupScrollList()
  self:RefreshModeLabel()
  self:UpdateScrollList()
end

function FarmingPartyPlusFilterWindow:Finalize()
  self:SavePosition()
end

function FarmingPartyPlusFilterWindow:SavePosition()
  Settings:FilterWindow().positionLeft = FarmingPartyPlusItemFilterWindow:GetLeft()
  Settings:FilterWindow().positionTop = FarmingPartyPlusItemFilterWindow:GetTop()
  Settings:FilterWindow().width = FarmingPartyPlusItemFilterWindow:GetWidth()
  Settings:FilterWindow().height = FarmingPartyPlusItemFilterWindow:GetHeight()
end

function FarmingPartyPlusFilterWindow:WindowResizeHandler(control)
  self:SavePosition()
  ZO_ScrollList_Commit(listContainer)
end

function FarmingPartyPlusFilterWindow:RefreshModeLabel()
  local modeLabel = FarmingPartyPlusItemFilterWindow:GetNamedChild('ModeValue')
  modeLabel:SetText(Settings:UseWhitelistMode() and 'Whitelist On' or 'Whitelist Off')
end

function FarmingPartyPlusFilterWindow:ToggleWhitelistMode()
  Settings:SetWhitelistMode(not Settings:UseWhitelistMode())
  self:RefreshModeLabel()
end

function FarmingPartyPlusFilterWindow:ToggleWindow()
  FarmingPartyPlusItemFilterWindow:SetHidden(not FarmingPartyPlusItemFilterWindow:IsHidden())
end

function FarmingPartyPlusFilterWindow:OpenWindow()
  FarmingPartyPlusItemFilterWindow:SetHidden(false)
end

function FarmingPartyPlusFilterWindow:ToggleItem(itemKey)
  Settings:SetWhitelistedItem(itemKey, not Settings:IsWhitelistedItem(itemKey))
  self:UpdateScrollList()
end

function FarmingPartyPlusFilterWindow:SetAll(value)
  Settings:ToggleAllWhitelistItems(value)
  self:UpdateScrollList()
end

function FarmingPartyPlusFilterWindow:SetCategory(categoryKey, value)
  Settings:ToggleWhitelistCategory(categoryKey, value)
  self:UpdateScrollList()
end

function FarmingPartyPlusFilterWindow:SetupScrollList()
  ZO_ScrollList_AddResizeOnScreenResize(listContainer)
  ZO_ScrollList_AddDataType(listContainer, FarmingPartyPlus.DataTypes.FILTER_HEADER, 'FarmingPartyPlusFilterHeaderRow', 28, function(control, data)
    self:SetupHeaderRow(control, data)
  end)
  ZO_ScrollList_AddDataType(listContainer, FarmingPartyPlus.DataTypes.FILTER_ROW, 'FarmingPartyPlusFilterItemRow', 30, function(control, data)
    self:SetupItemRow(control, data)
  end)
end

function FarmingPartyPlusFilterWindow:UpdateScrollList()
  local scrollData = ZO_ScrollList_GetDataList(listContainer)
  ZO_ScrollList_Clear(listContainer)

  local grouped = FarmingPartyPlusItemCatalog:GetGroupedItems()
  for _, categoryKey in ipairs(CATEGORY_ORDER) do
    scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(FarmingPartyPlus.DataTypes.FILTER_HEADER, {
      title = FarmingPartyPlusItemCatalog.categories[categoryKey],
      categoryKey = categoryKey
    })

    local items = grouped[categoryKey]
    for index = 1, #items, 3 do
      local rowItems = {}
      rowItems[#rowItems + 1] = items[index]
      rowItems[#rowItems + 1] = items[index + 1]
      rowItems[#rowItems + 1] = items[index + 2]
      scrollData[#scrollData + 1] = ZO_ScrollList_CreateDataEntry(FarmingPartyPlus.DataTypes.FILTER_ROW, { items = rowItems })
    end
  end

  self:RefreshModeLabel()
  ZO_ScrollList_Commit(listContainer)
end

function FarmingPartyPlusFilterWindow:SetupHeaderRow(control, data)
  control:GetNamedChild('Title'):SetText(data.title)
  control:GetNamedChild('Enable'):SetHandler('OnClicked', function()
    self:SetCategory(data.categoryKey, true)
  end)
  control:GetNamedChild('Disable'):SetHandler('OnClicked', function()
    self:SetCategory(data.categoryKey, false)
  end)
end

function FarmingPartyPlusFilterWindow:SetupItemRow(control, data)
  for i = 1, 3 do
    local button = control:GetNamedChild('Item' .. i)
    local itemData = data.items[i]
    if itemData == nil then
      button:SetHidden(true)
    else
      UpdateItemButton(button, itemData)
      button:SetHandler('OnClicked', function()
        self:ToggleItem(itemData.key)
      end)
    end
  end
end
