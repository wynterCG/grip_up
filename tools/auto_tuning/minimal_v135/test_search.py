"""Synthetic unit evidence only: no Godot, human traces or physical scores."""
import copy
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

sys.path.insert(0, str(Path(__file__).resolve().parent))
from search import (Budget, PLAN, ProposalStudy, TRAIN_IDS, baseline, candidate_id,
                    digest, pareto, project_score, sensitivity_proposals, validate_parameters)
from candidate_schema import parameter_resource


def metric(name, value, status="MEASURED", reason="UNIT_TRACE"):
    return dict(metric=name, value=value, status=status, reason_code=reason,
                onset_tick=100, end_tick=220, unit="synthetic_unit")


def envelope(progress=(.20, .14)):
    scenarios = {}
    for scenario, value in zip(TRAIN_IDS, progress):
        scenarios[scenario] = dict(task_succeeded=True, observation={"status": "MEASURED"}, metrics={
            "signed_progress_m": metric("signed_progress_m", value),
            "hard_physical_violations": metric("hard_physical_violations", 0),
            "directional_efficiency": metric("directional_efficiency", .8),
            "latency_to_useful_motion_s": metric("latency_to_useful_motion_s", None,
                "PRECONDITION_NOT_MET", "ALREADY_MOVING_BEFORE_ONSET"),
            "twist_rms_rad": metric("twist_rms_rad", None, "NOT_APPLICABLE", "NO_VALID_TWIST_FRAME"),
        })
    return dict(lane="FIXED_TAPE", physics_hz=120, run_valid=True, source_identity_ok=True,
                teardown_ok=True, hard_invariants_pass=True, scenarios=scenarios)


def quality():
    return {"frozen": True, "tasks": {key: {
        "directional_efficiency": dict(direction="maximize", max_worsening=.03),
        "latency_to_useful_motion_s": dict(direction="minimize", max_worsening=.02,
            allowed_missing=[dict(status="PRECONDITION_NOT_MET", reason_code="ALREADY_MOVING_BEFORE_ONSET")]),
        "twist_rms_rad": dict(direction="minimize", max_worsening=.02,
            allowed_missing=[dict(status="NOT_APPLICABLE", reason_code="NO_VALID_TWIST_FRAME")]),
    } for key in TRAIN_IDS}}


class ParametersAndBudget(unittest.TestCase):
    def setUp(self):
        self.registry = parameter_resource()

    def test_exact_eight_safe_single_factor_perturbations(self):
        proposals = sensitivity_proposals(self.registry)
        self.assertEqual(len(proposals), 8)
        self.assertEqual(len({row["candidate_id"] for row in proposals}), 8)
        a0 = baseline(self.registry)
        for row in proposals:
            self.assertEqual(sum(row["parameter_overrides"][key] != a0[key] for key in a0), 1)
            self.assertEqual(row["candidate_id"], candidate_id(row["parameter_overrides"]))

    def test_strict_whitelist_precision_constraint_and_boolean(self):
        center = baseline(self.registry)
        variants = [dict(center, traversal_speed_m_s=True),
                    dict(center, traversal_speed_m_s=float("nan")),
                    dict(center, traversal_speed_m_s=.250000001),
                    dict(center, traversal_target_max_rate=.30, traversal_target_max_acceleration=.60),
                    {**center, "strength": 999}, {key:value for key,value in center.items() if key!="traversal_speed_m_s"}]
        for values in variants:
            with self.subTest(values=values), self.assertRaises(ValueError):
                validate_parameters(values, self.registry)

    def test_canonical_numeric_equivalence(self):
        center = baseline(self.registry)
        self.assertEqual(validate_parameters(center, self.registry),
                         validate_parameters({k:float(v) for k,v in center.items()}, self.registry))

    def test_budget_eighteen_pairs_and_two_confirmations_including_failures(self):
        b = Budget()
        for i in range(18):b.reserve(f"candidate_{i}")
        with self.assertRaises(ValueError):b.reserve("candidate_19")
        b.reserve("failed_timeout_confirmation", confirmation=True)
        b.reserve("confirm_2", confirmation=True)
        self.assertEqual(sum(r["processes"] for r in b.snapshot()), 40)
        with self.assertRaises(ValueError):b.reserve("extra", confirmation=True)
        self.assertEqual(Budget(b.snapshot()).snapshot(), b.snapshot())

    def test_no_partial_reservation_or_duplicate_or_boolean(self):
        b=Budget();b.reserve("a")
        for args in [dict(attempt_id="a"),dict(attempt_id="b",processes=1),
                     dict(attempt_id="b",episodes=True),dict(attempt_id="b",confirmation=1)]:
            with self.subTest(args=args), self.assertRaises(ValueError):b.reserve(**args)
        self.assertEqual(len(b.snapshot()),1)


