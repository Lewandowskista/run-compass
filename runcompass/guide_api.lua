local GuideAPI = {}
GuideAPI.__index = GuideAPI

function GuideAPI.new(models)
  return setmetatable({ models = models, rules = {}, profiles = {}, diagnostics = {} }, GuideAPI)
end

function GuideAPI:RegisterItemModel(modId, kind, id, model)
  if type(modId) ~= "string" or id == nil or type(model) ~= "table" then return false end
  model.kind = kind or model.kind
  model.source = modId
  return self.models:register(id, model)
end

function GuideAPI:RegisterInteractionRule(modId, rule)
  if type(modId) ~= "string" or type(rule) ~= "table" or rule.candidate == nil then return false end
  rule.source = modId
  self.rules[#self.rules + 1] = rule
  local model = self.models:get(rule.candidate) or { effects = {} }
  model.synergies = model.synergies or {}
  if rule.owned then model.synergies[#model.synergies + 1] = { owned = rule.owned, effects = rule.effects or {}, id = rule.id or (modId .. ":interaction:" .. tostring(rule.candidate)) } end
  self.models:register(rule.candidate, model)
  return true
end

function GuideAPI:RegisterCharacterProfile(modId, characterToken, profile)
  if type(modId) ~= "string" or type(characterToken) ~= "string" or type(profile) ~= "table" then return false end
  profile.source = modId
  self.profiles[characterToken] = profile
  self.models.characterProfiles[characterToken] = profile
  return true
end

return GuideAPI
