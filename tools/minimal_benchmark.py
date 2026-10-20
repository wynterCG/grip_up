"""Single-worker v1.3.5 MBQ campaign. Historical campaigns are read-only inputs."""
from __future__ import annotations
import argparse
import copy
import json
import shutil
import subprocess
import sys
import math
import time
import uuid
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/'tools'),str(ROOT/'tools/auto_tuning'),str(ROOT/'tools/auto_tuning/benchmark_qualification'),str(ROOT/'tools/auto_tuning/virtual_cursor')]
from common import DEST,ENGINE,atomic_json,read_json,file_hash,digest,source_hashes,git_identity,engine_identity,utc_now,StudyLock
from candidate_schema import baseline,parameter_resource
from run_trial import make_candidate
from minimal_v135 import engine as e
from comparison import compare_required
import campaign as historical
import benchmark_r3 as r3

B=e.BASE;D=e.DOC;CAT=e.CATALOG;TRANSFER=e.TRANSFER
TRAIN=['vertical_pull_clean_v134_r2','lateral_clean_right_v134_r2']
HELPERS=['tools/minimal_benchmark.py','tools/project.py','tools/run_contextual_vault.py','tools/benchmark_safety.py','tools/benchmark_r3.py','tools/virtual_cursor_native_safety.py','tools/virtual_cursor_report.py']
parameters=None
current_phase=''

def helper_hashes():return {p:file_hash(ROOT/p) for p in HELPERS}

def guard(source=None):
    s=source or read_json(B/'source_identity.json')
    if source_hashes()!=s['source_hashes'] or source_hashes(DEST)!=s['source_hashes']:raise ValueError('MEASURED_SOURCE_CHANGED')
    if helper_hashes()!=s['helper_hashes']:raise ValueError('MEASURED_HELPER_CHANGED')
    if engine_identity()!=s['engine_identity']:raise ValueError('ENGINE_CHANGED')
    if file_hash(D/'run_plan.json')!=s['run_plan_sha256']:raise ValueError('RUN_PLAN_CHANGED')
    for v in s['tapes'].values():
        if file_hash(Path(v['path']))!=v['sha256']:raise ValueError('HISTORICAL_REFERENCE_TAPE_CHANGED')
    for v in read_json(D/'run_plan.json').get('protected_public_tapes',{}).values():
        if file_hash(Path(v['path']))!=v['sha256']:raise ValueError('HISTORICAL_PROTECTED_TAPE_CHANGED')
    protected=read_json(D/'baseline_audit.json')
    for p,h in protected['protected_hashes'].items():
        if file_hash(ROOT/p)!=h or file_hash(DEST/p)!=h:raise ValueError('PROTECTED_GAMEPLAY_CHANGED:'+p)
    for p,h in protected['external_protected'].items():
        if file_hash(Path(p))!=h:raise ValueError('EXTERNAL_PROTECTED_CHANGED:'+p)
    return s

def freeze():
    assert not (B/'source_identity.json').exists(),'Source is immutable after registration'
    s={**git_identity(),'source_hashes':source_hashes(),'helper_hashes':helper_hashes(),'engine_identity':engine_identity(),'run_plan_sha256':file_hash(D/'run_plan.json'),'tapes':read_json(D/'run_plan.json')['reference_tapes'],'dirty_tree_policy':'Exact public source/helper bytes frozen; generated evidence may change working-tree status. No gameplay writes.','budget_ledger':'MINIMAL_V135_PROSPECTIVE'}
    s['snapshot_sha256']=digest({'source_hashes':s['source_hashes'],'helper_hashes':s['helper_hashes']})
    guard(s)
    atomic_json(B/'source_identity.json',s);atomic_json(D/'source_identity.json',s)
    import virtual_cursor_report as ar
    ar.DOC=D;index={};ar.source_archive('measured_source_v135',s['repository_commit'],{**s['source_hashes'],**s['helper_hashes']},index)
    atomic_json(D/'source_archive_index.json',index)
    print('FROZEN',s['snapshot_sha256'],flush=True)

def tape_check(path,hz,source,scenario,negative=False):
    if scenario=='swing_catch_train':return historical.tape_check(path,hz,source,scenario,negative)
    tape=read_json(path)
    old=read_json(D/'run_plan.json').get('protected_public_tapes',{}).get(f'{scenario}:{hz}')
    if old is not None and str(path)==old['path']:
        if file_hash(path)!=old['sha256'] or tape['benchmark']!='fixture_feasibility_v134' or tape['scenario_id']!=scenario or tape['scenario_catalog_sha256']!=old['catalog_sha256'] or digest(tape['source_hashes'])!=old['source_map_sha256']:raise ValueError('PROTECTED_HISTORICAL_TAPE_IDENTITY')
        if current_phase!='finalist_protected':raise ValueError('PROTECTED_TAPE_OUTSIDE_FINALIST_STAGE')
    elif tape['benchmark']!='benchmark_minimal_v135_r1' or tape['scenario_id']!=scenario or tape['scenario_catalog_sha256']!=file_hash(CAT) or tape['source_hashes']!=source['source_hashes']:raise ValueError('MINIMAL_TAPE_SOURCE_CATALOG')
    if tape['physics_hz']!=hz or tape['engine_identity']!=source['engine_identity'] or tape['camera_mode']!='V0_PHYSICS_FOLLOW':raise ValueError('MINIMAL_TAPE_ENVIRONMENT')
    if tape.get('diagnostic_only') and not negative:raise ValueError('INVALID_ONSET_TAPE_NOT_SCORING')
    frames=copy.deepcopy(tape['frames'])
    for f in frames:f['tape_sha256']='CAPTURE_SOURCE_IDENTITY'
    if digest(frames)!=tape['tape_content_sha256'] or any(f['tape_sha256']!=tape['tape_content_sha256'] for f in tape['frames']):raise ValueError('TAPE_CONTENT_HASH')
    return tape

