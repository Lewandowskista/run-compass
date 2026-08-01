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
local Frontier = require("runcompass.frontier")
local MCM = require("runcompass.mcm")
local UI = require("runcompass.ui")
local RouteState = require("runcompass.route_state")

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
      { id = 1, kind = "start", visited = true, clear = true, doors = { { to = 2, slot = 0, cost = { keys = 1 } }, { to = 4, slot = 1 } } },
      { id = 2, kind = "treasure", visited = false, clear = false, doors = { { to = 1, slot = 2 }, { to = 3, slot = 0 } }, pickups = { { id = 1, quality = 4, visible = true } } },
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
  assertEqual(migrated.schemaVersion, 5, "save data should be migrated")
  assertEqual(migrated.pinned, false, "missing fields should use safe defaults")
end

local function testSaveRoundTripsLocalData()
  local encoded = Save.serialize({ schemaVersion = 1, selectedGoalId = "boss.delirium", pinned = true })
  local decoded = Save.deserialize(encoded)
  assertEqual(decoded.selectedGoalId, "boss.delirium", "save serializer should preserve selected goal")
  assertEqual(decoded.pinned, true, "save serializer should preserve pin state")
end

local function testSaveV4AddsBrowserCategoryAndDetailBindings()
  local migrated = Save.migrate({ schemaVersion = 3, browser = { status = "locked" }, bindings = { keyboardGoal = 117 } })
  assertEqual(migrated.schemaVersion, 5, "trustworthy foundation requires schema v5")
  assertEqual(migrated.browser.category, "boss_routes", "migration should add the default category")
  assertEqual(migrated.bindings.keyboardDetail, 297, "migration should add a detail key")
  assertEqual(migrated.bindings.controllerDetail, 11, "migration should add a detail controller button")
end

