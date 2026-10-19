# Visible replay on monitor1

Requested by the player after the initial monitor2 validation. Both editor and
game are back on monitor1 (Godot screen index0), including future test launches.

Existing native primitive and integrated test helpers replayed at120/60Hz.
Short3-second pauses freeze the simulation at observed snapshots; actuator,
collision and acceptance rules are unchanged. This is an automatic visual
replay, not a human-controlled attempt or a rerun of all4032 headless checks.

54/54 native primitive and safety checks pass. Both low/high functional top-out
gates remain false at both frequencies. Editor reports0 errors/warnings.
The ordinary low-ledge experiment is left open at120Hz, fixture startOFF.
Historical monitor2 evidence is retained separately under ../native/.
