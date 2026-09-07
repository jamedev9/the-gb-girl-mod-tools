@tool
extends TriggerCondition
class_name TriggerCondition_RandomChance

### TODO: Fetch a trigger chance from save game?
@export_range(0,1,0.01) var trigger_chance: float = 1 #100# chance

func is_condition_met(
	_input_context: EffectContext,
	_game_state: GameState,
	_save_game_state: SaveGameState,
	_owner_of_trigger: TargetEntity) -> bool:
		
		if trigger_chance == 0:
			#print("Trigger chance is 0, returning false.")
			return false
		
		var random_nr: float = randf_range(0,1)
		#print("random roll: %s - is it lower than trigger chance: %s ?"%[random_nr,trigger_chance])
		return random_nr <= trigger_chance

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("TRIGGERCONDITION_RANDOMCHANCE_TEMPLATE"), {"percent": str(roundi(trigger_chance * 100.0))})
