class_name HotelBlockBuilder
extends RefCounted


static func generate_maintenance_room(generator: HotelLevelGenerator, parent: Node, f_scale: float, height: float, thickness: float, wall_mat: Material) -> void:
	var wall_y = height / 2.0
	HotelSpecialFloorBuilder.create_static_box(parent, "Maint_Inner_South", Vector3(11.15 * f_scale, wall_y, -20.0 * f_scale), Vector3(3.0 * f_scale, height, thickness), wall_mat)

	# Doorway gap narrowed from 2.0m to a standard 1.2m (matching the stairs doors) so a
	# single door.tscn leaf covers it instead of leaving 0.8m permanently uncovered.
	# Center stays at Z=-23 (unchanged) - only the two wall segments' extents shrank in.
	var door_w = 1.2 * f_scale
	var door_z_center = -23.0 * f_scale
	var gap_min_z = door_z_center - door_w / 2.0
	var gap_max_z = door_z_center + door_w / 2.0
	var north_len = gap_min_z - (-30.0 * f_scale)
	var north_center_z = ((-30.0 * f_scale) + gap_min_z) / 2.0
	var south_len = (-20.0 * f_scale) - gap_max_z
	var south_center_z = (gap_max_z + (-20.0 * f_scale)) / 2.0
	HotelSpecialFloorBuilder.create_static_box(parent, "Maint_Inner_West_North", Vector3(9.65 * f_scale, wall_y, north_center_z), Vector3(thickness, height, north_len), wall_mat)
	HotelSpecialFloorBuilder.create_static_box(parent, "Maint_Inner_West_South", Vector3(9.65 * f_scale, wall_y, south_center_z), Vector3(thickness, height, south_len), wall_mat)
	var door_h = 2.2 * f_scale
	if height > door_h:
		var lintel_h = height - door_h
		var lintel_y = door_h + (lintel_h / 2.0)
		HotelSpecialFloorBuilder.create_static_box(parent, "Maint_Inner_West_Lintel", Vector3(9.65 * f_scale, lintel_y, door_z_center), Vector3(thickness, lintel_h, door_w), wall_mat)

	# Corridor is west of this wall (smaller X), so basis.z needs to point -X: rotation.y = -PI/2.
	var door_scene_maint = load("res://entities/props/door.tscn")
	if door_scene_maint:
		var maint_door_inst = door_scene_maint.instantiate()
		maint_door_inst.name = "MaintenanceDoor"
		# position/rotation/scale MUST be set before add_child(): add_child() fires _ready()
		# synchronously on the whole subtree (including door.gd's AnimatableBody3D), which
		# would otherwise see the door still at its pre-placement identity transform - i.e.
		# sitting at local (0,0,0), right on top of the player's spawn point at world origin.
		maint_door_inst.position = Vector3(9.65 * f_scale, 0, door_z_center)
		maint_door_inst.rotation.y = -PI / 2.0
		maint_door_inst.scale = Vector3(door_w, f_scale, f_scale)
		parent.add_child(maint_door_inst)

	# Storage wardrobes, backs against the building's own east wall (X=12.65), opening
	# facing west into the room. Kept north of the doorway gap (Z -24..-22) for clearance.
	# maintenance_room.tscn (an older, unused standalone scene) had 2 wardrobes here too,
	# but its own wall layout no longer matches this procedurally-built room - these are
	# placed fresh against the room this function actually builds.
	var wardrobe_scene = load("res://entities/props/wardrobe.tscn")
	if wardrobe_scene:
		for i in range(2):
			var wardrobe_inst = wardrobe_scene.instantiate()
			wardrobe_inst.name = "MaintWardrobe" + str(i + 1)
			wardrobe_inst.transform = Transform3D(Basis(Vector3(0, 0, 1), Vector3(0, 1, 0), Vector3(-1, 0, 0)), Vector3(12.25 * f_scale, 0, (-28.0 + i * 2.5) * f_scale))
			generator._bake_csg(wardrobe_inst)
			parent.add_child(wardrobe_inst)


