local GameAdapter = {}
GameAdapter.__index = GameAdapter

local function safe(default, callback)
  if type(callback) ~= "function" then return default end
  local ok, value = pcall(callback)
  if ok and value ~= nil then return value end
  return default
end

local function values(container)
  local result = {}
  if type(container) == "table" then
    for _, value in pairs(container) do result[#result + 1] = value end
    return result
  end
  local misses = 0
  for index = 0, 2048 do
    local value = container[index]
    if value ~= nil then result[#result + 1] = value; misses = 0 else misses = misses + 1 end
    if #result > 0 and misses > 32 then break end
  end
  return result
end

function GameAdapter.new(env)
  return setmetatable({ env = env }, GameAdapter)
end

function GameAdapter:roomKind(dataType, variant, currentRoom)
  local roomType = self.env.roomType or rawget(_G, "RoomType") or {}
  local kinds = {}
  local function addKind(constant, name) if constant ~= nil then kinds[constant] = name end end
  addKind(roomType.ROOM_TREASURE, "treasure")
  addKind(roomType.ROOM_SHOP, "shop")
  addKind(roomType.ROOM_ARCADE, "arcade")
  addKind(roomType.ROOM_SACRIFICE, "sacrifice")
  addKind(roomType.ROOM_CURSE, "curse")
  addKind(roomType.ROOM_CHALLENGE, "challenge")
  addKind(roomType.ROOM_BOSS, "boss")
  addKind(roomType.ROOM_SECRET, "secret")
  addKind(roomType.ROOM_SUPERSECRET, "secret")
  if currentRoom and currentRoom.GetBossID then
    local boss = safe(nil, function() return currentRoom:GetBossID() end)
    if boss ~= nil then
      local bossType = self.env.bossType or rawget(_G, "BossId") or {}
      if boss == bossType.DELIRIUM then return "delirium" end
      if boss == bossType.HUSH then return "hush" end
      if boss == bossType.MOTHER then return "mother" end
      if boss == bossType.THE_BEAST or boss == bossType.BEAST then return "beast" end
      if boss == bossType.MEGA_SATAN then return "mega_satan" end
    end
  end
  return kinds[dataType] or "normal"
end

function GameAdapter:collectItems(itemConfig)
  local result = {}
  local collectibleType = self.env.collectibleType or rawget(_G, "CollectibleType") or {}
  local max = collectibleType.NUM_COLLECTIBLES or 733
  for id = 1, max - 1 do
    local item = safe(nil, function() return itemConfig:GetCollectible(id) end)
    if item then result[#result + 1] = { id = id, name = item.Name, achievementId = item.AchievementID, quality = item.Quality, tags = item.Tags } end
  end
  return result
end

function GameAdapter:detectCurrentBossKind()
  local isaac = self.env.isaac or rawget(_G, "Isaac")
  local entityType = self.env.entityType or rawget(_G, "EntityType") or {}
  local kinds = {
    { entityType.ENTITY_DELIRIUM, "delirium" },
    { entityType.ENTITY_HUSH, "hush" },
    { entityType.ENTITY_MOTHER, "mother" },
    { entityType.ENTITY_BEAST, "beast" },
    { entityType.ENTITY_MEGA_SATAN, "mega_satan" }
  }
  if not isaac or not isaac.FindByType then return nil end
  for _, pair in ipairs(kinds) do
    if pair[1] ~= nil and #values(safe({}, function() return isaac.FindByType(pair[1], -1, -1, false, false) end)) > 0 then return pair[2] end
  end
  return nil
end

function GameAdapter:buildRooms(level, currentIndex, currentRoom, visibility)
  local descriptors = values(safe({}, function() return level:GetRooms() end))
  local rooms, bySafe = {}, {}
  for index, desc in ipairs(descriptors) do
    local id = desc.ListIndex or desc.GridIndex or index
    local safeGrid = desc.SafeGridIndex or desc.GridIndex
    local visited = (desc.VisitedCount or 0) > 0 or id == currentIndex
    local displayFlags = desc.DisplayFlags or 0
    local room = {
      id = id,
      safeGridIndex = safeGrid,
      visited = visited,
      hidden = not visited and displayFlags == 0,
      clear = false,
      kind = self:roomKind(desc.Data and desc.Data.Type, desc.Data and desc.Data.Variant, id == currentIndex and currentRoom or nil),
      doors = {},
      pickups = {}
    }
    rooms[#rooms + 1] = room
    if safeGrid and safeGrid >= 0 then bySafe[safeGrid] = id end
  end
  local directions = { { slot = 0, delta = -1 }, { slot = 1, delta = -13 }, { slot = 2, delta = 1 }, { slot = 3, delta = 13 } }
  for _, room in ipairs(rooms) do
    if room.safeGridIndex and room.safeGridIndex >= 0 then
      for _, direction in ipairs(directions) do
        local target = bySafe[room.safeGridIndex + direction.delta]
        if target then room.doors[#room.doors + 1] = { slot = direction.slot, to = target } end
      end
    end
  end
  if currentRoom and currentRoom.GetDoor then
    local current = nil
    for _, room in ipairs(rooms) do if room.id == currentIndex then current = room end end
    if current then
      current.doors = {}
      for slot = 0, 7 do
        local door = safe(nil, function() return currentRoom:GetDoor(slot) end)
        local target = door and safe(nil, function() return door.TargetRoomIndex end)
        if door and target and target >= 0 then current.doors[#current.doors + 1] = { slot = slot, to = target } end
      end
    end
  end
  return rooms
end

function GameAdapter:build()
  local env, game = self.env, self.env.game
  local level = safe(nil, function() return game:GetLevel() end)
  local currentIndex = safe(0, function() return level:GetCurrentRoomIndex() end)
  local currentRoom = safe(nil, function() return level:GetCurrentRoom() end)
  local curses = safe(0, function() return level:GetCurses() end)
  local levelCurse = env.levelCurse or rawget(_G, "LevelCurse") or {}
  local visibility = {
    curseBlind = levelCurse.CURSE_OF_BLIND and (curses & levelCurse.CURSE_OF_BLIND) ~= 0 or false,
    curseLost = levelCurse.CURSE_OF_THE_LOST and (curses & levelCurse.CURSE_OF_THE_LOST) ~= 0 or false
  }
  local players = {}
  local count = safe(1, function() return game:GetNumPlayers() end)
  for index = 0, count - 1 do
    local player = safe(nil, function() return game:GetPlayer(index) end)
    if player then
      players[#players + 1] = {
        health = (player:GetHearts() or 0) + (player:GetSoulHearts() or 0) + (player:GetBlackHearts() or 0),
        maxHealth = player:GetMaxHearts(),
        keys = player:GetNumKeys(), bombs = player:GetNumBombs(), coins = player:GetNumCoins(),
        power = player.Damage or 0, playerType = player:GetPlayerType()
      }
    end
  end
  local difficulty = rawget(_G, "Difficulty") or {}
  local hard = difficulty.DIFFICULTY_HARD and game.Difficulty == difficulty.DIFFICULTY_HARD
  local mode = { kind = safe(false, function() return game:IsGreedMode() end) and "greed" or "normal", difficulty = hard and "hard" or "normal", coOp = count > 1, progressionAllowed = true }
  if (game.Challenge or 0) > 0 then mode.kind = "challenge"; mode.progressionAllowed = false end
  local seeds = safe(nil, function() return game:GetSeeds() end)
  if seeds and seeds.IsCustomRun and safe(false, function() return seeds:IsCustomRun() end) then mode.progressionAllowed = false end
  local rooms = self:buildRooms(level, currentIndex, currentRoom, visibility)
  local currentBossKind = self:detectCurrentBossKind()
  local currentClear = safe(false, function() return currentRoom:IsClear() end)
  for _, room in ipairs(rooms) do
    if room.id == currentIndex then
      room.clear = currentClear
      if currentBossKind then room.kind = currentBossKind end
    end
  end
  local pickups = {}
  local isaac = env.isaac or rawget(_G, "Isaac")
  if isaac and isaac.FindByType then
    local entityType = self.env.entityType or rawget(_G, "EntityType") or {}
    local pickupVariant = self.env.pickupVariant or rawget(_G, "PickupVariant") or {}
    for _, pickup in ipairs(values(safe({}, function() return isaac.FindByType(entityType.ENTITY_PICKUP, -1, -1, false, false) end))) do
      local quality
      if not visibility.curseBlind and pickup.Variant == pickupVariant.PICKUP_COLLECTIBLE and self.env.itemConfig and self.env.itemConfig.GetCollectible then
        local item = safe(nil, function() return self.env.itemConfig:GetCollectible(pickup.SubType) end)
        quality = item and item.Quality
      end
      pickups[#pickups + 1] = { variant = pickup.Variant, subtype = pickup.SubType, visible = not visibility.curseBlind, quality = quality }
    end
  end
  return {
    currentRoom = currentIndex,
    currentRoomClear = currentClear,
    mode = mode,
    visibility = visibility,
    player = players[1] or {},
    rooms = rooms,
    observations = { pickups = pickups },
    timing = { frame = safe(0, function() return currentRoom:GetFrameCount() end) }
  }
end

return GameAdapter
