"""Pure synthetic orchestration checks; no engine or withheld data access."""
import copy
from pathlib import Path
import sys
import tempfile
import unittest
from types import SimpleNamespace
from unittest import mock

ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'tools/auto_tuning'),str(ROOT/'tools/auto_tuning/minimal_v135')]
from minimal_v135 import deterministic_campaign as dc
from minimal_v135.search import ProposalStudy
from candidate_schema import parameter_resource
from test_search import envelope,quality
from common import digest
from common import atomic_json,read_json,file_hash


def evidence():
    result={'by_hz':{}}
    rules={'by_hz':{}}
    for hz in dc.FREQUENCIES:
        result['by_hz'][str(hz)]=envelope();result['by_hz'][str(hz)]['physics_hz']=hz
        rules['by_hz'][str(hz)]=quality()
    return result,rules


class FourCellScores(unittest.TestCase):
    def test_both_frequencies_required_and_nulls_preserved(self):
        base,rules=evidence();changed=copy.deepcopy(base)
        self.assertTrue(dc.score_all(changed,base,rules)['eligible'])
        del changed['by_hz']['60']
        score=dc.score_all(changed,base,rules)
        self.assertEqual(score['disposition'],'STOP_STUDY');self.assertIsNone(score['values'])

    def test_worst_hz_objectives_and_practical_each_hz(self):
        base,rules=evidence();changed=copy.deepcopy(base)
        for hz,value in [('120',.23),('60',.215)]:
            changed['by_hz'][hz]['scenarios'][dc.TRAIN[0]]['metrics']['signed_progress_m']['value']=value
        s=dc.score_all(changed,base,rules)
        self.assertTrue(s['eligible']);self.assertTrue(s['practical_gain'])
        self.assertEqual(s['values'],[.215,.14]);self.assertEqual(len(s['per_task']),4)
        changed['by_hz']['60']['scenarios'][dc.TRAIN[0]]['metrics']['signed_progress_m']['value']=.20
        self.assertFalse(dc.score_all(changed,base,rules)['practical_gain'])

    def test_120_gain_cannot_hide_60_task_failure_or_regression(self):
        for invalid in [False,True]:
            base,rules=evidence();changed=copy.deepcopy(base)
            c=changed['by_hz']['60']['scenarios'][dc.TRAIN[1]]
            if invalid:
                c['task_succeeded']=False;c['observation']['status']='INTERRUPTED'
                c['metrics']['signed_progress_m'].update(status='INTERRUPTED',value=None,reason_code='GROUND')
            else:c['metrics']['signed_progress_m']['value']=.10
            s=dc.score_all(changed,base,rules)
            self.assertEqual(s['disposition'],'REJECT_CANDIDATE');self.assertIsNone(s['values'])

    def test_invalid_metric_hard_stop_and_reasoned_null_not_zero(self):
        base,rules=evidence();changed=copy.deepcopy(base)
        c=changed['by_hz']['60']['scenarios'][dc.TRAIN[0]]
        c['metrics']['signed_progress_m'].update(status='INVALID_MEASUREMENT',value=None)
        self.assertEqual(dc.score_all(changed,base,rules)['disposition'],'STOP_STUDY')
        changed=copy.deepcopy(base)
        c=changed['by_hz']['60']['scenarios'][dc.TRAIN[0]]
        c['metrics']['latency_to_useful_motion_s']['value']=0.
        self.assertEqual(dc.score_all(changed,base,rules)['disposition'],'STOP_STUDY')

    def test_frequency_specific_latency_rule(self):
        base,rules=evidence();changed=copy.deepcopy(base)
        for hz in ['120','60']:
            b=base['by_hz'][hz]['scenarios'][dc.TRAIN[0]]['metrics']['latency_to_useful_motion_s']
            c=changed['by_hz'][hz]['scenarios'][dc.TRAIN[0]]['metrics']['latency_to_useful_motion_s']
            b.update(status='MEASURED',value=.05);c.update(status='MEASURED',value=.075)
            rules['by_hz'][hz]['tasks'][dc.TRAIN[0]]['latency_to_useful_motion_s']['max_worsening']=2/int(hz)
        s=dc.score_all(changed,base,rules)
        self.assertFalse(s['eligible'])
        self.assertFalse(s['per_frequency']['120']['eligible'])
        self.assertTrue(s['per_frequency']['60']['eligible'])


