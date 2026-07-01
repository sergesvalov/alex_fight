@tool
extends Node3D
class_name HotelLevelGenerator

@export var generate: bool = false:
    set(value):
        if value:
            _generate_level()

@export var num_double_rooms: int = 6
@export var num_single_rooms: int = 9
@export var double_room_step: float = 12.0
@export var single_room_step: float = 7.2
@export var corridor_width: float = 7.0
@export var corridor_height: float = 4.25

@export_group("Stylization")
@export var floor_number: int = 4
@export var carpet_color: Color = Color.WHITE
@export var map_texture: Texture2D

var double_room_scene = preload("res://scenes/levels/hotel_siberia/rooms/double_room.tscn")
var single_room_scene = preload("res://scenes/levels/hotel_siberia/rooms/single_room.tscn")

func _ready() -> void:
    if not Engine.is_editor_hint():
        _generate_level()
        _apply_stylization()
        
        # Await two physics frames to let CSG operations finish baking
        await get_tree().physics_frame
        await get_tree().physics_frame
        
        # Bake navmesh at runtime
        var nav_region = get_parent()
        if nav_region is NavigationRegion3D:
            nav_region.bake_navigation_mesh()

func _apply_stylization() -> void:
    # Apply to CorridorFloor
    for floor_node in get_children():
        if floor_node.name.begins_with("GeneratedFloor"):
            if floor_node.has_node("CorridorFloor"):
                var cf = floor_node.get_node("CorridorFloor")
                if cf is CSGBox3D:
                    var material = StandardMaterial3D.new()
                    material.albedo_texture = preload("res://assets/textures/hotel_carpet.jpg")
                    material.albedo_color = carpet_color
                    material.uv1_scale = Vector3(10, 10, 10)
                    cf.material = material
            
            # Apply to Rooms inside the floor
            for child in floor_node.get_children():
                if child is HotelRoom:
                    child.carpet_color = carpet_color
            
    # Apply to Map
    pass

func _generate_level() -> void:
    print("Generating hotel level geometry...")
    _clear_generated_nodes()
    
    # 1. Main floor
    var main_parent = Node3D.new()
    main_parent.name = "GeneratedFloor_Main"
    main_parent.transform.origin.y = 0.0
    add_child(main_parent)
    main_parent.owner = get_tree().edited_scene_root
    _generate_floor(floor_number, main_parent, true)
    
    # 2. Floor above
    var above_parent = Node3D.new()
    above_parent.name = "GeneratedFloor_Above"
    above_parent.transform.origin.y = 4.0
    add_child(above_parent)
    above_parent.owner = get_tree().edited_scene_root
    if ResourceLoader.exists("res://scenes/levels/hotel_siberia/hotel_level_" + str(floor_number + 1) + ".tscn"):
        _generate_floor(floor_number + 1, above_parent, false)
    else:
        _generate_floor(floor_number, above_parent, false)
        
    # 3. Floor below
    var below_parent = Node3D.new()
    below_parent.name = "GeneratedFloor_Below"
    below_parent.transform.origin.y = -4.0
    add_child(below_parent)
    below_parent.owner = get_tree().edited_scene_root
    if ResourceLoader.exists("res://scenes/levels/hotel_siberia/hotel_level_" + str(floor_number - 1) + ".tscn"):
        _generate_floor(floor_number - 1, below_parent, false)
    else:
        _generate_floor(floor_number, below_parent, false)

