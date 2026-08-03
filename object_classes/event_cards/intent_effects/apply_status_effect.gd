extends EffectIntent
class_name ApplyStatusEffect

@export var status_definition: StatusEffectDefinition
@export var status_duration: int = 1
@export var number_of_stacks: int = 1

#func apply_effect_to_context(context: EffectContext):
	#context.statuses_to_apply.append(self)
	
func create_intent_context(_game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var ctx = EffectContext.new()
	ctx.statuses_to_apply.append(self)
	return ctx
