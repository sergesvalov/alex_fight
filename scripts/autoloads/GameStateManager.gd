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
var cerberus_spawned: bool = false

# Cached by hotel_level_generator.gd's _move_player() the one time it computes floor 4's own
# spawn spot (next to Cassette #1's wardrobe) - stairs_fall_catcher.gd reads this to rescue a
# player who fell through a stairwell shaft instead of recomputing the same wardrobe lookup.
var floor4_spawn_position: Vector3 = Vector3.ZERO

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
            # Not a plain clear(): a collected tape is gone from the level for good, so coming
            # back to a floor has to pick its count up where it was left. Floor 3 needs this to
            # be completable at all - its tapes sit on both sides of corridor_barrier.gd, and the
            # only way from the south half to the north one is a detour through floor 4.
            tapes_found.clear()
            for entry in collected_tapes:
                if entry["floor"] == value:
                    tapes_found.append(entry["id"])
            cerberus_spawned = false
            _emit_tape_count()
            # Reactive line for the first time floor 3 is actually reached, regardless of how
            # (secret door, stairs, elevator once unlocked) - distinct from "secret_portal"
            # (fired the moment the door is stepped through, if that's how they got here) since
            # this is specifically about the destination, not the act of crossing. Same
            # at-most-once guard as every other trigger_alex_line() call (_alex_lines_fired).
            if value == 3:
                DialogSystem.trigger_alex_line("floor3_arrival")
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

# The lift's service code, on a plate in the machine room on the roof (roof_code_plate.gd). Reading
# it sets lobby_unlocked, which is the only thing that ever opens floor 1 - unlock_floor()
# refuses anything below MIN_UNLOCKABLE_FLOOR, so floor 1 can never join the range by accident.
var lift_code: String = "%04d" % (randi() % 10000)

# What the level is built from: the generator seeds the random generator with this before
# placing anything, so the same seed always gives the same hotel - where the tapes lie, which
# rooms the floor 5 and floor 8 traps single out - and the same lift code. SaveManager stores it;
# a new game rolls a new one.
var world_seed: int = randi():
    set(value):
        world_seed = value
        lift_code = "%04d" % (absi(hash(value)) % 10000)

# Which physical cassettes have been taken, as [floor, tape_id] - the generator removes them
# again after rebuilding a saved game's level. (collected_tapes cannot say: it records which
# RECORDING each one turned out to be, and that depends on the order of finding.)
var taken_cassettes: Array = []
var lobby_unlocked: bool = false

# The lobby (floor 1, lobby_parts.gd): whether the second lift - the one that goes
# underground - has taken the code.
var lower_lift_called: bool = false

# The laboratory under the lobby (hotel_level_generator.gd::_build_lab()): whether the player
# has been down there (opens the lab's documents on its terminal), and how many of the three
# consoles around the installation are off - 1: lobby turrets, 2: outside line, 3: the
# installation itself, after which the lobby's main entrance is the way out.
var lab_reached: bool = false
var lab_consoles_off: int = 0

func is_floor_unlocked(floor_num: int) -> bool:
    if floor_num == 1:
        return lobby_unlocked
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

# Separate from the secret door above (that one stays untouched, still leads to floor 3) - floor
# 4's own main corridor is split in half by a permanent physical barrier (corridor_barrier.gd)
# that keeps the elevator/North Stairs off-limits until floor 3's own 3 tapes are collected. Set
# true (never reset) the instant that happens - see hotel_level_generator.gd's
# _on_all_tapes_collected(). Moved from floor 4 to floor 3 (2026-08-23, corrected per user report):
# floor 4 (the starting floor) is meant to be fully open with no corridor gating at all - the
# "endless corridor" nightmare belongs to floor 3 (reached via the secret door), not the start.
var floor3_corridor_unlocked: bool = false

# Floor 5's own nightmare (room_shuffle_trap.gd - walk into one room, end up in another). Set
# true, never reset, the moment floor 5's 3 tapes are collected - which also unlocks floor 6.
var floor5_rooms_unlocked: bool = false

# Floor 6's own nightmare (sleeper_cerberus.gd - blind robots that wake to sound and put a caught
# player back by the elevator). Set true, never reset, the moment floor 6's 3 tapes are
# collected - which also unlocks floor 7.
var floor6_sleepers_off: bool = false

# Floor 7's own nightmare (blackout_trap.gd - the lights go out and whoever moves in the dark is
# put back by the elevator). Set true, never reset, the moment floor 7's 3 tapes are collected -
# which also unlocks floor 8.
var floor7_lights_steady: bool = false

# Floor 8's own nightmare (name_door_trap.gd - only the room with the hero's name lets him in).
# Set true the moment floor 8's 3 tapes are collected - which also unlocks floor 9.
var floor8_named: bool = false

# Floor 2 - the last floor of the story's route - replays "that night": floor 7's blackouts and
# floor 6's sleepers together. Set true the moment floor 2's 3 tapes are collected.
var floor2_done: bool = false

# Floor 9 (sweep_camera_trap.gd - bars of light sweeping the corridor) and floor 10
# (edge_wall_trap.gd - a wall creeping up the floor from its south end). Each is set true the
# moment that floor's 3 tapes are collected; floor 9's also unlocks floor 10, floor 10's the roof.
var floor9_cameras_off: bool = false
var floor10_edge_stopped: bool = false

func change_state(new_state: GameState) -> void:
    current_state = new_state
    state_changed.emit(new_state)

func add_to_inventory(floor_num: int, tape_id: int) -> void:
    for entry in collected_tapes:
        if entry["floor"] == floor_num and entry["id"] == tape_id:
            return # already have this one, don't duplicate
    collected_tapes.append({"floor": floor_num, "id": tape_id})

const TAPES_PER_FLOOR: int = 3

# The HUD counter ("1/3") shows the CURRENT floor's tapes - it has to follow tapes_found, both
# when one is picked up and when the floor changes. (It used to be a separate running total kept
# by the player node, which never reset and read "4/3" on the second floor.)
func _emit_tape_count() -> void:
    EventBus.tapes_collected_updated.emit(tapes_found.size(), TAPES_PER_FLOOR)

func collect_tape(tape_id: int) -> void:
    if tape_id not in tapes_found:
        tapes_found.append(tape_id)
        tape_collected.emit(tape_id)
        _emit_tape_count()
        # После сбора 3 кассет
        if tapes_found.size() == TAPES_PER_FLOOR:
            all_tapes_collected.emit()
            if not cerberus_spawned:
                cerberus_spawned = true
                enemy_spawned.emit()