def manifest(scenario,hz,mode,run_id,directory,group,source,plan,tape_path=None,probe=True,negative=''):
    values=parameters if parameters is not None else baseline(parameter_resource())
    candidate=make_candidate(values,[scenario],trial_id=run_id,hz=hz,seed=101,timeout=100,provenance=source,input_trace_id='benchmark_minimal_v135_r1')
    m={'schema_version':'1.3.5','benchmark':'benchmark_minimal_v135_r1','run_id':run_id,'campaign_id':B.name,'phase':current_phase,'physics_hz':hz,'engine_mode':mode,'lane':'A','input_lane':'FIXED_TAPE' if tape_path else 'ADAPTIVE_CAPTURE','virtual_mode':'REPLAY' if tape_path else 'CAPTURE','scenario_ids':[scenario],'recorder_enabled':True,'existing_observer_enabled':True,'output_dir':str(directory),'run_seed':101,'expected_source_hashes':copy.deepcopy(source['source_hashes']),'code_commit':source['repository_commit'],'dirty_tree':source.get('repository_dirty',False),'engine_identity':source['engine_identity'],'timeout_s':100,'budget_group':group,'negative_case':negative,'local_override_sha256':'ABSENT','projection_config':{'window_size':[1024,576],'logical_viewport_size':[1920,1080],'probe_enabled':probe},'virtual_tape_sha256':'CAPTURE_SOURCE_IDENTITY','catalog_sha256':file_hash(CAT),'minimal_catalog_sha256':file_hash(CAT),'transfer_catalog_sha256':file_hash(TRANSFER),'run_plan_sha256':file_hash(D/'run_plan.json'),'baseline_candidate':candidate,'pick_contract_version':'1.3.4','source_snapshot_sha256':source['snapshot_sha256'],'dirty_tree_policy':source['dirty_tree_policy'],'budget_ledger':source['budget_ledger']}
    tape=None
    if tape_path:
        tape=tape_check(tape_path,hz,source,scenario,bool(negative))
        m.update(virtual_tape_path=str(tape_path),virtual_tape_sha256=file_hash(tape_path),projection_capture_source_hashes=tape['source_hashes'])
        if tape.get('benchmark')=='fixture_feasibility_v134':m['historical_feasibility_tape']=True
        m['capture_runtime_source_delta']={p:{'capture_sha256':tape['source_hashes'].get(p),'runtime_sha256':source['source_hashes'].get(p)} for p in sorted(tape['source_hashes'].keys()|source['source_hashes'].keys()) if tape['source_hashes'].get(p)!=source['source_hashes'].get(p)}
    return m,copy.deepcopy(tape)

def configure():
    e.identity=guard;e.build_manifest=manifest

def ledger():
    rows=[read_json(p) for p in (B/'attempts').glob('*/manifest.json')]
    batches=list((B/'final_batches').glob('*/batch.json'));capabilities=list((B/'capability_first_ascent').glob('*/manifest.json'))
    out={'limits':read_json(D/'run_plan.json')['budget_limits'],'single_process_attempts':len(rows),'groups':{g:sum(m['budget_group']==g for m in rows) for g in ['preflight','baseline','negative_canary','optimizer','finalist']},'batch_processes':len(batches),'capability_processes':len(capabilities),'episodes':len(rows)+2*len(batches)+len(capabilities),'evaluation_processes':len(rows)+len(batches)+len(capabilities),'process_count_policy':'Attempt manifest written before launch; aborts and retries consume slots; final batches have two independently admitted episodes.'}
    out['groups']['finalist']+=len(batches)+len(capabilities)
    out['prior_physical_preflight_failures']=read_json(D/'run_plan.json').get('prior_preflight_physical',0)
    out['cumulative_evaluation_processes']=out['evaluation_processes']+out['prior_physical_preflight_failures']
    assert out['cumulative_evaluation_processes']<=128 and out['groups']['finalist']<=48
    atomic_json(B/'budget_ledger.json',out);return out

def one(scenario,hz,mode,group,tape=None,negative='',values=None,phase=None):
    global parameters,current_phase
    parameters=values;current_phase=phase or group;configure()
    count=sum(read_json(p)['budget_group']==group for p in (B/'attempts').glob('*/manifest.json'))
    try:return e.execute(scenario,hz,mode,count+1,group,tape,negative=negative)
    finally:ledger();parameters=None

def valid_task(row):
    m=row.get('metrics',{})
    return row['status']=='RUN_VALID' and m.get('observation',{}).get('status')=='MEASURED' and m.get('task_succeeded') is True

def compare(a,b,label):
    result=compare_required(a['directory'],b['directory'])
    atomic_json(B/'comparisons'/f'{label}.json',result)
    return {'id':label,'status':result['status'],'left':a['run_id'],'right':b['run_id'],'first_difference':result.get('first_difference'),'first_by_layer':result.get('first_by_layer')}

