@tool
extends TriggerCondition
class_name TriggerCondition_OnPlayerActionsStarted

@export var action_ids: Array[String]

func is_condition_met(
	input_context: EffectContext,
	_game_state: GameState
	,_save_game_state: SaveGameState,
	_owner_of_trigger: TargetEntity) -> bool:
		
	if not input_context.moving_player_action:
		return false
	if input_context.player_action_id not in action_ids:
		return false
	if input_context.target_is_immune_to_action:
		return false
	#print("Condition met, player started action: %s"%input_context.player_action_id)
	return true

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("TRIGGERCONDITION_ONPLAYERACTIONSSTARTED_TEMPLATE"), {"action_names": _action_names(action_ids)})
