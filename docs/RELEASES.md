# Testing, packaging, and releases

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

The script removes stale output, refuses to package over the source tree, and copies only runtime files: `main.lua`, `metadata.xml`, `README.md`, `runcompass/`, optional `strings/`, and runtime `gfx/`. Tests, docs, plans, and local tooling are excluded.

Before promotion, verify:

1. `git diff --check` is clean and `npm.cmd test` passes.
2. A clean install and save-continuation run works with Mod Config Menu.
3. The base, Repentogon 1.1.0+, and EID combinations load without recurring Lua errors.
4. A mixed regular/tainted-character Normal/Hard soak (60 minutes) shows no game-state mutation and no repeated errors.
5. Unsupported modes (Greed, challenges, Victory Laps, co-op, and progression-disabled custom runs) remain visibly inactive.

Publish one verified package for the version declared in `metadata.xml`; do not promote incomplete increments. Record user-facing changes in the repository release notes and keep compatibility/model additions source-tagged.
