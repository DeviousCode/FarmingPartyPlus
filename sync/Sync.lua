local SYNC_PROTOCOL_ID = 391
local MESH_SYNC_PROTOCOL_ID = 392
local SYNC_PROTOCOL_NAME = 'FarmingPartyPlusSyncLoot'
local MESH_SYNC_PROTOCOL_NAME = 'FarmingPartyPlusMeshLoot'
local DUPLICATE_WINDOW_SECONDS = 5
local SYNC_KIND_DELTA = 0
local SYNC_KIND_FISH_STACK_STATE = 1
local SYNC_KIND_FISH_STACK_DELTA = 2
local OBSERVED_SOURCE_NATIVE = 'native'
local OBSERVED_SOURCE_SYNC = 'sync'

FarmingPartyPlusSyncHost = ZO_Object:Subclass()

local observedEvents = {}

local function NormalizeText(text)
  if text == nil then
    return ''
  end
  return zo_strlower(zo_strformat('<<z:1>>', text))
end

local function GetNormalizedItemNameFromLink(itemLink)
  if itemLink == nil or itemLink == '' then
    return ''
  end
  local itemName = GetItemLinkName(itemLink)
  if itemName == nil or itemName == '' then
    itemName = zo_strformat('<<t:1>>', itemLink)
  end
  return zo_strlower(zo_strformat('<<z:1>>', itemName))
end

local function BuildEventKey(displayName, itemName, quantity, lootType)
  return table.concat({
    NormalizeText(displayName),
    NormalizeText(itemName),
    tostring(quantity or 0),
    tostring(lootType or 0)
  }, '|')
end

local function CleanupObservedEvents(now)
  for key, eventState in pairs(observedEvents) do
    if now - (eventState.timestamp or 0) > DUPLICATE_WINDOW_SECONDS then
      observedEvents[key] = nil
    end
  end
end

local function GetObservedCountKeys(source)
  if source == OBSERVED_SOURCE_SYNC then
    return 'syncCount', 'nativeCount'
  end
  return 'nativeCount', 'syncCount'
end

local function GetOrCreateObservedEvent(displayName, itemName, quantity, lootType, now)
  local eventKey = BuildEventKey(displayName, itemName, quantity, lootType)
  local eventState = observedEvents[eventKey]
  if eventState == nil then
    eventState = {
      nativeCount = 0,
      syncCount = 0,
      timestamp = now
    }
    observedEvents[eventKey] = eventState
  end

  eventState.timestamp = now
  return eventKey, eventState
end

local function GetObservedEvent(displayName, itemName, quantity, lootType)
  local eventKey = BuildEventKey(displayName, itemName, quantity, lootType)
  return eventKey, observedEvents[eventKey]
end

function FarmingPartyPlusSyncHost:New()
  local obj = ZO_Object.New(self)
  obj:Initialize()
  return obj
end

function FarmingPartyPlusSyncHost:Initialize()
  self.enabled = false
  self.protocol = nil
  self.meshProtocol = nil

  local lib = LibGroupBroadcast
  if type(lib) ~= 'table' then
    return
  end

  local handler = lib:RegisterHandler('FarmingPartyPlus', 'SyncHost')
  if handler == nil then
    return
  end

  self.protocol = self:DeclareProtocol(handler, lib, SYNC_PROTOCOL_ID, SYNC_PROTOCOL_NAME)
  self.meshProtocol = self:DeclareProtocol(handler, lib, MESH_SYNC_PROTOCOL_ID, MESH_SYNC_PROTOCOL_NAME)
  self.enabled = true
end

function FarmingPartyPlusSyncHost:DeclareProtocol(handler, lib, protocolId, protocolName)
  local protocol = handler:DeclareProtocol(protocolId, protocolName)
  protocol:AddField(lib.CreateStringField('senderDisplayName', { maxLength = 64 }))
  protocol:AddField(lib.CreateStringField('itemLink', { maxLength = 255 }))
  protocol:AddField(lib.CreateNumericField('quantity', { minValue = -1000, maxValue = 1000 }))
  protocol:AddField(lib.CreateNumericField('itemType', { numBits = 32 }))
  protocol:AddField(lib.CreateNumericField('equipType', { numBits = 16 }))
  protocol:AddField(lib.CreateNumericField('quality', { numBits = 8 }))
  protocol:AddField(lib.CreateNumericField('lootType', { numBits = 16 }))
  protocol:AddField(lib.CreateNumericField('itemValue', { numBits = 32 }))
  protocol:AddField(lib.CreateNumericField('syncKind', { numBits = 8 }))
  protocol:AddField(lib.CreateNumericField('bagId', { numBits = 8 }))
  protocol:AddField(lib.CreateNumericField('slotIndex', { numBits = 16 }))
  protocol:AddField(lib.CreateNumericField('claimedCount', { numBits = 16 }))
  protocol:OnData(function(unitTag, data)
    self:OnData(unitTag, data)
  end)
  protocol:Finalize({
    isRelevantInCombat = false,
    replaceQueuedMessages = false
  })
  return protocol
