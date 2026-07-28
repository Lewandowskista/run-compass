local Visibility = {}

local function clone(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, item in pairs(value) do result[key] = clone(item) end
  return result
end

function Visibility.filterRooms(rooms, flags)
  flags = flags or {}
  local result = {}
  for _, room in ipairs(rooms or {}) do
    local visible = not room.hidden and not room.secret
    if flags.curseLost and not room.visited then visible = false end
    if visible then result[room.id] = room end
  end
  return result
end

function Visibility.filterPickups(pickups, flags)
  flags = flags or {}
  local result = {}
  for _, pickup in ipairs(pickups or {}) do
    local copy = {}
    for key, value in pairs(pickup) do copy[key] = value end
    if flags.curseBlind then
      copy.visible = false
      copy.quality = nil
      copy.id = nil
      copy.subtype = nil
      copy.name = nil
      copy.tags = nil
    end
    result[#result + 1] = copy
  end
  return result
end

function Visibility.sanitizeSnapshot(snapshot)
  snapshot = clone(snapshot or {})
  local flags = snapshot.visibility or {}
  local visibleRooms, roomIds = {}, {}
  for _, room in ipairs(snapshot.rooms or {}) do
    local secret = room.secret or room.superSecret or room.kind == "secret"
    local visible = not room.hidden and not secret
    if flags.curseLost and not room.visited then visible = false end
    if visible then
      roomIds[room.id] = true
      visibleRooms[#visibleRooms + 1] = room
    end
  end
  for _, room in ipairs(visibleRooms) do
    local doors = {}
    for _, door in ipairs(room.doors or {}) do
      if door.to ~= nil and roomIds[door.to] then doors[#doors + 1] = door end
    end
    room.doors = doors
    room.pickups = Visibility.filterPickups(room.pickups or {}, flags)
  end
  snapshot.rooms = visibleRooms
  if snapshot.floor then snapshot.floor.rooms = visibleRooms end
  snapshot.observations = snapshot.observations or {}
  local observationRooms = {}
  for roomId, observation in pairs(snapshot.observations.rooms or {}) do
    if roomIds[roomId] then
      local copy = clone(observation)
      copy.pickups = Visibility.filterPickups(copy.pickups or {}, flags)
      observationRooms[roomId] = copy
    end
  end
  snapshot.observations.rooms = observationRooms
  snapshot.observations.pickups = Visibility.filterPickups(snapshot.observations.pickups or {}, flags)
  local choices = {}
  for _, choice in ipairs(snapshot.visibleChoices or {}) do
    if roomIds[choice.roomId] then
      if flags.curseBlind then
        choice.observedIdentity = nil
        choice.confidence = "low"
      end
      choices[#choices + 1] = choice
    end
  end
  snapshot.visibleChoices = choices
  return snapshot
end

function Visibility.assertFairSnapshot(snapshot)
  local roomIds = {}
  for _, room in ipairs(snapshot.rooms or {}) do
    if room.hidden or room.secret or room.superSecret or room.kind == "secret" then
      return false, "forbidden room reached planner"
    end
    roomIds[room.id] = true
  end
  for _, room in ipairs(snapshot.rooms or {}) do
    for _, door in ipairs(room.doors or {}) do
      if not roomIds[door.to] then return false, "invalid topology reached planner" end
    end
  end
  if snapshot.visibility and snapshot.visibility.curseBlind then
    local function check(pickups)
      for _, pickup in ipairs(pickups or {}) do
        if pickup.subtype or pickup.quality or pickup.name or pickup.tags or pickup.id then return false end
      end
      return true
    end
    if not check(snapshot.observations and snapshot.observations.pickups) then return false, "Blind identity reached planner" end
    for _, observation in pairs(snapshot.observations and snapshot.observations.rooms or {}) do
      if not check(observation.pickups) then return false, "Blind identity reached planner" end
    end
    for _, choice in ipairs(snapshot.visibleChoices or {}) do
      if choice.observedIdentity then return false, "Blind choice identity reached planner" end
    end
  end
  return true
end

return Visibility
