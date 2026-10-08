# scripts/levels/blocks/blackout_trap.gd
# Floor 7's nightmare, "the light blinked": every so often the floor's lights stutter and then go
# out for a few seconds. Whoever is MOVING in the dark is put back by the floor's elevator -
# "the light blinked; whoever was standing in the corridor stayed where they were, the rest just
# vanished" (tape 702, which is the rule said out loud). Standing still through the dark is safe;
# looking around is fine, only walking counts.
#
# The rule is fixed and observable: the stutter always comes first, as a warning. Each tape
# found on the floor makes the blackouts come sooner (PERIODS), and the floor's third tape stops
# them for good (GameStateManager.floor7_lights_steady) and unlocks floor 8.
#
# One instance, created only on floor 7 by hotel_level_generator.gd::_add_blackout_trap().
extends Node3D

enum Phase { LIT, WARNING, DARK }

const PERIODS: Array = [16.0, 12.0, 8.0]  # seconds of steady light, by tapes found on this floor
const WARNING_TIME: float = 1.5           # lights stutter - time to stop
const DARK_TIME: float = 3.0
const DARK_GRACE: float = 0.4             # the first moment of darkness doesn't count yet
const MOVING_SPEED: float = 0.4           # m/s along the floor; slower than this is "standing"

var floor_num: int = 7
# Name of the GameStateManager flag that stops the blackouts for good - floor 7's by default;
# floor 2 reuses the trap with its own flag.
var off_flag: StringName = &"floor7_lights_steady"
var lights: Array = []                    # this floor's Light3D nodes (the generator's own list)
var lamp_meshes: Array = []               # their glowing ceiling panels, hidden while dark
var return_position: Vector3 = Vector3.ZERO

var phase: Phase = Phase.LIT
var _timer: float = PERIODS[0]
var _base_energy: Dictionary = {}         # Light3D -> its authored light_energy

static func period_for(tapes_found: int) -> float:
	return PERIODS[clampi(tapes_found, 0, PERIODS.size() - 1)]

func _ready() -> void:
	for light in lights:
		_base_energy[light] = light.light_energy

func _process(delta: float) -> void:
	var active: bool = GameStateManager.current_floor == floor_num and not (GameStateManager.get(off_flag) == true)
	if not active:
		if phase != Phase.LIT:
			_enter(Phase.LIT)
		return

	_timer -= delta
	match phase:
		Phase.LIT:
			if _timer <= 0.0:
				_enter(Phase.WARNING)
		Phase.WARNING:
			# Stutter: each light jumps between dim and full a few times a second.
			for light in lights:
				if is_instance_valid(light):
					light.light_energy = _base_energy[light] * (1.0 if randf() > 0.45 else 0.15)
			if _timer <= 0.0:
				_enter(Phase.DARK)
		Phase.DARK:
			if _timer <= DARK_TIME - DARK_GRACE:
				_catch_if_moving()
			if phase == Phase.DARK and _timer <= 0.0:
				_enter(Phase.LIT)

func _enter(new_phase: Phase) -> void:
	phase = new_phase
	match new_phase:
		Phase.LIT:
			_timer = period_for(GameStateManager.tapes_found.size())
			_set_lights(1.0, true)
		Phase.WARNING:
			_timer = WARNING_TIME
			DialogSystem.trigger_alex_line("floor7_warning")
		Phase.DARK:
			_timer = DARK_TIME
			_set_lights(0.0, false)

func _set_lights(factor: float, lamps_visible: bool) -> void:
	for light in lights:
		if is_instance_valid(light):
			light.light_energy = _base_energy[light] * factor
	for lamp in lamp_meshes:
		if is_instance_valid(lamp):
			lamp.visible = lamps_visible

func _catch_if_moving() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player or not "velocity" in player:
		return
	if GameStateManager.current_state == GameStateManager.GameState.SPECTATOR:
		return
	if Vector2(player.velocity.x, player.velocity.z).length() <= MOVING_SPEED:
		return
	# Same kind of line every other teleport in the game prints (see stairs_gate.gd).
	print("[BlackoutTrap] player moved in the dark at ", player.global_position, " - returning to ", return_position)
	player.global_position = return_position
	player.velocity = Vector3.ZERO
	DialogSystem.trigger_alex_line("floor7_caught")
	_enter(Phase.LIT)
