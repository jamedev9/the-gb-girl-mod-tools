@tool
extends TriggerCondition
class_name TriggerCondition_OnMultipleDefeatInOneTurn

@export var trigger_multiple_times: bool = false
@export var required_defeats: int

func is_condition_met(
	input_context: EffectContext,
	_game_state: GameState
	,_save_game_state: SaveGameState,
	_owner_of_trigger: TargetEntity) -> bool:
	
	if input_context.opponent_with_id_was_defeated == "":
		return false
	
	var opps_defeated_this_turn: int = _game_state.get_nr_of_opponents_defeated_this_turn()
	
	if opps_defeated_this_turn < required_defeats:
		#print("Found opps defeated lower than defeats.")
		return false
	
	if opps_defeated_this_turn == required_defeats:
		return true
	
	return opps_defeated_this_turn > required_defeats and trigger_multiple_times

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_pluralized_template(
		required_defeats, "TRIGGERCONDITION_ONMULTIPLEDEFEATINONETURN_TEMPLATE_SINGULAR",
		"TRIGGERCONDITION_ONMULTIPLEDEFEATINONETURN_TEMPLATE", {"count": str(required_defeats)})
