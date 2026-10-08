# scripts/levels/blocks/wake_up_room.gd
# The wake-up room: the game's tutorial, with no text in it. The hero comes to in his own room on
# floor 4 with empty hands and the door to the corridor locked, and the room lets him out only
# once he has done everything the game is played with - in an order the room itself imposes:
#
#   turn      he wakes facing the bed and the wall behind it; everything else is behind him
#   walk      the only light is the strip under the bathroom door, across the room
#   interact  that door is the first thing that takes a press; the pistol lies behind it,
#             on the washbasin
#   tape      the cassette in the wardrobe by the way out (the generator's own Cassette_0) -
#             playing it brings the floor's robot to the door, which stays shut: a red glow under
#             it and steps outside are all there is of it
#   shoot     the lock on the door to the corridor (door_lock.gd) takes shots, nothing else
#   door      and then the door opens like every other door in the hotel
#
# Nothing here says what to press. If the player stops making progress, the next thing to deal
# with starts to pulse and tick - faintly after NUDGE_AFTER seconds, plainly by NUDGE_FULL.
# The tape is the one step that can be skipped: the lock gives way to shots with or without it.
#
# One instance, created by hotel_level_generator.gd::_add_wake_up_room() on a NEW game only -
# a continued one starts by the elevator with the room already open. It removes itself when the
# door opens (GameStateManager.wake_up_done). Parented to the floor, not the room: the starting
# room is a mirrored one (scale.z = -1), and lights and shapes are better off outside that.
extends Node3D

enum Stage { WC_DOOR, PISTOL, TAPE, LOCK, EXIT }

const NUDGE_AFTER: float = 25.0
const NUDGE_FULL: float = 60.0
const NUDGE_TICK_INTERVAL: float = 2.2
const NUDGE_COLOR := Color(1.0, 0.8, 0.5)
const ROBOT_GLOW_COLOR := Color(1.0, 0.1, 0.05)
const ROBOT_NEAR: float = 1.5   # a robot this close to the door (m) glows at full strength
const ROBOT_FAR: float = 6.5    # and from this far it does not show at all
const ROBOT_STEP_INTERVAL: float = 0.45

# Everything below is in the single room's own coordinates (single_room.tscn) - the starting
# room is always one of those (413: its wardrobe is the closest to the middle of the floor).
const WAKE_SPOT := Vector3(2.9, 0.0, 3.0)          # beside the bed
const WAKE_FACING := Vector3(0.0, 0.0, 1.0)        # the bed and the wall behind it
const WC_SLIT_POS := Vector3(-2.55, 0.015, 2.62)   # the room side of WCSouthWall, at the floor
const PISTOL_POS := Vector3(-2.31, 0.93, 0.45)     # on the washbasin (sink.tscn), facing its door
const DOOR_INSIDE_POS := Vector3(-3.2, 1.3, 3.5)   # in front of the door to the corridor
const DOOR_SLIT_POS := Vector3(-3.64, 0.015, 3.5)  # the room side of RoomWestWall, at the floor
const DOOR_OUTSIDE_POS := Vector3(-4.6, 0.0, 3.5)  # the corridor just outside it
const LOCK_ON_DOOR := Vector3(0.5, 1.3, -0.09)    # on the door's own body: room side, middle of the leaf

var room: Node3D = null   # set by the generator before add_child()
var stage: Stage = Stage.WC_DOOR

var _room_door: Node = null
var _wc_door: Node = null
var _lock: Node = null
var _pickup: Node = null
var _cassette: Node = null
var _main_light: Light3D = null
var _main_light_mesh: Node3D = null
var _main_light_energy: float = 0.0

var _wc_slit: MeshInstance3D = null
var _door_glow: OmniLight3D = null
var _door_slit_mat: StandardMaterial3D = null
var _nudge: OmniLight3D = null

var _stalled: float = 0.0
var _time: float = 0.0
var _tick_timer: float = 0.0
var _robot_glow: float = 0.0
var _robot_step_timer: float = 0.0

