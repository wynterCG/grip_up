"""Bounded two-task orchestration. evaluate callback owns all engine launches.

No engine/API/holdout access here. Failed callbacks consume their reserved
pair. Crash windows are preserved and fail closed rather than silently replayed.
"""
from __future__ import annotations

import copy
from pathlib import Path

from .search import (Budget, PLAN, ProposalStudy, TRAIN_IDS, VERSION, baseline,
                     candidate_id, digest, pareto, project_score)
from common import atomic_json, read_json, utc_now


def _immutable(path, value):
    if path.exists():
        raise FileExistsError(f"immutable receipt exists: {path}")
    atomic_json(path, value)


def _select(frontier, baseline_id):
    eligible = [r for r in frontier if r["candidate_id"] != baseline_id
                and r.get("score", {}).get("practical_gain") is True]
    def key(record):
        gains = [cell["paired_difference_m"] / cell["practical_gain_floor_m"]
                 for cell in record["score"]["per_task"]]
        return (-min(gains), -max(gains), record["candidate_id"])
    return sorted(eligible, key=key)[:1]


def run(directory, identity, registry, gate, reference, quality_contract, evaluate, *, stop_after=None):
    """Run only after authentic root MB2 GO; callback gets params/phase/attemptid.

    Root must ensure each callback launches exactly the reserved two fresh
    120-Hz FIXED_TAPE processes (V and R) and retains all manifests/raw receipts.
    No engine executes in this module. Root decides no extra callback/retry
    beyond this plan. Confirmation reserve remains unspent here.
    """
    if gate.get("decision") != "GO_MINIMAL_BENCHMARK" or gate.get("identity_sha256") != digest(identity):
        raise ValueError("matching MB2 GO required before any study mutation")
    if not callable(evaluate):
        raise ValueError("evaluation callback required")
    if stop_after not in (None, "sensitivity", "random", "tpe"):
        raise ValueError("unknown phase boundary")
    baseline_score = project_score(reference, reference, quality_contract)
    if not baseline_score["eligible"]:
        raise ValueError("fresh baseline/reference/quality gate failed: " + "; ".join(baseline_score["reasons"]))
    directory = Path(directory)
    frozen = {"identity": identity, "registry_sha256": digest(registry),
              "reference_sha256": digest(reference), "quality_sha256": digest(quality_contract),
              "plan": PLAN, "version": VERSION, "train_ids": list(TRAIN_IDS),
              "processes_per_proposal": 2, "episodes_per_proposal": 2,
              "workers": 1, "max_processes": 40, "max_episodes": 160,
              "confirmation_launch_reserve": 4,
              "selection": "max minimum normalized practical paired gain, then maximum gain, then ascending canonical hash; at most one"}
    effective = {**copy.deepcopy(identity), "pilot_contract_sha256": digest(frozen)}
    effective_gate = {"decision": "GO_MINIMAL_BENCHMARK", "identity_sha256": digest(effective)}
    with ProposalStudy(directory, effective, registry, effective_gate) as proposals:
        manifest = directory / "pilot_manifest.json"
        if manifest.exists():
            if read_json(manifest) != frozen:
                raise ValueError("resume frozen pilot identity mismatch")
        else:
            _immutable(manifest, frozen)
        state_file = directory / "pilot_state.json"
        state = read_json(state_file) if state_file.exists() else {"status": "RUNNING", "records": [], "reservations": []}
        if len(proposals.study.trials) != len(state["records"]):
            raise ValueError("unresolved SQLite/physical receipt boundary; inspect preserved attempts")
        for record in state["records"]:
            receipt = directory / record["receipt"]
            if not receipt.exists() or digest(read_json(receipt)) != record["receipt_sha256"]:
                raise ValueError("missing/changed completed receipt on resume")
        if state["status"] != "RUNNING":
            report = read_json(directory / "pilot_report.json")
            if report["manifest_sha256"] != digest(frozen):
                raise ValueError("report identity changed")
            return report
        budget = Budget(state["reservations"])
        values = baseline(registry)
        a0 = {"candidate_id": candidate_id(values), "parameter_overrides": values,
              "role": "FRESH_A0_REFERENCE", "score": baseline_score}

        def finish(reason, global_stop=False):
            result = pareto(state["records"], a0)
            shortlist = [] if global_stop else _select(result["frontier"], a0["candidate_id"])
            report = {"status": "NO_GO_MINIMAL_BENCHMARK" if global_stop else "SHORTLIST_READY" if shortlist else "NO_ELIGIBLE_CANDIDATE",
                      "global_stop": global_stop, "reason": reason, "manifest_sha256": digest(frozen),
                      "proposal_count": len(state["records"]),
                      "process_launches_reserved": sum(r["processes"] for r in budget.reservations),
                      "training_episodes_reserved": sum(r["episodes"] for r in budget.reservations),
                      "reservations": budget.snapshot(), "records": state["records"],
                      "archive": result["archive"], "frontier": result["frontier"], "shortlist": shortlist,
                      "selection_rule": frozen["selection"], "holdout_accessed": False,
                      "human_sessions": 0, "product_promotion": "NONE",
                      "scope": "narrow fixed-tape120Hz pilot; repeats are not independent starts; no transfer or feel certification"}
            _immutable(directory / "pilot_report.json", report)
            state["status"] = report["status"]
            atomic_json(state_file, state)
            return report

        def phase_complete(phase):
            result = pareto(state["records"], a0)
            report = {"status": "PHASE_COMPLETE", "phase": phase,
                      "manifest_sha256": digest(frozen), "proposal_count": len(state["records"]),
                      "process_launches_reserved": sum(r["processes"] for r in budget.reservations),
                      "training_episodes_reserved": sum(r["episodes"] for r in budget.reservations),
                      "archive": result["archive"], "frontier": result["frontier"],
                      "shortlist": [], "holdout_accessed": False,
                      "scope": "intermediate phase only; root must audit before exact-identity resume"}
            target = directory / "phase_reports" / f"{phase}.json"
            if target.exists():
                if read_json(target) != report:
                    raise ValueError("phase receipt changed")
            else:
                _immutable(target, report)
            return report

        while True:
            index = len(state["records"])
            boundary = {"sensitivity": 8, "random": 14}.get(stop_after)
            if boundary is not None and index >= boundary:
                if index > boundary:
                    raise ValueError("study already advanced beyond requested phase")
                return phase_complete(stop_after)
            signal_records = [r for r in state["records"] if (r.get("score") or {}).get("eligible") is True]
            distinct_vectors = {tuple(r["score"]["values"]) for r in signal_records}
            tpe_ready = len(distinct_vectors) >= 3 and any(r["score"]["practical_gain"] for r in signal_records)
            if index >= 14 and not tpe_ready:
                return finish("FUTILITY: fewer than three distinct eligible vectors or no practical promising candidate after random")
            if index >= sum(PLAN.values()):
                return finish("bounded proposal plan complete")
            proposal = proposals.ask(tpe_ready=tpe_ready)
            if proposal is None:
                return finish("bounded proposal plan complete")
            attempt = f"mbq_{proposal['proposal_index']:03}_{proposal['phase']}"
            proposal = {**proposal, "attempt_id": attempt, "created_utc": utc_now()}
            _immutable(directory / "proposals" / f"{attempt}.json", proposal)
            record = copy.deepcopy(proposal)
            if proposal["status"] != "PROPOSED":
                record["score"] = None
            else:
                budget.reserve(attempt)
                reservation = {"attempt_id": attempt, "processes": 2, "episodes": 2,
                               "confirmation": False, "state": "RESERVED_BEFORE_CALLBACK"}
                _immutable(directory / "attempts" / f"{attempt}.json", reservation)
                state["reservations"] = budget.snapshot()
                atomic_json(state_file, state)
                try:
                    envelope = evaluate(copy.deepcopy(proposal["parameter_overrides"]), proposal["phase"], attempt)
                    score = project_score(envelope, reference, quality_contract)
                    _immutable(directory / "outcomes" / f"{attempt}.json", envelope)
                except Exception as exc:
                    score = {"eligible": False, "disposition": "STOP_STUDY", "values": None,
                             "reasons": [f"callback/infrastructure {type(exc).__name__}: {exc}"]}
                    _immutable(directory / "failures" / f"{attempt}.json", score)
                record["score"] = score
                proposals.tell(proposal, score, f"receipts/{attempt}.json")
            receipt_path = Path("receipts") / f"{attempt}.json"
            _immutable(directory / receipt_path, record)
            record["receipt"] = receipt_path.as_posix()
            record["receipt_sha256"] = digest(read_json(directory / receipt_path))
            state["records"].append(record)
            atomic_json(state_file, state)
            if record.get("score") and record["score"]["disposition"] == "STOP_STUDY":
                return finish("; ".join(record["score"]["reasons"]), global_stop=True)
