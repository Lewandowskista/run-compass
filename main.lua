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

local game = Game()
local isaac = Isaac
local state = Save.migrate(nil)
local capabilities = Capabilities.detect(rawget(_G, "REPENTOGON"), { ModConfigMenu = rawget(_G, "ModConfigMenu") or rawget(_G, "MCM") })
local catalog
local controller = Controller.new(Planner)
local ui
local adapter
local lastSnapshot

local function output(message)
  if isaac and isaac.ConsoleOutput then isaac.ConsoleOutput("[Run Compass] " .. message .. "\n") end
end

local function addCallback(name, callback)
  local callbacks = rawget(_G, "ModCallbacks") or {}
  if callbacks[name] then RunCompass:AddCallback(callbacks[name], callback) end
end

local function fingerprint(snapshot)
  local player = snapshot.player or {}
  return table.concat({
    tostring(snapshot.currentRoom), tostring(snapshot.currentRoomClear), tostring(snapshot.visibility.curseBlind),
    tostring(snapshot.visibility.curseLost), tostring(player.health), tostring(player.keys), tostring(player.bombs),
    tostring(player.coins), tostring(#(snapshot.observations.pickups or {})), tostring(snapshot.mode.kind)
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
  if not adapter then return end
  local snapshot = adapter:build()
  snapshot.capabilities = capabilities
  local nextFingerprint = fingerprint(snapshot)
  if lastSnapshot and nextFingerprint ~= lastSnapshot then controller:onEvent("PLAYER_STATE_CHANGED") end
  lastSnapshot = nextFingerprint
  local goal = selectedGoal(snapshot)
  local recommendation = controller:tick(snapshot, goal)
  recommendation.capabilityTier = capabilities.tier
  ui:render(snapshot, recommendation)
end

local function initialize()
  capabilities = Capabilities.detect(rawget(_G, "REPENTOGON"), { ModConfigMenu = rawget(_G, "ModConfigMenu") or rawget(_G, "MCM") })
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
    pickupVariant = rawget(_G, "PickupVariant"), itemConfig = itemConfig
  })
  catalog = Catalog.new(itemConfig and adapter:collectItems(itemConfig) or {}, Rules.unlocks)
  for _, boss in ipairs(Goals.bosses()) do catalog:add(boss) end
  if not state.selectedGoalId then state.selectedGoalId = "boss.delirium" end
  ui = UI.new({
    isaac = isaac,
    input = rawget(_G, "Input"),
    keyboard = rawget(_G, "Keyboard"),
    controller = rawget(_G, "Controller"),
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
  output("Loaded base tier" .. (capabilities.tier == "enhanced" and " with Repentogon " .. tostring(capabilities.repentogonVersion) or "."))
end

local normalized = Events.normalized(controller)

addCallback("MC_POST_GAME_STARTED", function()
  if isaac.LoadModData then state = Save.deserialize(isaac.LoadModData(RunCompass)) end
  initialize()
  normalized.run()
end)
addCallback("MC_POST_NEW_LEVEL", normalized.level)
addCallback("MC_POST_NEW_ROOM", normalized.room)
addCallback("MC_POST_PICKUP_UPDATE", normalized.pickup)
addCallback("MC_POST_PEFFECT_UPDATE", normalized.player)
addCallback("MC_POST_UPDATE", function() refresh() end)
addCallback("MC_POST_RENDER", function() if ui then ui:input() end end)
addCallback("MC_PRE_GAME_EXIT", function()
  if isaac.SaveModData then isaac.SaveModData(RunCompass, Save.serialize(state)) end
end)
addCallback("MC_EXECUTE_CMD", function(command, params)
  if command ~= "runcompass" then return end
  local argument = string.lower(params or "")
  if catalog and catalog:get(argument) then state.selectedGoalId = argument; controller:onEvent("TARGET_CHANGED"); output("Target set to " .. argument)
  elseif argument == "status" then output("tier=" .. capabilities.tier .. ", target=" .. tostring(state.selectedGoalId))
  else output("Usage: runcompass status | runcompass <goal-id>") end
end)

addCallback("MC_POST_COMPLETION_MARK_GET", normalized.progress)
addCallback("MC_POST_PLAYER_COLLECTIBLE_ADDED", normalized.player)
addCallback("MC_POST_PLAYER_COLLECTIBLE_REMOVED", normalized.player)
