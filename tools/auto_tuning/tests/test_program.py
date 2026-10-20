"""Orchestrator test with explicit artificial task outcomes and no Godot process."""
import copy
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

import optuna

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import optimize
from common import atomic_json, read_json
from test_contract import RESOURCE
from test_scoring import outcome


class ProgramTests(unittest.TestCase):
    def test_known_support_loss_is_unscored_confirmed_once_and_stops(self):
        databases = []
        real_create = optuna.create_study

        def create(**kwargs):
            database = optuna.storages.RDBStorage(kwargs["storage"])
            databases.append(database)
            return real_create(**{**kwargs, "storage": database})

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            project = root / "synthetic_project"
            config = read_json(Path(optimize.__file__).parent / "configs/first_sweep.json")
            config["study_name"] = "synthetic_program_contract"
            config_path = root / "config.json"
            atomic_json(config_path, config)
            train = {"input_trace_id": "synthetic_policy", "scenarios": [{"id": row["id"]} for row in outcome()["engine_result"]["scenarios"]]}
            atomic_json(project / "features/auto_tuning_lab/resources/train_scenarios.json", train)
            calls = []

            def fake_trial(request, output, **_):
                calls.append(request)
                result = outcome()
                if len(calls) > 3:
                    row = next(row for row in result["engine_result"]["scenarios"] if row["id"] == "lateral_traverse_train")
                    row.update(status="failed_task", completed=False, reason="NATIVE_GROUND_CONTAMINATED", ground_contact_during_measurement=True)
                    row["metrics"]["useful_displacement_m"] = None
                result.update(reason="completed", elapsed_wall_s=0.0)
                directory = output / request["trial_id"]
                atomic_json(directory / "result.json", result)
                return result, directory

            try:
                with patch.object(optimize, "run_trial", side_effect=fake_trial), patch.object(optimize, "parameter_resource", return_value=RESOURCE), \
                     patch.object(optimize, "source_hashes", return_value={"synthetic_driver.gd": "a" * 64}), \
                     patch.object(optimize, "git_identity", return_value={"repository_commit": "b" * 40, "repository_dirty": False}), \
                     patch.object(optimize, "engine_identity", return_value={"version": "synthetic", "sha256": "c" * 64}), \
                     patch.object(optimize.optuna, "create_study", side_effect=create):
                    state = optimize.run(config_path, root / "study", project=project)
                self.assertEqual(len(calls), 5)  # Three baselines, one proposal, exactly one confirmation.
                self.assertEqual(len(state["trials"]), 1)
                self.assertEqual(state["status"], "stopped")
                self.assertIn("reproduced essential physical", state["stopped"])
                trial = optuna.load_study(study_name=config["study_name"], storage=databases[0]).trials[0]
                self.assertEqual(trial.state, optuna.trial.TrialState.FAIL)
                self.assertIsNone(trial.values)
                self.assertNotIn("score", state["trials"][0])
                self.assertTrue((root / "study/pareto.json").is_file())
                self.assertFalse(any("holdout" in request["scenarios"] for request in calls))
            finally:
                for database in databases:
                    database.remove_session()
                    database.engine.dispose()


if __name__ == "__main__":
    unittest.main()
