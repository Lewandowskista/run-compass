# Run Compass v1.0 Completion Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task with tests and review checkpoints.

**Goal:** Finish the original solo Normal/Hard scope with reliable runtime behavior, complete goal classification, genuine Repentogon progress, bounded route optimization, polished UI, and Workshop validation.

**Architecture:** Keep `main.lua` and the existing public facades stable while splitting adapters, snapshot/visibility, catalog/rules, milestone compilation, planner search/valuation, events, and UI into focused modules. The planner remains deterministic, side-effect free, and the only routing entry point.

**Tech Stack:** Repentance+ Lua 5.3, vanilla Lua APIs, optional Repentogon 1.1.0+, Mod Config Menu, Fengari Lua fixtures, PowerShell packaging.

---

## Ordered workstreams

1. **Runtime stabilization:** canonical room IDs, missing-room guards, real callback dispatch, update/render separation, error throttling, and regression tests for the logged nil-room crash.
2. **Adapters and snapshots:** immutable run/player/floor/progress snapshots, persistent per-room observations, mode detection, capability probes, and read-only Repentogon progress/callback integration.
3. **Fair-play boundary:** filter prohibited topology, secret rooms, Blind identities, Lost map data, and unobserved rewards before planner input; add development assertions.
4. **Catalog and rules:** classify every live collectible; commit a verified versioned achievement rule dataset; resolve prerequisites and cycles; expose catalog diagnostics.
5. **Milestones:** compile boss, unlock, branch, timer, health, key, bomb, card, and quest-item requirements for Hush/Delirium, Mega Satan, Mother, Beast, photo branches, and alternate portals.
6. **Planner:** implement shortest-path graph search plus three-destination beam-width-12 receding horizon, lexicographic scoring, visible pickup valuation, synergy overrides, caching, and 10% hysteresis.
7. **Events/UI/persistence:** dirty-event scheduling, render-only HUD, complete browser filters, original arrow assets, MCM settings, translation-ready strings, schema-v2 saves, diagnostics, and clean packaging.
8. **Validation/release:** split fixture suites, scenario/performance tests, compatibility matrix, 60-minute in-game soak, private 0.9 Workshop candidate, then public 1.0.0.

## Public contracts

`CapabilitySet` exposes tier, version, MCM availability, individual persistent-achievement/completion-mark/precise-callback probes, and diagnostics.

`GameSnapshot` exposes frame/run/player/progress/floor/observations/visibility/capabilities. Room IDs use `SafeGridIndex`; snapshots are deep-copied before planner use and contain no prohibited information.

`GoalDefinition` exposes ID, name, kind, achievement ID, classification, support tier, structured unlock rule, prerequisites, and eligibility.

`Recommendation` exposes status (`ok`, `explore`, `waiting`, `complete`, `inactive`, `unreachable`, `prerequisite_redirect`, `instructional`, `error`), optional door slot, at most three steps, reason codes, confidence, and capability tier.

`Planner.plan(snapshot, goal, previousRecommendation)` remains the only route API consumed by controller/UI and must never mutate game or persisted state.

## Acceptance gates

- No recurring Lua errors during a 60-minute mixed-path in-game soak; the logged nil-room case is covered by a failing-then-passing regression test.
- Every current-version live collectible is classified; unknown future IDs visibly return `catalog_update_required`.
- Base and enhanced capability fallbacks remain safe when Repentogon/MCM are missing or partially incompatible.
- Fair-play fixtures prove secret, Blind, Lost, unseen-reward, and unrevealed-topology data never reaches planning.
- Typical replans remain below 5 ms and worst synthetic floors below 12 ms.
- Output remains stable until meaningful state changes; same-risk alternatives need at least 10% value improvement.
- Keyboard/controller browser, HUD positioning/scaling, MCM settings, save migration, clean package, and private Workshop install all pass before public promotion.

## Release assumptions

V1 does not add co-op, Greed/Greedier, challenges, Victory Laps, or progression-disabled run support. English strings are translation-ready. The mod never grants unlocks, predicts hidden information, mutates run state, or adds telemetry. MCM is the Workshop dependency; Repentogon 1.1.0+ is optional enhanced functionality.
