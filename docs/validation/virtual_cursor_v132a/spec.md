# GRIP UP — Isolated Virtual Cursor & Deterministic Picking Replay
## Targeted evaluator patch v1.3.2a · Implementation specification (English)

**Status:** DESIGN / NOT IMPLEMENTED.  
**Audience:** Codex implementation agent, Godot gameplay engineer, independent physics/replay reviewer.  
**Scope:** Make automated *rendered* and *headless* Grip Up tests independent of the host computer's physical mouse, keyboard and window-focus input, while preserving **exactly the game's real camera projection, candidate sampling, surface raycasts, grip acquisition, material anchors, and Jolt physics**. This is a targeted input-isolation and diagnostic task, **not** a new locomotion controller, physics retune, auto-tuning study, or M7 milestone.

---

## 0. Authoritative context and rationale

The v1.3.2 evaluator qualification ended `NO_GO / EVALUATOR_NOT_READY`. Its R0 lane delivered normal mouse/button/keyboard events through Godot Input at physics ticks. In a rendered 120 Hz R0 run, the tape requested viewport cursor `(0, 0)` while the observed cursor was `(960, 540)` at tick 13, even though 534 logical commands matched. The first contact point differed by approximately **1.256634 mm at tick 55**; subsequently velocity/spin/COM diverged. In a 60 Hz diagnostic the intended underside `-Y` surface was replaced by a `+Z` face, with about **109.669 mm** of material-point difference and no real attachment. These facts make the surface-picking path, not simply the Jolt solver, the immediate investigation target.

The designer subsequently confirmed they were **actively using the PC** (moving the mouse and changing windows) while automated tests ran. This makes OS interference plausible, **but does not prove it**. In particular, `(960, 540)` is also the center of a 1920×1080 viewport; Godot can report centered positions under captured-mouse behavior, and the old `(0, 0)` may represent an absent event/default rather than a genuine user target. This patch must isolate the causes experimentally and **must not retroactively relabel the old result as explained**.

Existing realities to preserve:

- Godot 4.7.2/Jolt, 120 Hz primary and 60 Hz comparison; same **12 kg RigidBody3D** and collision/force authority.
- Gameplay profile 4, movement coordinator **A0**, feet **B1** are the evaluator's explicit baseline. Normal startup remains profile 2; do not promote profile 4 globally.
- Mouse chooses freely eligible surface points; **LMB/RMB held** request the left/right hand; holding out-of-reach targets is allowed under the existing configured profile; pending targets exert no force.
- MMB camera orbit, wheel dolly, real raycast/surface checks, finite hand reach, grip states, support-local material anchors and real grip retention remain authoritative.
- A hybrid static top-out may take temporary kinematic authority under its existing rules; the replay may not use that phase to make a false claim of fully dynamic climbing.
- The earlier v1.3 study, v1.3.1, and v1.3.2 results and manifests remain immutable historical artifacts.

**Non-goals:** no new ML/Jev/Optuna runs; no optimization; no new physics solver, actuator force, mass, grip range, input feel, animation, camera behavior or level geometry; no universal solution to display-server scheduling or OS process suspension; no bypassing gameplay raycasts by writing a hand's attachment state.

## 1. User-facing outcome

In an explicitly selected automated test session, a **test-owned virtual pointer** supplies the viewport-space aim coordinates on every relevant physics tick. The physical mouse may move, click, or interact with another application without changing that test pointer, the test's button/key states, or the test camera's requested orbit/dolly. The gameplay code consumes **one authoritative per-tick input snapshot** regardless of whether it originates from a real player or a test tape.

The player's normal game stays unchanged. No virtual-cursor authority exists in ordinary gameplay, in release builds, or by default in the development lab.

**Important promise boundary:** Input isolation prevents *input contamination*. It does not guarantee that a minimized/unfocused rendered process continues to produce physics ticks on every OS/Godot configuration. Background scheduling, window resize, device loss and actual suspension are independent environmental conditions and must be measured and classified; do not silently advance a game clock that stopped.

## 2. Design principle: ONE picking pipeline, TWO input sources

The implementation shall preserve one canonical picking path:

