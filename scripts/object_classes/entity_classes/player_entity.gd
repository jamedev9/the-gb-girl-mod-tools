extends TargetEntity
class_name PlayerEntity


func _init(_game_state: GameState):
	game_state = _game_state

func get_player_stats():
	return game_state.player

func get_player_energy():
	return get_player_stats()["current_energy"]

func get_status_effects() -> Dictionary:
	return game_state.player["status_effects"]

func get_passive_effects() -> Array:
	return game_state.player["passive_effects"]
