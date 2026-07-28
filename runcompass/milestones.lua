local Milestones = {}

local function copy(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, item in pairs(value) do result[key] = copy(item) end
  return result
end

local function addItem(result, name)
  result.requiredItems[name] = true
end

local function hasItem(snapshot, token)
  local inventory = snapshot and snapshot.player and snapshot.player.inventory or {}
  local items = inventory.questItems or inventory.items or {}
  return items[token] == true or items[token] == 1
end

function Milestones.compile(goal, snapshot)
  local result = {
    status = "ok",
    requiredResources = {},
    requiredItems = {},
    futureFloors = {},
    branches = {},
    timers = {},
    reasonCodes = {}
  }
  local id = goal and goal.id or ""
  local run = snapshot and snapshot.run or {}
  local elapsed = run.elapsedSeconds or snapshot and snapshot.timing and snapshot.timing.runFrame and snapshot.timing.runFrame / 30 or 0

  if id == "boss.hush" then
    result.timers.hushEntrance = 30 * 60
    if elapsed > result.timers.hushEntrance then
      result.status = "unreachable"
      result.reasonCodes.timer_missed = true
    end
  elseif id == "boss.delirium" then
    result.branches[#result.branches + 1] = "Hush portal (guaranteed after Hush)"
    result.branches[#result.branches + 1] = "Post-boss Void portal (probabilistic)"
    result.reasonCodes.portal_uncertainty = true
  elseif id == "boss.mega_satan" then
    addItem(result, "key_piece_1")
    addItem(result, "key_piece_2")
    if hasItem(snapshot, "key_piece_1") then result.requiredItems.key_piece_1 = nil end
    if hasItem(snapshot, "key_piece_2") then result.requiredItems.key_piece_2 = nil end
    result.branches[#result.branches + 1] = "Angel key pieces or a supported alternate door opener"
  elseif id == "boss.mother" then
    result.requiredResources.health = 2
    if snapshot and snapshot.player and snapshot.player.health and snapshot.player.health < 2 then
      result.status = "unreachable"
      result.reasonCodes.low_health = true
    end
    addItem(result, "knife_piece_1")
    addItem(result, "knife_piece_2")
    result.futureFloors[#result.futureFloors + 1] = "Downpour/Dross II mirror"
    result.futureFloors[#result.futureFloors + 1] = "Mines/Ashpit II chase"
    result.futureFloors[#result.futureFloors + 1] = "Mausoleum/Gehenna II flesh door"
    if snapshot and snapshot.player and snapshot.player.inventory and snapshot.player.inventory.knifeConsumed then
      result.status = "unreachable"
      result.reasonCodes.knife_consumed = true
    end
  elseif id == "boss.beast" then
    addItem(result, "photo")
    addItem(result, "dad_note")
    addItem(result, "fool_or_teleport")
    result.futureFloors[#result.futureFloors + 1] = "Depths II / Strange Door"
    result.futureFloors[#result.futureFloors + 1] = "Home / Dad's Note ascent"
    if snapshot and snapshot.player and snapshot.player.inventory and snapshot.player.inventory.photoChoice == "wrong" then
      result.status = "unreachable"
      result.reasonCodes.wrong_photo = true
    end
  elseif id == "boss.isaac" or id == "boss.blue_baby" or id == "boss.lamb" or id == "boss.satan" then
    addItem(result, id == "boss.satan" and "negative" or "polaroid")
  end

  if goal and goal.matchKinds and #goal.matchKinds > 0 and result.status == "ok" then
    result.matchKinds = copy(goal.matchKinds)
  end
  result.destinationRooms = copy(goal and goal.destinationRooms or {})
  return result
end

return Milestones
