local GameAdapter = {}
GameAdapter.__index = GameAdapter
local Visibility = require("runcompass.visibility")
local BuildState = require("runcompass.build_state")

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
  return setmetatable({ env = env, observationRooms = {}, observationChoices = {}, floorToken = nil }, GameAdapter)
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
      local bossType = self.env.bossType or rawget(_G, "BossID") or rawget(_G, "BossId") or {}
      if boss == bossType.MOM then return "mom" end
      if boss == bossType.MOMS_HEART or boss == bossType.MOM_HEART then return "mom_heart" end
      if boss == bossType.ISAAC then return "isaac" end
      if boss == bossType.SATAN then return "satan" end
      if boss == bossType.BLUE_BABY then return "blue_baby" end
      if boss == bossType.LAMB then return "lamb" end
      if boss == bossType.BEAST then return "beast" end
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

function GameAdapter:collectConfigured(kind, max)
  local itemConfig = self.env.itemConfig
  if not itemConfig then return {} end
  local getterName = kind == "trinket" and "GetTrinket" or kind == "card" and "GetCard" or "GetPillEffect"
  local getter = itemConfig[getterName]
  if type(getter) ~= "function" then return {} end
  local result = {}
  for id = 0, (tonumber(max) or 0) - 1 do
    local item = safe(nil, function() return getter(itemConfig, id) end)
    if item then result[#result + 1] = { id = id, kind = kind, name = item.Name, quality = item.Quality, tags = item.Tags } end
  end
  return result
end

function GameAdapter:buildPlayer(player)
  local playerTypes = self.env.playerType or rawget(_G, "PlayerType") or {}
  local characterTokens = {}
  local function addCharacter(constant, token) if constant ~= nil then characterTokens[constant] = token end end
  addCharacter(playerTypes.PLAYER_ISAAC, "isaac"); addCharacter(playerTypes.PLAYER_MAGDALENA, "magdalene")
  addCharacter(playerTypes.PLAYER_CAIN, "cain"); addCharacter(playerTypes.PLAYER_JUDAS, "judas")
  addCharacter(playerTypes.PLAYER_BLUEBABY, "blue_baby"); addCharacter(playerTypes.PLAYER_EVE, "eve")
  addCharacter(playerTypes.PLAYER_SAMSON, "samson"); addCharacter(playerTypes.PLAYER_AZAZEL, "azazel")
  addCharacter(playerTypes.PLAYER_LAZARUS, "lazarus"); addCharacter(playerTypes.PLAYER_EDEN, "eden")
  addCharacter(playerTypes.PLAYER_THELOST, "the_lost"); addCharacter(playerTypes.PLAYER_LILITH, "lilith")
  addCharacter(playerTypes.PLAYER_KEEPER, "keeper"); addCharacter(playerTypes.PLAYER_APOLLYON, "apollyon")
  addCharacter(playerTypes.PLAYER_THEFORGOTTEN, "the_forgotten"); addCharacter(playerTypes.PLAYER_BETHANY, "bethany")
  addCharacter(playerTypes.PLAYER_JACOB, "jacob_and_esau"); addCharacter(playerTypes.PLAYER_ESAU, "jacob_and_esau")
  addCharacter(playerTypes.PLAYER_ISAAC_B, "tainted_isaac"); addCharacter(playerTypes.PLAYER_MAGDALENA_B, "tainted_magdalene")
  addCharacter(playerTypes.PLAYER_CAIN_B, "tainted_cain"); addCharacter(playerTypes.PLAYER_JUDAS_B, "tainted_judas")
  addCharacter(playerTypes.PLAYER_BLUEBABY_B, "tainted_blue_baby"); addCharacter(playerTypes.PLAYER_EVE_B, "tainted_eve")
  addCharacter(playerTypes.PLAYER_SAMSON_B, "tainted_samson"); addCharacter(playerTypes.PLAYER_AZAZEL_B, "tainted_azazel")
  addCharacter(playerTypes.PLAYER_LAZARUS_B, "tainted_lazarus"); addCharacter(playerTypes.PLAYER_EDEN_B, "tainted_eden")
  addCharacter(playerTypes.PLAYER_THELOST_B, "tainted_lost"); addCharacter(playerTypes.PLAYER_LILITH_B, "tainted_lilith")
  addCharacter(playerTypes.PLAYER_KEEPER_B, "tainted_keeper"); addCharacter(playerTypes.PLAYER_APOLLYON_B, "tainted_apollyon")
  addCharacter(playerTypes.PLAYER_THEFORGOTTEN_B, "tainted_forgotten"); addCharacter(playerTypes.PLAYER_BETHANY_B, "tainted_bethany")
  addCharacter(playerTypes.PLAYER_JACOB_B, "tainted_jacob")
  local function invoke(default, method, ...)
    if type(player[method]) ~= "function" then return default end
    local ok, value = pcall(player[method], player, ...)
    return ok and value ~= nil and value or default
  end
  local playerType = invoke(nil, "GetPlayerType")
  local collectibles, collectibleType = {}, self.env.collectibleType or rawget(_G, "CollectibleType") or {}
  for id = 1, (collectibleType.NUM_COLLECTIBLES or 733) - 1 do
    local count = invoke(0, "GetCollectibleNum", id, true)
    if count and count > 0 then collectibles[id] = count end
  end
  local actives, trinkets, cards, pills = {}, {}, {}, {}
  for slot = 0, 3 do
    local active = invoke(0, "GetActiveItem", slot)
    if active and active > 0 then actives[#actives + 1] = { id = active, slot = slot, charge = invoke(0, "GetActiveCharge", slot), batteryCharge = invoke(0, "GetBatteryCharge", slot) } end
    local card = invoke(0, "GetCard", slot)
    if card and card > 0 then cards[#cards + 1] = { id = card, slot = slot, identified = true } end
    local pill = invoke(0, "GetPill", slot)
    if pill and pill > 0 then
      local identified, effect = false, nil
      local itemPool = self.env.itemPool
      if itemPool and type(itemPool.IsPillIdentified) == "function" then
        local ok, value = pcall(itemPool.IsPillIdentified, itemPool, pill)
        identified = ok and value == true
        if identified and type(itemPool.GetPillEffect) == "function" then local effectOk, effectValue = pcall(itemPool.GetPillEffect, itemPool, pill, player); if effectOk then effect = effectValue end end
      end
      pills[#pills + 1] = { color = pill, slot = slot, identified = identified, effect = effect }
    end
  end
  local trinketType = self.env.trinketType or rawget(_G, "TrinketType") or {}
  local goldenFlag = tonumber(self.env.goldenTrinketFlag or trinketType.TRINKET_GOLDEN_FLAG)
  local function normalizeTrinket(raw)
    raw = tonumber(raw) or 0
    if raw <= 0 then return nil end
    local golden = false
    if goldenFlag and goldenFlag > 0 and math.floor(raw / goldenFlag) % 2 == 1 then
      golden = true
      raw = raw - goldenFlag
    end
    return raw, golden
  end
  for slot = 0, 1 do
    local rawTrinket = invoke(0, "GetTrinket", slot)
    local trinket, golden = normalizeTrinket(rawTrinket)
    if trinket and trinket > 0 then
      trinkets[#trinkets + 1] = { id = trinket, rawId = rawTrinket, slot = slot, multiplier = invoke(1, "GetTrinketMultiplier", trinket), golden = golden, smelted = false }
    end
  end
  local smelted = invoke(nil, "GetSmeltedTrinkets")
  if type(smelted) == "table" then
    for _, rawTrinket in pairs(smelted) do
      local trinket, golden = normalizeTrinket(rawTrinket)
      if trinket and trinket > 0 then trinkets[#trinkets + 1] = { id = trinket, rawId = rawTrinket, slot = "smelted", multiplier = 1, golden = golden, smelted = true } end
    end
  end
  local transformations = {}
  local playerForm = self.env.playerForm or rawget(_G, "PlayerForm") or {}
  local formNames = {
    { playerForm.PLAYERFORM_GUPPY, "guppy" }, { playerForm.PLAYERFORM_BOOK_WORM, "bookworm" },
    { playerForm.PLAYERFORM_MUSHROOM, "fun_guy" }, { playerForm.PLAYERFORM_ANGEL, "seraphim" },
    { playerForm.PLAYERFORM_BOB, "bob" }, { playerForm.PLAYERFORM_MOM, "mom" },
    { playerForm.PLAYERFORM_LORD_OF_THE_FLIES, "lord_of_the_flies" }, { playerForm.PLAYERFORM_BELIAL, "belial" }
  }
  for _, form in ipairs(formNames) do if form[1] ~= nil and invoke(false, "HasPlayerForm", form[1]) then transformations[form[2]] = true end end
  local healthState = {
    current = invoke(0, "GetHearts") + invoke(0, "GetSoulHearts") + invoke(0, "GetBlackHearts"),
    red = invoke(0, "GetHearts"), soul = invoke(0, "GetSoulHearts"), black = invoke(0, "GetBlackHearts"),
    bone = invoke(0, "GetBoneHearts"), rotten = invoke(0, "GetRottenHearts"), max = invoke(0, "GetMaxHearts")
  }
  local actorToken = characterTokens[playerType]
  if actorToken == "jacob_and_esau" then actorToken = invoke(false, "IsSubPlayer") and "esau" or "jacob" end
  return {
    health = healthState.current, maxHealth = healthState.max, healthState = healthState,
    keys = invoke(0, "GetNumKeys"), bombs = invoke(0, "GetNumBombs"), coins = invoke(0, "GetNumCoins"),
    power = player.Damage or 0, playerType = playerType, actorToken = actorToken, characterToken = characterTokens[playerType],
    stats = { damage = player.Damage or 0, fireRate = player.MaxFireDelay or 0, speed = player.MoveSpeed or 0 },
    resources = { keys = invoke(0, "GetNumKeys"), bombs = invoke(0, "GetNumBombs"), coins = invoke(0, "GetNumCoins") },
    collectibles = collectibles, actives = actives, trinkets = trinkets, cards = cards, pills = pills,
    transformations = transformations, temporaryEffects = {}, inventory = { collectibles = collectibles, actives = actives, trinkets = trinkets, cards = cards, pills = pills }
  }
end

function GameAdapter:buildVisibleChoice(pickup, roomId, visibility)
  pickup, visibility = pickup or {}, visibility or {}
  local variants = self.env.pickupVariant or rawget(_G, "PickupVariant") or {}
  local variant = pickup.Variant
  local kind = "pickup"
  if variant == variants.PICKUP_COLLECTIBLE then kind = "collectible"
  elseif variant == variants.PICKUP_TAROTCARD then kind = "card"
  elseif variant == variants.PICKUP_TRINKET then kind = "trinket"
  elseif variant == variants.PICKUP_PILL then kind = "pill" end
  local position = pickup.Position or {}
  local identity
  local itemConfigEntry
  if not visibility.curseBlind and kind == "collectible" then
    local item = self.env.itemConfig and safe(nil, function() return self.env.itemConfig:GetCollectible(pickup.SubType) end)
    itemConfigEntry = item
    identity = { id = pickup.SubType, name = item and item.Name, quality = item and item.Quality, tags = item and item.Tags, itemType = item and item.Type }
  elseif not visibility.curseBlind and kind == "trinket" then
    local item = self.env.itemConfig and self.env.itemConfig.GetTrinket and safe(nil, function() return self.env.itemConfig:GetTrinket(pickup.SubType) end)
    itemConfigEntry = item
    identity = { id = pickup.SubType, name = item and item.Name, quality = item and item.Quality, tags = item and item.Tags }
  elseif not visibility.curseBlind and kind == "card" then
    local item = self.env.itemConfig and self.env.itemConfig.GetCard and safe(nil, function() return self.env.itemConfig:GetCard(pickup.SubType) end)
    itemConfigEntry = item
    identity = { id = pickup.SubType, name = item and item.Name, quality = item and item.Quality, tags = item and item.Tags }
  elseif not visibility.curseBlind and kind == "pill" then
    local itemPool = self.env.itemPool
    local identified = itemPool and type(itemPool.IsPillIdentified) == "function" and safe(false, function() return itemPool:IsPillIdentified(pickup.SubType) end)
    if identified then
      local effect = itemPool and type(itemPool.GetPillEffect) == "function" and safe(nil, function() return itemPool:GetPillEffect(pickup.SubType) end) or nil
      identity = { id = pickup.SubType, effect = effect, identified = true }
    end
  end
  local option = pickup.OptionsPickupIndex
  local isActive = itemConfigEntry and tonumber(itemConfigEntry.Type) == tonumber(self.env.activeItemType or 3)
  return {
    id = tostring(roomId) .. ":" .. tostring(pickup.InitSeed or pickup.Index or pickup.SubType or "pickup"),
    roomId = roomId,
    position = { x = position.X or 0, y = position.Y or 0 },
    kind = kind,
    action = (tonumber(pickup.Price) or 0) > 0 and "buy" or (isActive and "replace_active" or nil),
    choiceGroupId = tostring(roomId) .. ":" .. tostring(option or pickup.ShopItemId or pickup.InitSeed or "solo"),
    observedIdentity = identity,
    price = tonumber(pickup.Price) or 0,
    resourceCost = { coins = math.max(0, tonumber(pickup.Price) or 0) },
    eligibleActors = { "primary" },
    replacement = isActive and { kind = "active", consequence = "replace_or_hold" } or nil,
    confidence = identity and "high" or "low",
    source = "observed_pickup",
    visible = not visibility.curseBlind
  }
end

function GameAdapter:buildInteractionChoices(roomId, visibility)
  local isaac = self.env.isaac or rawget(_G, "Isaac")
  local entityType = self.env.entityType or rawget(_G, "EntityType") or {}
  if not isaac or type(isaac.FindByType) ~= "function" or entityType.ENTITY_SLOT == nil then return {} end
  local result = {}
  local entities = safe({}, function() return isaac.FindByType(entityType.ENTITY_SLOT, -1, -1, false, false) end)
  for _, entity in ipairs(values(entities)) do
    local position = entity.Position or {}
    result[#result + 1] = {
      id = tostring(roomId) .. ":slot:" .. tostring(entity.InitSeed or entity.Index or entity.SubType or #result),
      roomId = roomId,
      position = { x = position.X or 0, y = position.Y or 0 },
      kind = "machine",
      choiceGroupId = tostring(roomId) .. ":slot",
      observedIdentity = { variant = entity.Variant, subtype = entity.SubType },
      price = tonumber(entity.Price) or 0,
      resourceCost = { coins = math.max(0, tonumber(entity.Price) or 0) },
      eligibleActors = { "primary" },
      confidence = "medium",
      source = "observed_slot",
      visible = not (visibility and visibility.curseBlind)
    }
  end
  return result
end

function GameAdapter:buildRerollChoice(player, roomId)
  local rerollActives = self.env.rerollActives or { [105] = true, [166] = true, [374] = true, [477] = true }
  for _, active in ipairs((player and player.actives) or {}) do
    if rerollActives[active.id] and (active.charge or 0) > 0 then
      return {
        id = tostring(roomId) .. ":reroll:" .. tostring(active.id), roomId = roomId, position = { x = 0, y = 0 }, kind = "reroll", action = "reroll",
        choiceGroupId = tostring(roomId) .. ":reroll", observedIdentity = { id = active.id }, price = 0,
        resourceCost = { activeCharge = 1 }, eligibleActors = { "primary" }, confidence = "medium", source = "owned_active"
      }
    end
  end
  return nil
end

function GameAdapter:buildRooms(level, currentIndex, currentRoom, visibility)
  local descriptors = values(safe({}, function() return level:GetRooms() end))
  local rooms, bySafe = {}, {}
  for index, desc in ipairs(descriptors) do
    local safeGrid = desc.SafeGridIndex
    if safeGrid == nil or safeGrid < 0 then safeGrid = desc.GridIndex end
    local id = safeGrid or desc.ListIndex or index
    local visited = (desc.VisitedCount or 0) > 0 or id == currentIndex
    local displayFlags = desc.DisplayFlags or 0
    local room = {
      id = id,
      listIndex = desc.ListIndex,
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
        local canonical = target
        if target ~= nil and bySafe[target] then canonical = bySafe[target] end
        if door and canonical and canonical >= 0 then current.doors[#current.doors + 1] = { slot = slot, to = canonical, cost = door.IsLocked and 1 or 0 } end
      end
    end
  end
  return rooms
end

function GameAdapter:build()
  local env, game = self.env, self.env.game
  local level = safe(nil, function() return game:GetLevel() end)
  local floorToken = tostring(safe("", function() return level:GetStage() end)) .. ":" .. tostring(safe("", function() return level:GetStageType() end))
  if floorToken ~= self.floorToken then
    self.floorToken = floorToken
    self.observationRooms = {}
    self.observationChoices = {}
  end
  local currentIndex = safe(0, function() return level:GetCurrentRoomIndex() end)
  local currentRoom = safe(nil, function() return level:GetCurrentRoom() end)
  local curses = safe(0, function() return level:GetCurses() end)
  local levelCurse = env.levelCurse or rawget(_G, "LevelCurse") or {}
  local visibility = {
    curseBlind = levelCurse.CURSE_OF_BLIND and (curses & levelCurse.CURSE_OF_BLIND) ~= 0 or false,
    curseLost = levelCurse.CURSE_OF_THE_LOST and (curses & levelCurse.CURSE_OF_THE_LOST) ~= 0 or false
  }
  local players = {}
  local independentPlayers = 0
  local count = safe(1, function() return game:GetNumPlayers() end)
  for index = 0, count - 1 do
    local player = safe(nil, function() return game:GetPlayer(index) end)
    if player then
      if not safe(false, function() return player:IsSubPlayer() end) then independentPlayers = independentPlayers + 1 end
      players[#players + 1] = self:buildPlayer(player)
    end
  end
  local difficulty = rawget(_G, "Difficulty") or {}
  local hard = difficulty.DIFFICULTY_HARD and game.Difficulty == difficulty.DIFFICULTY_HARD
  local mode = { kind = safe(false, function() return game:IsGreedMode() end) and "greed" or "normal", difficulty = hard and "hard" or "normal", coOp = independentPlayers > 1, progressionAllowed = true }
  if (game.Challenge or 0) > 0 then mode.kind = "challenge"; mode.progressionAllowed = false end
  local seeds = safe(nil, function() return game:GetSeeds() end)
  if seeds and seeds.IsCustomRun and safe(false, function() return seeds:IsCustomRun() end) then mode.progressionAllowed = false end
  if game.AchievementUnlocksDisallowed and safe(false, function() return game:AchievementUnlocksDisallowed() end) then mode.progressionAllowed = false end
  local frameId = safe(0, function() return game:GetFrameCount() end)
  local stage = safe(nil, function() return level:GetStage() end)
  local stageType = safe(nil, function() return level:GetStageType() end)
  local victoryLap = safe(0, function() return game:GetVictoryLap() end)
  local rooms = self:buildRooms(level, currentIndex, currentRoom, visibility)
  local currentBossKind = self:detectCurrentBossKind()
  local currentClear = safe(false, function() return currentRoom:IsClear() end)
  for _, room in ipairs(rooms) do
    if room.id == currentIndex then
      room.clear = currentClear
      if currentBossKind then room.kind = currentBossKind end
    end
  end
  local pickups, pickupsByRoom, visibleChoices, choicesByRoom = {}, {}, {}, {}
  local isaac = env.isaac or rawget(_G, "Isaac")
  if isaac and isaac.FindByType then
    local entityType = self.env.entityType or rawget(_G, "EntityType") or {}
    local pickupVariant = self.env.pickupVariant or rawget(_G, "PickupVariant") or {}
    for _, pickup in ipairs(values(safe({}, function() return isaac.FindByType(entityType.ENTITY_PICKUP, -1, -1, false, false) end))) do
      local roomId = pickup.RoomIndex or safe(nil, function() return pickup:GetRoomIndex() end) or currentIndex
      local choice = self:buildVisibleChoice(pickup, roomId, visibility)
      local entry = {
        variant = pickup.Variant,
        subtype = pickup.SubType,
        category = choice.kind,
        visible = not visibility.curseBlind,
        quality = choice.observedIdentity and choice.observedIdentity.quality,
        id = choice.observedIdentity and choice.observedIdentity.id,
        tags = choice.observedIdentity and choice.observedIdentity.tags,
        choiceId = choice.id,
        price = choice.price
      }
      pickups[#pickups + 1] = entry
      pickupsByRoom[roomId] = pickupsByRoom[roomId] or {}
      pickupsByRoom[roomId][#pickupsByRoom[roomId] + 1] = entry
      visibleChoices[#visibleChoices + 1] = choice
      choicesByRoom[roomId] = choicesByRoom[roomId] or {}
      choicesByRoom[roomId][#choicesByRoom[roomId] + 1] = choice
    end
    local interactions = self:buildInteractionChoices(currentIndex, visibility)
    for _, choice in ipairs(interactions) do
      visibleChoices[#visibleChoices + 1] = choice
      choicesByRoom[currentIndex] = choicesByRoom[currentIndex] or {}
      choicesByRoom[currentIndex][#choicesByRoom[currentIndex] + 1] = choice
    end
    local reroll = self:buildRerollChoice(players[1], currentIndex)
    if reroll then
      visibleChoices[#visibleChoices + 1] = reroll
      choicesByRoom[currentIndex] = choicesByRoom[currentIndex] or {}
      choicesByRoom[currentIndex][#choicesByRoom[currentIndex] + 1] = reroll
    end
  end
  for roomId, roomPickups in pairs(pickupsByRoom) do
    self.observationRooms[roomId] = { entered = true, pickups = roomPickups }
  end
  for roomId, roomChoices in pairs(choicesByRoom) do self.observationChoices[roomId] = roomChoices end
  if currentClear and pickupsByRoom[currentIndex] == nil and self.observationRooms[currentIndex] then
    self.observationRooms[currentIndex].pickups = {}
  end
  if currentClear and choicesByRoom[currentIndex] == nil then self.observationChoices[currentIndex] = {} end
  for _, room in ipairs(rooms) do
    if self.observationRooms[room.id] then room.pickups = self.observationRooms[room.id].pickups end
  end
  local progress = { achievements = {}, completionMarks = {} }
  local caps = env.capabilities or {}
  if caps.persistentAchievements and isaac and isaac.GetPersistentGameData then
    progress.achievementsAvailable = safe(false, function() return isaac.GetPersistentGameData() ~= nil end)
  end
  if caps.completionMarks and isaac and isaac.GetCompletionMarks then
    for _, p in ipairs(players) do
      local marks = safe(nil, function() return isaac.GetCompletionMarks(p.playerType) end)
      if marks ~= nil then progress.completionMarks[p.playerType] = marks end
    end
  end
  local observedPickups = {}
  for _, observation in pairs(self.observationRooms) do
    for _, pickup in ipairs(observation.pickups or {}) do observedPickups[#observedPickups + 1] = pickup end
  end
  local observedChoices = {}
  for _, roomChoices in pairs(self.observationChoices) do for _, choice in ipairs(roomChoices or {}) do observedChoices[#observedChoices + 1] = choice end end
  local snapshot = {
    frameId = frameId,
    run = {
      mode = mode.kind,
      difficulty = mode.difficulty,
      progressionAllowed = mode.progressionAllowed,
      victoryLap = victoryLap and victoryLap > 0 or false,
      elapsedSeconds = frameId / 30
    },
    floor = { stage = stage, stageType = stageType, currentRoomId = currentIndex, rooms = rooms },
    currentRoom = currentIndex,
    currentRoomClear = currentClear,
    mode = mode,
    visibility = visibility,
    player = players[1] or {},
    rooms = rooms,
    observations = { pickups = observedPickups, rooms = self.observationRooms },
    visibleChoices = observedChoices,
    timing = { frame = safe(0, function() return currentRoom:GetFrameCount() end), runFrame = frameId },
    progress = progress,
    capabilities = caps,
    buildState = BuildState.fromPlayer(players[1] or {})
  }
  return Visibility.sanitizeSnapshot(snapshot)
end

return GameAdapter
