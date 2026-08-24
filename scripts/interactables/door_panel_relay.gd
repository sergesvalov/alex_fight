# scripts/interactables/door_panel_relay.gd
# Attached to each physical panel (LeftPanel/RightPanel) of a SlidingDoorPair (see
# sliding_door_pair.gd). player_interaction.gd calls .interact() directly on whichever collider
# its raycast/proximity check actually hit - since either panel can be the one facing the player,
# each needs its own interact() method, but the actual open/close state and tween live on the
# shared parent so both panels always move together instead of drifting out of sync.
extends AnimatableBody3D

func interact(player: Node) -> void:
	get_parent().interact(player)
