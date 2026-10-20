# Independent final review — virtual cursor requalification

Date: 2026-10-20. Campaign: `requal_20261020_r1`.

**Binary decision: NO_GO_INPUT_REPLAY under the frozen strict headless/rendered picking contract.** Input noninterference has positive, narrowly scoped evidence in the recorded rendered pairs. That evidence does not erase the cross-mode gate, complete the24-run matrix, qualify continuous metrics or authorize optimization.

The specialist read source and results only. No engine was launched, no source changed, no tolerance introduced and no new capture or trial requested. Earlier campaign failures, tapes and decisions remain historical and separate.

## Identity and executed scope

Frozen commit: `036a9dc719baef92d9dc41408e20d90ce50bad85`. All280 source hashes and the separately hashed orchestration wrapper were independently rechecked against `source_identity.json`: unchanged. The wrapper SHA-256 is `267b78294c1bd4d9d16a0a72dec0f0dcd91497ae3b4a1ccc1bf7cb89b7351c77`.

The new campaign used two fresh source captures, then executed six accepted headless qualification repeats and one rejected rendered qualification attempt. Thus **7/24 primary attempts ran;17 remain not run after the gate**. Four further processes were explicitly diagnostic, not replacement qualification cells. This review covers all11 replay/diagnostic runs plus the two captures:13 worlds and5,330 recorded POST snapshots.

All paths below are under `builds/eval_virtual_cursor/requal_20261020_r1`:

| Group | Actual evidence |
|---|---|
| Sources | `capture/attempts/`: one120-Hz and one60-Hz fresh capture |
| Primary headless | `baseline/attempts/`: H120 n3 and H60 n3, all accepted |
| First rendered primary | `V0-R_120_r1_f2b1ab4d`: strict picking rejection |
| Started-unfocused diagnostic120 | `diagnostic_human120/attempts/D_MOUSE_FOCUS_120_r1_896ac6b7` |
| Quiet-render diagnostic60 | `diagnostic_quiet60/attempts/D_RENDER_QUIET_60_r1_3cf7908d` |
| Focus-change diagnostic60 | `diagnostic_human60/attempts/D_MOUSE_FOCUS_60_r1_64aee090` |
| Mouse diagnostic120 | `diagnostic_mouse120/attempts/D_MOUSE_FOCUS_120_r1_8afaa588` |

Every engine process completed its physical task and recorded real load-bearing catch/retention. The first rendered primary and all four diagnostic receipts remain rejected against the headless reference. Process/task completion is not a picking qualification pass.

## Corrected admission and headless repeatability

The six headless repeats successfully consumed serialized corrected-source tapes through the actual replay entry. Requested and effective canonical frames, logical aim, camera/ray, normalized material anchors and the comparator's selected physical fields matched their same-Hz source, with no first divergence reported.

This closes the prior JSON admission failure for these samples. It does not retroactively repair the earlier failed qualification or imply a cross-frequency identical-trajectory requirement.120 and60 Hz remain separate conditions.

## Strict cross-mode divergence

###120 Hz

The first rendered primary differs at destination selection tick282:

- Requested/effective input and cursor remain exact for all536 ticks.
- Pick camera node pose, complete recorded projection matrix, ray origin, pointer pixels, winning offset `(0,0)`, collider `catch`, shape0 and underside normal `[0,-1,0]` match.
- Ray direction norm difference: `1.54318774049e-7`.
- Selected local material point norm difference: `8.10710818482e-7 m`, approximately0.811 micrometres.
- First published force-budget difference:440; first velocity/spin difference:442; first source-body-pose metadata difference:443; first COM difference:449.
- Actual contact440, source FREE455 and required retention527 all occur on the intended underside.

###60 Hz

The quiet rendered diagnostic first differs at **source selection tick28**, rather than at the later destination:

- Requested/effective input and cursor match the263-tick tape.
- Pick camera node pose and complete recorded projection matrix match at that first pick. Ray origin, central winning offset, collider `source`, shape0 and underside normal `[0,-1,0]` also match.
- Ray direction differs only in its Y component at the first recorded comparison: `0.118181772530079` expected versus `0.118181802332401` actual. Norm difference: `2.98023219991e-8`.
- Local material point norm difference: `1.47453747712e-6 m`, approximately1.475 micrometres.
- First force-budget difference:46; first velocity/spin and source-body-pose metadata differences:48; first COM difference:65.
- Rendered60 contacts the destination at210, compared with215 in the headless source; both release the origin at223 and reach required retention at259.

The tiny ray/material differences are real under the **exact preregistered numerical gate**. They are not a wrong-face flip, a cursor reset, a meaningful force-limit violation or an independently demonstrated Jolt defect. No epsilon was invented to rescue these runs.

Equal serialized camera pose/projection does not expose every internal camera/viewport transform or projection conversion. Headless backing window1024×576/final scale0.533333361 and rendered1440×810/final scale0.75 differ despite the common logical viewport1920×1080. This is a recorded context difference, not a proven cause. No camera/viewport code or solver was changed after observing it.

## Rendered-versus-rendered paired diagnostics

`paired_summary.json` and the three `paired_rendered_comparison.json` files preserve a separate comparison against quiet rendered references at the same frequency. The pair tool substitutes **only reference observations**; it retains the same frozen source tape frames and records both audit hashes and the input tape hash. It does not mint a new adaptive input policy or retag the original headless comparison.

The tool's independently recorded SHA-256 is `c4f3bd4811943b1c0b9fc4e5f632149162c3f138ef2fe8cac6bca6d76aa1d091`. It is postprocessing outside the frozen runtime source set.

