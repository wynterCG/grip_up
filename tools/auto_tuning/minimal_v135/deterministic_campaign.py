"""One isolated v135a campaign; legacy R4 artifacts are immutable inputs."""
from __future__ import annotations

import copy
import shutil
from pathlib import Path

from common import atomic_json, digest, file_hash, read_json, utc_now, StudyLock
from candidate_schema import baseline, parameter_resource, PARAMETER_IDS, parameter_rows
from .search import ProposalStudy, project_score, pareto, candidate_id, sensitivity_proposals

CAMPAIGN = 'minimal_v135a_r1'
PLAN = {'sensitivity': 4, 'random': 1, 'tpe': 0}
SENSITIVITY_INDICES = (1,2,4,6)
FREQUENCIES = (120, 60)
TRAIN = ('vertical_pull_clean_v134_r2', 'lateral_clean_right_v134_r2')
VERSION = 'deterministic_two_frequency_v135a_r1'


def require_environment(expected=None):
    from metric_binary64 import require_environment as check
    return check(expected)


def immutable(path, value):
    path = Path(path)
    if path.exists():
        raise FileExistsError(f'IMMUTABLE_ARTIFACT:{path}')
    atomic_json(path, value)


def prepare(app):
    """Freeze prospective budgets and authentic historical tape descriptors."""
    require_environment()
    if (app.D/'run_plan.json').exists():
        raise FileExistsError('PLAN_ALREADY_EXISTS')
    audit = read_json(app.D/'baseline_audit.json')
    if not audit:
        raise ValueError('MR0_AUDIT_REQUIRED')
    olddoc = app.ROOT/'docs/validation/auto_tuning/minimal_v135/r4'
    oldbase = app.ROOT/'builds/eval_virtual_cursor/minimal_v135_r4'
    old = read_json(olddoc/'run_plan.json')
    training = {}
    for hz in FREQUENCIES:
        for scenario in TRAIN:
            p = oldbase/'tapes'/f'{scenario}_{hz}.json'
            t = read_json(p)
            if (t['scenario_id'] != scenario or t['physics_hz'] != hz
                    or t['benchmark'] != 'benchmark_minimal_v135_r1'
                    or t['scenario_catalog_sha256'] != file_hash(app.CAT)):
                raise ValueError('HISTORICAL_TRAINING_IDENTITY')
            training[f'{scenario}:{hz}'] = {'path':str(p), 'sha256':file_hash(p),
                'source_map_sha256':digest(t['source_hashes']),
                'catalog_sha256':t['scenario_catalog_sha256'],
                'admission':'Exact immutable tape bytes; explicit capture/runtime source delta; fresh full replay required'}
            target = app.B/'tapes'/p.name
            target.parent.mkdir(parents=True,exist_ok=True)
            if target.exists():
                raise FileExistsError(target)
            shutil.copyfile(p,target)
    plan = {
        'id':CAMPAIGN, 'version':VERSION,
        'authorization':'GRIP_UP_Deterministic_Metric_Reduction_Auto_Tuning_v1_3_5a_EN.md',
        'frozen_before_results_utc':utc_now(),
        'reference_tapes':copy.deepcopy(old['reference_tapes']),
        'protected_public_tapes':copy.deepcopy(old['protected_public_tapes']),
        'historical_training_tapes':training,
        'historical_quality_policy':{'path':str(olddoc/'quality_contract.json'),
                                     'sha256':file_hash(olddoc/'quality_contract.json')},
        'historical_R4_decision':'NO_GO_MINIMAL_BENCHMARK_IMMUTABLE',
        'budget_limits':{'preflight':8,'baseline':24,'negative_canary':8,
            'optimizer':40,'optimizer_episodes':40,'finalist':24,'development':2,
            'regression':34,'total_evaluation':106},
        'max_qualification_attempts':106, 'prior_preflight_physical':0,
        'auxiliary_safety':{'physical_worlds_reserved':4,'scope':'normal startup/MCP LIVE/release smoke/isolated pack; never scoring'},
        'independent_regression':{'processes':34,'scope':'mandatory safety suite; never training'},
        'overall_physical_process_ceiling':144,
        'preflight_schedule':{'protected_catch_bothHz':2,'A0_candidate_dry_run_two_tasks_bothHz':4,
            'reserve':2,'pure_transport_environment':'separate zero-world process ledger'},
        'baseline_schedule':'2tasks x2Hz x3H/Rfixedpairs =24 processes;12H/R+16within-mode comparisons',
        'negative_schedule':copy.deepcopy(old['negative_schedule']),
        'canary_parameters':copy.deepcopy(old['canary_parameters']),
        'canary_gate':old['canary_gate'],
        'proposal_schedule':PLAN, 'processes_per_proposal':4,
        'optimizer_seed':135101, 'max_proposals':5,
        'sensitivity_indices':list(SENSITIVITY_INDICES),'confirmation_reserved_processes':20,
        'confirmation':'At most1; initial4H +20missingcells =24candidateprocesses,3H/R×4cells; no retry',
        'frequency_order':list(FREQUENCIES),'task_order':list(TRAIN),
        'tpe':'NOT_REACHED_BY_PREREGISTERED_BUDGET',
        'shortlist':'max1; all four cells; worst Hz per task; no averaging losses',
        'finalist_schedule':{'maximum':1,'process_limit':24,
            'catch_A0_candidate_HR_bothHz':8,'first_ascent_A0_candidate_bothHz':4,
            'stop_A0_candidate_bothHz':4,'asym_left_A0_candidate_120':4,
            'vertical_novel_A0_candidate_120':2,'right_independent_reserved':2,
            'right_independent_policy':'NOT_RUN unless existing certified tape is frozen in this plan; no replacement jobs'},
        'missing_required_coverage':['one_hand_hang_release_brake_60',
            'one_hand_hang_release_brake_certified_wrapper','right_independent_start'],
        'no_default_promotion':True,'no_scoring_holdouts':True,
        'global_stop':['metric','input','source','environment','physics','restore','mandatory_baseline'],
    }
    novel = oldbase/'tapes/vertical_novel_v135_r1_120.json'
    if novel.exists():
        t=read_json(novel)
        plan['protected_public_tapes']['vertical_novel_v135_r1:120']={
            'path':str(novel),'sha256':file_hash(novel),
            'catalog_sha256':t['scenario_catalog_sha256'],
            'source_map_sha256':digest(t['source_hashes']),
            'benchmark':t['benchmark']}
    immutable(app.D/'run_plan.json',plan)


