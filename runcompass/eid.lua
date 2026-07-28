local EID = {}
EID.__index = EID

function EID.detect(provider)
  local adapter = setmetatable({ available = false, provider = provider }, EID)
  adapter.available = type(provider) == "table" and type(provider.getDescription) == "function"
  return adapter
end

function EID:describe(id)
  if not self.available then return nil end
  local ok, value = pcall(self.provider.getDescription, self.provider, id)
  return ok and value or nil
end

return EID
