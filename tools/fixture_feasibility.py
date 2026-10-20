"""Bounded v134 laboratory; never resumes R3 or exposes a tuning score."""
import argparse
import copy
import json
from pathlib import Path
import sys
import uuid

sys.path.insert(0, str(Path(__file__).resolve().parent))
import benchmark_r3 as old
from fixture_prerequisites import diagnose

ROOT, DEST = old.ROOT, old.DEST
B = ROOT/'builds/eval_virtual_cursor/fixture_feasibility_v134_r1'
D = ROOT/'docs/validation/auto_tuning/fixture_repair_v134'
CAT = ROOT/'features/evaluator_virtual_cursor/resources/fixture_feasibility_v134.json'
HELPERS = ['tools/fixture_feasibility.py','tools/fixture_prerequisites.py',
           'tools/project.py','tools/run_contextual_vault.py','tools/benchmark_safety.py']
c = old.campaign
original_factory = c.build_manifest
original_tape_check = c.tape_check
phase = ''


def identity():
    source = old.read_json(B/'active_source.json')
    if old.source_hashes()!=source['source_hashes'] or old.source_hashes(DEST)!=source['source_hashes']:raise ValueError('MEASURED_SOURCE_CHANGED')
    if {p:old.file_hash(ROOT/p) for p in HELPERS}!=source['helper_hashes']:raise ValueError('MEASURED_HELPER_CHANGED')
    if old.engine_identity()!=source['engine_identity']:raise ValueError('ENGINE_CHANGED')
    if old.file_hash(D/'run_plan.json')!=source['run_plan_sha256']:raise ValueError('RUN_PLAN_CHANGED')
    for value in source['reference_tapes'].values():
        if old.file_hash(Path(value['path']))!=value['sha256']:raise ValueError('ORIGINAL_REFERENCE_TAPE_CHANGED')
    return source


def tape_check(path,hz,source,scenario,negative=False):
    if scenario=='swing_catch_train':return original_tape_check(path,hz,source,scenario,negative)
    tape=old.read_json(path)
    if tape['benchmark']!='fixture_feasibility_v134' or tape['scenario_id']!=scenario:raise ValueError('FIXTURE_TAPE_IDENTITY')
    if tape['scenario_catalog_sha256']!=old.file_hash(CAT) or tape['source_hashes']!=source['source_hashes']:raise ValueError('FIXTURE_TAPE_SOURCE_CATALOG')
    if tape['physics_hz']!=hz or tape['engine_identity']!=source['engine_identity'] or tape['camera_mode']!='V0_PHYSICS_FOLLOW':raise ValueError('FIXTURE_TAPE_ENVIRONMENT')
    if tape.get('diagnostic_only') and not negative:raise ValueError('INVALID_ONSET_TAPE_NOT_REPLAYED')
    frames=copy.deepcopy(tape['frames'])
    for f in frames:f['tape_sha256']='CAPTURE_SOURCE_IDENTITY'
    if old.digest(frames)!=tape['tape_content_sha256'] or any(f['tape_sha256']!=tape['tape_content_sha256'] for f in tape['frames']):raise ValueError('TAPE_CONTENT_HASH')
    return tape


def build_manifest(*args,**kwargs):
    m,tape=original_factory(*args,**kwargs)
    m.update(benchmark='fixture_feasibility_v134',pick_contract_version='1.3.4',
             fixture_catalog_sha256=old.file_hash(CAT),feasibility_phase=phase,score_eligible=False)
    return m,tape


def configure():
    c.BASE=B;c.DOC=D;c.CATALOG=CAT;c.ENTRY='res://features/evaluator_virtual_cursor/scripts/feasibility_runner.gd'
    c.identity=identity;c.tape_check=tape_check;c.build_manifest=build_manifest


def register(label,final=False):
    path=B/'sources'/label/'source_identity.json'
    if path.exists():raise FileExistsError(path)
    source={'source_hashes':old.source_hashes(), 'helper_hashes':{p:old.file_hash(ROOT/p) for p in HELPERS},
        **old.git_identity(), 'engine_identity':old.engine_identity(), 'dirty_tree_policy':'Exact source/helper byte map frozen per candidate; generated evidence permitted',
        'budget_ledger':'V134_DEVELOPMENT' if not final else 'V134_FINAL_PILOT', 'label':label,
        'catalog_sha256':old.file_hash(CAT), 'final':final}
    source['run_plan_sha256']=old.file_hash(D/'run_plan.json')
    source['reference_tapes']=old.read_json(D/'run_plan.json')['reference_tapes']
    assert source['source_hashes']==old.source_hashes(DEST)
    source['snapshot_sha256']=old.digest({'source_hashes':source['source_hashes'],'helper_hashes':source['helper_hashes']})
    old.atomic_json(path,source);old.atomic_json(B/'active_source.json',source)
    import virtual_cursor_report as ar
    ar.DOC=D
    index={};ar.source_archive(label,source['repository_commit'],{**source['source_hashes'],**source['helper_hashes']},index)
    old.atomic_json(B/'sources'/label/'archive_receipt.json',index)
    print('REGISTERED',label,source['snapshot_sha256'])


