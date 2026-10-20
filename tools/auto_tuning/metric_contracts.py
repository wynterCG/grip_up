"""Typed, fixed-physics-sample movement measurements; no scorer or game writes."""
from __future__ import annotations

import math

VERSION = "benchmark_eval_v131_stop_v1"
STATUSES = {"MEASURED", "CENSORED_TIMEOUT", "INTERRUPTED", "PRECONDITION_NOT_MET", "INVALID_MEASUREMENT", "NOT_APPLICABLE"}
DEFAULTS = {
    "settle_linear_m_s": .1, "settle_angular_rad_s": .2, "settle_hold_s": .25,
    "reverse_speed_m_s": .02, "reverse_hold_s": .05, "movement_epsilon_m": 1e-6,
    "intent_epsilon": 1e-6, "time_tolerance_s": 1e-6, "min_initial_speed_m_s": 0.0,
    "allow_ground": False, "require_support": True, "fixed_horizons_s": [],
    "brake_fractions": [.5, .1], "stop_target_corridor_m": 0.0,
}
UNITS = {
    "stop_distance_m": "m", "settling_time_s": "s", "reversal_time_s": "s",
    "release_signed_drift_m": "m", "release_absolute_directional_drift_m": "m",
    "release_path_length_m": "m", "post_stop_overshoot_m": "m",
    "useful_progress_m": "m", "directional_efficiency": "dimensionless",
}


def _number(value):
    return type(value) in (int, float) and math.isfinite(value)


def _vector(value, field):
    if not isinstance(value, (list, tuple)) or len(value) != 3 or not all(_number(x) for x in value):
        raise ValueError("INVALID_VECTOR:" + field)
    return tuple(float(x) for x in value)


def _sub(a, b):
    return tuple(x - y for x, y in zip(a, b))


def _norm(a):
    return math.sqrt(sum(x * x for x in a))


def _dot(a, b):
    return sum(x * y for x, y in zip(a, b))


def _outcome(name, unit, status, reason, value=None, **extra):
    if status not in STATUSES or (status == "MEASURED" and not _number(value)):
        raise ValueError("invalid internal typed metric")
    return {"metric": name, "unit": unit, "status": status, "value": value if status == "MEASURED" else None,
            "reason": reason, "observed_duration_s": None, "observed_path_length_m": None,
            "observed_signed_displacement_m": None, **extra}


def _blank(status, reason, contract=None, kind=None):
    c = contract if isinstance(contract, dict) else {}
    fractions = c.get("brake_fractions", DEFAULTS["brake_fractions"])
    if not isinstance(fractions, list):
        fractions = []
    horizons = c.get("fixed_horizons_s", [])
    if not isinstance(horizons, list):
        horizons = []
    metrics = {name: _outcome(name, unit, status, reason) for name, unit in UNITS.items()}
    if status != "INVALID_MEASUREMENT" and kind in {"release", "brake", "reverse", "none"}:
        for name, unit in UNITS.items():
            applicable = (name in {"useful_progress_m", "directional_efficiency"}
                          or name == "reversal_time_s" and kind == "reverse"
                          or name.startswith("release_") and kind == "release"
                          or name in {"stop_distance_m", "settling_time_s", "post_stop_overshoot_m"} and kind in {"release", "brake"})
            if not applicable:
                metrics[name] = _outcome(name, unit, "NOT_APPLICABLE", "NO_MATCHING_TRANSITION_REQUESTED")
    braking = []
    for fraction in fractions:
        if not _number(fraction):
            continue
        state = "NOT_APPLICABLE" if kind != "brake" and status != "INVALID_MEASUREMENT" else status
        why = "NO_ACTIVE_BRAKE_REQUESTED" if state == "NOT_APPLICABLE" else reason
        braking.append({"fraction": fraction, "threshold_speed_m_s": None,
                        "time_s": _outcome("active_braking_time_s", "s", state, why),
                        "distance_m": _outcome("active_braking_distance_m", "m", state, why)})
    return {"metric_definition_version": VERSION, "metrics": metrics, "active_braking": braking,
            "fixed_horizons": [{"horizon_s": horizon, **_outcome("fixed_horizon_progress_m", "m", status, reason)}
                               for horizon in horizons if _number(horizon)],
            "observation": {"status": status, "reason": reason}}


def precondition_outcomes(reason: str, contract: dict, kind: str) -> dict:
    """A real fixture failed before any transition existed; do not invent a tick."""
    if not isinstance(reason, str) or not reason or not isinstance(contract, dict) or kind not in {"release", "brake", "reverse", "none"}:
        return _blank("INVALID_MEASUREMENT", "INVALID_PRECONDITION_OUTCOME_REQUEST", contract)
    return _blank("PRECONDITION_NOT_MET", reason, {**DEFAULTS, **contract}, kind)


