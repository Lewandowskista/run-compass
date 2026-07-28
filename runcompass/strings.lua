local Strings = {
  hud = {
    installMcm = "Run Compass: install Mod Config Menu for settings",
    target = "Target: %s",
    confidence = "%s confidence / %s tier",
    inactive = "Guidance unavailable in this run mode",
    unreachable = "Target is unreachable this run",
    prerequisite = "Choose the required character or prerequisite run",
    instructional = "This unlock needs a prerequisite or enhanced progress",
    waiting = "Waiting for the room graph to finish generating",
    error = "Planner paused after an internal error",
    choice = "Choice: %s (%s)",
    alternative = "Alternative: %s",
    hold = "Hold/skip: available",
    why = "Why: %s",
    warning = "Warning: %s"
  },
  browser = {
    title = "Run Compass",
    search = "Search: %s",
    empty = "No matching goals",
    eligible = "ELIGIBLE",
    unavailable = "UNAVAILABLE",
    completed = "COMPLETED",
    categoryControls = "LB/RB Category",
    filterControls = "X Filter  Y Status",
    selectControls = "A Select  B Close",
    prerequisites = "Prerequisites",
    supportTier = "Support: %s",
    currentRun = "Current run: %s",
    filters = "kind=%s status=%s letter=%s",
    mcmNotice = "Install Mod Config Menu for bindings and HUD settings"
  }
}

local function format(template, ...)
  local ok, value = pcall(string.format, template, ...)
  return ok and value or template
end

function Strings.get(path, ...)
  local value = Strings
  for segment in string.gmatch(path or "", "[^%.]+") do value = value and value[segment] end
  if type(value) ~= "string" then return path end
  return format(value, ...)
end

return Strings
