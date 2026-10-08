class_name HotelSpecialFloorBuilder
extends RefCounted


static func create_static_box(parent: Node, node_name: String, pos: Vector3, size: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> void:
	var static_body = StaticBody3D.new()
	static_body.name = node_name
	static_body.position = pos
	static_body.rotation = rot
	static_body.collision_layer = 2 # Matches old floor layer
	
	# Named explicitly: an unnamed node gets an auto-generated "@MeshInstance3D@123" name, and
	# _create_exit_portal() looks this one up by path.
	var mesh_inst = MeshInstance3D.new()
	mesh_inst.name = "MeshInstance3D"
	var box_mesh = BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = mat
	mesh_inst.mesh = box_mesh
	static_body.add_child(mesh_inst)
	
	var coll = CollisionShape3D.new()
	coll.name = "CollisionShape3D"
	var box_shape = BoxShape3D.new()
	box_shape.size = size
	coll.shape = box_shape
	static_body.add_child(coll)
	
	parent.add_child(static_body)

const LOBBY_CORRIDOR_HALF_WIDTH: float = 2.5   # the corridor to the entrance, centred on Z=0
const LOBBY_NORTH_ZONE_Z: float = -20.0        # south edge of the wider zone in front of the lift
const LOBBY_NORTH_ZONE_EAST_X: float = 9.65    # its east wall - where the maintenance room starts upstairs

# The ground-floor lobby (floor 1 only). Plan, north on the left as the owner drew it:
#
#     north stairs + lift | ......... main hall ......... | south stairs
#                         |        [reception] [aquarium] |        <- east wall
#                         |______      ______ ____________|
#                                |    |                             <- west wall
#                                |    |  corridor, straight across from the reception
#                                |door|  main entrance at its end, under the turrets
#
# The hall runs along the same axis as every floor's corridor, between the lift at the north end
# and the second staircase at the south end; in front of the lift it is as wide as the lift
# lobby of the floors above. The rest of the floor's box is walled off. Coordinates are the
# floor's own, unscaled meters, like the layout constants at the top of this file.
static func build_lobby(parent: Node3D, f_scale: float, height: float, wall_mat: Material) -> void:
	var hh: float = height / f_scale
	var west: float = HotelConstants.CORRIDOR_WEST_EDGE_X
	var east: float = HotelConstants.CORRIDOR_EAST_EDGE_X
	var half_x: float = HotelConstants.BUILDING_WIDTH_X / 2.0
	var north_z: float = HotelConstants.ELEVATOR_CENTER_Z            # -25: the lift's and the north stairs' own doors
	var south_z: float = HotelConstants.SOUTH_STAIRS_ZONE_Z_START    # 25: the south stairs wall
	var cw: float = LOBBY_CORRIDOR_HALF_WIDTH
	var parts_script = load("res://scripts/levels/blocks/lobby_parts.gd")
	# A box given by its extents (unscaled meters) rather than by center and size.
	var box = func(box_name: String, mat: Material, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float) -> void:
		create_static_box(parent, box_name, Vector3((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0) * f_scale,
			Vector3(absf(x1 - x0), absf(y1 - y0), absf(z1 - z0)) * f_scale, mat)

	# --- Walls ---
	box.call("Lobby_WestWall_N", wall_mat, west - 0.2, west, 0.0, hh, north_z, -cw)
	box.call("Lobby_WestWall_S", wall_mat, west - 0.2, west, 0.0, hh, cw, south_z)
	box.call("Lobby_Corridor_N", wall_mat, -half_x, west, 0.0, hh, -cw - 0.2, -cw)
	box.call("Lobby_Corridor_S", wall_mat, -half_x, west, 0.0, hh, cw, cw + 0.2)
	box.call("Lobby_EastWall", wall_mat, east, east + 0.2, 0.0, hh, LOBBY_NORTH_ZONE_Z, south_z)
	box.call("Lobby_NorthZone_S", wall_mat, east, LOBBY_NORTH_ZONE_EAST_X, 0.0, hh, LOBBY_NORTH_ZONE_Z, LOBBY_NORTH_ZONE_Z + 0.2)
	box.call("Lobby_NorthZone_E", wall_mat, LOBBY_NORTH_ZONE_EAST_X, LOBBY_NORTH_ZONE_EAST_X + 0.2, 0.0, hh, north_z, LOBBY_NORTH_ZONE_Z + 0.2)
	box.call("Lobby_NorthWall_W", wall_mat, west - 0.2, HotelConstants.NORTH_STAIRS_CENTER_X - 3.8, 0.0, hh, north_z - 0.2, north_z)

	# --- Reception: a long desk in the middle of the hall, in front of the east wall, facing
	# the corridor to the entrance. There is room to walk round either end and behind it. ---
	var wood = StandardMaterial3D.new()
	wood.albedo_color = Color(0.28, 0.16, 0.08)
	wood.roughness = 0.6
	box.call("Reception_Desk", wood, 2.5, 3.3, 0.0, 1.1, -2.6, 2.6)
	box.call("Reception_Top", wood, 2.3, 3.4, 1.1, 1.18, -2.7, 2.7)
	var desk_light = OmniLight3D.new()
	desk_light.name = "ReceptionLight"
	desk_light.light_color = Color(1.0, 0.85, 0.6)
	desk_light.light_energy = 1.0
	desk_light.omni_range = 7.0 * f_scale
	desk_light.position = Vector3(2.9, 2.6, 0.0) * f_scale
	parent.add_child(desk_light)

	# --- The second lift, the one that goes underground: doors in the east wall behind the
	# desk, and a panel beside them (see lobby_parts.gd, role "lift"). ---
	var steel = StandardMaterial3D.new()
	steel.albedo_color = Color(0.4, 0.4, 0.45)
	steel.metallic = 0.8
	steel.roughness = 0.25
	box.call("LowerLift_DoorL", steel, east - 0.08, east, 0.0, 2.5, -0.66, 0.0)
	box.call("LowerLift_DoorR", steel, east - 0.1, east, 0.0, 2.5, 0.0, 0.66)
	box.call("LowerLift_Frame", steel, east - 0.14, east, 2.5, 2.7, -0.8, 0.8)
	# Its panel is created in build_lab(), together with the panels on the levels below.

	# --- The aquarium: against the east wall, right next to the reception. Glowing, cloudy
	# water you cannot quite see through, and something in it (lobby_parts.gd, "creature"). ---
	var tank_x0: float = 3.55
	var tank_x1: float = east - 0.05
	var tank_z0: float = 3.4
	var tank_z1: float = 9.4
	var tank_h: float = 2.8
	var tank_body = StaticBody3D.new()
	tank_body.name = "Aquarium"
	tank_body.collision_layer = 2
	tank_body.position = Vector3((tank_x0 + tank_x1) / 2.0, tank_h / 2.0 + 0.3, (tank_z0 + tank_z1) / 2.0) * f_scale
	var tank_size: Vector3 = Vector3(tank_x1 - tank_x0, tank_h, tank_z1 - tank_z0) * f_scale
	var tank_coll = CollisionShape3D.new()
	var tank_shape = BoxShape3D.new()
	tank_shape.size = tank_size
	tank_coll.shape = tank_shape
	tank_body.add_child(tank_coll)
	var water = MeshInstance3D.new()
	water.name = "Water"
	var water_box = BoxMesh.new()
	water_box.size = tank_size
	var water_mat = StandardMaterial3D.new()
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.albedo_color = Color(0.1, 0.55, 0.45, 0.78)
	water_mat.emission_enabled = true
	water_mat.emission = Color(0.1, 0.9, 0.7)
	water_mat.emission_energy_multiplier = 0.7
	water_mat.roughness = 0.1
	water_box.material = water_mat
	water.mesh = water_box
	tank_body.add_child(water)
	var creature = Node3D.new()
	creature.name = "Creature"
	creature.set_script(parts_script)
	creature.role = "creature"
	creature.swim_half_length = (tank_z1 - tank_z0) / 2.0 * f_scale - 1.2 * f_scale
	var creature_mat = StandardMaterial3D.new()
	creature_mat.albedo_color = Color(0.01, 0.02, 0.02)
	creature_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Body, and something long trailing behind it - only ever a darker shape in the murk.
	for part in [[Vector3(0.28, 0.5, 1.0), Vector3(0, 0, 0)], [Vector3(0.12, 0.2, 1.3), Vector3(0, -0.1, -1.0)], [Vector3(0.5, 0.08, 0.5), Vector3(0, 0.2, 0.3)]]:
		var shape_mesh = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		sphere.material = creature_mat
		shape_mesh.mesh = sphere
		shape_mesh.scale = part[0] * 2.0 * f_scale
		shape_mesh.position = part[1] * f_scale
		creature.add_child(shape_mesh)
	tank_body.add_child(creature)
	box.call("Aquarium_Base", steel, tank_x0 - 0.05, tank_x1, 0.0, 0.3, tank_z0 - 0.05, tank_z1 + 0.05)
	parent.add_child(tank_body)
	var tank_light = OmniLight3D.new()
	tank_light.name = "AquariumLight"
	tank_light.light_color = Color(0.2, 1.0, 0.8)
	tank_light.light_energy = 2.2
	tank_light.omni_range = 12.0 * f_scale
	tank_light.position = Vector3(tank_x0 - 0.8, 1.8, (tank_z0 + tank_z1) / 2.0) * f_scale
	parent.add_child(tank_light)

	# --- The main entrance at the west end of the corridor, and the turrets over it. ---
	var door_mat = StandardMaterial3D.new()
	door_mat.albedo_color = Color(0.12, 0.1, 0.08)
	door_mat.metallic = 0.3
	box.call("Entrance_DoorL", door_mat, -half_x, -half_x + 0.12, 0.0, 2.6, -1.3, -0.02)
	box.call("Entrance_DoorR", door_mat, -half_x, -half_x + 0.12, 0.0, 2.6, 0.02, 1.3)
	var exit_sign = MeshInstance3D.new()
	exit_sign.name = "Entrance_Sign"
	var sign_box = BoxMesh.new()
	sign_box.size = Vector3(0.05, 0.3, 1.2) * f_scale
	var sign_mat = StandardMaterial3D.new()
	sign_mat.albedo_color = Color(0.1, 0.5, 0.15)
	sign_mat.emission_enabled = true
	sign_mat.emission = Color(0.2, 1.0, 0.3)
	sign_mat.emission_energy_multiplier = 2.5
	sign_box.material = sign_mat
	exit_sign.mesh = sign_box
	exit_sign.position = Vector3(-half_x + 0.16, 2.95, 0.0) * f_scale
	parent.add_child(exit_sign)
	var eye_mat = StandardMaterial3D.new()
	eye_mat.albedo_color = Color(0.6, 0.05, 0.05)
	eye_mat.emission_enabled = true
	eye_mat.emission = Color(1.0, 0.15, 0.05)
	eye_mat.emission_energy_multiplier = 3.0
	var turret_x: float = west - 2.0
	for side in [-1.0, 1.0]:
		box.call("Turret_%s" % ("N" if side < 0.0 else "S"), steel, turret_x - 0.25, turret_x + 0.25, hh - 0.45, hh, side * 1.5 - 0.25, side * 1.5 + 0.25)
		box.call("TurretEye_%s" % ("N" if side < 0.0 else "S"), eye_mat, turret_x - 0.32, turret_x - 0.25, hh - 0.32, hh - 0.2, side * 1.5 - 0.08, side * 1.5 + 0.08)
	var turret_light = OmniLight3D.new()
	turret_light.name = "TurretLight"
	turret_light.light_color = Color(1.0, 0.12, 0.08)
	turret_light.light_energy = 1.5
	turret_light.omni_range = 9.0 * f_scale
	turret_light.position = Vector3(turret_x - 2.0, hh - 0.6, 0.0) * f_scale
	parent.add_child(turret_light)

	# The kill zone: the corridor from just past its mouth all the way to the door.
	var zone_x0: float = -half_x + 0.2
	var zone_x1: float = west - 1.5
	var kill_zone = Area3D.new()
	kill_zone.name = "TurretKillZone"
	kill_zone.collision_layer = 0
	kill_zone.collision_mask = 1 # Player layer
	kill_zone.set_script(parts_script)
	kill_zone.role = "turrets"
	kill_zone.position = Vector3((zone_x0 + zone_x1) / 2.0, 1.2, 0.0) * f_scale
	# Where he comes to: in front of the lift he arrived by.
	kill_zone.return_position = parent.global_position + Vector3(HotelConstants.ELEVATOR_CENTER_X * f_scale, 0.1, (HotelConstants.ELEVATOR_CENTER_Z + 2.0) * f_scale)
	var zone_coll = CollisionShape3D.new()
	var zone_shape = BoxShape3D.new()
	zone_shape.size = Vector3(zone_x1 - zone_x0, 2.4, cw * 2.0 - 0.2) * f_scale
	zone_coll.shape = zone_shape
	kill_zone.add_child(zone_coll)
	parent.add_child(kill_zone)


# The laboratory: two levels under the lobby, reached only by the second lift. Both are one hall
# across the whole footprint of the building.
#   Level -1 - the open-plan office: rows of desks, the empty crates the Cerberus units came in,
#              and a terminal with the lab's own documents (which say what the units are for).
#   Level -2 - the plant: glowing tanks like the lobby's aquarium, instrument racks, and the
#              installation in the middle with its three consoles. Switching them off in order
#              ends the game's situation; the way out is then the lobby's main entrance.
# No tapes down here - by now the hero's memory is whole; what is left is documents.
# Built as children of floor 1's node, in its coordinates: level -1's floor is LAB_LEVEL_DROP
# below the lobby's, level -2's twice that.
const LAB_LEVEL_DROP: float = 4.5
const LAB_LIFT_X: float = 4.85     # the second lift's doors are in the lobby's east hall wall, at Z=0
const LAB_ARRIVE_X: float = 4.1    # where it lets the player out, on every level (behind the lobby desk)

static func build_lab(parent: Node3D, f_scale: float) -> void:
	var half_x: float = HotelConstants.BUILDING_WIDTH_X / 2.0
	var half_z: float = HotelConstants.BUILDING_LENGTH_Z / 2.0
	var drop: float = HotelSpecialFloorBuilder.LAB_LEVEL_DROP
	var y1: float = -drop          # level -1 floor
	var y2: float = -2.0 * drop    # level -2 floor
	var parts_script = load("res://scripts/levels/blocks/lobby_parts.gd")
	var concrete = StandardMaterial3D.new()
	concrete.albedo_color = Color(0.32, 0.33, 0.35)
	concrete.roughness = 0.95
	var steel = StandardMaterial3D.new()
	steel.albedo_color = Color(0.4, 0.4, 0.45)
	steel.metallic = 0.8
	steel.roughness = 0.3
	var wood = StandardMaterial3D.new()
	wood.albedo_color = Color(0.3, 0.3, 0.32)
	var lamp_mat = StandardMaterial3D.new()
	lamp_mat.emission_enabled = true
	lamp_mat.emission = Color(1.0, 0.95, 0.8)
	lamp_mat.emission_energy_multiplier = 2.0
	var box = func(box_name: String, mat: Material, x0: float, x1: float, y0: float, y1b: float, z0: float, z1: float) -> void:
		create_static_box(parent, box_name, Vector3((x0 + x1) / 2.0, (y0 + y1b) / 2.0, (z0 + z1) / 2.0) * f_scale,
			Vector3(absf(x1 - x0), absf(y1b - y0), absf(z1 - z0)) * f_scale, mat)
	var light = func(light_name: String, pos: Vector3, color: Color, energy: float, reach: float) -> OmniLight3D:
		var omni = OmniLight3D.new()
		omni.name = light_name
		omni.light_color = color
		omni.light_energy = energy
		omni.omni_range = reach * f_scale
		omni.position = pos * f_scale
		parent.add_child(omni)
		return omni
	# A panel of the second lift, one per stop: where it stands and which stop it is. Every
	# panel knows all three stops - it opens the same floor-select screen as the main lift.
	var lift_stops: Dictionary = {}
	for stop in [[1, 0.0], [-1, y1], [-2, y2]]:
		lift_stops[stop[0]] = parent.global_position + Vector3(HotelSpecialFloorBuilder.LAB_ARRIVE_X, stop[1] + 0.1, 0.0) * f_scale
	var lift_panel = func(panel_name: String, at: Vector3, here: int, needs_code: bool) -> void:
		var panel = Area3D.new()
		panel.name = panel_name
		panel.collision_layer = 4 # the interact raycast's layer
		panel.collision_mask = 0
		panel.set_script(parts_script)
		panel.role = "lift"
		panel.needs_code = needs_code
		panel.here = here
		panel.stops = lift_stops
		panel.position = at * f_scale
		var coll = CollisionShape3D.new()
		var shape = BoxShape3D.new()
		shape.size = Vector3(0.2, 0.5, 0.35) * f_scale
		coll.shape = shape
		panel.add_child(coll)
		var mesh = MeshInstance3D.new()
		var mesh_box = BoxMesh.new()
		mesh_box.size = Vector3(0.05, 0.4, 0.25) * f_scale
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.1, 0.1, 0.1)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.6, 0.1)
		mat.emission_energy_multiplier = 1.5
		mesh_box.material = mat
		mesh.mesh = mesh_box
		panel.add_child(mesh)
		parent.add_child(panel)

	# --- Shell: two floor slabs and four walls two levels tall. Level -1's ceiling is the
	# lobby's own floor slab. ---
	box.call("Lab_Floor1", concrete, -half_x, half_x, y1 - 0.5, y1, -half_z, half_z)
	box.call("Lab_Floor2", concrete, -half_x, half_x, y2 - 0.5, y2, -half_z, half_z)
	box.call("Lab_Wall_W", concrete, -half_x - 0.2, -half_x, y2 - 0.5, -0.5, -half_z, half_z)
	box.call("Lab_Wall_E", concrete, half_x, half_x + 0.2, y2 - 0.5, -0.5, -half_z, half_z)
	box.call("Lab_Wall_N", concrete, -half_x, half_x, y2 - 0.5, -0.5, -half_z - 0.2, -half_z)
	box.call("Lab_Wall_S", concrete, -half_x, half_x, y2 - 0.5, -0.5, half_z, half_z + 0.2)

	# --- The second lift: the lobby's panel (down, needs the code) and, on each level below, a
	# shaft front with doors and its own panels. ---
	lift_panel.call("LowerLiftPanel", Vector3(HotelSpecialFloorBuilder.LAB_LIFT_X - 0.1, 1.3, 1.05), 1, true)
	for level in [[y1, "1"], [y2, "2"]]:
		var ly: float = level[0]
		box.call("Lab%s_LiftShaft" % level[1], steel, HotelSpecialFloorBuilder.LAB_LIFT_X, HotelSpecialFloorBuilder.LAB_LIFT_X + 1.6, ly, ly + 3.2, -2.2, 2.2)
		box.call("Lab%s_LiftDoor" % level[1], concrete, HotelSpecialFloorBuilder.LAB_LIFT_X - 0.06, HotelSpecialFloorBuilder.LAB_LIFT_X, ly, ly + 2.5, -0.66, 0.66)
		lift_panel.call("Lab%s_LiftPanel" % level[1], Vector3(HotelSpecialFloorBuilder.LAB_LIFT_X - 0.1, ly + 1.3, 1.05), -int(level[1]), false)

	# --- Level -1: the open-plan office. ---
	for col in range(3):
		for row in range(9):
			var dx: float = -9.0 + col * 4.0
			var dz: float = -24.0 + row * 6.0
			box.call("Lab1_Desk_%d_%d" % [col, row], wood, dx - 0.8, dx + 0.8, y1, y1 + 0.75, dz - 0.4, dz + 0.4)
			var lamp = MeshInstance3D.new()
			var lamp_box = BoxMesh.new()
			lamp_box.size = Vector3(0.18, 0.06, 0.3) * f_scale
			lamp_box.material = lamp_mat
			lamp.mesh = lamp_box
			lamp.position = Vector3(dx + 0.5, y1 + 1.05, dz) * f_scale
			parent.add_child(lamp)
	for i in range(5):
		light.call("Lab1_Light_%d" % i, Vector3(-5.0, y1 + 3.2, -22.0 + i * 11.0), Color(0.85, 0.92, 1.0), 1.6, 12.0)
	# The crates the nine Cerberus units came in (the waybill in the terminal archive), empty.
	for i in range(9):
		box.call("Lab1_Crate_%d" % i, wood, -half_x + 0.3, -half_x + 1.5, y1, y1 + 1.9, -21.0 + i * 2.3, -19.2 + i * 2.3)
	# The lab's own terminal, by the lift: its documents open once the player has come down.
	HotelPropSpawner.add_floor_terminal(parent, f_scale, Vector3(HotelSpecialFloorBuilder.LAB_LIFT_X - 0.15, y1 + 1.3, -1.9), PI)

	# --- Level -2: the plant. ---
	for i in range(4):
		for side in [-1.0, 1.0]:
			add_lab_tank(parent, "Lab2_Tank_%d_%s" % [i, "N" if side < 0.0 else "S"],
				Vector3(-10.0 + i * 4.0, y2 + 1.75, side * 14.0), Vector3(2.4, 3.0, 3.6), f_scale, parts_script)
			box.call("Lab2_Rack_%d_%s" % [i, "N" if side < 0.0 else "S"], steel, -10.5 + i * 4.0, -8.5 + i * 4.0, y2, y2 + 2.2, side * 28.6 - 0.4, side * 28.6 + 0.4)
	light.call("Lab2_TankLight_N", Vector3(-4.0, y2 + 2.2, -10.5), Color(0.2, 1.0, 0.8), 2.0, 14.0)
	light.call("Lab2_TankLight_S", Vector3(-4.0, y2 + 2.2, 10.5), Color(0.2, 1.0, 0.8), 2.0, 14.0)
	# The installation: a column of light in a housing, in the middle of the hall.
	var installation = Node3D.new()
	installation.name = "Lab2_Installation"
	installation.set_script(parts_script)
	installation.role = "installation"
	installation.position = Vector3(-4.0, y2, 0.0) * f_scale
	var housing = MeshInstance3D.new()
	housing.name = "Housing"
	var torus = TorusMesh.new()
	torus.inner_radius = 1.3 * f_scale
	torus.outer_radius = 1.7 * f_scale
	torus.material = steel
	housing.mesh = torus
	housing.position = Vector3(0, 1.2, 0) * f_scale
	installation.add_child(housing)
	var column = MeshInstance3D.new()
	column.name = "Column"
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = 0.5 * f_scale
	cylinder.bottom_radius = 0.5 * f_scale
	cylinder.height = 4.0 * f_scale
	var column_mat = StandardMaterial3D.new()
	column_mat.emission_enabled = true
	column_mat.emission = Color(0.75, 0.85, 1.0)
	column_mat.emission_energy_multiplier = 6.0
	cylinder.material = column_mat
	column.mesh = cylinder
	column.position = Vector3(0, 2.0, 0) * f_scale
	installation.add_child(column)
	var core_light = OmniLight3D.new()
	core_light.light_color = Color(0.75, 0.85, 1.0)
	core_light.light_energy = 4.0
	core_light.omni_range = 16.0 * f_scale
	core_light.position = Vector3(0, 2.0, 0) * f_scale
	installation.add_child(core_light)
	parent.add_child(installation)
	create_static_box(parent, "Lab2_InstallationBody", Vector3(-4.0, y2 + 2.0, 0.0) * f_scale, Vector3(1.0, 4.0, 1.0) * f_scale, steel)
	# The three consoles around it, numbered - they only work in order (lobby_parts.gd).
	var console_spots: Array = [Vector3(-4.0, y2, -4.0), Vector3(-8.0, y2, 0.0), Vector3(-4.0, y2, 4.0)]
	for i in range(3):
		var spot: Vector3 = console_spots[i]
		box.call("Lab2_ConsoleBody_%d" % (i + 1), steel, spot.x - 0.5, spot.x + 0.5, y2, y2 + 1.0, spot.z - 0.3, spot.z + 0.3)
		var console = Area3D.new()
		console.name = "Lab2_Console_%d" % (i + 1)
		console.collision_layer = 4
		console.collision_mask = 0
		console.set_script(parts_script)
		console.role = "console"
		console.index = i + 1
		console.position = (spot + Vector3(0, 1.15, 0)) * f_scale
		var console_coll = CollisionShape3D.new()
		var console_shape = BoxShape3D.new()
		console_shape.size = Vector3(1.1, 0.5, 0.9) * f_scale
		console_coll.shape = console_shape
		console.add_child(console_coll)
		var number = Label3D.new()
		number.text = str(i + 1)
		number.font_size = 96
		number.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		number.modulate = Color(1.0, 0.7, 0.2)
		number.position = Vector3(0, 0.35, 0) * f_scale
		console.add_child(number)
		parent.add_child(console)



