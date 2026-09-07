@tool
extends TriggerCondition
class_name TriggerCondition_OnOpponentDefeatedByPlayerAction

@export var action_ids: Array[String]

func is_condition_met(
	input_context: EffectContext,game_state: GameState,_save_game_state: SaveGameState,owner_of_trigger: TargetEntity) -> bool:
	if input_context.opponent_with_id_was_defeated == "":
		#print("TriggerCondition_OnOpponentDefeat Found input context with blank opponent defeated, returning false.")
		return false
	
	var defeat_reason: String = game_state.get_action_that_defeated_opponent(input_context.opponent_with_id_was_defeated)
	if defeat_reason not in action_ids:
		return false
	
	#print("Trigger condition %s found opponent defeat, condition is True."%trigger_condition_id)
	return true

### "a {OPPONENT} is defeated", not "the" - describes the general rule ("whenever a Partner is
### defeated by X, ..."), not a narration of one already-known specific individual.
func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("TRIGGERCONDITION_ONOPPONENTDEFEATEDBYPLAYERACTION_TEMPLATE"), {"action_names": _action_names(action_ids)})
