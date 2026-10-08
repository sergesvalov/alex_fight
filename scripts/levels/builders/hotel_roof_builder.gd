class_name HotelRoofBuilder
extends RefCounted


static func generate_roof(generator: HotelLevelGenerator, y_offset: float, f_scale: float) -> void:
	var parent = Node3D.new()
	parent.name = "GeneratedRoof"
	parent.position.y = y_offset
	generator.add_child(parent)
	
	var z_length = HotelConstants.BUILDING_LENGTH_Z * f_scale
	var x_width = HotelConstants.BUILDING_WIDTH_X * f_scale
	var thickness = generator.wall_thickness * f_scale
	var floor_thick = generator.floor_thickness * f_scale

	var half_x = x_width / 2.0

	var roof_mat = StandardMaterial3D.new()
	var roof_tex = HotelLevelGenerator._load_texture_safe("res://assets/textures/roof_concrete.jpg")
	if roof_tex:
		roof_mat.albedo_texture = roof_tex
		roof_mat.uv1_scale = Vector3(10, 10, 10)
	else:
		roof_mat.albedo_color = Color(0.8, 0.8, 0.8)
	
	# Roof slabs (same logic as floor slabs)
	var floor_y = -floor_thick / 2.0
	var z_south_len = 55.18 * f_scale
	var z_south_pos = 2.41 * f_scale
	var z_north_len = 4.82 * f_scale
	var z_north_pos = -27.59 * f_scale
	
	var x_nw_east = HotelConstants.NORTH_ZONE_INNER_X * f_scale
	var x_nw_len = x_nw_east + half_x
	var x_nw_pos = (x_nw_east - half_x) / 2.0
	var x_ne_len = 8.0 * f_scale
	var x_ne_pos = 8.65 * f_scale

	# The main slab stops at the south stairs zone: the part of that zone over the upper ramp
	# (X HotelConstants.SOUTH_STAIRS_RAMP_INNER_X..LANDING_INNER_X, the southern half of the zone) is left open,
	# so the top flight of floor 10's south stairs comes out onto the roof instead of running
	# into the underside of the slab.
	var half_z_roof = z_length / 2.0
	var z_stairs_mid = (HotelConstants.SOUTH_STAIRS_ZONE_Z_START + HotelConstants.SOUTH_STAIRS_ZONE_Z_END) / 2.0 * f_scale
	var z_main_north = z_south_pos - z_south_len / 2.0
	var x_ramp_west = HotelConstants.SOUTH_STAIRS_RAMP_INNER_X * f_scale
	var x_ramp_east = HotelConstants.SOUTH_STAIRS_LANDING_INNER_X * f_scale
	HotelSpecialFloorBuilder.create_static_box(parent, "Roof_Main", Vector3(0, floor_y, (z_main_north + z_stairs_mid) / 2.0), Vector3(x_width, floor_thick, z_stairs_mid - z_main_north), roof_mat)
	HotelSpecialFloorBuilder.create_static_box(parent, "Roof_SW", Vector3((x_ramp_west - half_x) / 2.0, floor_y, (z_stairs_mid + half_z_roof) / 2.0), Vector3(x_ramp_west + half_x, floor_thick, half_z_roof - z_stairs_mid), roof_mat)
	HotelSpecialFloorBuilder.create_static_box(parent, "Roof_SE", Vector3((x_ramp_east + half_x) / 2.0, floor_y, (z_stairs_mid + half_z_roof) / 2.0), Vector3(half_x - x_ramp_east, floor_thick, half_z_roof - z_stairs_mid), roof_mat)
	HotelSpecialFloorBuilder.create_static_box(parent, "Roof_NW", Vector3(x_nw_pos, floor_y, z_north_pos), Vector3(x_nw_len, floor_thick, z_north_len), roof_mat)
	HotelSpecialFloorBuilder.create_static_box(parent, "Roof_NE", Vector3(x_ne_pos, floor_y, z_north_pos), Vector3(x_ne_len, floor_thick, z_north_len), roof_mat)

	# Parapets (Outer walls)
	var parapet_height = 1.0 * f_scale + floor_thick
	var parapet_y = (1.0 * f_scale - floor_thick) / 2.0
	var half_z = z_length / 2.0

	HotelSpecialFloorBuilder.create_static_box(parent, "Parapet_West", Vector3(-half_x - thickness/2.0, parapet_y, 0), Vector3(thickness, parapet_height, z_length), roof_mat)
	HotelSpecialFloorBuilder.create_static_box(parent, "Parapet_East", Vector3(half_x + thickness/2.0, parapet_y, 0), Vector3(thickness, parapet_height, z_length), roof_mat)
	HotelSpecialFloorBuilder.create_static_box(parent, "Parapet_North", Vector3(0, parapet_y, -half_z - thickness/2.0), Vector3(x_width + thickness * 2.0, parapet_height, thickness), roof_mat)
	HotelSpecialFloorBuilder.create_static_box(parent, "Parapet_South", Vector3(0, parapet_y, half_z + thickness/2.0), Vector3(x_width + thickness * 2.0, parapet_height, thickness), roof_mat)

	build_roof_structures(generator, parent, f_scale, roof_mat)


