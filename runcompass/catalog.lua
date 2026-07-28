local Catalog = {}
Catalog.__index = Catalog

function Catalog.new(items, unlockRules)
  local self = setmetatable({ entries = {}, order = {} }, Catalog)
  unlockRules = unlockRules or {}
  for _, item in ipairs(items or {}) do
    local entry = {
      id = item.id,
      name = item.name or ("Collectible " .. tostring(item.id)),
      achievementId = item.achievementId,
      kind = "collectible",
      supportTier = "base",
      status = "locked"
    }
    if item.achievementId == -1 or item.achievementId == nil then
      entry.status = "already_unlocked"
    elseif unlockRules[item.achievementId] then
      for key, value in pairs(unlockRules[item.achievementId]) do entry[key] = value end
    else
      entry.status = "catalog_update_required"
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

return Catalog
