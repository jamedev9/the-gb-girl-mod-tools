@tool
extends TriggerCondition
class_name TriggerCondition_OnOpponentDefeat


func is_condition_met(
	input_context: EffectContext,_game_state: GameState,_save_game_state: SaveGameState,owner_of_trigger: TargetEntity) -> bool:
		if input_context.opponent_with_id_was_defeated == "":
			#print("TriggerCondition_OnOpponentDefeat Found input context with blank opponent defeated, returning false.")
			return false
		#print("Trigger condition %s found opponent defeat, condition is True."%trigger_condition_id)
		return true

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(tr("TRIGGERCONDITION_ONOPPONENTDEFEAT_TEMPLATE"))
