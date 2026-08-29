extends UnlockCondition
class_name Condition_MakeNGuysCumInOneTurn

@export var required_count: int

func is_condition_met(save_game_state: SaveGameState,_encounter_report: EncounterReport) -> bool:
	if save_game_state.most_guys_cumming_in_one_turn < required_count:
		return false
	return true
