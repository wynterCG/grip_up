"""Freeze a small, diverse Pareto shortlist before a separate holdout process."""
import argparse
from pathlib import Path

from candidate_schema import baseline, candidate_id, parameter_resource
from common import ROOT, atomic_json, digest, file_hash, read_json, utc_now
from scoring import AXES, nondominated


def select(records, top=5):
    eligible = [row for row in nondominated(records) if row["score"]["meaningful_screening_gain"]]
    selected = []
    for axis in range(len(AXES)):
        if eligible and len(selected) < top:
            choice = max(eligible, key=lambda row: row["score"]["values"][axis])
            if choice not in selected:
                selected.append(choice)
    for row in sorted(eligible, key=lambda value: value["candidate_id"]):
        if len(selected) >= top:
            break
        if row not in selected:
            selected.append(row)
    return selected


def freeze(study_path: Path, output: Path, top=5):
    if not 1 <= top <= 8:
        raise ValueError("shortlist bound is one to eight; human finalists at most two or three")
    if output.exists():
        raise FileExistsError("shortlist is immutable; use a new version if selection changes")
    state = read_json(study_path / "study_state.json")
    manifest = read_json(study_path / "study_manifest.json")
    if state["status"] not in {"completed", "stopped"}:
        raise ValueError("finish/stop training before freezing selection")
    values = baseline(parameter_resource())
    selected = select(state["trials"], top)
    record = {
        "schema_version": "1.0", "frozen": True, "frozen_at_utc": utc_now(),
        "train_study_manifest_sha256": file_hash(study_path / "study_manifest.json"),
        "train_state_sha256": file_hash(study_path / "study_state.json"),
        "provenance": manifest["identity"]["provenance"],
        "baseline": {"candidate_id": candidate_id(values), "parameter_overrides": values},
        "selection_rule": "practical-gain Pareto set, axis extremes then candidate ID order; no single numeric winner",
        "candidates": [{"candidate_id": row["candidate_id"], "parameter_overrides": row["parameter_overrides"],
                        "train_trial_id": row["trial_id"], "train_score": row["score"]} for row in selected],
        "holdout_accessed_before_freeze": False, "promotion": "NONE; repeated validation and human review still required",
        "no_candidate_reason": None if selected else "no robust practical Pareto screening improvement; retain baseline",
    }
    record["freeze_sha256"] = digest(record)
    atomic_json(output, record)
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--study", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--top", type=int, default=5)
    args = parser.parse_args()
    record = freeze(args.study, args.output, args.top)
    print(f"frozen {len(record['candidates'])} candidates: {args.output}")


if __name__ == "__main__":
    main()
