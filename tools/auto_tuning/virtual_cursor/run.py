"""Bounded virtual-input evidence, no optimization imports or score aggregation."""
from __future__ import annotations
import argparse,itertools,json,subprocess,sys,time,uuid
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from common import ROOT,DEST,ENGINE,atomic_json,digest,engine_identity,file_hash,git_identity,read_json,source_hashes,utc_now,StudyLock
from candidate_schema import baseline,parameter_resource
from run_trial import make_candidate

ENTRY='res://features/evaluator_virtual_cursor/scripts/virtual_cursor_runner.gd'
BENCHMARK='benchmark_eval_virtual_cursor_v1'
def check_budget(development,hz,capture,negative):
    manifests=[read_json(p) for p in (ROOT/'builds/eval_virtual_cursor').glob('**/attempts/*/manifest.json')]
    relevant=[m for m in manifests if m.get('benchmark')==BENCHMARK]
    if negative:
        if sum(bool(m.get('negative_case')) for m in relevant)>=4:raise ValueError('DIAGNOSTIC_BUDGET_EXHAUSTED')
    elif development:
        if sum(m.get('classification')=='DEVELOPMENT_NOT_CERTIFIED' and not m.get('negative_case') for m in relevant)>=8:raise ValueError('DEVELOPMENT_BUDGET_EXHAUSTED')
        if capture and sum(m.get('virtual_mode')=='CAPTURE' and m.get('physics_hz')==hz for m in relevant)>=2:raise ValueError('CAPTURE_PER_HZ_BUDGET_EXHAUSTED')
    else:
        if sum(m.get('classification')=='QUALIFICATION' and not m.get('negative_case') for m in relevant)>=24:raise ValueError('QUALIFICATION_BUDGET_EXHAUSTED')
def first_difference(a,b,path=''):
    if isinstance(a,dict) and isinstance(b,dict):
        if a.keys()!=b.keys():return {'field':path,'reason':'KEYS','expected':list(a),'actual':list(b)}
        for k in a:
            found=first_difference(a[k],b[k],path+'.'+str(k))
            if found:return found
    elif isinstance(a,list) and isinstance(b,list):
        if len(a)!=len(b):return {'field':path,'reason':'LENGTH','expected':len(a),'actual':len(b)}
        for i,(x,y) in enumerate(zip(a,b)):
            found=first_difference(x,y,f'{path}[{i}]')
            if found:return found
    elif a!=b:return {'field':path,'expected':a,'actual':b}
    return None

def strip_runtime(value):
    if isinstance(value,dict):return {k:strip_runtime(v) for k,v in value.items() if k not in {'collider_runtime_id','runtime_id','anchor_runtime_id','physics_interpolation_fraction'}}
    if isinstance(value,list):return [strip_runtime(v) for v in value]
    return value

def compare(tape,audit):
    ticks=audit['ticks'];reference=tape['reference_ticks'];frames=tape['frames']
    if not frames or len(ticks)!=len(frames) or len(reference)!=len(frames):return {'status':'MISSING_TICK','first':{'expected':len(frames),'actual':len(ticks),'reference':len(reference)}}
    first_physics=None
    for index,(wanted,expected,actual) in enumerate(zip(frames,reference,ticks)):
        for field,observed in [('requested',actual['canonical_input']['requested']),('effective',actual['canonical_input']['effective'])]:
            diff=first_difference(wanted,observed)
            if diff:return {'status':'INPUT_SOURCE_MISMATCH','tick':index+1,'phase':'input.'+field,'first':diff}
        if wanted['aim_valid'] and actual['canonical_input']['effective_aim_px']!=wanted['aim_position_viewport_px']:
            return {'status':'CURSOR_OR_CAMERA_MISMATCH','tick':index+1,'phase':'effective_aim','first':{'expected':wanted['aim_position_viewport_px'],'actual':actual['canonical_input']['effective_aim_px']}}
        for phase in ['camera','target']:
            diff=first_difference(strip_runtime(expected[phase]),strip_runtime(actual[phase]))
            if diff:return {'status':'CURSOR_OR_CAMERA_MISMATCH' if phase=='camera' else 'CONTACT_SELECTION_DIVERGED','tick':index+1,'phase':phase,'first':diff,'first_physics_divergence':first_physics}
        for phase in ['body','hands']:
            # Never treat different process-generated node names as physical state.
            def physical(v):
                if isinstance(v,dict):return {k:physical(x) for k,x in v.items() if k not in {'name','runtime_id','anchor_runtime_id','controller_step','support_id','blocker_id','collider_id'}}
                if isinstance(v,list):return [physical(x) for x in v]
                return v
            diff=first_difference(physical(expected[phase]),physical(actual[phase]))
            if diff and first_physics is None:first_physics={'tick':index+1,'phase':phase,'first':diff}
    return {'status':'PASS_PICKING_REPLAY','input_status':'PASS_INPUT_ISOLATION','ticks':len(ticks),'first_physics_divergence':first_physics,'physics_status':'PHYSICS_DIVERGENCE_AFTER_MATCHED_INPUT_AND_PICKING' if first_physics else 'NO_RECORDED_PHYSICS_DIFFERENCE','physics_scope':'diagnostic only, no approved continuous error envelope'}

