local Goals = {}

local BOSS_DEFINITIONS = {
  { id = "boss.mom", name = "Mom", kind = "boss", matcher = function(room) return room.kind == "mom" end },
  { id = "boss.mom_heart", name = "Mom's Heart / It Lives", kind = "boss", matcher = function(room) return room.kind == "mom_heart" end },
  { id = "boss.isaac", name = "Isaac", kind = "boss", matcher = function(room) return room.kind == "isaac" end },
  { id = "boss.satan", name = "Satan", kind = "boss", matcher = function(room) return room.kind == "satan" end },
  { id = "boss.blue_baby", name = " ??? ", kind = "boss", matcher = function(room) return room.kind == "blue_baby" end },
  { id = "boss.lamb", name = "The Lamb", kind = "boss", matcher = function(room) return room.kind == "lamb" end },
  { id = "boss.mega_satan", name = "Mega Satan", kind = "boss", matcher = function(room) return room.kind == "mega_satan" end },
  { id = "boss.hush", name = "Hush", kind = "boss", matcher = function(room) return room.kind == "hush" end, timers = { { name = "Hush entrance", seconds = 30 * 60 } } },
  { id = "boss.delirium", name = "Delirium", kind = "boss", matcher = function(room) return room.kind == "delirium" or room.kind == "void" end },
  { id = "boss.mother", name = "Mother", kind = "boss", matcher = function(room) return room.kind == "mother" end },
  { id = "boss.beast", name = "The Beast", kind = "boss", matcher = function(room) return room.kind == "beast" end }
}

function Goals.bosses()
  local result = {}
  for _, definition in ipairs(BOSS_DEFINITIONS) do
    local copy = {}
    for key, value in pairs(definition) do copy[key] = value end
    result[#result + 1] = copy
  end
  return result
end

function Goals.resolve(selected, snapshot)
  local resolved = {}
  for key, value in pairs(selected or {}) do resolved[key] = value end
  if resolved.status == "catalog_update_required" then
    resolved.status = "instructional"
    resolved.frontier = false
    resolved.destinationRooms = {}
    return resolved
  end
  if resolved.status == "already_unlocked" then
    resolved.status = "complete"
    resolved.frontier = false
    resolved.destinationRooms = {}
    return resolved
  end
  if resolved.destinationRooms then return resolved end
  for _, definition in ipairs(BOSS_DEFINITIONS) do
    if definition.id == resolved.id then
      for key, value in pairs(definition) do resolved[key] = value end
      break
    end
  end
  resolved.destinationRooms = {}
  if resolved.matcher then
    for _, room in ipairs(snapshot.rooms or {}) do
      if resolved.matcher(room) then resolved.destinationRooms[#resolved.destinationRooms + 1] = room.id end
    end
  end
  if #resolved.destinationRooms == 0 then
    resolved.frontier = true
    resolved.status = resolved.status or "milestone"
  end
  return resolved
end

return Goals