```text
LIVE hardware input --------> LiveInputProvider ---\
                                                 > GripInputFrame (per physics tick)
TEST recorded input --------> ReplayInputProvider -/          |
                                                             v
                                              Existing gameplay input router
                                                             |
                       +-----------------------------+-------+------------------+
                       |                             |                          |
                Camera orbit/dolly         Viewport-space aim cursor     LMB/RMB/WASD edges
                       |                             |                          |
                 Real Camera3D ---------------> Canonical grip ray -----> normal grip request
                                                       |
                                           Existing surface sampler/raycast
                                                       |
                                       Surface eligibility and obstruction checks
                                                       |
                                        Actual REACHING -> ATTACHED/contact
                                                       |
                                                  Existing Jolt physics
```

**Never create** separate “test grip detection,” “assisted target placement,” a fake `ATTACHED` state, a preselected world target or a direct `RigidBody3D` position/velocity write to make the test pass.

### 2.1 Recommended integration seam

Inspect the actual source first; do not assume paths are exact without confirming the current tree. Candidate existing modules from the project report:

- `features/grip_up/scripts/climbing_input_router.gd` — normal input routing.
- `features/grip_up/scripts/grip_targeting.gd` — camera-dependent selection and free-surface contact.
- `features/grip_up/scripts/climbing_camera.gd` — MMB orbit and wheel dolly.
- `features/grip_up/scripts/grip_up_lab.gd` — test scene and comparison activation.
- `features/grip_up/scripts/climbing_controller.gd` — authoritative grip requests and finite attachment.
- The v1.3.2 evaluator runner, tapes and trace writer under the existing auto-tuning/evaluator folders; discover exact names before editing.

Add **a minimal input-source abstraction immediately before the existing input-to-gameplay boundary**, not inside physics, targeting decisions or the Windows cursor API. Refactor only direct global mouse/key reads that actually influence test gameplay so they consume the canonical frame. An audit of `Input.*`, `Viewport.get_mouse_position()` and `_input` / `_unhandled_input` in the participating gameplay/camera/UI scripts is mandatory; do not declare isolation based on a single rewritten getter.

If full routing of an existing code path would cause risky production changes, keep it behind a tightly scoped flag and mark any unconverted input reader as **`INPUT_ISOLATION_INCOMPLETE`**. Do not silently claim a certified test.

## 3. Canonical per-tick input contract

Define a typed immutable value for each physics tick (illustrative schema; use idiomatic GDScript / typed dictionaries or RefCounted class matching the codebase):

```text
GripInputFrame:
    schema_version               # e.g. "grip_input_frame_v1"
    session_id, tape_sha256
    tick_index, physics_hz
    source_kind                  # LIVE | VIRTUAL_REPLAY
    viewport_id, viewport_size_px
    aim_valid                    # explicit; never infer from x == 0
    aim_position_viewport_px     # Vector2; finite and explicitly bounded
    pointer_motion_valid         # separate from persistent aim validity
    camera_orbit_delta           # exactly the player-facing input modality
    camera_zoom_steps            # signed, ordered wheel input
    held_left, held_right        # button states
    pressed_left, pressed_right  # calculated/replayed edges
    released_left, released_right
    move_axis                    # signed W/S, A/D or canonical actions
    action_edges                 # e.g. optional Space, reset, debug
    focus_policy_state           # ACTIVE / EXTERNALLY_UNFOCUSED / RUNTIME_PAUSED
    input_source_sequence        # deterministic ordering within a tick
```

Rules:

1. **One frame is committed exactly once per physics tick**, before any gameplay action consuming its values. Log first/last tick and a duplicate/missing-frame guard.
2. `aim_valid = false` means **no valid cursor sample**, not `(0, 0)` or viewport center. A frame with invalid aim cannot request a new world target; it may preserve or release an existing held state only according to the actual game rule and tape provenance.
3. `(0, 0)` is a **legitimate top-left coordinate only when the recorded event explicitly asserts it is valid**. Migrate legacy R0 tapes conservatively: if ambiguity cannot be eliminated, reject with `LEGACY_POINTER_AMBIGUOUS` rather than filling the gap.
4. Pointer aim, pointer movement, held buttons, edge transitions, MMB orbit and camera deltas are **different fields**. Mouse capture may center reported event positions; never treat a captured-window center as movement intent.
5. Initial cursor, held keys, handedness, action bindings, camera pose and viewport transform must be explicit in session setup. A test tape cannot inherit a stale pointer from a prior test or physical user session.
6. No implicit OS clicks, keys, buttons, wheel or mouse motion may change an active `VIRTUAL_REPLAY` frame. They can be logged as rejected external events in a bounded diagnostic stream.
7. The replay version, tape hash, viewport mapping and camera sampling phase are part of the test identity; a change must create a new benchmark revision.

