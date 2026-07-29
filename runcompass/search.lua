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

function Search.shortestPath(snapshot, start, destination)
  local rooms = roomMap(snapshot.rooms)
  if not rooms[start] or not rooms[destination] then return nil end
  local flags = snapshot.visibility or {}
  local distance, previous = { [start] = 0 }, {}
  local open, inOpen, settled = { start }, { [start] = true }, {}
  while #open > 0 do
    local bestIndex = 1
    for index = 2, #open do
      if distance[open[index]] < distance[open[bestIndex]] then bestIndex = index end
    end
    local bestNode = table.remove(open, bestIndex)
    inOpen[bestNode] = nil
    settled[bestNode] = true
    if bestNode == destination then break end
    for _, door in ipairs(Edges.bestDoors(rooms[bestNode])) do
      local nextRoom = rooms[door.to]
      if not settled[door.to] and visible(nextRoom, flags) then
        local nextDistance = distance[bestNode] + Edges.weight(door)
        if distance[door.to] == nil or nextDistance < distance[door.to] then
          distance[door.to] = nextDistance
          previous[door.to] = bestNode
          if not inOpen[door.to] then
            open[#open + 1] = door.to
            inOpen[door.to] = true
          end
        end
      end
    end
  end
  if distance[destination] == nil then return nil end
  local nodes, current = {}, destination
  while current do
    table.insert(nodes, 1, current)
    current = previous[current]
  end
  return { nodes = nodes, distance = distance[destination] }
end

local function pathScore(snapshot, path, goalRooms)
  local rooms = roomMap(snapshot.rooms)
  local goalSet, score = {}, 0
  for _, id in ipairs(goalRooms or {}) do goalSet[id] = true end
  for index = 2, #path do
    local room = rooms[path[index]]
    local door = Edges.best(rooms[path[index - 1]], path[index])
    local cost = Edges.cost(door)
    score = score - Edges.weight(door)
    score = score - (cost.keys or 0) * 20
    score = score - (cost.bombs or 0) * 8
    score = score - (cost.coins or 0) * 0.25
    score = score - (cost.health or 0) * 15
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
  local beam = { { roomId = snapshot.currentRoom, nodes = { snapshot.currentRoom }, stops = 0, score = 0 } }
  local pathCache = {}
  local function cachedPath(start, destination)
    pathCache[start] = pathCache[start] or {}
    if pathCache[start][destination] == false then return nil end
    if pathCache[start][destination] then return pathCache[start][destination] end
    local path = Search.shortestPath(snapshot, start, destination)
    pathCache[start][destination] = path or false
    return path
  end
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
            local path = cachedPath(state.roomId, destination)
            if path then
              local nodes = {}
              for _, node in ipairs(state.nodes) do nodes[#nodes + 1] = node end
              for index = 2, #path.nodes do nodes[#nodes + 1] = path.nodes[index] end
              nextBeam[#nextBeam + 1] = {
                roomId = destination,
                nodes = nodes,
                stops = state.stops + 1,
                score = state.score + pathScore(snapshot, path.nodes, goalRooms)
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
  return best and { nodes = best.nodes, score = best.score, expanded = retained, candidates = candidates } or { nodes = {}, score = -math.huge, expanded = retained, candidates = {} }
end

return Search
