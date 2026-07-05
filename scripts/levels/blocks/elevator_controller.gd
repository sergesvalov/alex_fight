extends Node3D
class_name ElevatorController

@onready var door_animatable = $ElevatorDoor/AnimatableBody3D
@onready var panel = $ElevatorGeometry/ElevatorPanel
@onready var button = $ElevatorGeometry/ElevatorPanel/ButtonFloor4

# We'll create an AudioStreamPlayer3D for the hum dynamically if not present
var sfx_hum: AudioStreamPlayer3D

func _ready() -> void:
	# Connect the button
	if button:
		button.button_pressed.connect(_on_button_pressed)
		
	# Setup audio
	sfx_hum = AudioStreamPlayer3D.new()
	add_child(sfx_hum)
	# We can use an existing looping hum or just a low pitch sound
	# Since we don't have a specific hum, we'll leave stream empty and just print for now,
	# or use an existing sound. Let's look for something suitable or just not play.

func _on_button_pressed(floor_num: int) -> void:
	print("Elevator button pressed for floor: ", floor_num)
	_run_elevator_sequence()

func _run_elevator_sequence() -> void:
	# 1. Close doors if open
	if door_animatable.is_open:
		door_animatable.interact(null) # triggers closing
		await get_tree().create_timer(door_animatable.move_time + 0.5).timeout
	else:
		# If it's already closed, maybe we want to open then close?
		# Let's assume it's open by default.
		pass
		
	# Ensure closed
	if door_animatable.is_open:
		door_animatable.interact(null)
		await get_tree().create_timer(door_animatable.move_time + 0.5).timeout
		
	print("Elevator moving...")
	# 2. Hum sound (simulated)
	if sfx_hum.stream:
		sfx_hum.play()
		
	# 3. Delay for movement
	await get_tree().create_timer(4.0).timeout
	
	print("Elevator arrived!")
	if sfx_hum.playing:
		sfx_hum.stop()
		
	# 4. Open doors
	if not door_animatable.is_open:
		door_animatable.interact(null)
