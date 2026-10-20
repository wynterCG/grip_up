"""Compare evaluator receipts without inventing physical equivalence tolerances."""
from __future__ import annotations

import argparse
import gzip
import json
import math
from pathlib import Path

from common import atomic_json, read_json

IDENTITY = ("schema_version", "code_commit", "engine_identity", "expected_source_hashes", "metric_definition_version", "contract_sha256", "controller", "run_seed")


def iter_trace(directory: Path):
    path = directory / "trace.jsonl.gz"
    if path.exists():
        with gzip.open(path, "rt", encoding="utf-8") as handle:
            for line in handle:
                if line.strip():yield json.loads(line)
    else:
        path = directory / "trace.jsonl"
        if path.exists():
            with path.open(encoding="utf-8") as handle:
                for line in handle:
                    if line.strip():yield json.loads(line)


def read_trace(directory: Path, scenario_id=None):
    rows = [row for row in iter_trace(directory) if scenario_id is None or row.get("scenario_id") == scenario_id]
    event_path = directory / "events.jsonl.gz"
    if event_path.exists():
        event_text = gzip.decompress(event_path.read_bytes()).decode("utf-8")
    else:
        event_path = directory / "events.jsonl"
        event_text = event_path.read_text(encoding="utf-8") if event_path.exists() else ""
    events = {}
    for line in event_text.splitlines():
        if not line.strip():continue
        event = json.loads(line)
        if scenario_id is not None and event.get("scenario_id") != scenario_id:continue
        key = (event.get("scenario_id"), event.get("tick"), event.get("sample_phase"))
        # Continuous data remain in the raw event; compare transition order/hand.
        code = event.get("event_code", event.get("code"))
        if code in {"REQUEST_SELECTED", "TARGET_LOCKED", "REACHING", "ENTER_REACH_WINDOW", "EXIT_REACH_WINDOW", "PATH_CLEAR", "PATH_BLOCKED", "CONTACT_VALIDATED", "ATTACHED", "LOAD_ADMITTED", "RETAINED", "SLIPPING", "RELEASED", "FREE", "INPUT_RELEASE"}:
            events.setdefault(key, []).append({"code": code, "hand": event.get("hand", event.get("gesture", {}).get("hand"))})
    for row in rows:
        row.setdefault("contact_events", events.get((row.get("scenario_id"),row.get("tick"),row.get("sample_phase")), []))
    return rows


def channel(row, field):
    value = row[field]
    if field == "command_requested":
        return {key: value[key] for key in ("keys", "hand_held", "d") if key in value}
    if field == "command_accepted":
        return {key: value[key] for key in ("accepted_input", "hand_held", "input_owner", "blocked", "d") if key in value}
    if field == "target":
        return {key: value[key] for key in ("collider_key", "stable_id", "material_local_point_m", "material_local_normal") if key in value}
    if field == "hands" and isinstance(value, list):
        return [{key: hand[key] for key in ("id", "state", "attached", "reason") if key in hand} for hand in value]
    if field == "contact_events":
        return [{"code":event.get("actual_event",{}).get("code",event.get("event_code",event.get("code"))),
                 "hand":event.get("hand",event.get("actual_event",{}).get("hand",event.get("gesture",{}).get("hand")))} for event in value]
    return value


def stable(value):
    if isinstance(value, dict):
        return {key: stable(item) for key, item in value.items()
                if key not in {"runtime_id", "instance_id", "collider_runtime_id", "anchor_runtime_id", "wall_time_us", "wall_time_ms", "run_id"}}
    if isinstance(value, list):
        return [stable(item) for item in value]
    return value


def first_delta(left, right, *, epsilon=1e-6, path=""):
    if isinstance(left, dict) and isinstance(right, dict):
        if set(left) != set(right):
            return {"field": path, "left_keys": sorted(left), "right_keys": sorted(right)}
        for key in sorted(left):
            difference = first_delta(left[key], right[key], epsilon=epsilon, path=f"{path}.{key}".strip("."))
            if difference:
                return difference
        return None
    if isinstance(left, list) and isinstance(right, list):
        if len(left) != len(right):
            return {"field": path, "left_length": len(left), "right_length": len(right)}
        for index, (a, b) in enumerate(zip(left, right)):
            difference = first_delta(a, b, epsilon=epsilon, path=f"{path}[{index}]")
            if difference:
                return difference
        return None
    numeric = lambda x: type(x) in (int, float) and math.isfinite(x)
    if numeric(left) and numeric(right):
        return None if abs(left - right) <= epsilon else {"field": path, "left": left, "right": right, "absolute_difference": abs(left - right)}
    return None if type(left) is type(right) and left == right else {"field": path, "left": left, "right": right}


def validate_trace(rows):
    previous = {}
    for row in rows:
        if not isinstance(row, dict):
            raise ValueError("trace row is not an object")
        scenario, phase = row.get("scenario_id"), row.get("sample_phase")
        tick, time = row.get("tick"), row.get("physics_time_s")
        if not scenario or not phase or type(tick) is not int or type(time) not in (int, float) or not math.isfinite(time):
            raise ValueError("trace identity/phase/timestamp missing")
        key = (scenario, phase)
        if key in previous and (tick != previous[key][0]+1 or time <= previous[key][1]):
            raise ValueError("nonconsecutive or nonmonotonic trace sample within scenario/phase")
        previous[key] = (tick, time)


