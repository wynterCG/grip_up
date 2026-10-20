"""Visible, real-time scripted replay on monitor 1, with the same audited runner."""
import argparse
from pathlib import Path

from common import ROOT, read_json
from run_trial import run_trial


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=ROOT / "builds/auto_tuning/native_replays")
    parser.add_argument("--shortlist", type=Path)
    args = parser.parse_args()
    result, directory = run_trial(read_json(args.candidate), args.output, shortlist_path=args.shortlist, visible=True)
    print(result["status"], directory)
    raise SystemExit(0 if result["status"] == "completed" else 1)


if __name__ == "__main__":
    main()