def pure():
    configure();s=guard()
    # Reuse R3 exact transport generator with the full MBQ manifest and new driver.
    historical.build_manifest=manifest
    r3.DOC=D;r3.campaign=historical
    r3.ENGINE=ENGINE
    oldlaunch=r3.launch
    def launch(directory,command,timeout=30):
        command=[str(v).replace('test_r3_transport.gd','test_minimal_transport.gd') for v in command]
        command.append('--minimal-tuning')
        return oldlaunch(directory,command,timeout)
    r3.launch=launch
    passed=r3.transport(B,s)
    # Environment tests do not create gameplay bodies. Preserve all receipts.
    rows=[];target=B/'environment';target.mkdir(exist_ok=False)
    for hz,mode,resolution,declared,positive in [(h,m,'1024x576','1024x576',True) for h in [120,60] for m in ['headless','rendered_scripted']]+[(120,'headless','1440x810','1440x810',False),(120,'rendered_scripted','1440x810','1024x576',False)]:
        directory=target/f'{mode}_{hz}_{positive}';directory.mkdir()
        m,_=manifest('swing_catch_train',hz,mode,directory.name,directory,'preflight',s,read_json(D/'run_plan.json'),Path(s['tapes'][str(hz)]['path']))
        atomic_json(directory/'manifest.json',m)
        flags=['--headless','--fixed-fps','120'] if mode=='headless' else ['--screen','0','--position','80,80']
        code=launch(directory,[ENGINE,*flags,'--resolution',resolution,'--path',ROOT,'--script','res://features/evaluator_virtual_cursor/scripts/benchmark_preflight.gd','--','--manifest',directory/'manifest.json','--backing-size',declared,'--hz',str(hz),'--output',directory/'result.json'])
        result=read_json(directory/'result.json')
        ok=code==(0 if positive else 1) and result['status']==('PREFLIGHT_PASS' if positive else 'ENVIRONMENT_NOT_COMPARABLE') and result['gameplay_bodies_created']==0
        if positive:ok=ok and result['actual_size']==[1024,576] and result['clock_samples'][-2:]==[1/hz]*2
        rows.append({'pass':ok,'hz':hz,'mode':mode,'positive':positive,'result':result})
    atomic_json(B/'pure_results.json',{'pass':passed and all(x['pass'] for x in rows),'environment':rows,'gameplay_worlds':0,'physical_launches':0,'source_snapshot':s['snapshot_sha256']})
    assert passed and all(x['pass'] for x in rows),'PURE_ADMISSION_FAILED'

def preflight():
    assert read_json(B/'pure_results.json')['pass']
    path=B/'preflight_session.json';assert not path.exists()
    session={'runs':[],'status':'RUNNING','reason':''}
    def save():atomic_json(path,session)
    save()
    for hz in [120,60]:
        r=one('swing_catch_train',hz,'headless','preflight',Path(guard()['tapes'][str(hz)]['path']))
        session['runs'].append(r);save()
        if r['status']!='RUN_VALID':session.update(status='NO_GO',reason=r['reason']);save();return
    for hz in [120,60]:
        for scenario in TRAIN:
            r=one(scenario,hz,'headless','preflight');session['runs'].append(r);save()
            if not valid_task(r):session.update(status='NO_GO',reason='CAPTURE_NOT_VALID:'+scenario+':'+r.get('reason',''));save();return
            e.capture_tape(r)
    for scenario in read_json(D/'run_plan.json').get('novel_capture_ids',['vertical_novel_v135_r1','right_novel_v135_r1']):
        r=one(scenario,120,'headless','preflight');session['runs'].append(r);save()
        if valid_task(r):e.capture_tape(r)
        # Held-out failure is disclosed; it never changes the training tapes.
    session.update(status='PREFLIGHT_PASS',reason='');save()

def baseline_matrix():
    assert read_json(B/'preflight_session.json')['status']=='PREFLIGHT_PASS'
    target=B/'baseline_session.json';assert not target.exists()
    session={'status':'RUNNING','runs':[],'pairs':[],'within_mode':[],'reason':''}
    def save():atomic_json(target,session)
    save()
    for hz in [120,60]:
        for scenario in TRAIN:
            first={};tape=B/'tapes'/f'{scenario}_{hz}.json'
            for repeat in [1,2,3]:
                pair=[]
                for mode in ['headless','rendered_scripted']:
                    r=one(scenario,hz,mode,'baseline',tape);session['runs'].append(r);save()
                    if not valid_task(r):session.update(status='NO_GO_MINIMAL_BENCHMARK',reason='MANDATORY_BASELINE_CELL:'+r['run_id']);save();return
                    pair.append(r)
                    if mode in first:
                        comparison=compare(first[mode],r,f'within_{scenario}_{hz}_{mode}_{repeat}');session['within_mode'].append(comparison)
                        if comparison['status']!='STRICT_MATCH':session.update(status='NO_GO_MINIMAL_BENCHMARK',reason='WITHIN_MODE_NOT_STRICT');save();return
                    else:first[mode]=r
                comparison=compare(*pair,f'pair_{scenario}_{hz}_{repeat}');session['pairs'].append(comparison);save()
                if comparison['status']!='STRICT_MATCH':session.update(status='NO_GO_MINIMAL_BENCHMARK',reason='BASELINE_PAIR_NOT_STRICT');save();return
    session['status']='BASELINE_MATRIX_PASS_REVIEW_REQUIRED';save()

