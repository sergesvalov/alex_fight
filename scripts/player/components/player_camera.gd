class_name PlayerCamera
extends Node

@export var camera_sensitivity: float = 0.003
const CAMERA_X_LIMIT: float = PI / 2.5

@onready var player: CharacterBody3D = get_parent()
@onready var camera_rig: Node3D = get_parent().get_node("CameraRig")

var camera_x_rotation: float = 0.0
var is_desktop: bool = false

func _ready() -> void:
    is_desktop = OS.get_name() in ["Windows", "macOS", "Linux", "FreeBSD", "NetBSD", "OpenBSD", "BSD"]
    if is_desktop:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func process_input(event: InputEvent) -> void:
    if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and event is InputEventMouseMotion:
        _rotate_camera(-event.relative.x, -event.relative.y)

func process_swipe(relative: Vector2) -> void:
    # Mobile is restricted to horizontal rotation only
    _rotate_camera(-relative.x, 0.0)

func _rotate_camera(rot_x: float, rot_y: float) -> void:
    var look_factor = camera_sensitivity * 0.5
    player.rotate_y(rot_x * look_factor)
    
    if rot_y != 0.0:
        camera_x_rotation += rot_y * look_factor
        camera_x_rotation = clamp(camera_x_rotation, -CAMERA_X_LIMIT, CAMERA_X_LIMIT)
        camera_rig.rotation.x = camera_x_rotation
