"""v132 input identity, immutable tape and phase contracts. No gameplay writes."""
from __future__ import annotations

import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from common import digest, file_hash, read_json, atomic_json
from compare_traces import first_delta, stable

SCHEMA = "grip_up_replay_v132"
ACTIONS = {"contract", "extend", "bias_left", "bias_right"}


def finite(value):
    digest(value)  # allow_nan=False recursively; bool is not accepted as a vector below


def vector(value, count, field):
    if not isinstance(value, list) or len(value) != count or any(type(x) not in (int, float) or not math.isfinite(x) for x in value):
        raise ValueError("INVALID_VECTOR:" + field)


def validate_ticks(ticks, hz):
    if hz not in (60, 120) or not isinstance(ticks, list) or not 1 <= len(ticks) <= 10240:
        raise ValueError("CLOCK_MISMATCH:TICKS_HZ")
    held = [False, False]
    for expected, row in enumerate(ticks, 1):
        finite(row)
        if row.get("physics_tick") != expected:
            raise ValueError("CLOCK_MISMATCH:DROPPED_OR_DUPLICATE_TICK")
        if row.get("sample_phase") != "post_control":
            raise ValueError("PHASE_MISMATCH")
        if abs(row.get("delta_s", -1) - 1 / hz) > 1e-7 or abs(row.get("physics_time_s", -1) - expected / hz) > 1e-6:
            raise ValueError("CLOCK_MISMATCH:DELTA_TIME")
        requested = row["requested"]
        keys = requested["keys"]
        if not isinstance(keys, list) or len(keys) != len(set(keys)) or not set(keys) <= ACTIONS:
            raise ValueError("REQUEST_MISMATCH:KEYS")
        vector(requested["cursor_before_px"], 2, "cursor_before")
        vector(requested["cursor_after_px"], 2, "cursor_after")
        vector(requested["cursor_normalized"], 2, "cursor_normalized")
        # Current frozen policy never orbits/dollies. Reject unsupported events;
        # zero camera inputs are explicit, not inferred from equal ray hits.
        if requested["camera_input"] != {"orbit_dx": 0., "orbit_dy": 0., "dolly": 0.}:
            raise ValueError("CAMERA_TARGET_MISMATCH:UNSUPPORTED_CAMERA_INPUT")
        for event in requested["gestures"]:
            if type(event["hand"]) is not int or event["hand"] not in (0, 1) or type(event["pressed"]) is not bool or type(event["motion"]) is not bool:
                raise ValueError("REQUEST_MISMATCH:GESTURE")
            vector(event["cursor_px"], 2, "event_cursor")
            vector(event["relative_px"], 2, "event_relative")
            held[event["hand"]] = event["pressed"]
        if requested["hand_held"] != held:
            raise ValueError("REQUEST_MISMATCH:HELD_RELEASE_HISTORY")
        accepted = row["accepted"]
        vector(accepted["accepted_input"], 2, "accepted")
        vector(accepted["intent_world"], 3, "effective_direction")
        if accepted["hand_held"] != held:
            raise ValueError("INPUT_ROUTER_MISMATCH:FOCUS_OR_RELEASE")
        if "emitted_observed" in row:
            observed=row["emitted_observed"]
            if observed["hand_held"]!=held:raise ValueError("INPUT_ROUTER_MISMATCH:EMITTED_HELD")
            if first_delta(observed["cursor_after_px"],requested["cursor_after_px"],epsilon=1e-6):raise ValueError("REQUEST_MISMATCH:EMITTED_CURSOR")
        if accepted["input_owner"] not in ("GAME", "CAMERA", "UI") or type(accepted["blocked"]) is not bool or type(accepted["window_has_focus"]) is not bool:
            raise ValueError("INPUT_ROUTER_MISMATCH:GATE_METADATA")
        if len(row["effective"]) != 2:
            raise ValueError("GRIP_DECISION_MISMATCH:MISSING_HAND")
        for name in ("com_m","linear_velocity_m_s","angular_velocity_rad_s"):
            vector(row["body"][name],3,"body."+name)
        if not isinstance(row["target"],dict) or not isinstance(row["camera"],dict):
            raise ValueError("CAMERA_TARGET_MISMATCH:METADATA")
        for i,hand in enumerate(row["effective"]):
            if hand["id"]!=i or hand["state"] not in ("FREE","REACHING","ATTACHED","SLIPPING","RELEASED"):
                raise ValueError("GRIP_DECISION_MISMATCH:HAND_ID_STATE")
            vector(hand["force_n"],3,"hand.force_n")
    return True


