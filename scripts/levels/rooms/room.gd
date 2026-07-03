@tool
extends CSGCombiner3D
class_name HotelRoom

@export_group("Room Properties")
@export var room_number: String = "":
    set(value):
        room_number = value
        _update_label()

# Ширина проема, которую эта комната "вырезает" в стене коридора
@export var door_hole_width: float = 3.68 

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
@export var floor_mesh: GeometryInstance3D # Поддерживает и CSG, и MeshInstance3D

@export_group("Transforms")
@export var label_door_offset: Vector3 = Vector3(0.75, 1.5, 0.06)


func _ready() -> void:
    _update_label()
    _update_floor_color()
    if not Engine.is_editor_hint():
        _attach_label_to_door()

func _attach_label_to_door() -> void:
    # Проверяем, что ссылки на узлы заданы в Инспекторе
    if room_label and door_body:
        var current_parent = room_label.get_parent()
        
        # Убеждаемся, что еще не прикрепили
        if current_parent != door_body:
            current_parent.remove_child(room_label)
            door_body.add_child(room_label)
            
            # Позиционируем табличку на стороне коридора (+Z оси двери)
            room_label.transform.basis = Basis.IDENTITY
            room_label.transform.origin = label_door_offset

func _update_label() -> void:
    if room_label:
        room_label.text = room_number

func _update_floor_color() -> void:
    if floor_mesh:
        var material = StandardMaterial3D.new()
        if carpet_texture:
            material.albedo_texture = carpet_texture
        material.albedo_color = carpet_color
        material.uv1_scale = carpet_uv_scale
        
        # Применяем материал в зависимости от типа узла
        if floor_mesh is CSGPrimitive3D:
            floor_mesh.material = material
        elif floor_mesh is MeshInstance3D:
            floor_mesh.set_surface_override_material(0, material)