### 3.1 Sample test tape — illustrative, not a live capture

```json
{
  "schema": "grip_virtual_replay_v1",
  "lane": "V0_ISOLATED_POINTER",
  "physics_hz": 120,
  "viewport": {"width": 1920, "height": 1080, "coordinate_space": "viewport_pixels"},
  "initial": {"aim_valid": true, "aim_px": [1042.0, 486.0], "left": false, "right": false},
  "frames": [
    {"tick": 0, "aim_valid": true, "aim_px": [1042.0, 486.0], "left": false, "right": false, "move": [0, 0]},
    {"tick": 1, "aim_valid": true, "aim_px": [1042.0, 486.0], "left": true, "right": false, "move": [0, 1]},
    {"tick": 2, "aim_valid": true, "aim_px": [1050.0, 478.0], "left": true, "right": false, "move": [0, 1]}
  ]
}
```

This schema is a design target. The implementation must choose compact storage (e.g. delta frames) if desired while retaining the exact semantic fields. It must never fabricate example coordinates as though they came from archived v1.3.2 evidence.

## 4. Virtual pointer ownership and runtime isolation

Implement an explicit finite-state test-only provider:

```text
DISABLED
  -> ARMING (validate tape, clock, viewport, bindings and scene)
  -> ACTIVE  (single authoritative virtual frame per tick)
  -> FINISHING (release all virtual held states, flush evidence)
  -> DISABLED (restore normal game input and all temporary settings)
            OR
  -> INVALID (abort on invariant / unsafe environment)
```

Requirements:

- **Default = DISABLED**, including ordinary editor run, game startup, user playtest and exported builds.
- Enable only by a dedicated evaluator command or explicit lab selection; never infer from an installed plugin or the existence of a tape on disk.
- When ACTIVE, normal OS input continues to be usable by the operating system and other applications; the automated GRIP UP gameplay must **ignore** that input for aim, grip, locomotion and camera. Do not call `Input.warp_mouse()`, modify cursor position globally or install system-wide hooks.
- Ordinary UI/menus/debug hotkeys that could reset, pause or change the test must be locked out, explicitly excluded from the benchmark, or cause `EXTERNAL_UI_INTERFERENCE` / `RUN_INVALID`; do not allow a click on a lab button to silently alter the run.
- No use of `Input.action_press()` or `Input.parse_input_event()` as the sole isolation mechanism. Those interfaces inject events but do not prevent later real OS events or polling of global input from changing state. If used in a comparative/diagnostic lane, label that lane as **OS-sensitive**, not isolated. Godot documentation states that simulated mouse-motion input does not move the actual OS cursor; this alone does not establish input independence.
- On normal gameplay return, clear virtual held buttons/edges and transient camera deltas; remove provider authority in a guarded, idempotent cleanup. Do not leave actual gameplay thinking a physical button remains held.
- Telemetry must expose both `virtual_aim_px` and `hardware_aim_px` when safe to read, plus `effective_aim_px`, `source_kind`, focus state, and the reason for any rejection. Hardware position is **diagnostic only**, never authority in the active lane.

### 4.1 Focus and window handling

Distinguish three cases:

1. **Physical mouse moves while test window still processes:** virtual gameplay input must remain unchanged.
2. **User clicks another window or Alt+Tabs:** external focus may change, but virtual aim/buttons remain authoritative *if physics ticks continue and gameplay is not paused*. Record `focus_changed` and actual step cadence. The test must not lose grips due to normal live `focus-out` cleanup being applied to the virtual provider.
3. **OS/Godot suspends or throttles a minimized/unfocused test process:** record `RUNTIME_SUSPENDED`, `TICK_GAP` or `ENVIRONMENT_NOT_COMPARABLE` and invalidate that qualification run. Do not hide skipped ticks, invent time, change `Engine.physics_ticks_per_second`, or claim the cursor abstraction guarantees background execution. For unattended experiments prefer a verified headless/offscreen execution path.

A real player losing focus must **still release held gameplay input** as before. Only the explicitly opt-in replay provider has separate focus policy. This is a safety and backward-compatibility gate.

## 5. Coordinate spaces, viewport and camera projection

Use *canonical viewport-local pixels* for replay aiming, not desktop screen pixels, global mouse positions or normalized device coordinates with unspecified rounding.

