local Hud = {}

local REASON_PRIORITY = {
  "goal_resource_reserved",
  "active_replacement_loss",
  "anti_synergy",
  "transformation_threshold",
  "owned_item_synergy",
  "character_synergy",
  "ranked_frontier"
}

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

function Hud.view(recommendation, targetName, expanded)
  local primary = recommendation.decision and recommendation.decision.primary or nil
  local lines = {}
  for index, step in ipairs(recommendation.steps or {}) do
    if index > (expanded and 3 or 1) then break end
    lines[#lines + 1] = step
  end
  local reason = primary and Hud.strongestReason(primary.reasonCodes) or Hud.strongestReason(recommendation.reasonCodes)
  if reason then lines[#lines + 1] = reason end
  if primary and primary.name then lines[#lines + 1] = primary.name end
  while not expanded and #lines > 4 do table.remove(lines) end
  return {
    target = targetName,
    status = recommendation.status,
    lines = lines,
    action = primary and string.upper(primary.action or "") or nil,
    choiceName = primary and primary.name or nil,
    choicePosition = primary and primary.position or nil,
    confidence = primary and primary.confidence or recommendation.confidence,
    warnings = primary and primary.warnings or {},
    nextDoorSlot = recommendation.nextDoorSlot,
    expanded = expanded == true
  }
end

return Hud
