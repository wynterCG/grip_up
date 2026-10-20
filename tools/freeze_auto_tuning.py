"""Create the one-time AT0 rollback record; verify it on subsequent calls."""
from pathlib import Path
import hashlib
import json
import subprocess
from datetime import datetime, timezone
from project_config import ROOT, DEST, ENGINE

sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
out = ROOT / 'docs/validation/auto_tuning/baseline/freeze.json'
if out.exists():
    data = json.loads(out.read_text(encoding='utf-8'))
    changed = [name for name, value in data['protected_files'].items() if not (ROOT/name).is_file() or sha(ROOT/name) != value]
    if changed:
        raise SystemExit('Protected baseline changed: ' + ', '.join(changed))
    if sha(Path(data['janga_path'])) != data['janga_sha256']:
        raise SystemExit('Janga changed')
    if sha(ENGINE) != data['engine_sha256']:
        raise SystemExit('Engine binary changed; the recorded baseline needs a new explicit audit')
    if sha(ROOT/data['build_path']) != data['build_sha256']:
        raise SystemExit('Rollback build changed')
    print('Protected baseline verified:', len(data['protected_files']), 'files')
else:
    janga = Path(r'E:\Godot Games\janga_proto\runtime\physics_grabber.gd')
    files = {p.relative_to(ROOT).as_posix(): sha(p) for folder in ('features/grip_up', 'features/locomotion_test_suite')
             for p in (ROOT/folder).rglob('*') if p.is_file() and p.suffix in ('.gd', '.tres', '.tscn', '.glb')}
    data = {'schema_version': 'at0_freeze_1', 'recorded_utc': datetime.now(timezone.utc).isoformat(),
            'commit': subprocess.check_output(['git','rev-parse','HEAD'],cwd=DEST,text=True).strip(),
            'rollback_tag': 'baseline/pre-v1.3-auto-tuning', 'protected_files': files,
            'engine_path': str(ENGINE), 'engine_sha256': sha(ENGINE),
            'engine_version': subprocess.check_output([str(ENGINE),'--version'],text=True).strip(),
            'janga_path': str(janga), 'janga_sha256': sha(janga),
            'build_path': 'builds/GripUp-v1.2-pre-v1.3.exe', 'build_sha256': sha(ROOT/'builds/GripUp-v1.2-pre-v1.3.exe'),
            'startup_profile': 2, 'comparison_profile': 4, 'allocation': 'A0', 'comparison_feet': 'B1',
            'human_sessions': 0, 'v12_state': 'Technical suite present; experiment stopped by user; no human preference or mastery acceptance'}
    out.parent.mkdir(parents=True,exist_ok=True)
    out.write_text(json.dumps(data,indent=2)+'\n',encoding='utf-8')
    print('Frozen', len(files), 'existing feature files at', data['commit'])
