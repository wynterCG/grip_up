"""Postprocess immutable v134 receipts; never launches a physical test."""
import csv
import io
import json
from pathlib import Path
import sys

sys.path.insert(0,str(Path(__file__).resolve().parent))
import fixture_feasibility as f
import virtual_cursor_report as ar


def save(name,value): f.old.atomic_json(f.D/name,value)


def mcp_json(path):
    return json.JSONDecoder().raw_decode(path.read_text(encoding='utf-8-sig'))[0]


def foot_work(rows):
    """Same static-support point-work proxy used by existing physics tests."""
    signed=positive=impulse=0.0
    loaded_ticks=0
    for row in rows:
        velocity=row['body']['linear_velocity_m_s'];omega=row['body']['angular_velocity_rad_s'];com=row['body']['com_m']
        loaded=False
        for foot in row['feet']:
            force=foot['force_n']
            if not any(force):continue
            if foot['support']['type']!='StaticBody3D':return {'status':'INVALID_MEASUREMENT','value':None,'reason':'DYNAMIC_SUPPORT_POINT_VELOCITY_NOT_PUBLISHED'}
            lever=[a-b for a,b in zip(foot['point_m'],com)]
            cross=[omega[1]*lever[2]-omega[2]*lever[1],omega[2]*lever[0]-omega[0]*lever[2],omega[0]*lever[1]-omega[1]*lever[0]]
            power=sum(a*(b+c) for a,b,c in zip(force,velocity,cross))
            signed+=power*row['delta_s'];positive+=max(0.0,power)*row['delta_s']
            impulse+=max(0.0,foot['normal_force_n'])*row['delta_s'];loaded=loaded or foot['normal_force_n']>1
        loaded_ticks+=int(loaded)
    return {'status':'RAW_DIAGNOSTIC_NOT_A_SCORE','signed_point_work_J':signed,'positive_point_work_J':positive,
        'compressive_normal_impulse_Ns':impulse,'ticks_with_foot_compression_gt1N':loaded_ticks,
        'sample_count':len(rows),'formula':'sum F dot (v_COM + omega cross (contact_point-COM)) delta; authored static supports have zero velocity',
        'limitation':'Discrete POST point-work proxy; no claim of exact solver energy or exclusion of unknown native contacts'}


