"""Single-factor local perturbations, with repeated paired center evaluations."""
import argparse
from pathlib import Path

from aggregate import summarize
from candidate_schema import PARAMETER_IDS, baseline, parameter_resource, parameter_rows
from common import ROOT, StudyLock, atomic_json, read_json
from run_trial import make_candidate, run_trial


def run(study: Path, output: Path, repeats=2):
    if not 2 <= repeats <= 5:
        raise ValueError("local sensitivity requires two to five repeated center/perturbation runs")
    manifest = read_json(study / "study_manifest.json")
    provenance = manifest["identity"]["provenance"]
    resource = parameter_resource()
    rows = parameter_rows(resource)
    center = baseline(resource)
    train = read_json(ROOT / "features/auto_tuning_lab/resources/train_scenarios.json")
    scenarios = [row["id"] for row in train["scenarios"]]
    variants = [("center", center)]
    for key in PARAMETER_IDS:
        for sign, label in ((-1, "minus"), (1, "plus")):
            values = dict(center)
            delta = .1 * (rows[key]["max"] - rows[key]["min"])
            values[key] = round(max(rows[key]["min"], min(rows[key]["max"], center[key] + sign * delta)), 8)
            variants.append((key + "_" + label, values))
    with StudyLock(output):
        if (output / "sensitivity.json").exists():
            raise FileExistsError("sensitivity result immutable; use a new output directory")
        results = []
        for label, values in variants:
            outcomes = []
            paths = []
            for repeat in range(repeats):
                candidate = make_candidate(values, scenarios, trial_id=f"sensitivity_{label}_r{repeat + 1}",
                                           seed=manifest["identity"]["config"]["run_seed"], provenance=provenance)
                outcome, path = run_trial(candidate, output / "trials", resource=resource)
                outcomes.append(outcome)
                paths.append(str(path.relative_to(output)))
                if outcome["status"] not in ("completed", "invalid_candidate"):
                    record = {"status": "stopped", "reason": outcome["reason"], "results": results,
                              "failed_variant": label, "retained_failure_path": str(path.relative_to(output))}
                    atomic_json(output / "sensitivity.json", record)
                    return record
            results.append({"variant": label, "parameter_overrides": values, "paths": paths, "summary": summarize(outcomes)})
        record = {"status": "completed", "center": "A0 baseline", "step": "ten percent of each certified range, one knob at a time",
                  "repeats": repeats, "scope": "local numerical effects; not a global causal model or proof of human preference", "results": results}
        atomic_json(output / "sensitivity.json", record)
        return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--study", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--repeats", type=int, default=2)
    args = parser.parse_args()
    result = run(args.study, args.output, args.repeats)
    print(result["status"])


if __name__ == "__main__":
    main()
