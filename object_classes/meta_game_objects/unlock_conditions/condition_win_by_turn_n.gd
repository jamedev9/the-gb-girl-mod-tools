extends UnlockCondition
class_name Condition_WinByTurnN

@export var encounter_id: String
@export var turn_to_win_by: int

func is_condition_met(_save_game_state: SaveGameState,encounter_report: EncounterReport) -> bool:
	if not encounter_report:
		return false
	if not encounter_report.player_won:
		return false
	if encounter_report.encounter_def.encounter_id != encounter_id:
		return false
	return encounter_report.final_round_number <= turn_to_win_by
