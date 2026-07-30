# Testing, packaging, and releases

## 1.3.0 — Trustworthy Foundation

- Normalizes observed health, door costs, visible-choice costs, and option alternatives conservatively.
- Keeps unknown prices, hidden identities, unsupported machines, and unsupported reroll comparisons as insufficient information.
- Wires versioned vanilla model/profile/rule data and kind-aware compatibility registration.
- Moves save data to schema v5 and clamps HUD scale to the truthful bitmap range (`1–2`).
- Corrects progress callback names for current Repentogon callback tables.

## 1.2.0 — Actionable Guidance UI

- Replaces the flat goal list with a three-pane, controller-friendly browser.
- Shows readable goal names, prerequisites, support tier, and current-run eligibility.
- Ranks legitimately revealed route frontiers instead of choosing the first door.
- Evaluates visible items during exploratory routing.
- Adds compact persistent route cards, exact door arrows, and TAKE/BUY/REROLL/SKIP markers.
- Keeps EID descriptive-only and preserves the fair-play visibility boundary.

## Local verification

Run the pure Lua fixture, performance, and build-guide suites with:

```powershell
npm.cmd ci
npm.cmd test
```

`npm.cmd test` executes `tests/run.lua`, `tests/performance.lua`, and `tests/build_guide.lua` through Fengari. Keep the planner deterministic and side-effect free; tests should not require a running game client.

## Package validation

Stage a clean Workshop candidate:

```powershell
./scripts/package.ps1 -OutputPath C:\tmp\run-compass-public-package
```

The script removes stale output, refuses to package inside the source tree, and copies only runtime files/assets: `main.lua`, `metadata.xml`, `README.md`, `runcompass/`, optional `strings/`, and runtime `gfx/`. Tests, docs, images, plans, node modules, and local tooling stay in the repository and are excluded from Workshop output.

Before promotion, verify:

1. `git diff --check` is clean and `npm.cmd test` passes.
2. A clean install and save-continuation run works with Mod Config Menu.
3. The base, Repentogon 1.1.0+, and EID combinations load without recurring Lua errors.
4. A mixed regular/tainted-character Normal/Hard soak (60 minutes) shows no game-state mutation and no repeated errors.
5. Unsupported modes (Greed, challenges, Victory Laps, co-op, and progression-disabled custom runs) remain visibly inactive.

Publish one verified package for the version declared in `metadata.xml`; do not promote incomplete increments. Record user-facing changes in the repository release notes and keep compatibility/model additions source-tagged.
