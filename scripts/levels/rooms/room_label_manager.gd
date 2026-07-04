@tool
extends Node
class_name RoomLabelManager

@export var room_number: String = "":
	set(value):
		room_number = value
		_update_label()

@export var room_label: Label3D
@export var door_body: Node3D
@export var label_door_offset: Vector3 = Vector3(0.5, 1.5, 0.06)

func _ready() -> void:
	if not Engine.is_editor_hint():
		_attach_label_to_door()
		
	_update_label()

func _attach_label_to_door() -> void:
	if not room_label:
		room_label = get_parent().get_node_or_null("RoomLabel")
	
	if not door_body:
		door_body = get_parent().get_node_or_null("MainDoor/AnimatableBody3D")
		
	if room_label and door_body:
		var current_parent = room_label.get_parent()
		
		if current_parent != door_body:
			current_parent.remove_child(room_label)
			door_body.add_child(room_label)
			
			room_label.transform.basis = Basis.IDENTITY
			room_label.transform.origin = label_door_offset
			
			if get_parent().scale.z < 0:
				room_label.scale.x = -1

func _update_label() -> void:
	if not room_label:
		room_label = get_parent().get_node_or_null("RoomLabel")
		if not room_label:
			room_label = get_parent().get_node_or_null("MainDoor/AnimatableBody3D/RoomLabel")
			
	if room_label:
		room_label.text = room_number
