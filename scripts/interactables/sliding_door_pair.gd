# scripts/interactables/sliding_door_pair.gd
# Two-panel elevator door (2026-08-24, replacing the old single sliding panel - see
# elevator_door.tscn's own history): the single panel had to travel the ENTIRE hole width to
# clear it, which is what forced open_offset/hole width/door scale to be tuned against each
# other across many earlier fixes (2.0->1.5->1.2 hole, 0.8->1.3 offset, native->0.93 scale) and
# still left little margin. Splitting into two panels sliding opposite ways means each only has
# to clear HALF the hole width, structurally removing that constraint instead of re-tuning it
# again. Attached to a plain Node3D (not an AnimatableBody3D itself) named "AnimatableBody3D" so
# elevator_controller.gd's existing `get_node_or_null("ElevatorDoor/AnimatableBody3D")` lookup
# and its is_open/open_offset/interact() usage keep working unchanged - the two actual physics
# bodies are LeftPanel/RightPanel below it, each carrying door_panel_relay.gd so a player's
# raycast/proximity interact (player_interaction.gd, which calls straight through to whichever
# collider it actually hit) works on either panel and always drives both together.
extends Node3D
class_name SlidingDoorPair

@onready var left_panel: AnimatableBody3D = $LeftPanel
@onready var right_panel: AnimatableBody3D = $RightPanel
@onready var sfx_open: AudioStreamPlayer3D = $"../SfxOpen"
@onready var sfx_close: AudioStreamPlayer3D = $"../SfxClose"

# Distance EACH panel slides away from center, in opposite directions - not the total gap
# between them (that's twice this value plus the closed-position overlap).
@export var open_offset: Vector3 = Vector3(1.3, 0, 0)
@export var move_time: float = 1.5

var is_open: bool = false
var is_moving: bool = false
var _left_closed_pos: Vector3
var _right_closed_pos: Vector3

func _ready() -> void:
	_left_closed_pos = left_panel.position
	_right_closed_pos = right_panel.position

func interact(_player: Node) -> void:
	if is_moving:
		return

	is_moving = true
	is_open = !is_open

	var left_target = _left_closed_pos - open_offset if is_open else _left_closed_pos
	var right_target = _right_closed_pos + open_offset if is_open else _right_closed_pos

	if sfx_open and is_open:
		sfx_open.play()
	elif sfx_close and not is_open:
		sfx_close.play()

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(left_panel, "position", left_target, move_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(right_panel, "position", right_target, move_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.chain().tween_callback(func(): is_moving = false)
