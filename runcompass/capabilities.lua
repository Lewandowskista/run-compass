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
    persistentProgress = false,
    preciseEvents = false,
    repentogonVersion = nil
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
      result.persistentProgress = true
      result.preciseEvents = true
    end
  end
  return result
end

return Capabilities
