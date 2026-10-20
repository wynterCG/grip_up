"""Transport doubles below are explicitly synthetic; they are not gameplay evidence."""
import copy
import json
import math
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from candidate_schema import InvalidCandidate, PARAMETER_IDS, baseline, candidate_id, validate_candidate, validate_overrides
from common import StudyLock, atomic_json, digest, read_json, utc_now
from run_trial import make_candidate, run_trial, validate_result, validate_shortlist

RESOURCE = {"schema_version": "1.0", "version": "AT1-r1", "parameters": [
    {"id": "traversal_speed_m_s", "baseline": .25, "min": .18, "max": .32},
    {"id": "traversal_input_ramp_s", "baseline": .12, "min": .07, "max": .20},
    {"id": "traversal_target_max_rate", "baseline": .24, "min": .16, "max": .30},
    {"id": "traversal_target_max_acceleration", "baseline": .9, "min": .6, "max": 1.2},
]}


def candidate():
    return make_candidate(baseline(RESOURCE), ["vertical_pull_train"], trial_id="synthetic-contract", provenance={
        "repository_commit": "a" * 40, "source_hashes": {"features/driver.gd": "b" * 64},
        "engine_identity": {"version": "4.7.2.test.abcdef", "sha256": "c" * 64},
    })


def engine_result(request):
    return {"schema_version": "1.0", "trial_id": request["trial_id"], "candidate_id": request["candidate_id"],
            "parameter_overrides": request["parameter_overrides"], "status": "completed",
            "environment": {"repository_commit": request["repository_commit"], "physics_hz": request["requested_physics_hz"],
                            "source_hashes": request["source_hashes"], "engine_version": "abcdef",
                            "input_trace_id": request["input_trace_id"], "evaluation_split": request["evaluation_split"], "run_seed": request["run_seed"],
                            "engine_binary_sha256": "c" * 64, "physics_backend": "Jolt Physics"},
            "invariants": {"force_budget_violation": False, "unphysical_grip": False,
                           "direct_body_transform_mutation": False, "solver_nonfinite": False},
            "scenarios": [{"id": request["scenarios"][0], "revision": 1, "status": "completed", "completed": False,
                           "metrics": {"useful_displacement_m": .0, "movement_latency_s": None},
                           "capture": {"source": "synthetic_transport_double"}, "invariants": {
                               "force_budget_violation": False, "unphysical_grip": False,
                               "direct_body_transform_mutation": False, "solver_nonfinite": False}, "scope": "synthetic contract only"}]}


class SchemaTests(unittest.TestCase):
    def test_baseline_and_stable_decimal_identity(self):
        request = candidate()
        validate_candidate(request, RESOURCE)
        reversed_values = dict(reversed(list(request["parameter_overrides"].items())))
        self.assertEqual(candidate_id(reversed_values), request["candidate_id"])
        request["parameter_overrides"]["traversal_target_max_acceleration"] = 0.90000000
        self.assertEqual(candidate_id(request["parameter_overrides"]), request["candidate_id"])

    def test_parameter_boundary_rejects_unsafe_values(self):
        for bad in (float("nan"), float("inf"), -1, .321, True, ".25", None, .250000001):
            with self.subTest(value=bad):
                values = baseline(RESOURCE)
                values["traversal_speed_m_s"] = bad
                with self.assertRaises(InvalidCandidate):
                    validate_overrides(values, RESOURCE)

    def test_unknown_missing_and_coupled_values(self):
        for change in (lambda x: x.update({"mass": 10}), lambda x: x.pop(PARAMETER_IDS[0]),
                       lambda x: x.update(traversal_target_max_rate=.3, traversal_target_max_acceleration=.6)):
            values = baseline(RESOURCE)
            change(values)
            with self.assertRaises(InvalidCandidate):
                validate_overrides(values, RESOURCE)

    def test_candidate_metadata_integrity(self):
        changes = [{"schema_version": "9"}, {"profile": "A1-NEGATIVE"}, {"candidate_id": "a" * 64},
                   {"scenarios": []}, {"scenarios": ["a", "a"]}, {"run_seed": True}, {"requested_physics_hz": True},
                   {"timeout_seconds": True}, {"timeout_seconds": float("inf")}, {"repository_commit": "VERIFIED_AT_RUNTIME"},
                   {"trial_id": "../overwrite"}, {"source_hashes": {"..\\outside": "a" * 64}},
                   {"source_hashes": {"x/../outside": "a" * 64}}, {"source_hashes": {"C:/outside": "a" * 64}},
                   {"source_hashes": {}}, {"unknown": 1}, {"evaluation_split": "hidden_auto"}]
        for change in changes:
            with self.subTest(change=change):
                request = {**candidate(), **change}
                with self.assertRaises(InvalidCandidate):
                    validate_candidate(request, RESOURCE)
        with self.assertRaises(InvalidCandidate):
            validate_candidate(candidate(), RESOURCE, {"other"})

    def test_missing_fields_and_resource_version(self):
        for key in candidate():
            request = candidate()
            del request[key]
            with self.assertRaises(InvalidCandidate):
                validate_candidate(request, RESOURCE)
        with self.assertRaises(InvalidCandidate):
            validate_overrides(baseline(RESOURCE), {**RESOURCE, "version": "other"})


