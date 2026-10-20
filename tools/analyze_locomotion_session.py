"""Offline six-group timelines and raw comparisons; no gameplay or rating synthesis.

Run with an environment containing matplotlib, e.g.
uv run --with matplotlib python tools/analyze_locomotion_session.py SESSION_DIR
"""
from pathlib import Path
import argparse
import csv
import gzip
import html
import json
import math
import statistics

parser = argparse.ArgumentParser()
parser.add_argument('sessions', nargs='+', type=Path)
parser.add_argument('--output', type=Path, default=Path('builds/v12_analysis'))
args = parser.parse_args()
args.output.mkdir(parents=True, exist_ok=True)

def read_jsonl(path):
    opener = gzip.open if path.suffix == '.gz' else open
    with opener(path, 'rt', encoding='utf-8') as stream:
        for line in stream:
            if line.strip():
                value = json.loads(line)
                if not isinstance(value, dict):
                    raise ValueError('Expected a JSON object per sample/event')
                yield value

def norm(value):
    return math.sqrt(sum(float(x)**2 for x in value)) if isinstance(value, list) and len(value) == 3 else math.nan

def dot(a, b):
    return sum(float(x)*float(y) for x, y in zip(a, b))

runs = []
table = []
for directory in args.sessions:
    summary = json.loads((directory / 'summary.json').read_text(encoding='utf-8'))
    raw = directory / 'samples.jsonl'
    if not raw.exists():
        raw = raw.with_suffix('.jsonl.gz')
    rows = list(read_jsonl(raw))
    if not rows:
        raise ValueError('No physical samples: ' + str(directory))
    events = list(read_jsonl(directory / 'events.jsonl'))
    row = {'session': directory.name, 'source': summary['source'], 'scenario': summary['scenario'],
           'revision': summary['scenario_revision'], 'variant': summary['variant']['id'],
           'physics_hz': summary['physics_hz'], 'completed': summary['result']['completed'],
           'reason': summary['result']['reason'], 'duration_s': summary['result']['duration_s'],
           'useful_progress_m': summary['movement']['useful_progress_m'],
           'path_length_m': summary['movement']['path_length_m'],
           'directional_efficiency': summary['movement']['directional_efficiency'],
           'twist_rms_rad': summary['rotation']['twist_rms_rad'],
           'foot_load_fraction_hands_feet': summary['support']['foot_upward_load_fraction'],
           'attempts': summary['capture']['attempts'], 'contacts': summary['capture']['contacts'],
           'retained': summary['capture']['retained'], 'build_id': summary['build_identity']['build_id'],
           'tester_id': summary.get('tester_id'), 'mode': summary.get('mode'),
           'attempt_order': summary.get('attempt_order'), 'condition': summary.get('condition')}
    ratings = summary.get('assessment', {}).get('human_ratings') or {}
    for key in ('control_response', 'predictability', 'grip_aiming', 'swing_agency', 'comfort', 'skill_expression', 'replay_desire'):
        row['rating_'+key] = ratings.get(key)
    table.append(row)
    runs.append((directory, summary, rows, events))
with (args.output / 'attempts.csv').open('w', newline='', encoding='utf-8') as stream:
    writer = csv.DictWriter(stream, fieldnames=list(table[0]))
    writer.writeheader(); writer.writerows(table)

# Paired within-person deltas stay separate from technical/scripted evidence.
paired = []
fields = ('useful_progress_m', 'directional_efficiency', 'twist_rms_rad', 'duration_s')
human_rows = [row for row in table if row['source'] == 'human' and row['mode'] in ('scored', 'retention')]
groups = {}
for row in human_rows:
    key = tuple(row.get(name) for name in ('tester_id','scenario','revision','physics_hz','condition','mode'))
    groups.setdefault(key, []).append(row)
for key, values in groups.items():
    reference = sorted([row for row in values if row['variant'] == 'V0'], key=lambda row: row['attempt_order'])
    for variant in ('V1','V3','V4'):
        comparison = sorted([row for row in values if row['variant'] == variant], key=lambda row: row['attempt_order'])
        for ordinal, (a, b) in enumerate(zip(reference, comparison), 1):
            for metric in fields:
                delta = b[metric]-a[metric] if a[metric] is not None and b[metric] is not None else None
                paired.append({'tester_id':key[0], 'scenario':key[1], 'hz':key[3], 'variant':variant,
                               'pair_ordinal':ordinal,'metric':metric,'V0':a[metric],'variant_value':b[metric],
                               'delta':delta, 'percent_of_abs_reference':delta/abs(a[metric])*100 if delta is not None and abs(a[metric])>1e-6 else None,
                               'order':'AB' if a['attempt_order']<b['attempt_order'] else 'BA',
                               'same_build':a['build_id']==b['build_id'],
                               'scope':'Ordinal within-person pair; learning/order and initial-pose differences still require review'})