class BudgetsAndIdentity(unittest.TestCase):
    def test_five_four_cell_plus_twenty_confirmation_max40_nonrefundable(self):
        rows=[]
        for i in range(5):
            r=dc.reserve(rows,str(i));self.assertEqual(len(r['cells']),4)
        with self.assertRaises(ValueError):dc.reserve(rows,'sixth')
        dc.reserve(rows,'confirmation',confirmation=True)
        self.assertEqual(sum(r['processes'] for r in rows),40)
        with self.assertRaises(ValueError):dc.reserve(rows,'second_confirmation',confirmation=True)
        self.assertEqual(len(rows),6)
        with self.assertRaises(ValueError):dc.reserve(rows,'0')

    def test_additive_study_plan_and_resume_identity(self):
        registry=parameter_resource();identity={'seed':42,'campaign_id':'synthetic_v135a'}
        q={'decision':'GO_MINIMAL_BENCHMARK','identity_sha256':digest(identity)}
        from minimal_v135.search import sensitivity_proposals
        queue=[sensitivity_proposals(registry)[i] for i in dc.SENSITIVITY_INDICES]
        with tempfile.TemporaryDirectory() as td:
            new=ProposalStudy(Path(td),identity,registry,q,plan=dc.PLAN,sensitivity_queue=queue)
            old=ProposalStudy(Path(td),identity,registry,q)
            self.assertNotEqual(new.guard,old.guard)
            different={**identity,'python_environment':{'sha256':'foreign'}}
            other=ProposalStudy(Path(td),different,registry,{'decision':'GO_MINIMAL_BENCHMARK','identity_sha256':digest(different)},plan=dc.PLAN,sensitivity_queue=queue)
            self.assertNotEqual(new.guard,other.guard)
            self.assertEqual(new.plan,{'sensitivity':4,'random':1,'tpe':0})
            self.assertEqual(len(queue),4)
            self.assertEqual(len({next(k for k in p['parameter_overrides'] if p['parameter_overrides'][k]!=dc.baseline(registry)[k]) for p in queue}),4)

    def test_environment_delegates_exact_expected_fingerprint(self):
        expected={'sha256':'expected'}
        with mock.patch('metric_binary64.require_environment',return_value=expected) as check:
            self.assertEqual(dc.require_environment(expected),expected)
            check.assert_called_once_with(expected)
        with mock.patch('metric_binary64.require_environment',side_effect=ValueError('ENV_CHANGED')):
            with self.assertRaisesRegex(ValueError,'ENV_CHANGED'):dc.require_environment(expected)

    def test_immutable_artifacts_and_no_legacy_writes(self):
        with tempfile.TemporaryDirectory() as td:
            p=Path(td)/'new.json';dc.immutable(p,{'a':1})
            with self.assertRaises(FileExistsError):dc.immutable(p,{'a':2})

    def test_real_tape_admission_confirmation_phase_and_changed_bytes(self):
        import minimal_benchmark as app
        with tempfile.TemporaryDirectory() as td:
            base=Path(td);p=base/'tapes'/f'{dc.TRAIN[0]}_120.json'
            frames=[{'tape_sha256':'CAPTURE_SOURCE_IDENTITY','synthetic':True}];content=digest(frames)
            frames[0]['tape_sha256']=content
            tape={'benchmark':'benchmark_minimal_v135_r1','scenario_id':dc.TRAIN[0],
                'scenario_catalog_sha256':file_hash(app.CAT),'source_hashes':{'old':'hash'},
                'physics_hz':120,'engine_identity':{'synthetic':True},'camera_mode':'V0_PHYSICS_FOLLOW',
                'frames':frames,'tape_content_sha256':content}
            atomic_json(p,tape)
            plan={'historical_training_tapes':{f'{dc.TRAIN[0]}:120':{'path':str(p),
                'sha256':file_hash(p),'source_map_sha256':digest(tape['source_hashes'])}}}
            atomic_json(base/'run_plan.json',plan)
            with mock.patch.multiple(app,B=base,D=base,CAMPAIGN=dc.CAMPAIGN,current_phase='confirmation'):
                self.assertEqual(app.tape_check(p,120,{'engine_identity':{'synthetic':True}},dc.TRAIN[0]),tape)
                tape['frames'][0]['synthetic']=False;atomic_json(p,tape)
                with self.assertRaisesRegex(ValueError,'HISTORICAL_TRAINING_TAPE_IDENTITY'):
                    app.tape_check(p,120,{'engine_identity':{'synthetic':True}},dc.TRAIN[0])