def n1_tape(hz):
    path=B/'negative_tapes'/f'N1_{hz}.json';assert not path.exists()
    original=Path(guard()['tapes'][str(hz)]['path']);t=read_json(original)
    for i,f in enumerate(t['frames'][:4],1):
        f['aim_valid']=i>=3;f['aim_position_viewport_px']=[0.,0.];f['strengths']['grip_left']=1. if i in [1,3] else 0.;f['button_edges']=[{'hand':0,'pressed':i in [1,3]}]
    for f in t['frames']:f['tape_sha256']='CAPTURE_SOURCE_IDENTITY'
    content=digest(t['frames'])
    for f in t['frames']:f['tape_sha256']=content
    t.update(tape_content_sha256=content,diagnostic_only=True,original_tape_sha256=file_hash(original),derivation='N1_INVALID_AIM_LOGICAL_SUPPRESSION_REAL_DISPATCH')
    atomic_json(path,t);return path

def negatives():
    assert read_json(B/'baseline_session.json')['status']=='BASELINE_MATRIX_PASS_REVIEW_REQUIRED'
    target=B/'negative_session.json';assert not target.exists()
    session={'status':'RUNNING','runs':[],'reason':'','canary':{}}
    def save():atomic_json(target,session)
    save()
    for hz in [120,60]:
        r=one('swing_catch_train',hz,'headless','negative_canary',n1_tape(hz),negative='N1');session['runs'].append(r);save()
        view=read_json(Path(r['directory'])/'python_pick_dispatch_contract.json') if r['status']=='RUN_VALID' else {}
        checks=r['engine_result'].get('negative_checks',[])
        if r['status']!='RUN_VALID' or len(checks)!=9 or not all(x['pass'] for x in checks) or [view.get(k) for k in ['logical_count','dispatch_count','ray_count','suppressed_count']]!=[4,3,9,1]:session.update(status='NO_GO',reason='N1_FAILED');save();return
    impaired=read_json(D/'run_plan.json')['canary_parameters'];base=read_json(B/'baseline_session.json')['runs']
    for scenario in TRAIN:
        rows=[]
        for repeat in [1,2]:
            r=one(scenario,120,'headless','negative_canary',B/'tapes'/f'{scenario}_120.json',values=impaired,phase='impaired_canary');rows.append(r);session['runs'].append(r);save()
            if r['status']!='RUN_VALID':session.update(status='NO_GO',reason='CANARY_INFRASTRUCTURE_OR_SAFETY');save();return
        baseline_value=next(r['metrics']['signed_progress_m'] for r in base if r['scenario_id']==scenario and r['hz']==120 and r['mode']=='headless')
        detectable=all(valid_task(r) and baseline_value-r['metrics']['signed_progress_m']>=max(.010,.05*baseline_value) for r in rows)
        session['canary'][scenario]={'continuous_sensitivity_demonstrated':detectable,'baseline':baseline_value,'values':[r['metrics'].get('signed_progress_m') for r in rows],'task_valid':[valid_task(r) for r in rows]};save()
    for scenario in ['asymmetric_pull_clean_v134_r2','lateral_clean_left_v134_r2']:
        r=one(scenario,60,'headless','negative_canary',phase='public_known_failure_diagnostic');session['runs'].append(r);save()
        if r['status']!='RUN_VALID':session.update(status='NO_GO',reason='DIAGNOSTIC_INFRASTRUCTURE_OR_SAFETY');save();return
        observation=r['metrics'].get('observation',{})
        expected='GROUND_CLEARANCE_NOT_CERTIFIED' if scenario=='asymmetric_pull_clean_v134_r2' else 'NATIVE_GROUND_AUTHORITY_CHANGED_TASK'
        interruption=observation.get('interruption',{}).get('tick')
        if observation.get('status')!='INTERRUPTED' or observation.get('reason_code')!=expected or interruption is None:
            session.update(status='NO_GO',reason='DECLARED_PHYSICAL_NEGATIVE_PATH_NOT_EXERCISED:'+scenario);save();return
        if scenario=='lateral_clean_left_v134_r2':
            raw=read_json(Path(r['directory'])/'benchmark_audit.json')['ticks'][interruption-1]
            if not raw['benchmark_extra']['native_ground_authority']:
                session.update(status='NO_GO',reason='GROUND_NEGATIVE_LACKS_ACTUAL_AUTHORITY');save();return
    sensitive=any(x['continuous_sensitivity_demonstrated'] for x in session['canary'].values())
    # Deliberate corruption of actual captured evidence tests the real validator.
    from pick_contract import validate_stream
    from projection_comparison import load_picks
    original=Path(base[0]['directory']);audit=read_json(original/'benchmark_audit.json');picks=load_picks(original)
    controls=[]
    for label,altered in [('missing_sidecar',picks[1:]),('duplicate_sidecar',picks+[copy.deepcopy(picks[0])])]:
        reason=''
        try:validate_stream(audit['ticks'],altered,base[0]['run_id'],completed=True,expected_tick_count=len(audit['frames']),strict_new=True)
        except ValueError as error:reason=str(error)
        controls.append({'case':label,'pass':bool(reason),'reason':reason,'source_directory':str(original),'corruption':'READ_ONLY_COPY_NO_PHYSICS'})
    pending=[h for r in audit['ticks'] for h in r['hands'] if h['state'] not in ['ATTACHED','SLIPPING']]
    controls.append({'case':'free_pending_zero_force','pass':bool(pending) and all(sum(x*x for x in h['force_n'])==0 for h in pending),'observations':len(pending),'source_directory':str(original)})
    atomic_json(B/'raw_negative_contracts.json',{'pass':all(c['pass'] for c in controls),'controls':controls,'extra_physical_processes':0})
    if not all(c['pass'] for c in controls):session.update(status='NO_GO',reason='RAW_NEGATIVE_CONTRACT_FAILED');save();return
    session.update(status='NEGATIVES_PASS_REVIEW_REQUIRED' if sensitive else 'NO_GO',reason='' if sensitive else 'CONTINUOUS_CANARY_SENSITIVITY_NOT_DEMONSTRATED');save()

