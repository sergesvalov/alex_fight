# scripts/player/player_controller.gd
class_name PlayerController
extends CharacterBody3D

# === Параметры ===
@export var walk_speed: float = 4.0
@export var sprint_speed: float = 7.0
@export var camera_sensitivity: float = 0.003    # Для тач-управления
@export var gravity: float = 9.8
@export var jump_height: float = 0.0             # Без прыжков в шутере

# === Узлы ===
@onready var camera_rig: Node3D = $CameraRig
@onready var camera: Camera3D = $CameraRig/Camera3D
@onready var ray_interact: RayCast3D = $RayCast3D
# @onready var weapon: Node3D = $CameraRig/Camera3D/WeaponHolder/Shotgun
# @onready var left_joystick: VirtualJoystick = %LeftJoystick
# @onready var right_joystick: VirtualJoystick = %RightJoystick

# === Состояние ===
var move_input: Vector2 = Vector2.ZERO
var look_input: Vector2 = Vector2.ZERO
var is_sprinting: bool = false
var camera_x_rotation: float = 0.0
const CAMERA_X_LIMIT: float = PI / 2.5

func _ready() -> void:
    # Jolt physics tweaks
    collision_layer = 1   # Слой "Player"
    collision_mask = 2    # Видит слой "World"
    floor_stop_on_slope = true
    floor_max_angle = deg_to_rad(45)
    floor_snap_length = 0.1

    # Подключение UI (когда будет добавлено в дерево сцен)
    var hud = null
    if get_tree().current_scene:
        hud = get_tree().current_scene.find_child("HUD", true, false)
    if not hud:
        hud = get_node_or_null("../HUD")
    if hud:
        var left = hud.find_child("LeftJoystick", true, false)
        var right = hud.find_child("RightJoystick", true, false)
        if left: left.input_vector_changed.connect(_on_left_joystick_changed)
        if right: right.input_vector_changed.connect(_on_right_joystick_changed)
    
    # Для десктоп теста
    if OS.get_name() in ["Windows", "macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
    if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
        look_input = -event.relative * 0.5 # mouse sensitivity scaling

func _on_left_joystick_changed(vector: Vector2) -> void:
    move_input = vector

func _on_right_joystick_changed(vector: Vector2) -> void:
    look_input = vector

func _physics_process(delta: float) -> void:
    if GameStateManager.current_state == GameStateManager.GameState.READING:
        return  # Заморозить управление во время чтения
        
    # Десктоп-фаллбэк (WASD)
    if move_input == Vector2.ZERO:
        move_input.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
        move_input.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
        if move_input.length() > 1.0: move_input = move_input.normalized()
    
    _apply_gravity(delta)
    _apply_movement(delta)
    _apply_look(delta)
    move_and_slide()
    
    # Reset look input from mouse to prevent spinning if used as direct offset rather than vector
    if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        look_input = Vector2.ZERO

func _apply_movement(delta: float) -> void:
    var speed: float = sprint_speed if is_sprinting else walk_speed
    var direction: Vector3 = (
        transform.basis.x * move_input.x +
        transform.basis.z * move_input.y
    ).normalized()
    velocity.x = direction.x * speed
    velocity.z = direction.z * speed

func _apply_look(delta: float) -> void:
    if look_input == Vector2.ZERO: return
    
    var look_factor = camera_sensitivity * 60 * delta
    if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        look_factor = camera_sensitivity
        
    rotate_y(-look_input.x * look_factor)
    camera_x_rotation -= look_input.y * look_factor
    camera_x_rotation = clamp(camera_x_rotation, -CAMERA_X_LIMIT, CAMERA_X_LIMIT)
    camera_rig.rotation.x = camera_x_rotation

func _apply_gravity(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= gravity * delta

func try_interact() -> void:
    if ray_interact.is_colliding():
        var collider = ray_interact.get_collider()
        if collider.has_method("interact"):
            collider.interact(self)