class PurePipeline(unittest.TestCase):
    """Actual SQLite, synthetic callback: validates orchestration, not physics."""
    def app(self,directory,*,fail_first=False):
        b=Path(directory)/'raw';d=Path(directory)/'docs';b.mkdir();d.mkdir()
        ref,rules=evidence()
        atomic_json(b/'optimizer_reference.json',ref);atomic_json(d/'quality_contract.json',rules)
        atomic_json(d/'run_plan.json',{'synthetic':True})
        for hz in dc.FREQUENCIES:
            for scenario in dc.TRAIN:
                atomic_json(b/'tapes'/f'{scenario}_{hz}.json',{'synthetic':True})
        source={'snapshot_sha256':'synthetic_source','python_environment':{'sha256':'synthetic_environment'},'metric_reducer_sha256':'synthetic_reducer'}
        app=SimpleNamespace(B=b,D=d,guard=lambda:source,calls=[])
        def one(scenario,hz,mode,group,tape,*,values,phase):
            n=len(app.calls)+1;p=b/'attempts'/str(n);p.mkdir(parents=True)
            m={'budget_group':group,'source_snapshot_sha256':source['snapshot_sha256'],
                'python_environment':source['python_environment'],
                'baseline_candidate':{'parameter_overrides':copy.deepcopy(values)},'virtual_tape_sha256':file_hash(tape)}
            atomic_json(p/'manifest.json',m)
            summary=envelope((.23,.16))['scenarios'][scenario]
            r={'run_id':str(n),'directory':str(p),'hz':hz,'scenario_id':scenario,'mode':mode,
                'status':'RUN_INVALID' if fail_first else 'RUN_VALID','metrics':summary,
                'engine_result':{'restoration':{'resources':{'exact_originals_and_pointer_restore':True}},'scenarios':[{'invariants':{}}]}}
            atomic_json(p/'receipt.json',r);app.calls.append(r);return r
        app.one=one
        app.valid_task=lambda r:r['status']=='RUN_VALID' and r['metrics']['task_succeeded']
        app.compare=lambda a,b,label:{'id':label,'status':'STRICT_MATCH'}
        return app,source

    def test_five_proposals_plus_one_n3_confirmation_max40_with_sqlite(self):
        with tempfile.TemporaryDirectory() as td:
            app,source=self.app(td)
            with mock.patch.object(dc,'verify_gate',return_value=source),mock.patch.object(dc,'require_environment',return_value=source['python_environment']):
                result=dc.search(app)
            self.assertEqual(result['proposal_count'],5)
            self.assertEqual(result['actual_optimizer_processes'],40)
            self.assertEqual(result['process_launches_reserved'],40)
            self.assertEqual(len(result['shortlist']),1)
            confirmation=read_json(app.B/'optimizer/confirmation/result.json')
            self.assertTrue(confirmation['passed']);self.assertEqual(len(confirmation['runs']),24)
            self.assertEqual(len(confirmation['pairs']),28)
            with mock.patch.object(dc,'verify_gate',return_value=source),mock.patch.object(dc,'require_environment',return_value=source['python_environment']):
                with self.assertRaisesRegex(ValueError,'TERMINAL'):dc.search(app,resume=True)

    def test_invalid_callback_stops_before_second_cell_and_no_shortlist(self):
        with tempfile.TemporaryDirectory() as td:
            app,source=self.app(td,fail_first=True)
            with mock.patch.object(dc,'verify_gate',return_value=source),mock.patch.object(dc,'require_environment',return_value=source['python_environment']):
                result=dc.search(app)
            self.assertEqual(result['status'],'OPTIMIZATION_NO_GO');self.assertTrue(result['global_stop'])
            self.assertEqual(result['proposal_count'],1);self.assertEqual(len(app.calls),1)
            self.assertEqual(result['process_launches_reserved'],4);self.assertEqual(result['shortlist'],[])


if __name__=='__main__':unittest.main()
