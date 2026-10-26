@tool
extends UnlockCondition
class_name Condition_SimultaneousCumInGivenEncounter

@export var encounter_id: String
@export var required_count: int

func is_judged_on_a_single_run() -> bool:
	return true

func is_condition_met(save_game_state: SaveGameState,encounter_report: EncounterReport) -> bool:
	if not save_game_state:
		return false
	if not encounter_report:
		return false
	if encounter_report.encounter_def.encounter_id != encounter_id:
		return false
	if not encounter_report.player_won:
		return false
	if encounter_report.get_max_opponents_defeated_in_one_turn() < required_count:
		return false
	return true

### During the encounter: the most guys made to cum in one turn so far this run. Otherwise the best result in
### this encounter so far, from SaveGameState.encounter_records.
func get_progress_style() -> ProgressStyle:
	return ProgressStyle.COUNT_UP

func get_progress_current(save_game_state: SaveGameState) -> int:
	var live_report: EncounterReport = get_in_progress_report(save_game_state,encounter_id)
	if live_report:
		return live_report.get_max_opponents_defeated_in_one_turn()
	return save_game_state.get_encounter_record(encounter_id,SaveGameState.RECORD_BEST_SIMULTANEOUS_CUM,0)

func get_progress_required(_save_game_state: SaveGameState) -> int:
	return required_count

func _build_description_segments(_save_game_state: SaveGameState) -> Array[DescriptionSegment]:
	return _template("UI_UNLOCK_CONDITION_CUM_ONE_TURN_ENCOUNTER",
		{"count": _number(required_count), "encounter": _encounter_name(encounter_id)}, required_count)
