"""Explicitly requested comparisons after early-stop; never qualifying runs."""
from pathlib import Path
import argparse,sys
ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/'tools/auto_tuning/virtual_cursor'),str(ROOT/'tools/auto_tuning')]
from common import StudyLock,atomic_json,read_json,file_hash,source_hashes
from run import execute
CAMPAIGN='requal_20261020_r1';BASE=ROOT/'builds/eval_virtual_cursor'/CAMPAIGN
parser=argparse.ArgumentParser();parser.add_argument('case',choices=['human120','human60','quiet60','quiet120']);args=parser.parse_args()
hz=120 if args.case.endswith('120') else 60;human=args.case.startswith('human')
assert source_hashes(ROOT)==read_json(BASE/'source_identity.json')['source_hashes']
output=BASE/('diagnostic_'+args.case)
assert not (output/'session_manifest.json').exists()
atomic_json(output/'session_manifest.json',{'campaign':CAMPAIGN,'classification':'DIRECT_REQUESTED_DIAGNOSTIC_AFTER_HARD_GATE','case':args.case,'human_ready_message_received':human,'human_protocol':'8s no-world notice then physical mouse over/outside, click another window, Alt+Tab away/back DURING active replay' if human else 'quiet rendered comparison','wrapper_sha256':file_hash(Path(__file__)),'qualification_reopened':False})
with StudyLock(ROOT/'builds/eval_virtual_cursor'):
    receipt=execute('rendered_scripted',hz,'D_MOUSE_FOCUS' if human else 'D_RENDER_QUIET',1,output,BASE/'capture/tapes'/f'catch_{hz}.json',True,'D_'+args.case.upper(),CAMPAIGN,8 if human else 0)
atomic_json(output/'session_state.json',{'runs':[receipt],'classification':'DIAGNOSTIC_ONLY','qualification_reopened':False})
print('DIAGNOSTIC',args.case,receipt['status'],receipt['reason'])
