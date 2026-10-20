"""Read-only v133 measurements. No candidate score and no gameplay writes."""
from __future__ import annotations

import copy
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from metric_contracts import STATUSES, analyze
from metric_binary64 import norm3, dot3, sum_binary64_ordered, CONTRACT as REDUCER_CONTRACT

VERSION = "benchmark_eval_v135a_metrics_r1"
UNITS = {
    "signed_progress_m": "m", "latency_to_useful_motion_s": "s",
    "directional_efficiency": "dimensionless", "overshoot_after_release_m": "m",
    "stop_path_3d_m": "m", "settling_time_s": "s",
    "brake_fraction_reached": "dimensionless", "reversal_time_s": "s",
    "catch_success": "binary", "retention_s": "s",
    "foot_load_contribution": "dimensionless", "twist_rms_rad": "rad",
    "hard_physical_violations": "count",
}
CONTRACT = {"useful_velocity_m_s": .02, "useful_dwell_s": .05,
            "path_floor_m": 1e-6, "settle_linear_m_s": .1,
            "settle_angular_rad_s": .2, "settle_hold_s": .25}


def number(value):
    return type(value) in (float, int) and math.isfinite(value)


def vector(value):
    if not isinstance(value, (list, tuple)) or len(value) != 3 or not all(number(x) for x in value):
        raise ValueError("INVALID_VECTOR")
    return tuple(float(x) for x in value)


def norm(value):
    return norm3(value)


def dot(a, b):
    return dot3(a, b)


def sub(a, b):
    return tuple(x-y for x, y in zip(a, b))


def outcome(metric, status, reason, onset=None, end=None, value=None, **extra):
    if status not in STATUSES or status == "MEASURED" and not number(value):
        raise ValueError("INVALID_TYPED_METRIC")
    return {"metric": metric, "unit": UNITS[metric], "status": status,
            "value": value if status == "MEASURED" else None,
            "reason_code": reason, "onset_tick": onset, "end_tick": end,
            "event_provenance": "actual_post_control_trace", **extra}


def _blank(status, reason, onset=None):
    return {"metric_definition_version": VERSION, "contract": dict(CONTRACT),
            "metrics": {name: outcome(name, status, reason, onset) for name in UNITS},
            "observation": {"status": status, "reason_code": reason},
            "task_succeeded": False, "ranking_eligible": False,
            "signed_progress_m": None, "path3d_onset_to_end": None}


def _foot_load(row):
    load = 0.
    for foot in row["feet"]:
        force = vector(foot["force_n"])
        compressive = foot["normal_force_n"]
        if not number(compressive) or compressive < 0:
            raise ValueError("INVALID_FOOT_COMPRESSION")
        if foot["state"] in {"SUPPORTING", "SLIDING"}:
            if foot.get("support", {}).get("key") in {None, "NONE"}:
                if norm(force) > 1e-6:
                    raise ValueError("FOOT_FORCE_WITHOUT_SUPPORT")
            else:
                load += compressive
    return load


def _support_reason(row, anchors):
    extra = row.get("benchmark_extra", {})
    support = row["support"]
    budgets = row["force_budget"]
    if "ground_clearance_status" in extra and extra["ground_clearance_status"] != "CLEAR_QUERIED_SEGMENT":
        return "GROUND_CLEARANCE_NOT_CERTIFIED"
    if support["grounded"] or extra["native_ground_authority"] or norm(vector(budgets["ground_force_n"])) > .0001 or norm(vector(budgets["ground_torque_nm"])) > .0001:
        return "NATIVE_GROUND_AUTHORITY_CHANGED_TASK"
    if support["hybrid_owned"]:
        return "HYBRID_AUTHORITY_CHANGED_TASK"
    if not support["valid"]:
        return "SUPPORT_LOST"
    for hand, anchor in zip(row["hands"], anchors):
        if hand["state"] != "ATTACHED" or hand["anchor_runtime_id"] != anchor:
            return "TWO_HAND_ANCHOR_SUPPORT_LOST"
        if "support" in hand and hand["support"].get("key") in {None, "NONE"}:
            return "TWO_HAND_ANCHOR_SUPPORT_LOST"
    return None


