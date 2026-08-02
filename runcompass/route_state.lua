local RouteState = {}

local function copy(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, item in pairs(value) do result[key] = copy(item) end
  return result
end

local function currentRoom(snapshot)
  local currentId = snapshot and (snapshot.currentRoom or snapshot.floor and snapshot.floor.currentRoomId)
  for _, room in ipairs((snapshot and snapshot.rooms) or {}) do
    if room.id == currentId then return room end
  end
  return nil
end

function RouteState.fromInventory(collectibles, cards, env)
  collectibles, cards, env = collectibles or {}, cards or {}, env or {}
  local collectibleType = env.collectibleType or rawget(_G, "CollectibleType") or {}
  local cardType = env.cardType or rawget(_G, "Card") or {}
  local function held(id) return id ~= nil and (collectibles[id] or 0) > 0 end
  local cardSet = {}
  for _, card in ipairs(cards) do cardSet[card.id] = true end
  local function hasCard(id) return id ~= nil and cardSet[id] == true end

  local questItems = {
    key_piece_1 = held(collectibleType.COLLECTIBLE_KEY_PIECE_1),
    key_piece_2 = held(collectibleType.COLLECTIBLE_KEY_PIECE_2),
    knife_piece_1 = held(collectibleType.COLLECTIBLE_KNIFE_PIECE_1),
    knife_piece_2 = held(collectibleType.COLLECTIBLE_KNIFE_PIECE_2),
    polaroid = held(collectibleType.COLLECTIBLE_POLAROID),
    negative = held(collectibleType.COLLECTIBLE_NEGATIVE),
    moms_shovel = held(collectibleType.COLLECTIBLE_MOMS_SHOVEL),
    dad_note = held(collectibleType.COLLECTIBLE_DADS_NOTE),
    photo = held(collectibleType.COLLECTIBLE_DADS_NOTE_PHOTO or collectibleType.COLLECTIBLE_POLAROID_PHOTO)
  }
  local routeCards = {
    fool = hasCard(cardType.CARD_FOOL),
    teleport = hasCard(cardType.CARD_TELEPORT),
    emperor = hasCard(cardType.CARD_EMPEROR),
    moon = hasCard(cardType.CARD_MOON)
  }
  return {
    questItems = questItems,
    routeCards = routeCards,
    alternateOpeners = {
      dads_key = held(collectibleType.COLLECTIBLE_DADS_KEY),
      moms_shovel = questItems.moms_shovel
    }
  }
end

function RouteState.fromSnapshot(snapshot)
  snapshot = snapshot or {}
  local floor = snapshot.floor or {}
  local run = snapshot.run or {}
  local inventory = snapshot.player and snapshot.player.inventory or {}
  local questItems = inventory.questItems or inventory.items or {}
  local state = {
    stage = floor.stage,
    stageType = floor.stageType,
    branch = inventory.branch,
    questPieces = copy(questItems),
    photoChoice = inventory.photoChoice,
    routeCards = copy(inventory.routeCards or {}),
    consumedPieces = copy(inventory.consumedPieces or {}),
    alternateOpeners = copy(inventory.alternateOpeners or {}),
    timers = { elapsed = run.elapsedSeconds or 0, hushDeadline = 30 * 60 },
    visibleSpecialDoors = {}
  }
  local room = currentRoom(snapshot)
  for _, door in ipairs((room and room.doors) or {}) do
    if door.kind == "special" or (door.cost and door.cost.unknown) then
      state.visibleSpecialDoors[#state.visibleSpecialDoors + 1] = {
        slot = door.slot,
        kind = door.kind or "unknown",
        cost = copy(door.cost or {}),
        confidence = door.confidence or "low"
      }
    end
  end
  return state
end

return RouteState
