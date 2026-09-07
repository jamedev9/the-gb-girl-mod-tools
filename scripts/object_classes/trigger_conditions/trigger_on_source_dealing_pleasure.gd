@tool
extends TriggerCondition
class_name TriggerCondition_OnSourceDealingPleasure

func is_condition_met(
	input_context: EffectContext,
	_game_state: GameState
	,_save_game_state: SaveGameState,
	_owner_of_trigger: TargetEntity) -> bool:
		
	#print("Checking TriggerCondition_OnSourceDealingPleasure")
	if not input_context.damage_was_succesfully_done:
		#print("The context does not contain any notification of successful damage.")
		return false
	
	if _owner_of_trigger.get_data() != input_context.source.get_data():
		#print("Error in context: Source is not owner of trigger")
		return false
	
	if input_context.damage_that_was_done <= 0:
		#print("No damage was dealt.")
		return false
	
	#print("Trigger condition is true!")
	return true

### Subjectless ("deals Pleasure", not "you deal Pleasure") - this fires for whoever owns the
### trigger dealing Pleasure, which could be the player or an opponent.
func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(tr("TRIGGERCONDITION_ONSOURCEDEALINGPLEASURE_TEMPLATE"))
