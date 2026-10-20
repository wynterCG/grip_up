# F0 independent physics source review

Date: 2026-10-21. Reference supplied by the integration owner: recovery commit `54a1b98`. This is a source review and a prospective reproduction contract, not a diagnosis from a completed reproduction. No engine was launched by this reviewer. No gameplay, collider, solver, resource, camera or level was edited by this reviewer.

## Observed report and unresolved cause

The player's reported location is the lateral crossing from the first wall into the second section/bars of First Ascent. The reported sticking is real user evidence. It does not yet distinguish foot actuation, rendered IK, native collision, hand geometry or ground-motor handoff. B3 is not implemented or approved by this review. F0 remains unclassified until the owner collects and reviews the physical traces and the player's example.

## Live source and effective values

- `features/grip_up/resources/foot_tuning.gd`: total feet 180 N, per foot 120 N, planting 2 m/s, K=1800 N/m, D=100 N s/m, preload .025 m, engagement .12 s and nominal friction .85. Search interval .10 s, extension .30 m/s, lowering .40 m/s. These match the v1.4 reference; no value was corrected or retuned.
- `features/grip_up/resources/biped_tuning.gd:4`: one 12 kg dynamic body, body friction .12. Physical lower capsule is height .84 m, radius .15 m, local center Y=-.4967. `FootBase` is (.36,.08,.28) m at (0,-.8767,-.035). The measured .54708 m arm chain plus .11 m palm offset gives .65708 m maximum shoulder-to-contact reach.
- `features/grip_up/scripts/grip_up_lab.gd:384`: First Ascent enables native contact reporting with a maximum of 16 contacts. Full-buffer or unavailable direct-state data must not be represented as complete collision absence.
- `features/grip_up/scripts/foot_contact_solver.gd:95`: each prepare clears cached force components. New support requires real validation and finite planting. At contact, rest length is actual hip-to-ankle distance plus preload, capped anatomically. W raises the foot compression target; neutral preserves it.
- `features/grip_up/scripts/foot_contact_solver.gd:200`: the implicit spring is unilateral. Negative stretch beyond its .002 m tolerance yields no effort. Normal force is nonnegative, tangent is limited to material-constrained friction times normal force, then shared foot and central moment limits apply. This is not a bilateral positional weld.
- `features/grip_up/scripts/foot_contact_solver.gd:237`: commit applies the actual scaled force to the body and its opposite to an unfrozen dynamic support at the same world point. The paired force law is a source contract, not an independent reaction sensor in the proposed observer.
- `features/grip_up/scripts/foothold_candidate_sampler.gd:99`: B1 placement cost considers finite travel, lateral offset, elevation and bearing normal. B2 adds optional local search ranking. Neither policy is an intent-aware release rule for an already planted foot.
- `features/grip_up/scripts/locomotion_support_frame.gd:26`: when hands exist, their normals define the climb tangent; foot support IDs may still be reported. A planted floor foot does not rotate W into the floor as its load rises. Direction must be taken from the actual current support frame, not assumed global axes.

## Causally plausible mechanisms, not established faults

1. **B1 retains a geometrically valid contact.** SUPPORTING can persist with zero force; neutral does not reset the rest length. No input-away, zero-load timeout or same-patch release suppression exists. This can preserve useful compression, or can leave a foot applying friction against intended lateral movement. A force opposed to intent is not sufficient evidence of unwanted sticking: braking and support stabilization can have that sign legitimately.
2. **Rendered anchoring without physical load.** `biped_visual.gd:188` constrains the passive leg target to the solver ankle while PLANTING/SUPPORTING/SLIDING, without a force threshold. A contact with zero transmitted force can therefore still look planted. The physical ankle is not the material contact point or the rendered sole. IK observations must identify their render/modifier phase independently from physics.
3. **Native fixed-body contact persists in B0.** The lower capsule and FootBase remain native physical proxies even with feet OFF. A visually bent leg does not articulate those colliders. Resistance that remains in B0 may come from them, or from hands/ground authority; no foot-release heuristic can be assumed to remove it.
4. **Ground-owner filtering.** The controller suppresses a foot request sharing the native ground support. The foot can still be SUPPORTING with actual committed force zero. State, requested force and committed force must be separated before blaming actuation.
5. **Another constraint can dominate.** The same wall/bar crossing changes hand anchors, shoulder workspace, support moment and native collisions. Foot friction alone cannot be inferred from low COM progress. Observe actual hand forces/reasons, angular motion and ground motor output together.