var _step_sound = preload("res://assets/audio/sfx/footstep.wav")

func _ready() -> void:
	_room_door = room.get_node("RoomDoor/AnimatableBody3D")
	_wc_door = room.get_node("WCDoor/AnimatableBody3D")
	_cassette = get_parent().get_node_or_null("Cassette_0")

	_room_door.locked = true
	_lock = StaticBody3D.new()
	_lock.name = "WakeUpLock"
	_lock.set_script(load("res://scripts/interactables/door_lock.gd"))
	_lock.position = LOCK_ON_DOOR
	_room_door.add_child(_lock)
	_room_door.rattled.connect(_lock.flash)

	_pickup = Area3D.new()
	_pickup.name = "PistolPickup"
	_pickup.set_script(load("res://scripts/interactables/pistol_pickup.gd"))
	_pickup.position = _at(PISTOL_POS)
	_pickup.taken.connect(_on_pistol_taken)
	add_child(_pickup)

	# The room's own ceiling light stays off until the pistol is in hand - light_energy, not
	# `visible`: the generator switches whole floors on and off through `visible`.
	_main_light = room.get_node_or_null("MainRoomLight")
	_main_light_mesh = room.get_node_or_null("MainRoomLightMesh")
	if _main_light:
		_main_light_energy = _main_light.light_energy
		_main_light.light_energy = 0.0
	if _main_light_mesh:
		_main_light_mesh.visible = false

	_wc_slit = _make_slit(_at(WC_SLIT_POS), Vector3(0.9, 0.02, 0.02), Color(1.0, 0.95, 0.8), 3.0)
	var door_slit := _make_slit(_at(DOOR_SLIT_POS), Vector3(0.02, 0.02, 0.9), ROBOT_GLOW_COLOR, 0.0)
	_door_slit_mat = door_slit.mesh.material

	_door_glow = _make_light(ROBOT_GLOW_COLOR, 2.5)
	_door_glow.position = _at(DOOR_SLIT_POS) + Vector3(0.0, 0.15, 0.0)
	_nudge = _make_light(NUDGE_COLOR, 2.2)

	print("[wake_up] room ", room.name, " armed: door locked, pistol at ", _pickup.position)

# A point of the room, in the floor's coordinates (which are this node's own).
func _at(room_local: Vector3) -> Vector3:
	return room.transform * room_local

func _make_slit(at: Vector3, size: Vector3, color: Color, energy: float) -> MeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.BLACK # a gap that light comes through, not a painted strip: dark when nothing shines
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var slit := MeshInstance3D.new()
	slit.mesh = mesh
	slit.position = at
	add_child(slit)
	return slit

func _make_light(color: Color, light_range: float) -> OmniLight3D:
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 0.0
	light.omni_range = light_range
	add_child(light)
	return light

# Called by the generator's _move_player() in place of its usual spot by the wardrobe.
func place_player(player: Node3D) -> void:
	var spot: Vector3 = room.global_transform * WAKE_SPOT
	player.global_position = Vector3(spot.x, player.global_position.y, spot.z)
	var facing: Vector3 = room.global_basis * WAKE_FACING
	player.rotation.y = atan2(-facing.x, -facing.z)
	var weapon = player.get("weapon")
	if weapon and weapon.has_method("set_armed"):
		weapon.set_armed(false)
	print("[wake_up] player placed at ", player.global_position, " facing ", facing, ", unarmed")

func _process(delta: float) -> void:
	if _room_door.is_open:
		_finish()
		return
	_time += delta

	var new_stage: Stage = _current_stage()
	if new_stage != stage:
		print("[wake_up] stage ", Stage.keys()[stage], " -> ", Stage.keys()[new_stage])
		stage = new_stage
		_stalled = 0.0
	if _wc_slit and _wc_door.is_open:
		_wc_slit.queue_free()
		_wc_slit = null

	_update_nudge(delta)
	_update_robot_glow(delta)

