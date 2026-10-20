# R3 candidate 003 — measurement certification sign-off

**APPROVED_FOR_PRIMARY**, bound exclusively to source snapshot `a6bd333c5f4fc8f8571d5c907db09f858da9429852befc20e2777f9dc9b36986`. This approval covers PC0–PC2 measurement/admission certification and permits the separately gated primary qualification to begin after the integration and physics approvals. It does not qualify a movement domain, authorize optimization, replace any primary repetition, or approve human feel.

The reviewer performed read-only source inspection, raw-receipt inspection, source/helper/tape hashing, direct trace readback and independent re-execution of the reviewed Python comparator against recorded data. No Godot/physics process, source edit, Git operation, E mirror operation or synchronization was invoked. The reviewer authored the comparison/measurement implementations and discloses that self-review limitation; this is independent raw-evidence readback, not an independent second simulator. The physics specialist's separate sign-off is required.

## Identity and failed candidates

Authoritative candidate directory: `builds/eval_virtual_cursor/benchmark_v133_r3/candidate_preflight/benchmark_v133_r3_candidate_003`. The terminal `results.json` is `CERTIFICATION_READY_FOR_REVIEW`, contains four RUN_VALID processes and two strict pairs, and records zero primary processes. Its SHA256 at review is `fba4fcd119595f4b7c5c8a955d47ab8043baca1c670bc37cd440a5b6d98ed180`.

The combined canonical digest of the actual registered `source_hashes` and `helper_hashes` independently recomputes to the approved snapshot above. All listed C-source/helper bytes still match those registered hashes. Both frequencies use their original canonical tape bytes, each independently hashed against the candidate registration and real manifests. The observed engine remains the pinned binary SHA256 `12310c74bdda7dcd43f28e971f33047dcecadd436b68169d61ce41009006df38`.

Candidates 001 and 002 remain `PREFLIGHT_NOT_CERTIFIED`, failed in PC0 and created no physical replay worlds. They are not silently repaired or credited as passes. Their distinct source identities and raw failed negative-case results remain preserved. The candidate count is three of three; physical replay use is four of twelve, all on candidate 003. Primary use is zero of 96 at this boundary. Pure/schema processes and the later 34 regression processes remain separate ledgers.

## Factory independence and PC0 transport

The current manifest factory first deep-copies the whole manifest, then independently deep-copies `expected_source_hashes`. The second copy is essential: a whole-graph deepcopy preserves aliases inside the graph. The current sequence detaches the manifest from the source registry and also separates its top-level source guard from `baseline_candidate.source_hashes`.

The actual serialized `transport/changed_source/manifest.json` demonstrates the intended negative: top-level `project.godot` hash is all zero, while the baseline candidate and source registry retain original `6ae2782544aa70dfb6a099260ead68de0b0bb7007093ef846bbb2dabfc6a86c9`. The positive manifest's expected/baseline/registry maps match. Therefore the negative changes one guard, not its expected authority or the other guard.

Candidate 003's actual Python→JSON files→Godot suite passes **135 assertions over 41 cases** with zero gameplay bodies. Parsed projection receipts preserve float types and raw `[1024.0,576.0]` / `[1920.0,1080.0]`, then exact canonical integral dimensions. Actual negative receipts include `SOURCE_HASH_MISMATCH:project.godot`, `TAPE_HASH`, and wrong logical viewport rejection, each with empty world creation. The result does not rely on a Python-only mock or a direct in-memory positive dictionary.

## PC1 observations

All seven pure environment/opt-in cases pass: four canonical H/R × 60/120 Hz positives, two genuine wrong-size rejections and wrong opt-in rejection. Wrong-size checks do not silently resize rendered windows or initialize an invalid headless request. No gameplay bodies are created in these checks.

Every real PC2 process independently records valid parsed projection admission, actual backing 1024x576, logical viewport 1920x1080, READY clock and a preworld creation boundary with no old subtrees. Headless explicitly initializes its 64x64 dummy root before the world; rendered observes the real window without forcing it. Actual headless/rendered screen, position and mode differences remain context, not artificial equalities.

At 60 Hz, the rendered process's global preworld callback count differs from headless. Certification compares declared episode ticks and contact-event phases, while preserving global startup callbacks in raw receipts. Both worlds are created only after the correct clock confirmation; no alignment to contact ticks or dropping of gameplay ticks is used.

## PC2 physical chain and exact comparison

| Mode / Hz | Run suffix | POST / input frames | Real picks | Contact / source FREE / retained ticks |
| --- | --- | --- | --- | --- |
| Headless 120 | `f3e424e1` | 536 / 536 | 2 | 440 / 455 / 527 |
| Rendered 120 | `bb7b46fb` | 536 / 536 | 2 | 440 / 455 / 527 |
| Headless 60 | `67af4529` | 263 / 263 | 2 | 215 / 223 / 259 |
| Rendered 60 | `780e6b31` | 263 / 263 | 2 | 215 / 223 / 259 |

All four engine exits are zero and all four receipts are RUN_VALID. Direct readback confirms requested/effective frames agree on every recorded tick, FREE/REACHING/nonattached hand force is exactly zero, real loaded catch contact occurs, the source hand releases, and the destination anchor remains retained. Picking uses the real underside -Y destination and original beyond-static policy. B1 and native-ground contribution are explicitly retained; these are not arm-only trials.

Read-only re-execution of `compare_required` produces **STRICT_MATCH at 120 Hz and STRICT_MATCH at 60 Hz**, with no first unequal INPUT/PICK/CONTACT/PHYSICS/TASK field, exact typed cursor agreement, and point-of-call strict agreement. No physical divergence was observed in the required published chain. The legacy scalar/API-vector cursor discrepancy is still preserved at each frequency with `LEGACY_REPRESENTATION_SELF_COMPARISON`; neither its output nor the raw input is rewritten, and no tolerance is introduced. The comparison is within frequency; different 60/120 contact tick counts are expected and not equated.

Independent maximum-force readback agrees within each H/R pair:

| Hz | Shared hands N | Feet N | Assistance Nm | Combined Nm | Native ground N |
| --- | --- | --- | --- | --- | --- |
| 120 | 254.94798278808594 | 45.47065353393555 | 20.000001395424437 | 67.24547801300011 | 168.000008816823 |
| 60 | 242.3865966796875 | 38.39064025878906 | 20.00000093561646 | 76.7607120562746 | 168.00001406209788 |

These satisfy existing monitor conventions; the 20.001 Nm reporting allowance is historical, not a widened actuator limit. Scenario invariant flags are all false. All four receipts report original resources preserved, correct pre-step installation, unchanged runtime sources, startup profile preservation, restored Hz and disabled replay/returned LIVE camera cleanup. Empty native-contact buffers still do not prove no collisions.

## Approval limits

This sign-off applies to exactly the registered source/helper bytes, pinned engine, original per-Hz tapes, canonical backing and these two within-frequency PC2 pairs. Commit/checkpoint creation may record those identical bytes; any actual source/helper/engine/tape/catalog/binding/config change requires invalidation rather than splicing results. No R1/R2 example contributes an R3 pass.

PC2 is not n=3 primary repeatability, cross-seed/hardware generalization, new-domain onset/metric qualification or observer overhead qualification. Primary references must still run fresh three pairs per frequency, followed by the phased domain gates, separate regression/LIVE/release checks and source integrity checks. Optimizer, private holdout outcomes, default promotion, M7 and human-feel approval remain outside this approval.
