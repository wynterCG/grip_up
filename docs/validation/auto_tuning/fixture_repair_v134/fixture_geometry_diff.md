# Prospective fixture/input revision 1

No physical feasibility pass is claimed by this design document.

The first v134 candidate retains the exact `qualification_mirror_v1` geometry from `fixture_registry_v132_r1.json`: normal arena8 spawn(0,1.17,0.4), wall, 0.48×0.30×0.48 pad at(0,0.10,0.56), safety floor and four original wall footholds. No pad is removed, moved at runtime, disabled or made kinematic. Conservative swept/rotational queries retain their original algorithm and margins.

The changed preparation is real input: acquire entry hands, hold W1.5s, release/reacquire each hand through the ordinary picker at surfaces15cm higher, wait for the unchanged quiet predicate, then issue the original test command. Entry and measurement contacts are separate in the new catalog. Higher contacts are(-0.24,2.25,0) and(0.24,2.25,0); asymmetric right contact is(0.24,2.13,0), retaining a real12cm height difference. Acquisition order remains mirrored for left/right traversal.

The physics review calculated necessary static reach in actual old settled states; all proposed contact distances fit the existing0.65708m reach. This does not prove successful regrip, collision clearance, quiet support or performance. Those require bounded real-input runs.

The foot-step case changes from the old arena6 floor/Step to the existing arena8 mirror wall/footholds, with a new scenario ID. This explicitly changes the physical support context to test nonground B1 loading. Load>1N, nonground and hand support must coexist; a failure retains typed nulls. It cannot be described as the same-world replay or scoring improvement over R3.

All six IDs end `_v134_r1`, use `fixture_revision=v134_mirror_real_regrip_r1`, and require newly captured tapes. Unchanged Swing & Catch uses its original separate fixture/tapes. Any development revision will record a new catalog/source identity before another run; final source is frozen before pilot comparisons.

## Final candidate r2, before pilot

The eight development launches are closed. r1 Vertical60 measured a complete positive window; Asymmetric60 ended with a FootBase END_OVERLAP query against the pad; Step60 had wall contact but zero compressive load at quiet rest. These remain development results only.

Final r2 changes test-world geometry before the first actor step. Pad X extent, topY0.25 and rearZ0.80 remain fixed; frontZ moves0.32→0.39, producing centerZ0.595 and depth0.41. Its key becomesV134SpawnPadR2. Actual recorded r1 asymmetric FootBase maxZ was0.385717108, giving a nominal4.283mm separation in that old pose. The initial COMZ0.40 has only10mm nominal margin inside the new support polygon. Neither value guarantees the future path; unchanged conservative queries must certify each new pose segment.

Only Step replaces the four small mirror footholds with one broad B1 lip of size(0.95,0.16,0.22), center(0,0.57,-0.01), topY0.65 and frontZ0.10. The proposed unrecessed frontZ0.11 had an estimated2.127mm overlap with the LowerCapsule in the old Step resting pose. The independent physics review required the1cm recess; it gives about7.87mm nominal clearance in that same old pose. No body shape, collision mask, force, contact-preload setting or solver margin is changed. New poses still need real testing; native manifold absence remains UNKNOWN.

All final IDs end `_v134_r2`; new captures/tapes are mandatory. The final source will be archived and frozen after static reviews, then tested directly under the48-process pilot ceiling. No additional development episode or retroactive r1 promotion is permitted. `feasibility_fixture.gd` records authored before/after parts and actual native-sized static shape transforms in each result.
