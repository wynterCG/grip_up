"""Read-only report assembly; run with the frozen uv environment from project root.

python docs/validation/auto_tuning/v131/analyze_controls.py SESSION OUTPUT
This does not re-run metric formulas or rewrite raw experiment receipts.
"""
from pathlib import Path
import collections
import hashlib
import json
import math
import statistics
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / 'tools/auto_tuning'))
from compare_traces import iter_trace


def read(path):
    return json.loads(path.read_text(encoding='utf-8'))


def norm(value):
    return math.sqrt(sum(x*x for x in value))


def stats(values):
    return {'n': len(values), 'min': min(values) if values else None,
            'max': max(values) if values else None,
            'mean': statistics.mean(values) if values else None,
            'sample_sd': statistics.stdev(values) if len(values) > 1 else None}


def assemble(session, output):
    state = read(session/'session_state.json')
    if state['status'] != 'completed':
        raise ValueError('Incomplete matrix: preserve it separately, do not certify this report')
    if output.exists():
        raise FileExistsError(output)
    output.mkdir(parents=True)
    groups = collections.defaultdict(list)
    counts = {key: collections.Counter() for key in ('main', 'braking', 'horizons')}
    raw_status = collections.Counter()
    runs = []
    for entry in state['runs']:
        directory = session/entry['path']
        manifest = read(directory/'manifest.json')
        result = read(directory/'engine_result.json')
        typed = read(directory/'typed_metrics.json')['scenarios']
        runs.append((directory, manifest, result))
        for row in result['scenarios']:
            metric = typed[row['id']]
            raw_status[row['status']] += 1
            counts['main'].update(x['status'] for x in metric['metrics'].values())
            counts['braking'].update(x[field]['status'] for x in metric['active_braking'] for field in ('time_s', 'distance_m'))
            counts['horizons'].update(x['status'] for x in metric['fixed_horizons'])
            snapshot = row['precondition_snapshot']
            v = [a-b for a,b in zip(snapshot['body']['linear_velocity_m_s'], snapshot['support']['point_velocity_m_s'])]
            w = [a-b for a,b in zip(snapshot['body']['angular_velocity_rad_s'], snapshot['support']['angular_velocity_rad_s'])]
            accepted = row['status'] != 'precondition_not_met' and 'requested_tick' in row['transition']
            groups[(row['id'], manifest['engine_mode'], manifest['physics_hz'])].append({
                'run_id': manifest['run_id'], 'status': row['status'], 'reason': row['reason'],
                'transition': row['transition'], 'metrics': metric['metrics'],
                'active_braking': metric['active_braking'], 'fixed_horizons': metric['fixed_horizons'],
                'accepted_transition_observed': accepted,
                'actual_onset_speed_m_s': norm(v) if accepted else None,
                'actual_onset_spin_rad_s': norm(w) if accepted else None,
                'onset_feet_total_n': snapshot['force_budget']['feet_n'] if accepted else None,
                'last_preparation_speed_m_s': norm(v), 'last_preparation_spin_rad_s': norm(w),
                'raw_observed_signed_progress_m': row['metrics']['useful_displacement_m'],
                'accepted_input': snapshot['command_accepted']['accepted_input'] if accepted else None,
                'onset_grounded': snapshot['support']['grounded'] if accepted else None,
                'onset_hybrid': snapshot['support']['hybrid_owned'] if accepted else None})
    summaries = []
    for (scenario, mode, hz), items in sorted(groups.items()):
        summaries.append({'scenario': scenario, 'mode': mode, 'hz': hz, 'n': len(items),
            'statuses': dict(collections.Counter(x['status'] for x in items)),
            'metrics': {name: {'statuses': dict(collections.Counter(x['metrics'][name]['status'] for x in items)),
                              'measured_values': stats([x['metrics'][name]['value'] for x in items if x['metrics'][name]['status'] == 'MEASURED'])}
                        for name in items[0]['metrics']}, 'observations': items})
    summary = {'analysis_sha256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'session_manifest_sha256': hashlib.sha256((session/'session_manifest.json').read_bytes()).hexdigest(),
        'scope': 'Existing frozen typed results; measured values exclude every censored/interrupted/invalid value, never substitute zero. No scoring or automatic equivalence.',
        'evaluations': len(runs), 'observations': sum(len(x) for x in groups.values()),
        'raw_statuses': dict(raw_status), 'metric_status_counts': {k: dict(v) for k,v in counts.items()},
        'groups': summaries}
    (output/'control_summary.json').write_text(json.dumps(summary, indent=2)+'\n', encoding='utf-8')
    lines = ['# Locomotion control observations', '',
        'Existing metric receipts, not recalculated under another catalogue. Only MEASURED values enter ranges. '
        'A valid observation is distinct from positive performance. Signed progress uses each declared axis; reversal follows the newly accepted command.', '',
        '| Case | Mode / Hz | Runtime states | Stop distance, measured range (m) | Settling, measured range (s) | Reversal, measured range (s) |',
        '|---|---|---|---|---|---|']
    def span(group, name):
        x = group['metrics'][name]['measured_values']
        return f"{x['min']:.6f}–{x['max']:.6f} (n={x['n']})" if x['n'] else 'No MEASURED value'
    for x in summaries:
        lines.append(f"| {x['scenario']} | {x['mode']} / {x['hz']} | {x['statuses']} | {span(x,'stop_distance_m')} | {span(x,'settling_time_s')} | {span(x,'reversal_time_s')} |")
    lines += ['', f"Typed status counts (different metric families kept separate): `{summary['metric_status_counts']}`", '',
        'The JSON retains status/reason and all onset/input/support fields per repetition. Ranges describe observations, not prospective acceptance bands.']
    (output/'controls.md').write_text('\n'.join(lines)+'\n', encoding='utf-8')
    plot_representatives(runs, output)
    print(json.dumps({key: summary[key] for key in ('evaluations', 'observations', 'raw_statuses', 'metric_status_counts')}))


