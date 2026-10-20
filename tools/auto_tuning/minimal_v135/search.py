"""Bounded MBQ proposal/score helpers. No engine, holdout or gameplay writes.

Root owns qualification, immutable physical receipts and process execution.
Use ProposalStudy only inside its context (one worker) and after MB2 GO.
Scores are the two signed progress values; other dimensions are hard screens
and preserved typed observations, never an invented aggregate reward.
"""
from __future__ import annotations

import copy
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from candidate_schema import (PARAMETER_IDS, baseline, candidate_id, finite_number,
                              parameter_rows, validate_overrides)
from common import StudyLock, digest

VERSION = "minimal_v135_score_r3"
TRAIN_IDS = ("vertical_pull_clean_v134_r2", "lateral_clean_right_v134_r2")
PLAN = {"sensitivity": 8, "random": 6, "tpe": 4}
PERTURBATIONS = {
    "traversal_speed_m_s": (.22, .28),
    "traversal_input_ramp_s": (.10, .14),
    "traversal_target_max_rate": (.21, .27),
    "traversal_target_max_acceleration": (.75, 1.05),
}
STATUSES = {"MEASURED", "INTERRUPTED", "PRECONDITION_NOT_MET", "CENSORED_TIMEOUT",
            "INVALID_MEASUREMENT", "NOT_APPLICABLE"}


def validate_parameters(values, registry):
    """Exact existing whitelist/8-decimal canonical transport plus 60-Hz ramp."""
    validate_overrides(values, registry)
    if values["traversal_input_ramp_s"] * 60 < 4:
        raise ValueError("digital ramp must span at least four 60-Hz steps")
    return candidate_id(values)


def sensitivity_proposals(registry):
    center = baseline(registry)
    proposals = []
    for key in PARAMETER_IDS:
        for side, value in zip(("lower", "upper"), PERTURBATIONS[key]):
            values = {**center, key: value}
            proposals.append({"label": f"{key}_{side}", "parameter_overrides": values,
                              "candidate_id": validate_parameters(values, registry)})
    return proposals


class Budget:
    """Reserve BEFORE launching. Failures/retries consume non-refundable slots.

    18 full candidates use 36 launches/36 episodes. Four more launches are
    reserved for complete two-task confirmations, not extra proposals.
    Persist snapshot() in the root immutable study ledger after each reserve.
    """
    def __init__(self, reservations=()):
        self.reservations = []
        for row in reservations:
            self.reserve(**row)

    def reserve(self, attempt_id, processes=2, episodes=2, confirmation=False):
        if (not isinstance(attempt_id, str) or not attempt_id
                or any(row["attempt_id"] == attempt_id for row in self.reservations)):
            raise ValueError("missing or reused attempt identity")
        if type(confirmation) is not bool or type(processes) is not int or type(episodes) is not int:
            raise ValueError("invalid budget types")
        if processes != 2 or episodes != 2:
            raise ValueError("reserve one complete V+R pair, two processes/two episodes")
        launches = sum(row["processes"] for row in self.reservations)
        total = sum(row["episodes"] for row in self.reservations)
        proposals = sum(not row["confirmation"] for row in self.reservations)
        confirmations = len(self.reservations) - proposals
        if (launches + processes > 40 or total + episodes > 160
                or not confirmation and proposals >= 18
                or confirmation and confirmations >= 2):
            raise ValueError("declared budget exhausted; no partial candidate launch")
        self.reservations.append(dict(attempt_id=attempt_id, processes=processes,
                                      episodes=episodes, confirmation=confirmation))
        return self.snapshot()

    def snapshot(self):
        return copy.deepcopy(self.reservations)


def _typed(row, name):
    metric = row.get("metrics", {}).get(name)
    if not isinstance(metric, dict) or metric.get("status") not in STATUSES:
        raise ValueError(f"missing/malformed typed metric {name}")
    if metric["status"] == "MEASURED":
        if not finite_number(metric.get("value")):
            raise ValueError(f"nonfinite/nonnumeric measured {name}")
    elif metric.get("value") is not None:
        raise ValueError(f"official non-measured value must be null: {name}")
    return metric


def _result(disposition, reasons, dimensions=None, values=None, practical=False, cells=None):
    return {"version": VERSION, "disposition": disposition, "eligible": disposition == "COMPLETE",
            "reasons": reasons, "values": values, "objective_names": list(TRAIN_IDS),
            "directions": ["maximize", "maximize"], "four_dimensions": dimensions,
            "practical_gain": practical, "per_task": cells or [],
            "scope": "two fixed tapes at 120Hz; no statistical significance, transfer or human acceptance"}


