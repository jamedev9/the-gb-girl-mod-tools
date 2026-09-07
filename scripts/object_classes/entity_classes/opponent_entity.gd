extends TargetEntity
class_name OpponentEntity

var opponent_id: String

func _init(_game_state: GameState, _opponent_id: String) -> void:
	game_state = _game_state
	opponent_id = _opponent_id

func get_opponent_id() -> String:
	return opponent_id

func get_data() -> OpponentInstance:
	return game_state.get_opponent_instance(opponent_id)

func get_tracker_key() -> String:
	return opponent_id

func get_status_effects() -> Dictionary:
	if not get_data():
		return {}
	return get_data().status_effects

func get_passive_effects() -> Array:
	if not get_data():
		return []
	return get_data().opponent_type.passive_effects

func is_still_in_encounter() -> bool:
	return get_data() != null
