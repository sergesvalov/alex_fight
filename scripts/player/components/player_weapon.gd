class_name PlayerWeapon
extends Node

@onready var player: CharacterBody3D = get_parent()
@onready var camera_rig: Node3D = get_parent().get_node("CameraRig")
@onready var laser_pistol: Node3D = get_parent().get_node("CameraRig/Camera3D/WeaponHolder/LaserPistol")


func _ready() -> void:
    if laser_pistol:
        laser_pistol.heat_changed.connect(_on_heat_changed)
        
    var right_hand = player.get_node_or_null("XROrigin3D/RightController")
    if right_hand:
        right_hand.button_pressed.connect(_on_xr_button_pressed)

func _on_xr_button_pressed(button_name: String) -> void:
    if button_name == "trigger_click":
        shoot()

func _on_heat_changed(current_heat: float) -> void:
    if EventBus.has_signal("heat_updated"):
        EventBus.heat_updated.emit(current_heat)

func shoot() -> void:
    var tween = create_tween()
    var current_rot = camera_rig.rotation.x
    tween.tween_property(camera_rig, "rotation:x", current_rot + deg_to_rad(2), 0.05)
    tween.tween_property(camera_rig, "rotation:x", current_rot, 0.1)
    
    if laser_pistol and laser_pistol.has_method("shoot"):
        laser_pistol.shoot()

