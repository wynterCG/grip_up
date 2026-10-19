# GRIP UP v0.8 ? physical capability experiment

**Decision: KEEP the isolated palm and collision capabilities, REVISE the
integrated maneuver. Full mantle acceptance is NOT MET.**

This implements the experimental part of the supplied v0.8 specification and
stops at its explicit no-go gate: isolated palm support and lower-body clearance
pass, but hanging-to-standing-to-walking does not. The approved v0.7.3 route and
all prior comparison profiles remain available. Nothing is promoted into that
route. H1 automatic local palm roll and human usability are not demonstrated.

Baseline is commit `9197172e50a9e78c481b9ed251725a3c9ccb3d1c` on the preserved
v0.7 branch. Work is isolated on `feature/v0.8-physical-mantle`; checkpoint
`70f6248` preserves the initial failures before the bent-arm extension. Actual
engine/runtime is Godot4.7.2 with integrated Jolt, not an assumed skill version.
Canonical project: `E:\Godot Games\grip_up`. Local executable:
`builds/GripUp-v0.8-experimental.exe`. Earlier executables are retained locally.

## What changed and where

- `scripts/palm_support_solver.gd`: finite7?10cm virtual contact patch,
  unilateral axial compression and separate bent-arm normal-force variant.
- `scripts/palm_arm_path.gd`: bounded-length shoulder/elbow/wrist/palm witness,
  obstacle queries, finite H0 travel waypoint. No independent physical arm body.
- `scripts/climbing_controller.gd`, `pending_grip_target.gd`,
  `intent_locomotion_coordinator.gd`: guarded contact modes, shared allocation,
  actual reactions, H0 finite arrival, diagnostics. Pending targets stay unladen.
- `scripts/adaptive_leg_collision.gd`: two same-body capsules and full sole,
  collision-authorized local flexion, contact-load guard, safe restoration.
- `scripts/mantle_support_coordinator.gd`: real-support recognition, opt-in pose
  requests, phase ledger and strict completion observation. No body actuation.
- `scripts/ground_locomotion.gd`: adaptive sole pose and, in the new experiment,
  actual native sole contact required before walking authority.
- `scripts/foot_contact_solver.gd`: rejects obsolete virtual feet away from
  the current physical sole pose; no airborne support by proximity alone.
- `scripts/biped_visual.gd`, `mantle_collision_overlay.gd`: attainable limb
  targets, post-IK foot mismatch measurement and visible collision proxies.
- `scripts/mantle_v08_level.gd`, `scenes/mantle_v08_low.tscn`,
  `mantle_v08_high.tscn`, `scripts/grip_up_lab.gd`: separate1.25/2.10m platforms,
  comparison buttons and telemetry. Existing levels0?11 are preserved.
- `tests/palm_compression_lab.tscn`, `mantle_leg_clearance_lab.tscn` and their
  runners isolate contact and collision claims from full gameplay.
- `test_palm_compression.gd`, `test_palm_wrist.gd`,
  `test_mantle_leg_clearance.gd`, `test_mantle_support_handoff.gd` exercise
  primitives/safety. `test_mantle_full_sequence.gd` deliberately fails when a
  full top-out is missing. MCP capture helpers retain actual rendered failures.
- `tools/run_mantle_v08.py` preserves numbered attempts;
  `tools/run_regressions.py v08` runs old and new safety suites separately from
  functional acceptance. `tools/project.py` launches tests/editor on monitor2.

Paths above are relative to `features/grip_up/` unless prefixed tools/docs.

## Flags, defaults and rollback

Startup is unchanged: profile2, intentOFF, physical feetOFF, early targetsOFF,
postureP0 and experimental SpaceOFF. The following new root/controller flags
all default false:

| Flag | Effect |
|---|---|
| `physics_mantle_v08_enabled` | Master, additionally requires profile4 and new arena |
| `palm_compression_enabled` | Distinct finite-area compression contacts |
| `palm_wrist_support_enabled` | Bent-arm contact and bounded wrist moment |
| `adaptive_leg_collision_enabled` | Swept same-body lower proxies |
| `mantle_support_handoff_enabled` | Support-aware coordination/pose requests |
| `mantle_hanging_fixture_start` | Test setup only, never enabled by ordinary UI |

`intent_auto_mantle_enabled` remains the separate old M6 comparison. H0 is
explicit release then held regrip. H1 is unimplemented; no flag silently enables
an automatic roll. New buttons explicitly enable only their declared comparison.
Returning to **PLAY / The first route** creates the original body/controller
without adaptive metadata and disables the new contact model. Cold relaunch
restores original defaults. Preserve this feature branch or return to baseline
`9197172` for source rollback; no existing project folder was removed.

