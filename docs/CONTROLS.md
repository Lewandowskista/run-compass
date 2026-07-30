# Controls and HUD

When Mod Config Menu is installed, bindings can be changed in **Run Compass → General**. Without it, base routing still runs on safe defaults and shows a one-time notice. The default keyboard bindings are **F6** (goal browser), **F7** (toggle guidance), and **F8** (guidance details, hold to expand the card); the default controller bindings are left stick click (goal browser), right stick click (toggle guidance), and right bumper (guidance details). All are rebindable in MCM via the named input picker.

## Goal browser

Opening the browser shows three panes: **categories** on the left, the **goal list** in the middle, and **details** (readable name, prerequisites, support tier, and current-run eligibility) on the right. Navigation moves within whichever pane is focused:

- **Up/Down** (or controller D-pad up/down) moves the selection within the focused pane — goals in the goal list, categories in the category pane, or scrolls the details text when details is focused.
- **Left/Right** (or controller D-pad left/right) switches focus between the categories, goals, and details panes.
- Controller **LB/RB** (or **LT/RT**) cycle categories directly from any pane.
- **Enter** (controller **A**) selects the highlighted goal; **Escape** (controller **B**) closes the browser.
- **Tab** (controller **X**) cycles the kind filter: all, boss, collectible.
- **S** (controller **Y**) cycles the status filter: all, locked, already unlocked, instructional only, catalog update required.
- **L** cycles the alphabetical letter filter.
- **Backspace** edits the search; letter keys, **Space**, and punctuation (`-`, `'`, `,`, `.`, `/`) all add to it. The goal list scrolls to fit more than ten entries.

Controller navigation covers D-pad movement within and across panes, **LB/RB** for category cycling, **A** to select, **B** to close, **X** for the kind filter, and **Y** for the status filter. Text search and text editing use the keyboard; controller text entry is not assumed.

## Guidance HUD

After a room is clear, the HUD shows a compact card: the target's readable name, the top route step, the strongest reason for the recommendation, and an action label (`TAKE`, `BUY`, `REROLL`, or `SKIP`) in four lines or fewer. The HUD never shows internal goal or item IDs. Holding the **guidance details** binding (keyboard default `119`; controller default button `11`) expands the card with additional steps. **Toggle guidance** switches the HUD's pinned state; when unpinned, the recommendation is suppressed in uncleared rooms. **Pinned** and **HUD enabled** are separate settings.

A door arrow points to the next legitimately revealed door using its live in-room position, and a marker (`TAKE`, `CAUTION`, `SKIP`, or `REROLL`) appears over the visible pedestal, shop item, or interactable the recommendation is evaluating.

Available settings include scale (`1–2`), X/Y offsets, automatic comparisons, detail level (`1–3`), confidence and warning text, developer diagnostics, and optional EID descriptions. EID text remains descriptive-only; when an item's identity is hidden (Curse of the Blind), Run Compass shows no advice and EID shows no text for it.

## Console

Use the in-game console command prefix `runcompass`:

```text
runcompass status
runcompass catalog
runcompass boss.delirium
```

`status` prints the capability tier and selected goal. `catalog` prints the rules version, total/classified entries, unknown entries, and invalid entries. Supplying a goal id selects it directly; unsupported or unknown arguments print the usage line.
