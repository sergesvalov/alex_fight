class_name HotelLevelCoordinates
extends RefCounted

static func get_corridor_start_z() -> float:
	return 25.0 * GlobalConfig.get_floor_scale()

static func get_total_corridor_end() -> float:
	return -20.0 * GlobalConfig.get_floor_scale()

static func get_left_rooms_data() -> Array:
	return [
		{"name": "408", "z": 25.0,  "type": "normal", "flip": true},
		{"name": "406", "z": 15.0,  "type": "normal", "flip": false},
		{"name": "405", "z": 5.0,   "type": "normal", "flip": false},
		{"name": "403", "z": -5.0,  "type": "normal", "flip": true},
		{"name": "402", "z": -15.0, "type": "large",  "flip": true},
		{"name": "401", "z": -25.0, "type": "large",  "flip": false},
	]

static func get_right_rooms_data() -> Array:
	return [
		{"name": "421", "z": 22.5,  "flip": false},
		{"name": "420", "z": 17.5,  "flip": false},
		{"name": "417", "z": 12.5,  "flip": false},
		{"name": "416", "z": 7.5,   "flip": false},
		{"name": "415", "z": 2.5,   "flip": false},
		{"name": "413", "z": -2.5,  "flip": false},
		{"name": "412", "z": -7.5,  "flip": false},
		{"name": "411", "z": -12.5, "flip": false},
		{"name": "410", "z": -17.5, "flip": false},
	]

static func get_south_stair_z() -> float:
	return 27.5 * GlobalConfig.get_floor_scale()

static func get_map_decal_z() -> float:
	return -16.0 * GlobalConfig.get_floor_scale()

static func get_elevator_z() -> float:
	return -27.5 * GlobalConfig.get_floor_scale()

static func get_maintenance_z() -> float:
	return -25.0 * GlobalConfig.get_floor_scale()
