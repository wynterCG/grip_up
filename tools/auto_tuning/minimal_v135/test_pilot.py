"""Synthetic callbacks and temporary SQLite only; no physical pilot evidence."""
from pathlib import Path
import copy
import sys
import tempfile
import unittest

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
sys.path.insert(0,str(Path(__file__).resolve().parent))
from minimal_v135.pilot import run
from search import digest
from candidate_schema import parameter_resource
from common import read_json
from test_search import envelope, quality


class SyntheticPilotTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.path=Path(self.temp.name)/'SYNTHETIC_UNIT_NO_ENGINE'
        self.identity={'seed':101,'data_kind':'SYNTHETIC_UNIT_NO_PHYSICS'}
        self.gate={'decision':'GO_MINIMAL_BENCHMARK','identity_sha256':digest(self.identity)}
        self.registry=parameter_resource();self.calls=[]
        import optuna
        optuna.logging.set_verbosity(optuna.logging.ERROR)

    def tearDown(self):self.temp.cleanup()

    def execute(self,callback,**kwargs):
        return run(self.path,self.identity,self.registry,self.gate,kwargs.get('reference',envelope()),quality(),callback,stop_after=kwargs.get('stop_after'))

    def test_no_go_no_mutations_no_callback(self):
        with self.assertRaises(ValueError):
            run(self.path,self.identity,self.registry,{'decision':'NO_GO'},envelope(),quality(),lambda *a:self.fail('called'))
        self.assertFalse(self.path.exists())

    def test_futility_stops_after_random_preserves_a0_and_exact_reservations(self):
        def callback(params,phase,attempt):
            self.calls.append((params,phase,attempt))
            self.assertTrue((self.path/'proposals'/f'{attempt}.json').exists())
            self.assertTrue((self.path/'attempts'/f'{attempt}.json').exists())
            self.assertEqual(len(read_json(self.path/'pilot_state.json')['reservations']),len(self.calls))
            return envelope()
        report=self.execute(callback)
        self.assertEqual(report['status'],'NO_ELIGIBLE_CANDIDATE');self.assertFalse(report['global_stop'])
        self.assertEqual(report['proposal_count'],14);self.assertFalse(any(c[1]=='tpe' for c in self.calls))
        self.assertEqual(report['process_launches_reserved'],2*len(self.calls))
        self.assertEqual(report['archive'][0]['role'],'FRESH_A0_REFERENCE');self.assertEqual(report['shortlist'],[])
        self.assertEqual(self.execute(lambda *a:self.fail('completed resume called callback')),report)

    def test_informative_surface_tpe_caps_and_deterministic_one_finalist(self):
        def callback(params,phase,attempt):
            self.calls.append(phase);n=len(self.calls)
            return envelope((.21+n*.001,.14+n*.002))
        report=self.execute(callback)
        self.assertEqual(report['proposal_count'],18);self.assertEqual(report['status'],'SHORTLIST_READY')
        self.assertLessEqual(self.calls.count('sensitivity'),8);self.assertLessEqual(self.calls.count('random'),6)
        self.assertLessEqual(self.calls.count('tpe'),4);self.assertGreater(self.calls.count('tpe'),0)
        self.assertEqual(len(report['shortlist']),1);self.assertLessEqual(report['process_launches_reserved'],36)
        self.assertEqual(report['training_episodes_reserved'],len(self.calls)*2)
        self.assertFalse(report['holdout_accessed']);self.assertEqual(report['product_promotion'],'NONE')

    def test_practical_but_identical_vectors_do_not_open_tpe(self):
        report=self.execute(lambda *args:envelope((.22,.16)))
        self.assertEqual(report['proposal_count'],14)
        self.assertIn('three distinct',report['reason'])
        self.assertEqual(report['status'],'SHORTLIST_READY')

    def test_callback_exception_is_global_stop_and_consumes_pair(self):
        def callback(*args):raise TimeoutError('SYNTHETIC_UNIT_TIMEOUT')
        report=self.execute(callback)
        self.assertTrue(report['global_stop']);self.assertEqual(report['status'],'NO_GO_MINIMAL_BENCHMARK')
        self.assertEqual(report['proposal_count'],1);self.assertEqual(report['process_launches_reserved'],2)
        self.assertEqual(len(list((self.path/'failures').glob('*.json'))),1)
        self.assertEqual(self.execute(lambda *a:self.fail('resumed after stop')),report)

    def test_projected_interrupted_partial_rejects_only_candidate(self):
        def callback(*args):
            row=envelope();scenario=next(iter(row['scenarios'].values()))
            scenario['task_succeeded']=False;scenario['observation']['status']='INTERRUPTED'
            for name in ['signed_progress_m','directional_efficiency']:
                scenario['metrics'][name]['status']='INTERRUPTED'
                scenario['metrics'][name]['reason_code']='NATIVE_GROUND_AUTHORITY'
            row['raw_summary']=copy.deepcopy(row['scenarios'])
            for name in ['signed_progress_m','directional_efficiency']:
                scenario['metrics'][name]['value']=None
            return row
        report=self.execute(callback)
        self.assertFalse(report['global_stop']);self.assertEqual(report['proposal_count'],14)
        records=[r for r in report['records'] if r['status']=='PROPOSED']
        self.assertTrue(all(r['score']['values'] is None for r in records))
        self.assertTrue(all(r['score']['disposition']=='REJECT_CANDIDATE' for r in records))

    def test_source_quality_baseline_changes_refuse_resume(self):
        self.execute(lambda *args:envelope())
        changed=envelope((.201,.14))
        with self.assertRaises(ValueError):self.execute(lambda *a:self.fail('changed resume callback'),reference=changed)

    def test_unresolved_crash_boundary_never_auto_retries(self):
        def callback(*args):raise SystemExit('SYNTHETIC_UNIT_CRASH')
        with self.assertRaises(SystemExit):self.execute(callback)
        self.assertEqual(len(read_json(self.path/'pilot_state.json')['reservations']),1)
        with self.assertRaises(ValueError):self.execute(lambda *a:self.fail('crash was retried'))

    def test_changed_receipt_refuses_completed_resume(self):
        report=self.execute(lambda *args:envelope())
        receipt=self.path/report['records'][0]['receipt']
        receipt.write_text('{}',encoding='utf-8')
        with self.assertRaises(ValueError):self.execute(lambda *a:self.fail('tampered resume callback'))

    def test_phase_boundaries_resume_without_changing_plan_or_selecting_finalist(self):
        def callback(*args):
            self.calls.append(args[1]);n=len(self.calls)
            return envelope((.21+n*.001,.14+n*.002))
        first=self.execute(callback,stop_after='sensitivity')
        self.assertEqual(first['status'],'PHASE_COMPLETE');self.assertEqual(first['proposal_count'],8)
        self.assertEqual(first['shortlist'],[])
        self.assertEqual(self.execute(lambda *a:self.fail('repeated phase callback'),stop_after='sensitivity'),first)
        second=self.execute(callback,stop_after='random')
        self.assertEqual(second['proposal_count'],14);self.assertEqual(second['status'],'PHASE_COMPLETE')
        with self.assertRaises(ValueError):self.execute(callback,stop_after='sensitivity')
        final=self.execute(callback,stop_after='tpe')
        self.assertEqual(final['proposal_count'],18);self.assertEqual(final['status'],'SHORTLIST_READY')


if __name__=='__main__':unittest.main()
