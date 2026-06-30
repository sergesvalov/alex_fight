# scripts/enemies/cerberus_ai.gd
class_name CerberusAI
extends CharacterBody3D

@export var idle_wait_time: float = 2.0
@export var patrol_speed: float = 3.0
@export var chase_speed: float = 6.5
@export var attack_range: float = 2.0
@export var attack_damage: int = 40
@export var attack_cooldown: float = 1.5
@export var patrol_points: Array[Marker3D] = []

@onready var movement: CerberusMovement = $CerberusMovement
@onready var sensors: CerberusSensors = $CerberusSensors

enum State { IDLE, PATROL, CHASE, ATTACK, RETURN, DEAD }
var current_state: State = State.IDLE
var player: CharacterBody3D = null
var spawn_position: Vector3
var current_patrol_index: int = 0

var attack_timer: float = 0.0
var idle_timer: float = 0.0

func _ready() -> void:
    add_to_group("enemies")
    spawn_position = global_position
    
    sensors.player_detected.connect(_on_player_detected)
    sensors.player_lost.connect(_on_player_lost)
    
    if patrol_points.size() > 0:
        _set_state(State.PATROL)
    else:
        _set_state(State.IDLE)

func _physics_process(delta: float) -> void:
    movement.apply_gravity(delta)
    attack_timer -= delta
    
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
        
    movement.nav_agent.target_position = player.global_position
    movement.move_along_nav(chase_speed)
    
    if not sensors.has_line_of_sight(player):
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
    
    var target_pos = player.global_position
    target_pos.y = global_position.y
    look_at(target_pos, Vector3.UP)
    
    if global_position.distance_to(player.global_position) > attack_range * 1.5:
        _set_state(State.CHASE)
        return
    
    if attack_timer <= 0.0:
        _perform_attack()
        attack_timer = attack_cooldown

func _perform_attack() -> void:
    if player.has_method("take_damage"):
        player.take_damage(attack_damage)
        print("Cerberus attacked player for ", attack_damage)

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

func _on_player_detected(p: Node3D) -> void:
    if current_state != State.ATTACK:
        player = p
        _set_state(State.CHASE)

func _on_player_lost() -> void:
    pass

func take_damage(amount: int) -> void:
    print("Cerberus took damage: ", amount)
    _set_state(State.DEAD)
    queue_free()