end

function FarmingPartyPlusSyncHost:Finalize()
end

function FarmingPartyPlusSyncHost:ClearSessionState()
  ZO_ClearTable(observedEvents)
end

function FarmingPartyPlusSyncHost:IsEnabled()
  return self.enabled == true
end

function FarmingPartyPlusSyncHost:SendMeshDelta(data)
  if not self:IsEnabled() or self.meshProtocol == nil or data == nil then
    return false
  end

  self.meshProtocol:Send({
    senderDisplayName = data.senderDisplayName,
    itemLink = data.itemLink,
    quantity = data.quantity,
    itemType = data.itemType,
    equipType = data.equipType,
    quality = data.quality,
    lootType = data.lootType,
    itemValue = data.itemValue,
    syncKind = data.syncKind or SYNC_KIND_DELTA,
    bagId = data.bagId or 0,
    slotIndex = data.slotIndex or 0,
    claimedCount = data.claimedCount or 0
  })
  return true
end

function FarmingPartyPlusSyncHost:RecordObservedLoot(displayName, itemName, quantity, lootType, source)
  if not self:IsEnabled() then
    return
  end

  local now = GetTimeStamp()
  CleanupObservedEvents(now)
  local _, eventState = GetOrCreateObservedEvent(displayName, itemName, quantity, lootType, now)
  local observedCountKey = GetObservedCountKeys(source)
  eventState[observedCountKey] = (eventState[observedCountKey] or 0) + 1
end

function FarmingPartyPlusSyncHost:ConsumeDuplicate(displayName, itemName, quantity, lootType, source)
  if not self:IsEnabled() then
    return false
  end

  local now = GetTimeStamp()
  CleanupObservedEvents(now)
  local eventKey, eventState = GetObservedEvent(displayName, itemName, quantity, lootType)
  if eventState == nil then
    return false
  end

  local _, opposingKey = GetObservedCountKeys(source)
  local remainingCount = eventState[opposingKey] or 0
  if remainingCount <= 0 then
    return false
  end

  eventState[opposingKey] = remainingCount - 1
  eventState.timestamp = now
  if (eventState.nativeCount or 0) <= 0 and (eventState.syncCount or 0) <= 0 then
    observedEvents[eventKey] = nil
  else
    observedEvents[eventKey] = eventState
  end
  return true
end

function FarmingPartyPlusSyncHost:OnData(unitTag, data)
  if not self:IsEnabled() then
    return
  end
  if data == nil then
    return
  end

  local senderDisplayName = data.senderDisplayName
  if senderDisplayName == nil or senderDisplayName == '' then
    senderDisplayName = UndecorateDisplayName(GetUnitDisplayName(unitTag or ''))
  end
  if senderDisplayName == nil or senderDisplayName == '' then
    return
  end
  local senderCharacterName = zo_strformat(SI_UNIT_NAME, GetUnitName(unitTag or ''))
  local itemName = GetNormalizedItemNameFromLink(data.itemLink)
  local localDisplayName = UndecorateDisplayName(GetDisplayName('player'))
  if senderDisplayName == localDisplayName then
    return
  end
  if self:ConsumeDuplicate(senderDisplayName, itemName, data.quantity, data.lootType, 'sync') then
    return
  end

  self:RecordObservedLoot(senderDisplayName, itemName, data.quantity, data.lootType, 'sync')

  local memberList = FarmingPartyPlus.Modules.MemberList
  if memberList ~= nil and memberList.MarkHelperActive ~= nil then
    memberList:MarkHelperActive(senderCharacterName, senderDisplayName)
  end

  data.senderCharacterName = senderCharacterName
  data.senderDisplayName = senderDisplayName
  data.itemName = itemName
  local lootModule = FarmingPartyPlus.Modules.Loot
  if lootModule ~= nil then
    lootModule:OnSyncedLootReceived(data, unitTag)
  end
end
