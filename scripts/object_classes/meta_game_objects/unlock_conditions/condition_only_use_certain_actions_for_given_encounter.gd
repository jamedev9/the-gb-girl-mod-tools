@tool
extends UnlockCondition
class_name Condition_OnlyUseCertainActionsForGivenEncounter

@export var action_ids: Array[String]
@export var encounter_id: String

func is_judged_on_a_single_run() -> bool:
	return true

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

func _build_description_segments(_save_game_state: SaveGameState) -> Array[DescriptionSegment]:
	if action_ids.is_empty():
		return DescriptionBuilder.parse_template(tr("UI_UNLOCK_CONDITION_NO_ACTIONS_USED"))
	return _template("UI_UNLOCK_CONDITION_ONLY_USE_ACTIONS_TEMPLATE",
		{"encounter": _encounter_name(encounter_id), "actions": _term_list("ACTION", action_ids)})
