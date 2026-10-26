@tool
extends EffectIntent
class_name SetPlayerPleasure

### Base of the effects that SET the player's Pleasure to an exact amount (SetPleasureToPercent, SetPleasureToValue). Not a hit and
### not healing: no damage or healing multiplier touches it, and nothing that reacts to damage dealt or healing fires. It still
### counts as Pleasure rising or falling (Edging, the encounter's peak Pleasure) and a value at or above the max is an ordinary
### orgasm - see MainCardgame._resolve_set_player_pleasure(). Player-only, so author it with NO_TARGET. Subclasses only say
### which amount to set (get_target_pleasure()) and how they read.

func create_intent_context(game_state: GameState, _intent_context: EffectContext) -> EffectContext:
	var context: EffectContext = EffectContext.new()
	context.set_player_pleasure_to = maxi(get_target_pleasure(int(game_state.player["damage_threshold"])), 0)
	return context

### The Pleasure the player is set to. max_pleasure is the player's max Pleasure (the bar's size) in this encounter.
func get_target_pleasure(_max_pleasure: int) -> int:
	return 0

func description_includes_targeting(
		_targeting_intent: TargetingSystem.TargetingMode, _targeting_rules: Array[TargetingRule]) -> bool:
	return false
