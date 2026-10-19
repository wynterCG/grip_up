"""Archive native MCP Pro evidence; keep negative trials and baseline intact."""
from pathlib import Path
import json
import os
import shutil

root = Path(__file__).resolve().parents[1]
dest = root/'docs/validation/v04'
userdata = Path(os.environ['APPDATA'])/'Godot/app_userdata/GRIP UP'
dest.mkdir(parents=True,exist_ok=True)
for hz in [120,60]:
    report=json.loads((root/f'builds/independent_capture_{hz}hz.json').read_text())
    assert report['complete'] and report['physics_hz']==hz
    assert all(item['passed'] for item in report['checks'])
    (dest/f'rendered_{hz}hz.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    for shot in report['snapshots']:
        label=shot['label']
        shutil.copy2(root/f'builds/v04_{hz}hz_{label}.png',dest/f'{hz}hz_{label}.png')
    rows=[json.loads(line) for line in (userdata/f'v04_rendered_{hz}hz.jsonl').read_text(encoding='utf-8').splitlines()]
    assert rows and all(row['control_profile']==3 and row['total_force']<=360.001 and row['aim_input_does_not_change_length'] for row in rows)
    (dest/f'rendered_samples_{hz}hz.jsonl').write_text(''.join(json.dumps(row,allow_nan=False)+'\n' for row in rows),encoding='utf-8')
    shutil.copy2(root/f'builds/independent_routes_{hz}hz.json',dest/f'transfer_routes_{hz}hz.json')
print('Archived native independent-aim checks and routes:',dest)
