# M2 — isolated adaptive lower-body collision

**Decision: KEEP as an opt-in collision experiment.** The isolated C1 clearance gate passes at120Hz and60Hz. This is not a demonstrated mantle or a claim of human usability. Root integration still owns support handoff, actual-ground probing and visual/physical agreement.

## Changes and interface

`features/grip_up/scripts/adaptive_leg_collision.gd` owns only local collision-proxy poses. `features/grip_up/tests/test_mantle_leg_clearance.gd` is an independent SceneTree physics fixture. It is runnable without the game/main scene. `features/grip_up/tests/mantle_leg_clearance_lab.tscn` and its script provide a separate visible C0/C1 diagnostic scene, with the biped IK render and actual cyan collision proxies together.

The diagnostic scene explicitly labels its gravity-zero dynamic12kg fixture and disabled climbing-controller force processing. W/S held requests finite fold/unfold; release holds the attained pose. It offers a thin swept-path lip, an expansion blocker, a declared25N load guard toggle (which applies no force), and safe C1 OFF restoration. A blocker is rejected if insertion would overlap the current physical body. The visible fixture is diagnostic geometry evidence, not genuine load-bearing or a functional mantle. Public MCP-facing fields are `data`, `samples`, `legs`, `body`, and `visual`; calls are `request_flex(value)` and `set_blocker("NONE"/"LIP"/"EXPANSION")`. Root controls all native launches on the second monitor.

```
configure(body, original_leg_capsule, sole, tuning_resource)
request_flex(0.0 .. 1.0)
set_pose_mode("SYMMETRIC_TUCK" / "HEEL_BACK") -> bool
step(dt, enabled=false, loaded_foot_force_n=0.0) -> telemetry
pose_for(flex) -> local thigh/shin/sole transforms + hip/knee/ankle
audit_pose(flex, optional_padding) -> geometry result
audit_path(from_flex, to_flex) -> conservative whole-path result
foot_local_transform() -> actual sole local transform
clearance_diagnostics() -> contact-pair penetration estimate/separation bin
telemetry() -> requested/achieved flex, reason, query result, native impulses
```

Call `step` from controlled `_physics_process`, before deriving the current tick's ground/foot contact/force requests, never from `_integrate_forces`, a query callback or an unsynchronized render update. Setting supported CollisionShape3D transform/shape properties submits the updated compound shapes to the physics server before the next solve. Queries use the proposed world transforms explicitly and exclude the character body.

The root flag must start OFF. OFF from the initial standing state does not modify the original shape resources, transforms, collider count or automatic inertia. Turning OFF after flex requests a finite collision-checked return; an obstruction or a loaded foot can keep the character safely crouched. Reset should destroy/recreate the character normally; do not forcibly restore a blocked pose.

## Geometry and assumptions

Actual baseline reread:12kg, original lower capsule height0.84m/radius0.15m atY−0.4967; sole0.36×0.08×0.28m at(0,−0.8767,−0.035). Torso and head remain unchanged. No force/torque budgets are changed.

Only while enabled, split the lower capsule into two0.57m capsules of the same0.15m radius. Their two centerline spans of0.27m meet atY−0.4967; atflex0 their occupied union exactly equals the old0.84m capsule. They are not independently dynamic limbs. The sole retains its original dimensions and stays horizontal in body-local space.

The proximal centerline endpoint remains atY−0.2267. Hip flexion is75°×flex; knee flexion150°×flex. Thigh inclines forward and shin returns rearward. The ankle and unchanged sole follow these finite links. Full flex raises the sole center by approximately0.40024m, from−0.8767 to−0.47646; sole bottom remains near−0.51646. It does not disappear, shorten to zero or automatically clear every lip.

Flexion slews at0.65/s. With rigid segment lengths and knee limited150°, the capsule radii and fixed proximal endpoint limit clearance. Achieving a sole bottom near−0.25m would need a substantially different physical leg representation; this experiment does not silently translate the hip or enlarge anatomical motion.

### Explicit heel-back variant

`pose_mode` defaults to `SYMMETRIC_TUCK`, preserving the original M2 fixture. The new `HEEL_BACK` variant keeps hip flexion0° and rotates the shin rearward through knee flexion150°. It represents heels folding toward the buttocks, with the full thigh remaining down and the same full-size shin/sole. Set it explicitly through `set_pose_mode("HEEL_BACK")` (or the guarded property) only at achievedflex0. A mid-flex variant switch is rejected, preventing an unqueried collider jump.

Atfullflex the knee stays at(0,−0.4967,0), ankle reaches(0,−0.262873,+0.135), and sole center reaches(0,−0.372873,+0.100). Sole rise is0.503827m, with135mm rearward travel. **The full lower-body bottom is still the stationary knee capsule atY−0.6467.** Therefore the variant improves frontal wall avoidance and heel placement, not universal vertical clearance. Its overall lowest point gains270mm, less than the symmetric tuck's~400mm. No body lean or top-out is implied.

Both pose variants have total absolute segment-angle change150°, so the same conservative sweep arc bound remains valid. The heel-back thigh is genuinely stationary and uses the unchanged-shape query/tolerance policy; moving shin/sole retain strict inflated sweeps. Body mass, proxies, slew rate, loaded-foot guard and exact standing restoration remain unchanged.

