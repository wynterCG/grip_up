"""BQ1 only: no gameplay body, no scored physical outcome."""
from pathlib import Path
import sys,subprocess,time
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools/auto_tuning'))
from common import ENGINE,atomic_json,read_json,file_hash,source_hashes,StudyLock,utc_now
BASE=ROOT/'builds/eval_virtual_cursor/benchmark_v133_r1'

def main(campaign_id='benchmark_v133_r1'):
    assert not (BASE/'preflight_session.json').exists()
    frozen=read_json(BASE/'source_identity.json');assert frozen['source_hashes']==source_hashes()
    cases=[(hz,mode,r,[1024,576],False) for hz in [120,60] for mode in ['headless','rendered_scripted'] for r in [1,2,3]]
    cases.append((120,'headless',1,[1440,810],True));rows=[];passed=True
    with StudyLock(ROOT/'builds/eval_virtual_cursor'):
        for hz,mode,r,size,negative in cases:
            d=BASE/'preflight'/f'{mode}_{hz}_{r}_{"negative" if negative else "positive"}';d.mkdir(parents=True,exist_ok=False)
            flags=['--headless','--fixed-fps','120'] if mode=='headless' else ['--screen','0','--position','80,80']
            command=[str(ENGINE),*flags,'--resolution','x'.join(map(str,size)),'--path',str(ROOT),'--script','res://features/evaluator_virtual_cursor/scripts/benchmark_preflight.gd','--','--hz',str(hz),'--output',str(d/'result.json')]
            if negative:
                manifest={'scenario_ids':['swing_catch_train'],'campaign_id':campaign_id,'run_id':'NEGATIVE_CANONICAL_BACKING','output_dir':str(d),'input_lane':'NEGATIVE_SETUP_ONLY','physics_hz':hz,'engine_mode':mode,'virtual_mode':'REPLAY','expected_source_hashes':frozen['source_hashes'],'engine_identity':frozen['engine_identity']}
                atomic_json(d/'driver_manifest.json',manifest)
                command=[str(ENGINE),*flags,'--resolution','1440x810','--path',str(ROOT),'--script','res://features/evaluator_virtual_cursor/scripts/benchmark_runner.gd','--','--virtual-cursor-evaluator','--benchmark-qualification','--manifest',str(d/'driver_manifest.json'),'--result',str(d/'result.json')]
            atomic_json(d/'manifest.json',{'command':command,'source':frozen,'hz':hz,'mode':mode,'repeat':r,'requested_size':size,'negative':negative,'gameplay_bodies_expected':0,'utc':utc_now()})
            with (d/'stdout.txt').open('wb') as stdout,(d/'stderr.txt').open('wb') as stderr:
                p=subprocess.Popen(command,cwd=ROOT,stdout=stdout,stderr=stderr)
                try:code=p.wait(timeout=20)
                except subprocess.TimeoutExpired:p.kill();p.wait();code=124
            try:
                result=read_json(d/'result.json');expected='BLOCKED_SETUP' if negative else 'PREFLIGHT_PASS'
                ok=result['status']==expected and code==(1 if negative else 0)
                if negative:ok=ok and result['reason']=='ENVIRONMENT_NOT_COMPARABLE:CANONICAL_BACKING' and result['world_creation_record']=={} and read_json(d/'benchmark_audit.json')=={'frames':[],'ticks':[]}
                else:ok=ok and result['gameplay_bodies_created']==0
            except (OSError,ValueError,KeyError):result={};ok=False
            rows.append({'hz':hz,'mode':mode,'repeat':r,'negative':negative,'exit_code':code,'pass':ok,'directory':str(d),'result':result});passed=passed and ok
            atomic_json(BASE/'preflight_session.json',{'pass':passed,'runs':rows,'physics_outcomes':0,'pure_preflight_processes':len(rows),'source_commit':frozen['repository_commit']})
            print(hz,mode,r,'NEG' if negative else '',ok,flush=True)
            if not ok:break
    return 0 if passed and len(rows)==13 else 1
if __name__=='__main__':raise SystemExit(main())
