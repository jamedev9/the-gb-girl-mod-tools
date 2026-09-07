@tool
extends TriggerCondition
class_name TriggerCondition_OnSourceTakingNDamageOnOneTurn

@export var damage_value: int

func is_condition_met(
	_input_context: EffectContext,_game_state: GameState,save_game_state: SaveGameState,_owner_of_trigger: TargetEntity) -> bool:

	if trigger_condition_id == "":
		push_error("TriggerCondition_OnSourceTakingNDamageOnOneTurn has no trigger_condition_id set - cannot track firing state safely.")
		return false
	if _game_state.get_turn_tracked_value("damage_taken",_owner_of_trigger) < damage_value:
		return false
	if _game_state.get_turn_tracked_value(trigger_condition_id,_owner_of_trigger) > 0:
		return false ### Already fired for this owner this turn.
	_game_state.add_to_turn_tracked_value(trigger_condition_id,_owner_of_trigger,1)
	return true

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("TRIGGERCONDITION_ONSOURCETAKINGNDAMAGEONONETURN_TEMPLATE"), {"count": str(damage_value)})
