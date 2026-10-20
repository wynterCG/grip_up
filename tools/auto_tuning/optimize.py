"""Bounded, sequential Random -> multi-objective TPE pilot; never loads holdout."""
from __future__ import annotations

import argparse
from pathlib import Path
import json
import os
import sys

import optuna
from optuna.trial import TrialState

from candidate_schema import PARAMETER_IDS, baseline, parameter_resource, parameter_rows
from common import ROOT, StudyLock, atomic_json, digest, engine_identity, file_hash, git_identity, read_json, source_hashes, utc_now
from run_trial import make_candidate, run_trial
from scoring import AXES, UnqualifiedTask, Unrankable, build_reference, compare, nondominated


def event(path: Path, record: dict):
    with path.open("a", encoding="utf-8", newline="\n") as handle:
        handle.write(json.dumps({"time": utc_now(), **record}, sort_keys=True, allow_nan=False) + "\n")
        handle.flush()
        os.fsync(handle.fileno())


def run(config_path: Path, directory: Path, *, project=ROOT, baseline_only=False):
    config = read_json(config_path)
    if config.get("schema_version") != "1.0" or config.get("workers") != 1 or config["physics_hz"] != 120:
        raise ValueError("first sweep requires schema1.0, one worker and 120Hz")
    if not 3 <= config["baseline_repeats"] <= 5 or not 12 <= config["random_trials"] <= 20 or not 0 <= config["tpe_trials"] <= 80:
        raise ValueError("out-of-budget sweep")
    # Intentionally only public training definitions. No holdout configuration import.
    train_path = project / "features/auto_tuning_lab/resources/train_scenarios.json"
    train = read_json(train_path)
    scenarios = [row["id"] for row in train["scenarios"]]
    resource = parameter_resource(project)
    provenance = {**git_identity(), "source_hashes": source_hashes(project), "engine_identity": engine_identity()}
    identity = {"config": config, "provenance": provenance, "parameter_space_sha256": digest(resource),
                "train_sha256": file_hash(train_path), "input_trace_id": train["input_trace_id"], "optuna_version": optuna.__version__,
                "python_version": sys.version, "objective_version": "four_worst_cell_gains_r1", "holdout_accessed": False}
    with StudyLock(directory):
        manifest_path = directory / "study_manifest.json"
        if manifest_path.exists():
            manifest = read_json(manifest_path)
            if manifest["identity"] != identity:
                raise ValueError("resume provenance/config mismatch; start a new study rather than mixing evidence")
        else:
            manifest = {"schema_version": "1.0", "started_utc": utc_now(), "identity": identity}
            atomic_json(manifest_path, manifest)
        state_path = directory / "study_state.json"
        state = read_json(state_path) if state_path.exists() else {"baseline": [], "trials": [], "stopped": None, "status": "running"}
        if state.get("status") in ("completed", "stopped"):
            print(json.dumps({"status": state["status"], "reason": state.get("stopped"), "study": str(directory)}))
            return state
        events_path = directory / "events.jsonl"

        def save():
            atomic_json(state_path, state)

        def stop(reason):
            state.update(status="stopped", stopped=reason)
            atomic_json(directory / "pareto.json", {"objective_names": list(AXES), "candidates": nondominated(state["trials"]), "holdout_accessed": False, "stop_reason": reason})
            event(events_path, {"event": "study_stopped", "reason": reason})
            save()
            return state

        def evaluate(values, label, *, seed=None):
            request = make_candidate(values, scenarios, trial_id=label, hz=config["physics_hz"],
                                     seed=config["run_seed"] if seed is None else seed,
                                     timeout=config["timeout_seconds"], provenance=provenance)
            result, path = run_trial(request, directory / "trials", project=project, resource=resource)
            record = {"trial_id": label, "candidate_id": request["candidate_id"], "parameter_overrides": values,
                      "status": result["status"], "reason": result["reason"], "path": str(path.relative_to(directory)),
                      "elapsed_wall_s": result["elapsed_wall_s"]}
            event(events_path, {"event": "evaluation_finished", **record})
            return record, result

        for repeat in range(len(state["baseline"]), config["baseline_repeats"]):
            record, result = evaluate(baseline(resource), f"baseline-r{repeat + 1:02}")
            state["baseline"].append(record)
            save()
            if result["status"] != "completed":
                return stop("baseline failed: " + result["reason"])
        baseline_results = [read_json(directory / record["path"] / "result.json") for record in state["baseline"]]
        try:
            reference = build_reference(baseline_results)
            compare(baseline_results[0], reference)  # All four axes must actually be measured.
        except Unrankable as exc:
            return stop("measurement gate: " + str(exc))
        atomic_json(directory / "baseline_reference.json", reference)
        if reference["noisy_directed_cells"]:
            return stop("baseline dominated by noise: " + ",".join(reference["noisy_directed_cells"]))
        if baseline_only:
            state["status"] = "baseline_ready"
            save()
            event(events_path, {"event": "baseline_gate_ready", "repeats": len(state["baseline"])})
            return state
        storage = "sqlite:///" + (directory / "study.sqlite3").resolve().as_posix()
        study = optuna.create_study(storage=storage, study_name=config["study_name"], load_if_exists=True,
                                    sampler=optuna.samplers.RandomSampler(seed=config["seed"]), directions=["maximize"] * 4)
        study.set_metric_names(list(AXES))
        current_guard = digest(identity)
        guard = study.user_attrs.get("provenance_sha256")
        if guard is not None and guard != current_guard:
            raise ValueError("SQLite provenance mismatch")
        study.set_user_attr("provenance_sha256", current_guard)
        for old in study.get_trials(states=(TrialState.RUNNING,)):
            study.tell(old.number, state=TrialState.FAIL)
            event(events_path, {"event": "abandoned_previous_process", "optuna_trial": old.number})
        budget = config["random_trials"] + config["tpe_trials"]
        for index in range(len(state["trials"]), budget):
            phase = "random" if index < config["random_trials"] else "tpe"
            if index == config["random_trials"] and config["require_meaningful_random_gain_for_tpe"] and not any(record.get("score", {}).get("meaningful_screening_gain") for record in state["trials"]):
                return stop("random pilot: no robust practical Pareto screening improvement; retain A0")
            # Per-trial seeds allow exact parameter proposal replay after resume, not a claim of Jolt determinism.
            study.sampler = (optuna.samplers.RandomSampler(seed=config["seed"] + index) if phase == "random" else
                             optuna.samplers.TPESampler(seed=config["seed"] + index, n_startup_trials=0, multivariate=False, constant_liar=False))
            trial = study.ask()
            values = {key: round(trial.suggest_float(key, parameter_rows(resource)[key]["min"], parameter_rows(resource)[key]["max"]), 8) for key in PARAMETER_IDS}
            record, result = evaluate(values, f"{phase}-{index + 1:04}")
            record.update(phase=phase, optuna_trial=trial.number)
            record["sampler"] = "RandomSampler" if phase == "random" else "TPESampler(n_startup_trials=0; explicit random history already collected)"
            trial.set_user_attr("artifact_path", record["path"])
            trial.set_user_attr("candidate_id", record["candidate_id"])
            trial.set_user_attr("status", record["status"])
            score = None
            physical_task_loss = False
            try:
                score = compare(result, reference)
            except Unrankable as exc:
                record["ranking_rejection"] = str(exc)
                physical_task_loss = isinstance(exc, UnqualifiedTask)
                record["observed_physical_task_rejection"] = physical_task_loss
            if score is None:
                trial.set_constraint("physics_and_measurement", 1.0)
                study.tell(trial, state=TrialState.FAIL)
            else:
                record["score"] = score
                trial.set_constraint("physics_and_measurement", 0.0)
                study.tell(trial, values=score["values"])
            state["trials"].append(record)
            save()
            if result["status"] not in ("completed", "invalid_candidate"):
                return stop("hard/runtime safety gate: " + result["reason"])
            if result["status"] == "completed" and score is None and not physical_task_loss:
                return stop("ambiguous measurement: " + record["ranking_rejection"])
            if physical_task_loss:
                confirm, repeated = evaluate(values, f"confirm_task_{index + 1:04}")
                repeated_loss = False
                try:
                    confirm["score"] = compare(repeated, reference)
                except Unrankable as exc:
                    confirm["ranking_rejection"] = str(exc)
                    repeated_loss = isinstance(exc, UnqualifiedTask)
                record["regression_confirmation"] = confirm
                save()
                if repeated_loss:
                    return stop("reproduced essential physical support/preparation loss: " + record["ranking_rejection"])
                if repeated["status"] != "completed" or confirm.get("ranking_rejection"):
                    return stop("hard/runtime or ambiguous measurement during physical-task confirmation: " + confirm.get("ranking_rejection", repeated["reason"]))
                if confirm["score"]["regression_flags"]:
                    return stop("essential regression during physical-task confirmation: " + ";".join(confirm["score"]["regression_flags"]))
            if score and score["regression_flags"]:
                confirm, repeated = evaluate(values, f"confirm-{index + 1:04}")
                try:
                    confirm["score"] = compare(repeated, reference)
                except Unrankable as exc:
                    confirm["ranking_rejection"] = str(exc)
                record["regression_confirmation"] = confirm
                save()
                if confirm.get("score", {}).get("regression_flags") or repeated["status"] != "completed" or confirm.get("ranking_rejection"):
                    return stop("reproduced essential regression: " + ";".join(score["regression_flags"]))
            atomic_json(directory / "pareto.json", {"objective_names": list(AXES), "candidates": nondominated(state["trials"]), "holdout_accessed": False})
            if phase == "tpe":
                tpe_rows = [row for row in state["trials"] if row.get("phase") == "tpe"]
                window = config["tpe_batch_size"] * config["no_improvement_batch_limit"]
                if len(tpe_rows) >= window and len(tpe_rows) % config["tpe_batch_size"] == 0 and not any(row.get("score", {}).get("meaningful_screening_gain") for row in tpe_rows[-window:]):
                    return stop("TPE batches show no practical robust gain; retain A0")
        state["status"] = "completed"
        save()
        event(events_path, {"event": "budget_completed", "candidate_trials": len(state["trials"])})
        return state


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=Path(__file__).parent / "configs/first_sweep.json")
    parser.add_argument("--output", type=Path, default=ROOT / "builds/auto_tuning/stage1_r1")
    parser.add_argument("--baseline-only", action="store_true")
    args = parser.parse_args()
    state = run(args.config, args.output, baseline_only=args.baseline_only)
    print(json.dumps({"status": state["status"], "reason": state.get("stopped"), "trials": len(state["trials"])}))


if __name__ == "__main__":
    main()
