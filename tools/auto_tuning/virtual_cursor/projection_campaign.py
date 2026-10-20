"""Frozen finite PV matrix. All physics runs use the existing replay executor."""
import sys,json,statistics
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from run import execute
from common import ROOT,atomic_json,read_json,file_hash,source_hashes,git_identity,StudyLock,utc_now
from projection_comparison import load_picks,pair

DOC=ROOT/'docs/validation/auto_tuning/projection_v132b'
OUT=ROOT/'builds/eval_virtual_cursor/projection_v132b_r2'

def run():
    if (OUT/'session_manifest.json').exists():raise ValueError('IMMUTABLE_SESSION')
    if git_identity()['repository_dirty']:raise ValueError('CLEAN_SOURCE_FREEZE_REQUIRED')
    plan=read_json(DOC/'test_plan_r2.json')
    atomic_json(OUT/'session_manifest.json',{'plan_sha256':file_hash(DOC/'test_plan_r2.json'),'source_hashes':source_hashes(),'identity':git_identity(),'utc':utc_now(),'optimizer':'OFF','max_runs':40})
    rows=[];pairs=[];stopped='';bycell={}
    def state():atomic_json(OUT/'session_state.json',{'runs':rows,'pairs':pairs,'hard_stop':stopped,'optimizer':'OFF'})
    def one(mode,hz,size,condition,repeat,probe=True):
        nonlocal stopped
        if file_hash(Path(plan['tapes'][str(hz)]['path']))!=plan['tapes'][str(hz)]['sha256']:stopped='FROZEN_TAPE_SHA';state();return None
        receipt=execute(mode,hz,condition,repeat,OUT,Path(plan['tapes'][str(hz)]['path']),campaign_id=plan['campaign'],projection_config={'window_size':size,'probe_enabled':probe})
        rows.append({'mode':mode,'hz':hz,'size':size,'condition':condition,'repeat':repeat,'probe_enabled':probe,**receipt});state()
        if receipt['status']!='completed':stopped=receipt['reason'];state();return None
        r=receipt['engine_result']
        if r.get('projection_setup',{}).get('actual_size')!=size:stopped='EFFECTIVE_WINDOW_SIZE';state();return None
        comparison=receipt.get('comparison',{})
        if comparison.get('status') in ['INPUT_SOURCE_MISMATCH','MISSING_TICK']:stopped=comparison['status'];state();return None
        if probe:
            try:
                picks=load_picks(receipt['directory'])
                if r['projection_probe']['error']:raise ValueError(r['projection_probe']['error'])
                expected_picks=sum(len(t['target'].get('picks',[])) for t in read_json(Path(receipt['directory'])/'virtual_audit.json')['ticks'])
                if len(picks)!=expected_picks:raise ValueError('MISSING_PICK_TRACE')
            except (ValueError,KeyError,TypeError) as e:stopped='INVALID_TRACE:'+str(e);state();return None
        return receipt
    def paired(p,hz,repeat):
        small=[1024,576];large=[1440,810]
        a=one('headless',hz,large if p==3 else small,f'P{p}_H',repeat)
        if not a:return
        b=one('rendered_scripted',hz,small if p==2 else large,f'P{p}_R',repeat)
        if not b:return
        result=pair(a['directory'],b['directory']);name=f'P{p}_{hz}_r{repeat}'
        atomic_json(OUT/'comparisons'/f'{name}.json',result)
        pairs.append({'id':name,'p':p,'hz':hz,'repeat':repeat,'left':a['directory'],'right':b['directory'],'status':result['status'],'first_by_stage':result.get('first_by_stage')})
        bycell[p,hz,repeat]=(a,b)
        if result['status']=='HARD_STOP':
            nonlocal stopped
            stopped='PAIRED_HARD_STOP:'+str(result['hard_reasons'])
        state()
    with StudyLock(ROOT/'builds/eval_virtual_cursor'):
        for hz in [120,60]:
            for p in [1,2,3]:
                paired(p,hz,1)
                if stopped:break
            if stopped:break
        # Repetitions characterize a candidate size effect; no relaxed policy.
        if not stopped:
            for hz in [120,60]:
                for p in [2,3]:
                    for repeat in [2,3]:
                        paired(p,hz,repeat)
                        if stopped:break
                    if stopped:break
                if stopped:break
        if not stopped:
            from layered_comparison import compare_layers
            for hz in [120,60]:
                for mode in ['headless','rendered_scripted']:
                    a=one(mode,hz,[1024,576],'CONTROL_ON',1,True)
                    if not a:break
                    b=one(mode,hz,[1024,576],'CONTROL_OFF',1,False)
                    if not b:break
                    aa=read_json(Path(a['directory'])/'virtual_audit.json');bb=read_json(Path(b['directory'])/'virtual_audit.json')
                    result=compare_layers({'frames':aa['frames'],'reference_ticks':aa['ticks']},bb)
                    atomic_json(OUT/'comparisons'/f'control_{mode}_{hz}.json',result)
                    pairs.append({'id':f'CONTROL_{mode}_{hz}','status':result['status'],'left':a['directory'],'right':b['directory'],'probe_cost_usec':a['engine_result']['projection_probe']['probe_usec']})
                    if any(result['first_by_layer'][k] for k in ['input','cursor','camera','raycast','material_anchor']):stopped='OBSERVER_CONTROL_NONPHYSICS_DIFFERENCE'
                    state()
                    if stopped:break
                if stopped:break
    state()
    print(json.dumps({'runs':len(rows),'pairs':len(pairs),'hard_stop':stopped},indent=2))
    return 1 if stopped else 0
if __name__=='__main__':raise SystemExit(run())
