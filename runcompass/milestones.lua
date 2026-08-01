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
  local routeState = snapshot and snapshot.routeState or {}
  if routeState.questPieces and (routeState.questPieces[token] == true or routeState.questPieces[token] == 1) then return true end
  local inventory = snapshot and snapshot.player and snapshot.player.inventory or {}
  local items = inventory.questItems or inventory.items or {}
  return items[token] == true or items[token] == 1
end

local function consumed(snapshot, token)
  local routeState = snapshot and snapshot.routeState or {}
  local consumedPieces = routeState.consumedPieces or {}
  local inventory = snapshot and snapshot.player and snapshot.player.inventory or {}
  return consumedPieces[token] == true or consumedPieces[token] == 1 or inventory[token .. "Consumed"] == true
end

local function hasAlternateOpener(snapshot)
  local openers = snapshot and snapshot.routeState and snapshot.routeState.alternateOpeners or {}
  for _, value in pairs(openers) do if value == true or value == 1 then return true end end
  return false
end

local function alternateOpener(snapshot)
  local openers = snapshot and snapshot.routeState and snapshot.routeState.alternateOpeners or {}
  for key, value in pairs(openers) do
    if value == true or value == 1 then return key end
  end
  return nil
end

local function hasRouteCard(snapshot, token)
  local cards = snapshot and snapshot.routeState and snapshot.routeState.routeCards or {}
  return cards[token] == true or cards[token] == 1
end

local function photoChoice(snapshot)
  if snapshot and snapshot.routeState and snapshot.routeState.photoChoice ~= nil then return snapshot.routeState.photoChoice end
  return snapshot and snapshot.player and snapshot.player.inventory and snapshot.player.inventory.photoChoice
end

local function nextMissingItem(result, ordered)
  for _, item in ipairs(ordered) do
    if result.requiredItems[item] then return item end
  end
  return nil
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
      result.nextAction = { type = "ROUTE_UNAVAILABLE", deadline = result.timers.hushEntrance, confidence = "high" }
    end
  elseif id == "boss.delirium" then
    result.branches[#result.branches + 1] = "Hush portal (guaranteed after Hush)"
    result.reasonCodes.observed_portal_required = true
  elseif id == "boss.mega_satan" then
    addItem(result, "key_piece_1")
    addItem(result, "key_piece_2")
    local opener = alternateOpener(snapshot)
    if opener ~= nil or hasAlternateOpener(snapshot) then
      result.requiredItems.key_piece_1 = nil
      result.requiredItems.key_piece_2 = nil
      result.reasonCodes.alternate_opener_observed = true
      result.nextAction = { type = "USE_OPENER", targetId = opener, confidence = "medium" }
    end
    if consumed(snapshot, "key_piece_1") or consumed(snapshot, "key_piece_2") then
      result.status = "unreachable"
      result.reasonCodes.key_piece_consumed = true
      result.nextAction = { type = "ROUTE_UNAVAILABLE", confidence = "high" }
    end
    if hasItem(snapshot, "key_piece_1") then result.requiredItems.key_piece_1 = nil end
    if hasItem(snapshot, "key_piece_2") then result.requiredItems.key_piece_2 = nil end
    local missing = nextMissingItem(result, { "key_piece_1", "key_piece_2" })
    if missing and not result.nextAction then
      result.nextAction = { type = "COLLECT_QUEST_ITEM", targetId = missing, reserve = copy(result.requiredResources), confidence = "medium" }
    end
    result.branches[#result.branches + 1] = "Angel key pieces or a supported alternate door opener"
  elseif id == "boss.mother" then
    result.requiredResources.health = 2
    if snapshot and snapshot.player and snapshot.player.health and snapshot.player.health < 2 then
      result.status = "unreachable"
      result.reasonCodes.low_health = true
      result.nextAction = { type = "PRESERVE_RESOURCE", cost = copy(result.requiredResources), reserve = copy(result.requiredResources), confidence = "high" }
    end
    addItem(result, "knife_piece_1")
    addItem(result, "knife_piece_2")
    if hasItem(snapshot, "knife_piece_1") then result.requiredItems.knife_piece_1 = nil end
    if hasItem(snapshot, "knife_piece_2") then result.requiredItems.knife_piece_2 = nil end
    local missing = nextMissingItem(result, { "knife_piece_1", "knife_piece_2" })
    if missing and not result.nextAction then
      result.nextAction = { type = "COLLECT_QUEST_ITEM", targetId = missing, reserve = copy(result.requiredResources), confidence = "medium" }
    end
    result.futureFloors[#result.futureFloors + 1] = "Downpour/Dross II mirror"
    result.futureFloors[#result.futureFloors + 1] = "Mines/Ashpit II chase"
    result.futureFloors[#result.futureFloors + 1] = "Mausoleum/Gehenna II flesh door"
    if consumed(snapshot, "knife") or consumed(snapshot, "knife_piece_1") or consumed(snapshot, "knife_piece_2") then
      result.status = "unreachable"
      result.reasonCodes.knife_consumed = true
      result.nextAction = { type = "ROUTE_UNAVAILABLE", confidence = "high" }
    end
  elseif id == "boss.beast" then
    addItem(result, "photo")
    addItem(result, "dad_note")
    addItem(result, "fool_or_teleport")
    if hasItem(snapshot, "photo") then result.requiredItems.photo = nil end
    if hasItem(snapshot, "dad_note") then result.requiredItems.dad_note = nil end
    if hasRouteCard(snapshot, "fool") or hasRouteCard(snapshot, "teleport") then result.requiredItems.fool_or_teleport = nil end
    local missing = nextMissingItem(result, { "photo", "fool_or_teleport", "dad_note" })
    if missing then
      result.nextAction = { type = "COLLECT_QUEST_ITEM", targetId = missing, reserve = copy(result.requiredResources), confidence = "medium" }
    else
      result.nextAction = { type = "RETURN_TO_ROOM", targetId = "ascent", reserve = copy(result.requiredResources), confidence = "medium" }
    end
    result.futureFloors[#result.futureFloors + 1] = "Depths II / Strange Door"
    result.futureFloors[#result.futureFloors + 1] = "Home / Dad's Note ascent"
    if photoChoice(snapshot) == "wrong" then
      result.status = "unreachable"
      result.reasonCodes.wrong_photo = true
      result.nextAction = { type = "ROUTE_UNAVAILABLE", confidence = "high" }
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
