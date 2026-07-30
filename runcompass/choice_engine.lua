local ChoiceEngine = {}
local BuildState = require("runcompass.build_state")
local ItemModels = require("runcompass.item_models")

local function addEffects(target, effects)
  for key, value in pairs(effects or {}) do target[key] = (target[key] or 0) + (tonumber(value) or 0) end
end

local function score(effects, action)
  local value = (effects.offense or 0) * 10 + (effects.bossDamage or 0) * 12 + (effects.defense or 0) * 11
    + (effects.sustain or 0) * 8 + (effects.routeAccess or 0) * 9 + (effects.economy or 0) * 4
  if action == "skip" then value = value - 1 end
  return value
end

local function actionFor(choice)
  if choice.action then return choice.action end
  if choice.kind == "skip" then return "skip" end
  if choice.kind == "shop" then return "buy" end
  if choice.kind == "active" then return "replace_active" end
  if choice.kind == "reroll" then return "reroll" end
  if choice.kind == "hold" then return "hold" end
  if choice.kind == "machine" or choice.kind == "beggar" or choice.kind == "sacrifice" then return "interact" end
  return "take"
end

local function unavailableWarning(availability)
  if availability == "unknown_cost" then return "unknown_cost" end
  if availability == "unsupported" then return "unsupported_mechanic" end
  if availability == "insufficient_information" then return "insufficient_information" end
  return nil
end

local function better(left, right)
  local leftVector, rightVector = left.scoreVector, right.scoreVector
  local fields = { { "feasible", true }, { "survival", true }, { "resourceMargin", true }, { "goalUtility", true }, { "buildGain", true }, { "volatility", false }, { "detour", false } }
  for _, field in ipairs(fields) do
    local key, higher = field[1], field[2]
    local a, b = leftVector[key] or 0, rightVector[key] or 0
    if a ~= b then
      if higher then return a > b end
      return a < b
    end
  end
  return left.choiceId < right.choiceId
end

function ChoiceEngine.evaluate(snapshot, choices, goal, models, descriptions)
  models = models or ItemModels.new()
  local build = BuildState.fromPlayer(snapshot and snapshot.player or {})
  build.featureSummary = models:featureSummary(build)
  local evaluations = {}
  for _, choice in ipairs(choices or {}) do
    local action = actionFor(choice)
    local item = choice.observedIdentity or {}
    local actors = choice.eligibleActors or { choice.actorToken or build.actorToken }
    if build.characterToken == "jacob_and_esau" and #actors == 1 and actors[1] == "primary" then actors = { "jacob", "esau" } end
    for _, actorToken in ipairs(actors) do
      local actorBuild = BuildState.clone(build)
      actorBuild.actorToken = actorToken
      local model = models:evaluate(item.id, actorBuild, goal, choice.kind)
      local effects = model.effects or {}
      if choice.replacement and (action == "replace" or action == "replace_active") then
        local charged = false
        for _, active in ipairs(build.actives or {}) do
          if (tonumber(active.id) or 0) > 0 and ((tonumber(active.charge) or 0) > 0 or (tonumber(active.batteryCharge) or 0) > 0) then charged = true; break end
        end
        if charged then
          addEffects(effects, { activeUtility = -2 })
          model.reasonCodes.active_replacement_loss = true
          model.warnings[#model.warnings + 1] = "charged_active_replaced"
        end
      end
      local profile = models.characterProfiles and models.characterProfiles[build.characterToken]
      if profile and profile.effects then effects = addEffects(effects, profile.effects) or effects; model.reasonCodes.character_profile = true end
      local identityHidden = (choice.kind == "collectible" or choice.kind == "trinket" or choice.kind == "card" or choice.kind == "pill") and item.id == nil
      local feasible = true
      local resourceWarnings = {}
      local available = build.resources or {}
      local reserve = (goal and (goal.resourceReserve or goal.reserve)) or {}
      local costs = choice.resourceCost or ((tonumber(choice.price) or 0) > 0 and { coins = tonumber(choice.price) } or {})
      local unavailable = unavailableWarning(choice.availability)
      if unavailable then
        feasible = false
        table.insert(resourceWarnings, unavailable)
        model.reasonCodes.insufficient_information = true
        action = "insufficient_information"
      end
      for resource, amount in pairs(costs) do
        if resource ~= "activeCharge" and (available[resource] or 0) < (tonumber(amount) or 0) then
          feasible = false
          resourceWarnings[#resourceWarnings + 1] = resource == "coins" and "insufficient_coins" or "insufficient_resource"
        elseif resource ~= "activeCharge" and (available[resource] or 0) < ((tonumber(amount) or 0) + (tonumber(reserve[resource]) or 0)) then
          feasible = false
          resourceWarnings[#resourceWarnings + 1] = "route_reserve_required"
        end
      end
      if identityHidden then
        feasible = false
        action = "insufficient_information"
        table.insert(model.warnings, 1, "identity_hidden")
        model.reasonCodes.insufficient_information = true
      end
      for _, warning in ipairs(resourceWarnings) do table.insert(model.warnings, 1, warning) end
      if not feasible then model.reasonCodes.resource_insufficient = true end
      if model.reasonCodes.character_restriction then feasible = false end
      local value = (identityHidden or not feasible) and -1000 or score(effects, action) - (tonumber(choice.price) or 0) * 0.1
      local resourceMargin = math.huge
      for resource, amount in pairs(costs) do if resource ~= "activeCharge" then resourceMargin = math.min(resourceMargin, (available[resource] or 0) - (tonumber(amount) or 0)) end end
      if resourceMargin == math.huge then resourceMargin = 0 end
      evaluations[#evaluations + 1] = {
        action = action,
        actorToken = actorToken,
        choiceId = choice.id,
        name = item.name,
        position = choice.position,
        kind = choice.kind,
        scoreVector = { feasible = feasible and 1 or 0, survival = effects.defense or 0, resourceMargin = resourceMargin, goalUtility = effects.bossDamage or effects.routeAccess or 0, buildGain = value, volatility = effects.volatility or 0, detour = 0 },
        effectDelta = effects,
        synergyRuleIds = model.ruleIds,
        reasonCodes = model.reasonCodes,
        warnings = model.warnings,
        description = descriptions and item.id and descriptions:describe(item.id, snapshot and snapshot.visibility) or nil,
        confidence = choice.confidence or model.confidence,
        value = value
      }
    end
  end
  table.sort(evaluations, better)
  local result = { primary = evaluations[1], alternatives = {}, skip = nil, comparisonRequired = #evaluations > 1 }
  for _, evaluation in ipairs(evaluations) do
    if evaluation.action == "skip" then result.skip = evaluation end
  end
  for index = 2, math.min(3, #evaluations) do result.alternatives[#result.alternatives + 1] = evaluations[index] end
  return result
end

return ChoiceEngine
