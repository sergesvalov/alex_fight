class_name PlayerWeapon
extends Node

@onready var player: CharacterBody3D = get_parent()
@onready var camera_rig: Node3D = get_parent().get_node("CameraRig")
@onready var laser_pistol: Node3D = get_parent().get_node("CameraRig/Camera3D/WeaponHolder/LaserPistol")

var hit_marker_scene = preload("res://scenes/fx/hit_marker.tscn")

func _ready() -> void:
    if laser_pistol:
        laser_pistol.heat_changed.connect(_on_heat_changed)

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

func spawn_hit_marker(pos: Vector3) -> void:
    if hit_marker_scene:
        var instance = hit_marker_scene.instantiate()
        instance.global_position = pos
        var scene = get_tree().current_scene
        if scene:
            scene.add_child(instance)
            get_tree().create_timer(1.0).timeout.connect(instance.queue_free)
