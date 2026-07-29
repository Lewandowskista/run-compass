local Search = {}
local Visibility = require("runcompass.visibility")

local function roomMap(rooms)
  local result = {}
  for _, room in ipairs(rooms or {}) do result[room.id] = room end
  return result
end

local function visible(room, flags)
  return room and not room.hidden and not room.secret and not (flags.curseLost and not room.visited)
end

local function edgeCost(door)
  local cost = 1
  for resource, amount in pairs(door and door.cost or {}) do
    if resource == "unknown" and amount then
      cost = cost + 1000
    elseif type(amount) == "number" then
      cost = cost + amount * 0.01
    end
  end
  return cost
end

local function traversedEdge(rooms, from, to)
  for _, door in ipairs(rooms[from] and rooms[from].doors or {}) do
    if door.to == to then return door end
  end
end

function Search.shortestPath(snapshot, start, destination)
  local rooms = roomMap(snapshot.rooms)
  if not rooms[start] or not rooms[destination] then return nil end
  local flags = snapshot.visibility or {}
  local distance, previous, open, head = { [start] = 0 }, {}, { start }, 1
  while head <= #open do
    local bestNode = open[head]; head = head + 1
    if bestNode == destination then break end
    for _, door in ipairs(rooms[bestNode].doors or {}) do
      local nextRoom = rooms[door.to]
      if visible(nextRoom, flags) then
        local nextDistance = distance[bestNode] + edgeCost(door)
        if distance[door.to] == nil or nextDistance < distance[door.to] then
          distance[door.to] = nextDistance
          previous[door.to] = bestNode
          open[#open + 1] = door.to
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
    local door = traversedEdge(rooms, path[index - 1], path[index])
    local cost = door and door.cost or {}
    score = score - edgeCost(door)
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
    table.sort(nextBeam, function(left, right) return left.score > right.score end)
    beam = {}
    for index = 1, math.min(width, #nextBeam) do beam[index] = nextBeam[index] end
    retained = retained + #beam
    if #beam == 0 then break end
  end
  table.sort(terminal, function(left, right) return left.score > right.score end)
  local best = terminal[1]
  if not best then
    table.sort(beam, function(left, right) return left.score > right.score end)
    best = beam[1]
  end
  local candidates = #terminal > 0 and terminal or beam
  return best and { nodes = best.nodes, score = best.score, expanded = retained, candidates = candidates } or { nodes = {}, score = -math.huge, expanded = retained, candidates = {} }
end

return Search
