# v1.3.2 prospective protocol — revision 1

Declared before new physical outcomes. Baseline: `0f1a4bf7c6c74c381301475bfcbc18f686e094aa`;
tag `baseline/pre-v1.3.2-qualification`. Historical measured v1.3.1 source recovered
and verified against `24b18d760604fffe3455c5b4c9b8b72f37577b4d`.

No gameplay candidate, parameter sweep, policy threshold adjustment, holdout access,
or promotion. All experiments use A0/B1, profile 4, mass 12 kg. One engine worker.

## Finite budget and selection

- Development: at most 8 engine launches to establish recorder/runner integrity.
  These are unqualified and retained, including failures. A source edit resets the
  implementation identity, never retroactively certifies a development result.
- Preparation diagnostics: at most three declared lawful input scripts, both
  hand variants in both execution modes, first 120 Hz then 60 Hz, one attempt
  per script/side/rate/mode (24 attempts, four processes with six episodes each).
  No script timing is selected by a reward; first eligible script in declared
  order is selected. If none is eligible, retain missing coverage and NO_GO.
  Each screen observes the accepted quiet onset for .25 s, then tries the same
  directional drive (maximum2 s) and accepted neutral onset used by motion tasks.
  Quiet and motion eligibility are recorded separately; select the first valid
  script separately for each onset class, mode/Hz/hand. The extra drive is a
  fixed diagnostic suffix, not another script or a motion-score search.
- Reference capture: first complete adaptive catch episode at each Hz in a fresh
  headless process; no best-of selection. One reference per Hz. Failed first
  capture is evidence and blocks qualification until directly diagnosed.
- Primary catch: 2 lanes × 2 modes × 2 Hz × 2 contexts × 3 independent processes
  = 48 processes. Sequence context runs the public two-hand release control first,
  then synchronously retires its world before catch. This is a named reduced
  public sequence, not a claim about every historical curriculum ordering.
- Instrumentation: R0 isolated, 2 modes × 2 Hz × 4 trace/observer combinations ×
  3 paired repetitions. The 12 ON/ON primary processes are reused; 36 additional
  processes. OFF controls keep compact requested/accepted/effective event audit
  and safety checks. No full trajectory equivalence claim without full trace.
- Controls: 2 modes × 2 Hz × 3 independent processes = 12 processes, each running
  the named mirror/control catalog. Adaptive preparation, fixed observation
  commands; no claim these are an additional qualified R0 distribution.
- No automatic expansion beyond three repetitions. At most four direct diagnostic
  launches after a hard integrity failure. Such failure stops the scoring matrix;
  diagnostic evidence cannot be silently relabelled as certification.
- Existing 60/120 Hz regression suite and one native MCP review are separate
  safety checks, not candidate trials or extra distribution repetitions.

## Prospective comparison contract

Identity is strict for Hz, phase, source/engine, scenario geometry, tape hash,
fixture mapping, bindings and actual input transitions. Starting physical fields
use 1e-6 m / m/s / rad/s localization epsilon, not an outcome equivalence band.
Exact accepted logical stream equality is required; effective frame direction,
camera/target and grip decisions are compared separately. First divergence ends
the physical equivalence window. Real task failure is never an integrity pass.

No continuous scored metric is initially eligible. Three pilots per mode/Hz cell
can support descriptive envelopes only. A specialist must review any proposed
scenario-specific envelope before a future candidate study; current results
cannot establish an arbitrary global tolerance. Missing one-hand60 coverage,
unresolved replay integrity or unqualified essential metrics gives NO_GO.

Catch contact + same-anchor retention + source release remain mandatory safety
gates even when continuous catch metrics are quarantined. Foot/ground work stays
visible. Automation does not assess human enjoyment.
