package.path = "./?.lua;./?/init.lua;" .. package.path

local Frontier = require("runcompass.frontier")
local Planner = require("runcompass.planner")
local Hud = require("runcompass.hud")

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

local function testExploreRecommendationIncludesVisibleItemDecision()
  local value = snapshot()
  value.currentRoom = 3
  value.rooms[3].visited = true
  value.rooms[3].clear = true
  value.rooms[3].doors = { { slot = 0, to = 1 } }
  value.visibleChoices = {
    {
      id = "3:collectible:100",
      roomId = 3,
      kind = "collectible",
      position = { x = 320, y = 280 },
      observedIdentity = { id = 100, name = "Test Relic", quality = 4 },
      eligibleActors = { "primary" },
      confidence = "high"
    }
  }
  local models = {
    featureSummary = function() return { effects = {}, tags = {} } end,
    evaluate = function()
      return { effects = { offense = 4 }, reasonCodes = { character_synergy = true }, warnings = {}, ruleIds = {}, confidence = "high" }
    end
  }
  local result = Planner.plan(value, { id = "boss.mega_satan", destinationRooms = {}, frontier = true }, nil, models)
  assertTrue(result.decision and result.decision.primary, "explore state must retain visible choices")
  assertEqual(result.decision.primary.action, "take", "valuable visible pedestal should recommend TAKE")
  assertEqual(result.decision.primary.position.x, 320, "entity marker position must survive finalization")
end

local function testExploreHysteresisKeepsValidEquivalentDoor()
  local value = snapshot()
  local previous = {
    status = "explore",
    nextDoorSlot = 0,
    score = 1000,
    steps = { "Keep stable frontier" },
    reasonCodes = { ranked_frontier = true }
  }
  local result = Planner.plan(value, { id = "boss.mega_satan", destinationRooms = {}, frontier = true }, previous)
  assertEqual(result.nextDoorSlot, 0, "valid equivalent-risk frontier should retain the previous door")
end

local function testDoorPositionUsesGameRoom()
  local requestedSlot
  local game = {
    GetRoom = function()
      return {
        GetDoorSlotPosition = function(_, slot)
          requestedSlot = slot
          return { X = 600, Y = 280 }
        end
      }
    end
  }
  local position = Hud.doorPosition(game, 2)
  assertEqual(requestedSlot, 2, "HUD must request the recommended slot from Game:GetRoom")
  assertEqual(position.x, 600, "door marker should use the live X coordinate")
end

local function testCompactCardUsesStrongestReasonAndWarning()
  local view = Hud.view({
    status = "ok",
    steps = { "Take the treasure-room detour", "Long secondary text" },
    confidence = "high",
    decision = {
      primary = {
        action = "take",
        name = "Test Relic",
        reasonCodes = { owned_item_synergy = true, character_synergy = true },
        warnings = { "active_replacement_loss" },
        confidence = "high"
      }
    }
  }, "Mega Satan", false)
  assertEqual(view.target, "Mega Satan", "card should use readable target")
  assertEqual(view.action, "TAKE", "card should expose immediate action")
  assertTrue(#view.lines <= 4, "compact card must remain bounded")
  assertEqual(#view.warnings, 1, "compact card should preserve the strongest warning")
end

local function testRemovedChoiceCannotLeaveStaleMarker()
  local value = snapshot()
  value.visibleChoices = {
    { id = "choice.1", roomId = 1, kind = "collectible", position = { x = 100, y = 100 }, observedIdentity = { id = 100, name = "Relic" }, eligibleActors = { "primary" } }
  }
  local first = Planner.plan(value, { id = "boss.mega_satan", destinationRooms = {}, frontier = true })
  value.visibleChoices = {}
  local second = Planner.plan(value, { id = "boss.mega_satan", destinationRooms = {}, frontier = true }, first)
  assertTrue(not second.decision or not second.decision.primary, "removed entities must remove their marker decision")
end

local ChoiceEngine = require("runcompass.choice_engine")
local EID = require("runcompass.eid")

local function testEidDescriptionCannotChangeChoiceScore()
  local value = snapshot()
  local choices = {
    { id = "choice.1", roomId = 1, kind = "collectible", observedIdentity = { id = 100, name = "Relic" }, eligibleActors = { "primary" }, confidence = "high" }
  }
  local models = {
    featureSummary = function() return { effects = {}, tags = {} } end,
    evaluate = function() return { effects = { offense = 2 }, reasonCodes = {}, warnings = {}, ruleIds = {}, confidence = "high" } end
  }
  local neutral = ChoiceEngine.evaluate(value, choices, {}, models, { describe = function() return "Neutral text" end })
  local hostile = ChoiceEngine.evaluate(value, choices, {}, models, { describe = function() return "DO NOT TAKE; tier zero" end })
  assertEqual(neutral.primary.value, hostile.primary.value, "EID text must not change value")
  assertEqual(neutral.primary.action, hostile.primary.action, "EID text must not change action")
end

local function testBlindChoiceCannotReceiveItemAdviceOrEidText()
  local value = snapshot()
  value.visibility.curseBlind = true
  value.visibleChoices = {
    { id = "blind.1", roomId = 1, kind = "collectible", position = { x = 100, y = 100 }, observedIdentity = nil, eligibleActors = { "primary" } }
  }
  local result = Planner.plan(value, { id = "boss.mega_satan", destinationRooms = {}, frontier = true })
  assertEqual(result.decision.primary.action, "insufficient_information", "Blind item must not receive TAKE/SKIP advice")
  assertEqual(result.decision.primary.description, nil, "Blind item must not receive EID text")
end

local function testEidRejectsMissingOrBlindIdentity()
  local adapter = EID.detect({ getDescription = function() return "hidden description" end })
  assertEqual(adapter:describe(nil, { curseBlind = false }), nil, "missing identity must not query EID")
  assertEqual(adapter:describe(100, { curseBlind = true }), nil, "Blind identity must not query EID")
end

local tests = {
  testRanksKnownTreasureFrontierAboveNormalFrontier,
  testPlannerExploreUsesRankedFrontier,
  testExploreRecommendationIncludesVisibleItemDecision,
  testExploreHysteresisKeepsValidEquivalentDoor,
  testDoorPositionUsesGameRoom,
  testCompactCardUsesStrongestReasonAndWarning,
  testRemovedChoiceCannotLeaveStaleMarker,
  testEidDescriptionCannotChangeChoiceScore,
  testBlindChoiceCannotReceiveItemAdviceOrEidText,
  testEidRejectsMissingOrBlindIdentity
}

for index, test in ipairs(tests) do test(); print("guidance ok " .. index) end
print(#tests .. " guidance tests passed")