def accepted_stream(ticks):
    # Physical world intent is audited separately from the normalized logical
    # router intent. Focus is metadata; actual cancellation changes held/raw.
    return [{"physics_tick": r["physics_tick"], **{k: r["accepted"][k] for k in ("accepted_input", "hand_held", "input_owner", "blocked")}} for r in ticks]


def fixture_map(initial):
    if "fixture_identity" in initial:
        return {item["identity"]["key"]:stable(item) for item in initial["fixture_identity"]}
    result = {}
    for hand in initial.get("hands", []):
        support = hand["support"]
        if support["key"] != "NONE":result[support["key"]] = support.get("type")
    return result


def initial_fields(initial):
    configuration = dict(initial["configuration"])
    configuration.pop("observer_enabled", None)
    camera = {key: value for key, value in initial["camera"].items() if key != "physics_interpolation_fraction"}
    # Stable node identities, never process runtime IDs, are physical setup keys.
    return stable({"body": initial["body"], "hands": initial["hands"], "support": initial["support"],
                   "configuration": configuration, "camera": camera, "profile": initial["profile"],
                   "fixture_identity":initial.get("fixture_identity")})


def make_tape(run_dir, destination):
    run_dir, destination = Path(run_dir), Path(destination)
    if destination.exists():raise FileExistsError("immutable tape exists")
    manifest = read_json(run_dir / "manifest.json")
    audit = read_json(run_dir / "swing_catch_train_audit.json")
    validate_ticks(audit["ticks"], audit["physics_hz"])
    trace_path = run_dir / "trace.jsonl.gz"
    if not trace_path.exists():trace_path = run_dir / "trace.jsonl"
    tape = {"schema": SCHEMA, "replay_lane": "R0_REQUESTED_INPUT", "scenario_id": "swing_catch_train", "scenario_revision": 3,
            "physics_hz": manifest["physics_hz"], "source_run_id": manifest["run_id"], "source_trace_id": file_hash(trace_path),
            "engine_build": manifest["engine_identity"], "source_hashes": manifest["expected_source_hashes"],
            "source_policy": "declared_state_policy_r2/shared_physics_tick_v1; frozen angular threshold -0.04",
            "scenario_sha256": manifest["catch_definition_sha256"], "bindings": audit["bindings"],
            "initial_state": audit["initial_state"], "fixture_map": fixture_map(audit["initial_state"]),
            "ticks": audit["ticks"], "source_manifest_sha256": file_hash(run_dir / "manifest.json"),
            "accepted_reference_sha256": digest(accepted_stream(audit["ticks"])),
            "camera_scope": "actual follow camera; no orbit/dolly requested by source policy; recorded pixel events are replayed without world projection"}
    tape["tape_sha256"] = digest(tape)
    atomic_json(destination, tape)
    return tape


def validate_tape(tape, manifest=None):
    if tape.get("schema") != SCHEMA or tape.get("replay_lane") != "R0_REQUESTED_INPUT":
        raise ValueError("NOT_COMPARABLE:TAPE_SCHEMA")
    body = {k:v for k,v in tape.items() if k != "tape_sha256"}
    if digest(body) != tape.get("tape_sha256"):
        raise ValueError("NOT_COMPARABLE:TAPE_HASH")
    validate_ticks(tape["ticks"], tape["physics_hz"])
    if digest(accepted_stream(tape["ticks"])) != tape["accepted_reference_sha256"]:
        raise ValueError("NOT_COMPARABLE:ACCEPTED_REFERENCE_HASH")
    if fixture_map(tape["initial_state"]) != tape["fixture_map"]:
        raise ValueError("SETUP_MISMATCH:FIXTURE_MAP")
    if manifest:
        for a,b in (("physics_hz","physics_hz"),("engine_build","engine_identity"),("source_hashes","expected_source_hashes"),("scenario_sha256","catch_definition_sha256")):
            if tape[a] != manifest[b]:raise ValueError("SETUP_MISMATCH:" + a)
    return True