class ScoreTests(unittest.TestCase):
    def score(self, changed=None, base=None, rules=None):
        return project_score(changed or envelope(),base or envelope(),rules or quality())

    def test_baseline_explicit_two_axes_and_four_dimensions(self):
        score=self.score()
        self.assertTrue(score['eligible']);self.assertEqual(score['values'],[.2,.14])
        self.assertFalse(score['practical_gain']);self.assertEqual(len(score['four_dimensions']),4)

    def test_practical_floor_and_other_task_loss_boundary(self):
        for progress, gain in [((.21,.14),True),((.209,.14),False),((.21,.135),True)]:
            score=self.score(envelope(progress));self.assertTrue(score['eligible']);self.assertEqual(score['practical_gain'],gain)
        score=self.score(envelope((.23,.1349)))
        self.assertEqual(score['disposition'],'REJECT_CANDIDATE');self.assertIsNone(score['values'])

    def test_five_percent_and_three_percent_large_baseline(self):
        base=envelope((1.,1.));self.assertTrue(self.score(envelope((1.05,.97)),base)['practical_gain'])
        self.assertFalse(self.score(envelope((1.049,1.)),base)['practical_gain'])
        self.assertEqual(self.score(envelope((1.1,.969)),base)['disposition'],'REJECT_CANDIDATE')

    def test_genuine_interrupted_task_rejected_never_zero(self):
        row=envelope();s=row['scenarios'][TRAIN_IDS[0]]
        s['task_succeeded']=False;s['observation']['status']='INTERRUPTED'
        s['metrics']['signed_progress_m']=metric('signed_progress_m',None,'INTERRUPTED','GROUND_AUTHORITY')
        result=self.score(row);self.assertEqual(result['disposition'],'REJECT_CANDIDATE');self.assertIsNone(result['values'])
        self.assertIsNone(result['four_dimensions']['directed_progress'][TRAIN_IDS[0]]['value'])

    def test_precondition_failure_blank_monitor_is_not_fake_invariant(self):
        row=envelope();s=row['scenarios'][TRAIN_IDS[0]];s['task_succeeded']=False
        s['observation']['status']='PRECONDITION_NOT_MET'
        for name in s['metrics']:s['metrics'][name]=metric(name,None,'PRECONDITION_NOT_MET','NO_ACTUAL_ONSET')
        self.assertEqual(self.score(row)['disposition'],'REJECT_CANDIDATE')

    def test_official_projection_nulls_partial_interrupted_progress_preserves_raw_evidence(self):
        row=envelope();s=row['scenarios'][TRAIN_IDS[0]];s['task_succeeded']=False
        s['observation']['status']='INTERRUPTED'
        s['metrics']['signed_progress_m']=metric('signed_progress_m',.081,'INTERRUPTED','NATIVE_GROUND_AUTHORITY')
        s['metrics']['directional_efficiency']=metric('directional_efficiency',.72,'INTERRUPTED','NATIVE_GROUND_AUTHORITY')
        row['raw_summary']={TRAIN_IDS[0]:copy.deepcopy(s)}
        s['metrics']['signed_progress_m']['value']=None
        s['metrics']['directional_efficiency']['value']=None
        result=self.score(row)
        self.assertEqual(result['disposition'],'REJECT_CANDIDATE');self.assertIsNone(result['values'])
        self.assertIsNone(result['four_dimensions']['directed_progress'][TRAIN_IDS[0]]['value'])
        self.assertEqual(row['raw_summary'][TRAIN_IDS[0]]['metrics']['signed_progress_m']['value'],.081)

    def test_unnormalized_nonmeasured_partial_is_global_contract_error(self):
        for status in ['INTERRUPTED','CENSORED_TIMEOUT','PRECONDITION_NOT_MET','NOT_APPLICABLE']:
            row=envelope();s=row['scenarios'][TRAIN_IDS[0]];s['task_succeeded']=False
            s['observation']['status']=status
            s['metrics']['signed_progress_m']=metric('signed_progress_m',.081,status,'RAW_PARTIAL_NOT_PROJECTED')
            result=self.score(row)
            self.assertEqual(result['disposition'],'STOP_STUDY');self.assertIsNone(result['values'])

    def test_missing_baseline_or_invalid_metric_stops_whole_study(self):
        for label in ['baseline','candidate']:
            row=envelope();row['scenarios'][TRAIN_IDS[0]]['metrics']['signed_progress_m']=metric('signed_progress_m',None,'INVALID_MEASUREMENT','BAD_CLOCK')
            self.assertEqual(self.score(base=row) ['disposition'] if label=='baseline' else self.score(row)['disposition'],'STOP_STUDY')

    def test_false_missing_bool_lane_hz_extra_domain_stop(self):
        for key,value in [('run_valid',False),('hard_invariants_pass',None),('source_identity_ok',1),('lane','ADAPTIVE_CAPTURE'),('physics_hz',60)]:
            row=envelope();row[key]=value;self.assertEqual(self.score(row)['disposition'],'STOP_STUDY')
        row=envelope();row['scenarios']['catch_holdout']=copy.deepcopy(row['scenarios'][TRAIN_IDS[0]])
        self.assertEqual(self.score(row)['disposition'],'STOP_STUDY')

    def test_invariant_never_compensated_by_high_progress(self):
        row=envelope((10.,10.));row['scenarios'][TRAIN_IDS[0]]['metrics']['hard_physical_violations']['value']=1
        self.assertEqual(self.score(row)['disposition'],'STOP_STUDY')

    def test_quality_regression_reject_and_unmeasured_twist_retained(self):
        row=envelope((.3,.2));row['scenarios'][TRAIN_IDS[0]]['metrics']['directional_efficiency']['value']=.76
        self.assertEqual(self.score(row)['disposition'],'REJECT_CANDIDATE')
        result=self.score();twist=result['four_dimensions']['physics_control_quality'][TRAIN_IDS[0]]['twist_rms_rad']
        self.assertEqual(twist['status'],'NOT_APPLICABLE');self.assertIsNone(twist['value'])

    def test_latency_already_moving_never_zero_and_unknown_null_rejected(self):
        result=self.score();latency=result['four_dimensions']['movement_fidelity'][TRAIN_IDS[0]]['latency_to_useful_motion_s']
        self.assertIsNone(latency['value']);self.assertEqual(latency['reason_code'],'ALREADY_MOVING_BEFORE_ONSET')
        row=envelope();row['scenarios'][TRAIN_IDS[0]]['metrics']['latency_to_useful_motion_s']['reason_code']='UNKNOWN'
        self.assertEqual(self.score(row)['disposition'],'REJECT_CANDIDATE')

    def test_nonfinite_bool_and_materialized_null_stop(self):
        for value,status in [(float('inf'),'MEASURED'),(False,'MEASURED'),(0,'NOT_APPLICABLE')]:
            row=envelope();row['scenarios'][TRAIN_IDS[0]]['metrics']['twist_rms_rad']=metric('twist_rms_rad',value,status)
            self.assertEqual(self.score(row)['disposition'],'STOP_STUDY')

    def test_quality_contract_must_be_frozen_and_derived_before_proposals(self):
        rules=quality();rules['frozen']=False
        self.assertEqual(self.score(rules=rules)['disposition'],'STOP_STUDY')

    def test_pareto_retains_baseline_in_archive_and_bounds_shortlist(self):
        base={'candidate_id':'a0','score':self.score()}
        records=[{'candidate_id':str(i),'score':self.score(envelope((.22+i*.001,.16-i*.001)))} for i in range(5)]
        result=pareto(records+[records[0]],base)
        self.assertEqual(len(result['archive']),6);self.assertTrue(result['baseline_in_archive'])
        self.assertNotIn('a0',[r['candidate_id'] for r in result['frontier']]);self.assertLessEqual(len(result['shortlist']),3)


