local ADDON_NAME = 'FarmingPartyPlus'

FarmingPartyPlus = ZO_Object:Subclass()
FarmingPartyPlus.Modules = {}
FarmingPartyPlus.DataTypes = {
  MEMBER = 1,
  MEMBER_ITEM = 2,
  FILTER_HEADER = 3,
  FILTER_ROW = 4
}
FarmingPartyPlus.SaveData = {}
FarmingPartyPlus.Settings = {}

local DIGIT_GROUP_REPLACER = ','
local DIGIT_GROUP_DECIMAL_REPLACER = '.'
local DIGIT_GROUP_REPLACER_THRESHOLD = zo_pow(10, GetDigitGroupingSize())

function FPPlus_LocalizeDecimalNumber(amount)
  if amount == 0 then
    amount = '0'
  end

  local amountNumber = tonumber(amount)
  if amountNumber >= DIGIT_GROUP_REPLACER_THRESHOLD then
    local decimalSeparatorIndex = zo_strfind(amount, '%' .. DIGIT_GROUP_DECIMAL_REPLACER)
    local decimalPartString = decimalSeparatorIndex and zo_strsub(amount, decimalSeparatorIndex) or ''
    local wholePartString = zo_strsub(amount, 1, decimalSeparatorIndex and decimalSeparatorIndex - 1)

    amount = ZO_CommaDelimitNumber(tonumber(wholePartString)) .. decimalPartString
  end

  return amount
end

function FarmingPartyPlus.FormatNumber(num)
  return FPPlus_LocalizeDecimalNumber(string.format('%0.' .. (FarmingPartyPlus.Settings:ValueDecimals() or 2) .. 'f', num))
end

local function OnPlayerDeactivated()
  FarmingPartyPlus:Finalize()
end

function FarmingPartyPlus:OnAddOnLoaded(event, addonName)
  if addonName ~= ADDON_NAME then
    return
  end

  ZO_CreateStringId('SI_BINDING_NAME_TOGGLE_SCOREBOARD_PLUS', 'Toggle Farming Party Plus Scoreboard')
  ZO_CreateStringId('SI_BINDING_NAME_TOGGLE_ITEM_BREAKDOWN_PLUS', 'Toggle Farming Party Plus Item Breakdown')
  ZO_CreateStringId('SI_BINDING_NAME_TOGGLE_FILTERS_PLUS', 'Toggle Farming Party Plus Filters')

  EVENT_MANAGER:RegisterForEvent(ADDON_NAME, EVENT_PLAYER_DEACTIVATED, OnPlayerDeactivated)
  EVENT_MANAGER:UnregisterForEvent(ADDON_NAME, EVENT_ADD_ON_LOADED)
  FarmingPartyPlus.Settings = FarmingPartyPlusSettings:New()
  self:ConsoleCommands()
  self:Initialize()
  d('[Farming Party Plus]: Loaded')
end

function FarmingPartyPlus:Finalize()
  for _, moduleObject in pairs(self.Modules) do
    moduleObject:Finalize()
  end

  if self.Settings:ResetStatusOnLogout() then
    self.Settings:ToggleStatusValue(FarmingPartyPlus.Settings.TRACKING_STATUS.DISABLED)
  end
end

function FarmingPartyPlus:Initialize()
  self:ConsoleCommands()
  self.Modules.MemberList = FarmingPartyPlusMemberList:New()
  self.Modules.Logger = FarmingPartyPlusLogger:New()
  self.Modules.MemberItems = FarmingPartyPlusMemberItems:New()
  self.Modules.FilterWindow = FarmingPartyPlusFilterWindow:New()
  self.Modules.Loot = FarmingPartyPlusLoot:New()
end

function FarmingPartyPlus:Prune()
  self.Modules.MemberList:PruneMissingMembers()
  d('[Farming Party Plus]: Members have been pruned')
end

function FarmingPartyPlus:UpdateMembers()
  self.Modules.MemberList:PruneMissingMembers()
  self.Modules.MemberList:AddAllGroupMembers()
  d('[Farming Party Plus]: Members have been updated')
end

function FarmingPartyPlus:Reset()
  self.Modules.MemberList:Reset()
  d('[Farming Party Plus]: Tracking data has been reset')
end

function FarmingPartyPlus:ConsoleCommands()
  SLASH_COMMANDS['/fpphelp'] = function()
    d('-- Farming Party Plus commands --')
    d('/fpp                  Show or hide the highscore window.')
    d('/fpp prune            Removes members no longer in group.')
    d('/fpp reset            Resets all loot data.')
    d('/fpp [start|stop]     Start or stop loot tracking.')
    d('/fpp [status]         Show loot tracking status.')
    d('/fpp update           Sync tracked members with current group.')
    d('/fpp filters          Open the node whitelist window.')
    d('/fpp whitelist on     Count only selected whitelist items.')
    d('/fpp whitelist off    Use the original quality-based filters.')
    d('/fppc                 Put score output into the chat box.')
  end

  SLASH_COMMANDS['/fpp'] = function(param)
    local trimmedParam = string.gsub(param or '', '%s+$', ''):lower()
    if trimmedParam == '' then
      self.Modules.MemberList:ToggleMembersWindow()
    elseif trimmedParam == 'prune' then
      self:Prune()
    elseif trimmedParam == 'reset' then
      self:Reset()
    elseif trimmedParam == 'start' then
      if FarmingPartyPlus.Settings:Status() == FarmingPartyPlus.Settings.TRACKING_STATUS.DISABLED then
        self.Modules.MemberList:AddEventHandlers()
        self.Modules.Loot:AddEventHandlers()
      end
      d('[Farming Party Plus]: Tracking is on')
    elseif trimmedParam == 'stop' or trimmedParam == 'pause' then
      self.Modules.MemberList:RemoveEventHandlers()
      self.Modules.Loot:RemoveEventHandlers()
      d('[Farming Party Plus]: Tracking is off')
    elseif trimmedParam == 'status' then
      if FarmingPartyPlus.Settings:Status() == FarmingPartyPlus.Settings.TRACKING_STATUS.ENABLED then
        d('[Farming Party Plus]: Tracking is on')
      else
        d('[Farming Party Plus]: Tracking is off')
      end
    elseif trimmedParam == 'update' then
      self:UpdateMembers()
    elseif trimmedParam == 'filters' then
      self.Modules.FilterWindow:ToggleWindow()
    elseif trimmedParam == 'whitelist on' then
      FarmingPartyPlus.Settings:SetWhitelistMode(true)
      d('[Farming Party Plus]: Whitelist mode is on')
    elseif trimmedParam == 'whitelist off' then
      FarmingPartyPlus.Settings:SetWhitelistMode(false)
      d('[Farming Party Plus]: Whitelist mode is off')
    elseif trimmedParam == 'help' then
      SLASH_COMMANDS['/fpphelp']()
    else
      d(string.format('Invalid parameter %s.', trimmedParam))
      SLASH_COMMANDS['/fpphelp']()
    end
  end

  SLASH_COMMANDS['/fppc'] = function()
    self.Modules.MemberList:PrintScoresToChat()
  end

  SLASH_COMMANDS['/fppm'] = function()
    FarmingPartyPlusMemberItems:ToggleWindow()
  end

  SLASH_COMMANDS['/fppfilters'] = function()
    self.Modules.FilterWindow:ToggleWindow()
  end
end

EVENT_MANAGER:RegisterForEvent(
  ADDON_NAME,
  EVENT_ADD_ON_LOADED,
  function(...)
    FarmingPartyPlus:OnAddOnLoaded(...)
  end
)
