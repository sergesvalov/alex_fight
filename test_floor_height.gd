
extends SceneTree

func _init():
    var scene = preload("res://scenes/levels/hotel_siberia/base_hotel_level.tscn").instantiate()
    var root = Node.new()
    root.add_child(scene)
    
    var gen = scene.get_node("NavigationRegion3D/HotelGeometry")
    gen._ready()
    
    var c_floor = gen.get_node("GeneratedFloor_Current/CorridorFloor")
    var r_floor = gen.get_node("GeneratedFloor_Current/DoubleRoomL1_F3/Floor")
    
    print("CorridorFloor Global Y: ", c_floor.global_transform.origin.y)
    print("CorridorFloor Size Y: ", c_floor.size.y)
    
    print("Room Floor Global Y: ", r_floor.global_transform.origin.y)
    print("Room Floor Size Y: ", r_floor.size.y)
    
    quit()

