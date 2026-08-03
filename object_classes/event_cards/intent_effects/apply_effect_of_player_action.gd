extends EffectIntent
class_name ApplyEffectOfPlayerAction

@export var player_action_id: String

func create_intent_context(game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var context: EffectContext = EffectContext.new_player_action_damage_intent(
		game_state,player_action_id,null
	)
	context.source = PlayerEntity.new(game_state)

	return context
