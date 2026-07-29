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

-- Deterministic multi-label traversal of revealed rooms. Each room retains
-- every nondominated scalar-distance/resource-cost state, with independent
-- edge and valuation histories. Parent links keep rejected labels cheap;
-- complete node/edge arrays are materialized only for retained candidates.
local function revealedStates(snapshot, map, goal)
  local start = snapshot.currentRoom
  local goalRooms = {}
  for _, id in ipairs(goal and goal.destinationRooms or {}) do goalRooms[id] = true end
  local startTotals = Valuation.newTotals()
  local startState = {
    roomId = start,
    totals = startTotals,
    cost = startTotals.cost,
    distance = 0,
    pathLength = 1
  }
  local labels, open, settledStates = { [start] = {} }, {}, {}
  Edges.addLabel(labels[start], startState)
  open[1] = startState
  while #open > 0 do
    local bestIndex = 1
    for index = 2, #open do
      if Edges.stateBefore(open[index], open[bestIndex]) then bestIndex = index end
    end
    local state = table.remove(open, bestIndex)
    if state.active ~= false and not state.expanded then
      state.expanded = true
      settledStates[#settledStates + 1] = state
      local context = Edges.context(snapshot, goal, state.cost)
      for _, door in ipairs(Edges.feasibleDoors(map[state.roomId], context)) do
        local nextRoom = map[door.to]
        if visible(nextRoom, snapshot.visibility or {}) then
          local totals = Valuation.cloneTotals(state.totals)
          Valuation.accumulate(snapshot, nextRoom, goalRooms, totals, Edges.cost(door))
          local candidate = {
            roomId = door.to,
            parent = state,
            edge = door,
            totals = totals,
            cost = totals.cost,
            distance = state.distance + Edges.weight(door),
            pathLength = state.pathLength + 1
          }
          labels[door.to] = labels[door.to] or {}
          if Edges.addLabel(labels[door.to], candidate) then open[#open + 1] = candidate end
        end
      end
    end
  end
  return settledStates
end

function Frontier.candidates(snapshot, goal)
  local map = roomMap(snapshot.rooms)
  local current = map[snapshot.currentRoom]
  if not current then return {} end
  local settledStates = revealedStates(snapshot, map, goal)
  local result = {}
  for _, node in ipairs(settledStates) do
    local room = map[node.roomId]
    if node.active ~= false and room and node.roomId ~= snapshot.currentRoom and node.pathLength > 1
        and (not room.visited or room.kind == "treasure" or room.kind == "shop") then
      local path, edges = Edges.materialize(node)
      local slot = edges[1] and edges[1].slot
      if slot ~= nil then
        local pathLength = node.pathLength
        result[#result + 1] = {
          doorSlot = slot,
          nextRoomId = room.id,
          path = path,
          nodes = path,
          edges = edges,
          cost = node.cost,
          distance = node.distance,
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

local function candidateBefore(left, right)
  local compared = compare(left.evaluation, right.evaluation)
  if compared ~= 0 then return compared > 0 end
  if left.pathLength ~= right.pathLength then return left.pathLength < right.pathLength end
  if left.nextRoomId ~= right.nextRoomId then return left.nextRoomId < right.nextRoomId end
  return Edges.stateBefore(left, right)
end

function Frontier.best(snapshot, goal)
  local best
  for _, candidate in ipairs(Frontier.candidates(snapshot, goal)) do
    if not best or candidateBefore(candidate, best) then best = candidate end
  end
  return best
end

return Frontier