- Capture the target `Viewport` identity, visible rectangle, canvas/stretch transforms, actual size, device pixel ratio where exposed, window mode and render mode. State whether the game viewport differs from a UI or editor viewport.
- Record the pixel and its validity at the same physics phase used by the actual selection call.
- The canonical grip ray must use the game's current `Camera3D` and the actual existing projection/picking logic. `Camera3D.project_ray_origin()` and `.project_ray_normal()` are suitable Godot APIs **if the current targeting implementation already constructs rays this way**; reuse it rather than writing a duplicate implementation.
- Preserve the existing target candidate sampling near the cursor, collider/world masks, line-of-sight checks, free-surface eligibility, hand selection, reach, pending targets and contact authority. The test provides **aim pixels only**, not a world anchor, collider ID or collision normal.
- Orbit/dolly are replayed through the normal camera controller. Camera world transform is recorded immediately **before** picking. If ordinary visuals use an interpolated camera pose while physics uses a different pose, record both and choose a single documented physics-phase camera for the isolated evaluation. Do not overwrite the player's real camera transform every frame to force matching.
- On unexpected viewport size, scaling, DPI, focus/camera ownership change or failed camera availability, **abort or explicitly mark environmental non-comparability**. Do not silently normalize to the current center, clamp to visible bounds or pick a different ray.
- Test a point on an edge/corner and a point near a geometry silhouette: one pixel can switch the hit face. Therefore, a cursor-coordinate mismatch is a **hard failure before** applying any tolerance to contact position.

## 6. Execution ordering and one-authority rule

The agent must inspect `_input`, `_unhandled_input`, `_process`, `_physics_process`, camera updates, input-router calls, targeting, and test runner scheduling. Document the actual update order with a small timing trace.

Desired documented tick sequence:

```text
begin physics tick K
  -> verify clock, world and scene identity
  -> load VIRTUAL frame K (no poll of hardware input)
  -> resolve canonical input state + edge transitions
  -> update gameplay camera from frame K as existing logic requires
  -> sample camera/viewport state and construct normal aiming ray
  -> invoke existing free-surface targeting and grip requests
  -> update existing movement/controller actuators
  -> Jolt integrates normally at physics-step boundary
  -> record phase-labelled input, picking and physics observables
end tick K
```

If the engine's actual callback order differs, adapt the seam so the above causal relationship holds without pretending a post-control state is post-solver. **Any `Input.get_mouse_position()`, `Viewport.get_mouse_position()`, physical `Input.is_action_pressed()` or late `_input()` consumer affecting this sequence must be converted or explicitly rejected by the isolation audit.**

The provider is the authority for input only. **The existing grip solver remains the authority for actual attachments, and Jolt remains authority for body movement.** No test may set `hand.state = ATTACHED`, spoof a collision result, force grip retention, directly write a body transform or bypass finite-speed reach.

## 7. Read-only diagnostic evidence and first-divergence detector

Add compact, bounded tracing with separate data for each phase:

- **Environment:** engine/Jolt version, physics Hz, viewport and window metrics, hardware/virtual focus states, physics tick durations, scheduling gaps, observer/recorder switches, hashes and scenario seed.
- **Input:** tape-requested frame, effective frame, event source/sequence, button press/release edges, camera orbit/dolly commands, real hardware cursor *for diagnosis only*.
- **Picking:** camera pose/projection, effective screen point, ray origin/direction, winning collider stable identity and material-space hit point/normal, all candidate rejection reasons (bounded), selected hand, whether target was pending, reach-path status.
- **Contact/physics:** hand FREE/REACHING/ATTACHED/SLIPPING, admitted force, material anchor identity/normal, support local frame, feet carrying load, ground support, body COM/velocity/spin, ownership phase.

Compare run pairs with ordered cut points:

1. Is the **same tape/engine/source/scene/viewport/camera seed** being used?
2. Are the **requested and effective input frames identical** at each tick?
3. Are the **camera transform, ray origin and ray direction** equivalent before contact selection?
4. Did the **same collider face/material point** get selected by the real raycast?
5. Only *after 1–4* may physics trajectories be compared and labelled as potential solver/runtime differences.

Report **first divergent tick and first divergent field**, with a bounded PRE/POST window. Avoid a global 15 cm tolerance or post hoc shifts of input timelines to make outcomes appear equal. A first mismatch at tick 13 must remain visible even if later logical W/A/D counts match.