def gate():
    s=guard();base=read_json(B/'baseline_session.json');neg=read_json(B/'negative_session.json')
    approved=base['status']=='BASELINE_MATRIX_PASS_REVIEW_REQUIRED' and neg['status']=='NEGATIVES_PASS_REVIEW_REQUIRED'
    for role in ['physics','measurement']:
        p=D/f'specialist/{role}_signoff.json'
        approved=approved and p.exists() and read_json(p).get('source_snapshot_sha256')==s['snapshot_sha256'] and read_json(p).get('status')=='APPROVED_FOR_TWO_DOMAIN_SEARCH'
        if role=='measurement':approved=approved and (D/'quality_contract.json').exists() and p.exists() and read_json(p).get('quality_contract_sha256')==file_hash(D/'quality_contract.json') and (B/'optimizer_reference.json').exists() and read_json(p).get('optimizer_reference_sha256')==file_hash(B/'optimizer_reference.json')
    result={'status':'GO_MINIMAL_BENCHMARK' if approved else 'NO_GO_MINIMAL_BENCHMARK','source_snapshot_sha256':s['snapshot_sha256'],'quality_contract_sha256':file_hash(D/'quality_contract.json') if (D/'quality_contract.json').exists() else None,'optimizer_reference_sha256':file_hash(B/'optimizer_reference.json') if (B/'optimizer_reference.json').exists() else None,'review_sha256':{role:file_hash(D/f'specialist/{role}_signoff.json') if (D/f'specialist/{role}_signoff.json').exists() else None for role in ['physics','measurement']},'baseline_status':base['status'],'negative_status':neg['status'],'reason':neg.get('reason') or base.get('reason') or ('INDEPENDENT_REVIEW_REQUIRED' if not approved else ''),'default_promotion':False}
    atomic_json(D/'mb2_gate.json',result);print(result['status'],result['reason'],flush=True)

def quality_reference():
    rows=read_json(B/'baseline_session.json')['runs']
    reference={'lane':'FIXED_TAPE','physics_hz':120,'run_valid':True,'source_identity_ok':True,'teardown_ok':True,'hard_invariants_pass':True,'scenarios':{}}
    contract={'frozen':True,'frozen_utc':utc_now(),'source_snapshot_sha256':guard()['snapshot_sha256'],'tasks':{},'scope':'Prospective gameplay floors or twice fresh A0 max-minus-min repeat range; deterministic tape repetitions are not independent skill samples. Twist unavailable is NOT_APPLICABLE, never zero.'}
    for scenario in TRAIN:
        selected=[r for r in rows if r['scenario_id']==scenario and r['hz']==120 and r['mode']=='headless']
        assert len(selected)==3 and all(valid_task(r) for r in selected)
        prior=copy.deepcopy(selected[0]['metrics']);reference['scenarios'][scenario]=prior;rules={}
        for name,direction,floor in [('directional_efficiency','maximize',.05),('backwards_excursion_m','minimize',.005),('off_axis_excursion_m','minimize',.005),('latency_to_useful_motion_s','minimize',max(2/120,.15*(prior['metrics']['latency_to_useful_motion_s']['value'] or 0))),('twist_rms_rad','minimize',.03)]:
            metrics=[r['metrics']['metrics'][name] for r in selected]
            measured=[m['value'] for m in metrics if m['status']=='MEASURED']
            allowed=[{'status':m['status'],'reason_code':m['reason_code']} for m in metrics if m['status']!='MEASURED']
            rules[name]={'direction':direction,'max_worsening':max(floor,2*(max(measured)-min(measured)) if measured else 0),'allowed_missing':allowed,'baseline_repeat_range':max(measured)-min(measured) if measured else None}
        contract['tasks'][scenario]=rules
    return reference,contract

def validation_quality(primary):
    """Full per-frequency matched differences; no aggregate can erase a loss."""
    contract=read_json(D/'quality_contract.json');out=[]
    for hz in [120,60]:
        for scenario in TRAIN:
            runs=[r for r in primary if r['hz']==hz and r['scenario_id']==scenario and r['mode']=='headless']
            assert len(runs)==6
            a,c=runs[0]['metrics'],runs[3]['metrics']
            delta=c['signed_progress_m']-a['signed_progress_m'];loss=max(.005,.03*abs(a['signed_progress_m']))
            reasons=[]
            if delta < -loss:reasons.append('PROGRESS_REGRESSION')
            for name,rule in contract['tasks'][scenario].items():
                am,cm=a['metrics'][name],c['metrics'][name]
                if am['status']=='MEASURED' and cm['status']=='MEASURED':
                    tolerance=rule['max_worsening']
                    if name=='latency_to_useful_motion_s':tolerance=max(tolerance,2/hz,.15*am['value'])
                    worsening=(cm['value']-am['value'])*(1 if rule['direction']=='minimize' else -1)
                    if worsening>tolerance:reasons.append('QUALITY_REGRESSION:'+name)
                elif (am['status'],am['reason_code'])!=(cm['status'],cm['reason_code']):reasons.append('LOST_QUALITY_MEASUREMENT:'+name)
            out.append({'hz':hz,'scenario':scenario,'paired_progress_delta_m':delta,'practical_gain':delta>=max(.010,.05*abs(a['signed_progress_m'])),'pass':not reasons,'reasons':reasons})
    return {'pass':all(r['pass'] for r in out) and all(any(r['practical_gain'] for r in out if r['hz']==h) for h in [120,60]),'cells':out}

