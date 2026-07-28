local Capabilities = {}

local function versionAtLeast(version, minimum)
  local function parts(value)
    local result = {}
    for number in string.gmatch(value or "0", "%d+") do result[#result + 1] = tonumber(number) end
    return result
  end
  local actual, required = parts(version), parts(minimum)
  for index = 1, math.max(#actual, #required) do
    local left, right = actual[index] or 0, required[index] or 0
    if left ~= right then return left > right end
  end
  return true
end

function Capabilities.detect(repentogon, dependencies)
  dependencies = dependencies or {}
  local result = {
    tier = "base",
    mcm = dependencies.ModConfigMenu ~= nil,
    persistentAchievements = false,
    completionMarks = false,
    persistentProgress = false,
    preciseEvents = false,
    repentogonVersion = nil,
    diagnostics = {}
  }
  if type(repentogon) == "table" and type(repentogon.Version) == "string" then
    result.repentogonVersion = repentogon.Version
    local compatible = versionAtLeast(repentogon.Version, "1.1.0")
    if type(repentogon.MeetsVersion) == "function" then
      local ok, value = pcall(repentogon.MeetsVersion, "1.1.0")
      compatible = ok and value == true
    end
    if compatible then
      result.tier = "enhanced"
      local isaac = dependencies.isaac or rawget(_G, "Isaac") or {}
      local game = dependencies.game or {}
      local callbacks = dependencies.callbacks or rawget(_G, "ModCallbacks") or {}
      result.persistentAchievements = type(isaac.GetPersistentGameData) == "function"
      result.completionMarks = type(isaac.GetCompletionMarks) == "function"
      result.preciseEvents = callbacks.MC_POST_ACHIEVEMENT_UNLOCK ~= nil and callbacks.MC_POST_COMPLETION_MARK_GET ~= nil
      result.persistentProgress = result.persistentAchievements or result.completionMarks
      if not result.persistentAchievements then result.diagnostics.persistentAchievements = "read API unavailable" end
      if not result.completionMarks then result.diagnostics.completionMarks = "read API unavailable" end
      if not result.preciseEvents then result.diagnostics.preciseEvents = "callback constants unavailable" end
      result.diagnostics.achievementUnlocksDisallowed = type(game.AchievementUnlocksDisallowed) == "function" and "available" or "unavailable"
    end
  else
    result.diagnostics.repentogon = "missing or outdated"
  end
  return result
end

return Capabilities
