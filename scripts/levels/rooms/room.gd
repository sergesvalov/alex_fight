@tool
extends CSGCombiner3D
class_name HotelRoom

@export_group("Room Properties")
@export var room_number: String = "":
    set(value):
        room_number = value
        _update_label()

# Ширина проема, которую генератор считывает для постройки стен
@export var door_hole_width: float = 3.68 

@export_group("Stylization")
@export var carpet_color: Color = Color.WHITE:
    set(value):
        carpet_color = value
        _update_floor_color()

@export var carpet_texture: Texture2D = preload("res://assets/textures/hotel_carpet.jpg")
@export var carpet_uv_scale: Vector3 = Vector3(10, 10, 10)

@export_group("Transforms")
@export var label_door_offset: Vector3 = Vector3(0.75, 1.5, 0.06)

func _ready() -> void:
    _update_label()
    _update_floor_color()
    if not Engine.is_editor_hint():
        _attach_label_to_door()

func _attach_label_to_door() -> void:
    var label = _get_label_node()
    var door_body = get_node_or_null("MainDoor/AnimatableBody3D")
    
    if label and door_body:
        var current_parent = label.get_parent()
        
        if current_parent != door_body:
            current_parent.remove_child(label)
            door_body.add_child(label)
            
            # Позиционируем табличку на стороне коридора
            label.transform.basis = Basis.IDENTITY
            label.transform.origin = label_door_offset

func _get_label_node() -> Label3D:
    # Динамически ищем табличку, где бы она ни находилась
    var label = get_node_or_null("RoomLabel")
    if not label:
        label = get_node_or_null("MainDoor/AnimatableBody3D/RoomLabel")
    return label as Label3D

func _update_label() -> void:
    var label = _get_label_node()
    if label:
        label.text = room_number

func _update_floor_color() -> void:
    var floor_mesh = get_node_or_null("Floor")
    if floor_mesh:
        var material = StandardMaterial3D.new()
        if carpet_texture:
            material.albedo_texture = carpet_texture
        material.albedo_color = carpet_color
        material.uv1_scale = carpet_uv_scale
        
        if floor_mesh is CSGPrimitive3D:
            floor_mesh.material = material
        elif floor_mesh is MeshInstance3D:
            floor_mesh.set_surface_override_material(0, material)