const EnemyState = preload("res://scripts/enemies/states/enemy_state.gd")

class IdleState extends EnemyState:
	func enter() -> void:
		ai.velocity.x = 0.0
		ai.velocity.z = 0.0
		if GameStateManager.current_state == GameStateManager.GameState.COMBAT:
			GameStateManager.change_state(GameStateManager.GameState.EXPLORING)

	func physics_process(delta: float) -> void:
		ai.idle_timer -= delta
		if ai.idle_timer <= 0 and ai.patrol_points.size() > 0:
			ai.state_machine.change_state("PATROL")

class PatrolState extends EnemyState:
	func physics_process(_delta: float) -> void:
		if ai.patrol_points.is_empty():
			ai.state_machine.change_state("IDLE")
			return

		var target_point: Vector3 = ai.patrol_points[ai.current_patrol_index].global_position
		var nav_target: Vector3 = target_point
		nav_target.y = ai.global_position.y
		ai.movement.nav_agent.target_position = nav_target
		ai.movement.move_along_nav(ai.patrol_speed)

		if ai._flat_distance(target_point) < 0.5:
			ai.current_patrol_index = (ai.current_patrol_index + 1) % ai.patrol_points.size()
			ai.idle_timer = ai.idle_wait_time
			ai.state_machine.change_state("IDLE")

class ChaseState extends EnemyState:
	func enter() -> void:
		ai.attack_timer = 0.0
		GameStateManager.change_state(GameStateManager.GameState.COMBAT)
		AudioManager.play_music("combat")

	func physics_process(_delta: float) -> void:
		if not is_instance_valid(ai.player):
			ai.state_machine.change_state("RETURN")
			return

		if GameStateManager.current_state == GameStateManager.GameState.SPECTATOR:
			ai.player = null
			ai.state_machine.change_state("RETURN")
			return

		if ai._nav_update_timer <= 0.0:
			var nav_target: Vector3 = ai.player.global_position
			nav_target.y = ai.global_position.y
			ai.movement.nav_agent.target_position = nav_target
			ai._nav_update_timer = ai.NAV_UPDATE_INTERVAL
		ai.movement.move_along_nav(ai.chase_speed)

		if ai._los_check_timer <= 0.0:
			ai._last_los = ai.sensors.has_line_of_sight(ai.player)
			ai._los_check_timer = ai.LOS_CHECK_INTERVAL

		if not ai._last_los:
			if ai.attack_timer <= -3.0:
				ai.state_machine.change_state("RETURN")
		else:
			ai.attack_timer = 0.0

		if ai._last_los and ai._flat_distance(ai.player.global_position) <= ai.attack_range:
			ai.state_machine.change_state("ATTACK")

class AttackState extends EnemyState:
	func enter() -> void:
		ai.velocity.x = 0.0
		ai.velocity.z = 0.0

	func physics_process(delta: float) -> void:
		if not is_instance_valid(ai.player):
			ai.state_machine.change_state("RETURN")
			return

		var to_player: Vector3 = ai.player.global_position - ai.global_position
		to_player.y = 0.0
		if to_player.length_squared() > 0.0001:
			var prev_facing: Vector3 = -ai.global_transform.basis.z
			ai.look_at(ai.global_position + to_player, Vector3.UP)
			ai._log_attack_rotation_spike_if_any(prev_facing, to_player)

		if ai._flat_distance(ai.player.global_position) > ai.attack_range * 1.5:
			ai.state_machine.change_state("CHASE")
			return

		if ai._los_check_timer <= 0.0:
			ai._last_los = ai.sensors.has_line_of_sight(ai.player)
			ai._los_check_timer = ai.LOS_CHECK_INTERVAL
			
		ai._attack_blind_time = 0.0 if ai._last_los else ai._attack_blind_time + delta
		if ai._attack_blind_time > ai.ATTACK_BLIND_LIMIT:
			ai._attack_blind_time = 0.0
			ai.state_machine.change_state("CHASE")
			return

		if ai.attack_timer <= 0.0:
			ai._perform_attack()
			ai.attack_timer = ai.attack_cooldown

class ReturnState extends EnemyState:
	func enter() -> void:
		if GameStateManager.current_state == GameStateManager.GameState.COMBAT:
			GameStateManager.change_state(GameStateManager.GameState.EXPLORING)

	func physics_process(_delta: float) -> void:
		var nav_target: Vector3 = ai.spawn_position
		nav_target.y = ai.global_position.y
		ai.movement.nav_agent.target_position = nav_target
		ai.movement.move_along_nav(ai.patrol_speed)

		if ai._flat_distance(ai.spawn_position) < 1.2:
			ai.player = null
			ai.state_machine.change_state("IDLE")

class InvestigateState extends EnemyState:
	func physics_process(delta: float) -> void:
		ai._investigate_time_left -= delta

		if ai.can_see and ai._los_check_timer <= 0.0:
			ai._los_check_timer = ai.LOS_CHECK_INTERVAL
			var target = ai.get_tree().get_first_node_in_group("player")
			if target and GameStateManager.current_state != GameStateManager.GameState.SPECTATOR \
					and absf(target.global_position.y - ai.global_position.y) <= EnemySensors.SAME_FLOOR_Y_TOLERANCE \
					and ai._flat_distance(target.global_position) <= ai.SIGHT_RANGE \
					and ai.sensors.has_line_of_sight(target):
				ai.player = target
				ai.state_machine.change_state("CHASE")
				return

		if ai._flat_distance(ai._noise_position) > ai.INVESTIGATE_ARRIVE_DISTANCE and ai._investigate_time_left > ai.INVESTIGATE_LOOK_TIME:
			var nav_target: Vector3 = ai._noise_position
			nav_target.y = ai.global_position.y
			ai.movement.nav_agent.target_position = nav_target
			ai.movement.move_along_nav(ai.investigate_speed)
			return

		ai.velocity.x = 0.0
		ai.velocity.z = 0.0
		ai.rotate_y(ai.INVESTIGATE_TURN_SPEED * delta)
		ai._investigate_look_left -= delta
		
		if ai._investigate_look_left <= 0.0 or ai._investigate_time_left <= 0.0:
			ai.state_machine.change_state("RETURN")

class DeadState extends EnemyState:
	func enter() -> void:
		ai._die()
