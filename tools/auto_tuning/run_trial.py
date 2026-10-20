"""One isolated Godot process. Every outcome, including invalid input, is retained."""
from __future__ import annotations

import argparse
import json
import os
import re
from pathlib import Path
import subprocess
import time
import uuid
from datetime import datetime, timezone

from candidate_schema import InvalidCandidate, SCHEMA_VERSION, STATUSES, candidate_id, parameter_resource, validate_candidate
from common import ROOT, DEST, ENGINE, atomic_json, digest, engine_identity, file_hash, git_identity, read_json, source_hashes, utc_now

ENTRY = "res://features/auto_tuning_lab/scripts/optimization_trial_runner.gd"
REQUIRED_INVARIANTS = {
    "force_budget_violation", "unphysical_grip", "direct_body_transform_mutation", "solver_nonfinite",
}


def make_candidate(overrides, scenarios, *, trial_id, hz=120, seed=101, timeout=180, split="train", project=ROOT, provenance=None, input_trace_id=None):
    provenance = provenance or {**git_identity(), "source_hashes": source_hashes(project), "engine_identity": engine_identity()}
    if input_trace_id is None:
        if split != "train":
            raise ValueError("non-training candidate needs an explicit post-gate input trace ID")
        input_trace_id = read_json(project / "features/auto_tuning_lab/resources/train_scenarios.json")["input_trace_id"]
    return {
        "schema_version": SCHEMA_VERSION, "trial_id": trial_id, "candidate_id": candidate_id(overrides),
        "profile": "BASE-A0-B1", "parameter_overrides": dict(overrides), "scenarios": list(scenarios),
        "requested_physics_hz": hz, "input_trace_id": input_trace_id,
        "run_seed": seed, "repository_commit": provenance["repository_commit"], "timeout_seconds": timeout,
        "source_hashes": provenance["source_hashes"], "engine_identity": provenance["engine_identity"],
        "evaluation_split": split,
    }


def validate_result(result: dict, candidate: dict) -> None:
    """Provenance/integrity before metrics. A missing measurement is never zero."""
    if not isinstance(result, dict) or result.get("schema_version") != SCHEMA_VERSION:
        raise ValueError("missing/unknown result schema")
    for key in ("trial_id", "candidate_id", "parameter_overrides"):
        if result.get(key) != candidate[key]:
            raise ValueError(f"stale/mismatched result {key}")
    status = result.get("status")
    if status not in STATUSES:
        raise ValueError("unknown result status")
    if status in {"invalid_candidate", "unsupported_scenario"}:
        if not isinstance(result.get("reason"), str) or not result["reason"]:
            raise ValueError("rejected engine input has no machine-readable reason")
        # A source mismatch is itself a valid rejection, never a scored simulation.
        digest(result)
        return
    environment = result.get("environment", {})
    if environment.get("repository_commit") != candidate["repository_commit"]:
        raise ValueError("result revision mismatch")
    if environment.get("physics_hz") != candidate["requested_physics_hz"]:
        raise ValueError("result frequency mismatch")
    if environment.get("source_hashes") != candidate["source_hashes"]:
        raise ValueError("result source hashes mismatch")
    for key in ("input_trace_id", "evaluation_split", "run_seed"):
        if environment.get(key) != candidate[key]:
            raise ValueError(f"result {key} mismatch")
    release = str(environment.get("engine_version", ""))
    expected_version = candidate["engine_identity"]["version"]
    full_hash_matches_cli = re.fullmatch(r"[0-9a-f]{40}", release) is not None and expected_version.endswith("." + release[:9])
    if not release or (release not in expected_version and not full_hash_matches_cli):
        raise ValueError("result engine version mismatch")
    if environment.get("engine_binary_sha256") != candidate["engine_identity"]["sha256"]:
        raise ValueError("result engine binary mismatch")
    if "jolt" not in str(environment.get("physics_backend", "")).lower():
        raise ValueError("result physics backend mismatch")
    invariants = result.get("invariants", {})
    if not REQUIRED_INVARIANTS <= set(invariants) or any(type(value) is not bool for value in invariants.values()):
        raise ValueError("missing/nonboolean invariant result")
    rows = result.get("scenarios", [])
    if status == "completed":
        if any(invariants.values()):
            raise ValueError("completed result contains violated hard invariant")
        if not isinstance(rows, list) or [row.get("id") for row in rows] != candidate["scenarios"]:
            raise ValueError("missing/reordered/duplicate scenario results")
        for row in rows:
            if row.get("status") not in ("completed", "failed_task") or type(row.get("completed")) is not bool:
                raise ValueError("scenario has no explicit task outcome")
            if not isinstance(row.get("metrics"), dict) or not isinstance(row.get("capture"), dict) or not row.get("scope"):
                raise ValueError("scenario missing metrics/capture/scope")
            if not isinstance(row.get("revision"), int) or row["revision"] < 1:
                raise ValueError("scenario revision missing")
            if not isinstance(row.get("invariants"), dict) or not REQUIRED_INVARIANTS <= set(row["invariants"]) or any(type(value) is not bool for value in row["invariants"].values()) or any(row["invariants"].values()):
                raise ValueError("completed result contains scenario invariant violation")
    # Refuses NaN/Infinity recursively, even in fields not currently ranked.
    digest(result)