def execute(scenario,hz,mode,stage,tape=None,negative=''):
    global phase
    phase=stage
    prior=[old.read_json(p) for p in (B/'attempts').glob('*/manifest.json')]
    limits={'development':8,'capture':12,'replay':24,'reference':4,'negative':2,'reserve':6}
    count=sum(x.get('feasibility_phase')==stage for x in prior)
    if count>=limits[stage]:raise ValueError('V134_PHASE_BUDGET_EXHAUSTED')
    final=sum(x.get('feasibility_phase')!='development' for x in prior)
    if stage!='development' and final>=48:raise ValueError('V134_FINAL_BUDGET_EXHAUSTED')
    configure()
    group='reference' if stage=='reference' else 'negative' if stage=='negative' else 'domain'
    row=c.execute(scenario,hz,mode,count+1,group,tape,negative=negative)
    row.update(feasibility_phase=stage,score_eligible=False,source_snapshot=identity()['snapshot_sha256'])
    old.atomic_json(Path(row['directory'])/'feasibility_receipt.json',row)
    if scenario!='swing_catch_train' and (Path(row['directory'])/'benchmark_audit.json').exists():
        definition=next(d for d in old.read_json(CAT)['scenarios'] if d['id']==scenario)
        timeline,funnel=diagnose(old.read_json(Path(row['directory'])/'benchmark_audit.json')['ticks'],definition,
            row['engine_result']['scenarios'][0]['onset_certificate'],row['metrics'].get('observation'),
            {'source_hash':row['source_snapshot'],'tape_hash':row['tape_sha256'],
             'actual_backing_size':row['engine_result']['projection_setup']['actual_size']})
        funnel.update(phase_scope='QUIET_PREPARATION_PREDICATES; final onset certificate remains authoritative',observation=row['metrics'].get('observation'),scenario=scenario)
        old.atomic_json(Path(row['directory'])/'prerequisite_funnel.json',funnel)
        with (Path(row['directory'])/'prerequisites.jsonl').open('w',encoding='utf-8') as f:
            for item in timeline:f.write(json.dumps(item,separators=(',',':'),allow_nan=False)+'\n')
    update_ledger()
    return row


def update_ledger():
    manifests=[old.read_json(p) for p in (B/'attempts').glob('*/manifest.json')]
    ledger=old.read_json(B/'budget_ledgers.json')
    ledger['development']['attempted']=sum(x.get('feasibility_phase')=='development' for x in manifests)
    ledger['final']['attempted']=sum(x.get('feasibility_phase')!='development' for x in manifests)
    ledger['final']['groups']={name:sum(x.get('feasibility_phase')==name for x in manifests) for name in ['capture','replay','reference','negative','reserve']}
    old.atomic_json(B/'budget_ledgers.json',ledger)


def original_tape(hz):
    return ROOT/f'builds/eval_virtual_cursor/requal_20261020_r1/capture/tapes/catch_{hz}.json'


def n1_tape(hz):
    path=B/'negative_tapes'/f'N1_{hz}.json'
    if path.exists():return path
    tape=copy.deepcopy(old.read_json(original_tape(hz)))
    for i,f in enumerate(tape['frames'][:4],1):
        f['aim_valid']=i>=3;f['aim_position_viewport_px']=[0.,0.]
        f['strengths']['grip_left']=1. if i in [1,3] else 0.
        f['button_edges']=[{'hand':0,'pressed':i in [1,3]}]
    for f in tape['frames']:f['tape_sha256']='CAPTURE_SOURCE_IDENTITY'
    content=old.digest(tape['frames'])
    for f in tape['frames']:f['tape_sha256']=content
    tape.update(tape_content_sha256=content,diagnostic_only=True,derivation='R3 N1 first4 frame negative; original immutable',original_tape_sha256=old.file_hash(original_tape(hz)))
    old.atomic_json(path,tape);return path


def capture_tape(row):
    path=c.capture_tape(row)
    # New captured source, never an R3 tape or an old-world replay.
    tape=old.read_json(path);tape['benchmark']='fixture_feasibility_v134'
    tape['fixture_revision']=next(d['fixture_revision'] for d in old.read_json(CAT)['scenarios'] if d['id']==row['scenario_id'])
    old.atomic_json(path,tape)
    return path


def pair(left,right,label):
    result=old.compare_required(left['directory'],right['directory'])
    old.atomic_json(B/'comparisons'/f'{label}.json',result)
    return {'id':label,'left':left['run_id'],'right':right['run_id'],
            'status':result['status'],'first_difference':result.get('first_difference')}


