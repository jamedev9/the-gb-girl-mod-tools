extends EffectIntent
class_name DealDamageEffect

@export var damage: int

func create_intent_context(_game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var context = EffectContext.new()
	context.damage_amount = self.damage
	return context
	
