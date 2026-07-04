@tool
extends CSGCombiner3D
class_name HotelRoom

@export_group("Room Properties")
@export var room_number: String = "":
	set(value):
		room_number = value
		_update_label()

# Ширина проема, которую генератор считывает для постройки стен
@export var door_hole_width: float = 1.84 

@export_group("Stylization")
@export var carpet_color: Color = Color.WHITE:
	set(value):
		carpet_color = value
		_update_floor_color()

@export var carpet_texture: Texture2D = preload("res://assets/textures/hotel_carpet.jpg")
@export var carpet_uv_scale: Vector3 = Vector3(10, 10, 10)

@export_group("Node References")
@export var room_label: Label3D
@export var door_body: Node3D
@export var floor_mesh: GeometryInstance3D

@export_group("Transforms")
@export var label_door_offset: Vector3 = Vector3(0.5, 1.5, 0.06)

func _ready() -> void:
	if not Engine.is_editor_hint():
		GlobalConfig.apply_dynamic_scale(self)
		
	_update_label()
	_update_floor_color()
	if not Engine.is_editor_hint():
		_attach_label_to_door()

func _attach_label_to_door() -> void:
	var label = _get_label_node()
	var d_body = get_node_or_null("MainDoor/AnimatableBody3D")
	
	if label and d_body:
		var current_parent = label.get_parent()
		
		if current_parent != d_body:
			current_parent.remove_child(label)
			d_body.add_child(label)
			
			label.transform.basis = Basis.IDENTITY
			label.transform.origin = label_door_offset

func _get_label_node() -> Label3D:
	var label = get_node_or_null("RoomLabel")
	if not label:
		label = get_node_or_null("MainDoor/AnimatableBody3D/RoomLabel")
	return label as Label3D

func _update_label() -> void:
	var label = _get_label_node()
	if label:
		label.text = room_number

func _update_floor_color() -> void:
	var f_mesh = get_node_or_null("Floor")
	if f_mesh:
		var material = StandardMaterial3D.new()
		if carpet_texture:
			material.albedo_texture = carpet_texture
		material.albedo_color = carpet_color
		material.uv1_scale = carpet_uv_scale
		
		if f_mesh is CSGPrimitive3D:
			f_mesh.material = material
		elif f_mesh is MeshInstance3D:
			f_mesh.set_surface_override_material(0, material)