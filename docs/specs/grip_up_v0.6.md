# GRIP UP — Out-of-Reach Grip Targeting
## Physics Climbing Prototype Specification — v0.6

**Status:** Isolated input/targeting experiment; additive to the existing playable GRIP UP prototype.  
**Language:** English  
**Platform:** Windows PC, third-person, landscape 16:9  
**Engine / physics:** Existing Godot 4.7.2 + Jolt prototype (verify live project configuration before editing)  
**Owners:** Main Codex agent (input, UX, scenarios, instrumentation), physics specialist (reach, collisions, attachment, force audit)  
**Depends on:** Existing independent-aim, hold-to-grip climbing controller; v0.5 transfer diagnostics can be reused.  
**Goal:** Let the player **select a visible, grabbable surface point that is currently outside anatomical reach**, hold the corresponding mouse button, and **automatically establish the grip only if the moving shoulder and hand physically make that selected point reachable**.

> **Target selection is not physical attachment.** A distant target may be remembered; the free hand cannot extend beyond its allowed reach, pull the body toward the target, teleport, or attach without valid contact.

---

## 1. Why this experiment exists

The existing selectable-grip limit requires the desired hold to be within arm reach at the moment of mouse-down. In a physical climbing game, that can force pixel-precise clicking during a brief swing or while the character is moving upward. This experiment lets the player **commit to the destination early**, and then earn the physical contact through body motion, swinging, contraction of the supporting arm, or other existing mechanics.

The change is deliberately narrower than the proposed timed-pull or mouse-drag redesigns. **Do not implement delayed arm contraction, a ratchet, a new toggle scheme, or extra body stabilization as part of this milestone.** First determine whether allowing preselection alone improves transfers.

### Example sequence

1. Player hangs by the left hand (LMB held).
2. Player aims at a higher point and presses/holds RMB, even though the right hand cannot currently reach it.
3. The right hand extends toward that point only within its current physically achievable workspace.
4. The player uses existing climbing/swing movement to bring the shoulder closer.
5. As the target enters a valid reach/collision envelope, the right hand continues moving at its permitted speed.
6. **Only once physical contact conditions are satisfied** does the right hand become `ATTACHED`.
7. Releasing RMB at any point before or after attachment cancels/releases the right hand immediately, preserving the left hand.

---

## 2. Inputs and preserved behavior

| Input | Required behavior |
|---|---|
| Hold LMB | Left hand tries to reach/hold the selected point; button-up cancels/releases it |
| Hold RMB | Right hand tries to reach/hold the selected point; button-up cancels/releases it |
| Move pointer after mouse-down | May aim visually elsewhere; does **not** silently change the committed target or attached point |
| MMB + drag | Orbit the camera without modifying stored world/local grip targets |
| Mouse wheel | Dolly/zoom; no grip changes |
| WASD while suspended | Preserve the currently implemented supported swing / posture controls |
| Existing ground movement | Preserve as-is |

**No toggle. No added modifier keys. No direct arm-length control introduced here.**

Only the hand whose input is pressed gets the new pending target. The other hand must continue its ongoing physics and existing target unchanged. A pending hand counts as **unattached** for load distribution and grip-strength budgeting.

---

## 3. Target acquisition versus actual reach

On initial hand-button down, perform the usual camera raycast and validate:

- The ray hit is a real, grabbable surface, not UI, empty space, or a forbidden collider.
- The sampled hit point and normal are well-defined.
- The target is **visibly selectable from the camera** at acquisition (normal visibility/occlusion rules apply).
- The target object remains alive and eligible for attachment.

**Remove anatomical distance as a reason to reject initial target selection.** Do not remove anatomical distance from the physical movement and attachment checks.

For a rigid/dynamic target, store:

- Stable object/collider identity.
- Initial local-space hit position (material point) and local-space normal.
- Hand side, attempt identifier and button-held state.
- Time of acquisition and diagnostic data.

Each physics tick, resolve the selected target's current world-space point and normal from the object's **current** transform. This avoids leaving a target in midair when the support moves or rotates.

There need not be an arbitrary 0.66 m *selection* radius. If extremely distant surfaces make targeting confusing, add a separate configurable **camera selection distance** for usability; do not label it anatomical reach or use it to grant physical access.

---

## 4. Hand state machine

Keep existing hand states and add explicit handling for the out-of-reach pending case. The following is a logical state map; the implementation may extend the current enum or represent `PENDING_OUT_OF_REACH` as a substate of `REACHING` if that better preserves compatibility.

| State | Meaning | Body/support force from this hand? |
|---|---|---|
| `FREE` | No active attempt | No |
| `PENDING_OUT_OF_REACH` | Valid target stored, but no physically reachable contact yet | **No** |
| `REACHING` | Hand physically traveling toward target within reachable workspace | **No** |
| `ATTACHED` | Contact verified and grip physically established | Yes, bounded |
| `SLIPPING` | Existing overload/slip mechanics | As current design |
| `RELEASED` | Release/cancellation transition | No after detachment |

