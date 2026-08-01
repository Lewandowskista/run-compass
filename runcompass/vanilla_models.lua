local ItemModels = require("runcompass.item_models")
local Profiles = require("runcompass.character_profiles")

local VanillaModels = {}
VanillaModels.version = "1.3.0"
VanillaModels.source = "vanilla:repentance-plus-1.3"

local function clone(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, item in pairs(value) do result[key] = clone(item) end
  return result
end

local TAG_BITS = {
  { 1, "tear" }, { 2, "luck" }, { 4, "damage" }, { 8, "spider" },
  { 16, "fly" }, { 32, "poison" }, { 64, "fire" }, { 128, "technology" },
  { 256, "battery" }, { 512, "homing" }, { 1024, "pierce" }, { 2048, "slow" },
  { 4096, "charm" }, { 8192, "spawn" }, { 16384, "familiar" }, { 32768, "blood" },
  { 65536, "needs_charge" }, { 1048576, "offensive" }, { 2097152, "defensive" },
  { 4194304, "quest" }, { 8388608, "chest" }, { 16777216, "food" }
}

function VanillaModels.normalizeTags(raw)
  if type(raw) == "table" then
    local result = clone(raw)
    for _, value in pairs(raw) do if type(value) == "string" then result[value] = true end end
    return result
  end
  local mask, result = tonumber(raw) or 0, {}
  for _, pair in ipairs(TAG_BITS) do if mask % (pair[1] * 2) >= pair[1] then result[pair[2]] = true end end
  return result
end

VanillaModels.curated = {
  [68] = { effects = { offense = 2, bossDamage = 2 }, tags = { technology = true, tear = true }, source = VanillaModels.source, sourceVersion = VanillaModels.version },
  [114] = { effects = { offense = 3, bossDamage = 4 }, tags = { knife = true, tear = true }, antiSynergies = { { owned = 330, effects = { offense = -2 }, id = "mom_knife_soy_milk" } }, source = VanillaModels.source, sourceVersion = VanillaModels.version },
  [116] = { effects = { activeUtility = 2, economy = 1 }, tags = { battery = true }, source = VanillaModels.source, sourceVersion = VanillaModels.version },
  [118] = { effects = { offense = 3, bossDamage = 4 }, tags = { beam = true, tear = true }, source = VanillaModels.source, sourceVersion = VanillaModels.version },
  [152] = { effects = { offense = 2, bossDamage = 3 }, tags = { technology = true, tear = true }, source = VanillaModels.source, sourceVersion = VanillaModels.version },
  [182] = { effects = { offense = 4, defense = 2, bossDamage = 4 }, tags = { homing = true, tear = true }, source = VanillaModels.source, sourceVersion = VanillaModels.version },
  [247] = { effects = { offense = 1, defense = 1 }, tags = { familiar = true }, source = VanillaModels.source, sourceVersion = VanillaModels.version },
  [273] = { effects = { defense = 4, sustain = 3 }, tags = { explosive_immunity = true }, source = VanillaModels.source, sourceVersion = VanillaModels.version },
  [330] = { effects = { offense = 2, tearRate = 3 }, tags = { tear = true, rapid_fire = true }, source = VanillaModels.source, sourceVersion = VanillaModels.version },
  [356] = { effects = { activeUtility = 4, routeAccess = 1 }, tags = { battery = true }, source = VanillaModels.source, sourceVersion = VanillaModels.version },
  [327] = { effects = { routeAccess = 1, offense = 1 }, tags = { quest = true }, source = VanillaModels.source, sourceVersion = VanillaModels.version },
  [328] = { effects = { routeAccess = 1, offense = 1 }, tags = { quest = true }, source = VanillaModels.source, sourceVersion = VanillaModels.version },
  [399] = { effects = { routeAccess = 1, offense = 1 }, tags = { quest = true }, source = VanillaModels.source, sourceVersion = VanillaModels.version },
  [510] = { effects = { routeAccess = 2, bossDamage = 2 }, tags = { quest = true }, source = VanillaModels.source, sourceVersion = VanillaModels.version }
}

function VanillaModels.fromCatalog(items)
  local entries = {}
  for _, item in ipairs(items or {}) do
    local copy = clone(item)
    copy.tags = VanillaModels.normalizeTags(copy.tags)
    entries[#entries + 1] = copy
  end
  local models = ItemModels.fromCatalog(entries, VanillaModels.curated)
  models.metadata.source = VanillaModels.source
  models.metadata.version = VanillaModels.version
  models.metadata.profilesVersion = Profiles.version
  for _, item in ipairs(entries) do
    local model = models:get(item.id, item.kind or "collectible")
    if model then
      model.source = model.source or VanillaModels.source
      model.sourceVersion = model.sourceVersion or VanillaModels.version
      if model.status ~= "curated" then model.status = "data_update_required" end
    end
  end
  models.diagnostics = VanillaModels.diagnostics(entries, models)
  return models
end

VanillaModels.build = VanillaModels.fromCatalog

function VanillaModels.diagnostics(items, models)
  local report = {
    version = VanillaModels.version,
    source = VanillaModels.source,
    total = 0,
    modeled = 0,
    curated = 0,
    baseline = 0,
    dataUpdateRequired = 0,
    unknown = {},
    confidence = {},
    unsupportedMechanics = {}
  }
  local supportedKinds = { collectible = true, trinket = true, card = true, pill = true, pickup = true }
  for _, item in ipairs(items or {}) do
    report.total = report.total + 1
    local kind = item.kind or "collectible"
    local model = models and models:get(item.id, kind)
    if model then
      report.modeled = report.modeled + 1
      if model.status == "curated" then report.curated = report.curated + 1 else report.baseline = report.baseline + 1 end
      if model.status == "data_update_required" then report.dataUpdateRequired = report.dataUpdateRequired + 1 end
      local confidence = model.confidence or "low"
      report.confidence[confidence] = (report.confidence[confidence] or 0) + 1
    else
      report.unknown[#report.unknown + 1] = item.id
    end
    if not supportedKinds[kind] then report.unsupportedMechanics[kind] = true end
  end
  return report
end

function VanillaModels.profile(token)
  return Profiles.get(token)
end

return VanillaModels
