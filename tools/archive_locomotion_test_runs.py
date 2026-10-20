"""Archive only explicitly scripted visible trials; never collect human files."""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import gzip
import hashlib
import json
import shutil

root = Path(__file__).resolve().parents[1]
saved = Path(r'E:\Godot Games\grip_up')
userdata = Path.home() / 'AppData/Roaming/Godot/app_userdata/GRIP UP'
parser = argparse.ArgumentParser()
parser.add_argument('--soak', action='store_true')
parser.add_argument('--hz', nargs='+', type=int, default=[120, 60])
args = parser.parse_args()
base = root / 'docs/validation/v12/native'
base.mkdir(parents=True, exist_ok=True)
number = 1
while (base / f'attempt_{number:03}').exists(): number += 1
out = base / f'attempt_{number:03}'
out.mkdir()
report = {'recorded_utc': datetime.now(timezone.utc).isoformat(), 'source': 'scripted', 'runs': []}
def write(path, raw):
    path.with_suffix(path.suffix+'.gz').write_bytes(gzip.compress(raw, mtime=0))
def archive_session(uri, destination):
    source = userdata / uri.removeprefix('user://')
    assert source.resolve().is_relative_to((userdata/'locomotion_v12/sessions').resolve())
    summary = json.loads((source/'summary.json').read_text(encoding='utf-8'))
    assert summary['source'] == 'scripted', 'Refusing to publish human/exploratory records'
    destination.mkdir()
    for name in ('metadata.json','events.jsonl','summary.json'):
        shutil.copy2(source/name,destination/name)
    write(destination/'samples.jsonl',(source/'samples.jsonl').read_bytes())
    return summary
for hz in args.hz:
    path = root / f'builds/v12_native_{hz}hz.json'
    data = json.loads(path.read_text(encoding='utf-8'))
    assert data['complete'] and data['source']=='scripted' and data['physics_hz']==hz
    write(out/path.name,path.read_bytes())
    trial = data['trial']
    archive_session(trial['recording']['path'],out/f'trial_{hz}hz')
    for label in ('measured_task','test_ui'):
        shutil.copy2(root/f'builds/v12_{hz}hz_{label}.png',out/f'v12_{hz}hz_{label}.png')
    report['runs'].append({'hz':hz,'checks':data['checks'],'failures':data['failures'],'screen':data['screen'],
                           'build_id':trial['build_identity']['build_id'], 'source_commit':trial['build_identity']['commit'],
                           'source_dirty':trial['build_identity']['dirty_tree'],'human_ratings':None})
if args.soak:
    path = root/'builds/v12_soak.json'
    data = json.loads(path.read_text(encoding='utf-8'))
    assert data['complete'] and data['real_wall_soak_s']>=600
    write(out/path.name,path.read_bytes())
    summary = archive_session(data['session_path'],out/'soak_session')
    samples = data['memory_samples']
    phases = {key:dict(value, mean_process_monitor_ms=value['process_ms_sum']/value['frames'],
                      mean_physics_monitor_ms=value['physics_monitor_ms_sum']/value['frames']) for key,value in data['phases'].items()}
    report['soak']={'real_wall_soak_s':data['real_wall_soak_s'],'physics_duration_s':summary['duration_s'],
                    'sample_count':summary['recording']['written_samples'],'buffers':summary['buffers'],
                    'memory_first_bytes':samples[0]['static_bytes'],'memory_last_bytes':samples[-1]['static_bytes'],
                    'memory_range_bytes':[min(row['static_bytes'] for row in samples),max(row['static_bytes'] for row in samples)],
                    'memory_sample_count':len(samples),'phases':phases,
                    'scope':'One real-time idle session; monitor costs and process-local static memory, not a human stress/feel study',
                    'build_id':summary['build_identity']['build_id']}
report['runtime_source_sha256']={p.relative_to(saved).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
                                 for p in (saved/'features').rglob('*.gd')}
report['all_passed']=all(row['failures']==0 for row in report['runs'])
(out/'results.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'archive':str(out),'runs':report['runs'],'soak':report.get('soak'),'all_passed':report['all_passed']}))
