@tool
extends OpponentActionStrategy
class_name Strategy_SequentialActionProgression
#

func choose_action(opponent_instance: OpponentInstance, _context: EffectContext=null) -> OpponentActionDefinition:
	var actions: Array[OpponentActionDefinition] = opponent_instance.opponent_type.get_available_actions()

	if not opponent_instance.strategy_state.has(self):
		opponent_instance.strategy_state[self] = 0

	var index: int = opponent_instance.strategy_state[self]
	var chosen_action := actions[index]

	index += 1
	if index >= actions.size():
		index = 0

	opponent_instance.strategy_state[self] = index
	return chosen_action
