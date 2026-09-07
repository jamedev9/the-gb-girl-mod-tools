@tool
extends EffectIntent
class_name DealDamagePerEnergy

@export var damage_per_energy: int

func create_intent_context(game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var context: EffectContext = EffectContext.new()
	var player: PlayerEntity = PlayerEntity.new(game_state)
	var energy_to_drain: int = player.get_player_energy()
	
	context.damage_phase = DamageSystem.DamagePhase.OUTGOING
	context.damage_amount = damage_per_energy*energy_to_drain
	
	#context.energy_delta = energy_to_drain
	#context.energy_reason = EffectContext.EnergyReason.EVENT_CARD_EFFECT

	return context

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("EFFECTINTENT_DEALDAMAGEPERENERGY_TEMPLATE"), {"amount": str(damage_per_energy)})

### Explicit "Player" since targeting_intent=PLAYER always means the player, regardless of which
### side owns the surrounding status/passive - see DealDamageEffect's own self-targeted override.
func get_self_targeted_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("EFFECTINTENT_DEALDAMAGEPERENERGY_SELF_TEMPLATE"), {"amount": str(damage_per_energy)})
