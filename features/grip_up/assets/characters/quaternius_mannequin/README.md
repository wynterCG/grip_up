# Quaternius biped mannequin

Selected for GRIP UP as a clearly articulated biped candidate. Original GLB is unmodified, self-contained, with one skinned mesh, 65 joints and 43 animation clips.

Open `res://features/grip_up/scenes/biped_preview.tscn` and run current scene (F6). Middle mouse orbits; wheel zooms; the selector changes animation. Godot imports `_Loop` clips as looping animations and removes that suffix.

Validation: 12 Godot rig/import/animation checks passed, followed by an MCP Pro rendered preview with zero editor errors. Both arms have upperarm/lowerarm/hand chains; both legs have thigh/calf/foot chains; hands include finger bones.

The mannequin is now integrated through `biped_visual.gd`: render-only arm/leg IK, measured shoulder/palm calibration, authored Idle/Walk on the ground, passive coordinated legs while suspended and optional physical-foot targets. The player remains one physics body; this asset is not a ragdoll. Animation never drives the torso or its grip targets. The original asset-selection validation above is historical; current integration checks are recorded in the project validation reports.

Creator: Quaternius. Source: https://quaternius.com/packs/universalanimationlibrary.html . Free Standard archive: https://quaternius.itch.io/universal-animation-library . License CC0-1.0; see License.txt and provenance.json.