local function testKeyboardBindingsAreRealKeycodes()
  -- GLFW (Isaac's Keyboard enum) has no keys 117-119; legacy defaults could never trigger
  local fresh = Save.migrate(nil)
  assertEqual(fresh.bindings.keyboardGoal, 295, "default goal key should be a real keycode (F6)")
  assertEqual(fresh.bindings.keyboardToggle, 296, "default toggle key should be a real keycode (F7)")
  assertEqual(fresh.bindings.keyboardDetail, 297, "default detail key should be a real keycode (F8)")
  local legacy = Save.migrate({ schemaVersion = 4, bindings = { keyboardGoal = 117, keyboardToggle = 118, keyboardDetail = 119 } })
  assertEqual(legacy.bindings.keyboardGoal, 295, "unusable legacy goal code must remap to F6")
  assertEqual(legacy.bindings.keyboardToggle, 296, "unusable legacy toggle code must remap to F7")
  assertEqual(legacy.bindings.keyboardDetail, 297, "unusable legacy detail code must remap to F8")
  local assigned = Save.migrate({ schemaVersion = 4, bindings = { keyboardGoal = 71, keyboardToggle = 72, keyboardDetail = 73 } })
  assertEqual(assigned.bindings.keyboardGoal, 71, "user-assigned keys must survive migration")
  assertEqual(assigned.bindings.keyboardToggle, 72, "user-assigned keys must survive migration")
  assertEqual(assigned.bindings.keyboardDetail, 73, "user-assigned keys must survive migration")
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

local function testGameAdapterReadsLiveRoomDescriptorListApi()
  local descriptors = {
    { ListIndex = 0, GridIndex = 100, SafeGridIndex = 100, VisitedCount = 1, DisplayFlags = 1, Data = { Type = 1 } },
    { ListIndex = 1, GridIndex = 101, SafeGridIndex = 101, VisitedCount = 0, DisplayFlags = 1, Data = { Type = 1 } }
  }
  local roomList = setmetatable({}, {
    __index = function(_, key)
      if key == "Size" then return #descriptors end
      if key == "Get" then return function(_, index) return descriptors[index + 1] end end
    end
  })
  local currentRoom = {
    IsClear = function() return true end,
    GetFrameCount = function() return 12 end
  }
  local level = {
    GetRooms = function() return roomList end,
    GetCurrentRoomIndex = function() return 101 end,
    GetCurrentRoomDesc = function() return descriptors[1] end,
    GetCurses = function() return 0 end
  }
  local game = {
    GetLevel = function() return level end,
    GetRoom = function() return currentRoom end,
    GetNumPlayers = function() return 0 end,
    IsGreedMode = function() return false end,
    GetSeeds = function() return nil end
  }
  local snapshot = GameAdapter.new({ game = game, roomType = {} }):build()
  assertEqual(#snapshot.rooms, 2, "RoomDescriptorList must be enumerated through Size and Get")
  assertEqual(snapshot.currentRoom, 100, "current room must use the descriptor SafeGridIndex")
  assertEqual(snapshot.currentRoomClear, true, "current room state must come from Game:GetRoom")
  local recommendation = Planner.plan(snapshot, { id = "boss.delirium", kind = "boss", destinationRooms = { 101 } })
  assertTrue(recommendation.status ~= "waiting", "a complete live room graph must not stay in the loading state")
end

local function testGameAdapterCallsIsLockedAndNormalizesOrdinaryKeyDoor()
  local descriptors = {
    { ListIndex = 0, GridIndex = 100, SafeGridIndex = 100, VisitedCount = 1, DisplayFlags = 1, Data = { Type = 1 } },
    { ListIndex = 1, GridIndex = 101, SafeGridIndex = 101, VisitedCount = 0, DisplayFlags = 1, Data = { Type = 1 } },
    { ListIndex = 2, GridIndex = 102, SafeGridIndex = 102, VisitedCount = 0, DisplayFlags = 1, Data = { Type = 1 } }
  }
  local lockedCalls = 0
  local currentRoom = {
    GetDoor = function(_, slot)
      if slot == 0 then
        return {
          TargetRoomIndex = 101,
          Desc = { Variant = 1 },
          IsLocked = function()
            lockedCalls = lockedCalls + 1
            return true
          end,
          IsOpen = function() return false end
        }
      elseif slot == 1 then
        return {
          TargetRoomIndex = 102,
          Desc = { Variant = 9 },
          IsLocked = function()
            lockedCalls = lockedCalls + 1
            return false
          end,
          IsOpen = function() return true end
        }
      end
    end
  }
  local level = { GetRooms = function() return descriptors end }
  local adapter = GameAdapter.new({ roomType = {}, doorVariant = { DOOR_LOCKED = 1, DOOR_UNLOCKED = 9 } })
  local rooms = adapter:buildRooms(level, 100, currentRoom, {})
  local door, unlocked
  for _, room in ipairs(rooms) do
    if room.id == 100 then
      for _, candidate in ipairs(room.doors) do
        if candidate.slot == 0 then door = candidate else unlocked = candidate end
      end
    end
  end
  assertEqual(lockedCalls, 2, "door:IsLocked() should be invoked for every live door")
  assertEqual(door.slot, 0, "door slot should be retained")
  assertEqual(door.to, 101, "door target should be normalized to canonical room ID")
  assertEqual(door.kind, "ordinary", "ordinary key doors should be classified explicitly")
  assertEqual(door.locked, true, "locked state should come from the method result")
  assertEqual(door.open, false, "open state should come from the method result")
  assertEqual(door.cost.keys, 1, "ordinary locked doors should cost one key")
  assertEqual(door.confidence, "high", "known ordinary lock costs should be high confidence")
  assertEqual(unlocked.kind, "ordinary", "ordinary unlocked doors should retain their kind")
  assertEqual(unlocked.locked, false, "unlocked method results should remain false")
  assertEqual(unlocked.open, true, "open method results should remain true")
  assertEqual(next(unlocked.cost), nil, "open or unlocked doors should have zero resource cost")
  assertEqual(unlocked.confidence, "high", "observed zero-cost doors should be high confidence")
end

local function testGameAdapterMarksSpecialLockedDoorCostUnknown()
  local descriptors = {
    { GridIndex = 100, SafeGridIndex = 100, VisitedCount = 1, DisplayFlags = 1, Data = { Type = 1 } },
    { GridIndex = 101, SafeGridIndex = 101, VisitedCount = 0, DisplayFlags = 1, Data = { Type = 1 } }
  }
  local currentRoom = {
    GetDoor = function(_, slot)
      if slot ~= 0 then return nil end
      return {
        TargetRoomIndex = 101,
        Desc = { Variant = 2 },
        IsLocked = function() return true end,
        IsOpen = function() return false end
      }
    end
  }
  local adapter = GameAdapter.new({ roomType = {}, doorVariant = { DOOR_LOCKED = 1, DOOR_LOCKED_DOUBLE = 2 } })
  local rooms = adapter:buildRooms({ GetRooms = function() return descriptors end }, 100, currentRoom, {})
  local door
  for _, room in ipairs(rooms) do
    if room.id == 100 then door = room.doors[1] end
  end
  assertEqual(door.kind, "special", "known non-ordinary lock variants should be classified as special")
  assertEqual(door.locked, true, "special door lock state should remain observed")
  assertEqual(door.cost.unknown, true, "special locked doors should expose unknown resource cost")
  assertEqual(door.confidence, "low", "unknown special lock costs should be low confidence")
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

local function testRouteStateIsObservedAndClassifiesSpecialDoors()
  local snapshot = baseSnapshot()
  snapshot.floor = { stage = 8, stageType = 1, currentRoomId = 1 }
  snapshot.run = { elapsedSeconds = 29 * 60 }
  snapshot.player.inventory = { questItems = { key_piece_1 = true }, photoChoice = "polaroid", routeCards = { fool = true } }
  snapshot.rooms[1].doors = {
    { slot = 0, to = 2, kind = "special", cost = { unknown = true }, confidence = "low" },
    { slot = 1, to = 3, kind = "ordinary", cost = {} }
  }
  local state = RouteState.fromSnapshot(snapshot)
  assertEqual(state.stage, 8, "route state should copy observed stage")
  assertEqual(state.stageType, 1, "route state should copy observed stage type")
  assertTrue(state.questPieces.key_piece_1, "route state should copy observed quest pieces")
  assertEqual(state.photoChoice, "polaroid", "route state should copy observed photo choice")
  assertTrue(state.routeCards.fool, "route state should copy observed route cards")
  assertEqual(state.timers.hushDeadline, 30 * 60, "route state should expose the Hush deadline")
  assertEqual(state.visibleSpecialDoors[1].slot, 0, "route state should expose observed special door slots")
end

local function testPlannerEmitsTypedEnterDoorAction()
  local snapshot = baseSnapshot()
  snapshot.rooms[1].doors = { { slot = 3, to = 3, cost = { keys = 1 } } }
  snapshot.player.keys = 2
  local result = Planner.plan(snapshot, { id = "boss.delirium", kind = "boss", destinationRooms = { 3 }, requiredResources = {} })
  assertEqual(result.status, "ok", "revealed destination should remain routable")
  assertEqual(result.nextAction.type, "ENTER_DOOR", "routed path should expose a typed enter-door action")
  assertEqual(result.nextAction.doorSlot, 3, "typed action should retain the exact selected door")
  assertEqual(result.nextAction.cost.keys, 1, "typed action should expose the traversed edge cost")
end

local function testPlannerEmitsTypedExploreFrontierAction()
  local snapshot = baseSnapshot()
  snapshot.rooms[2].kind = "treasure"
  snapshot.rooms[2].pickups = { { visible = true, quality = 4 } }
  local result = Planner.plan(snapshot, { id = "boss.mother", kind = "boss", frontier = true, destinationRooms = {} })
  assertEqual(result.status, "explore", "frontier routing should remain exploratory")
  assertEqual(result.nextAction.type, "EXPLORE_FRONTIER", "frontier fallback should be typed explicitly")
  assertEqual(result.nextAction.doorSlot, result.nextDoorSlot, "typed frontier action should point at the rendered door")
end

local function testPlannerMarksExpiredHushDeadlineUnavailable()
  local snapshot = baseSnapshot()
  snapshot.run = { elapsedSeconds = 30 * 60 + 1 }
  local result = Planner.plan(snapshot, { id = "boss.hush", kind = "boss", destinationRooms = { 3 } })
  assertEqual(result.status, "unreachable", "expired Hush entrance should be unavailable")
  assertEqual(result.nextAction.type, "ROUTE_UNAVAILABLE", "expired route should expose a typed unavailable action")
  assertEqual(result.nextAction.deadline, 30 * 60, "typed unavailable action should expose the missed deadline")
end

local function testDeliriumMilestoneDoesNotPredictProbabilisticPortals()
  local result = Milestones.compile({ id = "boss.delirium", kind = "boss" }, baseSnapshot())
  local joined = table.concat(result.branches, "|")
  assertTrue(string.find(joined, "probabilistic", 1, true) == nil, "Delirium guidance must not predict optional Void portals")
  assertTrue(result.reasonCodes.observed_portal_required, "Delirium portal guidance should require observed state")
end

local function testMotherMilestoneReservesHealthAndQuestItems()
  local result = Milestones.compile({ id = "boss.mother", kind = "boss" }, baseSnapshot())
  assertEqual(result.requiredResources.health, 2, "Mother route should reserve Mausoleum entrance health")
  assertTrue(result.requiredItems.knife_piece_1 and result.requiredItems.knife_piece_2, "Mother route should expose both knife-piece milestones")
  local hasPiece = baseSnapshot()
  hasPiece.routeState = { questPieces = { knife_piece_1 = true }, consumedPieces = {} }
  local partial = Milestones.compile({ id = "boss.mother", kind = "boss" }, hasPiece)
  assertTrue(partial.requiredItems.knife_piece_1 == nil and partial.requiredItems.knife_piece_2, "observed knife pieces should satisfy only their own requirement")
end

local function testBeastMilestoneExposesPhotoAndAscentRequirements()
  local result = Milestones.compile({ id = "boss.beast", kind = "boss" }, baseSnapshot())
  assertTrue(result.requiredItems.photo and result.requiredItems.dad_note, "Beast route should expose photo and Dad's Note milestones")
  assertTrue(result.futureFloors[1] == "Depths II / Strange Door", "Beast route should provide a strategic future-floor milestone")
  local ready = baseSnapshot()
  ready.routeState = { questPieces = { photo = true }, routeCards = { fool = true }, photoChoice = "polaroid" }
  local partial = Milestones.compile({ id = "boss.beast", kind = "boss" }, ready)
  assertTrue(partial.requiredItems.photo == nil and partial.requiredItems.fool_or_teleport == nil, "observed photo and teleport card should satisfy Beast route requirements")
end

local function testMegaSatanMilestoneDistinguishesPiecesAndOpeners()
  local opened = baseSnapshot()
  opened.routeState = { questPieces = {}, consumedPieces = {}, alternateOpeners = { dads_key = true } }
  local alternate = Milestones.compile({ id = "boss.mega_satan", kind = "boss" }, opened)
  assertTrue(alternate.requiredItems.key_piece_1 == nil and alternate.requiredItems.key_piece_2 == nil, "observed alternate openers should satisfy Mega Satan access")
  assertTrue(alternate.reasonCodes.alternate_opener_observed, "alternate opener should be explicit")
  local consumed = baseSnapshot()
  consumed.routeState = { questPieces = { key_piece_2 = true }, consumedPieces = { key_piece_1 = true }, alternateOpeners = {} }
  local unavailable = Milestones.compile({ id = "boss.mega_satan", kind = "boss" }, consumed)
  assertEqual(unavailable.status, "unreachable", "consumed Mega Satan key pieces should make the route unavailable")
  assertTrue(unavailable.reasonCodes.key_piece_consumed, "consumed key piece should be explained")
end

local function testMilestonesEmitTypedStrategicActions()
  local mother = Milestones.compile({ id = "boss.mother", kind = "boss" }, baseSnapshot())
  assertEqual(mother.nextAction.type, "COLLECT_QUEST_ITEM", "missing Mother route pieces should request a quest-item collection")
  assertEqual(mother.nextAction.targetId, "knife_piece_1", "Mother action should identify the next missing knife piece")
  assertEqual(mother.nextAction.reserve.health, 2, "Mother action should preserve the flesh-door health reserve")

  local lowHealth = baseSnapshot()
  lowHealth.player.health = 1
  local preserve = Milestones.compile({ id = "boss.mother", kind = "boss" }, lowHealth)
  assertEqual(preserve.nextAction.type, "PRESERVE_RESOURCE", "insufficient reserved health should be a typed preservation action")
  assertEqual(preserve.nextAction.cost.health, 2, "preservation action should expose the required health reserve")

  local opened = baseSnapshot()
  opened.routeState = { alternateOpeners = { dads_key = true } }
  local megaSatan = Milestones.compile({ id = "boss.mega_satan", kind = "boss" }, opened)
  assertEqual(megaSatan.nextAction.type, "USE_OPENER", "observed alternate Mega Satan openers should emit a typed opener action")
  assertEqual(megaSatan.nextAction.targetId, "dads_key", "opener action should identify the observed opener")

  local beast = baseSnapshot()
  beast.routeState = { questPieces = { photo = true, dad_note = true }, routeCards = { fool = true }, photoChoice = "polaroid" }
  local ascent = Milestones.compile({ id = "boss.beast", kind = "boss" }, beast)
  assertEqual(ascent.nextAction.type, "RETURN_TO_ROOM", "completed Beast requirements should guide back through the observed route flow")
  assertEqual(ascent.nextAction.targetId, "ascent", "Beast return action should name the ascent route target")
end

local function testPlannerPropagatesMilestoneActionWhenStrategicEntranceIsNotVisible()
  local result = Planner.plan(baseSnapshot(), { id = "boss.mother", kind = "boss", destinationRooms = {} })
  assertEqual(result.status, "explore", "missing observed strategic entrances should produce guidance instead of generic unavailability")
  assertEqual(result.nextAction.type, "COLLECT_QUEST_ITEM", "planner should preserve milestone typed route actions")
  assertEqual(result.nextAction.targetId, "knife_piece_1", "planner milestone action should identify the concrete missing requirement")
end

local function testMilestonesRejectWrongPhotoAndConsumedKnife()
  local beast = baseSnapshot()
  beast.player.inventory = { photoChoice = "wrong" }
  local wrongPhoto = Milestones.compile({ id = "boss.beast", kind = "boss" }, beast)
  assertEqual(wrongPhoto.status, "unreachable", "wrong Beast photo should redirect the run")
  assertTrue(wrongPhoto.reasonCodes.wrong_photo, "wrong photo should be explained")
  local mother = baseSnapshot()
  mother.routeState = { consumedPieces = { knife = true } }
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

local function testSaveMigratesSubOneHudScaleToTruthfulMinimum()
  local migrated = Save.migrate({ schemaVersion = 4, hud = { scale = 0.5 } })
  assertEqual(migrated.schemaVersion, 5, "scale migration should move saves to schema v5")
  assertEqual(migrated.hud.scale, 1, "bitmap HUD scale below one should migrate to the truthful minimum")
end

local function testSearchRanksPathsByTraversedEdgeCost()
  local snapshot = {
    currentRoom = 1,
    visibility = {},
    rooms = {
      { id = 1, visited = true, doors = { { to = 2, cost = { keys = 1 } }, { to = 3, cost = {} } } },
      { id = 2, visited = true, doors = { { to = 4 } } },
      { id = 3, visited = true, cost = { keys = 99 }, doors = { { to = 4 } } },
      { id = 4, visited = true, doors = {} }
    }
  }
  local result = Search.shortestPath(snapshot, 1, 4)
  assertEqual(result.nodes[2], 3, "search should prefer the free traversed edge and ignore destination-room cost")
end

local function testSearchPrefersCheaperLongerPathOverEarlierDirectEdge()
  local snapshot = {
    currentRoom = 1,
    visibility = {},
    rooms = {
      { id = 1, visited = true, doors = { { to = 3, cost = { unknown = true } }, { to = 2, cost = {} } } },
      { id = 2, visited = true, doors = { { to = 3, cost = {} } } },
      { id = 3, visited = true, doors = {} }
    }
  }
  local result = Search.shortestPath(snapshot, 1, 3)
  assertEqual(#result.nodes, 3, "weighted search should allow a cheaper path with more edges")
  assertEqual(result.nodes[2], 2, "unknown-cost direct edge should lose to the two-hop free route")
end

local function testSearchKeepsFirstDiscoveredEqualCostPath()
  local snapshot = {
    currentRoom = 1,
    visibility = {},
    rooms = {
      { id = 1, visited = true, doors = { { to = 2 }, { to = 3 } } },
      { id = 2, visited = true, doors = { { to = 4 } } },
      { id = 3, visited = true, doors = { { to = 4 } } },
      { id = 4, visited = true, doors = {} }
    }
  }
  local result = Search.shortestPath(snapshot, 1, 4)
  assertEqual(result.nodes[2], 2, "equal-cost paths should retain deterministic door discovery order")
end

local function testSearchBeamBreaksEqualScoreTiesByRoomId()
  local snapshot = {
    currentRoom = 1,
    visibility = {},
    rooms = {
      { id = 1, visited = true, doors = { { to = 3 }, { to = 2 } } },
      { id = 2, visited = true, doors = {} },
      { id = 3, visited = true, doors = {} }
    }
  }
  local result = Search.beam(snapshot, { destinationRooms = { 3, 2 } }, 12, 2)
  assertEqual(result.nodes[#result.nodes], 2, "equal-score beam states should prefer the lower room ID")
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
  assertEqual(treasure.cost.keys, 1, "valuation should charge the traversed locked edge")
  assertTrue(Valuation.compare(shop, treasure) > 0, "resource margin should outrank a treasure detour when only one key remains")
end

local function testValuationRejectsUnaffordableEdgeWithoutReserve()
  local snapshot = baseSnapshot()
  snapshot.player.keys = 0
  local evaluation = Valuation.evaluate(snapshot, { 1, 2 }, { requiredResources = {} })
  assertEqual(evaluation.cost.keys, 1, "valuation should retain the actual traversed key cost")
  assertEqual(evaluation.feasible, false, "actual edge costs must be affordable even without a goal reserve")
end

local function testParallelDoorsUseOneDeterministicAffordableEdge()
  local snapshot = {
    currentRoom = 1,
    currentRoomClear = true,
    mode = { kind = "normal", difficulty = "hard", coOp = false, progressionAllowed = true },
    visibility = {},
    player = { keys = 0, bombs = 0, coins = 0, health = 6, maxHealth = 6 },
    rooms = {
      { id = 1, kind = "start", visited = true, clear = true, doors = {
        { to = 2, slot = 0, cost = { keys = 1 } },
        { to = 2, slot = 1, cost = {} }
      } },
      { id = 2, kind = "boss", visited = false, clear = false, doors = {} }
    }
  }
  local goal = { id = "test.parallel", kind = "boss", destinationRooms = { 2 }, requiredResources = {} }
  local path = Search.shortestPath(snapshot, 1, 2)
  local evaluation = Valuation.evaluate(snapshot, path.nodes, goal)
  local recommendation = Planner.plan(snapshot, goal)
  assertEqual(path.distance, 1, "search should price the free parallel edge")
  assertEqual(evaluation.cost.keys, 0, "valuation should charge the same free parallel edge")
  assertEqual(evaluation.feasible, true, "the selected parallel edge should be affordable")
  assertEqual(recommendation.status, "ok", "planner should keep the affordable parallel route")
  assertEqual(recommendation.nextDoorSlot, 1, "recommended slot should identify the selected free parallel edge")
  assertEqual(recommendation.scoreVector.cost.keys, 0, "planner scoring should use the recommended edge cost")
end

local function testParallelDoorsPreferAffordableResourceWithoutHardCodedPreference()
  local snapshot = {
    currentRoom = 1,
    currentRoomClear = true,
    mode = { kind = "normal", difficulty = "hard", coOp = false, progressionAllowed = true },
    visibility = {},
    player = { keys = 0, bombs = 1, coins = 0, health = 6, maxHealth = 6 },
    rooms = {
      { id = 1, kind = "start", visited = true, clear = true, doors = {
        { to = 2, slot = 0, cost = { keys = 1 } },
        { to = 2, slot = 1, cost = { bombs = 1 } }
      } },
      { id = 2, kind = "treasure", visited = false, clear = false, doors = {}, pickups = { { quality = 4, visible = true } } }
    }
  }
  local goal = { id = "test.resource_parallel", kind = "boss", destinationRooms = { 2 }, requiredResources = {} }
  local path = Search.shortestPath(snapshot, 1, 2, goal)
  local evaluation = Valuation.evaluate(snapshot, path.nodes, goal)
  local recommendation = Planner.plan(snapshot, goal)
  local frontier = Frontier.best(snapshot, goal)
  assertEqual(evaluation.cost.keys, 0, "valuation should not charge the unaffordable lower-slot resource")
  assertEqual(evaluation.cost.bombs, 1, "valuation should charge the affordable selected resource")
  assertEqual(evaluation.feasible, true, "selected resource edge should be affordable")
  assertEqual(recommendation.status, "ok", "planner should retain the affordable parallel resource route")
  assertEqual(recommendation.nextDoorSlot, 1, "recommendation should identify the affordable resource edge")
  assertEqual(recommendation.scoreVector.cost.bombs, 1, "planner score should charge the recommended edge resource")
  assertEqual(frontier.doorSlot, 1, "frontier should use the same affordable resource edge")
  assertEqual(frontier.evaluation.cost.bombs, 1, "frontier valuation should charge its recommended edge")
end

local function testParallelDoorsPreserveRequiredResourceReserve()
  local snapshot = {
    currentRoom = 1,
    currentRoomClear = true,
    mode = { kind = "normal", difficulty = "hard", coOp = false, progressionAllowed = true },
    visibility = {},
    player = { keys = 1, bombs = 1, coins = 0, health = 6, maxHealth = 6 },
    rooms = {
      { id = 1, kind = "start", visited = true, clear = true, doors = {
        { to = 2, slot = 0, cost = { keys = 1 } },
        { to = 2, slot = 1, cost = { bombs = 1 } }
      } },
      { id = 2, kind = "boss", visited = false, clear = false, doors = {} }
    }
  }
  local goal = { id = "test.resource_reserve", kind = "boss", destinationRooms = { 2 }, requiredResources = { keys = 1 } }
  local path = Search.shortestPath(snapshot, 1, 2, goal)
  local evaluation = Valuation.evaluate(snapshot, path.nodes, goal)
  local recommendation = Planner.plan(snapshot, goal)
  assertEqual(evaluation.cost.keys, 0, "edge selection should preserve the required key reserve")
  assertEqual(evaluation.cost.bombs, 1, "edge selection should spend the unreserved resource")
  assertEqual(evaluation.feasible, true, "reserve-preserving parallel edge should remain feasible")
  assertEqual(recommendation.nextDoorSlot, 1, "recommendation should use the reserve-preserving edge")
end

local function testRoutePreservesParetoResourceStateForDownstreamEdge()
  local snapshot = {
    currentRoom = 1,
    currentRoomClear = true,
    mode = { kind = "normal", difficulty = "hard", coOp = false, progressionAllowed = true },
    visibility = {},
    player = { keys = 1, bombs = 1, coins = 0, health = 6, maxHealth = 6 },
    rooms = {
      { id = 1, kind = "start", visited = true, clear = true, doors = {
        { to = 2, slot = 0, cost = { keys = 1 } },
        { to = 2, slot = 1, cost = { bombs = 1 } }
      } },
      { id = 2, kind = "normal", visited = true, clear = true, doors = {
        { to = 3, slot = 2, cost = { keys = 1 } }
      } },
      { id = 3, kind = "treasure", visited = false, clear = false, doors = {}, pickups = { { quality = 4, visible = true } } }
    }
  }
  local goal = { id = "test.pareto_route", kind = "boss", destinationRooms = { 3 }, requiredResources = {} }
  local path = Search.shortestPath(snapshot, 1, 3, goal)
  local recommendation = Planner.plan(snapshot, goal)
  local frontier = Frontier.best(snapshot, goal)
  assertEqual(recommendation.status, "ok", "planner should retain the feasible bomb-entry then key-exit route")
  assertEqual(path.edges[1].slot, 1, "search should preserve the nondominated bomb-entry edge")
  assertEqual(path.edges[2].slot, 2, "search should preserve the downstream key edge")
  assertEqual(path.cost.keys, 1, "search should charge the downstream key exactly once")
  assertEqual(path.cost.bombs, 1, "search should charge the retained bomb-entry state")
  assertEqual(recommendation.nextDoorSlot, 1, "recommendation should use the exact feasible first edge")
  assertEqual(recommendation.scoreVector.cost.keys, 1, "planner valuation should retain exact key history")
  assertEqual(recommendation.scoreVector.cost.bombs, 1, "planner valuation should retain exact bomb history")
  assertEqual(frontier.doorSlot, 1, "frontier should preserve the same feasible first edge")
  assertEqual(frontier.evaluation.feasible, true, "frontier's retained Pareto state should be feasible")
end

local function testDirectGoalRetainsParetoEdgesForPlannerValuation()
  local snapshot = {
    currentRoom = 1,
    currentRoomClear = true,
    mode = { kind = "normal", difficulty = "hard", coOp = false, progressionAllowed = true },
    visibility = {},
    player = { keys = 1, bombs = 1, coins = 0, health = 6, maxHealth = 6 },
    rooms = {
      { id = 1, kind = "start", visited = true, clear = true, doors = {
        { to = 2, slot = 0, cost = { keys = 1 } },
        { to = 2, slot = 1, cost = { bombs = 1 } }
      } },
      { id = 2, kind = "treasure", visited = false, clear = false, doors = {}, pickups = {} }
    }
  }
  local goal = { id = "test.direct_pareto_goal", kind = "boss", destinationRooms = { 2 }, requiredResources = {} }
  local path = Search.shortestPath(snapshot, 1, 2, goal)
  local recommendation = Planner.plan(snapshot, goal)
  assertEqual(path.edges[1].slot, 0, "shortest-path compatibility default should remain deterministic")
  assertEqual(#path.candidates, 2, "search should expose both nondominated destination histories")
  assertEqual(path.candidates[1].edges[1].slot, 0, "destination alternatives should retain deterministic slot order")
  assertEqual(path.candidates[2].edges[1].slot, 1, "destination alternatives should retain the bomb edge")
  assertEqual(recommendation.nextDoorSlot, 1, "planner valuation should prefer spending a bomb over a key")
  assertEqual(recommendation.scoreVector.cost.keys, 0, "planner should retain the key on its selected route")
  assertEqual(recommendation.scoreVector.cost.bombs, 1, "planner should charge the selected bomb edge")
end

local function testRouteFiltersSoleInfeasibleEdge()
  local snapshot = {
    currentRoom = 1,
    currentRoomClear = true,
    mode = { kind = "normal", difficulty = "hard", coOp = false, progressionAllowed = true },
    visibility = {},
    player = { keys = 0, bombs = 0, coins = 0, health = 6, maxHealth = 6 },
    rooms = {
      { id = 1, kind = "start", visited = true, clear = true, doors = {
        { to = 2, slot = 0, cost = { keys = 1 } }
      } },
      { id = 2, kind = "treasure", visited = false, clear = false, doors = {}, pickups = { { quality = 4, visible = true } } }
    }
  }
  local goal = { id = "test.infeasible_edge", kind = "boss", destinationRooms = { 2 }, requiredResources = {} }
  local path = Search.shortestPath(snapshot, 1, 2, goal)
  local frontier = Frontier.best(snapshot, goal)
  local recommendation = Planner.plan(snapshot, goal)
  assertEqual(path, nil, "search should filter a sole unaffordable edge")
  assertEqual(frontier, nil, "frontier should not expose a candidate behind a sole unaffordable edge")
  assertEqual(recommendation.status, "unreachable", "planner should reject the filtered route")
end

local function testFrontierRejectsUnaffordableTreasureWithoutReserve()
  local snapshot = {
    currentRoom = 1,
    visibility = {},
    player = { keys = 0, health = 6, maxHealth = 6 },
    rooms = {
      { id = 1, visited = true, clear = true, doors = {
        { to = 2, slot = 0, cost = { keys = 1 } },
        { to = 3, slot = 1, cost = {} }
      } },
      { id = 2, kind = "treasure", visited = false, clear = false, doors = {}, pickups = { { quality = 4, visible = true } } },
      { id = 3, kind = "normal", visited = false, clear = false, doors = {}, pickups = {} }
    }
  }
  local candidate = Frontier.best(snapshot, { destinationRooms = {}, requiredResources = {}, frontier = true })
  assertEqual(candidate.nextRoomId, 3, "frontier should reject an unaffordable quality-four treasure route")
  assertEqual(candidate.evaluation.feasible, true, "frontier should return the affordable alternative")
end

local function testFrontierRelaxesToCheaperMultiHopPath()
  local snapshot = {
    currentRoom = 1,
    visibility = {},
    player = { keys = 0, health = 6, maxHealth = 6 },
    rooms = {
      { id = 1, visited = true, clear = true, doors = {
        { to = 4, slot = 0, cost = { unknown = true } },
        { to = 2, slot = 1, cost = {} }
      } },
      { id = 2, kind = "normal", visited = true, clear = true, doors = { { to = 3, cost = {} } } },
      { id = 3, kind = "normal", visited = true, clear = true, doors = { { to = 4, cost = {} } } },
      { id = 4, kind = "treasure", visited = false, clear = false, doors = {}, pickups = { { quality = 4, visible = true } } }
    }
  }
  local candidate = Frontier.best(snapshot, { destinationRooms = {}, requiredResources = {}, frontier = true })
  assertEqual(#candidate.path, 4, "frontier should relax an earlier expensive discovery to a cheaper longer path")
  assertEqual(candidate.path[2], 2, "frontier path should traverse the free branch")
  assertEqual(candidate.doorSlot, 1, "frontier marker should use the cheaper path's first door")
  assertEqual(candidate.evaluation.feasible, true, "frontier should evaluate the affordable relaxed path")
end

local function testValuationPrefersVisibleBuildGainWhenRiskIsEqual()
  local snapshot = baseSnapshot()
  snapshot.player.keys = 2
  snapshot.rooms[1].doors[1].cost = {}
  snapshot.rooms[2].cost = { keys = 99 }
  local treasure = Valuation.evaluate(snapshot, { 1, 2, 3 }, { requiredResources = {} })
  local shop = Valuation.evaluate(snapshot, { 1, 4, 3 }, { requiredResources = {} })
  assertTrue(Valuation.compare(treasure, shop) > 0, "visible build gain should win when only destination-room cost differs")
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

local function testControllerConfirmsAndCancelsGoalBrowser()
  local selected = nil
  local triggered = nil
  local ui = UI.new({
    input = { IsButtonTriggered = function(code) return code == triggered end },
    keyboard = { KEY_UP = 100, KEY_DOWN = 101, KEY_TAB = 102, KEY_S = 103, KEY_L = 104, KEY_ESCAPE = 105, KEY_BACKSPACE = 106, KEY_ENTER = 107, KEY_A = 200, KEY_Z = 225, KEY_SPACE = 108, KEY_MINUS = 109 },
    controller = { DPAD_UP = 1, DPAD_DOWN = 2, BUTTON_X = 3, BUTTON_Y = 4, BUTTON_A = 5, BUTTON_B = 6 },
    state = { bindings = { keyboardGoal = 117, keyboardToggle = 118, controllerGoal = 10, controllerToggle = 13 } },
    entries = { { id = "boss.delirium", name = "Delirium", kind = "boss", status = "routable" } },
    onGoalSelected = function(goal) selected = goal end
  })

  ui.open = true
  triggered = 5
  ui:input()
  assertEqual(selected.id, "boss.delirium", "controller A should select the highlighted goal")
  assertEqual(ui.open, false, "selecting a goal should close the browser")

  ui.open = true
  triggered = 6
  ui:input()
  assertEqual(ui.open, false, "controller B should close the browser without changing the goal")
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
  testSaveV4AddsBrowserCategoryAndDetailBindings,
  testKeyboardBindingsAreRealKeycodes,
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
  testGameAdapterReadsLiveRoomDescriptorListApi,
  testGameAdapterCallsIsLockedAndNormalizesOrdinaryKeyDoor,
  testGameAdapterMarksSpecialLockedDoorCostUnknown,
  testRuntimeReportsRepeatedFailureOnce,
  testRuntimeDefersRenderUntilRenderCall,
  testFairPlaySnapshotRemovesSecretAndInvalidTopology,
  testSnapshotBuilderDeepCopiesRuntimeObservations,
  testGameAdapterStoresPickupsByObservedRoom,
  testGameAdapterEmitsContractSnapshotAliases,
  testRuntimeCanAssertFairPlayBoundary,
  testHushMilestoneDetectsMissedEntranceTimer,
  testRouteStateIsObservedAndClassifiesSpecialDoors,
  testPlannerEmitsTypedEnterDoorAction,
  testPlannerEmitsTypedExploreFrontierAction,
  testPlannerMarksExpiredHushDeadlineUnavailable,
  testDeliriumMilestoneDoesNotPredictProbabilisticPortals,
  testMotherMilestoneReservesHealthAndQuestItems,
  testBeastMilestoneExposesPhotoAndAscentRequirements,
  testMegaSatanMilestoneDistinguishesPiecesAndOpeners,
  testMilestonesEmitTypedStrategicActions,
  testPlannerPropagatesMilestoneActionWhenStrategicEntranceIsNotVisible,
  testMilestonesRejectWrongPhotoAndConsumedKnife,
  testSaveClampsUnsafeValues,
  testSaveMigratesSubOneHudScaleToTruthfulMinimum,
  testCatalogValidationReportsClassifiedTotals,
  testSearchFindsShortestRevealedPath,
  testSearchRanksPathsByTraversedEdgeCost,
  testSearchPrefersCheaperLongerPathOverEarlierDirectEdge,
  testSearchKeepsFirstDiscoveredEqualCostPath,
  testSearchBeamBreaksEqualScoreTiesByRoomId,
  testSearchBeamIsBoundedAndCanUseOptionalDestination,
  testHysteresisRejectsSmallRiskEquivalentSwitch,
  testHysteresisAllowsLargeImprovement,
  testInvalidPreviousRecommendationIsNotPreserved,
  testValuationRanksSurvivalAndResourceMarginBeforeBuildGain,
  testFrontierRejectsUnaffordableTreasureWithoutReserve,
  testFrontierRelaxesToCheaperMultiHopPath,
  testValuationRejectsUnaffordableEdgeWithoutReserve,
  testParallelDoorsUseOneDeterministicAffordableEdge,
  testParallelDoorsPreserveRequiredResourceReserve,
  testParallelDoorsPreferAffordableResourceWithoutHardCodedPreference,
  testRouteFiltersSoleInfeasibleEdge,
  testRoutePreservesParetoResourceStateForDownstreamEdge,
  testDirectGoalRetainsParetoEdgesForPlannerValuation,
  testValuationPrefersVisibleBuildGainWhenRiskIsEqual,
  testMcmKeybindRowsOpenInteractivePopups,
  testControllerConfirmsAndCancelsGoalBrowser
}

for index, test in ipairs(tests) do
  test()
  print("ok " .. index)
end

print(#tests .. " planner tests passed")
