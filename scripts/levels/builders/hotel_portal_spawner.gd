class_name HotelPortalSpawner
extends RefCounted


# Rebuilds the same doorway from GameStateManager's persisted secret_portal_* fields - called
# both right after _on_all_tapes_collected() rolls them, and from _ready() if this level scene
# reloads after the door already exists (so it doesn't move to a new random spot on reload).
static func create_exit_portal(generator: HotelLevelGenerator) -> void:
	var f_scale = GlobalConfig.get_floor_scale()
	var floor_num = GameStateManager.secret_portal_floor
	var suffix = "Main" if floor_num == generator.floor_number else str(floor_num)
	var floor_node = generator.get_node_or_null("GeneratedFloor_" + suffix)
	if not floor_node: return

	var is_double = GameStateManager.secret_portal_is_double
	var layout = HotelConstants.DOUBLE_ROOM_LAYOUT if is_double else HotelConstants.SINGLE_ROOM_LAYOUT
	var room_layout = layout.get(GameStateManager.secret_portal_room_num)
	if not room_layout: return
	var door_local_z = HotelConstants.DOUBLE_ROOM_EXIT_DOOR_LOCAL_Z if is_double else HotelConstants.SINGLE_ROOM_EXIT_DOOR_LOCAL_Z
	if room_layout["mirror"]:
		door_local_z = -door_local_z
	var room_z = (room_layout["z"] + door_local_z) * f_scale

	# Rooms only own their corridor-facing wall (RoomEastWall/RoomWestWall's equivalent) - the
	# building's actual OUTER wall is one long Wall_West/Wall_East shared by every room on that
	# side, built once per floor in _build_floor_geometry(). It's a plain StaticBody3D+BoxMesh,
	# not CSG, so a doorway is cut by replacing it with two shorter segments plus a gap - the
	# same "union boxes instead of CSG subtraction" approach already used for the wardrobe back
	# panel and the stairs walls (CSG subtraction on a wall this size is exactly the kind of
	# operation that's repeatedly made a WHOLE combined shape vanish elsewhere in this project).
	var wall_name = "Wall_West" if is_double else "Wall_East"
	var old_wall = floor_node.get_node_or_null(wall_name)
	if not old_wall: return

	var wall_mesh: MeshInstance3D = old_wall.get_node("MeshInstance3D")
	var wall_mat: Material = wall_mesh.mesh.material

	var half_x = (HotelConstants.BUILDING_WIDTH_X * f_scale) / 2.0
	var half_z = (HotelConstants.BUILDING_LENGTH_Z * f_scale) / 2.0
	var thickness = generator.wall_thickness * f_scale
	var height = generator.corridor_height * f_scale
	var floor_thick = generator.floor_thickness * f_scale
	var outer_wall_height = height + floor_thick
	var outer_wall_y = (height - floor_thick) / 2.0
	var wall_x = (-half_x - thickness / 2.0) if is_double else (half_x + thickness / 2.0)

	var door_w = 1.2 * f_scale
	var door_h = 2.2 * f_scale
	var gap_half = door_w / 2.0

	old_wall.queue_free()

	var seg_a_len = (room_z - gap_half) - (-half_z)
	if seg_a_len > 0.1:
		var seg_a_z = (-half_z + (room_z - gap_half)) / 2.0
		HotelSpecialFloorBuilder.create_static_box(floor_node, wall_name + "_A", Vector3(wall_x, outer_wall_y, seg_a_z), Vector3(thickness, outer_wall_height, seg_a_len), wall_mat)

	var seg_b_len = half_z - (room_z + gap_half)
	if seg_b_len > 0.1:
		var seg_b_z = ((room_z + gap_half) + half_z) / 2.0
		HotelSpecialFloorBuilder.create_static_box(floor_node, wall_name + "_B", Vector3(wall_x, outer_wall_y, seg_b_z), Vector3(thickness, outer_wall_height, seg_b_len), wall_mat)

	# Standard door.tscn, same as everywhere else in the hotel - basis.z points outward, away
	# from the building interior, matching the "always points toward the corridor" rule doors
	# use elsewhere (here there's no corridor beyond it, just the portal).
	var door_scene = load("res://entities/props/door.tscn")
	if door_scene:
		var door_inst = door_scene.instantiate()
		door_inst.name = "SecretExitDoor"
		door_inst.position = Vector3(wall_x, 0, room_z)
		door_inst.rotation.y = (-PI / 2.0) if is_double else (PI / 2.0)
		door_inst.scale = Vector3(door_w, f_scale, f_scale)
		floor_node.add_child(door_inst)

	# Teleport trigger filling the doorway - stepping through leads to the fixed floor-3 room
	# rolled once in _on_all_tapes_collected(), and permanently unlocks stairs access to floor 3
	# (secret_portal.gd calls GameStateManager.unlock_floor() itself once target_floor is set).
	if GameStateManager.secret_portal_target != Vector3.ZERO:
		var area = Area3D.new()
		area.collision_layer = 0
		area.collision_mask = 1 # Player layer
		var coll = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		# Starts just PAST the wall's own center plane and extends outward from there, so it can
		# only be reached by opening the door and stepping into the doorway. If it reached into
		# the room, touching the still-closed door would set it off.
		var portal_depth: float = 0.8 * f_scale
		var outward: float = -1.0 if is_double else 1.0
		shape.size = Vector3(portal_depth, door_h, door_w * 0.8)
		coll.shape = shape
		area.add_child(coll)
		var script = load("res://scripts/interactables/secret_portal.gd")
		if script:
			area.set_script(script)
		area.target_position = GameStateManager.secret_portal_target
		area.target_floor = GameStateManager.secret_portal_target_floor
		area.position = Vector3(wall_x + outward * (0.05 * f_scale + portal_depth / 2.0), door_h / 2.0, room_z)
		floor_node.add_child(area)

	# The "something heavy just fell somewhere in the hotel" cue: door_open.wav pitched way
	# down, so it needs no asset of its own.
	var audio = AudioStreamPlayer3D.new()
	audio.stream = load("res://assets/audio/sfx/door_open.wav")
	audio.pitch_scale = 0.3
	audio.volume_db = 15.0
	audio.position = Vector3(wall_x, outer_wall_y, room_z)
	floor_node.add_child(audio)
	audio.finished.connect(audio.queue_free)
	audio.play()


# Picks a random room on floor 3 and a safe standing spot just inside it.
static func pick_random_floor3_target(generator: HotelLevelGenerator) -> Vector3:
	var is_single = randi() % 2 == 1
	var layout = HotelConstants.SINGLE_ROOM_LAYOUT if is_single else HotelConstants.DOUBLE_ROOM_LAYOUT
	var keys = layout.keys()
	var room_num = keys[randi() % keys.size()]
	var prefix = "SingleRoom_" if is_single else "DoubleRoom_"
	var room_name = prefix + str(3 * 100 + (room_num % 100))
	var room_node = generator.find_child(room_name, true, false)
	if not room_node:
		return Vector3.ZERO
	var target_pos = room_node.global_position
	if is_single:
		# Open floor just inside RoomDoor, south of the WC: Z=3.6 clears WCSouthWall, which
		# spans X -3.75..-1.35 at Z=2.5.
		target_pos += room_node.global_basis * Vector3(-1.5, 0.5, 3.6)
	else:
		target_pos += room_node.global_basis * Vector3(2.5, 0.5, 7.5)
	return target_pos






