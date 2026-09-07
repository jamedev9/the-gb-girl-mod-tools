@tool
extends StatusTickComponent
class_name TickingIfGuyWithPassiveHasBeenDefeated

@export var passive_id: String

func are_ticking_conditions_met(game_state: GameState) -> bool:
	var defeated_opponents: Dictionary = game_state.encounter_report.get_defeated_opponents()
	for opponent_id in defeated_opponents.keys():
		var opponent_type: OpponentType = AutoloadDatabase.opponent_types[opponent_id]
		if passive_id in opponent_type.passive_effects:
			return true

	return false

### Template says "a {OPPONENT}", not "the {OPPONENT}" - are_ticking_conditions_met() above
### checks whether ANY opponent with this passive has EVER been defeated across the whole
### encounter (an existential/historical check over get_defeated_opponents()), not one already-
### identified specific individual - "the" implies a definite, singular referent that doesn't
### exist here.
func get_when_description_segments() -> Array[DescriptionSegment]:
	var passive_def: PassiveEffectDefinition = AutoloadDatabase.passive_effect_definitions.get(passive_id, null)
	var passive_name: String = passive_def.get_effect_name() if passive_def else "?"
	return DescriptionBuilder.parse_template(
		tr("TICKINGIFGUYWITHPASSIVEHASBEENDEFEATED_WHEN_TEMPLATE"), {"passive_name": passive_name})
