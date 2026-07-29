local Valuation = require("runcompass.valuation")
local Edges = require("runcompass.edges")

local Frontier = {}

local function roomMap(rooms)
  local result = {}
  for _, room in ipairs(rooms or {}) do result[room.id] = room end
  return result
end

local function visible(room, visibility)
  return room and not room.hidden and not room.secret and not (visibility.curseLost and not room.visited)
end

local function firstDoor(current, path, snapshot, goal)
  local door = Edges.best(current, path[2], Edges.context(snapshot, goal))
  return door and door.slot
end

-- Deterministic Dijkstra traversal of revealed rooms. Each settled room
-- carries the cheapest known room-id path and the cumulative valuation totals
-- for the exact selected edges on that path. A cheaper relaxation replaces
-- both together, so cost and path identity cannot diverge.
--
-- Every node's `path` and `totals` are its own independent tables (never
-- shared with a parent or sibling), since `nodes[roomId]` stays alive and is
-- read again later when building that room's candidate entry.
local function revealedNodes(snapshot, map, goal)
  local start = snapshot.currentRoom
  local goalRooms = {}
  for _, id in ipairs(goal and goal.destinationRooms or {}) do goalRooms[id] = true end
  local nodes = { [start] = { path = { start }, totals = Valuation.newTotals(), distance = 0 } }
  local open, inOpen, settled, visitOrder = { start }, { [start] = true }, {}, {}
  while #open > 0 do
    local bestIndex = 1
    for index = 2, #open do
      if nodes[open[index]].distance < nodes[open[bestIndex]].distance then bestIndex = index end
    end
    local roomId = table.remove(open, bestIndex)
    inOpen[roomId] = nil
    settled[roomId] = true
    visitOrder[#visitOrder + 1] = roomId
    local current = nodes[roomId]
    local context = Edges.context(snapshot, goal, current.totals.cost)
    for _, door in ipairs(Edges.bestDoors(map[roomId], context)) do
      local nextRoom = map[door.to]
      local nextDistance = current.distance + Edges.weight(door)
      if not settled[door.to] and visible(nextRoom, snapshot.visibility or {})
          and (not nodes[door.to] or nextDistance < nodes[door.to].distance) then
        local currentLength = #current.path
        local path = table.move(current.path, 1, currentLength, 1, {})
        path[currentLength + 1] = door.to
        local totals = Valuation.cloneTotals(current.totals)
        Valuation.accumulate(snapshot, nextRoom, goalRooms, totals, Edges.cost(door))
        nodes[door.to] = { path = path, totals = totals, distance = nextDistance }
        if not inOpen[door.to] then
          open[#open + 1] = door.to
          inOpen[door.to] = true
        end
      end
    end
  end
  -- `visitOrder` holds every settled room id in deterministic weighted order, so
  -- it doubles as an ordered visit list callers can walk instead of using
  -- `pairs(nodes)` (unordered hash iteration).
  return nodes, visitOrder
end

function Frontier.candidates(snapshot, goal)
  local map = roomMap(snapshot.rooms)
  local current = map[snapshot.currentRoom]
  if not current then return {} end
  local nodes, visitOrder = revealedNodes(snapshot, map, goal)
  local result = {}
  -- Every revealed, reachable room already appears at most once in
  -- `visitOrder` (Dijkstra settles each room id once), so no separate "seen" dedup
  -- table or repeated `visible()` re-check is needed here: `nodes` already
  -- reflects exactly the rooms `visible()` would accept.
  for _, roomId in ipairs(visitOrder) do
    local node = nodes[roomId]
    local room = map[roomId]
    if room and roomId ~= snapshot.currentRoom and #node.path > 1 and (not room.visited or room.kind == "treasure" or room.kind == "shop") then
      local slot = firstDoor(current, node.path, snapshot, goal)
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
