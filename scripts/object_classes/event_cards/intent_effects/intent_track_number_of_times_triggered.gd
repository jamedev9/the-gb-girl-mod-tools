@tool
extends EffectIntent
class_name Intent_TrackNumberOfTimesTriggered

func create_intent_context(game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var intent_context: TriggeredEffectContext = TriggeredEffectContext.new()
	intent_context.target = PlayerEntity.new(intent_context.game_state)
	intent_context.id_of_effect_origin = intent_effect_id
	intent_context.effect_origin = self
	
	
	return intent_context
