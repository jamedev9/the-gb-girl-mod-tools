extends UnlockCondition
class_name Condition_HasDefeatedXOpponents

@export var required_number: int

func is_condition_met(save_game_state: SaveGameState,_encounter_report: EncounterReport) -> bool:
	return save_game_state.get_nr_of_defeated_opponents() >= required_number