def envelope(rows,hz):
    selected=[r for r in rows if r['hz']==hz]
    if len(selected)!=2 or {r['scenario_id'] for r in selected}!=set(TRAIN):
        raise ValueError('INCOMPLETE_FREQUENCY_CELL_SET')
    return {'lane':'FIXED_TAPE','physics_hz':hz,
        'run_valid':all(r['status']=='RUN_VALID' for r in selected),
        'source_identity_ok':True,
        'teardown_ok':all(r['engine_result']['restoration']['resources']['exact_originals_and_pointer_restore'] for r in selected),
        'hard_invariants_pass':all(not any(r['engine_result']['scenarios'][0].get('invariants',{}).values()) for r in selected),
        'scenarios':{r['scenario_id']:r['metrics'] for r in selected},
        'raw_receipts':[r['directory'] for r in selected]}


def quality_from_rows(rows,source_hash,*,repeats=3):
    reference={'version':VERSION,'by_hz':{}}
    quality={'version':VERSION,'frozen':True,'frozen_utc':utc_now(),
        'source_snapshot_sha256':source_hash,'by_hz':{},
        'scope':'Fresh A0 deterministic repeats, not independent starts; reasoned null is not zero'}
    for hz in FREQUENCIES:
        chosen=[];contract={'frozen':True,'tasks':{}}
        for scenario in TRAIN:
            samples=[r for r in rows if r['hz']==hz and r['scenario_id']==scenario and r['mode']=='headless']
            if len(samples)!=repeats or not all(r['status']=='RUN_VALID' and r['metrics'].get('task_succeeded') is True for r in samples):
                raise ValueError('FRESH_A0_REFERENCE_INCOMPLETE')
            chosen.append(samples[0]);prior=samples[0]['metrics'];rules={}
            latency=prior['metrics']['latency_to_useful_motion_s']
            latency_floor=max(2/hz,.15*abs(latency['value'])) if latency['status']=='MEASURED' else 2/hz
            for name,direction,floor in [('directional_efficiency','maximize',.05),
                    ('backwards_excursion_m','minimize',.005),('off_axis_excursion_m','minimize',.005),
                    ('latency_to_useful_motion_s','minimize',latency_floor),('twist_rms_rad','minimize',.03)]:
                ms=[r['metrics']['metrics'][name] for r in samples]
                measured=[m['value'] for m in ms if m['status']=='MEASURED']
                allowed=[{'status':m['status'],'reason_code':m['reason_code']} for m in ms if m['status']!='MEASURED']
                span=max(measured)-min(measured) if measured else None
                rules[name]={'direction':direction,'max_worsening':max(floor,2*span if span is not None else 0),
                    'allowed_missing':allowed,'baseline_repeat_range':span}
            contract['tasks'][scenario]=rules
        reference['by_hz'][str(hz)]=envelope(chosen,hz)
        quality['by_hz'][str(hz)]=contract
    return reference,quality


