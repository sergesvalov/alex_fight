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
		
	# Пресет экспорта. В Godot 4 xr_features/xr_mode - число (0 = Regular, 1 = OpenXR); строка
	# "OpenXR" молча читается как 0, и apk собирается обычным плоским приложением - в шлеме
	# игра открывается окном, а не в 3D. OpenXR к тому же экспортируется только gradle-сборкой.
	var presets := ConfigFile.new()
	if presets.load("res://export_presets.cfg") != OK:
		printerr("ОШИБКА: не читается export_presets.cfg")
		passed = false
	else:
		var found := false
		for section in presets.get_sections():
			if presets.get_value(section, "name", "") != "Android Quest 2":
				continue
			found = true
			var xr_mode = presets.get_value(section + ".options", "xr_features/xr_mode", 0)
			var gradle = presets.get_value(section + ".options", "gradle_build/use_gradle_build", false)
			print("Пресет Android Quest 2: xr_mode = ", var_to_str(xr_mode), ", use_gradle_build = ", gradle)
			if typeof(xr_mode) != TYPE_INT or xr_mode != 1:
				printerr("ОШИБКА: xr_features/xr_mode должно быть числом 1 (OpenXR), иначе apk выйдет плоским!")
				passed = false
			if gradle != true:
				printerr("ОШИБКА: gradle_build/use_gradle_build должно быть true - без него OpenXR не экспортируется!")
				passed = false
		if not found:
			printerr("ОШИБКА: в export_presets.cfg нет пресета Android Quest 2")
			passed = false

	if passed:
		print("✅ VR-КОНФИГУРАЦИЯ УСПЕШНО ПРОШЛА ПРОВЕРКУ!")
		quit(0)
	else:
		print("❌ ТЕСТ VR-КОНФИГУРАЦИИ ПРОВАЛЕН!")
		quit(1)
