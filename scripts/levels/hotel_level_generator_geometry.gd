@tool
extends HotelLevelGeneratorBase
class_name HotelLevelGeneratorGeometry

# region Corridor Shell & Rooms

func _generate_corridor_shell(parent: Node3D, corridor_start_z: float, total_corridor_end: float) -> void:
	var corridor_length = corridor_start_z - total_corridor_end
	var corridor_center_z = (corridor_start_z + total_corridor_end) / 2.0
	
	var floor_y = -floor_thickness / 2.0
	var ceil_y = corridor_height + (floor_thickness / 2.0)
	
	_create_csg_box(parent, "CorridorFloor", Vector3(0, floor_y, corridor_center_z), Vector3(35.0, floor_thickness, corridor_length), true)
	_create_csg_box(parent, "CorridorCeiling", Vector3(0, ceil_y, corridor_center_z), Vector3(35.0, floor_thickness, corridor_length), true)

func _generate_rooms_side(f_num: int, parent: Node3D, is_left: bool, corridor_start_z: float, total_corridor_end: float) -> void:
	var prev_z = corridor_start_z
	var wall_x = -corridor_width / 2.0 if is_left else corridor_width / 2.0
	var num_rooms = num_double_rooms if is_left else num_single_rooms
	var start_z = double_room_start_z if is_left else single_room_start_z
	var step = double_room_step if is_left else single_room_step
	var room_x = double_room_x if is_left else single_room_x
	var suffixes = double_room_suffixes if is_left else single_room_suffixes
	var prefix = "DoubleRoomL" if is_left else "SingleRoomR"
	var side_str = "L_" if is_left else "R_"
	
	for i in range(num_rooms):
		var c_z = start_z - i * step
		var room
		if is_left:
			room = double_room_large_scene.instantiate() if i < 2 else double_room_scene.instantiate()
		else:
			room = single_room_scene.instantiate()
			
		room.name = prefix + str(i + 1) + "_F" + str(f_num)
		room.transform.origin = Vector3(room_x, room_y_offset, c_z)
		parent.add_child(room)
		room.owner = get_tree().edited_scene_root
		
		if "room_number" in room:
			room.room_number = str(f_num) + suffixes[i % suffixes.size()]
		if "carpet_color" in room:
			room.carpet_color = carpet_color
			
		var door_center_z = c_z + room_door_z_offset
		var half_opening = room_door_opening_width / 2.0
		var door_top_z = door_center_z + half_opening
		var door_bottom_z = door_center_z - half_opening
		
		if prev_z > door_top_z:
			_create_wall(parent, "CorrWall_" + side_str + str(i), Vector3(wall_x, 0, (prev_z + door_top_z) / 2.0), prev_z - door_top_z)
		prev_z = door_bottom_z
		
	if prev_z > total_corridor_end:
		_create_wall(parent, "CorrWall_" + side_str + "end", Vector3(wall_x, 0, (total_corridor_end + prev_z) / 2.0), prev_z - total_corridor_end)

func _generate_map_decals(parent: Node3D) -> void:
	var map_z = double_room_start_z - (double_room_step / 2.0)
	var inner_wall_x = (corridor_width / 2.0) - (wall_thickness / 2.0)
	var decal_x = inner_wall_x - map_decal_wall_offset
	
	var decal_positions = [Vector3(-decal_x, map_decal_y_pos, map_z), Vector3(decal_x, map_decal_y_pos, map_z)]
	
	for i in range(decal_positions.size()):
		var pos = decal_positions[i]
		var map_decal = MeshInstance3D.new()
		map_decal.name = "MapDecal_" + str(i + 1)
		map_decal.transform.origin = pos
		map_decal.transform.basis = Basis.from_euler(Vector3(0, PI/2 if pos.x < 0 else -PI/2, 0))
			
		var quad = QuadMesh.new()
		quad.size = map_decal_size
		var map_mat = StandardMaterial3D.new()
		map_mat.albedo_texture = map_texture if map_texture else preload("res://assets/textures/hotel_map.jpg")
		map_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		quad.material = map_mat
		map_decal.mesh = quad
		parent.add_child(map_decal)
		map_decal.owner = get_tree().edited_scene_root

# endregion

# region Block Generators

func _generate_north_block(parent: Node3D, start_z: float) -> void:
	_generate_elevator_shaft(parent)
	_generate_maintenance_room(parent)
	
	var main_wall_len = start_z - side_corridor_z_end
	if main_wall_len > 0:
		var center_z = side_corridor_z_end + (main_wall_len / 2.0)
		var center_x = corridor_width / 2.0
		_create_csg_box(parent, "MainCorrRightWall", Vector3(center_x, corridor_height / 2.0, center_z), Vector3(wall_thickness, corridor_height, main_wall_len), false, false)
		
	var stair = stairwell_scene.instantiate()
	stair.name = "Stairwell_N"
	stair.transform.basis = Basis.from_euler(Vector3(0, 0, 0))
	stair.transform.origin = Vector3(0, 0, start_z)
	parent.add_child(stair)
	stair.owner = get_tree().edited_scene_root
	
	_create_csg_box(parent, "NorthFillerRight", Vector3(7.4, 2.0, 9.0), Vector3(7.8, 4.0, 2.0), false, false)