def _parse(samples, contract, transition):
    if not isinstance(contract, dict) or not isinstance(transition, dict) or not isinstance(samples, list):
        raise ValueError("INVALID_API_TYPES")
    c = {**DEFAULTS, **contract}
    for field in ("physics_hz", "deadline_s", "settle_linear_m_s", "settle_angular_rad_s", "settle_hold_s",
                  "reverse_speed_m_s", "reverse_hold_s", "movement_epsilon_m", "intent_epsilon", "time_tolerance_s", "min_initial_speed_m_s", "stop_target_corridor_m"):
        if not _number(c.get(field)) or c[field] < 0:
            raise ValueError("INVALID_CONTRACT:" + field)
    if c["physics_hz"] <= 0 or c["deadline_s"] <= 0 or c["settle_hold_s"] <= 0 or c["reverse_hold_s"] <= 0:
        raise ValueError("NONPOSITIVE_TIME_CONTRACT")
    if not isinstance(c.get("sample_phase"), str) or not c["sample_phase"]:
        raise ValueError("MISSING_SAMPLE_PHASE")
    for field in ("allow_ground", "require_support"):
        if type(c[field]) is not bool:
            raise ValueError("INVALID_CONTRACT:" + field)
    for field in ("fixed_horizons_s", "brake_fractions"):
        if not isinstance(c[field], list) or any(not _number(x) for x in c[field]) or len(c[field]) != len(set(c[field])):
            raise ValueError("INVALID_CONTRACT:" + field)
    if any(x < 0 or x > c["deadline_s"] for x in c["fixed_horizons_s"]):
        raise ValueError("HORIZON_OUTSIDE_DECLARED_DEADLINE")
    if any(not 0 < x < 1 for x in c["brake_fractions"]):
        raise ValueError("INVALID_BRAKE_FRACTION")
    axis = _vector(c.get("direction_world"), "direction_world")
    length = _norm(axis)
    if length <= 0:
        raise ValueError("ZERO_DIRECTION")
    axis = tuple(x / length for x in axis)
    if transition.get("kind") not in {"release", "brake", "reverse", "none"}:
        raise ValueError("UNKNOWN_TRANSITION_KIND")
    if not _number(transition.get("physics_time_s")) or type(transition.get("tick")) is not int:
        raise ValueError("INVALID_ACCEPTED_TRANSITION_TIME")
    if transition.get("stop_target_progress_m") is not None and not _number(transition["stop_target_progress_m"]):
        raise ValueError("INVALID_STOP_TARGET")
    selected = [sample for sample in samples if isinstance(sample, dict) and sample.get("sample_phase") == c["sample_phase"]]
    if not selected:
        raise ValueError("NO_SAMPLES_IN_DECLARED_PHASE")
    rows = []
    dt = 1 / c["physics_hz"]
    tolerance = c["time_tolerance_s"]
    for sample in selected:
        tick, timestamp = sample.get("tick"), sample.get("physics_time_s")
        if type(tick) is not int or not _number(timestamp):
            raise ValueError("INVALID_TICK_OR_TIMESTAMP")
        if not _number(sample.get("delta_s")) or abs(sample["delta_s"] - dt) > tolerance:
            raise ValueError(f"INVALID_FIXED_DELTA:tick={tick}")
        if rows and (tick != rows[-1]["tick"] + 1 or timestamp <= rows[-1]["t"] or abs(timestamp - rows[-1]["t"] - dt) > tolerance):
            raise ValueError(f"NONCONSECUTIVE_OR_NONMONOTONIC_TIME:tick={tick}")
        body = sample.get("body", {})
        position = _vector(body.get("com_m"), "body.com_m")
        velocity = _vector(body.get("linear_velocity_m_s"), "body.linear_velocity_m_s")
        angular = _vector(body.get("angular_velocity_rad_s"), "body.angular_velocity_rad_s")
        intent = _vector(sample.get("command_accepted", {}).get("intent_world"), "command_accepted.intent_world")
        support = sample.get("support", {})
        if not isinstance(support, dict) or any(type(support.get(key)) is not bool for key in ("valid", "grounded", "hybrid_owned")):
            raise ValueError("MISSING_ACTUAL_SUPPORT_FLAGS")
        row = {"tick": tick, "t": float(timestamp), "support": support, "intent": intent, "sample": sample,
               "position": position, "velocity": velocity, "angular": angular}
        eligible = (support["valid"] or not c["require_support"]) and not support["hybrid_owned"] and (c["allow_ground"] or not support["grounded"])
        if eligible:
            if not isinstance(support.get("frame_id"), str) or not support["frame_id"]:
                raise ValueError("MISSING_DECLARED_SUPPORT_FRAME")
            row["relative_position"] = _sub(position, _vector(support.get("point_m"), "support.point_m"))
            row["relative_velocity"] = _sub(velocity, _vector(support.get("point_velocity_m_s"), "support.point_velocity_m_s"))
            row["relative_angular"] = _sub(angular, _vector(support.get("angular_velocity_rad_s"), "support.angular_velocity_rad_s"))
        rows.append(row)
    matching = [index for index, row in enumerate(rows) if row["tick"] == transition["tick"] and abs(row["t"] - transition["physics_time_s"]) <= tolerance]
    if len(matching) != 1:
        raise ValueError("ACCEPTED_TRANSITION_NOT_ON_RECORDED_TICK")
    return c, axis, rows[matching[0]:], len(samples) - len(selected)


