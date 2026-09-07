@tool
extends EffectIntent
class_name Intent_RemovePassiveFromPlayer

@export var passive_id: String

func create_intent_context(game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var intent_context: TriggeredEffectContext = TriggeredEffectContext.new()
	intent_context.target = PlayerEntity.new(game_state)
	intent_context.passive_to_remove_from_target = passive_id
	intent_context.id_of_effect_origin = intent_effect_id
	intent_context.effect_origin = self
	
	print("Returning context to remove player passive with id: %s"%passive_id)
	return intent_context

func get_description_segments() -> Array[DescriptionSegment]:
	var passive_def: PassiveEffectDefinition = AutoloadDatabase.passive_effect_definitions.get(passive_id, null)
	return DescriptionBuilder.parse_template(
		tr("EFFECTINTENT_REMOVEPASSIVEFROMPLAYER_TEMPLATE"), {"name": passive_def.get_effect_name() if passive_def else "?"})
