extends EffectIntent
class_name RandomlyHealOrDealDamage

@export var damage: int
@export_range(0,1,0.01) var chance_to_heal: float

func create_intent_context(_game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var context = EffectContext.new()
	var random_nr: float = randf_range(0,1)
	if random_nr <= chance_to_heal:
		context.healing_amount = damage
	else:
		context.damage_amount = self.damage
	return context
