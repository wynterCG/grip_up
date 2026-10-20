"""Finite v133 orchestration around the existing isolated replay/clock driver."""
from __future__ import annotations
import argparse,copy,json,math,subprocess,sys,time,uuid,struct
from pathlib import Path
sys.path[:0]=[str(Path(__file__).resolve().parents[1]),str(Path(__file__).resolve().parents[1]/'virtual_cursor')]
from common import ROOT,DEST,ENGINE,atomic_json,read_json,file_hash,digest,source_hashes,git_identity,engine_identity,utc_now,StudyLock
from run_trial import make_candidate
from candidate_schema import baseline,parameter_resource
from comparison import compare_required
from metrics import summarize
from projection_comparison import load_picks

DOC=ROOT/'docs/validation/auto_tuning/benchmark_v133'
BASE=ROOT/'builds/eval_virtual_cursor/benchmark_v133_r1'
ENTRY='res://features/evaluator_virtual_cursor/scripts/benchmark_runner.gd'
CATALOG=ROOT/'features/evaluator_virtual_cursor/resources/benchmark_eval_v133.json'

def identity():
    frozen=read_json(BASE/'source_identity.json')
    if source_hashes()!=frozen['source_hashes'] or source_hashes(DEST)!=frozen['source_hashes']:raise ValueError('FROZEN_SOURCE_CHANGED')
    if engine_identity()!=frozen['engine_identity']:raise ValueError('FROZEN_ENGINE_CHANGED')
    return frozen

def tape_check(path,hz,source,scenario,negative=False):
    tape=read_json(path)
    if tape['schema']!='grip_virtual_replay_v1' or tape['camera_mode']!='V0_PHYSICS_FOLLOW' or tape['physics_hz']!=hz or tape['engine_identity']!=source['engine_identity']:raise ValueError('TAPE_SCHEMA_ENGINE_HZ')
    if tape.get('diagnostic_only') and not negative:raise ValueError('DIAGNOSTIC_TAPE_NOT_PRIMARY')
    if scenario=='swing_catch_train':
        original=read_json(ROOT/'builds/eval_virtual_cursor/requal_20261020_r1/source_identity.json')['source_hashes']
        if tape['source_hashes']!=original:raise ValueError('CATCH_CAPTURE_SOURCE')
    else:
        if tape['source_hashes']!=source['source_hashes']:raise ValueError('DOMAIN_CAPTURE_SOURCE')
        if tape.get('scenario_id')!=scenario or tape.get('scenario_catalog_sha256')!=file_hash(CATALOG) or tape.get('benchmark')!='benchmark_eval_v133' or tape.get('source_input_lane')!='ADAPTIVE_CAPTURE_SOURCE_NOT_A_FIXED_REPLAY':raise ValueError('TAPE_SCENARIO_CATALOG_BENCHMARK_LANE')
    normalized=copy.deepcopy(tape['frames'])
    for f in normalized:f['tape_sha256']='CAPTURE_SOURCE_IDENTITY'
    if digest(normalized)!=tape['tape_content_sha256'] or any(f['tape_sha256']!=tape['tape_content_sha256'] for f in tape['frames']):raise ValueError('TAPE_CONTENT_HASH')
    return tape