One-body approximation: local shape motion does not simulate independently moving limb mass or internal muscle work. The initially solved standing inertia is pinned on first activation, avoiding inertia changes as proxies fold, and original automatic/custom inertia is restored only after exact standing shape recovery. This is a stable approximation, not a full humanoid inertia model. No main-body pose/velocity, collision layer/mask, collision-disable or force APIs are written by the module.

## Whole-path clearance and load guard

Every requested flex interval is split so the maximum proxy-point motion bound per interval is≤2mm. A conservative arc bound `(segment_length + radius) × (75° +75°) × |delta_flex|` includes translation and capsule rotation. Each midpoint moving capsule/sole is inflated by half the interval bound plus0.5mm skin. This encloses intermediate shapes instead of merely checking endpoints. Torso/head and all other enabled collision shapes are also queried at their unchanged poses: they do not receive a lower-limb motion inflation. An existing native stationary contact with geometric penetration estimate≤2mm is allowed; deeper stationary overlap is rejected. A dedicated torso-wall contact test verifies this does not veto a clear lower-leg fold. If any interval is blocked, the whole tick is denied; the previous admitted pose remains. Native collision still handles an obstacle moving into an already stationary proxy.

Any declared real foot load>1N blocks a shape change in either direction. Integration must supply all relevant virtual foot and ordinary-ground support loads, invalidate stale foot anchors when the pose changes and reacquire contacts from the actual sole transform before applying force. A successful free-space test is not authority to remove a loaded ground contact.

`collide_shape` point pairs supply a geometric penetration estimate. It is distinct from Jolt's solved contact impulse, sampled separately from direct body state. Separation is conservatively binned by1/3/10/30/50mm inflated shape queries. These estimates are not exact signed-distance measurements.

## Measured independent tests

Commands:

```
python tools/project.py test test_mantle_leg_clearance
python tools/project.py test test_mantle_leg_clearance -- --60hz
```

Both return37checks/0failures, exit0, Godot4.7.2/Jolt. Four checks exercise the independent visible fixture headlessly, including finite full flex, safe blocker insertion, blocked reverse sweep and restoration after blocker removal. Eight additional checks compare a torso-touching wall against the two explicit variants, enforce standing-only variant changes, measure actual heel rise, guard loaded extension and restore the original collider. The standard footer is `MANTLE LEG CLEARANCE RESULTS:37 checks,0 failures` (normal output includes spaces). JSON receipts and normalized full logs are alongside this report.

Atboth120/60Hz, a real wall atfrontZ−0.22 touches the torso while leaving the standing legs clear. Symmetric tuck stops atflex0.195 because the knee actually moves into the wall. After safe restoration, `HEEL_BACK` reachesflex1 continuously against that same wall: zero body speed, zero native impulse and zero measured overlap in this isolated fixture. This proves the requested wall-clear pose alternative only; root must test whether it materially improves M4.

| Measurement |120Hz|60Hz|
|---|---:|---:|
|Free fold/unfold main-body speed|0m/s|0m/s|
|Free fold/unfold native impulse|0Ns|0Ns|
|Intermediate thin-lip blocked flex|0.44958|0.44417|
|Blocked static fold body speed/impulse|0/0|0/0|
|Incoming dynamic15kg lip blocked flex|0.62833|0.62833|
|Incoming dynamic lip peak body speed|0.00843m/s|0.00840m/s|
|Incoming dynamic lip peak impulse|0.11178Ns|0.11156Ns|

The thin-lip fixture explicitly has both flex0 and flex1 clear, yet an intermediate path collision: it must stop. Obstacle removal permits resumption. A lower platform volume then blocks reverse expansion; abort retains the valid folded geometry. This tests the collider-expansion mechanism. A literal ceiling above the unchanged torso/head does not become clear by bending legs on one rigid body; that larger body-path question belongs to integration.

After a clear unfold over a real platform, gravity settles the restored original standing collider by approximately3.3mm; it remains upright and stable without a ground motor. The settling contact impulse is gravity/landing response, not free-space collider actuation. Its peak is reported in JSON separately. All sampled overlap estimates remain below the declared4mm tolerance.

The moving15kg lip has initial fixture velocity0.025m/s and then evolves freely under native integration. Its reduced-mass momentum scale is about0.167Ns; the acceptance ceiling0.25Ns allows native contact geometry/solver variation. This is not a claim that moving support never contacts the leg.

## Preserved failures and limitations

The first120/60Hz runs each passed21/22. A test incorrectly required peak dynamic impact<0.1Ns and no instantaneous shape-query contact. The real incoming block produced~0.112Ns with~0.0084m/s player speed, physically plausible against its incoming momentum. Those JSON/log receipts remain under `../development/m2_first_moving_collision_*`; the criterion was replaced with explicit momentum-scale impulse and sampled penetration tolerances. The geometry controller was not weakened to hide collision. A subsequent all-pass run initially lacked the runner's required `RESULTS:` colon; that formatting was corrected before final successful process exits.

No whole mantle, actual foot handoff, skeletal-bone IK mismatch measurement or ordinary human approach was tested by this independent fixture. Its visible scene was smoke-tested headlessly; root must provide the actual native rendered capture and integration checks. The module can refuse a fold while a moving lower proxy already contacts geometry or a stationary proxy penetrates beyond2mm; this conservative limitation is preferable to pulling a collider through the lip. If safe one-body clearance remains insufficient in M4, evaluate C2 articulated lower-body dynamics rather than disabling collision or increasing hidden force.
