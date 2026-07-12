extends Node3D
class_name ElevatorController

@onready var panel = $ElevatorPanel

# We'll create an AudioStreamPlayer3D for the hum dynamically if not present
var sfx_hum: AudioStreamPlayer3D
var f_scale: float = 1.0

func _ready() -> void:
	if GlobalConfig:
		f_scale = GlobalConfig.get_floor_scale()
		
	var template = panel.get_node_or_null("ButtonFloor4")
	
	# Generate 10 buttons
	for i in range(1, 11):
		var btn
		if i == 4 and template:
			btn = template
		elif template:
			btn = template.duplicate()
			btn.name = "ButtonFloor" + str(i)
			panel.add_child(btn)
		else:
			continue
			
		btn.floor_num = i
		if not btn.button_pressed.is_connected(_on_button_pressed):
			btn.button_pressed.connect(_on_button_pressed)
		
		# Layout in 2 columns
		var col = (i - 1) % 2
		var row = int((i - 1) / 2)
		var z_pos = -0.08 if col == 0 else 0.08
		var y_pos = -0.3 + row * 0.15
		btn.position = Vector3(0.01, y_pos, z_pos)
		
		# Add a Label3D to show the floor number
		if not btn.has_node("Label3D"):
			var lbl = Label3D.new()
			lbl.name = "Label3D"
			lbl.text = str(i)
			lbl.pixel_size = 0.005
			lbl.font_size = 12
			lbl.modulate = Color(0, 0, 0, 1) # Black text
			lbl.outline_modulate = Color(1, 1, 1, 0)
			# Position label slightly in front of the button
			# Assuming the button faces +X based on position Vector3(0.01, y, z)
			lbl.position = Vector3(0.021, 0, 0)
			lbl.rotation = Vector3(0, PI / 2.0, 0) # Rotate to face outwards
			btn.add_child(lbl)
		
	# Setup audio
	sfx_hum = AudioStreamPlayer3D.new()
	add_child(sfx_hum)
	add_to_group("elevator_controller")

func _on_button_pressed(floor_num: int) -> void:
	print("Elevator button pressed for floor: ", floor_num)
	_run_elevator_sequence(floor_num)

func _run_elevator_sequence(target_floor: int) -> void:
	var door_animatable = get_node_or_null("ElevatorDoor/AnimatableBody3D")
	
	# 1. Close doors if open
	if door_animatable and door_animatable.is_open:
		door_animatable.interact(null)
		await get_tree().create_timer(door_animatable.move_time + 0.5).timeout
		
	print("Elevator moving to floor ", target_floor)
	
	if sfx_hum.stream:
		sfx_hum.play()
		
	# 2. Delay for movement
	await get_tree().create_timer(1.0).timeout
	
	# 3. Teleport player
	var player = get_tree().current_scene.get_node_or_null("Player")
	if player:
		# Determine current floor from global Y
		var parent_node = get_parent()
		var current_y = 0.0
		if parent_node and parent_node.name.begins_with("GeneratedFloor_"):
			current_y = parent_node.global_position.y
		else:
			current_y = self.global_position.y
			
		var y_step = 4.5 * f_scale
		var current_floor = round(current_y / y_step) + 4
		
		if current_floor != target_floor:
			var target_y = (target_floor - 4) * y_step
			var delta_y = target_y - current_y
			player.global_position.y += delta_y
			
			# Since player teleported, this elevator instance is no longer where the player is.
			# We must open the door on the target floor's elevator!
			var elevators = get_tree().get_nodes_in_group("elevator_controller")
			for el in elevators:
				if el != self:
					var el_parent = el.get_parent()
					var el_y = 0.0
					if el_parent and el_parent.name.begins_with("GeneratedFloor_"):
						el_y = el_parent.global_position.y
					else:
						el_y = el.global_position.y
					
					var el_floor = round(el_y / y_step) + 4
					if el_floor == target_floor:
						el._arrive_and_open()
						return # We stop here for the current elevator
			
	# If no teleport happened or target is same floor, just open
	await get_tree().create_timer(1.0).timeout
	_arrive_and_open()

func _arrive_and_open() -> void:
	print("Elevator arrived!")
	if sfx_hum.playing:
		sfx_hum.stop()
		
	var door_animatable = get_node_or_null("ElevatorDoor/AnimatableBody3D")
	if door_animatable and not door_animatable.is_open:
		door_animatable.interact(null)