static func generate_north_stairs(generator: HotelLevelGenerator, parent: Node, f_scale: float, f_num: int) -> void:
	var scene = load("res://scenes/levels/hotel_siberia/blocks/north_stairs.tscn")
	if scene:
		var inst = scene.instantiate()
		# position MUST be set before add_child() - see generate_maintenance_room() for why.
		inst.position = Vector3(HotelConstants.NORTH_STAIRS_CENTER_X * f_scale, 0, HotelConstants.NORTH_STAIRS_CENTER_Z * f_scale)

		# Обе двери на южной стене (лицом в коридор, +Z, без поворота), ширина проёма 1.2м.
		# Local coords, NOT multiplied by f_scale here: this whole block (like double_room.tscn/
		# single_room.tscn) is static authored content that GlobalConfig.apply_dynamic_scale()
		# rescales on its own via block.gd's _ready() - scaling it again here would double it
		# for any build with a non-default player/floor scale.
		# Created in code, not embedded in north_stairs.tscn - see _add_room_door()'s comment
		# for why (embedding a second door.tscn instance in one scene file loses nodes when
		# packed into an exported PCK).
		var door_scene = load("res://entities/props/door.tscn")
		if door_scene:
			for door_data in [["DoorEast", 2.8], ["DoorWest", -2.8]]:
				var door_inst = door_scene.instantiate()
				door_inst.name = door_data[0]
				door_inst.position = Vector3(door_data[1], 0, 4.9)
				door_inst.scale = Vector3(1.2, 1.0, 1.0)
				inst.add_child(door_inst)

				# Floor-lock gate at this same doorway - see stairs_gate.gd. Left in inst's own
				# UNSCALED local space like the door above - block.gd's apply_dynamic_scale()
				# rescales this whole subtree itself (a plain Area3D with no
				# "door/bed/table/chair/wardrobe" in its name takes the generic Node3D scaling
				# path, not the human-sized prop path).
				var gate = Area3D.new()
				gate.name = door_data[0] + "Gate"
				gate.collision_layer = 0
				gate.collision_mask = 1 # Player layer
				gate.set_script(load("res://scripts/levels/blocks/stairs_gate.gd"))
				gate.floor_num = f_num
				gate.y_step = HotelConstants.BASE_FLOOR_TO_FLOOR_HEIGHT * f_scale
				gate.position = Vector3(door_data[1], 1.1, 4.9)

				var gate_coll = CollisionShape3D.new()
				var gate_shape = BoxShape3D.new()
				gate_shape.size = Vector3(1.2, 2.2, 1.0)
				gate_coll.shape = gate_shape
				gate.add_child(gate_coll)
				inst.add_child(gate)

		# Fall-through-the-shaft safety net (see stairs_fall_catcher.gd) - spans this floor's
		# own slice of the stairwell interior (Y 0..4.5, between StairsWestWall/EastWall at
		# X -3.7/+3.7 and StairsSouthWall/north wall at Z 4.9/0.0), same unscaled local space
		# as the door/gate above. Stacking one of these per floor forms one continuous column
		# covering the whole shaft, so a player who falls off a ramp/landing edge anywhere in
		# the building gets caught regardless of which floor they started falling from.
		var fall_catcher = Area3D.new()
		fall_catcher.name = "FallCatcher"
		fall_catcher.collision_layer = 0
		fall_catcher.collision_mask = 1 # Player layer
		fall_catcher.set_script(load("res://scripts/levels/blocks/stairs_fall_catcher.gd"))
		fall_catcher.position = Vector3(0, 2.25, 2.45)

		var fall_coll = CollisionShape3D.new()
		var fall_shape = BoxShape3D.new()
		fall_shape.size = Vector3(7.0, 4.5, 4.6)
		fall_coll.shape = fall_shape
		fall_catcher.add_child(fall_coll)
		inst.add_child(fall_catcher)

		# Landing checkpoints (see stairs_gate.gd) - a second floor-lock check on each of the
		# two flat landings a player walks across climbing this floor's own dog-leg flights
		# (NELanding, NWLanding - see north_stairs.tscn/AGENTS.md's "North Stairs Block Map").
		# Same idea as the South Stairs landing gate in _build_floor_geometry(): catches a
		# player who slips slightly past the DoorEast/DoorWest gates above while still walking
		# on solid ground, distinct from stairs_fall_catcher.gd's job of catching an actual fall
		# through open air. Same unscaled local space as the doors/gates/fall-catcher above.
		for landing_data in [["NELandingGate", Vector3(2.5, 1.5, 0.6)], ["NWLandingGate", Vector3(-2.5, 3.0, 0.6)]]:
			var l_center: Vector3 = landing_data[1]
			var landing_gate = Area3D.new()
			landing_gate.name = landing_data[0]
			landing_gate.collision_layer = 0
			landing_gate.collision_mask = 1 # Player layer
			landing_gate.set_script(load("res://scripts/levels/blocks/stairs_gate.gd"))
			landing_gate.floor_num = f_num
			landing_gate.y_step = HotelConstants.BASE_FLOOR_TO_FLOOR_HEIGHT * f_scale
			landing_gate.position = Vector3(l_center.x, l_center.y + 0.1 + 1.1, l_center.z)

			var landing_gate_coll = CollisionShape3D.new()
			var landing_gate_shape = BoxShape3D.new()
			landing_gate_shape.size = Vector3(2.4, 2.2, 1.2)
			landing_gate_coll.shape = landing_gate_shape
			landing_gate.add_child(landing_gate_coll)
			inst.add_child(landing_gate)

		generator._bake_csg(inst)
		parent.add_child(inst)


