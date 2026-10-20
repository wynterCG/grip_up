"""Separate repeat/holdout process. Withheld files are never imported by optimize."""
from __future__ import annotations

import argparse
from pathlib import Path
import statistics

from aggregate import summarize
from candidate_schema import parameter_resource
from common import ROOT, StudyLock, atomic_json, digest, engine_identity, file_hash, git_identity, read_json, source_hashes, utc_now
from run_trial import make_candidate, run_trial, validate_shortlist
from scoring import AXES, Unrankable, build_reference, compare


def validate(shortlist_path: Path, output: Path, split="train", repeats=3):
    if split not in {"train", "holdout"} or not 3 <= repeats <= 5:
        raise ValueError("validation requires train/holdout and three to five repeats")
    # Public freeze validation is deliberately the first access, before withheld paths.
    freeze = validate_shortlist(shortlist_path, require_repeats=split == "holdout")
    observed = {"repository_commit": git_identity()["repository_commit"], "engine_identity": engine_identity(), "source_hashes": source_hashes()}
    if any(observed[key] != freeze["provenance"].get(key) for key in observed):
        raise ValueError("frozen public runtime provenance changed; withheld definitions remain unopened")
    if split == "holdout":
        manifest_path = ROOT / "features/auto_tuning_lab/holdout/scenarios.json"
    else:
        manifest_path = ROOT / "features/auto_tuning_lab/resources/train_scenarios.json"
    cases = read_json(manifest_path)
    scenarios = [row["id"] for row in cases["scenarios"]]
    provenance = dict(freeze["provenance"])
    if split == "holdout":
        provenance["source_hashes"] = source_hashes(include_holdout=True)
    resource = parameter_resource()
    members = [freeze["baseline"], *freeze["candidates"]]
    outputs = []
    all_outcomes = {}
    with StudyLock(output):
        if (output / "validation_summary.json").exists():
            raise FileExistsError("validation is immutable; choose a new output directory")
        atomic_json(output / "validation_manifest.json", {"split": split, "repeats_per_frequency": repeats,
                    "frequencies": [120, 60], "shortlist_path": str(shortlist_path), "shortlist_sha256": file_hash(shortlist_path),
                    "started_utc": utc_now(), "provenance": provenance, "fixture_manifest_sha256": file_hash(manifest_path)})
        for member_index, member in enumerate(members):
            for hz in (120, 60):
                outcomes = []
                paths = []
                for repeat in range(repeats):
                    request = make_candidate(member["parameter_overrides"], scenarios,
                                             trial_id=f"{split}_m{member_index}_{hz}_r{repeat + 1}", hz=hz,
                                             provenance=provenance, split=split, input_trace_id=cases["input_trace_id"])
                    validate_shortlist(shortlist_path, request, require_repeats=split == "holdout")
                    result, path = run_trial(request, output / "trials", resource=resource, shortlist_path=shortlist_path)
                    outcomes.append(result)
                    paths.append(str(path.relative_to(output)))
                    if result["status"] != "completed":
                        summary = {"status": "stopped", "split": split, "reason": result["reason"],
                                   "candidate_id": member["candidate_id"], "physics_hz": hz,
                                   "failure_path": str(path.relative_to(output)), "completed_cells": outputs,
                                   "promotion": False}
                        atomic_json(output / "validation_summary.json", summary)
                        return summary
                all_outcomes[(member["candidate_id"], hz)] = outcomes
                outputs.append({"candidate_id": member["candidate_id"], "baseline": member_index == 0,
                                "physics_hz": hz, "paths": paths, "summary": summarize(outcomes)})
        accepted = []
        if split == "train":
            references = {hz: build_reference(all_outcomes[(freeze["baseline"]["candidate_id"], hz)]) for hz in (60, 120)}
            for member in freeze["candidates"]:
                scores = []
                rejection = None
                for hz in (120, 60):
                    for outcome in all_outcomes[(member["candidate_id"], hz)]:
                        try:
                            score = compare(outcome, references[hz])
                            scores.append({"physics_hz": hz, **score})
                        except Unrankable as exc:
                            rejection = str(exc)
                if not rejection and scores and all(not score["regression_flags"] and min(score["values"]) >= -.25 for score in scores):
                    means = [statistics.mean(score["values"][index] for score in scores) for index in range(4)]
                    if max(means) >= 1.0:
                        accepted.append({**member, "repeat_validation_scores": scores})
                for row in outputs:
                    if row["candidate_id"] == member["candidate_id"]:
                        row["ranking_rejection"] = rejection
            validated = {
                "schema_version": "1.0", "frozen": True, "frozen_at_utc": utc_now(), "provenance": freeze["provenance"],
                "parent_shortlist_sha256": file_hash(shortlist_path), "baseline": freeze["baseline"], "candidates": accepted[:3],
                "selection_rule": "all repeated train runs avoid severe regression at both Hz; mean at least one practical unit; at most three finalists",
                "training_repeat_validation": {"passed": bool(accepted), "repeats_per_frequency": repeats, "frequencies": [60, 120],
                                               "evidence_manifest_sha256": file_hash(output / "validation_manifest.json")},
                "holdout_accessed_before_freeze": False, "promotion": "NONE; unseen and human review pending",
            }
            validated["freeze_sha256"] = digest(validated)
            atomic_json(output / "validated_shortlist.json", validated)
        summary = {"status": "completed", "split": split, "repeats_per_frequency": repeats,
                   "cells": outputs, "accepted_training_candidates": len(accepted) if split == "train" else None,
                   "holdout_accessed": split == "holdout", "human_sessions": 0, "promotion": False,
                   "decision_scope": "numeric screening only; every raw failure and frequency retained for reviewer"}
        atomic_json(output / "validation_summary.json", summary)
        return summary


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--shortlist", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--split", choices=("train", "holdout"), default="train")
    parser.add_argument("--repeats", type=int, default=3)
    args = parser.parse_args()
    result = validate(args.shortlist, args.output, args.split, args.repeats)
    print(result["status"])


if __name__ == "__main__":
    main()
