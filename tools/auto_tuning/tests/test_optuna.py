"""Installed API/persistence smoke, using math tables and no engine process."""
from pathlib import Path
import tempfile
import unittest
import optuna


class OptunaTests(unittest.TestCase):
    def test_pinned_multiobjective_random_tpe_and_sqlite(self):
        self.assertEqual(optuna.__version__, "5.0.0")
        with tempfile.TemporaryDirectory() as temporary:
            url = "sqlite:///" + (Path(temporary) / "contract.sqlite3").as_posix()
            storage = optuna.storages.RDBStorage(url)
            study = optuna.create_study(storage=storage, study_name="synthetic_api_contract",
                                        sampler=optuna.samplers.RandomSampler(seed=17), directions=["maximize"] * 4)
            for index in range(3):
                if index == 2:
                    study.sampler = optuna.samplers.TPESampler(seed=17, n_startup_trials=0, multivariate=False, constant_liar=False)
                trial = study.ask()
                x = trial.suggest_float("synthetic_x", 0, 1)
                trial.set_constraint("synthetic_hard_gate", 0.0)
                trial.set_user_attr("scope", "synthetic API smoke, no gameplay evidence")
                study.tell(trial, values=[x, 1 - x, 0, 1])
            resumed = optuna.load_study(storage=storage, study_name="synthetic_api_contract")
            self.assertEqual(len(resumed.trials), 3)
            self.assertTrue(resumed.best_trials)
            self.assertEqual(len(resumed.directions), 4)
            trial = resumed.ask()
            trial.set_constraint("synthetic_hard_gate", 1.0)
            resumed.tell(trial, state=optuna.trial.TrialState.FAIL)
            self.assertIsNone(resumed.trials[-1].values)
            storage.remove_session()
            storage.engine.dispose()


if __name__ == "__main__":
    unittest.main()
