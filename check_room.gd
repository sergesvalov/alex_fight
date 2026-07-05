extends SceneTree
func _init():
    var scene = load("res://scenes/levels/hotel_siberia/blocks/double_room.tscn")
    if scene:
        print("Double Room loads!")
    quit()
