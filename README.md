# Run Compass [REP+]

![Run Compass Observatory](https://raw.githubusercontent.com/Lewandowskista/run-compass/main/docs/images/run-compass-observatory-hero.png)
<img src="https://raw.githubusercontent.com/Lewandowskista/run-compass/main/docs/images/run-compass-observatory-mark.png" alt="Run Compass Observatory mark" width="96" align="right">

[![Version 1.1.0](https://img.shields.io/badge/version-1.1.0-8be04e?style=flat-square&labelColor=101b33)](metadata.xml)
[![Tests](https://img.shields.io/badge/tests-fengari%20fixtures-8be04e?style=flat-square&labelColor=101b33)](docs/RELEASES.md)
[![Fair play](https://img.shields.io/badge/fair--play-visible%20information-8be04e?style=flat-square&labelColor=101b33)](https://github.com/Lewandowskista/run-compass/blob/main/docs/FAIR_PLAY.md)

Run Compass is an Observatory for **The Binding of Isaac: Repentance+**: a fair-play route and build guide for solo Normal and Hard runs. Pick a boss or vanilla unlock, then get a compact next-door and visible-choice recommendation as the floor reveals itself. It is a decision aid, not an oracle—there is no guaranteed optimal play.

[Install](https://github.com/Lewandowskista/run-compass/blob/main/docs/INSTALLATION.md) · [Controls](https://github.com/Lewandowskista/run-compass/blob/main/docs/CONTROLS.md) · [Fair-play method](https://github.com/Lewandowskista/run-compass/blob/main/docs/FAIR_PLAY.md) · [Compatibility API](https://github.com/Lewandowskista/run-compass/blob/main/docs/COMPATIBILITY.md) · [Releases](https://github.com/Lewandowskista/run-compass/blob/main/docs/RELEASES.md)

## What the Observatory sees

| Route lens | Choice lens |
| --- | --- |
| Replans over revealed rooms toward Delirium, Mother, The Beast, Mega Satan, Hush, and other supported goals. | Compares take, buy, replace, reroll, interact, hold, or skip for visible pedestals, shops, machines, beggars, sacrifices, and pickups. |
| Keeps timers and reserved resources in view while choosing a bounded path. | Explains goal utility, survival, synergies, anti-synergies, transformations, replacement loss, volatility, and confidence. |

**Fair-play filter.** Secret rooms, unseen rewards, Blind identities, Lost topology, future pools, and RNG outcomes are never inferred. Unknown or future content is labeled `data_update_required` or `Repentogon required` and falls back conservatively.

**Dynamic replanning.** Room transitions, pickups, damage, purchases, inventory changes, resources, rerolls, actor/form changes, and branch choices invalidate the previous recommendation. Rendering only presents the latest plan; it never mutates game state.

## Install and dependencies

| Component | Install role | What it provides |
| --- | --- | --- |
| The Binding of Isaac: Repentance+ | Yes | Runtime and vanilla `ItemConfig` catalog. |
| Mod Config Menu | Recommended settings dependency | Goal/browser keybinds, HUD placement, detail, warnings, and comparison settings; without it, base routing uses safe defaults and shows a notice. |
| Repentogon 1.1.0+ | Optional | Enhanced tier: persistent unlock/completion progress and richer callbacks, probed feature-by-feature. |
| EID | Optional | Descriptions only; never scores, reveals identities, or supplies route facts. |

Install the Workshop package, enable Run Compass, and start a solo Normal/Hard run. Mod Config Menu is recommended for settings; base routing still runs without it using safe defaults and an in-game notice. For a local checkout, see the [installation guide](https://github.com/Lewandowskista/run-compass/blob/main/docs/INSTALLATION.md), including `scripts/deploy.ps1` and package staging.

## First run: a two-minute route

1. Open the Run Compass goal browser (configure its keyboard/controller binding in Mod Config Menu) and choose a target such as `boss.delirium`.
2. Clear a room. The HUD shows the selected target, the next revealed door, and a short list of visible actions; a diamond marks the primary visible choice when one is available.
3. Take the action you want, or hold/skip it. The guide recomputes after the next event and preserves a margin for required keys, bombs, coins, health, or timers.
4. Use `runcompass status` to inspect the capability tier and selected goal, or `runcompass catalog` to inspect catalog totals and unmapped-achievement diagnostics.

The HUD is hidden while a room is uncleared unless **Pinned** is enabled. A recommendation can be instructional (for example, a goal requiring Repentogon) rather than pretending it can route an unsupported state.

## Controls and settings

The [controls guide](https://github.com/Lewandowskista/run-compass/blob/main/docs/CONTROLS.md) lists keyboard browser navigation, currently supported controller D-pad/X/Y navigation, configured browser/toggle bindings, console commands, and every Mod Config Menu setting. Keyboard text search uses letter keys; controller text entry is not assumed. Keyboard and controller bindings are editable; defaults are stored as game input codes so they survive save migration. HUD visibility, pinning, scale, X/Y offset, automatic comparisons, detail level (1–3), confidence, warnings, diagnostics, and EID text are all opt-in/configurable.

## Fair-play methodology

Run Compass consumes normalized observations only: revealed room topology, visible entities, known inventory/resources, and callbacks the current capability tier actually exposes. Its bounded planner ranks goal feasibility, survival, reserved-resource margin, goal utility, build gain, volatility, then detour/time. Confidence and warnings travel with the explanation. Read the [methodology](https://github.com/Lewandowskista/run-compass/blob/main/docs/FAIR_PLAY.md) before using it for challenge or speedrun practice.

## Extend the model

Mods can add conservative, source-tagged data through the public `RunCompassAPI` without replacing the planner contract:

```lua
RunCompassAPI:RegisterItemModel("my-mod", "collectible", 9001, {
  effects = { offense = 2 },
  tags = { damage = true }
})
RunCompassAPI:RegisterInteractionRule("my-mod", {
  candidate = 9001,
  owned = 100,
  effects = { bossDamage = 1 }
})
RunCompassAPI:RegisterCharacterProfile("my-mod", "my_character", {
  effects = { defense = 1 }
})
```

See [COMPATIBILITY.md](https://github.com/Lewandowskista/run-compass/blob/main/docs/COMPATIBILITY.md) for validation behavior, model fields, and contribution guidance. Every live collectible still receives an `ItemConfig` baseline; curated route-critical rules remain versioned in `runcompass/rules.lua`.

## Test, package, release

```powershell
npm.cmd ci
npm.cmd test
./scripts/package.ps1 -OutputPath C:\tmp\run-compass-public-package
```

The fixture, performance, and build-guide suites are described in the [release guide](https://github.com/Lewandowskista/run-compass/blob/main/docs/RELEASES.md). Workshop packaging copies only runtime files and assets; repository guides and Observatory presentation images remain available in GitHub. Before promotion, perform a clean install/save-continuation check and the documented mixed-character soak.

## Scope

Version 1.1 targets solo Normal/Hard routing and visible build decisions for every regular and tainted vanilla character. Greed, challenges, Victory Laps, co-op, and progression-disabled custom runs are marked inactive. Run Compass never changes rooms, pickups, seeds, achievements, or player state.
