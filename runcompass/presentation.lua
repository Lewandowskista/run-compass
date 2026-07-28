local Presentation = {}
local Strings = require("runcompass.strings")

function Presentation.lines(recommendation)
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
  lines[#lines + 1] = Strings.get("hud.confidence", string.upper(recommendation.confidence or "low"), string.upper(recommendation.capabilityTier or "base"))
  return lines
end

return Presentation
