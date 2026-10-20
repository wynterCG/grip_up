"""Per-scenario distributions; a catastrophic row is never hidden by an average."""
from __future__ import annotations

from collections import Counter, defaultdict
import statistics
from candidate_schema import finite_number


def distribution(values):
    values = [float(value) for value in values if finite_number(value)]
    if not values:
        return {"n": 0, "mean": None, "stdev": None, "min": None, "max": None, "range": None}
    return {"n": len(values), "mean": statistics.mean(values), "stdev": statistics.stdev(values) if len(values) > 1 else None,
            "min": min(values), "max": max(values), "range": max(values) - min(values)}


def summarize(outcomes):
    statuses = Counter(result["status"] for result in outcomes)
    cells = defaultdict(list)
    for outcome in outcomes:
        result = outcome.get("engine_result") or {}
        hz = result.get("environment", {}).get("physics_hz")
        for row in result.get("scenarios", []):
            cells[(row["id"], hz)].append(row)
    rows = []
    for (scenario, hz), samples in sorted(cells.items()):
        keys = sorted({key for sample in samples for key in sample.get("metrics", {})})
        rows.append({"scenario": scenario, "physics_hz": hz, "attempts": len(samples),
                     "completed_tasks": sum(sample.get("completed") is True for sample in samples),
                     "task_failures": sum(sample.get("completed") is False for sample in samples),
                     "metrics": {key: distribution([sample.get("metrics", {}).get(key) for sample in samples]) for key in keys}})
    return {"status_counts": dict(statuses), "scenarios": rows}
