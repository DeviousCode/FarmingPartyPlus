local ADDON_NAME = 'FarmingPartyPlus'
local function GetItemPrice(itemLink)
  local price = LibPrice.ItemLinkToPriceGold(itemLink)
  if price == nil or price == 0 then
    price = GetItemLinkValue(itemLink, true)
  end
  return price
end

local function NormalizeItemName(itemLink)
  local itemName = GetItemLinkName(itemLink)
  if itemName == nil or itemName == '' then
    itemName = zo_strformat('<<t:1>>', itemLink)
  end
  return zo_strlower(zo_strformat('<<z:1>>', itemName))
end

FarmingPartyPlusLoot = ZO_Object:Subclass()

local NOT_EQUIPPABLE = 0
local Members
local MemberList
local Logger
local Settings
local Sync
local trackedLocalFishSlots = {}
local recentLocalGuttingOutputs = {}
local AUTO_ADD_WARNING_DIALOG_NAME = 'FarmingPartyPlusCraftBagWarningDialog'

local function BuildBagSlotKey(bagId, slotIndex)
  return string.format('%d:%d', bagId, slotIndex)
end

local function IsBackpackSlot(bagId)
  return bagId == BAG_BACKPACK
end

local function IsGuttableFishItem(itemLink)
  return GetItemLinkItemType(itemLink) == ITEMTYPE_FISH
      and GetItemLinkQuality(itemLink) <= ITEM_QUALITY_NORMAL
      and NormalizeItemName(itemLink) ~= 'fish'
end

local function IsTrackedGuttingOutputName(itemName)
  return itemName == 'fish' or itemName == 'perfect roe'
end

local function IsRecipeItemType(itemType)
  return itemType == ITEMTYPE_RECIPE
end

local function BuildRecentOutputKey(itemLink, quantity)
  return string.format('%s|%s', NormalizeItemName(itemLink), tostring(quantity or 0))
end

local function CleanupRecentOutputs(cache, now)
  for eventKey, timestamp in pairs(cache) do
    if now - timestamp > 2 then
      cache[eventKey] = nil
    end
  end
end

local function IsCraftBagAutoAddEnabled()
  if GetSetting_Bool == nil then
    return false
  end
  return GetSetting_Bool(SETTING_TYPE_LOOT, LOOT_SETTING_AUTO_ADD_TO_CRAFT_BAG)
end

function FarmingPartyPlusLoot:New()
  local obj = ZO_Object.New(self)
  obj:Initialize()
  return obj
end

function FarmingPartyPlusLoot:Initialize()
  Members = FarmingPartyPlus.Modules.Members
  MemberList = FarmingPartyPlus.Modules.MemberList
  Logger = FarmingPartyPlus.Modules.Logger
  Settings = FarmingPartyPlus.Settings
  Sync = FarmingPartyPlus.Modules.Sync
  self.hasShownCraftBagAutoAddWarning = false

  self:RegisterDialogs()
  if Settings:Status() == FarmingPartyPlus.Settings.TRACKING_STATUS.ENABLED then
    self:AddEventHandlers()
  end
end

function FarmingPartyPlusLoot:Finalize()
end

function FarmingPartyPlusLoot:ClearSessionState()
  ZO_ClearTable(trackedLocalFishSlots)
  ZO_ClearTable(recentLocalGuttingOutputs)
  self.hasShownCraftBagAutoAddWarning = false
end

function FarmingPartyPlusLoot:RegisterDialogs()
  if self.dialogsRegistered then
    return
  end

  ZO_Dialogs_RegisterCustomDialog(AUTO_ADD_WARNING_DIALOG_NAME, {
    title = {
      text = 'Craft Bag Auto-Add Detected'
    },
    mainText = {
      text = 'Auto-Add to Craft Bag is on. Fish and Perfect Roe may skip Farming Party Plus tracking. Turn it off now?'
    },
    buttons = {
      {
        text = SI_DIALOG_ACCEPT,
        callback = function()
          SetSetting(SETTING_TYPE_LOOT, LOOT_SETTING_AUTO_ADD_TO_CRAFT_BAG, 'false')
          d('[Farming Party Plus]: Auto-Add to Craft Bag was turned off.')
        end
      },
      {
        text = SI_DIALOG_CANCEL
      }
    }
  })

  self.dialogsRegistered = true
