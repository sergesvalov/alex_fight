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
        
        var door_body = door.get_node("AnimatableBody3D")
        if door_body.is_open:
            print("[FAILED] Дверь должна быть закрыта по умолчанию")
            passed = false
        else:
            var dummy_player = Node3D.new()
            dummy_player.transform.origin = Vector3(0, 0, 2)
            door.add_child(dummy_player)
            
            door_body.interact(dummy_player)
            if not door_body.is_open:
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
    print("Тест: HotelLevelGenerator")
    var gen_script = load("res://scripts/levels/hotel_level_generator.gd")
    if gen_script:
        var generator = Node3D.new()
        generator.set_script(gen_script)
        add_child(generator)
        
        # Эмулируем генерацию
        generator._generate_level()
        # Проверяем, что стилизация работает без ошибок
        generator._apply_stylization()
        
        var floor_main = generator.get_node_or_null("GeneratedFloor_Main")
        var floor_above = generator.get_node_or_null("GeneratedFloor_Above")
        var floor_below = generator.get_node_or_null("GeneratedFloor_Below")
        
        if not floor_main or not floor_above or not floor_below:
            print("[FAILED] Не все этажи сгенерировались!")
            passed = false
        else:
            var stair_n = floor_main.get_node_or_null("Stairwell_N")
            var stair_s = floor_main.get_node_or_null("Stairwell_S")
            var map_1 = floor_main.get_node_or_null("MapDecal_1")
            var room_dbl = floor_main.get_node_or_null("DoubleRoomL1_F4")
            var room_sgl = floor_main.get_node_or_null("SingleRoomR1_F4")
            
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
                
            if not room_dbl or not room_sgl:
                print("[FAILED] Комнаты (DoubleRoomL1_F4 или SingleRoomR1_F4) не были сгенерированы")
                passed = false
            else:
                print("[OK] Экземпляры комнат успешно инстанцированы")
                
            # -----------------------------------------------------
            # Проверка состыковки полов и работоспособности дверей
            # -----------------------------------------------------
            print("  -> Проверка состыковки всех полов на этаже...")
            var floor_errors = 0
            var checked_floors = 0
            
            print("  -> Проверка работоспособности всех дверей на этаже...")
            var door_errors = 0
            var checked_doors = 0
            
            var dummy_player = Node3D.new()
            floor_main.add_child(dummy_player)
            
            var nodes_to_check = [floor_main]
            while nodes_to_check.size() > 0:
                var current = nodes_to_check.pop_back()
                
                # Проверка пола
                if current is CSGBox3D and "Floor" in current.name and not "StairFloor" in current.name:
                    checked_floors += 1
                    var top_y = current.global_transform.origin.y + (current.size.y / 2.0)
                    if abs(top_y) > 0.001:
                        print("     [FAILED] Пол '", current.name, "' в '", current.get_parent().name, "' не выровнен! Y = ", top_y)
                        floor_errors += 1
                
                # Проверка дверей
                if current.name in ["MainDoor", "WCDoor", "MaintenanceDoor", "Door"]:
                    var door_body = current.get_node_or_null("AnimatableBody3D")
                    if door_body:
                        checked_doors += 1
                        if door_body.is_open:
                            print("     [FAILED] Дверь '", current.name, "' в '", current.get_parent().name, "' открыта по умолчанию!")
                            door_errors += 1
                        else:
                            var door_dummy_player = Node3D.new()
                            door_body.add_child(door_dummy_player)
                            door_dummy_player.global_transform.origin = door_body.global_transform.origin + door_body.global_transform.basis.z * 1.5
                            
                            door_body.interact(door_dummy_player)
                            
                            if not door_body.is_open:
                                print("     [FAILED] Дверь '", current.name, "' в '", current.get_parent().name, "' не открылась после interact()")
                                door_errors += 1
                            else:
                                # В headless-режиме Tween не синхронизирует физику.
                                # Принудительно телепортируем дверь в открытое положение
                                # (это тест проходимости, не тест анимации).
                                door_body.rotation.y = door_body.open_angle
                                
                                # Физическая симуляция прохода персонажа сквозь дверной проем
                                var char_body = CharacterBody3D.new()
                                var col = CollisionShape3D.new()
                                var shape = CapsuleShape3D.new()
                                shape.radius = 0.3
                                shape.height = 1.8
                                col.shape = shape
                                char_body.add_child(col)
                                current.get_parent().add_child(char_body)
                                
                                # Ставим манекен ВНУТРИ комнаты (у дальней стены от двери)
                                # basis.z смотрит в коридор, значит -basis.z смотрит вглубь комнаты
                                var start_pos = current.global_transform.origin - current.global_transform.basis.z * 4.0
                                start_pos.y = 0.9
                                char_body.global_transform.origin = start_pos
                                
                                # Даем физическому движку 3 кадра синхронизироваться
                                await get_tree().physics_frame
                                await get_tree().physics_frame
                                await get_tree().physics_frame
                                
                                # Пытаемся ВЫЙТИ из номера (движемся вдоль basis.z на 6 метров)
                                var motion = current.global_transform.basis.z * 6.0
                                var collision = char_body.move_and_collide(motion, true) # true = test_only
                                
                                if collision:
                                    var hit_name = "Unknown"
                                    if collision.get_collider():
                                        hit_name = collision.get_collider().name
                                    print("     [FAILED] Выход заблокирован! Персонаж уперся в: ", hit_name)
                                    door_errors += 1
                                    
                                char_body.queue_free()
                            door_dummy_player.queue_free()
                
                for child in current.get_children():
                    nodes_to_check.append(child)
                    
            dummy_player.queue_free()
            
            if floor_errors == 0 and checked_floors > 0:
                print("     [OK] Проверено полов: ", checked_floors, ". Все поверхности состыкованы идеально (Y=0.0).")
            else:
                passed = false
                
            if door_errors == 0 and checked_doors > 0:
                print("     [OK] Проверено дверей: ", checked_doors, ". Все двери закрыты по умолчанию, открываются и пропускают персонажа.")
            else:
                passed = false
                
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