def plot_representatives(runs, output):
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
    cases = ['lateral_clean_left_v1', 'lateral_clean_right_v1',
             'lateral_counter_swing_left_v1', 'lateral_counter_swing_right_v1']
    for hz in (120, 60):
        fig, axes = plt.subplots(2, 2, figsize=(11, 7), constrained_layout=True)
        for mode in ('headless', 'rendered_scripted'):
            directory, manifest, result = next(x for x in runs if x[1]['physics_hz'] == hz and x[1]['engine_mode'] == mode)
            outcomes = {x['id']: x for x in result['scenarios']}
            compact = collections.defaultdict(list)
            for row in iter_trace(directory):
                if row['scenario_id'] in cases and row['sample_phase'] == 'post_control' and row['measurement_active']:
                    compact[row['scenario_id']].append((row['physics_time_s'], row['body']['com_m'][0], row['support']['grounded'], row['support']['valid']))
            for axis, scenario in zip(axes.flat, cases):
                rows = compact[scenario]
                onset = outcomes[scenario]['transition']['physics_time_s']
                if not rows:
                    axis.text(.05, .5, mode+': no accepted window', transform=axis.transAxes)
                    continue
                sign = outcomes[scenario]['direction_world'][0]
                times = [r[0]-onset for r in rows]
                axis.plot(times, [(r[1]-rows[0][1])*sign for r in rows], label=mode)
                interrupt = next((r[0]-onset for r in rows if r[2] or not r[3]), None)
                if interrupt is not None:
                    axis.axvline(interrupt, linestyle=':', alpha=.6)
                axis.set_title(scenario.replace('lateral_', '').replace('_v1', ''))
                axis.set_xlabel('Seconds after accepted onset')
                axis.set_ylabel('Signed COM displacement (m)')
                axis.grid(alpha=.2)
                axis.legend(fontsize=8)
        fig.suptitle(f'{hz} Hz / first scripted repetition / dotted: ground or support interruption; later path is raw only')
        fig.savefig(output/f'lateral_{hz}.png', dpi=140)
        plt.close(fig)


if __name__ == '__main__':
    assemble(Path(sys.argv[1]), Path(sys.argv[2]))
