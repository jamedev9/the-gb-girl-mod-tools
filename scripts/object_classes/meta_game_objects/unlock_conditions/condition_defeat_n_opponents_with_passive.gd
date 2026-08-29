extends UnlockCondition
class_name Condition_DefeatNOpponentsWithPassive

@export var number_to_defeat: int
@export var passive_id: String

func is_condition_met(save_game_state: SaveGameState,_encounter_report: EncounterReport) -> bool:
	var count = save_game_state.get_defeated_opponents_with_passive(passive_id)
	return count >= number_to_defeat
	
