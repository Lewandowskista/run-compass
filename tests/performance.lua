local Planner = require("runcompass.planner")
local rooms = {}
for id = 1, 48 do
  local doors = {}
  if id > 1 then doors[#doors + 1] = { slot = 0, to = id - 1 } end
  if id < 48 then doors[#doors + 1] = { slot = 2, to = id + 1 } end
  rooms[#rooms + 1] = { id = id, visited = true, hidden = false, kind = id == 200 and "delirium" or "normal", doors = doors, pickups = {} }
end
local snapshot = { currentRoom = 1, currentRoomClear = true, mode = { kind = "normal", difficulty = "hard", progressionAllowed = true }, visibility = {}, player = { keys = 6, bombs = 6, coins = 20, health = 6 }, rooms = rooms, capabilities = { tier = "base" } }
local goal = { id = "boss.delirium", kind = "boss", destinationRooms = { 48 } }
local start = os.clock()
local recommendation = Planner.plan(snapshot, goal, nil)
local elapsed = os.clock() - start
assert(recommendation and recommendation.status == "ok", "synthetic floor should route")
assert(elapsed < 0.12, "synthetic floor planner exceeded generous harness budget: " .. tostring(elapsed))
print(string.format("performance planner %.4fs", elapsed))