def validate_shortlist(path: Path | None, candidate: dict | None = None, *, require_repeats=False) -> dict:
    """Read public freeze evidence before any withheld fixture definition is opened."""
    if path is None:
        raise InvalidCandidate("holdout requires a previously frozen public shortlist")
    freeze = read_json(path)
    core = {key: value for key, value in freeze.items() if key != "freeze_sha256"}
    if freeze.get("frozen") is not True or freeze.get("freeze_sha256") != digest(core):
        raise InvalidCandidate("invalid or modified shortlist freeze")
    timestamp = datetime.fromisoformat(freeze["frozen_at_utc"])
    if timestamp.tzinfo is None or timestamp > datetime.now(timezone.utc):
        raise InvalidCandidate("shortlist freeze timestamp invalid")
    if not freeze.get("candidates"):
        raise InvalidCandidate("empty frozen shortlist")
    if require_repeats:
        validation = freeze.get("training_repeat_validation", {})
        if validation.get("passed") is not True or validation.get("repeats_per_frequency", 0) < 3 or set(validation.get("frequencies", [])) != {60, 120}:
            raise InvalidCandidate("holdout requires repeated training validation at 60/120Hz")
    if candidate is not None:
        provenance = freeze.get("provenance", {})
        if candidate["repository_commit"] != provenance.get("repository_commit") or candidate["engine_identity"] != provenance.get("engine_identity"):
            raise InvalidCandidate("holdout revision/engine differs from frozen training")
        if any(candidate["source_hashes"].get(key) != value for key, value in provenance.get("source_hashes", {}).items()) or not provenance.get("source_hashes"):
            raise InvalidCandidate("holdout public source differs from frozen training")
        members = {row["candidate_id"]: row["parameter_overrides"] for row in freeze["candidates"]}
        # Baseline is allowed as paired reference; it is explicitly recorded in the freeze.
        members[freeze["baseline"]["candidate_id"]] = freeze["baseline"]["parameter_overrides"]
        if members.get(candidate["candidate_id"]) != candidate["parameter_overrides"]:
            raise InvalidCandidate("holdout candidate not in frozen shortlist")
    return freeze


