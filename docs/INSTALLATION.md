# Installation

## Workshop install

1. Install **Mod Config Menu** (recommended for settings). Install **Repentogon 1.1.0+** only if you want the enhanced progress tier; EID is optional. Without Mod Config Menu, base routing still runs with safe defaults and shows a notice.
2. Subscribe to or copy the Run Compass [REP+] Workshop package into `repentance/mods/run-compass`.
3. Enable the mod in the in-game Mods menu and start a solo Normal or Hard run.
4. Open Mod Config Menu → **Run Compass** to set goal-browser and guidance bindings, HUD placement, and explanation preferences.

The package is self-contained: `main.lua`, `metadata.xml`, `runcompass/`, runtime `gfx/`, and optional `strings/`. Repository guides and Observatory images are documentation-only and are not copied into the game mod folder.

## Local checkout

From the repository root:

```powershell
npm.cmd ci
npm.cmd test
./scripts/deploy.ps1 -GamePath "C:\Program Files (x86)\Steam\steamapps\common\The Binding of Isaac Rebirth"
```

Use a different `-GamePath` when Steam is installed elsewhere. To make a clean distributable instead of deploying directly:

```powershell
./scripts/package.ps1 -OutputPath C:\tmp\run-compass-public-package
```

The package script removes an existing output directory after validating it is not the source tree. Review the resulting directory before Workshop upload.

## Dependency matrix

| Setup | Routing | Progress reads | Descriptions |
| --- | --- | --- | --- |
| Vanilla without Mod Config Menu | Base, visible-information routing with safe defaults | Base catalog only | Built-in strings plus an in-game notice |
| Vanilla + Mod Config Menu | Base, visible-information routing with configurable settings | Base catalog only | Built-in strings |
| + Repentogon 1.1.0+ | Base plus enhanced callbacks | Persistent achievements/completion marks when each API exists | Built-in strings |
| + EID | Same as above | Same as above | EID text only |

Missing optional APIs disable only the affected enhancement and are reported by `runcompass status`; the planner does not guess a replacement.
