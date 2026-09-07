@tool
extends EffectIntent
class_name DeltaEnergyBasedOnOrgasms

@export var energy_per_orgasm: int

func create_intent_context(game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var context: EffectContext = EffectContext.new()
	var orgasm_count: int = game_state.get_current_orgasm_count()
	
	context.energy_reason = EffectContext.EnergyReason.EVENT_CARD_EFFECT
	context.energy_delta = energy_per_orgasm*orgasm_count

	return context

### Same sign convention as ApplyEnergyDelta - negative means gain, positive means lose.
func get_description_segments() -> Array[DescriptionSegment]:
	if energy_per_orgasm < 0:
		return DescriptionBuilder.parse_template(
			tr("EFFECTINTENT_DELTAENERGYBASEDONORGASMS_GAIN_TEMPLATE"), {"amount": str(-energy_per_orgasm)})
	return DescriptionBuilder.parse_template(
		tr("EFFECTINTENT_DELTAENERGYBASEDONORGASMS_LOSE_TEMPLATE"), {"amount": str(energy_per_orgasm)})

func description_includes_targeting(
		_targeting_intent: TargetingSystem.TargetingMode, _targeting_rules: Array[TargetingRule]) -> bool:
	return false
