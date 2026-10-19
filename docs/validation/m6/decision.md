# M6 physical ledge transfer experiment

The designer played the v0.7.3 route and said "muito bom", then approved
continuing with mantle/top-out. This is an unscored human observation, not a
completed comparative M5 questionnaire.

The M6 experiment stays separate from the approved route and its startup
defaults. The acceptance gate is a collision-safe transfer onto an ordinary
platform, actual ground load, and an immediate return to walking. Holding a
ledge alone does not count as completion.

The current arms only transmit tension. The calves and sole are colliders on
the single torso rigid body. Testing must distinguish a planning defect from
missing physical capability; no body transform animation, hidden lift force,
collider removal or larger actuator budget may conceal the latter.

## Result: functional acceptance gate not met

Both 1.25 m and 2.10 m ordinary platforms were tested at 60/120 Hz, with
hands only and with physical feet. Neither configuration transferred to actual
top ground and walked away. The high edge does allow upward arm traction;
feet improve the achieved height, but cannot clear the fixed lower-body shape.

For the 2.10 m platform, a standing sole would require a torso origin near
3.017 m. The body remains around 1.3–1.5 m during the measured pull. A finite
lean inside the existing torque allowance does not bridge that geometry.
These observations are not a proof of impossibility for every possible swing
trajectory; they are sufficient to reject this implementation as a usable M6.

The experiment identifies an actual top on the gripped collider and checks a
standing destination for occupancy. **It does not certify the continuous body
path.** Intermediate collisions stay enabled. A 35 cm rear bearing check
rejects a narrow lip; an occupied destination also rejects the mantle request.
Neither diagnostic nor an edge attachment counts as a completed top-out.
Discovery currently starts from front-face grip normals. Pure top-face grips
are not classified by this candidate, another reason it is not a finished mantle.

## Next capability to investigate

The current hand actuator can pull but cannot support a palm pressing down on
the top. A legitimate compressive palm contact, with an actual surface normal,
friction limits and opposite reaction, is one missing capability to investigate.
The fixed calves and sole also need a physically valid way to tuck/clear the
lip; visual knee IK alone cannot change collision geometry. A minimally
articulated lower body is a candidate, not an implemented solution.

Keep this branch as an isolated feasibility experiment. Keep the approved
v0.7.3 course and old comparators intact. Do not promote this attempt into the
course, count safety checks as gameplay success, or proceed to M7 claiming
that the full walk–climb–top-out–walk loop is solved.
