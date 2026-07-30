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
  local result = ChoiceEngine.evaluate(snapshot, choices, { id = "boss.delirium", destinationRooms = {} }, ItemModels.new({ [200] = { effects = { bossDamage = 5 } } }))
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
  assertEqual(normalized.healthState.boneContainers, 1, "health containers should be retained")
  assertTrue(normalized.transformations.guppy, "active transformations should be detected")
  assertTrue(normalized.pills[1].identified, "identified pill state should be retained")
  assertEqual(normalized.pills[1].effect, "speed_up", "identified pill effect should be retained")
end

local function testGameAdapterCachesCollectibleScansBetweenFallbackFrames()
  local scans = 0
  local player = {
    GetPlayerType = function() return 1 end,
    GetCollectibleNum = function(_, id) scans = scans + 1; return id == 2 and 1 or 0 end
  }
  local adapter = GameAdapter.new({ playerType = { PLAYER_ISAAC = 1 }, collectibleType = { NUM_COLLECTIBLES = 5 } })
  adapter.currentFrameId = 1
  local first = adapter:buildPlayer(player)
  adapter.currentFrameId = 2
  local second = adapter:buildPlayer(player)
  assertEqual(first.collectibles[2], 1, "initial collectible scan should populate inventory")
  assertEqual(second.collectibles[2], 1, "cached collectible inventory should be reused before fallback")
  assertEqual(scans, 4, "full collectible scan should not repeat before the 30-frame fallback")
  adapter.currentFrameId = 31
  adapter:buildPlayer(player)
  assertEqual(scans, 8, "full collectible scan should refresh on the 30-frame fallback")
  adapter:invalidateInventory()
  adapter.currentFrameId = 32
  adapter:buildPlayer(player)
  assertEqual(scans, 12, "explicit inventory invalidation should force a fresh scan")
end

local function healthPlayer(playerType, red, soul, blackMask, boneContainers, maxRed)
  return {
    GetPlayerType = function() return playerType end,
    GetHearts = function() return red end,
    GetSoulHearts = function() return soul end,
    GetBlackHearts = function() return blackMask end,
    GetBoneHearts = function() return boneContainers end,
    GetMaxHearts = function() return maxRed end
  }
end

local function testGameAdapterDoesNotCountBlackHeartBitmaskAsHealth()
  local adapter = GameAdapter.new({ playerType = { PLAYER_ISAAC = 1 } })
  local normalized = adapter:buildPlayer(healthPlayer(1, 2, 4, 6, 0, 6))
  assertEqual(normalized.healthState.effective, 6, "effective health should count soul hearts once")
  assertEqual(normalized.healthState.blackMask, 6, "black-heart bitmask should be retained as metadata")
  assertEqual(normalized.health, 6, "planner health alias should use effective half-heart health")
  assertEqual(normalized.maxHealth, 6, "planner max-health alias should remain numeric half-heart capacity")
end

local function testGameAdapterNormalizesConservativeHealthModes()
  local adapter = GameAdapter.new({ playerType = {
    PLAYER_ISAAC = 1,
    PLAYER_BLUEBABY = 2,
    PLAYER_THEFORGOTTEN = 3,
    PLAYER_KEEPER = 4,
    PLAYER_THELOST = 5
  } })
  local red = adapter:buildPlayer(healthPlayer(1, 4, 0, 0, 0, 6))
  local soul = adapter:buildPlayer(healthPlayer(2, 0, 6, 3, 0, 0))
  local bone = adapter:buildPlayer(healthPlayer(3, 2, 0, 0, 1, 0))
  local coin = adapter:buildPlayer(healthPlayer(4, 4, 0, 0, 0, 6))
  local noHealth = adapter:buildPlayer(healthPlayer(5, 0, 0, 0, 0, 0))
  assertEqual(red.healthState.mode, "red", "ordinary characters should use red-heart mode")
  assertEqual(soul.healthState.mode, "soul", "no-red-container characters should use soul-heart mode")
  assertEqual(bone.healthState.mode, "bone", "observed bone containers should select bone-heart mode")
  assertEqual(coin.healthState.mode, "coin", "Keeper should select coin-health mode")
  assertEqual(noHealth.healthState.mode, "soul", "no-health characters should not invent red health")
  assertEqual(bone.healthState.effective, 2, "bone containers should not invent filled health")
  assertEqual(bone.healthState.boneContainers, 1, "bone containers should remain explicit")
  assertEqual(red.healthState.maxRed, 6, "red-heart capacity should remain in half-heart units")
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