def execute(scenario,hz,mode,repeat,group,tape_path=None,probe=True,negative=''):
    source=identity();plan=read_json(DOC/'run_plan.json')
    previous=[read_json(p) for p in (BASE/'attempts').glob('*/manifest.json')]
    if len(previous)>=plan['max_qualification_attempts']:raise ValueError('GLOBAL_BUDGET_EXHAUSTED')
    maximum={'reference':12,'domain':72,'negative':8,'diagnostic':4}[group]
    if sum(m['budget_group']==group for m in previous)>=maximum:raise ValueError('GROUP_BUDGET_EXHAUSTED')
    run_id=f'{scenario}_{hz}_{mode}_r{repeat}_{uuid.uuid4().hex[:8]}'
    directory=BASE/'attempts'/run_id;directory.mkdir(parents=True,exist_ok=False)
    lane='FIXED_VIRTUAL_REPLAY' if tape_path else 'ADAPTIVE_CAPTURE_SOURCE'
    m={'schema_version':'1.3.3','benchmark':'benchmark_eval_v133','run_id':run_id,'campaign_id':'benchmark_v133_r1','physics_hz':hz,'engine_mode':mode,'lane':'A','input_lane':lane,'virtual_mode':'REPLAY' if tape_path else 'CAPTURE','scenario_ids':[scenario],'recorder_enabled':True,'existing_observer_enabled':True,'output_dir':str(directory),'run_seed':101,'expected_source_hashes':source['source_hashes'],'code_commit':source['repository_commit'],'dirty_tree':False,'engine_identity':source['engine_identity'],'timeout_s':100,'budget_group':group,'negative_case':negative,'local_override_sha256':'ABSENT','projection_config':{'window_size':[1024,576],'probe_enabled':probe},'virtual_tape_sha256':'CAPTURE_SOURCE_IDENTITY','catalog_sha256':file_hash(CATALOG),'run_plan_sha256':file_hash(DOC/'run_plan.json')}
    m['baseline_candidate']=make_candidate(baseline(parameter_resource()),[scenario],trial_id=run_id,hz=hz,seed=101,timeout=100,provenance=source,input_trace_id='benchmark_eval_v133_r1')
    tape=None
    if tape_path:
        tape=tape_check(tape_path,hz,source,scenario,bool(negative));m.update(virtual_tape_path=str(tape_path),virtual_tape_sha256=file_hash(tape_path),projection_capture_source_hashes=tape['source_hashes'])
        m['capture_runtime_source_delta']={p:{'capture_sha256':tape['source_hashes'].get(p),'runtime_sha256':source['source_hashes'].get(p)} for p in sorted(tape['source_hashes'].keys()|source['source_hashes'].keys()) if tape['source_hashes'].get(p)!=source['source_hashes'].get(p)}
    atomic_json(directory/'manifest.json',m)
    flags=['--headless','--fixed-fps','120'] if mode=='headless' else ['--screen','0','--position','80,80']
    command=[str(ENGINE),*flags,'--resolution','1024x576','--path',str(ROOT),'--script',ENTRY,'--','--virtual-cursor-evaluator','--benchmark-qualification','--manifest',str(directory/'manifest.json'),'--result',str(directory/'engine_result.json')]
    atomic_json(directory/'execution.json',{'command':command,'utc':utc_now(),'workers':1,'input_lane':lane})
    started=time.monotonic();code=None;reason='';result={};metrics={}
    with (directory/'stdout.txt').open('wb') as stdout,(directory/'stderr.txt').open('wb') as stderr:
        process=subprocess.Popen(command,cwd=ROOT,stdout=stdout,stderr=stderr)
        try:code=process.wait(timeout=115)
        except (KeyboardInterrupt,subprocess.TimeoutExpired):process.kill();process.wait();reason='PROCESS_ABORTED_OR_TIMEOUT'
    status='RUN_INVALID'
    try:
        result=read_json(directory/'engine_result.json')
        logs='\n'.join((directory/name).read_text(errors='replace') for name in ['stdout.txt','stderr.txt'])
        if any(word in logs for word in ['SCRIPT ERROR:','Parse Error:','ERROR: Failed to load']):raise ValueError('ENGINE_SCRIPT_ERROR')
        if code!=0 or result['status']!='completed':raise ValueError(result.get('reason') or 'RUNTIME_NOT_COMPLETED')
        if result['manifest_file_sha256']!=file_hash(directory/'manifest.json'):raise ValueError('MANIFEST_IDENTITY')
        if source_hashes()!=source['source_hashes']:raise ValueError('SOURCE_CHANGED_DURING_RUN')
        for key in ['physics_hz_restored','startup_profile_preserved','installs_pre_step','sources_after_unchanged']:
            if not result['restoration'][key]:raise ValueError('RESTORATION:'+key)
        cleanup=result['virtual_input']['cleanup']
        if not all(cleanup[k] for k in ['provider_disabled','lab_provider_removed','camera_live','router_frame_removed']) or any(cleanup['hand_held']) or cleanup['orbiting']:raise ValueError('INPUT_CLEANUP')
        if result['trace']['dropped_rows'] or result['trace']['error']:raise ValueError('TRACE_INCOMPLETE')
        if result['projection_setup']['actual_size']!=[1024,576] or not result['projection_setup']['before_world']:raise ValueError('CANONICAL_ENVIRONMENT')
        audit=read_json(directory/'benchmark_audit.json');ticks=audit['ticks']
        if not ticks or len(ticks)!=len(audit['frames']):raise ValueError('FRAME_COUNT')
        for i,row in enumerate(ticks,1):
            if row['tick']!=i or row['sample_phase']!='post_control' or abs(row['delta_s']-1/hz)>1e-7:raise ValueError('TICK_PHASE_CLOCK')
            if row['canonical_input']['requested']!=row['canonical_input']['effective']:raise ValueError('REQUEST_EFFECTIVE_INPUT_MISMATCH')
            n=lambda v:math.sqrt(sum(x*x for x in v))
            if row['body']['mass_kg']!=12 or any(h['reach_m']!=.65708 for h in row['hands']):raise ValueError('PROTECTED_PHYSICS_VALUES')
            if any(h['state'] not in ['ATTACHED','SLIPPING'] and n(h['force_n'])!=0 for h in row['hands']):raise ValueError('FREE_PENDING_HAND_FORCE')
            f=row['force_budget']
            if f['hands_n']>360.001 or f['feet_n']>180.001 or n(f['assist_nm'])>20.001 or n(f['combined_nm'])>150.001 or any(n(foot['force_n'])>120.001 for foot in row['feet']):raise ValueError('HARD_PHYSICS_CAP')
            if tape:
                wanted=tape['frames'][i-1];actual=row['canonical_input']['effective']
                # Native cursor contract is Vector2 (float32 build). Preserve raw
                # scalar parse values in precise audit; never re-center the aim.
                for key in wanted:
                    if key!='aim_position_viewport_px' and wanted[key]!=actual[key]:raise ValueError('TAPE_EFFECTIVE_INPUT:'+key)
                f32=lambda v:struct.unpack('<f',struct.pack('<f',v))[0]
                if row['canonical_input']['effective_aim_px']!=[f32(x) for x in wanted['aim_position_viewport_px']] and wanted['aim_valid']:raise ValueError('TAPE_NATIVE_VECTOR2_CURSOR')
        if probe:
            picks=load_picks(directory)
            if len(picks)!=sum(len(t['target'].get('picks',[])) for t in ticks):raise ValueError('MISSING_REAL_PICK_RECORDS')
            if result['projection_probe']['error']:raise ValueError(result['projection_probe']['error'])
        s=result['scenarios'][0]
        if any(s.get('invariants',{}).values()):raise ValueError('HARD_PHYSICS_INVARIANT')
        if scenario=='swing_catch_train':
            c=s['catch_native']
            if not negative and not all(c[k] for k in ['real_contact','retained_at_end','beyond_static_reach','known_underside_selected']):raise ValueError('NO_REAL_RETAINED_CATCH')
        else:
            definition=next(d for d in read_json(CATALOG)['scenarios'] if d['id']==scenario)
            precise=read_json(directory/'benchmark_runtime.json')[0]
            metrics=summarize(ticks,definition,precise['onset_certificate'])
            atomic_json(directory/'scenario_metrics.json',metrics)
            if metrics['observation']['status']=='INVALID_MEASUREMENT':raise ValueError('INVALID_METRIC:'+metrics['observation']['reason_code'])
            hard=metrics['metrics']['hard_physical_violations']
            if hard['status']=='MEASURED' and hard['value']>0:raise ValueError('METRIC_HARD_PHYSICAL_VIOLATION')
            rt=precise['runtime_measurement']
            for key in ['signed_progress_m','path3d_onset_to_end']:
                if rt.get(key)!=metrics.get(key):raise ValueError('INDEPENDENT_METRIC_RECOMPUTE:'+key)
        status='RUN_VALID'
    except (OSError,ValueError,TypeError,KeyError,IndexError) as e:reason=str(e)
    receipt={'run_id':run_id,'directory':str(directory),'scenario_id':scenario,'hz':hz,'mode':mode,'repeat':repeat,'group':group,'input_lane':lane,'probe_enabled':probe,'status':status,'reason':reason,'process_exit_code':code,'elapsed_wall_s':time.monotonic()-started,'engine_result':result,'metrics':metrics,'tape_sha256':m['virtual_tape_sha256'],'source_commit':source['repository_commit']}
    atomic_json(directory/'receipt.json',receipt)
    print(run_id,status,reason,flush=True)
    return receipt

