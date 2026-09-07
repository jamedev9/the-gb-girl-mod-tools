@tool
extends EffectIntent
class_name ApplyEnergyDelta

@export var energy_delta: int

func create_intent_context(_game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var context: EffectContext = EffectContext.new()
	context.energy_delta = self.energy_delta
	context.energy_reason = EffectContext.EnergyReason.EVENT_CARD_EFFECT
	return context

### Energy is player-only, so unlike most effects this doesn't need a Partner-facing phrasing -
### a negative delta means the player gains energy, a positive delta means they lose it.
func get_description_segments() -> Array[DescriptionSegment]:
	if energy_delta < 0:
		return DescriptionBuilder.parse_template(
			tr("EFFECTINTENT_APPLYENERGYDELTA_GAIN_TEMPLATE"), {"amount": str(-energy_delta)})
	return DescriptionBuilder.parse_template(
		tr("EFFECTINTENT_APPLYENERGYDELTA_LOSE_TEMPLATE"), {"amount": str(energy_delta)})

func description_includes_targeting(
		_targeting_intent: TargetingSystem.TargetingMode, _targeting_rules: Array[TargetingRule]) -> bool:
	return false
