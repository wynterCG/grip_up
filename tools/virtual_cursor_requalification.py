"""One new campaign, immutable stage directories; no automatic human attestation."""
from pathlib import Path
import argparse,subprocess,sys,json
ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/'tools/auto_tuning/virtual_cursor'),str(ROOT/'tools/auto_tuning')]
from common import atomic_json,read_json,source_hashes,git_identity,file_hash,engine_identity
CAMPAIGN='requal_20261020_r1'
OUT=ROOT/'builds/eval_virtual_cursor'/CAMPAIGN
DOC=ROOT/'docs/validation/virtual_cursor_requalification_v132a'
def main():
    p=argparse.ArgumentParser();p.add_argument('stage',choices=['freeze','capture','baseline','mouse','focus']);p.add_argument('--human-attested',action='store_true');p.add_argument('--hz',choices=[60,120],type=int,action='append');args=p.parse_args()
    if args.stage=='freeze':
        assert not git_identity()['repository_dirty']
        assert source_hashes(ROOT)==source_hashes(Path(r'E:\Godot Games\grip_up'))
        assert not (OUT/'source_identity.json').exists()
        atomic_json(OUT/'source_identity.json',{'campaign':CAMPAIGN,'identity':git_identity(),'source_hashes':source_hashes(ROOT),'engine_identity':engine_identity(),'protocol_sha256':file_hash(DOC/'protocol.md'),'wrapper_sha256':file_hash(Path(__file__))})
        print('New source identity frozen');return 0
    frozen=read_json(OUT/'source_identity.json');assert frozen['source_hashes']==source_hashes(ROOT),'SOURCE_FREEZE_CHANGED'
    conditions={'capture':['V0-H'],'baseline':['V0-H','V0-R'],'mouse':['V0-M'],'focus':['V0-F']}[args.stage]
    if args.stage in ['mouse','focus'] and not args.human_attested:raise ValueError('HUMAN_PARTICIPATION_REQUIRED')
    stage=args.stage+('_'+'_'.join(map(str,args.hz)) if args.hz else '')
    command=[sys.executable,str(ROOT/'tools/auto_tuning/virtual_cursor/run.py'),'--suite','capture' if args.stage=='capture' else 'matrix','--output',str(OUT/stage),'--campaign',CAMPAIGN]
    for condition in conditions:command+=['--condition',condition]
    for hz in args.hz or [120,60]:command+=['--hz',str(hz)]
    if args.stage!='capture':command+=['--tapes',str(OUT/'capture/tapes')]
    if args.human_attested:command+=['--human-attested','--human-lead-in','8']
    print('CAMPAIGN',CAMPAIGN,'STAGE',stage,flush=True)
    return subprocess.call(command,cwd=ROOT)
if __name__=='__main__':raise SystemExit(main())
