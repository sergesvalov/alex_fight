# scripts/enemies/enemy_ai_base.gd
# Shared enemy AI: the Finite State Machine (IDLE, PATROL, CHASE, ATTACK, RETURN, DEAD),
# navigation/detection wiring, and generic melee-ish combat defaults. Concrete enemies (see
# cerberus_ai.gd) extend this and only override what actually makes them different - typically
# just _perform_attack() (and maybe _ready()/_die() for extra setup or a death effect). Splitting
# this out of what used to be cerberus_ai.gd means a second enemy type doesn't start by copying
# ~200 lines of state-machine plumbing and quietly drifting out of sync with bugfixes made to
# the original.
class_name EnemyAI
extends CharacterBody3D

@export var idle_wait_time: float = 2.0
@export var patrol_speed: float = 3.0
@export var chase_speed: float = 6.5
@export var attack_range: float = 2.0
@export var attack_damage: int = 20
@export var attack_cooldown: float = 1.5
@export var patrol_points: Array[Marker3D] = []

# Node names are fixed by convention (every enemy .tscn built on this base names its nodes the
# same way) rather than configurable, so new enemy scenes can just copy the skeleton wholesale.
@onready var movement: EnemyMovement = $Movement
@onready var sensors: EnemySensors = $Sensors

enum State { IDLE, PATROL, CHASE, ATTACK, RETURN, DEAD }
var current_state: State = State.IDLE
var player: CharacterBody3D = null
var spawn_position: Vector3
var current_patrol_index: int = 0

var attack_timer: float = 0.0
var idle_timer: float = 0.0
var _nav_update_timer: float = 0.0
var _los_check_timer: float = 0.0
var _last_los: bool = false

# Интервалы обновления (throttle)
const NAV_UPDATE_INTERVAL: float = 0.3
const LOS_CHECK_INTERVAL: float = 0.2

# Diagnostic only - catches "stuck in place, spinning wildly" reports (reported 2026-08-23 on
# floor 4). ATTACK is the one state that never calls move_along_nav() - if it IS the state
# reported as "spinning on the spot", this look_at() toward a jittering to_player is the only
# candidate (e.g. the player standing pressed right up against the enemy's own collider, so
# their relative position swings wildly frame to frame even though both bodies barely move).
const ATTACK_ROTATION_SPIKE_DEG_THRESHOLD: float = 60.0
const ATTACK_ROTATION_SPIKE_LOG_INTERVAL: float = 0.5
var _attack_rotation_spike_log_timer: float = 0.0

func _ready() -> void:
	add_to_group("enemies")
	spawn_position = global_position

	sensors.player_detected.connect(_on_player_detected)
	sensors.player_lost.connect(_on_player_lost)

	# Always start in IDLE, even with patrol points - hotel_level_generator.gd bakes the
	# NavigationRegion3D's navmesh AFTER the whole level (including every enemy) is already in
	# the tree, and bake_navigation_mesh() defaults to on_thread=true (bakes in the background,
	# doesn't block) - there's no fixed number of frames that's "surely" long enough to guarantee
	# it's done, especially baking a whole 10-floor hotel on slower hardware. Entering PATROL
	# before the navmesh is ready sets NavigationAgent3D.target_position with nothing to path
	# across, and since _state_patrol() re-assigns that SAME target_position every frame,
	# NavigationAgent3D never sees a value change and never retries the query once the navmesh
	# actually becomes available - the enemy silently never moves, forever.
	# _on_navmesh_ready() (below) is the real fix - the generator calls it on every "enemies"
	# group member via bake_finished, the instant the navmesh is actually ready. idle_timer is
	# still given a generous fallback value here in case that call is ever missed for some
	# reason, but it should normally never be what actually starts PATROL.
	idle_timer = idle_wait_time * 3.0
	_set_state(State.IDLE)

