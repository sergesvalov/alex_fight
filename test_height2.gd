
extends SceneTree

func _init():
    var scene = preload("res://scenes/levels/hotel_siberia/base_hotel_level.tscn").instantiate()
    var root = Node.new()
    root.add_child(scene)
    
    var gen = scene.get_node("NavigationRegion3D/HotelGeometry")
    gen._ready()
    
    var c_floor = gen.get_node("GeneratedFloor_Current/CorridorFloor")
    var r_floor = gen.get_node("GeneratedFloor_Current/DoubleRoomL1_F3/Floor")
    
    var c_pos = c_floor.global_transform.origin
    var r_pos = r_floor.global_transform.origin
    
    var file = FileAccess.open("res://floor_output.txt", FileAccess.WRITE)
    file.store_string("Corridor: " + str(c_pos.y) + " Room: " + str(r_pos.y))
    file.close()
    
    quit()

