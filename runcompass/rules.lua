local Rules = {}

Rules.version = 1

-- Achievement IDs are intentionally data-driven. The runtime ItemConfig supplies the
-- authoritative collectible/achievement list; this table is extended as Repentance+
-- unlock rules are verified against the current game data.
Rules.unlocks = {
  -- Route-critical rules can be added without changing the planner contract.
}

function Rules.forAchievement(achievementId)
  return Rules.unlocks[achievementId]
end

return Rules