func _physics_process(delta: float) -> void:
	movement.apply_gravity(delta)
	attack_timer -= delta
	_nav_update_timer -= delta
	_los_check_timer -= delta

	match current_state:
		State.IDLE:     _state_idle(delta)
		State.PATROL:   _state_patrol(delta)
		State.CHASE:    _state_chase(delta)
		State.ATTACK:   _state_attack(delta)
		State.RETURN:   _state_return(delta)

	move_and_slide()

func _state_idle(delta: float) -> void:
	idle_timer -= delta
	if idle_timer <= 0 and patrol_points.size() > 0:
		_set_state(State.PATROL)

# Called via get_tree().call_group("enemies", ...) from hotel_level_generator.gd the instant
# NavigationRegion3D.bake_finished fires - the real, timing-independent signal that pathfinding
# will actually work now, unlike guessing a fixed delay is "surely" long enough.
func _on_navmesh_ready() -> void:
	if current_state == State.IDLE and patrol_points.size() > 0:
		_set_state(State.PATROL)

# Horizontal-only distance from global_position to target - used everywhere below instead of
# Vector3.distance_to()/nav_agent.distance_to_target(). Root cause of the "stuck in place,
# spinning wildly" report (2026-08-23, confirmed via the ROTATION SPIKE diagnostic log): a target
# whose Y differs from the enemy's own resting Y (e.g. spawn_position, captured in _ready() before
# gravity ever settles the body onto the floor, so it can end up ~1m off) can never be closed to
# zero in full 3D distance even once the enemy is standing right on top of it horizontally -
# NavigationAgent3D.is_navigation_finished() then never reports true, and move_along_nav() keeps
# recomputing a direction toward an unreachable point every physics tick, flipping ~180° each time
# as the enemy overshoots back and forth across the one XZ point it CAN reach.
func _flat_distance(target: Vector3) -> float:
	var to_target: Vector3 = target - global_position
	to_target.y = 0.0
	return to_target.length()

func _state_patrol(_delta: float) -> void:
	if patrol_points.is_empty():
		_set_state(State.IDLE)
		return

	var target_point: Vector3 = patrol_points[current_patrol_index].global_position
	var nav_target: Vector3 = target_point
	nav_target.y = global_position.y
	movement.nav_agent.target_position = nav_target
	movement.move_along_nav(patrol_speed)

	if _flat_distance(target_point) < 0.5:
		current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
		idle_timer = idle_wait_time
		_set_state(State.IDLE)

func _state_chase(_delta: float) -> void:
	if not is_instance_valid(player):
		_set_state(State.RETURN)
		return

	if GameStateManager.current_state == GameStateManager.GameState.SPECTATOR:
		player = null
		_set_state(State.RETURN)
		return

	# Throttle: обновляем маршрут раз в NAV_UPDATE_INTERVAL
	if _nav_update_timer <= 0.0:
		var nav_target: Vector3 = player.global_position
		nav_target.y = global_position.y
		movement.nav_agent.target_position = nav_target
		_nav_update_timer = NAV_UPDATE_INTERVAL
	movement.move_along_nav(chase_speed)

	# Throttle: проверяем линию видимости раз в LOS_CHECK_INTERVAL
	if _los_check_timer <= 0.0:
		_last_los = sensors.has_line_of_sight(player)
		_los_check_timer = LOS_CHECK_INTERVAL

	if not _last_los:
		if attack_timer <= -3.0:
			_set_state(State.RETURN)
	else:
		attack_timer = 0.0

	if _flat_distance(player.global_position) <= attack_range:
		_set_state(State.ATTACK)

func _state_attack(_delta: float) -> void:
	if not is_instance_valid(player):
		_set_state(State.RETURN)
		return

	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	if to_player.length_squared() > 0.0001:
		var prev_facing: Vector3 = -global_transform.basis.z
		look_at(global_position + to_player, Vector3.UP)
		_log_attack_rotation_spike_if_any(prev_facing, to_player)

	if _flat_distance(player.global_position) > attack_range * 1.5:
		_set_state(State.CHASE)
		return

	if attack_timer <= 0.0:
		_perform_attack()
		attack_timer = attack_cooldown

