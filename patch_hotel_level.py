import re

with open('scripts/levels/hotel_level.gd', 'r', encoding='utf-8') as f:
    content = f.read()

new_ready = '''func _ready() -> void:
    GameStateManager.all_tapes_collected.connect(_on_all_tapes_collected)
    
    var rooms = []
    var hotel_geo = $NavigationRegion3D/HotelGeometry
    for child in hotel_geo.get_children():
        if child.name.begins_with("DoubleRoom") or child.name.begins_with("SingleRoom"):
            rooms.append(child)
            
    if GameStateManager.entered_from_outer_door:
        GameStateManager.entered_from_outer_door = false
        if rooms.size() > 0:
            var target_room = rooms.pick_random()
            var is_double = target_room.name.begins_with("DoubleRoom")
            
            # Spawn door behind player
            _spawn_exit_door(target_room, true)
            
            # Place player in front of the door
            var player = null
            if has_node("Player"):
                player = get_node("Player")
            
            if player:
                if is_double:
                    # Player at X=-3.0 (facing +X into room)
                    player.global_position = target_room.global_position + Vector3(-3.0, 2.0, 0.0)
                    player.rotation.y = -PI/2 # Face +X
                else:
                    # Player at X=2.0 (facing -X into room)
                    player.global_position = target_room.global_position + Vector3(2.0, 2.0, 0.0)
                    player.rotation.y = PI/2 # Face -X

    if GameStateManager.current_floor == 3:
        # Randomize tapes and Cerberus spawn
        var available_rooms = rooms.duplicate()
        available_rooms.shuffle()
        
        var tapes = []
        for i in range(1, 4):
            if has_node("VhsTape_" + str(i)):
                tapes.append(get_node("VhsTape_" + str(i)))
                
        for tape in tapes:
            if available_rooms.size() > 0:
                var r = available_rooms.pop_back()
                tape.global_position = r.global_position + Vector3(0, 1.0, 0)
                
        if has_node("Enemies/Cerberus") and available_rooms.size() > 0:
            var r = available_rooms.pop_back()
            get_node("Enemies/Cerberus").global_position = r.global_position + Vector3(0, 1.0, 0)
'''

content = re.sub(r'func _ready\(\) -> void:.*?func _on_all_tapes_collected\(\) -> void:', new_ready + '\nfunc _on_all_tapes_collected() -> void:', content, flags=re.DOTALL)

# Add a `silent` parameter to _spawn_exit_door so it doesn't play the loud sound when spawning at start
content = content.replace('func _spawn_exit_door(room: Node3D) -> void:', 'func _spawn_exit_door(room: Node3D, silent: bool = false) -> void:')
content = content.replace('audio.play()', 'if not silent:\n        audio.play()')

with open('scripts/levels/hotel_level.gd', 'w', encoding='utf-8') as f:
    f.write(content)
