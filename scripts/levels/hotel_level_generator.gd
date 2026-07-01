@tool
extends Node3D
class_name HotelLevelGenerator

@export var generate: bool = false:
    set(value):
        if value:
            _generate_level()

@export var num_double_rooms: int = 6
@export var num_single_rooms: int = 9
@export var double_room_step: float = 10.0
@export var single_room_step: float = 6.0
@export var corridor_width: float = 7.0
@export var corridor_height: float = 4.25

var double_room_scene = preload("res://scenes/levels/hotel_siberia/rooms/double_room.tscn")
var single_room_scene = preload("res://scenes/levels/hotel_siberia/rooms/single_room.tscn")

func _generate_level() -> void:
    pass
        
    print("Generating hotel level geometry...")
    _clear_generated_nodes()
    
    _generate_north_block()
    
    # 1. Calculate corridor length based on the farthest room
    var max_double_z = -5.0 - (num_double_rooms - 1) * double_room_step - 5.0
    var max_single_z = -3.0 - (num_single_rooms - 1) * single_room_step - 3.0
    var corridor_end_z = min(max_double_z, max_single_z)
    var corridor_length = abs(corridor_end_z) + 10.0 # From +10 to end
    var corridor_center_z = (10.0 + corridor_end_z) / 2.0
    
    # 2. Generate Floors and Ceilings
    _create_csg_box("CorridorFloor", Vector3(0, 0, corridor_center_z), Vector3(corridor_width, 0.5, corridor_length), true)
    _create_csg_box("CorridorCeiling", Vector3(0, corridor_height, corridor_center_z), Vector3(corridor_width, 0.5, corridor_length), true)
    
    # 3. Generate Double Rooms (Left side)
    var dbl_labels = ["401", "402", "403", "405", "406", "408", "409", "410", "411"]
    var prev_z = 0.0
    var wall_x = -corridor_width / 2.0
    
    for i in range(num_double_rooms):
        var c_z = -5.0 - i * double_room_step
        
        # Room instance
        var room = double_room_scene.instantiate()
        room.name = "DoubleRoomL" + str(i + 1)
        room.transform.origin = Vector3(-7.5, 0, c_z)
        add_child(room)
        room.owner = get_tree().edited_scene_root
        if room.has_method("set_room_number"):
            room.room_number = dbl_labels[i % dbl_labels.size()]
        elif "room_number" in room:
            room.room_number = dbl_labels[i % dbl_labels.size()]
            
        # Wall segment before this room
        var gap_start = c_z + 1.25
        var gap_end = c_z - 0.25
        var length = prev_z - gap_start
        var center = (prev_z + gap_start) / 2.0
        if length > 0:
            _create_wall("CorrWallW" + str(i + 1), Vector3(wall_x, 2, center), length)
        prev_z = gap_end
        
    var last_w_length = prev_z - corridor_end_z
    if last_w_length > 0:
        _create_wall("CorrWallW_End", Vector3(wall_x, 2, (prev_z + corridor_end_z) / 2.0), last_w_length)
        
    # 4. Generate Single Rooms (Right side)
    var sngl_labels = ["410", "411", "412", "413", "415", "416", "417", "420", "421", "422", "423"]
    prev_z = 0.0
    wall_x = corridor_width / 2.0
    
    for i in range(num_single_rooms):
        var c_z = -3.0 - i * single_room_step
        
        # Room instance
        var room = single_room_scene.instantiate()
        room.name = "SingleRoomR" + str(i + 1)
        room.transform.origin = Vector3(6.5, 0, c_z)
        add_child(room)
        room.owner = get_tree().edited_scene_root
        if "room_number" in room:
            room.room_number = sngl_labels[i % sngl_labels.size()]
            
        # Wall segment
        var gap_start = c_z + 1.25
        var gap_end = c_z - 0.25
        var length = prev_z - gap_start
        var center = (prev_z + gap_start) / 2.0
        if length > 0:
            _create_wall("CorrWallE" + str(i + 1), Vector3(wall_x, 2, center), length)
        prev_z = gap_end

    var last_e_length = prev_z - corridor_end_z
    if last_e_length > 0:
        _create_wall("CorrWallE_End", Vector3(wall_x, 2, (prev_z + corridor_end_z) / 2.0), last_e_length)

    # 5. Generate South Block (Stairwell and End Wall)
    var stairwell_scene = preload("res://scenes/levels/hotel_siberia/stairwell.tscn")
    
    var stair_z = corridor_end_z - 10.0
    var stair = stairwell_scene.instantiate()
    stair.name = "Stairwell_S"
    stair.transform.origin = Vector3(0, 0, stair_z)
    # Rotate 180 degrees
    stair.transform.basis = Basis.from_euler(Vector3(0, PI, 0))
    add_child(stair)
    stair.owner = get_tree().edited_scene_root
    
    _create_wall("CorrWallSouthEnd", Vector3(0, 2, stair_z - 1.5), 1.0)
    var end_wall = get_node_or_null("CorrWallSouthEnd")
    if end_wall:
        end_wall.size = Vector3(6.0, 4.0, 1.0) # Override size for the end wall
        
    print("Level geometry generated.")

