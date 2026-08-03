extends EffectIntent
class_name Intent_CapturePlayerAction

@export var player_action_id: String

func create_intent_context(game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var move_intent: EffectContext = EffectContext.new_capture_player_action_intent(
		game_state,player_action_id)
	return move_intent
