local GuideData = {}

GuideData.version = "1.1.0"

-- IDs here are route/build-critical overrides. Every other live ItemConfig
-- entry receives a conservative quality/tag baseline in ItemModels.fromCatalog.
GuideData.items = {
  [68] = { effects = { offense = 2, bossDamage = 2 }, tags = { technology = true, tear = true } },
  [114] = { effects = { offense = 3, bossDamage = 4 }, tags = { knife = true, tear = true }, antiSynergies = { { owned = 330, effects = { offense = -2 }, id = "mom_knife_soy_milk" } } },
  [116] = { effects = { activeUtility = 2, economy = 1 }, tags = { battery = true } },
  [118] = { effects = { offense = 3, bossDamage = 4 }, tags = { beam = true, tear = true } },
  [152] = { effects = { offense = 2, bossDamage = 3 }, tags = { technology = true, tear = true } },
  [182] = { effects = { offense = 4, defense = 2, bossDamage = 4 }, tags = { homing = true, tear = true } },
  [247] = { effects = { offense = 1, defense = 1 }, tags = { familiar = true, synergy_family = "familiar" } },
  [273] = { effects = { defense = 4, sustain = 3 }, tags = { explosive_immunity = true } },
  [330] = { effects = { offense = 2, tearRate = 3 }, tags = { tear = true, rapid_fire = true } },
  [356] = { effects = { activeUtility = 4, routeAccess = 1 }, tags = { battery = true } }
}

GuideData.characterProfiles = {
  isaac = { id = "character:isaac", effects = { offense = 0.2 } },
  azazel = { id = "character:azazel", effects = { bossDamage = 0.5, routeAccess = 1 } },
  keeper = { id = "character:keeper", effects = { economy = 2, defense = -0.5 } },
  the_lost = { id = "character:lost", effects = { defense = 1 } },
  tainted_lost = { id = "character:tainted_lost", effects = { defense = 2, volatility = 1 } },
  bethany = { id = "character:bethany", effects = { activeUtility = 1 } },
  tainted_isaac = { id = "character:tainted_isaac", effects = { economy = 0.5 } },
  tainted_lazarus = { id = "character:tainted_lazarus", effects = { activeUtility = 1, volatility = 1 } },
  jacob_and_esau = { id = "character:jacob_and_esau", effects = { defense = -0.5, offense = 0.5 } }
}

local allCharacters = {
  "isaac", "magdalene", "cain", "judas", "blue_baby", "eve", "samson", "azazel", "lazarus", "eden", "the_lost", "lilith", "keeper", "apollyon", "the_forgotten", "bethany", "jacob_and_esau",
  "tainted_isaac", "tainted_magdalene", "tainted_cain", "tainted_judas", "tainted_blue_baby", "tainted_eve", "tainted_samson", "tainted_azazel", "tainted_lazarus", "tainted_eden", "tainted_lost", "tainted_lilith", "tainted_keeper", "tainted_apollyon", "tainted_forgotten", "tainted_bethany", "tainted_jacob"
}
for _, token in ipairs(allCharacters) do
  if not GuideData.characterProfiles[token] then GuideData.characterProfiles[token] = { id = "character:" .. token, effects = {} } end
end

return GuideData
