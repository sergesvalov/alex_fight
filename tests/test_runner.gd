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
        var parent_node = Node3D.new()
        add_child(parent_node)
        
        var mock_player = Node3D.new()
        mock_player.name = "Player"
        parent_node.add_child(mock_player)
        
        var mock_enemies = Node3D.new()
        mock_enemies.name = "Enemies"
        var mock_cerberus = Node3D.new()
        mock_cerberus.name = "Cerberus"
        mock_enemies.add_child(mock_cerberus)
        parent_node.add_child(mock_enemies)
        
        var nav_region = Node3D.new()
        nav_region.name = "NavigationRegion3D"
        parent_node.add_child(nav_region)
        
        var generator = Node3D.new()
        generator.set_script(gen_script)
        generator.name = "HotelGeometry"
        nav_region.add_child(generator)
        
        # Эмулируем генерацию
        generator._ready() # _ready triggers generation
        
        # Validate that generation completed successfully by checking if player moved
        if mock_player.global_transform.origin == Vector3.ZERO:
            print("[FAILED] Игрок не был перемещен на точку спавна! Возможно, генератор прервался с ошибкой до генерации энтити.")
            passed = false
        else:
            print("[OK] Игрок успешно перемещен генератором на " + str(mock_player.global_transform.origin))
            
        if mock_cerberus.global_transform.origin == Vector3.ZERO:
            print("[FAILED] Цербер не был перемещен на точку спавна! Генератор прервался или не нашел ноду.")
            passed = false
        else:
            print("[OK] Цербер успешно перемещен генератором на " + str(mock_cerberus.global_transform.origin))
        
        var floor_main = generator.get_node_or_null("GeneratedFloor_Main")
        var floor_above = generator.get_node_or_null("GeneratedFloor_Above")
        var floor_below = generator.get_node_or_null("GeneratedFloor_Below")
        
        if not floor_main or not floor_above or not floor_below:
            print("[FAILED] Не все этажи сгенерировались!")
            passed = false
        else:
            var stair_n = floor_main.get_node_or_null("Stairwell_N")
            var stair_s = floor_main.get_node_or_null("StairwellSouth")
            var map_1 = floor_main.get_node_or_null("MapDecal_1")
            var room_dbl = floor_main.get_node_or_null("DoubleRoomL1_F4")
            var room_sgl = floor_main.get_node_or_null("SingleRoomR1_F4")
            
            if not stair_n:
                print("[FAILED] Stairwell_N не сгенерирован")
                passed = false
            elif stair_n.transform.origin.z != 10.0:
                print("[FAILED] Stairwell_N имеет неверную координату Z: ", stair_n.transform.origin.z)
                passed = false
            else:
                print("[OK] Stairwell_N корректно сгенерирован на Z = 10.0")
                
            if not stair_s:
                print("[FAILED] StairwellSouth не сгенерирован")
                passed = false
            elif stair_s.transform.origin.z >= 0:
                print("[FAILED] StairwellSouth должен быть на отрицательной Z, а он на: ", stair_s.transform.origin.z)
                passed = false
            else:
                print("[OK] StairwellSouth корректно сгенерирован на Z < 0")
                
            if not map_1:
                print("[FAILED] MapDecal_1 не найден")
                passed = false
            elif map_1.transform.origin.z != (generator.double_room_start_z - generator.double_room_step / 2.0):
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
            generator.add_child(dummy_player)
            
            var nodes_to_check = [floor_main, floor_above, floor_below]
            while nodes_to_check.size() > 0:
                var current = nodes_to_check.pop_back()
                
                # Проверка пола
                if current is CSGBox3D and "Floor" in current.name and not "StairFloor" in current.name:
                    checked_floors += 1
                    var top_y = current.global_transform.origin.y + (current.size.y / 2.0)
                    var expected_y = current.get_parent().global_transform.origin.y
                    if abs(top_y - expected_y) > 0.001:
                        print("     [FAILED] Пол '", current.name, "' в '", current.get_parent().name, "' не выровнен! Ожидалось Y = ", expected_y, ", а факт Y = ", top_y)
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
                            # Ставим dummy ВНУТРИ комнаты:
                            # basis.z двери указывает В КОРИДОР, значит -basis.z = внутрь комнаты
                            var door_dummy_player = Node3D.new()
                            door_body.add_child(door_dummy_player)
                            door_dummy_player.global_transform.origin = door_body.global_transform.origin - door_body.global_transform.basis.z * 1.5
                            
                            door_body.interact(door_dummy_player)
                            
                            if not door_body.is_open:
                                if door_body is StairDoor and current.global_transform.origin.y < -2.0:
                                    # Это нижняя дверь лестницы, она работает как телепорт, а не открывается.
                                    pass
                                else:
                                    print("     [FAILED] Дверь '", current.name, "' в '", current.get_parent().name, "' не открылась после interact()")
                                    door_errors += 1
                            else:
                                # В headless-режиме Tween не синхронизирует физику.
                                # Принудительно телепортируем дверь в открытое положение (внутрь комнаты).
                                door_body.rotation.y = door_body.open_angle
                                
                                # Физическая симуляция прохода персонажа через дверной проём
                                var char_body = CharacterBody3D.new()
                                var col = CollisionShape3D.new()
                                var shape = CapsuleShape3D.new()
                                shape.radius = 0.3
                                shape.height = 1.8
                                col.shape = shape
                                char_body.add_child(col)
                                current.get_parent().add_child(char_body)
                                
                                # Персонаж стартует ВНУТРИ комнаты (3м от двери по -basis.z),
                                # смещён на +basis.x * 0.8 — это центр дверного проёма,
                                # подальше от шарнира и открытой панели двери.
                                var door_basis = current.global_transform.basis
                                var start_pos = current.global_transform.origin \
                                    - door_basis.z * 3.0 \
                                    + door_basis.x * 0.8
                                start_pos.y = current.global_transform.origin.y + 0.9
                                char_body.global_transform.origin = start_pos
                                
                                # Даём физическому движку 3 кадра на синхронизацию
                                await get_tree().physics_frame
                                await get_tree().physics_frame
                                await get_tree().physics_frame
                                
                                # Идём из комнаты В КОРИДОР (+basis.z = к коридору)
                                var motion = door_basis.z * 6.0
                                var collision = char_body.move_and_collide(motion, true) # test_only
                                
                                if collision:
                                    var collider = collision.get_collider()
                                    # Столкновение с самой дверью (она открылась внутрь комнаты) — это ОК.
                                    # Провал только если мешает что-то ДРУГОЕ (стена, ступенька, etc.)
                                    if collider != door_body:
                                        var hit_name = collider.name if collider else "Unknown"
                                        var hit_pos = collider.global_transform.origin if collider else Vector3.ZERO
                                        var door_global = current.global_transform.origin
                                        print("     [FAILED] Дверь '", current.name, "' в '", current.get_parent().name,
                                              "' (pos=", door_global, ") — выход заблокирован '", hit_name,
                                              "' (pos=", hit_pos, ")")
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
                
            # -----------------------------------------------------
            # [4] Тестирование геометрии отеля (Debug Geometry)
            # -----------------------------------------------------
            print("\n[4] Тестирование геометрии отеля (Debug Geometry)...")
            var DebugGeometry = load("res://scripts/utils/debug_geometry.gd")
            if DebugGeometry:
                var mismatches = DebugGeometry.print_room_alignments(floor_main)
                if mismatches.size() > 0:
                    print("     [FAILED] Найдено ", mismatches.size(), " несовпадений дверей с проемами!")
                    passed = false
                else:
                    print("     [OK] Все двери идеально выровнены по проемам.")
            else:
                print("     [FAILED] Скрипт debug_geometry.gd не найден.")
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
