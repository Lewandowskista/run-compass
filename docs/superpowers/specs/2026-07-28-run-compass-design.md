# Run Compass [REP+] Design

Run Compass is a fair-play route adviser for solo Normal/Hard Repentance+ runs. It selects a boss or vanilla collectible unlock target, evaluates revealed rooms and observed pickups, and recommends the next door plus up to three actions. Future floors remain milestone guidance until generated.

The mod is a normal Workshop Lua mod. Mod Config Menu is the configuration dependency. Repentogon is an optional enhanced tier: vanilla mode routes safely verifiable goals, while Repentogon mode reads persistent unlock/completion state and richer callbacks. Hidden room topology, secret rooms, Curse of the Blind identities, and Curse of the Lost map data are never passed to the planner.

The core contracts are `CapabilitySet`, `GameSnapshot`, `GoalDefinition`, `Recommendation`, and `Planner.plan(snapshot, goal, previousRecommendation)`. Routing uses a bounded receding-horizon search over revealed topology, lexicographically prioritizing goal feasibility, survival risk, resource margin, build gain, and then detour/time. State changes trigger replanning; rendering never performs route solving.

The first release supports solo Normal/Hard only, English text with translation-ready strings, keyboard and controller controls, a searchable goal browser, and a compact after-clear HUD arrow. It never changes game state, grants unlocks, or predicts hidden rewards.
