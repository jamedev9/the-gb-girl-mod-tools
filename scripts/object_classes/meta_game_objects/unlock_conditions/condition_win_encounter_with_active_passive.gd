extends UnlockCondition
class_name Condition_WinEncounterWithActivePassive

@export var encounter_id: String
@export var passive_id: String

func is_condition_met(_save_game_state: SaveGameState,encounter_report: EncounterReport) -> bool:
	if not encounter_report:
		return false
	if encounter_report.encounter_def.encounter_id != encounter_id:
		return false
	if not encounter_report.player_won:
		return false
	
	if passive_id not in encounter_report.active_player_passives_at_end_of_game:
		#print("Passive ID not in player at end of game.")
		return false
	
	return true

func is_condition_hidden_from_player(save_game_state: SaveGameState) -> bool:
	return not save_game_state.player_owns_passive(passive_id)
