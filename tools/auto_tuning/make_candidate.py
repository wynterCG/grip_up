"""Create a fully observed baseline/override manifest, without starting Godot."""
import argparse
from pathlib import Path

from candidate_schema import baseline, parameter_resource, validate_candidate
from common import ROOT, atomic_json, read_json
from run_trial import make_candidate


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--trial-id", required=True)
    parser.add_argument("--overrides", type=Path)
    parser.add_argument("--scenario", action="append")
    parser.add_argument("--hz", type=int, choices=(60, 120), default=120)
    parser.add_argument("--seed", type=int, default=101)
    parser.add_argument("--timeout", type=float, default=180)
    args = parser.parse_args()
    resource = parameter_resource()
    train = read_json(ROOT / "features/auto_tuning_lab/resources/train_scenarios.json")
    scenarios = args.scenario or [row["id"] for row in train["scenarios"]]
    candidate = make_candidate(read_json(args.overrides) if args.overrides else baseline(resource), scenarios,
                               trial_id=args.trial_id, hz=args.hz, seed=args.seed, timeout=args.timeout)
    validate_candidate(candidate, resource, {row["id"] for row in train["scenarios"]})
    if args.output.exists():
        raise FileExistsError("candidate manifest is immutable; choose a new output")
    atomic_json(args.output, candidate)
    print(args.output.resolve())


if __name__ == "__main__":
    main()