## Physical model and assumptions

Mass remains12kg; hand effort360N shared across traction and compression;
feet180N separately; shared wrist/attitude/swing20Nm; resultant climbing moment
150Nm including same-tick ground. K6000/D220, anatomical reach.65708m, original
hand speed4m/s and planning.24m/s/.9m/s? remain unchanged.

P-A virtual palms use center plus8 perimeter contact rays, upward-normal and
same-material tests and an air-side volume query. Contact is only established
after actual finite hand arrival. The support-local anchor follows its actual
body. Axial force is along shoulder?palm, positive compression only; a shoulder
below the top cannot rise merely by enabling this axial link. Tangential axial
reaction must fit the friction cone. Off-contact, release, invalid footprint,
blocked chain and excessive reach remove support.

For the bent-arm variant, a two-link collision-free witness uses.27000m upper
arm +.27708m forearm and.11000m palm segment. The split and2cm query radius are
explicit virtual-arm approximations. At shoulderS and real palmP:

`F = N*n, N >= 0; C = -(S-P) cross F`.

The body receivesF atS and boundedC, the platform receives?F atP. Their total
force and moment cancel. There is no duplicated oppositeC on the platform.
All palms first share `sum(abs(C_i)) <= 20Nm`; only the remainder is available
to the existing reacted attitude/swing assistance. Final hand/resultant caps
scale admitted forces and couples together. Wrist normal force has no tangent
component, so it stays inside its friction cone without invented adhesion.
The scalar height servo follows achieved motion with maximum.055m unachieved
offset and bounded rate/acceleration; blocked W cannot accumulate free lift.

This creates a real leverage limit:20Nm at.30?.50m permits only40?67N palm
reaction, below the approximately118N weight of the character. Another real
support and favorable body geometry are needed; two palms do not double20Nm.
The isolated bent-arm lift check uses zero gravity deliberately to isolate that
new force model. It is not evidence of lifting the full hanging character.

C1 splits the original lower capsule into two capsules with exactly the same
standing union, retains.15m radius/full sole and12kg mass, and pins the initially
solved standing inertia while flexed. It slews at.65/s. Every pose interval uses
conservative inflated midpoint geometry with at most2mm proxy motion and.5mm
skin. Existing shallow stationary contact up to2mm is allowed; moving limb
segments remain subject to strict swept clearance. No body pose/velocity or
collision layer/mask is changed. Free shape articulation has no force authority.

Default isolated symmetric tuck (hip75?, knee150?) raises the sole.400m but
moves the knee toward the wall. The explicit integrated HEEL_BACK variant keeps
the thigh down and folds the shin rearward: sole rises.504m, but the stationary
knee still sets the lowest point, so whole-body clearance improves only.270m.
It is not a universal leg lift. All actual lower/sole native impulses and virtual
foot load feed a >1N guard that blocks both fold and unfold until unloaded.
Blocked restoration retains valid geometry. This conservative rule also means
loaded stand-up requires a further physical solution, not disabling the guard.

Only current physically nearby ankle contacts can create virtual foot force
(5mm normal gap and8cm tangent tolerance). The ground motor needs actual native
sole support in the candidate. Completion requires a verified loaded hanging
start, actual top ground, original standing geometry, both hands and buttons
released, upright stable body for.3s, then ordinary walking at least.30m in the
support material frame. Moving-platform carry cannot count as walking.

## Tests and evidence

| Evidence | Result | What it establishes |
|---|---|---|
| M0 original saved baseline |120 checks across60/120Hz | Existing M6/route and runtime diagnosis |
| Final regression matrix |4032 checks,129 runs,0 failures | Preserved old behavior and new isolated safety contracts |
| M1 axial |49/49 per frequency | Finite contact, load, friction, release, reaction and shared limits |
| M1 wrist/H0 |37/37 per frequency | Finite bent-arm reach, bounded moment, dynamic wrench and failures |
| M2 |37/37 per frequency | Both collision variants, whole-path blocking, load guard, restoration |
| Integration contracts |13/13 per frequency | Native ground/contact authority, no false win, focus reset, rollback |
| Native primitives |16/16 per frequency | Rendered isolated palms and collision fixture; not gameplay |
| Native combined attempt |11/11 safety per frequency | Actual in-app input and load, release/caps; full gate false |
| Final M4 functional attempts |8 checks /2 failures per frequency | Both low/high top-out assertions fail |
| Human ordinary approach |Not evaluated | No controllability or comfort acceptance |

Commands: `python tools/run_regressions.py v08`;
`python tools/run_mantle_v08.py m4 mantle_full_sequence`;
add `--counterbalance` for the recorded manual input variant. All automated
inputs remain inside Godot, so the user's primary monitor keeps its TV session.
The Windows debug export renders3 smoke frames on monitor2. This is a startup
smoke, not a long-session performance or gameplay certification.

