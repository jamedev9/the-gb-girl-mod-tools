@tool
extends ModExportable
class_name StatusTickComponent

@export var tick_component_id: String
@export var effect_intents: Array[EffectAndTargetIntent]

func are_ticking_conditions_met(_game_state: GameState) -> bool:
	return true

### Generic description support (see DescriptionBuilder) - the "when" half of this tick's
### tooltip line (paired with effect_intents for the "then" half - see
### EffectDefinition.get_tooltip_description_segments()). Base default matches the base
### are_ticking_conditions_met() above: ticks unconditionally every turn. Override for any
### subclass with a real conditional tick (e.g. TickingIfNoOtherOppHasPassive).
func get_when_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(tr("STATUSTICKCOMPONENT_EVERY_TURN_TEMPLATE"))
