local Browser = {}

function Browser.filter(entries, filters)
  filters = filters or {}
  local query = string.lower(filters.query or "")
  local result = {}
  for _, entry in ipairs(entries or {}) do
    local matchesQuery = query == "" or string.find(string.lower(entry.name or ""), query, 1, true)
    local matchesKind = not filters.kind or filters.kind == "all" or entry.kind == filters.kind
    local matchesStatus = not filters.status or filters.status == "all" or entry.status == filters.status
    local matchesCharacter = not filters.character or filters.character == "all" or entry.requiredCharacterToken == filters.character
    local matchesUnlock = not filters.unlockMethod or filters.unlockMethod == "all" or entry.unlockMethod == filters.unlockMethod or entry.displayRule == filters.unlockMethod
    local matchesMark = not filters.completionMark or filters.completionMark == "all" or entry.completionMark == filters.completionMark
    local matchesLetter = not filters.letter or filters.letter == "all" or string.upper(string.sub(entry.name or "", 1, 1)) == filters.letter
    if matchesQuery and matchesKind and matchesStatus and matchesCharacter and matchesUnlock and matchesMark and matchesLetter then result[#result + 1] = entry end
  end
  table.sort(result, function(left, right)
    local leftName, rightName = string.lower(left.name or ""), string.lower(right.name or "")
    if leftName == rightName then return tostring(left.id) < tostring(right.id) end
    return leftName < rightName
  end)
  return result
end

local STATUS_LABELS = {
  routable = "Eligible",
  locked = "Locked",
  already_unlocked = "Completed",
  instructional_only = "Instructional",
  catalog_update_required = "Update required",
  unavailable_this_run = "Unavailable"
}

function Browser.category(entry)
  if entry.kind == "boss" then return "boss_routes" end
  if entry.completionMark then return "completion_marks" end
  if entry.kind == "collectible" and entry.unlockMethod ~= "donation" and entry.unlockMethod ~= "special" then
    return "item_unlocks"
  end
  return "special"
end

function Browser.statusLabel(status)
  return STATUS_LABELS[status] or tostring(status or "Unknown")
end

return Browser