func _generate_floor(f_num: int, parent: Node3D, is_main: bool) -> void:
    _generate_north_block(parent)
    
    # 1. Calculate corridor length based on the farthest room
    var max_double_z = 4.0 - (num_double_rooms - 1) * double_room_step - 6.0
    var max_single_z = -3.6 - (num_single_rooms - 1) * single_room_step - 3.6
    var corridor_end_z = min(max_double_z, max_single_z)
    var stair_z = corridor_end_z - 10.0
    var total_corridor_end = stair_z - 1.5
    var corridor_length = abs(total_corridor_end) + 11.0 # From +11 to end
    var corridor_center_z = (11.0 + total_corridor_end) / 2.0
    
    if is_main:
        _generate_entities(corridor_end_z)
    
    # 2. Generate Floors and Ceilings
    _create_csg_box(parent, "CorridorFloor", Vector3(0, -0.25, corridor_center_z), Vector3(corridor_width + 0.2, 0.5, corridor_length), true)
    _create_csg_box(parent, "CorridorCeiling", Vector3(0, corridor_height + 0.25, corridor_center_z), Vector3(corridor_width + 0.2, 0.5, corridor_length), true)
    
    # 3. Generate Double Rooms (Left side)
    var dbl_suffixes = ["01", "02", "03", "05", "06", "08", "09", "10", "11"]
    var prev_z = 10.0
    var wall_x = -corridor_width / 2.0
    
    for i in range(num_double_rooms):
        var c_z = 4.0 - i * double_room_step
        
        # Room instance
        var room = double_room_scene.instantiate()
        room.name = "DoubleRoomL" + str(i + 1) + "_F" + str(f_num)
        room.transform.origin = Vector3(-8.3, 0, c_z)
        parent.add_child(room)
        room.owner = get_tree().edited_scene_root
        if "room_number" in room:
            room.room_number = str(f_num) + dbl_suffixes[i % dbl_suffixes.size()]
        if "carpet_color" in room:
            room.carpet_color = carpet_color
            
        # Wall segment before this room
        var gap_start = c_z + 1.60
        var gap_end = prev_z
        if gap_end > gap_start:
            _create_wall(parent, "CorrWall_L_" + str(i) + "_pre", Vector3(wall_x, 2, (gap_start + gap_end) / 2.0), gap_end - gap_start)
        
        # Wall segment after this room
        gap_start = c_z - 6.6
        gap_end = c_z - 1.60
        if gap_end > gap_start:
            _create_wall(parent, "CorrWall_L_" + str(i) + "_post", Vector3(wall_x, 2, (gap_start + gap_end) / 2.0), gap_end - gap_start)
            
        prev_z = gap_start
        
    if prev_z > total_corridor_end:
        _create_wall(parent, "CorrWall_L_end", Vector3(wall_x, 2, (total_corridor_end + prev_z) / 2.0), prev_z - total_corridor_end)
        
    # 4. Generate Single Rooms (Right side)
    var sngl_suffixes = ["10", "11", "12", "13", "15", "16", "17", "20", "21", "22", "23"]
    prev_z = 10.0
    wall_x = corridor_width / 2.0
    
    for i in range(num_single_rooms):
        var c_z = -3.6 - i * single_room_step
        
        # Room instance
        var room = single_room_scene.instantiate()
        room.name = "SingleRoomR" + str(i + 1) + "_F" + str(f_num)
        room.transform.origin = Vector3(7.1, 0, c_z)
        parent.add_child(room)
        room.owner = get_tree().edited_scene_root
        if "room_number" in room:
            room.room_number = str(f_num) + sngl_suffixes[i % sngl_suffixes.size()]
        if "carpet_color" in room:
            room.carpet_color = carpet_color
            
        # Wall segment before this room
        var gap_start = c_z + 1.60
        var gap_end = prev_z
        if gap_end > gap_start:
            _create_wall(parent, "CorrWall_R_" + str(i) + "_pre", Vector3(wall_x, 2, (gap_start + gap_end) / 2.0), gap_end - gap_start)
            
        # Wall segment after this room
        gap_start = c_z - 2.8
        gap_end = c_z - 1.60
        if gap_end > gap_start:
            _create_wall(parent, "CorrWall_R_" + str(i) + "_post", Vector3(wall_x, 2, (gap_start + gap_end) / 2.0), gap_end - gap_start)
            
        prev_z = gap_start

    if prev_z > total_corridor_end:
        _create_wall(parent, "CorrWall_R_end", Vector3(wall_x, 2, (total_corridor_end + prev_z) / 2.0), prev_z - total_corridor_end)

    # 5. Generate South Block (Stairwell and End Wall)
    var stairwell_scene = preload("res://scenes/levels/hotel_siberia/stairwell.tscn")
    
    var stair = stairwell_scene.instantiate()
    stair.name = "Stairwell_S"
    stair.transform.origin = Vector3(0, 0, stair_z)
    parent.add_child(stair)
    stair.owner = get_tree().edited_scene_root
        
    print("Level geometry generated for floor " + str(f_num))

