extends UnlockCondition
class_name Condition_OrgasmNTimesAndWinEncounter

@export var encounter_id: String
@export var required_count: int

func is_condition_met(_save_game_state: SaveGameState,encounter_report: EncounterReport) -> bool:
	
	if not encounter_report:
		return false
	if not encounter_report.player_won:
		return false
	if encounter_id != encounter_report.encounter_def.encounter_id:
		return false
	if encounter_report.orgasms_achieved < required_count:
		return false
	return true