class RunnerTests(unittest.TestCase):
    def execute_double(self, script, request=None):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        folder = Path(temporary.name)
        return run_trial(request or candidate(), folder, resource=RESOURCE, command_override=[sys.executable, "-c", script], verify_provenance=False)

    def test_nonzero_exit_and_missing_result_fail(self):
        result, _ = self.execute_double("raise SystemExit(7)")
        self.assertEqual(result["status"], "failed_runtime")
        self.assertEqual(result["reason"], "engine_exit_7")
        result, directory = self.execute_double("pass")
        self.assertEqual(result["reason"], "missing_result")
        self.assertTrue((directory / "stdout.log").exists())
        self.assertTrue((directory / "manifest.json").exists())

    def test_timeout_is_never_ranked_as_completion(self):
        request = candidate()
        request["timeout_seconds"] = 1
        result, _ = self.execute_double("import time; time.sleep(10)", request)
        self.assertEqual(result["status"], "timed_out")
        self.assertIsNone(result["engine_result"])

    def test_engine_deadline_retains_timeout_with_nonzero_exit(self):
        request = candidate()
        value = engine_result(request)
        value.update(status="timed_out", reason="WALL_TIMEOUT")
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            script = ("import pathlib,sys; "
                      "directory=next(pathlib.Path(sys.argv[1]).iterdir()); "
                      f"(directory/'engine_result.json').write_text({json.dumps(value)!r}, encoding='utf-8'); "
                      "raise SystemExit(1)")
            result, _ = run_trial(request, folder, resource=RESOURCE,
                                  command_override=[sys.executable, "-c", script, str(folder)], verify_provenance=False)
            self.assertEqual(result["status"], "timed_out")
            self.assertEqual(result["reason"], "WALL_TIMEOUT")
            self.assertEqual(result["exit_code"], 1)

    def test_stale_id_revision_source_hz_engine_and_invariant_rejected(self):
        original = engine_result(candidate())
        changes = [lambda x: x.update(trial_id="stale"), lambda x: x.update(candidate_id="a" * 64),
                   lambda x: x["environment"].update(repository_commit="a" * 39 + "b"),
                   lambda x: x["environment"].update(source_hashes={}), lambda x: x["environment"].update(physics_hz=60),
                   lambda x: x["environment"].update(engine_version="WRONG"),
                   lambda x: x["environment"].update(engine_binary_sha256="d" * 64),
                   lambda x: x["environment"].update(input_trace_id="wrong_tape"),
                   lambda x: x["environment"].update(run_seed=999),
                   lambda x: x["environment"].update(evaluation_split="holdout"),
                   lambda x: x["environment"].update(physics_backend="GodotPhysics3D"),
                   lambda x: x["invariants"].update(force_budget_violation=True),
                   lambda x: x.update(scenarios=[]),
                   lambda x: x["scenarios"][0]["metrics"].update(bad=float("nan"))]
        for change in changes:
            value = copy.deepcopy(original)
            change(value)
            with self.assertRaises(ValueError):
                validate_result(value, candidate())

    def test_actual_task_failure_is_not_runtime_crash_or_successful_task(self):
        value = engine_result(candidate())
        validate_result(value, candidate())
        self.assertFalse(value["scenarios"][0]["completed"])

    def test_godot_full_version_hash_matches_cli_abbreviation(self):
        request = candidate()
        request["engine_identity"]["version"] = "4.7.2.stable.official.ed1daf0bf"
        value = engine_result(request)
        value["environment"]["engine_version"] = "ed1daf0bf001b61586d9930840f2f1394092c079"
        validate_result(value, request)

    def test_engine_source_rejection_retains_taxonomy_without_a_score(self):
        request = candidate()
        value = engine_result(request)
        value.update(status="invalid_candidate", reason="SOURCE_MISMATCH")
        value["environment"]["source_hashes"] = {"features/driver.gd": "0" * 64}
        validate_result(value, request)
        value["trial_id"] = "stale"
        with self.assertRaises(ValueError):
            validate_result(value, request)

    def test_unique_directories_and_atomic_results(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            result1, first = run_trial(candidate(), folder, resource=RESOURCE, command_override=[sys.executable, "-c", "pass"], verify_provenance=False)
            result2, second = run_trial(candidate(), folder, resource=RESOURCE, command_override=[sys.executable, "-c", "pass"], verify_provenance=False)
            self.assertNotEqual(first, second)
            self.assertEqual(read_json(first / "result.json"), result1)
            self.assertFalse(list(folder.rglob("*.tmp")))

    def test_invalid_nonfinite_input_preserved_without_launch(self):
        request = candidate()
        request["parameter_overrides"]["traversal_speed_m_s"] = math.nan
        result, directory = self.execute_double("raise RuntimeError('must not launch')", request)
        self.assertEqual(result["status"], "invalid_candidate")
        self.assertTrue((directory / "invalid_input.txt").exists())
        self.assertIsNone(result["exit_code"])

    def test_single_worker_lock(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary)
            with StudyLock(path):
                with self.assertRaises(RuntimeError):
                    with StudyLock(path):
                        pass
            self.assertFalse((path / "worker.lock").exists())

    def test_holdout_cannot_execute_without_public_freeze(self):
        request = candidate()
        request["evaluation_split"] = "holdout"
        result, _ = self.execute_double("raise RuntimeError('must not launch')", request)
        self.assertEqual(result["status"], "invalid_candidate")
        self.assertIn("frozen public shortlist", result["reason"])

    def test_holdout_freeze_requires_matching_provenance_and_repeats(self):
        request = candidate()
        core = {"frozen": True, "frozen_at_utc": utc_now(), "candidates": [{"candidate_id": request["candidate_id"], "parameter_overrides": request["parameter_overrides"]}],
                "baseline": {"candidate_id": request["candidate_id"], "parameter_overrides": request["parameter_overrides"]},
                "provenance": {key: request[key] for key in ("repository_commit", "engine_identity", "source_hashes")}}
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "freeze.json"
            freeze = {**core, "freeze_sha256": digest(core)}
            atomic_json(path, freeze)
            validate_shortlist(path, request)
            with self.assertRaises(InvalidCandidate):
                validate_shortlist(path, request, require_repeats=True)
            bad = copy.deepcopy(request)
            bad["source_hashes"]["features/driver.gd"] = "d" * 64
            with self.assertRaises(InvalidCandidate):
                validate_shortlist(path, bad)
            bad = {**request, "repository_commit": "f" * 40}
            with self.assertRaises(InvalidCandidate):
                validate_shortlist(path, bad)
            core["training_repeat_validation"] = {"passed": True, "repeats_per_frequency": 3, "frequencies": [60, 120]}
            atomic_json(path, {**core, "freeze_sha256": digest(core)})
            validate_shortlist(path, request, require_repeats=True)
            modified = read_json(path)
            modified["candidates"][0]["parameter_overrides"]["traversal_speed_m_s"] = .3
            atomic_json(path, modified)
            with self.assertRaises(InvalidCandidate):
                validate_shortlist(path, request, require_repeats=True)


if __name__ == "__main__":
    unittest.main()
