# Compatibility and data API

## Supported tiers

| Tier | Detection | Behavior |
| --- | --- | --- |
| Base | No compatible Repentogon (Mod Config Menu optional/recommended) | Visible-information routing and conservative catalog baseline; safe defaults apply without MCM. |
| Enhanced | Repentogon `1.1.0+` detected | Adds persistent achievement/completion reads and richer callbacks when each API is present. |

The capability probe is feature-by-feature. If a function or callback is missing, only that enhancement is disabled and diagnostics explain why. EID is an optional description provider and never contributes scores, identities, or route facts.

## Registration API

`RunCompassAPI` is published globally after the mod initializes. Registration returns `true` for valid records and `false` for malformed inputs.

```lua
RunCompassAPI:RegisterItemModel("my-mod", "collectible", 9001, {
  effects = { offense = 2 },
  tags = { damage = true }
})

RunCompassAPI:RegisterInteractionRule("my-mod", {
  id = "my-mod:synergy:100:9001",
  candidate = 9001,
  owned = 100,
  effects = { bossDamage = 1 }
})

RunCompassAPI:RegisterCharacterProfile("my-mod", "my_character", {
  effects = { defense = 1 }
})
```

`modId` and character tokens must be strings. Item ids and interaction candidates must be non-nil. Models and profiles are tables; interaction rules need a `candidate`. Records are source-tagged with `modId` so diagnostics can identify their origin.

## Contribution guidance

Prefer small, explainable effects and explicit interaction rules over opaque score overrides. Do not use this API to reveal hidden identities or future rooms. Add fixture coverage for a new model, run `npm.cmd test`, and describe the observed in-game version and optional dependencies in the pull request. Route-critical vanilla unlock rules belong in the versioned `runcompass/rules.lua` catalog.
