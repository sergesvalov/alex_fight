class_name HotelLevelCoordinates
extends RefCounted

static func get_corridor_start_z() -> float:
	return 13.05 * GlobalConfig.get_floor_scale()

static func get_total_corridor_end() -> float:
	return -58.0 * GlobalConfig.get_floor_scale()

static func get_left_rooms_data() -> Array:
	return [
		{"name": "408", "z": 5.0,   "type": "normal", "flip": true},
		{"name": "406", "z": -5.0,  "type": "normal", "flip": false},
		{"name": "405", "z": -15.0, "type": "normal", "flip": false},
		{"name": "403", "z": -25.0, "type": "normal", "flip": true},
		{"name": "402", "z": -35.0, "type": "large",  "flip": true},
		{"name": "401", "z": -45.0, "type": "large",  "flip": false},
	]

static func get_right_rooms_data() -> Array:
	return [
		{"name": "421", "z": 7.0,   "flip": false},
		{"name": "420", "z": 1.0,   "flip": false},
		{"name": "417", "z": -5.0,  "flip": false},
		{"name": "416", "z": -13.0, "flip": false},
		{"name": "415", "z": -21.0, "flip": false},
		{"name": "413", "z": -27.0, "flip": false},
		{"name": "412", "z": -33.0, "flip": false},
		{"name": "411", "z": -39.0, "flip": false},
		{"name": "410", "z": -45.0, "flip": false},
	]

static func get_south_stair_z() -> float:
	return 12.0 * GlobalConfig.get_floor_scale()

static func get_map_decal_z() -> float:
	return -42.5 * GlobalConfig.get_floor_scale()

static func get_elevator_z() -> float:
	return -58.0 * GlobalConfig.get_floor_scale()

static func get_maintenance_z() -> float:
	return -50.5 * GlobalConfig.get_floor_scale()

static func get_alcove_south_wall_z() -> float:
	return -48.0 * GlobalConfig.get_floor_scale()

static func get_alcove_east_wall_gap1_z_start() -> float:
	return -50.5 * GlobalConfig.get_floor_scale()

static func get_alcove_east_wall_gap1_z_end() -> float:
	return -58.0 * GlobalConfig.get_floor_scale()

static func get_alcove_east_wall_gap2_z_start() -> float:
	return -48.0 * GlobalConfig.get_floor_scale()

static func get_alcove_east_wall_gap2_z_end() -> float:
	return -47.5 * GlobalConfig.get_floor_scale()
