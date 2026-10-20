"""Sequential A0-only evaluator diagnostics. Never imports an optimizer or holdout."""
from __future__ import annotations

import argparse
import gzip
import json
import itertools
from pathlib import Path
import subprocess
import time
import uuid
import zipfile

from candidate_schema import baseline, parameter_resource
from common import ROOT, DEST, ENGINE, StudyLock, atomic_json, digest, engine_identity, file_hash, git_identity, read_json, source_hashes, utc_now
from run_trial import make_candidate

CONFIG = Path(__file__).parent / "configs/reliability_v131.json"
REFERENCE = DEST / "builds/reference_v13_reliability"
ENTRY = "res://features/evaluator_reliability/scripts/reliability_runner.gd"
LEGACY_ENTRY = "res://features/auto_tuning_lab/scripts/optimization_trial_runner.gd"


def historical_provenance():
    with zipfile.ZipFile(ROOT / "docs/validation/auto_tuning/evidence/stage1_r1.zip") as archive:
        return json.loads(archive.read("study_manifest.json"))["identity"]["provenance"]


def audit_baseline():
    frozen = read_json(ROOT / "docs/validation/auto_tuning/v131/baseline_manifest.json")
    changed = [name for name, expected in frozen["files"].items()
               if any(not (base / name).is_file() or file_hash(base / name) != expected for base in (ROOT, DEST))]
    original = read_json(ROOT / "docs/validation/auto_tuning/baseline/freeze.json")
    if changed or engine_identity() != frozen["engine"]:
        raise ValueError("historical source/engine changed: " + ",".join(changed))
    if file_hash(Path(original["janga_path"])) != original["janga_sha256"] or file_hash(ROOT / original["build_path"]) != original["build_sha256"]:
        raise ValueError("Janga or rollback build changed")
    if file_hash(ROOT / "project.godot") != historical_provenance()["source_hashes"]["project.godot"]:
        raise ValueError("normal project settings changed")
    if source_hashes(ROOT) != source_hashes(DEST):
        raise ValueError("public source mirror/canonical mismatch")
    return {"historical_files_unchanged": len(frozen["files"]), "engine_janga_rollback_unchanged": True,
            "normal_project_settings_unchanged": True, "public_source_copies_equal": True,
            "scope": "File/configuration audit; runtime physics verified separately by trials"}


def repository_identity(project: Path):
    command = ["git", "-c", f"safe.directory={project.resolve().as_posix()}", "-C", str(project)]
    return {"repository_commit": subprocess.check_output([*command, "rev-parse", "HEAD"], text=True).strip(),
            "repository_dirty": bool(subprocess.check_output([*command, "status", "--porcelain"], text=True).strip())}


def finish_receipts(directory: Path):
    for name in ("trace.jsonl", "events.jsonl"):
        path = directory / name
        if path.exists():
            data = path.read_bytes()
            compressed = gzip.compress(data, mtime=0)
            assert gzip.decompress(compressed) == data
            temporary = path.with_suffix(path.suffix + ".gz.tmp")
            temporary.write_bytes(compressed)
            temporary.replace(path.with_suffix(path.suffix + ".gz"))
            path.unlink()  # verified lossless replacement, original bytes in gzip
    files = {p.relative_to(directory).as_posix(): {"sha256": file_hash(p), "bytes": p.stat().st_size}
             for p in sorted(directory.rglob("*")) if p.is_file() and p.name != "checksums.json"}
    atomic_json(directory / "checksums.json", {"schema_version": "1.3.1", "files": files})


