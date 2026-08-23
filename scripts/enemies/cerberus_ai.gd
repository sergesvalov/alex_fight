# scripts/enemies/cerberus_ai.gd
class_name CerberusAI
extends CharacterBody3D

@export var idle_wait_time: float = 2.0
@export var patrol_speed: float = 3.0
@export var chase_speed: float = 6.5
# Ranged now (a security robot with a laser rifle, not a melee creature) - engages from across
# a room/corridor instead of needing to close to point-blank range.
@export var attack_range: float = 10.0
@export var attack_damage: int = 15
@export var attack_cooldown: float = 1.2
@export var patrol_points: Array[Marker3D] = []

@onready var movement: CerberusMovement = $CerberusMovement
@onready var sensors: CerberusSensors = $CerberusSensors
@onready var weapon_beam: MeshInstance3D = $RobotBody/Weapon/WeaponBeam
@onready var audio: AudioStreamPlayer3D = $AudioStreamPlayer3D

var shoot_sound = preload("res://assets/audio/sfx/shoot.wav")

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

func _ready() -> void:
    add_to_group("enemies")
    spawn_position = global_position
    
    var c_scale = GlobalConfig.player_height / 1.6
    scale = Vector3(c_scale, c_scale, c_scale)

    # Sub-resources loaded from a .tscn are shared across every instance of that scene by
    # default - with 10 floors each spawning their own robot, mutating weapon_beam.mesh directly
    # would resize every other robot's beam too (same gotcha laser_pistol.gd already works around
    # for the player's own beam_mesh).
    if weapon_beam and weapon_beam.mesh:
        weapon_beam.mesh = weapon_beam.mesh.duplicate()

    sensors.player_detected.connect(_on_player_detected)
    sensors.player_lost.connect(_on_player_lost)
    
    if patrol_points.size() > 0:
        _set_state(State.PATROL)
    else:
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

func _state_patrol(_delta: float) -> void:
    if patrol_points.is_empty():
        _set_state(State.IDLE)
        return
        
    var target_point: Vector3 = patrol_points[current_patrol_index].global_position
    movement.nav_agent.target_position = target_point
    movement.move_along_nav(patrol_speed)
    
    if global_position.distance_to(target_point) < 0.5:
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
        movement.nav_agent.target_position = player.global_position
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
    
    if global_position.distance_to(player.global_position) <= attack_range:
        _set_state(State.ATTACK)

func _state_attack(_delta: float) -> void:
    if not is_instance_valid(player):
        _set_state(State.RETURN)
        return
    
    var to_player: Vector3 = player.global_position - global_position
    to_player.y = 0.0
    if to_player.length_squared() > 0.0001:
        look_at(global_position + to_player, Vector3.UP)
    
    if global_position.distance_to(player.global_position) > attack_range * 1.5:
        _set_state(State.CHASE)
        return
    
    if attack_timer <= 0.0:
        _perform_attack()
        attack_timer = attack_cooldown

func _perform_attack() -> void:
    # Ranged attack - unlike the old point-blank bite, a wall between the robot and the player
    # must actually block the shot, not just distance.
    if not sensors.has_line_of_sight(player):
        return

    _fire_laser()
    if player.has_method("take_damage"):
        player.take_damage(attack_damage)
        print("Cerberus attacked player for ", attack_damage)

func _fire_laser() -> void:
    if audio:
        audio.stream = shoot_sound
        audio.play()

    if not weapon_beam or not is_instance_valid(player):
        return

    var distance: float = weapon_beam.get_parent().global_position.distance_to(player.global_position)
    weapon_beam.mesh.height = distance
    weapon_beam.position.z = -distance / 2.0
    weapon_beam.scale = Vector3(1, 1, 1)
    weapon_beam.show()

    # Shrinks the beam's cross-section (local X/Z) to a point while keeping its length (local Y,
    # which the node's baked -90deg X rotation maps to world -Z) - same fade laser_pistol.gd
    # uses for the player's own beam.
    var tween := create_tween()
    tween.tween_property(weapon_beam, "scale", Vector3(0, 0, 1), 0.15)
    tween.tween_callback(weapon_beam.hide)

func _state_return(_delta: float) -> void:
    movement.nav_agent.target_position = spawn_position
    movement.move_along_nav(patrol_speed)
    if global_position.distance_to(spawn_position) < 0.5:
        player = null
        _set_state(State.IDLE)

func _set_state(new_state: State) -> void:
    current_state = new_state
    if new_state == State.CHASE:
        GameStateManager.change_state(GameStateManager.GameState.COMBAT)
        AudioManager.play_music("combat")
    elif new_state == State.RETURN or new_state == State.IDLE:
        if GameStateManager.current_state == GameStateManager.GameState.COMBAT:
            GameStateManager.change_state(GameStateManager.GameState.EXPLORING)

    # ATTACK/IDLE never touch velocity.x/z themselves (only CHASE/PATROL/RETURN do, via
    # move_along_nav) - without this, a robot that just arrived here from CHASE keeps sliding at
    # chase_speed on whatever direction it last had, fighting look_at()'s per-frame reorientation
    # every physics tick. Harmless at the old attack_range=2.0 (stopped almost instantly), but at
    # the current attack_range=10.0 that stale slide reads as standing in place and twitching.
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
    print("Cerberus took damage: ", amount)
    _set_state(State.DEAD)
    queue_free()
