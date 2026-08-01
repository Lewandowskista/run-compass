local Rules = {}

Rules.version = "1.5.0"
Rules.source = "vanilla:repentance-plus-1.5"

local function rule(id, family, fields)
  fields = fields or {}
  fields.id, fields.family = fields.id or id, fields.family or family
  fields.source = fields.source or Rules.source
  fields.sourceVersion = fields.sourceVersion or Rules.version
  return fields
end

local records = {
  rule("tear:shared_delivery", "tear", { requires = { candidateTag = "tear", ownedTag = "tear" }, effects = { offense = 0.15 }, confidence = "medium" }),
  rule("tear:rapid_fire_cap", "tear", { requires = { candidateTag = "tear", ownedTag = "rapid_fire" }, diminishingReturns = true, cap = "tearRate" }),
  rule("beam:explicit_pair", "beam", { requires = { candidateTag = "beam", ownedTag = "beam" }, effects = { bossDamage = 0.25 }, confidence = "medium" }),
  rule("knife:explicit_pair", "knife", { requires = { candidateTag = "knife", ownedTag = "knife" }, effects = { offense = 0.2 } }),
  rule("familiar:duplicate_cap", "familiar", { requires = { candidateTag = "familiar", ownedTag = "familiar" }, diminishingReturns = true, maxStacks = 4 }),
  rule("technology:explicit_pair", "technology", { requires = { candidateTag = "technology", ownedTag = "technology" }, effects = { offense = 0.15 } }),
  rule("duplicates", "duplicates", { diminishingReturns = true, statCaps = { tearRate = 5, speed = 2, luck = 10 }, duplicatePolicy = "first_full_then_marginal" }),
  rule("stat_caps", "stat_caps", { caps = { tearRate = 5, speed = 2, luck = 10, damage = 100 }, diminishingReturns = true }),
  rule("active_charge_replacement", "active_charge_replacement", { requires = { candidateKind = "active" }, preservesCharge = false, chargedLoss = true, replacementWarning = "active_replacement_loss" }),
  rule("health_restrictions", "health_restrictions", { requiresRedHealth = true, incompatibleCharacters = { the_lost = true, tainted_lost = true, keeper = true, tainted_keeper = true, blue_baby = true, tainted_blue_baby = true }, warning = "requires_red_health" }),
  rule("route_critical_utilities", "route_critical_utilities", { tags = { routeAccess = true, quest = true, battery = true }, effects = { routeAccess = 1 } }),
  rule("actor_allocation", "actor_allocation", { characters = { jacob_and_esau = { "jacob", "esau" }, tainted_jacob = { "jacob", "esau" }, tainted_lazarus = { "living", "dead" } }, allocationRequired = true })
}

local byFamily, byId = {}, {}
for _, entry in ipairs(records) do
  byId[entry.id] = entry
  byFamily[entry.family] = byFamily[entry.family] or {}
  byFamily[entry.family][#byFamily[entry.family] + 1] = entry
end

function Rules.all()
  local result = {}
  for index, entry in ipairs(records) do result[index] = entry end
  return result
end

function Rules.find(id)
  return byId[id]
end

function Rules.forFamily(family)
  local result = {}
  for _, entry in ipairs(byFamily[family] or {}) do result[#result + 1] = entry end
  return result
end

local function hasTag(tags, tag)
  return type(tags) == "table" and tags[tag] == true
end

function Rules.evaluate(candidate, owned, context)
  candidate, owned, context = candidate or {}, owned or {}, context or {}
  local result = { claimed = false, ruleIds = {}, effects = {}, warnings = {} }
  for _, entry in ipairs(records) do
    local requirement = entry.requires
    if requirement and requirement.candidateTag and requirement.ownedTag and hasTag(candidate.tags, requirement.candidateTag) and hasTag(owned.tags, requirement.ownedTag) then
      result.claimed = true
      result.ruleIds[#result.ruleIds + 1] = entry.id
      for key, value in pairs(entry.effects or {}) do result.effects[key] = (result.effects[key] or 0) + value end
    end
  end
  if context.characterToken and byId.health_restrictions and byId.health_restrictions.incompatibleCharacters[context.characterToken] then
    result.warnings[#result.warnings + 1] = "requires_red_health"
  end
  return result
end

function Rules.diagnostics()
  local families, tagged = 0, 0
  for family in pairs(byFamily) do families = families + 1; if #byFamily[family] > 0 then tagged = tagged + 1 end end
  return { version = Rules.version, source = Rules.source, total = #records, families = families, indexedFamilies = tagged }
end

return Rules
