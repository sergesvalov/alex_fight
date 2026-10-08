# scripts/levels/blocks/sweep_camera_trap.gd
# Floor 9's nightmare, "they turn": ceiling units along the corridor - the hero once took their
# like for cameras (tape 902) - sweep bars of red light up and down it. Step into a bar and you
# are back by the floor's elevator.
#
# The rule is fixed and observable: every bar swings back and forth on its own steady rhythm,
# never follows anyone and never speeds up. Cross in the gaps; a room doorway is always a blind
# spot, since the bars only cover the corridor. Two units run at first and each tape found on
# the floor switches on one more (ACTIVE_AT_START + tapes). Floor 9's own three tapes stop them
# for good (GameStateManager.floor9_cameras_off) and unlock floor 10.
#
# One instance, created only on floor 9 by hotel_level_generator.gd::_add_sweep_cameras().
# Everything here is in this node's local space, which is the floor's own.
extends Node3D

const POSTS_Z: Array = [-13.0, -3.0, 7.0, 17.0]  # where the units hang, along the corridor
const ACTIVE_AT_START: int = 2
const SWEEP_AMPLITUDE: float = 4.0   # how far a bar swings either side of its unit
const SWEEP_PERIOD: float = 8.0      # seconds for a full swing there and back
const BAR_HALF_LENGTH: float = 2.2   # along the corridor
const GRACE_AFTER_CATCH: float = 1.5
const CEILING_Y: float = 3.8

var floor_num: int = 9
var corridor_x_min: float = -2.75
var corridor_x_max: float = 4.85
var return_position: Vector3 = Vector3.ZERO   # global

var _lights: Array = []
var _time: float = 0.0
var _grace: float = 0.0

func _ready() -> void:
	var mid_x: float = (corridor_x_min + corridor_x_max) / 2.0
	for z in POSTS_Z:
		var light := SpotLight3D.new()
		light.light_color = Color(1.0, 0.12, 0.08)
		light.light_energy = 6.0
		light.spot_range = 8.0
		light.spot_angle = 42.0
		light.position = Vector3(mid_x, CEILING_Y, z)
		light.rotation.x = -PI / 2.0 # straight down; _process() slides it along the corridor
		light.visible = false
		add_child(light)
		_lights.append(light)

func active_count() -> int:
	return mini(ACTIVE_AT_START + GameStateManager.tapes_found.size(), POSTS_Z.size())

# Where unit i's bar is centred along the corridor at time t.
func bar_z(i: int, t: float) -> float:
	return POSTS_Z[i] + SWEEP_AMPLITUDE * sin(TAU * t / SWEEP_PERIOD + i * PI / 2.0)

func _process(delta: float) -> void:
	var running: bool = GameStateManager.current_floor == floor_num and not GameStateManager.floor9_cameras_off
	var count: int = active_count() if running else 0
	_time += delta
	_grace = maxf(0.0, _grace - delta)
	for i in range(_lights.size()):
		_lights[i].visible = i < count
		_lights[i].position.z = bar_z(i, _time)
	if not running or _grace > 0.0:
		return
	var player = get_tree().get_first_node_in_group("player")
	if not player or GameStateManager.current_state == GameStateManager.GameState.SPECTATOR:
		return
	var local: Vector3 = to_local(player.global_position)
	if local.y < -1.0 or local.y > 3.0 or local.x < corridor_x_min or local.x > corridor_x_max:
		return # another floor, or inside a room / the stairs - the bars only cover the corridor
	for i in range(count):
		if absf(local.z - bar_z(i, _time)) <= BAR_HALF_LENGTH:
			# Same kind of line every other teleport in the game prints (see stairs_gate.gd).
			print("[SweepCameraTrap] unit ", i + 1, " caught the player at ", player.global_position, " - returning to ", return_position)
			player.global_position = return_position
			if "velocity" in player:
				player.velocity = Vector3.ZERO
			_grace = GRACE_AFTER_CATCH
			DialogSystem.trigger_alex_line("floor9_caught")
			return
