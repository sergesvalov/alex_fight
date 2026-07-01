@tool
extends Node3D
class_name HotelRoom

@export var room_number: String = "":
    set(value):
        room_number = value
        _update_label()

@export var carpet_color: Color = Color.WHITE:
    set(value):
        carpet_color = value
        _update_floor_color()

func _ready() -> void:
    _update_label()
    _update_floor_color()

func _update_label() -> void:
    if has_node("RoomLabel"):
        var label = get_node("RoomLabel")
        if label is Label3D:
            label.text = room_number

func _update_floor_color() -> void:
    if has_node("Floor"):
        var floor_mesh = get_node("Floor")
        if floor_mesh is CSGBox3D or floor_mesh is MeshInstance3D:
            var material = StandardMaterial3D.new()
            material.albedo_texture = preload("res://assets/textures/hotel_carpet.jpg")
            material.albedo_color = carpet_color
            material.uv1_scale = Vector3(10, 10, 10)
            if floor_mesh is CSGBox3D:
                floor_mesh.material = material
            elif floor_mesh is MeshInstance3D:
                floor_mesh.set_surface_override_material(0, material)
