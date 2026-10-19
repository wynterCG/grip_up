# v0.5 M0: frozen v0.4

Repository baseline: d53b43d on feature/v0.4-independent-aim, pushed to GitHub.
2012 automated checks,37 native checks per60/120Hz, exported executable smoke3
frames. Configuration, reports and source are preserved; Janga SHAunchanged.

Native failure reproduction uses capture_independent_route.gd center_lane=true,
profile3/policyB,0.16m spacing on the unchanged authored StaticClimb wall. No
teleport, collider edit or budget change. It completes5 transfers, then attempt
index6 rejects out_of_reach at17.04s. The primary stage is pose/geometric reach,
not a failed contact or grip retention. Exact shoulder distance is absent from
this older native schema; the corresponding archived headless trials measure
0.706m against0.65708m. M1 will add this missing per-attempt measurement.

The same route in a clear lane completed10 transfers under scripted timedA/D.
Thus do not conflate a selected obstructed route with all climbing being broken.
Human input success and comfort have not been demonstrated. Automated captures
are labelled; v0.5 does not silently treat them as human pilot sessions.

Torque source is a finite torque-capable gripper, with20Nm shared moment and
opposite dynamic reactions. See docs/validation/V05_PHYSICS_AUDIT.md for the
explicit approximation and separation of pendulum, twist, damping and work.
