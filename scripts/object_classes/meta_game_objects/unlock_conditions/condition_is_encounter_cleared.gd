@tool
extends UnlockCondition
class_name Condition_IsEncounterCleared

@export var encounter_id: String

func is_condition_met(save_game_state: SaveGameState,_encounter_report: EncounterReport) -> bool:
	if not save_game_state:
		return false
	return encounter_id in save_game_state.encounters_completed.keys()

func _build_description_segments(_save_game_state: SaveGameState) -> Array[DescriptionSegment]:
	return _template("UI_UNLOCK_CONDITION_ENCOUNTER_CLEARED", {"encounter": _encounter_name(encounter_id)})
