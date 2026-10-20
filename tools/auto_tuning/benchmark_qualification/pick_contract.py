"""FR0 derived view of actual logical targeting and picker observations.

No query is made here. The input streams are never mutated. Historical rows
are classified only when their existing audit and chronological sidecar agree.
"""
from __future__ import annotations

import copy
import math
import struct

SCHEMA = 'grip_pick_dispatch_contract_v134'
OFFSETS = [[0, 0], [12, 0], [-12, 0], [0, 12], [0, -12], [8, 8], [-8, -8]]
RAY_FIELDS = {'offset_px': 'offset', 'point_px': 'screen_point',
              'origin_m': 'origin', 'direction': 'world_normal_used', 'reason': 'reason'}
HIT_FIELDS = {'collider_key': 'collider_key', 'collider_runtime_id': 'runtime_id',
              'local_point_m': 'material_point', 'local_normal': 'material_normal',
              'world_point_m': 'world_point', 'world_normal': 'world_normal', 'shape': 'shape'}


def integer(value, reason, low=0, high=None):
    if type(value) not in (int, float) or not math.isfinite(value) or value != int(value) or value < low or (high is not None and value > high):
        raise ValueError(reason)
    return int(value)


def dispatch_identity(session_id, tick, hand, ordinal):
    return f'{session_id}:t{tick}:h{hand}:d{ordinal}'


def _require_equal(a, b, reason):
    # JSON numeric 0/0.0 is accepted; cursor components are never rounded.
    if a != b:
        raise ValueError(reason)


def _finite(value):
    if isinstance(value, float) and not math.isfinite(value):
        return False
    if isinstance(value, list):
        return all(_finite(v) for v in value)
    if isinstance(value, dict):
        return all(_finite(v) for v in value.values())
    return True


def _vector(value, length):
    return isinstance(value, list) and len(value) == length and all(type(v) in (int, float) and math.isfinite(v) for v in value)


def _f32(value):
    return struct.unpack('<f', struct.pack('<f', value))[0]


