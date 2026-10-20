"""Read-only clause timeline for old R3 and new feasibility observations."""
import math


def norm(v):
    return math.sqrt(sum(x*x for x in v))


def diagnose(ticks, definition, onset_certificate=None, observation=None, context=None):
    """Expose every prerequisite; these diagnostics do not redefine an onset."""
    axis = definition['direction_world']
    timeline = []
    counts = {}
    first = None
    first_all = None
    earliest_loss = None
    longest = 0.0
    onset_certificate = onset_certificate or {}
    observation = observation or {}
    context = context or {}
    onset = onset_certificate.get('onset_tick')
    interruption = observation.get('interruption') or {}
    interrupt_tick = interruption.get('tick')
    for index, row in enumerate(ticks):
        ex = row['benchmark_extra']
        support_velocity = row['support'].get('point_velocity_m_s')
        velocity = list(row['body']['linear_velocity_m_s'])
        if support_velocity is not None:
            velocity = [a-b for a, b in zip(velocity, support_velocity)]
        directed = sum(a*b for a, b in zip(axis, velocity))
        spin = norm(row['body']['angular_velocity_rad_s'])
        hands = row['hands']
        clauses = {
            'support_valid': row['support']['valid'],
            'not_grounded': not row['support']['grounded'],
            'no_native_ground_authority': not ex['native_ground_authority'],
            'no_hybrid_authority': not row['support']['hybrid_owned'],
            'clearance_certified': ex['ground_clearance_status'] == 'CLEAR_QUERIED_SEGMENT',
            'both_hands_attached': all(h['state'] == 'ATTACHED' for h in hands),
            'both_hand_material_supports': all(h['support']['key'] != 'NONE' and h['anchor_runtime_id'] != 0 for h in hands),
            'hands_loaded_gt_1N': sum(norm(h['force_n']) for h in hands) > 1.0,
            'axis_speed_le_0_1': abs(directed) <= .1,
            'full_spin_le_0_2': spin <= .2,
            'required_foot_load_gt_1N': not definition['require_foot_load'] or ex['foot_compressive_load_n'] > 1.0,
            'relative_support_velocity_available': support_velocity is not None,
            'ground_force_le_0_0001': norm(row['force_budget']['ground_force_n']) <= .0001,
            'ground_torque_le_0_0001': norm(row['force_budget']['ground_torque_nm']) <= .0001,
        }
        if support_velocity is None: clauses['axis_speed_le_0_1'] = False
        valid = all(clauses.values())
        if valid:
            if first is None: first = row['tick']
            if first_all is None: first_all = row['tick']
        else:
            if first_all is not None and earliest_loss is None: earliest_loss = row['tick']
            first = None
        duration = (row['tick']-first)/row['physics_hz'] if first is not None else 0.0
        longest = max(longest, duration)
        for name, value in clauses.items(): counts[name] = counts.get(name, 0) + int(value)
        clearance = row.get('benchmark_clearance', {})
        prior_start = index-1-math.ceil(.25*row['physics_hz'])
        prior = timeline[max(0, prior_start):index]
        anchors = [h['anchor_runtime_id'] for h in hands]
        same_anchor_quiet = prior_start >= 0 and all(p['all_prerequisites_true'] and
            [h['anchor_runtime_id'] for h in p['hands']] == anchors for p in prior)
        stop = definition['kind'] == 'release_stop'
        accepted = row['command_accepted']
        onset_clauses = {k:v for k,v in clauses.items() if k not in ['axis_speed_le_0_1','full_spin_le_0_2']}
        onset_clauses['accepted_command'] = accepted['accepted_input'] == [0, 0] if stop else sum(a*b for a,b in zip(accepted['intent_world'], axis)) > .000001
        onset_clauses['accepted_speed'] = support_velocity is not None and (.15 <= directed <= .5 if stop else abs(directed) <= .1 and spin <= .2)
        onset_clauses['prior_same_anchor_quiet_dwell'] = True if stop else same_anchor_quiet
        phase = 'PREPARATION' if onset is None or row['tick'] < onset else 'MEASUREMENT'
        if interrupt_tick is not None and row['tick'] >= interrupt_tick: phase = 'INTERRUPTED_UNCREDITED'
        elif onset is not None and row['tick'] > onset+round(definition['observe_s']*row['physics_hz']): phase = 'POST_WINDOW'
        timeline.append({'tick': row['tick'], 'physics_hz': row['physics_hz'], 'phase': row['sample_phase'],
            'run_id': row['run_id'], 'scenario_id': row['scenario_id'],
            'fixture_revision': definition.get('fixture_revision', definition['revision']),
            'source_hash': context.get('source_hash'), 'tape_hash': context.get('tape_hash'),
            'backing_size': context.get('actual_backing_size'),
            'logical_viewport_size': row['canonical_input']['effective']['viewport_size_px'],
            'active_profile': row['profile'],
            'task_phase': phase, 'authoritative_onset_tick': onset, 'authoritative_onset_reason': onset_certificate.get('reason_code'),
            'measurement_window_status': observation.get('status'), 'interrupt_tick': interrupt_tick,
            'interrupt_reason': interruption.get('reason_code'),
            'accepted_onset_clauses': onset_clauses,
            'all_failed_accepted_onset_clauses': [k for k,v in onset_clauses.items() if not v],
            'prior_same_anchor_quiet_dwell': same_anchor_quiet,
            'clauses': clauses, 'all_failed_clauses': [k for k, v in clauses.items() if not v],
            'first_failed_clause': next((k for k, v in clauses.items() if not v), None),
            'all_prerequisites_true': valid, 'quiet_window_elapsed_s': duration,
            'quiet_duration_ge_0_25': duration >= .25, 'linear_speed_m_s': norm(velocity),
            'directed_speed_m_s': directed if support_velocity is not None else None, 'full_spin_rad_s': spin,
            'relative_velocity_support_observed': support_velocity is not None,
            'body_COM': row['body']['com_m'], 'body_pose': row['body']['pose'],
            'requested_move': ex.get('requested_input'), 'accepted_move': row['command_accepted'],
            'hands': hands, 'feet': row['feet'], 'foot_compressive_load_n': ex['foot_compressive_load_n'],
            'ground_state': ex['ground_state'], 'motor_authority': ex['motor_authority'],
            'native_contact_truth': 'UNKNOWN' if ex['native_contact_reporting_limit'] == 0 else 'OBSERVED_BUFFER_ONLY',
            'native_contact_reporting_limit': ex['native_contact_reporting_limit'], 'clearance': clearance})
    hz = ticks[0]['physics_hz'] if ticks else None
    return timeline, {'schema': 'fixture_prerequisite_funnel_v134', 'diagnostic_only': True,
        'thresholds_unchanged': {'axis_speed_m_s': .1, 'full_spin_rad_s': .2, 'quiet_duration_s': .25, 'hand_load_N': 1, 'required_foot_load_N': 1},
        'total_ticks': len(ticks), 'physics_hz': hz,
        'clauses': {k: {'true_ticks': v, 'false_ticks': len(ticks)-v, 'true_time_s': v/hz} for k, v in counts.items()},
        'all_true_ticks': sum(x['all_prerequisites_true'] for x in timeline),
        'first_all_true_tick': first_all, 'earliest_loss_after_first_all_true_tick': earliest_loss,
        'longest_contiguous_quiet_s': longest,
        'native_contact_absence_certified': False,
        'onset_authority': 'Original driver and independent R3 metrics, not this diagnostic funnel',
        'actual_onset_certificate': onset_certificate, 'observation': observation,
        'phase_scope': 'Quiet preparation predicates plus separate accepted-onset/history clauses; authoritative certificate controls credit'}
