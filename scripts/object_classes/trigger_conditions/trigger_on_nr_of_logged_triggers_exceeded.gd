@tool
extends TriggerCondition
class_name TriggerCondition_OnNrOfLoggedTriggersExceeded

@export var trigger_id_to_check: String
@export var nr_to_exceed: int
@export var reset_counter_after_triggering: bool = true

func is_condition_met(
	_input_context: EffectContext,_game_state: GameState,save_game_state: SaveGameState,_owner_of_trigger: TargetEntity) -> bool:
	
	var return_value: bool = false
	
	var current_nr_of_triggers: int = save_game_state.get_times_trigger_has_triggered(trigger_id_to_check)
	if current_nr_of_triggers >= nr_to_exceed:
		return_value = true
		if reset_counter_after_triggering:
			#print("Resetting trigger counter for: %s"%trigger_id_to_check)
			save_game_state.reset_trigger_counter_for_id(trigger_id_to_check)
	
	#print("%s cheking if triggers exceeded. Returning: %s"%[trigger_condition_id,return_value])
	return return_value

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("TRIGGERCONDITION_ONNROFLOGGEDTRIGGERSEXCEEDED_TEMPLATE"), {"count": str(nr_to_exceed)})
