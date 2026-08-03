extends UnlockCondition
class_name Condition_SimultaneousCumInGivenEncounter

@export var encounter_id: String
@export var required_count: int

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