| Diagnostic versus quiet rendered reference | Observed paired result |
|---|---|
| Started-unfocused120 versus first quiet rendered120 | No difference in any compared layer |
| Focus-change60 versus quiet rendered60 | No difference in any compared layer |
| Mouse120 versus first quiet rendered120 | No difference in any compared layer |

The compared fields include canonical input, effective cursor, camera, ray/selection, normalized material anchor/state chain, body COM/pose/velocity/spin/mass, published budgets and hand state/force. This is not a claim that every native contact manifold or internal solver cache was compared.

These exact observed pairs are useful positive noninterference evidence. They remain **DIAGNOSTIC_ONLY**, with one observation per circumstance, not three repetitions per primary V0-M/F cell. All original headless-reference rejections remain unchanged.

## What external activity was actually recorded

| Diagnostic | Observable disturbance/focus evidence | Cadence and limitation |
|---|---|---|
| `896ac6b7`,120 Hz | Initial focus false at tick0; no later focus callback or rejected game event.59 distinct safe hardware-pointer samples while virtual input runs. |536 ticks; maximum measured gap20,334 µs. Demonstrates a started-unfocused run, not an ACTIVE Alt+Tab transition. |
| `64aee090`,60 Hz | Initial focus true; external callback stamped at prior committed tick132 changes focus false. First subsequent POST with false focus is133;131 POSTs are unfocused. One game-delivered key event rejected;202 distinct hardware-pointer samples. |263 ticks; maximum gap34,469 µs. Continued physics and unchanged paired input/picking after focus loss are observed. No return-to-focus transition is recorded. |
| `8afaa588`,120 Hz |220 MouseMotion and2 MouseButton events rejected;474 distinct hardware-pointer samples. Focus stays true, with only the initial tick0 sample. |536 ticks; maximum gap34,728 µs. No focus transition or outside-window click is established by those game-delivered button counts. |

The initial focus sample is not an event caused by the person. Event rejection/hardware readback alone does not identify the exact user gesture or application receiving a click; the owner's separately requested human attestation must remain an additional evidence source. Do not silently infer outside-window clicking, a particular Alt+Tab sequence, focus return, minimization or process suspension.

These measured runs continued without the prospectively invalidating250 ms gap. The first rendered primary has a maximum gap203,103 µs, also below that fixed guard. This does not prove zero interruption or uninterrupted background scheduling under every operating-system condition. No minimized/suspended condition was demonstrated.

## Physical authority, reach and budgets across all13 worlds

Independent review of all5,330 POSTs found:

- Mass12 kg, profile4 and no hybrid ownership throughout.
- 1,874 REACHING hand-state observations, all with exactly zero published hand force.
- No non-ATTACHED/non-SLIPPING hand with nonzero published force.
- Finite body COM, linear-velocity and angular-velocity vectors in all checked rows.
- All published invariant flags false; cleanup receipts remove provider/router authority, restore LIVE camera, clear held state and leave the hands RELEASED.

Aggregate controlled-channel peaks:

| Channel | Observed peak | Unchanged limit |
|---|---:|---:|
| Shared hands |254.947983 N |360 N |
| Total feet |45.470654 N |180 N |
| Individual foot |45.470654 N |120 N |
| Shared assistance |20.0000014 Nm |20 Nm |
| Combined published ground/climb moment |76.760712 Nm |150 Nm |

The micro-Nm excess in the computed norm is float component rounding, not a new assist budget. Foot normal load never goes negative; maximum observed tangent/normal ratio0.437020 is below unchanged friction0.85. Maximum REACHING endpoint distance is0.65708015 m, float-scale rounding around0.65708 m; largest ATTACHED separation is0.65408325 m. Distant target distance must not be mislabelled as physical arm stretch.

Ground drive is an existing separate authority: aggregate peak ground force168.000014 N and torque65.000006 Nm. The combined moment channel includes its contribution; no new ground force source was introduced. Native collision impulses are not claimed to share the actuator cap.

All13 tasks have actual loaded `catch` contact, origin FREE and a final same-anchor chain of at least0.6 s, on the intended `-Y` underside and initially beyond0.65708 m reach plus the existing0.02 m policy margin.120-Hz final chains last0.675 s;60-Hz chains last0.666667 s.

The task is **not arm-only**. Most120 episodes contain160 ground/26 loaded-foot ticks; headless60 contains107/25, whereas rendered60 contains95/26. These counts include preparation, not ground at final capture. No dynamic support reaction-pair qualification is provided by these static fixtures. No physics improvement or gameplay-feel claim follows from the successful task outcomes.

## Final scoped judgment

The renewed authorization was used to preserve a new corrected-source campaign. It produced real headless JSON replay success and positive sample-specific rendered noninterference, while retaining the strict cross-mode failure and not completing the skipped qualification cells.

Therefore:

- **NO_GO_INPUT_REPLAY** under the frozen exact cross-mode picking contract.
- **Positive observed input noninterference** in the recorded rendered pairs, including delivered mouse/button rejection and continuing physics after the recorded focus loss.
- No claim of full V0-M/F n3 coverage, outside-click/focus-return/minimize coverage, universal background scheduling, continuous physical equivalence, or causal resolution of historical R0 failures.
- Ordinary MCP startup/default restoration remains supplementary owner evidence, not another V0 cell; it should be reported separately when complete.
- No ML/Optuna/Jev/RL, holdout access, candidate promotion, physics retune or M7 approval.

No further runtime or source action is requested by this specialist review. Preserve the two sources, all11 replay/diagnostic receipts, rejected strict comparisons, separate paired results and missing-coverage table in the final archive.
