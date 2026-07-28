# Controls and HUD

When Mod Config Menu is installed, bindings can be changed in **Run Compass → General**. Without it, base routing still runs on safe defaults and shows a one-time notice. The saved defaults are keyboard input codes `117` (goal browser) and `118` (toggle guidance), plus controller codes `10` and `13`; use the named input picker rather than relying on numeric codes when rebinding.

## Goal browser

With the browser open:

- **Up/Down** (or controller D-pad up/down) moves the selection.
- **Enter** selects the highlighted goal; **Escape** closes the browser.
- **Backspace** edits the search; letter keys and **Space** add to it.
- **Tab** (controller **X**) cycles kind: all, boss, collectible.
- **S** (controller **Y**) cycles status: all, locked, already unlocked, instructional only, catalog update required.
- **L** cycles the alphabetical letter filter.

Controller navigation currently covers D-pad up/down plus **X** (kind filter) and **Y** (status filter). Text search and text editing use the keyboard; controller text entry is not assumed.

## Guidance HUD

After a room is clear, the HUD shows the target, short route steps, and a next-door arrow. A diamond marks the primary visible choice when comparisons are enabled. **Toggle guidance** switches the HUD's pinned state; when unpinned, the recommendation is suppressed in uncleared rooms. **Pinned** and **HUD enabled** are separate settings.

Available settings include scale (`0.5–2`), X/Y offsets, automatic comparisons, detail level (`1–3`), confidence and warning text, developer diagnostics, and optional EID descriptions.

## Console

Use the in-game console command prefix `runcompass`:

```text
runcompass status
runcompass catalog
runcompass boss.delirium
```

`status` prints the capability tier and selected goal. `catalog` prints the rules version, total/classified entries, unknown entries, and invalid entries. Supplying a goal id selects it directly; unsupported or unknown arguments print the usage line.