### 7.1 Required result statuses

At minimum:

- `PASS_INPUT_ISOLATION`
- `PASS_PICKING_REPLAY` (tested cases only)
- `INPUT_SOURCE_MISMATCH`
- `CURSOR_OR_CAMERA_MISMATCH`
- `CONTACT_SELECTION_DIVERGED`
- `LEGACY_POINTER_AMBIGUOUS`
- `MISSING_TICK` / `DUPLICATE_TICK`
- `RUNTIME_SUSPENDED` / `ENVIRONMENT_NOT_COMPARABLE`
- `UNSUPPORTED_REPLAY_CASE`
- `PHYSICS_DIVERGENCE_AFTER_MATCHED_INPUT_AND_PICKING`
- `INCOMPLETE_COVERAGE`

Do not label physical outcome success merely because the test process completed. Preserve selection, real contact and retained attachment as distinct results.

## 8. Test plan — deliberately small, discriminating and budgeted

**Primary aim:** Demonstrate that external human mouse/window interaction cannot contaminate the isolated virtual test input or grip ray. Then assess repeatability of picking and the Swing & Catch task. Test the known historical failure conditions first, not the entire auto-tuning study.

### 8.1 Mandatory controlled conditions

Use the *same explicitly identified tape*, viewport, reference A0/B1 configuration, world reset and physics frequency within each matched pair. Record all result identities.

| ID | Condition | 120 Hz | 60 Hz | Hard expectation |
|---|---|---|---|---|
| V0-H | Headless, no external action | 3 runs | 3 runs | Exactly replayed canonical frames; valid real picking |
| V0-R | Rendered, user leaves PC untouched | 3 runs | 3 runs | Same frame/picking contract in supported case |
| V0-M | Rendered, user deliberately moves/clicks physical mouse | 3 runs | 3 runs | No effect on virtual cursor, input or camera |
| V0-F | Rendered, user deliberately changes active window/Alt+Tab | 3 runs | 3 runs | If physics continues: virtual input unchanged. If runtime pauses: classified separately, never false PASS |

Core budget = **24 qualification runs**, plus up to **four directly related negative/diagnostic runs**. If a hard input/picking gate fails, stop downstream qualification and keep the remaining cells visibly `NOT_RUN_EARLY_STOP`; do not spend a large matrix trying to average away the error. Development and rerun budgets must be logged separately.

A rendered run must not depend on the observer operating the game's window; use the same automated control driver in every condition. Mark manual interfering actions as **external disturbance**, not game input or a human playtest of the controls.

### 8.2 Mandatory negative and adversarial cases

1. **False-zero test:** old/missing cursor event resolves as invalid; never interpreted as real `(0,0)`; genuine top-left screen point is accepted only with explicit `aim_valid=true`.
2. **One-pixel/silhouette test:** virtual cursor deliberately picks different adjacent faces at known pixel locations; both must be selected by actual raycasts, not by hard-coded hit identities.
3. **World-identity test:** viewport size/change, source hash mismatch, camera loss or wrong physics tick are rejected, not silently corrected.
4. **Cleanup test:** abort during held LMB/RMB and focus change; test authority and all held states are fully cleared; ordinary live controls operate normally afterward.
5. **Button-edge test:** button pressed/held/released while the OS mouse independently clicks; no fake second press or missing release.
6. **Camera test:** MMB orbit and wheel from tape drive normal camera behavior; physical MMB/wheel do not drive camera while virtual lane owns input.
7. **UI-control test:** external mouse clicks on the rendered window cannot invoke lab selectors or reset the scenario in a way that contaminates a certified run.
8. **Known 60 Hz underside test:** record whether the valid target is the intended underside `-Y`; if it becomes `+Z`, trace the first differing pixel, projection or candidate. Do not increase hit radius or hand reach to fix it.

**Acceptance requires trace evidence**, not just screenshots. Screenshots and a bounded real-time clip can support a human review of what the test displayed, but do not replace the collider/material-point evidence.

### 8.3 Equivalence requirements — layered

