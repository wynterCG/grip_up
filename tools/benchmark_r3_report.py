"""Post-campaign publication only. Never starts a game or repairs measured source."""
from pathlib import Path
import collections
import csv
import io
import json
import shutil
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import benchmark_r3 as r
import virtual_cursor_report as archives

D, B, P = r.DOC, r.BASE, r.PRIMARY


def save(name, value):
    r.atomic_json(D / name, value)


def mcp_json(path):
    # CLI appends transport timing after the complete JSON object.
    return json.JSONDecoder().raw_decode(path.read_text(encoding='utf-8-sig'))[0]


def main():
    source = r.guard(r.read_json(P / 'source_identity.json'))
    certificate = r.read_json(B / 'certified_source.json')
    plan = r.read_json(D / 'run_plan.json')
    ref = r.read_json(P / 'reference_session.json')
    dom = r.read_json(P / 'domains_session.json')
    neg = r.read_json(P / 'negative_controls/results.json')
    runs = ref['runs'] + dom['runs'] + neg['runs']
    assert len(runs) == 61 and not ref['hard_stop'] and not dom['hard_stop']
    assert sum(x['status'] == 'RUN_INVALID' for x in runs) == 1
    failure = neg['runs'][0]
    assert failure['reason'] == 'MISSING_REAL_PICK_RECORDS'
    matrix = []
    for group, cells in [('reference', plan['reference_cells']), ('domain', plan['new_domain_cells'])]:
        actual = [x for x in runs if x['group'] == group]
        for i, cell in enumerate(cells, 1):
            row = dict(cell, group=group, slot=i, attempted=False)
            match = next((x for x in actual if (x['scenario_id'], x['hz'], x['mode'], x['repeat']) ==
                          (cell['scenario'], cell['hz'], cell['mode'], cell['repeat'])), None)
            if match:
                row.update(attempted=True, status=match['status'], reason=match['reason'], run_id=match['run_id'],
                           directory=match['directory'], tape_sha256=match['tape_sha256'],
                           input_lane=match['input_lane'], probe_enabled=match['probe_enabled'])
                if match['metrics']:
                    row.update(observation=match['metrics']['observation'], task_succeeded=match['metrics']['task_succeeded'])
            else:
                capture = next(x for x in dom['runs'] if x['scenario_id'] == cell['scenario'] and x['hz'] == cell['hz'] and x['repeat'] == 0)
                assert capture['metrics']['observation'].get('onset_tick') is None
                row.update(status='NOT_RUN_PRECONDITION_NOT_MET', reason=capture['metrics']['observation']['reason_code'],
                           prerequisite_capture=capture['run_id'])
            matrix.append(row)
    for i in range(1, 9):
        row = {'group': 'negative', 'slot': i, 'attempted': i == 1,
               'status': failure['status'] if i == 1 else 'NOT_RUN_EARLY_STOP',
               'reason': failure['reason'], 'purpose': 'Reserved physical control slot; pure priorities separately indexed'}
        if i == 1: row.update(run_id=failure['run_id'], directory=failure['directory'], case='N1_INVALID_AIM_CANCEL')
        matrix.append(row)
    for i in range(1, 5):
        matrix.append({'group': 'diagnostic', 'slot': i, 'attempted': False,
                       'status': 'NOT_RUN_NOT_NEEDED', 'reason': 'Issue explained offline; no physical diagnostic spent'})
    assert len(matrix) == 96 and sum(x['attempted'] for x in matrix) == 61
    save('r3_primary_test_matrix.json', {'preflight_status': 'CERTIFIED', 'primary_qualification_status': 'NO_GO_BENCHMARK',
         'source_hash': certificate['source_hash'], 'measured_commit': certificate['measurement_commit'],
         'counts': dict(collections.Counter(x['status'] for x in matrix)), 'cells': matrix,
         'allocation_note': plan['capture_policy_note'], 'physical_control_registration': r.read_json(P / 'negative_controls/plan.json')})

    ledger = r.read_json(B / 'budget_ledgers.json')
    ledger['preflight']['final_status'] = 'CERTIFIED'
    ledger['preflight']['pure'] = {'transport_processes': 3, 'environment_processes': 7,
        'successful_transport_assertions': 135, 'successful_transport_cases': 41,
        'failed_transport_batches': 2, 'additional_repair_diagnostics_per_candidate': [0, 0, 0],
        'development_check_only_processes': 4, 'python_contracts_unique_final': 49,
        'note': 'Pure processes and development compiler checks give no physical or primary credit.'}
    ledger['primary'] = {'limit': 96, 'attempted': 61, 'status': 'CLOSED_NO_GO_BENCHMARK',
        'groups': dict(collections.Counter(x['group'] for x in runs)), 'valid_runtime_receipts': 60,
        'invalid_runtime_receipts': 1, 'unattempted_slots': 35, 'pure_environment_processes': 13,
        'adaptive_domain_captures_included': 12, 'fixed_domain_pair_replays': 34,
        'fixed_projection_probe_OFF_domain_controls': 2,
        'invalid_attempt_not_reclaimed': failure['run_id'], 'ordinary_safety_excluded': True}
    ledger['primary']['groups']['diagnostic'] = 0
    regressions = []
    for label in ['benchmark_reference', 'benchmark_live_reference']:
        value = r.read_json(D / label / 'attempt_001/results.json')
        assert value['all_passed'] and all(x['passed'] for x in value['runs'])
        regressions.extend(dict(x, group=label, receipt=f'{label}/attempt_001/results.json') for x in value['runs'])
    assert len(regressions) == 34 and sum(x['checks'] for x in regressions) == 1146
    ledger['regression'] = {'required': 34, 'completed': 34, 'checks': 1146, 'passed': True, 'separate': True}
    r.atomic_json(B / 'budget_ledgers.json', ledger)
    save('budget_ledgers.json', ledger)
    save('regression_index.json', {'runs': regressions, 'processes': 34, 'checks': 1146, 'all_passed': True,
                                 'qualification_credit': 0})

    fields = ['run_id', 'scenario', 'hz', 'mode', 'repeat', 'input_lane', 'runtime_status', 'task_succeeded',
              'metric', 'status', 'value_json', 'unit', 'reason_code', 'onset_tick', 'end_tick',
              'event_provenance', 'tape_sha256', 'source_commit']
    output = io.StringIO(newline='')
    writer = csv.DictWriter(output, fieldnames=fields)
    writer.writeheader()
    for row in dom['runs']:
        for name, metric in row['metrics']['metrics'].items():
            writer.writerow({'run_id': row['run_id'], 'scenario': row['scenario_id'], 'hz': row['hz'],
                'mode': row['mode'], 'repeat': row['repeat'], 'input_lane': row['input_lane'],
                'runtime_status': row['status'], 'task_succeeded': row['metrics']['task_succeeded'],
                'metric': name, 'status': metric['status'], 'value_json': json.dumps(metric['value'], allow_nan=False),
                'unit': metric['unit'], 'reason_code': metric['reason_code'],
                'onset_tick': json.dumps(metric['onset_tick']), 'end_tick': json.dumps(metric['end_tick']),
                'event_provenance': metric['event_provenance'], 'tape_sha256': row['tape_sha256'],
                'source_commit': row['source_commit']})
    (D / 'r3_metrics.csv').write_text(output.getvalue(), encoding='utf-8', newline='')
    comparisons = []
    for path in sorted((P / 'comparisons').glob('*.json')):
        value = r.read_json(path)
        comparisons.append({'file': path.relative_to(r.ROOT).as_posix(), 'sha256': r.file_hash(path),
             'status': value['status'], 'first_difference': value.get('first_difference'),
             'legacy_explanation': value.get('legacy_explanation'), 'scope': 'projection_probe_OFF' if 'observer_control' in path.name else 'H_R_same_Hz'})
    assert len(comparisons) == 25 and all(x['status'] == 'STRICT_MATCH' for x in comparisons)
    within = r.read_json(D / 'specialist/primary_within_mode_measurement.json')
    save('replay_comparison.json', {'source_hash': certificate['source_hash'], 'primary_H_R_reference_pairs': ref['pairs'],
         'primary_H_R_domain_pairs': dom['pairs'], 'comparisons': comparisons,
         'within_mode_reference': r.read_json(P / 'reference_within_mode.json'),
         'within_mode_domain': within, 'cross_frequency_tick_identity': 'NOT_REQUIRED_NOT_CLAIMED',
         'legacy_raw_scalar_vs_native_Vector2': 'Retained inside every raw comparison; representation semantics only, no physical tolerance'})
    save('first_divergence.json', {'primary_hard_stop': True, 'run_id': failure['run_id'],
         'source_commit': failure['source_commit'], 'source_hash': certificate['source_hash'],
         'tape_sha256': failure['tape_sha256'], 'reason': failure['reason'],
         'phase': 'POST_RUN_OBSERVER_ACCOUNTING', 'earliest_semantic_discrepancy_tick': 1,
         'logical_pick_entries': 4, 'actual_ray_query_records': 3,
         'first_entry': {'hand': 0, 'reason': 'INVALID_AIM_NO_NEW_TARGET'},
         'actual_query_ticks': [3, 55, 282], 'published_H_R_first_divergence': None,
         'first_actual_physics_divergence': None, 'actual_physics_divergence_status': 'NOT_DEMONSTRATED',
         'interpretation': 'Frozen validator counted an invalid-aim no-query sentinel as a real raycast. Receipt remains RUN_INVALID; no source repair or new campaign.',
         'trace_window': 'Full 536 POST rows, point-of-call records and engine result retained in evidence archives',
         'prior_domain_task_interruptions_are_not_H_R_divergences': True})
    save('negative_controls.json', {'plan': plan['negative_control_plan'],
         'physical_registration': r.read_json(P / 'negative_controls/plan.json'),
         'attempted': [{'run_id': failure['run_id'], 'status': failure['status'], 'reason': failure['reason'],
                       'internal_checks': failure['engine_result']['negative_checks'],
                       'cleanup': failure['engine_result']['virtual_input']['cleanup']}],
         'remaining_registered_physical_controls': 'NOT_RUN_EARLY_STOP', 'unused_negative_slots': 7,
         'pure_prerequisite_coverage': {'scope': 'PC0/PC1 certification; not fresh primary physical cells',
             'wrong_backing': 'REJECTED_BEFORE_WORLD; also fresh BQ1 negative',
             'source_and_tape_mutation': 'REJECTED_PC0', 'duplicate_missing_out_of_order': 'REJECTED_PC0'},
         'invalid_new_native_support_physical_control': 'NOT_RUN',
         'unsafe_authority_transfer_new_physical_control': 'NOT_RUN',
         'projection_probe_OFF_domain_controls': ['two_hand_release_stop_120', 'two_hand_release_stop_60'],
         'full_observer_ON_OFF_equivalence': 'NOT_QUALIFIED; n1 probe toggle retains audit and trace',
         'human_external_interference_or_AltTab': 'NOT_RUN_IN_R3'})

    cells = []
    for row in dom['runs']:
        if row['repeat'] != 0: continue
        met = row['metrics']
        cells.append({'scenario': row['scenario_id'], 'hz': row['hz'], 'capture': row['run_id'],
            'observation': met['observation'], 'metrics': met['metrics'], 'task_succeeded': met['task_succeeded'],
            'cell_status': 'SCOPED_MEASURED_N3' if row['scenario_id'].startswith('lateral_') and row['hz'] == 120 else 'DIAGNOSTIC_ONLY',
            'domain_both_Hz_ranking': 'EXCLUDED', 'score': None})
    save('domain_eligibility.json', {'primary_qualification_status': 'NO_GO_BENCHMARK', 'eligible_scoring_domains': [],
        'cells': cells, 'required_vertical_asymmetric_both_laterals_at_both_Hz': False,
        'foot_stop_n1_exclusion_prospective': True, 'late_negative_hard_stop_also_blocks_promotion': True})
    save('dataset_partitions.json', {'status': 'FROZEN_NONSCORING_R3_EVIDENCE',
         'reference': [x['run_id'] for x in ref['runs']],
         'domain_adaptive_sources_not_replicates': [x['run_id'] for x in dom['runs'] if x['repeat'] == 0],
         'domain_fixed_observations': [x['run_id'] for x in dom['runs'] if x['repeat'] != 0],
         'negative_never_training': [failure['run_id']], 'eligible_training': [],
         'private_holdout_definitions_or_outcomes_accessed': False, 'optimizer_trials': 0,
         'human_protocol': 'No human feel or new external mouse/focus test performed; future human tests independent of replay eligibility.'})

    baseline = r.read_json(B / 'baseline_manifest.json')
    changed_raw = [key for key, expected in baseline['historical_raw_evidence'].items()
                   if not (r.ROOT / key).is_file() or r.file_hash(r.ROOT / key) != expected]
    changed_docs = [key for key, expected in baseline['historical_tracked_evidence'].items()
                    if not (r.DEST / key).is_file() or r.file_hash(r.DEST / key) != expected]
    changed_external = [key for key, expected in baseline['protected_external'].items()
                        if not Path(key).is_file() or r.file_hash(Path(key)) != expected]
    assert not changed_raw and not changed_docs and not changed_external
    production = {key: value for key, value in baseline['baseline_source_hashes'].items()
                  if key == 'project.godot' or key.startswith(('features/grip_up/', 'features/grip_core/'))}
    assert all(r.file_hash(r.ROOT / key) == value == r.file_hash(r.DEST / key) for key, value in production.items())
    normal = r.read_json(B / 'safety/normal_runtime.json')
    assert normal['normal'] == r.read_json(r.ROOT / 'docs/validation/evaluator_v132/baseline/normal_runtime.json')
    native = mcp_json(B / 'native_retry/normal_runtime_response.json')
    native_value = json.loads(native['output'][0])
    assert all(native_value[key] == value for key, value in normal['normal'].items())
    assert native_value['virtual_provider_disabled'] and not native_value['virtual_arming'] and not native_value['camera_virtual'] and native_value['source_kind'] == 'LIVE'
    restoration = r.read_json(B / 'native_retry/restoration.json')
    assert restoration['project_C_restored'] and restoration['project_E_restored'] and restoration['owned_editor_closed']
    pack = r.read_json(B / 'safety/export_pack_check.json')
    assert all(pack['excluded'].values()) and pack['profile'] == 2 and pack['provider_disabled'] and not pack['camera_virtual']
    assert mcp_json(B / 'native_retry/errors_after_response.json')['count'] == 0
    r.guard(source)
    save('verification.json', {'preflight_status': 'CERTIFIED', 'primary_qualification_status': 'NO_GO_BENCHMARK',
         'measured_commit': certificate['measurement_commit'], 'source_hash': certificate['source_hash'],
         'source_hash_scope': '295 public source hashes plus 5 execution helpers; manifest snapshot hashes only public map',
         'engine': source['engine_identity'], 'source_C_E_parity': True, 'frozen_source_unchanged_after_primary': True,
         'protected_external': baseline['protected_external'], 'production_files_checked': len(production),
         'historical_tracked_files_verified': len(baseline['historical_tracked_evidence']),
         'historical_raw_files_verified': len(baseline['historical_raw_evidence']),
         'historical_changes': [], 'normal_startup_exact_baseline': True, 'native_MCP_Pro': {'version': '1.17.1',
             'final_runtime': native_value, 'fresh_final_errors': 0, 'initial_warning_count': 1,
             'first_inspection': 'Failed supplementary query used nonexistent app.projection_probe; retained, no gameplay source change.',
             'retry': 'Corrected query only; ordinary LIVE inspection, no qualification credit',
             'screenshot_visually_inspected': True, 'restoration': restoration},
         'release_export': r.read_json(B / 'safety/export_identity.json'),
         'release_smoke': r.read_json(B / 'safety/export_smoke_receipt.json'),
         'pack_inspection': pack, 'pack_inspection_uses_debug_tools_engine': True,
         'regression_processes': 34, 'regression_checks': 1146,
         'human_feel_approved_in_R3': False, 'human_external_interference_tested_in_R3': False,
         'optimizer_trials': 0, 'private_holdout_accessed': False, 'M7_started': False,
         'remaining_physical_controls_halted': True})
    print('PUBLICATION_JSON_COMPLETE', flush=True)


