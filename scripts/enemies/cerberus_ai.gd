# scripts/enemies/cerberus_ai.gd
class_name CerberusAI
extends CharacterBody3D

# === Параметры ===
@export var idle_wait_time: float = 2.0
@export var patrol_speed: float = 3.0
@export var chase_speed: float = 6.5
@export var attack_range: float = 2.0
@export var detection_range: float = 12.0
@export var attack_damage: int = 40
@export var attack_cooldown: float = 1.5
@export var patrol_points: Array[Marker3D] = []

# === Узлы ===
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var detection_area: Area3D = $DetectionArea
@onready var ray_sight: RayCast3D = $RayCast3D
# @onready var anim: AnimationPlayer = $AnimationPlayer
# @onready var audio: AudioStreamPlayer3D = $AudioStreamPlayer3D

# === Состояние ===
enum State { IDLE, PATROL, CHASE, ATTACK, RETURN, DEAD }
var current_state: State = State.IDLE
var player: CharacterBody3D = null
var spawn_position: Vector3
var current_patrol_index: int = 0
var attack_timer: float = 0.0
var idle_timer: float = 0.0
var gravity: float = 9.8

func _ready() -> void:
    add_to_group("enemies")
    spawn_position = global_position
    detection_area.body_entered.connect(_on_body_entered_detection)
    detection_area.body_exited.connect(_on_body_exited_detection)
    
    if patrol_points.size() > 0:
        _set_state(State.PATROL)
    else:
        _set_state(State.IDLE)

func _physics_process(delta: float) -> void:
    _apply_gravity(delta)
    attack_timer -= delta
    
    match current_state:
        State.IDLE:     _state_idle(delta)
        State.PATROL:   _state_patrol(delta)
        State.CHASE:    _state_chase(delta)
        State.ATTACK:   _state_attack(delta)
        State.RETURN:   _state_return(delta)
    
    move_and_slide()

# ── IDLE ──────────────────────────────────────────────────
func _state_idle(delta: float) -> void:
    # if anim.has_animation("idle"): anim.play("idle")
    idle_timer -= delta
    if idle_timer <= 0 and patrol_points.size() > 0:
        _set_state(State.PATROL)

# ── PATROL ────────────────────────────────────────────────
func _state_patrol(delta: float) -> void:
    if patrol_points.is_empty():
        _set_state(State.IDLE)
        return
    # if anim.has_animation("walk"): anim.play("walk")
    var target_point: Vector3 = patrol_points[current_patrol_index].global_position
    nav_agent.target_position = target_point
    _move_along_nav(patrol_speed)
    
    if global_position.distance_to(target_point) < 0.5:
        current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
        idle_timer = idle_wait_time
        _set_state(State.IDLE)

# ── CHASE ─────────────────────────────────────────────────
func _state_chase(delta: float) -> void:
    if not is_instance_valid(player):
        _set_state(State.RETURN)
        return
    # if anim.has_animation("run"): anim.play("run")
    nav_agent.target_position = player.global_position
    _move_along_nav(chase_speed)
    
    # Потерял ли видимость?
    if not _has_line_of_sight():
        if attack_timer <= -3.0: # Используем attack_timer как таймер потери
            _set_state(State.RETURN)
            return
    else:
        attack_timer = 0.0
    
    # В радиусе атаки?
    if global_position.distance_to(player.global_position) <= attack_range:
        _set_state(State.ATTACK)

# ── ATTACK ────────────────────────────────────────────────
func _state_attack(_delta: float) -> void:
    if not is_instance_valid(player):
        _set_state(State.RETURN)
        return
    
    # Смотреть на игрока
    var target_pos = player.global_position
    target_pos.y = global_position.y
    look_at(target_pos, Vector3.UP)
    
    # Выход из атаки если игрок убежал
    if global_position.distance_to(player.global_position) > attack_range * 1.5:
        _set_state(State.CHASE)
        return
    
    if attack_timer <= 0.0:
        _perform_attack()
        attack_timer = attack_cooldown

func _perform_attack() -> void:
    # if anim.has_animation("attack"): anim.play("attack")
    # if audio: audio.play()  # Звук рыка
    # Нанести урон
    if player.has_method("take_damage"):
        player.take_damage(attack_damage)
        print("Cerberus attacked player for ", attack_damage)

# ── RETURN ────────────────────────────────────────────────
func _state_return(_delta: float) -> void:
    nav_agent.target_position = spawn_position
    _move_along_nav(patrol_speed)
    if global_position.distance_to(spawn_position) < 0.5:
        player = null
        _set_state(State.IDLE)

# ── HELPERS ───────────────────────────────────────────────
func _move_along_nav(speed: float) -> void:
    if nav_agent.is_navigation_finished(): return
    var next_pos: Vector3 = nav_agent.get_next_path_position()
    var direction: Vector3 = (next_pos - global_position).normalized()
    velocity.x = direction.x * speed
    velocity.z = direction.z * speed
    if direction != Vector3.ZERO:
        var look_pos = global_position + direction
        look_pos.y = global_position.y
        look_at(look_pos, Vector3.UP)

func _apply_gravity(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= gravity * delta

func _has_line_of_sight() -> bool:
    if not is_instance_valid(player):
        return false
    ray_sight.target_position = ray_sight.to_local(player.global_position)
    ray_sight.force_raycast_update()
    if ray_sight.is_colliding():
        return ray_sight.get_collider() == player
    return false

func _set_state(new_state: State) -> void:
    current_state = new_state
    if new_state == State.CHASE:
        GameStateManager.change_state(GameStateManager.GameState.COMBAT)
        AudioManager.play_music("combat")
    elif new_state == State.RETURN or new_state == State.IDLE:
        if GameStateManager.current_state == GameStateManager.GameState.COMBAT:
            GameStateManager.change_state(GameStateManager.GameState.EXPLORING)

func _on_body_entered_detection(body: Node3D) -> void:
    if body.is_in_group("player") and current_state != State.ATTACK:
        player = body
        _set_state(State.CHASE)

func _on_body_exited_detection(body: Node3D) -> void:
    pass  # Проверяется через line of sight
    
func take_damage(amount: int) -> void:
    print("Cerberus took damage: ", amount)
    _set_state(State.DEAD)
    queue_free()
