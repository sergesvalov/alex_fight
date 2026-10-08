# scripts/interactables/pistol_pickup.gd
# The laser pistol lying on the washbasin of the wake-up room's bathroom (wake_up_room.gd). The hero
# wakes up with empty hands (player_weapon.gd's `armed`); taking this puts the pistol in them.
extends Area3D

signal taken

const GLOW_COLOR := Color(0.2, 0.9, 1.0) # the pistol's own beam colour

var _glow_mat: StandardMaterial3D
var _time: float = 0.0

func _ready() -> void:
	collision_layer = 4 # the interact ray's layer, same as vhs_tape.tscn
	collision_mask = 0

	var shape := SphereShape3D.new()
	shape.radius = 0.3
	var coll := CollisionShape3D.new()
	coll.shape = shape
	add_child(coll)

	# Same boxes as laser_pistol.tscn's GunModel, lying on their side.
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.2, 0.2, 0.2)
	metal.metallic = 0.8
	metal.roughness = 0.4
	var model := Node3D.new()
	model.rotation = Vector3(0.0, 0.7, PI / 2.0)
	add_child(model)

	var barrel := MeshInstance3D.new()
	var barrel_mesh := BoxMesh.new()
	barrel_mesh.size = Vector3(0.1, 0.1, 0.4)
	barrel_mesh.material = metal
	barrel.mesh = barrel_mesh
	barrel.position = Vector3(0, 0, -0.1)
	model.add_child(barrel)

	var grip := MeshInstance3D.new()
	var grip_mesh := BoxMesh.new()
	grip_mesh.size = Vector3(0.08, 0.2, 0.1)
	grip_mesh.material = metal
	grip.mesh = grip_mesh
	grip.position = Vector3(0, -0.12, 0.05)
	grip.rotation.x = -PI / 6.0
	model.add_child(grip)

	# The charge indicator: the one thing on it that shows in the dark.
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.albedo_color = GLOW_COLOR
	_glow_mat.emission_enabled = true
	_glow_mat.emission = GLOW_COLOR
	var indicator := MeshInstance3D.new()
	var indicator_mesh := BoxMesh.new()
	indicator_mesh.size = Vector3(0.105, 0.03, 0.12)
	indicator_mesh.material = _glow_mat
	indicator.mesh = indicator_mesh
	indicator.position = Vector3(0, 0.02, -0.12)
	model.add_child(indicator)

func _process(delta: float) -> void:
	_time += delta
	_glow_mat.emission_energy_multiplier = lerpf(0.8, 3.0, 0.5 - 0.5 * cos(_time * TAU / 2.0))

func interact(player: Node) -> void:
	var weapon = player.get("weapon") if player else null
	if weapon and weapon.has_method("set_armed"):
		weapon.set_armed(true)
	AudioManager.play_sfx(AudioManager.tape_pickup_sound(), global_position, 0.7)
	print("[pistol_pickup] taken")
	taken.emit()
	queue_free()
