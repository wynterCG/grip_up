# First Ascent - continuous playable course

The new opt-in level joins wall climbing, lateral transfers, arm-only bars,
another real wall climb, the retained v1.0 top-out and normal deck walking.
Open **Controls / PLAY / The first ascent**. The original first route and all
comparison fixtures remain available; startup defaults are unchanged.

## Design and implementation

The user explicitly requested an online level-design agent. We found the public
`level-designer` profile in Donchitos/Claude-Code-Game-Studios and assigned it to
a Codex subagent for spatial design. This is a role definition, not a separately
trained external model or installed studio service. The original profile, MIT
license and pinned revision are under `../../agents/level-designer/`. The design
handoff is `../../levels/first_ascent.md`. Main Codex implements the level and
integration; the physics specialist validates actual input-driven traversal.

`first_ascent_level.gd` extends the approved layout in a separate level 21. It
reuses the wall/base/lips, adapts the teaching bars, and adds a static 2.4 x 2.8 m
deck at Y=3.25. Initial bar transfer was too close to maximum reach. Only the new
course lowers/widens the first bar, levels the second and makes the bar/deck
fronts coplanar at Z=.20. The wall-to-bar leading edge still has a real protrusion;
it can be negotiated with a closer contact on the actual bar. This is no socket,
snap or requirement to click the scripted test coordinates.

World labels were shortened and separated after rendered review. Broad paint
and contextual HUD hints explain the intended line. The complete marked-route
badge requires all three observed climb/traverse/suspension regions plus the
real top-out and .30 m walking. Taking another free line is physically allowed;
if the player reaches the deck without those regions, the HUD acknowledges
**TOP REACHED** and identifies the unfinished route challenge.

Climbing forces, reach, gravity, body mass, input semantics and the mantle motor
are unchanged. There is no required ballistic jump, Space ability, new animation
variant, classifier or forced swing-energy gate. Connected bars permit pendular
loading and transfers; that does not prove a mandatory swing puzzle.

## Verified behavior

- Full ordinary floor-spawn replay: **17/17 at 120 Hz and 17/17 at 60 Hz**.
- Selected regressions: original first route 15 per frequency, v1.0 low/high and
  two-ledge suite 29 per frequency, resilience 59 per frequency. **206 checks**
  all pass. These repeat prior coverage and are not added to the earlier total.
- The marked path gains approximately **3.00 m** before ending in a dynamic
  standing body, native FootBase contact on the actual new deck, and more than
  .30 m ordinary walking. A final bar contact alone cannot award top-out.
- Every precommit transfer retains a real supporting hand. Old forces are
  retired only at the certified assisted commitment. All observed ordinary
  forces and moments respect the original budgets.
- Rendered replay is performed through **Godot MCP Pro on monitor 1**, at both
  120 and 60 Hz. It shares the same finite input exercise with headless testing;
  the helper never writes body transforms, velocities or attachment states.
  Actual rendered completion adds the full-course win check (18 per frequency).
- Windows export and three-frame startup smoke pass. Final hashes, native
  receipts and prepared session are recorded in `course_verification.json`.

Final headless course evidence: `course/attempt_005/`. The selected old-route,
vault and resilience receipts are in `course/attempt_001/`. The earlier complete
4,728-check M1 matrix remains archived in its own report; it was not rerun merely
to inflate this course's test count. No shared physics controller changed here.

## Development failures and practical limits

Failed development runs are retained in `course_development/`. They exposed a
bar edge blocking a direct hand sweep, insufficient reach margin, and a lip
selection too high for the actual arrival posture. Geometry was adjusted in
level 21, and the replay selects closer legitimate surface points. No collision
rule, reach limit or force budget was relaxed to pass.

`course_native/attempt_001/` is a failed direct-CLI rendered development run. It
checked a route stage before the real scorer became ready and aborted the next
section; later samples had already completed that stage. The test now waits
boundedly for the real event. A direct CLI instance was not registered as the
editor's playing scene, so final visible tests use the MCP-launched normal game.
Headless and MCP replay share a Node exercise instead of separate control plans.

`course_native/attempt_002/` includes a passing older 120 Hz trial and a failed
60 Hz trial where the selected left-hand point became 12 mm out of reach during
movement. A closer left contact keeps the anchors in anatomical left/right
order. `course_native/attempt_003/` includes a passing 60 Hz run and a failed
120 Hz bar catch during a different pendulum phase. The final exercise chooses
a closer last-bar contact at X=1.60, an intermediate left face contact at
(2.16,2.88,.20), and a right near-lip contact at (2.34,3.06,.20). It waits up to
six seconds for actual body height inside the existing start envelope and a
real shoulder reach window before releasing that lower right grip. The
preceding `course_native/attempt_004/` reached the lip at 60 Hz but lost the
new grip before the body was high enough; its 120 Hz run passed. These are
ordinary surface choices; no production physics changes
were made. Final rendered receipts are indexed in `course_verification.json`.
Failures are not reclassified as passes or hidden by stale JSON.

Thirty-to-ninety seconds is the design target for a first human attempt, not a
measured human result. The scripted line is roughly 20-35 simulated seconds
before crossing; this does not establish learning time, comfort or enjoyment.
The leading bar edge and readability need the user's playtest. No human rating
or default promotion is claimed. Recommendation: **KEEP the playable greybox
and iterate from real player feedback.**

## Files and reproduction

Production changes are limited to the new `scripts/first_ascent_level.gd` and
guarded level/UI/telemetry integration in `scripts/grip_up_lab.gd`, relative to
`features/grip_up/`. `test_first_ascent.gd` wraps the shared
`first_ascent_exercise.gd`; `capture_first_ascent.gd` runs it in the live game.

```
python tools/run_contextual_vault.py course first_ascent climbing_route vault_v10 vault_resilience
python tools/project.py export
python tools/project.py smoke
```

MCP: play the main scene, set the desired Engine physics frequency, and add
`capture_first_ascent.gd` beneath the current lab. After a finite replay it saves
fresh JSON/frames, releases inputs and leaves First Ascent ready at 120 Hz.
