@tool
extends UnlockCondition
class_name Condition_AnyEncounterCleared

### Met once any one of the encounters is cleared. Made by an EncounterMapNode whose lines are set to ANY.
@export var encounter_ids: Array[String] = []

func is_condition_met(save_game_state: SaveGameState,_encounter_report: EncounterReport) -> bool:
	if not save_game_state:
		return false
	for encounter_id in encounter_ids:
		if encounter_id in save_game_state.encounters_completed.keys():
			return true
	return false

func _build_description_segments(_save_game_state: SaveGameState) -> Array[DescriptionSegment]:
	var name_lists: Array = []
	for encounter_id in encounter_ids:
		var single: Array[DescriptionSegment] = [_encounter_name(encounter_id)]
		name_lists.append(single)
	return _template("UI_UNLOCK_CONDITION_ANY_ENCOUNTER_CLEARED", {"encounters": _join(name_lists, true)})