local function modeSnapshotForPlayers(rawPlayers)
  local currentRoom = { IsClear = function() return true end, GetFrameCount = function() return 1 end, GetDoor = function() return nil end }
  local level = {
    GetCurrentRoomIndex = function() return 1 end,
    GetCurrentRoom = function() return currentRoom end,
    GetCurses = function() return 0 end,
    GetStage = function() return 1 end,
    GetStageType = function() return 0 end,
    GetRooms = function() return { { GridIndex = 1, SafeGridIndex = 1, VisitedCount = 1, DisplayFlags = 1, Data = { Type = 1 } } } end
  }
  local game = {
    GetLevel = function() return level end,
    GetNumPlayers = function() return #rawPlayers end,
    GetPlayer = function(_, index) return rawPlayers[index + 1] end,
    IsGreedMode = function() return false end,
    GetSeeds = function() return nil end,
    GetFrameCount = function() return 1 end
  }
  return GameAdapter.new({ game = game, collectibleType = { NUM_COLLECTIBLES = 1 }, roomType = {} }):build()
end

local function testGameAdapterTreatsJacobAndEsauTwinAsSolo()
  local snapshot = modeSnapshotForPlayers({
    { GetPlayerType = function() return 1 end, IsSubPlayer = function() return false end },
    { GetPlayerType = function() return 2 end, IsSubPlayer = function() return true end }
  })
  assertEqual(snapshot.mode.coOp, false, "a character-controlled twin must not disable solo guidance")
end

local function testGameAdapterStillDetectsTrueCoop()
  local snapshot = modeSnapshotForPlayers({
    { GetPlayerType = function() return 1 end, IsSubPlayer = function() return false end },
    { GetPlayerType = function() return 2 end, IsSubPlayer = function() return false end }
  })
  assertEqual(snapshot.mode.coOp, true, "two independent players must remain unsupported co-op")
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
  assertEqual(choice.action, "replace", "active pedestals should expose replacement action")
  assertTrue(choice.replacement and choice.replacement.kind == "active", "active replacement consequence should be explicit")
end

local function testVisibleChoiceMapsPickupPriceConstantsToResourceCosts()
  local adapter = GameAdapter.new({
    pickupVariant = { PICKUP_COLLECTIBLE = 100 },
    pickupPrice = { PRICE_TWO_HEARTS = -2, PRICE_ONE_SOUL_HEART = -3, PRICE_SPIKES = -9 },
    itemConfig = { GetCollectible = function() return { Name = "Devil Item", Quality = 4 } end }
  })
  local red = adapter:buildVisibleChoice({ Variant = 100, SubType = 200, Price = -2, InitSeed = 1 }, 1, { curseBlind = false })
  assertEqual(red.resourceCost.redHearts, 4, "red-heart prices should use half-heart units")
  assertEqual(red.cost.kind, "red_hearts", "red-heart price should be typed")
  local soul = adapter:buildVisibleChoice({ Variant = 100, SubType = 201, Price = -3, InitSeed = 2 }, 1, { curseBlind = false })
  assertEqual(soul.resourceCost.soulHearts, 2, "soul-heart prices should use half-heart units")
  assertEqual(soul.cost.kind, "soul_hearts", "soul-heart price should be typed")
  local spikes = adapter:buildVisibleChoice({ Variant = 100, SubType = 202, Price = -9, InitSeed = 3 }, 1, { curseBlind = false })
  assertEqual(spikes.resourceCost.spikes, 1, "spike prices should be represented without pretending they are coins")
end