def measurement_valid(row,definition):
    metrics=row['metrics']
    if metrics['observation']['status']!='MEASURED':return False
    if definition['kind']=='progress':return metrics['task_succeeded'] is True
    return all(metrics['metrics'][key]['status']=='MEASURED' for key in ['stop_path_3d_m','settling_time_s'])


def pilot():
    source=identity()
    if not source['final']:raise ValueError('FINAL_SOURCE_NOT_REGISTERED')
    target=B/'final_session.json'
    if target.exists():raise FileExistsError(target)
    session={'source_snapshot':source['snapshot_sha256'],'runs':[],'pairs':[],
             'fixture_failures':[],'hard_stop':'','scoring':'PROHIBITED'}
    def save():old.atomic_json(target,session)
    def one(*args,**kwargs):
        row=execute(*args,**kwargs);session['runs'].append(row)
        if row['status']!='RUN_VALID':session['hard_stop']=row['reason']
        save();return row
    save()
    for hz in [120,60]:
        row=one('swing_catch_train',hz,'headless','negative',n1_tape(hz),negative='N1')
        if session['hard_stop']:return
        checks=row['engine_result']['negative_checks']
        view=old.read_json(Path(row['directory'])/'python_pick_dispatch_contract.json')
        if not checks or not all(x['pass'] for x in checks) or [view['logical_count'],view['dispatch_count'],view['ray_count'],view['suppressed_count']]!=[4,3,9,1]:
            session['hard_stop']='N1_EXPECTED_CONTRACT_NOT_MET';save();return
    for hz in [120,60]:
        h=one('swing_catch_train',hz,'headless','reference',original_tape(hz))
        if session['hard_stop']:return
        rendered=one('swing_catch_train',hz,'rendered_scripted','reference',original_tape(hz))
        if session['hard_stop']:return
        comparison=pair(h,rendered,f'reference_{hz}');session['pairs'].append(comparison)
        if comparison['status']!='STRICT_MATCH':session['hard_stop']='REFERENCE_REPLAY_FIDELITY_FAILURE';save();return
        save()
    for hz in [120,60]:
        for definition in old.read_json(CAT)['scenarios']:
            name=definition['id'];row=one(name,hz,'headless','capture')
            if session['hard_stop']:return
            metrics=row['metrics'];observation=metrics['observation']
            if not measurement_valid(row,definition):
                session['fixture_failures'].append({'scenario':name,'hz':hz,'capture':row['run_id'],
                    'status':observation['status'],'reason':observation['reason_code'],
                    'fixed_replay':'NOT_RUN_FIXTURE_PRECONDITION_OR_WINDOW_FAILURE'})
                save();continue
            tape=capture_tape(row)
            h=one(name,hz,'headless','replay',tape)
            if session['hard_stop']:return
            if not measurement_valid(h,definition):
                session['fixture_failures'].append({'scenario':name,'hz':hz,'run_id':h['run_id'],
                    'status':'FIXED_REPLAY_TASK_WINDOW_FAILED','reason':h['metrics']['observation']['reason_code'],
                    'rendered_replay':'NOT_RUN_FAILED_HEADLESS_WINDOW'})
                save();continue
            rendered=one(name,hz,'rendered_scripted','replay',tape)
            if session['hard_stop']:return
            comparison=pair(h,rendered,f'{name}_{hz}');session['pairs'].append(comparison)
            if not measurement_valid(rendered,definition):
                session['fixture_failures'].append({'scenario':name,'hz':hz,'run_id':rendered['run_id'],
                    'status':'FIXED_REPLAY_TASK_WINDOW_FAILED','reason':rendered['metrics']['observation']['reason_code']})
            if comparison['status']!='STRICT_MATCH':session['hard_stop']='DOMAIN_REPLAY_FIDELITY_FAILURE';save();return
            save()
    session['closed']=True;session['decision']='FEASIBILITY_NO_GO' if session['fixture_failures'] else 'PENDING_INDEPENDENT_FINAL_REVIEW'
    save()


def main():
    p=argparse.ArgumentParser();p.add_argument('stage',choices=['register','run','final']);p.add_argument('--label');p.add_argument('--scenario');p.add_argument('--hz',type=int,default=120);p.add_argument('--phase',default='development');a=p.parse_args()
    if a.stage=='register':register(a.label,final=a.phase=='final');return
    with old.StudyLock(ROOT/'builds/eval_virtual_cursor'):
        if a.stage=='run':
            row=execute(a.scenario,a.hz,'headless',a.phase,n1_tape(a.hz) if a.scenario=='swing_catch_train' else None,negative='N1' if a.scenario=='swing_catch_train' else '')
            print('V134',row['status'],row['reason']);return
        pilot()


if __name__=='__main__':main()