Suggested transitions:

```text
FREE --button-down valid target--> PENDING_OUT_OF_REACH or REACHING
PENDING_OUT_OF_REACH --target becomes feasible--> REACHING
REACHING --target leaves feasible range--> PENDING_OUT_OF_REACH
REACHING --valid physical contact--> ATTACHED
ATTACHED --overload--> SLIPPING (existing behavior)
ANY ACTIVE STATE --button-up / target destroyed / invalid support--> RELEASED -> FREE
```

**Do not repeatedly reset reaching speed, arm pose, reach animation, or target coordinates** when crossing the reach boundary. Use hysteresis and smooth motion to avoid visible oscillation between `PENDING_OUT_OF_REACH` and `REACHING`.

### Pending duration

- A pending target persists **as long as its button remains held and the object remains valid**.
- There is **no short arbitrary timeout** in the initial experiment.
- No new click is needed once the body brings the selected point into range.
- Releasing the input immediately cancels pending selection; it must not attach later.
- Existing attached hands never auto-release merely because their target is momentarily beyond an idealized arm target length; continue to use the existing physical overload/slip logic.

---

## 5. Physical reach envelope

Anatomical reach is measured from the **current physical shoulder frame**, not from the camera, the torso origin, or the original click position.

The provided earlier prototype report listed approximately **0.65708 m** for shoulder-to-palm selectable reach, with an arm-actuator target maximum around **0.62 m** and **0.04 m** elastic allowance. Treat these as **reported baseline numbers**; inspect actual code/rig values before using them.

At each physics tick:

1. Compute the real shoulder position and current target position.
2. Determine the free hand's maximum reachable position in that direction using the rig's physical/anatomical reach model.
3. Generate a reachable **hand movement target** clamped to the workspace, including any existing safe approach offset.
4. Advance the free hand at its existing capped reaching speed and obey path collision tests.
5. Never convert the remote desired contact into an arm constraint that is allowed to exceed its maximum reach.

The pending hand may appear fully extended, tracking the direction of the selected target. As the torso moves naturally, that extended workspace moves with the shoulder.

**Crucial distinction:** IK/visual hand placement must not extend the character's arm beyond its limit, nor impart impulses to its main `RigidBody3D`. A free arm is not a rope connected to a distant object.

For a target substantially above reach, the hand should approach the furthest **currently valid** extension toward it; it must not remain frozen in its initial world-space position while the character moves. Smooth repositioning is allowed within the standard reaching speed cap.

---

## 6. Obstructions and collision-safe approach

Selection from a visible camera ray does not guarantee a physically clear hand path from the shoulder.

Handle these as separate conditions:

- **Out of range:** target valid but arm cannot yet physically touch it.
- **Temporarily obstructed:** target valid but shoulder-to-hand approach is blocked by geometry.
- **Approach now clear:** body/support movement opens a path and the hand may continue reaching.
- **Permanently invalid:** target object becomes ungrabbable, is destroyed, or leaves the gameplay world.

A temporary obstruction is **not permission to tunnel through the obstacle**. It may remain pending while the button stays held, with a clear debug reason.

Reuse current collision-aware reaching, shoulder-to-target visibility checks, and the previous wall-leaving/normal-offset fix where applicable. Do not invent a path that travels through the surface just to make the capture succeed.

If the final contact requires the wrist to be on the wrong side of an occluder, the attachment must fail regardless of proximity.

---

## 7. Establishing the grip (real contact only)

Moving into the anatomical envelope is **necessary but not sufficient** for attachment. The hand must still reach the intended surface point physically.

Before `ATTACHED`, check:

1. Button still held and target object still valid.
2. Target is within the physically achievable workspace **at contact time**.
3. Hand position is within a small configurable contact tolerance of the target material point.
4. Approach path/contact is valid (no intervening collider or invalid penetration).
5. Existing grip eligibility and surface-normal rules pass.
6. The support can actually accept attachment and enter the existing force-limited grip model.

Use finite-speed hand travel and relative target/hand velocity. On a moving support, use the object's **material-point velocity**, including its angular component, for approach and subsequent load calculations.

When a grip establishes:

- Anchor to the precise selected local-space point, not to a nearby convenience point.
- Initialize actuator length from the **actual** shoulder-to-anchor separation to avoid force spikes.
- Preserve the physical velocities of player and support.
- Fade in the grip's force contribution using the existing acquisition blend.
- Respect existing shared force and torque caps (do not grant a free-hand pre-pull).
- Let the existing slip/load model reject or lose an unsustainable catch; no guaranteed attachment.