end

function FarmingPartyPlusLoot:WarnAboutCraftBagAutoAddIfNeeded(itemLink)
  if self.hasShownCraftBagAutoAddWarning then
    return
  end
  if itemLink == nil or itemLink == '' then
    return
  end

  local normalizedItemName = NormalizeItemName(itemLink)
  local isFishingRelevant = IsGuttableFishItem(itemLink) or IsTrackedGuttingOutputName(normalizedItemName)
  if not isFishingRelevant or not IsCraftBagAutoAddEnabled() then
    return
  end

  self.hasShownCraftBagAutoAddWarning = true
  ZO_Dialogs_ShowDialog(AUTO_ADD_WARNING_DIALOG_NAME)
end

function FarmingPartyPlusLoot:AddEventHandlers()
  EVENT_MANAGER:RegisterForEvent(
    ADDON_NAME,
    EVENT_LOOT_RECEIVED,
    function(...)
      self:OnItemLooted(...)
    end
  )
  EVENT_MANAGER:RegisterForEvent(
    ADDON_NAME,
    EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
    function(...)
      self:OnInventorySlotUpdated(...)
    end
  )
  Settings:ToggleStatusValue(FarmingPartyPlus.Settings.TRACKING_STATUS.ENABLED)
end

function FarmingPartyPlusLoot:RemoveEventHandlers()
  EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_LOOT_RECEIVED)
  EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
  Settings:ToggleStatusValue(FarmingPartyPlus.Settings.TRACKING_STATUS.DISABLED)
end

local function FindMemberKey(looterName, lootedByPlayer)
  if lootedByPlayer then
    return zo_strformat(SI_UNIT_NAME, GetUnitName('player'))
  end

  if looterName ~= nil and looterName ~= '' then
    local normalizedName = zo_strformat(SI_UNIT_NAME, looterName)
    if Members:HasMember(normalizedName) then
      return normalizedName
    end

    for memberKey, memberData in pairs(Members:GetMembers()) do
      if memberData.displayName == looterName or memberData.displayName == UndecorateDisplayName(looterName) then
        return memberKey
      end
    end
  end

  return nil
end

local function GetMember(looterName, lootedByPlayer)
  local memberKey = FindMemberKey(looterName, lootedByPlayer)
  if memberKey ~= nil and Members:HasMember(memberKey) then
    return memberKey, Members:GetMember(memberKey)
  end

  MemberList:AddAllGroupMembers()
  memberKey = FindMemberKey(looterName, lootedByPlayer)
  if memberKey ~= nil then
    return memberKey, Members:GetMember(memberKey)
  end

  if Members:HasMember(looterName) then
    return looterName, Members:GetMember(looterName)
  end

  local playerName = zo_strformat(SI_UNIT_NAME, GetUnitName('player'))
  if Members:HasMember(playerName) then
    return playerName, Members:GetMember(playerName)
  end

  return nil, nil
end

local function GetSyncedMember(characterName, displayName)
  local normalizedCharacterName = zo_strformat(SI_UNIT_NAME, characterName or '')
  if normalizedCharacterName ~= '' and Members:HasMember(normalizedCharacterName) then
    return normalizedCharacterName, Members:GetMember(normalizedCharacterName)
  end

  MemberList:AddAllGroupMembers()
  if normalizedCharacterName ~= '' and Members:HasMember(normalizedCharacterName) then
    return normalizedCharacterName, Members:GetMember(normalizedCharacterName)
  end

  for memberKey, memberData in pairs(Members:GetMembers()) do
    if displayName ~= nil and (memberData.displayName == displayName or memberData.displayName == UndecorateDisplayName(displayName)) then
      return memberKey, memberData
    end
  end

  return nil, nil
end

function FarmingPartyPlusLoot:PassesBaseExclusions(itemLink)
  local _, _, _, equipType = GetItemLinkInfo(itemLink)
  local itemType = GetItemLinkItemType(itemLink)

  if equipType ~= NOT_EQUIPPABLE and not Settings:TrackGearLoot() then
    return false
  end
  if itemType == ITEMTYPE_RACIAL_STYLE_MOTIF and not Settings:TrackMotifLoot() then
    return false
  end

  return true