def validate_reliability_result(result: dict, manifest: dict, manifest_sha: str):
    if result.get("schema_version") != "1.3.1" or result.get("run_id") != manifest["run_id"] or result.get("manifest_file_sha256") != manifest_sha:
        raise ValueError("result schema/run/manifest identity mismatch")
    if result.get("status") != "completed":
        return  # caller preserves explicit failure, never ranks it
    environment = result.get("environment", {})
    if environment.get("engine_binary_sha256") != manifest["engine_identity"]["sha256"] or "jolt" not in str(environment.get("physics_backend", "")).lower():
        raise ValueError("actual engine/Jolt identity mismatch")
    if result.get("physics_hz") != manifest["physics_hz"] or result.get("engine_mode") != manifest["engine_mode"]:
        raise ValueError("actual mode/frequency mismatch")
    for key in ("code_commit", "dirty_tree", "expected_source_hashes"):
        if environment.get(key) != manifest[key]:
            raise ValueError("runtime provenance mismatch: " + key)
    if [row.get("id") for row in result.get("scenarios", [])] != manifest["scenario_ids"]:
        raise ValueError("missing/reordered scenario result")
    restoration = result.get("restoration", {})
    if not all(restoration.get(key) is True for key in ("physics_hz_restored", "startup_profile_preserved", "installs_pre_step", "sources_after_unchanged")) or restoration.get("resources", {}).get("originals_preserved") is not True:
        raise ValueError("resource/settings/source restoration failed")
    for row in result["scenarios"]:
        if type(row.get("completed")) is not bool or not row.get("status") or not row.get("invariants") or any(type(value) is not bool or value for value in row["invariants"].values()):
            raise ValueError("missing task outcome or violated invariant")
        if str(row["status"]).startswith("BLOCKED"):
            raise ValueError("blocked fixture cannot be a completed evaluator: " + row.get("reason",row["status"]))
    if result.get("trace", {}).get("dropped_rows", 0):
        raise ValueError("bounded trace overflow; missing high-frequency evidence")


def analyze_runtime(result: dict, manifest: dict, directory: Path):
    from compare_traces import iter_trace, stable
    from metric_contracts import analyze, precondition_outcomes
    states = {row["id"]: row.get("initial_state", {}) for row in result["scenarios"]}
    chosen = {}
    for scenario, state in states.items():
        configuration = dict(state.get("configuration",{})); configuration.pop("observer_enabled",None)
        chosen[scenario] = stable({"body": state.get("body"), "hands": state.get("hands"), "configuration": configuration,
                                  "support": state.get("support"), "profile": state.get("profile"),
                                  "camera_setup": {k:v for k,v in state.get("camera", {}).items() if k != "physics_interpolation_fraction"}})
    atomic_json(directory / "runtime_provenance.json", {"schema_version": "1.3.1", "manifest_sha256": file_hash(directory / "manifest.json"),
                                                       "initial_state_hashes": {key:digest(value) for key,value in chosen.items()},
                                                       "initial_state_fields": chosen,
                                                       "initial_state_valid": {key: bool(value.get("body", {}).get("valid")) for key,value in chosen.items()},
                                                       "hash_scope": "Observed first-pre-control body/hands/support/profile/camera setup; runtime IDs removed, full raw fields retained separately"})
    if not manifest["recorder_enabled"]:
        return
    catalog = read_json(ROOT / "features/evaluator_reliability/resources/benchmark_eval_v131.json")
    definitions = {row["id"]: row for row in catalog["scenarios"]}
    grouped = itertools.groupby(iter_trace(directory), key=lambda sample:sample["scenario_id"])
    outcomes_by_id = {row["id"]:row for row in result["scenarios"]}
    analyses = {}
    for scenario_id, trace_group in grouped:
        if scenario_id not in definitions:
            for _ in trace_group:pass
            continue
        row = outcomes_by_id[scenario_id]
        samples = list(trace_group)  # bounded one-scenario window, never full multi-course trace
        definition = definitions[row["id"]]
        direction = row.get("direction_world", [float(definition.get("sign", 1)), 0, 0])
        duration = float(definition["observe_s"])
        contract = {"physics_hz": manifest["physics_hz"], "sample_phase": "post_control", "direction_world": direction,
                    "deadline_s": duration, "fixed_horizons_s": [value for value in (.25, .5, 1., 2., 5.) if value <= duration],
                    "min_initial_speed_m_s": .15 if definition["task"] in ("stop_release", "brake_counter", "reverse_command") else 0}
        kind = {"stop_release":"release", "low_energy":"release", "brake_counter":"brake", "reverse_command":"reverse", "counter":"reverse"}.get(definition["task"], "none")
        if row.get("status") == "precondition_not_met":
            analyses[row["id"]] = precondition_outcomes(row.get("reason", "PRECONDITION_NOT_MET"), contract, kind)
        else:
            transition = dict(row.get("transition", {}))
            if kind in {"release", "brake"}:
                transition["stop_target_progress_m"] = 0.0  # declared observation target at actual accepted onset, no actuation
            analyses[row["id"]] = analyze(samples, contract, transition)
    atomic_json(directory / "typed_metrics.json", {"schema_version": "1.3.1", "scenarios": analyses,
                                                   "scope": "Raw typed observations only; no optimizer, aggregate reward or candidate ranking"})