**No teleport, direct body velocity modification, one-frame rigid snap, range inflation, or extra grab strength.**

---

## 8. Independent aiming and other hand behavior

This change must not reintroduce the previous conflict between cursor direction and arm contraction.

- Mouse movement after selecting a point does not change any attached arm's target length.
- Moving the mouse toward another point does not retarget the pending hand. Targets are latched on button-down.
- A hand in `PENDING_OUT_OF_REACH` has no support force: it cannot share the 360 N budget as a load-bearing hand until attached.
- The attached hand continues supporting the body, including existing swing inputs and body/structure forces.
- The player can simultaneously hold LMB on an anchor and RMB for a pending upper target.
- When the new grip attaches, the current one-hand-to-two-hand transition logic shares the normal total force/torque budget.
- Mouse-up of one hand must never release the other hand.

The experiment tests *early targeting*, not automated climbing. Player posture, swing timing, contraction by existing controls, and route choice remain consequential.

---

## 9. Visual and audio feedback

Minimal and readable; avoid adding a large HUD.

| State | Suggested presentation |
|---|---|
| Valid but out of reach | Small target marker with **pending** outline; fully extended hand points toward it |
| Approach temporarily blocked | Subtle obstruction indication in debug; optional distinct marker |
| Enters feasible envelope | Pending marker transitions to reachable style |
| Real contact established | Existing grip feedback and hand pose |
| Attempt cancelled | Marker disappears immediately |

Use consistent visual indication for free hand versus attached hand. Do not advertise an actual grip while it is merely pending. All cues must remain secondary to the physical movement and can be feature-flagged for user testing.

---

## 10. Diagnostic and telemetry requirements

Add per-hand debugging for:

- Input button held and target-selection time.
- Stable target collider ID, local/world point and normal.
- Real shoulder position and target-to-shoulder distance.
- Calculated reachable hand limit and clamped hand goal.
- Actual hand position, hand speed, target-relative speed.
- Physical reach margin (positive/negative).
- Path-obstruction status and blocking collider.
- Time spent pending, number of in/out reach transitions.
- Actual contact time and acquisition load.
- Failure/cancellation reason.

Recommended event labels:

`TARGET_SELECTED_OUT_OF_REACH`, `TARGET_SELECTED_IN_REACH`, `TARGET_ENTERED_REACH`, `TARGET_LEFT_REACH`, `HAND_PATH_BLOCKED`, `HAND_PATH_CLEAR`, `HAND_CONTACT_VALID`, `CATCH_OVERLOAD`, `PENDING_CANCELLED_MOUSE_UP`, `TARGET_LOST`, `ATTACHED`.

Retain useful categories from v0.5: `POSE_UNREACHABLE`, `HAND_TOO_SLOW`, `CONTACT_REJECTED`, and `GRIP_SLIP`. Distinguish **selection success** from **catch success**.

---

## 11. Required test scenes and acceptance cases

### T1 — Static distant target

- Character hangs by left hand; visible higher point starts outside right-hand reach.
- Hold RMB: target is selected, right arm extends **only** to its max workspace.
- Without body motion, the hand never attaches.

**Pass:** no body attraction and no attachment beyond range.

### T2 — Approach into range

- Same setup. Move body naturally by supported climbing/swing input until target is physically accessible.
- Right hand continues the reach attempt and establishes contact when it actually arrives.

**Pass:** one continuous RMB hold succeeds without clicking again; original left hand remains unchanged.

### T3 — Cancel before reach

- Hold RMB on distant target, then release before the body arrives.

**Pass:** pending attempt cancels immediately and can never attach later.

### T4 — Moving support

- Select a point on a hinged/rotating beam that initially lies outside reach.
- The support moves closer; its local material point becomes reachable.

**Pass:** selected marker follows the same physical point; hand reaches it at finite speed and reaction forces are applied only after attachment.

### T5 — Obstruction

- Camera can select a distant surface but arm's path is obstructed.
- Body motion may or may not open the path.

**Pass:** no collision tunneling, no grabbing through walls; pending survives temporary obstruction while the button is held.

### T6 — One-to-two handoff

- Hold the left support, queue a right higher hold, move to it, attach right, and release left.

**Pass:** no forced length change in left arm, no instant jump or new strength spike, no input cross-talk.

### T7 — High-speed catch

- Select out-of-reach target before a deliberately timed swing.
- Contact occurs at varied relative speeds.

**Pass:** each result is physically explained as captured, missed due to hand travel, or released due to overload; velocity is not erased.

### T8 — Ten alternating transfers

- Reuse the existing reference route with ten handoffs.
- Count distance initially outside reach, how many queued targets become reachable, and why failures occur.

**Pass:** human-playable improvement in transfer flow without reducing meaningful physical difficulty.