def compare(left_manifest, right_manifest, left_rows, right_rows):
    mismatches = [key for key in IDENTITY if key not in left_manifest or key not in right_manifest or left_manifest[key] is None or right_manifest[key] is None or left_manifest[key] != right_manifest[key]]
    result = {"schema_version": "1.3.1", "status": "NOT_COMPARABLE", "identity_mismatches": mismatches,
              "interpretation": "State-difference detector, not a calibrated physical-equivalence or game-feel score",
              "first_behavioral_difference": None, "first_observed_state_difference": None, "differences": [], "human_sessions": 0}
    if mismatches:
        result["reason"] = "manifest identity mismatch"
        return result
    if not left_rows or not right_rows:
        result["reason"] = "high-frequency trace missing or recorder disabled"
        return result
    try:
        validate_trace(left_rows); validate_trace(right_rows)
    except ValueError as exc:
        result["reason"] = str(exc)
        return result
    phases_a = {row["sample_phase"] for row in left_rows}
    phases_b = {row["sample_phase"] for row in right_rows}
    if phases_a != phases_b:
        result["reason"] = "sample-phase mismatch; pre/post samples are not interchangeable"
        return result
    if left_manifest["physics_hz"] != right_manifest["physics_hz"]:
        result.update(status="CROSS_HZ_EVENT_TIME_ONLY", reason="Different tick grids; compare event times/outcomes and per-mode distributions separately")
        return result
    epsilon = left_manifest.get("contract", {}).get("comparison_contract", {}).get("float_difference_detection", 1e-6)
    def index(rows):
        # Driver ticks may be process-global; align each scenario's own phase grid.
        starts = {}
        indexed = {}
        for row in rows:
            starts.setdefault(row["scenario_id"], row["tick"])
            relative = row.get("episode_tick", row["tick"] - starts[row["scenario_id"]])
            indexed[(row["scenario_id"], row["sample_phase"], relative)] = row
        return indexed
    a, b = index(left_rows), index(right_rows)
    result["unpaired_sample_counts"] = {"left": len(set(a) - set(b)), "right": len(set(b) - set(a))}
    peaks = {"com_m": 0.0, "linear_velocity_m_s": 0.0, "angular_velocity_rad_s": 0.0}
    groups = (("command_requested", "REQUESTED_INPUT_DIVERGENCE"), ("command_accepted", "ACCEPTED_INPUT_DIVERGENCE"),
              ("target", "TARGET_DIVERGENCE"), ("contact_events", "CONTACT_EVENT_DIVERGENCE"), ("hands", "GRIP_STATE_DIVERGENCE"))
    first_groups = set()
    # Preserve actual scenario occurrence order instead of alphabetically reordering episodes.
    for key in a:
        if key not in b:
            continue
        row_a, row_b = a[key], b[key]
        context = {"scenario_id": key[0], "sample_phase": key[1], "relative_tick": key[2],
                   "left_tick": row_a["tick"], "right_tick": row_b["tick"],
                   "left_physics_time_s": row_a["physics_time_s"], "right_physics_time_s": row_b["physics_time_s"]}
        for field, classification in groups:
            if field not in row_a or field not in row_b:
                result["reason"] = f"missing required comparison field {field}"
                return result
            difference = first_delta(stable(channel(row_a,field)), stable(channel(row_b,field)), epsilon=epsilon, path=field)
            if difference and (key[0], field) not in first_groups:
                entry = {**context, "classification": classification, **difference}
                result["differences"].append(entry); first_groups.add((key[0], field))
                if result["first_behavioral_difference"] is None:
                    result["first_behavioral_difference"] = entry
        difference = first_delta(stable(row_a.get("body")), stable(row_b.get("body")), epsilon=epsilon, path="body")
        if difference and result["first_observed_state_difference"] is None:
            result["first_observed_state_difference"] = {**context, **difference}
        for field in peaks:
            va, vb = row_a.get("body", {}).get(field), row_b.get("body", {}).get(field)
            if isinstance(va, list) and isinstance(vb, list) and len(va) == len(vb) == 3:
                peaks[field] = max(peaks[field], math.dist(va, vb))
    result.update(status="ALIGNED_DIAGNOSTIC", reason="Same manifest policy and sample phases; physical acceptance requires separately calibrated envelope",
                  peak_vector_difference=peaks, physical_equivalence_certified=False)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("left", type=Path); parser.add_argument("right", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--scenario", default="swing_catch_train")
    args = parser.parse_args()
    result = compare(read_json(args.left / "manifest.json"), read_json(args.right / "manifest.json"), read_trace(args.left,args.scenario), read_trace(args.right,args.scenario))
    atomic_json(args.output, result)
    print(result["status"], result["reason"])


if __name__ == "__main__":
    main()