def score_all(candidate,reference,quality):
    """All four cells required; objectives are each task's worst Hz progress."""
    try:
        for value in (candidate,reference,quality):
            if set(value.get('by_hz',{}))!={'120','60'}:
                raise ValueError('MISSING_OR_EXTRA_FREQUENCY')
        scores={str(hz):project_score(candidate['by_hz'][str(hz)],reference['by_hz'][str(hz)],
            quality['by_hz'][str(hz)],physics_hz=hz) for hz in FREQUENCIES}
        reasons=[f'{hz}:{reason}' for hz,s in scores.items() for reason in s['reasons']]
        if any(s['disposition']=='STOP_STUDY' for s in scores.values()):disposition='STOP_STUDY'
        elif any(not s['eligible'] for s in scores.values()):disposition='REJECT_CANDIDATE'
        else:disposition='COMPLETE'
        eligible=disposition=='COMPLETE'
        values=[min(scores[str(hz)]['values'][i] for hz in FREQUENCIES) for i in range(2)] if eligible else None
        cells=[dict(cell,hz=int(hz)) for hz,s in scores.items() for cell in s['per_task']]
        return {'version':VERSION,'disposition':disposition,'eligible':eligible,'values':values,
            'reasons':reasons,'per_frequency':scores,'per_task':cells,
            'practical_gain':eligible and all(s['practical_gain'] for s in scores.values()),
            'scope':'two fixed tapes per Hz; worst Hz per task; no independent-start/feel claim'}
    except (ValueError,KeyError,TypeError,OverflowError) as exc:
        return {'version':VERSION,'disposition':'STOP_STUDY','eligible':False,'values':None,
                'reasons':[str(exc)],'practical_gain':False,'per_task':[]}


def require_certification(app):
    source=app.guard();c=read_json(app.D/'metric_contract_certification.json')
    if (c.get('status')!='CERTIFIED_METRIC_CONTRACT'
            or c.get('source_snapshot_sha256')!=source['snapshot_sha256']
            or c.get('python_environment_sha256')!=source['python_environment']['sha256']
            or c.get('metric_reducer_sha256')!=source['metric_reducer_sha256']):
        raise ValueError('METRIC_CONTRACT_NO_GO')
    return source


def sqlite_settings(storage):
    """Observe effective settings on one fresh connection, without changing them."""
    with storage.engine.connect() as connection:
        return {key:connection.exec_driver_sql('PRAGMA '+key).scalar() for key in
                ('journal_mode','synchronous','foreign_keys','busy_timeout')}


