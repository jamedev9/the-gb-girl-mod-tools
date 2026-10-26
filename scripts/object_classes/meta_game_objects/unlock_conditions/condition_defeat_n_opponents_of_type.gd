@tool
extends UnlockCondition
class_name Condition_DefeatNOpponentsOfType

### Progression (save game): make N partners of the given type(s) cum, counted over the whole save. With
### several types the defeats of all of them add up (e.g. every kind of trucker).

@export var opponent_type_ids: Array[String] = []
@export var number_to_defeat: int = 1

func is_condition_met(save_game_state: SaveGameState,_encounter_report: EncounterReport) -> bool:
	return get_progress_current(save_game_state) >= number_to_defeat

func get_progress_style() -> ProgressStyle:
	return ProgressStyle.COUNT_UP

func get_progress_current(save_game_state: SaveGameState) -> int:
	var count: int = 0
	for opponent_type_id in opponent_type_ids:
		count += int(save_game_state.opponents_defeated.get(opponent_type_id,0))
	return count

func get_progress_required(_save_game_state: SaveGameState) -> int:
	return number_to_defeat

func _build_description_segments(_save_game_state: SaveGameState) -> Array[DescriptionSegment]:
	var type_lists: Array = []
	for opponent_type_id in opponent_type_ids:
		var opponent_type: OpponentType = AutoloadDatabase.opponent_types.get(opponent_type_id, null)
		var type_segments: Array[DescriptionSegment] = [
			DescriptionSegment.emphasis_segment(opponent_type.get_opponent_type_name() if opponent_type else "?")]
		type_lists.append(type_segments)
	return _template("UI_UNLOCK_CONDITION_DEFEAT_OF_TYPES", {"count": _number(number_to_defeat), "types": _join(type_lists, true)})
