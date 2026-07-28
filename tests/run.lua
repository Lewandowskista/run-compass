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
  assertEqual(migrated.schemaVersion, 1, "save data should be migrated")
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
    onEvent = function(name) seen[#seen + 1] = name end
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

local tests = {
  testRoutesToGoalThroughRevealedRooms,
  testNeverUsesHiddenSecretRoom,
  testReservesRequiredKey,
  testUnsupportedModeIsInactive,
  testHysteresisKeepsStableRecommendation,
  testVisibilityFiltersHiddenInformation,
  testCatalogClassifiesUnknownAndKnownGoals,
  testCapabilityDetectionFallsBackSafely,
  testSaveMigrationUsesSafeDefaults,
  testSaveRoundTripsLocalData,
  testBlindCurseDoesNotValueHiddenPickup,
  testControllerReplansOnlyWhenDirty,
  testSnapshotBuilderNormalizesRuntimeState,
  testGoalBrowserFiltersAndSortsCatalog,
  testEventsNormalizeKnownCallbacks,
  testGoalResolverFindsCurrentFloorBoss,
  testPresentationFormatsCompactRecommendation,
  testInstructionalGoalDoesNotPretendToRoute,
  testCompletedGoalStopsRouting
}

for index, test in ipairs(tests) do
  test()
  print("ok " .. index)
end

print(#tests .. " planner tests passed")
