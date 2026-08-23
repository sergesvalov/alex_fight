# scripts/levels/blocks/stairs_fall_catcher.gd
# Spans North Stairs' own interior footprint on ONE floor (see _generate_north_stairs() in
# hotel_level_generator.gd, which creates one instance per floor) - stacked across all 10 floor
# instances it forms one continuous column covering the whole stairwell shaft. A player
# legitimately climbing the ramps/landings is on_floor() almost the entire time, so standing or
# walking inside this zone never trips it, no matter how long they linger; only actually falling
# through the open shaft air (stepped or knocked off a ramp/landing edge) accumulates fall time,
# and 2 continuous seconds of that means they've already fallen well past any floor they could
# have landed on normally - exactly the reported bug where a player who fell down the shaft ended
# up on floor 1 despite the stairs_gate.gd door checks (falling through open air never crosses a
# door's Area3D, so those checks never got a chance to fire). Kept short (2s, not a more generous
# margin) because a real multi-floor fall builds up enough velocity to hurt on landing - rescuing
# quickly matters more here than tolerating a long graceful arc.
extends Area3D

const FALL_TIME_LIMIT: float = 2.0

var _falling: Dictionary = {} # body -> accumulated seconds of continuous falling

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 # Player layer
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_physics_process(false)

func _on_body_entered(body: Node) -> void:
	if body.name != "Player":
		return
	_falling[body] = 0.0
	set_physics_process(true)

func _on_body_exited(body: Node) -> void:
	_falling.erase(body)
	if _falling.is_empty():
		set_physics_process(false)

func _physics_process(delta: float) -> void:
	for body in _falling.keys():
		if not is_instance_valid(body):
			_falling.erase(body)
			continue
		if body.has_method("is_on_floor") and body.is_on_floor():
			_falling[body] = 0.0
			continue
		_falling[body] += delta
		if _falling[body] >= FALL_TIME_LIMIT:
			_falling.erase(body)
			_rescue(body)
	if _falling.is_empty():
		set_physics_process(false)

func _rescue(body: Node) -> void:
	# Diagnostic (2026-08-23) - see stairs_gate.gd's matching print for why.
	print("[StairsFallCatcher] ", name, " rescuing ", body.name, " from ", body.global_position,
		" to floor4_spawn_position=", GameStateManager.floor4_spawn_position)
	body.global_position = GameStateManager.floor4_spawn_position
	if "velocity" in body:
		body.velocity = Vector3.ZERO
	GameStateManager.current_floor = 4