def search(stage=None,resume=False):
    qualified=read_json(D/'mb2_gate.json');assert qualified['status']=='GO_MINIMAL_BENCHMARK','MB2 GO required'
    assert qualified['source_snapshot_sha256']==guard()['snapshot_sha256'],'Cached GO source differs'
    for key,path in [('quality_contract_sha256',D/'quality_contract.json'),('optimizer_reference_sha256',B/'optimizer_reference.json')]:
        assert qualified.get(key)==file_hash(path),'Cached GO reviewed artifact differs: '+key
    for role in ['physics','measurement']:
        assert qualified['review_sha256'][role]==file_hash(D/f'specialist/{role}_signoff.json'),'Cached GO review changed'
    directory=B/'optimizer';assert resume or not (directory/'study.sqlite3').exists(),'Use --resume for exact identity and ledger audit'
    refpath=B/'optimizer_reference.json';qpath=D/'quality_contract.json'
    assert refpath.exists() and qpath.exists(),'Freeze realized baseline quality contract and obtain independent sign-off BEFORE search'
    reference=read_json(refpath);contract=read_json(qpath)
    if stage in ['random','tpe']:
        state=read_json(directory/'pilot_state.json')
        minimum=8 if stage=='random' else 14
        assert len(state.get('records',[]))>=minimum,'Prior phase receipts required; no skipped prerequisites'
    identity={'source_snapshot_sha256':guard()['snapshot_sha256'],'engine_identity':guard()['engine_identity'],'catalog_sha256':file_hash(CAT),'registry_sha256':file_hash(ROOT/'features/auto_tuning_lab/resources/parameter_space.json'),'score_contract_sha256':file_hash(qpath),'backing':[1024,576],'logical':[1920,1080],'physics_hz':120,'seed':135101,'tapes':{s:file_hash(B/'tapes'/f'{s}_120.json') for s in TRAIN},'ordered_schedule':{'sensitivity':8,'random':6,'tpe':4}}
    def evaluate(values,phase,attemptid):
        rows=[]
        for scenario in TRAIN:
            row=one(scenario,120,'headless','optimizer',B/'tapes'/f'{scenario}_120.json',values=values,phase=phase);rows.append(row)
            if row['status']!='RUN_VALID':raise RuntimeError('INFRASTRUCTURE_OR_SAFETY_STOP:'+row['directory'])
        envelope={'lane':'FIXED_TAPE','physics_hz':120,'run_valid':all(r['status']=='RUN_VALID' for r in rows),'source_identity_ok':True,'teardown_ok':all(r.get('engine_result',{}).get('restoration',{}).get('resources',{}).get('originals_preserved') is True for r in rows),'hard_invariants_pass':all(not any(r.get('engine_result',{}).get('scenarios',[{}])[0].get('invariants',{}).values()) for r in rows),'scenarios':{r['scenario_id']:r['metrics'] for r in rows},'raw_receipts':[r['directory'] for r in rows]}
        atomic_json(B/'candidate_receipts'/f'{attemptid}.json',{'values':values,'phase':phase,'envelope':envelope,'runs':rows})
        return envelope
    from minimal_v135.pilot import run
    result=run(directory,identity,parameter_resource(),{'decision':'GO_MINIMAL_BENCHMARK','identity_sha256':digest(identity)},reference,contract,evaluate,stop_after=stage)
    atomic_json(D/'search_result.json',result)
    return result

def first_ascent_capability(values,hz,shortlist):
    """Existing private essential capability is opened only after frozen finalist."""
    assert read_json(D/'mb2_gate.json')['status']=='GO_MINIMAL_BENCHMARK' and shortlist
    from run_trial import run_trial
    private=ROOT/'features/auto_tuning_lab/holdout/scenarios.json'
    access=B/'capability_holdout_access.json'
    if not access.exists():atomic_json(access,{'authorized_after_shortlist_utc':utc_now(),'shortlist_sha256':digest(shortlist),'purpose':'FIRST_ASCENT_CAPABILITY_ONLY_NOT_REWARD'})
    catalog=read_json(private)
    definition=next(d for d in catalog['scenarios'] if d.get('implementation_id',d['id'])=='first_ascent')
    source=guard();source={**source,'source_hashes':source_hashes(include_holdout=True)}
    freeze={'frozen':True,'frozen_at_utc':utc_now(),'candidates':shortlist,'baseline':{'candidate_id':__import__('candidate_schema').candidate_id(baseline(parameter_resource())),'parameter_overrides':baseline(parameter_resource())},'provenance':{'repository_commit':source['repository_commit'],'engine_identity':source['engine_identity'],'source_hashes':source['source_hashes']},'training_repeat_validation':{'passed':True,'repeats_per_frequency':3,'frequencies':[60,120]}}
    freeze['freeze_sha256']=digest(freeze)
    path=B/'capability_freezes'/f'{uuid.uuid4().hex}.json';atomic_json(path,freeze)
    candidate=make_candidate(values,[definition['id']],trial_id=f'capability_ascent_{hz}_{uuid.uuid4().hex[:8]}',hz=hz,split='holdout',provenance=source,input_trace_id=catalog['input_trace_id'])
    outcome,directory=run_trial(candidate,B/'capability_first_ascent',shortlist_path=path)
    ledger()
    return {'status':outcome['status'],'completed':outcome.get('engine_result',{}).get('scenarios',[{}])[0].get('completed') is True,'directory':str(directory),'scope':'Non-training existing FirstAscent/hybrid route; no continuous reward'}

