# Run Compass Navigation and Guidance UI Design

## Objective

Replace the prototype goal list and generic exploration output with an organized, controller-friendly goal browser and actionable, goal-aware route/build guidance.

The completed experience must:

- Present the live goal catalog through an organized three-pane browser.
- Display readable target names and current-run eligibility.
- Recommend a specific revealed door even when the final target room is not yet known.
- Evaluate every legitimately visible current-room choice, including treasure-room items.
- Explain route and build advice without exposing hidden information or duplicating EID.
- Keep `Planner.plan(snapshot, goal, previousRecommendation)` as the controller's only planner entry point.

## Observed Problems

### Goal browser

The current browser renders a flat text list with a maximum of ten visible rows. Selection can move beyond the rendered window, filters are represented as terse text, goal details are absent, and the HUD shows internal IDs such as `boss.mega_satan`.

### Route guidance

When a target room is not yet visible, `Planner.plan` returns from its frontier branch before normal path valuation and visible-choice evaluation. It selects the first visible door rather than the best revealed frontier and omits the build decision entirely.

The HUD also requests door coordinates through `Level:GetCurrentRoom()`. The live room object belongs to `Game:GetRoom()`, so the intended door arrow is not positioned in game.

### Build guidance

Visible choices are evaluated only after an exact route candidate succeeds. Consequently, a visible treasure-room pedestal receives no TAKE, REROLL, or SKIP recommendation while the route status is `explore`.

## Player Experience

### Three-pane goal browser

The browser uses the approved three-pane navigator:

1. **Categories** — Boss Routes, Item Unlocks, Completion Marks, and Special/Other.
2. **Goals** — a scrollable, sorted list with status badges.
3. **Details** — prerequisites, required character, unlock method, route requirements, support tier, and current-run eligibility.

The panes remain visible together so players can compare goals without repeated drill-down navigation.

Entries and status counts are derived from the live catalog. Category labels and ordering are presentation definitions; membership, goal names, requirements, and status are not duplicated in the UI.

The selected goal remains visible while scrolling. Switching categories or filters restores a valid highlighted entry and never leaves the cursor outside the rendered window.

### Browser controls

- Controller D-pad navigates within the focused pane.
- LB/RB changes category.
- A selects the highlighted goal.
- B closes the browser or returns focus to the previous pane.
- X opens/cycles contextual filters.
- Y cycles status.
- Keyboard arrows navigate, Enter selects, and Escape closes.
- Keyboard text search supports spaces and punctuation.
- Controller use never requires text input.

### Goal details

The details pane displays:

- Human-readable goal name.
- Goal kind and unlock method.
- Required character and difficulty.
- Prerequisite chain.
- Completion-mark or achievement status when available.
- Base/enhanced support tier.
- Current-run state: eligible, unavailable, completed, prerequisite redirect, instructional, or catalog update required.
- Immediate strategic milestone, such as preserving Angel access for Mega Satan.

After selection, the HUD displays the human-readable name, such as `Mega Satan`, rather than the internal goal ID.

## Gameplay Guidance

### Compact contextual HUD

The approved gameplay layout contains:

- A compact route card anchored to a configurable safe-area position.
- An arrow sprite at the exact recommended door.
- A small action badge over the recommended entity or interaction point.
- A concise visible-choice summary with the strongest reason and warning.

The route card remains visible after the room is clear until the player leaves or performs an action that invalidates the recommendation. It does not auto-fade.

The compact view shows only information required for immediate action:

- Target name and current milestone.
- Recommended direction or room type.
- Important reserved resource or timer warning.
- Recommended visible action: TAKE, BUY, GIVE, REPLACE, HOLD, USE, REROLL, INTERACT, or SKIP.
- Item/choice name, quality when known, strongest synergy or anti-synergy, and confidence.

Expanded reasoning remains available through the configured detail control. EID may continue to show its own complete description.

### Frontier routing

When the target room or branch is not yet revealed, the planner must still produce an actionable recommendation.

It builds frontier candidates from legitimately revealed doors and ranks them using the normal lexicographic priorities:

1. Goal feasibility.
2. Survival risk.
3. Required-resource margin.
4. Goal utility.
5. General build gain.
6. Volatility.
7. Detour and time.

Known treasure rooms, shops, resource rooms, visible pickups, and route milestones may influence the selected frontier. The planner never uses hidden room contents or future RNG.

The recommendation explains uncertainty precisely, for example:

- `Explore east; best revealed frontier`
- `Take the treasure-room detour before continuing`
- `Skip the shop to preserve the Mega Satan key`
- `Preserve Angel chance; target branch not revealed yet`

Generic “explore and replan” text is used only when all legitimately known alternatives are equivalent.

### Visible-choice evaluation

Every actionable planner state, including `explore`, passes through the same recommendation-finalization stage.

That stage:

1. Collects visible choices in the current room.
2. Evaluates them through the build decision engine.
3. Attaches the primary choice, at most two alternatives, and skip/hold advice.
4. Adds the recommended entity position for rendering.
5. Applies confidence and structured reason codes.

Evaluation order remains:

1. Base ItemConfig effects.
2. Character and form modifiers.
3. Owned-build synergies and anti-synergies.
4. Transformation progress.
5. Goal-specific utility.
6. Survival and reserved-resource costs.
7. Replacement and opportunity cost.

Unknown or hidden identities return `insufficient_information`. Unknown modded content uses conservative ItemConfig scoring and `data_update_required`.

### EID relationship

Live ItemConfig quality, tags, type, and Run Compass's internal models determine scores.

EID is optional descriptive enrichment only. EID text:

- Is added after scoring.
- Cannot change an action, score, confidence, or route.
- Cannot reveal Blind or otherwise hidden identities.
- Is omitted when unavailable or when the user disables EID descriptions.