- **Input isolation gate:** canonical `GripInputFrame` bytes/typed values and edge ordering **exactly** match the tape at each tick, apart from explicitly normalized representation in the documented schema. No OS-driven changes. This must hold in every valid test condition.
- **Picking gate:** identical camera input and viewport state must produce the expected camera ray and real target identity. Do not approve a run when only the *outcome* happens to match but the selected face/contact differs.
- **Task outcome gate:** Swing & Catch requires real contact **and** retention, recorded separately. A0/B1's historical 32/32 catch from v1.3.1 is context, not a substitute for new V0 measurements.
- **Continuous physics gate:** do not demand bitwise-equal positions across different physics Hz or invent tolerances. First establish same inputs and picking **within each Hz**; then measure physical outcome distributions and propose explicit, preregistered error envelopes for independent review. Differences between 60 and 120 Hz are coverage comparisons, not identical-tick trajectory comparisons.
- **Background-work gate:** verify the session can continue while the user's PC is in use **where the runtime permits**. A paused/suspended process is not an input-isolation failure but is not a valid qualification run.

## 9. Rollout and milestones

### VC0 — Audit and immutable baseline

- Read and preserve v1.3.2 manifests, old tapes, qualified/failed receipts, known R0 divergences, engine version and baseline hashes.
- Identify every hardware input read that affects aim/camera/requests and trace its physics-phase order.
- Produce `input_authority_audit.md` with a narrow map of necessary hook points; assign a named owner to each.
- **Gate:** No physics/controller retune; baseline preserved; unknown input readers enumerated.

### VC1 — Canonical provider seam

- Implement live and virtual providers returning the same per-tick frame type.
- Add replay selection only behind explicit test flag; retain exact normal live behavior by default.
- Block hardware input propagation to game test state; leave system-wide cursor untouched.
- **Gate:** Existing live-input regression suite passes; test frame ordering assertions pass.

### VC2 — Pixel-to-ray and camera isolation

- Feed virtual pointer coordinates into the **existing** targeting function and normal camera controller.
- Verify viewport conversion, interpolation/order, button edges, hardware mouse movements and deterministic audit fields.
- **Gate:** Known tick-13 cursor mismatch and selected-face identity are directly measurable; no implicit viewport-center fallback.

### VC3 — Real replay qualification

- Run 24-cell-budget matrix and negative cases as allowed by preregistered gates.
- Compare first divergent field among input -> camera -> ray -> grip -> physics.
- **Gate:** Demonstrated noninterference where runtime continues, plus valid outcome/selection trace; else `NO_GO` with explicit failure category.

### VC4 — Independent physics and project safety review

- Independent reviewer validates that virtual input has no physical authority, `REACHING` does not gain force, and collision/material/grip decisions remain real.
- Verify script/resource hashes or approved diffs, editor warnings, rollback, live keyboard/mouse, gamepad unaffected unless explicitly in original scope, production export exclusions, original Janga code protected.
- **Gate:** Only input-test infrastructure differences permitted. Unexplained gameplay regression = rollback.

### VC5 — Handoff decision

- Write `virtual_cursor_qualification.md`, `first_divergence.json`, `evidence_manifest.json`, test matrix, screenshots where available, rejected/invalid runs, and a binary decision **`GO_INPUT_REPLAY`** or **`NO_GO_INPUT_REPLAY`**.
- `GO_INPUT_REPLAY` is **not** approval for Optuna/ML. Other incomplete v1.3.2 gates (one-hand 60 Hz, lateral mirror, continuous metric envelopes, holdouts) remain open until separately qualified.
- If input isolation remains broken, stop; record whether the residual is OS focus, window scheduling, camera/viewport transform, unconverted global input read, or unresolved.

## 10. Regression and rollback contract

- Preserve the current A0/B1 and physical caps: **12 kg; ~0.65708 m anatomical reach; 360 N shared hands; 180 N feet total / 120 N per foot; 20 N·m assistance; 150 N·m resultant climbing moment**.
- No change to initial test geometry, actuator tuning, runtime material/grip logic, Jolt settings, 1.15 s static hybrid top-out or v1.0 presentation solely to pass a replay test.
- Do not delete old reports, rewrite the v1.3.2 frozen benchmark, reopen holdout datasets, overwrite run directories, or relabel invalid runs.
- Compare normal startup exactly before and after (profile 2, user bindings and flags, local settings, camera behavior, hold-to-grip, focus handling, headless boot, export smoke). A normal player must not be exposed to the test provider.
- On abort/end, restore *all* experimental input-source state, active keys/buttons, capture state and temporary viewport-test policy. On runtime failure, restore via scene teardown/process exit without persisting options.
- Tests use independent output directories and a versioned `benchmark_eval_virtual_cursor_v1` identity; legacy R0/A and new V0 data cannot be silently combined into one training score.