def execute(manifest: dict, directory: Path, project: Path, *, legacy=False):
    directory.mkdir(parents=True, exist_ok=False)
    atomic_json(directory / "manifest.json", manifest)
    output = directory / "engine_result.json"
    flags = ["--headless", "--fixed-fps", "120"] if manifest["engine_mode"] == "headless" else ["--screen", "0", "--position", "80,80"]
    if legacy:
        atomic_json(directory / "candidate.json", manifest["baseline_candidate"])
        command = [str(ENGINE), *flags, "--path", str(project), "--script", LEGACY_ENTRY,
                   "--", "--candidate", str((directory / "candidate.json").resolve()), "--result", str(output.resolve())]
    else:
        command = [str(ENGINE), *flags, "--path", str(project), "--script", ENTRY,
                   "--", "--manifest", str((directory / "manifest.json").resolve()), "--result", str(output.resolve())]
    atomic_json(directory / "execution.json", {"command": command, "launch_utc": utc_now(), "worker_count": 1})
    started = time.monotonic()
    result = None
    status, reason, code = "failed_runtime", "missing_result", None
    with (directory / "stdout.txt").open("wb") as stdout, (directory / "stderr.txt").open("wb") as stderr:
        process = subprocess.Popen(command, stdout=stdout, stderr=stderr, cwd=project)
        try:
            code = process.wait(timeout=manifest["timeout_s"])
        except (subprocess.TimeoutExpired, KeyboardInterrupt) as exc:
            process.kill(); process.wait(timeout=10)
            status, reason = ("timed_out", "wall_timeout") if isinstance(exc, subprocess.TimeoutExpired) else ("cancelled", "operator_interrupt")
        else:
            if output.exists():
                try:
                    result = read_json(output)
                    digest(result)  # reject non-finite JSON recursively
                    if legacy:
                        from run_trial import validate_result
                        validate_result(result, manifest["baseline_candidate"])
                    else:
                        validate_reliability_result(result, manifest, file_hash(directory / "manifest.json"))
                    status, reason = result.get("status", "failed_runtime"), result.get("reason", "evaluation_finished")
                    if code and status == "completed":
                        status, reason = "failed_runtime", f"engine_exit_{code}_despite_completion"
                except (ValueError, TypeError, KeyError) as exc:
                    status, reason = "failed_runtime", str(exc)
            elif code:
                reason = f"engine_exit_{code}"
    logs = "\n".join((directory / name).read_text(encoding="utf-8", errors="replace") for name in ("stdout.txt", "stderr.txt"))
    errors = [line for line in logs.splitlines() if any(marker in line for marker in ("SCRIPT ERROR:", "Parse Error:", "ERROR: Failed to load", "ERROR: Condition"))]
    if errors and status == "completed":
        status, reason = "failed_runtime", "engine_logged_error"
    if source_hashes(project) != manifest["expected_source_hashes"]:
        status, reason = "failed_runtime", "source_changed_during_run"
    if not legacy and status == "completed":
        try:
            analyze_runtime(result, manifest, directory)
        except (ValueError, TypeError, KeyError, OSError) as exc:
            status, reason = "failed_runtime", "postprocess: " + str(exc)
    atomic_json(directory / "diagnostics.json", {"exit_code": code, "elapsed_wall_s": time.monotonic() - started,
                                                "errors": errors, "logs_complete": True,
                                                "parser_warning_scope": "Full raw logs preserved; headless stdout may omit editor-only static warnings"})
    receipt = {"schema_version": "1.3.1", "run_id": manifest["run_id"], "status": status, "reason": reason,
               "engine_result": result, "data_kind": manifest["data_kind"], "manifest_sha256": file_hash(directory / "manifest.json")}
    atomic_json(directory / "result.json", receipt)
    finish_receipts(directory)
    print(manifest["run_id"], status, reason, flush=True)
    return receipt


