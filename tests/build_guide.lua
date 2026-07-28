package.path = "./?.lua;./?/init.lua;" .. package.path

local BuildState = require("runcompass.build_state")
local ItemModels = require("runcompass.item_models")
local ChoiceEngine = require("runcompass.choice_engine")
local GameAdapter = require("runcompass.game")
local GuideAPI = require("runcompass.guide_api")
local Planner = require("runcompass.planner")
local EID = require("runcompass.eid")
local Save = require("runcompass.save")

local function assertEqual(actual, expected, message)
  if actual ~= expected then error((message or "values differ") .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")") end
end

local function assertTrue(value, message)
  if not value then error(message or "expected truthy value") end
end

local function testBuildStateNormalizesOwnedInventory()
  local state = BuildState.fromPlayer({
    characterToken = "azazel",
    playerType = 7,
    health = 3,
    maxHealth = 6,
    damage = 4,
    collectibles = { [100] = 2, [200] = 1 },
    actives = { { id = 300, slot = 0, charge = 4, maxCharge = 6 } },
    trinkets = { { id = 10, golden = true, smelted = false } },
    cards = { { id = 5, slot = 0, identified = true } },
    pills = { { color = 2, effect = "speed_up", identified = true } },
    transformations = { bookworm = 1 }
  })
  assertEqual(state.characterToken, "azazel", "character should be retained")
  assertEqual(state.collectibles[100], 2, "duplicate collectibles should be retained")
  assertEqual(state.actives[1].charge, 4, "active charge should be retained")
  assertTrue(state.trinkets[1].golden, "golden trinket state should be retained")
  assertEqual(state.pills[1].effect, "speed_up", "identified pill effect should be retained")
end

local function testFeatureModelAppliesOwnedSynergy()
  local models = ItemModels.new({
    [100] = { effects = { offense = 2 }, tags = { tear = true } },
    [200] = { effects = { offense = 1 }, tags = { tear = true }, synergies = { { owned = 100, effects = { bossDamage = 4 }, reason = "tear_pair" } } }
  })
  local evaluation = models:evaluate(200, { collectibles = { [100] = 1 }, characterToken = "isaac" }, { id = "boss.delirium" })
  assertEqual(evaluation.effects.bossDamage, 4, "owned synergy should add its effect")
  assertTrue(evaluation.reasonCodes.owned_item_synergy, "synergy should produce a structured reason")
end

local function testFeatureSummaryAggregatesOwnedBuild()
  local models = ItemModels.new({ [100] = { effects = { offense = 2 }, tags = { tear = true } }, [101] = { effects = { defense = 1 }, tags = { familiar = true } } })
  local summary = models:featureSummary({ collectibles = { [100] = 2, [101] = 1 }, characterToken = "isaac" })
  assertEqual(summary.effects.offense, 4, "owned build features should aggregate duplicate effects")
  assertEqual(summary.tags.tear, 2, "owned build tags should count duplicates")
end

local function testTagSynergyUsesIndexedBuildFeatures()
  local models = ItemModels.new({ [100] = { effects = {}, tags = { tear = true } }, [201] = { effects = { offense = 1 }, tagSynergies = { { tag = "tear", effects = { bossDamage = 2 }, id = "tear_family" } } } })
  local build = { collectibles = { [100] = 1 }, characterToken = "isaac" }
  build.featureSummary = models:featureSummary(build)
  local result = models:evaluate(201, build, {})
  assertEqual(result.effects.bossDamage, 2, "tag-family synergy should use the indexed feature summary")
end

