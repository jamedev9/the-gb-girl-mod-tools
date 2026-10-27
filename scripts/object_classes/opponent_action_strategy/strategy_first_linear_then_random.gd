@tool
extends OpponentActionStrategy
class_name Strategy_FirstLinearThenRandom

@export var loop_entries_at_or_above: int = 0

func choose_action(opponent_instance: OpponentInstance, _context: EffectContext=null) -> OpponentActionDefinition:
	var actions: Array[OpponentActionDefinition] = opponent_instance.opponent_type.get_available_actions()

	if not opponent_instance.strategy_state.has(self):
		opponent_instance.strategy_state[self] = 0

	var index: int = opponent_instance.strategy_state[self]
	var chosen_action := actions[index]


	if index >= actions.size()-1:
		var random_index: int = randi_range(loop_entries_at_or_above,actions.size()-1)
		chosen_action = actions[random_index]
	else:
		index += 1

	opponent_instance.strategy_state[self] = index
	return chosen_action
