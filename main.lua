local RunCompass = RegisterMod("Run Compass [REP+]", 1)

local Planner = require("runcompass.planner")
local Controller = require("runcompass.controller")
local Capabilities = require("runcompass.capabilities")
local Catalog = require("runcompass.catalog")
local Goals = require("runcompass.goals")
local Rules = require("runcompass.rules")
local Save = require("runcompass.save")
local GameAdapter = require("runcompass.game")
local Events = require("runcompass.events")
local MCM = require("runcompass.mcm")
local UI = require("runcompass.ui")
local Runtime = require("runcompass.runtime")
local ItemModels = require("runcompass.item_models")
local GuideData = require("runcompass.guide_data")
local GuideAPI = require("runcompass.guide_api")
local EID = require("runcompass.eid")

local game = Game()
local isaac = Isaac
local state = Save.migrate(nil)
local capabilities = Capabilities.detect(rawget(_G, "REPENTOGON"), { ModConfigMenu = rawget(_G, "ModConfigMenu") or rawget(_G, "MCM"), isaac = isaac, game = game, callbacks = rawget(_G, "ModCallbacks") })
local catalog
local controller = Controller.new(Planner)
local ui
local adapter
local runtime
local decisionModels
local RunCompassAPI
local eid

local function output(message)
  if isaac and isaac.ConsoleOutput then isaac.ConsoleOutput("[Run Compass] " .. message .. "\n") end
end

local function addCallback(name, callback)
  local callbacks = rawget(_G, "ModCallbacks") or {}
  if callbacks[name] then RunCompass:AddCallback(callbacks[name], callback) end
end