def project_score(candidate, reference, quality_contract):
    """Project root-verified evidence, preserving summarize() typed objects.

    candidate: lane='FIXED_TAPE', physics_hz=120, booleans run_valid,
    source_identity_ok, teardown_ok, hard_invariants_pass; scenarios={ID:summary}.
    reference: same envelope from fresh qualified A0 (not historical values).
    quality_contract: {'frozen':True,'tasks':{ID:{metric:{direction:'minimize'|
    'maximize', max_worsening:finite>=0, allowed_missing:[{status,reason_code}]}}}}.
    Rules/allowances must be frozen from fresh A0 BEFORE any physical proposal.
    No quality metric is inferred from a null or renamed whole-body rotation.
    Official non-MEASURED metric values must be null. The root adapter preserves
    original partial-window values separately in raw_summary/evidence; such
    archived observations are never accepted as official score values.
    """
    try:
        if (not isinstance(quality_contract, dict) or quality_contract.get("frozen") is not True
                or set(quality_contract.get("tasks", {})) != set(TRAIN_IDS)):
            raise ValueError("missing frozen two-task quality contract")
        dimensions = {"directed_progress": {}, "movement_fidelity": {},
                      "physics_control_quality": {}, "reliability": {}}
        for label, envelope in (("baseline", reference), ("candidate", candidate)):
            if not isinstance(envelope, dict) or envelope.get("lane") != "FIXED_TAPE" or envelope.get("physics_hz") != 120:
                raise ValueError(f"{label}: wrong scoring lane/frequency")
            if set(envelope.get("scenarios", {})) != set(TRAIN_IDS):
                raise ValueError(f"{label}: missing/extra training domains; no holdout data accepted")
            for field in ("run_valid", "source_identity_ok", "teardown_ok", "hard_invariants_pass"):
                if envelope.get(field) is not True:
                    raise ValueError(f"{label}: infrastructure/invariant gate {field}")
        reasons, cells, objectives, changes = [], [], [], []
        for scenario in TRAIN_IDS:
            row, prior = candidate["scenarios"][scenario], reference["scenarios"][scenario]
            for label, summary in (("baseline", prior), ("candidate", row)):
                for metric_name in summary.get("metrics", {}):
                    _typed(summary, metric_name)
                hard = _typed(summary, "hard_physical_violations")
                progress = _typed(summary, "signed_progress_m")
                if hard["status"] == "MEASURED" and hard["value"] != 0:
                    raise ValueError(f"{label}/{scenario}: physical invariant")
                if hard["status"] != "MEASURED" and not (label == "candidate"
                        and progress["status"] in {"PRECONDITION_NOT_MET", "INTERRUPTED", "CENSORED_TIMEOUT"}
                        and hard["status"] == "PRECONDITION_NOT_MET"):
                    raise ValueError(f"{label}/{scenario}: missing physical monitor")
                if progress["status"] == "INVALID_MEASUREMENT":
                    raise ValueError(f"{label}/{scenario}: invalid progress measurement")
                complete = (progress["status"] == "MEASURED"
                            and summary.get("observation", {}).get("status") == "MEASURED"
                            and type(progress.get("onset_tick")) is int
                            and type(progress.get("end_tick")) is int
                            and progress["end_tick"] > progress["onset_tick"]
                            and summary.get("task_succeeded") is True)
                if not complete:
                    if label == "baseline":
                        raise ValueError(f"baseline/{scenario}: mandatory qualified task unavailable")
                    reasons.append(f"{scenario}: actual task/onset/full-window failure {progress['status']}")
            metrics = copy.deepcopy(row["metrics"])
            dimensions["directed_progress"][scenario] = metrics["signed_progress_m"]
            dimensions["movement_fidelity"][scenario] = {k: v for k, v in metrics.items() if k in
                ("directional_efficiency", "latency_to_useful_motion_s", "backwards_excursion_m")}
            dimensions["physics_control_quality"][scenario] = {k: v for k, v in metrics.items() if k not in
                ("signed_progress_m", "directional_efficiency", "latency_to_useful_motion_s", "backwards_excursion_m")}
            dimensions["reliability"][scenario] = {"task_succeeded": row.get("task_succeeded"),
                                                     "observation": copy.deepcopy(row.get("observation"))}
            rules = quality_contract["tasks"][scenario]
            if not isinstance(rules, dict) or "directional_efficiency" not in rules:
                raise ValueError("directional efficiency requires a prospective quality rule")
            for metric, rule in rules.items():
                if not isinstance(rule, dict) or rule.get("direction") not in ("minimize", "maximize") or not finite_number(rule.get("max_worsening")) or rule["max_worsening"] < 0:
                    raise ValueError(f"invalid quality rule {metric}")
                observed, base = _typed(row, metric), _typed(prior, metric)
                if "INVALID_MEASUREMENT" in (observed["status"], base["status"]):
                    raise ValueError(f"invalid quality measurement {scenario}/{metric}")
                if observed["status"] != "MEASURED" or base["status"] != "MEASURED":
                    def allowed(value):
                        return any(value["status"] == x.get("status") and value.get("reason_code") == x.get("reason_code") for x in rule.get("allowed_missing", []))
                    if base["status"] != "MEASURED" and not allowed(base):
                        raise ValueError(f"baseline quality unavailable {scenario}/{metric}")
                    if observed["status"] != "MEASURED" and not allowed(observed):
                        reasons.append(f"{scenario}/{metric}: lost required quality measurement")
                    continue
                worsening = (observed["value"] - base["value"]) * (1 if rule["direction"] == "minimize" else -1)
                if worsening > rule["max_worsening"] + 1e-12:
                    reasons.append(f"{scenario}/{metric}: predeclared quality regression")
            if row["metrics"]["signed_progress_m"]["status"] == "MEASURED":
                value = row["metrics"]["signed_progress_m"]["value"]
                base_value = prior["metrics"]["signed_progress_m"]["value"]
                delta = value - base_value
                gain = max(.010, .05 * abs(base_value))
                loss = max(.005, .03 * abs(base_value))
                cells.append(dict(scenario=scenario, baseline=base_value, candidate=value,
                                  paired_difference_m=delta, practical_gain_floor_m=gain,
                                  max_loss_m=loss))
                objectives.append(value); changes.append(delta >= gain - 1e-12)
                if delta < -loss - 1e-12:
                    reasons.append(f"{scenario}: predeclared primary progress regression")
        if reasons:
            return _result("REJECT_CANDIDATE", reasons, dimensions, cells=cells)
        return _result("COMPLETE", [], dimensions, objectives, any(changes), cells)
    except (ValueError, KeyError, TypeError, OverflowError) as exc:
        return _result("STOP_STUDY", [str(exc)])


