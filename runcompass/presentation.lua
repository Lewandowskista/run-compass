local Presentation = {}

function Presentation.lines(recommendation)
  local lines = {}
  for index, step in ipairs(recommendation.steps or {}) do
    if index > 3 then break end
    lines[#lines + 1] = step
  end
  if recommendation.reasonCodes and recommendation.reasonCodes.resource_reservation then
    lines[#lines + 1] = "Preserve required resources"
  end
  if recommendation.status == "unreachable" then lines[#lines + 1] = "Target is not reachable with current information" end
  if recommendation.status == "inactive" then lines[#lines + 1] = "Guidance unavailable in this run mode" end
  lines[#lines + 1] = string.upper(recommendation.confidence or "low") .. " / " .. string.upper(recommendation.capabilityTier or "base")
  return lines
end

return Presentation
