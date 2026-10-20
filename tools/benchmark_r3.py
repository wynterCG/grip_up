"""R3 certification first, immutable primary source second; one engine worker."""
from pathlib import Path
import argparse
import copy
import json
import shutil
import subprocess
import sys

ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/'tools'),str(ROOT/'tools/auto_tuning/benchmark_qualification'),str(ROOT/'tools/auto_tuning')]
from common import DEST,ENGINE,read_json,atomic_json,source_hashes,file_hash,digest,engine_identity,git_identity,utc_now,StudyLock
import campaign
import benchmark_preflight
from comparison import compare_required
DOC=ROOT/'docs/validation/auto_tuning/benchmark_v133_r3'
BASE=ROOT/'builds/eval_virtual_cursor/benchmark_v133_r3'
PRIMARY=BASE/'primary/benchmark_v133_r3'
HELPERS=['tools/benchmark_r3.py','tools/benchmark_preflight.py','tools/benchmark_safety.py','tools/project.py','tools/run_contextual_vault.py']

def helper_hashes():return {p:file_hash(ROOT/p) for p in HELPERS}
def snapshot_hash(source):return digest({'source_hashes':source['source_hashes'],'helper_hashes':source['helper_hashes']})
def guard(source):
    if source_hashes()!=source['source_hashes'] or source_hashes(DEST)!=source['source_hashes']:raise ValueError('SOURCE_BYTES_CHANGED')
    if helper_hashes()!=source['helper_hashes']:raise ValueError('EXECUTION_HELPER_CHANGED')
    if engine_identity()!=source['engine_identity']:raise ValueError('ENGINE_CHANGED')
    for hz,tape in source['tapes'].items():
        if file_hash(Path(tape['path']))!=tape['sha256']:raise ValueError('ORIGINAL_TAPE_CHANGED:'+hz)
    return source

def initialize():
    assert not (BASE/'baseline_manifest.json').exists()
    old=ROOT/'docs/validation/auto_tuning/benchmark_v133'
    previous=read_json(old/'baseline_manifest.json')
    paths=subprocess.check_output(['git','ls-files','docs/validation'],cwd=DEST,text=True).splitlines()
    baseline={'baseline_commit':git_identity()['repository_commit'],'engine':engine_identity(),
              'baseline_source_hashes':source_hashes(DEST),'protected_external':previous['protected_external'],
              'historical_tracked_evidence':{p:file_hash(DEST/p) for p in paths if (DEST/p).is_file()},
              'historical_raw_evidence':{p.relative_to(ROOT).as_posix():file_hash(p) for name in ['requal_20261020_r1','projection_v132b_r1','projection_v132b_r2','benchmark_v133_r1','benchmark_v133_r2','benchmark_v133_headless_init_r1','benchmark_v133_headless_init_r2'] for p in (ROOT/'builds/eval_virtual_cursor'/name).rglob('*') if p.is_file()}}
    atomic_json(BASE/'baseline_manifest.json',baseline);atomic_json(DOC/'baseline_manifest.json',baseline)
    plan=read_json(old/'run_plan.json')
    plan.update(id='benchmark_v133_r3',frozen_before_qualification_utc=utc_now(),
        authorization='GRIP_UP_Benchmark_Preflight_Certification_R3_Spec_v1_3_3_EN.md',
        preflight_budget={'source_candidates':3,'physical_replays_total':12,'per_candidate_physical':4,'additional_pure_repairs_per_candidate':2},
        separate_regression_processes=34,
        negative_control_plan=['wrong_actual_backing_before_world','corrupt_tape_hash_before_world','mutated_source_before_world','duplicate_missing_out_of_order_input_pure','pending_canceled_grip_zero_traction','invalid_support_not_proximity','abort_held_cleanup','observer_probe_OFF_control'],
        negative_policy='Pure transport contracts cover preworld invalid paths separately. Physical controls run only after prerequisites and remaining budget; any hard stop leaves later controls NOT_RUN. No slot transfer.',
        capture_policy_note='Original72 allocation retained, including12adaptive captures;four required domains n3pairs/Hz; foot and stop n1 remain explicitly diagnostic/excluded. No extra captures outside72.')
    atomic_json(DOC/'run_plan.json',plan)
    atomic_json(BASE/'budget_ledgers.json',{'preflight':{'limit':12,'physical_attempted':0,'candidates':[]},'primary':{'limit':96,'attempted':0,'status':'NOT_STARTED_UNCERTIFIED'},'regression':{'required':34,'completed':0,'separate':True}})
    print('R3 baseline and three independent prospective ledgers preserved')

