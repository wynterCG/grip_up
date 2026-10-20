"""Strict Stage-1 transport. Physics owns the certified parameter resource."""
from __future__ import annotations

import math
import hashlib
from pathlib import Path
import re
from common import ROOT, canonical, digest, read_json

SCHEMA_VERSION = "1.0"
PARAMETER_IDS = (
    "traversal_speed_m_s", "traversal_input_ramp_s",
    "traversal_target_max_rate", "traversal_target_max_acceleration",
)
FIELDS = {
    "schema_version", "trial_id", "candidate_id", "profile", "parameter_overrides", "scenarios",
    "requested_physics_hz", "input_trace_id", "run_seed", "repository_commit", "timeout_seconds",
    "source_hashes", "engine_identity", "evaluation_split",
}
STATUSES = {"completed", "failed_invariant", "invalid_candidate", "failed_runtime", "timed_out", "unsupported_scenario", "cancelled"}


class InvalidCandidate(ValueError):
    pass


def finite_number(value) -> bool:
    return type(value) in (int, float) and math.isfinite(value)


def parameter_resource(project: Path = ROOT) -> dict:
    return read_json(project / "features/auto_tuning_lab/resources/parameter_space.json")


def parameter_rows(resource: dict) -> dict:
    parameters = resource["parameters"]
    if isinstance(parameters, dict):
        return parameters
    return {row["id"]: row for row in parameters}


def validate_overrides(overrides: dict, resource: dict) -> dict:
    if not isinstance(overrides, dict) or set(overrides) != set(PARAMETER_IDS):
        raise InvalidCandidate("overrides must contain exactly the four certified parameter IDs")
    rows = parameter_rows(resource)
    if resource.get("schema_version") != SCHEMA_VERSION or resource.get("version") != "AT1-r1":
        raise InvalidCandidate("unknown parameter schema/version")
    if set(rows) != set(PARAMETER_IDS):
        raise InvalidCandidate("parameter resource does not match Stage-1 schema")
    for key, value in overrides.items():
        row = rows[key]
        if not finite_number(value) or not row["min"] <= value <= row["max"]:
            raise InvalidCandidate(f"invalid/out-of-range {key}: {value!r}")
        if abs(value - round(value, 8)) > 1e-12:
            raise InvalidCandidate(f"{key} exceeds certified eight-decimal transport precision")
    stop_distance = overrides["traversal_target_max_rate"] ** 2 / (2 * overrides["traversal_target_max_acceleration"])
    if stop_distance > 0.055 + 1e-12:
        raise InvalidCandidate("coupled slew stopping distance exceeds certified 0.055m envelope")
    return overrides


def baseline(resource: dict) -> dict:
    return validate_overrides({key: parameter_rows(resource)[key]["baseline"] for key in PARAMETER_IDS}, resource)


def candidate_id(overrides: dict) -> str:
    # Fixed decimal transport is identical in Python and Godot (no exponent/float repr ambiguity).
    fields = [f'"{key}":' + format(float(overrides[key]), ".8f").rstrip("0").rstrip(".") for key in sorted(overrides)]
    return hashlib.sha256(("{" + ",".join(fields) + "}").encode("utf-8")).hexdigest()


def validate_candidate(candidate: dict, resource: dict, allowed_scenarios: set[str] | None = None) -> dict:
    def require(condition, message):
        if not condition:
            raise InvalidCandidate(message)

    require(isinstance(candidate, dict) and set(candidate) == FIELDS, "unknown or missing candidate field")
    require(candidate["schema_version"] == SCHEMA_VERSION, "unsupported schema version")
    require(candidate["profile"] == "BASE-A0-B1", "initial search only permits explicit A0/B1 with physical feet")
    require(candidate["evaluation_split"] in {"train", "holdout", "safety"}, "invalid evaluation split")
    for key in ("trial_id", "input_trace_id"):
        require(isinstance(candidate[key], str) and re.fullmatch(r"[A-Za-z0-9_-]{1,100}", candidate[key]) is not None, f"unsafe {key}")
    validate_overrides(candidate["parameter_overrides"], resource)
    require(candidate["candidate_id"] == candidate_id(candidate["parameter_overrides"]), "candidate ID is not canonical parameter SHA256")
    require(type(candidate["requested_physics_hz"]) is int and candidate["requested_physics_hz"] in (60, 120), "unsupported physics frequency")
    require(type(candidate["run_seed"]) is int and 0 <= candidate["run_seed"] <= 2**31 - 1, "invalid seed")
    require(finite_number(candidate["timeout_seconds"]) and 1 <= candidate["timeout_seconds"] <= 1800, "invalid timeout")
    require(isinstance(candidate["repository_commit"], str) and re.fullmatch(r"[0-9a-f]{40}", candidate["repository_commit"]) is not None, "invalid observed repository revision")
    scenarios = candidate["scenarios"]
    require(isinstance(scenarios, list) and 1 <= len(scenarios) <= 32 and all(isinstance(x, str) and re.fullmatch(r"[A-Za-z0-9_-]{1,100}", x) for x in scenarios) and len(scenarios) == len(set(scenarios)), "empty/duplicate/unsafe scenario list")
    if allowed_scenarios is not None:
        require(set(scenarios) <= allowed_scenarios, "unsupported scenario")
    hashes = candidate["source_hashes"]
    require(isinstance(hashes, dict) and bool(hashes), "missing source hash map")
    for key, value in hashes.items():
        require(isinstance(key, str) and not key.startswith("/") and "\\" not in key and ":" not in key and ".." not in key.split("/") and "" not in key.split("/"), "unsafe source path")
        require(isinstance(value, str) and re.fullmatch(r"[0-9a-f]{64}", value) is not None, "invalid source hash")
    identity = candidate["engine_identity"]
    require(isinstance(identity, dict) and set(identity) == {"version", "sha256"}, "invalid engine identity")
    require(isinstance(identity["version"], str) and identity["version"], "missing engine version")
    require(isinstance(identity["sha256"], str) and re.fullmatch(r"[0-9a-f]{64}", identity["sha256"]) is not None, "invalid engine binary hash")
    canonical(candidate)
    return candidate