func _log_attack_rotation_spike_if_any(prev_facing: Vector3, to_player: Vector3) -> void:
	var new_facing: Vector3 = -global_transform.basis.z
	var angle_deg: float = rad_to_deg(prev_facing.angle_to(new_facing))
	if angle_deg <= ATTACK_ROTATION_SPIKE_DEG_THRESHOLD:
		return
	_attack_rotation_spike_log_timer -= get_physics_process_delta_time()
	if _attack_rotation_spike_log_timer > 0.0:
		return
	_attack_rotation_spike_log_timer = ATTACK_ROTATION_SPIKE_LOG_INTERVAL
	print("[EnemyAI] ", name, " ATTACK ROTATION SPIKE ", angle_deg, "deg/tick pos=", global_position,
		" player_pos=", (player.global_position if is_instance_valid(player) else "?"),
		" to_player=", to_player, " to_player_len=", to_player.length(),
		" attack_timer=", attack_timer, " velocity=", velocity)

# Generic default: plain melee, no line-of-sight check, no visual/audio effect - good enough for
# a simple contact-damage enemy as-is. Ranged or otherwise fancier enemies (see cerberus_ai.gd's
# laser) override this entirely instead of calling super().
func _perform_attack() -> void:
	if player.has_method("take_damage"):
		player.take_damage(attack_damage)
		print(name, " attacked player for ", attack_damage)

func _state_return(_delta: float) -> void:
	var nav_target: Vector3 = spawn_position
	nav_target.y = global_position.y
	movement.nav_agent.target_position = nav_target
	movement.move_along_nav(patrol_speed)
	if _flat_distance(spawn_position) < 0.5:
		player = null
		_set_state(State.IDLE)

func _set_state(new_state: State) -> void:
	print("[EnemyAI] ", name, " state ", State.keys()[current_state], " -> ", State.keys()[new_state],
		" pos=", global_position, " patrol_points=", patrol_points.size())
	current_state = new_state
	if new_state == State.CHASE:
		# attack_timer decrements unconditionally every physics tick regardless of state (see
		# _physics_process), so after any stretch of time spent IDLE/PATROL/RETURN before this
		# detection (which, in practice, is however long this enemy has existed since its own
		# _ready() - easily tens of seconds during level generation) it can already be deeply
		# negative. _state_chase()'s "give up after 3s without line of sight" check
		# (attack_timer <= -3.0) doesn't care WHY it's negative - without this reset, a fresh
		# detection could see a stale timer already past -3.0 and instantly bail back to RETURN
		# on its very first tick, before line-of-sight is even checked once. Reported 2026-08-23
		# as "robot notices me but never actually attacks."
		attack_timer = 0.0
		GameStateManager.change_state(GameStateManager.GameState.COMBAT)
		AudioManager.play_music("combat")
	elif new_state == State.RETURN or new_state == State.IDLE:
		if GameStateManager.current_state == GameStateManager.GameState.COMBAT:
			GameStateManager.change_state(GameStateManager.GameState.EXPLORING)

	# ATTACK/IDLE never touch velocity.x/z themselves (only CHASE/PATROL/RETURN do, via
	# move_along_nav) - without this, an enemy that just arrived here from CHASE keeps sliding at
	# chase_speed on whatever direction it last had, fighting look_at()'s per-frame reorientation
	# every physics tick - harmless for a short-range melee attack_range (stops almost instantly),
	# but very visible for anything with a long attack_range (e.g. Cerberus's ranged laser).
	if new_state == State.ATTACK or new_state == State.IDLE:
		velocity.x = 0.0
		velocity.z = 0.0

func _on_player_detected(p: Node3D) -> void:
	if GameStateManager.current_state == GameStateManager.GameState.SPECTATOR:
		return

	if current_state != State.ATTACK:
		player = p
		_set_state(State.CHASE)

func _on_player_lost() -> void:
	pass

func take_damage(amount: int) -> void:
	print(name, " took damage: ", amount)
	_set_state(State.DEAD)
	_die()

# Overridable hook for a death effect/sound/drop - default is just to disappear immediately.
func _die() -> void:
	queue_free()
