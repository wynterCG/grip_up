# R3 preflight contract certification

Candidate003 passed PC0/PC1/PC2 on one exact source snapshot:
`a6bd333c5f4fc8f8571d5c907db09f858da9429852befc20e2777f9dc9b36986`.
This report precedes primary qualification and grants no scoring eligibility.

## Actual transport

The shared Python `campaign.build_manifest` generated complete baseline candidates and projection structures. Each test serialized a manifest to disk; Godot read and parsed those bytes before calling the original benchmark driver's admission. The same factory and `Backing.projection_schema`/`canonical_dimensions` are used by full replay. The four PC2 processes then continued through the full tape/engine/source admission, real clock handshake, real V0 picking, controller and Jolt. There is no separate loose positive replay path.

PC0 executed41 file-backed cases and135 assertions in one Godot process. Numeric int, float and mixed input for both `window_size` and `logical_viewport_size` survived the JSON parser (which reports float) and produced canonical integer dimensions. Raw serialized config, parsed values/types, canonical values, reasons and per-file SHA are retained. Fractional, string, bool, null, wrong length, swapped, zero/negative, oversized, object/nested, missing fields and nonboolean probe flags were rejected. Synthetic non-JSON NAN/INF were rejected and stored using explicit nonfinite labels. No pixel, ray or physical sample is rounded by this dimension utility.

The same batch exercised corrupted tape and source hashes through full `driver.start`, actual viewport mismatch, idempotence, rejection of a changed backing without repair, the actual clock handshake's missing-confirmation/stale-rate rules, and duplicate/missing/out-of-order JSON frame rejection. No gameplay body was created. Actual source/tape negatives reached their original guards, not mocked Python answers.

PC1 separately executed7 pure processes: H/R60/120 positive environments, wrong rendered actual1440×810, wrong headless declared size, and missing evaluator opt-in. Positives observed1024×576 backing,1920×1080 logical viewport and two correct callbacks before bodies. Rendered setup never overwrote a wrong window size. Wrong dimensions/opt-in were rejected before world creation. Requested and actual screen/window context, transforms and clock transients remain raw evidence.

## Real replay before source freeze

| Cell | POST samples | Real contact | Source FREE | Destination retained | Same-frequency pair |
|---|---:|---:|---:|---:|---|
| H120 |536|440|455|527|STRICT_MATCH|
| R120 |536|440|455|527|STRICT_MATCH|
| H60 |263|215|223|259|STRICT_MATCH|
| R60 |263|215|223|259|STRICT_MATCH|

These are four new certification processes using the original frequency-specific tapes. They do not count as primary reference pairs. Both comparators' full published INPUT/PICK/CONTACT/PHYSICS/TASK chains were inspected at matching ticks. The new typed cursor audit preserves raw scalar64 values/bits, native float32 values/bits and exact cross-mode equality. The legacy self-representation discrepancy remains included with its explanation. No epsilon, changed raycast, contact substitution or physics tolerance was added.

Actual hand attachments, material anchor retention, source release, zero FREE/REACHING traction, foot/native ground authority, original budgets and clean teardown were reviewed independently. Catch retains B1/ground contributions; it is not an arm-only benchmark. The physics and measurement sign-offs are limited to PC0–PC2 and bound to this source/engine/tape identity.

## Failed candidates retained

Candidate001 failed a pure negative-source test because a mutable manifest aliased the source registry. Its identity guard rejected the changed in-memory dictionary; actual source files were unchanged. Candidate002 detached the registry but retained an alias between the manifest's two source maps, so its source-negative reached a different original guard than the test expected. Candidate003 detaches these fields independently; a Python regression checks both boundaries. Candidates001/002 consumed zero physical replay processes and remain NOT_CERTIFIED, with stdout/stderr and exact old source snapshots.

Preflight ledger:3 distinct candidates,4/12 physical replay processes,3 base transport processes and7 environment processes. No additional per-candidate repair-diagnostic engine processes were used. Development parse checks and Python contract runs are recorded separately; the final unique Python contract suite has49 passing tests. None of these checks fills primary qualification cells.

The next step is to commit the identical certified bytes, issue `certified_source.json`, run the separate34-process regression suite, and only then start BQ1/BQ2 of the new primary campaign. No optimization or human-feel approval is implied.