def execute(mode,hz,condition,repeat,output,tape_path=None,development=False,negative=''):
    check_budget(development,hz,tape_path is None,negative)
    identity=git_identity();identity.update(source_hashes=source_hashes(ROOT),engine_identity=engine_identity())
    run_id=f'{condition}_{hz}_r{repeat}_{uuid.uuid4().hex[:8]}'
    directory=output/'attempts'/run_id;directory.mkdir(parents=True,exist_ok=False)
    manifest={'schema_version':'1.3.2a','benchmark':BENCHMARK,'run_id':run_id,'physics_hz':hz,'engine_mode':mode,'lane':'A','virtual_mode':'REPLAY' if tape_path else 'CAPTURE','scenario_ids':['swing_catch_train'],'recorder_enabled':True,'existing_observer_enabled':True,'output_dir':str(directory),'run_seed':101,'expected_source_hashes':identity['source_hashes'],'code_commit':identity['repository_commit'],'dirty_tree':identity['repository_dirty'],'engine_identity':identity['engine_identity'],'timeout_s':100,'condition':condition,'classification':'DEVELOPMENT_NOT_CERTIFIED' if development else 'QUALIFICATION','local_override_sha256':file_hash(ROOT/'override.cfg') if (ROOT/'override.cfg').exists() else 'ABSENT','negative_case':negative}
    manifest['baseline_candidate']=make_candidate(baseline(parameter_resource()),['swing_catch_train'],trial_id=run_id,hz=hz,seed=101,timeout=100,provenance=identity)
    if tape_path:
        tape=read_json(tape_path)
        manifest.update(virtual_tape_path=str(tape_path),virtual_tape_sha256=file_hash(tape_path))
        if tape['source_hashes']!=identity['source_hashes']:raise ValueError('TAPE_SOURCE_IDENTITY')
        if tape['engine_identity']!=identity['engine_identity'] or tape['benchmark']!=BENCHMARK or tape['camera_mode']!='V0_PHYSICS_FOLLOW':raise ValueError('TAPE_ENGINE_CAMERA_BENCHMARK')
        import copy
        normalized=copy.deepcopy(tape['frames'])
        for frame in normalized:frame['tape_sha256']='CAPTURE_SOURCE_IDENTITY'
        if digest(normalized)!=tape['tape_content_sha256'] or any(f['tape_sha256']!=tape['tape_content_sha256'] for f in tape['frames']):raise ValueError('TAPE_CONTENT_HASH')
    atomic_json(directory/'manifest.json',manifest)
    flags=['--headless','--fixed-fps','120'] if mode=='headless' else ['--screen','0','--position','80,80']
    command=[str(ENGINE),*flags,'--path',str(ROOT),'--script',ENTRY,'--','--virtual-cursor-evaluator','--manifest',str(directory/'manifest.json'),'--result',str(directory/'engine_result.json')]
    atomic_json(directory/'execution.json',{'command':command,'utc':utc_now(),'workers':1})
    started=time.monotonic();code=None;result={};reason='';comparison={}
    with (directory/'stdout.txt').open('wb') as stdout,(directory/'stderr.txt').open('wb') as stderr:
        process=subprocess.Popen(command,cwd=ROOT,stdout=stdout,stderr=stderr)
        try:code=process.wait(timeout=110)
        except (subprocess.TimeoutExpired,KeyboardInterrupt):process.kill();process.wait();reason='WALL_TIMEOUT_OR_CANCELLED'
    try:
        result=read_json(directory/'engine_result.json');status=result['status'];reason=result.get('reason','') or reason
        if result.get('manifest_file_sha256')!=file_hash(directory/'manifest.json'):raise ValueError('MANIFEST_HASH')
        logs='\n'.join((directory/n).read_text(errors='replace') for n in ['stdout.txt','stderr.txt'])
        if any(x in logs for x in ['SCRIPT ERROR:','Parse Error:','ERROR: Failed to load']):raise ValueError('ENGINE_ERROR')
        expected_abort=negative=='N4' and code==1 and status=='BLOCKED_TRACE' and reason=='TEST_ABORT_WHILE_HELD'
        if not expected_abort and (code!=0 or status!='completed'):raise ValueError(reason or 'RUNTIME_NOT_COMPLETED')
        if source_hashes(ROOT)!=identity['source_hashes']:raise ValueError('SOURCE_CHANGED')
        restoration=result['restoration']
        if not all(restoration[k] for k in ['physics_hz_restored','startup_profile_preserved','installs_pre_step','sources_after_unchanged']):raise ValueError('RESTORATION_FAILED')
        if result['trace']['dropped_rows'] or result['trace']['error']:raise ValueError('TRACE_INCOMPLETE')
        audit=read_json(directory/'virtual_audit.json')
        if tape_path and negative not in ['N1','N2']:
            compared_tape=tape
            if expected_abort:compared_tape={**tape,'frames':tape['frames'][:len(audit['ticks'])],'reference_ticks':tape['reference_ticks'][:len(audit['ticks'])]}
            comparison=compare(compared_tape,audit);atomic_json(directory/'comparison.json',comparison)
            if comparison['status']!='PASS_PICKING_REPLAY':raise ValueError(comparison['status'])
        cleanup=result['virtual_input']['cleanup']
        if not all(cleanup[k] for k in ['provider_disabled','lab_provider_removed','camera_live','router_frame_removed']) or cleanup['hand_held']!=[False,False] or cleanup['orbiting']:raise ValueError('CLEANUP_FAILED')
        if not negative:
            for row in result['scenarios']:
                if any(row.get('invariants',{}).values()):raise ValueError('PHYSICS_INVARIANT')
                if not row['catch_native']['real_contact'] or not row['catch_native']['retained_at_end']:raise ValueError('TASK_OUTCOME_NOT_RETAINED')
                if not row['catch_native']['beyond_static_reach']:raise ValueError('TASK_NOT_BEYOND_STATIC_REACH')
                if not row['catch_native']['known_underside_selected']:raise ValueError('CONTACT_SELECTION_DIVERGED:EXPECTED_UNDERSIDE')
        if negative and any(not check['pass'] for check in result.get('negative_checks',[])):raise ValueError('NEGATIVE_CASE_FAILED')
        status='completed'
    except (OSError,KeyError,TypeError,ValueError) as exc:status='failed_runtime';reason=str(exc)
    receipt={'status':status,'reason':reason,'run_id':run_id,'directory':str(directory),'exit_code':code,'elapsed_wall_s':time.monotonic()-started,'engine_result':result,'comparison':comparison}
    atomic_json(directory/'receipt.json',receipt)
    print(run_id,status,reason,flush=True)
    return receipt

