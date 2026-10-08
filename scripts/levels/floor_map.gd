# scripts/levels/floor_map.gd
# The floor plan hanging on each floor's corridor wall, drawn from the very same layout
# constants hotel_level_generator.gd builds the floor from - so the map can't disagree with the
# level, and every floor gets its own floor number and room numbers. (The two hand-made
# textures it replaces, hotel_map.jpg / hotel_map_3.jpg, covered floors 4 and 3 only; every
# other floor showed one of those two.)
#
# Usage: FloorMap.make_texture(host, floor_num) - renders once into a SubViewport parked under
# `host` and returns its texture.
extends Control

const SIZE := Vector2i(512, 800)
const PX_PER_M: float = 11.0
const MAP_TOP: float = 84.0

const BG := Color(0.02, 0.025, 0.03)
const LINE := Color(0.92, 0.95, 1.0)
const DIM := Color(0.55, 0.6, 0.66)
const ACCENT := Color(1.0, 0.35, 0.2)

var floor_num: int = 4

static func make_texture(host: Node, for_floor: int) -> Texture2D:
	var viewport := SubViewport.new()
	viewport.name = "FloorMapViewport_" + str(for_floor)
	viewport.size = SIZE
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	var map: Control = load("res://scripts/levels/floor_map.gd").new()
	map.floor_num = for_floor
	map.size = Vector2(SIZE)
	viewport.add_child(map)
	host.add_child(viewport)
	return viewport.get_texture()

# World meters (X east, Z south - see AGENTS.md) -> map pixels (north up).
func _p(x: float, z: float) -> Vector2:
	var gen = load("res://scripts/levels/hotel_level_generator.gd")
	var map_w: float = gen.BUILDING_WIDTH_X * PX_PER_M
	var left: float = (SIZE.x - map_w) / 2.0
	return Vector2(left + (x + gen.BUILDING_WIDTH_X / 2.0) * PX_PER_M,
		MAP_TOP + (z + gen.BUILDING_LENGTH_Z / 2.0) * PX_PER_M)

func _box(x0: float, z0: float, x1: float, z1: float, color: Color = LINE, width: float = 2.0) -> void:
	var a := _p(minf(x0, x1), minf(z0, z1))
	var b := _p(maxf(x0, x1), maxf(z0, z1))
	draw_rect(Rect2(a, b - a), color, false, width)

func _text(x: float, z: float, text: String, font_size: int = 13, color: Color = LINE) -> void:
	var font: Font = ThemeDB.fallback_font
	var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, _p(x, z) + Vector2(-text_size.x / 2.0, font_size * 0.35), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

# A doorway in a wall running along Z at wall_x, centered on door_z: a gap plus a door leaf.
func _door_in_z_wall(wall_x: float, door_z: float, into_x: float) -> void:
	draw_line(_p(wall_x, door_z - 0.5), _p(wall_x, door_z + 0.5), BG, 4.0)
	draw_line(_p(wall_x, door_z - 0.5), _p(wall_x + into_x * 0.9, door_z - 0.5), DIM, 1.5)

# Same, for a wall running along X at wall_z.
func _door_in_x_wall(door_x: float, wall_z: float, into_z: float) -> void:
	draw_line(_p(door_x - 0.6, wall_z), _p(door_x + 0.6, wall_z), BG, 4.0)
	draw_line(_p(door_x - 0.6, wall_z), _p(door_x - 0.6, wall_z + into_z * 0.9), DIM, 1.5)