def capture_tape(receipt):
    if receipt['status']!='RUN_VALID':raise ValueError('INVALID_CAPTURE')
    directory=Path(receipt['directory']);audit=read_json(directory/'virtual_audit.json');m=read_json(directory/'manifest.json');s=read_json(directory/'benchmark_runtime.json')[0]
    frames=audit['frames'];content=digest(frames)
    for frame in frames:frame['tape_sha256']=content
    tape={'schema':'grip_virtual_replay_v1','benchmark':'benchmark_eval_v133','physics_hz':m['physics_hz'],'camera_mode':'V0_PHYSICS_FOLLOW','source_hashes':m['expected_source_hashes'],'engine_identity':m['engine_identity'],'capture_manifest_sha256':file_hash(directory/'manifest.json'),'capture_audit_sha256':file_hash(directory/'virtual_audit.json'),'frames':frames,'reference_ticks':audit['ticks'],'tape_content_sha256':content,'scenario_id':receipt['scenario_id'],'scenario_catalog_sha256':file_hash(CATALOG),'source_receipt':receipt['run_id'],'source_input_lane':'ADAPTIVE_CAPTURE_SOURCE_NOT_A_FIXED_REPLAY','onset_certificate':s.get('onset_certificate',{}),'diagnostic_only':s.get('onset_certificate',{}).get('onset_tick') is None}
    path=BASE/'tapes'/f"{receipt['scenario_id']}_{m['physics_hz']}.json"
    if path.exists():raise FileExistsError(path)
    atomic_json(path,tape);return path

