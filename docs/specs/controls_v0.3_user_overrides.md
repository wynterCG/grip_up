# User overrides to the supplied v0.3 specification

The supplied specification is archived with trailing whitespace normalized in `grip_up_controls_v0.3.md`.
Two subsequent user instructions take precedence:

1. Start the playable prototype in profile 1. The user reported that arm
   extension still used W/S because the application initially selected profile 0.
   Preserve profile 0 as an explicit comparison option.
2. Invert vertical arm drag. **Mouse up contracts; mouse down extends.** The
   user wants aiming higher for the second grip to accompany pulling upward,
   without having to first move the cursor below the target.

The final mapping is `target_delta = screen_delta_y * positive_sensitivity`.
It retains the specification's deliberate coupling: the attached supporting
arm responds while the other hand is being aimed or is still reaching.
There is no aiming freeze, clutch, added impulse or strength increase.

Starting in profile 1 is the user's requested test configuration. It does not
mean that the specification's long-session feel hypothesis has been validated.
