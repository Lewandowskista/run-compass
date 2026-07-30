local Profiles = {}

Profiles.version = "1.3.0"
Profiles.source = "vanilla:repentance-plus-1.3"

local function clone(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, item in pairs(value) do result[key] = clone(item) end
  return result
end

local function profile(token, fields)
  fields = fields or {}
  fields.id = fields.id or "character:" .. token
  fields.source = fields.source or Profiles.source
  fields.sourceVersion = fields.sourceVersion or Profiles.version
  fields.confidence = fields.confidence or "high"
  fields.effects = fields.effects or {}
  return fields
end

local records = {
  isaac = profile("isaac", { effects = { offense = 0.2 } }),
  magdalene = profile("magdalene", { effects = { sustain = 1, defense = 0.25 } }),
  cain = profile("cain", { effects = { luck = 1, economy = 0.25 } }),
  judas = profile("judas", { effects = { offense = 1, defense = -0.25 } }),
  blue_baby = profile("blue_baby", { effects = { defense = 0.2, sustain = -0.5 }, healthRestrictions = { noRedHealth = true } }),
  eve = profile("eve", { effects = { offense = 0.5, sustain = -0.25 } }),
  samson = profile("samson", { effects = { offense = 0.4, volatility = 0.5 } }),
  azazel = profile("azazel", { effects = { bossDamage = 0.5, routeAccess = 1 } }),
  lazarus = profile("lazarus", { effects = { sustain = 0.25, volatility = 0.25 } }),
  eden = profile("eden", { effects = {}, confidence = "low", liveBuild = true, randomStart = true }),
  the_lost = profile("the_lost", { effects = { defense = 1 }, healthRestrictions = { noRedHealth = true, holyMantle = true } }),
  lilith = profile("lilith", { effects = { familiar = 1, activeUtility = 0.5 } }),
  keeper = profile("keeper", { effects = { economy = 2, defense = -0.5 }, healthRestrictions = { noRedHealth = true, coinHealth = true } }),
  apollyon = profile("apollyon", { effects = { activeUtility = 0.75, offense = 0.25 } }),
  the_forgotten = profile("the_forgotten", { effects = { offense = 0.5, defense = 0.25 }, soulToken = "soul", actors = { forgotten = true, soul = true }, healthRestrictions = { boneHearts = true } }),
  bethany = profile("bethany", { effects = { activeUtility = 1, soulCharges = 1 } }),
  jacob_and_esau = profile("jacob_and_esau", { effects = { defense = -0.5, offense = 0.5 }, actors = { jacob = true, esau = true }, actorAllocation = { jacob = "primary", esau = "secondary" }, splitStats = true }),
  tainted_isaac = profile("tainted_isaac", { effects = { economy = 0.5 }, slotLimit = 8, replacementOnPickup = true, visibleSlots = true }),
  tainted_cain = profile("tainted_cain", { effects = { economy = 2, activeUtility = 0.5 }, visibleEconomy = true, crafting = { recipeVisibility = "observed", preserveIngredients = true } }),
  tainted_lazarus = profile("tainted_lazarus", { effects = { activeUtility = 1, volatility = 1 }, flip = { slots = 2, replacement = "flip_actor" }, actors = { living = true, dead = true }, actorAllocation = { living = "primary", dead = "flip" } }),
  tainted_lost = profile("tainted_lost", { effects = { defense = 2, volatility = 1 }, healthRestrictions = { noRedHealth = true, noHolyMantle = true } }),
  tainted_keeper = profile("tainted_keeper", { effects = { economy = 2, defense = -1 }, healthRestrictions = { noRedHealth = true, coinHealth = true } }),
  tainted_jacob = profile("tainted_jacob", { effects = { defense = -0.75, offense = 0.5 }, actors = { jacob = true, esau = true, cursed = true }, actorAllocation = { jacob = "primary", esau = "secondary" }, curseOfEsau = true, splitStats = true })
}

Profiles.records = records

function Profiles.get(token)
  return clone(records[token] or profile(token or "unknown", { confidence = "low", status = "data_update_required" }))
end

function Profiles.all()
  local result = {}
  for token, value in pairs(records) do result[token] = clone(value) end
  return result
end

function Profiles.validate(tokens)
  local report = { total = 0, modeled = 0, unknown = {} }
  for _, token in ipairs(tokens or {}) do
    report.total = report.total + 1
    if records[token] then report.modeled = report.modeled + 1 else report.unknown[#report.unknown + 1] = token end
  end
  return report
end

return Profiles