static func generate_south_stairs_ramp(generator: HotelLevelGenerator, parent: Node, f_scale: float, height: float, floor_thick: float, floor_mat: Material) -> void:
	# Dog-leg staircase, self-contained per floor (same philosophy as north_stairs.tscn's
	# 3 flights: each floor climbs its own full 0 -> floor-to-floor-height run, and stacking
	# floors is what makes it continuous - no geometry is shared with or duplicated by the
	# neighboring floor). One door only, so both flights start/end at the same X as the door
	# area (Floor_SW's edge), not two separate doors like the north stairs.
	#
	# Layout inside the 5m-deep south-stairs zone (Z 25..30), split into two 2.5m bands so
	# the up-flight and the return flight sit side by side instead of stacked (stacking them
	# would need the upper flight to clear headroom over the lower one; side by side avoids
	# that entirely):
	#   Band 1 (Z 25..27.5):  RampA climbs EAST,  X 1.87 -> 8.03,  Y 0 -> mid_y
	#   Landing (full Z 25..30, X 8.03..12.65, Y mid_y): turn here (reuses Landing_SouthStairs)
	#   Band 2 (Z 27.5..30):  RampB climbs WEST,  X 8.03 -> 1.87,  Y mid_y -> full_y
	# RampB's arrival point (X=1.87, Y=full_y) is exactly where the floor-above's own
	# Floor_SW edge sits, so it needs no landing of its own - the next floor provides it.
	var x_inner = HotelConstants.SOUTH_STAIRS_RAMP_INNER_X * f_scale      # Floor_SW's east edge
	var x_outer = HotelConstants.SOUTH_STAIRS_LANDING_INNER_X * f_scale   # Landing_SouthStairs' west edge
	var mid_y = (height + floor_thick) / 2.0   # Landing_SouthStairs' walkable SURFACE height
	                                            # (its box center, y_landing, sits floor_thick/2
	                                            # below this, at height/2 - see that comment)
	var full_y = height + floor_thick          # this floor's ceiling = next floor's floor

	var band_depth = (HotelConstants.SOUTH_STAIRS_ZONE_Z_END - HotelConstants.SOUTH_STAIRS_ZONE_Z_START) / 2.0 * f_scale
	var z_band1 = (HotelConstants.SOUTH_STAIRS_ZONE_Z_START * f_scale) + band_depth / 2.0  # center of band 1
	var z_band2 = (HotelConstants.SOUTH_STAIRS_ZONE_Z_END * f_scale) - band_depth / 2.0    # center of band 2

	var run = x_outer - x_inner
	var ramp_len = sqrt(run * run + mid_y * mid_y)
	var angle_up = atan2(mid_y, run)

	# create_static_box() places a box by its center, but the player walks on its top face,
	# which on an inclined box sits slab_half_t from the center perpendicular to the slope,
	# not straight up. Centering the box on the two floor-surface points would leave the
	# walking surface short at both ends - a ledge at the landing that blocks the way up.
	# Shifting the center by that perpendicular offset puts the surface on the points.
	var slab_half_t = 0.1 * f_scale
	var offset_x = slab_half_t * sin(angle_up)
	var offset_y = slab_half_t * cos(angle_up)

	# RampA: rises to the east, Band 1
	HotelSpecialFloorBuilder.create_static_box(
		parent, "SouthStairsRampA",
		Vector3((x_inner + x_outer) / 2.0 + offset_x, mid_y / 2.0 - offset_y, z_band1),
		Vector3(ramp_len, slab_half_t * 2.0, band_depth),
		floor_mat,
		Vector3(0, 0, angle_up)
	)

	# RampB: rises to the west, Band 2 - same shape as RampA, mirrored in X and offset up by mid_y
	HotelSpecialFloorBuilder.create_static_box(
		parent, "SouthStairsRampB",
		Vector3((x_inner + x_outer) / 2.0 - offset_x, mid_y + (full_y - mid_y) / 2.0 - offset_y, z_band2),
		Vector3(ramp_len, slab_half_t * 2.0, band_depth),
		floor_mat,
		Vector3(0, 0, -angle_up)
	)