def analyze(samples: list[dict], contract: dict, transition: dict) -> dict:
    """Analyze one accepted transition. Values are tick observations, not interpolated events.

    The fixed axis is declared at onset. COM positions/velocities are relative to
    one tracked material reference; missing multi-support frames are never zeroed.
    """
    try:
        c, axis, rows, ignored = _parse(samples, contract, transition)
    except (ValueError, KeyError, TypeError, OverflowError) as exc:
        return _blank("INVALID_MEASUREMENT", str(exc), contract, transition.get("kind") if isinstance(transition, dict) else None)
    first = rows[0]
    kind = transition["kind"]
    support = first["support"]
    if (c["require_support"] and not support["valid"]) or support["hybrid_owned"] or (support["grounded"] and not c["allow_ground"]):
        return _blank("PRECONDITION_NOT_MET", "INITIAL_SUPPORT_GROUND_OR_AUTHORITY_NOT_ELIGIBLE", c, kind)
    initial_speed = _norm(first["relative_velocity"])
    if initial_speed + c["movement_epsilon_m"] < c["min_initial_speed_m_s"]:
        return _blank("PRECONDITION_NOT_MET", "INITIAL_SPEED_BELOW_DECLARED_MINIMUM", c, kind)
    if kind == "release" and _norm(first["intent"]) > c["intent_epsilon"]:
        return _blank("PRECONDITION_NOT_MET", "NEUTRAL_TRANSITION_NOT_ACTUALLY_ACCEPTED", c, kind)
    effort_axis = axis
    if kind in {"brake", "reverse"}:
        intent_length = _norm(first["intent"])
        if intent_length <= c["intent_epsilon"] or _dot(first["relative_velocity"], first["intent"]) >= -c["movement_epsilon_m"]:
            return _blank("PRECONDITION_NOT_MET", "OPPOSITE_COMMAND_OR_INITIAL_DIRECTED_MOTION_NOT_ACHIEVED", c, kind)
        effort_axis = tuple(x / intent_length for x in first["intent"])
    t0 = first["t"]
    deadline = t0 + c["deadline_s"]
    tolerance = c["time_tolerance_s"]
    valid = []
    interruption = None
    brake_end = None
    neutral_after_brake = False
    for row in rows:
        if row["t"] > deadline + tolerance:
            break
        s = row["support"]
        reason = None
        if c["require_support"] and not s["valid"]:
            reason = "SUPPORT_LOST"
        elif s["hybrid_owned"]:
            reason = "HYBRID_AUTHORITY_SWITCH"
        elif s["grounded"] and not c["allow_ground"]:
            reason = "GROUND_CONTACT_CHANGED_TASK"
        elif s.get("frame_id") != support["frame_id"]:
            reason = "SUPPORT_MATERIAL_FRAME_CHANGED"
        elif row["sample"].get("interruption"):
            event = row["sample"]["interruption"]
            reason = event.get("reason", "EXPLICIT_TASK_INTERRUPTION") if isinstance(event, dict) else str(event)
        intent = _dot(row["intent"], effort_axis)
        neutral = _norm(row["intent"]) <= c["intent_epsilon"]
        if reason is None and kind == "release" and not neutral:
            reason = "NEW_COMMAND_AFTER_RELEASE"
        if reason is None and kind == "reverse" and intent <= c["intent_epsilon"]:
            reason = "REVERSE_COMMAND_ENDED"
        if reason is None and kind == "brake":
            if neutral:
                neutral_after_brake = True
                if brake_end is None:
                    brake_end = len(valid)  # Boundary body state includes the preceding braking integration.
            elif intent <= c["intent_epsilon"] or neutral_after_brake:
                reason = "UNEXPECTED_COMMAND_AFTER_BRAKE"
        if reason:
            interruption = {"reason": reason, "physics_time_s": row["t"], "tick": row["tick"]}
            break
        valid.append(row)
    if not valid:
        return _blank("INTERRUPTED", interruption["reason"] if interruption else "EMPTY_VALID_WINDOW", c, kind)
    paths, signed, directional_paths = [0.0], [0.0], [0.0]
    origin = first["relative_position"]
    for index in range(1, len(valid)):
        delta = _sub(valid[index]["relative_position"], valid[index - 1]["relative_position"])
        paths.append(paths[-1] + _norm(delta))
        directional_paths.append(directional_paths[-1] + abs(_dot(delta, axis)))
        signed.append(_dot(_sub(valid[index]["relative_position"], origin), axis))
    last = len(valid) - 1
    full_window = valid[last]["t"] >= deadline - tolerance
    terminal_status = "INTERRUPTED" if interruption else ("CENSORED_TIMEOUT" if full_window else "INVALID_MEASUREMENT")
    terminal_reason = interruption["reason"] if interruption else ("CRITERION_NOT_CONFIRMED_BEFORE_DEADLINE" if full_window else "TRACE_ENDED_BEFORE_DECLARED_DEADLINE")

    def outcome(name, unit, status, reason, value=None, index=None, **extra):
        index = last if index is None else index
        fields = {"observed_duration_s": valid[index]["t"] - t0, "observed_path_length_m": paths[index],
                  "observed_signed_displacement_m": signed[index], "observed_absolute_directional_travel_m": directional_paths[index]}
        if status == "INTERRUPTED":
            fields["interruption"] = interruption
        fields.update(extra)
        return _outcome(name, unit, status, reason, value, **fields)

    def na(name, unit, reason):
        return outcome(name, unit, "NOT_APPLICABLE", reason)

    def sustained(predicate, hold):
        start = None
        for index, row in enumerate(valid):
            if predicate(row):
                start = index if start is None else start
                if row["t"] - valid[start]["t"] >= hold - tolerance:
                    return start, index
            else:
                start = None
        return None

    settled = sustained(lambda row: _norm(row["relative_velocity"]) <= c["settle_linear_m_s"] and _norm(row["relative_angular"]) <= c["settle_angular_rad_s"], c["settle_hold_s"])
    reversed_window = sustained(lambda row: _dot(row["relative_velocity"], effort_axis) >= c["reverse_speed_m_s"], c["reverse_hold_s"])
    metrics = {}
    stopping = kind in {"release", "brake"}
    for name, unit in UNITS.items():
        metrics[name] = na(name, unit, "NO_MATCHING_TRANSITION_REQUESTED")
    if stopping:
        names = ["stop_distance_m", "settling_time_s"]
        if kind == "release":
            names += ["release_signed_drift_m", "release_absolute_directional_drift_m", "release_path_length_m"]
        for name in names:
            if settled:
                start, end = settled
                value = {"stop_distance_m": paths[end], "settling_time_s": valid[start]["t"] - t0,
                         "release_signed_drift_m": signed[end], "release_absolute_directional_drift_m": directional_paths[end], "release_path_length_m": paths[end]}[name]
                metrics[name] = outcome(name, UNITS[name], "MEASURED", "SUSTAINED_SETTLING_CONFIRMED", value, end,
                                        criterion_time_s=valid[start]["t"] - t0, confirmation_time_s=valid[end]["t"] - t0)
            else:
                metrics[name] = outcome(name, UNITS[name], terminal_status, terminal_reason)
        target = transition.get("stop_target_progress_m")
        if target is not None:
            end = settled[1] if settled else last
            excursion = max(0.0, max(signed[:end + 1]) - target - c["stop_target_corridor_m"])
            status = "MEASURED" if settled else terminal_status
            metrics["post_stop_overshoot_m"] = outcome("post_stop_overshoot_m", "m", status,
                "POST_STOP_WINDOW_TO_CONFIRMED_SETTLING" if settled else terminal_reason,
                excursion if settled else None, end, observed_max_post_stop_excursion_m=excursion)
        else:
            metrics["post_stop_overshoot_m"] = na("post_stop_overshoot_m", "m", "NO_SPATIAL_STOP_TARGET_DECLARED")
    if kind == "reverse":
        if reversed_window:
            start, end = reversed_window
            metrics["reversal_time_s"] = outcome("reversal_time_s", "s", "MEASURED", "SUSTAINED_OPPOSITE_VELOCITY_CONFIRMED",
                valid[start]["t"] - t0, end, criterion_time_s=valid[start]["t"] - t0, confirmation_time_s=valid[end]["t"] - t0)
        else:
            metrics["reversal_time_s"] = outcome("reversal_time_s", "s", terminal_status, terminal_reason)
    progress_status = "MEASURED" if full_window else terminal_status
    metrics["useful_progress_m"] = outcome("useful_progress_m", "m", progress_status,
        "DECLARED_OBSERVATION_HORIZON" if full_window else terminal_reason, signed[last] if full_window else None)
    if paths[last] <= c["movement_epsilon_m"]:
        metrics["directional_efficiency"] = outcome("directional_efficiency", "dimensionless", "PRECONDITION_NOT_MET", "UNDEFINED_NO_MOVEMENT")
    else:
        metrics["directional_efficiency"] = outcome("directional_efficiency", "dimensionless", progress_status,
            "SIGNED_PROGRESS_OVER_FULL_3D_RELATIVE_COM_PATH" if full_window else terminal_reason,
            signed[last] / paths[last] if full_window else None)
    braking = []
    for fraction in c["brake_fractions"]:
        entry = {"fraction": fraction, "threshold_speed_m_s": initial_speed * fraction}
        for field, unit in (("time_s", "s"), ("distance_m", "m")):
            name = f"active_braking_{field}"
            if kind != "brake":
                entry[field] = na(name, unit, "NO_ACTIVE_BRAKE_REQUESTED")
            else:
                end = min(last, brake_end) if brake_end is not None else last
                crossing = next((i for i in range(end + 1) if _norm(valid[i]["relative_velocity"]) <= initial_speed * fraction), None)
                if crossing is not None:
                    value = valid[crossing]["t"] - t0 if field == "time_s" else paths[crossing]
                    entry[field] = outcome(name, unit, "MEASURED", "SPEED_FRACTION_REACHED_DURING_OPPOSITE_COMMAND", value, crossing)
                elif brake_end is not None:
                    entry[field] = outcome(name, unit, "INTERRUPTED", "OPPOSITE_COMMAND_WINDOW_ENDED_BEFORE_SPEED_FRACTION", index=end,
                        interruption={"reason": "OPPOSITE_COMMAND_WINDOW_ENDED", "physics_time_s": valid[end]["t"], "tick": valid[end]["tick"]})
                else:
                    entry[field] = outcome(name, unit, terminal_status, terminal_reason)
        braking.append(entry)
    horizons = []
    for horizon in c["fixed_horizons_s"]:
        index = next((i for i, row in enumerate(valid) if abs(row["t"] - t0 - horizon) <= tolerance), None)
        if index is not None:
            value = outcome("fixed_horizon_progress_m", "m", "MEASURED", "DECLARED_FIXED_PHYSICS_HORIZON", signed[index], index)
        elif valid[last]["t"] - t0 > horizon + tolerance:
            value = outcome("fixed_horizon_progress_m", "m", "INVALID_MEASUREMENT", "HORIZON_NOT_ON_RECORDED_PHYSICS_GRID")
        else:
            value = outcome("fixed_horizon_progress_m", "m", terminal_status, terminal_reason)
        horizons.append({"horizon_s": horizon, **value})
    return {"metric_definition_version": VERSION, "metrics": metrics, "active_braking": braking, "fixed_horizons": horizons,
            "observation": {"sample_phase": c["sample_phase"], "ignored_other_phase_samples": ignored,
                            "initial_speed_m_s": initial_speed, "direction_world_at_onset": list(axis),
                            "accepted_effort_direction_world_at_onset": list(effort_axis) if kind in {"brake", "reverse"} else None,
                            "support_frame_id": support["frame_id"], "transition_kind": kind, "accepted_transition_tick": first["tick"],
                            "start_physics_time_s": t0, "deadline_physics_time_s": deadline,
                            "observed_end_physics_time_s": valid[last]["t"], "unconfirmed_metric_terminal_status": terminal_status,
                            "window_status": "INTERRUPTED" if interruption else ("COMPLETE" if full_window else "INCOMPLETE"),
                            "terminal_reason": terminal_reason, "interruption": interruption,
                            "settling_thresholds": {key: c[key] for key in ("settle_linear_m_s", "settle_angular_rad_s", "settle_hold_s")},
                            "reversal_thresholds": {key: c[key] for key in ("reverse_speed_m_s", "reverse_hold_s")}}}
