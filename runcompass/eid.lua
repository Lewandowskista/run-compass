local EID = {}
EID.__index = EID

function EID.detect(provider)
  local adapter = setmetatable({ available = false, provider = provider }, EID)
  adapter.available = type(provider) == "table" and type(provider.getDescription) == "function"
  return adapter
end

function EID:describe(id, visibility)
  if visibility and visibility.curseBlind then return nil end
  if id == nil or not self.available then return nil end
  local ok, value = pcall(self.provider.getDescription, self.provider, id)
  return ok and type(value) == "string" and value or nil
end

return EID