## 11. Specific agent instructions

**Codex — implementation owner:**

1. Audit the live input consumption path, camera update order and R0 source; document actual code paths first.
2. Introduce canonical `GripInputFrame` and isolated `V0` provider with minimal guarded changes.
3. Use normal target raycasts and normal finite-grip requests. Do not modify motor/solver code unless required only to read existing evidence; any needed game-logic change beyond input routing must be escalated and independently justified.
4. Implement the fixed-input test runner, focused logging, negative cases, time/clock guards and exact cleanup.
5. Run baseline and targeted V0 matrix, preserve every failed attempt and record file/engine/tape hashes.

**Physics/replay specialist — independent reviewer:**

1. Audit input ownership and candidate/contact authority; seek hidden `Input` pollers and bypasses.
2. Inspect first divergence in **input, camera, ray and contact** before assigning blame to Jolt.
3. Confirm pending/reaching hands cannot exert force; physical limits and support reactions remain unchanged.
4. Review physics cadence when focus changes, one-body control ownership and lack of fake attachment/body writes.
5. Approve or reject **input isolation only**, with explicit remaining evaluator limitations.

**Designer / human observation:** Use the machine normally in the `V0-M` and `V0-F` adversarial conditions, including physical mouse motion and window switching. This is not a gameplay-feel survey. Do not attempt to avoid touching the PC in the interference case; the test is meant to prove whether the automation is independent of those actions.

## 12. Practical acceptance checklist

- [ ] The real game's cursor/camera/grip/raycast path is demonstrably reused.
- [ ] Virtual replay never consults hardware cursor/button state as gameplay authority.
- [ ] Input frames and ordering match exactly; `(0,0)` vs absent event is unambiguous.
- [ ] External mouse movement and clicks do not change virtual aim, camera, grip or WASD state.
- [ ] Focus changes either leave valid ticks/input unchanged or invalidate a suspended run honestly.
- [ ] Current camera and viewport coordinate system are traceable before picking.
- [ ] No direct grip assignment, auto-selection of world anchors, body teleport or physical limit change.
- [ ] Headless/rendered conditions at both Hz have a completed or explicitly stopped matrix.
- [ ] The known underside/front-face mis-selection is resolved or remains clearly diagnosed, never hidden.
- [ ] Live game control/defaults and protected baseline remain unchanged after teardown.
- [ ] Specialist gives a scoped `GO_INPUT_REPLAY` / `NO_GO_INPUT_REPLAY` with evidence.
- [ ] Auto-tuning/Optuna/Jev/RL remain **OFF** pending a separate evaluator qualification.

## 13. Design caveats and relevant Godot documentation

These APIs are implementation reference points, **not** permission to bypass project-specific code:

- `Camera3D.project_ray_origin` and `Camera3D.project_ray_normal` project viewport points to world rays; use the game's existing targeting/raycast implementation: https://docs.godotengine.org/en/stable/classes/class_camera3d.html
- Godot viewport input coordinates and mouse-capture semantics: https://docs.godotengine.org/en/stable/tutorials/inputs/mouse_and_input_coordinates.html
- `Viewport.get_mouse_position` is a *live* viewport position, not virtual replay authority: https://docs.godotengine.org/en/stable/classes/class_viewport.html
- `Input.parse_input_event` delivers game events but does not warp the actual OS cursor; input accumulation can also have render-frame timing implications: https://docs.godotengine.org/en/stable/classes/class_input.html

The engine API references should be verified against the **actual installed Godot 4.7.2** before choosing callback names or making claims about ordering; the evaluated project, not example code, defines the true input behavior.

---

### Final product decision rule

**Success** means the recorded virtual cursor/buttons/camera commands reach **the real Grip Up targeting and grip pipeline** with measured immunity to the user's physical mouse and window activity, and the resulting test evidence is attributable to those commands. A successful grip capture is not enough if the picked face/ray or effective commands differ. A visually convincing automated run is not enough if the runtime skipped physics ticks.

**If successful:** keep this isolation infrastructure as a versioned tool, then separately finish the evaluator's remaining pre-ML qualifications. **If unsuccessful:** preserve A0/B1, publish first divergence and stop. In either case, this patch does **not** change how Grip Up plays.
