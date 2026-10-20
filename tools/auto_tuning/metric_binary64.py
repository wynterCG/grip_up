"""Source-ordered scalar binary64 audit arithmetic; never a physics controller.

Paths start at +0.0 and add magnitudes in POST tick order. Three-term
expressions follow Godot's ((x*x)+(y*y))+(z*z), without an extra +0 seed.
Integer vector components are accepted only at the existing vector-schema
boundary; scalar segment streams require genuine binary64 floats.
"""
from __future__ import annotations

import hashlib
import importlib.metadata
import json
import locale
import math
from pathlib import Path
import platform
import sqlite3
import struct
import sys

CONTRACT = "ordered_binary64_sequential_v1"
SCHEMA = "metric_binary64_audit_v1"


def scalar(value):
    if type(value) is not float or not math.isfinite(value):
        raise ValueError("FINITE_BINARY64_FLOAT_REQUIRED")
    return value


def bits(value):
    return struct.pack(">d", scalar(value)).hex()


def sum_binary64_ordered(values, *, nonnegative=False):
    total = 0.0
    for value in values:
        scalar(value)
        if nonnegative and value < 0.0:
            raise ValueError("NEGATIVE_PATH_SEGMENT")
        total = total + value
        scalar(total)  # Finite operands can still overflow the accumulator.
    return total


def vector3(value):
    if not isinstance(value, (list, tuple)) or len(value) != 3:
        raise ValueError("VECTOR3_REQUIRED")
    if any(type(x) not in (int, float) for x in value):
        raise ValueError("FINITE_VECTOR_COMPONENT_REQUIRED")
    return tuple(scalar(float(x)) for x in value)


def dot3(a, b):
    a, b = vector3(a), vector3(b)
    p0, p1, p2 = scalar(a[0]*b[0]), scalar(a[1]*b[1]), scalar(a[2]*b[2])
    return scalar(scalar(p0+p1)+p2)


def norm3(value):
    value = vector3(value)
    return scalar(math.sqrt(dot3(value, value)))


def _canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()


