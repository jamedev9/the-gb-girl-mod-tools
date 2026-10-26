@tool
extends EffectIntent
class_name EndPlayerTurn

### Ends the player's turn, as if they had pressed End Turn. Like the button it only queues the end of the turn: the turn really ends
### once the animations of everything before it have played, and the player can't act in between (MainCardgame._resolve_end_player_turn()).
### The rest of the card still resolves first, since a card's effects all resolve in the game logic before any of them is animated. Does
### nothing outside the player's own turn (an opponent Move or a status tick), or when the turn is already ending. Player-only, so
### author it with NO_TARGET.

func create_intent_context(_game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var context: EffectContext = EffectContext.new()
	context.end_player_turn = true
	return context

### "End your turn"
func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(tr("EFFECTINTENT_ENDPLAYERTURN_TEMPLATE"))

func description_includes_targeting(
		_targeting_intent: TargetingSystem.TargetingMode, _targeting_rules: Array[TargetingRule]) -> bool:
	return false