def run_trial(candidate: dict, output_root: Path, *, project: Path = ROOT, engine: Path = ENGINE,
              resource: dict | None = None, command_override: list[str] | None = None,
              verify_provenance=True, shortlist_path: Path | None = None, visible=False) -> tuple[dict, Path]:
    trial_label = candidate.get("trial_id", "invalid") if isinstance(candidate, dict) else "invalid"
    if not isinstance(trial_label, str) or any(char not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_.-" for char in trial_label):
        trial_label = "invalid"
    directory = output_root / f"{trial_label[:100]}_{uuid.uuid4().hex}"
    directory.mkdir(parents=True, exist_ok=False)
    manifest = {
        "schema_version": SCHEMA_VERSION, "started_utc": utc_now(), "candidate": candidate,
        "project": str(project.resolve()), "engine": str(engine.resolve()),
        "repository": git_identity() if verify_provenance else {"test_double": True},
        "source_hashing_scope": "production+train+driver tests+optimizer; withheld paths/tool unit tests/build_identity excluded",
        "worker_count": 1,
        "clock_scope": "native real-time visible replay" if visible else "accelerated fixed-step simulation; not human pacing or real-time CPU profiling",
        "fixed_render_fps": None if visible else 120,
        "requested_physics_hz": candidate.get("requested_physics_hz") if isinstance(candidate, dict) else None,
    }
    # Invalid nonfinite input cannot itself be serialized as JSON. Preserve its repr separately.
    try:
        atomic_json(directory / "manifest.json", manifest)
    except (ValueError, TypeError):
        (directory / "invalid_input.txt").write_text(repr(candidate), encoding="utf-8")
        atomic_json(directory / "manifest.json", {**manifest, "candidate": None, "input_repr": "invalid_input.txt"})
    started = time.monotonic()
    status, reason, result = "failed_runtime", "not_started", None
    code = None
    command = None
    try:
        validate_candidate(candidate, resource or parameter_resource(project))
        if candidate["evaluation_split"] == "holdout":
            validate_shortlist(shortlist_path, candidate, require_repeats=True)
            manifest["shortlist_freeze_sha256"] = file_hash(shortlist_path)
            # This audit is separate; the already-published manifest remains immutable.
            atomic_json(directory / "shortlist_gate.json", {"path": str(shortlist_path), "sha256": file_hash(shortlist_path), "checked_at_utc": utc_now()})
        include_holdout = candidate["evaluation_split"] == "holdout"
        if verify_provenance:
            if source_hashes(project, include_holdout=include_holdout) != candidate["source_hashes"]:
                raise ValueError("source_provenance_changed_before_run")
            if engine_identity(engine) != candidate["engine_identity"]:
                raise ValueError("engine_identity_changed_before_run")
            if git_identity()["repository_commit"] != candidate["repository_commit"]:
                raise ValueError("repository_revision_changed_before_run")
        candidate_path = directory / "candidate.json"
        engine_result = directory / "engine_result.json"
        atomic_json(candidate_path, candidate)
        runtime_flags = ["--screen", "0"] if visible else ["--headless", "--fixed-fps", "120"]
        command = command_override or [str(engine), *runtime_flags, "--path", str(project), "--script", ENTRY,
                                       "--", "--candidate", str(candidate_path.resolve()), "--result", str(engine_result.resolve())]
        atomic_json(directory / "execution.json", {"command": command, "started_utc": utc_now()})
        startup = None
        if os.name == "nt":
            startup = subprocess.STARTUPINFO()
            startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            startup.wShowWindow = 0
        with (directory / "stdout.log").open("wb") as stdout, (directory / "stderr.log").open("wb") as stderr:
            process = subprocess.Popen(command, cwd=project, stdout=stdout, stderr=stderr, startupinfo=startup)
            try:
                code = process.wait(timeout=candidate["timeout_seconds"])
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=10)
                status, reason = "timed_out", "wall_timeout"
            except KeyboardInterrupt:
                process.kill()
                process.wait(timeout=10)
                status, reason = "cancelled", "operator_interrupt"
            else:
                if code != 0:
                    status, reason = "failed_runtime", f"engine_exit_{code}"
                    # Preserve a validated engine failure, including its own deadline.
                    if engine_result.exists():
                        result = read_json(engine_result)
                        validate_result(result, candidate)
                        if result["status"] in {"failed_invariant", "invalid_candidate", "unsupported_scenario", "timed_out", "cancelled"}:
                            status, reason = result["status"], result.get("reason", result["status"])
                elif not engine_result.exists():
                    status, reason = "failed_runtime", "missing_result"
                else:
                    result = read_json(engine_result)
                    validate_result(result, candidate)
                    status, reason = result["status"], result.get("reason", result["status"])
        log_text = (directory / "stdout.log").read_text(encoding="utf-8", errors="replace") + (directory / "stderr.log").read_text(encoding="utf-8", errors="replace")
        if status == "completed" and any(marker in log_text for marker in ("SCRIPT ERROR:", "Parse Error:", "ERROR: Failed to load script", "ERROR: Condition")):
            status, reason = "failed_runtime", "engine_logged_error_despite_completed_output"
        if verify_provenance and source_hashes(project, include_holdout=include_holdout) != candidate["source_hashes"]:
            status, reason = "failed_runtime", "source_provenance_changed_during_run"
    except InvalidCandidate as exc:
        status, reason = "invalid_candidate", str(exc)
    except (ValueError, OSError, subprocess.SubprocessError, KeyError, TypeError) as exc:
        status, reason = "failed_runtime", f"{type(exc).__name__}: {exc}"
    outcome = {
        "schema_version": SCHEMA_VERSION, "trial_id": candidate.get("trial_id") if isinstance(candidate, dict) else None,
        "candidate_id": candidate.get("candidate_id") if isinstance(candidate, dict) else None,
        "status": status, "reason": reason, "exit_code": code, "elapsed_wall_s": time.monotonic() - started,
        "finished_utc": utc_now(), "engine_result": result,
        "artifacts": {"manifest": "manifest.json", "candidate": "candidate.json", "stdout": "stdout.log", "stderr": "stderr.log", "engine_result": "engine_result.json"},
    }
    atomic_json(directory / "result.json", outcome)
    return outcome, directory


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=ROOT / "builds/auto_tuning/trials")
    parser.add_argument("--project", type=Path, default=ROOT)
    parser.add_argument("--shortlist", type=Path)
    args = parser.parse_args()
    try:
        candidate = read_json(args.candidate)
    except (ValueError, OSError) as exc:
        candidate = {"invalid_input_source": str(args.candidate), "parse_error": str(exc)}
    result, directory = run_trial(candidate, args.output, project=args.project, shortlist_path=args.shortlist)
    if result["status"] == "invalid_candidate" and args.candidate.is_file():
        (directory / "rejected_input.bin").write_bytes(args.candidate.read_bytes())
    print(json.dumps({"status": result["status"], "reason": result["reason"], "directory": str(directory)}))
    raise SystemExit(0 if result["status"] == "completed" else 1)


if __name__ == "__main__":
    main()
