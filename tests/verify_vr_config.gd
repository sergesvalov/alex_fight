extends SceneTree

func _init() -> void:
	print("=== БЫСТРЫЙ ТЕСТ: Проверка VR-конфигурации ===")
	
	var openxr_enabled = ProjectSettings.get_setting("xr/openxr/enabled", false)
	var renderer = ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", "")
	
	print("Значение xr/openxr/enabled: ", openxr_enabled)
	print("Значение rendering_method.mobile: ", renderer)
	
	var passed = true
	
	if not openxr_enabled:
		printerr("ОШИБКА: xr/openxr/enabled должно быть TRUE для генерации VR-манифеста Android!")
		passed = false
		
	if renderer != "mobile":
		printerr("ОШИБКА: rendering_method.mobile должен быть 'mobile' (Vulkan) для Quest 2!")
		passed = false
		
	if passed:
		print("✅ VR-КОНФИГУРАЦИЯ УСПЕШНО ПРОШЛА ПРОВЕРКУ!")
		quit(0)
	else:
		print("❌ ТЕСТ VR-КОНФИГУРАЦИИ ПРОВАЛЕН!")
		quit(1)
