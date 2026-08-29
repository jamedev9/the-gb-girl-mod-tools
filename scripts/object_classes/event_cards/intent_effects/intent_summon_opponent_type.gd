extends EffectIntent
class_name Intent_SummonOpponent

@export var opponent_type_id: String
@export var opponent_is_unique: bool = false

func create_intent_context(_game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var context: EffectContext = EffectContext.new()
	context.spawn_opponent = true
	context.spawn_opponent_type = opponent_type_id
	context.spawned_opponent_is_unique = opponent_is_unique
	return context