end

function FarmingPartyPlusLoot:PassesBaseExclusionsForData(itemType, equipType)
  if equipType ~= NOT_EQUIPPABLE and not Settings:TrackGearLoot() then
    return false
  end
  if itemType == ITEMTYPE_RACIAL_STYLE_MOTIF and not Settings:TrackMotifLoot() then
    return false
  end
  return true
end

function FarmingPartyPlusLoot:ShouldTrackByLegacyRules(itemLink)
  local itemQuality = GetItemLinkQuality(itemLink)
  local minimumQuality = tonumber(Settings:MinimumLootQuality()) or ITEM_QUALITY_TRASH
  if itemQuality < minimumQuality then
    return false
  end
  return true
end

function FarmingPartyPlusLoot:ShouldTrackByWhitelist(itemLink)
  local itemType = GetItemLinkItemType(itemLink)
  if IsRecipeItemType(itemType) and Settings:IsWhitelistRuleEnabled('__recipes_any__') then
    return GetItemPrice(itemLink) >= Settings:MinimumRecipeValue()
  end

  local itemKey = NormalizeItemName(itemLink)
  if Settings:IsWhitelistedItem(itemKey) then
    return true
  end

  if itemType == ITEMTYPE_FISH and Settings:IsWhitelistRuleEnabled('__fish_any__') then
    return true
  end

  return false
end

function FarmingPartyPlusLoot:ShouldTrackItem(itemLink, lootType)
  if lootType == LOOT_TYPE_QUEST_ITEM then
    return false
  end
  if not self:PassesBaseExclusions(itemLink) then
    return false
  end

  if Settings:UseWhitelistMode() then
    return self:ShouldTrackByWhitelist(itemLink)
  end

  return self:ShouldTrackByLegacyRules(itemLink)
end

function FarmingPartyPlusLoot:ShouldTrackSyncedData(data)
  if data.lootType == LOOT_TYPE_QUEST_ITEM then
    return false
  end
  if not self:PassesBaseExclusionsForData(data.itemType, data.equipType) then
    return false
  end

  if Settings:UseWhitelistMode() then
    if IsRecipeItemType(data.itemType) and Settings:IsWhitelistRuleEnabled('__recipes_any__') then
      return (tonumber(data.itemValue) or 0) >= Settings:MinimumRecipeValue()
    end
    if data.itemType == ITEMTYPE_FISH and Settings:IsWhitelistRuleEnabled('__fish_any__') then
      return true
    end
    return Settings:IsWhitelistedItem(zo_strlower(zo_strformat('<<z:1>>', data.itemName or '')))
  end

  return (data.quality or 0) >= (tonumber(Settings:MinimumLootQuality()) or ITEM_QUALITY_TRASH)
end

function FarmingPartyPlusLoot:RememberLocalFishSlot(bagId, slotIndex)
  if not IsBackpackSlot(bagId) then
    return
  end

  local itemLink = GetItemLink(bagId, slotIndex)
  if itemLink == nil or itemLink == '' or not IsGuttableFishItem(itemLink) then
    trackedLocalFishSlots[BuildBagSlotKey(bagId, slotIndex)] = nil
    return
  end

  local slotKey = BuildBagSlotKey(bagId, slotIndex)
  local existingTrackedSlot = trackedLocalFishSlots[slotKey]
  local normalizedItemName = NormalizeItemName(itemLink)
  local preservedClaimedCount = 0
  if existingTrackedSlot ~= nil and NormalizeItemName(existingTrackedSlot.itemLink or '') == normalizedItemName then
    preservedClaimedCount = existingTrackedSlot.claimedCount or 0
  end

  trackedLocalFishSlots[slotKey] = {
    bagId = bagId,
    slotIndex = slotIndex,
    itemLink = itemLink,
    itemValue = GetItemPrice(itemLink),
    stackCount = GetSlotStackSize(bagId, slotIndex),
    claimedCount = preservedClaimedCount
  }
end