def pareto(records, baseline_record):
    """Archive always includes explicit A0; frontier may mathematically exclude it."""
    if baseline_record.get("score", {}).get("eligible") is not True:
        raise ValueError("Pareto requires explicit eligible fresh A0")
    archive, seen = [], set()
    for record in [baseline_record, *records]:
        key = record["candidate_id"]
        if key not in seen:
            archive.append(copy.deepcopy(record)); seen.add(key)
    valid = [r for r in archive if (r.get("score") or {}).get("eligible") is True]
    for r in valid:
        if not isinstance(r["score"].get("values"), list) or len(r["score"]["values"]) != 2 or not all(finite_number(v) for v in r["score"]["values"]):
            raise ValueError("malformed Pareto objectives")
    frontier = [r for r in valid if not any(all(x >= y for x, y in zip(o["score"]["values"], r["score"]["values"])) and any(x > y for x, y in zip(o["score"]["values"], r["score"]["values"])) for o in valid)]
    promising = [r for r in frontier if r["candidate_id"] != baseline_record["candidate_id"] and r["score"].get("practical_gain") is True]
    return {"archive": archive, "frontier": frontier, "shortlist": sorted(promising, key=lambda r:r["candidate_id"])[:3], "baseline_in_archive": True}


class ProposalStudy:
    """Single-worker SQLite ask/tell only; never executes a physical process.

    qualification={'decision':'GO_MINIMAL_BENCHMARK','identity_sha256':digest(identity)}.
    Root must provide authentic MB2 evidence, freeze identity and audit ledger
    before resume. Unresolved RUNNING trials stop; they are never auto-retried.
    """
    def __init__(self, directory, identity, registry, qualification):
        self.directory, self.identity, self.registry = Path(directory), identity, registry
        if qualification.get("decision") != "GO_MINIMAL_BENCHMARK" or qualification.get("identity_sha256") != digest(identity):
            raise ValueError("MB2 GO matching frozen study identity required")
        if type(identity.get("seed")) is not int or not 0 <= identity["seed"] <= 2**31-1:
            raise ValueError("invalid optimizer seed")
        self.guard = digest({"identity": identity, "registry": registry, "plan": PLAN, "version": VERSION})
        self.lock = StudyLock(self.directory)

    def __enter__(self):
        self.lock.__enter__()
        try:
            import optuna
            if optuna.__version__ != "5.0.0":
                raise ValueError("pinned Optuna5.0.0 required")
            self.optuna = optuna
            storage = "sqlite:///" + (self.directory / "study.sqlite3").resolve().as_posix()
            from sqlalchemy.pool import NullPool
            self.storage = optuna.storages.RDBStorage(storage, engine_kwargs={"poolclass": NullPool})
            self.study = optuna.create_study(storage=self.storage, study_name="minimal_v135", directions=["maximize"]*2, load_if_exists=True)
            old = self.study.user_attrs.get("identity_sha256")
            if old is not None and old != self.guard:
                raise ValueError("resume identity/registry/plan/score mismatch")
            if old is None and self.study.trials:
                raise ValueError("untrusted preexisting SQLite trials")
            self.study.set_user_attr("identity_sha256", self.guard)
            self.live_trials = {}
            return self
        except BaseException:
            if hasattr(self, "storage"):
                self.storage.remove_session()
                self.storage.engine.dispose()
            self.lock.__exit__(*sys.exc_info()); raise

    def __exit__(self, *args):
        try:
            self.storage.remove_session()
            self.storage.engine.dispose()
        finally:
            self.lock.__exit__(*args)

    def ask(self, *, tpe_ready=False):
        state = self.optuna.trial.TrialState
        if self.study.user_attrs.get("global_stop") is not None:
            raise ValueError("study stopped globally; preserve receipts, no further proposals")
        trials = self.study.get_trials(deepcopy=False)
        if any(t.state in (state.RUNNING, state.WAITING) for t in trials):
            raise ValueError("unresolved prior trial; audit receipts before continuing")
        index = len(trials)
        if index >= sum(PLAN.values()):
            return None
        phase = "sensitivity" if index < 8 else "random" if index < 14 else "tpe"
        if phase == "tpe" and tpe_ready is not True:
            raise ValueError("informative eligible pilot gate required before TPE")
        seed = (self.identity["seed"] + index) % (2**32)
        self.study.sampler = (self.optuna.samplers.TPESampler(seed=seed, n_startup_trials=0, constant_liar=False) if phase == "tpe" else self.optuna.samplers.RandomSampler(seed=seed))
        if phase == "sensitivity":
            self.study.enqueue_trial(sensitivity_proposals(self.registry)[index]["parameter_overrides"])
        trial = self.study.ask()
        self.live_trials[trial.number] = trial
        values = {key: round(trial.suggest_float(key, parameter_rows(self.registry)[key]["min"], parameter_rows(self.registry)[key]["max"]), 8) for key in PARAMETER_IDS}
        proposal = {"phase": phase, "proposal_index": index, "optuna_trial": trial.number, "parameter_overrides": values, "status": "PROPOSED"}
        proposal["candidate_id"] = candidate_id(values)
        try:
            key = validate_parameters(values, self.registry)
            seen = {t.user_attrs.get("candidate_id") for t in trials} | {candidate_id(baseline(self.registry))}
            proposal["candidate_id"] = key
            if key in seen:
                proposal.update(status="DUPLICATE", reason="canonical configuration already proposed or A0")
        except ValueError as exc:
            proposal.update(status="INVALID_PARAMETERS", reason=str(exc))
        for key, value in proposal.items():
            trial.set_user_attr(key, value)
        if proposal["status"] != "PROPOSED":
            self.study.tell(trial, state=state.FAIL)
            self.live_trials.pop(trial.number, None)
        return proposal

    def tell(self, proposal, score, artifact_path):
        if proposal.get("status") != "PROPOSED" or not isinstance(artifact_path, str) or not artifact_path:
            raise ValueError("requires physical proposal and retained artifact identity")
        trial = next(t for t in self.study.trials if t.number == proposal["optuna_trial"])
        if trial.state != self.optuna.trial.TrialState.RUNNING or trial.user_attrs.get("candidate_id") != proposal.get("candidate_id"):
            raise ValueError("stale/foreign/already finalized trial")
        if (proposal.get("parameter_overrides") != trial.user_attrs.get("parameter_overrides")
                or validate_parameters(proposal["parameter_overrides"], self.registry) != proposal["candidate_id"]):
            raise ValueError("proposal values changed after canonical identity was archived")
        disposition = score.get("disposition")
        if disposition not in {"COMPLETE", "REJECT_CANDIDATE", "STOP_STUDY"} or type(score.get("eligible")) is not bool or score["eligible"] != (disposition == "COMPLETE"):
            raise ValueError("inconsistent score disposition")
        # Public Trial API attaches evidence before terminal state; values on
        # failed trials remain None, never a fake physical worst-case distance.
        live = self.live_trials.get(trial.number)
        if live is None:
            raise ValueError("unresolved trial must be audited; cannot adopt a foreign worker")
        live.set_user_attr("artifact_path", artifact_path)
        live.set_user_attr("score", score)
        if score.get("eligible") is True:
            values = score.get("values")
            if not isinstance(values, list) or len(values) != 2 or not all(finite_number(v) for v in values):
                raise ValueError("invalid eligible objectives")
            self.study.tell(live, values=values)
        else:
            self.study.tell(live, state=self.optuna.trial.TrialState.FAIL)
        if disposition == "STOP_STUDY":
            self.study.set_user_attr("global_stop", {"trial": trial.number, "reasons": score.get("reasons", [])})
        self.live_trials.pop(trial.number)