def launch(directory,command,timeout=30):
    atomic_json(directory/'execution.json',{'command':[str(c) for c in command],'utc':utc_now(),'workers':1})
    with (directory/'stdout.txt').open('wb') as out,(directory/'stderr.txt').open('wb') as err:
        p=subprocess.Popen([str(c) for c in command],cwd=ROOT,stdout=out,stderr=err)
        try:code=p.wait(timeout=timeout)
        except subprocess.TimeoutExpired:p.kill();p.wait();code=124
    return code

def transport(candidate,source):
    target=candidate/'transport';target.mkdir(exist_ok=False)
    plan=read_json(DOC/'run_plan.json');cases=[]
    def add(label,config,accept,reason=None,synthetic=None,mutation=None):
        directory=target/label;directory.mkdir()
        m,_=campaign.build_manifest('swing_catch_train',120,'headless',label,directory,'reference',source,plan,Path(source['tapes']['120']['path']))
        m['projection_config']=copy.deepcopy(config)
        if mutation=='source':m['expected_source_hashes']['project.godot']='0'*64
        if mutation=='tape':m['virtual_tape_sha256']='0'*64
        atomic_json(directory/'manifest.json',m);atomic_json(directory/'serialized_projection_config.json',config)
        case={'id':label,'manifest':str(directory/'manifest.json'),'accept':accept}
        if reason:case['expected_reason']=reason
        if synthetic:case['synthetic']=synthetic
        if mutation:case['full_start']=True
        cases.append(case)
    base={'window_size':[1024,576],'logical_viewport_size':[1920,1080],'probe_enabled':True}
    for field,expected in [('window_size',[1024,576]),('logical_viewport_size',[1920,1080])]:
        for kind,value,valid in [('int',expected,True),('float',[float(v) for v in expected],True),('mixed',[expected[0],float(expected[1])],True),('fraction',[expected[0]+.125,expected[1]],False),('string',[str(expected[0]),expected[1]],False),('bool',[True,expected[1]],False),('null',[None,expected[1]],False),('short',[expected[0]],False),('long',expected+[1],False),('swap',expected[::-1],False),('zero',[0,expected[1]],False),('negative',[-1,expected[1]],False),('bounds',[16385,expected[1]],False),('object',{'x':expected[0],'y':expected[1]},False),('nested',[[expected[0]],expected[1]],False)]:
            c=copy.deepcopy(base);c[field]=value;add(field+'_'+kind,c,valid)
        c=copy.deepcopy(base);del c[field];add(field+'_missing',c,False)
        for special in ['NAN','INF']:add(field+'_'+special,base,False,synthetic={'field':field,'special':special})
    add('missing_projection',None,False)
    c=copy.deepcopy(base);c['probe_enabled']='true';add('probe_not_boolean',c,False)
    add('changed_source',base,False,'SOURCE_HASH_MISMATCH:',mutation='source')
    add('corrupt_tape',base,False,'TAPE_HASH',mutation='tape')
    add('wrong_actual_viewport',base,False,'ENVIRONMENT_NOT_COMPARABLE:LOGICAL_VIEWPORT')
    cases[-1]['wrong_actual_viewport']=True
    atomic_json(target/'suite.json',{'cases':cases,'tape':source['tapes']['120']['path']})
    command=[ENGINE,'--headless','--path',ROOT,'--script','res://features/evaluator_virtual_cursor/tests/test_r3_transport.gd','--','--virtual-cursor-evaluator','--benchmark-qualification','--backing-size','1024x576','--suite',target/'suite.json','--output',target/'schema_results.json']
    code=launch(target,command)
    result=read_json(target/'schema_results.json') if (target/'schema_results.json').exists() else {}
    passed=code==0 and result.get('status')=='CONTRACT_PASS'
    atomic_json(target/'admission_receipt.json',{'pass':passed,'exit_code':code,'source_snapshot_sha256':snapshot_hash(source),'case_count':len(cases),'result':result})
    print('PC0 transport',passed,result.get('checks'),flush=True)
    return passed