def preflight(app):
    source=require_certification(app)
    if not read_json(app.B/'pure_results.json')['pass']:raise ValueError('PURE_ADMISSION_REQUIRED')
    target=app.B/'preflight_session.json';session={'status':'RUNNING','runs':[],'reason':''}
    immutable(target,session)
    def save():atomic_json(target,session)
    try:
        for hz in FREQUENCIES:
            r=app.one('swing_catch_train',hz,'headless','preflight',Path(source['tapes'][str(hz)]['path']))
            session['runs'].append(r);save()
            if r['status']!='RUN_VALID':raise ValueError('PROTECTED_CATCH:'+r['reason'])
        rows=[]
        for hz in FREQUENCIES:
            for scenario in TRAIN:
                r=app.one(scenario,hz,'headless','preflight',app.B/'tapes'/f'{scenario}_{hz}.json',
                          values=baseline(parameter_resource()),phase='dry_run')
                session['runs'].append(r);rows.append(r);save()
                if not app.valid_task(r):raise ValueError('A0_CANDIDATE_DRY_RUN:'+r.get('reason',''))
        ref,quality=quality_from_rows(rows,source['snapshot_sha256'],repeats=1)
        score=score_all(ref,ref,quality)
        if not score['eligible']:raise ValueError('DRY_RUN_SCORER:'+str(score['reasons']))
        import optuna
        from sqlalchemy.pool import NullPool
        directory=app.B/'dry_run';directory.mkdir(exist_ok=False)
        storage=optuna.storages.RDBStorage('sqlite:///'+(directory/'study.sqlite3').resolve().as_posix(),engine_kwargs={'poolclass':NullPool})
        try:
            study=optuna.create_study(storage=storage,study_name=CAMPAIGN+'_A0_PIPELINE_ONLY',directions=['maximize']*2)
            values=baseline(parameter_resource());study.enqueue_trial(values);trial=study.ask()
            actual={key:trial.suggest_float(key,parameter_rows(parameter_resource())[key]['min'],parameter_rows(parameter_resource())[key]['max']) for key in PARAMETER_IDS}
            if actual!=values:raise ValueError('DRY_RUN_A0_OVERRIDE_CHANGED')
            trial.set_user_attr('python_environment_sha256',source['python_environment']['sha256'])
            trial.set_user_attr('score',score);study.tell(trial,values=score['values'])
            persisted=study.trials[0]
            if persisted.state!=optuna.trial.TrialState.COMPLETE or persisted.values!=score['values']:raise ValueError('DRY_RUN_SQLITE_READBACK')
            immutable(directory/'report.json',{'status':'A0_END_TO_END_PASS','score':score,'trial':persisted.number,
                'optimizer_started':False,'python_environment':require_environment(source['python_environment']),
                'source_snapshot_sha256':source['snapshot_sha256'],'rows':[r['directory'] for r in rows],
                'sqlite_connection_settings':sqlite_settings(storage),
                'sqlite_settings_scope':'Observed fresh SQLAlchemy connection; no PRAGMA assignment; connection-local settings are not global DB properties'})
        finally:
            storage.remove_session();storage.engine.dispose()
        app.guard();session.update(status='PREFLIGHT_PASS',reason='')
    except Exception as exc:
        session.update(status='METRIC_CONTRACT_NO_GO',reason=f'{type(exc).__name__}:{exc}')
    save()


def quality_freeze(app):
    source=app.guard()
    base=read_json(app.B/'baseline_session.json')
    if base['status']!='BASELINE_MATRIX_PASS_REVIEW_REQUIRED':raise ValueError('BASELINE_NOT_COMPLETE')
    reference,quality=quality_from_rows(base['runs'],source['snapshot_sha256'])
    immutable(app.B/'optimizer_reference.json',reference);immutable(app.D/'quality_contract.json',quality)


def verify_gate(app):
    source=require_certification(app);gate=read_json(app.D/'mb2_gate.json')
    if gate['status']!='GO_MINIMAL_BENCHMARK' or gate['source_snapshot_sha256']!=source['snapshot_sha256']:
        raise ValueError('CERTIFIED_FOR_LIMITED_SEARCH_REQUIRED')
    for key,path in [('quality_contract_sha256',app.D/'quality_contract.json'),('optimizer_reference_sha256',app.B/'optimizer_reference.json')]:
        if gate.get(key)!=file_hash(path):raise ValueError('CACHED_GO_ARTIFACT_CHANGED:'+key)
    for role in ('physics','measurement'):
        if gate['review_sha256'][role]!=file_hash(app.D/f'specialist/{role}_signoff.json'):raise ValueError('CACHED_GO_REVIEW_CHANGED')
    if read_json(app.B/'preflight_session.json')['status']!='PREFLIGHT_PASS' or read_json(app.B/'dry_run/report.json')['status']!='A0_END_TO_END_PASS':
        raise ValueError('END_TO_END_DRY_RUN_REQUIRED')
    return source


def reserve(reservations,attempt,*,confirmation=False):
    processes=20 if confirmation else 4
    if (not isinstance(attempt,str) or not attempt or any(r['attempt_id']==attempt for r in reservations)
            or sum(r.get('confirmation',False) is False for r in reservations)+(not confirmation)>5
            or confirmation and any(r.get('confirmation') for r in reservations)
            or sum(r['processes'] for r in reservations)+processes+(0 if confirmation else 20)>40):
        raise ValueError('PROPOSAL_OR_PROCESS_BUDGET_EXHAUSTED')
    row={'attempt_id':attempt,'processes':processes,'episodes':processes,'confirmation':confirmation,
         'cells':[[hz,s] for hz in FREQUENCIES for s in TRAIN]}
    reservations.append(row)
    return copy.deepcopy(row)


