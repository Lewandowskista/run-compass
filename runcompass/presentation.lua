local Presentation = {}
local Strings = require("runcompass.strings")

local LABELS = {
  ranked_frontier = "Best revealed frontier",
  treasure_detour = "Worthwhile treasure detour",
  shop_detour = "Worthwhile shop detour",
  character_synergy = "Strong for this character",
  owned_item_synergy = "Synergizes with owned items",
  anti_synergy = "Conflicts with the current build",
  transformation_threshold = "Completes or advances a transformation",
  active_replacement_loss = "Replacing the active loses stored value",
  goal_resource_reserved = "Preserve resources for the target"
}

function Presentation.label(code)
  return LABELS[code] or tostring(code or "")
end

function Presentation.lines(recommendation, settings)
  local lines = {}
  for index, step in ipairs(recommendation.steps or {}) do
    if index > 3 then break end
    lines[#lines + 1] = step
  end
  if recommendation.reasonCodes and recommendation.reasonCodes.resource_reservation then
    lines[#lines + 1] = "Preserve required resources"
  end
  if recommendation.status == "unreachable" then lines[#lines + 1] = Strings.get("hud.unreachable") end
  if recommendation.status == "inactive" then lines[#lines + 1] = Strings.get("hud.inactive") end
  if recommendation.status == "prerequisite_redirect" then lines[#lines + 1] = Strings.get("hud.prerequisite") end
  if recommendation.status == "instructional" then lines[#lines + 1] = Strings.get("hud.instructional") end
  if recommendation.status == "waiting" then lines[#lines + 1] = Strings.get("hud.waiting") end
  if recommendation.status == "error" then lines[#lines + 1] = Strings.get("hud.error") end
  local decision = settings and settings.autoCompare == false and nil or recommendation.decision
  if decision and decision.primary then
    lines[#lines + 1] = Strings.get("hud.choice", tostring(decision.primary.action), tostring(decision.primary.choiceId))
    if (not settings or settings.eidDescriptions ~= false) and decision.primary.description then lines[#lines + 1] = decision.primary.description end
    if not settings or (settings.detailLevel or 3) >= 3 then
      local reasons = {}
      for reason, enabled in pairs(decision.primary.reasonCodes or {}) do if enabled then reasons[#reasons + 1] = reason end end
      table.sort(reasons)
      for _, reason in ipairs(reasons) do lines[#lines + 1] = Strings.get("hud.why", tostring(reason)) end
    end
    if (not settings or (settings.detailLevel or 3) >= 2) and decision.alternatives and decision.alternatives[1] then lines[#lines + 1] = Strings.get("hud.alternative", tostring(decision.alternatives[1].action)) end
    if (not settings or (settings.detailLevel or 3) >= 2) and decision.skip and decision.skip ~= decision.primary then lines[#lines + 1] = Strings.get("hud.hold") end
    if not settings or settings.showWarnings ~= false then
      for _, warning in ipairs(decision.primary.warnings or {}) do lines[#lines + 1] = Strings.get("hud.warning", tostring(warning)) end
    end
  end
  if not settings or settings.showConfidence ~= false then
    lines[#lines + 1] = Strings.get("hud.confidence", string.upper(recommendation.confidence or "low"), string.upper(recommendation.capabilityTier or "base"))
  end
  return lines
end

return Presentation
