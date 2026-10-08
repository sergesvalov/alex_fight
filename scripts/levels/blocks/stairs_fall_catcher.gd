# scripts/levels/blocks/stairs_fall_catcher.gd
# Spans North Stairs' own interior footprint on ONE floor (see _generate_north_stairs() in
# hotel_level_generator.gd, which creates one instance per floor) - stacked across all 10 floor
# instances it forms one continuous column covering the whole stairwell shaft. A player
# legitimately climbing the ramps/landings is on_floor() almost the entire time, so standing or
# walking inside this zone never trips it, no matter how long they linger; only actually falling
# through the open shaft air (stepped or knocked off a ramp/landing edge) accumulates fall time,
# and FALL_TIME_LIMIT continuous seconds of that means they've already fallen well past any floor they could
# have landed on normally - exactly the reported bug where a player who fell down the shaft ended
# up on floor 1 despite the stairs_gate.gd door checks (falling through open air never crosses a
# door's Area3D, so those checks never got a chance to fire). Kept short (not a more generous
# margin) because a real multi-floor fall builds up enough velocity to hurt on landing - rescuing
# quickly matters more here than tolerating a long graceful arc.
extends Area3D

# 1.2s of free fall is ~7m - more than any drop the stairs themselves have (1.5m between
# landings), less than the ~1.9s it takes to hit floor 1's slab from the starting floor. (Was
# 2.0s, which that fall never reached.)
const FALL_TIME_LIMIT: float = 1.2

# Shared by every floor's catcher, not per instance: a fall through the shaft crosses one
# catcher per floor in under a second each, so a timer that restarts on entering each of them
# never gets anywhere near the limit, no matter how far the player falls.
static var _fall_time: Dictionary = {}   # body -> seconds of continuous falling
# body -> physics frame already counted (two stacked catchers both overlap the body for a moment
# at a floor boundary - without this that stretch would be counted twice).
static var _fall_frame: Dictionary = {}

var _inside: Array = []

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 # Player layer
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_physics_process(false)

func _on_body_entered(body: Node) -> void:
	if body.name != "Player":
		return
	if not _inside.has(body):
		_inside.append(body)
	set_physics_process(true)

func _on_body_exited(body: Node) -> void:
	_inside.erase(body)
	if _inside.is_empty():
		set_physics_process(false)

func _physics_process(delta: float) -> void:
	var frame: int = Engine.get_physics_frames()
	for body in _inside.duplicate():
		if not is_instance_valid(body):
			_inside.erase(body)
			continue
		if body.has_method("is_on_floor") and body.is_on_floor():
			_fall_time[body] = 0.0
			continue
		if _fall_frame.get(body, -1) == frame:
			continue
		_fall_frame[body] = frame
		_fall_time[body] = _fall_time.get(body, 0.0) + delta
		if _fall_time[body] >= FALL_TIME_LIMIT:
			_fall_time[body] = 0.0
			_rescue(body)
	if _inside.is_empty():
		set_physics_process(false)

func _rescue(body: Node) -> void:
	# Bug (reported 2026-08-23 as "keeps teleporting me to floor 4 when I should be on floor 3"):
	# this used to always send the rescued player to floor4_spawn_position AND force
	# current_floor = 4, regardless of which floor they actually fell from. A player legitimately
	# on floor 3 (via the secret exit door) who spent >=2s off-floor anywhere in that floor's own
	# North Stairs shaft - plausible from perfectly normal stair use, not just a real fall, since
	# is_on_floor() can read false for a moment on a ramp/landing edge - got yanked all the way
	# back to floor 4 for no visible reason.
	# Fix: every floor is the same generated layout, just offset in Y (see
	# hotel_level_generator.gd's y_offset = (i - floor_number) * y_step) - so floor4_spawn_position
	# plus that same Y offset for whatever floor the player is ACTUALLY on lands them in the
	# equivalent room on THEIR OWN floor, not floor 4's.
	var f_scale: float = GlobalConfig.get_floor_scale() if GlobalConfig else 1.0
	var y_step: float = HotelConstants.BASE_FLOOR_TO_FLOOR_HEIGHT * f_scale
	var current_floor: int = GameStateManager.current_floor
	var rescue_pos: Vector3 = GameStateManager.floor4_spawn_position
	rescue_pos.y += (current_floor - 4) * y_step

	print("[StairsFallCatcher] ", name, " rescuing ", body.name, " from ", body.global_position,
		" to ", rescue_pos, " (current_floor=", current_floor, ", unchanged)")
	body.global_position = rescue_pos
	if "velocity" in body:
		body.velocity = Vector3.ZERO
