# Native course evidence

`attempt_005` is the final complete two-frequency replay, with fresh JSON and
stage/crossing/finish frames. Its `results.json` pins the shared exercise hash.

Attempts 001-004 retain development failures and earlier successes. Their JSON
is the authoritative per-run result. PNG output filenames were reused during
development; copying the directory after a failed run could also retain a
crossing frame from an earlier successful run. In particular the crossing PNGs
beside failed 120 Hz attempt 003 and failed 60 Hz attempt 004 are stale, and do
not establish a crossing in those failed runs. Do not infer a pass from them.

These are automated native-window tests using ordinary in-application inputs
through Godot MCP Pro, not human playtests or ratings of gameplay feel.