pair_fields = ['tester_id','scenario','hz','variant','pair_ordinal','metric','V0','variant_value','delta','percent_of_abs_reference','order','same_build','scope']
with (args.output / 'human_pairs.csv').open('w', newline='', encoding='utf-8') as stream:
    writer = csv.DictWriter(stream, fieldnames=pair_fields); writer.writeheader(); writer.writerows(paired)
distributions = []
group_keys = ('source','scenario','variant','physics_hz','mode')
for key in sorted(set(tuple(str(row.get(name)) for name in group_keys) for row in table)):
    attempts = [row for row in table if tuple(str(row.get(name)) for name in group_keys)==key]
    for metric in fields:
        values = [row[metric] for row in attempts if row[metric] is not None]
        if values:
            distributions.append(dict(zip(group_keys,key),metric=metric,n=len(values),attempts=len(attempts),
                                      completions=sum(bool(row['completed']) for row in attempts),
                                      mean=statistics.mean(values),min=min(values),max=max(values),
                                      sample_sd=statistics.stdev(values) if len(values)>1 else None,
                                      scope='Descriptive only; no mastery/default promotion inferred'))
with (args.output / 'distributions.csv').open('w', newline='', encoding='utf-8') as stream:
    writer = csv.DictWriter(stream, fieldnames=list(group_keys)+['metric','n','attempts','completions','mean','min','max','sample_sd','scope']); writer.writeheader(); writer.writerows(distributions)

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

def group_limits(summary, key):
    values = []
    for _, other, samples, _ in runs:
        if (other['scenario'],other['scenario_revision'],other['physics_hz']) != (summary['scenario'],summary['scenario_revision'],summary['physics_hz']):
            continue
        first = samples[0]['com_position']
        direction = other['direction_world']
        for row in samples:
            value = None
            if key == 'progress': value = dot([row['com_position'][i]-first[i] for i in range(3)],direction)
            elif key == 'velocity': value = dot(row['velocity'],direction)
            elif key == 'spin': value = norm(row['angular_velocity'])
            elif key == 'twist': value = row.get('twist_rad')
            elif key == 'angle': value = row.get('pendulum_angle_rad')
            elif key == 'power': value = row.get('swing_power')
            if isinstance(value,(int,float)) and math.isfinite(value): values.append(value)
    if not values: return (-1,1)
    low, high = min(0,min(values)), max(0,max(values))
    margin = max(.01,(high-low)*.08)
    return (low-margin,high+margin)

