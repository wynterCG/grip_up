"""Only the directly related N1 diagnostic after the frozen admission failure."""
import sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/'tools/auto_tuning/virtual_cursor'),str(ROOT/'tools/auto_tuning')]
from run import execute
from common import atomic_json,StudyLock
out=ROOT/'builds/eval_virtual_cursor/direct_diagnostic_r2'
assert not (out/'session_manifest.json').exists()
atomic_json(out/'session_manifest.json',{'classification':'DIAGNOSTIC_ONLY_AFTER_EARLY_STOP','executed':['N1'],'not_run_early_stop':['N2','N3','N4'],'candidate_trials':0})
with StudyLock(ROOT/'builds/eval_virtual_cursor'):
    result=execute('headless',120,'N1_JSON_EDGE_GUARDS',1,out,ROOT/'builds/eval_virtual_cursor/diagnostic_tapes_r2/catch_120.json',True,'N1')
atomic_json(out/'session_state.json',{'runs':[result],'status':result['status'],'not_run_early_stop':['N2','N3','N4']})
raise SystemExit(0 if result['status']=='completed' else 1)
