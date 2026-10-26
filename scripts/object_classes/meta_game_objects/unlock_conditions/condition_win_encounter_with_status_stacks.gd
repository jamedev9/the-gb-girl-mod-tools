@tool
extends Condition_WinEncounterWithActiveStatus
class_name Condition_WinEncounterWithStatusStacks

### Report: win the encounter while the player has at least required_stacks stacks of the status when it ends. The status has to be
### stackable (StatusEffectDefinition.stackable) for more than 1 to be possible, and its max_stacks must allow the number.

@export_range(1, 99, 1) var required_stacks: int = 2

func get_required_stacks() -> int:
	return maxi(required_stacks,1)

func _build_description_segments(_save_game_state: SaveGameState) -> Array[DescriptionSegment]:
	return _template("UI_UNLOCK_CONDITION_WIN_WITH_STATUS_STACKS", {
		"encounter": _encounter_name(encounter_id), "status": _term_link("STATUS", status_id),
		"count": _number(required_stacks)}, required_stacks)