local function testChoiceEngineRanksTakeOverSkipWhenGoalRelevant()
  local build = { characterToken = "isaac", collectibles = { [100] = 1 }, stats = { damage = 3 }, health = { current = 6, max = 6 }, resources = { coins = 15 } }
  local snapshot = { player = build, visibility = { curseBlind = false }, capabilities = { tier = "base" } }
  local choices = {
    { id = "pedestal.1", kind = "collectible", roomId = 1, observedIdentity = { id = 200, quality = 4 }, position = { x = 80, y = 60 }, confidence = "high" },
    { id = "skip.1", kind = "skip", roomId = 1, position = { x = 80, y = 60 }, confidence = "high" }
  }
  local result = ChoiceEngine.evaluate(snapshot, choices, { id = "boss.delirium", destinationRooms = {} })
  assertEqual(result.primary.action, "take", "goal-relevant collectible should beat skip")
  assertTrue(#result.alternatives <= 2, "comparison should expose at most two alternatives")
end

local function testCatalogBuildsBaselineModelsForEveryLiveItem()
  local models = ItemModels.fromCatalog({
    { id = 1, quality = 0, tags = 1 },
    { id = 2, quality = 4, tags = 2 },
    { id = 1, kind = "trinket", quality = 0, tags = 4 },
    { id = 1, kind = "card", quality = 0, tags = 8 }
  })
  local report = models:validate({ { id = 1, kind = "collectible" }, { id = 2, kind = "collectible" }, { id = 1, kind = "trinket" }, { id = 1, kind = "card" } })
  assertEqual(report.modeled, 4, "every live item should receive a baseline model")
end

local function testCharacterModifierAndUnknownFallbackAreExplicit()
  local models = ItemModels.new({
    [10] = { effects = { offense = 1 }, characterModifiers = { { characterToken = "keeper", effects = { economy = 3 }, reason = "coin_health" } } }
  })
  local keeper = models:evaluate(10, { characterToken = "keeper", collectibles = {} }, {})
  assertEqual(keeper.effects.economy, 3, "character modifier should affect item utility")
  local unknown = models:evaluate(999, { characterToken = "isaac", collectibles = {} }, {})
  assertEqual(unknown.confidence, "low", "unknown content should be conservative")
  assertTrue(unknown.warnings[1] == "data_update_required", "unknown content should explain its fallback")
end

local function testTransformationThresholdProducesReasonCode()
  local models = ItemModels.new({ [20] = { effects = { offense = 1 }, transformation = { token = "bookworm", adds = 1, threshold = 3 } } })
  local result = models:evaluate(20, { characterToken = "isaac", collectibles = {}, transformations = { bookworm = 2 } }, {})
  assertTrue(result.reasonCodes.transformation_threshold, "crossing a transformation threshold should be explained")
end

local function testCharacterRestrictionProducesWarningInsteadOfFalseSynergy()
  local models = ItemModels.new({ [21] = { effects = { sustain = 3 }, requiresRedHealth = true } })
  local result = models:evaluate(21, { characterToken = "the_lost", collectibles = {} }, {})
  assertTrue(result.reasonCodes.character_restriction, "health-incompatible item should be explained")
  assertTrue(result.warnings[1] ~= nil, "health-incompatible item should warn")
end

local function testGameAdapterCapturesOwnedItemsAndActives()
  local player = {
    GetPlayerType = function() return 1 end,
    GetHearts = function() return 6 end,
    GetSoulHearts = function() return 0 end,
    GetBlackHearts = function() return 0 end,
    GetMaxHearts = function() return 6 end,
    GetNumKeys = function() return 2 end,
    GetNumBombs = function() return 1 end,
    GetNumCoins = function() return 15 end,
    HasCollectible = function(_, id) return id == 100 end,
    GetCollectibleNum = function(_, id) return id == 100 and 2 or 0 end,
    GetActiveItem = function() return 300 end,
    GetActiveCharge = function() return 4 end,
    GetBatteryCharge = function() return 0 end,
    GetTrinket = function(_, slot) return slot == 0 and 10 or 0 end,
    GetTrinketMultiplier = function() return 1 end,
    GetCard = function(_, slot) return slot == 0 and 5 or 0 end,
    GetPill = function() return 7 end,
    GetBoneHearts = function() return 1 end,
    GetRottenHearts = function() return 1 end,
    HasPlayerForm = function(_, form) return form == 10 end,
    Damage = 4,
    MaxFireDelay = 10,
    MoveSpeed = 1
  }
  local adapter = GameAdapter.new({ playerType = { PLAYER_ISAAC = 1 }, playerForm = { PLAYERFORM_GUPPY = 10 }, itemPool = { IsPillIdentified = function() return true end, GetPillEffect = function() return "speed_up" end }, game = { GetNumPlayers = function() return 1 end, GetPlayer = function() return player end } })
  local normalized = adapter:buildPlayer(player)
  assertEqual(normalized.collectibles[100], 2, "adapter should enumerate owned collectible counts")
  assertEqual(normalized.actives[1].id, 300, "adapter should capture active item identity")
  assertEqual(normalized.trinkets[1].id, 10, "adapter should capture held trinkets")
  assertEqual(normalized.healthState.bone, 1, "health containers should be retained")
  assertTrue(normalized.transformations.guppy, "active transformations should be detected")
  assertTrue(normalized.pills[1].identified, "identified pill state should be retained")
  assertEqual(normalized.pills[1].effect, "speed_up", "identified pill effect should be retained")
end

local function testGameAdapterNormalizesGoldenAndSmeltedTrinkets()
  local player = {
    GetTrinket = function(_, slot) return slot == 0 and 32778 or 0 end,
    GetTrinketMultiplier = function() return 2 end,
    GetSmeltedTrinkets = function() return { 12 } end
  }
  local adapter = GameAdapter.new({ trinketType = { TRINKET_GOLDEN_FLAG = 32768 } })
  local trinkets = adapter:buildPlayer(player).trinkets
  assertTrue(trinkets[1].golden, "golden trinket flags should be normalized")
  assertEqual(trinkets[1].id, 10, "golden flag should not contaminate the base trinket id")
  assertTrue(trinkets[2].smelted, "Repentogon smelted trinkets should be retained when probed")
end

local function testVisibleChoiceNormalizesObservedPickupAndPrice()
  local adapter = GameAdapter.new({ pickupVariant = { PICKUP_COLLECTIBLE = 100 }, itemConfig = { GetCollectible = function() return { Name = "Test Relic", Quality = 4, Tags = 8 } end } })
  local choice = adapter:buildVisibleChoice({ Variant = 100, SubType = 200, Price = 15, OptionsPickupIndex = 2, InitSeed = 777, Position = { X = 40, Y = 50 } }, 9, { curseBlind = false })
  assertEqual(choice.kind, "collectible", "collectible pickup should become a visible choice")
  assertEqual(choice.observedIdentity.id, 200, "observed item identity should be retained")
  assertEqual(choice.price, 15, "shop price should be retained")
  assertEqual(choice.choiceGroupId, "9:2", "option groups should be stable")
  assertEqual(choice.action, "buy", "priced pickup should become an explicit buy action")
end

local function testVisibleActiveChoiceExposesReplacementConsequence()
  local adapter = GameAdapter.new({ pickupVariant = { PICKUP_COLLECTIBLE = 100 }, activeItemType = 3, itemConfig = { GetCollectible = function() return { Name = "Active", Quality = 3, Type = 3 } end } })
  local choice = adapter:buildVisibleChoice({ Variant = 100, SubType = 200, Position = { X = 1, Y = 2 } }, 1, { curseBlind = false })
  assertEqual(choice.action, "replace_active", "active pedestals should expose replacement action")
  assertTrue(choice.replacement and choice.replacement.kind == "active", "active replacement consequence should be explicit")
end

local function testVisiblePillIdentityRequiresIdentificationProbe()
  local adapter = GameAdapter.new({ pickupVariant = { PICKUP_PILL = 70 }, itemPool = { IsPillIdentified = function() return true end, GetPillEffect = function() return 5 end } })
  local known = adapter:buildVisibleChoice({ Variant = 70, SubType = 3, Position = { X = 1, Y = 2 } }, 1, { curseBlind = false })
  assertEqual(known.observedIdentity.id, 3, "identified pills may expose their color identity")
  assertEqual(known.observedIdentity.effect, 5, "identified pill effects should be observed, not inferred")
  local unknownAdapter = GameAdapter.new({ pickupVariant = { PICKUP_PILL = 70 }, itemPool = { IsPillIdentified = function() return false end, GetPillEffect = function() return 5 end } })
  local unknown = unknownAdapter:buildVisibleChoice({ Variant = 70, SubType = 3 }, 1, { curseBlind = false })
  assertTrue(unknown.observedIdentity == nil, "unidentified pills must remain insufficient information")
end

local function testAdapterCatalogsTrinketsCardsAndPills()
  local adapter = GameAdapter.new({ itemConfig = {
    GetTrinket = function(_, id) return id < 2 and { Name = "T" .. id, Quality = 1, Tags = 1 } or nil end,
    GetCard = function(_, id) return id < 2 and { Name = "C" .. id, Quality = 0, Tags = 2 } or nil end,
    GetPillEffect = function(_, id) return id < 2 and { Name = "P" .. id } or nil end
  } })
  local trinkets = adapter:collectConfigured("trinket", 2)
  local cards = adapter:collectConfigured("card", 2)
  local pills = adapter:collectConfigured("pill", 2)
  assertEqual(#trinkets, 2, "trinket catalog should use ItemConfig")
  assertEqual(#cards, 2, "card catalog should use ItemConfig")
  assertEqual(#pills, 2, "pill catalog should use ItemConfig")
end

local function testAdapterCapturesVisibleMachineInteractions()
  local adapter = GameAdapter.new({ entityType = { ENTITY_SLOT = 6 }, isaac = { FindByType = function() return { { InitSeed = 88, Variant = 2, SubType = 4, Price = 3, Position = { X = 20, Y = 30 } } } end } })
  local choices = adapter:buildInteractionChoices(5, { curseBlind = false })
  assertEqual(#choices, 1, "visible slot interactions should be captured")
  assertEqual(choices[1].kind, "machine", "slot interaction should use machine kind")
  assertEqual(choices[1].price, 3, "machine cost should be retained")
end

local function testAdapterExposesAvailableRerollDecision()
  local adapter = GameAdapter.new({ rerollActives = { [105] = true } })
  local choice = adapter:buildRerollChoice({ actives = { { id = 105, slot = 0, charge = 6 } } }, 2)
  assertTrue(choice ~= nil, "available reroll active should become a decision")
  assertEqual(choice.kind, "reroll", "reroll choice should be classified")
  assertEqual(choice.action, "reroll", "reroll action should be explicit")
end

local function testChoiceEngineDoesNotGuessBlindItemIdentity()
  local result = ChoiceEngine.evaluate({ player = { characterToken = "isaac" }, visibility = { curseBlind = true } }, {
    { id = "blind.1", kind = "collectible", position = { x = 1, y = 1 }, confidence = "low" }
  }, {})
  assertEqual(result.primary.action, "insufficient_information", "Blind identities must not receive guessed item advice")
  assertTrue(result.primary.warnings[1] == "identity_hidden", "Blind uncertainty should be explicit")
end

local function testChoiceEngineRejectsUnaffordablePurchase()
  local result = ChoiceEngine.evaluate({ player = { characterToken = "isaac", coins = 3 }, visibility = {} }, {
    { id = "shop.1", kind = "collectible", action = "buy", price = 15, observedIdentity = { id = 200 }, confidence = "high" },
    { id = "skip.1", kind = "skip", confidence = "high" }
  }, {})
  assertEqual(result.primary.action, "skip", "unaffordable purchases should not beat skip")
  assertTrue(result.alternatives[1] and result.alternatives[1].warnings[1] == "insufficient_coins", "unaffordable choice should be explained")
end

local function testChoiceEngineUsesLexicographicSafetyBeforeBuildGain()
  local models = ItemModels.new({ [301] = { effects = { offense = 20 } }, [302] = { effects = { defense = 3 } } })
  local result = ChoiceEngine.evaluate({ player = { characterToken = "isaac", coins = 99 }, visibility = {} }, {
    { id = "offense", kind = "collectible", observedIdentity = { id = 301 }, confidence = "high" },
    { id = "defense", kind = "collectible", observedIdentity = { id = 302 }, confidence = "high" }
  }, {}, models)
  assertEqual(result.primary.choiceId, "defense", "survival should outrank raw build gain")
end

local function testChoiceEngineExplainsChargedActiveReplacementLoss()
  local result = ChoiceEngine.evaluate({ player = { characterToken = "isaac", actives = { { id = 99, charge = 6 } } } }, {
    { id = "active", kind = "collectible", action = "replace_active", replacement = { kind = "active" }, observedIdentity = { id = 301 }, confidence = "high" }
  }, {}, ItemModels.new({ [301] = { effects = { activeUtility = 3 } } }))
  assertTrue(result.primary.reasonCodes.active_replacement_loss, "charged active replacement loss should be explained")
end

local function testCompatibilityAPIRegistersModelsAndRules()
  local api = GuideAPI.new(ItemModels.new())
  assertTrue(api:RegisterItemModel("test", "collectible", 901, { effects = { offense = 5 } }), "compatibility item model should register")
  assertTrue(api:RegisterInteractionRule("test", { candidate = 901, owned = 902, effects = { bossDamage = 3 } }), "compatibility interaction should register")
  assertTrue(api:RegisterCharacterProfile("test", "test_character", { effects = { defense = 2 } }), "compatibility character should register")
  assertEqual(api.models:get(901).effects.offense, 5, "registered model should be queryable")
end

local function testPlannerReturnsVisibleDecisionAlongsideRoute()
  local snapshot = {
    currentRoom = 1,
    currentRoomClear = true,
    mode = { kind = "normal", difficulty = "hard", progressionAllowed = true },
    visibility = { curseBlind = false, curseLost = false },
    player = { characterToken = "isaac", health = 6, maxHealth = 6, keys = 2, bombs = 2, coins = 15, collectibles = { [100] = 1 } },
    buildState = { characterToken = "isaac", collectibles = { [100] = 1 }, health = { current = 6, max = 6 }, resources = { coins = 15 } },
    capabilities = { tier = "base" },
    rooms = {
      { id = 1, kind = "start", visited = true, clear = true, doors = { { to = 2, slot = 0 } }, pickups = {} },
      { id = 2, kind = "boss", visited = false, clear = false, doors = { { to = 1, slot = 2 } }, pickups = {} }
    },
    visibleChoices = {
      { id = "p1", roomId = 1, kind = "collectible", observedIdentity = { id = 200, quality = 4 }, position = { x = 40, y = 40 }, confidence = "high" },
      { id = "s1", roomId = 1, kind = "skip", position = { x = 40, y = 40 }, confidence = "high" }
    },
    observations = { pickups = {} }
  }
  local models = ItemModels.new({ [200] = { effects = { bossDamage = 5 } } })
  local result = Planner.plan(snapshot, { id = "boss.delirium", destinationRooms = { 2 } }, nil, models)
  assertTrue(result.decision and result.decision.primary, "route recommendation should include a visible decision")
end

local function testEIDIsOptionalDescriptionOnly()
  local adapter = EID.detect({ getDescription = function(_, id) return "Description " .. tostring(id) end })
  assertTrue(adapter.available, "EID adapter should detect a compatible description provider")
  assertEqual(adapter:describe(12), "Description 12", "EID should only provide display text")
  local missing = EID.detect(nil)
  assertTrue(not missing.available, "missing EID should fall back safely")
end

local function testSaveV3MigratesDecisionSettingsSafely()
  local saved = Save.migrate({ schemaVersion = 2, decision = { detailLevel = 99, autoCompare = false }, browser = { alphabet = "Z" } })
  assertEqual(saved.schemaVersion, 3, "build-guide settings should use schema v3")
  assertEqual(saved.decision.detailLevel, 3, "decision detail should be clamped")
  assertEqual(saved.decision.autoCompare, false, "decision setting should migrate")
  assertEqual(saved.browser.alphabet, "Z", "browser preferences should migrate")
end

local tests = { testBuildStateNormalizesOwnedInventory, testFeatureModelAppliesOwnedSynergy, testFeatureSummaryAggregatesOwnedBuild, testTagSynergyUsesIndexedBuildFeatures, testChoiceEngineRanksTakeOverSkipWhenGoalRelevant, testChoiceEngineRejectsUnaffordablePurchase, testChoiceEngineUsesLexicographicSafetyBeforeBuildGain, testChoiceEngineExplainsChargedActiveReplacementLoss, testCatalogBuildsBaselineModelsForEveryLiveItem, testCharacterModifierAndUnknownFallbackAreExplicit, testTransformationThresholdProducesReasonCode, testCharacterRestrictionProducesWarningInsteadOfFalseSynergy, testGameAdapterCapturesOwnedItemsAndActives, testGameAdapterNormalizesGoldenAndSmeltedTrinkets, testVisibleChoiceNormalizesObservedPickupAndPrice, testVisibleActiveChoiceExposesReplacementConsequence, testVisiblePillIdentityRequiresIdentificationProbe, testAdapterCatalogsTrinketsCardsAndPills, testAdapterCapturesVisibleMachineInteractions, testAdapterExposesAvailableRerollDecision, testChoiceEngineDoesNotGuessBlindItemIdentity, testCompatibilityAPIRegistersModelsAndRules, testPlannerReturnsVisibleDecisionAlongsideRoute, testEIDIsOptionalDescriptionOnly, testSaveV3MigratesDecisionSettingsSafely }
for index, test in ipairs(tests) do test(); print("build ok " .. index) end
print(#tests .. " build-guide tests passed")
