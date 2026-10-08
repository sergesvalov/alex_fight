# scripts/levels/blocks/lobby_parts.gd
# The live pieces of the ground-floor lobby and of the two laboratory levels under it
# (hotel_level_generator.gd::_build_lobby() / _build_lab()). One script, several roles picked
# by `role`, because each is a handful of lines:
#
#   "turrets"      - Area3D filling the corridor to the main entrance. While the turrets are
#                    live, whoever walks in is put back by the lobby's elevator, every time - no
#                    rule to learn and no way through. The first console downstairs switches
#                    them off; once the installation is stopped, walking in here is walking
#                    out of the hotel - the end of the game.
#   "lift"         - Area3D on a panel of the second lift, the one that goes underground. Takes
#                    the player to `target_position`. The lobby's panel needs the service code
#                    from the roof (`needs_code`); the panels downstairs do not.
#   "console"      - Area3D on one of the three consoles around the installation. They only
#                    work in order (`index` 1, 2, 3): turrets off, outside line back, stop.
#   "installation" - the glowing column itself: goes dark once all three consoles are off.
#   "creature"     - Node3D inside a tank: a dark shape drifting slowly back and forth in
#                    glowing water, never quite visible. What it is, the game does not say.
extends Node3D

var role: String = ""
var return_position: Vector3 = Vector3.ZERO   # "turrets": where the player is put back (global)
var target_position: Vector3 = Vector3.ZERO   # "lift": where it takes the player (global)
var needs_code: bool = false                  # "lift"
var going_down: bool = true                   # "lift": only picks the line shown
var index: int = 0                            # "console": 1..3
var swim_half_length: float = 2.2             # "creature": how far it drifts either side

const SHOT_SOUND: AudioStream = preload("res://assets/audio/sfx/shoot.wav")
var _swim_time: float = 0.0
var _swim_origin: Vector3 = Vector3.ZERO

func _ready() -> void:
	if role == "turrets":
		connect("body_entered", _on_turret_zone_entered)
	if role == "creature":
		_swim_origin = position
		_swim_time = randf() * 20.0
	set_process(role == "creature" or role == "installation")

func _on_turret_zone_entered(body: Node) -> void:
	if body.name != "Player" or GameStateManager.current_state == GameStateManager.GameState.SPECTATOR:
		return
	if GameStateManager.lab_consoles_off >= 3:
		# The installation is stopped: the hotel is back where it belongs and this door leads out.
		print("[Lobby] player walks out through the main entrance - the end")
		GameStateManager.change_state(GameStateManager.GameState.WIN)
		DialogSystem.show_thought(UIStrings.get_string("ending"), 30.0)
		return
	if GameStateManager.lab_consoles_off >= 1:
		DialogSystem.show_thought(UIStrings.get_string("lobby_door_nothing_outside"), 5.0)
		return # turrets are off, but there is still nothing outside to walk out into
	print("[Lobby] turrets caught the player at ", body.global_position, " - returning to ", return_position)
	for i in range(3):
		AudioManager.play_sfx(SHOT_SOUND, body.global_position, 0.7 + 0.1 * i)
	body.global_position = return_position
	if "velocity" in body:
		body.velocity = Vector3.ZERO
	DialogSystem.show_thought(UIStrings.get_string("lobby_turret_return"), 6.0)

# "lift" and "console": called by the player's interact ray.
func interact(player: Node) -> void:
	if role == "lift":
		if needs_code and not GameStateManager.lobby_unlocked:
			DialogSystem.show_thought(UIStrings.get_string("lobby_lift_no_code"), 5.0)
			return
		GameStateManager.lower_lift_called = true
		GameStateManager.lab_reached = true
		print("[Lobby] second lift takes the player from ", player.global_position, " to ", target_position)
		player.global_position = target_position
		if "velocity" in player:
			player.velocity = Vector3.ZERO
		DialogSystem.show_thought(UIStrings.get_string("lab_lift_down" if going_down else "lab_lift_up"), 4.0)
	elif role == "console":
		if GameStateManager.lab_consoles_off >= index:
			return # already off
		if GameStateManager.lab_consoles_off < index - 1:
			DialogSystem.show_thought(UIStrings.get_string("lab_console_out_of_order"), 5.0)
			return
		GameStateManager.lab_consoles_off = index
		print("[Lab] console ", index, " switched off")
		DialogSystem.show_thought(UIStrings.get_string("lab_console_%d" % index), 7.0)

func _process(delta: float) -> void:
	if role == "installation":
		# The column and its light die the moment the third console is off.
		var stopped: bool = GameStateManager.lab_consoles_off >= 3
		for child in get_children():
			if child is Light3D:
				child.visible = not stopped
			elif child is MeshInstance3D:
				child.visible = not stopped or child.name == "Housing"
		return
	# "creature": slow, uneven drift along the tank with a little rise and fall.
	_swim_time += delta
	var along: float = sin(_swim_time * 0.23) * 0.7 + sin(_swim_time * 0.071) * 0.3
	position = _swim_origin + Vector3(0, sin(_swim_time * 0.31) * 0.35, along * swim_half_length)
	rotation.y = 0.0 if cos(_swim_time * 0.23) >= 0.0 else PI