def plan(suite: str, modes: list[str], rates: list[int], repetitions: int):
    if suite in {"catch", "historical-catch"}:
        for hz in rates:
            for mode in modes:
                for sequence in (False, True):
                    for repeat in range(repetitions):
                        yield {"hz": hz, "mode": mode, "sequence": sequence, "repeat": repeat + 1, "recorder": True, "scenarios": ["swing_catch_train"]}
                if suite == "catch":
                    yield {"hz": hz, "mode": mode, "sequence": False, "repeat": 1, "recorder": False, "scenarios": ["swing_catch_train"]}
                    yield {"hz": hz, "mode": mode, "sequence": False, "repeat": 1, "recorder": False, "observer": False, "scenarios": ["swing_catch_train"]}
    elif suite == "lateral-stop":
        for hz in rates:
            for mode in modes:
                for repeat in range(repetitions):
                    yield {"hz": hz, "mode": mode, "sequence": False, "repeat": repeat + 1, "recorder": True,
                           "scenarios": ["lateral_clean_left_v1", "lateral_clean_right_v1", "lateral_counter_swing_left_v1", "lateral_counter_swing_right_v1",
                                         "stop_release_v1", "brake_counter_v1", "reverse_command_v1", "stop_low_energy_control_v1",
                                         "stop_release_one_hand_v1", "brake_counter_one_hand_v1", "reverse_command_one_hand_v1", "stop_low_energy_control_one_hand_v1"]}