def run_stage(stage):
    target=BASE/(stage+'_session.json')
    if target.exists():raise FileExistsError('IMMUTABLE_STAGE:'+stage)
    source=identity();rows=[];pairs=[];stopped=''
    def save():atomic_json(target,{'stage':stage,'source_commit':source['repository_commit'],'runs':rows,'pairs':pairs,'hard_stop':stopped,'optimizer':'OFF'})
    def one(*args,**kwargs):
        nonlocal stopped
        r=execute(*args,**kwargs);rows.append(r)
        if r['status']!='RUN_VALID':stopped=r['reason']
        save();return r
    def paired(scenario,hz,repeat,group,tape):
        nonlocal stopped
        h=one(scenario,hz,'headless',repeat,group,tape)
        if stopped:return
        r=one(scenario,hz,'rendered_scripted',repeat,group,tape)
        if stopped:return
        try:d=compare_required(h['directory'],r['directory'])
        except (ValueError,KeyError,TypeError) as e:d={'status':'MISMATCH','reason':'INVALID_COMPARISON:'+str(e)}
        pair_id=f'{scenario}_{hz}_r{repeat}';atomic_json(BASE/'comparisons'/f'{pair_id}.json',d)
        pairs.append({'pair_id':pair_id,'scenario':scenario,'hz':hz,'repeat':repeat,'left':h['directory'],'right':r['directory'],'status':d['status'],'first_difference':d.get('first_difference'),'reason':d.get('reason')})
        if d['status']!='STRICT_MATCH':stopped='REQUIRED_CHANNEL_MISMATCH:'+pair_id
        save()
    with StudyLock(ROOT/'builds/eval_virtual_cursor'):
        if stage=='reference':
            preflight=read_json(BASE/'preflight_session.json')
            if not preflight['pass']:raise ValueError('BQ1_PREFLIGHT_NOT_PASSED')
            for hz in [120,60]:
                tape=ROOT/f'builds/eval_virtual_cursor/requal_20261020_r1/capture/tapes/catch_{hz}.json'
                if file_hash(tape)!=read_json(DOC/'run_plan.json')['reference_tapes'][str(hz)]['sha256']:raise ValueError('FROZEN_CATCH_TAPE')
                for repeat in [1,2,3]:
                    paired('swing_catch_train',hz,repeat,'reference',tape)
                    if stopped:break
                if stopped:break
        elif stage=='domains':
            ref=read_json(BASE/'reference_session.json')
            if ref['hard_stop'] or len(ref['pairs'])!=6 or any(x['status']!='STRICT_MATCH' for x in ref['pairs']):raise ValueError('BQ2_REFERENCE_NOT_QUALIFIED')
            definitions=read_json(CATALOG)['scenarios'];eligible={}
            for hz in [120,60]:
                for definition in definitions:
                    name=definition['id'];capture=one(name,hz,'headless',0,'domain')
                    if stopped:break
                    tape=capture_tape(capture)
                    onset=capture['engine_result']['scenarios'][0]['onset_certificate']['onset_tick']
                    eligible[name,hz]=onset is not None
                    if onset is None:continue
                    paired(name,hz,1,'domain',tape)
                    if stopped:break
                    if name in ['foot_supported_step','two_hand_release_stop']:
                        off=one(name,hz,'headless',9,'domain',tape,probe=False)
                        if stopped:break
                        h=next(x for x in rows if x['scenario_id']==name and x['hz']==hz and x['mode']=='headless' and x['repeat']==1)
                        d=compare_required(h['directory'],off['directory'],probe=False);atomic_json(BASE/'comparisons'/f'{name}_{hz}_observer_control.json',d)
                        if d['status']!='STRICT_MATCH':stopped='OBSERVER_CONTROL_MISMATCH:'+name;save();break
                if stopped:break
                for definition in definitions[:4]:
                    name=definition['id']
                    if not eligible.get((name,hz)):continue
                    for repeat in [2,3]:
                        paired(name,hz,repeat,'domain',BASE/'tapes'/f'{name}_{hz}.json')
                        if stopped:break
                    if stopped:break
                if stopped:break
    save();print(json.dumps({'stage':stage,'runs':len(rows),'pairs':len(pairs),'hard_stop':stopped},indent=2))
    return 1 if stopped else 0

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('stage',choices=['reference','domains']);args=p.parse_args();raise SystemExit(run_stage(args.stage))
