extends UnlockCondition
class_name Condition_DefeatNOppsWithActions

@export var number_to_defeat: int
@export var action_ids: Array[String]

func is_condition_met(save_game_state: SaveGameState,_encounter_report: EncounterReport) -> bool:
	var count: int = 0
	for action_id in action_ids:
		count += save_game_state.get_opponents_defeated_by_action(action_id)
	return count >= number_to_defeat
