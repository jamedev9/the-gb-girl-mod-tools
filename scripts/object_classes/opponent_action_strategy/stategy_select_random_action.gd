@tool
extends OpponentActionStrategy
class_name Strategy_SelectRandomAction

func choose_action(opponent_instance: OpponentInstance, _context: EffectContext=null) -> OpponentActionDefinition:
	var available_opponent_actions: Array[OpponentActionDefinition] = opponent_instance.opponent_type.get_available_actions()
	var random_action_index: int = randi_range(0,available_opponent_actions.size()-1)
	return available_opponent_actions[random_action_index]