static func generate_elevator(generator: HotelLevelGenerator, parent: Node, f_scale: float) -> void:
	var scene = load("res://scenes/levels/hotel_siberia/blocks/elevator_shaft.tscn")
	if scene:
		var inst = scene.instantiate()

		# position/scale MUST be set before add_child() - see HotelBlockBuilder.generate_maintenance_room()
		# for why (add_child() fires _ready() synchronously on the whole subtree).
		inst.position = Vector3(HotelConstants.ELEVATOR_CENTER_X * f_scale, 0, HotelConstants.ELEVATOR_CENTER_Z * f_scale)
		inst.scale.z = -1.0

		# ElevatorDoor MUST be added to inst before inst itself is added to parent: adding inst
		# to parent fires elevator_controller.gd's _ready() synchronously, which looks up
		# "ElevatorDoor/AnimatableBody3D" once and caches it in door_animatable - if that lookup
		# happens before this door exists, door_animatable stays null forever, and the whole
		# button-triggered open/close sequence (_run_elevator_sequence/_arrive_and_open) silently
		# never touches the door (interacting with the door directly still works, since that
		# doesn't go through elevator_controller.gd at all).
		var door_scene = load("res://entities/props/elevator_door.tscn")
		if door_scene:
			var door_inst = door_scene.instantiate()
			door_inst.name = "ElevatorDoor"
			door_inst.position = Vector3(0, 0, 0.1 * f_scale)
			inst.add_child(door_inst)

		generator._bake_csg(inst)
		parent.add_child(inst)

		# Floor buttons are NOT created here. elevator_shaft.tscn already ships a real,
		# wired-up "ButtonFloor4" template under ElevatorPanel, and elevator_controller.gd's
		# _setup_buttons() duplicates it for floors 1-10 and connects button_pressed itself.
		# A second button made here would sit on top of the real one, unconnected: a hitbox
		# by the panel that does nothing.


