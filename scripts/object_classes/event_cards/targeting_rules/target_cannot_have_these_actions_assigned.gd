@tool
extends TargetingRule
class_name TargetCannotHaveTheseActionsAssigned

@export var action_ids: Array[String]


func is_target_valid(game_state: GameState,opponent_id: String) -> bool:
	var action_on_opponent: String = game_state.get_action_assigned_to_opponent(opponent_id)
	return not action_on_opponent in action_ids
