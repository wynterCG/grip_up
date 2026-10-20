"""Known synthetic detector traces only: these do not demonstrate game braking."""
import copy
import math
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from metric_contracts import analyze, precondition_outcomes


def trace(velocities, *, hz=10, intents=None, angular=None):
    position = 0.0
    result = []
    for index, velocity in enumerate(velocities):
        if index:
            position += (velocity + velocities[index - 1]) * .5 / hz
        result.append({"tick": index, "physics_time_s": index / hz, "delta_s": 1 / hz, "sample_phase": "post_control",
                       "body": {"com_m": [position, 0, 0], "linear_velocity_m_s": [velocity, 0, 0],
                                "angular_velocity_rad_s": [0, 0 if angular is None else angular[index], 0]},
                       "command_accepted": {"intent_world": [0 if intents is None else intents[index], 0, 0]},
                       "support": {"valid": True, "frame_id": "static_wall_material_A", "point_m": [0, 0, 0],
                                   "point_velocity_m_s": [0, 0, 0], "angular_velocity_rad_s": [0, 0, 0],
                                   "grounded": False, "hybrid_owned": False}})
    return result


def config(duration=1, hz=10, **extra):
    return {"physics_hz": hz, "sample_phase": "post_control", "direction_world": [1, 0, 0], "deadline_s": duration, **extra}


def transition(kind="release", tick=0, hz=10, **extra):
    return {"kind": kind, "tick": tick, "physics_time_s": tick / hz, **extra}


