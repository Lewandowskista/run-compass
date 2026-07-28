local Catalog = {}
Catalog.__index = Catalog

function Catalog.new(items, unlockRules, metadata)
  local self = setmetatable({ entries = {}, order = {} }, Catalog)
  unlockRules = unlockRules or {}
  metadata = metadata or {}
  for _, item in ipairs(items or {}) do
    local entry = {
      id = item.id,
      name = item.name or ("Collectible " .. tostring(item.id)),
      achievementId = item.achievementId,
      quality = item.quality,
      tags = item.tags,
      kind = "collectible",
      supportTier = "base",
      status = "locked",
      classification = "base_routable"
    }
    if item.achievementId == -1 or item.achievementId == nil then
      entry.status = "already_unlocked"
      entry.classification = "already_unlocked"
    elseif unlockRules[item.achievementId] then
      for key, value in pairs(unlockRules[item.achievementId]) do entry[key] = value end
      if not entry.classification then
        entry.classification = entry.requiredCapability == "enhanced" and "enhanced_routable" or "base_routable"
      end
    elseif metadata.knownAchievementMax and tonumber(item.achievementId) and tonumber(item.achievementId) <= metadata.knownAchievementMax then
      entry.status = "instructional_only"
      entry.classification = "instructional_only"
      entry.supportTier = "none"
    else
      entry.status = "catalog_update_required"
      entry.classification = "catalog_update_required"
      entry.supportTier = "none"
    end
    self.entries[item.id] = entry
    self.order[#self.order + 1] = item.id
  end
  table.sort(self.order)
  return self
end

function Catalog:get(id)
  return self.entries[id]
end

function Catalog:add(entry)
  if not self.entries[entry.id] then self.order[#self.order + 1] = entry.id end
  self.entries[entry.id] = entry
  table.sort(self.order, function(left, right)
    return string.lower(self.entries[left].name or "") < string.lower(self.entries[right].name or "")
  end)
end

function Catalog:search(query)
  query = string.lower(query or "")
  local result = {}
  for _, id in ipairs(self.order) do
    local entry = self.entries[id]
    if query == "" or string.find(string.lower(entry.name), query, 1, true) then
      result[#result + 1] = entry
    end
  end
  return result
end

function Catalog:all()
  local result = {}
  for _, id in ipairs(self.order) do result[#result + 1] = self.entries[id] end
  return result
end

function Catalog:validate(metadata)
  metadata = metadata or {}
  local report = { version = metadata.version or "unknown", total = 0, classified = 0, unknown = {}, invalid = {} }
  for _, id in ipairs(self.order) do
    local entry = self.entries[id]
    if entry.kind == "collectible" then
      report.total = report.total + 1
      if entry.classification then report.classified = report.classified + 1 end
      if entry.classification == "catalog_update_required" then report.unknown[#report.unknown + 1] = entry.achievementId end
      if entry.achievementId ~= nil and tonumber(entry.achievementId) and tonumber(entry.achievementId) < -1 then report.invalid[#report.invalid + 1] = entry.id end
    end
  end
  report.unmapped = #report.unknown
  return report
end

return Catalog
