package.path = "./?.lua;./?/init.lua;" .. package.path

local VanillaModels = require("runcompass.vanilla_models")
local Profiles = require("runcompass.character_profiles")
local Interactions = require("runcompass.interaction_rules")
local ItemModels = require("runcompass.item_models")

local function assertEqual(actual, expected, message)
  if actual ~= expected then error((message or "values differ") .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")") end
end

local function assertTrue(value, message)
  if not value then error(message or "expected truthy value") end
end

local function testEveryCatalogEntryGetsVersionedSourceTaggedModel()
  local models = VanillaModels.fromCatalog({
    { id = 1, name = "Unknown", quality = 2, tags = 0 },
    { id = 68, name = "Technology", quality = 3, tags = 128 },
    { id = 1, kind = "trinket", name = "Trinket", quality = 0, tags = 0 }
  })
  local unknown = models:get(1, "collectible")
  local curated = models:get(68, "collectible")
  local trinket = models:get(1, "trinket")
  assertTrue(unknown and curated and trinket, "all live entries should be modeled")
  assertEqual(unknown.confidence, "low", "generic baseline must be low confidence")
  assertEqual(unknown.status, "data_update_required", "generic baseline must request data update")
  assertTrue(type(unknown.source) == "string" and unknown.source ~= "", "baseline needs a source tag")
  assertTrue(curated.confidence == "high" and curated.sourceVersion == VanillaModels.version, "curated models need versioned source metadata")
end

local function testItemConfigTagsNormalizeIntoFamilies()
  local tags = VanillaModels.normalizeTags(1 + 8 + 16 + 128 + 16384)
  assertTrue(tags.tear and tags.spider and tags.fly and tags.technology and tags.familiar, "known ItemConfig bits should become semantic tags")
  assertTrue(not tags.beam, "normalization must not claim beam from a generic technology bit")
end

local function testSpecialCharacterProfilesExposeMechanics()
  local jacob = Profiles.get("jacob_and_esau")
  local forgotten = Profiles.get("the_forgotten")
  local lazarus = Profiles.get("tainted_lazarus")
  local isaac = Profiles.get("tainted_isaac")
  local cain = Profiles.get("tainted_cain")
  local eden = Profiles.get("eden")
  assertTrue(jacob.actors and jacob.actors.jacob and jacob.actors.esau, "Jacob and Esau must allocate both actors")
  assertTrue(forgotten.soulToken == "soul", "Forgotten profile must preserve Soul form")
  assertTrue(lazarus.flip and lazarus.flip.slots, "Tainted Lazarus must expose Flip slot state")
  assertEqual(isaac.slotLimit, 8, "Tainted Isaac item slots must be capped")
  assertTrue(cain.visibleEconomy and cain.effects.economy > 0, "Tainted Cain must use visible economy utility")
  assertTrue(eden.liveBuild and eden.confidence == "low", "Eden must be evaluated from the live build")
end

local function testInteractionFamiliesAreIndexedAndConservative()
  local tear = Interactions.forFamily("tear")
  local beam = Interactions.forFamily("beam")
  assertTrue(#tear > 0 and #beam > 0, "major interaction families should be indexed")
  local duplicate = Interactions.find("duplicates")
  assertTrue(duplicate and duplicate.diminishingReturns, "duplicate/stat cap rules must be explicit")
  local falseSynergy = Interactions.evaluate({ tags = { technology = true } }, { tags = { beam = true } })
  assertTrue(falseSynergy.claimed == false, "technology alone must not claim a beam synergy")
end

local function testItemModelsNormalizeBaselineTagsWithoutFalseFamilies()
  local models = VanillaModels.fromCatalog({ { id = 99, quality = 3, tags = 128 } })
  local model = models:get(99, "collectible")
  assertTrue(model.tags.technology, "ItemModels should preserve normalized technology tags")
  assertTrue(not model.tags.beam, "ItemModels must not infer beam from technology")
end

local tests = {
  testEveryCatalogEntryGetsVersionedSourceTaggedModel,
  testItemConfigTagsNormalizeIntoFamilies,
  testSpecialCharacterProfilesExposeMechanics,
  testInteractionFamiliesAreIndexedAndConservative,
  testItemModelsNormalizeBaselineTagsWithoutFalseFamilies
}
for index, test in ipairs(tests) do test(); print("vanilla ok " .. index) end
print(#tests .. " vanilla model tests passed")