def search(app,stage=None,resume=False):
    if stage=='tpe':raise ValueError('TPE_NOT_REACHED_BY_PREREGISTERED_BUDGET')
    source=verify_gate(app);require_environment(source['python_environment'])
    directory=app.B/'optimizer';directory.mkdir(exist_ok=True)
    if (directory/'study.sqlite3').exists() and not resume:raise ValueError('EXPLICIT_EXACT_RESUME_REQUIRED')
    reference=read_json(app.B/'optimizer_reference.json');quality=read_json(app.D/'quality_contract.json')
    identity={'campaign_id':CAMPAIGN,'version':VERSION,'seed':135101,
        'source_snapshot_sha256':source['snapshot_sha256'],'python_environment':source['python_environment'],
        'metric_reducer_sha256':source['metric_reducer_sha256'],'plan_sha256':file_hash(app.D/'run_plan.json'),
        'quality_sha256':file_hash(app.D/'quality_contract.json'),'reference_sha256':file_hash(app.B/'optimizer_reference.json'),
        'schedule':PLAN,'sensitivity_indices':list(SENSITIVITY_INDICES),'confirmation_reserve':20,
        'cells':[[hz,s] for hz in FREQUENCIES for s in TRAIN]}
    manifestpath=directory/'pilot_manifest.json'
    if manifestpath.exists():
        if read_json(manifestpath)!=identity:raise ValueError('IMMUTABLE_PILOT_IDENTITY_CHANGED')
    else:immutable(manifestpath,identity)
    registry=parameter_resource();statepath=directory/'pilot_state.json'
    if statepath.exists():
        state=read_json(statepath)
        if state['identity_sha256']!=digest(identity) or state['status']!='RUNNING':raise ValueError('RESUME_IDENTITY_OR_TERMINAL_STUDY')
    else:
        state={'identity_sha256':digest(identity),'status':'RUNNING','records':[],'reservations':[]};immutable(statepath,state)
    a0score=score_all(reference,reference,quality)
    if not a0score['eligible']:raise ValueError('FRESH_A0_SCORE_NO_GO')
    a0={'candidate_id':candidate_id(baseline(registry)),'parameter_overrides':baseline(registry),'role':'FRESH_A0_REFERENCE','score':a0score}
    def finish(status,reason,confirmed=None):
        result=pareto(state['records'],a0)
        promising=[r for r in result['frontier'] if r['candidate_id']!=a0['candidate_id'] and r['score'].get('practical_gain')]
        if status!='OPTIMIZATION_NO_GO' and promising and confirmed is not None:
            def key(r):
                gains=[c['paired_difference_m']/c['practical_gain_floor_m'] for c in r['score']['per_task']]
                return (-min(gains),-max(gains),r['candidate_id'])
            shortlist=[confirmed]
        else:shortlist=[]
        final_status=status if status=='OPTIMIZATION_NO_GO' else 'TECHNICAL_SHORTLIST_REQUIRES_FINALIST' if shortlist else 'NO_CANDIDATE_KEEP_A0'
        report={**result,'status':final_status,'reason':reason,'shortlist':shortlist,
            'proposal_count':len(state['records']),'process_launches_reserved':sum(r['processes'] for r in state['reservations']),
            'actual_optimizer_processes':sum(1 for p in (app.B/'attempts').glob('*/manifest.json') if read_json(p)['budget_group']=='optimizer'),
            'global_stop':status=='OPTIMIZATION_NO_GO','tpe':'NOT_REACHED_BY_PREREGISTERED_BUDGET',
            'identity':identity,'default_promotion':False,'holdout_accessed':False}
        state['status']=final_status;atomic_json(statepath,state)
        immutable(directory/'pilot_report.json',report);immutable(app.D/'search_result.json',report)
        return report
    qualification={'decision':'GO_MINIMAL_BENCHMARK','identity_sha256':digest(identity)}
    queue=[sensitivity_proposals(registry)[i] for i in SENSITIVITY_INDICES]
    with ProposalStudy(directory,identity,registry,qualification,plan=PLAN,sensitivity_queue=queue) as proposals:
        settings=sqlite_settings(proposals.storage);settingspath=directory/'sqlite_configuration.json'
        if settingspath.exists():
            if read_json(settingspath)!=settings:raise ValueError('SQLITE_CONNECTION_CONFIGURATION_CHANGED')
        else:immutable(settingspath,settings)
        if len(proposals.study.trials)!=len(state['records']):raise ValueError('UNRESOLVED_TRIAL_OR_RECEIPT_GAP')
        if sum(r['processes'] for r in state['reservations'])!=4*sum(r.get('status')=='PROPOSED' for r in state['records']):raise ValueError('RESERVATION_RECORD_GAP')
        while len(state['records'])<5:
            if stage=='sensitivity' and len(state['records'])>=4:
                report={'status':'PHASE_COMPLETE','phase':'sensitivity','shortlist':[],
                    'identity_sha256':digest(identity),'proposal_count':len(state['records'])}
                immutable(directory/'phase_reports/sensitivity.json',report);return report
            if stage=='random' and len(state['records'])<4:raise ValueError('SENSITIVITY_PHASE_REQUIRED')
            verify_gate(app)
            proposal=proposals.ask()
            if proposal is None:break
            attempt=f"v135a_{proposal['proposal_index']:03}_{proposal['phase']}"
            proposal={**proposal,'attempt_id':attempt,'created_utc':utc_now()}
            immutable(directory/f'proposals/{attempt}.json',proposal);record=copy.deepcopy(proposal)
            if proposal['status']!='PROPOSED':record['score']=None
            else:
                row=reserve(state['reservations'],attempt)
                immutable(directory/f'attempts/{attempt}.json',row);atomic_json(statepath,state)
                rows=[]
                try:
                    for hz in FREQUENCIES:
                        for scenario in TRAIN:
                            r=app.one(scenario,hz,'headless','optimizer',app.B/'tapes'/f'{scenario}_{hz}.json',values=proposal['parameter_overrides'],phase=proposal['phase'])
                            rows.append(r)
                            if r['status']!='RUN_VALID':raise ValueError('INFRASTRUCTURE_OR_SAFETY_STOP:'+r['directory'])
                    candidate={'by_hz':{str(hz):envelope(rows,hz) for hz in FREQUENCIES}}
                    score=score_all(candidate,reference,quality)
                    immutable(directory/f'outcomes/{attempt}.json',{'candidate':candidate,'rows':[r['directory'] for r in rows]})
                except Exception as exc:
                    score={'disposition':'STOP_STUDY','eligible':False,'values':None,'reasons':[f'{type(exc).__name__}:{exc}'],'practical_gain':False}
                    immutable(directory/f'failures/{attempt}.json',{'score':score,'actual_rows':[r['directory'] for r in rows]})
                record['score']=score
                proposals.tell(proposal,score,f'receipts/{attempt}.json')
            immutable(directory/f'receipts/{attempt}.json',record);state['records'].append(record);atomic_json(statepath,state)
            if (record.get('score') or {}).get('disposition')=='STOP_STUDY':return finish('OPTIMIZATION_NO_GO',';'.join(record['score']['reasons']))
        promising=[r for r in pareto(state['records'],a0)['frontier'] if r['candidate_id']!=a0['candidate_id'] and r['score'].get('practical_gain')]
        if not promising:return finish('BOUNDED_STUDY_COMPLETE','No meaningful four-cell proposal; confirmation reserve unused')
        def order(r):
            gains=[c['paired_difference_m']/c['practical_gain_floor_m'] for c in r['score']['per_task']]
            return (-min(gains),-max(gains),r['candidate_id'])
        chosen=sorted(promising,key=order)[0]
        reservation=reserve(state['reservations'],'confirmation_'+chosen['candidate_id'],confirmation=True)
        immutable(directory/'confirmation/reservation.json',reservation);atomic_json(statepath,state)
        try:
            confirmation=confirm(app,chosen,reference,quality,directory)
        except Exception as exc:
            immutable(directory/'confirmation/failure.json',{'reason':f'{type(exc).__name__}:{exc}'})
            return finish('OPTIMIZATION_NO_GO','CONFIRMATION_INFRASTRUCTURE_OR_AUDIT_FAILURE:'+str(exc))
        if not confirmation['pass']:return finish('BOUNDED_STUDY_COMPLETE','Confirmation failed; no retry or second finalist')
        chosen=copy.deepcopy(chosen);chosen['training_repeat_validation']=confirmation
        return finish('BOUNDED_STUDY_COMPLETE','Complete frozen proposal and confirmation plan',chosen)