def _audit(pick, physical):
    audit = pick['audit']
    rays, observed = audit.get('rays'), physical.get('rays')
    if not isinstance(rays, list) or not rays or len(rays) > 7 or not isinstance(observed, list) or len(rays) != len(observed):
        raise ValueError('PICK_RAY_COUNT_MISMATCH')
    if not isinstance(physical.get('cursor'), dict) or any(not _vector(v, 2) for v in [pick.get('pointer'), audit.get('pointer'), physical['cursor'].get('actual_vector')]):
        raise ValueError('INVALID_PICK_CURSOR')
    _require_equal(pick.get('pointer'), audit.get('pointer'), 'PICK_CURSOR_MISMATCH')
    _require_equal(audit.get('pointer'), physical.get('cursor', {}).get('actual_vector'), 'PICK_CURSOR_MISMATCH')
    _require_equal(audit.get('mask'), 3, 'PICK_MASK_MISMATCH')
    _require_equal(audit.get('range_m'), 70, 'PICK_RANGE_MISMATCH')
    winner = None
    for index, (logical, real) in enumerate(zip(rays, observed)):
        if not isinstance(logical, dict) or not isinstance(real, dict):
            raise ValueError('INVALID_PICK_RAY')
        if any(not _vector(logical.get(k), n) for k, n in [('offset_px', 2), ('point_px', 2), ('origin_m', 3), ('direction', 3)]) or any(not _vector(real.get(k), n) for k, n in [('offset', 2), ('screen_point', 2), ('origin', 3), ('world_normal_used', 3), ('query_from', 3), ('query_to', 3)]):
            raise ValueError('INVALID_PICK_RAY_VECTOR')
        _require_equal(integer(real.get('query_index'), 'PICK_RAY_ORDER'), index, 'PICK_RAY_ORDER')
        _require_equal(logical.get('offset_px'), OFFSETS[index], 'PICK_RAY_ORDER')
        for src, dst in RAY_FIELDS.items():
            if src not in logical or dst not in real:
                raise ValueError('PICK_RAY_FIELD_MISSING')
            _require_equal(logical[src], real[dst], 'PICK_RAY_MISMATCH:' + src)
        _require_equal(real.get('query_from'), logical['origin_m'], 'PICK_RAY_MISMATCH:query_from')
        # Actual query construction uses native Vector3 operations (float32 in
        # this engine). This checks that endpoint, not a tolerance or aim cast.
        try:
            endpoint = [_f32(_f32(o) + _f32(_f32(d) * 70.0)) for o, d in zip(logical['origin_m'], logical['direction'])]
        except (OverflowError, struct.error):
            raise ValueError('INVALID_PICK_RAY_VECTOR') from None
        bits = physical.get('numeric_bits')
        if not isinstance(bits, dict):
            raise ValueError('PICK_ENDPOINT_BITS_MISSING')
        for component in range(3):
            encoded = bits.get(f'/rays/{index}/query_to/{component}')
            if not isinstance(encoded, str) or len(encoded) != 16:
                raise ValueError('PICK_ENDPOINT_BITS_MISSING')
            try:
                measured = bytes.fromhex(encoded)
            except ValueError:
                raise ValueError('PICK_ENDPOINT_BITS_INVALID') from None
            if struct.pack('<d', real['query_to'][component]) != measured:
                raise ValueError('PICK_ENDPOINT_RAW_BITS_MISMATCH')
            if struct.pack('<d', endpoint[component]) != measured:
                raise ValueError('PICK_RAY_MISMATCH:query_to')
        _require_equal(real.get('mask'), audit['mask'], 'PICK_MASK_MISMATCH')
        _require_equal(real.get('distance_m'), audit['range_m'], 'PICK_RANGE_MISMATCH')
        reason = logical['reason']
        if not isinstance(reason, str) or reason not in ('MISS', 'INELIGIBLE', 'SELECTED'):
            raise ValueError('UNKNOWN_PICK_RESULT')
        if reason == 'MISS':
            if 'hit' in real or any(k in logical for k in HIT_FIELDS):
                raise ValueError('FABRICATED_PICK_HIT')
        else:
            hit = real.get('hit')
            if not isinstance(hit, dict):
                raise ValueError('PICK_MATERIAL_MISMATCH')
            if any(not _vector(logical.get(k), 3) for k in ['local_point_m', 'local_normal', 'world_point_m', 'world_normal']) or any(not _vector(hit.get(k), 3) for k in ['material_point', 'material_normal', 'world_point', 'world_normal']):
                raise ValueError('INVALID_PICK_MATERIAL_VECTOR')
            if not isinstance(logical.get('collider_key'), str) or not logical['collider_key']:
                raise ValueError('INVALID_PICK_MATERIAL_ID')
            integer(logical.get('collider_runtime_id'), 'INVALID_PICK_MATERIAL_ID', low=1)
            integer(logical.get('shape'), 'INVALID_PICK_MATERIAL_SHAPE')
            for src, dst in HIT_FIELDS.items():
                if src not in logical or dst not in hit:
                    raise ValueError('PICK_MATERIAL_FIELD_MISSING')
                _require_equal(logical[src], hit[dst], 'PICK_MATERIAL_MISMATCH:' + src)
            _require_equal(hit.get('surface_material_id'), logical['collider_key'], 'PICK_MATERIAL_MISMATCH:surface_material_id')
        if reason == 'SELECTED':
            if index != len(rays) - 1:
                raise ValueError('PICK_QUERY_AFTER_WINNER')
            winner = logical
    if winner is None and len(rays) != 7:
        raise ValueError('PICK_INCOMPLETE_MISS_RAYS')
    _require_equal(audit.get('winner'), winner, 'PICK_WINNER_MISMATCH')
    if type(physical.get('selected')) is not bool:
        raise ValueError('PICK_WINNER_MISMATCH')
    _require_equal(physical['selected'], winner is not None, 'PICK_WINNER_MISMATCH')
    return {'ray_count': len(rays), 'winning_offset': copy.deepcopy(winner['offset_px']) if winner else None,
            'outcome': 'SELECTED' if winner else 'MISS_OR_INELIGIBLE'}


