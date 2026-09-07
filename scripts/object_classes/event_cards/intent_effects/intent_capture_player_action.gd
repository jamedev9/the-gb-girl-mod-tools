@tool
extends EffectIntent
class_name Intent_CapturePlayerAction

@export var player_action_id: String

func create_intent_context(game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var move_intent: EffectContext = EffectContext.new_capture_player_action_intent(
		game_state,player_action_id)
	return move_intent

func get_description_segments() -> Array[DescriptionSegment]:
	var action_def: PlayerAction = AutoloadDatabase.get_player_action_by_id(player_action_id)
	var action_name: String = action_def.get_action_name() if action_def else "?"
	return DescriptionBuilder.parse_template(
		tr("EFFECTINTENT_CAPTUREPLAYERACTION_TEMPLATE"), {"action_name": action_name})
