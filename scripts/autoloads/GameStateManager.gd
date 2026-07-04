# autoloads/GameStateManager.gd
extends Node

signal state_changed(new_state: GameState)
signal tape_collected(tape_id: int)
signal enemy_spawned
signal all_tapes_collected

enum GameState {
    EXPLORING,      # Исследование
    READING,        # Просмотр кассеты / записки
    COMBAT,         # Боевой контакт
    DEAD,
    WIN,
    SPECTATOR
}

var current_state: GameState = GameState.EXPLORING
var tapes_found: Array[int] = []         # [0, 1, 2] — ID найденных кассет
var exit_code_known: bool = false
var cerberus_spawned: bool = false
var current_floor: int = 4
var entered_from_outer_door: bool = false
var entered_from_stairs: bool = false
var stair_spawn_position: Vector3 = Vector3.ZERO
var stair_spawn_rotation: Vector3 = Vector3.ZERO

func change_state(new_state: GameState) -> void:
    current_state = new_state
    state_changed.emit(new_state)

func collect_tape(tape_id: int) -> void:
    if tape_id not in tapes_found:
        tapes_found.append(tape_id)
        tape_collected.emit(tape_id)
        # Кассета #3 даёт код выхода
        if tape_id == 2:
            exit_code_known = true
        # После сбора 3 кассет
        if tapes_found.size() == 3:
            all_tapes_collected.emit()
            if not cerberus_spawned:
                cerberus_spawned = true
                enemy_spawned.emit()

func reset_floor(new_floor: int) -> void:
    current_floor = new_floor
    tapes_found.clear()
    cerberus_spawned = false
    exit_code_known = false
    current_state = GameState.EXPLORING
