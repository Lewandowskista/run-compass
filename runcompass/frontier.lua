local Valuation = require("runcompass.valuation")

local Frontier = {}

local function roomMap(rooms)
  local result = {}
  for _, room in ipairs(rooms or {}) do result[room.id] = room end
  return result
end

local function visible(room, visibility)
  return room and not room.hidden and not room.secret and not (visibility.curseLost and not room.visited)
end

local function firstDoor(current, path)
  for _, door in ipairs(current.doors or {}) do
    if path[2] == door.to then return door.slot end
  end
end

-- Breadth-first traversal of revealed rooms from the current room. Each
-- visited room carries: its `path` (the same room-id sequence the original
-- walk-based implementation reconstructed via parent pointers, built once
-- per node here by extending the parent's already-built path instead of
-- walking back from every downstream candidate) and the cumulative Valuation
-- totals for that path, built by paying each traversed door's
-- `Valuation.accumulate` cost exactly once (when its target is first visited) instead of once per
-- downstream candidate. This turns the overall candidate-ranking cost from
-- O(rooms^2) into O(rooms + doors).
--
-- Every node's `path` and `totals` are its own independent tables (never
-- shared with a parent or sibling), since `nodes[roomId]` stays alive and is
-- read again later when building that room's candidate entry.
local function revealedNodes(snapshot, map, goal)
  local start = snapshot.currentRoom
  local goalRooms = {}
  for _, id in ipairs(goal and goal.destinationRooms or {}) do goalRooms[id] = true end
  local nodes = { [start] = { path = { start }, totals = Valuation.newTotals() } }
  local queue, head = { start }, 1
  while head <= #queue do
    local roomId = queue[head]
    head = head + 1
    local current = nodes[roomId]
    for _, door in ipairs(map[roomId] and map[roomId].doors or {}) do
      local nextRoom = map[door.to]
      if not nodes[door.to] and visible(nextRoom, snapshot.visibility or {}) then
        local currentLength = #current.path
        local path = table.move(current.path, 1, currentLength, 1, {})
        path[currentLength + 1] = door.to
        local totals = Valuation.cloneTotals(current.totals)
        Valuation.accumulate(snapshot, nextRoom, goalRooms, totals, door.cost)
        nodes[door.to] = { path = path, totals = totals }
        queue[#queue + 1] = door.to
      end
    end
  end
  -- `queue` ends up holding every visited room id in BFS-discovery order, so
  -- it doubles as an ordered visit list callers can walk instead of using
  -- `pairs(nodes)` (unordered hash iteration).
  return nodes, queue
end

function Frontier.candidates(snapshot, goal)
  local map = roomMap(snapshot.rooms)
  local current = map[snapshot.currentRoom]
  if not current then return {} end
  local nodes, visitOrder = revealedNodes(snapshot, map, goal)
  local result = {}
  -- Every revealed, reachable room already appears at most once in
  -- `visitOrder` (BFS visits each room id once), so no separate "seen" dedup
  -- table or repeated `visible()` re-check is needed here: `nodes` already
  -- reflects exactly the rooms `visible()` would accept.
  for _, roomId in ipairs(visitOrder) do
    local node = nodes[roomId]
    local room = map[roomId]
    if room and roomId ~= snapshot.currentRoom and #node.path > 1 and (not room.visited or room.kind == "treasure" or room.kind == "shop") then
      local slot = firstDoor(current, node.path)
      if slot ~= nil then
        local pathLength = #node.path
        result[#result + 1] = {
          doorSlot = slot,
          nextRoomId = room.id,
          path = node.path,
          pathLength = pathLength,
          roomKind = room.kind,
          evaluation = Valuation.finalize(snapshot, goal, node.totals, pathLength),
          reasonCodes = {
            ranked_frontier = true,
            treasure_detour = room.kind == "treasure",
            shop_detour = room.kind == "shop"
          }
        }
      end
    end
  end
  return result
end

local compare = Valuation.compare

function Frontier.best(snapshot, goal)
  local candidates = Frontier.candidates(snapshot, goal)
  table.sort(candidates, function(left, right)
    local compared = compare(left.evaluation, right.evaluation)
    if compared ~= 0 then return compared > 0 end
    if left.pathLength ~= right.pathLength then return left.pathLength < right.pathLength end
    return left.nextRoomId < right.nextRoomId
  end)
  return candidates[1]
end

return Frontier
