package.path = "./?.lua;./?/init.lua;" .. package.path

local Planner = require("runcompass.planner")
local Catalog = require("runcompass.catalog")
local Visibility = require("runcompass.visibility")
local Capabilities = require("runcompass.capabilities")
local Save = require("runcompass.save")
local Controller = require("runcompass.controller")
local Snapshot = require("runcompass.snapshot")
local Browser = require("runcompass.browser")
local Events = require("runcompass.events")
local Goals = require("runcompass.goals")
local Presentation = require("runcompass.presentation")
local Rules = require("runcompass.rules")
local GameAdapter = require("runcompass.game")
local Runtime = require("runcompass.runtime")
local Milestones = require("runcompass.milestones")
local Search = require("runcompass.search")
local Valuation = require("runcompass.valuation")
local MCM = require("runcompass.mcm")

local function assertEqual(actual, expected, message)
  if actual ~= expected then
    error((message or "values differ") .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")")
  end
end

local function assertTrue(value, message)
  if not value then error(message or "expected truthy value") end
end

local function baseSnapshot()
  return {
    currentRoom = 1,
    mode = { kind = "normal", difficulty = "hard", coOp = false, progressionAllowed = true },
    visibility = { curseBlind = false, curseLost = false },
    player = { health = 6, maxHealth = 6, keys = 2, bombs = 2, coins = 15, power = 1 },
    rooms = {
      { id = 1, kind = "start", visited = true, clear = true, doors = { { to = 2, slot = 0 }, { to = 4, slot = 1 } } },
      { id = 2, kind = "treasure", visited = false, clear = false, doors = { { to = 1, slot = 2 }, { to = 3, slot = 0 } }, cost = { keys = 1 }, pickups = { { id = 1, quality = 4, visible = true } } },
      { id = 3, kind = "boss", visited = false, clear = false, doors = { { to = 2, slot = 2 } } },
      { id = 4, kind = "shop", visited = false, clear = false, hidden = false, doors = { { to = 1, slot = 3 }, { to = 3, slot = 0 } } }
    },
    observations = { pickups = {} }
  }
end

