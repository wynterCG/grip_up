"""Compare old authored-code geometry with revision-1 data, not object IDs."""
import hashlib
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[4]
keys = ("geometry", "mirror", "mode", "direction", "selected_point", "last_normal",
        "signed_progress", "outcome", "displacement", "relative_partial_work_j",
        "peak_force_n", "loaded_samples")
comparisons = []
for hz in (120, 60):
    name = f"measurement_physics_{hz}hz.json"
    old = json.loads((HERE / "before" / name).read_text(encoding="utf-8-sig"))
    raw = ROOT / "builds" / name
    new = json.loads(raw.read_text(encoding="utf-8-sig"))
    (HERE/name).write_text(json.dumps(new, ensure_ascii=False, indent=2), encoding="utf-8")
    differences = []
    for i, (a, b) in enumerate(zip(old["feet"], new["feet"])):
        for key in keys:
            if a[key] != b[key]:
                differences.append({"case": f"foot_{i}", "field": key, "before": a[key], "after": b[key]})
    for key in ("swing", "reaction", "checks", "failures", "decisions"):
        if old[key] != new[key]:
            differences.append({"case": key, "before": old[key], "after": new[key]})
    comparisons.append({"physics_hz": hz, "physical_outcomes_exactly_equal": not differences,
                        "differences": differences, "fixture_revision": new["fixture_revision"],
                        "fixture_sha256": new["fixture_sha256"],
                        "outcome_changes_expected": new["outcome_changes_expected"]})
files = ["features/locomotion_test_suite/tests/test_measurement_physics.gd",
         "features/locomotion_test_suite/resources/technical_fixtures_r1.json"]
result = {"scope": "Exact comparison of reported physical outcomes; process-local object IDs/selection diagnostics excluded",
          "comparisons": comparisons,
          "source_sha256": {name: hashlib.sha256((ROOT/name).read_bytes()).hexdigest() for name in files}}
(HERE/"comparison.json").write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
print(json.dumps(result, indent=2))
raise SystemExit(0 if all(row["physical_outcomes_exactly_equal"] for row in comparisons) else 1)