This avoids conflicting score authorities and preserves the established fair-play boundary.

## Architecture

### Browser view model

Add a browser view-model module that converts catalog entries and current snapshot state into:

```lua
BrowserViewModel = {
  categories,
  activeCategory,
  goals,
  selectedIndex,
  scrollOffset,
  selectedGoalDetails,
  filters,
  resultCount
}
```

The view model owns categorization, sorting, status labels, filter options, scroll-window calculation, and goal-detail formatting. The UI owns input and rendering only.

### Recommendation finalization

Refactor planner returns through an internal finalizer:

```lua
finalizeRecommendation(snapshot, goal, recommendation, decisionModels)
```

The function remains internal to `planner.lua` or a focused planner module. It attaches visible-choice decisions, merges milestone reason codes, and applies stable recommendation metadata before returning.

Instructional, inactive, waiting, complete, and error results do not evaluate choices. Actionable `ok` and `explore` results do.

### Frontier candidates

Create focused frontier candidate generation and valuation. The route engine must not select the first door by iteration order.

Each candidate contains:

```lua
FrontierCandidate = {
  doorSlot,
  nextRoomId,
  path,
  expectedRoomValue,
  resourceCost,
  evaluation,
  reasonCodes
}
```

Candidate generation consumes only sanitized snapshot data.

### Rendering

Door positions come from:

```lua
Game:GetRoom():GetDoorSlotPosition(recommendation.nextDoorSlot)
```

The renderer uses original Run Compass sprite assets for:

- Recommended-door arrow.
- TAKE/positive badge.
- Caution/conditional badge.
- SKIP/negative badge.

Text fallback remains available if an asset fails to load, but live releases must include valid PNG and ANM2 assets.

Entity markers use the stable position stored in `ChoiceEvaluation`. Rendering remains read-only and never invokes the planner or scans entities.

### Scheduling and invalidation

Browser view models rebuild when the catalog, progress, target, filters, or current-run eligibility changes.

Route/build recommendations invalidate after:

- Room or floor transition.
- Revealed topology change.
- Pickup, purchase, reroll, or entity removal.
- Affordability or reserved-resource change.
- Inventory, stats, health, transformation, character, actor, or form change.
- Goal change.

Rendering alone never invalidates or rebuilds state.

## Fair Play and Failure Handling

- Secret and super-secret rooms remain excluded from route topology and frontier valuation, including after visitation.
- Unrevealed rooms and future-floor rewards never enter frontier valuation.
- Curse of the Blind strips item identity and all derived values.
- Unidentified pills remain generic.
- EID enrichment occurs only after visibility checks.
- No recipes, seeds, RNG outcomes, portals, or future rewards are predicted.
- Run Compass never grants items, moves the player, opens doors, manipulates achievements, or performs the recommended action.

When guidance cannot be produced, the HUD states the precise reason:

- Current room graph incomplete.
- No revealed frontier.
- Identity hidden.
- Insufficient resources.
- Target unavailable this run.
- Unsupported content or catalog update required.

## Testing

### Browser

- Dynamic category membership and counts.
- Stable sorting and readable labels.
- Lists longer than ten entries.
- Scroll offset keeps selection visible.
- Pane focus and selection preservation.
- Search with spaces and punctuation.
- Controller-only category, list, filter, select, and close flows.
- Goal details, prerequisites, support tier, and eligibility.
- Human-readable HUD target name.

### Planner and decisions

- Ranked frontier choice rather than iteration order.
- Treasure/shop detours versus direct exploration.
- Goal resource and timer reservations.
- `explore` recommendations include `nextDoorSlot`.
- `explore` recommendations include visible-choice decisions.
- Character synergy, owned-item synergy, anti-synergy, transformation threshold, active replacement, reroll, affordability, and skip.
- Recommendation invalidation after every relevant action.
- Hysteresis for equivalent-risk alternatives.
- EID text does not modify scores or actions.

### Rendering

- Door position uses `Game:GetRoom()`.
- Arrow orientation matches every door slot.
- Entity marker uses the evaluated choice position.
- Compact card stays until room transition or decision invalidation.
- HUD anchors respect scale, offset, safe area, and EID coexistence.
- Missing assets use a safe text fallback.

### Fair play and performance

- Blind, Lost, hidden topology, unseen entities, hidden pools, and future RNG never reach evaluation.
- Typical replans remain below 5 ms.
- Worst supported synthetic cases remain below 12 ms.
- Rendering performs no room scan or planning.

## In-Game Acceptance

1. Open the browser and select Mega Satan using only an Xbox controller.
2. Confirm the HUD displays `Mega Satan`.
3. On an early floor, confirm a specific revealed door receives an arrow before the target branch is known.
4. Confirm the route card explains why that frontier or detour is preferred.
5. Enter a treasure room and confirm a visible pedestal receives TAKE, REROLL, or SKIP advice based on the live character and build.
6. Confirm the item marker and compact card remain until leaving or acting.
7. Pick up or reroll the item and confirm stale advice disappears immediately.
8. Confirm EID remains readable and does not alter the recommendation.
9. Continue through room/floor transitions and a save continuation without stale markers or recurring errors.
10. Complete a mixed-path soak with no game-state mutation.

## Completion Criteria

The work is complete when:

- The flat prototype browser is replaced by the approved three-pane navigator.
- Goal names, statuses, prerequisites, and eligibility are readable and dynamic.
- Revealed frontiers are ranked and visibly indicated.
- Actionable `explore` states include build decisions.
- Visible treasure-room items receive explainable, build-aware advice.
- Door and entity markers render at correct live positions.
- Controller navigation works end to end.
- Automated performance and fair-play tests pass.
- The two reported in-game scenarios pass after clean deployment and restart.