def batch_pair(tasks,hz,mode,values,label):
    """Exactly two independent scored episodes; one owned engine process."""
    global parameters,current_phase
    s=guard();configure();parameters=values;current_phase='finalist'
    prior=list((B/'final_batches').glob('*/batch.json'))
    assert len(prior)<24,'24 primary batch processes reserved; no slot transfer'
    directory=B/'final_batches'/f'{label}_{uuid.uuid4().hex[:8]}';directory.mkdir(parents=True,exist_ok=False)
    entries=[];prepared=[]
    try:
        for index,scenario in enumerate(tasks):
            d=directory/f'episode_{index+1}';d.mkdir();run_id=f'final_{scenario}_{hz}_{mode}_{uuid.uuid4().hex[:8]}'
            m,t=manifest(scenario,hz,mode,run_id,d,'finalist',s,read_json(D/'run_plan.json'),B/'tapes'/f'{scenario}_{hz}.json')
            atomic_json(d/'manifest.json',m);atomic_json(d/'serialized_projection_config.json',m['projection_config'])
            entries.append({'manifest':str(d/'manifest.json'),'result':str(d/'engine_result.json')});prepared.append((d,m,t))
    finally:parameters=None
    atomic_json(directory/'batch.json',{'episodes':entries,'receipt':str(directory/'batch_receipt.json'),'processes':1,'episodes_count':2,'reserved_utc':utc_now()})
    flags=['--headless','--fixed-fps','120'] if mode=='headless' else ['--screen','0','--position','80,80']
    command=[str(ENGINE),*flags,'--resolution','1024x576','--path',str(ROOT),'--script','res://features/evaluator_virtual_cursor/scripts/minimal_batch_runner.gd','--','--batch-manifest',str(directory/'batch.json'),'--backing-size','1024x576','--virtual-cursor-evaluator','--benchmark-qualification','--minimal-tuning','--validate-shortlist']
    atomic_json(directory/'execution.json',{'command':command,'workers':1,'utc':utc_now()})
    started=time.monotonic()
    code=r3.launch(directory,command,240)
    receipt=read_json(directory/'batch_receipt.json') if (directory/'batch_receipt.json').exists() else {}
    rows=[]
    for d,m,t in prepared:
        for name in ['stdout.txt','stderr.txt']:shutil.copy2(directory/name,d/name)
        row=e.audit_execution(d,m['scenario_ids'][0],hz,mode,1,'finalist',s,m,t,started,code)
        clean=row['engine_result'].get('batch_boundary',{}).get('cleanup_pass')
        if receipt.get('status')!='PASS' or clean is not True:row.update(status='RUN_INVALID',reason='BATCH_CLEANUP_OR_EPISODE_FAILURE')
        atomic_json(d/'receipt.json',row);rows.append(row)
    ledger()
    return rows

