"""Archive successful native relative-input runs; older experiments stay intact."""
from pathlib import Path
import json
import os
import shutil

root = Path(__file__).resolve().parents[1]
dest = root/'docs/validation/contextual'
dest.mkdir(parents=True,exist_ok=True)
userdata = Path(os.environ['APPDATA'])/'Godot/app_userdata/GRIP UP'
for hz in [120,60]:
    report=json.loads((root/f'builds/contextual_capture_{hz}hz.json').read_text())
    assert report['complete'] and report['physics_hz']==hz
    assert all(item['passed'] for item in report['checks'])
    assert report['rise_m']>.04 and report['lower_m']>.03
    (dest/f'rendered_{hz}hz.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    for label in ['free_aim','contracted','aim_reposition','dual_posture','controls']:
        shutil.copy2(root/f'builds/contextual_{hz}hz_{label}.png',dest/f'{hz}hz_{label}.png')
    rows=[json.loads(line) for line in (userdata/f'contextual_rendered_{hz}hz.jsonl').read_text(encoding='utf-8').splitlines()]
    assert rows and all(row['control_profile']==2 and row['total_force']<=360.001 for row in rows)
    (dest/f'rendered_samples_{hz}hz.jsonl').write_text(''.join(json.dumps(row,allow_nan=False)+'\n' for row in rows),encoding='utf-8')
print('Archived native contextual checks, both rates:',dest)
