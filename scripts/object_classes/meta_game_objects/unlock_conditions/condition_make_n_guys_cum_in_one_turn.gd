@tool
extends UnlockCondition
class_name Condition_MakeNGuysCumInOneTurn

@export var required_count: int

func is_condition_met(save_game_state: SaveGameState,_encounter_report: EncounterReport) -> bool:
	if save_game_state.most_guys_cumming_in_one_turn < required_count:
		return false
	return true

func get_progress_style() -> ProgressStyle:
	return ProgressStyle.COUNT_UP

func get_progress_current(save_game_state: SaveGameState) -> int:
	return save_game_state.most_guys_cumming_in_one_turn

func get_progress_required(_save_game_state: SaveGameState) -> int:
	return required_count

func _build_description_segments(_save_game_state: SaveGameState) -> Array[DescriptionSegment]:
	return _template("UI_UNLOCK_CONDITION_CUM_ONE_TURN_ANY", {"count": _number(required_count)}, required_count)
