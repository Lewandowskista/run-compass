local Browser = require("runcompass.browser")
local Goals = require("runcompass.goals")

local BrowserModel = {}

local CATEGORY_DEFINITIONS = {
  { id = "boss_routes", name = "Boss Routes" },
  { id = "item_unlocks", name = "Item Unlocks" },
  { id = "completion_marks", name = "Completion Marks" },
  { id = "special", name = "Special / Other" }
}

local function copy(value)
  local result = {}
  for key, item in pairs(value or {}) do result[key] = item end
  return result
end

local function sortGoals(goals)
  table.sort(goals, function(left, right)
    local leftName, rightName = string.lower(left.name or ""), string.lower(right.name or "")
    if leftName == rightName then return tostring(left.id) < tostring(right.id) end
    return leftName < rightName
  end)
end

local function readablePrerequisite(prerequisite)
  if type(prerequisite) == "table" then return prerequisite.name or prerequisite.id or prerequisite.token or "Required" end
  return tostring(prerequisite)
end

local function detailsFor(entry)
  if not entry then return { name = "No matching goals", statusLabel = "Unavailable" } end
  local method = entry.unlockMethod or entry.displayRule or (entry.kind == "boss" and "Boss route" or "Vanilla unlock")
  local prerequisites = entry.prerequisites or {}
  local details = {
    id = entry.id,
    name = entry.name,
    kind = entry.kind,
    status = entry.status,
    statusLabel = Browser.statusLabel(entry.status),
    requiredCharacterToken = entry.requiredCharacterToken,
    requiredDifficulty = entry.requiredDifficulty,
    unlockMethod = method,
    completionMark = entry.completionMark,
    prerequisites = prerequisites,
    supportTier = entry.supportTier or "base",
    eligibility = entry.eligibility,
    currentRunStatus = entry.currentRunStatus or entry.status,
    lines = {}
  }
  details.lines[#details.lines + 1] = "Status: " .. details.statusLabel
  details.lines[#details.lines + 1] = "Character: " .. tostring(details.requiredCharacterToken or "Any")
  details.lines[#details.lines + 1] = "Difficulty: " .. tostring(details.requiredDifficulty or "Normal / Hard")
  details.lines[#details.lines + 1] = "Method: " .. tostring(method)
  details.lines[#details.lines + 1] = "Support: " .. tostring(details.supportTier)
  details.lines[#details.lines + 1] = "Current run: " .. Browser.statusLabel(details.currentRunStatus)
  for _, prerequisite in ipairs(prerequisites) do
    details.lines[#details.lines + 1] = "Prerequisite: " .. readablePrerequisite(prerequisite)
  end
  return details
end

function BrowserModel.build(entries, snapshot, state, pageSize)
  snapshot = snapshot or {}
  state = state or {}
  pageSize = math.max(1, tonumber(pageSize) or 10)
  local resolvedEntries = {}
  for _, entry in ipairs(entries or {}) do
    local resolved = Goals.resolve(entry, snapshot)
    resolved.currentRunStatus = resolved.status
    resolved.status = entry.status or resolved.status
    resolvedEntries[#resolvedEntries + 1] = resolved
  end
  local filteredEntries = Browser.filter(resolvedEntries, state.filters or {})
  local byCategory = {}
  for _, definition in ipairs(CATEGORY_DEFINITIONS) do byCategory[definition.id] = {} end
  for _, entry in ipairs(filteredEntries) do
    local category = Browser.category(entry)
    byCategory[category][#byCategory[category] + 1] = entry
  end
  local categories = {}
  for _, definition in ipairs(CATEGORY_DEFINITIONS) do
    local goals = byCategory[definition.id]
    sortGoals(goals)
    categories[#categories + 1] = { id = definition.id, name = definition.name, label = definition.name, count = #goals }
  end
  local activeCategory = state.category or CATEGORY_DEFINITIONS[1].id
  if not byCategory[activeCategory] then activeCategory = CATEGORY_DEFINITIONS[1].id end
  local goals = byCategory[activeCategory]
  local selectedIndex = tonumber(state.selectedIndex) or 1
  if #goals == 0 then selectedIndex = 0
  elseif selectedIndex < 1 then selectedIndex = 1
  elseif selectedIndex > #goals then selectedIndex = #goals end
  local maxScroll = math.max(1, #goals - pageSize + 1)
  local scrollOffset = tonumber(state.scrollOffset) or 1
  if scrollOffset < 1 then scrollOffset = 1 elseif scrollOffset > maxScroll then scrollOffset = maxScroll end
  if selectedIndex > 0 and selectedIndex < scrollOffset then scrollOffset = selectedIndex end
  if selectedIndex > scrollOffset + pageSize - 1 then scrollOffset = selectedIndex - pageSize + 1 end
  local rows = {}
  local firstRowIndex = scrollOffset
  for index = firstRowIndex, math.min(#goals, firstRowIndex + pageSize - 1) do
    local row = copy(goals[index])
    row.absoluteIndex = index
    row.statusLabel = Browser.statusLabel(row.status)
    row.selected = row.absoluteIndex == selectedIndex
    row.entry = goals[index]
    rows[#rows + 1] = row
  end
  return {
    categories = categories,
    activeCategory = activeCategory,
    goals = goals,
    rows = rows,
    selectedIndex = selectedIndex,
    scrollOffset = scrollOffset,
    details = detailsFor(goals[selectedIndex]),
    resultCount = #goals,
    snapshot = snapshot
  }
end

return BrowserModel