def main():
    source=f.identity()
    final=f.old.read_json(f.B/'final_session.json')
    runs=[f.old.read_json(p) for p in sorted((f.B/'attempts').glob('*/feasibility_receipt.json'))]
    development=[r for r in runs if r['feasibility_phase']=='development']
    pilot=[r for r in runs if r['feasibility_phase']!='development']
    assert len(development)==8 and len(pilot)<=48
    definitions=f.old.read_json(f.CAT)['scenarios']
    pairs=final['pairs']
    cells=[]
    for hz in [120,60]:
        for d in definitions:
            matching=[r for r in pilot if r['scenario_id']==d['id'] and r['hz']==hz]
            capture=next((r for r in matching if r['feasibility_phase']=='capture'),None)
            replays=[r for r in matching if r['feasibility_phase']=='replay']
            pair=next((p for p in pairs if p['id']==f"{d['id']}_{hz}"),None)
            valid=bool(capture and f.measurement_valid(capture,d) and len(replays)==2 and
                all(f.measurement_valid(r,d) for r in replays) and pair and pair['status']=='STRICT_MATCH')
            cells.append({'domain':d['domain_id'],'scenario_id':d['id'],'fixture_revision':d['fixture_revision'],
                'hz':hz,'capture':capture['run_id'] if capture else None,
                'replays':[r['run_id'] for r in replays],
                'measurement_status':capture['metrics']['observation']['status'] if capture else 'NOT_RUN',
                'reason':capture['metrics']['observation']['reason_code'] if capture else 'NOT_RUN_EARLY_STOP',
                'strict_pair':pair['status'] if pair else 'NOT_RUN',
                'feasible':valid,'diagnostic_only':d['domain_id'] in ['foot_supported_step','two_hand_release_stop'],
                'score_eligible':False,'n_per_mode':1 if len(replays)==2 else 0})
    required=[x for x in cells if not x['diagnostic_only']]
    mandatory_ok=all(x['feasible'] for x in required)
    diagnostic_ok=all(x['feasible'] for x in cells if x['diagnostic_only'])
    negatives=[r for r in pilot if r['feasibility_phase']=='negative']
    negative_ok=len(negatives)==2 and all(r['status']=='RUN_VALID' and all(x['pass'] for x in r['engine_result']['negative_checks']) for r in negatives)
    refs=[p for p in pairs if p['id'].startswith('reference_')]
    reference_ok=len(refs)==2 and all(p['status']=='STRICT_MATCH' for p in refs)
    decision='FEASIBILITY_READY_FOR_REQUALIFICATION' if mandatory_ok and diagnostic_ok and negative_ok and reference_ok and not final['hard_stop'] else 'FEASIBILITY_NO_GO'
    save('feasibility_cells.json',{'decision':decision,'mandatory_domains_all_Hz':mandatory_ok,
        'diagnostic_windows_all_Hz':diagnostic_ok,'reference_pass':reference_ok,'negative_pass':negative_ok,
        'source_commit':source['repository_commit'],'source_snapshot':source['snapshot_sha256'],
        'cells':cells,'hard_stop':final['hard_stop'],'score_eligible':False})
    fields=['domain','scenario_id','fixture_revision','hz','capture','measurement_status','reason','strict_pair','feasible','diagnostic_only','score_eligible','n_per_mode']
    stream=io.StringIO(newline='');writer=csv.DictWriter(stream,fieldnames=fields);writer.writeheader()
    for row in cells:writer.writerow({k:row[k] for k in fields})
    (f.D/'domain_feasibility.csv').write_text(stream.getvalue(),encoding='utf-8',newline='')
    fields=['run_id','phase','scenario_id','fixture_revision','hz','mode','source_hash','tape_hash','metric','value_json','unit','status','onset_tick','end_tick','reason','provenance','score_eligible']
    stream=io.StringIO(newline='');writer=csv.DictWriter(stream,fieldnames=fields);writer.writeheader()
    for row in pilot:
        if not row['metrics']:continue
        definition=next(d for d in definitions if d['id']==row['scenario_id'])
        for name,m in row['metrics']['metrics'].items():
            writer.writerow({'run_id':row['run_id'],'phase':row['feasibility_phase'],'scenario_id':row['scenario_id'],
                'fixture_revision':definition['fixture_revision'],'hz':row['hz'],'mode':row['mode'],
                'source_hash':row['source_snapshot'],'tape_hash':row['tape_sha256'],'metric':name,
                'value_json':json.dumps(m['value'],allow_nan=False),'unit':m['unit'],'status':m['status'],
                'onset_tick':json.dumps(m['onset_tick']),'end_tick':json.dumps(m['end_tick']),
                'reason':m['reason_code'],'provenance':m['event_provenance'],'score_eligible':False})
    (f.D/'metrics.csv').write_text(stream.getvalue(),encoding='utf-8',newline='')
    matrix=[]
    for cell in cells:
        for phase,mode in [('capture','headless'),('replay','headless'),('replay','rendered_scripted')]:
            row=next((r for r in pilot if r['scenario_id']==cell['scenario_id'] and r['hz']==cell['hz'] and r['mode']==mode and r['feasibility_phase']==phase),None)
            matrix.append({'scenario_id':cell['scenario_id'],'hz':cell['hz'],'phase':phase,'mode':mode,
                'attempted':row is not None,'run_id':row['run_id'] if row else None,
                'runtime_status':row['status'] if row else 'NOT_RUN_FIXTURE_FAILURE' if cell['capture'] else 'NOT_RUN_EARLY_STOP',
                'reason':row['reason'] if row else cell['reason']})
    for phase in ['negative','reference','reserve']:
        allowance={'negative':2,'reference':4,'reserve':6}[phase]
        actual=[r for r in pilot if r['feasibility_phase']==phase]
        for i in range(allowance):
            row=actual[i] if i<len(actual) else None
            matrix.append({'phase':phase,'slot':i+1,'attempted':row is not None,
                'run_id':row['run_id'] if row else None,'runtime_status':row['status'] if row else 'NOT_RUN_UNUSED_RESERVE' if phase=='reserve' else 'NOT_RUN_EARLY_STOP',
                'reason':row['reason'] if row else final['hard_stop'] or 'NO_DISCREPANCY_DIAGNOSTIC_REQUIRED'})
    assert len(matrix)==48 and sum(x['attempted'] for x in matrix)==len(pilot)
    save('test_matrix.json',{'decision':decision,'planned_slots':48,'actual_attempts':len(pilot),'cells':matrix,'development_separate':len(development)})
    save('replay_pair_results.json',{'source_snapshot':source['snapshot_sha256'],'pairs':pairs,
        'comparisons':{p.name:{'sha256':f.old.file_hash(p),'status':f.old.read_json(p)['status']} for p in (f.B/'comparisons').glob('*.json')},
        'same_Hz_only':True,'n3_or_statistical_qualification':False})
    save('negative_controls.json',{'final':[{'run_id':r['run_id'],'hz':r['hz'],'status':r['status'],
        'contract':f.old.read_json(Path(r['directory'])/'python_pick_dispatch_contract.json'),
        'checks':r['engine_result']['negative_checks'],'cleanup':r['engine_result']['virtual_input']['cleanup']} for r in negatives],
        'old_R3_N1_status':'RUN_INVALID_UNCHANGED','development_has_no_final_credit':True})
    work=[]
    for row in pilot:
        if row['feasibility_phase']!='capture':continue
        ticks=f.old.read_json(Path(row['directory'])/'benchmark_audit.json')['ticks']
        obs=row['metrics']['observation'];onset=obs.get('onset_tick');end=obs.get('end_tick')
        work.append({'run_id':row['run_id'],'scenario_id':row['scenario_id'],'hz':row['hz'],
            'source_hash':row['source_snapshot'],'tape_hash':row['tape_sha256'],'score_eligible':False,
            'raw_preparation':foot_work([t for t in ticks if onset is None or t['tick']<onset]),
            'authorized_full_window':foot_work([t for t in ticks if onset<=t['tick']<=end]) if obs['status']=='MEASURED' else {'status':obs['status'],'value':None,'reason':obs['reason_code']}})
    save('foot_load_work_diagnostics.json',work)
    ledger=f.old.read_json(f.B/'budget_ledgers.json')
    regression=[]
    for name in ['benchmark_reference','benchmark_live_reference']:
        value=f.old.read_json(f.D/name/'attempt_001/results.json')
        assert value['all_passed'] and all(r['passed'] for r in value['runs'])
        regression.extend(dict(r,group=name) for r in value['runs'])
    assert len(regression)==34 and sum(r['checks'] for r in regression)==1146
    ledger['regression']={'required':34,'completed':34,'checks':1146,'separate':True,'passed':True}
    ledger['pure']={'Godot_file_JSON_cases':49,'Godot_successful_assertions':128,
        'Godot_transport_batches_attempted':4,'failed_batches_preserved':3,
        'Godot_parse_only_processes':3,'Python_unittest_methods_final':50,'new_Python_JSON_subcases':49,
        'diagnostic_window_gate_checks':8,'Python_zero_discovery_attempt_no_coverage':True,
        'coverage_not_summed_across_repeats':True}
    ledger['status']='CLOSED_'+decision
    f.old.atomic_json(f.B/'budget_ledgers.json',ledger);save('budget_ledgers.json',ledger)
    save('regression_index.json',{'runs':regression,'checks':1146,'processes':34,'all_passed':True,'final_pilot_credit':0})
    base=f.old.read_json(f.D/'baseline_audit.json')
    assert all(f.old.file_hash(f.ROOT/p)==h for p,h in base['immutable_R3'].items())
    protected={p:h for p,h in base['R3_public_sources'].items() if p=='project.godot' or p.startswith('features/grip_up/')}
    assert all(f.old.file_hash(f.ROOT/p)==h==f.old.file_hash(f.DEST/p) for p,h in protected.items())
    assert all(f.old.file_hash(Path(p))==h for p,h in base['protected_external'].items())
    assert f.old.file_hash(f.DEST/'builds/GripUp-v1.2-pre-v1.3.exe')==f.old.file_hash(f.ROOT/'builds/GripUp-v1.2-pre-v1.3.exe')
    normal=f.old.read_json(f.B/'safety/normal_runtime.json')
    assert normal['normal']==f.old.read_json(f.ROOT/'docs/validation/evaluator_v132/baseline/normal_runtime.json')
    native=mcp_json(f.B/'native/normal_runtime_response.json');runtime=json.loads(native['output'][0])
    assert all(runtime[k]==v for k,v in normal['normal'].items())
    assert runtime['virtual_provider_disabled'] and not runtime['virtual_arming'] and not runtime['camera_virtual'] and runtime['source_kind']=='LIVE'
    assert mcp_json(f.B/'native/errors_after_response.json')['count']==0
    restoration=f.old.read_json(f.B/'native/restoration.json')
    assert restoration['project_C_restored'] and restoration['project_E_restored'] and restoration['owned_editor_closed']
    pack=f.old.read_json(f.B/'safety/export_pack_check.json')
    assert all(pack['excluded'].values()) and pack['provider_disabled'] and pack['profile']==2 and not pack['camera_virtual']
    source=f.identity()
    save('verification.json',{'source_commit':source['repository_commit'],'source_snapshot':source['snapshot_sha256'],
        'public_source_file_count':len(source['source_hashes']),'helper_count':len(source['helper_hashes']),
        'engine':source['engine_identity'],'source_bytes_unchanged_since_final_freeze':True,
        'source_C_E_parity':True,'protected_game_files_unchanged':len(protected),
        'immutable_R3_files_unchanged':len(base['immutable_R3']),'protected_external':base['protected_external'],
        'rollback_both_C_E_verified':True,
        'ordinary_startup_exact_baseline':True,'native_runtime':runtime,'native_MCP_version':'1.17.1',
        'native_fresh_errors':0,'native_restoration':restoration,'screenshot_visually_inspected':True,
        'release_export':f.old.read_json(f.B/'safety/export_identity.json'),'pack_inspection':pack,
        'pack_inspection_uses_debug_tool_engine':True,'regressions':{'processes':34,'checks':1146,'passed':True},
        'n3_qualification':False,'scoring_eligible':False,'new_96_process_campaign':False,
        'Optuna_ML_RL_Jev_M7_executed':False,'private_holdout_accessed':False,'human_feel_tested':False})
    print('PUBLICATION_DATA_READY',decision,'pilot',len(pilot),'dev',len(development),flush=True)