func _create_wall(parent: Node, node_name: String, pos: Vector3, length: float) -> void:
    _create_csg_box(parent, node_name, pos, Vector3(1.0, 4.0, length), false, false)

func _create_csg_box(parent: Node, node_name: String, pos: Vector3, size: Vector3, is_floor: bool, add_occluder: bool = true) -> CSGBox3D:
    var box = CSGBox3D.new()
    box.name = node_name
    box.transform.origin = pos
    box.size = size
    box.use_collision = true
    box.collision_layer = 2
    
    var material = StandardMaterial3D.new()
    if is_floor:
        material.albedo_texture = preload("res://assets/textures/hotel_carpet.jpg")
        material.albedo_color = carpet_color
        material.uv1_scale = Vector3(10, 10, 10)
    else:
        material.albedo_texture = preload("res://assets/textures/hotel_wallpaper.jpg")
        material.uv1_scale = Vector3(20, 2, 2)
        material.roughness = 0.9
        
    box.material = material
    parent.add_child(box)
    box.owner = get_tree().edited_scene_root
    
    if add_occluder:
        var occluder_inst = OccluderInstance3D.new()
        var occ_shape = BoxOccluder3D.new()
        occ_shape.size = Vector3(max(0.1, size.x - 0.1), size.y, max(0.1, size.z - 0.1))
        occluder_inst.occluder = occ_shape
        box.add_child(occluder_inst)
        occluder_inst.owner = get_tree().edited_scene_root

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

func _create_light(parent: Node, node_name: String, pos: Vector3, color: Color) -> OmniLight3D:
    var light = OmniLight3D.new()
    light.name = node_name
    light.transform.origin = pos
    light.light_color = color
    light.omni_range = 8.0
    parent.add_child(light)
    light.owner = get_tree().edited_scene_root
    return light

func _generate_north_block(parent: Node) -> void:
    # 1. Elevator (Z: 5.0 to 10.0)
    var elev_wall = _create_csg_box(parent, "ElevatorWallW", Vector3(3.5, 2, 7.5), Vector3(1.2, 4, 5), false, false)
    _create_csg_hole(elev_wall, "ElevatorDoorHole", Vector3(0, -0.75, 0), Vector3(1.6, 2.5, 2))
    
    var elev_shaft = _create_csg_box(parent, "ElevatorShaft", Vector3(7.4, 2, 7.5), Vector3(6.6, 4, 5), false, false)
    elev_shaft.flip_faces = true
    _create_light(parent, "ElevatorLight", Vector3(6.0, 3.5, 7.5), Color(0.9, 0.95, 1, 1))
    
    # Solid Elevator Doors to block the shaft
    var elev_doors = CSGBox3D.new()
    elev_doors.name = "ElevatorDoors"
    elev_doors.size = Vector3(0.2, 2.5, 2.0)
    elev_doors.transform.origin = Vector3(3.5, 1.25, 7.5)
    var metal_mat = StandardMaterial3D.new()
    metal_mat.albedo_color = Color(0.4, 0.4, 0.45)
    metal_mat.metallic = 0.8
    metal_mat.roughness = 0.2
    elev_doors.material = metal_mat
    elev_doors.use_collision = true
    parent.add_child(elev_doors)
    elev_doors.owner = get_tree().edited_scene_root
    
    # 2. Maintenance (Z: 0.0 to 5.0)
    var maint_wall = _create_csg_box(parent, "MaintenanceWallW", Vector3(3.5, 2, 2.5), Vector3(1.2, 4, 5), false, false)
    _create_csg_hole(maint_wall, "MaintenanceDoorHole", Vector3(0, -0.75, 0), Vector3(1.6, 2.5, 2))
    
    var maint_room = _create_csg_box(parent, "MaintenanceRoom", Vector3(7.4, 2, 2.5), Vector3(6.6, 4, 5), false, false)
    maint_room.flip_faces = true
    _create_csg_hole(maint_room, "MaintenanceRoomDoorHole", Vector3(-3.3, -0.75, 0), Vector3(2.0, 2.5, 2.0))
    _create_light(parent, "MaintenanceLight", Vector3(7.4, 3.5, 2.5), Color(1.0, 0.9, 0.7, 1))
    
    # Maintenance Door
    var door_scene = preload("res://entities/props/door.tscn")
    var maint_door = door_scene.instantiate()
    maint_door.name = "MaintenanceDoor"
    maint_door.transform.origin = Vector3(3.5, 0, 3.4)
    maint_door.transform.basis = Basis.from_euler(Vector3(0, -PI/2, 0))
    parent.add_child(maint_door)
    maint_door.owner = get_tree().edited_scene_root
    
    # 3. North Stairwell
    var stairwell_scene = preload("res://scenes/levels/hotel_siberia/stairwell.tscn")
    var stair = stairwell_scene.instantiate()
    stair.name = "Stairwell_N"
    stair.transform.basis = Basis.from_euler(Vector3(0, PI, 0))
    stair.transform.origin = Vector3(0, 0, 10.5)
    parent.add_child(stair)
    stair.owner = get_tree().edited_scene_root
    
    # 6. Map Decals (Only 2 maps on the floor, between the first double room and the second one)
    var map_z = 4.0 - double_room_step / 2.0
    var decal_positions = [
        Vector3(-2.99, 2.0, map_z), # Left wall
        Vector3(2.99, 2.0, map_z)   # Right wall
    ]
    for i in range(decal_positions.size()):
        var pos = decal_positions[i]
        var map_decal = MeshInstance3D.new()
        map_decal.name = "MapDecal_" + str(i + 1)
        map_decal.transform.origin = pos
        if pos.x < 0:
            map_decal.transform.basis = Basis.from_euler(Vector3(0, PI/2, 0))
        else:
            map_decal.transform.basis = Basis.from_euler(Vector3(0, -PI/2, 0))
            
        var quad = QuadMesh.new()
        quad.size = Vector2(2, 2)
        var map_mat = StandardMaterial3D.new()
        if map_texture:
            map_mat.albedo_texture = map_texture
        else:
            map_mat.albedo_texture = preload("res://assets/textures/hotel_map.jpg")
        map_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        quad.material = map_mat
        map_decal.mesh = quad
        parent.add_child(map_decal)
        map_decal.owner = get_tree().edited_scene_root

