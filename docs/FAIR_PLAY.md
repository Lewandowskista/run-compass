# Fair-play methodology

Run Compass is intentionally bounded by what a player can observe in the current run. It is useful for route practice and build decisions, but it does not promise an optimal line.

## Inputs the planner may use

- Revealed rooms, doors, room-clear state, floor/stage, timers, and visible entities.
- Observed pickups, shop prices, machines, beggars, sacrifices, rerolls, active replacements, cards, trinkets, identified pills, inventory, health, and resources.
- Character/form state and callbacks available in the detected capability tier.
- Curated vanilla models plus a conservative `ItemConfig` quality/tag baseline.

## Inputs it refuses to invent

Secret rooms, unseen rewards, hidden item-pool contents, Curse of the Blind identities, Curse of the Lost topology, future-room rewards, recipes, and RNG outcomes are not passed to the planner. Unknown or future catalog entries are surfaced as `data_update_required`; goals that need enhanced progress APIs are instructional until Repentogon is available.

## Decision order and confidence

For visible choices, the guide compares the primary action with alternatives and hold/skip using this lexicographic order:

1. goal feasibility;
2. survival;
3. reserved-resource margin;
4. goal utility;
5. build gain;
6. volatility;
7. detour/time.

Explanations can cite owned-item synergies, anti-synergies, transformation thresholds, character modifiers, active replacement loss, timers, or low-confidence expected value. Turn on **Show confidence** and **Show warnings** in Mod Config Menu to make those limits explicit.

## No side effects

The planner is a pure recommendation step over a normalized snapshot. Run Compass does not alter rooms, pickups, seeds, achievements, unlocks, or player state. Replanning is triggered by observed events; rendering never performs route solving or game mutations.