def _validate_rows(ticks):
    if not isinstance(ticks, list) or not ticks:
        raise ValueError("EMPTY_TRACE")
    if any(row.get("sample_phase") != "post_control" for row in ticks):
        raise ValueError("MIXED_OR_NON_POST_PHASE")
    rows = copy.deepcopy(ticks)
    if not rows:
        raise ValueError("MISSING_POST_CONTROL")
    hz = rows[0].get("physics_hz")
    if hz not in (60, 120):
        raise ValueError("INVALID_PHYSICS_HZ")
    previous = None
    for row in rows:
        tick = row.get("tick")
        if type(tick) is not int or row.get("physics_hz") != hz:
            raise ValueError("TICK_OR_HZ_CONTRACT")
        if not number(row.get("physics_time_s")) or not number(row.get("delta_s")) or abs(row["delta_s"]-1/hz) > 1e-7 or abs(row["physics_time_s"]-tick/hz) > 1e-6:
            raise ValueError("CLOCK_CONTRACT")
        if previous is not None and tick != previous+1:
            raise ValueError("DUPLICATE_OR_MISSING_TICK")
        previous = tick
        for key in ("com_m", "linear_velocity_m_s", "angular_velocity_rad_s"):
            vector(row["body"][key])
        vector(row["command_accepted"]["intent_world"])
        support = row["support"]
        if any(type(support.get(key)) is not bool for key in ("valid", "grounded", "hybrid_owned")):
            raise ValueError("MISSING_ACTUAL_SUPPORT_FLAGS")
        if type(row.get("benchmark_extra", {}).get("native_ground_authority")) is not bool:
            raise ValueError("MISSING_NATIVE_GROUND_AUTHORITY")
        hands = row["hands"]
        if len(hands) != 2 or [h["id"] for h in hands] != [0, 1]:
            raise ValueError("HAND_IDENTITY")
        for hand in hands:
            vector(hand["force_n"])
            if type(hand["anchor_runtime_id"]) is not int or hand["state"] not in {"FREE", "REACHING", "ATTACHED", "SLIPPING", "RELEASED"}:
                raise ValueError("HAND_STATE_OR_ANCHOR")
        _foot_load(row)
        budgets = row["force_budget"]
        for key in ("hands_n", "feet_n"):
            if not number(budgets[key]) or budgets[key] < 0:
                raise ValueError("INVALID_FORCE_BUDGET")
        for key in ("assist_nm", "combined_nm", "ground_force_n", "ground_torque_nm"):
            vector(budgets[key])
    return rows, hz


