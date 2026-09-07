extends UnlockCondition
class_name Condition_MakeGuysCumWIthActivePassive_Resetable

@export var count: int
@export var passive_id: String

func is_condition_met(save_game_state: SaveGameState,encounter_report: EncounterReport) -> bool:
	if not encounter_report:
		return false
	#if not encounter_report.player_won:
		#return false
	
	if passive_id not in encounter_report.active_player_passives_at_end_of_game:
		print("Passive ID not in player at end of game.")
		return false
	
	var new_value_from_encounter_report: int = encounter_report.get_total_nr_of_defeated_opponents()
	if self.unlock_condition_id not in save_game_state.condition_tracking.keys():
		save_game_state.condition_tracking[self.unlock_condition_id] = new_value_from_encounter_report
	else:
		save_game_state.condition_tracking[self.unlock_condition_id] += new_value_from_encounter_report
	
	if save_game_state.condition_tracking[self.unlock_condition_id] >= count:
		print("Found that count is high enough to reward %s, reseting count."%self.unlock_condition_id)
		save_game_state.condition_tracking[self.unlock_condition_id] = 0
		return true
	print("Count is not yet high enough to get the passive change (%s/%s)."%[
		save_game_state.condition_tracking[self.unlock_condition_id],count])
	return false

func is_condition_hidden_from_player(save_game_state: SaveGameState) -> bool:
	return not save_game_state.player_owns_passive(passive_id)
