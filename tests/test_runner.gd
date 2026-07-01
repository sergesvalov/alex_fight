extends Node

func _ready() -> void:
    print("===============================")
    print("  СТАРТ АВТОТЕСТОВ GODOT  ")
    print("===============================")
    
    var passed = true
    
    # ---------------------------------------------------------
    # 1. SMOKE TESTS (Инстанцирование ключевых сцен)
    # ---------------------------------------------------------
    print("\n[1] Запуск Smoke-тестов сцен...")
    var scenes_to_test = [
        "res://scenes/levels/hotel_siberia/hotel_level_4.tscn",
        "res://entities/player/player.tscn",
        "res://entities/enemies/cerberus/cerberus.tscn",
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
        add_child(pistol)
        
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
            
        pistol.queue_free()
    else:
        print("[FAILED] Не удалось загрузить LaserPistol для тестов")
        passed = false
        
    # Тест 2.2: Интерактивная дверь (InteractiveDoor)
    print("Тест: InteractiveDoor State Change")
    var door_res = load("res://entities/props/door.tscn")
    if door_res:
        var door = door_res.instantiate()
        add_child(door)
        
        if door.is_open:
            print("[FAILED] Дверь должна быть закрыта по умолчанию")
            passed = false
        else:
            var dummy_player = Node3D.new()
            dummy_player.transform.origin = Vector3(0, 0, 2)
            door.add_child(dummy_player)
            
            door.interact(dummy_player)
            if not door.is_open:
                print("[FAILED] Дверь не открылась после interact()")
                passed = false
            else:
                print("[OK] Дверь корректно открывается")
        
        door.queue_free()
    else:
        print("[FAILED] Не удалось загрузить door.tscn")
        passed = false

    # ---------------------------------------------------------
    # 3. LEVEL INTEGRITY TESTS (Тесты генератора)
    # ---------------------------------------------------------
    print("\n[3] Запуск тестов генерации уровня...")
    print("Тест: HotelLevelGenerator Coordinates")
    var gen_script = load("res://scripts/levels/hotel_level_generator.gd")
    if gen_script:
        var generator = Node3D.new()
        generator.set_script(gen_script)
        add_child(generator)
        
        # Эмулируем генерацию
        generator._generate_level()
        
        var floor_main = generator.get_node_or_null("GeneratedFloor_Main")
        if not floor_main:
            print("[FAILED] GeneratedFloor_Main не найден!")
            passed = false
        else:
            var stair_n = floor_main.get_node_or_null("Stairwell_N")
            var stair_s = floor_main.get_node_or_null("Stairwell_S")
            var map_1 = floor_main.get_node_or_null("MapDecal_1")
            
            if not stair_n:
                print("[FAILED] Stairwell_N не сгенерирован")
                passed = false
            elif stair_n.transform.origin.z != 10.5:
                print("[FAILED] Stairwell_N имеет неверную координату Z: ", stair_n.transform.origin.z)
                passed = false
            else:
                print("[OK] Stairwell_N корректно сгенерирован на Z = 10.5")
                
            if not stair_s:
                print("[FAILED] Stairwell_S не сгенерирован")
                passed = false
            elif stair_s.transform.origin.z >= 0:
                print("[FAILED] Stairwell_S должен быть на отрицательной Z, а он на: ", stair_s.transform.origin.z)
                passed = false
            else:
                print("[OK] Stairwell_S корректно сгенерирован на Z < 0")
                
            if not map_1:
                print("[FAILED] MapDecal_1 не найден")
                passed = false
            elif map_1.transform.origin.z != (4.0 - generator.double_room_step / 2.0):
                print("[FAILED] MapDecal_1 не на середине первого номера. Z = ", map_1.transform.origin.z)
                passed = false
            else:
                print("[OK] Карты корректно расположены в начале этажа")
                
        generator.queue_free()
    else:
        print("[FAILED] Не удалось загрузить скрипт генератора")
        passed = false


    # ---------------------------------------------------------
    # ИТОГИ
    # ---------------------------------------------------------
    print("\n===============================")
    if passed:
        print("  ✅ ТЕСТЫ ПРОЙДЕНЫ УСПЕШНО  ")
        print("===============================\n")
        get_tree().quit(0)
    else:
        print("  ❌ ОШИБКА В ТЕСТАХ!  ")
        print("===============================\n")
        get_tree().quit(1)
