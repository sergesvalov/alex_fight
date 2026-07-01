extends SceneTree
func _init():
    var combiner = CSGCombiner3D.new()
    var wrapper = Node3D.new()
    var box = CSGBox3D.new()
    combiner.add_child(wrapper)
    wrapper.add_child(box)
    print("Combiner child count: ", combiner.get_child_count())
    quit()
