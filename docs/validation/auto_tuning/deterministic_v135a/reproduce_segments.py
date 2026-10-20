"""Materialize derived segment bytes from frozen raw receipts; no engine/scorer.

Run with the campaign's pinned C:\\Users\\Wynter\\grip_up venv interpreter.
Existing metric receipts and raw inputs are never modified.
"""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT/"tools/auto_tuning"))
from common import read_json, file_hash, atomic_json
from metric_binary64 import require_environment, segment_payload, bits

B = ROOT/"builds/eval_virtual_cursor/minimal_v135a_r1"
source = read_json(B/"source_identity.json")
require_environment(source["python_environment"])
for directory in sorted((B/"attempts").iterdir()):
    path = directory/"metric_binary64_audit.json"
    if not path.exists():
        continue  # Catch-native metrics or the genuinely interrupted setup.
    audit = read_json(path)
    if audit["status"] != "MEASURED":
        continue
    window = audit["window"]
    raw = read_json(directory/"benchmark_audit.json")
    rows = [r for r in raw["ticks"] if window["first_tick"] <= r["tick"] <= window["last_tick"]]
    payload = segment_payload(rows, provenance=audit["provenance"])
    if payload["sequence_sha256"] != audit["sequence_sha256"] or bits(payload["value"]) != audit["recomputed_binary64_bits"]:
        raise ValueError("ARCHIVED_AUDIT_IDENTITY_CHANGED")
    destination = directory/"metric_binary64_segments.json"
    if destination.exists():
        if read_json(destination) != payload:
            raise ValueError("IMMUTABLE_SEGMENT_SIDECAR_CHANGED")
    else:
        atomic_json(destination, payload)
    print(directory.name, len(payload["segments"]), bits(payload["value"]))
