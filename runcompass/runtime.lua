local Runtime = {}
Runtime.__index = Runtime
local Visibility = require("runcompass.visibility")

local function tier(capabilities)
  return capabilities and capabilities.tier or "base"
end

function Runtime.new(env)
  env = env or {}
  return setmetatable({
    adapter = env.adapter,
    controller = env.controller,
    getGoal = env.getGoal or function() return {} end,
    fingerprint = env.fingerprint or function() return "" end,
    output = env.output,
    capabilities = env.capabilities or { tier = "base" },
    decisionModels = env.decisionModels,
    eid = env.eid,
    assertFairPlay = env.assertFairPlay == true,
    ui = env.ui,
    snapshot = nil,
    recommendation = nil,
    lastFingerprint = nil,
    lastError = nil
  }, Runtime)
end

function Runtime:_error(message)
  message = tostring(message)
  if message ~= self.lastError and self.output then
    self.output("Routing paused: " .. message)
  end
  self.lastError = message
  self.recommendation = {
    status = "error",
    steps = { "Routing paused after an internal error" },
    reasonCodes = { internal_error = true },
    confidence = "none",
    capabilityTier = tier(self.capabilities)
  }
  return self.recommendation
end

function Runtime:update()
  if not self.adapter or not self.controller then return self.recommendation end
  local ok, snapshot = pcall(self.adapter.build, self.adapter)
  if not ok then return self:_error(snapshot) end
  if self.assertFairPlay then
    local fair, reason = Visibility.assertFairSnapshot(snapshot)
    if not fair then return self:_error(reason) end
  end
  snapshot = Visibility.sanitizeSnapshot(snapshot)
  snapshot.capabilities = self.capabilities
  snapshot.decisionModels = self.decisionModels
  snapshot.eid = self.eid
  local fingerprinted, nextFingerprint = pcall(self.fingerprint, snapshot)
  if not fingerprinted then return self:_error(nextFingerprint) end
  if self.lastFingerprint and nextFingerprint ~= self.lastFingerprint and self.controller.onEvent then
    self.controller:onEvent("PLAYER_STATE_CHANGED")
  end
  self.lastFingerprint = nextFingerprint
  local goalOk, goal = pcall(self.getGoal, snapshot)
  if not goalOk then return self:_error(goal) end
  local planned, recommendation = pcall(self.controller.tick, self.controller, snapshot, goal)
  if not planned then return self:_error(recommendation) end
  self.snapshot = snapshot
  self.recommendation = recommendation
  self.lastError = nil
  return recommendation
end

function Runtime:render()
  if self.ui and self.snapshot and self.recommendation then
    self.ui:render(self.snapshot, self.recommendation)
  end
end

function Runtime:getRecommendation()
  return self.recommendation
end

return Runtime