local function testRoutesToGoalThroughRevealedRooms()
  local result = Planner.plan(baseSnapshot(), { id = "boss.delirium", kind = "boss", destinationRooms = { 3 } })
  assertEqual(result.status, "ok", "revealed route should be actionable")
  assertEqual(result.nextDoorSlot, 0, "planner should choose the treasure branch before the boss")
  assertTrue(#result.steps >= 1, "recommendation should contain steps")
end

local function testNeverUsesHiddenSecretRoom()
  local snapshot = baseSnapshot()
  snapshot.rooms[4].kind = "secret"
  snapshot.rooms[4].hidden = true
  snapshot.rooms[2].doors = { { to = 1, slot = 2 }, { to = 4, slot = 0 } }
  local result = Planner.plan(snapshot, { id = "boss.delirium", kind = "boss", destinationRooms = { 4 } })
  assertEqual(result.status, "unreachable", "hidden destinations must not be routable")
  assertTrue(result.reasonCodes.hidden_information, "unreachable reason should identify hidden information")
end

local function testReservesRequiredKey()
  local snapshot = baseSnapshot()
  snapshot.player.keys = 1
  local result = Planner.plan(snapshot, { id = "boss.delirium", kind = "boss", destinationRooms = { 3 }, requiredResources = { keys = 1 } })
  assertEqual(result.nextDoorSlot, 1, "planner should preserve the only key for the goal")
  assertTrue(result.reasonCodes.resource_reservation, "explanation should identify the reservation")
end

local function testUnsupportedModeIsInactive()
  local snapshot = baseSnapshot()
  snapshot.mode.kind = "greed"
  local result = Planner.plan(snapshot, { id = "boss.delirium", kind = "boss", destinationRooms = { 3 } })
  assertEqual(result.status, "inactive", "unsupported modes must disable guidance")
end

local function testHysteresisKeepsStableRecommendation()
  local snapshot = baseSnapshot()
  local previous = Planner.plan(snapshot, { id = "boss.delirium", kind = "boss", destinationRooms = { 3 } })
  snapshot.player.coins = 99
  local result = Planner.plan(snapshot, { id = "boss.delirium", kind = "boss", destinationRooms = { 3 } }, previous)
  assertEqual(result.nextDoorSlot, previous.nextDoorSlot, "small score changes should not cause flicker")
end

local function testVisibilityFiltersHiddenInformation()
  local rooms = {
    { id = 1, visited = true, hidden = false },
    { id = 2, visited = false, hidden = true },
    { id = 3, visited = false, hidden = false }
  }
  local filtered = Visibility.filterRooms(rooms, { curseLost = true, curseBlind = true })
  assertTrue(filtered[1] ~= nil, "current/visited room should remain visible")
  assertTrue(filtered[2] == nil, "hidden room should be removed")
  assertTrue(filtered[3] == nil, "unvisited room under Curse of the Lost should be removed")
end

local function testCatalogClassifiesUnknownAndKnownGoals()
  local catalog = Catalog.new({
    { id = 1, name = "Known Relic", achievementId = 10 },
    { id = 2, name = "Default Relic", achievementId = -1 },
    { id = 3, name = "Future Relic", achievementId = 999 }
  }, {
    [10] = { kind = "completion_mark", supportTier = "base", destinationRooms = { 7 } }
  })
  assertEqual(catalog:get(1).supportTier, "base", "known unlock rule should be routable")
  assertEqual(catalog:get(2).status, "already_unlocked", "default items should not require an unlock route")
  assertEqual(catalog:get(3).status, "catalog_update_required", "unknown achievements must be explicit")
end

local function testCapabilityDetectionFallsBackSafely()
  local base = Capabilities.detect({}, {})
  assertEqual(base.tier, "base", "missing Repentogon should use base tier")
  local enhanced = Capabilities.detect({ Version = "1.1.2e", MeetsVersion = function() return true end }, { ModConfigMenu = true })
  assertEqual(enhanced.tier, "enhanced", "compatible Repentogon should enable enhanced tier")
end

local function testSaveMigrationUsesSafeDefaults()
  local migrated = Save.migrate({ schemaVersion = 0, selectedGoalId = "boss.delirium" })
  assertEqual(migrated.schemaVersion, 3, "save data should be migrated")
  assertEqual(migrated.pinned, false, "missing fields should use safe defaults")
end

local function testSaveRoundTripsLocalData()
  local encoded = Save.serialize({ schemaVersion = 1, selectedGoalId = "boss.delirium", pinned = true })
  local decoded = Save.deserialize(encoded)
  assertEqual(decoded.selectedGoalId, "boss.delirium", "save serializer should preserve selected goal")
  assertEqual(decoded.pinned, true, "save serializer should preserve pin state")
end

local function testBlindCurseDoesNotValueHiddenPickup()
  local snapshot = baseSnapshot()
  snapshot.visibility.curseBlind = true
  local result = Planner.plan(snapshot, { id = "boss.delirium", kind = "boss", destinationRooms = { 3 } })
  assertEqual(result.nextDoorSlot, 1, "blind pickups must not make a treasure detour look valuable")
end

local function testControllerReplansOnlyWhenDirty()
  local calls = 0
  local fakePlanner = { plan = function(snapshot, goal, previous)
    calls = calls + 1
    return { status = "ok", nextDoorSlot = snapshot.currentRoom, steps = {}, previous = previous }
  end }
  local controller = Controller.new(fakePlanner)
  local snapshot = { currentRoom = 1 }
  local goal = { id = "boss.delirium" }
  controller:tick(snapshot, goal)
  controller:tick(snapshot, goal)
  assertEqual(calls, 1, "controller should not replan every frame")
  controller:onEvent("PLAYER_STATE_CHANGED")
  controller:tick(snapshot, goal)
  assertEqual(calls, 2, "meaningful state changes should invalidate the plan")
end

local function testSnapshotBuilderNormalizesRuntimeState()
  local builder = Snapshot.new({
    getCurrentRoom = function() return 4 end,
    getMode = function() return { kind = "normal", difficulty = "hard" } end,
    getVisibility = function() return { curseBlind = false, curseLost = false } end,
    getPlayer = function() return { health = 3, maxHealth = 6, keys = 1 } end,
    getRooms = function() return { { id = 4, visited = true, doors = {} } } end,
    getObservations = function() return { pickups = {} } end
  })
  local snapshot = builder:build()
  assertEqual(snapshot.currentRoom, 4, "snapshot should include current room")
  assertEqual(snapshot.player.keys, 1, "snapshot should include resources")
end

local function testGoalBrowserFiltersAndSortsCatalog()
  local entries = {
    { id = 2, name = "Zebra", kind = "collectible", status = "locked" },
    { id = 1, name = "Alpha", kind = "collectible", status = "already_unlocked" },
    { id = "boss.delirium", name = "Delirium", kind = "boss", status = "routable" }
  }
  local result = Browser.filter(entries, { query = "e", kind = "collectible" })
  assertEqual(#result, 1, "browser should apply query and kind filters")
  assertEqual(result[1].name, "Zebra", "browser should return matching entry")
end

local function testEventsNormalizeKnownCallbacks()
  local seen = {}
  local callbacks = Events.normalized({
    onEvent = function(_, name) seen[#seen + 1] = name end
  })
  callbacks.room()
  callbacks.pickup()
  assertEqual(seen[1], "ROOM_CHANGED", "room callback should normalize event name")
  assertEqual(seen[2], "OBSERVATION_CHANGED", "pickup callback should normalize event name")
end

local function testGoalResolverFindsCurrentFloorBoss()
  local snapshot = baseSnapshot()
  snapshot.rooms[3].kind = "delirium"
  local goal = Goals.resolve({ id = "boss.delirium", kind = "boss" }, snapshot)
  assertEqual(goal.destinationRooms[1], 3, "goal resolver should map a known boss room")
end

local function testPresentationFormatsCompactRecommendation()
  local lines = Presentation.lines({ status = "ok", steps = { "Go to treasure", "Then boss" }, reasonCodes = { resource_reservation = true }, confidence = "medium", capabilityTier = "base" })
  assertEqual(lines[1], "Go to treasure", "HUD should show the first next step")
  assertTrue(string.find(lines[#lines], "BASE", 1, true) ~= nil, "HUD should show capability tier")
end

local function testPresentationIncludesBuildChoiceComparison()
  local lines = Presentation.lines({ status = "ok", steps = { "Go to treasure" }, reasonCodes = {}, confidence = "high", capabilityTier = "enhanced", decision = {
    primary = { action = "take", choiceId = "p1", reasonCodes = { owned_item_synergy = true }, confidence = "high" },
    alternatives = { { action = "skip", choiceId = "s1" } },
    skip = { action = "skip" }, comparisonRequired = true
  } })
  local rendered = table.concat(lines, "|")
  assertTrue(string.find(rendered, "take", 1, true) ~= nil, "HUD should show the primary action")
  assertTrue(string.find(rendered, "owned_item_synergy", 1, true) ~= nil, "HUD should show structured synergy rationale")
end

local function testInstructionalGoalDoesNotPretendToRoute()
  local snapshot = baseSnapshot()
  local resolved = Goals.resolve({ id = "collectible.future", kind = "collectible", status = "catalog_update_required" }, snapshot)
  local result = Planner.plan(snapshot, resolved)
  assertEqual(result.status, "instructional", "unmapped unlocks should not receive a fabricated route")
end

local function testCompletedGoalStopsRouting()
  local snapshot = baseSnapshot()
  local result = Planner.plan(snapshot, Goals.resolve({ id = "collectible.done", kind = "collectible", status = "already_unlocked" }, snapshot))
  assertEqual(result.status, "complete", "already unlocked goals should stop route guidance")
end

local function testRouteCriticalCollectibleRuleResolvesToBoss()
  local snapshot = baseSnapshot()
  snapshot.player.characterToken = "isaac"
  snapshot.rooms[3].kind = "mother"
  local entry = { id = 631, name = "Meat Cleaver", kind = "collectible", status = "locked" }
  for key, value in pairs(Rules.forAchievement(440)) do entry[key] = value end
  local goal = Goals.resolve(entry, snapshot)
  assertEqual(goal.destinationRooms[1], 3, "Meat Cleaver should route to Mother when playing Isaac")
end

local function testWrongCharacterRedirectsUnlockGoal()
  local snapshot = baseSnapshot()
  snapshot.player.characterToken = "cain"
  local entry = { id = 631, name = "Meat Cleaver", kind = "collectible", status = "locked" }
  for key, value in pairs(Rules.forAchievement(440)) do entry[key] = value end
  local goal = Goals.resolve(entry, snapshot)
  local result = Planner.plan(snapshot, goal)
  assertEqual(result.status, "prerequisite_redirect", "wrong character should redirect instead of routing a false path")
end

local function testPersistentCounterGoalIsInstructionalWithoutEnhancedTier()
  local snapshot = baseSnapshot()
  local entry = { id = 175, name = "Dad's Key", kind = "collectible", status = "locked" }
  for key, value in pairs(Rules.forAchievement(58)) do entry[key] = value end
  local goal = Goals.resolve(entry, snapshot)
  local result = Planner.plan(snapshot, goal)
  assertEqual(result.status, "instructional", "persistent progress goals need the enhanced tier")
end

local function testBossRoomKindsUseBossIdEnum()
  local adapter = GameAdapter.new({ bossType = { MOM = 6, MOMS_HEART = 8, SATAN = 24, ISAAC = 39 }, roomType = { ROOM_BOSS = 5 } })
  local room = { GetBossID = function() return 24 end }
  assertEqual(adapter:roomKind(5, 0, room), "satan", "BossID should normalize regular boss rooms")
end

local function testCapabilityDetectionProbesEnhancedFeaturesIndividually()
  local enhanced = Capabilities.detect({ Version = "1.1.2e", MeetsVersion = function() return true end }, {
    ModConfigMenu = true,
    isaac = { GetPersistentGameData = function() end, GetCompletionMarks = function() end },
    callbacks = { MC_POST_ACHIEVEMENT_UNLOCK = 1, MC_POST_COMPLETION_MARK_GET = 2 },
    game = { AchievementUnlocksDisallowed = function() end }
  })
  assertTrue(enhanced.persistentAchievements, "enhanced capabilities should expose persistent achievement reads")
  assertTrue(enhanced.completionMarks, "enhanced capabilities should expose completion mark reads")
  assertTrue(enhanced.preciseEvents, "enhanced capabilities should expose precise progress callbacks")
end

local function testCatalogClassifiesKnownUnmappedAchievementsInstructionally()
  local catalog = Catalog.new({ { id = 4, name = "Known Instruction", achievementId = 100 } }, {}, { knownAchievementMax = 637 })
  assertEqual(catalog:get(4).status, "instructional_only", "known but unmapped achievements should be instructional")
  assertEqual(catalog:get(4).classification, "instructional_only", "catalog should expose the explicit classification")
end

local function testNormalizedCallbacksInvalidateRealController()
  local controller = Controller.new({ plan = function() return { status = "ok" } end })
  controller.dirty = false
  local callbacks = Events.normalized(controller)
  callbacks.room()
  assertTrue(controller.dirty, "normalized callbacks must invoke Controller:onEvent")
end

local function testPlannerWaitsWhenCurrentRoomIsMissing()
  local snapshot = baseSnapshot()
  snapshot.currentRoom = 99
  local result = Planner.plan(snapshot, { id = "boss.delirium", kind = "boss", destinationRooms = { 3 } })
  assertEqual(result.status, "waiting", "planner should wait for a complete room graph")
end

local function testPlannerDoesNotFollowInvalidDoorTarget()
  local snapshot = baseSnapshot()
  snapshot.rooms[1].doors = { { to = 999, slot = 0 } }
  local result = Planner.plan(snapshot, { id = "boss.delirium", kind = "boss", destinationRooms = { 3 } })
  assertTrue(result.status == "waiting" or result.status == "unreachable", "invalid door targets must not throw")
end

local function testRoomGraphUsesSafeGridIndexAsCanonicalId()
  local adapter = GameAdapter.new({ roomType = {} })
  local level = { GetRooms = function()
    return {
      { ListIndex = 0, GridIndex = 100, SafeGridIndex = 100, VisitedCount = 1, DisplayFlags = 1, Data = { Type = 1 } },
      { ListIndex = 1, GridIndex = 101, SafeGridIndex = 101, VisitedCount = 0, DisplayFlags = 1, Data = { Type = 1 } }
    }
  end }
  local rooms = adapter:buildRooms(level, 100, nil, {})
  local found = false
  for _, room in ipairs(rooms) do if room.id == 100 then found = true end end
  assertTrue(found, "room IDs must match Level current/door grid indices")
end

local function testRuntimeReportsRepeatedFailureOnce()
  local messages = {}
  local runtime = Runtime.new({
    adapter = { build = function() error("synthetic planner failure") end },
    controller = {},
    getGoal = function() return {} end,
    fingerprint = function() return "" end,
    output = function(message) messages[#messages + 1] = message end,
    capabilities = { tier = "base" }
  })
  runtime:update()
  runtime:update()
  assertEqual(#messages, 1, "repeated runtime errors should be reported once")
  assertEqual(runtime:getRecommendation().status, "error", "runtime failures should become an error recommendation")
end

local function testRuntimeDefersRenderUntilRenderCall()
  local rendered = 0
  local runtime = Runtime.new({
    adapter = { build = function() return { currentRoom = 1 } end },
    controller = { tick = function() return { status = "ok" } end },
    getGoal = function() return {} end,
    fingerprint = function() return "1" end,
    capabilities = { tier = "base" },
    ui = { render = function() rendered = rendered + 1 end }
  })
  runtime:update()
  assertEqual(rendered, 0, "update must not render the HUD")
  runtime:render()
  assertEqual(rendered, 1, "render should occur only through the render method")
end

local function testFairPlaySnapshotRemovesSecretAndInvalidTopology()
  local Visibility = require("runcompass.visibility")
  local filtered = Visibility.sanitizeSnapshot({
    currentRoom = 1,
    rooms = {
      { id = 1, visited = true, hidden = false, doors = { { to = 2, slot = 0 }, { to = 99, slot = 1 } } },
      { id = 2, visited = true, kind = "secret", hidden = false, doors = {} },
      { id = 3, visited = false, hidden = false, doors = {} }
    },
    observations = { rooms = { [1] = { pickups = { { subtype = 42, quality = 4, category = "collectible" } } } } },
    visibility = { curseLost = true, curseBlind = true }
  })
  assertTrue(filtered.rooms[2] == nil, "visited secret rooms must not reach the planner")
  assertTrue(filtered.rooms[3] == nil, "unvisited Curse of the Lost rooms must not reach the planner")
  assertEqual(#filtered.rooms[1].doors, 0, "doors into removed or invalid rooms must be pruned")
  local pickup = filtered.observations.rooms[1].pickups[1]
  assertEqual(pickup.subtype, nil, "Blind pickup identity must be stripped")
  assertEqual(pickup.quality, nil, "Blind pickup quality must be stripped")
  assertEqual(pickup.category, "collectible", "Blind pickup category may remain generic")
end

local function testSnapshotBuilderDeepCopiesRuntimeObservations()
  local observations = { rooms = { [1] = { pickups = { { category = "collectible" } } } } }
  local builder = Snapshot.new({
    getCurrentRoom = function() return 1 end,
    getMode = function() return { kind = "normal", difficulty = "normal" } end,
    getVisibility = function() return { curseBlind = false, curseLost = false } end,
    getPlayer = function() return { keys = 1 } end,
    getRooms = function() return { { id = 1, visited = true, doors = {} } } end,
    getObservations = function() return observations end
  })
  local snapshot = builder:build()
  snapshot.observations.rooms[1].pickups[1].category = "changed"
  assertEqual(observations.rooms[1].pickups[1].category, "collectible", "snapshot mutation must not change adapter state")
end

local function testGameAdapterStoresPickupsByObservedRoom()
  local currentRoom = {
    IsClear = function() return true end,
    GetFrameCount = function() return 10 end,
    GetDoor = function() return nil end
  }
  local level = {
    GetCurrentRoomIndex = function() return 100 end,
    GetCurrentRoom = function() return currentRoom end,
    GetCurses = function() return 0 end,
    GetRooms = function()
      return { { GridIndex = 100, SafeGridIndex = 100, ListIndex = 0, VisitedCount = 1, DisplayFlags = 1, Data = { Type = 1 } } }
    end
  }
  local game = {
    GetLevel = function() return level end,
    GetNumPlayers = function() return 0 end,
    IsGreedMode = function() return false end,
    GetSeeds = function() return nil end
  }
  local adapter = GameAdapter.new({
    game = game,
    isaac = { FindByType = function() return { { Variant = 100, SubType = 5, RoomIndex = 100 } } end },
    entityType = { ENTITY_PICKUP = 5 },
    pickupVariant = { PICKUP_COLLECTIBLE = 100 },
    itemConfig = { GetCollectible = function() return { Quality = 4, Name = "Visible" } end },
    collectibleType = { NUM_COLLECTIBLES = 10 }
  })
  local snapshot = adapter:build()
  assertTrue(snapshot.observations.rooms[100] ~= nil, "observed pickups must be keyed by room")
  assertEqual(snapshot.observations.rooms[100].pickups[1].quality, 4, "visible pickup quality should be retained")
end

local function testGameAdapterEmitsContractSnapshotAliases()
  local level = {
    GetCurrentRoomIndex = function() return 100 end,
    GetCurrentRoom = function() return { IsClear = function() return true end, GetFrameCount = function() return 1 end } end,
    GetCurses = function() return 0 end,
    GetStage = function() return 2 end,
    GetStageType = function() return 0 end,
    GetRooms = function() return { { GridIndex = 100, SafeGridIndex = 100, VisitedCount = 1, DisplayFlags = 1, Data = { Type = 1 } } } end
  }
  local adapter = GameAdapter.new({ game = {
    GetLevel = function() return level end, GetNumPlayers = function() return 0 end,
    IsGreedMode = function() return false end, GetSeeds = function() return nil end,
    GetFrameCount = function() return 300 end
  }, roomType = {} })
  local snapshot = adapter:build()
  assertEqual(snapshot.floor.currentRoomId, 100, "contract snapshot should expose canonical floor room")
  assertEqual(snapshot.run.elapsedSeconds, 10, "contract snapshot should expose run timing")
  assertEqual(snapshot.frameId, 300, "contract snapshot should expose a frame identifier")
end

local function testRuntimeCanAssertFairPlayBoundary()
  local runtime = Runtime.new({
    adapter = { build = function() return { rooms = { { id = 1, hidden = true } }, observations = {}, visibility = {} } end },
    controller = { tick = function() return { status = "ok" } end },
    getGoal = function() return {} end,
    fingerprint = function() return "1" end,
    capabilities = { tier = "base" },
    assertFairPlay = true
  })
  local result = runtime:update()
  assertEqual(result.status, "error", "unsafe snapshots should be rejected in assertion mode")
end

local function testHushMilestoneDetectsMissedEntranceTimer()
  local snapshot = baseSnapshot()
  snapshot.run = { elapsedSeconds = 30 * 60 + 1 }
  local result = Milestones.compile({ id = "boss.hush", kind = "boss" }, snapshot)
  assertEqual(result.status, "unreachable", "Hush should be unreachable after the entrance timer")
  assertTrue(result.reasonCodes.timer_missed, "missed Hush timer should be explained")
end

local function testMotherMilestoneReservesHealthAndQuestItems()
  local result = Milestones.compile({ id = "boss.mother", kind = "boss" }, baseSnapshot())
  assertEqual(result.requiredResources.health, 2, "Mother route should reserve Mausoleum entrance health")
  assertTrue(result.requiredItems.knife_piece_1 and result.requiredItems.knife_piece_2, "Mother route should expose both knife-piece milestones")
end

local function testBeastMilestoneExposesPhotoAndAscentRequirements()
  local result = Milestones.compile({ id = "boss.beast", kind = "boss" }, baseSnapshot())
  assertTrue(result.requiredItems.photo and result.requiredItems.dad_note, "Beast route should expose photo and Dad's Note milestones")
  assertTrue(result.futureFloors[1] == "Depths II / Strange Door", "Beast route should provide a strategic future-floor milestone")
end

local function testMilestonesRejectWrongPhotoAndConsumedKnife()
  local beast = baseSnapshot()
  beast.player.inventory = { photoChoice = "wrong" }
  local wrongPhoto = Milestones.compile({ id = "boss.beast", kind = "boss" }, beast)
  assertEqual(wrongPhoto.status, "unreachable", "wrong Beast photo should redirect the run")
  assertTrue(wrongPhoto.reasonCodes.wrong_photo, "wrong photo should be explained")
  local mother = baseSnapshot()
  mother.player.inventory = { knifeConsumed = true }
  local consumed = Milestones.compile({ id = "boss.mother", kind = "boss" }, mother)
  assertEqual(consumed.status, "unreachable", "consumed knife route should be unreachable")
  assertTrue(consumed.reasonCodes.knife_consumed, "consumed knife should be explained")
end

local function testSaveClampsUnsafeValues()
  local migrated = Save.migrate({ hud = { scale = 99, x = -999, y = 999 }, bindings = { keyboardGoal = "bad" }, diagnostics = 1 })
  assertEqual(migrated.hud.scale, 2, "HUD scale should be clamped")
  assertEqual(migrated.hud.x, -400, "HUD X should be clamped")
  assertEqual(migrated.hud.y, 240, "HUD Y should be clamped")
  assertEqual(migrated.diagnostics, false, "diagnostics should require an explicit boolean")
end

local function testCatalogValidationReportsClassifiedTotals()
  local catalog = Catalog.new({ { id = 1, name = "A", achievementId = 1 }, { id = 2, name = "Future", achievementId = 999 } }, { [1] = {} }, { version = 2, knownAchievementMax = 10 })
  local report = catalog:validate({ version = 2 })
  assertEqual(report.total, 2, "catalog report should count collectibles")
  assertEqual(report.classified, 2, "catalog report should classify every entry")
  assertEqual(report.unmapped, 1, "future IDs should be visible in diagnostics")
end

local function testSearchFindsShortestRevealedPath()
  local result = Search.shortestPath(baseSnapshot(), 1, 3)
  assertEqual(result.nodes[1], 1, "shortest path should start at the current room")
  assertEqual(result.nodes[#result.nodes], 3, "shortest path should end at the goal room")
  assertEqual(#result.nodes, 3, "shortest path should use two revealed doors")
end

local function testSearchBeamIsBoundedAndCanUseOptionalDestination()
  local result = Search.beam(baseSnapshot(), { destinationRooms = { 3 } }, 12, 3)
  assertTrue(result.expanded <= 12 * 3, "beam search must remain bounded by width and horizon")
  assertEqual(result.nodes[#result.nodes], 3, "beam search should end at the goal destination")
end

local function testHysteresisRejectsSmallRiskEquivalentSwitch()
  local snapshot = baseSnapshot()
  local previous = { status = "ok", nextDoorSlot = 1, score = 10000, steps = { "old" } }
  local result = Planner.plan(snapshot, { id = "boss.delirium", destinationRooms = { 3 } }, previous)
  assertEqual(result.nextDoorSlot, 1, "small-value alternatives must not flicker the recommendation")
end

local function testHysteresisAllowsLargeImprovement()
  local snapshot = baseSnapshot()
  local previous = { status = "ok", nextDoorSlot = 1, score = 1, steps = { "old" } }
  local result = Planner.plan(snapshot, { id = "boss.delirium", destinationRooms = { 3 } }, previous)
  assertEqual(result.nextDoorSlot, 0, "a materially better route should replace the previous recommendation")
end

local function testInvalidPreviousRecommendationIsNotPreserved()
  local snapshot = baseSnapshot()
  local previous = { status = "ok", nextDoorSlot = 7, score = 10000, steps = { "old" } }
  local result = Planner.plan(snapshot, { id = "boss.delirium", destinationRooms = { 3 } }, previous)
  assertTrue(result.nextDoorSlot ~= 7, "a door that no longer exists cannot be preserved")
end

local function testValuationRanksSurvivalAndResourceMarginBeforeBuildGain()
  local snapshot = baseSnapshot()
  snapshot.player.keys = 1
  local treasure = Valuation.evaluate(snapshot, { 1, 2, 3 }, { requiredResources = { keys = 1 } })
  local shop = Valuation.evaluate(snapshot, { 1, 4, 3 }, { requiredResources = { keys = 1 } })
  assertTrue(Valuation.compare(shop, treasure) > 0, "resource margin should outrank a treasure detour when only one key remains")
end

local function testValuationPrefersVisibleBuildGainWhenRiskIsEqual()
  local snapshot = baseSnapshot()
  snapshot.player.keys = 2
  snapshot.rooms[2].cost = {}
  local treasure = Valuation.evaluate(snapshot, { 1, 2, 3 }, { requiredResources = {} })
  local shop = Valuation.evaluate(snapshot, { 1, 4, 3 }, { requiredResources = {} })
  assertTrue(Valuation.compare(treasure, shop) > 0, "visible build gain should win after feasibility, risk, and margin tie")
end

local function testMcmKeybindRowsOpenInteractivePopups()
  local originalMenu = rawget(_G, "ModConfigMenu")
  local originalMcm = rawget(_G, "MCM")
  local settings = {}
  _G.ModConfigMenu = {
    OptionType = {
      BOOLEAN = 4,
      NUMBER = 5,
      KEYBIND_KEYBOARD = 6,
      KEYBIND_CONTROLLER = 7
    },
    PopupGfx = { WIDE_SMALL = "wide-small" },
    KeyboardToString = { [117] = "F6", [118] = "F7" },
    ControllerToString = { [10] = "A", [13] = "Menu" },
    AddSetting = function(_, _, config) settings[#settings + 1] = config end
  }
  _G.MCM = nil

  local state = {
    bindings = { keyboardGoal = 117, keyboardToggle = 118, controllerGoal = 10, controllerToggle = 13 },
    hud = { visible = true, scale = 1, x = 0, y = 0 },
    pinned = false,
    diagnostics = false,
    decision = { autoCompare = true, detailLevel = 2, showConfidence = true, showWarnings = true, eidDescriptions = false }
  }
  local registered = MCM.register(state)

  _G.ModConfigMenu = originalMenu
  _G.MCM = originalMcm

  assertTrue(registered, "MCM registration should succeed")
  assertEqual(settings[1].Display(), "Goal browser: F6", "keyboard bindings should use friendly MCM key names")
  assertEqual(settings[3].Display(), "Controller goal browser: A", "controller bindings should use friendly MCM button names")
  for index = 1, 4 do
    local option = settings[index]
    assertTrue(type(option.Popup) == "function", "keybind row " .. index .. " must open an input popup")
    assertEqual(option.PopupGfx, "wide-small", "keybind popup should use the installed MCM popup style")
    assertEqual(option.PopupWidth, 280, "keybind popup should fit its instructions")
  end
end

local tests = {
  testRoutesToGoalThroughRevealedRooms,
  testNeverUsesHiddenSecretRoom,
  testReservesRequiredKey,
  testUnsupportedModeIsInactive,
  testHysteresisKeepsStableRecommendation,
  testVisibilityFiltersHiddenInformation,
  testCatalogClassifiesUnknownAndKnownGoals,
  testCatalogClassifiesKnownUnmappedAchievementsInstructionally,
  testCapabilityDetectionFallsBackSafely,
  testCapabilityDetectionProbesEnhancedFeaturesIndividually,
  testSaveMigrationUsesSafeDefaults,
  testSaveRoundTripsLocalData,
  testBlindCurseDoesNotValueHiddenPickup,
  testControllerReplansOnlyWhenDirty,
  testSnapshotBuilderNormalizesRuntimeState,
  testGoalBrowserFiltersAndSortsCatalog,
  testEventsNormalizeKnownCallbacks,
  testGoalResolverFindsCurrentFloorBoss,
  testPresentationFormatsCompactRecommendation,
  testPresentationIncludesBuildChoiceComparison,
  testInstructionalGoalDoesNotPretendToRoute,
  testCompletedGoalStopsRouting,
  testRouteCriticalCollectibleRuleResolvesToBoss,
  testWrongCharacterRedirectsUnlockGoal,
  testPersistentCounterGoalIsInstructionalWithoutEnhancedTier,
  testBossRoomKindsUseBossIdEnum,
  testNormalizedCallbacksInvalidateRealController,
  testPlannerWaitsWhenCurrentRoomIsMissing,
  testPlannerDoesNotFollowInvalidDoorTarget,
  testRoomGraphUsesSafeGridIndexAsCanonicalId,
  testRuntimeReportsRepeatedFailureOnce,
  testRuntimeDefersRenderUntilRenderCall,
  testFairPlaySnapshotRemovesSecretAndInvalidTopology,
  testSnapshotBuilderDeepCopiesRuntimeObservations,
  testGameAdapterStoresPickupsByObservedRoom,
  testGameAdapterEmitsContractSnapshotAliases,
  testRuntimeCanAssertFairPlayBoundary,
  testHushMilestoneDetectsMissedEntranceTimer,
  testMotherMilestoneReservesHealthAndQuestItems,
  testBeastMilestoneExposesPhotoAndAscentRequirements,
  testMilestonesRejectWrongPhotoAndConsumedKnife,
  testSaveClampsUnsafeValues,
  testCatalogValidationReportsClassifiedTotals,
  testSearchFindsShortestRevealedPath,
  testSearchBeamIsBoundedAndCanUseOptionalDestination,
  testHysteresisRejectsSmallRiskEquivalentSwitch,
  testHysteresisAllowsLargeImprovement,
  testInvalidPreviousRecommendationIsNotPreserved,
  testValuationRanksSurvivalAndResourceMarginBeforeBuildGain,
  testValuationPrefersVisibleBuildGainWhenRiskIsEqual,
  testMcmKeybindRowsOpenInteractivePopups
}

for index, test in ipairs(tests) do
  test()
  print("ok " .. index)
end

print(#tests .. " planner tests passed")
