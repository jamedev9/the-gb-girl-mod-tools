@tool
extends EffectIntent
class_name ClearStatusesfromTargets

@export var status_ids: Array[String]

func create_intent_context(_game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var context: EffectContext = EffectContext.new()
	context.statuses_to_clear = status_ids
	context.id_of_effect_origin = self.intent_effect_id
	context.effect_origin = self

	return context

func get_description_segments() -> Array[DescriptionSegment]:
	var names: Array[String] = []
	for id in status_ids:
		var status_def: StatusEffectDefinition = AutoloadDatabase.get_status_effect_by_id(id)
		names.append(status_def.get_effect_name() if status_def else "?")
	return DescriptionBuilder.parse_template(
		tr("EFFECTINTENT_CLEARSTATUSESFROMTARGETS_TEMPLATE"), {"status_names": DescriptionBuilder.join_with_and(names)})

### You clear something FROM a target, not "to" it.
func get_targeting_preposition() -> String:
	return tr("PREPOSITION_FROM")