def summarize(ticks, definition, onset_certificate):
    """Independent recomputation from published POST rows, never a simulator."""
    onset = onset_certificate.get("onset_tick") if isinstance(onset_certificate, dict) else None
    if onset is None:
        return _blank("PRECONDITION_NOT_MET", onset_certificate.get("reason_code", "NO_VALID_ONSET") if isinstance(onset_certificate, dict) else "NO_VALID_ONSET")
    try:
        if type(onset) is not int or definition["kind"] not in {"progress", "release_stop"}:
            raise ValueError("INVALID_ONSET_OR_TASK_KIND")
        if any(type(definition.get(key)) is not bool for key in ("physical_feet", "require_foot_load")):
            raise ValueError("MISSING_TASK_SUPPORT_POLICY")
        axis = vector(definition["direction_world"])
        length = norm(axis)
        if length == 0 or not number(definition["observe_s"]) or definition["observe_s"] <= 0:
            raise ValueError("INVALID_DIRECTION_OR_HORIZON")
        axis = tuple(x/length for x in axis)
        rows, hz = _validate_rows(ticks)
        matching = [row for row in rows if row["tick"] == onset]
        if len(matching) != 1 or matching[0] != onset_certificate["certificate"]:
            raise ValueError("ONSET_CERTIFICATE_NOT_RECORDED_POST")
        first = matching[0]
        anchors = [hand["anchor_runtime_id"] for hand in first["hands"]]
        if not all(anchors) or _support_reason(first, anchors) or sum_binary64_ordered((norm(vector(h["force_n"])) for h in first["hands"]), nonnegative=True) <= 1:
            return _blank("PRECONDITION_NOT_MET", "ACTUAL_TWO_HAND_LOADED_ONSET_REQUIRED", onset)
        if definition.get("require_foot_load", False) and _foot_load(first) <= 1:
            return _blank("PRECONDITION_NOT_MET", "ACTUAL_COMPRESSIVE_FOOT_LOAD_REQUIRED", onset)
        if not definition.get("physical_feet", False) and any(norm(vector(f["force_n"])) > 1e-6 for f in first["feet"]):
            return _blank("INVALID_MEASUREMENT", "FEET_FORCE_WHILE_DECLARED_OFF", onset)
        if definition["kind"] == "release_stop" and norm(vector(first["command_accepted"]["intent_world"])) > 1e-6:
            return _blank("PRECONDITION_NOT_MET", "RELEASE_NOT_ACTUALLY_ACCEPTED", onset)
        if definition["kind"] == "progress" and dot(vector(first["command_accepted"]["intent_world"]), axis) <= 1e-6:
            return _blank("PRECONDITION_NOT_MET", "POSITIVE_DIRECTED_COMMAND_NOT_ACTUALLY_ACCEPTED", onset)
        if definition["kind"] == "progress":
            quiet_start = onset-1-round(.25*hz)
            quiet = [row for row in rows if quiet_start <= row["tick"] <= onset]
            if len(quiet) != round(.25*hz)+2:
                return _blank("PRECONDITION_NOT_MET", "PRIOR_QUIET_DWELL_NOT_RECORDED", onset)
            for row in quiet:
                relative = sub(vector(row["body"]["linear_velocity_m_s"]), vector(row["support"]["point_velocity_m_s"]))
                spin = vector(row["body"]["angular_velocity_rad_s"])
                if (_support_reason(row, anchors) or abs(dot(relative, axis)) > .1 or norm(spin) > .2
                        or sum_binary64_ordered((norm(vector(h["force_n"])) for h in row["hands"]), nonnegative=True) <= 1
                        or definition["require_foot_load"] and _foot_load(row) <= 1):
                    return _blank("PRECONDITION_NOT_MET", "QUIET_DWELL_OR_ACCEPTED_ONSET_NOT_ELIGIBLE", onset)
        else:
            directed = dot(sub(vector(first["body"]["linear_velocity_m_s"]), vector(first["support"]["point_velocity_m_s"])), axis)
            if not .15 <= directed <= .5:
                return _blank("PRECONDITION_NOT_MET", "DIRECTED_STOP_ONSET_SPEED_OUTSIDE_015_050", onset)
        contract = {"physics_hz": hz, "sample_phase": "post_control", "direction_world": list(axis),
                    "deadline_s": definition["observe_s"], "settle_linear_m_s": .1,
                    "settle_angular_rad_s": .2, "settle_hold_s": .25}
        for row in rows:
            if row["tick"] >= onset:
                reason = _support_reason(row, anchors)
                if reason:
                    row["interruption"] = {"reason": reason}
        kind = "release" if definition["kind"] == "release_stop" else "none"
        legacy = analyze(rows, contract, {"kind": kind, "tick": onset, "physics_time_s": first["physics_time_s"], "stop_target_progress_m": 0.} if kind == "release" else {"kind": kind, "tick": onset, "physics_time_s": first["physics_time_s"]})
        if legacy["observation"].get("status") == "INVALID_MEASUREMENT":
            raise ValueError(legacy["observation"]["reason"])
        deadline = first["physics_time_s"]+definition["observe_s"]
        selected, interruption = [], None
        for row in rows:
            if row["tick"] < onset or row["physics_time_s"] > deadline+1e-6:
                continue
            reason = _support_reason(row, anchors)
            if reason or row.get("interruption"):
                interruption = {"tick": row["tick"], "reason_code": reason or row["interruption"].get("reason", "EXPLICIT_INTERRUPTION")}
                break
            selected.append(row)
        end = selected[-1]["tick"]
        complete = selected[-1]["physics_time_s"] >= deadline-1e-6
        terminal = "INTERRUPTED" if interruption else "CENSORED_TIMEOUT" if complete else "INVALID_MEASUREMENT"
        why = interruption["reason_code"] if interruption else "CRITERION_NOT_REACHED_BEFORE_DEADLINE" if complete else "TRACE_ENDED_BEFORE_DEADLINE"
        requested_end = onset_certificate.get("end_tick")
        if requested_end is not None and (type(requested_end) is not int or requested_end != end):
            raise ValueError("END_CERTIFICATE_NOT_ACTUAL_AUTHORIZED_END")
        positions = [vector(row["body"]["com_m"]) for row in selected]
        path = sum_binary64_ordered((norm(sub(b, a)) for a, b in zip(positions, positions[1:])), nonnegative=True)
        progress = dot(sub(positions[-1], positions[0]), axis)
        result = _blank("NOT_APPLICABLE", "NOT_DEFINED_FOR_TASK", onset)
        metrics = result["metrics"]
        def put(name, status, reason, value=None, end_tick=end, **extra):
            metrics[name] = outcome(name, status, reason, onset, end_tick, value, **extra)
        status = "MEASURED" if complete else terminal
        put("signed_progress_m", status, "FIXED_AUTHORIZED_WORLD_COM_WINDOW" if complete else why, progress)
        if path > 1e-6:
            put("directional_efficiency", status, "SIGNED_PROGRESS_OVER_3D_WORLD_COM_PATH" if complete else why, progress/path)
        else:
            put("directional_efficiency", "PRECONDITION_NOT_MET", "PATH_BELOW_DECLARED_FLOOR")
        candidate = None
        useful = None
        for row in selected:
            qualifies = dot(vector(row["body"]["linear_velocity_m_s"]), axis) > .02
            if qualifies:
                candidate = row if candidate is None else candidate
                if (row["tick"]-candidate["tick"])/hz >= .05-1e-9:
                    useful = (candidate, row)
                    break
            else:
                candidate = None
        if definition["kind"] == "progress":
            previous = next(row for row in rows if row["tick"] == onset-1)
            prior_directed_velocity = dot(vector(previous["body"]["linear_velocity_m_s"]), axis)
            if prior_directed_velocity > .02:
                put("latency_to_useful_motion_s", "PRECONDITION_NOT_MET", "ALREADY_MOVING_BEFORE_ONSET",
                    prior_tick=previous["tick"], prior_directed_velocity_m_s=prior_directed_velocity,
                    observed_useful_event={"criterion_tick": useful[0]["tick"], "confirmation_tick": useful[1]["tick"]} if useful else None)
            elif useful:
                put("latency_to_useful_motion_s", "MEASURED", "POSITIVE_VELOCITY_SUSTAINED", (useful[0]["tick"]-onset)/hz, useful[1]["tick"], criterion_tick=useful[0]["tick"], confirmation_tick=useful[1]["tick"])
            else:
                put("latency_to_useful_motion_s", terminal, why)
        if kind == "release":
            for source, target in (("stop_distance_m", "stop_path_3d_m"), ("settling_time_s", "settling_time_s"), ("post_stop_overshoot_m", "overshoot_after_release_m")):
                old = legacy["metrics"][source]
                confirmed = onset+round(old.get("confirmation_time_s", old.get("observed_duration_s", 0) or 0)*hz)
                put(target, old["status"], old["reason"], old["value"], confirmed, legacy_definition=legacy["metric_definition_version"])
        foot_integral = hand_integral = 0.
        for row in selected[1:]:
            foot_integral += _foot_load(row)/hz
            hand_integral += sum_binary64_ordered((max(0., vector(h["force_n"])[1]) for h in row["hands"]), nonnegative=True)/hz
        if definition.get("physical_feet", False):
            total = foot_integral+hand_integral
            put("foot_load_contribution", status if total > 1e-6 else "PRECONDITION_NOT_MET", "COMPRESSIVE_FOOT_IMPULSE_OVER_FOOT_PLUS_UPWARD_HAND_IMPULSE" if total > 1e-6 else "NO_OBSERVED_SUPPORT_LOAD", foot_integral/total if total > 1e-6 else None)
        if selected and all(row.get("benchmark_extra", {}).get("twist_frame_valid") is True and number(row["benchmark_extra"].get("twist_rad")) for row in selected):
            put("twist_rms_rad", status, "DECLARED_SUPPORT_RELATIVE_TWIST" if complete else why, math.sqrt(sum_binary64_ordered((float(row["benchmark_extra"]["twist_rad"])**2 for row in selected), nonnegative=True)/len(selected)))
        violations = []
        for row in rows:
            for hand in row["hands"]:
                if hand["state"] not in {"ATTACHED", "SLIPPING"} and norm(vector(hand["force_n"])) > 1e-6:
                    violations.append({"tick": row["tick"], "reason_code": "PENDING_OR_FREE_HAND_FORCE", "hand": hand["id"]})
            b = row["force_budget"]
            if b["hands_n"] > 360.001 or b["feet_n"] > 180.001 or norm(vector(b["assist_nm"])) > 20.001 or norm(vector(b["combined_nm"])) > 150.001 or any(norm(vector(f["force_n"])) > 120.001 for f in row["feet"]):
                violations.append({"tick": row["tick"], "reason_code": "PUBLISHED_FORCE_OR_TORQUE_CAP"})
            if not definition["physical_feet"] and any(norm(vector(f["force_n"])) > 1e-6 for f in row["feet"]):
                violations.append({"tick": row["tick"], "reason_code": "FEET_FORCE_WHILE_DECLARED_OFF"})
        put("hard_physical_violations", "MEASURED", "EXISTING_PUBLISHED_LIMIT_MONITORS_SCOPE", len(violations), violations=violations)
        result.update(observation={"status": "MEASURED" if complete else terminal, "reason_code": "AUTHORIZED_HORIZON_COMPLETE" if complete else why,
                                   "onset_tick": onset, "end_tick": end, "interruption": interruption,
                                   "physics_hz": hz, "direction_world": list(axis), "support_frame": first["support"]["frame_id"],
                                   "raw_scope": "world COM; static common support required by legacy stop contract"},
                      signed_progress_m=progress, path3d_onset_to_end=path,
                      task_succeeded=complete and progress > 0 and not violations if kind == "none" else metrics["stop_path_3d_m"]["status"] == "MEASURED" and not violations,
                      ranking_eligible=False,
                      eligibility_reason="DOMAIN_REPLAY_NEGATIVE_CONTROL_AND_REPLICATION_GATES_REQUIRED",
                      legacy_stop_analysis=legacy if kind == "release" else None)
        return result
    except (ValueError, KeyError, TypeError, IndexError, OverflowError) as exc:
        return _blank("INVALID_MEASUREMENT", str(exc), onset)


def required_cells_complete(cells, required):
    """Null-safe canary for a future worst-cell policy; deliberately no score."""
    if not isinstance(cells, dict) or not isinstance(required, (list, tuple)) or not required or any(not isinstance(key, str) or not key for key in required) or len(set(required)) != len(required):
        return {"complete": False, "missing_or_unmeasured": [], "worst_measured_value": None,
                "reason_code": "INVALID_REQUIRED_CELL_CATALOG"}
    missing = [key for key in required if key not in cells or not isinstance(cells[key], dict)
               or cells[key].get("status") != "MEASURED" or not number(cells[key].get("value"))]
    return {"complete": not missing, "missing_or_unmeasured": sorted(missing),
            "worst_measured_value": min((cells[key]["value"] for key in required), default=None) if not missing else None}
