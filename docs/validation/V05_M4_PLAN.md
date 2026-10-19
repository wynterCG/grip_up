# v0.5 M4 ? implementation plan after M2/M3 gate

Reuse the existing GripCapturePredictor and held-only GripIntentBuffer rather
than a second capture engine. Existing predictor is read-only; existing finite
reach, actual shoulder sphere, contact/sweep/LOS checks and integrity remain
sole physical authority. No arm controller or momentum redesign is justified
by M1's exact OFF/ON equivalence and observed smooth catches.

Separate flags, defaultOFF: reach_prediction_enabled (advisory only) and
catch_buffer_enabled (reuse current bounded held intent,100?150ms configurable).
Legacy predictive comparisons remain recoverable. Buffer OFF never makes an
early out-of-range press sticky; releasing the button cancels pending/reaching.

An assessment wrapper should add a bounded future geometric interval, finite
hand arrival information, estimated relative velocity at contact, confidence
for translating/rotating supports and a clearly approximate catch-load warning.
Do not pretend a0.2s forecast predicts an entire0.3s reach: unavailable future
contact is unknown, not proof the valid current request must be rejected.
High support spin, unknown future contacts/joint forces and grounded contacts
must reduce confidence; forecast never authorizes physical attachment.

Display only a restrained developer classification: IN RANGE, PREDICTED CATCH
WINDOW, NEEDS SWING, OBSTRUCTED, UNSAFE CATCH (estimate), or unknown horizon.
A fast outward radial catch may have a load-risk estimate from effective point
mass and current stopping allowance; it is not an actual force or guarantee.
Actual pose/transit/retention event codes remain observed, independent facts.

Capture an immutable assessment on the intentional press, separately from
hover assessments; later pointer motion cannot rewrite the attempted target or
its forecast. On signal emission, include that attempt's assessment in JSONL,
not the newest hovered surface. No selected point is moved while button-held.

Tests: pointer/camera invariance, fixed/moving/rotating supports, confidence
limits, speeds/poses, early buffer OFF/ON, cancellation while held input/UI/focus
changes, real finite catch and retention, unchanged360N/20Nm/150Nm. Static
reference and separate swing route use identical geometry across variants.
Human comfort/agency and improved consistency must be evaluated separately.
