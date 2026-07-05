@tool
extends HotelLevelGeneratorBase
#class_name HotelLevelGeneratorGeometry

# region Corridor Shell & Rooms

func _generate_corridor_shell(parent: Node3D, corridor_start_z: float, total_corridor_end: float) -> void:
	var f_scale = GlobalConfig.get_floor_scale()
	var corridor_length = 60.0 * f_scale
	var corridor_center_z = 0.0 * f_scale
	
	var floor_y = -floor_thickness / 2.0
	var ceil_y = corridor_height + (floor_thickness / 2.0)
	
	var hotel_width = 22.35 * f_scale
	var hotel_center_x = -0.175 * f_scale
	
	_create_csg_box(parent, "CorridorFloor", Vector3(hotel_center_x, floor_y, corridor_center_z), Vector3(hotel_width, floor_thickness, corridor_length), true)
	_create_csg_box(parent, "CorridorCeiling", Vector3(hotel_center_x, ceil_y, corridor_center_z), Vector3(hotel_width, floor_thickness, corridor_length), true)

func _generate_outer_shell(parent: Node3D) -> void:
	var f_scale = GlobalConfig.get_floor_scale()
	var left_x = -10.75 * f_scale
	var right_x = 10.75 * f_scale
	var top_z = -30.0 * f_scale
	var bottom_z = 30.0 * f_scale
	
	var width = right_x - left_x
	var length = bottom_z - top_z
	var center_x = (left_x + right_x) / 2.0
	var center_z = (top_z + bottom_z) / 2.0
	
	_create_csg_box(parent, "OuterWall_West", Vector3(left_x - wall_thickness/2.0, corridor_height/2.0, center_z), Vector3(wall_thickness, corridor_height, length), false, false)
	_create_csg_box(parent, "OuterWall_East", Vector3(right_x + wall_thickness/2.0, corridor_height/2.0, center_z), Vector3(wall_thickness, corridor_height, length), false, false)
	_create_csg_box(parent, "OuterWall_North", Vector3(center_x, corridor_height/2.0, top_z - wall_thickness/2.0), Vector3(width + wall_thickness*2, corridor_height, wall_thickness), false, false)
	_create_csg_box(parent, "OuterWall_South", Vector3(center_x, corridor_height/2.0, bottom_z + wall_thickness/2.0), Vector3(width + wall_thickness*2, corridor_height, wall_thickness), false, false)

func _generate_rooms_side(f_num: int, parent: Node3D, is_left: bool, corridor_start_z: float, total_corridor_end: float) -> void:
	var prev_z = corridor_start_z
	var corridor_wall_shift = wall_thickness / 2.0
	var wall_x = (-corridor_width / 2.0 + corridor_wall_shift) if is_left else (corridor_width / 2.0 - corridor_wall_shift)
	var room_x = double_room_x if is_left else single_room_x
	var prefix = "DoubleRoomL_" if is_left else "SingleRoomR_"
	var side_str = "L_" if is_left else "R_"
	
	var rooms_data = HotelLevelCoordinates.get_left_rooms_data() if is_left else HotelLevelCoordinates.get_right_rooms_data()
	
	for i in range(rooms_data.size()):
		var data = rooms_data[i]
		var c_z = data["z"] * GlobalConfig.get_floor_scale()
		var is_flipped = data["flip"]
		var room_number = str(f_num) + data["name"].substr(1, 2)
		var room
		
		if is_left:
			room = double_room_large_scene.instantiate() if data["type"] == "large" else double_room_scene.instantiate()
			# HotelDoorGenerator.create_room_wc_door(room, Vector3(1.55, 0, -3.6), true)
		else:
			room = single_room_scene.instantiate()
			# HotelDoorGenerator.create_room_wc_door(room, Vector3(-2.2, 0, -0.25), false)
			
		room.name = prefix + room_number
		room.transform.origin = Vector3(room_x, room_y_offset, c_z)
		
		if is_flipped:
			room.scale.z = -1
			
		parent.add_child(room)
		room.owner = get_tree().edited_scene_root
		
		var lc = Node.new()
		lc.name = "RoomLightController"
		lc.set_script(preload("res://scripts/levels/rooms/room_light_controller.gd"))
		room.add_child(lc)
		lc.owner = get_tree().edited_scene_root
		
		var lm = Node.new()
		lm.name = "RoomLabelManager"
		lm.set_script(preload("res://scripts/levels/rooms/room_label_manager.gd"))
		room.add_child(lm)
		lm.owner = get_tree().edited_scene_root
		
		lm.room_number = room_number
		
		if "carpet_color" in room:
			room.carpet_color = carpet_color
			
	# Generate continuous corridor wall using CSG Subtraction from rooms
	var f_scale = GlobalConfig.get_floor_scale()
	var end_wall_z = -30.0 * f_scale if is_left else -20.0 * f_scale
	var wall_length = corridor_start_z - end_wall_z
	var wall_center_z = (corridor_start_z + end_wall_z) / 2.0
	
	_create_wall(parent, "CorrWall_Solid_" + side_str, Vector3(wall_x, 0, wall_center_z), wall_length)

