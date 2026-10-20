"""Four interpretable, baseline-scaled objectives, after independent hard gates.

Every axis is a worst-cell gain. One unit is at least the declared practical
floor, ten percent of baseline magnitude, or two baseline standard deviations.
This is a screening rule for the pilot, not statistical proof of better feel.
"""
from __future__ import annotations

import math
import statistics
from aggregate import distribution
from candidate_schema import finite_number

AXES = ("directed_progress", "precision", "physical_quality", "reliability")
DIRECTED = ("vertical_pull_train", "asymmetric_pull_train", "lateral_traverse_train", "foot_supported_step_train", "ground_grip_transition_train")
TWIST = ("vertical_pull_train", "asymmetric_pull_train", "lateral_traverse_train", "foot_supported_step_train")
SWING = ("one_hand_hang_train", "swing_catch_train")
FLOORS = {"useful_displacement_m": .01, "movement_latency_s": .03, "overshoot_m": .01,
          "reversal_latency_s": .05, "stop_distance_m": .01, "unwanted_twist_rms_rad": .03,
          "controllable_swing": .1, "grip_retention_rate": .1, "completion_rate": .1}


class Unrankable(ValueError):
    pass


class UnqualifiedTask(Unrankable):
    """Observed physical task loss; confirm once, never assign invented metrics."""


def complete_support_evidence(row: dict) -> bool:
    initial = row.get("initial_conditions", {})
    com = initial.get("com")
    return (isinstance(initial.get("grounded"), bool) and isinstance(initial.get("hands"), list)
            and isinstance(com, list) and len(com) == 3 and all(finite_number(value) for value in com)
            and isinstance(row.get("ground_contact_during_measurement"), bool)
            and isinstance(row.get("native_ground_authority_observed"), bool)
            and finite_number(row.get("ungrounded_supported_samples")) and row["ungrounded_supported_samples"] >= 0)


def qualification_issue(row: dict) -> str | None:
    """Lateral intent must be an actual supported climb, never a ground walk."""
    if row.get("id") != "lateral_traverse_train":
        return None
    initial = row.get("initial_conditions", {})
    hands = initial.get("hands", [])
    if initial.get("grounded") is not False or not isinstance(hands, list) or hands.count("ATTACHED") < 2:
        return "lateral start is not two attached hands without native ground support"
    if row.get("ground_contact_during_measurement") is not False:
        return "lateral measurement contains or cannot exclude native ground contact"
    if row.get("native_ground_authority_observed") is not False:
        return "lateral measurement contains or cannot exclude native ground motor authority"
    samples = row.get("ungrounded_supported_samples")
    if not finite_number(samples) or samples <= 0:
        return "lateral measurement has no qualified airborne supported sample"
    return None


def observed_rows(outcome):
    if outcome.get("status") != "completed":
        raise Unrankable(f"hard/runtime gate: {outcome.get('status')}: {outcome.get('reason')}")
    result = outcome.get("engine_result") or {}
    if result.get("status") != "completed" or any(result.get("invariants", {}).values()):
        raise Unrankable("engine hard gate")
    rows = result.get("scenarios", [])
    if not rows or any(any(row.get("invariants", {}).values()) for row in rows):
        raise Unrankable("scenario hard gate")
    return {row["id"]: row for row in rows}


def build_reference(outcomes: list[dict]) -> dict:
    if not 3 <= len(outcomes) <= 5:
        raise Unrankable("baseline requires three to five repeated evaluations")
    repeats = [observed_rows(outcome) for outcome in outcomes]
    invalid_starts = ("INVALID_START", "MISSING_ACTUAL_COM", "INITIAL_TARGET_NOT_OUTSIDE_STATIC_REACH",
                      "BASELINE_DRIFT", "PROTECTED_RESOURCE_CHANGED", "OVERRIDE_INSTALL_FAILED")
    for rows in repeats:
        for scenario, row in rows.items():
            if str(row.get("reason", "")).startswith(invalid_starts):
                raise Unrankable(f"invalid baseline fixture/readiness: {scenario}: {row['reason']}")
            issue = qualification_issue(row)
            if issue:
                raise Unrankable(f"invalid baseline fixture/readiness: {scenario}: {issue}")
    keys = set(repeats[0])
    if any(set(rows) != keys for rows in repeats):
        raise Unrankable("baseline scenario coverage differs between repeats")
    reference = {}
    for scenario in sorted(keys):
        samples = [rows[scenario] for rows in repeats]
        metric_names = sorted({key for row in samples for key in row["metrics"]})
        metrics = {key: distribution([row["metrics"].get(key) for row in samples]) for key in metric_names}
        metrics["completion_rate"] = distribution([int(row["completed"]) for row in samples])
        reference[scenario] = {"metrics": metrics, "revision": samples[0]["revision"],
                               "scope": samples[0].get("scope"), "capture": [row.get("capture") for row in samples]}
    missing = []
    for scenario in DIRECTED:
        if scenario not in reference or reference[scenario]["metrics"].get("useful_displacement_m", {}).get("n", 0) < len(outcomes):
            missing.append(f"{scenario}: signed actual-COM progress")
    if not any(reference.get(scenario, {}).get("metrics", {}).get("controllable_swing", {}).get("n", 0) == len(outcomes) for scenario in SWING):
        missing.append("hang/catch: measured controllable_swing; all-rotation penalty forbidden")
    if missing:
        raise Unrankable("baseline measurement gate: " + "; ".join(missing))
    # Reproducible baseline regression/noise gates are separate from candidate ranking.
    noisiness = []
    for scenario in DIRECTED:
        progress = reference[scenario]["metrics"]["useful_displacement_m"]
        if (progress["stdev"] or 0) > max(.015, .25 * abs(progress["mean"])):
            noisiness.append(scenario)
    return {"repeats": len(outcomes), "scenarios": reference, "noisy_directed_cells": noisiness,
            "scale": "max(practical floor, 10% abs baseline mean, 2 baseline sample SD)", "floors": FLOORS}