# What stands on the roof: a bulkhead over each stairwell (so the stairs come out through a
# door instead of an open hole in the slab) and the elevator machine room over the lift shaft,
# with the code plate inside. Coordinates are the roof node's own - Y=0 is the roof surface.
const ROOF_ROOM_HEIGHT: float = 2.6
const ROOF_FLOOR_INDEX: int = 11 # what stairs_gate.gd / GameStateManager call the roof

static func build_roof_structures(_generator: HotelLevelGenerator, parent: Node3D, f_scale: float, mat: Material) -> void:
	var hh: float = HotelRoofBuilder.ROOF_ROOM_HEIGHT
	var door_w: float = 1.2 * f_scale
	var door_h: float = 2.2 * f_scale
	var door_scene = load("res://entities/props/door.tscn")
	var gate_script = load("res://scripts/levels/blocks/stairs_gate.gd")
	# A box given by its extents (unscaled meters) rather than by center and size.
	var box = func(box_name: String, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float) -> void:
		HotelSpecialFloorBuilder.create_static_box(parent, box_name, Vector3((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0) * f_scale,
			Vector3(absf(x1 - x0), absf(y1 - y0), absf(z1 - z0)) * f_scale, mat)
	var add_door = func(door_name: String, pos: Vector3, rot_y: float) -> void:
		if not door_scene:
			return
		var door_inst = door_scene.instantiate()
		door_inst.name = door_name
		door_inst.position = pos * f_scale
		door_inst.rotation.y = rot_y
		door_inst.scale = Vector3(door_w, f_scale, f_scale)
		parent.add_child(door_inst)
	# The same floor-lock gate every stairwell door has. The roof counts as "floor 11", which
	# floor 10's tapes unlock (see _on_all_tapes_collected()); until then stepping through
	# puts the player back on floor 10, exactly like any other locked floor.
	var add_gate = func(gate_name: String, pos: Vector3, rot_y: float) -> void:
		var gate = Area3D.new()
		gate.name = gate_name
		gate.collision_layer = 0
		gate.collision_mask = 1 # Player layer
		gate.set_script(gate_script)
		gate.floor_num = HotelRoofBuilder.ROOF_FLOOR_INDEX
		gate.y_step = HotelConstants.BASE_FLOOR_TO_FLOOR_HEIGHT * f_scale
		gate.position = (pos + Vector3(0, 1.1, 0)) * f_scale
		gate.rotation.y = rot_y
		var gate_coll = CollisionShape3D.new()
		var gate_shape = BoxShape3D.new()
		gate_shape.size = Vector3(door_w, door_h, 1.0 * f_scale)
		gate_coll.shape = gate_shape
		gate.add_child(gate_coll)
		parent.add_child(gate)

	# --- North stairs bulkhead, over the stairwell hole (X -2.65..4.75, Z -30..-25.1). Its door
	# is where every floor's own "west" stair door is (X = HotelConstants.NORTH_STAIRS_CENTER_X - 2.8): that is
	# where floor 10's top flight arrives. ---
	var nx0: float = HotelConstants.NORTH_STAIRS_CENTER_X - 3.8
	var nx1: float = HotelConstants.NORTH_STAIRS_CENTER_X + 3.8
	var nz0: float = -HotelConstants.BUILDING_LENGTH_Z / 2.0
	var nz1: float = -25.1
	var ndoor: float = HotelConstants.NORTH_STAIRS_CENTER_X - 2.8
	box.call("NorthExit_West", nx0, nx0 + 0.2, 0.0, hh, nz0, nz1)
	box.call("NorthExit_East", nx1 - 0.2, nx1, 0.0, hh, nz0, nz1)
	box.call("NorthExit_North", nx0, nx1, 0.0, hh, nz0, nz0 + 0.2)
	box.call("NorthExit_SouthA", nx0, ndoor - 0.6, 0.0, hh, nz1 - 0.1, nz1 + 0.1)
	box.call("NorthExit_SouthB", ndoor + 0.6, nx1, 0.0, hh, nz1 - 0.1, nz1 + 0.1)
	box.call("NorthExit_Lintel", ndoor - 0.6, ndoor + 0.6, 2.2, hh, nz1 - 0.1, nz1 + 0.1)
	box.call("NorthExit_Cap", nx0, nx1, hh, hh + 0.2, nz0, nz1 + 0.1)
	add_door.call("NorthExitDoor", Vector3(ndoor, 0, nz1), 0.0) # basis.z -> +Z, out onto the roof
	add_gate.call("NorthExitGate", Vector3(ndoor, 0, nz1), 0.0)

	# --- South stairs bulkhead, over the opening left in the slab above the upper ramp. The
	# ramp climbs west and arrives at X = HotelConstants.SOUTH_STAIRS_RAMP_INNER_X, so the door is in the west
	# side, opening west onto Roof_SW. ---
	var sx0: float = HotelConstants.SOUTH_STAIRS_RAMP_INNER_X
	var sx1: float = HotelConstants.SOUTH_STAIRS_LANDING_INNER_X
	var sz0: float = (HotelConstants.SOUTH_STAIRS_ZONE_Z_START + HotelConstants.SOUTH_STAIRS_ZONE_Z_END) / 2.0
	var sz1: float = HotelConstants.SOUTH_STAIRS_ZONE_Z_END
	var sdoor: float = (sz0 + sz1) / 2.0
	box.call("SouthExit_North", sx0, sx1, 0.0, hh, sz0 - 0.2, sz0)
	box.call("SouthExit_South", sx0, sx1, 0.0, hh, sz1 - 0.2, sz1)
	box.call("SouthExit_East", sx1, sx1 + 0.2, 0.0, hh, sz0 - 0.2, sz1)
	box.call("SouthExit_WestA", sx0 - 0.1, sx0 + 0.1, 0.0, hh, sz0 - 0.2, sdoor - 0.6)
	box.call("SouthExit_WestB", sx0 - 0.1, sx0 + 0.1, 0.0, hh, sdoor + 0.6, sz1)
	box.call("SouthExit_Lintel", sx0 - 0.1, sx0 + 0.1, 2.2, hh, sdoor - 0.6, sdoor + 0.6)
	box.call("SouthExit_Cap", sx0 - 0.1, sx1 + 0.2, hh, hh + 0.2, sz0 - 0.2, sz1)
	add_door.call("SouthExitDoor", Vector3(sx0, 0, sdoor), -PI / 2.0) # basis.z -> -X, out onto the roof
	add_gate.call("SouthExitGate", Vector3(sx0, 0, sdoor), -PI / 2.0)

	# --- Elevator machine room, over the lift shaft (shaft interior X 4.95..9.45, Z -30..-25).
	# An ordinary room on the roof: a door, no floor gate. ---
	var mx0: float = HotelConstants.ELEVATOR_CENTER_X - 2.0
	var mx1: float = HotelConstants.ELEVATOR_CENTER_X + 2.0
	var mz0: float = -29.6
	var mz1: float = -26.0
	box.call("MachineRoom_West", mx0, mx0 + 0.2, 0.0, hh, mz0, mz1)
	box.call("MachineRoom_East", mx1 - 0.2, mx1, 0.0, hh, mz0, mz1)
	box.call("MachineRoom_North", mx0, mx1, 0.0, hh, mz0, mz0 + 0.2)
	box.call("MachineRoom_SouthA", mx0, HotelConstants.ELEVATOR_CENTER_X - 0.6, 0.0, hh, mz1 - 0.1, mz1 + 0.1)
	box.call("MachineRoom_SouthB", HotelConstants.ELEVATOR_CENTER_X + 0.6, mx1, 0.0, hh, mz1 - 0.1, mz1 + 0.1)
	box.call("MachineRoom_Lintel", HotelConstants.ELEVATOR_CENTER_X - 0.6, HotelConstants.ELEVATOR_CENTER_X + 0.6, 2.2, hh, mz1 - 0.1, mz1 + 0.1)
	box.call("MachineRoom_Cap", mx0, mx1, hh, hh + 0.2, mz0, mz1 + 0.1)
	add_door.call("MachineRoomDoor", Vector3(HotelConstants.ELEVATOR_CENTER_X, 0, mz1), 0.0)

	var room_light = OmniLight3D.new()
	room_light.name = "MachineRoomLight"
	room_light.light_color = Color(1.0, 0.25, 0.15) # emergency red
	room_light.light_energy = 1.2
	room_light.omni_range = 5.0 * f_scale
	room_light.position = Vector3(HotelConstants.ELEVATOR_CENTER_X, 2.2, (mz0 + mz1) / 2.0) * f_scale
	parent.add_child(room_light)

	# The code plate on the back wall - see roof_code_plate.gd.
	var plate = Area3D.new()
	plate.name = "LiftCodePlate"
	plate.collision_layer = 4 # same layer vhs_tape.tscn uses - the interact raycast's mask
	plate.collision_mask = 0
	plate.set_script(load("res://scripts/interactables/roof_code_plate.gd"))
	plate.position = Vector3(HotelConstants.ELEVATOR_CENTER_X, 1.4, mz0 + 0.26) * f_scale
	var plate_coll = CollisionShape3D.new()
	var plate_shape = BoxShape3D.new()
	plate_shape.size = Vector3(0.9, 0.6, 0.2) * f_scale
	plate_coll.shape = plate_shape
	plate.add_child(plate_coll)
	var plate_mesh = MeshInstance3D.new()
	var plate_box = BoxMesh.new()
	plate_box.size = Vector3(0.8, 0.5, 0.04) * f_scale
	var plate_mat = StandardMaterial3D.new()
	plate_mat.albedo_color = Color(0.55, 0.5, 0.2)
	plate_mat.metallic = 0.6
	plate_mat.roughness = 0.5
	plate_box.material = plate_mat
	plate_mesh.mesh = plate_box
	plate.add_child(plate_mesh)
	var plate_text = Label3D.new()
	plate_text.name = "Text"
	plate_text.font_size = 40
	plate_text.modulate = Color(0.05, 0.05, 0.05)
	plate_text.outline_size = 0
	plate_text.position = Vector3(0, 0, 0.03) * f_scale
	plate.add_child(plate_text)
	parent.add_child(plate)

