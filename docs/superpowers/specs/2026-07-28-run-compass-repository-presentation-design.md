# Run Compass Repository Presentation Design

## Goal

Present Run Compass as a polished, trustworthy open-source companion for The Binding of Isaac: Repentance+. The repository should communicate the fair-play boundary, the route/build-guide value, and the path from installation to contribution within the first screen of the README.

## Visual direction: Observatory

- Midnight blue foundation with warm chartreuse route accents.
- Minimal compass/radar mark and a single directional beam.
- Precise tactical typography and generous negative space.
- Original artwork only; no copied Isaac sprites, game UI, or copyrighted character art.
- The in-game arrow asset remains a separate runtime asset and is not replaced by README branding.

## README information architecture

1. Hero banner, project promise, version/dependency badges, and quick links.
2. Feature cards covering goal routing, visible build choices, fair-play filtering, and dynamic replanning.
3. Installation and dependency matrix for vanilla, Repentogon, EID, and MCM.
4. First-run walkthrough with a short example route.
5. Controls, HUD behavior, settings, and supported/unsupported modes.
6. Fair-play methodology and confidence language.
7. Compatibility API examples and contribution/data-model guidance.
8. Testing, packaging, release validation, and release notes.

## Repository support files

- `docs/INSTALLATION.md`, `docs/CONTROLS.md`, `docs/FAIR_PLAY.md`, `docs/COMPATIBILITY.md`, and `docs/RELEASES.md`.
- `docs/images/` for generated hero, social mark, and monochrome icon assets.
- GitHub issue templates for bug reports and compatibility/model contributions.
- GitHub Actions workflow running the fixture/performance suite.
- `.superpowers/` ignored as local visual-companion state.

## Constraints and validation

- Do not expose hidden game information or imply guaranteed optimal play.
- Keep Workshop packaging limited to runtime files and assets.
- Preserve the existing Lua contracts and tests.
- Validate generated assets visually, run `npm.cmd test`, run `git diff --check`, and verify the public repository contents after pushing.