func _generate_south_block(parent: Node3D, stair_z: float) -> void:
	var stairwell_south_scene = load("res://scenes/levels/hotel_siberia/stairwell_south.tscn")
	if stairwell_south_scene:
		var stair_inst = stairwell_south_scene.instantiate()
		stair_inst.name = "StairwellSouth"
		stair_inst.rotation_degrees.y = 180
		stair_inst.position = Vector3(0, 0, stair_z)
		parent.add_child(stair_inst)
		stair_inst.owner = get_tree().edited_scene_root
		
	var fill_left_len = -62.0 - stair_z
	if fill_left_len > 0:
		_create_csg_box(parent, "SouthFillerLeft", Vector3(-8.6, 2.0, stair_z + fill_left_len/2.0), Vector3(10.2, 4.0, fill_left_len), false, false)
		
	var fill_right_len = -64.8 - stair_z
	if fill_right_len > 0:
		_create_csg_box(parent, "SouthFillerRight", Vector3(7.4, 2.0, stair_z + fill_right_len/2.0), Vector3(7.8, 4.0, fill_right_len), false, false)

func _generate_elevator_shaft(parent: Node3D) -> void:
	var wall_y_center = corridor_height / 2.0
	var hole_y = (util_door_height - corridor_height) / 2.0
	
	var elev_x_center = (corridor_width / 2.0) + (side_corridor_depth / 2.0)
	var elev_z_center = side_corridor_z_end + (elev_shaft_depth / 2.0)
	
	var side_north_wall = _create_csg_box(parent, "SideCorrNorthWall", Vector3(elev_x_center, wall_y_center, side_corridor_z_end), Vector3(side_corridor_depth, corridor_height, wall_thickness), false, false)
	_create_csg_hole(side_north_wall, "ElevatorDoorHole", Vector3(0, hole_y, 0), Vector3(util_door_width, util_door_height, wall_thickness + door_hole_width_margin))
	
	_create_csg_box(parent, "ElevatorShaft", Vector3(elev_x_center, wall_y_center, elev_z_center), Vector3(side_corridor_depth, corridor_height, elev_shaft_depth), false, false)
	_create_csg_hole(parent, "ElevatorHole", Vector3(elev_x_center, wall_y_center, elev_z_center), Vector3(side_corridor_depth - room_hole_margin, corridor_height, elev_shaft_depth - room_hole_margin))
	
	var light_z = side_corridor_z_end + elev_light_z_offset
	var light_y = corridor_height - north_block_light_y_offset
	_create_light(parent, "ElevatorLight", Vector3(elev_x_center, light_y, light_z), Color(0.9, 0.95, 1, 1))
	
	var elev_doors = elevator_door_scene.instantiate()
	elev_doors.name = "ElevatorDoors"
	elev_doors.transform.origin = Vector3(elev_x_center, 0.0, side_corridor_z_end)
	parent.add_child(elev_doors)
	elev_doors.owner = get_tree().edited_scene_root

func _generate_maintenance_room(parent: Node3D) -> void:
	var wall_y_center = corridor_height / 2.0
	var hole_y = (util_door_height - corridor_height) / 2.0
	
	var side_corridor_z_len = side_corridor_z_end - side_corridor_z_start
	var side_corridor_z_center = side_corridor_z_start + (side_corridor_z_len / 2.0)
	var east_wall_x = (corridor_width / 2.0) + side_corridor_depth
	
	var side_east_wall = _create_csg_box(parent, "SideCorrEastWall", Vector3(east_wall_x, wall_y_center, side_corridor_z_center), Vector3(wall_thickness, corridor_height, side_corridor_z_len), false, false)
	_create_csg_hole(side_east_wall, "MaintenanceDoorHole", Vector3(0, hole_y, 0), Vector3(wall_thickness + door_hole_width_margin, util_door_height, util_door_width))
	
	var maint_x_center = east_wall_x + (maint_room_depth / 2.0)
	
	_create_csg_box(parent, "MaintenanceRoom", Vector3(maint_x_center, wall_y_center, side_corridor_z_center), Vector3(maint_room_depth, corridor_height, side_corridor_z_len), false, false)
	_create_csg_hole(parent, "MaintenanceRoomHole", Vector3(maint_x_center, wall_y_center, side_corridor_z_center), Vector3(maint_room_depth - room_hole_margin, corridor_height, side_corridor_z_len - room_hole_margin))
	
	_create_csg_hole(parent, "MaintenanceRoomDoorHole", Vector3(east_wall_x, wall_y_center + hole_y, side_corridor_z_center), Vector3(wall_thickness + maint_door_hole_width_margin, util_door_height, util_door_width))
	var light_y = corridor_height - north_block_light_y_offset
	_create_light(parent, "MaintenanceLight", Vector3(maint_x_center, light_y, side_corridor_z_center), Color(1.0, 0.9, 0.7, 1))
	
	var maint_door = door_scene.instantiate()
	maint_door.name = "MaintenanceDoor"
	maint_door.transform.origin = Vector3(east_wall_x, 0, side_corridor_z_center)
	maint_door.transform.basis = Basis.from_euler(Vector3(0, -PI/2, 0))
	maint_door.scale = Vector3(util_door_scale, util_door_scale, util_door_scale) 
	parent.add_child(maint_door)
	maint_door.owner = get_tree().edited_scene_root

# endregion
