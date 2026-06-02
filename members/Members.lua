FarmingPartyPlusMembers = ZO_CallbackObject:Subclass()

function FarmingPartyPlusMembers:New(saveData)
  local storage = ZO_CallbackObject.New(self)
  storage.members = saveData.members or {}
  saveData.members = storage.members
  return storage
end

function FarmingPartyPlusMembers:Finalize()
end

function FarmingPartyPlusMembers:GetMembers()
  return self.members
end

function FarmingPartyPlusMembers:GetCleanMembers()
  local cleanMembers = {}
  for key, member in pairs(self.members) do
    cleanMembers[key] = {
      bestItem = member.bestItem,
      totalValue = member.totalValue,
      items = member.items,
      displayName = member.displayName,
      helperActive = member.helperActive
    }
  end
  return cleanMembers
end

function FarmingPartyPlusMembers:GetKeys()
  local keys = {}
  for key in pairs(self.members) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  return keys
end

function FarmingPartyPlusMembers:GetMember(key)
  return self.members[key]
end

function FarmingPartyPlusMembers:HasMember(key)
  return self.members[key] ~= nil
end

function FarmingPartyPlusMembers:HasMembers()
  return next(self.members) ~= nil
end

function FarmingPartyPlusMembers:SetMember(key, member)
  local keyExists = self:HasMember(key)
  self.members[key] = member
  if not keyExists then
    self:FireCallbacks('OnKeysUpdated')
  end
end

function FarmingPartyPlusMembers:DeleteMember(key)
  local keyExists = self:HasMember(key)
  self.members[key] = nil
  if keyExists then
    self:FireCallbacks('OnKeysUpdated')
  end
end

function FarmingPartyPlusMembers:DeleteAllMembers()
  local hasMembers = self:HasMembers()
  ZO_ClearTable(self.members)
  if hasMembers then
    self:FireCallbacks('OnKeysUpdated')
  end
end

function FarmingPartyPlusMembers:GetItemForMember(memberKey, itemLink)
  local member = self:GetMember(memberKey)
  return member.items[itemLink]
end

function FarmingPartyPlusMembers:SetItemForMember(memberKey, itemLink, item)
  local member = self:GetMember(memberKey)
  member.items[itemLink] = item
end

function FarmingPartyPlusMembers:DeleteItemForMember(memberKey, itemLink)
  local member = self:GetMember(memberKey)
  member.items[itemLink] = nil
end

function FarmingPartyPlusMembers:GetItemsForMember(key)
  local member = self:GetMember(key)
  return member.items
end

function FarmingPartyPlusMembers:NewMember(name, displayName)
  local newMember = {
    bestItem = { itemLink = '', value = 0 },
    totalValue = 0,
    items = {},
    displayName = displayName,
    helperActive = false
  }
  self:FireCallbacks('OnKeysUpdated')
  return newMember
end

function FarmingPartyPlusMembers:SetHelperActive(name, isActive)
  local member = self:GetMember(name)
  if member == nil or member.helperActive == isActive then
    return
  end
  member.helperActive = isActive
  self:FireCallbacks('OnKeysUpdated')
end

function FarmingPartyPlusMembers:UpdateTotalValueAndSetBestItem(name, item, valueToAdd)
  local member = self:GetMember(name)
  local bestItem = member.bestItem
  if item.value > bestItem.value then
    bestItem = item
    bestItem.itemLink = item.itemLink
  end
  member.bestItem = bestItem
  member.totalValue = member.totalValue + valueToAdd
  self:FireCallbacks('OnKeysUpdated')
end

function FarmingPartyPlusMembers:RebuildMemberTotals(name)
  local member = self:GetMember(name)
  local bestItem = { itemLink = '', value = 0 }
  local totalValue = 0

  for itemLink, item in pairs(member.items) do
    if item.count == nil or item.count <= 0 then
      member.items[itemLink] = nil
    else
      totalValue = totalValue + (item.totalValue or 0)
      if (item.value or 0) > (bestItem.value or 0) then
        bestItem = {
          itemLink = item.itemLink,
          count = item.count,
          value = item.value,
          totalValue = item.totalValue
        }
      end
    end
  end

  member.bestItem = bestItem
  member.totalValue = totalValue
  self:FireCallbacks('OnKeysUpdated')
end