func _clear_generated_nodes() -> void:
    var nodes_to_remove = []
    for child in get_children():
        if child.name.begins_with("GeneratedFloor"):
            nodes_to_remove.append(child)
            
    for child in nodes_to_remove:
        remove_child(child)
        child.queue_free()

func _generate_entities(end_z: float) -> void:
    # 1. Move the Player to the last double room (Z = end_z + double_room_step / 2 roughly)
    var player = get_node_or_null("../../Player")
    if player:
        # Put player roughly in the middle of the first double room
        player.transform.origin = Vector3(-7.5, 2, 4.0)

    # 2. Update Enemy Spawner & Cerberus
    var enemies_node = get_node_or_null("../../Enemies")
    if enemies_node:
        if "spawn_position" in enemies_node:
            enemies_node.spawn_position = Vector3(0, 1, end_z + 10.0)
            
        var cerberus = enemies_node.get_node_or_null("Cerberus")
        if cerberus:
            cerberus.transform.origin = Vector3(0, 1, end_z + 10.0)
            
        # 3. Generate Patrol Points
        var patrol_points = enemies_node.get_node_or_null("PatrolPoints")
        if patrol_points:
            # Clear existing points
            for child in patrol_points.get_children():
                patrol_points.remove_child(child)
                child.queue_free()
                
            # Create new points every 20 meters from -20 down to end_z
            var points_array = []
            var current_z = -20.0
            var idx = 1
            while current_z > end_z + 5.0:
                var marker = Marker3D.new()
                marker.name = "Point" + str(idx)
                marker.transform.origin = Vector3(0, 0, current_z)
                patrol_points.add_child(marker)
                marker.owner = get_tree().edited_scene_root
                points_array.append(NodePath("../PatrolPoints/" + str(marker.name)))
                current_z -= 20.0
                idx += 1
                
            # Fallback if corridor is too short
            if points_array.size() == 0:
                var marker = Marker3D.new()
                marker.name = "Point1"
                marker.transform.origin = Vector3(0, 0, min(-5.0, end_z / 2.0))
                patrol_points.add_child(marker)
                marker.owner = get_tree().edited_scene_root
                points_array.append(NodePath("../PatrolPoints/Point1"))
                
            if cerberus and "patrol_points" in cerberus:
                cerberus.patrol_points = points_array