local function testUnknownPickupPriceMakesAcquisitionInsufficientInformation()
  local adapter = GameAdapter.new({ pickupVariant = { PICKUP_COLLECTIBLE = 100 }, itemConfig = { GetCollectible = function() return { Name = "Odd Price", Quality = 1 } end } })
  local choices = adapter:buildVisibleChoiceAlternatives({ Variant = 100, SubType = 200, Price = -99, InitSeed = 42, Position = { X = 8, Y = 9 } }, 3, { curseBlind = false })
  assertEqual(#choices, 2, "unknown-cost pickup should still expose acquisition plus skip")
  assertEqual(choices[1].action, "buy", "visible acquisition action should remain explicit")
  assertEqual(choices[1].availability, "unknown_cost", "unknown price must be infeasible instead of guessed")
  assertEqual(choices[2].action, "skip", "safe skip must remain available")
end

local function testVisibleChoiceAlternativesIncludeHoldForActiveReplacement()
  local adapter = GameAdapter.new({ pickupVariant = { PICKUP_COLLECTIBLE = 100 }, activeItemType = 3, itemConfig = { GetCollectible = function() return { Name = "Active", Quality = 3, Type = 3 } end } })
  local choices = adapter:buildVisibleChoiceAlternatives({ Variant = 100, SubType = 200, InitSeed = 44 }, 1, { curseBlind = false })
  assertEqual(#choices, 3, "active replacement should expose replace, hold, and skip")
  assertEqual(choices[1].action, "replace", "replacement action should be explicit")
  assertEqual(choices[2].action, "hold", "holding the current active should be an explicit alternative")
  assertEqual(choices[3].action, "skip", "skipping the option group should be explicit")
end

local function testSafeAlternativesDoNotInheritCandidateItemValue()
  local adapter = GameAdapter.new({ pickupVariant = { PICKUP_COLLECTIBLE = 100 }, itemConfig = { GetCollectible = function() return { Name = "Damage", Quality = 4 } end } })
  local choices = adapter:buildVisibleChoiceAlternatives({ Variant = 100, SubType = 200, InitSeed = 45 }, 1, { curseBlind = false })
  local result = ChoiceEngine.evaluate({ player = { characterToken = "isaac" } }, choices, {}, ItemModels.new({ [200] = { effects = { bossDamage = 5 } } }))
  assertEqual(result.primary.action, "take", "candidate value should belong only to the acquisition choice")
  assertTrue(result.skip and not result.skip.effectDelta.bossDamage, "skip must not inherit the candidate item model")
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
  local adapter = GameAdapter.new({ entityType = { ENTITY_SLOT = 6 }, slotVariant = { SLOT_MACHINE = 2 }, isaac = { FindByType = function() return { { InitSeed = 88, Variant = 2, SubType = 4, Price = 3, Position = { X = 20, Y = 30 } } } end } })
  local choices = adapter:buildInteractionChoices(5, { curseBlind = false })
  assertEqual(#choices, 1, "visible slot interactions should be captured")
  assertEqual(choices[1].kind, "machine", "slot interaction should use machine kind")
  assertEqual(choices[1].price, 3, "machine cost should be retained")
  assertEqual(choices[1].availability, "unsupported", "machines should remain descriptive until deterministic value is modeled")
  assertEqual(choices[1].observedIdentity.slotClass, "slot_machine", "supported slot variants should be classified by name")
end

local function testAdapterDescribesUnknownMachineVariantsConservatively()
  local adapter = GameAdapter.new({ entityType = { ENTITY_SLOT = 6 }, slotVariant = { SLOT_MACHINE = 2 }, isaac = { FindByType = function() return { { InitSeed = 89, Variant = 999, Price = 1 } } end } })
  local choices = adapter:buildInteractionChoices(5, { curseBlind = false })
  assertEqual(choices[1].observedIdentity.slotClass, "unknown", "unknown slot variants should not be folded into known machines")
  assertEqual(choices[1].availability, "unsupported", "unknown machines must not be recommended")
end

local function testAdapterExposesAvailableRerollDecision()
  local adapter = GameAdapter.new({ rerollActives = { [105] = true }, itemConfig = { GetCollectible = function() return { MaxCharges = 6 } end } })
  local choice = adapter:buildRerollChoice({ actives = { { id = 105, slot = 0, charge = 6 } } }, 2, {
    { id = "2:pedestal", roomId = 2, kind = "collectible", observedIdentity = { id = 200 } }
  })
  assertTrue(choice ~= nil, "available reroll active should become a decision")
  assertEqual(choice.kind, "reroll", "reroll choice should be classified")
  assertEqual(choice.action, "reroll", "reroll action should be explicit")
  assertEqual(choice.targetIds[1], "2:pedestal", "reroll advice must point at an observed visible target")
  assertEqual(choice.availability, "insufficient_information", "unsupported reroll expected-value comparison should not become confident advice")
end

local function testAdapterSuppressesRerollWithoutFullChargeOrTarget()
  local adapter = GameAdapter.new({ rerollActives = { [105] = true }, itemConfig = { GetCollectible = function() return { MaxCharges = 6 } end } })
  local partial = adapter:buildRerollChoice({ actives = { { id = 105, slot = 0, charge = 5 } } }, 2, {
    { id = "2:pedestal", roomId = 2, kind = "collectible", observedIdentity = { id = 200 } }
  })
  assertTrue(partial == nil, "partial charge must not produce reroll advice")
  local noTarget = adapter:buildRerollChoice({ actives = { { id = 105, slot = 0, charge = 6 } } }, 2, {})
  assertTrue(noTarget == nil, "rerolls without visible targets must be suppressed")
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

local function testChoiceEnginePreservesRouteReserveWhenRankingPurchases()
  local result = ChoiceEngine.evaluate({ player = { characterToken = "isaac", resources = { coins = 15 } }, visibility = {} }, {
    { id = "shop.1", kind = "collectible", action = "buy", resourceCost = { coins = 15 }, observedIdentity = { id = 200 }, confidence = "high" },
    { id = "skip.1", kind = "skip", confidence = "high" }
  }, { resourceReserve = { coins = 1 } })
  assertEqual(result.primary.action, "skip", "purchases must preserve resources reserved for the route")
  assertTrue(result.alternatives[1] and result.alternatives[1].warnings[1] == "route_reserve_required", "route reserve pressure should be explicit")
end

local function testChoiceEngineTreatsUnknownCostAsInsufficientInformation()
  local result = ChoiceEngine.evaluate({ player = { characterToken = "isaac", resources = { coins = 99 } }, visibility = {} }, {
    { id = "deal.1", kind = "collectible", action = "buy", availability = "unknown_cost", observedIdentity = { id = 200 }, confidence = "low" },
    { id = "skip.1", kind = "skip", confidence = "high" }
  }, {})
  assertEqual(result.primary.action, "skip", "unknown acquisition costs must not outrank safe alternatives")
  assertEqual(result.alternatives[1].action, "insufficient_information", "unknown-cost acquisition should be explicit insufficient information")
  assertTrue(result.alternatives[1].reasonCodes.insufficient_information, "unknown-cost reasoning should be machine-readable")
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
  assertTrue(api:RegisterItemModel("test", "trinket", 901, { effects = { economy = 7 } }), "compatibility trinket model should register without overwriting collectible")
  assertTrue(api:RegisterInteractionRule("test", { candidate = 901, owned = 902, effects = { bossDamage = 3 } }), "compatibility interaction should register")
  assertTrue(api:RegisterCharacterProfile("test", "test_character", { effects = { defense = 2 } }), "compatibility character should register")
  assertEqual(api.models:get(901, "collectible").effects.offense, 5, "registered collectible model should be queryable by kind")
  assertEqual(api.models:get(901, "trinket").effects.economy, 7, "registered trinket model should not collide with collectible id")
  assertEqual(api.models:evaluate(901, { collectibles = { [902] = 1 }, characterToken = "isaac" }, {}, "collectible").effects.bossDamage, 3, "registered interaction rules should affect evaluation immediately")
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
  assertEqual(saved.schemaVersion, 5, "build-guide settings should migrate to the current schema")
  assertEqual(saved.decision.detailLevel, 3, "decision detail should be clamped")
  assertEqual(saved.decision.autoCompare, false, "decision setting should migrate")
  assertEqual(saved.browser.alphabet, "Z", "browser preferences should migrate")
end

local tests = { testBuildStateNormalizesOwnedInventory, testFeatureModelAppliesOwnedSynergy, testFeatureSummaryAggregatesOwnedBuild, testTagSynergyUsesIndexedBuildFeatures, testChoiceEngineRanksTakeOverSkipWhenGoalRelevant, testChoiceEngineRejectsUnaffordablePurchase, testChoiceEnginePreservesRouteReserveWhenRankingPurchases, testChoiceEngineTreatsUnknownCostAsInsufficientInformation, testChoiceEngineUsesLexicographicSafetyBeforeBuildGain, testChoiceEngineExplainsChargedActiveReplacementLoss, testCatalogBuildsBaselineModelsForEveryLiveItem, testCharacterModifierAndUnknownFallbackAreExplicit, testTransformationThresholdProducesReasonCode, testCharacterRestrictionProducesWarningInsteadOfFalseSynergy, testGameAdapterCapturesOwnedItemsAndActives, testGameAdapterCachesCollectibleScansBetweenFallbackFrames, testGameAdapterDoesNotCountBlackHeartBitmaskAsHealth, testGameAdapterNormalizesConservativeHealthModes, testGameAdapterNormalizesGoldenAndSmeltedTrinkets, testGameAdapterTreatsJacobAndEsauTwinAsSolo, testGameAdapterStillDetectsTrueCoop, testVisibleChoiceNormalizesObservedPickupAndPrice, testVisibleActiveChoiceExposesReplacementConsequence, testVisibleChoiceMapsPickupPriceConstantsToResourceCosts, testUnknownPickupPriceMakesAcquisitionInsufficientInformation, testVisibleChoiceAlternativesIncludeHoldForActiveReplacement, testSafeAlternativesDoNotInheritCandidateItemValue, testVisiblePillIdentityRequiresIdentificationProbe, testAdapterCatalogsTrinketsCardsAndPills, testAdapterCapturesVisibleMachineInteractions, testAdapterDescribesUnknownMachineVariantsConservatively, testAdapterExposesAvailableRerollDecision, testAdapterSuppressesRerollWithoutFullChargeOrTarget, testChoiceEngineDoesNotGuessBlindItemIdentity, testCompatibilityAPIRegistersModelsAndRules, testPlannerReturnsVisibleDecisionAlongsideRoute, testEIDIsOptionalDescriptionOnly, testSaveV3MigratesDecisionSettingsSafely }
for index, test in ipairs(tests) do test(); print("build ok " .. index) end
print(#tests .. " build-guide tests passed")
