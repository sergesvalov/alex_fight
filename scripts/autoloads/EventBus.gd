extends Node

# Player UI outputs
signal player_health_changed(current_health: int, max_health: int)
signal tapes_collected_updated(collected: int, total: int)
signal heat_updated(current_heat: float)

# Game Flow
signal enemy_died(enemy_type: String)

signal narrative_thought_requested(text: String, duration: float)
