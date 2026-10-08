# scripts/interactables/door_lock.gd
# The lock bolted to the inside of the wake-up room's door (wake_up_room.gd). The door it sits
# on only rattles (door.gd's `locked`) until this has taken HITS_TO_BREAK shots - the first
# thing in the game that has to be shot, and the only thing in that room the pistol is for.
#
# A child of the door's own AnimatableBody3D, in the middle of its room side: a bar across the
# leaf with the lock on it. Its hit box is the whole door and a strip of the frame around it,
# not the plate you see: the pistol's ray starts at the pistol, 0.3m right of and below the
# middle of the screen, and on a phone the camera does not tilt at all - a shot aimed squarely
# at the plate lands beside it. Shooting the door is shooting the lock.
extends StaticBody3D

signal broken

const HITS_TO_BREAK: int = 5
const HIT_BOX: Vector3 = Vector3(1.7, 1.6, 0.1) # stands 3cm proud of the wall around the doorway
const LED_COLOR := Color(1.0, 0.12, 0.08)

var hits: int = 0
var is_broken: bool = false
# 0..1, set by wake_up_room.gd while the player is stuck in front of it: the light blinks faster.
var urgency: float = 0.0

var _plate: MeshInstance3D
var _led_mat: StandardMaterial3D
var _time: float = 0.0
var _flash: float = 0.0

var _clank = preload("res://assets/audio/sfx/door_close.wav")

func _ready() -> void:
	collision_layer = 6 # 2: the pistol's ray, 4: the interact ray (it passes the press on to the door)
	collision_mask = 0

	var shape := BoxShape3D.new()
	shape.size = HIT_BOX
	var coll := CollisionShape3D.new()
	coll.shape = shape
	add_child(coll)

	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.16, 0.16, 0.17)
	metal.metallic = 0.8
	metal.roughness = 0.45

	_plate = MeshInstance3D.new()
	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(0.26, 0.36, 0.05)
	plate_mesh.material = metal
	_plate.mesh = plate_mesh
	add_child(_plate)

	# The bar the lock holds across the door, frame to frame.
	var bar := MeshInstance3D.new()
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(0.98, 0.07, 0.03)
	bar_mesh.material = metal
	bar.mesh = bar_mesh
	bar.position = Vector3(0.0, -0.08, 0.01)
	add_child(bar)

	_led_mat = StandardMaterial3D.new()
	_led_mat.albedo_color = LED_COLOR
	_led_mat.emission_enabled = true
	_led_mat.emission = LED_COLOR
	var led := MeshInstance3D.new()
	var led_mesh := BoxMesh.new()
	led_mesh.size = Vector3(0.05, 0.05, 0.03)
	led_mesh.material = _led_mat
	led.mesh = led_mesh
	led.position = Vector3(-0.06, 0.1, -0.03)
	_plate.add_child(led)

func _process(delta: float) -> void:
	if is_broken:
		return
	_time += delta * lerpf(1.0, 4.0, urgency)
	_flash = maxf(_flash - delta * 4.0, 0.0)
	var pulse: float = 0.5 - 0.5 * cos(_time * TAU / 1.8)
	_led_mat.emission_energy_multiplier = lerpf(0.6, 2.5, pulse) + _flash * 8.0

# The door was tried and did not open: the light answers.
func flash() -> void:
	_flash = 1.0

# Pressing "interact" on the lock is pressing it on the door.
func interact(player: Node) -> void:
	get_parent().interact(player)

func take_damage(_amount: float) -> void:
	if is_broken:
		return
	hits += 1
	_flash = 1.0
	AudioManager.play_sfx(_clank, global_position, 2.6 + 0.25 * hits)
	# Each hit knocks the plate a little further out of true.
	_plate.rotation.z += randf_range(0.06, 0.14) * (1.0 if hits % 2 == 0 else -1.0)
	_plate.position.y -= 0.012
	print("[door_lock] hit ", hits, "/", HITS_TO_BREAK)
	if hits >= HITS_TO_BREAK:
		_break()

func _break() -> void:
	is_broken = true
	collision_layer = 0
	_led_mat.emission_energy_multiplier = 0.0
	_led_mat.albedo_color = Color(0.1, 0.02, 0.02)
	get_parent().locked = false
	broken.emit()
	print("[door_lock] broken - the door opens now")
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 1.25, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(func(): AudioManager.play_sfx(_clank, global_position, 1.4))
	tween.tween_callback(queue_free)
