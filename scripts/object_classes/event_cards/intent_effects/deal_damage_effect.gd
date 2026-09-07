@tool
extends EffectIntent
class_name DealDamageEffect

@export var damage: int

func create_intent_context(_game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var context = EffectContext.new()
	context.damage_amount = self.damage
	return context

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("EFFECTINTENT_DEALDAMAGEEFFECT_TEMPLATE"), {"damage": str(damage)})

### "Give X Pleasure to yourself" reads oddly - self-directed pleasure is "gained", not "given".
### Explicit "Player" (not just "Gain X") since statuses/passives can be owned by either side -
### targeting_intent=PLAYER always means the player specifically, not "whoever owns this", so an
### implicit "you" would be ambiguous read from an opponent's own status/passive tooltip.
func get_self_targeted_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("EFFECTINTENT_DEALDAMAGEEFFECT_SELF_TEMPLATE"), {"damage": str(damage)})
