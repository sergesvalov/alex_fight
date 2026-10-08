class_name HotelGeometryBuilder
extends RefCounted

const FloorMap = preload("res://scripts/levels/floor_map.gd")


static func build_floor_geometry(generator, f_num: int, y_offset: float, suffix: String, c_color: Color, is_empty: bool, f_scale: float) -> Node3D:
	var parent = Node3D.new()
	parent.name = "GeneratedFloor_" + suffix
	parent.position.y = y_offset
	generator.add_child(parent)
	
	var z_length = HotelConstants.BUILDING_LENGTH_Z * f_scale
	var x_width = HotelConstants.BUILDING_WIDTH_X * f_scale
	var height = generator.corridor_height * f_scale
	var thickness = generator.wall_thickness * f_scale
	var floor_thick = generator.floor_thickness * f_scale

	var half_x = x_width / 2.0

	var floor_y = -floor_thick / 2.0
	# Pull ceiling down by CEIL_BIAS so its top face is never co-planar with
	# the bottom face of the floor slab one storey above (Android Z-fighting fix).
	var ceil_y = height + (floor_thick / 2.0) - HotelLevelGenerator.CEIL_BIAS
	
	var floor_mat = StandardMaterial3D.new()
	if not is_empty:
		floor_mat.albedo_texture = generator.carpet_texture
	floor_mat.albedo_color = c_color
	floor_mat.uv1_scale = Vector3(10, 10, 10)
	# Force depth writes on gl_compatibility to prevent texture flickering on Android.
	floor_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	
	var ceil_mat = StandardMaterial3D.new()
	ceil_mat.albedo_texture = generator.ceiling_texture
	ceil_mat.uv1_scale = Vector3(10, 10, 10)
	# Force depth writes and explicit backface culling to prevent bleed-through on Android.
	ceil_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	ceil_mat.cull_mode = BaseMaterial3D.CULL_BACK
	
	var wall_mat = StandardMaterial3D.new()
	if f_num == 1:
		wall_mat.albedo_texture = generator.retro_wall_texture
	else:
		wall_mat.albedo_texture = generator.wall_texture
	wall_mat.uv1_scale = Vector3(15, 3, 1)
	wall_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS

	# 1 & 2. Floor and Ceiling (Split into parts to leave holes for North and South Stairs)
	var z_main_len = 50.18 * f_scale
	var z_main_pos = -0.09 * f_scale
	
	var z_north_len = 4.82 * f_scale
	var z_north_pos = -27.59 * f_scale
	var x_nw_east = HotelConstants.NORTH_ZONE_INNER_X * f_scale
	var x_nw_len = x_nw_east + half_x
	var x_nw_pos = (x_nw_east - half_x) / 2.0
	var x_ne_len = 8.0 * f_scale
	var x_ne_pos = 8.65 * f_scale

	var z_sw_len = (HotelConstants.SOUTH_STAIRS_ZONE_Z_END - HotelConstants.SOUTH_STAIRS_ZONE_Z_START) * f_scale
	var z_sw_pos = (HotelConstants.SOUTH_STAIRS_ZONE_Z_START + HotelConstants.SOUTH_STAIRS_ZONE_Z_END) / 2.0 * f_scale
	var x_sw_east = HotelConstants.SOUTH_STAIRS_RAMP_INNER_X * f_scale
	var x_sw_len = x_sw_east + half_x
	var x_sw_pos = (x_sw_east - half_x) / 2.0

	# Central Main (covers everything from Z=-25.18 to Z=25.0)
	HotelSpecialFloorBuilder.create_static_box(parent, "Floor_Main", Vector3(0, floor_y, z_main_pos), Vector3(x_width, floor_thick, z_main_len), floor_mat)
	HotelSpecialFloorBuilder.create_static_box(parent, "Ceiling_Main", Vector3(0, ceil_y, z_main_pos), Vector3(x_width, floor_thick, z_main_len), ceil_mat)

	# The main slab as an occluder: it has no holes (both stairwells are cut out of the separate
	# N/S slabs), so everything on the floor below is hidden behind it.
	var slab_occluder = OccluderInstance3D.new()
	slab_occluder.name = "Occluder_FloorMain"
	var slab_box = BoxOccluder3D.new()
	slab_box.size = Vector3(x_width, floor_thick, z_main_len)
	slab_occluder.occluder = slab_box
	slab_occluder.position = Vector3(0, floor_y, z_main_pos)
	parent.add_child(slab_occluder)

	# South West (covers Z=25.0 to 30.0, X=-12.65 to 1.87)
	HotelSpecialFloorBuilder.create_static_box(parent, "Floor_SW", Vector3(x_sw_pos, floor_y, z_sw_pos), Vector3(x_sw_len, floor_thick, z_sw_len), floor_mat)
	HotelSpecialFloorBuilder.create_static_box(parent, "Ceiling_SW", Vector3(x_sw_pos, ceil_y, z_sw_pos), Vector3(x_sw_len, floor_thick, z_sw_len), ceil_mat)
	
	# South Stairs Intermediate Landing (East side). y_landing is the box CENTER, not its
	# walkable surface - the surface sits floor_thick/2 above center, at
	# y_landing + floor_thick/2 = height/2 + floor_thick/2 = (height+floor_thick)/2, which is
	# the true midpoint between this floor's surface (Y=0) and the floor-above's (Y=height+
	# floor_thick). (A previous version set y_landing = (height+floor_thick)/2 directly,
	# mistaking the desired *surface* height for the box's center - that left the landing
	# floor_thick/2 (~0.15-0.25m) too high, forming an unwalkable step where the ramps meet it.)
	var x_landing_len = (HotelConstants.SOUTH_STAIRS_LANDING_OUTER_X - HotelConstants.SOUTH_STAIRS_LANDING_INNER_X) * f_scale
	var x_landing_pos = (HotelConstants.SOUTH_STAIRS_LANDING_INNER_X + HotelConstants.SOUTH_STAIRS_LANDING_OUTER_X) / 2.0 * f_scale
	var y_landing = height / 2.0
	HotelSpecialFloorBuilder.create_static_box(parent, "Landing_SouthStairs", Vector3(x_landing_pos, y_landing, z_sw_pos), Vector3(x_landing_len, floor_thick, z_sw_len), floor_mat)

	# Landing checkpoint (see stairs_gate.gd) - a second floor-lock check on this flat landing,
	# roughly halfway up the flight. Independent of stairs_fall_catcher.gd (that one catches
	# falling through open air on North Stairs specifically) - this instead catches a player who
	# slips slightly past the South Stairs door gate while still walking on solid ground, same
	# "went a bit below/above a locked floor - bounce back" idea, just checked a second time on
	# the one flat spot every up/down trip through this staircase is guaranteed to cross. Skipped
	# on floor 1 (is_empty) like the door/wall/ramp themselves - see the is_empty check a few
	# lines below in this same function.
	if not is_empty:
		var landing_gate = Area3D.new()
		landing_gate.name = "SouthStairsLandingGate"
		landing_gate.collision_layer = 0
		landing_gate.collision_mask = 1 # Player layer
		landing_gate.set_script(load("res://scripts/levels/blocks/stairs_gate.gd"))
		landing_gate.floor_num = f_num
		landing_gate.y_step = HotelConstants.BASE_FLOOR_TO_FLOOR_HEIGHT * f_scale
		landing_gate.position = Vector3(x_landing_pos, y_landing + floor_thick / 2.0 + 1.1, z_sw_pos)

		var landing_gate_coll = CollisionShape3D.new()
		var landing_gate_shape = BoxShape3D.new()
		landing_gate_shape.size = Vector3(x_landing_len, 2.2, z_sw_len)
		landing_gate_coll.shape = landing_gate_shape
		landing_gate.add_child(landing_gate_coll)
		parent.add_child(landing_gate)

	# North West (covers Z=-30.0 to -25.2, X=-12.65 to -2.55)
	HotelSpecialFloorBuilder.create_static_box(parent, "Floor_NW", Vector3(x_nw_pos, floor_y, z_north_pos), Vector3(x_nw_len, floor_thick, z_north_len), floor_mat)
	HotelSpecialFloorBuilder.create_static_box(parent, "Ceiling_NW", Vector3(x_nw_pos, ceil_y, z_north_pos), Vector3(x_nw_len, floor_thick, z_north_len), ceil_mat)
	
	# North East (covers Z=-30.0 to -25.2, X=4.65 to 12.65)
	HotelSpecialFloorBuilder.create_static_box(parent, "Floor_NE", Vector3(x_ne_pos, floor_y, z_north_pos), Vector3(x_ne_len, floor_thick, z_north_len), floor_mat)
	HotelSpecialFloorBuilder.create_static_box(parent, "Ceiling_NE", Vector3(x_ne_pos, ceil_y, z_north_pos), Vector3(x_ne_len, floor_thick, z_north_len), ceil_mat)
	
	# 3. Outer Walls
	var half_z = z_length / 2.0

	var outer_wall_height = height + floor_thick
	var outer_wall_y = (height - floor_thick) / 2.0

	HotelSpecialFloorBuilder.create_static_box(parent, "Wall_West", Vector3(-half_x - thickness/2.0, outer_wall_y, 0), Vector3(thickness, outer_wall_height, z_length), wall_mat)
	HotelSpecialFloorBuilder.create_static_box(parent, "Wall_East", Vector3(half_x + thickness/2.0, outer_wall_y, 0), Vector3(thickness, outer_wall_height, z_length), wall_mat)
	HotelSpecialFloorBuilder.create_static_box(parent, "Wall_North", Vector3(0, outer_wall_y, -half_z - thickness/2.0), Vector3(x_width + thickness * 2.0, outer_wall_height, thickness), wall_mat)
	HotelSpecialFloorBuilder.create_static_box(parent, "Wall_South", Vector3(0, outer_wall_y, half_z + thickness/2.0), Vector3(x_width + thickness * 2.0, outer_wall_height, thickness), wall_mat)
	
	if f_num == 1:
		HotelSpecialFloorBuilder.create_static_box(parent, "Floor_NorthStairs", Vector3(HotelConstants.NORTH_STAIRS_CENTER_X * f_scale, floor_y, -27.6 * f_scale), Vector3(7.6 * f_scale, floor_thick, 4.8 * f_scale), floor_mat)
		
		# Fill the South Stairs hole for the ground floor
		var x_se_len = 10.78 * f_scale
		var x_se_pos = 7.26 * f_scale
		HotelSpecialFloorBuilder.create_static_box(parent, "Floor_SouthStairs", Vector3(x_se_pos, floor_y, z_sw_pos), Vector3(x_se_len, floor_thick, z_sw_len), floor_mat)

	# 3.6 Elevator
	HotelBlockBuilder.generate_elevator(generator, parent, f_scale)
	
	# 3.7 North Stairs
	HotelBlockBuilder.generate_north_stairs(generator, parent, f_scale, f_num)

	if is_empty:
		# Floor 1 has no rooms - it is the lobby. It still needs its own flight of the south
		# stairs (the "second staircase" at the far end of the hall), which the furnished
		# floors get further down.
		generator._generate_south_stairs_wall(parent, f_scale, height, thickness, wall_mat)
		HotelBlockBuilder.generate_south_stairs_ramp(generator, parent, f_scale, height, floor_thick, floor_mat)
		generator._add_south_stairs_gate(parent, f_num, f_scale)
		HotelSpecialFloorBuilder.build_lobby(parent, f_scale, height, wall_mat)
		HotelSpecialFloorBuilder.build_lab(parent, f_scale)
		return parent

	# 3.5 Maintenance Room
	HotelBlockBuilder.generate_maintenance_room(generator, parent, f_scale, height, thickness, wall_mat)
	
	# 3.7.5 South Stairs Wall
	generator._generate_south_stairs_wall(parent, f_scale, height, thickness, wall_mat)
	HotelBlockBuilder.generate_south_stairs_ramp(generator, parent, f_scale, height, floor_thick, floor_mat)
	generator._add_south_stairs_gate(parent, f_num, f_scale)


	for room_num in HotelConstants.DOUBLE_ROOM_LAYOUT:
		HotelRoomBuilder.generate_double_room(generator, parent, f_scale, f_num, room_num)
	for room_num in HotelConstants.SINGLE_ROOM_LAYOUT:
		HotelRoomBuilder.generate_single_room(generator, parent, f_scale, f_num, room_num)
	
	# Floor 5 only - must come before the cassettes, which need to know the sealed room.
	if f_num == 8:
		HotelTrapBuilder.add_name_doors(generator, parent, f_num, f_scale)
	if f_num == 5:
		HotelTrapBuilder.add_room_shuffle_trap(generator, parent, f_num)

	HotelPropSpawner.spawn_cassettes(parent, f_scale, f_num)
	if f_num == 4 and suffix == "Main":
		generator._add_wake_up_room(parent)
	# The level scene's own floor already has its hand-placed robot (base_hotel_level.tscn's
	# Enemies/Cerberus) - a generated one on top of it would double it up.
	# Floor 6 has no patrol at all - its robots are the sleepers (see sleeper_cerberus.gd).
	if f_num == 6 or f_num == 2:
		HotelPropSpawner.spawn_sleepers(parent, f_scale, &"floor6_sleepers_off" if f_num == 6 else &"floor2_done")
	elif suffix != "Main":
		HotelPropSpawner.spawn_cerberus(parent, f_scale)

	# Floor 3 only - see HotelTrapBuilder.add_floor3_corridor_barrier(generator, )'s own comment for why.
	if f_num == 3:
		HotelTrapBuilder.add_floor3_corridor_barrier(generator, parent, f_scale)

	# Every floor that reaches this line already excludes floor 1 (empty_box_mode returns out of
	# this function before the room loop above) and the roof (a separate function entirely,
	# never calls this one) - exactly "every floor except the roof and floor 1" per the request.
	HotelPropSpawner.add_floor_terminal(parent, f_scale)

	# 5. Floor Map - drawn from this file's own layout constants (see floor_map.gd), so it shows
	# this floor's number and room numbers and can't drift away from what was actually built.
	var map_mesh = MeshInstance3D.new()
	map_mesh.name = "FloorMap"
	var quad = QuadMesh.new()
	quad.size = Vector2(2.0 * FloorMap.SIZE.x / FloorMap.SIZE.y, 2.0) * f_scale

	var map_tex: Texture2D = FloorMap.make_texture(parent, f_num)
	var map_mat = StandardMaterial3D.new()
	map_mat.albedo_texture = map_tex
	# A faint glow of its own, so the plan is readable in an unlit corridor.
	map_mat.emission_enabled = true
	map_mat.emission_texture = map_tex
	map_mat.emission_energy_multiplier = 0.6
	quad.material = map_mat
	map_mesh.mesh = quad

	map_mesh.position = Vector3(-2.74 * f_scale, 2.0 * f_scale, 0.0 * f_scale)
	map_mesh.rotation.y = PI / 2.0
	parent.add_child(map_mesh)

	
	# 6. Propaganda Screen
	var prog_mesh = MeshInstance3D.new()
	prog_mesh.name = "PropagandaScreen"
	var prog_quad = QuadMesh.new()
	prog_quad.size = Vector2(1.5, 2.0)
	
	var prog_mat = StandardMaterial3D.new()
	var prog_tex = load("res://assets/textures/propaganda.jpg")
	if prog_tex:
		prog_mat.albedo_texture = prog_tex
		prog_mat.emission_enabled = true
		prog_mat.emission_texture = prog_tex
		prog_mat.emission_energy_multiplier = 1.0
	else:
		prog_mat.albedo_color = Color(0.2, 0.2, 0.8)
		prog_mat.emission_enabled = true
		prog_mat.emission = Color(0.2, 0.2, 0.8)
	prog_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	prog_quad.material = prog_mat
	prog_mesh.mesh = prog_quad
	prog_mesh.set_script(load("res://scripts/levels/blocks/flicker_material.gd"))
	prog_mesh.position = Vector3(-2.74 * f_scale, 2.0 * f_scale, -15.5 * f_scale)
	prog_mesh.rotation.y = PI / 2.0
	# The top strip of the picture has a scrap of an English poster in it - cropped off.
	prog_mat.uv1_scale = Vector3(1.0, 0.93, 1.0)
	prog_mat.uv1_offset = Vector3(0.0, 0.07, 0.0)
	# The screen is the hotel's internal broadcast: looking at it and interacting plays the
	# address recorded for this floor - see broadcast_screen.gd.
	var broadcast = Area3D.new()
	broadcast.name = "Broadcast"
	broadcast.collision_layer = 4 # same layer vhs_tape.tscn uses - the interact raycast's mask
	broadcast.collision_mask = 0
	broadcast.set_script(load("res://scripts/interactables/broadcast_screen.gd"))
	broadcast.floor_num = f_num
	var broadcast_coll = CollisionShape3D.new()
	var broadcast_shape = BoxShape3D.new()
	broadcast_shape.size = Vector3(1.5, 2.0, 0.2)
	broadcast_coll.shape = broadcast_shape
	broadcast.add_child(broadcast_coll)
	prog_mesh.add_child(broadcast)
	parent.add_child(prog_mesh)

	# 7. Ad Screen
	var ad_mesh = MeshInstance3D.new()
	ad_mesh.name = "AdScreen"
	var ad_quad = QuadMesh.new()
	ad_quad.size = Vector2(2.0, 1.5)
	
	var ad_mat = StandardMaterial3D.new()
	var ad_tex = load("res://assets/textures/coca_cola.jpg")
	if ad_tex:
		ad_mat.albedo_texture = ad_tex
		ad_mat.emission_enabled = true
		ad_mat.emission_texture = ad_tex
		ad_mat.emission_energy_multiplier = 1.0
	else:
		ad_mat.albedo_color = Color(0.8, 0.2, 0.2)
		ad_mat.emission_enabled = true
		ad_mat.emission = Color(0.8, 0.2, 0.2)
	ad_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ad_quad.material = ad_mat
	ad_mesh.mesh = ad_quad
	ad_mesh.position = Vector3(-2.74 * f_scale, 2.0 * f_scale, 13.5 * f_scale)
	ad_mesh.rotation.y = PI / 2.0
	parent.add_child(ad_mesh)

	return parent