def compare_audits(reference, actual, *, observer_may_differ=False):
    result = {"status":"NOT_COMPARABLE", "matched_accepted_through_tick":0, "matched_effective_through_tick":0,
              "first_divergence":None, "first_native_difference":None, "physics_equivalence_certified":False}
    try:
        if reference["physics_hz"] != actual["physics_hz"]:raise ValueError("CLOCK_MISMATCH:HZ")
        validate_ticks(reference["ticks"], reference["physics_hz"]);validate_ticks(actual["ticks"], actual["physics_hz"])
    except (ValueError, KeyError, TypeError) as exc:
        result["reason"] = str(exc);return result
    if reference["bindings"] != actual["bindings"]:
        result["reason"]="SETUP_MISMATCH:BINDINGS";return result
    if not observer_may_differ and reference["initial_state"]["configuration"].get("observer_enabled")!=actual["initial_state"]["configuration"].get("observer_enabled"):
        result["reason"]="OBSERVER_STATE_MISMATCH";return result
    diff = first_delta(initial_fields(reference["initial_state"]), initial_fields(actual["initial_state"]))
    if diff:
        result.update(reason="SETUP_MISMATCH", initial_difference=diff);return result
    a, b = reference["ticks"], actual["ticks"]
    first = None
    matched_logical = 0
    matched_effective = 0
    firsts = {}
    for left, right in zip(a,b):
        tick=left["physics_tick"]
        logical_a,logical_b=accepted_stream([left])[0],accepted_stream([right])[0]
        logical_diff=first_delta(logical_a,logical_b,epsilon=0)
        if logical_diff is None and matched_logical==tick-1:matched_logical=tick
        # Force magnitude is native response, not a grip decision; anchor IDs are
        # process-local but same-anchor retention is checked within each run.
        def effective(r):
            return [{k:v for k,v in h.items() if k not in ("force_n","anchor_runtime_id","support_runtime_id")} for h in r["effective"]]
        checks=[("REQUEST_MISMATCH",left["requested"],right["requested"],0),
                ("INPUT_ROUTER_MISMATCH",logical_a,logical_b,0),
                ("CAMERA_TARGET_MISMATCH",stable(left["target"]),stable(right["target"]),1e-6),
                ("GRIP_DECISION_MISMATCH",effective(left),effective(right),1e-6),
                ("EFFECTIVE_DIRECTION_MISMATCH",left["accepted"]["intent_world"],right["accepted"]["intent_world"],1e-6)]
        for classification,x,y,epsilon in checks:
            difference=first_delta(x,y,epsilon=epsilon)
            if difference and classification not in firsts:firsts[classification]={"tick":tick,"difference":difference}
            if difference and first is None:first={"classification":classification,"tick":tick,"difference":difference}
        if first is None:matched_effective=tick
        native=first_delta(left["body"],right["body"])
        if native and result["first_native_difference"] is None:
            result["first_native_difference"]={"tick":tick,"difference":native,"before_input_or_effective_divergence":first is None}
    if len(a)!=len(b) and first is None:first={"classification":"NOT_COMPARABLE","tick":min(len(a),len(b))+1,"reason":"TICK_COVERAGE"}
    result.update(status="MATCHED_INPUTS_TO_TICK_N" if first is None else first["classification"],
                  matched_accepted_through_tick=matched_logical,matched_effective_through_tick=matched_effective,
                  first_divergence=first,first_by_channel=firsts,
                  accepted_reference_sha256=digest(accepted_stream(a)),accepted_actual_sha256=digest(accepted_stream(b)),
                  interpretation="Identity/localization only. No calibrated continuous-physics or game-feel equivalence follows from input identity.")
    return result
