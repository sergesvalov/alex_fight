class_name HotelConstants
extends RefCounted

const BASE_CORRIDOR_HEIGHT: float = 4.0
const BASE_FLOOR_THICKNESS: float = 0.5
const BASE_FLOOR_TO_FLOOR_HEIGHT: float = BASE_CORRIDOR_HEIGHT + BASE_FLOOR_THICKNESS

const BUILDING_LENGTH_Z: float = 60.0
const BUILDING_WIDTH_X: float = 25.3

const NORTH_ZONE_INNER_X: float = -2.55
const DOUBLE_ROOM_BASE_X: float = -7.65
const SINGLE_ROOM_BASE_X: float = 8.7

const CORRIDOR_WEST_EDGE_X: float = -2.75
const CORRIDOR_EAST_EDGE_X: float = 4.85

const NORTH_STAIRS_CENTER_X: float = 1.05
const NORTH_STAIRS_CENTER_Z: float = -30.0

const ELEVATOR_CENTER_X: float = 7.2
const ELEVATOR_CENTER_Z: float = -25.0

const SOUTH_STAIRS_DOOR_CENTER_X: float = 1.05
const SOUTH_STAIRS_ZONE_Z_START: float = 25.0
const SOUTH_STAIRS_ZONE_Z_END: float = 30.0
const SOUTH_STAIRS_RAMP_INNER_X: float = 1.87
const SOUTH_STAIRS_LANDING_INNER_X: float = 8.03
const SOUTH_STAIRS_LANDING_OUTER_X: float = 12.65

const DOUBLE_ROOM_LAYOUT := {
	401: {"z": -30.0, "mirror": false},
	402: {"z": -20.0, "mirror": false},
	403: {"z": 0.0, "mirror": true},
	405: {"z": 0.0, "mirror": false},
	406: {"z": 10.0, "mirror": false},
	408: {"z": 30.0, "mirror": true},
}

const SINGLE_ROOM_LAYOUT := {
	410: {"z": -20.0, "mirror": false},
	411: {"z": -10.0, "mirror": true},
	412: {"z": -10.0, "mirror": false},
	413: {"z": 0.0, "mirror": true},
	415: {"z": 0.0, "mirror": false},
	416: {"z": 10.0, "mirror": true},
	417: {"z": 15.0, "mirror": true},
	420: {"z": 15.0, "mirror": false},
	421: {"z": 25.0, "mirror": true},
}

const DOUBLE_ROOM_EXIT_DOOR_LOCAL_Z: float = 5.0
const SINGLE_ROOM_EXIT_DOOR_LOCAL_Z: float = 3.05
