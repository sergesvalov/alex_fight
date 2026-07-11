extends SceneTree
func _init():
    var scene = load('res://scenes/levels/hotel_siberia/blocks/north_stairs.tscn')
    if scene == null:
        print('FAILED TO LOAD SCENE')
        quit()
        return
    var inst = scene.instantiate()
    print('SCENE LOADED SUCCESSFULLY, nodes:', inst.get_child_count())
    quit()
