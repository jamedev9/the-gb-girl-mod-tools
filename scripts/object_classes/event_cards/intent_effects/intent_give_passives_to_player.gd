@tool
extends EffectIntent
class_name Intent_GivePassivesToPlayer

@export var passive_ids: Array[String]

func create_intent_context(game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var intent_context: TriggeredEffectContext = TriggeredEffectContext.new()
	intent_context.target = PlayerEntity.new(game_state)
	intent_context.passives_to_add_to_target = passive_ids
	intent_context.id_of_effect_origin = intent_effect_id
	intent_context.effect_origin = self
	
	print("Returning context to remove player passive with id: %s"%passive_ids)
	return intent_context

func get_description_segments() -> Array[DescriptionSegment]:
	var names: Array[String] = []
	for id in passive_ids:
		var passive_def: PassiveEffectDefinition = AutoloadDatabase.passive_effect_definitions.get(id, null)
		names.append(passive_def.get_effect_name() if passive_def else "?")
	return DescriptionBuilder.parse_template(
		tr("EFFECTINTENT_GIVEPASSIVESTOPLAYER_TEMPLATE"), {"names": DescriptionBuilder.join_with_and(names)})
