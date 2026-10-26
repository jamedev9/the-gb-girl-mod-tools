@tool
extends UnlockCondition
class_name Condition_HasDefeatedXOpponents

@export var required_number: int

func is_condition_met(save_game_state: SaveGameState,_encounter_report: EncounterReport) -> bool:
	return save_game_state.get_nr_of_defeated_opponents() >= required_number

func _build_description_segments(save_game_state: SaveGameState) -> Array[DescriptionSegment]:
	var current_number: int = save_game_state.get_nr_of_defeated_opponents() if save_game_state else 0
	return _template("UI_UNLOCK_CONDITION_DEFEATED_X_OPPONENTS",
		{"count": _number(required_number), "progress": _progress_text(current_number, required_number)}, required_number)
