extends "res://scripts/levels/base_hotel_level.gd"

func _ready() -> void:
	super._ready()
	
	var interactables = get_node_or_null("InteractableObjects")
	if interactables:
		interactables.queue_free()
		
	var enemies = get_node_or_null("Enemies")
	if enemies:
		enemies.queue_free()
