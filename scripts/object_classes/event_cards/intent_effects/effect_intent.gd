extends Resource
class_name EffectIntent

@export var intent_effect_id: String

### This method is overwritten by child classes.
### This only changes the effect of a context, not the target or source.
func create_intent_context(_game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var context: EffectContext = EffectContext.new()
	return context
