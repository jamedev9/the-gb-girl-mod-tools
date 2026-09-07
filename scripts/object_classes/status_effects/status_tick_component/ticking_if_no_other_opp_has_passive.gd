@tool
extends StatusTickComponent
class_name TickingIfNoOtherOppHasPassive

@export var passive_id: String

func are_ticking_conditions_met(game_state: GameState) -> bool:
	var nr_guys_with_passive: int = 0
	var active_opponents = game_state.get_currently_active_opponents()
	for opponent_id in active_opponents.keys():
		var opponent_entity: OpponentEntity = OpponentEntity.new(game_state,opponent_id)
		var passives = opponent_entity.get_passive_effects()
		#print("Passives on opponent %s: %s"%[passive_id,passives])
		if passive_id in passives:
			nr_guys_with_passive += 1
			if nr_guys_with_passive > 1:
				#print("Found another opponent with passive %s, returning False"%passive_id)
				return false

	return true

func get_when_description_segments() -> Array[DescriptionSegment]:
	var passive_def: PassiveEffectDefinition = AutoloadDatabase.passive_effect_definitions.get(passive_id, null)
	var passive_name: String = passive_def.get_effect_name() if passive_def else "?"
	return DescriptionBuilder.parse_template(
		tr("TICKINGIFNOOTHEROPPHASPASSIVE_WHEN_TEMPLATE"), {"passive_name": passive_name})
