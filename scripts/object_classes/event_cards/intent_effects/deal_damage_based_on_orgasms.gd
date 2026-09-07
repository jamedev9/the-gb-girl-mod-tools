@tool
extends EffectIntent
class_name DealDamageBasedOnOrgasms

@export var damage_per_orgasm: int

func create_intent_context(game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var context: EffectContext = EffectContext.new()
	var orgasm_count: int = game_state.get_current_orgasm_count()
	
	context.damage_phase = DamageSystem.DamagePhase.OUTGOING
	context.damage_amount = damage_per_orgasm*orgasm_count

	return context

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("EFFECTINTENT_DEALDAMAGEBASEDONORGASMS_TEMPLATE"), {"amount": str(damage_per_orgasm)})

### Explicit "Player" since targeting_intent=PLAYER always means the player, regardless of which
### side owns the surrounding status/passive - see DealDamageEffect's own self-targeted override.
func get_self_targeted_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("EFFECTINTENT_DEALDAMAGEBASEDONORGASMS_SELF_TEMPLATE"), {"amount": str(damage_per_orgasm)})
