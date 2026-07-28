local Visibility = {}

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
    end
    result[#result + 1] = copy
  end
  return result
end

return Visibility
