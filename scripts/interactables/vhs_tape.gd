# scripts/interactables/vhs_tape.gd
extends Area3D

@export var tape_id: int = 0

func interact(player):
    GameStateManager.collect_tape(tape_id)
    DialogSystem.play_tape(tape_id, global_position)
    queue_free()
