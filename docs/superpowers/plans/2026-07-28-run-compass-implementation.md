# Run Compass [REP+] Implementation Plan

> **For agentic workers:** Implement task-by-task with tests before production code and verify the packaged mod before release.

**Goal:** Build a fair-play dynamic route adviser for solo Normal/Hard Repentance+ runs.

**Architecture:** Pure Lua domain modules are driven by vanilla/Repentogon adapters and consumed by an event-driven controller plus MCM/HUD presentation. The route engine searches only revealed topology and observed information.

**Tech Stack:** Repentance+ Lua 5.3, optional Repentogon 1.1+, Mod Config Menu, Lua fixtures executed with `fengari-node-cli`.

---

1. Create the versioned goal/catalog contracts and failing tests.
2. Implement fair-play filtering, graph search, scoring, and hysteresis.
3. Implement capability adapters, normalized events, save migration, and controller integration.
4. Implement goal browser, HUD arrow, MCM settings, strings, metadata, and deployment tooling.
5. Run fixture/integration checks, package smoke tests, and prepare the Workshop upload.
