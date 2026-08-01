local BuildState = {}

local function clone(value)
  if type(value) ~= "table" then return value end
  local result = {}
  for key, item in pairs(value) do result[key] = clone(item) end
  return result
end

local function normalizeMap(value)
  local result = {}
  if type(value) ~= "table" then return result end
  for key, item in pairs(value) do result[tonumber(key) or key] = tonumber(item) or item end
  return result
end

function BuildState.fromPlayer(player)
  player = player or {}
  local health = clone(player.healthState or { current = player.health or 0, max = player.maxHealth or player.health or 0 })
  local resources = clone(player.resources or { keys = player.keys or 0, bombs = player.bombs or 0, coins = player.coins or 0 })
  if resources.redHearts == nil and health.red ~= nil then resources.redHearts = health.red end
  if resources.soulHearts == nil and health.soul ~= nil then resources.soulHearts = health.soul end
  if resources.effectiveHealth == nil and health.effective ~= nil then resources.effectiveHealth = health.effective end
  return {
    actorToken = player.actorToken or player.characterToken,
    characterToken = player.characterToken,
    formToken = player.formToken,
    playerType = player.playerType,
    collectibles = normalizeMap(player.collectibles),
    actives = clone(player.actives or {}),
    trinkets = clone(player.trinkets or {}),
    cards = clone(player.cards or {}),
    pills = clone(player.pills or {}),
    transformations = clone(player.transformations or {}),
    temporaryEffects = clone(player.temporaryEffects or {}),
    stats = clone(player.stats or { damage = player.damage or player.power or 0 }),
    health = health,
    resources = resources,
    actors = clone(player.actors or {}),
    inventoryLimits = clone(player.inventoryLimits or {}),
    featureSummary = clone(player.featureSummary or {}),
    applicableRuleIds = clone(player.applicableRuleIds or {})
  }
end

function BuildState.fingerprint(state)
  state = state or {}
  local parts = { tostring(state.characterToken), tostring(state.formToken) }
  for id, count in pairs(state.collectibles or {}) do parts[#parts + 1] = tostring(id) .. "=" .. tostring(count) end
  table.sort(parts)
  return table.concat(parts, "|")
end

function BuildState.clone(state)
  return clone(state or {})
end

return BuildState
