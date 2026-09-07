@tool
extends TriggerCondition
class_name TriggerCondition_OnlyIfSourceHasOneOfListedPlayerActions

@export var action_ids: Array[String]

func is_condition_met(
	_input_context: EffectContext,
	game_state: GameState
	,_save_game_state: SaveGameState,
	_owner_of_trigger: TargetEntity) -> bool:
		
	if _owner_of_trigger is not OpponentEntity:
		#print("Target is not OpponentEntity")
		return false
	var action_on_opponent: String = game_state.get_action_assigned_to_opponent(_owner_of_trigger.opponent_id)
	if action_on_opponent not in action_ids:
		#print("Id of effect origin is not in actions. Action: %s"%input_context.player_action_id)
		return false

	return true

### Subjectless ("has X assigned", not "you have X assigned") - this checks whoever owns the
### trigger (always an opponent per is_condition_met() above, but kept generic/agnostic anyway).
func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("TRIGGERCONDITION_ONLYIFSOURCEHASONEOFLISTEDPLAYERACTIONS_TEMPLATE"), {"action_names": _action_names(action_ids)})
