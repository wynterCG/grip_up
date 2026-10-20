# FR0: logical targeting versus real picker dispatches

The v1.3.4 correction is evaluation-only. It adds a versioned, read-only derived view of the original targeting audit and actual query sidecar. It does not change `grip_targeting.gd`, production selection, ray order, collision masks, acquisition, contact, strength or reach. Existing R3 archives and their failed N1 receipt remain historical failures.

## Preserved R3 evidence

Original attempt: `swing_catch_train_120_headless_r1_e0310d17`, under `builds/eval_virtual_cursor/benchmark_v133_r3/primary/benchmark_v133_r3/attempts/`.

Its four logical `target.picks` rows comprise:

| Tick | Hand | Meaning | Actual dispatches | Actual rays |
|---|---:|---|---:|---:|
| 1 | 0 | `INVALID_AIM_NO_NEW_TARGET` | 0 | 0 |
| 3 | 0 | Valid `(0,0)` corner aim; all MISS | 1 | 7 |
| 55 | 0 | Source material hit | 1 | 1 |
| 282 | 1 | Destination material hit | 1 | 1 |

The old runner compared four logical events with three physical records and rejected the run as `MISSING_REAL_PICK_RECORDS`. The repair does not add a ray. The new historical migration passes only after exact chronological, ray, material and winner correlation of the three existing dispatches. The 27 endpoint bit fields in the new test fixture were independently checked against the original nine-ray sidecar; they match exactly. The fixture records the original file hashes and marks modified schema cases as synthetic tests, never physical evidence.

## Versioned mapping and identity

`grip_pick_dispatch_contract_v134` preserves the original `target.picks` entries. It emits separate derived `events`, `dispatches` and sidecar-index links:

| Original observation | Derived classification | Query requirement |
|---|---|---|
| Exact `INVALID_AIM_NO_NEW_TARGET`, without an audit | `PICK_SUPPRESSED` | No sidecar for this event |
| Audited real rays and matching actual sidecar | `PICK_RESULT` linked to `PICK_DISPATCH` | Exactly one sidecar per dispatch |
| Unrecognized or ambiguous legacy event | `UNKNOWN_LEGACY_EVENT`, invalid | No inferred pass |

A logical decision alone does not prove a dispatch. A grip request or lifecycle state is not manufactured or inferred by this contract. One picker invocation can issue up to seven rays; it remains one dispatch.

Dispatch identity is `session:t<physics_tick>:h<hand>:d<ordinal>`. Ordinals start at zero for each physics tick and count actual dispatches across both hands in invocation order. Suppressed decisions do not consume dispatch ordinals. Logical event IDs use a separate `e<logical_index>` suffix. The process-local original `pick_call_index` and material collider runtime IDs are retained for forensic comparison within the same process; they do not define cross-process identity.

New opt-in v1.3.4 manifests set `pick_contract_version` to `1.3.4`. Only that path adds `dispatch_identity` and `dispatch_ordinal` at the actual probe's `begin_pick`, and publishes `pick_dispatch_contract.json` plus its result receipt. Its Godot and Python validation require new identity metadata. Legacy offline migration is explicit: `strict_new=False`; it can derive identity only from unambiguous actual chronology and audits. A missing identity in a fresh v1.3.4 record cannot silently enter legacy mode.

Across headless/rendered runs, session IDs legitimately differ. Each run must validate its own full identity; cross-process correspondence uses tick, hand and ordinal, plus the actual fixed tape and required environment, ray, material and physical channels.

## Validation boundary

Both validators require completed streams and complete tick coverage. An aborted stream is `INCOMPLETE_PICK_STREAM` before any attempt to infer a missing ray from an absent tail. The caller supplies the actual completed-engine outcome and expected frame count; array length alone cannot certify completion.

Validation enforces:

- Exact integral numeric hand IDs `0` or `1`, accepting JSON `0.0`/`1.0`; fractional, string, boolean, null and out-of-range IDs are invalid. Cursor coordinates are not rounded or recentered.
- Session, tick, hand, per-tick ordinal, global call index and chronological one-to-one correspondence. Missing, orphan, duplicate and misordered observations are fatal. Repeated suppressed decisions create no query. Repeated dispatch decisions require distinct actual dispatch records.
- Finite numeric 2D/3D vectors of the expected sizes, typed hit material identity and shape, and a boolean selection outcome. Equal null or malformed vectors cannot pass through equality alone.
- Real ray order, offset, screen point, origin, world direction, reason, query origin, mask and range. All seven rays must exist for a no-winner invocation; no query may appear after its selected winner.
- Exact material collider, local point/normal, world point/normal and shape correspondence. The audit winner must equal the actual winning ray and selection state. A MISS cannot carry a fabricated hit.
- The measured query endpoint's binary receipt and native API construction, as specified below.

