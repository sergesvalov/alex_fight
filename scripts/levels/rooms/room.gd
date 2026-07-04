@tool
extends CSGCombiner3D
class_name HotelRoom

@export_group("Room Properties")
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
@export var floor_mesh: GeometryInstance3D

func _ready() -> void:
	if not Engine.is_editor_hint():
		GlobalConfig.apply_dynamic_scale(self)
		
	_update_floor_color()

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