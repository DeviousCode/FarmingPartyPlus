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

  if Settings:Status() == FarmingPartyPlus.Settings.TRACKING_STATUS.ENABLED then
    self:AddEventHandlers()
  end
end

function FarmingPartyPlusLoot:Finalize()
end

function FarmingPartyPlusLoot:AddEventHandlers()
  EVENT_MANAGER:RegisterForEvent(
    ADDON_NAME,
    EVENT_LOOT_RECEIVED,
    function(...)
      self:OnItemLooted(...)
    end
  )
  Settings:ToggleStatusValue(FarmingPartyPlus.Settings.TRACKING_STATUS.ENABLED)
end

function FarmingPartyPlusLoot:RemoveEventHandlers()
  EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_LOOT_RECEIVED)
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
  local itemKey = NormalizeItemName(itemLink)
  if Settings:IsWhitelistedItem(itemKey) then
    return true
  end

  local itemType = GetItemLinkItemType(itemLink)
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
    if data.itemType == ITEMTYPE_FISH and Settings:IsWhitelistRuleEnabled('__fish_any__') then
      return true
    end
    return Settings:IsWhitelistedItem(zo_strlower(zo_strformat('<<z:1>>', data.itemName or '')))
  end

  return (data.quality or 0) >= (tonumber(Settings:MinimumLootQuality()) or ITEM_QUALITY_TRASH)
end

function FarmingPartyPlusLoot:OnItemLooted(eventCode, name, itemLink, quantity, itemSound, lootType, lootedByPlayer)
  if not lootedByPlayer and not Settings:TrackGroupLoot() then
    return
  end
  if lootedByPlayer and not Settings:TrackSelfLoot() then
    return
  end
  if not self:ShouldTrackItem(itemLink, lootType) then
    return
  end

  local itemValue = GetItemPrice(itemLink)
  local totalValue = itemValue * quantity
  local memberKey, looterMember = GetMember(name, lootedByPlayer)

  if memberKey == nil or looterMember == nil then
    return
  end

  if Sync ~= nil then
    Sync:RecordObservedLoot(memberKey, GetItemLinkName(itemLink), quantity, lootType)
  end
  self:AddNewLootedItem(memberKey, itemLink, itemValue, quantity)
  Logger:LogLootItem(looterMember.displayName, lootedByPlayer, itemLink, quantity, totalValue, lootType)
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
  local itemValue = data.itemValue or 0
  local quantity = data.quantity or 1

  self:AddNewLootedItem(memberKey, itemName, itemValue, quantity)
  Logger:LogLootItem(looterMember.displayName, false, itemName, quantity, itemValue * quantity, data.lootType or 0)
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
