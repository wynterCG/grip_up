"""Archive completed visible MCP runs; never equate automation with human feel."""
from pathlib import Path
from datetime import datetime, timezone
import gzip
import hashlib
import json
import shutil

root = Path(__file__).resolve().parents[1]
base = root / 'docs/validation/v11/native'
base.mkdir(parents=True, exist_ok=True)
number = 1
while (base / f'attempt_{number:03}').exists():
    number += 1
out = base / f'attempt_{number:03}'
out.mkdir()
report = {'recorded_utc': datetime.now(timezone.utc).isoformat(),
          'provenance': 'Visible Godot MCP Pro automation, not human ratings', 'runs': []}
for hz in (120, 60):
    path = root / f'builds/locomotion_refinement_native_{hz}hz.json'
    raw = path.read_bytes()
    data = json.loads(raw)
    assert data['complete'] and data['rendered'] and data['physics_hz'] == hz
    assert data['allocation_variant'] == 0 and data['intent_aware_feet']
    assert data['window_screen'] == 0
    (out / (path.name + '.gz')).write_bytes(gzip.compress(raw, mtime=0))
    windows = data['observer_windows']['complete']
    rows = [row for window in windows for side in ('before', 'after') for row in window[side]]
    assisted = [row for row in rows if row['assisted']]
    hybrid_exclusive = all(row['owner_bits'] == 16 for row in assisted)
    assisted_hands_zero = bool(assisted) and all(
        len(row['hand_forces']) == 2 and all(str(v).replace(' ', '') == '(0.0,0.0,0.0)' for v in row['hand_forces'])
        for row in assisted)
    report['runs'].append({
        'hz': hz, 'checks': data['checks'], 'failures': data['failures'],
        'passed': data['failures'] == 0 and hybrid_exclusive and assisted_hands_zero,
        'screen': data['window_screen'], 'allocation': 'A0', 'feet': 'B2',
        'feedback': data['swing_phase_feedback'], 'peaks': data['peaks'],
        'complete_transition_windows': len(windows),
        'pending_transition_windows': len(data['observer_windows']['pending']),
        'assisted_rows_in_windows': len(assisted), 'hybrid_exclusive': hybrid_exclusive,
        'assisted_hand_forces_zero': assisted_hands_zero,
        'observer_cpu_usec_final_tick': data['last_observation'].get('observer_cpu_usec'),
        'raw_sha256': hashlib.sha256(raw).hexdigest(),
        'file_mtime_utc': datetime.fromtimestamp(path.stat().st_mtime, timezone.utc).isoformat(),
    })
    for label in ('stage_2', 'cross_0.60', 'finish'):
        source = root / f'builds/v11_{hz}hz_{label}.png'
        shutil.copy2(source, out / source.name)
runtime_root = Path(r'E:\Godot Games\grip_up')
report['runtime_source_root'] = str(runtime_root)
report['source_sha256'] = {
    str(p.relative_to(runtime_root)).replace('\\', '/'): hashlib.sha256(p.read_bytes()).hexdigest()
    for p in (runtime_root / 'features/grip_up').rglob('*') if p.is_file() and p.suffix in ('.gd', '.tres')}
report['all_passed'] = all(row['passed'] for row in report['runs'])
(out / 'results.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps({'archive': str(out), 'runs': report['runs'], 'all_passed': report['all_passed']}))
raise SystemExit(0 if report['all_passed'] else 1)
