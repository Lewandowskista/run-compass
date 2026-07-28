package.path = "./?.lua;./?/init.lua;" .. package.path

local Frontier = require("runcompass.frontier")
local Planner = require("runcompass.planner")

local function assertEqual(actual, expected, message)
  if actual ~= expected then error((message or "values differ") .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")") end
end

local function assertTrue(value, message)
  if not value then error(message or "expected truthy value") end
end

local function snapshot()
  return {
    currentRoom = 1,
    currentRoomClear = true,
    mode = { kind = "normal", difficulty = "normal", progressionAllowed = true },
    player = { health = 6, maxHealth = 6, keys = 2, bombs = 1, coins = 5, resources = { keys = 2, bombs = 1, coins = 5 } },
    visibility = { curseBlind = false, curseLost = false },
    capabilities = { tier = "enhanced" },
    rooms = {
      { id = 1, kind = "normal", visited = true, clear = true, doors = { { slot = 0, to = 2 }, { slot = 2, to = 3 } } },
      { id = 2, kind = "normal", visited = false, clear = false, doors = { { slot = 2, to = 1 } }, pickups = {} },
      { id = 3, kind = "treasure", visited = false, clear = false, doors = { { slot = 0, to = 1 } }, pickups = { { id = 100, visible = true, quality = 4 } } }
    },
    visibleChoices = {}
  }
end

local function testRanksKnownTreasureFrontierAboveNormalFrontier()
  local candidate = Frontier.best(snapshot(), { id = "boss.mega_satan", destinationRooms = {}, frontier = true })
  assertEqual(candidate.doorSlot, 2, "known treasure value should beat iteration order")
  assertEqual(candidate.nextRoomId, 3, "candidate should identify the ranked frontier")
end

local function testPlannerExploreUsesRankedFrontier()
  local result = Planner.plan(snapshot(), { id = "boss.mega_satan", destinationRooms = {}, frontier = true })
  assertEqual(result.status, "explore", "unknown target branch should remain exploratory")
  assertEqual(result.nextDoorSlot, 2, "planner must expose the ranked exact door")
  assertTrue(result.reasonCodes.ranked_frontier, "explanation should identify ranked frontier selection")
end

local tests = {
  testRanksKnownTreasureFrontierAboveNormalFrontier,
  testPlannerExploreUsesRankedFrontier
}

for index, test in ipairs(tests) do test(); print("guidance ok " .. index) end
print(#tests .. " guidance tests passed")
