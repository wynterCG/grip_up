# Headless backing initialization correction

**PASS — startup/admission correction.** The benchmark now initializes its headless backing to1024×576 and observes a1920×1080 logical viewport before constructing a gameplay world. Twelve positive preflights passed: headless/rendered ×60/120Hz ×3 independent processes. The wrong-size negative and six additional driver-scope checks also passed. No climbing, catch or parameter-search process was launched.

## Change and authority

User instruction: “Corrigir a inicialização headless”. This authorizes correcting and testing admission; it does not reopen the old matrix or promote any benchmark domain. The old `benchmark_v133_r1` NO_GO, raw files, report and decision remain unchanged. This correction uses new result directories `benchmark_v133_headless_init_r1` and `benchmark_v133_headless_init_r2`.

The shared test-only `benchmark_backing.gd` initializer is used by both the preflight and the benchmark driver. On this Godot build, headless starts with a64×64 dummy Window and ignores the engine resolution hint. The initializer requires an explicit canonical size through `--backing-size 1024x576` after `--`; launchers send the same size in the engine's `--resolution` option. It records before/requested/actual/logical size and that initialization occurred before gameplay-world creation. It does not change content scaling, body state, physics rate, player controls, camera behavior or tuning.

Noncanonical or absent headless requests are rejected before any setter. Rendered windows are observed and rejected if their actual size is incorrect. A noncanonical manifest projection size is also rejected before world construction. In-episode resize/environment guards remain in place; this initializer only runs at admission. The common campaign launcher now passes the script-visible argument, so the eventual real benchmark entry uses the same path as the preflight.

## Preserved failed development attempt

The full measured commit of the failed first implementation is recorded in the r1 source manifest. That first implementation attempted to read `--resolution` through `OS.get_cmdline_args()`. Godot consumes that engine option before exposing the arguments to scripts. Its first positive preflight was therefore rejected as `RESOLUTION_ARGUMENT_REQUIRED`, before any clock branch or gameplay body. This unsuccessful attempt is archived without replacing or reclassifying it. The subsequent correction passes the requested size explicitly through script-visible user arguments.

## Fresh corrected validation

Measured source: `486e03afdb9d169c1d2c7528fbd656660cc3d521`. Engine:4.7.2-stable Steam, SHA256 `12310c74bdda7dcd43f28e971f33047dcecadd436b68169d61ce41009006df38`. Complete source maps and source delta are in `verification.json`.

| Check | Processes | Result | Gameplay worlds |
|---|---:|---|---:|
| Headless60Hz,1024×576 |3|PASS; logical1920×1080; last two deltas1/60|0|
| Headless120Hz,1024×576 |3|PASS; logical1920×1080; last two deltas1/120|0|
| Rendered60Hz,1024×576 |3|PASS; logical1920×1080; last two deltas1/60|0|
| Rendered120Hz,1024×576 |3|PASS; logical1920×1080; last two deltas1/120|0|
| Wrong headless1440×810 request |1|Correctly BLOCKED_SETUP/CANONICAL_BACKING, without initialization|0|
| Canonical headless driver admission60/120 |2|Backing accepted; intentionally stops at missing TAPE_HASH|0|
| Missing headless explicit-size argument60/120 |2|Correctly rejected without initialization|0|
| Wrong rendered1440×810,60/120 |2|Correctly rejected without initialization|0|

There are19 successful admission assertions in r2, including seven deliberate rejections. The canonical driver checks intentionally provide no tape: reaching TAPE_HASH proves the environment scope was admitted, not that V0 replay, clock settling in a gameplay world, picking or catching was qualified. Including the preserved failed development attempt,20 engine processes were used for this correction's admission tests, zero gameplay worlds.

Both benchmark entry scripts pass Godot parse checks; the34 existing Python benchmark contract tests pass. Godot MCP Pro inspected the imported project: no new script/parse errors; one existing nested-project warning remains. The owned editor was closed and both project settings files restored byte for byte. No gameplay session was started by this MCP check.

The only source-map changes relative to the previous frozen benchmark are the new backing helper, its two callers and the benchmark launch command. Working C and canonical E source maps match. Original gameplay files, project settings and export preset remain unchanged. Historical reports/tapes are preserved; source archives and raw receipts are hash-verified in `evidence_manifest.json`.

## Remaining scope

The initialization blocker is fixed and admission checks pass. The historical NO_GO is not retroactively changed. No new movement domain is eligible, and no fresh Swing & Catch pair or new-domain matrix was run here. Qualification can proceed from a separately frozen new campaign using this corrected launch path; this correction itself grants no optimizer or physics-default promotion.

Executed admission command: `python tools/check_benchmark_backing.py --attempt r2`. Used paths are immutable; rerunning into them is rejected.