function FarmingPartyPlusLoot:ClaimLocalFishSlotForSession(normalizedItemName, caughtQuantity)
  zo_callLater(function()
    local playerName = zo_strformat(SI_UNIT_NAME, GetUnitName('player'))
    local claimedCatchQuantity = tonumber(caughtQuantity) or 0
    for slotIndex = 0, GetBagSize(BAG_BACKPACK) do
      local slotItemLink = GetItemLink(BAG_BACKPACK, slotIndex)
      if slotItemLink ~= nil and slotItemLink ~= '' and NormalizeItemName(slotItemLink) == normalizedItemName and IsGuttableFishItem(slotItemLink) then
        local slotKey = BuildBagSlotKey(BAG_BACKPACK, slotIndex)
        local currentStackCount = GetSlotStackSize(BAG_BACKPACK, slotIndex)
        local trackedSlot = trackedLocalFishSlots[slotKey]
        local previouslyClaimedCount = trackedSlot ~= nil and (trackedSlot.claimedCount or 0) or 0
        local claimDelta = currentStackCount - previouslyClaimedCount - claimedCatchQuantity

        self:RememberLocalFishSlot(BAG_BACKPACK, slotIndex)
        if claimDelta > 0 and Members:HasMember(playerName) then
          local itemValue = GetItemPrice(slotItemLink)
          self:AddNewLootedItem(playerName, slotItemLink, itemValue, claimDelta)
        end
        trackedLocalFishSlots[slotKey].claimedCount = currentStackCount
      end
    end
  end, 0)
end

function FarmingPartyPlusLoot:OnItemLooted(eventCode, name, itemLink, quantity, itemSound, lootType, lootedByPlayer)
  if not lootedByPlayer and not Settings:TrackGroupLoot() then
    return
  end
  if lootedByPlayer and not Settings:TrackSelfLoot() then
    return
  end

  local normalizedItemName = NormalizeItemName(itemLink)
  if lootedByPlayer then
    self:WarnAboutCraftBagAutoAddIfNeeded(itemLink)
  end
  if not self:ShouldTrackItem(itemLink, lootType) then
    return
  end

  if lootedByPlayer and IsTrackedGuttingOutputName(normalizedItemName) then
    local eventKey = BuildRecentOutputKey(itemLink, quantity)
    CleanupRecentOutputs(recentLocalGuttingOutputs, GetTimeStamp())
    recentLocalGuttingOutputs[eventKey] = GetTimeStamp()
  end

  local itemValue = GetItemPrice(itemLink)
  local totalValue = itemValue * quantity
  local memberKey, looterMember = GetMember(name, lootedByPlayer)

  if memberKey == nil or looterMember == nil then
    return
  end

  if not lootedByPlayer and Sync ~= nil and Sync.ConsumeDuplicate ~= nil and Sync:ConsumeDuplicate(memberKey, GetItemLinkName(itemLink), quantity, lootType, 'native') then
    return
  end

  if Sync ~= nil then
    Sync:RecordObservedLoot(memberKey, GetItemLinkName(itemLink), quantity, lootType, 'native')
  end
  self:AddNewLootedItem(memberKey, itemLink, itemValue, quantity)
  Logger:LogLootItem(looterMember.displayName, lootedByPlayer, itemLink, quantity, totalValue, lootType)

  if lootedByPlayer and IsGuttableFishItem(itemLink) then
    self:ClaimLocalFishSlotForSession(normalizedItemName, quantity)
  end
end

function FarmingPartyPlusLoot:OnSyncedLootReceived(data, unitTag)
  if data == nil or not Settings:TrackGroupLoot() then
    return
  end
  if not self:ShouldTrackSyncedData(data) then
    return
  end

  local memberKey, looterMember = GetSyncedMember(data.senderCharacterName, data.senderDisplayName)
  if memberKey == nil or looterMember == nil then
    return
  end

  local itemName = data.itemName
  local itemLink = data.itemLink
  local itemValue = data.itemValue or 0
  local quantity = tonumber(data.quantity) or 1
  local trackedItem = (itemLink ~= nil and itemLink ~= '') and itemLink or itemName
  local resolvedItemValue = ((itemLink ~= nil and itemLink ~= '') and GetItemPrice(itemLink)) or itemValue

  if quantity == 0 then
    return
  end

  if quantity > 0 then
    self:AddNewLootedItem(memberKey, trackedItem, resolvedItemValue, quantity)
    Logger:LogLootItem(looterMember.displayName, false, trackedItem, quantity, resolvedItemValue * quantity, data.lootType or 0)
  else
    self:AdjustLootedItem(memberKey, trackedItem, resolvedItemValue, quantity)
    Logger:LogLootItem(looterMember.displayName, false, trackedItem, quantity, resolvedItemValue * math.abs(quantity), data.lootType or 0)
  end
