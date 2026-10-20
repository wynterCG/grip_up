# GRIP UP offline tuning lab

This is a local research tool. It proposes four bounded A0 planner values and
runs the existing Godot/Jolt controller. It does not train an autonomous climber,
run a cloud service, change game defaults, or add a Python gameplay dependency.

The physics-owned certified registry is
`features/auto_tuning_lab/resources/parameter_space.json`. Stage 1 tunes only
speed, input ramp, target rate and target acceleration; all authority, anatomy,
geometry, spring and damping settings stay fixed. Full candidates are quantized
to eight decimal places before application. Candidate identity hashes sorted
compact JSON with fixed-eight-decimal numbers and trailing zeros removed.

From the repository root, on Windows:

```powershell
uv sync --frozen --project tools/auto_tuning
uv run --frozen --project tools/auto_tuning python -m unittest discover -s tools/auto_tuning/tests -v

# The source and fixture contracts must be frozen before actual measurements.
uv run --frozen --project tools/auto_tuning python tools/auto_tuning/optimize.py --baseline-only
# Resume the same provenance: up to 12 random + 40 TPE proposals, subject to gates.
uv run --frozen --project tools/auto_tuning python tools/auto_tuning/optimize.py

uv run --frozen --project tools/auto_tuning python tools/auto_tuning/report.py --study builds/auto_tuning/stage1_r1 --output docs/validation/auto_tuning/reports/stage1_r1
uv run --frozen --project tools/auto_tuning python tools/auto_tuning/shortlist.py --study builds/auto_tuning/stage1_r1 --output builds/auto_tuning/stage1_r1/shortlist.json --top 5
# Only if a practical-gain shortlist exists:
uv run --frozen --project tools/auto_tuning python tools/auto_tuning/validate_candidates.py --shortlist builds/auto_tuning/stage1_r1/shortlist.json --output builds/auto_tuning/repeated_train_r1 --split train --repeats 3
# Holdout definitions are opened only after the repeated-train gate passes:
uv run --frozen --project tools/auto_tuning python tools/auto_tuning/validate_candidates.py --shortlist builds/auto_tuning/repeated_train_r1/validated_shortlist.json --output builds/auto_tuning/holdout_r1 --split holdout --repeats 3
# Local one-factor numerical evidence, separate from the optimizer history:
uv run --frozen --project tools/auto_tuning python tools/auto_tuning/sensitivity.py --study builds/auto_tuning/stage1_r1 --output builds/auto_tuning/sensitivity_r1 --repeats 2
# Explicit scripted replay on the first monitor, using a fresh matching manifest:
uv run --frozen --project tools/auto_tuning python tools/auto_tuning/replay_candidate.py --candidate builds/auto_tuning_smoke/baseline_candidate.json
```

All actual trials run sequentially, with explicit physics Hz and a unique UUID
directory. `manifest.json` and candidate JSON precede execution; stdout, stderr,
raw engine output and the validated final result remain together. A crash,
timeout, invalid candidate, unknown scenario, stale identity or logged script
error cannot receive an objective value. Failed task completion is recorded
separately from evaluator execution. The engine path comes from the shared
`tools/project_config.py`, with its existing environment override.

Each study stores SQLite history, baseline distributions, all candidate outcomes,
an append-only event log and the Pareto archive. Resume refuses changed code,
parameters, engine, registry, Python/Optuna version or study configuration.
`worker.lock` blocks another process. After an interrupted process, inspect its
PID and any child engine process before manually removing an abandoned lock.
Unfinished SQLite trials become explicit failures on the next valid resume.

Four objectives maximize worst-cell baseline-scaled gains in directed progress,
precision, physical quality and reliability. Scaling uses the largest of a
declared practical floor, ten percent of baseline magnitude and twice measured
baseline SD. This is a conservative pilot screen, not a universal fun score.
Unknown metrics remain null. Baseline must include a genuinely supported,
airborne swing measurement: the useful-swing scalar measures phase-correct
signed incremental work and retained support. We never minimize every rotation.
The lateral cell additionally requires two attached hands and no native ground
support at onset, qualified airborne support samples, and no ground contact or
ground motor authority during measurement. Landing and walking cannot earn
climbing-progress credit; raw contaminated motion remains archived but unranked.
An observed candidate landing or failed required-posture preparation with complete
actual-state evidence is an unscored physical task failure. It is confirmed once
with the same parameters, seed and policy; repeated essential support loss stops
the pilot. Missing qualification fields or COM data stop the logger gate directly.

The random pilot stops if it cannot demonstrate a practical Pareto screening
gain. TPE does not start merely to fill a requested trial count. Hard failures,
ambiguous telemetry, baseline noise and confirmed essential regressions also
stop the study. A negative result supports keeping the current controller under
this screen; it does not establish global optimality.

The adaptive sampler uses `n_startup_trials=0` because the preceding phase uses
an explicit `RandomSampler`. Otherwise rejected random proposals could cause
TPE to perform extra random startup draws while being mislabeled adaptive.

Training code never opens withheld definitions or results, including for source
hashing. The separate validation command requires an immutable public shortlist,
matching candidate IDs/values and matching frozen source/engine provenance.
Held-out fixtures are only opened after that gate. No scripted result establishes
human preference, and no finalist is automatically promoted.

Python 3.13.13, Optuna 5.0.0 and Matplotlib 3.10.8 are locked locally. The installed
multi-objective/SQLite/Random/TPE APIs are exercised by synthetic contract tests;
those tables are not gameplay evidence. We use the documented
[multi-objective study API](https://optuna.readthedocs.io/en/stable/reference/generated/optuna.create_study.html)
and explicitly select
[TPESampler](https://optuna.readthedocs.io/en/stable/reference/samplers/generated/optuna.samplers.TPESampler.html).
Optuna 5 uses
[`Trial.set_constraint`](https://optuna.readthedocs.io/en/stable/reference/generated/optuna.trial.Trial.html#optuna.trial.Trial.set_constraint);
the older `constraints_func` argument is deprecated. Failed hard gates remain
failed trials with no score, even though samplers exclude failed observations
from performance-model fitting; the external safety stop and audit preserve them.