Regression receipts are `results.json` and adjacent normalized text logs.
Raw numbered milestone failures are retained. Native captures and JSON are in
`native/`; physics details are [M1](M1_PALM_PHYSICS.md),
[wrist/H0](M1_WRIST_H0_PHYSICS.md) and [M2](m2/physics_report.md).

## Integrated failure, quantitatively

Attempts001/002 retain early setup/acquisition failures;003 establishes actual
hanging starts but axial compression cannot provide the missing bent-arm route.
004 adds the bounded wrist path;005 uses a near-edge top point8cm inside the lip
with the full palm footprint and continuous measurement.006 adds one explicit
W+A pre-counterbalance input sequence. No strength/geometry cap is raised.

| Attempt005 |120Hz low/high|60Hz low/high|
|---|---:|---:|
| Actual hanging start |yes /yes|yes /yes|
| Finite H0 palm contact |yes /yes|yes /yes|
| Peak palm force |46.784 /46.782N|46.259 /46.256N|
| Full heel-back flex |1 /1|1 /1|
| Final body-originY |.4725 /1.3225m|.4650 /1.3150m|
| Peak speed |1.851m/s|1.862m/s|
| Max sampled overlap estimate |.490 /.490mm|.976 /.977mm|
| Real top ground /walking |none /0m|none /0m|

006 still fails both gates: palm peaks44.23N at120Hz and44.11N at60Hz; final
bodyY stays near.472/1.322m and.465/1.315m. Its peak sampled overlap estimate
stays below1.95mm. These are query estimates, not claims of exact signed distance
or proof that every possible path is certified.

Native rendered repetitions show real H0 contact and peak pressure46.69N at
120Hz /46.82?46.84N at60Hz, but both full gates remain false. Measured actual
post-IK ankle/proxy error peaks2.1/10.0mm for low/high at120Hz and6.8/14.7mm at
60Hz in this sequence. This is measured visual agreement, not extra foot force.

The palm loses its valid chain as the loaded body rotates and the shoulder
moves laterally/outward, ultimately returning `BENT_ARM_WRIST_OUT_OF_CHAIN` /
`BENT_ARM_PALM_OUT_OF_REACH`. When the wrist spends the shared20Nm, little
attitude/swing authority remains; additional A/D cannot secretly add torque.
The remaining traction hand then supports the body below the lip. No actual
upper-ground transition, restored standing on top or meaningful walking occurs.

Endpoint standing clearance is known, but the full body path remains explicitly
UNKNOWN (`PATH_NOT_CERTIFIED`). This diagnostic is not itself the observed
reason the palm releases; the release reasons above describe that failure.
No `TORSO_OVER_EDGE` or `FOOT_TRANSFER` success is invented to advance a state.

## Missing capability and next defensible experiment

C1 currently clears heels but cannot independently lift and plant a real foot
above the hip onto the platform. The foot solver's downward-leg workspace and
physical-sole guard correctly reject such a phantom support. The loaded
extension guard also cannot yet turn an acquired crouched contact into a
controlled standing push. These are distinct from increasing hand strength.

A next isolated experiment should compare an independently controlled,
collision-swept load-bearing leg/foot proxy or C2 articulated lower-body support
against a carefully modeled additional forearm contact. It must prove actual
finite placement, anatomical range, real load/reaction, contact-preserving
extension and release before reintegration. Study shared-moment allocation and
controllable traction-hand repositioning as separate hypotheses; neither is
implemented here as a hidden mantle assist. No full skeletal ragdoll is claimed
necessary by these failed trials.

M5 full moving-platform mantle is gated by failed static M4. Existing isolated
free-platform palm reaction and moving-obstacle C1 tests pass, but cannot stand
in for dynamic full top-out. H1 ergonomic comparison is gated until a physically
credible H0 sequence exists. No human ratings, success rates or comfort claims
are fabricated.

## Player comparison protocol

On monitor2, launch the new executable or open the canonical Godot project.
Controls contains low/high v0.8, fixed-leg, no-palm and axial-palm comparisons.
Use ordinary approach (test fixture startOFF), LMB/RMB hold-to-grip, mouse aim,
W/S effort, A/D shift, MMB orbit, scroll zoom, R retry, Tab physical overlay.
For H0, keep one real support, release the other hand and deliberately select
the top surface. Expect the current stall/release; this is an engineering
experiment, not a promised completable level. Return to PLAY for the approved
route. Record why contact is lost, camera burden and whether failure is clear;
only an actual person can supply that evidence.
