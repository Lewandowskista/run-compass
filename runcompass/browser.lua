local Browser = {}

function Browser.filter(entries, filters)
  filters = filters or {}
  local query = string.lower(filters.query or "")
  local result = {}
  for _, entry in ipairs(entries or {}) do
    local matchesQuery = query == "" or string.find(string.lower(entry.name or ""), query, 1, true)
    local matchesKind = not filters.kind or filters.kind == "all" or entry.kind == filters.kind
    local matchesStatus = not filters.status or filters.status == "all" or entry.status == filters.status
    local matchesLetter = not filters.letter or filters.letter == "all" or string.upper(string.sub(entry.name or "", 1, 1)) == filters.letter
    if matchesQuery and matchesKind and matchesStatus and matchesLetter then result[#result + 1] = entry end
  end
  table.sort(result, function(left, right)
    local leftName, rightName = string.lower(left.name or ""), string.lower(right.name or "")
    if leftName == rightName then return tostring(left.id) < tostring(right.id) end
    return leftName < rightName
  end)
  return result
end

return Browser
