# v0.5 human pilot ? pending

Automation and native scripted input do not count as human sessions. A native interactive P0 sequence reached ten transfers with zero recoveries;
its archived route took39.51s from first guide to tenth transfer. No subjective
ratings are recorded, and the full three-session comparison remains pending.
See ../validation/v05_human_observed/summary.json for provenance and limits.

Use the same PC, scene geometry,12kg/360N/20Nm/150Nm,arm length policyB,
feetOFF,SpaceOFF and bufferOFF. Choose Controls ?05Ten transfers. HoldLMB/RMB;
mouse movement only selects contacts. Start guide00 withL,01withR,then alternate.
Wait or deliberately swing when the actual shoulder is not in range. Markers
are optional guides, not grip sockets. Tab exposes actual geometry and diagnosis.

1. Learn the controls briefly. Run three sessions of the reference route; the
   target is two uninterrupted ten-transfer completions after learning. R starts
   a new attempt and preserves the comparison settings. Do not count recovery
   as an uninterrupted completion.
2. Compare P0 with P1 (enable the explicit v0.5 refinement checkbox for P1).
   Keep arm policy,spacing and physics fixed. Restart after changing a variant.
   P2 is available only as a labelled research option; it shortened some catch
   windows and is rejected as a default improvement. Compare only deliberately.
3. Use scene06 for deliberate swing-required catches. Compare neutral,pump and
   opposing/braking timing. Observe whether a failure is pose,transit or load.
4. After each run, choose Controls ?Rate current session,including failed runs.
   Rate precision,comfort,agency,recovery,readability and desire to retry1?5.
   Say whether you deliberately chose when to rise,or felt carried automatically.
5. Repeat a longer session to assess fatigue and willingness to continue.

Attempt JSONL is isolated by UTC/PID/session under user://transfer_sessions/;
optional sampled traces include motion/work. Ratings and outcomes are written
to the corresponding user://transfer_sessions/<session>_summary.jsonl. Report which P variant,spacing and buffer setting you
used. Success targets are experimental goals,not claims about current feel.

Compare advisory and held buffer independently; both are OFF by default.
Use the same route and rate fairness/recovery as well as completion. A forecast
is an estimate, not permission to attach. Releasing cancels pending intention.
