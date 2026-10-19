"""Archive final v0.7 observations without converting scripts into human evidence."""
from pathlib import Path
import gzip,hashlib,json,shutil,subprocess

root=Path(__file__).resolve().parents[1]
out=root/'docs/validation/v07/final'
out.mkdir(exist_ok=True)
user=Path.home()/'AppData/Roaming/Godot/app_userdata/GRIP UP'
for hz in [120,60]:
    native=json.loads((root/f'builds/intent_native_{hz}hz.json').read_text())
    assert native['complete'] and not native['focus_events'] and all(c['passed'] for c in native['checks'])
    shutil.copy2(root/f'builds/intent_native_{hz}hz.json',out/f'rendered_{hz}hz.json')
    trace=user/f'v07_native_{hz}hz.jsonl'
    with gzip.open(out/f'trace_{hz}hz.jsonl.gz','wb') as target:target.write(trace.read_bytes())
    sessions={json.loads(line).get('transfer_session','') for line in trace.read_text(encoding='utf-8').splitlines()}
    for session in sessions-{'','unknown'}:
        for source in (user/'transfer_sessions').glob(session+'*'):
            (out/'sessions').mkdir(exist_ok=True)
            shutil.copy2(source,out/'sessions'/source.name)
    for label in ['step_false','step_true','traverse','hang']:
        shutil.copy2(root/f'builds/v04_{hz}hz_v07_{label}.png',out/f'{hz}hz_{label}.png')
    for name in ['intent_locomotion','intent_swing','intent_integration','intent_arenas']:
        shutil.copy2(root/f'builds/{name}_{hz}hz.json',out/f'{name}_{hz}hz.json')
frame_count=json.loads((out/'rendered_120hz.json').read_text())['demo_frames']
subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-framerate','15','-i',str(root/'builds/v07_candidate_frames/%05d.jpg'),'-frames:v',str(frame_count),'-c:v','libx264','-crf','24','-pix_fmt','yuv420p',str(out/'scripted_candidate.mp4')],check=True)
manifest={str(p.relative_to(out)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(out.rglob('*')) if p.is_file() and p.name!='manifest.json'}
(out/'manifest.json').write_text(json.dumps({'provenance':'MCP scripted input, not human pilot','files':manifest},indent=2)+'\n',encoding='utf-8')
print('Archived',len(manifest),'evidence files')
