# Run Compass Repository Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Publish a professional Observatory-themed public GitHub repository for Run Compass without changing runtime behavior.

**Architecture:** Keep runtime Lua and Workshop assets untouched except for documentation links. Add repository-facing Markdown under `docs/`, generated artwork under `docs/images/`, and GitHub metadata under `.github/`. The README becomes the public landing page and links to focused guides.

**Tech Stack:** Markdown, PNG artwork generated with the built-in image tool, GitHub Actions YAML, PowerShell/npm fixture commands.

---

### Task 1: Repository hygiene and landing-page content

**Files:**
- Modify: `.gitignore`
- Modify: `README.md`
- Modify: `metadata.xml`
- Create: `docs/INSTALLATION.md`, `docs/CONTROLS.md`, `docs/FAIR_PLAY.md`, `docs/COMPATIBILITY.md`, `docs/RELEASES.md`

- [ ] Add `.superpowers/` and generated local packaging directories to `.gitignore`.
- [ ] Rewrite `README.md` with the Observatory hero, badges, feature cards, install matrix, first-run walkthrough, controls, fair-play methodology, API example, tests, and links to the focused docs.
- [ ] Keep all claims bounded: visible-information advice, conservative fallback, optional dependencies, and no guaranteed optimal play.
- [ ] Add focused docs with concrete commands and current v1.1 behavior.
- [ ] Run `git diff --check` and inspect rendered Markdown links locally.

### Task 2: Generate and validate repository artwork

**Files:**
- Create: `docs/images/run-compass-observatory-hero.png`
- Create: `docs/images/run-compass-observatory-mark.png`
- Create: `docs/images/run-compass-observatory-icon.png`

- [ ] Generate the wide hero using the built-in image generator with midnight blue, chartreuse route beam, compass/radar geometry, no copied game assets, and no text that must be typeset by the model.
- [ ] Generate a square social mark and a small monochrome icon in the same visual language.
- [ ] Inspect each generated image and copy final assets into `docs/images/`.
- [ ] Reference the hero and mark from `README.md` using repository-relative paths.

### Task 3: GitHub contribution and CI presentation

**Files:**
- Create: `.github/workflows/test.yml`
- Create: `.github/ISSUE_TEMPLATE/bug_report.yml`
- Create: `.github/ISSUE_TEMPLATE/compatibility-model.yml`
- Create: `.github/pull_request_template.md`

- [ ] Add a Windows GitHub Actions job that runs `npm.cmd ci` and `npm.cmd test` on pushes and pull requests.
- [ ] Add actionable issue forms for runtime bugs and compatibility/model contributions.
- [ ] Add a concise pull-request checklist covering fair-play, tests, packaging, and no game-state mutation.

### Task 4: Verify, commit, and publish

**Files:**
- Modify: all files above as needed after verification.

- [ ] Run `npm.cmd test` and confirm planner, performance, and build-guide suites pass.
- [ ] Run `git diff --check` and `scripts/package.ps1 -OutputPath C:\tmp\run-compass-public-package`.
- [ ] Confirm the package contains only runtime Lua, metadata, README, and graphics.
- [ ] Commit the presentation changes on `main` with a descriptive message.
- [ ] Create public `Lewandowskista/run-compass` with `gh repo create --public --source . --remote origin --push`.
- [ ] Verify the remote URL, default branch, visibility, latest commit, and public README through `gh repo view`.