end

function FarmingPartyPlusLoot:AddNewLootedItem(memberName, itemLink, itemValue, count)
  local itemDetails = Members:GetItemForMember(memberName, itemLink)
  if itemDetails == nil then
    itemDetails = FarmingPartyPlusMemberItem:New(itemLink)
  end
  itemDetails = FarmingPartyPlusMemberItem:UpdateItemCount(itemDetails, itemValue, count)
  Members:SetItemForMember(memberName, itemLink, itemDetails)
  Members:UpdateTotalValueAndSetBestItem(memberName, itemDetails, itemValue * count)
end

function FarmingPartyPlusLoot:AdjustLootedItem(memberName, itemLink, itemValue, count)
  local itemDetails = Members:GetItemForMember(memberName, itemLink)
  if itemDetails == nil then
    return
  end

  itemDetails = FarmingPartyPlusMemberItem:UpdateItemCount(itemDetails, itemValue, count)
  if itemDetails.count <= 0 then
    Members:DeleteItemForMember(memberName, itemLink)
  else
    Members:SetItemForMember(memberName, itemLink, itemDetails)
  end
  Members:RebuildMemberTotals(memberName)
end

function FarmingPartyPlusLoot:OnInventorySlotUpdated(eventCode, bagId, slotIndex, isNewItem, itemSoundCategory, inventoryUpdateReason, stackCountChange)
  if not IsBackpackSlot(bagId) or not Settings:TrackSelfLoot() then
    return
  end

  local slotKey = BuildBagSlotKey(bagId, slotIndex)
  local trackedSlot = trackedLocalFishSlots[slotKey]
  local countDelta = tonumber(stackCountChange) or 0
  local playerName = zo_strformat(SI_UNIT_NAME, GetUnitName('player'))

  if trackedSlot ~= nil and countDelta < 0 and Members:HasMember(playerName) then
    local quantityRemoved = math.min(math.abs(countDelta), trackedSlot.claimedCount or math.abs(countDelta))
    self:AdjustLootedItem(playerName, trackedSlot.itemLink, trackedSlot.itemValue, -quantityRemoved)
    Logger:LogLootItem(GetDisplayName(), true, trackedSlot.itemLink, -quantityRemoved, trackedSlot.itemValue * quantityRemoved, LOOT_TYPE_ITEM)
    trackedSlot.stackCount = math.max((trackedSlot.stackCount or 0) - quantityRemoved, 0)
    trackedSlot.claimedCount = math.max((trackedSlot.claimedCount or 0) - quantityRemoved, 0)
    if trackedSlot.claimedCount == 0 then
      trackedLocalFishSlots[slotKey] = nil
    end
  end

  if countDelta > 0 and Members:HasMember(playerName) then
    local itemLink = GetItemLink(bagId, slotIndex)
    if itemLink ~= nil and itemLink ~= '' then
      local normalizedItemName = NormalizeItemName(itemLink)
      if IsTrackedGuttingOutputName(normalizedItemName) and self:ShouldTrackItem(itemLink, LOOT_TYPE_ITEM) then
        local eventKey = BuildRecentOutputKey(itemLink, countDelta)
        CleanupRecentOutputs(recentLocalGuttingOutputs, GetTimeStamp())
        if recentLocalGuttingOutputs[eventKey] ~= nil then
          recentLocalGuttingOutputs[eventKey] = nil
          self:RememberLocalFishSlot(bagId, slotIndex)
          return
        end
        local itemValue = GetItemPrice(itemLink)
        self:AddNewLootedItem(playerName, itemLink, itemValue, countDelta)
        Logger:LogLootItem(GetDisplayName('player'), true, itemLink, countDelta, itemValue * countDelta, LOOT_TYPE_ITEM)
      end
    end
  end

  self:RememberLocalFishSlot(bagId, slotIndex)
end