local function fingerprint(snapshot)
  local player = snapshot.player or {}
  local pickups = snapshot.observations and snapshot.observations.pickups or {}
  local build = snapshot.buildState or {}
  local choices = snapshot.visibleChoices or {}
  local pickupSignature = {}
  for index, pickup in ipairs(pickups) do
    if index > 12 then break end
    pickupSignature[#pickupSignature + 1] = table.concat({ tostring(pickup.category), tostring(pickup.subtype), tostring(pickup.quality) }, ",")
  end
  local choiceSignature = {}
  for index, choice in ipairs(choices) do
    if index > 16 then break end
    choiceSignature[#choiceSignature + 1] = table.concat({ tostring(choice.id), tostring(choice.price), tostring(choice.observedIdentity and choice.observedIdentity.id) }, ",")
  end
  local inventorySignature = {}
  for id, count in pairs(build.collectibles or {}) do inventorySignature[#inventorySignature + 1] = tostring(id) .. "=" .. tostring(count) end
  table.sort(inventorySignature)
  return table.concat({
    tostring(snapshot.currentRoom), tostring(snapshot.currentRoomClear), tostring(snapshot.visibility.curseBlind),
    tostring(snapshot.visibility.curseLost), tostring(player.health), tostring(player.keys), tostring(player.bombs),
    tostring(player.coins), tostring(#pickups), table.concat(pickupSignature, ";"), tostring(snapshot.mode.kind),
    tostring(snapshot.mode.difficulty), tostring(snapshot.floor and snapshot.floor.stage), tostring(snapshot.floor and snapshot.floor.stageType),
    table.concat(inventorySignature, ";"), table.concat(choiceSignature, ";")
  }, ":")
end

local function selectedGoal(snapshot)
  local entry = catalog and catalog:get(state.selectedGoalId)
  if not entry then entry = catalog:get("boss.delirium") end
  if capabilities.persistentProgress and entry and entry.achievementId and isaac.GetPersistentGameData then
    local progress = isaac.GetPersistentGameData()
    if progress and progress.Unlocked and progress:Unlocked(entry.achievementId) then entry.status = "already_unlocked" end
  end
  return Goals.resolve(entry or { id = "boss.delirium", kind = "boss" }, snapshot)
end

local function refresh()
  if runtime then runtime:update() end
end

local function initialize()
  capabilities = Capabilities.detect(rawget(_G, "REPENTOGON"), { ModConfigMenu = rawget(_G, "ModConfigMenu") or rawget(_G, "MCM"), isaac = isaac, game = game, callbacks = rawget(_G, "ModCallbacks") })
  local itemConfig = isaac.GetItemConfig and isaac.GetItemConfig()
  adapter = GameAdapter.new({
    game = game,
    isaac = isaac,
    roomType = rawget(_G, "RoomType"),
    bossType = rawget(_G, "BossID") or rawget(_G, "BossId"),
    playerType = rawget(_G, "PlayerType"),
    entityType = rawget(_G, "EntityType"),
    levelCurse = rawget(_G, "LevelCurse"),
    collectibleType = rawget(_G, "CollectibleType"),
    pickupVariant = rawget(_G, "PickupVariant"), itemConfig = itemConfig, capabilities = capabilities,
    itemPool = game.GetItemPool and game:GetItemPool() or nil
  })
  local itemEntries = itemConfig and adapter:collectItems(itemConfig) or {}
  local modelEntries = {}
  for _, entry in ipairs(itemEntries) do modelEntries[#modelEntries + 1] = entry end
  local trinketType, cardType, pillColor = rawget(_G, "TrinketType") or {}, rawget(_G, "Card") or {}, rawget(_G, "PillColor") or {}
  for _, entry in ipairs(adapter:collectConfigured("trinket", trinketType.NUM_TRINKETS or 200)) do modelEntries[#modelEntries + 1] = entry end
  for _, entry in ipairs(adapter:collectConfigured("card", cardType.NUM_CARDS or 500)) do modelEntries[#modelEntries + 1] = entry end
  for _, entry in ipairs(adapter:collectConfigured("pill", pillColor.NUM_PILLS or 20)) do modelEntries[#modelEntries + 1] = entry end
  catalog = Catalog.new(itemEntries, Rules.unlocks, Rules)
  decisionModels = ItemModels.fromCatalog(modelEntries, GuideData.items)
  eid = EID.detect(rawget(_G, "EID"))
  RunCompassAPI = GuideAPI.new(decisionModels)
  for characterToken, profile in pairs(GuideData.characterProfiles) do RunCompassAPI:RegisterCharacterProfile("run-compass", characterToken, profile) end
  rawset(_G, "RunCompassAPI", RunCompassAPI)
  for _, boss in ipairs(Goals.bosses()) do catalog:add(boss) end
  if not state.selectedGoalId then state.selectedGoalId = "boss.delirium" end
  ui = UI.new({
    isaac = isaac,
    input = rawget(_G, "Input"),
    keyboard = rawget(_G, "Keyboard"),
    buttonAction = rawget(_G, "ButtonAction"),
    controller = rawget(_G, "Controller"),
    spriteFactory = rawget(_G, "Sprite"),
    game = game,
    snapshot = function() return runtime and runtime.snapshot or nil end,
    getSelectedGoal = function() return catalog and catalog:get(state.selectedGoalId) or nil end,
    state = state,
    entries = catalog:all(),
    capabilities = capabilities,
    mcmAvailable = capabilities.mcm,
    onGoalSelected = function(entry)
      state.selectedGoalId = entry.id
      controller:onEvent("TARGET_CHANGED")
    end
  })
  if not MCM.register(state, function() controller:onEvent("TARGET_CHANGED") end) then output("Mod Config Menu not detected; using defaults.") end
  runtime = Runtime.new({
    adapter = adapter,
    controller = controller,
    getGoal = selectedGoal,
    fingerprint = fingerprint,
    output = output,
    capabilities = capabilities,
    decisionModels = decisionModels,
    eid = eid,
    ui = ui
  })
  local modelReport = decisionModels:validate((function() local ids = {}; for _, entry in ipairs(modelEntries) do ids[#ids + 1] = { id = entry.id, kind = entry.kind or "collectible" } end; return ids end)())
  output("Loaded base tier" .. (capabilities.tier == "enhanced" and " with Repentogon " .. tostring(capabilities.repentogonVersion) or ".") .. " build models=" .. tostring(modelReport.modeled) .. "/" .. tostring(modelReport.total) .. ", EID=" .. (eid.available and "available" or "missing"))
end

local normalized = Events.normalized(controller)

addCallback("MC_POST_GAME_STARTED", function()
  if isaac.LoadModData then state = Save.deserialize(isaac.LoadModData(RunCompass)) end
  initialize()
  normalized.run()
end)
addCallback("MC_POST_NEW_LEVEL", normalized.level)
addCallback("MC_POST_NEW_ROOM", normalized.room)
addCallback("MC_POST_UPDATE", function() refresh() end)
addCallback("MC_POST_RENDER", function()
  if ui then ui:input() end
  if runtime then runtime:render() end
end)
addCallback("MC_PRE_GAME_EXIT", function()
  if isaac.SaveModData then isaac.SaveModData(RunCompass, Save.serialize(state)) end
end)
addCallback("MC_EXECUTE_CMD", function(command, params)
  if command ~= "runcompass" then return end
  local argument = string.lower(params or "")
  if catalog and catalog:get(argument) then state.selectedGoalId = argument; controller:onEvent("TARGET_CHANGED"); output("Target set to " .. argument)
  elseif argument == "status" then output("tier=" .. capabilities.tier .. ", target=" .. tostring(state.selectedGoalId))
  elseif argument == "catalog" and catalog then
    local report = catalog:validate(Rules)
    output("catalog=" .. tostring(Rules.version) .. ", total=" .. tostring(report.total) .. ", classified=" .. tostring(report.classified) .. ", unknown=" .. tostring(report.unmapped) .. ", invalid=" .. tostring(#report.invalid))
  else output("Usage: runcompass status | runcompass catalog | runcompass <goal-id>") end
end)

addCallback("MC_POST_COMPLETION_MARK_GET", normalized.progress)
addCallback("MC_POST_ACHIEVEMENT_UNLOCK", normalized.progress)
addCallback("MC_POST_PLAYER_COLLECTIBLE_ADDED", normalized.player)
addCallback("MC_POST_PLAYER_COLLECTIBLE_REMOVED", normalized.player)
addCallback("MC_POST_TRIGGER_COLLECTIBLE_ADDED", normalized.build)
addCallback("MC_POST_ENTITY_REMOVE", normalized.entityRemoved)
