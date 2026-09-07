@tool
extends EffectIntent
class_name Intent_TriggerNOrgasmsAndResetPleasure

@export var orgasms_to_trigger: int

func create_intent_context(_game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var context: EffectContext = EffectContext.new()
	
	context.orgasms_to_trigger = orgasms_to_trigger

	return context

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_pluralized_template(
		orgasms_to_trigger,
		"EFFECTINTENT_TRIGGERNORGASMSANDRESETPLEASURE_TEMPLATE_SINGULAR",
		"EFFECTINTENT_TRIGGERNORGASMSANDRESETPLEASURE_TEMPLATE",
		{"count": str(orgasms_to_trigger)})
