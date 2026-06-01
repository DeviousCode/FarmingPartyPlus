FarmingPartyPlusMemberItem = {}

function FarmingPartyPlusMemberItem:New(itemLink)
  return {
    itemLink = itemLink,
    count = 0,
    value = 0,
    totalValue = 0
  }
end

function FarmingPartyPlusMemberItem:UpdateItemCount(item, value, count)
  item.count = item.count + count
  item.value = value
  item.totalValue = item.count * item.value
  return item
end