class MetricStatusTests(unittest.TestCase):
    def test_monotonic_deceleration_sustained_settle_and_distance(self):
        samples = trace([1, .8, .6, .4, .2, .1, 0, 0, 0, 0, 0])
        result = analyze(samples, config(), transition())
        stop = result["metrics"]["stop_distance_m"]
        self.assertEqual(stop["status"], "MEASURED")
        self.assertEqual(stop["unit"], "m")
        self.assertAlmostEqual(stop["value"], .26)
        self.assertAlmostEqual(stop["confirmation_time_s"], .8)
        self.assertAlmostEqual(result["metrics"]["settling_time_s"]["value"], .5)

    def test_temporary_settle_resets_instead_of_returning_false_early_zero(self):
        samples = trace([.3, .09, .08, .09, .2, .09, .08, .07, .06, .05, .04])
        result = analyze(samples, config(), transition())
        self.assertAlmostEqual(result["metrics"]["settling_time_s"]["value"], .5)
        self.assertAlmostEqual(result["metrics"]["settling_time_s"]["confirmation_time_s"], .8)

    def test_threshold_chatter_is_censored_with_partial_motion(self):
        result = analyze(trace([.11, .09] * 6), config(), transition())
        metric = result["metrics"]["stop_distance_m"]
        self.assertEqual(metric["status"], "CENSORED_TIMEOUT")
        self.assertIsNone(metric["value"])
        self.assertGreater(metric["observed_path_length_m"], 0)
        self.assertAlmostEqual(metric["observed_duration_s"], 1)

    def test_angular_band_is_required_even_when_translation_is_stationary(self):
        result = analyze(trace([0] * 11, angular=[.3] * 11), config(), transition())
        self.assertEqual(result["metrics"]["settling_time_s"]["status"], "CENSORED_TIMEOUT")
        self.assertIsNone(result["metrics"]["stop_distance_m"]["value"])

    def test_low_energy_stationary_control_has_a_real_measured_zero(self):
        result = analyze(trace([0] * 11), config(), transition())
        self.assertEqual(result["metrics"]["stop_distance_m"]["status"], "MEASURED")
        self.assertEqual(result["metrics"]["stop_distance_m"]["value"], 0)
        self.assertEqual(result["metrics"]["directional_efficiency"]["reason"], "UNDEFINED_NO_MOVEMENT")
        self.assertIsNone(result["metrics"]["directional_efficiency"]["value"])

    def test_underdamped_oscillation_retains_signed_drift_and_full_path(self):
        velocities = [.3 * math.exp(-.1 * index / 100) * math.cos(2 * math.pi * index / 50) for index in range(201)]
        result = analyze(trace(velocities, hz=100), config(2, 100), transition(hz=100))
        drift = result["metrics"]["release_signed_drift_m"]
        self.assertEqual(drift["status"], "CENSORED_TIMEOUT")
        self.assertIsNone(drift["value"])
        self.assertGreater(drift["observed_path_length_m"], abs(drift["observed_signed_displacement_m"]))

    def test_onset_is_the_accepted_tick_not_first_trace_sample(self):
        samples = trace([1] * 5 + [1, .2, 0, 0, 0, 0, 0, 0, 0, 0, 0], intents=[1] * 5 + [0] * 11)
        result = analyze(samples, config(), transition(tick=5))
        self.assertAlmostEqual(result["metrics"]["settling_time_s"]["value"], .2)
        self.assertLess(result["metrics"]["stop_distance_m"]["value"], .15)
        self.assertEqual(result["observation"]["accepted_transition_tick"], 5)

    def test_stop_overshoot_excludes_held_command_corridor_excursion(self):
        samples = trace([10] * 5 + [.2, .1, 0, 0, 0, 0, 0, 0, 0, 0, 0], intents=[1] * 5 + [0] * 11)
        result = analyze(samples, config(), transition(tick=5, stop_target_progress_m=.01))
        metric = result["metrics"]["post_stop_overshoot_m"]
        self.assertEqual(metric["status"], "MEASURED")
        self.assertAlmostEqual(metric["value"], .01)
        self.assertLess(metric["value"], .1)

    def test_no_stop_target_is_explicitly_not_applicable(self):
        result = analyze(trace([0] * 11), config(), transition())
        self.assertEqual(result["metrics"]["post_stop_overshoot_m"]["status"], "NOT_APPLICABLE")

    def test_active_brake_fractions_use_speed_and_not_input_name_as_proof(self):
        samples = trace([1, .8, .6, .4, .2, 0, 0, 0, 0, 0, 0], intents=[-1] * 5 + [0] * 6)
        result = analyze(samples, config(), transition("brake"))
        half, tenth = result["active_braking"]
        self.assertEqual(half["time_s"]["status"], "MEASURED")
        self.assertAlmostEqual(half["time_s"]["value"], .3)
        self.assertAlmostEqual(half["distance_m"]["value"], .21)
        self.assertAlmostEqual(tenth["time_s"]["value"], .5)
        self.assertEqual(result["metrics"]["release_signed_drift_m"]["status"], "NOT_APPLICABLE")

    def test_brake_command_without_deceleration_does_not_measure_success(self):
        samples = trace([1] * 11, intents=[-1] * 3 + [0] * 8)
        result = analyze(samples, config(), transition("brake"))
        value = result["active_braking"][0]["time_s"]
        self.assertEqual(value["status"], "INTERRUPTED")
        self.assertIsNone(value["value"])
        self.assertEqual(value["interruption"]["tick"], 3)

    def test_reversal_requires_persistent_signed_velocity(self):
        samples = trace([.2, .1, -.03, .01, -.03, -.04, -.05, -.05, -.05, -.05, -.05], intents=[-1] * 11)
        result = analyze(samples, config(), transition("reverse"))
        metric = result["metrics"]["reversal_time_s"]
        self.assertEqual(metric["status"], "MEASURED")
        self.assertAlmostEqual(metric["value"], .4)
        self.assertAlmostEqual(metric["confirmation_time_s"], .5)
        self.assertEqual(result["metrics"]["stop_distance_m"]["status"], "NOT_APPLICABLE")

    def test_reversal_timeout_is_not_zero(self):
        result = analyze(trace([.2] * 11, intents=[-1] * 11), config(), transition("reverse"))
        self.assertEqual(result["metrics"]["reversal_time_s"]["status"], "CENSORED_TIMEOUT")
        self.assertIsNone(result["metrics"]["reversal_time_s"]["value"])

    def test_counter_swing_negative_start_reverses_into_positive_accepted_direction(self):
        samples = trace([-.2, -.1, .03, -.01, .03, .04, .05, .05, .05, .05, .05], intents=[1] * 11)
        result = analyze(samples, config(), transition("reverse"))
        self.assertEqual(result["metrics"]["reversal_time_s"]["status"], "MEASURED")
        self.assertAlmostEqual(result["metrics"]["reversal_time_s"]["value"], .4)
        self.assertEqual(result["observation"]["accepted_effort_direction_world_at_onset"], [1.0, 0.0, 0.0])

    def test_supported_material_motion_is_subtracted_explicitly(self):
        samples = trace([0] * 11)
        for row in samples:
            row["body"]["com_m"][0] += 2 * row["physics_time_s"]
            row["body"]["linear_velocity_m_s"][0] += 2
            row["support"]["point_m"][0] = 2 * row["physics_time_s"]
            row["support"]["point_velocity_m_s"][0] = 2
        result = analyze(samples, config(), transition())
        self.assertEqual(result["metrics"]["stop_distance_m"]["status"], "MEASURED")
        self.assertAlmostEqual(result["metrics"]["stop_distance_m"]["value"], 0)

    def test_loss_ground_hybrid_collision_and_new_commands_interrupt(self):
        changes = [lambda row: row["support"].update(valid=False), lambda row: row["support"].update(grounded=True),
                   lambda row: row["support"].update(hybrid_owned=True), lambda row: row["support"].update(frame_id="new_material"),
                   lambda row: row.update(interruption={"reason": "COLLISION_CHANGED_TASK"}),
                   lambda row: row["command_accepted"].update(intent_world=[1, 0, 0])]
        for change in changes:
            with self.subTest(change=change):
                samples = trace([1] * 11)
                change(samples[4])
                result = analyze(samples, config(), transition())
                metric = result["metrics"]["stop_distance_m"]
                self.assertEqual(metric["status"], "INTERRUPTED")
                self.assertEqual(metric["interruption"]["tick"], 4)
                self.assertAlmostEqual(metric["observed_duration_s"], .3)
                self.assertIsNone(metric["value"])

    def test_completed_metric_before_later_interruption_remains_measured(self):
        samples = trace([0] * 11)
        samples[6]["support"]["grounded"] = True
        result = analyze(samples, config(fixed_horizons_s=[.2, .8]), transition())
        self.assertEqual(result["metrics"]["stop_distance_m"]["status"], "MEASURED")
        self.assertEqual(result["fixed_horizons"][0]["status"], "MEASURED")
        self.assertEqual(result["fixed_horizons"][1]["status"], "INTERRUPTED")

    def test_preconditions_are_explicit(self):
        cases = [(lambda rows: rows[0]["support"].update(valid=False), config(), transition()),
                 (lambda rows: rows[0]["support"].update(grounded=True), config(), transition()),
                 (lambda rows: None, config(min_initial_speed_m_s=2), transition()),
                 (lambda rows: rows[0]["command_accepted"].update(intent_world=[1, 0, 0]), config(), transition()),
                 (lambda rows: None, config(), transition("brake"))]
        for change, settings, event in cases:
            rows = trace([1] * 11)
            change(rows)
            self.assertEqual(analyze(rows, settings, event)["metrics"]["stop_distance_m"]["status"], "PRECONDITION_NOT_MET")

    def test_unmet_preconditions_keep_requested_fraction_and_horizon_statuses(self):
        result = analyze(trace([0] * 11, intents=[-1] * 11), config(fixed_horizons_s=[.5]), transition("brake"))
        self.assertEqual(result["active_braking"][0]["time_s"]["status"], "PRECONDITION_NOT_MET")
        self.assertIsNone(result["active_braking"][0]["threshold_speed_m_s"])
        self.assertEqual(result["fixed_horizons"][0]["status"], "PRECONDITION_NOT_MET")
        self.assertEqual(result["metrics"]["reversal_time_s"]["status"], "NOT_APPLICABLE")
        samples = trace([0] * 11)
        samples[0]["support"]["valid"] = False
        result = analyze(samples, config(), transition("none"))
        self.assertEqual(result["metrics"]["stop_distance_m"]["status"], "NOT_APPLICABLE")
        self.assertEqual(result["metrics"]["useful_progress_m"]["status"], "PRECONDITION_NOT_MET")

    def test_fixture_precondition_failure_needs_no_fictitious_accepted_transition(self):
        result = precondition_outcomes("REQUIRED_LOW_MOTION_NOT_EARNED", config(fixed_horizons_s=[.5]), "release")
        self.assertEqual(result["metrics"]["stop_distance_m"]["status"], "PRECONDITION_NOT_MET")
        self.assertEqual(result["metrics"]["reversal_time_s"]["status"], "NOT_APPLICABLE")
        self.assertEqual(result["fixed_horizons"][0]["status"], "PRECONDITION_NOT_MET")
        self.assertIsNone(result["metrics"]["stop_distance_m"]["observed_duration_s"])
        self.assertEqual(precondition_outcomes("", config(), "release")["metrics"]["stop_distance_m"]["status"], "INVALID_MEASUREMENT")

    def test_nonfinite_missing_frame_and_bad_timing_are_invalid_not_timeout(self):
        mutations = [lambda rows: rows[3]["body"].update(com_m=[float("nan"), 0, 0]),
                     lambda rows: rows[3]["body"].update(linear_velocity_m_s=[float("inf"), 0, 0]),
                     lambda rows: rows[3]["support"].pop("point_velocity_m_s"),
                     lambda rows: rows[3].update(physics_time_s=rows[2]["physics_time_s"]),
                     lambda rows: rows[3].update(tick=99), lambda rows: rows[3].update(delta_s=.2),
                     lambda rows: rows.pop(3), lambda rows: rows[3].update(sample_phase="wrong_phase")]
        for mutation in mutations:
            rows = trace([1] * 11)
            mutation(rows)
            result = analyze(rows, config(), transition())
            self.assertEqual(result["metrics"]["stop_distance_m"]["status"], "INVALID_MEASUREMENT")
            self.assertIsNone(result["metrics"]["stop_distance_m"]["value"])

    def test_wrong_or_missing_sample_phase_fails_and_pre_post_are_never_mixed(self):
        post = trace([0] * 11)
        pre = copy.deepcopy(post)
        for row in pre:
            row["sample_phase"] = "pre_control"
        wrong = analyze(pre, config(), transition())
        self.assertEqual(wrong["metrics"]["stop_distance_m"]["status"], "INVALID_MEASUREMENT")
        mixed = [row for pair in zip(pre, post) for row in pair]
        result = analyze(mixed, config(), transition())
        self.assertEqual(result["metrics"]["stop_distance_m"]["status"], "MEASURED")
        self.assertEqual(result["observation"]["ignored_other_phase_samples"], 11)

    def test_unrecorded_transition_and_invalid_contract_fail_closed(self):
        for settings, event in ((config(direction_world=[0, 0, 0]), transition()),
                                (config(), {**transition(), "physics_time_s": .05}),
                                (config(fixed_horizons_s=[2]), transition()),
                                (config(settle_hold_s=0), transition())):
            self.assertEqual(analyze(trace([0] * 11), settings, event)["metrics"]["stop_distance_m"]["status"], "INVALID_MEASUREMENT")

    def test_fixed_horizon_measured_even_when_stop_is_censored(self):
        result = analyze(trace([1] * 11), config(fixed_horizons_s=[.5, 1]), transition())
        self.assertEqual(result["metrics"]["stop_distance_m"]["status"], "CENSORED_TIMEOUT")
        self.assertEqual([row["status"] for row in result["fixed_horizons"]], ["MEASURED", "MEASURED"])
        self.assertAlmostEqual(result["fixed_horizons"][0]["value"], .5)
        self.assertAlmostEqual(result["fixed_horizons"][1]["value"], 1)

    def test_early_trace_end_is_invalid_for_unconfirmed_metric(self):
        result = analyze(trace([1] * 6), config(), transition())
        self.assertEqual(result["metrics"]["stop_distance_m"]["status"], "INVALID_MEASUREMENT")
        self.assertEqual(result["metrics"]["stop_distance_m"]["reason"], "TRACE_ENDED_BEFORE_DECLARED_DEADLINE")

    def test_no_stop_or_reverse_requested_is_not_applicable(self):
        result = analyze(trace([1] * 11, intents=[1] * 11), config(), transition("none"))
        for name in ("stop_distance_m", "settling_time_s", "reversal_time_s", "post_stop_overshoot_m"):
            self.assertEqual(result["metrics"][name]["status"], "NOT_APPLICABLE")
            self.assertIsNone(result["metrics"][name]["value"])
        self.assertEqual(result["metrics"]["useful_progress_m"]["status"], "MEASURED")

    def test_60_and_120_use_confirmation_time_not_matching_tick_numbers(self):
        observations = []
        for hz in (60, 120):
            result = analyze(trace([0] * (hz + 1), hz=hz), config(1, hz), transition(hz=hz))
            observations.append(result["metrics"]["stop_distance_m"]["confirmation_time_s"])
            self.assertEqual(result["metrics"]["stop_distance_m"]["status"], "MEASURED")
        self.assertEqual(observations, [.25, .25])


if __name__ == "__main__":
    unittest.main()
