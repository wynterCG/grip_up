# v0.7.4 — isolated ledge transfer feasibility

**M6 functional gate: NOT MET.** This build exposes a tiny ledge experiment;
it does not add a working mantle to the approved climbing course.

The designer's latest "muito bom" was feedback on the v0.7.3 route. It justified
testing the next capability but supplies no rating or approval for this attempt.

## What changed

- Level 11 and two explicit Controls buttons compare hands only / hands + feet.
- Actual grip material is queried for a top and a rear bearing patch. The real
  body shapes are used to test standing destination occupancy.
- Explicit W can add inward planning and up to 8 Nm of reacted leaning effort
  inside the existing shared 20 Nm assist and 150 Nm common moment budgets.
- Existing finite hand acquisition, material anchors, axial hand forces,
  compressive/friction-limited feet, body collisions and ground motor stay in use.
- The goal requires actual platform ground, hands free, 300 ms stable support,
  then 30 cm of walking. An edge grip cannot produce a victory or rating panel.
- Startup remains profile 2; the approved route and other arenas keep mantle OFF.

## Validation and interpretation

The complete 60/120 Hz regression matrix passes **3760 checks in 121 runs**.
That includes 90 dedicated physics checks and 34 integration checks for the
experiment. These counts verify implementation contracts, not successful mantle
gameplay. Final native MCP receipts and the machine-readable verification are
archived in [final](final/verification.json).

The focused physical trial holds W for six seconds on low and high platforms,
with and without feet. Neither setup achieves actual top ground and hands-free
walking. The native trial separately measures four seconds on the 2.10 m edge.
The flags `physical_completion` / `acceptance_gate_met` remain false.

Final Godot MCP Pro runs pass **30 safety/integration checks**, with no focus
events and zero editor errors/warnings. Native peak torso Y on the 2.10 m edge:

| Variant | 120 Hz | 60 Hz | Actual top support / walk |
|---|---:|---:|---|
| Hands only | 1.356 m | 1.321 m | No |
| Hands + physical feet | 1.480 m | 1.469 m | No |

The ordinary high ledge allows traction and some upward progress. The fixed
calf/sole geometry and traction-only arms prevent this candidate from making the
full support transition. The [physics report](../m6/physics_report.md) includes
heights, force measurements and the dynamic-support reaction experiment.

The detector certifies destination occupancy only, not a continuous body path.
The first discarded native run recorded a focus event; its receipts and the
initial helper integer-division warning are retained under `development/`.
The helper warning was fixed, the runtime restarted, and native trials repeated.

The Windows executable was exported and rendered for three frames. This is a
startup/export smoke check, not a full exported-executable mantle playthrough.
Human feel evaluation of the experiment remains open.

## Decision

Keep this as an isolated, clearly labelled feasibility experiment. Do not
promote it into the approved route or claim the climb-to-walking loop is solved.
The next capability to investigate is legitimate palm compression plus a
physically valid way to tuck the legs and clear the lip. That capability is
not implemented here. See the [M6 decision](../m6/decision.md).
