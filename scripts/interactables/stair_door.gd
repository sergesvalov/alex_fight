extends AnimatableBody3D
class_name StairDoor

@onready var sfx_open: AudioStreamPlayer3D = $"../SfxOpen"
@onready var sfx_close: AudioStreamPlayer3D = $"../SfxClose"

var is_open: bool = false
var is_moving: bool = false

func interact(player: Node) -> void:
	if is_moving:
		return
		
	var is_bottom_door = global_position.y < -2.0
	
	if is_bottom_door:
		# Нажатие на нижнюю дверь (телепорт)
		sfx_open.play()
		var can_go_down = GameStateManager.exit_code_known
		
		if can_go_down and GameStateManager.current_floor == 4:
			# Переход на новый этаж
			GameStateManager.entered_from_stairs = true
			GameStateManager.reset_floor(3)
			GameStateManager.stair_spawn_position = Vector3(0, 0, 8.5) # Возле двери на 3 этаже
			GameStateManager.stair_spawn_rotation = Vector3(0, 0, 0)
			get_tree().change_scene_to_file("res://scenes/levels/hotel_siberia/hotel_level_3.tscn")
		else:
			# Запрещено: телепортируемся обратно на текущий этаж (Loop)
			# Телепорт на 5 метров вверх (к верхней двери)
			player.global_position += Vector3(0, 5.0, 0)
	else:
		# Обычная логика открытия для верхней двери
		is_moving = true
		
		if not is_open:
			var to_player = player.global_position - global_position
			var forward = global_transform.basis.z
			var open_angle = -PI / 2.0
			if to_player.dot(forward) > 0:
				open_angle = PI / 2.0
				
			is_open = true
			sfx_open.play()
			
			var tween = create_tween()
			tween.tween_property(self, "rotation:y", open_angle, 0.5)
			tween.tween_callback(func(): is_moving = false)
		else:
			is_open = false
			sfx_close.play()
			var tween = create_tween()
			tween.tween_property(self, "rotation:y", 0.0, 0.5)
			tween.tween_callback(func(): is_moving = false)