def environment(candidate,source):
    target=candidate/'environment';target.mkdir(exist_ok=False);rows=[]
    cases=[(hz,mode,'1024x576','1024x576',True) for hz in [120,60] for mode in ['headless','rendered_scripted']]
    cases += [(120,'rendered_scripted','1440x810','1024x576',False),(120,'headless','1440x810','1440x810',False)]
    for hz,mode,resolution,declared,positive in cases:
        d=target/f'{mode}_{hz}_{"positive" if positive else "wrong_size"}';d.mkdir()
        m,_=campaign.build_manifest('swing_catch_train',hz,mode,d.name,d,'reference',source,read_json(DOC/'run_plan.json'),Path(source['tapes'][str(hz)]['path']))
        atomic_json(d/'manifest.json',m);atomic_json(d/'serialized_projection_config.json',m['projection_config'])
        flags=['--headless','--fixed-fps','120'] if mode=='headless' else ['--screen','0','--position','80,80']
        command=[ENGINE,*flags,'--resolution',resolution,'--path',ROOT,'--script','res://features/evaluator_virtual_cursor/scripts/benchmark_preflight.gd','--','--benchmark-qualification','--manifest',d/'manifest.json','--backing-size',declared,'--hz',str(hz),'--output',d/'result.json']
        code=launch(d,command);r=read_json(d/'result.json')
        ok=r['status']==('PREFLIGHT_PASS' if positive else 'ENVIRONMENT_NOT_COMPARABLE') and code==(0 if positive else 1) and r['gameplay_bodies_created']==0
        if positive:ok=ok and r['actual_size']==[1024,576] and r['clock_samples'][-2:]==[1/hz]*2
        else:ok=ok and not r['backing_initialization']['explicit_headless_initialization']
        rows.append({'hz':hz,'mode':mode,'positive':positive,'pass':ok,'exit_code':code,'directory':str(d),'result':r})
        atomic_json(target/'results.json',{'pass':all(x['pass'] for x in rows),'runs':rows,'gameplay_worlds':0})
        print('PC1',hz,mode,positive,ok,flush=True)
        guard(source)
        if not ok:return False
    d=target/'wrong_opt_in';d.mkdir()
    m,_=campaign.build_manifest('swing_catch_train',120,'headless',d.name,d,'reference',source,read_json(DOC/'run_plan.json'),Path(source['tapes']['120']['path']))
    atomic_json(d/'manifest.json',m)
    code=launch(d,[ENGINE,'--headless','--path',ROOT,'--script',campaign.ENTRY,'--','--virtual-cursor-evaluator','--backing-size','1024x576','--manifest',d/'manifest.json','--result',d/'result.json'])
    r=read_json(d/'result.json');ok=code==1 and r['reason']=='BENCHMARK_FLAG_CAMPAIGN_REQUIRED' and r['world_creation_record']=={}
    rows.append({'case':'wrong_opt_in','pass':ok,'directory':str(d),'result':r})
    atomic_json(target/'results.json',{'pass':all(x['pass'] for x in rows),'runs':rows,'gameplay_worlds':0})
    if not ok:return False
    return True

def candidate_run(number):
    ledger=read_json(BASE/'budget_ledgers.json')
    assert 1<=number<=3 and len(ledger['preflight']['candidates'])<3
    candidate=BASE/f'candidate_preflight/benchmark_v133_r3_candidate_{number:03}'
    candidate.mkdir(parents=True,exist_ok=False)
    source={**git_identity(),'source_hashes':source_hashes(),'helper_hashes':helper_hashes(),'engine_identity':engine_identity(),
            'tapes':read_json(DOC/'run_plan.json')['reference_tapes'],'budget_ledger':'PREFLIGHT_CERTIFICATION',
            'dirty_tree_policy':'Candidate is uncommitted evaluation-only source; exact C/E bytes and helper hashes fixed per candidate. Artifacts excluded from source map.'}
    assert source['source_hashes']==source_hashes(DEST)
    source['source_snapshot_sha256']=snapshot_hash(source)
    atomic_json(candidate/'source_identity.json',source)
    ledger['preflight']['candidates'].append({'candidate':number,'path':str(candidate),'source_snapshot_sha256':snapshot_hash(source),'status':'RUNNING','pure_base_plan':{'transport_processes':1,'environment_processes':7,'additional_repair_diagnostics_limit':2}})
    atomic_json(BASE/'budget_ledgers.json',ledger)
    campaign.BASE=candidate;campaign.DOC=DOC;campaign.identity=lambda:guard(source)
    rows=[];pairs=[];status='PREFLIGHT_NOT_CERTIFIED';reason=''
    with StudyLock(ROOT/'builds/eval_virtual_cursor'):
        if not transport(candidate,source):reason='PC0_TRANSPORT_FAILED'
        elif not environment(candidate,source):reason='PC1_ENVIRONMENT_FAILED'
        else:
            for hz in [120,60]:
                for mode in ['headless','rendered_scripted']:
                    assert len(rows)<4 and ledger['preflight']['physical_attempted']<12
                    ledger['preflight']['physical_attempted']+=1;atomic_json(BASE/'budget_ledgers.json',ledger)
                    r=campaign.execute('swing_catch_train',hz,mode,1,'reference',Path(source['tapes'][str(hz)]['path']))
                    rows.append(r);atomic_json(candidate/'replay_matrix.json',{'runs':rows,'pairs':pairs,'status':'RUNNING'})
                    if r['status']!='RUN_VALID':reason='PC2_'+r['reason'];break
                if reason:break
                pair=compare_required(rows[-2]['directory'],rows[-1]['directory']);atomic_json(candidate/f'replay_comparison_{hz}.json',pair)
                pairs.append({'hz':hz,'status':pair['status'],'first_difference':pair.get('first_difference')})
                if pair['status']!='STRICT_MATCH':reason='PC2_STRICT_PAIR_'+str(hz);break
            if not reason and len(rows)==4 and len(pairs)==2:status='CERTIFICATION_READY_FOR_REVIEW'
    try:guard(source)
    except ValueError as error:status='PREFLIGHT_NOT_CERTIFIED';reason=reason+';IDENTITY:'+str(error)
    result={'status':status,'reason':reason,'candidate':number,'source_snapshot_sha256':snapshot_hash(source),'runs':rows,'pairs':pairs,'physical_processes':len(rows),'primary_processes':0}
    atomic_json(candidate/'results.json',result);atomic_json(DOC/'preflight_hz_mode_matrix.json',result)
    ledger['preflight']['candidates'][-1]['status']=status;atomic_json(BASE/'budget_ledgers.json',ledger)
    print(status,reason,flush=True)