def validate_stream(ticks, sidecars, session_id, completed=True, expected_tick_count=None, strict_new=False):
    """Return a versioned, one-to-one view, or a typed ValueError.

    Caller must establish completed from the actual engine outcome/trace. An
    aborted stream cannot be promoted by omitting its absent tail.
    """
    if not completed:
        raise ValueError('INCOMPLETE_PICK_STREAM')
    if not isinstance(session_id, str) or not session_id or not isinstance(ticks, list) or not isinstance(sidecars, list):
        raise ValueError('INVALID_PICK_STREAM_SCHEMA')
    if not _finite(ticks) or not _finite(sidecars):
        raise ValueError('PICK_NONFINITE')
    if expected_tick_count is not None and len(ticks) != expected_tick_count:
        raise ValueError('INCOMPLETE_PICK_STREAM')
    view = {'schema': SCHEMA, 'session_id': session_id, 'status': 'PASS', 'reason': '',
            'events': [], 'dispatches': [], 'sidecars': [], 'logical_count': 0,
            'dispatch_count': 0, 'ray_count': 0, 'suppressed_count': 0}
    physical_index = 0
    for expected_tick, row in enumerate(ticks, 1):
        if not isinstance(row, dict) or not isinstance(row.get('target', {}), dict):
            raise ValueError('INVALID_PICK_STREAM_SCHEMA')
        tick = integer(row.get('tick'), 'INVALID_PICK_TICK', low=1)
        if tick != expected_tick:
            raise ValueError('INCOMPLETE_PICK_STREAM')
        picks = row.get('target', {}).get('picks', [])
        if not isinstance(picks, list):
            raise ValueError('INVALID_PICK_STREAM_SCHEMA')
        ordinal = 0
        for event_index, pick in enumerate(picks):
            if not isinstance(pick, dict):
                raise ValueError('UNKNOWN_LEGACY_EVENT')
            hand = integer(pick.get('hand'), 'INVALID_PICK_HAND', high=1)
            event_id = f'{session_id}:t{tick}:h{hand}:e{event_index}'
            event = {'event_id': event_id, 'tick': tick, 'hand': hand, 'logical_index': event_index}
            if pick.get('reason') == 'INVALID_AIM_NO_NEW_TARGET' and 'audit' not in pick:
                event.update(kind='PICK_SUPPRESSED', dispatched_world_queries=False, dispatch_id=None,
                             reason='INVALID_AIM_NO_NEW_TARGET')
                view['suppressed_count'] += 1
            elif isinstance(pick.get('audit'), dict) and 'reason' not in pick:
                identity = dispatch_identity(session_id, tick, hand, ordinal)
                if physical_index >= len(sidecars):
                    raise ValueError('MISSING_REAL_PICK_RECORDS')
                real = sidecars[physical_index]
                if not isinstance(real, dict):
                    raise ValueError('INVALID_PICK_SIDECAR')
                real_tick = integer(real.get('tick'), 'INVALID_PICK_TICK', low=1)
                real_hand = integer(real.get('hand'), 'INVALID_PICK_HAND', high=1)
                if real.get('trial_id') != session_id or real_tick != tick or real_hand != hand:
                    raise ValueError('PICK_DISPATCH_IDENTITY_MISMATCH')
                if integer(real.get('pick_call_index'), 'INVALID_PICK_CALL_INDEX') != physical_index:
                    raise ValueError('DUPLICATE_OR_MISORDERED_PICK_SIDECAR')
                if strict_new and ('dispatch_identity' not in real or 'dispatch_ordinal' not in real):
                    raise ValueError('MISSING_DISPATCH_IDENTITY')
                if 'dispatch_identity' in real and real['dispatch_identity'] != identity:
                    raise ValueError('PICK_DISPATCH_IDENTITY_MISMATCH')
                if 'dispatch_ordinal' in real and integer(real['dispatch_ordinal'], 'INVALID_PICK_ORDINAL') != ordinal:
                    raise ValueError('PICK_DISPATCH_IDENTITY_MISMATCH')
                details = _audit(pick, real)
                dispatch = {'kind': 'PICK_DISPATCH', 'dispatch_id': identity, 'tick': tick, 'hand': hand, 'ordinal': ordinal,
                            'sidecar_index': physical_index, 'original_pick_call_index': real['pick_call_index'],
                            'dispatched_world_queries': True, **details}
                view['dispatches'].append(dispatch)
                view['sidecars'].append({'dispatch_id': identity, 'sidecar_index': physical_index,
                                         'original_pick_call_index': real['pick_call_index']})
                event.update(kind='PICK_RESULT', dispatched_world_queries=True, dispatch_id=identity,
                             outcome=details['outcome'])
                view['ray_count'] += details['ray_count']
                physical_index += 1
                ordinal += 1
            else:
                raise ValueError('UNKNOWN_LEGACY_EVENT')
            view['events'].append(event)
            view['logical_count'] += 1
    if physical_index != len(sidecars):
        raise ValueError('ORPHAN_OR_DUPLICATE_PICK_SIDECAR')
    view['dispatch_count'] = physical_index
    return view