def make_tape(receipt,destination):
    if receipt['status']!='completed':raise ValueError('CAPTURE_NOT_ACCEPTED')
    directory=Path(receipt['directory']);audit=read_json(directory/'virtual_audit.json');manifest=read_json(directory/'manifest.json')
    frames=audit['frames']
    payload=digest(frames)
    for frame in frames:frame['tape_sha256']=payload
    tape={'schema':'grip_virtual_replay_v1','benchmark':BENCHMARK,'physics_hz':manifest['physics_hz'],'camera_mode':'V0_PHYSICS_FOLLOW','source_hashes':manifest['expected_source_hashes'],'engine_identity':manifest['engine_identity'],'capture_manifest_sha256':file_hash(directory/'manifest.json'),'capture_audit_sha256':file_hash(directory/'virtual_audit.json'),'tape_content_sha256':payload,'hash_scope':'SHA256 of canonical source frames with tape_sha256=CAPTURE_SOURCE_IDENTITY; file SHA256 separately in replay manifest, avoiding self reference','initial':audit['environment'],'frames':frames,'reference_ticks':audit['ticks'],'source_receipt':receipt['run_id']}
    if destination.exists():raise FileExistsError(destination)
    atomic_json(destination,tape)

def main():
    p=argparse.ArgumentParser();p.add_argument('--suite',choices=['capture','development','matrix','negatives'],required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--tapes',type=Path);p.add_argument('--hz',type=int,choices=[60,120],action='append');p.add_argument('--condition',choices=['V0-H','V0-R','V0-M','V0-F'],action='append');p.add_argument('--human-attested',action='store_true');args=p.parse_args()
    output=args.output.resolve();output.mkdir(parents=True,exist_ok=True)
    conditions=args.condition or (['V0-H','V0-R','V0-M','V0-F'] if args.suite=='matrix' else ['V0-H'])
    if args.suite in ['matrix','negatives'] and not args.tapes:raise ValueError('QUALIFICATION_REQUIRES_FROZEN_TAPES')
    if args.suite=='matrix' and git_identity()['repository_dirty']:raise ValueError('QUALIFICATION_REQUIRES_CLEAN_GIT')
    cells=[dict(condition=c,hz=h,repeat=r) for c,h,r in itertools.product(conditions,args.hz or [120,60],range(1,4) if args.suite=='matrix' else [1])]
    if args.suite=='negatives':cells=[dict(condition=c,hz=h,repeat=1,negative=n) for n,c,h in [('N1','V0-H',120),('N2','V0-H',60),('N3','V0-R',120),('N4','V0-R',60)]]
    if (output/'session_manifest.json').exists():raise FileExistsError('IMMUTABLE_SESSION')
    atomic_json(output/'session_manifest.json',{'benchmark':BENCHMARK,'utc':utc_now(),'cells':cells,'suite':args.suite,'human_attested':args.human_attested,'protocol_sha256':file_hash(ROOT/'docs/validation/virtual_cursor_v132a/protocol.md'),'candidate_trials':0,'private_holdout_outcomes_accessed':False})
    receipts=[]
    with StudyLock(ROOT/'builds/eval_virtual_cursor'):
        for index,cell in enumerate(cells):
            condition=cell['condition'];hz=cell['hz']
            if condition in ['V0-M','V0-F'] and not args.human_attested:
                receipts.append({**cell,'status':'INCOMPLETE_COVERAGE','reason':'HUMAN_INTERFERENCE_NOT_OBSERVED'});continue
            tape_path=args.tapes/f'catch_{hz}.json' if args.tapes else None
            receipt=execute('headless' if condition=='V0-H' else 'rendered_scripted',hz,condition,cell['repeat'],output,tape_path,args.suite!='matrix',cell.get('negative',''))
            receipts.append({**cell,**receipt})
            if receipt['status']!='completed':
                receipts.extend({**pending,'status':'NOT_RUN_EARLY_STOP'} for pending in cells[index+1:]);break
            if args.suite=='capture':make_tape(receipt,output/'tapes'/f'catch_{hz}.json')
            atomic_json(output/'session_state.json',{'runs':receipts})
    atomic_json(output/'session_state.json',{'runs':receipts,'status':'completed' if all(x['status']=='completed' for x in receipts) else 'STOPPED_OR_INCOMPLETE'})
    return 0 if all(x['status']=='completed' for x in receipts) else 1
if __name__=='__main__':raise SystemExit(main())