def archive_all():
    """Bounded zip groups, all failed attempts included; release exe retained locally."""
    archives.DOC = D
    index = {}
    candidates = B / 'candidate_preflight'
    archives.archive('preflight', list(candidates.rglob('*')), index)
    archives.archive('primary', list(P.rglob('*')), index)
    safety = [p for name in ['safety', 'native', 'native_retry'] for p in (B / name).rglob('*') if p.suffix != '.exe']
    archives.archive('safety', safety, index)
    regression = [p for name in ['benchmark_reference', 'benchmark_live_reference'] for p in (D / name).rglob('*')]
    archives.archive('regression', regression, index)
    source = r.read_json(P / 'source_identity.json')
    archives.source_archive('measured_source', source['repository_commit'],
                            {**source['source_hashes'], **source['helper_hashes']}, index)
    save('archive_manifest.json', {'archives': index, 'all_members_CRC_and_SHA_roundtrip_verified': True,
         'failed_candidates_retained': [1, 2], 'failed_primary_attempt_retained': True,
         'candidate_sources': 'Exact registered hashes validated for all 300 source/helper members per candidate. For uncommitted candidates 001/002, two known earlier file versions reconstructed, accepted only by exact registered SHA; archive receipts disclose this. No old result recreated.',
         'release_executable_not_in_zip': {'path': str(B / 'safety/GripUp-v133-benchmark-safe.exe'),
                                         **r.read_json(B / 'safety/export_identity.json')},
         'historical_evidence_immutable': '../benchmark_v133/ and prior validation roots; baseline_manifest.json enumerates exact hashes'})
    print('ARCHIVES_COMPLETE', len(index), sum(x['bytes'] for x in index.values()), flush=True)


if __name__ == '__main__':
    if '--archive' in sys.argv: archive_all()
    else: main()
