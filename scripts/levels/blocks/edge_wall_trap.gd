# scripts/levels/blocks/edge_wall_trap.gd
# Floor 10's nightmare, "the edge": from the top floor you can see where the world ends, "a
# straight line, as if cut with a knife" (tape 1001) - and here that line is inside the building
# and moving. A black wall creeps up the floor from its south end; everything south of it is
# gone. Touch it and you are back by the floor's elevator, and the wall starts over from the
# south end.
#
# The rule is fixed and observable: it only ever advances north, at a steady pace, across the
# whole width of the floor - rooms included. So it is a race with a clock you can see: go for
# the tape furthest south first. Each tape found throws the wall back to the south end, but
# from then on it comes faster (SPEEDS). It stops short of the elevator (NORTH_LIMIT_Z), so
# the way off the floor is never cut. Floor 10's own three tapes stop it for good
# (GameStateManager.floor10_edge_stopped) and open the roof.
#
# One instance, created only on floor 10 by hotel_level_generator.gd::_add_edge_wall().
# Everything here is in this node's local space, which is the floor's own.
extends Node3D

const SOUTH_Z: float = 29.5         # where the wall starts, just inside the south wall
const NORTH_LIMIT_Z: float = -18.0  # as far north as it ever gets
const SPEEDS: Array = [0.35, 0.5, 0.7]  # m/s, by tapes found on this floor
const TOUCH_MARGIN: float = 0.4

var floor_num: int = 10
var return_position: Vector3 = Vector3.ZERO   # global
var width: float = 25.3
var height: float = 4.0

var edge_z: float = SOUTH_Z
var _tapes_seen: int = 0
var _wall: MeshInstance3D

func _ready() -> void:
	_wall = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, height, 0.1)
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0, 0, 0)
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	box.material = black
	_wall.mesh = box
	_wall.position = Vector3(0, height / 2.0, edge_z)
	add_child(_wall)
	# The cut itself: a thin bright line along the foot of the wall, so its position reads at a
	# glance down a dark corridor.
	var line := MeshInstance3D.new()
	var line_box := BoxMesh.new()
	line_box.size = Vector3(width, 0.04, 0.06)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1, 1, 1)
	glow.emission_enabled = true
	glow.emission = Color(0.9, 0.95, 1.0)
	glow.emission_energy_multiplier = 3.0
	line_box.material = glow
	line.mesh = line_box
	line.position = Vector3(0, -height / 2.0 + 0.03, -0.08)
	_wall.add_child(line)

static func speed_for(tapes_found: int) -> float:
	return SPEEDS[clampi(tapes_found, 0, SPEEDS.size() - 1)]

func _reset() -> void:
	edge_z = SOUTH_Z

func _process(delta: float) -> void:
	var running: bool = GameStateManager.current_floor == floor_num and not GameStateManager.floor10_edge_stopped
	_wall.visible = not GameStateManager.floor10_edge_stopped
	if not running:
		_reset() # nobody here to race, or it is over - back to the south end
		_tapes_seen = 0 if GameStateManager.current_floor != floor_num else _tapes_seen
		_wall.position.z = edge_z
		return

	var tapes: int = GameStateManager.tapes_found.size()
	if tapes > _tapes_seen:
		_reset() # a tape found throws it back...
	_tapes_seen = tapes
	edge_z = maxf(NORTH_LIMIT_Z, edge_z - speed_for(tapes) * delta) # ...and from then on it is faster
	_wall.position.z = edge_z

	var player = get_tree().get_first_node_in_group("player")
	if not player or GameStateManager.current_state == GameStateManager.GameState.SPECTATOR:
		return
	var local: Vector3 = to_local(player.global_position)
	if local.y < -1.0 or local.y > 3.5:
		return # on the stairs to another floor
	if local.z >= edge_z - TOUCH_MARGIN:
		# Same kind of line every other teleport in the game prints (see stairs_gate.gd).
		print("[EdgeWallTrap] player touched the edge at ", player.global_position, " (edge z=", edge_z, ") - returning to ", return_position)
		player.global_position = return_position
		if "velocity" in player:
			player.velocity = Vector3.ZERO
		_reset()
		DialogSystem.trigger_alex_line("floor10_caught")