func _generate_map_decals(parent: Node3D) -> void:
	# Place near the elevator (North end) where it's a solid wall on both sides
	var map_z = HotelLevelCoordinates.get_map_decal_z()
	var inner_wall_x = (corridor_width / 2.0) - (wall_thickness / 2.0)
	var decal_x = inner_wall_x - map_decal_wall_offset
	
	var decal_positions = [Vector3(-decal_x, map_decal_y_pos, map_z), Vector3(decal_x, map_decal_y_pos, map_z)]
	
	for i in range(decal_positions.size()):
		var pos = decal_positions[i]
		var map_decal = MeshInstance3D.new()
		# i == 0 is the map, i == 1 is the advertisement
		var is_map = (i == 0)
		map_decal.name = "MapDecal_" + str(i + 1) if is_map else "AdDecal_" + str(i + 1)
		map_decal.transform.origin = pos
		map_decal.transform.basis = Basis.from_euler(Vector3(0, PI/2 if pos.x < 0 else -PI/2, 0))
			
		var quad = QuadMesh.new()
		quad.size = map_decal_size
		var map_mat = StandardMaterial3D.new()
		
		if is_map:
			map_mat.albedo_texture = map_texture if map_texture else preload("res://assets/textures/hotel_map.jpg")
		else:
			map_mat.albedo_texture = ad_texture if ad_texture else preload("res://assets/textures/coca_cola.jpg")
			
		map_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		quad.material = map_mat
		map_decal.mesh = quad
		parent.add_child(map_decal)
		map_decal.owner = get_tree().edited_scene_root

func _generate_corridor_lights(parent: Node3D, start_z: float, end_z: float, f_num: int) -> void:
	var z = start_z - (double_room_step / 2.0)
	var i = 1
	while z >= end_z:
		var light = _create_light(parent, "CorridorLight_" + str(i), Vector3(0, corridor_height - 0.5, z), Color(1.0, 0.95, 0.9))
		light.visible = (f_num == 4)
		z -= double_room_step
		i += 1


# endregion

# region Block Generators

func _generate_north_block(parent: Node3D, start_z: float) -> void:
	var f_scale = GlobalConfig.get_floor_scale()
	
	_generate_elevator_shaft(parent)
	_generate_maintenance_room(parent)
		
	var stair = stairwell_scene.instantiate()
	stair.name = "Stairwell_N"
	stair.transform.basis = Basis.from_euler(Vector3(0, PI, 0))
	var stair_z = -27.5 * f_scale
	stair.transform.origin = Vector3(0, 0, stair_z)
	parent.add_child(stair)
	stair.owner = get_tree().edited_scene_root
	
	# Cap the North Stairs (between stairs and Horiz Corridor)
	_generate_stairwell_junction(parent, -25.0 * f_scale, true)
	
	# Horiz Corridor Top Wall (Separating Elevator and Horiz Corridor)
	# Spans from X = 3.0 to Maintenance room at X = 7.75
	var elev_w_start = 3.0 * f_scale
	var elev_w_end = 8.0 * f_scale
	var elev_w_center = (elev_w_start + elev_w_end) / 2.0
	_create_csg_box(parent, "ElevatorSouthWall", Vector3(elev_w_center, corridor_height / 2.0, -25.0 * f_scale - wall_thickness/2.0), Vector3(elev_w_end - elev_w_start, corridor_height, wall_thickness), false, false)

