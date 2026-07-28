local ChoiceEngine = require("runcompass.choice_engine")

local Recommendation = {}

local ACTIONABLE = { ok = true, explore = true }

function Recommendation.finalize(snapshot, goal, recommendation, milestone, decisionModels)
  recommendation.reasonCodes = recommendation.reasonCodes or {}
  for code, enabled in pairs(milestone and milestone.reasonCodes or {}) do
    recommendation.reasonCodes[code] = enabled
  end
  if milestone and next(milestone.requiredItems or {}) then
    recommendation.reasonCodes.required_quest_items = true
  end
  if not ACTIONABLE[recommendation.status] then return recommendation end
  local visibleChoices = {}
  for _, choice in ipairs(snapshot.visibleChoices or {}) do
    if choice.roomId == snapshot.currentRoom then visibleChoices[#visibleChoices + 1] = choice end
  end
  if #visibleChoices > 0 then
    recommendation.decision = ChoiceEngine.evaluate(
      snapshot,
      visibleChoices,
      goal,
      decisionModels or snapshot.decisionModels,
      snapshot.eid
    )
  end
  return recommendation
end

return Recommendation