### T9 — 60/120 Hz comparison

- Repeat T1–T8 at both simulation frequencies.

**Pass:** core invariants hold at both rates, without demanding numerically identical trajectories.

### T10 — Camera, UI, reset, invalid objects

- Orbit while pending, resize, lose application focus, change test scene, reset, remove target object.

**Pass:** no stale anchors, orphaned pending targets, ghost attachments, or unintended body impulses.

---

## 12. Implementation scope and suggested files

First inspect the actual working tree; do not assume the previous report still reflects current code exactly.

| Existing module | Intended modification |
|---|---|
| `grip_targeting.gd` | Accept eligible camera-ray targets without anatomical selection-radius rejection; save local material point |
| `climbing_controller.gd` | Add/coordinate pending target state; protect existing attached hands and button-up behavior |
| `biped_hand_pose.gd` / `biped_visual.gd` | Draw free hand/IK toward **clamped physical** reach goal only |
| `grip_anchor.gd` | Reuse local anchor + point-velocity tracking when actual attachment happens |
| `arm_actuator.gd` | **No fundamental changes**; only initialize new attachment correctly if tests reveal an issue |
| `climbing_input_router.gd` | Preserve hold-to-grip; no new keybinds; cancel pending on release or focus loss |
| `grip_up_lab.gd` and test scenes | Scenarios, debug labels, telemetry, reset and A/B comparison |

Use an opt-in tuning flag, such as:

```ini
allow_out_of_reach_grip_targets = false  # baseline default
pending_grip_persists_while_held = true
pending_grip_debug_enabled = true
```

Do not silently change existing aim assistance or contact force thresholds. Consider small hysteresis for reach transitions; tune by tests, not by hardcoding permissive overreach.

---

## 13. Implementation milestones (strict order)

### M0 — Protect baseline

- Verify live code and existing tests.
- Create safe working branch/snapshot (project is reportedly not yet a Git repository; confirm first).
- Preserve existing playable version and relevant tuning parameters.
- Capture current failed out-of-range selection behavior for A/B comparison.

### M1 — Select distant, never attach early

- Allow a visible eligible target to be selected outside physical reach.
- Latch target local coordinates.
- Show pending feedback.
- Enforce clamped hand extension and button-up cancellation.

**Gate:** T1 and T3 pass; no extra player force.

### M2 — Follow actual body/support motion

- Recompute shoulder-relative reach each physics tick.
- Track moving/rotating support material points.
- Continue finite-speed reaching when feasible; handle temporary obstructions.

**Gate:** T2, T4 and T5 pass.

### M3 — Attachment and handoff integrity

- Attach only after actual contact and existing load tests.
- Blend forces without increasing available strength.
- Preserve supporting hand, release states and momentum.

**Gate:** T6, T7 and T10 pass.

### M4 — Human validation

- Repeat ten-transfer and swing scenarios with the flag on/off.
- Compare completion, comfort, early target use and failure reasons.
- Run 60/120 Hz comparison.

**Gate:** T8/T9 pass and results justify KEEP / REVISE / REJECT.

---

## 14. Final acceptance checklist

- [ ] A grabbable point can be selected outside current anatomical reach.
- [ ] Only the chosen material point is stored; no automatic retarget as the cursor moves.
- [ ] A pending hand cannot apply load to the character or target.
- [ ] Free-hand reach remains within the actual anatomical workspace at every physics step.
- [ ] A moving shoulder can bring the original point into reach without another click.
- [ ] The hand still requires finite travel and a physically valid contact to attach.
- [ ] The target follows rotating/moving supports correctly.
- [ ] Obstacles always block invalid reaches.
- [ ] Releasing the relevant mouse button always cancels/releases its hand.
- [ ] Existing attached hand and shared strength budgets remain correct.
- [ ] No teleport, forced velocity, range inflation or added thrust.
- [ ] Camera and pointer movement never directly modify supporting arm length.
- [ ] Existing v0.4/v0.5 behavior is recoverable with feature flag OFF.
- [ ] Tests cover one-hand transfers, dynamic supports, swinging, reset, and both physics rates.
- [ ] Real human play confirms whether preselected targets improve fluidity.

---

## 15. Required report to the developer

After each milestone, report:

1. Code files changed and scope of changes.
2. Baseline vs experimental targeting behavior.
3. Physical reach and contact invariants tested.
4. Test logs, reproduced failures and fixes.
5. Whether any grip ever attached before actual physical contact.
6. Whether the new control reduced missed timing windows in ten transfers.
7. Unresolved issues and a final recommendation: **KEEP**, **REVISE**, or **REJECT**.

**Success means the player can choose a future handhold early but still has to physically earn the catch.** The targeting system must make the intention easier to express; it must not climb, pull, or grip on the player's behalf.