class SyntheticSQLiteTests(unittest.TestCase):
    """Temp SQLite only; fake MB2 gate + fabricated unit metrics, NOT a pilot."""
    def setUp(self):
        self.registry=parameter_resource();self.identity={'seed':101,'data_kind':'SYNTHETIC_UNIT_NO_PHYSICS','source':'unit'}
        self.qualification={'decision':'GO_MINIMAL_BENCHMARK','identity_sha256':digest(self.identity)}
        self.tmp=tempfile.TemporaryDirectory();self.path=Path(self.tmp.name)/'synthetic_unit'
        import optuna
        optuna.logging.set_verbosity(optuna.logging.ERROR)

    def tearDown(self):self.tmp.cleanup()

    def open(self,identity=None):
        identity=identity or self.identity
        return ProposalStudy(self.path,identity,self.registry,{'decision':'GO_MINIMAL_BENCHMARK','identity_sha256':digest(identity)})

    def test_no_go_refuses_before_sqlite(self):
        with self.assertRaises(ValueError):ProposalStudy(self.path,self.identity,self.registry,{'decision':'NO_GO'})
        self.assertFalse((self.path/'study.sqlite3').exists())

    def test_eight_sensitivity_order_sqlite_resume_identity_guard(self):
        expected=sensitivity_proposals(self.registry)
        with self.open() as s:
            for e in expected:
                p=s.ask();self.assertEqual(p['candidate_id'],e['candidate_id'])
                s.tell(p,project_score(envelope(),envelope(),quality()),'SYNTHETIC_UNIT/no_engine')
        with self.open() as s:
            self.assertEqual(s.ask()['phase'],'random')
        changed={**self.identity,'source':'different'}
        with self.assertRaises(ValueError),self.open(changed):pass

    def test_failed_trial_has_no_objective_and_no_hidden_redraw(self):
        with self.open() as s:
            p=s.ask();s.tell(p,{'eligible':False,'disposition':'REJECT_CANDIDATE','values':None},'SYNTHETIC_UNIT/failure')
            self.assertIsNone(s.study.trials[0].values)
            self.assertEqual(s.ask()['proposal_index'],1)

    def test_running_resume_and_second_worker_refuse(self):
        with self.open() as s:
            s.ask()
            with self.assertRaises(RuntimeError),self.open():pass
        with self.open() as s:
            with self.assertRaises(ValueError):s.ask()

    def test_finalized_trial_cannot_be_told_twice(self):
        with self.open() as s:
            p=s.ask();score=project_score(envelope(),envelope(),quality());s.tell(p,score,'SYNTHETIC_UNIT/ok')
            with self.assertRaises(ValueError):s.tell(p,score,'SYNTHETIC_UNIT/overwrite')

    def test_global_stop_persists_and_blocks_new_proposals(self):
        with self.open() as s:
            p=s.ask();s.tell(p,{'eligible':False,'disposition':'STOP_STUDY','reasons':['UNIT_BAD_CLOCK'],'values':None},'SYNTHETIC_UNIT/clock')
            with self.assertRaises(ValueError):s.ask()
        with self.open() as s:
            with self.assertRaises(ValueError):s.ask()

    def test_tampered_parameters_cannot_be_finalized(self):
        with self.open() as s:
            p=s.ask();p['parameter_overrides']['traversal_speed_m_s']=.23
            with self.assertRaises(ValueError):s.tell(p,project_score(envelope(),envelope(),quality()),'SYNTHETIC_UNIT/tampered')

    def test_duplicate_and_invalid_samples_consumed_without_redraw(self):
        with self.open() as s:
            for _ in range(8):
                p=s.ask();s.tell(p,project_score(envelope(),envelope(),quality()),'SYNTHETIC_UNIT/ok')
            import optuna
            base_sampler=optuna.samplers.RandomSampler(seed=1)
            for index,values,status in [(8,baseline(self.registry),'DUPLICATE'),
                    (9,{**baseline(self.registry),'traversal_target_max_rate':.30,'traversal_target_max_acceleration':.60},'INVALID_PARAMETERS')]:
                fixed=optuna.samplers.PartialFixedSampler(values,base_sampler)
                with mock.patch.object(optuna.samplers,'RandomSampler',return_value=fixed):
                    p=s.ask()
                self.assertEqual(p['proposal_index'],index);self.assertEqual(p['status'],status)
                self.assertIsNone(s.study.trials[-1].values)

    def test_bounded_schedule_and_tpe_requires_explicit_signal_gate(self):
        with self.open() as s:
            for _ in range(14):
                p=s.ask()
                if p['status']=='PROPOSED':s.tell(p,project_score(envelope(),envelope(),quality()),'SYNTHETIC_UNIT/ok')
            with self.assertRaises(ValueError):s.ask()
            for _ in range(4):
                p=s.ask(tpe_ready=True);self.assertEqual(p['phase'],'tpe')
                if p['status']=='PROPOSED':s.tell(p,project_score(envelope(),envelope(),quality()),'SYNTHETIC_UNIT/ok')
            self.assertIsNone(s.ask(tpe_ready=True));self.assertEqual(len(s.study.trials),18)


if __name__=='__main__':unittest.main()
