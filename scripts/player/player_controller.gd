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
@onready var weapon_holder: Node3D = $CameraRig/Camera3D/WeaponHolder
@onready var laser_pistol: Node3D = $CameraRig/Camera3D/WeaponHolder/LaserPistol
# @onready var left_joystick: VirtualJoystick = %LeftJoystick
# @onready var right_joystick: VirtualJoystick = %RightJoystick

# === Состояние ===
var move_input: Vector2 = Vector2.ZERO
var is_sprinting: bool = false
var camera_x_rotation: float = 0.0
const CAMERA_X_LIMIT: float = PI / 2.5
var is_desktop: bool = false
var hud_heat_bar: ProgressBar = null
var hud_tapes_counter: Label = null
var tapes_collected: int = 0
var max_tapes: int = 3

func _ready() -> void:
    # Auto-register shoot action for PC
    if not InputMap.has_action("shoot"):
        InputMap.add_action("shoot")
        var event = InputEventMouseButton.new()
        event.button_index = MOUSE_BUTTON_LEFT
        InputMap.action_add_event("shoot", event)

    # Jolt physics tweaks
    collision_layer = 1   # Слой "Player"
    collision_mask = 2    # Слой коллизий "World"
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
        var right_zone = hud.find_child("RightZone", true, false)
        if left: left.input_vector_changed.connect(_on_left_joystick_changed)
        if right_zone: right_zone.swipe_dragged.connect(_on_right_swipe_dragged)
        
        hud_heat_bar = hud.find_child("HeatBar", true, false)
        hud_tapes_counter = hud.find_child("TapesCounter", true, false)
        
        var interact_btn = hud.find_child("InteractButton", true, false)
        if interact_btn:
            interact_btn.pressed.connect(try_interact)
            
    if laser_pistol:
        laser_pistol.heat_changed.connect(_on_heat_changed)
        
    update_tapes_ui()
    
    # Для десктоп теста
    is_desktop = OS.get_name() in ["Windows", "macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]
    if is_desktop:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
    if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
        var look_factor = camera_sensitivity * 0.5
        rotate_y(-event.relative.x * look_factor)
        camera_x_rotation -= event.relative.y * look_factor
        camera_x_rotation = clamp(camera_x_rotation, -CAMERA_X_LIMIT, CAMERA_X_LIMIT)
        camera_rig.rotation.x = camera_x_rotation

func _on_left_joystick_changed(vector: Vector2) -> void:
    move_input = vector

func _on_right_swipe_dragged(relative: Vector2) -> void:
    # Mobile is restricted to horizontal rotation only
    var look_factor = camera_sensitivity * 0.5
    rotate_y(-relative.x * look_factor)

func _on_heat_changed(current_heat: float) -> void:
    if hud_heat_bar:
        hud_heat_bar.value = current_heat

func _physics_process(delta: float) -> void:
    if GameStateManager.current_state == GameStateManager.GameState.READING:
        return  # Заморозить управление во время чтения
        
    if Input.is_action_just_pressed("shoot"):
        shoot()
        
    # Десктоп-фаллбэк (WASD)
    if move_input == Vector2.ZERO and is_desktop:
        move_input.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
        move_input.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
        if move_input.length() > 1.0: move_input = move_input.normalized()
    
    _apply_gravity(delta)
    _apply_movement(delta)
    move_and_slide()

func _apply_movement(delta: float) -> void:
    var speed: float = sprint_speed if is_sprinting else walk_speed
    var direction: Vector3 = (
        transform.basis.x * move_input.x +
        transform.basis.z * move_input.y
    ).normalized()
    velocity.x = direction.x * speed
    velocity.z = direction.z * speed

func _apply_gravity(delta: float) -> void:
    if not is_on_floor():
        velocity.y -= gravity * delta

func try_interact() -> void:
    if ray_interact.is_colliding():
        var collider = ray_interact.get_collider()
        if collider.has_method("interact"):
            collider.interact(self)

func collect_tape() -> void:
    tapes_collected += 1
    update_tapes_ui()
    
func update_tapes_ui() -> void:
    if hud_tapes_counter:
        hud_tapes_counter.text = "Tapes: " + str(tapes_collected) + "/" + str(max_tapes)

func shoot() -> void:
    var tween = create_tween()
    var current_rot = camera_rig.rotation.x
    tween.tween_property(camera_rig, "rotation:x", current_rot + deg_to_rad(2), 0.05)
    tween.tween_property(camera_rig, "rotation:x", current_rot, 0.1)
    
    if laser_pistol and laser_pistol.has_method("shoot"):
        laser_pistol.shoot()

func spawn_hit_marker(pos: Vector3) -> void:
    var mesh_instance = MeshInstance3D.new()
    var sphere_mesh = SphereMesh.new()
    sphere_mesh.radius = 0.1
    sphere_mesh.height = 0.2
    
    var material = StandardMaterial3D.new()
    material.albedo_color = Color(1, 0, 0)
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    sphere_mesh.material = material
    
    mesh_instance.mesh = sphere_mesh
    mesh_instance.global_position = pos
    
    var scene = get_tree().current_scene
    if scene:
        scene.add_child(mesh_instance)
        get_tree().create_timer(1.0).timeout.connect(mesh_instance.queue_free)
