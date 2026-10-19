# Native Godot MCP Pro demonstrations

These are **automated real-input demonstrations**, not human play sessions.
Source: actual running Godot viewport, captured at nominal15 fps,1280?720,
no narration, no added music. Frames may have variable wall-clock spacing;
the JSONL physics traces are authoritative for simulation timing.

- `abc_automated.mp4`: identical authored FootSupport geometry, physical feetOFF;
  A/B/C length policies, single/dual grips, supported swing and reactive beam.
- `ten_transfers_automated.mp4`: ten alternating transfers on the existing wall's
  clear left lane, policyB,0.16m spacing,8 deliberate extra A/D presses,23.90s
  trial time. No collider changes, torso snapping, Space, wheel arm inputs or retries.

The full comparative capture contains37 passing native checks per frequency;
`rendered_{120,60}hz.json` and session samples contain the diagnostics. Samples
include QA iterations; adverse reports are preserved separately. A60Hz earlier
native trial lost both attachments between snapshots; a fresh run passed all37.
The first interruption's cause is not established by its incomplete event data.
