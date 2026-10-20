"""Independent repeat/archive adapter. Runs unchanged v11 fixtures, no gameplay writes.

python features/locomotion_test_suite/tests/study_v12.py --repeats 3
Reports body-origin metrics defined by the original fixtures, not invented COM.
"""
import argparse
import hashlib
import json
import statistics
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
ENGINE = Path(r"C:\Users\Wynter\WrapRush\tools\godot.exe")
ARCHIVE = ROOT / "docs/validation/v12/physics"


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def capture(command, timeout=180):
    startup = subprocess.STARTUPINFO()
    startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
    result = subprocess.run(command, capture_output=True, timeout=timeout, startupinfo=startup)
    return result.returncode, (result.stdout + result.stderr).decode("utf-8", errors="replace")


def distribution(values):
    return {"n": len(values), "values": values, "mean": statistics.mean(values),
            "min": min(values), "max": max(values), "range": max(values)-min(values),
            "sample_sd": statistics.stdev(values) if len(values)>1 else None}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repeats", type=int, default=3)
    args = parser.parse_args()
    if not 2 <= args.repeats <= 10:
        parser.error("repeat count must be 2..10")
    ARCHIVE.mkdir(parents=True, exist_ok=True)
    index = 1
    while (ARCHIVE / f"study_{index:03d}").exists():
        index += 1
    destination = ARCHIVE / f"study_{index:03d}"
    destination.mkdir()
    watched = ["features/grip_up/scripts/climbing_controller.gd", "features/grip_up/scripts/intent_locomotion_coordinator.gd", "features/grip_up/scripts/constraint_aware_allocation.gd", "features/grip_up/scripts/foot_contact_solver.gd", "features/grip_up/scripts/foothold_candidate_sampler.gd", "features/grip_up/resources/climbing_tuning.gd", "features/grip_up/resources/biped_tuning.gd", "features/grip_up/resources/foot_tuning.gd", "features/grip_up/tests/test_locomotion_allocation.gd", "features/grip_up/tests/test_intent_feet.gd", "project.godot"]
    before = {name: sha(ROOT/name) for name in watched}
    runs = []
    for hz in (120, 60):
        for repeat in range(1, args.repeats+1):
            for suite, basename, footer in [("test_locomotion_allocation", "locomotion_allocation", "LOCOMOTION ALLOCATION RESULTS"), ("test_intent_feet", "intent_feet", "INTENT FEET RESULTS")]:
                command = [str(ENGINE), "--headless", "--path", str(ROOT), "--fixed-fps", str(hz), "--script", f"res://features/grip_up/tests/{suite}.gd", "--quit-after", "15000"]
                if hz == 60:
                    command += ["--", "--60hz"]
                code, console = capture(command)
                stem = f"{basename}_{hz}hz_repeat{repeat}"
                (destination/f"{stem}.txt").write_text(console, encoding="utf-8")
                raw = ROOT/f"builds/{basename}_{hz}hz.json"
                report = json.loads(raw.read_text(encoding="utf-8-sig"))
                (destination/f"{stem}.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
                valid = code == 0 and report["failures"] == 0 and footer in console and "SCRIPT ERROR" not in console
                runs.append({"hz": hz, "repeat": repeat, "suite": suite, "valid": valid, "exit_code": code, "checks": report["checks"], "report": report, "command": command})
                print(stem, "VALID" if valid else "INVALID", flush=True)
    after = {name: sha(ROOT/name) for name in watched}
    grouped = {}
    for hz in (120, 60):
        allocations = [r["report"] for r in runs if r["hz"] == hz and r["suite"] == "test_locomotion_allocation" and r["valid"]]
        feet = [r["report"] for r in runs if r["hz"] == hz and r["suite"] == "test_intent_feet" and r["valid"]]
        comparisons = {}
        for kind in ("asymmetric", "asymmetric_diagonal"):
            selected = [next(c for c in report["comparisons"] if c["kind"] == kind) for report in allocations]
            comparisons[kind] = {key: distribution([c[key] for c in selected]) for key in ("a0_useful", "a1_useful", "a0_twist", "a1_twist")}
            comparisons[kind]["paired_progress_delta"] = distribution([c["a1_useful"]-c["a0_useful"] for c in selected])
            comparisons[kind]["paired_twist_delta"] = distribution([c["a1_twist"]-c["a0_twist"] for c in selected])
        comparisons["step"] = {key: distribution([c["step_comparison"][key] for c in feet]) for key in ("B0_rise", "B1_rise", "B2_rise", "B1_hand_integral", "B2_hand_integral", "B1_work", "B2_work")}
        comparisons["step"]["paired_B2_B1_progress_delta"] = distribution([c["step_comparison"]["B2_rise"]-c["step_comparison"]["B1_rise"] for c in feet])
        grouped[str(hz)] = comparisons
    manifest = {"source": "scripted_repeated_existing_fixtures", "schema": "v12_physics_study_1", "engine_sha256": sha(ENGINE), "source_hashes_before": before, "source_hashes_after": after, "sources_unchanged": before==after, "runs": [{k:v for k,v in r.items() if k!="report"} for r in runs], "comparisons": grouped, "decision": {"A1":"REVISE_known_regressions_preserved", "B2":"INCONCLUSIVE_global_locomotion_benefit_not_demonstrated", "default_promotion":False}, "limitations":["Three repeats of one initial state are repeatability evidence, not participant/seed diversity.","Legacy body-origin projection/twist definitions are preserved, not silently relabelled COM or v12 metrics.","No human sessions or force/geometry tuning."]}
    (destination/"summary.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    print(destination)
    raise SystemExit(0 if before==after and all(r["valid"] for r in runs) else 1)


if __name__ == "__main__":
    main()
