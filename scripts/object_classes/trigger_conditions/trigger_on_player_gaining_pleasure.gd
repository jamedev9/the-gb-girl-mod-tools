@tool
extends TriggerCondition
class_name TriggerCondition_OnPlayerGainingPleasure


func is_condition_met(
	input_context: EffectContext,_game_state: GameState,_save_game_state: SaveGameState,_owner_of_trigger: TargetEntity) -> bool:
	if input_context.target is not PlayerEntity:
		return false
	if not input_context.damage_amount:
		return false
	if input_context.damage_amount <= 0:
		return false
	return true

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(tr("TRIGGERCONDITION_ONPLAYERGAININGPLEASURE_TEMPLATE"))
