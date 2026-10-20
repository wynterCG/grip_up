"""Freeze the immutable pre-v132a repository; never reads private holdouts."""
import hashlib,json,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
DEST=Path(r'E:\Godot Games\grip_up')
OUT=ROOT/'docs/validation/virtual_cursor_v132a'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
OUT.mkdir(parents=True,exist_ok=True)
files=subprocess.check_output(['git','ls-files','-z'],cwd=DEST).decode().split('\0')
protected={p:sha(DEST/p) for p in files if p and (DEST/p).is_file()}
parity=[p for p in protected if (ROOT/p).is_file() and sha(ROOT/p)!=protected[p]]
assert not parity,parity
spec=Path(r'C:\Users\Wynter\Downloads\GRIP_UP_Virtual_Cursor_Isolation_Spec_v1_3_2a_EN.md')
(OUT/'spec.md').write_bytes(spec.read_bytes())
value={'commit':subprocess.check_output(['git','rev-parse','HEAD'],cwd=DEST).decode().strip(),'files':protected,'spec_sha256':sha(spec),'janga_sha256':sha(DEST.parent/'janga_proto/runtime/physics_grabber.gd'),'engine_sha256':sha(Path.home()/'WrapRush/tools/godot.exe'),'override_C':'ABSENT' if not (ROOT/'override.cfg').exists() else sha(ROOT/'override.cfg'),'override_E':sha(DEST/'override.cfg'),'all_existing_tracked_files_parity':True}
with (OUT/'baseline.json').open('x',encoding='utf-8') as f:json.dump(value,f,indent=2,sort_keys=True)
print('Frozen',len(protected),'tracked files at',value['commit'])
