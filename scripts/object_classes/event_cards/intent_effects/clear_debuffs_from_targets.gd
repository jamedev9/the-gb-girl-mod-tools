@tool
extends EffectIntent
class_name ClearDebuffsFromTargets

func create_intent_context(_game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var context: EffectContext = EffectContext.new()
	
	var status_ids: Array[String] = []
	for status_id in AutoloadDatabase.status_effects_by_id.keys():
		var status: StatusEffectDefinition = AutoloadDatabase.get_status_effect_by_id(status_id)
		if status.status_category != StatusEffectDefinition.StatusCategory.DEBUFF:
			continue
		status_ids.append(status_id)
	
	context.statuses_to_clear = status_ids
	context.id_of_effect_origin = self.intent_effect_id
	context.effect_origin = self

	return context

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(tr("EFFECTINTENT_CLEARDEBUFFSFROMTARGETS_TEMPLATE"))

### You clear something FROM a target, not "to" it.
func get_targeting_preposition() -> String:
	return tr("PREPOSITION_FROM")
