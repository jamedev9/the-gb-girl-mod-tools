extends UnlockCondition
class_name Condition_OnlyUseCertainActionsForGivenEncounter

@export var action_ids: Array[String]
@export var encounter_id: String

func is_condition_met(_save_game_state: SaveGameState,encounter_report: EncounterReport) -> bool:
	if not encounter_report:
		return false
	if encounter_report.player_won != true:
		return false
	if encounter_report.player_lost == true:
		return false
	if encounter_report.encounter_def.encounter_id != encounter_id:
		return false
	for used_action_id in encounter_report.action_usage.keys():
		if used_action_id not in action_ids:
			if encounter_report.action_usage[used_action_id].get_total_damage_dealt() > 0:
				return false
	return true
