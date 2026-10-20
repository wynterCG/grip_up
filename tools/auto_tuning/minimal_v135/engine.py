"""MBQ-specific physical adapter; shared audits remain unchanged."""
from __future__ import annotations
import copy, math, struct, subprocess, time, uuid
from pathlib import Path
from common import ROOT, DEST, ENGINE, atomic_json, read_json, file_hash, digest, source_hashes, utc_now
from run_trial import make_candidate
from candidate_schema import baseline, parameter_resource
from comparison import compare_required
from metrics import summarize
from projection_comparison import load_picks

DOC=ROOT/'docs/validation/auto_tuning/minimal_v135/r4'
BASE=ROOT/'builds/eval_virtual_cursor/minimal_v135_r4'
ENTRY='res://features/evaluator_virtual_cursor/scripts/minimal_runner.gd'
CATALOG=ROOT/'features/evaluator_virtual_cursor/resources/benchmark_minimal_v135_r1.json'
TRANSFER=ROOT/'features/evaluator_virtual_cursor/resources/minimal_transfer_v135.json'
# Integration supplies these source-guarded policies; there is no implicit baseline fallback.
identity=None
build_manifest=None

def definition_for(scenario):
    return next(d for p in [CATALOG,TRANSFER] for d in read_json(p)['scenarios'] if d['id']==scenario)

def enrich_quality(metrics,ticks,definition):
    """Read-only quality measures over the SAME certified complete window."""
    observation=metrics['observation'];onset=observation.get('onset_tick');end=observation.get('end_tick')
    names={'backwards_excursion_m':'m','off_axis_excursion_m':'m','angular_speed_peak_rad_s':'rad/s','target_saturation_fraction':'ratio'}
    for name,unit in names.items():
        metrics['metrics'][name]={'metric':name,'status':'NOT_APPLICABLE','value':None,'unit':unit,'reason_code':'COMPLETE_AUTHORIZED_WINDOW_REQUIRED','onset_tick':onset,'end_tick':end}
    if observation['status']!='MEASURED':return
    selected=[r for r in ticks if onset<=r['tick']<=end];origin=selected[0]['body']['com_m'];axis=definition['direction_world']
    progress=[];offaxis=[];speed=[]
    for r in selected:
        delta=[b-a for a,b in zip(origin,r['body']['com_m'])];directed=sum(a*b for a,b in zip(delta,axis))
        progress.append(directed);offaxis.append(math.sqrt(sum((d-a*directed)**2 for d,a in zip(delta,axis))))
        speed.append(math.sqrt(sum(x*x for x in r['body']['angular_velocity_rad_s'])))
    peak=0.;backwards=0.
    for value in progress:peak=max(peak,value);backwards=max(backwards,peak-value)
    values={'backwards_excursion_m':backwards,'off_axis_excursion_m':max(offaxis),'angular_speed_peak_rad_s':max(speed),'target_saturation_fraction':sum(r['benchmark_extra']['actuator_saturated'] is True for r in selected)/len(selected)}
    for name,value in values.items():metrics['metrics'][name].update(status='MEASURED',value=value,reason_code='ACTUAL_POST_TRACE_SAME_AUTHORIZED_WINDOW')

def execute(scenario,hz,mode,repeat,group,tape_path=None,probe=True,negative=''):
    source=identity();plan=read_json(DOC/'run_plan.json')
    previous=[read_json(p) for p in (BASE/'attempts').glob('*/manifest.json')]
    if len(previous)>=plan['max_qualification_attempts']:raise ValueError('GLOBAL_BUDGET_EXHAUSTED')
    maximum=plan['budget_limits'][group]
    if sum(m['budget_group']==group for m in previous)>=maximum:raise ValueError('GROUP_BUDGET_EXHAUSTED')
    run_id=f'{scenario}_{hz}_{mode}_r{repeat}_{uuid.uuid4().hex[:8]}'
    directory=BASE/'attempts'/run_id;directory.mkdir(parents=True,exist_ok=False)
    m,tape=build_manifest(scenario,hz,mode,run_id,directory,group,source,plan,tape_path,probe,negative)
    lane=m['input_lane']
    atomic_json(directory/'manifest.json',m)
    atomic_json(directory/'serialized_projection_config.json',m['projection_config'])
    flags=['--headless','--fixed-fps','120'] if mode=='headless' else ['--screen','0','--position','80,80']
    command=[str(ENGINE),*flags,'--resolution','1024x576','--path',str(ROOT),'--script',ENTRY,'--','--backing-size','1024x576','--virtual-cursor-evaluator','--benchmark-qualification','--manifest',str(directory/'manifest.json'),'--result',str(directory/'engine_result.json')]
    command.append('--minimal-tuning')
    atomic_json(directory/'execution.json',{'command':command,'utc':utc_now(),'workers':1,'input_lane':lane})
    started=time.monotonic();code=None;reason='';result={};metrics={}
    with (directory/'stdout.txt').open('wb') as stdout,(directory/'stderr.txt').open('wb') as stderr:
        process=subprocess.Popen(command,cwd=ROOT,stdout=stdout,stderr=stderr)
        try:code=process.wait(timeout=115)
        except (KeyboardInterrupt,subprocess.TimeoutExpired):process.kill();process.wait();reason='PROCESS_ABORTED_OR_TIMEOUT'
    return audit_execution(directory,scenario,hz,mode,repeat,group,source,m,tape,started,code,reason)

