local ItemModels = {}
ItemModels.__index = ItemModels

local function clone(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, item in pairs(value) do result[key] = clone(item) end
  return result
end

local function addEffects(target, effects)
  for key, value in pairs(effects or {}) do target[key] = (target[key] or 0) + (tonumber(value) or 0) end
end

local function keyFor(id, kind)
  if kind and kind ~= "collectible" then return tostring(kind) .. ":" .. tostring(id) end
  return tonumber(id) or id
end

function ItemModels.new(models, metadata)
  local self = setmetatable({ models = {}, metadata = metadata or {}, diagnostics = {}, characterProfiles = {} }, ItemModels)
  for id, model in pairs(models or {}) do self.models[tonumber(id) or id] = clone(model) end
  return self
end

function ItemModels.fromCatalog(items, curated, profiles)
  local models = {}
  curated, profiles = curated or {}, profiles or {}
  for _, item in ipairs(items or {}) do
    local quality = tonumber(item.quality) or 0
    local model = {
      name = item.name,
      kind = item.kind or "collectible",
      quality = quality,
      tags = clone(item.tags or {}),
      effects = { offense = math.max(0, quality) * 0.25, defense = quality >= 3 and 0.15 or 0 },
      confidence = "low",
      status = "metadata_baseline"
    }
    local override = curated[(item.kind and item.kind .. ":" .. tostring(item.id))] or ((not item.kind or item.kind == "collectible") and curated[item.id])
    if override then
      for key, value in pairs(clone(override)) do model[key] = value end
      model.confidence = "high"
      model.status = "curated"
    end
    if profiles[item.id] then model.characterModifiers = clone(profiles[item.id]) end
    models[keyFor(item.id, item.kind)] = model
  end
  return ItemModels.new(models, { source = "ItemConfig + curated-v1.1" })
end

function ItemModels:register(id, model)
  if id == nil or type(model) ~= "table" then return false, "invalid_model" end
  local copy = clone(model)
  self.models[keyFor(id, copy.kind)] = copy
  return true
end

function ItemModels:get(id, kind)
  local keyed = kind and self.models[keyFor(id, kind)]
  return keyed or self.models[id] or self.models[tonumber(id)]
end

function ItemModels:featureSummary(build)
  local summary = { effects = {}, tags = {}, modelIds = {} }
  for id, count in pairs((build and build.collectibles) or {}) do
    local model = self:get(id, "collectible") or self:get(id)
    if model then
      local multiplier = tonumber(count) or 1
      for key, value in pairs(model.effects or {}) do summary.effects[key] = (summary.effects[key] or 0) + (tonumber(value) or 0) * multiplier end
      for tag, enabled in pairs(model.tags or {}) do if enabled then summary.tags[tag] = (summary.tags[tag] or 0) + multiplier end end
      summary.modelIds[#summary.modelIds + 1] = id
    end
  end
  return summary
end

function ItemModels:evaluate(id, build, goal, kind)
  local model = self:get(id, kind) or { effects = {}, tags = {}, status = "data_update_required" }
  local result = { effects = clone(model.effects or {}), tags = clone(model.tags or {}), reasonCodes = {}, ruleIds = {}, confidence = model.status == "data_update_required" and "low" or "medium", warnings = {} }
  if model.status == "data_update_required" then result.warnings[#result.warnings + 1] = "data_update_required" end
  for _, rule in ipairs(model.synergies or {}) do
    local owned = build and build.collectibles and build.collectibles[rule.owned]
    if owned and owned > 0 then
      addEffects(result.effects, rule.effects)
      result.reasonCodes.owned_item_synergy = true
      result.ruleIds[#result.ruleIds + 1] = rule.id or ("synergy:" .. tostring(id) .. ":" .. tostring(rule.owned))
    end
  end
  for _, rule in ipairs(model.tagSynergies or {}) do
    local count = build and build.featureSummary and build.featureSummary.tags and build.featureSummary.tags[rule.tag] or 0
    if count > 0 then
      addEffects(result.effects, rule.effects)
      result.reasonCodes.owned_item_synergy = true
      result.ruleIds[#result.ruleIds + 1] = rule.id or ("tag:" .. tostring(id) .. ":" .. tostring(rule.tag))
    end
  end
  for _, rule in ipairs(model.antiSynergies or {}) do
    local owned = build and build.collectibles and build.collectibles[rule.owned]
    if owned and owned > 0 then
      addEffects(result.effects, rule.effects)
      result.reasonCodes.anti_synergy = true
      result.ruleIds[#result.ruleIds + 1] = rule.id or ("anti:" .. tostring(id) .. ":" .. tostring(rule.owned))
    end
  end
  local character = build and build.characterToken
  local noRedHealth = { the_lost = true, tainted_lost = true, keeper = true, tainted_keeper = true, blue_baby = true, tainted_blue_baby = true }
  if model.requiresRedHealth and noRedHealth[character] then
    result.effects.sustain = (result.effects.sustain or 0) - 8
    result.reasonCodes.character_restriction = true
    result.warnings[#result.warnings + 1] = "requires_red_health"
  end
  if model.blockedCharacters and model.blockedCharacters[character] then
    result.effects.routeAccess = (result.effects.routeAccess or 0) - 10
    result.reasonCodes.character_restriction = true
    result.warnings[#result.warnings + 1] = "blocked_for_character"
  end
  for _, rule in ipairs(model.characterModifiers or {}) do
    if rule.characterToken == character then
      addEffects(result.effects, rule.effects)
      result.reasonCodes.character_synergy = true
      result.ruleIds[#result.ruleIds + 1] = rule.id or ("character:" .. tostring(id) .. ":" .. tostring(character))
    end
  end
  for _, rule in ipairs(model.actorModifiers or {}) do
    if rule.actorToken == (build and build.actorToken) then
      addEffects(result.effects, rule.effects)
      result.reasonCodes.actor_allocation = true
      result.ruleIds[#result.ruleIds + 1] = rule.id or ("actor:" .. tostring(id) .. ":" .. tostring(rule.actorToken))
    end
  end
  if model.transformation then
    local transformation = model.transformation
    local current = build and build.transformations and build.transformations[transformation.token] or 0
    if current == true then
      result.reasonCodes.transformation_active = true
      current = transformation.threshold or 0
    elseif type(current) ~= "number" then
      current = tonumber(current) or 0
    end
    if current < transformation.threshold and current + (transformation.adds or 1) >= transformation.threshold then
      result.reasonCodes.transformation_threshold = true
      result.ruleIds[#result.ruleIds + 1] = transformation.id or ("transform:" .. tostring(transformation.token))
      addEffects(result.effects, transformation.effects or { transformationProgress = 1 })
    end
  end
  if goal and goal.id and model.goalEffects and model.goalEffects[goal.id] then addEffects(result.effects, model.goalEffects[goal.id]); result.reasonCodes.goal_utility = true end
  return result
end

function ItemModels:validate(ids)
  local report = { total = 0, modeled = 0, unknown = {} }
  for _, entry in ipairs(ids or {}) do
    local id, kind = entry, nil
    if type(entry) == "table" then id, kind = entry.id, entry.kind end
    report.total = report.total + 1
    if self:get(id, kind) then report.modeled = report.modeled + 1 else report.unknown[#report.unknown + 1] = id end
  end
  return report
end

return ItemModels
