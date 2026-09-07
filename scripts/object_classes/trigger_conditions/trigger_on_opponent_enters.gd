@tool
extends TriggerCondition
class_name TriggerCondition_OnOpponentEnters

func is_condition_met(
	input_context: EffectContext,_game_state: GameState,_save_game_state: SaveGameState,owner_of_trigger: TargetEntity) -> bool:
		#print("Checking condition: TriggerCondition_OnOpponentEnters")
		if input_context.new_opponent_spawned != null:
			return true
		return false

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(tr("TRIGGERCONDITION_ONOPPONENTENTERS_TEMPLATE"))
