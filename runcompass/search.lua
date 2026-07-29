local Search = {}
local Visibility = require("runcompass.visibility")
local Edges = require("runcompass.edges")

local function roomMap(rooms)
  local result = {}
  for _, room in ipairs(rooms or {}) do result[room.id] = room end
  return result
end

local function visible(room, flags)
  return room and not room.hidden and not room.secret and not (flags.curseLost and not room.visited)
end

local function copyAppend(values, value)
  local result = {}
  for index, item in ipairs(values or {}) do result[index] = item end
  result[#result + 1] = value
  return result
end

function Search.shortestPath(snapshot, start, destination, goal, initialCost)
  local rooms = roomMap(snapshot.rooms)
  if not rooms[start] or not rooms[destination] then return nil end
  local flags = snapshot.visibility or {}
  local startState = {
    roomId = start,
    nodes = { start },
    edges = {},
    cost = initialCost or {},
    distance = 0,
    active = true
  }
  local labels, open = { [start] = { startState } }, { startState }
  while #open > 0 do
    local bestIndex = 1
    for index = 2, #open do
      if Edges.stateBefore(open[index], open[bestIndex]) then bestIndex = index end
    end
    local state = table.remove(open, bestIndex)
    if state.active ~= false and not state.expanded then
      state.expanded = true
      if state.roomId == destination then
        return { nodes = state.nodes, edges = state.edges, cost = state.cost, distance = state.distance }
      end
      local context = Edges.context(snapshot, goal, state.cost)
      for _, door in ipairs(Edges.feasibleDoors(rooms[state.roomId], context)) do
        local nextRoom = rooms[door.to]
        if visible(nextRoom, flags) then
          local candidate = {
            roomId = door.to,
            nodes = copyAppend(state.nodes, door.to),
            edges = copyAppend(state.edges, door),
            cost = Edges.addCost(state.cost, door),
            distance = state.distance + Edges.weight(door)
          }
          labels[door.to] = labels[door.to] or {}
          if Edges.addLabel(labels[door.to], candidate) then
            open[#open + 1] = candidate
          end
        end
      end
    end
  end
  return nil
end

local function pathScore(snapshot, path, edges, goalRooms, goal, initialCost)
  local rooms = roomMap(snapshot.rooms)
  local goalSet, score, spent = {}, 0, initialCost or {}
  for _, id in ipairs(goalRooms or {}) do goalSet[id] = true end
  for index = 2, #path do
    local room = rooms[path[index]]
    local door = edges and edges[index - 1]
      or Edges.best(rooms[path[index - 1]], path[index], Edges.context(snapshot, goal, spent))
    local cost = Edges.cost(door)
    score = score - Edges.weight(door)
    score = score - (cost.keys or 0) * 20
    score = score - (cost.bombs or 0) * 8
    score = score - (cost.coins or 0) * 0.25
    score = score - (cost.health or 0) * 15
    spent = Edges.addCost(spent, door)
    if not goalSet[path[index]] then
      if room.kind == "treasure" then score = score + 2 end
      if room.kind == "shop" then score = score + 1 end
      for _, pickup in ipairs(Visibility.filterPickups(room.pickups or {}, snapshot.visibility or {})) do
        score = score + (pickup.quality or 0) * 10
      end
    end
  end
  if goalSet[path[#path]] then score = score + 1000 end
  return score
end

local function candidates(snapshot, goal)
  local rooms, result, seen = roomMap(snapshot.rooms), {}, {}
  local function add(id)
    if not seen[id] and rooms[id] and visible(rooms[id], snapshot.visibility or {}) and id ~= snapshot.currentRoom then
      seen[id] = true; result[#result + 1] = id
    end
  end
  for _, id in ipairs(goal.destinationRooms or {}) do add(id) end
  for _, choice in ipairs(snapshot.visibleChoices or {}) do add(choice.roomId) end
  for _, room in ipairs(snapshot.rooms or {}) do
    if room.kind == "treasure" or room.kind == "shop" or room.kind == "arcade" then add(room.id) end
  end
  return result
end

local function valueLess(left, right)
  if type(left) == "number" and type(right) == "number" then return left < right end
  return tostring(left) < tostring(right)
end

local function stateBefore(left, right)
  if left.score ~= right.score then return left.score > right.score end
  if left.stops ~= right.stops then return left.stops < right.stops end
  if left.roomId ~= right.roomId then return valueLess(left.roomId, right.roomId) end
  local length = math.min(#left.nodes, #right.nodes)
  for index = 1, length do
    if left.nodes[index] ~= right.nodes[index] then return valueLess(left.nodes[index], right.nodes[index]) end
  end
  return #left.nodes < #right.nodes
end

function Search.beam(snapshot, goal, width, horizon)
  width, horizon = width or 12, horizon or 3
  local goalRooms, destinations = goal.destinationRooms or {}, candidates(snapshot, goal)
  local goalSet = {}
  for _, id in ipairs(goalRooms) do goalSet[id] = true end
  local beam = { { roomId = snapshot.currentRoom, nodes = { snapshot.currentRoom }, edges = {}, cost = {}, stops = 0, score = 0 } }
  local terminal = {}
  local retained = 0
  for _ = 1, horizon do
    local nextBeam = {}
    for _, state in ipairs(beam) do
      if goalSet[state.roomId] then
        terminal[#terminal + 1] = state
      else
        for _, destination in ipairs(destinations) do
          if destination ~= state.roomId then
            local path = Search.shortestPath(snapshot, state.roomId, destination, goal, state.cost)
            if path then
              local nodes = {}
              local edges = {}
              for _, node in ipairs(state.nodes) do nodes[#nodes + 1] = node end
              for index = 2, #path.nodes do nodes[#nodes + 1] = path.nodes[index] end
              for _, edge in ipairs(state.edges or {}) do edges[#edges + 1] = edge end
              for _, edge in ipairs(path.edges or {}) do edges[#edges + 1] = edge end
              nextBeam[#nextBeam + 1] = {
                roomId = destination,
                nodes = nodes,
                edges = edges,
                cost = path.cost,
                stops = state.stops + 1,
                score = state.score + pathScore(snapshot, path.nodes, path.edges, goalRooms, goal, state.cost)
              }
            end
          end
        end
      end
    end
    table.sort(nextBeam, stateBefore)
    beam = {}
    for index = 1, math.min(width, #nextBeam) do beam[index] = nextBeam[index] end
    retained = retained + #beam
    if #beam == 0 then break end
  end
  table.sort(terminal, stateBefore)
  local best = terminal[1]
  if not best then
    table.sort(beam, stateBefore)
    best = beam[1]
  end
  local candidates = #terminal > 0 and terminal or beam
  return best and { nodes = best.nodes, edges = best.edges, cost = best.cost, score = best.score, expanded = retained, candidates = candidates }
    or { nodes = {}, edges = {}, cost = {}, score = -math.huge, expanded = retained, candidates = {} }
end

return Search
