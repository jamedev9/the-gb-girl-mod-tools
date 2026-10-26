@tool
extends UnlockCondition
class_name Condition_DefeatNOppsWithActions

@export var number_to_defeat: int
@export var action_ids: Array[String]

func is_condition_met(save_game_state: SaveGameState,_encounter_report: EncounterReport) -> bool:
	var count: int = 0
	for action_id in action_ids:
		count += save_game_state.get_opponents_defeated_by_action(action_id)
	return count >= number_to_defeat

func _build_description_segments(save_game_state: SaveGameState) -> Array[DescriptionSegment]:
	var current_number: int = 0
	if save_game_state:
		for action_id in action_ids:
			current_number += save_game_state.get_opponents_defeated_by_action(action_id)
	return _template("UI_UNLOCK_CONDITION_DEFEAT_WITH_ACTIONS", {
		"count": _number(number_to_defeat), "actions": _term_list("ACTION", action_ids, true),
		"progress": _progress_text(current_number, number_to_defeat)}, number_to_defeat)
