@tool
extends UnlockCondition
class_name Condition_DefeatNOpponentsWithPassive

@export var number_to_defeat: int
@export var passive_id: String

func is_condition_met(save_game_state: SaveGameState,_encounter_report: EncounterReport) -> bool:
	var count = save_game_state.get_defeated_opponents_with_passive(passive_id)
	return count >= number_to_defeat
	

### The hand-written description plus the counter (its text has no counter of its own).
func _build_description_segments(save_game_state: SaveGameState) -> Array[DescriptionSegment]:
	var current_count: int = save_game_state.get_defeated_opponents_with_passive(passive_id) if save_game_state else 0
	var segments: Array[DescriptionSegment] = DescriptionBuilder.parse_template(description)
	segments.append_array(_template("UI_UNLOCK_CONDITION_PROGRESS_SUFFIX", {"progress": _progress_text(current_count, number_to_defeat)}))
	return segments
