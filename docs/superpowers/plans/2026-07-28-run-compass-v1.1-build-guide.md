# Run Compass v1.1 Build Guide Implementation

## Objective

Extend the v1.0 route adviser into a goal-aware, fair-play decision guide for every regular and tainted vanilla character in solo Normal/Hard Repentance+ runs. The planner remains deterministic and side-effect free through `Planner.plan(snapshot, goal, previousRecommendation)`.

## Delivered slices

1. **Build snapshots** — normalized immutable collectible, active/charge, trinket (including golden/smelted probes), card, pill, transformation, health, stat, resource, and character/form state.
2. **Visible choices** — stable records for pedestals, options, shops, active replacements, rerolls, pickups, machines, beggars, and sacrifices; Blind and unidentified content is reduced to insufficient information.
3. **Knowledge model** — ItemConfig-backed baseline models plus curated route-critical effects, tags, synergies, anti-synergies, character restrictions, transformation thresholds, goal utility, and conservative unknown-content fallback.
4. **Decision engine** — compares take/buy/replace/hold/reroll/interact/skip actions with lexicographic goal/survival/resource/build ranking, alternatives, warnings, reason codes, and confidence.
5. **Compatibility** — public `RunCompassAPI` registration methods for item models, interaction rules, and character profiles; optional EID descriptions only.
6. **Runtime/UI** — build and choice fingerprints, event invalidation, contextual HUD comparison, marker coordinates, MCM controls, save schema v3 migration, and translation-ready strings.
7. **Release hygiene** — v1.1 metadata, fair-play/build-guide documentation, original HUD assets, package staging, and fixture/performance coverage.

## Verification gates

- `npm.cmd test` passes planner, performance, and build-guide suites.
- Package staging includes only runtime Lua, metadata, README, strings, and graphics.
- In-game validation still required before Workshop promotion: clean install, save continuation, Repentogon/MCM/EID compatibility matrix, and a mixed-character 60-minute soak with no recurring Lua errors or game-state mutation.

## Explicit limitations

Curated rules are intentionally indexed and route-critical rather than an exhaustive pairwise simulation. Every live entry receives a conservative ItemConfig baseline; unknown future/modded entries report `data_update_required`. Hidden identities, future rewards, recipes, and RNG outcomes are never predicted.
