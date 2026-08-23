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
var tapes_found: Array[int] = []         # [0, 1, 2] — ID найденных кассет на ТЕКУЩЕМ этаже,
                                          # сбрасывается автоматически сеттером current_floor ниже
                                          # при переходе на новый этаж/виток
var collected_tapes: Array[Dictionary] = []  # [{"floor": 4, "id": 0}, ...] — постоянный инвентарь
                                              # всех когда-либо найденных кассет, НЕ сбрасывается
var exit_code_known: bool = false
var cerberus_spawned: bool = false

# Setter fires on every genuine floor change (stairs_gate.gd, elevator_controller.gd, or the
# generator's own initial assignment) - centralizing the "entering a floor resets ITS OWN
# objective progress" reset here means every writer of current_floor gets this for free, instead
# of each call site needing to remember to call some separate reset function (the previous
# reset_floor() helper had exactly one caller, the now-deleted legacy exit_door.gd, and nothing
# else ever called it - so tapes_found silently never cleared between floors reached via stairs
# or the elevator).
var current_floor: int = 4:
    set(value):
        if value != current_floor:
            tapes_found.clear()
            cerberus_spawned = false
            exit_code_known = false
        current_floor = value

# ============================================================================
# FLOOR ACCESS (stairs only - the elevator is always open, see MECHANICS.md) - separate from
# current_floor tracking above. stairs_gate.gd only lets the player reach floors inside
# [unlocked_floor_min, unlocked_floor_max]; going further always bounces back to that range's
# edge, no matter how many tapes are collected on the floor they're currently on. The range only
# ever grows, one floor at a time, seeded by init_floor_access() at level start and expanded by
# unlock_floor() from genuine progression events (currently: stepping through the secret exit
# door - see hotel_level_generator.gd's _create_exit_portal()/secret_portal.gd). Floor 1
# (empty_box_mode) is never included.
# ============================================================================
const MIN_UNLOCKABLE_FLOOR: int = 2
var unlocked_floor_min: int = -1
var unlocked_floor_max: int = -1

func init_floor_access(start_floor: int) -> void:
    if unlocked_floor_min == -1:
        unlocked_floor_min = start_floor
        unlocked_floor_max = start_floor

func unlock_floor(floor_num: int) -> void:
    if floor_num < MIN_UNLOCKABLE_FLOOR:
        return
    unlocked_floor_min = min(unlocked_floor_min, floor_num)
    unlocked_floor_max = max(unlocked_floor_max, floor_num)

func is_floor_unlocked(floor_num: int) -> bool:
    return floor_num >= unlocked_floor_min and floor_num <= unlocked_floor_max

# The one-time secret exit door punched through a random room's OUTER wall once any floor's 3
# tapes are collected (see hotel_level_generator.gd::_create_exit_portal()). Persisted here (not
# just a local var in the generator) so _ready() can recreate the same door/portal in the same
# spot, leading to the same floor-3 room, if the level reloads after it's already been created.
var secret_portal_active: bool = false
var secret_portal_floor: int = 0        # which floor's outer wall got the doorway
var secret_portal_is_double: bool = false  # true = DoubleRoom (west wall), false = SingleRoom (east wall)
var secret_portal_room_num: int = 0     # room number on secret_portal_floor, for its Z position
var secret_portal_target: Vector3 = Vector3.ZERO  # fixed floor-3 destination, rolled once
var secret_portal_target_floor: int = 3

func change_state(new_state: GameState) -> void:
    current_state = new_state
    state_changed.emit(new_state)

func add_to_inventory(floor_num: int, tape_id: int) -> void:
    for entry in collected_tapes:
        if entry["floor"] == floor_num and entry["id"] == tape_id:
            return # already have this one, don't duplicate
    collected_tapes.append({"floor": floor_num, "id": tape_id})

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
