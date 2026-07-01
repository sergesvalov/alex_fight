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
    if not Engine.is_editor_hint():
        _attach_label_to_door()

func _attach_label_to_door() -> void:
    if has_node("RoomLabel") and has_node("MainDoor/AnimatableBody3D"):
        var label = get_node("RoomLabel")
        var door_body = get_node("MainDoor/AnimatableBody3D")
        
        # Calculate local transform relative to door_body
        var global_trans = label.global_transform
        
        label.get_parent().remove_child(label)
        door_body.add_child(label)
        
        # Position label on the corridor-facing side of the door
        # door_body's -Z axis faces the corridor.
        label.transform = Transform3D().rotated(Vector3.UP, PI)
        label.transform.origin = Vector3(0, 0.8, -0.06)

func _update_label() -> void:
    var label = get_node_or_null("RoomLabel")
    if not label:
        label = get_node_or_null("MainDoor/AnimatableBody3D/RoomLabel")
        
    if label and label is Label3D:
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
