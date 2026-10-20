"""Small, strict file/provenance helpers for the offline research process."""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
from datetime import datetime, timezone

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from project_config import DEST, ENGINE  # noqa: E402


def canonical(value) -> bytes:
    return json.dumps(value, sort_keys=True, separators=(",", ":"), allow_nan=False).encode("utf-8")


def digest(value) -> str:
    return hashlib.sha256(canonical(value)).hexdigest()


def file_hash(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read_json(path: Path):
    def reject(value):
        raise ValueError(f"nonfinite JSON constant: {value}")

    return json.loads(path.read_text(encoding="utf-8-sig"), parse_constant=reject)


def atomic_json(path: Path, value) -> None:
    """Only publish complete JSON. A result is never edited after publication."""
    payload = json.dumps(value, indent=2, sort_keys=True, allow_nan=False) + "\n"
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(path.name + f".{os.getpid()}.tmp")
    with temporary.open("x", encoding="utf-8", newline="\n") as handle:
        handle.write(payload)
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(temporary, path)


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def git_identity(repository: Path = DEST) -> dict:
    command = ["git", "-c", f"safe.directory={repository.resolve().as_posix()}", "-C", str(repository)]
    commit = subprocess.check_output([*command, "rev-parse", "HEAD"], text=True).strip()
    dirty = subprocess.check_output([*command, "status", "--porcelain"], text=True)
    return {"repository_commit": commit, "repository_dirty": bool(dirty.strip())}


def source_hashes(project: Path = ROOT, *, include_holdout=False) -> dict[str, str]:
    """Training never opens withheld definitions or outcomes, including for hashing."""
    paths = [project / "project.godot"]
    for base in (project / "features", project / "tools" / "auto_tuning"):
        for path in base.rglob("*"):
            relative = path.relative_to(project)
            if any(part in {".venv", "__pycache__", "studies"} for part in relative.parts):
                continue
            if relative.parts[:2] == ("tools", "auto_tuning") and "tests" in relative.parts:
                continue
            if not include_holdout and ("holdout" in relative.parts or "holdout" in path.name.lower()):
                continue
            if path.suffix in {".gd", ".tscn", ".tres", ".json", ".py", ".toml", ".lock"}:
                if path.name != "build_identity.json":
                    paths.append(path)
    paths += [project / "tools" / "project_config.py"]
    return {path.relative_to(project).as_posix(): file_hash(path) for path in sorted(set(paths)) if path.is_file()}


def engine_identity(engine: Path = ENGINE) -> dict:
    result = subprocess.run([str(engine), "--version"], capture_output=True, text=True, timeout=20, check=True)
    return {"version": result.stdout.strip(), "sha256": file_hash(engine)}


class StudyLock:
    """Single process even when two independent CLIs target the same study."""
    def __init__(self, directory: Path):
        directory.mkdir(parents=True, exist_ok=True)
        self.path = directory / "worker.lock"

    def __enter__(self):
        try:
            self.fd = os.open(self.path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
        except FileExistsError as exc:
            raise RuntimeError(f"study locked: {self.path}; inspect recorded PID before removing a stale lock") from exc
        os.write(self.fd, canonical({"pid": os.getpid(), "started": utc_now()}))
        return self

    def __exit__(self, *_):
        os.close(self.fd)
        self.path.unlink()
