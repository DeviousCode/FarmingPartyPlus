local SYNC_PROTOCOL_ID = 6391
local DUPLICATE_WINDOW_SECONDS = 5

FarmingPartyPlusSyncHost = ZO_Object:Subclass()

local observedEvents = {}

local function NormalizeText(text)
  if text == nil then
    return ''
  end
  return zo_strlower(zo_strformat('<<z:1>>', text))
end

local function BuildEventKey(characterName, itemName, quantity, lootType)
  return table.concat({
    NormalizeText(characterName),
    NormalizeText(itemName),
    tostring(quantity or 0),
    tostring(lootType or 0)
  }, '|')
end

local function CleanupObservedEvents(now)
  for key, timestamp in pairs(observedEvents) do
    if now - timestamp > DUPLICATE_WINDOW_SECONDS then
      observedEvents[key] = nil
    end
  end
end

function FarmingPartyPlusSyncHost:New()
  local obj = ZO_Object.New(self)
  obj:Initialize()
  return obj
end

function FarmingPartyPlusSyncHost:Initialize()
  self.enabled = false
  self.protocol = nil

  local lib = LibGroupBroadcast
  if type(lib) ~= 'table' then
    return
  end

  local handler = lib:RegisterHandler('FarmingPartyPlus', 'SyncHost')
  if handler == nil then
    return
  end

  local protocol = handler:DeclareProtocol(SYNC_PROTOCOL_ID, 'FarmingPartyPlusSyncLoot')
  protocol:AddField(lib.CreateStringField('senderCharacterName', { maxLength = 64 }))
  protocol:AddField(lib.CreateStringField('senderDisplayName', { maxLength = 64 }))
  protocol:AddField(lib.CreateStringField('itemName', { maxLength = 128 }))
  protocol:AddField(lib.CreateNumericField('quantity', { numBits = 16 }))
  protocol:AddField(lib.CreateNumericField('itemType', { numBits = 32 }))
  protocol:AddField(lib.CreateNumericField('equipType', { numBits = 16 }))
  protocol:AddField(lib.CreateNumericField('quality', { numBits = 8 }))
  protocol:AddField(lib.CreateNumericField('lootType', { numBits = 16 }))
  protocol:AddField(lib.CreateNumericField('itemValue', { numBits = 32 }))
  protocol:OnData(function(unitTag, data)
    self:OnData(unitTag, data)
  end)
  protocol:Finalize({
    isRelevantInCombat = false,
    replaceQueuedMessages = false
  })

  self.protocol = protocol
  self.enabled = true
end

function FarmingPartyPlusSyncHost:Finalize()
end

function FarmingPartyPlusSyncHost:IsEnabled()
  return self.enabled == true
end

function FarmingPartyPlusSyncHost:RecordObservedLoot(characterName, itemName, quantity, lootType)
  if not self:IsEnabled() then
    return
  end

  local now = GetTimeStamp()
  CleanupObservedEvents(now)
  observedEvents[BuildEventKey(characterName, itemName, quantity, lootType)] = now
end

function FarmingPartyPlusSyncHost:IsDuplicate(data)
  local eventKey = BuildEventKey(data.senderCharacterName, data.itemName, data.quantity, data.lootType)
  local timestamp = observedEvents[eventKey]
  if timestamp == nil then
    return false
  end
  return GetTimeStamp() - timestamp <= DUPLICATE_WINDOW_SECONDS
end

function FarmingPartyPlusSyncHost:OnData(unitTag, data)
  if not self:IsEnabled() then
    return
  end
  if data == nil or data.senderCharacterName == nil then
    return
  end

  local localCharacterName = zo_strformat(SI_UNIT_NAME, GetUnitName('player'))
  if data.senderCharacterName == localCharacterName then
    return
  end
  if self:IsDuplicate(data) then
    return
  end

  local lootModule = FarmingPartyPlus.Modules.Loot
  if lootModule ~= nil then
    lootModule:OnSyncedLootReceived(data, unitTag)
  end
end