def _hash(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def canonical_metric_contract_id():
    return {"id": CONTRACT, "schema": SCHEMA, "source_sha256": _hash(__file__),
            "expression": "path=+0; ascending POST: path=path+sqrt(((dx*dx)+(dy*dy))+(dz*dz)); no FMA"}


def environment_identity():
    root = Path(__file__).resolve().parents[2]
    value = {"executable": str(Path(sys.executable).resolve()), "executable_sha256": _hash(sys.executable),
             "base_executable": str(Path(sys._base_executable).resolve()),
             "base_executable_sha256": _hash(sys._base_executable),
             "prefix": sys.prefix, "base_prefix": sys.base_prefix,
             "sys_version": sys.version, "version": platform.python_version(),
             "packages": {d.metadata["Name"]: d.version for d in importlib.metadata.distributions()},
             "dependency_lock_sha256": _hash(root/"tools/auto_tuning/uv.lock"),
             "locale": list(locale.getlocale()), "platform": platform.platform(),
             "architecture": platform.machine(), "pointer_bits": struct.calcsize("P")*8,
             "byteorder": sys.byteorder, "float_info": repr(sys.float_info),
             "binary64_bytes": struct.calcsize("d"), "sqlite_version": sqlite3.sqlite_version,
             "reducer": canonical_metric_contract_id()}
    value["sha256"] = hashlib.sha256(_canonical(value)).hexdigest()
    return value


def environment_fingerprint():
    return environment_identity()["sha256"]


def require_environment(expected=None):
    root = Path(__file__).resolve().parents[2]
    pinned = root/"tools/auto_tuning/.venv/Scripts/python.exe"
    current = environment_identity()
    if (Path(sys.executable).resolve() != pinned.resolve() or current["version"] != "3.13.13"
            or importlib.metadata.version("optuna") != "5.0.0"
            or importlib.metadata.version("matplotlib") != "3.10.8"
            or sys.float_info.mant_dig != 53 or sys.float_info.radix != 2):
        raise ValueError("PINNED_CAMPAIGN_ENVIRONMENT_REQUIRED")
    if expected is not None:
        expected_hash = expected["sha256"] if isinstance(expected, dict) else expected
        if current["sha256"] != expected_hash:
            raise ValueError("CAMPAIGN_ENVIRONMENT_CHANGED")
    return current


def validate_ordered_segments(payload, *, expected_identity=None):
    """Validate an immutable JSON-compatible segment stream and its provenance.

    Hash covers endpoints, phase, unit, ordered tick/value bits and provenance.
    A non-measured payload carries null, never a partial numeric path.
    """
    if not isinstance(payload, dict) or payload.get("schema") != SCHEMA or payload.get("reducer_contract") != CONTRACT:
        raise ValueError("UNKNOWN_METRIC_SCHEMA_OR_REDUCER")
    if payload.get("unit") != "m" or payload.get("phase") != "POST":
        raise ValueError("METRIC_UNIT_OR_PHASE")
    rows = payload.get("segments")
    first, last = payload.get("first_tick"), payload.get("last_tick")
    if type(first) is not int or type(last) is not int or last < first or not isinstance(rows, list):
        raise ValueError("INVALID_METRIC_WINDOW")
    if payload.get("status") != "MEASURED":
        if payload.get("value") is not None:
            raise ValueError("NONMEASURED_METRIC_MUST_BE_NULL")
        raise ValueError("COMPLETE_MEASURED_WINDOW_REQUIRED")
    if len(rows) != last-first:
        raise ValueError("MISSING_OR_DUPLICATED_SEGMENT")
    values = []
    for tick, row in enumerate(rows, first+1):
        if (not isinstance(row, dict) or type(row.get("tick")) is not int or row["tick"] != tick
                or row.get("phase") != "POST"):
            raise ValueError("SEGMENT_ORDER_OR_PHASE")
        value = scalar(row.get("value"))
        if value < 0.0 or bits(value) != row.get("bits_be") or value.hex() != row.get("float_hex"):
            raise ValueError("SEGMENT_VALUE_OR_BITS")
        values.append(value)
    identity = {key: payload.get(key) for key in ("schema", "reducer_contract", "status", "unit", "phase", "first_tick", "last_tick", "provenance", "segments")}
    actual_hash = hashlib.sha256(_canonical(identity)).hexdigest()
    if actual_hash != payload.get("sequence_sha256") or expected_identity is not None and actual_hash != expected_identity:
        raise ValueError("METRIC_SEQUENCE_IDENTITY")
    result = sum_binary64_ordered(values, nonnegative=True)
    if bits(result) != bits(payload.get("value")):
        raise ValueError("METRIC_RESULT_BITS")
    return values


def segment_payload(rows, *, provenance):
    if not rows:
        raise ValueError("EMPTY_POST_WINDOW")
    first = rows[0]["tick"]
    segments = []
    for index, row in enumerate(rows):
        if type(row.get("tick")) is not int or row["tick"] != first+index or row.get("sample_phase") != "post_control":
            raise ValueError("NONCONSECUTIVE_POST_WINDOW")
        position = vector3(row["body"]["com_m"])
        # Actual DirectBodyState COM is a native Vector3, promoted without loss.
        for component in position:
            native = struct.unpack("<f", struct.pack("<f", component))[0]
            if bits(native) != bits(component):
                raise ValueError("COM_NOT_NATIVE_FLOAT32_PROMOTED_TO_BINARY64")
        if index:
            segment = norm3(tuple(a-b for a, b in zip(previous, position)))
            segments.append({"tick": row["tick"], "phase": "POST", "value": segment,
                             "bits_be": bits(segment), "float_hex": segment.hex()})
        previous = position
    payload = {"schema": SCHEMA, "reducer_contract": CONTRACT, "status": "MEASURED", "unit": "m", "phase": "POST",
               "first_tick": first, "last_tick": rows[-1]["tick"], "provenance": provenance, "segments": segments}
    payload["sequence_sha256"] = hashlib.sha256(_canonical(payload)).hexdigest()
    payload["value"] = sum_binary64_ordered((s["value"] for s in segments), nonnegative=True)
    validate_ordered_segments(payload)
    return payload


def audit_path_against_godot(ticks, summary, runtime, provenance, *, observe_s):
    observation = summary["observation"]
    onset, end = observation.get("onset_tick"), observation.get("end_tick")
    status = observation["status"]
    receipt = {"schema": SCHEMA, "metric": "path_3d_m", "status": status, "unit": "m",
               "window": {"first_tick": onset, "last_tick": end, "phase": "POST"},
               "reducer_contract": canonical_metric_contract_id(), "provenance": provenance,
               "value": None, "reason_code": observation["reason_code"]}
    if onset is None or end is None:
        if summary.get("path3d_onset_to_end") is not None or runtime.get("path3d_onset_to_end") is not None:
            raise ValueError("NO_WINDOW_WITH_NUMERIC_PATH")
        receipt.update(audit_result="TYPED_NULL_NO_AUTHORIZED_WINDOW", segment_count=0)
        return receipt
    rows = [row for row in ticks if onset <= row["tick"] <= end]
    payload = segment_payload(rows, provenance=provenance)
    if len(rows) != end-onset+1:
        raise ValueError("PATH_ENDPOINT_OR_CONTINUITY")
    if status == "MEASURED" and end-onset != round(observe_s*rows[0]["physics_hz"]):
        raise ValueError("COMPLETE_PATH_HORIZON_MISMATCH")
    computed = payload["value"]
    for key in ("path3d_onset_to_end", "signed_progress_m"):
        published, audited = runtime.get(key), summary.get(key)
        if published is None or audited is None or bits(published) != bits(audited):
            raise ValueError("INDEPENDENT_METRIC_RECOMPUTE:"+key)
    if bits(computed) != bits(summary["path3d_onset_to_end"]):
        raise ValueError("SHARED_PATH_REDUCER_NOT_USED")
    receipt.update(segment_count=len(payload["segments"]), segment_stream_sha256=hashlib.sha256(b"".join(struct.pack("<d", r["value"]) for r in payload["segments"])).hexdigest(),
                   sequence_sha256=payload["sequence_sha256"], published_binary64_bits=bits(runtime["path3d_onset_to_end"]),
                   recomputed_binary64_bits=bits(computed), float_hex=computed.hex(),
                   audit_result="EXACT_MATCH" if status == "MEASURED" else "EXACT_MATCH_RAW_PARTIAL_NOT_SCORE",
                   value=computed if status == "MEASURED" else None)
    return receipt
