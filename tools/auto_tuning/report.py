"""Portable tables, worst cases and a Pareto figure from archived raw trials."""
from __future__ import annotations

import argparse
from collections import Counter
import csv
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

from aggregate import summarize
from common import atomic_json, read_json
from scoring import AXES, nondominated


def report(study: Path, output: Path):
    output.mkdir(parents=True, exist_ok=True)
    state = read_json(study / "study_state.json")
    manifest = read_json(study / "study_manifest.json")
    records = []
    for row in state["baseline"]:
        records.append({**row, "phase": "baseline"})
    records += state["trials"]
    for row in state["trials"]:
        if row.get("regression_confirmation"):
            records.append({**row["regression_confirmation"], "phase": "regression_confirmation"})
    outcomes = [(row, read_json(study / row["path"] / "result.json")) for row in records]
    status_counts = Counter(result["status"] for _, result in outcomes)
    with (output / "trials.csv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["trial_id", "candidate_id", "phase", "status", "reason", "elapsed_wall_s", *AXES, "practical_screening_gain", "artifact_path"])
        for row, result in outcomes:
            score = row.get("score") or {}
            writer.writerow([row["trial_id"], row["candidate_id"], row["phase"], result["status"], result["reason"], result["elapsed_wall_s"],
                             *(score.get("values") or [None] * 4), score.get("meaningful_screening_gain"), row["path"]])
    with (output / "scenario_metrics.csv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(["trial_id", "candidate_id", "phase", "scenario", "revision", "physics_hz", "task_completed", "metric", "value", "scope"])
        for record, outcome in outcomes:
            engine = outcome.get("engine_result") or {}
            for row in engine.get("scenarios", []):
                for metric, value in row.get("metrics", {}).items():
                    if value is None or type(value) in (int, float, bool):
                        writer.writerow([record["trial_id"], record["candidate_id"], record["phase"], row["id"], row["revision"],
                                         engine.get("environment", {}).get("physics_hz"), row["completed"], metric, value, row.get("scope")])
    baseline_outcomes = [result for row, result in outcomes if row["phase"] == "baseline"]
    grouped = {"baseline": summarize(baseline_outcomes), "all_candidate_outcomes": summarize([result for row, result in outcomes if row["phase"] != "baseline"])}
    archive = nondominated(state["trials"])
    atomic_json(output / "summary.json", {"study_status": state["status"], "stop_reason": state.get("stopped"),
                                          "requested_candidate_budget": manifest["identity"]["config"]["random_trials"] + manifest["identity"]["config"]["tpe_trials"],
                                          "actual_candidate_trials": len(state["trials"]), "status_counts": dict(status_counts),
                                          "distributions": grouped, "pareto": archive,
                                          "human_sessions": 0, "promotion": False, "holdout_accessed": False})
    fig, axes = plt.subplots(1, 2, figsize=(12, 5), constrained_layout=True)
    feasible = [row for row in state["trials"] if row.get("score") and row["status"] == "completed"]
    for ax, (x, y) in zip(axes, ((0, 1), (2, 3))):
        ax.axhline(0, color="#777", lw=.8)
        ax.axvline(0, color="#777", lw=.8)
        ax.scatter([0], [0], marker="*", s=130, color="#222", label="A0 baseline")
        if feasible:
            ax.scatter([row["score"]["values"][x] for row in feasible], [row["score"]["values"][y] for row in feasible],
                       color="#4586a0", alpha=.5, label="valid candidate")
        if archive:
            ax.scatter([row["score"]["values"][x] for row in archive], [row["score"]["values"][y] for row in archive],
                       facecolors="none", edgecolors="#d46c35", s=100, label="Pareto (train)")
        ax.set_xlabel(AXES[x] + " (baseline-scaled worst-cell gain)")
        ax.set_ylabel(AXES[y] + " (baseline-scaled worst-cell gain)")
        ax.grid(alpha=.2)
        ax.legend(fontsize=8)
    fig.suptitle("GRIP UP Stage 1 — technical screening, no human preference claim")
    fig.savefig(output / "pareto.png", dpi=160)
    fig.savefig(output / "pareto.svg")
    plt.close(fig)
    lines = ["# Auto-tuning technical comparison", "", f"Study status: **{state['status']}**. {state.get('stopped') or ''}", "",
             f"Candidate trials: {len(state['trials'])}; baseline repeats: {len(state['baseline'])}. All archived evaluation statuses: `{dict(status_counts)}`.", "",
             "No candidate is promoted. Human A/B sessions: **0**. The screen cannot establish preferred game feel or global optimality.", "",
             "![Four objective Pareto projections](pareto.png)", "", "## Pareto archive (training only)", "",
             "| Candidate | Progress | Precision | Physical quality | Reliability | Practical screening gain |", "|---|---:|---:|---:|---:|---|"]
    for row in archive:
        lines.append("| " + " | ".join([row["candidate_id"][:12], *(f"{value:.4f}" for value in row["score"]["values"]), str(row["score"]["meaningful_screening_gain"])]) + " |")
    if not archive:
        lines.append("| None | — | — | — | — | No eligible candidate |")
    lines += ["", "## Baseline distributions", "", "The CSV retains every raw scenario metric and each failed task. Null means unavailable; it is not a zero or successful completion.", "",
              "| Scenario | Completed / attempts | Useful progress mean ± sample SD (m) | Worst (m) |", "|---|---:|---:|---:|"]
    for row in grouped["baseline"]["scenarios"]:
        metric = row["metrics"].get("useful_displacement_m", {})
        mean, sd, worst = metric.get("mean"), metric.get("stdev"), metric.get("min")
        lines.append(f"| {row['scenario']} | {row['completed_tasks']} / {row['attempts']} | {mean!s} ± {sd!s} | {worst!s} |")
    lines += ["", "## Interpretation limits", "",
              "Objectives are predeclared screening gains scaled by practical floors and measured baseline variability. They are not a validated utility function for fun. Axial twist is evaluated on directed tasks; useful swing has its own phase/work/retention measure. Runtime and safety failures receive no objective value.", "",
              "A negative pilot means no supported gain under this particular screen and budget. It does not prove that A0 is globally optimal. Held-out evidence is evaluated separately only after a repeated-valid shortlist is frozen. The main project report records native playback, regression coverage and the human review gate.", ""]
    (output / "report.md").write_text("\n".join(lines), encoding="utf-8")
    return output / "report.md"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--study", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    print(report(args.study, args.output))


if __name__ == "__main__":
    main()