func _create_wall(node_name: String, pos: Vector3, length: float) -> void:
    _create_csg_box(node_name, pos, Vector3(1.0, 4.0, length), false)

func _create_csg_box(node_name: String, pos: Vector3, size: Vector3, is_floor: bool) -> void:
    var box = CSGBox3D.new()
    box.name = node_name
    box.transform.origin = pos
    box.size = size
    box.use_collision = true
    box.collision_layer = 2
    
    var mat_path = "res://assets/textures/materials/standard_floor.tres" if is_floor else "res://assets/textures/materials/standard_wall.tres"
    # Fallback to creating a new material if we can't find it easily
    var material = StandardMaterial3D.new()
    if is_floor:
        material.albedo_texture = preload("res://assets/textures/hotel_carpet.jpg")
        material.uv1_scale = Vector3(10, 10, 10)
    else:
        material.albedo_texture = preload("res://assets/textures/hotel_wallpaper.jpg")
        material.uv1_scale = Vector3(20, 2, 2)
        material.roughness = 0.9
        
    box.material = material
    add_child(box)
    box.owner = get_tree().edited_scene_root
    return box

func _create_csg_hole(parent: Node, node_name: String, pos: Vector3, size: Vector3) -> CSGBox3D:
    var hole = CSGBox3D.new()
    hole.name = node_name
    hole.transform.origin = pos
    hole.size = size
    hole.operation = CSGShape3D.OPERATION_SUBTRACTION
    parent.add_child(hole)
    hole.owner = get_tree().edited_scene_root
    return hole

func _create_light(node_name: String, pos: Vector3, color: Color) -> OmniLight3D:
    var light = OmniLight3D.new()
    light.name = node_name
    light.transform.origin = pos
    light.light_color = color
    light.omni_range = 8.0
    add_child(light)
    light.owner = get_tree().edited_scene_root
    return light

func _generate_north_block() -> void:
    # 1. Side Corridor
    _create_csg_box("SideCorridorFloor", Vector3(7.5, 0, 7.5), Vector3(9, 0.5, 4), true)
    _create_csg_box("SideCorridorCeiling", Vector3(7.5, 4.25, 7.5), Vector3(9, 4, 1), false)
    
    # 2. Elevator
    var elev_wall = _create_csg_box("ElevatorWallS", Vector3(7.5, 2, 5.5), Vector3(9, 4, 1), false)
    _create_csg_hole(elev_wall, "ElevatorDoorHole", Vector3(0, -0.75, 0), Vector3(3, 2.5, 2))
    
    var elev_shaft = _create_csg_box("ElevatorShaft", Vector3(7.5, 2, 2.5), Vector3(6, 4, 5), false)
    elev_shaft.flip_faces = true
    _create_light("ElevatorLight", Vector3(7.5, 3.5, 4.0), Color(0.9, 0.95, 1, 1))
    
    # 3. Maintenance
    var maint_wall = _create_csg_box("MaintenanceWallW", Vector3(12, 2, 7.5), Vector3(1, 4, 5), false)
    _create_csg_hole(maint_wall, "MaintenanceDoorHole", Vector3(0, -0.75, 0), Vector3(2, 2.5, 1.5))
    
    var maint_room = _create_csg_box("MaintenanceRoom", Vector3(15, 2, 7.5), Vector3(6, 4, 5), false)
    maint_room.flip_faces = true
    _create_light("MaintenanceLight", Vector3(15, 3.5, 7.5), Color(1.0, 0.9, 0.7, 1))
    
    # 4. North Stairwell
    var stairwell_scene = preload("res://scenes/levels/hotel_siberia/stairwell.tscn")
    var stair = stairwell_scene.instantiate()
    stair.name = "Stairwell_N"
    stair.transform.origin = Vector3(0, 0, 5.0)
    add_child(stair)
    stair.owner = get_tree().edited_scene_root
    
    # 5. Front Wall
    _create_csg_box("CorrWallNorthEnd", Vector3(-3.5, 2, 5.0), Vector3(1, 4, 10), false)

func _clear_generated_nodes() -> void:
    var nodes_to_remove = []
    var clear_names = ["DoubleRoom", "SingleRoom", "CorrWall", "CorridorFloor", "CorridorCeiling", "RoomLabel", "Stairwell_S", "SideCorridorFloor", "SideCorridorCeiling", "ElevatorWallS", "ElevatorShaft", "MaintenanceWallW", "MaintenanceRoom", "ElevatorLight", "MaintenanceLight", "Stairwell_N", "CorrWallNorthEnd"]
    for child in get_children():
        var n = child.name
        var should_remove = false
        for c in clear_names:
            if n.begins_with(c) or n == c:
                should_remove = true
                break
        if should_remove:
            nodes_to_remove.append(child)
            
    for child in nodes_to_remove:
        remove_child(child)
        child.queue_free()
