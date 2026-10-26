@tool
extends EffectIntent
class_name DealDamageEffect

@export var damage: int
### When this damage comes from a stackable status (its tick or a triggered reaction), multiply it by the
### status's stack count: 10 damage at 3 stacks is 30.
@export var scale_with_stacks: bool = false

func create_intent_context(_game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var context = EffectContext.new()
	context.damage_amount = self.damage
	return context

func scale_context_by_stacks(context: EffectContext, stacks: int) -> void:
	if scale_with_stacks:
		context.damage_amount *= stacks

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("EFFECTINTENT_DEALDAMAGEEFFECT_TEMPLATE"), {"damage": str(damage)})

### "per stack" after the targeting phrase: "Give 10 Pleasure to target Partner per stack".
func get_trailing_description_segments() -> Array[DescriptionSegment]:
	if scale_with_stacks:
		return DescriptionBuilder.per_stack_segments()
	return []

### "Give X Pleasure to yourself" reads oddly - self-directed pleasure is "gained", not "given".
### Explicit "Player" (not just "Gain X") since statuses/passives can be owned by either side -
### targeting_intent=PLAYER always means the player specifically, not "whoever owns this", so an
### implicit "you" would be ambiguous read from an opponent's own status/passive tooltip.
func get_self_targeted_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("EFFECTINTENT_DEALDAMAGEEFFECT_SELF_TEMPLATE"), {"damage": str(damage)})
