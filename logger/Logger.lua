FarmingPartyPlusLogger = ZO_Object:Subclass()

function FarmingPartyPlusLogger:Finalize()
end

local function GetItemIcon(itemLink, lootType)
  local icon = ''
  if lootType == LOOT_TYPE_COLLECTIBLE then
    local collectibleId = GetCollectibleIdFromLink(itemLink)
    local _, _, collectibleIcon = GetCollectibleInfo(collectibleId)
    icon = collectibleIcon
  else
    local itemIcon = GetItemLinkInfo(itemLink)
    icon = itemIcon or ''
  end
  icon = icon ~= '' and ('|t16:16:' .. icon .. '|t ') or ''
  return icon
end

local function CreateTimestamp()
  local timeString = GetTimeString()
  local hours, minutes, seconds = timeString:match('([^%:]+):([^%:]+):([^%:]+)')
  local month, day, year = GetDateStringFromTimestamp(GetTimeStamp()):match('(%d+).(%d+).(%d+)')

  local timestamp = FarmingPartyPlus.Settings:GetSettings().logWindow.timestampFormat
  local replace = {
    DD = day,
    MM = month,
    YYYY = year,
    HH = hours,
    mm = minutes,
    ss = seconds
  }

  return zo_strformat('|cFFFFFF<<1>>|r', timestamp:gsub('%a+', replace))
end

function FarmingPartyPlusLogger:LogLootItem(looterName, lootedByPlayer, itemLink, quantity, totalValue, lootType)
  local icon = GetItemIcon(itemLink, lootType)
  local displayQuantity = math.abs(quantity)
  local displayTotalValue = math.abs(totalValue)
  local itemValueText = FarmingPartyPlus.Settings:DisplayLootValue()
      and zo_strformat(' - |cFFFFFF<<1>>|r|t16:16:EsoUI/Art/currency/currency_gold.dds|t', FarmingPartyPlus.FormatNumber(displayTotalValue))
      or ''
  local itemText

  if displayQuantity == 1 then
    itemText = zo_strformat(icon .. itemLink .. itemValueText)
  else
    itemText = zo_strformat(icon .. itemLink .. ' |cFFFFFFx' .. displayQuantity .. '|r' .. itemValueText)
  end

  local lootMessage
  if quantity < 0 then
    if not lootedByPlayer then
      if not FarmingPartyPlus.Settings:DisplayGroupLoot() then
        return
      end
      lootMessage = zo_strformat('|cFFFFFF<<1>>|r |cCC8844processed|r <<2>>', looterName, itemText)
    else
      if not FarmingPartyPlus.Settings:DisplayOwnLoot() then
        return
      end
      lootMessage = zo_strformat('|cCC8844Processed|r <<1>>', itemText)
    end
  elseif not lootedByPlayer then
    if not FarmingPartyPlus.Settings:DisplayGroupLoot() then
      return
    end
    lootMessage = zo_strformat('|cFFFFFF<<1>>|r |c228B22received|r <<2>>', looterName, itemText)
  else
    if not FarmingPartyPlus.Settings:DisplayOwnLoot() then
      return
    end
    lootMessage = zo_strformat('|c228B22Received|r <<1>>', itemText)
  end

  if FarmingPartyPlus.Settings:DisplayInChat() then
    CHAT_SYSTEM:AddMessage(lootMessage)
  end

  local timestamp = FarmingPartyPlus.Settings:ShowWindowTimestamp() and CreateTimestamp() or ''
  FarmingPartyPlusWindowBuffer:AddMessage(timestamp .. ' ' .. lootMessage, 255, 255, 0, 1)
end
