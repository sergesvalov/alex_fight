class_name PlayerWeapon
extends Node

@onready var player: CharacterBody3D = get_parent()
@onready var camera_rig: Node3D = get_parent().get_node("CameraRig")
@onready var laser_pistol: Node3D = get_parent().get_node("CameraRig/Camera3D/WeaponHolder/LaserPistol")


# False from waking up until the pistol is picked up (wake_up_room.gd): nothing in the hand,
# nothing to shoot with.
var armed: bool = true

func set_armed(value: bool) -> void:
    armed = value
    if laser_pistol:
        laser_pistol.get_parent().visible = value # WeaponHolder: the pistol and the hand holding it

func _ready() -> void:
    if laser_pistol:
        laser_pistol.heat_changed.connect(_on_heat_changed)
    # The VR trigger is wired up by player_controller.gd, like every other input. (It used to be
    # connected here as well - one pull of the trigger was two shots.)

func _on_heat_changed(current_heat: float) -> void:
    if EventBus.has_signal("heat_updated"):
        EventBus.heat_updated.emit(current_heat)

func shoot() -> void:
    if not armed:
        return
    var tween = create_tween()
    var current_rot = camera_rig.rotation.x
    tween.tween_property(camera_rig, "rotation:x", current_rot + deg_to_rad(2), 0.05)
    tween.tween_property(camera_rig, "rotation:x", current_rot, 0.1)
    
    if laser_pistol and laser_pistol.has_method("shoot"):
        laser_pistol.shoot()

