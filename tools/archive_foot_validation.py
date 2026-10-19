"""Archive completed native M2 comparisons without changing baseline evidence."""
from pathlib import Path
import json
import os
import shutil

root = Path(__file__).resolve().parents[1]
dest = root/'docs'/'validation'/'m2'
dest.mkdir(parents=True,exist_ok=True)
userdata = Path(os.environ['APPDATA'])/'Godot/app_userdata/GRIP UP'
for hz in [120,60]:
    report = json.loads((root/f'builds/feet_capture_{hz}hz.json').read_text())
    assert report['complete'] and report['physics_hz']==hz
    off,on = report['runs']
    assert off['hands_after']==on['hands_after']==2 and on['planted_samples']>=hz
    assert on['hand_load']<off['hand_load']*.85 and on['leg_load']>10
    (dest/f'rendered_{hz}hz.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    for label in ['support_off','support_on','debug','controls']:
        shutil.copy2(root/f'builds/m2_{hz}hz_{label}.png',dest/f'{hz}hz_{label}.png')
    sessions = [[]]
    for line in (userdata/f'm2_rendered_capture_{hz}hz.jsonl').read_text(encoding='utf-8').splitlines():
        row = json.loads(line)
        if sessions[-1] and row['time']<sessions[-1][-1]['time']:
            sessions.append([])
        sessions[-1].append(row)
    rows = [row for session in sessions[-2:] for row in session]
    assert rows and any(row['feet'] and row['feet'][0]['normal_force']>1 for row in rows)
    (dest/f'rendered_samples_{hz}hz.jsonl').write_text(''.join(json.dumps(row,allow_nan=False)+'\n' for row in rows),encoding='utf-8')
print('Archived native M2 comparison, both frequencies:',dest)