## Decisive F0 measurements

At a common post-control physics phase, record actual committed foot F, normal/tangent components, load-in, rest error and valid workspace. Include contact-to-actual-COM lever and its cross product with F. Distinguish force projected onto requested direction (N) from F dotted with body/support relative point velocity (W). A useful upward component and reduced hand load may coexist with a negative lateral projection.

Keep support-local anchor identity and current world point, actual support-point velocity and leg length trend. Measure COM progress over an interval, rather than asserting a stall from one tick. Record ground motor force/torque and native contact reporting state. A zero reported native impulse is not proof that no contact can constrain subsequent motion, particularly with a full reporting buffer.

On the visual side, report rendered ankle, rest-calibrated sole proxy, IK target, influence and ownership with their render clock. Their difference from a physics point is not automatically a solver error. During hybrid ownership, cached physical foot forces must not be presented as live actuation.

## Prospective reproduction and interpretation

The new Node exercise is `features/foot_release_lab/tests/foot_release_repro.gd`; the one-condition SceneTree entry is `test_foot_release_diagnosis.gd` in the same folder. The integration owner schedules four fresh processes: B0/B1 at 60/120 Hz. No run was performed by this reviewer.

The new app opens the existing First Ascent from its ordinary spawn, explicitly checks profile 4, A0, B2 OFF, hold controls and the chosen physical-feet flag before its controller's first step. It uses the original course's real input order through left crossing, uncovered right wall and the right bar-leading-edge contact. Contacts are actual bounded adaptive waits, not fixed replay frames. The warmup and controls are declared in the output; this is not a bitwise old-replay equivalence claim.

After reaching that location, both conditions receive identical fixed-duration commands: neutral .30 s; D .60 s; neutral .30 s; A .25 s; neutral .30 s; actual left-hand release, D .45 s while requesting right-hand retention; neutral .30 s. It then makes one real bounded left-hand first-bar recovery selection with W+D and ends neutral. The D-away label describes a requested direction; whether it actually moves away from either foot is determined from the recorded geometry. The requested one-hand stage is not proof that one hand remains attached.

The driver resumes at physics priority 200, after the owner's priority-100 observer. It never assigns body pose/velocity, foot contact, material anchor or force. Its output records setup, adaptive selections, actual material contacts, stage boundaries, support loss and actual cap peaks. Intentional cleanup occurs after measurement and is excluded from support-loss counts. `DIAGNOSTIC_COMPLETE` means that the localized section and diagnostic block were attempted, not that sticking or its absence was proven. `PREPARATION_FAILED` preserves evidence and exits nonzero.

If B0 cannot reach the section because feet are useful earlier in the climb, that is not proof that B1 pins the localized crossing. Any paired in-state feet toggle would require the owner's additional explicit process allocation and a separately labelled intervention, rather than replacing the fresh-condition comparison.

## Source identities read during this review

SHA256, captured before reproduction:

| File | SHA256 |
|---|---|
| `foot_contact_solver.gd` | `efe3e3c3fe0f2bf9d9de9f35df9a0ea768e9f6e168c9fab22fdc4611c5af4fb0` |
| `foothold_candidate_sampler.gd` | `a87cf3ccbf13e8fb38c322fe8720cd68219940af1434ba20e49bd9bc87fa3095` |
| `intent_locomotion_coordinator.gd` | `d72ae7142bc1f94f8a0c26ffc16b5af784080b39fa0becda90dff679e81ca5f0` |
| `locomotion_support_frame.gd` | `a28df3c2f54fda33f7b11fe71c76a171ea18958533db3a0b8b3bb57e8481011c` |
| `biped_visual.gd` | `50f9e4e52170afe361a3baf4af248ef102ef64bfc5e96f7e371bc1d6bbbb7607` |
| `ground_locomotion.gd` | `26178a4b0bd0083f20a4ecf82a501f3b56815ac561f40aeb994b530f99b91798` |
| `foot_tuning.gd` | `fac341838df47ca0a649d33fb276f28173019254cac251ac0db9d118c875aa72` |
| `biped_tuning.gd` | `b8a4f1aaa01c7563144dbbc10b80046fbb4a33fedd7addf75989a028349714c3` |

Decision at this source-review boundary: **F0 evidence pending; no causal classification and no authority for B3 from this review alone.** No inferred human ratings, no claim that automated input reaches the exact player's pose, and no claim that the diagnostic block improves play.
