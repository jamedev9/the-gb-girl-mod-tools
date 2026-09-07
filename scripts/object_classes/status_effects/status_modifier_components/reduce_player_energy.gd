@tool
extends StatusModifierComponent
class_name Status_ReducePlayerEnergy

@export var energy_reduction: int
	
func modify_context(context: EffectContext) -> void:
	context.player_energy_reduction = self.energy_reduction

### Subjectless ("{amount} less Energy", not "You have..." ) - see PassiveEffectDefinition's
### note on statuses/passives being ownership-agnostic.
func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("STATUS_REDUCEPLAYERENERGY_TEMPLATE"), {"amount": str(energy_reduction)})