static func generate_south_stairs_wall(parent: Node, f_scale: float, height: float, thickness: float, wall_mat: Material) -> void:
	var z_pos = HotelConstants.SOUTH_STAIRS_ZONE_Z_START * f_scale + (thickness / 2.0)
	var door_w = 1.2 * f_scale
	var door_h = 2.2 * f_scale

	var x_left = HotelConstants.CORRIDOR_WEST_EDGE_X * f_scale
	var x_right = HotelConstants.CORRIDOR_EAST_EDGE_X * f_scale
	var x_center = HotelConstants.SOUTH_STAIRS_DOOR_CENTER_X * f_scale
	
	var left_w = (x_center - door_w / 2.0) - x_left
	var left_cx = x_left + (left_w / 2.0)
	
	var right_w = x_right - (x_center + door_w / 2.0)
	var right_cx = x_right - (right_w / 2.0)
	
	HotelSpecialFloorBuilder.create_static_box(parent, "SouthStairsWall_Left", Vector3(left_cx, height / 2.0, z_pos), Vector3(left_w, height, thickness), wall_mat)
	HotelSpecialFloorBuilder.create_static_box(parent, "SouthStairsWall_Right", Vector3(right_cx, height / 2.0, z_pos), Vector3(right_w, height, thickness), wall_mat)
	
	if height > door_h:
		var lintel_h = height - door_h
		var lintel_y = door_h + (lintel_h / 2.0)
		HotelSpecialFloorBuilder.create_static_box(parent, "SouthStairsWall_Lintel", Vector3(x_center, lintel_y, z_pos), Vector3(door_w, lintel_h, thickness), wall_mat)

	# Corridor is north of this wall (smaller Z), so the door's basis.z (its "outward"
	# reference direction per door.gd) needs to point -Z: rotation.y = PI.
	# door.tscn's native panel is 1.0 wide x 2.2 tall x 0.1 thick - scale.x stretches it
	# to this doorway's width (door_w), scale.y/z match the same f_scale as everything
	# else this function builds (door_h is already 2.2*f_scale).
	var door_scene = load("res://entities/props/door.tscn")
	if door_scene:
		var door_inst = door_scene.instantiate()
		door_inst.name = "SouthStairsDoor"
		# See generate_maintenance_room() for why this must happen before add_child().
		door_inst.position = Vector3(x_center, 0, z_pos)
		door_inst.rotation.y = PI
		door_inst.scale = Vector3(door_w, f_scale, f_scale)
		parent.add_child(door_inst)


# Locks South Stairs floor-hopping at floor f_num's own doorway - see stairs_gate.gd for
# the actual check/teleport. Sized to span the full doorway so the player can't sidestep it.
static func add_south_stairs_gate(parent: Node, f_num: int, f_scale: float) -> void:
	var z_pos = HotelConstants.SOUTH_STAIRS_ZONE_Z_START * f_scale
	var x_center = HotelConstants.SOUTH_STAIRS_DOOR_CENTER_X * f_scale
	var door_w = 1.2 * f_scale
	var door_h = 2.2 * f_scale

	var gate = Area3D.new()
	gate.name = "SouthStairsGate"
	gate.collision_layer = 0
	gate.collision_mask = 1 # Player layer
	gate.set_script(load("res://scripts/levels/blocks/stairs_gate.gd"))
	gate.floor_num = f_num
	gate.y_step = HotelConstants.BASE_FLOOR_TO_FLOOR_HEIGHT * f_scale
	gate.position = Vector3(x_center, door_h / 2.0, z_pos)

	var coll = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = Vector3(door_w, door_h, 1.0 * f_scale)
	coll.shape = shape
	gate.add_child(coll)

	parent.add_child(gate)