plots = []
for index, (directory, summary, rows, events) in enumerate(runs):
    direction = summary['direction_world']
    first = rows[0]['com_position']
    start = rows[0]['time']
    times = [row['time']-start for row in rows]
    progress = [dot([row['com_position'][i]-first[i] for i in range(3)], direction) for row in rows]
    requested = [dot(row['movement_intent_world'], direction) for row in rows]
    hand_loads = [sum(norm(value) for value in row['hand_forces']) for row in rows]
    foot_loads = [sum(norm(contact['force']) for contact in row.get('contacts', [])
                      if contact.get('kind') == 'foot' and contact.get('applied') and contact.get('state') in ('SUPPORTING', 'SLIDING')) for row in rows]
    fig, axes = plt.subplots(8, 1, figsize=(14, 21), sharex=True, constrained_layout=True)
    fig.suptitle(f"{summary['scenario']} r{summary['scenario_revision']} / {summary['variant']['id']} / {summary['physics_hz']} Hz / {summary['source']}\n"
                 f"{directory.name} / build {summary['build_identity']['build_id'][:16]} / COM; no human mastery inferred", fontsize=12)
    axes[0].plot(times, progress, label='Actual signed COM progress', color='#117a75')
    axes[0].axhline(0, color='gray', linewidth=.5); axes[0].set_ylabel('1 Progress (m)')
    intent_axis = axes[0].twinx(); intent_axis.plot(times, requested, alpha=.4, color='#bf7600', label='Accepted intent')
    intent_axis.set_ylim(-1.1, 1.1); intent_axis.set_ylabel('Intent projection (unitless)')
    axes[1].plot(times, [dot(row['velocity'], direction) for row in rows], label='Useful world velocity')
    axes[1].set_ylabel('2a Velocity (m/s)')
    axes[2].plot(times, [norm(row['angular_velocity']) for row in rows], label='Actual body angular speed')
    axes[2].set_ylabel('2b Spin (rad/s)')
    axes[3].plot(times, [row.get('twist_rad') if row.get('twist_rad') is not None else math.nan for row in rows], label='Support-relative axial twist')
    axes[3].set_ylabel('2c Twist (rad)')
    axes[4].plot(times, hand_loads, label='Hands admitted force magnitude sum')
    axes[4].plot(times, foot_loads, label='Loaded feet admitted force magnitude sum')
    axes[4].axhline(360, linestyle='--', alpha=.4, label='Hands 360 N cap')
    axes[4].axhline(180, linestyle=':', alpha=.4, label='Feet 180 N cap')
    axes[4].set_ylim(0, max(380, max(hand_loads+foot_loads)*1.05)); axes[4].set_ylabel('3 Forces (N)')
    for kind, color in [('attempt', '#bf7600'), ('contact', '#117a75'), ('retained', '#377e22'), ('release', '#be3232'), ('slip', '#833d9b')]:
        selected = [event for event in events if event.get('type') == kind]
        axes[5].scatter([event['time']-start for event in selected], [event.get('hand_id', -1) for event in selected], label=kind, color=color, s=25)
    axes[5].set_yticks([-1, 0, 1], ['session', 'left', 'right']); axes[5].set_ylabel('4 Grip events')
    axes[6].plot(times, [row.get('pendulum_angle_rad') if row.get('pendulum_angle_rad') is not None else math.nan for row in rows], label='Pendulum deflection')
    axes[6].set_ylabel('5 Angle (rad)')
    power_axis = axes[6].twinx(); power_axis.plot(times, [row.get('swing_power', math.nan) for row in rows], color='#bf7600', alpha=.5)
    power_axis.axhline(0, color='gray', linewidth=.5); power_axis.set_ylabel('Incremental swing power (W)')
    for bit, name, lane in [(1, 'ground', 0), (2, 'hands', 1), (4, 'feet', 2), (8, 'swing', 3), (16, 'hybrid', 4)]:
        axes[7].step(times, [lane if row.get('owner_bits', 0)&bit else math.nan for row in rows], where='post', label=name)
    axes[7].set_yticks(range(5), ['ground', 'hands', 'feet', 'swing', 'hybrid']); axes[7].set_ylabel('6 Authority'); axes[7].set_xlabel('Physics time since first sample (s)')
    for axis in axes:
        axis.grid(alpha=.2); axis.legend(fontsize=8, loc='upper left')
    for axis, key in zip([axes[0],axes[1],axes[2],axes[3],axes[6],power_axis],['progress','velocity','spin','twist','angle','power']):
        axis.set_ylim(*group_limits(summary,key))
    basename = f'{index+1:02}_{summary["scenario"]}_{summary["variant"]["id"]}_{summary["physics_hz"]}hz'
    fig.savefig(args.output / (basename+'.png'), dpi=120)
    fig.savefig(args.output / (basename+'.svg'))
    plt.close(fig)
    plots.append(basename+'.png')

body = '<!doctype html><meta charset="utf-8"><title>GRIP UP v1.2 timelines</title><style>body{font:16px system-ui;max-width:1200px;margin:30px auto;padding:16px;background:#f5f6f4;color:#152a32}img{width:100%}table{border-collapse:collapse}td,th{border:1px solid #ccc;padding:6px}code{overflow-wrap:anywhere}</style><h1>GRIP UP v1.2 — offline traces</h1><p>Raw per-attempt evidence. Scripted success does not establish human mastery. Force work excludes ground and torque work. Swing power is incremental, not total system energy. Missing values remain missing; no hidden combined score.</p>'
body += '<table><tr>'+''.join('<th>'+html.escape(key)+'</th>' for key in ('source','scenario','variant','physics_hz','completed','useful_progress_m','directional_efficiency'))+'</tr>'
for row in table:
    body += '<tr>'+''.join('<td>'+html.escape(str(row[key]))+'</td>' for key in ('source','scenario','variant','physics_hz','completed','useful_progress_m','directional_efficiency'))+'</tr>'
body += '</table>'
for row, plot in zip(table, plots):
    body += '<h2>'+html.escape(row['session'])+'</h2><p><code>'+html.escape(row['build_id'])+'</code></p><img src="'+html.escape(plot)+'">'
(args.output / 'index.html').write_text(body, encoding='utf-8')
print('Offline CSV, PNG, SVG and HTML:', args.output.resolve())
