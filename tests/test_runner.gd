extends SceneTree

func _init() -> void:
    print("===============================")
    print("  СТАРТ АВТОТЕСТОВ GODOT  ")
    print("===============================")
    
    var passed = true
    
    # ---------------------------------------------------------
    # 1. SMOKE TESTS (Инстанцирование ключевых сцен)
    # ---------------------------------------------------------
    print("\n[1] Запуск Smoke-тестов сцен...")
    var scenes_to_test = [
        "res://scenes/levels/hotel_siberia/hotel_level.tscn",
        "res://entities/player/player.tscn",
        "res://entities/enemies/cerberus.tscn",
        "res://hud/hud.tscn"
    ]
    
    for path in scenes_to_test:
        var res = load(path)
        if not res:
            print("[FAILED] Сцена не найдена или сломана (возможно битые UID): ", path)
            passed = false
            continue
            
        var instance = res.instantiate()
        if not instance:
            print("[FAILED] Не удалось инстанцировать сцену: ", path)
            passed = false
        else:
            print("[OK] Сцена успешно загружена: ", path)
            instance.free()

    # ---------------------------------------------------------
    # 2. LOGIC TESTS (Тестирование логики оружия)
    # ---------------------------------------------------------
    print("\n[2] Запуск логических тестов...")
    
    # Тест 2.1: Перегрев лазерного пистолета
    print("Тест: LaserPistol Heat Mechanics")
    var pistol_res = load("res://entities/weapons/laser_pistol.tscn")
    if pistol_res:
        var pistol = pistol_res.instantiate()
        var root = Node.new()
        root.add_child(pistol)
        
        # Симулируем 7 выстрелов подряд (каждый дает +15 heat, 7 * 15 = 105)
        for i in range(7):
            pistol.shoot()
            
        if pistol.heat != 100.0:
            print("[FAILED] Лазерный пистолет не ограничил тепло до 100.0 (Текущее: ", pistol.heat, ")")
            passed = false
        elif pistol.is_overheated != true:
            print("[FAILED] Оружие должно было перегреться, но is_overheated == false")
            passed = false
        else:
            print("[OK] LaserPistol корректно перегревается")
            
        root.free()
    else:
        print("[FAILED] Не удалось загрузить LaserPistol для тестов")
        passed = false


    # ---------------------------------------------------------
    # ИТОГИ
    # ---------------------------------------------------------
    print("\n===============================")
    if passed:
        print("  ✅ ТЕСТЫ ПРОЙДЕНЫ УСПЕШНО  ")
        print("===============================\n")
        quit(0)
    else:
        print("  ❌ ОШИБКА В ТЕСТАХ!  ")
        print("===============================\n")
        quit(1)