# The first thing still not done. Read off the world every frame rather than counted in
# signals, so it cannot get out of step with it (the tape taken before the pistol, say).
func _current_stage() -> Stage:
	var armed: bool = not is_instance_valid(_pickup)
	var lock_broken: bool = not is_instance_valid(_lock) or _lock.is_broken
	if not armed:
		return Stage.PISTOL if _wc_door.is_open else Stage.WC_DOOR
	if lock_broken:
		return Stage.EXIT
	return Stage.TAPE if is_instance_valid(_cassette) else Stage.LOCK

func _stage_target() -> Vector3:
	match stage:
		Stage.WC_DOOR:
			return _at(WC_SLIT_POS) + Vector3(0.0, 0.4, 0.0)
		Stage.PISTOL:
			return _at(PISTOL_POS) + Vector3(0.0, 0.3, 0.0)
		Stage.TAPE:
			return _cassette.position + Vector3(0.0, 0.15, 0.0)
		Stage.LOCK:
			return to_local(_lock.global_position) + Vector3(0.0, 0.25, 0.0)
	return _at(DOOR_INSIDE_POS)

func _update_nudge(delta: float) -> void:
	_stalled += delta
	var strength: float = smoothstep(NUDGE_AFTER, NUDGE_FULL, _stalled)
	if is_instance_valid(_lock):
		_lock.urgency = strength if stage == Stage.LOCK else 0.0
	_nudge.position = _stage_target()
	_nudge.light_energy = strength * lerpf(0.2, 1.6, 0.5 - 0.5 * cos(_time * TAU / 1.6))
	if strength <= 0.0:
		_tick_timer = 0.0
		return
	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = NUDGE_TICK_INTERVAL
		AudioManager.play_sfx(AudioManager.tape_pickup_sound(), to_global(_nudge.position), 1.7, lerpf(-22.0, -8.0, strength))

# The robot on the other side of the shut door: its eye shows under the door, its steps carry.
func _update_robot_glow(delta: float) -> void:
	var outside: Vector3 = to_global(_at(DOOR_OUTSIDE_POS))
	var nearest: Node3D = null
	var nearest_dist: float = ROBOT_FAR
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if absf(enemy.global_position.y - outside.y) > EnemySensors.SAME_FLOOR_Y_TOLERANCE:
			continue
		var offset: Vector3 = enemy.global_position - outside
		offset.y = 0.0
		if offset.length() < nearest_dist:
			nearest_dist = offset.length()
			nearest = enemy
	var target: float = clampf(inverse_lerp(ROBOT_FAR, ROBOT_NEAR, nearest_dist), 0.0, 1.0) if nearest else 0.0
	_robot_glow = move_toward(_robot_glow, target, delta * 1.5)
	_door_glow.light_energy = _robot_glow * 1.8
	_door_slit_mat.emission_energy_multiplier = _robot_glow * 5.0

	_robot_step_timer -= delta
	if nearest and _robot_step_timer <= 0.0 and Vector2(nearest.velocity.x, nearest.velocity.z).length() > 0.5:
		_robot_step_timer = ROBOT_STEP_INTERVAL
		AudioManager.play_sfx(_step_sound, nearest.global_position, 0.6, -4.0)

func _on_pistol_taken() -> void:
	if not _main_light:
		return
	if _main_light_mesh:
		_main_light_mesh.visible = true
	# The lamp stutters on, as everything electrical in this hotel does.
	var tween := create_tween()
	for step in [[0.6, 0.05], [0.0, 0.08], [1.0, 0.1], [0.3, 0.05], [1.0, 0.25]]:
		tween.tween_property(_main_light, "light_energy", _main_light_energy * step[0], step[1])

func _finish() -> void:
	print("[wake_up] the door is open - the room is done")
	GameStateManager.wake_up_done = true
	queue_free()

# However this node goes - the door opened, or the level was rebuilt under it - the room gets
# its light back.
func _exit_tree() -> void:
	if is_instance_valid(_main_light):
		_main_light.light_energy = _main_light_energy
	if is_instance_valid(_main_light_mesh):
		_main_light_mesh.visible = true