def confirm(app,chosen,reference,quality,directory):
    """Reuse exactly four original H rows; run the20 missing cells once."""
    original=read_json(directory/f"outcomes/{chosen['attempt_id']}.json")
    first={}
    for p in original['rows']:
        p=Path(p);r=read_json(p/'receipt.json');m=read_json(p/'manifest.json');source=app.guard()
        if (r['mode']!='headless' or r['status']!='RUN_VALID'
                or m['baseline_candidate']['parameter_overrides']!=chosen['parameter_overrides']
                or m['source_snapshot_sha256']!=source['snapshot_sha256']
                or m['python_environment']!=source['python_environment']
                or m['virtual_tape_sha256']!=file_hash(app.B/'tapes'/f"{r['scenario_id']}_{r['hz']}.json")):
            raise ValueError('ORIGINAL_CANDIDATE_CELL_NOT_REUSABLE')
        first[(r['hz'],r['scenario_id'])]=r
    if set(first)!={(hz,s) for hz in FREQUENCIES for s in TRAIN}:raise ValueError('MISSING_INITIAL_FOUR_CELLS')
    result={'pass':False,'repeats_per_frequency':3,'frequencies':[60,120],
        'reused_initial_processes':4,'new_processes':0,'runs':list(first.values()),'pairs':[],'reason':''}
    target=directory/'confirmation/result.json';immutable(target,result)
    def save():atomic_json(target,result)
    by_repeat={}
    for hz in FREQUENCIES:
        for scenario in TRAIN:
            heads=[first[(hz,scenario)]];renders=[]
            for repeat in [1,2,3]:
                pair=[]
                for mode in ['headless','rendered_scripted']:
                    if repeat==1 and mode=='headless':r=heads[0]
                    else:
                        r=app.one(scenario,hz,mode,'optimizer',app.B/'tapes'/f'{scenario}_{hz}.json',
                            values=chosen['parameter_overrides'],phase='confirmation')
                        result['runs'].append(r);result['new_processes']+=1;save()
                        if r['status']!='RUN_VALID':raise ValueError('CONFIRMATION_INVALID_RUN:'+r['directory'])
                        if not app.valid_task(r):result['reason']='CONFIRMATION_TASK_FAILED';save();return result
                        history=heads if mode=='headless' else renders
                        if history:
                            comparison=app.compare(history[0],r,f'confirmation_within_{hz}_{scenario}_{mode}_{repeat}')
                            result['pairs'].append(comparison);save()
                            if comparison['status']!='STRICT_MATCH':raise ValueError('CONFIRMATION_WITHIN_MODE_DIVERGENCE')
                        history.append(r)
                    pair.append(r);by_repeat.setdefault((repeat,mode),[]).append(r)
                comparison=app.compare(*pair,f'confirmation_HR_{hz}_{scenario}_{repeat}')
                result['pairs'].append(comparison);save()
                if comparison['status']!='STRICT_MATCH':raise ValueError('CONFIRMATION_HR_DIVERGENCE')
    for rows in by_repeat.values():
        score=score_all({'by_hz':{str(h):envelope(rows,h) for h in FREQUENCIES}},reference,quality)
        if score['disposition']=='STOP_STUDY':raise ValueError('CONFIRMATION_SCORE_INVALID')
        if not score['eligible'] or not score['practical_gain']:result['reason']='CONFIRMATION_QUALITY_OR_PRACTICAL_FAILURE';save();return result
    if result['new_processes']!=20 or len(result['runs'])!=24 or len(result['pairs'])!=28:raise ValueError('CONFIRMATION_COVERAGE_COUNT')
    result.update({'pass':True,'passed':True,'reason':'COMPLETE_3HR_BOTH_TASKS_BOTH_HZ'})
    save();return result


