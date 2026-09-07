@tool
extends TriggerCondition
class_name TriggerCondition_OnlyIfTargetHasOneOfListedPlayerActions

@export var action_ids: Array[String]

func is_condition_met(
	input_context: EffectContext,
	game_state: GameState
	,_save_game_state: SaveGameState,
	_owner_of_trigger: TargetEntity) -> bool:
		
	if input_context.target is not OpponentEntity:
		#print("Target is not OpponentEntity")
		return false
	var action_on_opponent: String = game_state.get_action_assigned_to_opponent(input_context.target.opponent_id)
	if action_on_opponent not in action_ids:
		#print("Id of effect origin is not in actions. Action: %s"%input_context.player_action_id)
		return false

	return true

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("TRIGGERCONDITION_ONLYIFTARGETHASONEOFLISTEDPLAYERACTIONS_TEMPLATE"), {"action_names": _action_names(action_ids)})
