# Baseline audit

Pre-change Git was clean at `0f1a4bf7c6c74c381301475bfcbc18f686e094aa`.
Created recoverable annotated tag `baseline/pre-v1.3.2-qualification` and branch
`feature/v1.3.2-evaluator-qualification`. Historical tag
`baseline/v1.3-study-frozen` still resolves to
`afa04c9c322864dd75a32a1fcc6a87e6c9225864`.

The archived v131 raw source map was recovered from `source_24b18d7.zip` and all
254 public source hashes matched measured commit
`24b18d760604fffe3455c5b4c9b8b72f37577b4d` in both C and E copies. Measured code
and final documentation handoff commits are deliberately distinguished.

Before edits, 815 tracked historical feature/tool/auto-tuning-document files were
hashed and preserved. `baseline/freeze.json` is that exact pre-edit receipt.
The independent specialist rechecked all 815 with zero differences. Private
holdout outcomes were not opened. New evaluator source is confined to
`features/evaluator_qualification` and `tools/auto_tuning/evaluator_qualification`;
new documentation/spec and export/ignore exclusions are the remaining changes.

Godot `4.7.2.stable.steam.ed1daf0bf`, integrated Jolt; binary SHA256
`12310c74bdda7dcd43f28e971f33047dcecadd436b68169d61ce41009006df38`.
Ordinary project config SHA256
`6ae2782544aa70dfb6a099260ead68de0b0bb7007093ef846bbb2dabfc6a86c9`.
Janga grabber SHA256
`8ab923ac1d903e8dcc8ed2a2e4f9f8c5cec326a3217cb4a9d8f00036557e7dad`;
rollback build SHA256
`fb018cfbf8ac57dac83c43af6590f2107bede466d56053e1218583f03564e33d`.

Fresh ordinary-runtime preflight (`baseline/normal_runtime.json`): profile2,
120 Hz, allocation0, hold-to-grip true, physical feet false, intent-aware feet
false, observer/capture recorder false, 12 kg, reach .65708 m, A0 resource
.25/.12/.24/.9. W/S/A/D and left/right mouse bindings observed unchanged.
This preflight is automated headless evidence; it is not a human playtest.

Final restoration, native MCP review, mirror parity and full protected-file
checks are published in `verification.json` after the experiment matrix. No
gameplay tuning, force/reach increase, collider change or candidate promotion is
part of this qualification.
