# Replay contract v132 r1

R0 replays immutable requested key holds, integer tick scheduling, mouse-motion
pixel coordinates/relative motion and button down/up events through `Input`.
The frozen source policy requests no camera orbit/dolly; those explicit zero
inputs are part of the tape contract. Unsupported nonzero camera controls fail
closed. R0 does not call the live world-point projection used by adaptive A.
The original follow camera still runs; camera/target divergence remains possible.

PRE at priority −100 samples before input emission. POST at +100 samples after
the ordinary controller callbacks. A and R0 share the v131 clock handshake,
world retirement, baseline Resource verification, snapshot reader, contact chain
and native safety monitor. Rate is confirmed with no world present before bodies
are constructed. No PRE/POST substitution or cross-Hz trajectory alignment.

The tape preserves every tick, held/release states, viewport cursor coordinates,
camera pose/ray and stable material target plus runtime collider/anchor IDs,
bindings, actual focus/owner/blocked gates, accepted logical and world intent,
hands/feet and native motion. Tape file SHA256 and canonical internal SHA256 are
separate; source manifest, trace, policy and code/engine/scenario identities link
the reference. The first reference is selected, never a best-scoring one.

`REQUESTED` is the emitted event chronology. `ACCEPTED` is the actual router
logical intent/holds/owner/block state. Focus is observed metadata: cancellation
must affect accepted holds rather than treating focus alone as solver input.
`EFFECTIVE_ACTION` includes actual world intent, selected material point, hand
state/rejection/contact. Forces are native response, not an input identity key.
Runtime IDs are retained and same-anchor retention checked within a run; stable
fixture IDs/poses identify corresponding bodies across processes.

Equal tape hash never asserts accepted identity. The comparator publishes both
accepted-stream hashes, logical matched prefix, effective matched prefix, first
request/router/target/grip/effective-direction mismatch and first native-state
difference. The localization epsilon is 1e-6 for physical fields and zero for
logical inputs. This is not a scoring tolerance or a physics-equivalence band.
After the first effective divergence only task robustness is interpretable.

Trace OFF retains compact per-tick audit and safety checks. Observer OFF disables
the original gameplay diagnostic observer; it does not disable the shared direct
reader or invariant monitor. No claim of uninstrumented simulation is made.

R1: `UNSUPPORTED_SEAM`. The audited normal route reads Input and normalizes/gates
inside the production router. No existing test injection seam was established
that could replace accepted intent without production modification. R0 suffices;
grip validation, body state and physical authority are never bypassed.
