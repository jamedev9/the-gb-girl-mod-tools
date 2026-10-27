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

func create_pleasure_preview_context(game_state: GameState, intent_context: EffectContext) -> EffectContext:
	return create_intent_context(game_state, intent_context)

func get_pleasure_kind() -> PleasureKind:
	return PleasureKind.GIVES

func get_described_pleasure_amount() -> int:
	return damage

func scale_context_by_stacks(context: EffectContext, stacks: int) -> void:
	if scale_with_stacks:
		context.damage_amount *= stacks

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("EFFECTINTENT_DEALDAMAGEEFFECT_TEMPLATE"), {"damage": _get_damage_segment()})

### "per stack" after the targeting phrase: "Give 10 Pleasure to target Partner per stack", then what it comes to right now in a
### tooltip that knows the stacks (" (currently 30)").
func get_trailing_description_segments() -> Array[DescriptionSegment]:
	if scale_with_stacks:
		var segments: Array[DescriptionSegment] = DescriptionBuilder.per_stack_segments()
		segments.append(DescriptionSegment.live_pleasure_total_segment(self))
		return segments
	return []

### The number in the text, live in a tooltip that knows the situation (DescriptionSegment.Type.LIVE_PLEASURE). Scaling with stacks
### it stays the per-stack number, and the live total follows "per stack" (get_trailing_description_segments()).
func _get_damage_segment() -> DescriptionSegment:
	if scale_with_stacks:
		return DescriptionSegment.text_segment(str(damage))
	return DescriptionSegment.live_pleasure_segment(str(damage), self)

### "Give X Pleasure to yourself" reads oddly - self-directed pleasure is "gained", not "given".
### Explicit "Player" (not just "Gain X") since statuses/passives can be owned by either side -
### targeting_intent=PLAYER always means the player specifically, not "whoever owns this", so an
### implicit "you" would be ambiguous read from an opponent's own status/passive tooltip.
func get_self_targeted_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("EFFECTINTENT_DEALDAMAGEEFFECT_SELF_TEMPLATE"), {"damage": _get_damage_segment()})
