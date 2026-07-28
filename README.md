# Run Compass [REP+]

Run Compass is a fair-play route adviser for solo Normal and Hard runs in The Binding of Isaac: Repentance+.

Select a target such as Delirium, Mother, The Beast, Mega Satan, or a vanilla collectible unlock. After rooms are clear, Run Compass highlights the next door and explains the next few steps. It reacts to room transitions, pickups, damage, purchases, inventory changes, resources, timers, and branch choices.

The base catalog discovers every live collectible from `ItemConfig`. Route-critical unlock rules are versioned in `runcompass/rules.lua`; future or counter-based rules are deliberately labeled `catalog update required` or `Repentogon required` instead of being guessed.

## Dependencies

- Mod Config Menu is the Workshop configuration dependency.
- REPENTOGON is optional. When detected at version 1.1.0 or newer, it enables persistent unlock/completion progress and richer event callbacks.

## Fair-play rules

Run Compass does not reveal secret rooms, unseen rewards, Curse of the Blind pedestal identities, or Curse of the Lost topology. It never changes rooms, pickups, seeds, achievements, or player state.

Version 1.0 supports solo Normal/Hard routing. Greed, challenges, Victory Laps, co-op, and progression-disabled custom runs are marked inactive. Repentogon 1.1.0+ is probed feature-by-feature; missing APIs only disable the affected enhanced capability.

## Release validation

The release candidate is staged with `scripts/package.ps1`. It removes stale staging output, copies only runtime files, and excludes tests and development plans. Before Workshop promotion, run the fixture suite, perform a clean install/save-continuation check, and complete the documented 60-minute mixed-path soak. Version 0.9 is intended for private/unlisted validation; the verified source state is then promoted to 1.0.0.

Use `runcompass catalog` in the in-game console for catalog totals and unmapped-achievement diagnostics, and `runcompass status` for capability and selected-goal state.

## Development

Run pure Lua fixtures with:

```powershell
npm.cmd test
```

Deploy a local copy with `scripts/deploy.ps1 -GamePath "C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth"`.

The Workshop package contains `main.lua`, `runcompass/`, `metadata.xml`, and runtime assets. Tests and development tooling are excluded.