func _draw() -> void:
	var gen = load("res://scripts/levels/hotel_level_generator.gd")
	var half_x: float = gen.BUILDING_WIDTH_X / 2.0
	var half_z: float = gen.BUILDING_LENGTH_Z / 2.0
	var west: float = gen.CORRIDOR_WEST_EDGE_X
	var east: float = gen.CORRIDOR_EAST_EDGE_X

	draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE)), BG, true)
	draw_string(ThemeDB.fallback_font, Vector2(24, 40), "HOTEL SIBERIA", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, LINE)
	draw_string(ThemeDB.fallback_font, Vector2(24, 66), "FLOOR PLAN  -  LEVEL %d" % floor_num, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, DIM)
	draw_string(ThemeDB.fallback_font, Vector2(SIZE.x - 44, 44), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, LINE)
	draw_line(Vector2(SIZE.x - 38, 70), Vector2(SIZE.x - 38, 50), LINE, 2.0)

	_box(-half_x, -half_z, half_x, half_z, LINE, 3.0)

	# Double rooms, west of the corridor. Local layout (double_room.tscn): 10m deep along Z,
	# WC in the corridor-side corner at local Z 0..4.9, door at local Z=8.5.
	for num in gen.DOUBLE_ROOM_LAYOUT:
		var room: Dictionary = gen.DOUBLE_ROOM_LAYOUT[num]
		var dir: float = -1.0 if room["mirror"] else 1.0
		var z0: float = room["z"]
		_box(-half_x, z0, west, z0 + dir * 10.0)
		_box(gen.DOUBLE_ROOM_BASE_X, z0, west, z0 + dir * 4.9, DIM, 1.5)
		_text((gen.DOUBLE_ROOM_BASE_X + west) / 2.0, z0 + dir * 2.45, "WC", 10, DIM)
		_door_in_z_wall(west, z0 + dir * 8.5, -1.0)
		_text((-half_x + west) / 2.0 - 1.5, z0 + dir * 6.5, str(floor_num * 100 + num % 100), 15)

	# Single rooms, east of the corridor (single_room.tscn): 5m deep, WC at local Z 0..2.5 by
	# the corridor, door at local Z=3.5.
	for num in gen.SINGLE_ROOM_LAYOUT:
		var room: Dictionary = gen.SINGLE_ROOM_LAYOUT[num]
		var dir: float = -1.0 if room["mirror"] else 1.0
		var z0: float = room["z"]
		_box(east, z0, half_x, z0 + dir * 5.0)
		_box(east, z0, east + 2.5, z0 + dir * 2.5, DIM, 1.5)
		_text(east + 1.25, z0 + dir * 1.25, "WC", 10, DIM)
		_door_in_z_wall(east, z0 + dir * 3.5, 1.0)
		_text((east + half_x) / 2.0 + 1.2, z0 + dir * 2.5, str(floor_num * 100 + num % 100), 15)

	# North end: stairs over the corridor, elevator, maintenance room (see _generate_elevator(),
	# _generate_north_stairs(), _generate_maintenance_room()).
	var north_strip_z: float = -half_z + 5.0
	_box(west, -half_z, east, north_strip_z)
	_text((west + east) / 2.0, -half_z + 2.5, "STAIRS", 12)
	_door_in_x_wall(gen.NORTH_STAIRS_CENTER_X + 2.8, north_strip_z, -1.0)
	_door_in_x_wall(gen.NORTH_STAIRS_CENTER_X - 2.8, north_strip_z, -1.0)
	_box(east, -half_z, 9.55, north_strip_z)
	_text((east + 9.55) / 2.0, -half_z + 2.5, "LIFT", 12)
	_door_in_x_wall(gen.ELEVATOR_CENTER_X, north_strip_z, -1.0)
	_box(9.65, -half_z, half_x, -half_z + 10.0)
	_text((9.65 + half_x) / 2.0, -half_z + 5.0, "M", 12, DIM)
	_door_in_z_wall(9.65, -23.0, 1.0)

	# South stairs: the whole strip east of room x08, entered from the corridor's south end.
	_box(west, gen.SOUTH_STAIRS_ZONE_Z_START, half_x, gen.SOUTH_STAIRS_ZONE_Z_END)
	_text((west + half_x) / 2.0 + 2.0, (gen.SOUTH_STAIRS_ZONE_Z_START + gen.SOUTH_STAIRS_ZONE_Z_END) / 2.0, "STAIRS", 12)
	_door_in_x_wall(gen.SOUTH_STAIRS_DOOR_CENTER_X, gen.SOUTH_STAIRS_ZONE_Z_START, 1.0)

	# "You are here": the map itself hangs on the corridor's west wall at Z=0.
	draw_circle(_p(west + 0.9, 0.0), 6.0, ACCENT)
	draw_string(ThemeDB.fallback_font, Vector2(24, SIZE.y - 24), "o  YOU ARE HERE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, ACCENT)