Unknown schemas and inconsistent observations are invalid, rather than dropped. `MISSING_REAL_PICK_RECORDS` still rejects a real audited dispatch without its sidecar. The repair replaces a faulty logical-event count with stronger identity/content checks.

This is a dispatch-correlation contract, not a standalone validation of every sidecar field. Existing projection validation continues to check sidecar schema, finite fields, phase, camera ownership, requested/effective input, full binary coverage and recorded ray context. H/R comparison continues to compare actual endpoints, published bits, cameras, materials and required physical channels. Probe-disabled runs cannot claim complete dispatch correlation.

## Exact endpoint representation

The measured build uses native float32 `Vector3` components. Its production query endpoint is `origin + direction * 70.0`, with the normal native intermediate and output representation. The contract recomputes only this arithmetic; it issues no query.

Pure JSON roundtrip testing exposed a transport distinction. Godot parsed original endpoint X `-53.594322204589844` as `-53.59432220458984`: raw parsed binary64 bits `ffffffbf12cc4ac0`, whereas the original measured/promoted native value had bits `000000c012cc4ac0`. Casting that named parsed endpoint into native `Vector3` recovered the exact recorded native value. This is a JSON-parser observation, not a physics divergence.

For each endpoint component, the validator requires the original `numeric_bits['/rays/N/query_to/i']` field. It decodes those binary64 bytes and compares them exactly with the independently computed native endpoint promoted to binary64. Equality to that value also proves a finite, exactly promoted native float32 component. Godot separately checks that the parsed endpoint, converted only to its declared native `Vector3` representation, matches the measured component. Python additionally binds the parsed scalar to its measured binary64 bytes exactly. Raw values and measured bit receipts are preserved; the pure Godot test prints both representations and their bits.

There is no epsilon, generalized physics normalization, cursor cast or rounding rule. Missing or malformed bit receipts are invalid. Changing the endpoint and its bits by less than one native ULP, or by one complete native float32 ULP, is rejected. Full raw-sidecar bit integrity remains an independent Python/projection boundary and paired-replay check; Godot's parsed scalar check is explicitly limited to the declared native endpoint representation.

## Owners and execution

- `features/evaluator_virtual_cursor/scripts/pick_dispatch_contract.gd`: pure derived view and validation.
- `tools/auto_tuning/benchmark_qualification/pick_contract.py`: independent runner boundary and historical migration.
- `projection_probe.gd`: opt-in dispatch metadata only; actual query observations remain passed through from production.
- `virtual_cursor_driver.gd`: opt-in derived-view publication and typed rejection only.
- `tests/pick_contract_cases_v134.json`, `tests/test_pick_dispatch_contract.gd` and Python `tests/test_pick_contract.py`: shared file-backed boundary cases.

The new feasibility source/helper identity must include these files and the actual runner, fixtures, catalog and manifests under its new candidate identity. They are not amendments to R3's measured source, certificate or results. Ordinary startup does not set the opt-in manifest field. No protected gameplay file is edited for FR0.

Commands from `C:/Users/Wynter/grip_up`:

```powershell
python -m unittest discover -s tools/auto_tuning/benchmark_qualification/tests -p test_pick_contract.py -v
C:/Users/Wynter/WrapRush/tools/godot.exe --headless --path C:/Users/Wynter/grip_up --script res://features/evaluator_virtual_cursor/tests/test_pick_dispatch_contract.gd
```

Python passes all 49 shared JSON cases through actual temporary files (one unittest method with 49 subcases). The final Godot pure run `pure/pick_contract_004` passes 49 cases / 128 checks, with zero physical bodies. Earlier pure attempts remain preserved: the first exposed integer/float array equality plus an unsafe failing-test access; subsequent failures exposed the exact endpoint parser distinction. No failed attempt is counted as a pass.

Schema tests do not replace a genuine new N1 replay. Physical Gate A, reference fidelity, final fresh-run source identities and independent review outcomes are reported separately by the feasibility pilot. The old N1 remains `RUN_INVALID` in its immutable historical campaign even when its new offline derived view validates.
