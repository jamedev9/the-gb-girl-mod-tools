@tool
extends UnlockCondition
class_name Condition_ClearGivenEncounterWithoutUsingSpecifiedActions

@export var encounter_id: String
@export var action_ids: Array[String]

func is_judged_on_a_single_run() -> bool:
	return true

func is_condition_met(_save_game_state: SaveGameState,encounter_report: EncounterReport) -> bool:
	if not encounter_report:
		return false
	if not encounter_report.player_won:
		return false
	if encounter_id != encounter_report.encounter_def.encounter_id:
		return false
	for action_id in action_ids:
		if action_id in encounter_report.action_usage.keys():
			if encounter_report.action_usage[action_id].get_total_damage_dealt() > 0:
				return false
	return true

### adding at test text here

func _build_description_segments(_save_game_state: SaveGameState) -> Array[DescriptionSegment]:
	return _template("UI_UNLOCK_CONDITION_CLEAR_WITHOUT_ACTIONS",
		{"encounter": _encounter_name(encounter_id), "actions": _term_list("ACTION", action_ids)})
