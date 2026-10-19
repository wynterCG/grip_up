"""Archive final v0.7 observations without converting scripts into human evidence."""
from pathlib import Path
import gzip,hashlib,json,shutil,subprocess,sys

root=Path(__file__).resolve().parents[1]
version=sys.argv[1] if len(sys.argv)>1 else 'v07'
assert version in ['v07','v071']
native_prefix='intent_refinement' if version=='v071' else 'intent'
labels=['step_false','step_true','first_handoff','second_handoff','hang'] if version=='v071' else ['step_false','step_true','traverse','hang']
test_names=['intent_locomotion','intent_swing','intent_integration','intent_arenas']
if version=='v071':test_names+=['intent_reversal','intent_progress','intent_handoffs','intent_frame_sign']
out=root/f'docs/validation/{version}/final'
out.mkdir(exist_ok=True)
user=Path.home()/'AppData/Roaming/Godot/app_userdata/GRIP UP'
for hz in [120,60]:
    native=json.loads((root/f'builds/{native_prefix}_native_{hz}hz.json').read_text())
    assert native['complete'] and not native['focus_events'] and all(c['passed'] for c in native['checks'])
    shutil.copy2(root/f'builds/{native_prefix}_native_{hz}hz.json',out/f'rendered_{hz}hz.json')
    trace=user/f'{version}_native_{hz}hz.jsonl'
    with gzip.open(out/f'trace_{hz}hz.jsonl.gz','wb') as target:target.write(trace.read_bytes())
    sessions={json.loads(line).get('transfer_session','') for line in trace.read_text(encoding='utf-8').splitlines()}
    for session in sessions-{'','unknown'}:
        for source in (user/'transfer_sessions').glob(session+'*'):
            (out/'sessions').mkdir(exist_ok=True)
            shutil.copy2(source,out/'sessions'/source.name)
    for label in labels:
        shutil.copy2(root/f'builds/v04_{hz}hz_{version}_{label}.png',out/f'{hz}hz_{label}.png')
    for name in test_names:
        shutil.copy2(root/f'builds/{name}_{hz}hz.json',out/f'{name}_{hz}hz.json')
frame_count=json.loads((out/'rendered_120hz.json').read_text())['demo_frames']
subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-framerate','15','-i',str(root/f'builds/{version}_candidate_frames/%05d.jpg'),'-frames:v',str(frame_count),'-c:v','libx264','-crf','24','-pix_fmt','yuv420p',str(out/'scripted_candidate.mp4')],check=True)
manifest={str(p.relative_to(out)).replace('\\','/'):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(out.rglob('*')) if p.is_file() and p.name!='manifest.json'}
(out/'manifest.json').write_text(json.dumps({'provenance':'MCP scripted input, not human pilot','files':manifest},indent=2)+'\n',encoding='utf-8')
print('Archived',len(manifest),'evidence files')