def validate_shortlist():
    assert read_json(D/'mb2_gate.json')['status']=='GO_MINIMAL_BENCHMARK'
    result=read_json(D/'search_result.json')
    shortlist=result.get('shortlist',[])
    assert len(shortlist)==1,'Only one prospectively budgeted finalist'
    values=shortlist[0]['parameter_overrides'];target=B/'finalist_session.json';assert not target.exists()
    session={'status':'RUNNING','primary':[],'protected':[],'pairs':[],'reason':''}
    protected_matched={}
    def save():atomic_json(target,session)
    save()
    for name,params in [('A0',baseline(parameter_resource())),('candidate',values)]:
        for hz in [120,60]:
            first={}
            for repeat in [1,2,3]:
                modes={}
                for mode in ['headless','rendered_scripted']:
                    rows=batch_pair(TRAIN,hz,mode,params,f'{name}_{hz}_{mode}_r{repeat}');session['primary']+=rows;save()
                    if not all(valid_task(r) for r in rows):session.update(status='CANDIDATE_VALIDATION_FAILED',reason='PRIMARY_TASK_OR_BATCH_FAILURE');save();return
                    modes[mode]=rows
                    for r in rows:
                        key=(mode,r['scenario_id'])
                        if key in first:
                            pair=compare(first[key],r,f'final_within_{name}_{hz}_{mode}_{repeat}_{r["scenario_id"]}');session['pairs'].append(pair)
                            if pair['status']!='STRICT_MATCH':session.update(status='CANDIDATE_VALIDATION_FAILED',reason='BATCH_WITHIN_MODE_DIVERGENCE');save();return
                        else:first[key]=r
                for a,b in zip(modes['headless'],modes['rendered_scripted']):
                    pair=compare(a,b,f'final_pair_{name}_{hz}_{repeat}_{a["scenario_id"]}');session['pairs'].append(pair)
                    if pair['status']!='STRICT_MATCH':session.update(status='CANDIDATE_VALIDATION_FAILED',reason='FINAL_HR_DIVERGENCE');save();return
    quality=validation_quality(session['primary']);session['quality']=quality;save()
    if not quality['pass']:session.update(status='CANDIDATE_VALIDATION_FAILED',reason='FINAL_MATCHED_PERFORMANCE_OR_QUALITY');save();return
    # Public protected probes: identical inputs for A0/candidate, never optimizer rewards.
    for name,params in [('A0',baseline(parameter_resource())),('candidate',values)]:
        for hz in [120,60]:
            catch=[]
            for mode in ['headless','rendered_scripted']:
                row=one('swing_catch_train',hz,mode,'finalist',Path(guard()['tapes'][str(hz)]['path']),values=params,phase='finalist_protected');session['protected'].append(row);save()
                if row['status']!='RUN_VALID':session.update(status='CANDIDATE_VALIDATION_FAILED',reason='PROTECTED_CATCH_FAILED');save();return
                catch.append(row)
            pair=compare(*catch,f'protected_catch_{name}_{hz}');session['pairs'].append(pair);save()
            if pair['status']!='STRICT_MATCH':session.update(status='CANDIDATE_VALIDATION_FAILED',reason='PROTECTED_CATCH_PARITY');save();return
        for scenario,hz in [('vertical_novel_v135_r1',120),('right_novel_v135_r1',120),('two_hand_release_stop_v134_r2',120),('two_hand_release_stop_v134_r2',60),('asymmetric_pull_clean_v134_r2',120),('lateral_clean_left_v134_r2',120)]:
            old=read_json(D/'run_plan.json').get('protected_public_tapes',{}).get(f'{scenario}:{hz}')
            tape=Path(old['path']) if old else B/'tapes'/f'{scenario}_{hz}.json'
            if not tape.exists():
                # A new-start family with no budgeted tape cannot establish transfer.
                if scenario=='right_novel_v135_r1':
                    session['protected'].append({'scenario':scenario,'hz':hz,'mode':name,'status':'NOT_RUN','reason':'NOVEL_CAPTURE_BUDGET_CONSUMED_BY_PREFLIGHT_REPAIR','generalization':'NOT_TESTED'});save();continue
                session.update(status='CANDIDATE_VALIDATION_FAILED',reason='PROMISED_PROTECTED_TAPE_MISSING:'+scenario);save();return
            row=one(scenario,hz,'headless','finalist',tape,values=params,phase='finalist_protected');session['protected'].append(row);save()
            if not valid_task(row):session.update(status='CANDIDATE_VALIDATION_FAILED',reason='PROTECTED_TASK_FAILED:'+scenario);save();return
            key=(scenario,hz)
            if name=='A0':protected_matched[key]=row['metrics']
            else:
                prior=protected_matched[key];now=row['metrics'];reasons=[]
                checks=[('stop_path_3d_m',.005,.05),('settling_time_s',2/hz,.15),('overshoot_after_release_m',.005,.05)] if scenario=='two_hand_release_stop_v134_r2' else []
                for metric,floor,fraction in checks:
                    a,c=prior['metrics'][metric],now['metrics'][metric]
                    if a['status']!='MEASURED' or c['status']!='MEASURED' or c['value']-a['value']>max(floor,fraction*abs(a['value'])):reasons.append('PROTECTED_QUALITY_REGRESSION:'+metric)
                if not checks and now['signed_progress_m']<prior['signed_progress_m']-max(.005,.03*abs(prior['signed_progress_m'])):reasons.append('PROTECTED_PROGRESS_REGRESSION')
                if reasons:session.update(status='CANDIDATE_VALIDATION_FAILED',reason=';'.join(reasons));save();return
        for hz in [120,60]:
            row=first_ascent_capability(params,hz,shortlist);session['protected'].append(row);save()
            if row['status']!='completed' or not row['completed']:session.update(status='CANDIDATE_VALIDATION_FAILED',reason='FIRST_ASCENT_CAPABILITY_FAILED');save();return
    session.update(status='HUMAN_REVIEW_PENDING',reason='Final primary and protected evidence require independent review and separate human agreement');save()

def main():
    p=argparse.ArgumentParser();p.add_argument('stage',nargs='?',choices=['freeze','pure','preflight','baseline','negatives','quality-freeze','gate','search','validate']);p.add_argument('--preflight-only',action='store_true');p.add_argument('--baseline-only',action='store_true');p.add_argument('--sensitivity-only',action='store_true');p.add_argument('--random-only',action='store_true');p.add_argument('--tpe-only',action='store_true');p.add_argument('--validate-shortlist',action='store_true');p.add_argument('--resume',action='store_true');a=p.parse_args()
    if a.preflight_only:a.stage='preflight'
    if a.baseline_only:a.stage='baseline'
    if a.validate_shortlist:a.stage='validate'
    phase=next((name for name in ['sensitivity','random','tpe'] if getattr(a,name+'_only')),None)
    if phase:a.stage='search'
    if not a.stage:p.error('Choose an explicit stage')
    if a.stage=='freeze':return freeze()
    with StudyLock(ROOT/'builds/eval_virtual_cursor'):
        if a.stage=='search':return search(phase,a.resume)
        if a.stage=='quality-freeze':
            assert not (D/'quality_contract.json').exists()
            reference,contract=quality_reference();atomic_json(B/'optimizer_reference.json',reference);atomic_json(D/'quality_contract.json',contract);return
        return {'pure':pure,'preflight':preflight,'baseline':baseline_matrix,'negatives':negatives,'gate':gate,'validate':validate_shortlist}[a.stage]()

if __name__=='__main__':main()
