# Run Compass [REP+]

Run Compass is a fair-play route and build decision guide for solo Normal and Hard runs in The Binding of Isaac: Repentance+.

Select a target such as Delirium, Mother, The Beast, Mega Satan, or a vanilla collectible unlock. After rooms are clear, Run Compass highlights the next door, visible worthwhile pickup, or interaction and explains the next few steps. It reacts to room transitions, pickups, damage, purchases, inventory changes, resources, timers, rerolls, actor/form changes, and branch choices.

## Build guide

The guide evaluates every legitimately visible choice it can normalize: collectibles and active replacements, trinkets, cards/runes, identified pills, shop purchases, rerolls, pickups, machines, beggars, sacrifices, and hold/skip decisions. It compares the primary action with up to two alternatives and a skip/hold option using this order: goal feasibility, survival, reserved-resource margin, goal utility, build gain, volatility, then detour/time. Explanations include owned-item synergies, character modifiers, anti-synergies, transformation thresholds, active replacement loss, timer tradeoffs, and low-confidence expected value.

Curated models cover route-critical vanilla families and all regular/tainted character tokens. Every live ItemConfig entry still receives a conservative quality/tag baseline. Future or unmodeled content is explicitly marked `data_update_required`; Blind pedestals, unidentified pills, hidden pools, future-room rewards, and RNG outcomes are never guessed.

Compatibility packs may extend the model without changing the planner contract:

```lua
RunCompassAPI:RegisterItemModel("my-mod", "collectible", 9001, { effects = { offense = 2 } })
RunCompassAPI:RegisterInteractionRule("my-mod", { candidate = 9001, owned = 100, effects = { bossDamage = 1 } })
RunCompassAPI:RegisterCharacterProfile("my-mod", "my_character", { effects = { defense = 1 } })
```

EID is optional descriptive enrichment only. It never supplies scores, hidden identities, or route facts.

The base catalog discovers every live collectible from `ItemConfig`. Route-critical unlock rules are versioned in `runcompass/rules.lua`; future or counter-based rules are deliberately labeled `catalog update required` or `Repentogon required` instead of being guessed.

## Dependencies

- Mod Config Menu is the Workshop configuration dependency.
- REPENTOGON is optional. When detected at version 1.1.0 or newer, it enables persistent unlock/completion progress and richer event callbacks.

## Fair-play rules

Run Compass does not reveal secret rooms, unseen rewards, Curse of the Blind pedestal identities, or Curse of the Lost topology. It never changes rooms, pickups, seeds, achievements, or player state.

Version 1.1 supports solo Normal/Hard routing and visible build decisions for every regular and tainted vanilla character. Greed, challenges, Victory Laps, co-op, and progression-disabled custom runs are marked inactive. Repentogon 1.1.0+ is probed feature-by-feature; missing APIs only disable the affected enhanced capability.

## Release validation

The release candidate is staged with `scripts/package.ps1`. It removes stale staging output, copies only runtime files, and excludes tests and development plans. Before Workshop promotion, run the fixture suite, perform a clean install/save-continuation check, and complete the documented 60-minute mixed-character soak. v1.1 is released once as one verified public package; no incomplete public increments are published.

Use `runcompass catalog` in the in-game console for catalog totals and unmapped-achievement diagnostics, and `runcompass status` for capability and selected-goal state.

## Development

Run pure Lua fixtures with:

```powershell
npm.cmd test
```

Deploy a local copy with `scripts/deploy.ps1 -GamePath "C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth"`.

The Workshop package contains `main.lua`, `runcompass/`, `metadata.xml`, and runtime assets. Tests and development tooling are excluded.
