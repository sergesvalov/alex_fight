@tool
extends HotelLevelGeneratorBase
class_name HotelLevelGeneratorGeometry

# region Corridor Shell & Rooms

func _generate_corridor_shell(parent: Node3D, corridor_start_z: float, total_corridor_end: float) -> void:
	var corridor_length = corridor_start_z - total_corridor_end
	var corridor_center_z = (corridor_start_z + total_corridor_end) / 2.0
	
	var floor_y = -floor_thickness / 2.0
	var ceil_y = corridor_height + (floor_thickness / 2.0)
	
	var hotel_width = 22.35 * GlobalConfig.get_floor_scale()
	var hotel_center_x = -0.175 * GlobalConfig.get_floor_scale()
	
	_create_csg_box(parent, "CorridorFloor", Vector3(hotel_center_x, floor_y, corridor_center_z), Vector3(hotel_width, floor_thickness, corridor_length), true)
	_create_csg_box(parent, "CorridorCeiling", Vector3(hotel_center_x, ceil_y, corridor_center_z), Vector3(hotel_width, floor_thickness, corridor_length), true)

func _generate_rooms_side(f_num: int, parent: Node3D, is_left: bool, corridor_start_z: float, total_corridor_end: float) -> void:
	var prev_z = corridor_start_z
	var corridor_wall_shift = wall_thickness / 2.0
	var wall_x = (-corridor_width / 2.0 + corridor_wall_shift) if is_left else (corridor_width / 2.0 - corridor_wall_shift)
	var room_x = double_room_x if is_left else single_room_x
	var prefix = "DoubleRoomL_" if is_left else "SingleRoomR_"
	var side_str = "L_" if is_left else "R_"
	
	var left_rooms_data = [
		{"name": "408", "z": 5.0,   "type": "normal", "flip": true},
		{"name": "406", "z": -5.0,  "type": "normal", "flip": false},
		{"name": "405", "z": -15.0, "type": "normal", "flip": false},
		{"name": "403", "z": -25.0, "type": "normal", "flip": false},
		{"name": "402", "z": -41.0, "type": "large",  "flip": false},
		{"name": "401", "z": -51.0, "type": "large",  "flip": false},
	]

	var right_rooms_data = [
		{"name": "421", "z": 7.0,   "flip": false},
		{"name": "420", "z": 1.0,   "flip": true},
		{"name": "417", "z": -9.0,  "flip": true},
		{"name": "416", "z": -15.0, "flip": false},
		{"name": "415", "z": -21.0, "flip": true},
		{"name": "413", "z": -27.0, "flip": false},
		{"name": "412", "z": -33.0, "flip": false},
		{"name": "411", "z": -39.0, "flip": false},
		{"name": "410", "z": -45.0, "flip": false},
	]
	
	var rooms_data = left_rooms_data if is_left else right_rooms_data
	
	for i in range(rooms_data.size()):
		var data = rooms_data[i]
		var c_z = data["z"] * GlobalConfig.get_floor_scale()
		var is_flipped = data["flip"]
		var room_number = str(f_num) + data["name"].substr(1, 2)
		var room
		
		if is_left:
			room = double_room_large_scene.instantiate() if data["type"] == "large" else double_room_scene.instantiate()
			HotelDoorGenerator.create_room_main_door(room, Vector3(4.3, 0, 0.5), true)
			HotelDoorGenerator.create_room_wc_door(room, Vector3(1.55, 0, -3.6), true)
		else:
			room = single_room_scene.instantiate()
			HotelDoorGenerator.create_room_main_door(room, Vector3(-3.05, 0, -0.25), false)
			HotelDoorGenerator.create_room_wc_door(room, Vector3(-2.2, 0, -0.25), false)
			
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
			
		var flip_mult = -1.0 if is_flipped else 1.0
		var current_door_offset = (room_door_z_offset if is_left else -0.25 * GlobalConfig.get_floor_scale()) * flip_mult
		var half_opening = room_door_opening_width / 2.0
		var door_center_z = c_z + current_door_offset
		var door_top_z = door_center_z + half_opening
		var door_bottom_z = door_center_z - half_opening
		
		if prev_z > door_top_z:
			_create_wall(parent, "CorrWall_" + side_str + str(i), Vector3(wall_x, 0, (prev_z + door_top_z) / 2.0), prev_z - door_top_z)
			
		var lintel_height = corridor_height - room_door_height
		if lintel_height > 0.01:
			var lintel_y = room_door_height + lintel_height / 2.0
			_create_csg_box(parent, "CorrWall_" + side_str + "Lintel_" + str(i), Vector3(wall_x, lintel_y, door_center_z), Vector3(wall_thickness, lintel_height, room_door_opening_width), false, false)

		prev_z = door_bottom_z
		
	var end_wall_z = total_corridor_end
	if not is_left:
		# The right side has a side corridor (alcove) from -48.0 to -56.0 for Maintenance and Elevator
		end_wall_z = -48.0 * GlobalConfig.get_floor_scale()
		
	if prev_z > end_wall_z:
		_create_wall(parent, "CorrWall_" + side_str + "end", Vector3(wall_x, 0, (end_wall_z + prev_z) / 2.0), prev_z - end_wall_z)

