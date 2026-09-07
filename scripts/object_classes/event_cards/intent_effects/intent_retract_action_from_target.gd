@tool
extends EffectIntent
class_name Intent_RetractActionFromTarget

func create_intent_context(game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var retract_intent: EffectContext = EffectContext.new_retract_player_actions_intent(
		game_state,[""],self,self.intent_effect_id)
	print("Returning intent to retract action from target")
	return retract_intent

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(tr("EFFECTINTENT_RETRACTACTIONFROMTARGET_TEMPLATE"))
