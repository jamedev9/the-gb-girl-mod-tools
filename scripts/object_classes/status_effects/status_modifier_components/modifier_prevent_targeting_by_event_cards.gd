@tool
extends StatusModifierComponent
class_name Modifier_PreventTargetingByEventcards

func modify_context(context: EffectContext) -> void:
	context.target_is_immune_to_event_card_targeting = true
	#context.statuses_to_apply.clear()

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(tr("MODIFIER_PREVENTTARGETINGBYEVENTCARDS_TEMPLATE"))