func _generate_map_decals(parent: Node3D) -> void:
	# Place near the elevator (North end, Z=-42.5) where it's a solid wall on both sides
	var map_z = -42.5 * GlobalConfig.get_floor_scale()
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
	_generate_elevator_shaft(parent)
	_generate_maintenance_room(parent)
		
	var stair = stairwell_scene.instantiate()
	stair.name = "Stairwell_N"
	stair.transform.basis = Basis.from_euler(Vector3(0, PI, 0))
	stair.transform.origin = Vector3(0, 0, start_z)
	parent.add_child(stair)
	stair.owner = get_tree().edited_scene_root
	
	_generate_stairwell_junction(parent, start_z, true)

func _generate_south_block(parent: Node3D, stair_z: float) -> void:
	var stairwell_south_scene = load("res://scenes/levels/hotel_siberia/stairwell_south.tscn")
	if stairwell_south_scene:
		var stair_inst = stairwell_south_scene.instantiate()
		stair_inst.name = "StairwellSouth"
		stair_inst.rotation_degrees.y = -90
		var side_x = (corridor_width / 2.0) + (side_corridor_depth / 2.0)
		var stair_z_pos = -4.0 * GlobalConfig.get_floor_scale()
		stair_inst.position = Vector3(side_x, 0, stair_z_pos)
		parent.add_child(stair_inst)
		stair_inst.owner = get_tree().edited_scene_root
		
		# Cut hole in the automatically generated corridor wall for the stairs
		var w_x = corridor_width / 2.0 - wall_thickness / 2.0
		var hole_width = room_door_opening_width
		var hole_height = util_door_height
		var hole_y = hole_height / 2.0
		_create_csg_hole(parent, "SouthStairJunctionHole", Vector3(w_x, hole_y, stair_z_pos), Vector3(wall_thickness + room_hole_margin, hole_height, hole_width))
		
		var inst = HotelDoorGenerator.create_stairwell_door(parent, Vector3(w_x, 0, stair_z_pos), -PI/2.0, false)
		if inst and Engine.is_editor_hint() and get_tree().edited_scene_root:
			inst.owner = get_tree().edited_scene_root

	# Cap the south end of the corridor with a solid wall
	var wall_w = corridor_width + wall_thickness * 2.0
	var wall_h = corridor_height
	var wall_thick = wall_thickness
	var w_z = 10.0 * GlobalConfig.get_floor_scale() + (wall_thick / 2.0)
	_create_csg_box(parent, "SouthEndWall", Vector3(0, wall_h / 2.0, w_z), Vector3(wall_w, wall_h, wall_thick), false, false)

func _generate_stairwell_junction(parent: Node3D, z_pos: float, is_north: bool) -> void:
	var prefix = "North" if is_north else "South"
	
	var wall_w = 7.0
	var wall_h = corridor_height
	var wall_thick = wall_thickness
	
	var w_z = z_pos - (wall_thick / 2.0) if is_north else z_pos + (wall_thick / 2.0)
	
	var wall_node = _create_csg_box(parent, prefix + "StairwellJunctionWall", Vector3(0, wall_h / 2.0, w_z), Vector3(wall_w, wall_h, wall_thick), false, false)
	
	var hole_width = room_door_opening_width
	var hole_height = util_door_height
	var hole_y = hole_height / 2.0
	_create_csg_hole(wall_node, prefix + "StairwellJunctionHole", Vector3(0, hole_y - (wall_h / 2.0), 0), Vector3(hole_width, hole_height, wall_thick + room_hole_margin))
	
	var inst = HotelDoorGenerator.create_stairwell_door(parent, Vector3(0, 0, z_pos), PI if is_north else 0.0, is_north)
	if inst and Engine.is_editor_hint() and get_tree().edited_scene_root:
		inst.owner = get_tree().edited_scene_root


func _generate_elevator_shaft(parent: Node3D) -> void:
	if not elevator_shaft_scene: return
	var elev_z = -54.0 * GlobalConfig.get_floor_scale()
	var elev_x_center = (corridor_width / 2.0) + (side_corridor_depth / 2.0)
	var inst = elevator_shaft_scene.instantiate()
	inst.name = "ElevatorShaftBlock"
	inst.transform.origin = Vector3(elev_x_center, 0, elev_z)
	HotelDoorGenerator.create_elevator_door(inst, Vector3.ZERO)
	parent.add_child(inst)
	inst.owner = get_tree().edited_scene_root

func _generate_maintenance_room(parent: Node3D) -> void:
	if not maintenance_room_scene: return
	var maint_z = -50.0 * GlobalConfig.get_floor_scale()
	var east_wall_x = (corridor_width / 2.0) + side_corridor_depth
	var inst = maintenance_room_scene.instantiate()
	inst.name = "MaintenanceRoomBlock"
	inst.transform.origin = Vector3(east_wall_x, 0, maint_z)
	parent.add_child(inst)
	inst.owner = get_tree().edited_scene_root

# endregion
