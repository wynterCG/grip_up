"""Recompute descriptive F0 evidence; this is not an optimizer or a pass gate."""
from pathlib import Path
import hashlib
import json
import math
import sys

ROOT = Path(__file__).resolve().parents[3]
ATTEMPTS = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / 'builds/foot_release_v14_r1/attempts'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
norm = lambda v: math.sqrt(sum(x*x for x in v))
output = {'classification': 'F0_PARTIAL_KEEP_B1_NO_B3',
          'boundary': 'First and last POST rows of each stage; not driver START/END boundaries',
          'human_acceptance': False, 'attempts': [], 'matched_prefixes': []}
all_rows = {}
for directory in sorted(ATTEMPTS.glob('F0_*_headless')):
    report = json.loads((directory / 'attempt_report.json').read_text())
    rows = [json.loads(line) for line in (directory / 'physics.jsonl').read_text().splitlines()]
    assert rows and all(math.isfinite(x) for row in rows for x in row['body_COM'] + row['body_velocity'])
    all_rows[directory.name] = rows
    record = {'attempt': directory.name, 'status': report['status'], 'hz': report['physics_hz'],
              'localized_window_reached': report['reached_localized_cross_window'],
              'budgets_ok': report['budgets_ok'], 'row_count': len(rows),
              'raw_sha256': {p.name: sha(p) for p in sorted(directory.iterdir()) if p.is_file()}, 'stages': []}
    for stage in dict.fromkeys(row['stage'] for row in rows):
        samples = [row for row in rows if row['stage'] == stage]
        forces = [foot for row in samples for foot in row['feet']]
        record['stages'].append({'stage': stage, 'first_tick': samples[0]['tick'], 'last_tick': samples[-1]['tick'],
            'sample_count': len(samples), 'observed_duration_s': sum(row['delta_s'] for row in samples),
            'COM_displacement_m': [b-a for a,b in zip(samples[0]['body_COM'],samples[-1]['body_COM'])],
            'start_velocity_m_s': samples[0]['body_velocity'], 'end_velocity_m_s': samples[-1]['body_velocity'],
            'peak_per_foot_N': max(norm(f['actual_applied_force_N']) for f in forces),
            'summed_submitted_foot_impulse_Ns': [sum(f['actual_applied_force_N'][i]*r['delta_s'] for r in samples for f in r['feet']) for i in range(3)],
            'min_individual_foot_intent_projection_N': min(f['force_along_intent_N'] for f in forces),
            'zero_load_supporting_foot_samples': sum(f['state']=='SUPPORTING' and norm(f['actual_applied_force_N'])<1e-6 for f in forces),
            'rows_with_reported_FootBase': sum(r['native'].get('shape_reported_counts',{}).get('FootBase',0)>0 for r in samples)})
    output['attempts'].append(record)
for hz in (120,60):
    original = all_rows[f'F0_B1_{hz}_headless']
    switched = all_rows[f'F0_ABLATION_{hz}_headless']
    keys = ['body_COM', 'body_velocity', 'body_spin', 'hands', 'FootBase_transform', 'lower_collider_transform']
    first = next((a['tick'] for a,b in zip(original,switched) if any(a[k]!=b[k] for k in keys)), None)
    report = json.loads((ATTEMPTS/f'F0_ABLATION_{hz}_headless/attempt_report.json').read_text())
    event = report['cross_ablation']
    output['matched_prefixes'].append({'hz':hz,'switch_tick':event['tick'], 'first_state_or_hand_force_divergence_tick':first,
        'setter_preserved_body_hands_native':event['body_native_geometry_and_hands_unchanged_by_setter'],
        'later_stage_onsets_matched':False, 'caveat':'Existing feet-OFF setter changes solver and visual ownership; later neutral evolves differently'})
assert len(output['attempts']) == 6
assert [x['first_state_or_hand_force_divergence_tick'] for x in output['matched_prefixes']] == [900,455]
destination = Path(__file__).with_name('F0_measurements.json')
destination.write_text(json.dumps(output,indent=2)+'\n',encoding='utf-8')
print('Reduced six preserved attempts:',destination)