def validate(app):
    """Reserved protected24 gate; unavailable required skills stay missing."""
    source=verify_gate(app);report=read_json(app.D/'search_result.json');shortlist=report.get('shortlist',[])
    if len(shortlist)!=1 or shortlist[0].get('training_repeat_validation',{}).get('passed') is not True:
        raise ValueError('CONFIRMED_N3_SHORTLIST_REQUIRED')
    confirmation=read_json(app.B/'optimizer/confirmation/result.json')
    if (not confirmation.get('passed') or confirmation['new_processes']!=20
            or len(confirmation['runs'])!=24 or len(confirmation['pairs'])!=28
            or any(p['status']!='STRICT_MATCH' for p in confirmation['pairs'])):
        raise ValueError('CONFIRMATION_PROOF_INCOMPLETE')
    frozen={'source_snapshot_sha256':source['snapshot_sha256'],
        'python_environment':source['python_environment'],'shortlist':shortlist,
        'search_report_sha256':file_hash(app.D/'search_result.json'),
        'confirmation_sha256':file_hash(app.B/'optimizer/confirmation/result.json'),
        'frozen_utc':utc_now(),'holdout_accessed':False}
    immutable(app.B/'shortlist_freeze.json',frozen)
    session={'status':'RUNNING','runs':[],'pairs':[],'reason':'',
        'missing_coverage':copy.deepcopy(read_json(app.D/'run_plan.json')['missing_required_coverage']),
        'reserved_processes':24,'actual_processes':0,'default_promotion':False}
    target=app.B/'finalist_session.json';immutable(target,session)
    def save():atomic_json(target,session)
    a0=baseline(parameter_resource());candidate=shortlist[0]['parameter_overrides'];matched={}
    try:
        for name,values in [('A0',a0),('candidate',candidate)]:
            for hz in FREQUENCIES:
                pair=[]
                for mode in ['headless','rendered_scripted']:
                    r=app.one('swing_catch_train',hz,mode,'finalist',Path(source['tapes'][str(hz)]['path']),values=values,phase='finalist_protected')
                    session['runs'].append(r);session['actual_processes']+=1;save()
                    if r['status']!='RUN_VALID':raise ValueError('PROTECTED_CATCH_FAILED')
                    pair.append(r)
                c=app.compare(*pair,f'protected_{name}_catch_{hz}');session['pairs'].append(c);save()
                if c['status']!='STRICT_MATCH':raise ValueError('PROTECTED_CATCH_HR_DIVERGENCE')
            for scenario,hz in [('two_hand_release_stop_v134_r2',120),('two_hand_release_stop_v134_r2',60),
                    ('asymmetric_pull_clean_v134_r2',120),('lateral_clean_left_v134_r2',120),('vertical_novel_v135_r1',120)]:
                descriptor=read_json(app.D/'run_plan.json')['protected_public_tapes'].get(f'{scenario}:{hz}')
                if descriptor is None:raise ValueError('PROMISED_PROTECTED_TAPE_MISSING:'+scenario)
                r=app.one(scenario,hz,'headless','finalist',Path(descriptor['path']),values=values,phase='finalist_protected')
                session['runs'].append(r);session['actual_processes']+=1;save()
                if not app.valid_task(r):raise ValueError('PROTECTED_TASK_FAILED:'+scenario)
                if name=='A0':matched[(scenario,hz)]=r['metrics']
                else:
                    previous=matched[(scenario,hz)];now=r['metrics']
                    if scenario=='two_hand_release_stop_v134_r2':
                        for metric,floor,fraction in [('stop_path_3d_m',.005,.05),('settling_time_s',2/hz,.15),('overshoot_after_release_m',.005,.05)]:
                            a,c=previous['metrics'][metric],now['metrics'][metric]
                            if a['status']!='MEASURED' or c['status']!='MEASURED' or c['value']-a['value']>max(floor,fraction*abs(a['value'])):
                                raise ValueError('PROTECTED_STOP_QUALITY_REGRESSION:'+metric)
                    elif now['signed_progress_m']<previous['signed_progress_m']-max(.005,.03*abs(previous['signed_progress_m'])):
                        raise ValueError('PROTECTED_PROGRESS_REGRESSION:'+scenario)
            for hz in FREQUENCIES:
                r=app.first_ascent_capability(values,hz,shortlist)
                session['runs'].append(r);session['actual_processes']+=1;save()
                if r['status']!='completed' or not r['completed']:raise ValueError('FIRST_ASCENT_CAPABILITY_FAILED')
        if session['actual_processes']!=22:raise ValueError('PROTECTED_SCHEDULE_COUNT')
        session.update(status='NO_CANDIDATE_KEEP_A0',reason='Required one-hand and Right independent coverage remains missing; no general recommendation or human AB approval')
    except Exception as exc:
        session.update(status='OPTIMIZATION_NO_GO',reason=f'{type(exc).__name__}:{exc}')
    save();return session


def dispatch(app,stage,phase=None,resume=False):
    if stage=='prepare':return prepare(app)
    if stage=='freeze':return app.freeze()
    with StudyLock(app.ROOT/'builds/eval_virtual_cursor'):
        if stage=='preflight':return preflight(app)
        if stage=='quality-freeze':return quality_freeze(app)
        if stage=='search':return search(app,phase,resume)
        if stage=='validate':return validate(app)
        if stage=='gate':
            require_certification(app)
            if read_json(app.B/'preflight_session.json')['status']!='PREFLIGHT_PASS':raise ValueError('PREFLIGHT_REQUIRED')
        return {'pure':app.pure,'baseline':app.baseline_matrix,'negatives':app.negatives,'gate':app.gate}[stage]()
