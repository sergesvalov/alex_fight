class_name PlayerMovement
extends Node

@export var walk_speed: float = 4.0
@export var sprint_speed: float = 7.0
@export var gravity: float = 9.8

@onready var player: CharacterBody3D = get_parent()

var move_input: Vector2 = Vector2.ZERO
var is_sprinting: bool = false
var is_desktop: bool = false

func _ready() -> void:
    # Desktop check for keyboard fallback
    is_desktop = OS.get_name() in ["Windows", "macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]
    
    player.collision_layer = 1
    player.collision_mask = 2
    player.floor_stop_on_slope = true
    player.floor_max_angle = deg_to_rad(45)
    player.floor_snap_length = 0.1

var time_since_last_step: float = 0.0
var footstep_sound = preload("res://assets/audio/sfx/footstep.wav")

func process_movement(delta: float) -> void:
    if GameStateManager.current_state == GameStateManager.GameState.READING:
        return
        
    var current_input = move_input
    
    # Desktop fallback (WASD)
    if current_input == Vector2.ZERO and is_desktop:
        current_input.x = Input.get_action_strength("ui_right") - Input.get_action_strength("ui_left")
        current_input.y = Input.get_action_strength("ui_down") - Input.get_action_strength("ui_up")
        if current_input.length() > 1.0: 
            current_input = current_input.normalized()
    
    _apply_gravity(delta)
    _apply_movement(current_input, delta)
    player.move_and_slide()

func _apply_movement(input: Vector2, delta: float) -> void:
    var speed: float = sprint_speed if is_sprinting else walk_speed
    var direction: Vector3 = (
        player.transform.basis.x * input.x +
        player.transform.basis.z * input.y
    ).normalized()
    
    player.velocity.x = direction.x * speed
    player.velocity.z = direction.z * speed
    
    if player.is_on_floor() and input.length() > 0.1:
        time_since_last_step += delta
        var interval = 0.25 if is_sprinting else 0.4
        if time_since_last_step >= interval:
            AudioManager.play_sfx(footstep_sound, player.global_position)
            time_since_last_step = 0.0
    else:
        time_since_last_step = 0.4 # play immediately on next step

func _apply_gravity(delta: float) -> void:
    if not player.is_on_floor():
        player.velocity.y -= gravity * delta

func set_move_input(vector: Vector2) -> void:
    move_input = vector