func _generate_south_block(parent: Node3D, stair_z: float) -> void:
	var f_scale = GlobalConfig.get_floor_scale()
	
	# Cap the vertical corridor at Z = 25.0
	_generate_stairwell_junction(parent, 25.0 * f_scale, false)
	
	var stairwell_south_scene = load("res://scenes/levels/hotel_siberia/stairwell_south.tscn")
	if stairwell_south_scene:
		var stair_inst = stairwell_south_scene.instantiate()
		stair_inst.name = "StairwellSouth"
		# Place it shifted right to cover both the corridor and room 421 space
		stair_inst.position = Vector3(3.875 * f_scale, 0, 27.5 * f_scale)
		parent.add_child(stair_inst)
		stair_inst.owner = get_tree().edited_scene_root
		
		# Generate the door into the south stairwell
		# var inst = HotelDoorGenerator.create_stairwell_door(parent, Vector3(0, 0, 25.0 * f_scale), 0, false)
		# if inst and Engine.is_editor_hint() and get_tree().edited_scene_root:
		# 	inst.owner = get_tree().edited_scene_root

func _generate_stairwell_junction(parent: Node3D, z_pos: float, is_north: bool) -> void:
	var prefix = "North" if is_north else "South"
	
	var wall_w = corridor_width + wall_thickness * 2.0
	var wall_h = corridor_height
	var wall_thick = wall_thickness
	
	var w_z = z_pos - (wall_thick / 2.0) if is_north else z_pos + (wall_thick / 2.0)
	
	var wall_node = _create_csg_box(parent, prefix + "StairwellJunctionWall", Vector3(0, wall_h / 2.0, w_z), Vector3(wall_w, wall_h, wall_thick), false, false)
	
	var hole_width = room_door_opening_width
	var hole_height = util_door_height
	var hole_y = hole_height / 2.0
	_create_csg_hole(wall_node, prefix + "StairwellJunctionHole", Vector3(0, hole_y - (wall_h / 2.0), 0), Vector3(hole_width, hole_height, wall_thick + room_hole_margin))
	
	if is_north:
		pass
		# var inst = HotelDoorGenerator.create_stairwell_door(parent, Vector3(0, 0, z_pos), PI, true)
		# if inst and Engine.is_editor_hint() and get_tree().edited_scene_root:
		# 	inst.owner = get_tree().edited_scene_root


func _generate_elevator_shaft(parent: Node3D) -> void:
	if not elevator_shaft_scene: return
	var elev_z = HotelLevelCoordinates.get_elevator_z()
	var inst = elevator_shaft_scene.instantiate()
	inst.name = "ElevatorShaftBlock"
	inst.rotation_degrees.y = 180
	# Placed in the space between North Stairs and Maint Room
	inst.transform.origin = Vector3(5.5 * GlobalConfig.get_floor_scale(), 0, elev_z)
	# HotelDoorGenerator.create_elevator_door(inst, Vector3.ZERO)
	parent.add_child(inst)
	inst.owner = get_tree().edited_scene_root

func _generate_maintenance_room(parent: Node3D) -> void:
	if not maintenance_room_scene: return
	var maint_z = HotelLevelCoordinates.get_maintenance_z()
	var inst = maintenance_room_scene.instantiate()
	inst.name = "MaintenanceRoomBlock"
	# Placed on the far right edge
	inst.transform.origin = Vector3(9.25 * GlobalConfig.get_floor_scale(), 0, maint_z)
	parent.add_child(inst)
	inst.owner = get_tree().edited_scene_root

# endregion
