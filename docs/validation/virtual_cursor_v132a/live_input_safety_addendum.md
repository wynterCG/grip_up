# Additional existing LIVE input regression checks

Before handoff, run the five existing input regression suites at120/60Hz (10 original safety processes): drag_input, contextual_input, independent_input, distant_input, capture_input. These are LIVE-path regressions required by the changed router, not V0 replay, new negatives or renewed qualification. They cannot fill any stopped V0 matrix cell. No tuning changes or retries are planned; preserve every receipt. The existing884 physics/locomotion checks remain separately recorded.

Results are recorded in `virtual_cursor_live_input/attempt_001/results.json`. This supplement is later than the initial report assembly; it does not change the NO_GO_INPUT_REPLAY decision.

Resultado: **10/10 processos,262 checks,0 falhas**, a120/60Hz. Somados aos884 checks anteriores:1146 checks de regressão. Os recibos raw e hashes constam do manifest final. Perda de foco e release normais passaram; V0-M/F e abort virtual continuam não medidos.