# A glowing tank with something in it - the same thing the lobby's aquarium is.
static func add_lab_tank(parent: Node3D, tank_name: String, center: Vector3, size: Vector3, f_scale: float, parts_script: Script) -> void:
	var body = StaticBody3D.new()
	body.name = tank_name
	body.collision_layer = 2
	body.position = center * f_scale
	var coll = CollisionShape3D.new()
	var shape = BoxShape3D.new()
	shape.size = size * f_scale
	coll.shape = shape
	body.add_child(coll)
	var water = MeshInstance3D.new()
	var water_box = BoxMesh.new()
	water_box.size = size * f_scale
	var water_mat = StandardMaterial3D.new()
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.albedo_color = Color(0.1, 0.55, 0.45, 0.78)
	water_mat.emission_enabled = true
	water_mat.emission = Color(0.1, 0.9, 0.7)
	water_mat.emission_energy_multiplier = 0.7
	water_box.material = water_mat
	water.mesh = water_box
	body.add_child(water)
	var creature = Node3D.new()
	creature.name = "Creature"
	creature.set_script(parts_script)
	creature.role = "creature"
	creature.swim_half_length = maxf(0.1, size.z / 2.0 - 0.9) * f_scale
	var dark = StandardMaterial3D.new()
	dark.albedo_color = Color(0.01, 0.02, 0.02)
	dark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for part in [[Vector3(0.28, 0.5, 1.0), Vector3.ZERO], [Vector3(0.12, 0.2, 1.3), Vector3(0, -0.1, -1.0)]]:
		var blob = MeshInstance3D.new()
		var sphere = SphereMesh.new()
		sphere.radius = 0.5
		sphere.height = 1.0
		sphere.material = dark
		blob.mesh = sphere
		blob.scale = part[0] * 1.6 * f_scale
		blob.position = part[1] * 0.8 * f_scale
		creature.add_child(blob)
	body.add_child(creature)
	parent.add_child(body)