def certify(number):
    candidate=BASE/f'candidate_preflight/benchmark_v133_r3_candidate_{number:03}'
    source=guard(read_json(candidate/'source_identity.json'));result=read_json(candidate/'results.json')
    assert result['status']=='CERTIFICATION_READY_FOR_REVIEW'
    for role in ['physics','measurement']:
        r=read_json(DOC/f'specialist/{role}_signoff.json')
        assert r['status']=='APPROVED_FOR_PRIMARY' and r['source_snapshot_sha256']==snapshot_hash(source)
    current=git_identity();assert not current['repository_dirty'],'Commit identical certified bytes after preflight and reviews'
    assert not (BASE/'certified_source.json').exists()
    frozen={**source,**current,'budget_ledger':'PRIMARY_QUALIFICATION','dirty_tree_policy':'Exact certified source/helpers immutable; generated artifacts allowed; no source edits.'}
    certificate={'campaign':'benchmark_v133_r3','preflight_status':'CERTIFIED','source_hash':snapshot_hash(source),'source_hashes':source['source_hashes'],'helper_hashes':source['helper_hashes'],'engine_hash':source['engine_identity']['sha256'],'engine_identity':source['engine_identity'],'measurement_commit':current['repository_commit'],'candidate':number,'actual_backing':[1024,576],'logical_viewport':[1920,1080],'supported_frequencies':[60,120],'supported_lanes':['V0_HEADLESS','V0_RENDERED_SCRIPTED'],'real_json_roundtrip':True,'strict_catch_pairs':{str(p['hz']):p['status'] for p in result['pairs']},'preflight_physics_processes':len(result['runs']),'primary_processes_consumed':0,'optimization_permitted':False}
    atomic_json(BASE/'certified_source.json',certificate);atomic_json(DOC/'certified_source.json',certificate)
    atomic_json(PRIMARY/'source_identity.json',frozen)
    print('PREFLIGHT_CERTIFIED',snapshot_hash(source),flush=True)

def primary(stage):
    certificate=read_json(BASE/'certified_source.json');source=guard(read_json(PRIMARY/'source_identity.json'))
    assert snapshot_hash(source)==certificate['source_hash']
    campaign.BASE=PRIMARY;campaign.DOC=DOC;campaign.identity=lambda:guard(source)
    if stage=='preflight':
        benchmark_preflight.BASE=PRIMARY;return benchmark_preflight.main('benchmark_v133_r3')
    if stage=='domains':
        for label in ['benchmark_reference','benchmark_live_reference']:
            r=read_json(DOC/label/'attempt_001/results.json');assert all(x['passed'] for x in r['runs'])
    return campaign.run_stage(stage)

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('stage',choices=['initialize','candidate','certify','preflight','reference','domains']);p.add_argument('--candidate',type=int,default=1);a=p.parse_args()
    if a.stage=='initialize':initialize()
    elif a.stage=='candidate':candidate_run(a.candidate)
    elif a.stage=='certify':certify(a.candidate)
    else:raise SystemExit(primary(a.stage))