def run(args):
    config = read_json(CONFIG)
    if args.repeats < 3 and not args.development and args.suite != "baseline":
        raise ValueError("qualification requires at least three repetitions per cell; lower budgets must be explicitly --development")
    modes = ["headless", "rendered_scripted"] if args.mode == "both" else [args.mode]
    rates = args.hz or ([120] if args.suite == "historical-catch" else config["physics_hz"])
    project = REFERENCE if args.suite == "historical-catch" else ROOT
    provenance = {**repository_identity(project if args.suite == "historical-catch" else DEST),
                  "source_hashes": source_hashes(project), "engine_identity": engine_identity()}
    if args.suite != "historical-catch":
        provenance["canonical_git_dirty"] = provenance["repository_dirty"]
        provenance["source_mirror_parity"] = provenance["source_hashes"] == source_hashes(DEST)
        provenance["repository_dirty"] = provenance["repository_dirty"] or not provenance["source_mirror_parity"]
        if provenance["repository_dirty"] and not args.development:
            raise ValueError("qualification requires clean canonical Git and exact public mirror parity; use --development only for explicitly unqualified debugging")
    all_scenarios = [row["id"] for row in read_json(project / "features/auto_tuning_lab/resources/train_scenarios.json")["scenarios"]]
    values = baseline(parameter_resource(project))
    if args.suite == "historical-catch":
        historical = historical_provenance()
        if provenance["repository_commit"] != config["historical_code_commit"] or provenance["source_hashes"] != historical["source_hashes"] or provenance["engine_identity"] != historical["engine_identity"]:
            raise ValueError("historical source/engine identity differs; stop reconstruction before evaluation")
    with StudyLock(args.output):
        session_path = args.output / "session_manifest.json"
        if session_path.exists():
            raise FileExistsError("immutable session; choose a new output directory")
        atomic_json(session_path, {"schema_version": "1.3.1", "started_utc": utc_now(), "suite": args.suite,
                                  "config": config, "provenance": provenance, "modes": modes, "rates": rates,
                                  "orchestrator_sha256": file_hash(Path(__file__)),
                                  "qualification": "development_not_certified" if args.development else "frozen_reference_matrix",
                                  "repetitions": args.repeats, "private_holdout_outcomes_accessed": False})
        if args.suite == "baseline":
            audit = audit_baseline()
            atomic_json(args.output / "baseline_audit.json", audit)
            atomic_json(args.output / "session_state.json", {"suite": args.suite, "runs": [], "status": "completed", "audit": audit})
            print(json.dumps(audit))
            return 0
        results = []
        for cell in plan(args.suite, modes, rates, args.repeats):
            run_id = f"{args.suite}_{cell['mode']}_{cell['hz']}_{'sequence' if cell['sequence'] else 'isolated'}_r{cell['repeat']}_{'trace' if cell['recorder'] else 'observeroff' if not cell.get('observer',True) else 'outcome'}_{uuid.uuid4().hex[:8]}"
            directory = (args.output / "attempts" / run_id).resolve()
            scenarios = all_scenarios if cell["sequence"] else cell["scenarios"]
            candidate = make_candidate(values, [x for x in scenarios if x in all_scenarios] or ["swing_catch_train"], trial_id=run_id,
                                       hz=cell["hz"], seed=config["seed"], project=project, provenance=provenance, timeout=config["timeout_s"])
            manifest = {"schema_version": "1.3.1", "run_id": run_id, "physics_hz": cell["hz"], "engine_mode": cell["mode"],
                        "scenario_ids": scenarios, "recorder_enabled": cell["recorder"], "existing_observer_enabled": cell.get("observer",True), "output_dir": str(directory),
                        "run_seed": config["seed"], "expected_source_hashes": provenance["source_hashes"],
                        "code_commit": provenance["repository_commit"], "dirty_tree": provenance["repository_dirty"],
                        "engine_identity": provenance["engine_identity"], "baseline_candidate": candidate, "timeout_s": config["timeout_s"],
                        "controller": config["controller"], "contract": config, "contract_sha256": file_hash(CONFIG),
                        "metric_definition_version": config["benchmark_id"], "input_driver_hash": provenance["source_hashes"].get("features/evaluator_reliability/scripts/reliability_driver.gd"),
                        "qualification": "development_not_certified" if args.development else "frozen_reference_matrix",
                        "declared_setup_hash": digest({"scenario_ids":scenarios,"controller":config["controller"],"seed":config["seed"],"sources":provenance["source_hashes"]}),
                        "initial_state_policy": "Actual runtime fields/hash published separately and linked to this prior manifest; declared setup hash is not an observed state hash",
                        "data_kind": "automated_headless" if cell["mode"] == "headless" else "automated_rendered_scripted",
                        "legacy_trace_scope": "old 10Hz snapshots, no claim of synchronized tick input trace" if args.suite == "historical-catch" else None}
            if args.suite == "historical-catch":
                manifest["input_driver_hash"] = provenance["source_hashes"]["features/auto_tuning_lab/scripts/optimization_trial_driver.gd"]
            outcome = execute(manifest, directory, project, legacy=args.suite == "historical-catch")
            results.append({"run_id": run_id, "path": str(directory.relative_to(args.output.resolve())), "status": outcome["status"], "reason": outcome["reason"]})
            atomic_json(args.output / "session_state.json", {"suite": args.suite, "runs": results, "status": "running"})
            if outcome["status"] not in {"completed", "evaluation_finished"}:
                atomic_json(args.output / "session_state.json", {"suite": args.suite, "runs": results, "status": "stopped", "reason": outcome["reason"]})
                return 1
        atomic_json(args.output / "session_state.json", {"suite": args.suite, "runs": results, "status": "completed"})
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--suite", choices=("baseline", "historical-catch", "catch", "lateral-stop"), required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--mode", choices=("headless", "rendered_scripted", "both"), default="both")
    parser.add_argument("--hz", type=int, choices=(60, 120), action="append")
    parser.add_argument("--repeats", type=int, choices=range(1, 6), default=3)
    parser.add_argument("--development", action="store_true", help="Explicit unqualified debug run before source freeze; never search certification")
    args = parser.parse_args()
    raise SystemExit(run(args))


if __name__ == "__main__":
    main()
