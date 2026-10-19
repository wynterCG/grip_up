# Quaternius biped mannequin

Selected for GRIP UP as a clearly articulated biped candidate. Original GLB is unmodified, self-contained, with one skinned mesh, 65 joints and 43 animation clips.

Open `res://features/grip_up/scenes/biped_preview.tscn` and run current scene (F6). Middle mouse orbits; wheel zooms; the selector changes animation. Godot imports `_Loop` clips as looping animations and removes that suffix.

Validation: 12 Godot rig/import/animation checks passed, followed by an MCP Pro rendered preview with zero editor errors. Both arms have upperarm/lowerarm/hand chains; both legs have thigh/calf/foot chains; hands include finger bones.

This is the asset and preview, not a completed climbing integration. The existing rigid-body robot and force controller remain unchanged by this asset selection. Next work is a visual IK adapter for hand/foot targets, model scale and shoulder calibration. Root-motion animation must not move the physics torso.

Creator: Quaternius. Source: https://quaternius.com/packs/universalanimationlibrary.html . Free Standard archive: https://quaternius.itch.io/universal-animation-library . License CC0-1.0; see License.txt and provenance.json.