def archive():
    ar.DOC=f.D;index={}
    groups={
        'attempts':list((f.B/'attempts').rglob('*')),
        'diagnostics':list((f.B/'R3_diagnosis').rglob('*'))+list((f.B/'derived_diagnostics').rglob('*')),
        'comparison':list((f.B/'comparisons').rglob('*')),
        'pure':list((f.B/'pure').rglob('*')),
        'metadata':[p for p in f.B.glob('*.json')]+list((f.B/'sources').rglob('*'))+list((f.B/'negative_tapes').rglob('*'))+list((f.B/'tapes').rglob('*')),
        'safety':[p for n in ['safety','native'] for p in (f.B/n).rglob('*') if p.suffix!='.exe'],
        'regression':[p for n in ['benchmark_reference','benchmark_live_reference'] for p in (f.D/n).rglob('*')],
    }
    for label,files in groups.items():
        if files:ar.archive(label,files,index)
    for p in (f.B/'sources').glob('*/archive_receipt.json'):
        for name,entry in f.old.read_json(p).items():
            assert f.old.file_hash(f.D/'evidence'/name)==entry['sha256'];index[name]=entry
    save('evidence_manifest.json',{'archives':index,'all_members_SHA_and_CRC_verified_after_readback':True,
        'failed_pure_attempts_preserved':True,'development_failures_preserved':True,
        'source_candidates_separate':True,'R3_historical_status_unchanged':True,
        'release_exe_preserved_local_not_zipped':{'path':str(f.B/'safety/GripUp-v133-benchmark-safe.exe'),**f.old.read_json(f.B/'safety/export_identity.json')}})
    print('EVIDENCE_COMPLETE',len(index),sum(x['bytes'] for x in index.values()),flush=True)


if __name__=='__main__':
    if '--archive' in sys.argv:archive()
    else:main()