def audit_execution(directory,scenario,hz,mode,repeat,group,source,m,tape,started,code,reason=''):
    directory=Path(directory);lane=m['input_lane'];run_id=m['run_id'];result={};metrics={};probe=m['projection_config']['probe_enabled'];negative=m.get('negative_case','')
    status='RUN_INVALID'
    try:
        result=read_json(directory/'engine_result.json')
        logs='\n'.join((directory/name).read_text(errors='replace') for name in ['stdout.txt','stderr.txt'])
        if any(word in logs for word in ['SCRIPT ERROR:','Parse Error:','ERROR: Failed to load']):raise ValueError('ENGINE_SCRIPT_ERROR')
        atomic_json(directory/'admission_receipt.json',{'engine_status':result.get('status'),'reason':result.get('reason'),'backing':result.get('backing_initialization'),'clock':result.get('clock_startup'),'world_creation':result.get('world_creation_record'),'manifest_sha256':file_hash(directory/'manifest.json'),'source_snapshot_sha256':m['source_snapshot_sha256']})
        if code!=0 or result['status']!='completed':raise ValueError(result.get('reason') or 'RUNTIME_NOT_COMPLETED')
        if result['manifest_file_sha256']!=file_hash(directory/'manifest.json'):raise ValueError('MANIFEST_IDENTITY')
        if source_hashes()!=source['source_hashes']:raise ValueError('SOURCE_CHANGED_DURING_RUN')
        for key in ['physics_hz_restored','startup_profile_preserved','installs_pre_step','sources_after_unchanged']:
            if not result['restoration'][key]:raise ValueError('RESTORATION:'+key)
        resources=result['restoration']['resources']
        if not resources.get('exact_originals_and_pointer_restore') or not resources.get('originals_preserved'):raise ValueError('EXACT_RESOURCE_RESTORE')
        installs=result.get('parameter_installs',[])
        if not installs or any(x['step']!=0 or not x['original_unchanged'] or ('copied' in x and not x['copied']) for x in installs):raise ValueError('EXACT_COPY_INSTALL')
        if not any(x.get('seal_scope')=='MEASURED_WORLD_PRE_STEP' for x in installs):raise ValueError('MISSING_EFFECTIVE_PRE_STEP_SEAL')
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
            if m.get('pick_contract_version')=='1.3.4':
                from pick_contract import validate_stream
                view=validate_stream(ticks,picks,run_id,completed=True,expected_tick_count=len(audit['frames']),strict_new=True)
                atomic_json(directory/'python_pick_dispatch_contract.json',view)
                if result.get('pick_contract',{}).get('status')!='PASS':raise ValueError('GODOT_PICK_CONTRACT_NOT_PASSED')
            elif len(picks)!=sum(len(t['target'].get('picks',[])) for t in ticks):raise ValueError('MISSING_REAL_PICK_RECORDS')
            if result['projection_probe']['error']:raise ValueError(result['projection_probe']['error'])
        s=result['scenarios'][0]
        if any(s.get('invariants',{}).values()):raise ValueError('HARD_PHYSICS_INVARIANT')
        if scenario=='swing_catch_train':
            c=s['catch_native']
            if not negative and not all(c[k] for k in ['real_contact','retained_at_end','beyond_static_reach','known_underside_selected']):raise ValueError('NO_REAL_RETAINED_CATCH')
        else:
            definition=definition_for(scenario)
            precise=read_json(directory/'benchmark_runtime.json')[0]
            metrics=summarize(ticks,definition,precise['onset_certificate'])
            enrich_quality(metrics,ticks,definition)
            atomic_json(directory/'scenario_metrics_raw.json',metrics)
            # Partial-window arithmetic is evidence, never an official measured value.
            partial={}
            for key,metric in metrics['metrics'].items():
                if metric['status']!='MEASURED' and metric.get('value') is not None:
                    partial[key]=copy.deepcopy(metric);metric['value']=None
            metrics['partial_window_evidence']=partial
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
    tape={'schema':'grip_virtual_replay_v1','benchmark':'benchmark_minimal_v135_r1','physics_hz':m['physics_hz'],'camera_mode':'V0_PHYSICS_FOLLOW','source_hashes':m['expected_source_hashes'],'engine_identity':m['engine_identity'],'capture_manifest_sha256':file_hash(directory/'manifest.json'),'capture_audit_sha256':file_hash(directory/'virtual_audit.json'),'frames':frames,'reference_ticks':audit['ticks'],'tape_content_sha256':content,'scenario_id':receipt['scenario_id'],'scenario_catalog_sha256':file_hash(CATALOG),'source_receipt':receipt['run_id'],'source_input_lane':'ADAPTIVE_CAPTURE_SOURCE_NOT_A_FIXED_REPLAY','onset_certificate':s.get('onset_certificate',{}),'diagnostic_only':s.get('onset_certificate',{}).get('onset_tick') is None}
    path=BASE/'tapes'/f"{receipt['scenario_id']}_{m['physics_hz']}.json"
    if path.exists():raise FileExistsError(path)
    atomic_json(path,tape);return path
