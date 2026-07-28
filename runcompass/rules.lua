local Rules = {}

Rules.version = 2

-- Current-run-observable rules. Persistent counters remain instructional until
-- Repentogon can verify them safely.
Rules.unlocks = {
  [43] = { itemId = 114, matchKinds = { "satan" }, requiredCharacterToken = "isaac", displayRule = "Defeat Satan as Isaac" },
  [57] = { itemId = 327, matchKinds = { "isaac" }, displayRule = "Defeat Isaac (five total clears)" },
  [58] = { itemId = 175, status = "instructional", supportTier = "enhanced", requiredCapability = "enhanced", displayRule = "Collect both Angel key pieces in one run" },
  [78] = { itemId = 328, matchKinds = { "satan" }, displayRule = "Defeat Satan (five total clears)" },
  [156] = { itemId = 331, status = "instructional", supportTier = "enhanced", requiredCapability = "enhanced", displayRule = "Complete every Hard mark as The Lost" },
  [186] = { itemId = 399, matchKinds = { "hush" }, requiredCharacterToken = "azazel", displayRule = "Defeat Hush as Azazel" },
  [338] = { itemId = 510, matchKinds = { "delirium", "void" }, displayRule = "Defeat Delirium" },
  [440] = { itemId = 631, matchKinds = { "mother" }, requiredCharacterToken = "isaac", displayRule = "Defeat Mother as Isaac" },
  [441] = { itemId = 670, matchKinds = { "beast" }, requiredCharacterToken = "isaac", displayRule = "Defeat The Beast as Isaac" },
  [442] = { itemId = 639, matchKinds = { "mother" }, requiredCharacterToken = "magdalene", displayRule = "Defeat Mother as Magdalene" },
  [443] = { itemId = 671, matchKinds = { "beast" }, requiredCharacterToken = "magdalene", displayRule = "Defeat The Beast as Magdalene" },
  [444] = { itemId = 665, matchKinds = { "mother" }, requiredCharacterToken = "cain", displayRule = "Defeat Mother as Cain" },
  [445] = { itemId = 672, matchKinds = { "beast" }, requiredCharacterToken = "cain", displayRule = "Defeat The Beast as Cain" },
  [446] = { itemId = 641, matchKinds = { "mother" }, requiredCharacterToken = "judas", displayRule = "Defeat Mother as Judas" },
  [447] = { itemId = 673, matchKinds = { "beast" }, requiredCharacterToken = "judas", displayRule = "Defeat The Beast as Judas" },
  [470] = { itemId = 643, matchKinds = { "mother" }, requiredCharacterToken = "bethany", displayRule = "Defeat Mother as Bethany" },
  [501] = { itemId = 691, matchKinds = { "beast" }, status = "instructional", supportTier = "enhanced", requiredCapability = "enhanced", displayRule = "Defeat The Beast as Tainted The Lost" }
}

function Rules.forAchievement(achievementId)
  return Rules.unlocks[achievementId]
end

return Rules
