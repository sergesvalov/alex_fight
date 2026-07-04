extends Node
class_name RoomLightController

@export var room_light: OmniLight3D
@export var wc_light: OmniLight3D
@export var main_door: Node3D

@export var room_light_on_energy: float = 0.5
@export var wc_light_on_energy: float = 0.6
@export var tween_duration: float = 0.5

func _ready() -> void:
	if Engine.is_editor_hint():
		return
		
	if not room_light:
		room_light = get_parent().get_node_or_null("RoomLight")
	if not wc_light:
		wc_light = get_parent().get_node_or_null("WC_Light")
		
	# Инициализация нулевой яркости
	if room_light:
		room_light.light_energy = 0.0
	if wc_light:
		wc_light.light_energy = 0.0
		
	# Поиск двери, если она не назначена, пытаемся найти по имени
	if not main_door:
		main_door = get_parent().get_node_or_null("MainDoor/AnimatableBody3D")
		
	if main_door and main_door.has_signal("state_changed"):
		main_door.state_changed.connect(_on_door_state_changed)

func _on_door_state_changed(is_open: bool) -> void:
	var tween = create_tween().set_parallel(true)
	
	if room_light:
		tween.tween_property(room_light, "light_energy", room_light_on_energy if is_open else 0.0, tween_duration)
	if wc_light:
		tween.tween_property(wc_light, "light_energy", wc_light_on_energy if is_open else 0.0, tween_duration)
