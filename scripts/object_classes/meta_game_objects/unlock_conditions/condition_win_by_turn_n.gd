@tool
extends UnlockCondition
class_name Condition_WinByTurnN

@export var encounter_id: String
@export var turn_to_win_by: int

func is_judged_on_a_single_run() -> bool:
	return true

func is_condition_met(_save_game_state: SaveGameState,encounter_report: EncounterReport) -> bool:
	if not encounter_report:
		return false
	if not encounter_report.player_won:
		return false
	if encounter_report.encounter_def.encounter_id != encounter_id:
		return false
	return encounter_report.final_round_number <= turn_to_win_by

### Fastest win of this encounter so far (the turn it was won on), from SaveGameState.encounter_records.
func get_progress_style() -> ProgressStyle:
	return ProgressStyle.BEST_LOWER

func get_progress_current(save_game_state: SaveGameState) -> int:
	return save_game_state.get_encounter_record(encounter_id,SaveGameState.RECORD_FASTEST_WIN_TURN,-1)

func _build_description_segments(_save_game_state: SaveGameState) -> Array[DescriptionSegment]:
	return _template("UI_UNLOCK_CONDITION_WIN_BY_TURN", {"encounter": _encounter_name(encounter_id), "turn": _number(turn_to_win_by)})
