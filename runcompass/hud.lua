local Hud = {}
local Strings = require("runcompass.strings")

local NON_ACTIONABLE_STATUS_KEYS = {
  unreachable = "hud.unreachable",
  inactive = "hud.inactive",
  prerequisite_redirect = "hud.prerequisite",
  instructional = "hud.instructional",
  waiting = "hud.waiting",
  error = "hud.error"
}

local REASON_PRIORITY = {
  "goal_resource_reserved",
  "active_replacement_loss",
  "anti_synergy",
  "transformation_threshold",
  "owned_item_synergy",
  "character_synergy",
  "ranked_frontier"
}

local MARKER_STATES = {
  take = "TAKE",
  buy = "BUY",
  hold = "HOLD",
  skip = "SKIP",
  reroll = "REROLL",
  replace = "REPLACE",
  replace_active = "REPLACE",
  interact = "INTERACT",
  insufficient_information = "INSUFFICIENT INFORMATION"
}

local WARNING_LABELS = {
  data_update_required = "limited item data",
  active_replacement_loss = "active replacement risk",
  charged_active_replaced = "charged active would be replaced",
  unknown_cost = "unknown cost",
  unsupported_mechanic = "unsupported mechanic",
  insufficient_information = "insufficient information",
  identity_hidden = "identity hidden",
  insufficient_coins = "not enough coins",
  insufficient_resource = "not enough resources",
  route_reserve_required = "route resource reserve required"
}

local function warningLabel(warning)
  return WARNING_LABELS[warning] or tostring(warning or "caution"):gsub("_", " ")
end

function Hud.strongestReason(reasonCodes)
  for _, reason in ipairs(REASON_PRIORITY) do
    if reasonCodes and reasonCodes[reason] then return reason end
  end
  if reasonCodes then
    local keys = {}
    for reason, enabled in pairs(reasonCodes) do if enabled then keys[#keys + 1] = reason end end
    table.sort(keys)
    return keys[1]
  end
end

function Hud.doorPosition(game, slot)
  if not game or slot == nil or type(game.GetRoom) ~= "function" then return nil end
  local ok, room = pcall(game.GetRoom, game)
  if not ok or not room or type(room.GetDoorSlotPosition) ~= "function" then return nil end
  local positioned, value = pcall(room.GetDoorSlotPosition, room, slot)
  if not positioned or not value then return nil end
  return { x = value.X or 0, y = value.Y or 0 }
end

function Hud.markerState(primary)
  if not primary then return nil end
  if primary.warnings and #primary.warnings > 0 then return "CAUTION" end
  return MARKER_STATES[primary.action] or string.upper(tostring(primary.action or ""))
end

function Hud.view(recommendation, targetName, expanded, settings)
  settings = settings or {}
  local autoCompare = settings.autoCompare ~= false
  local detailLevel = math.max(1, math.min(3, tonumber(settings.detailLevel) or 3))
  local showConfidence = settings.showConfidence ~= false
  local showWarnings = settings.showWarnings ~= false
  local eidDescriptions = settings.eidDescriptions ~= false

  local primary = autoCompare and recommendation.decision and recommendation.decision.primary or nil
  local lines = {}
  local collapsedStepBudget = detailLevel >= 2 and 1 or 0
  local expandedStepBudget = detailLevel >= 3 and 3 or (detailLevel == 2 and 2 or 0)
  local stepBudget = expanded and expandedStepBudget or collapsedStepBudget
  for index, step in ipairs(recommendation.steps or {}) do
    if index > stepBudget then break end
    lines[#lines + 1] = step
  end

  local nonActionableKey = NON_ACTIONABLE_STATUS_KEYS[recommendation.status]
  if nonActionableKey then lines[#lines + 1] = Strings.get(nonActionableKey) end

  local reason = primary and Hud.strongestReason(primary.reasonCodes) or Hud.strongestReason(recommendation.reasonCodes)
  if reason and detailLevel >= 2 then lines[#lines + 1] = reason end
  if primary and primary.name then lines[#lines + 1] = primary.name end
  if primary and eidDescriptions and primary.description and detailLevel >= 3 then lines[#lines + 1] = primary.description end

  local strongestWarning = primary and primary.warnings and primary.warnings[1] or nil
  if showWarnings and strongestWarning then
    lines[#lines + 1] = Strings.get("hud.warning", warningLabel(strongestWarning))
  end

  local confidenceValue = primary and primary.confidence or recommendation.confidence
  if showConfidence and confidenceValue then
    lines[#lines + 1] = Strings.get("hud.confidence", string.upper(tostring(confidenceValue)), string.upper(recommendation.capabilityTier or "base"))
  end

  while not expanded and #lines > 4 do table.remove(lines) end
  return {
    target = targetName,
    status = recommendation.status,
    lines = lines,
    action = primary and string.upper(primary.action or "") or nil,
    choiceName = primary and primary.name or nil,
    choicePosition = primary and primary.position or nil,
    markerState = Hud.markerState(primary),
    confidence = confidenceValue,
    warnings = primary and primary.warnings or {},
    nextDoorSlot = recommendation.nextDoorSlot,
    expanded = expanded == true
  }
end

return Hud