def compare(outcome: dict, reference: dict) -> dict:
    rows = observed_rows(outcome)
    axes = {axis: [] for axis in AXES}
    cells = []
    regressions = []
    for scenario, base in reference["scenarios"].items():
        if scenario not in rows or rows[scenario]["revision"] != base["revision"]:
            raise Unrankable(f"missing or changed fixture: {scenario}")
        row = rows[scenario]
        reason = str(row.get("reason", ""))
        if reason.startswith(("PREPARATION_FAILED", "INVALID_START_NOT_LOADED_HANG")):
            if complete_support_evidence(row) and row.get("completed") is False and row.get("status") == "failed_task":
                raise UnqualifiedTask(f"observed required-posture preparation failed: {scenario}: {reason}")
            raise Unrankable(f"preparation failure lacks complete actual support/COM evidence: {scenario}")
        issue = qualification_issue(row)
        if issue:
            if complete_support_evidence(row) and row.get("completed") is False and row.get("status") == "failed_task" and reason == "NATIVE_GROUND_CONTAMINATED":
                raise UnqualifiedTask(f"observed loss of qualified climbing support: {scenario}: {issue}")
            raise Unrankable(f"candidate has no qualified climbing measurement: {scenario}: {issue}")

        def metric(axis, name, direction, *, required=False):
            prior = base["metrics"].get(name, {"n": 0})
            value = float(row["completed"]) if name == "completion_rate" else row["metrics"].get(name)
            if prior.get("n", 0) != reference["repeats"]:
                if required:
                    raise Unrankable(f"baseline metric unavailable: {scenario}/{name}")
                return
            if not finite_number(value):
                raise Unrankable(f"candidate lost baseline measurement: {scenario}/{name}")
            scale = max(FLOORS[name], .1 * abs(prior["mean"]), 2 * (prior["stdev"] or 0))
            gain = direction * (value - prior["mean"]) / scale
            axes[axis].append(gain)
            cells.append({"scenario": scenario, "metric": name, "axis": axis, "baseline_mean": prior["mean"],
                          "baseline_sd": prior["stdev"], "candidate": value, "scale": scale, "gain": gain})
            if name == "useful_displacement_m" and scenario in ("asymmetric_pull_train", "lateral_traverse_train"):
                limit = max(.02, .25 * abs(prior["mean"]), 3 * (prior["stdev"] or 0))
                if value < prior["mean"] - limit:
                    regressions.append(f"essential directed regression: {scenario}")
            if name == "completion_rate" and prior["mean"] >= 2 / 3 and value == 0:
                regressions.append(f"lost baseline task completion: {scenario}")
            if name == "controllable_swing" and value < prior["mean"] - max(.2, 3 * (prior["stdev"] or 0)):
                regressions.append(f"lost measured swing control: {scenario}")

        if scenario in DIRECTED:
            metric("directed_progress", "useful_displacement_m", 1, required=True)
            for name in ("movement_latency_s", "overshoot_m", "reversal_latency_s", "stop_distance_m"):
                metric("precision", name, -1)
        if scenario in TWIST:
            metric("physical_quality", "unwanted_twist_rms_rad", -1)
        if scenario in SWING:
            metric("physical_quality", "controllable_swing", 1)
        metric("reliability", "completion_rate", 1, required=True)
        metric("reliability", "grip_retention_rate", 1)
    missing_axes = [axis for axis, values in axes.items() if not values]
    if missing_axes:
        raise Unrankable("missing objective measurements: " + ", ".join(missing_axes))
    values = [min(axes[axis]) for axis in AXES]
    if not all(math.isfinite(value) for value in values):
        raise Unrankable("nonfinite objective")
    meaningful = min(values) >= -.25 and max(values) >= 1.0 and not regressions
    return {"objective_names": list(AXES), "directions": ["maximize"] * 4, "values": values,
            "per_cell": cells, "regression_flags": regressions, "meaningful_screening_gain": meaningful,
            "decision": "candidate for repeated validation, never automatic promotion" if meaningful else "no demonstrated robust practical gain"}


def nondominated(records: list[dict]) -> list[dict]:
    feasible = [row for row in records if row.get("score") and row.get("status") == "completed"]
    return [row for row in feasible if not any(
        all(a >= b for a, b in zip(other["score"]["values"], row["score"]["values"]))
        and any(a > b for a, b in zip(other["score"]["values"], row["score"]["values"]))
        for other in feasible if other is not row)]
