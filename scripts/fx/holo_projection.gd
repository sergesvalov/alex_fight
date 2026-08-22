# scripts/fx/holo_projection.gd
# Purely atmospheric now - a small flicker of light near the tape being played. The actual
# readable text moved to a screen-space subtitle (hud.gd, driven by DialogSystem.narrative_started)
# so it no longer needs to carry a Label3D: reading a floating world-space label meant tilting the
# camera up at whatever angle the pickup spot happened to leave the hologram at, up to and
# including straight into the ceiling in low rooms.
extends Node3D

var data = {}

func set_tape_data(tape_data: Dictionary) -> void:
    data = tape_data
