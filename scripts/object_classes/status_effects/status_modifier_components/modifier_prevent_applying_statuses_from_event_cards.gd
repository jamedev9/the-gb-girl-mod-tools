@tool
extends StatusModifierComponent
class_name Modifier_PreventApplyingStatusesFromEventCards

@export var apply_to_all_cards: bool = false
@export var event_card_ids: Array[String] = []

func modify_context(context: EffectContext) -> void:
	#print("Effect context origin id: %s"%context.id_of_effect_origin)
	if not context.event_card_causing_effect:
		#print("Event card is not causing this effect.")
		return
	#if context.source is not PlayerEntity:
		#print("Source is not player entity")
		#return
	if context.id_of_effect_origin not in event_card_ids and not apply_to_all_cards:
		#print("Event card is not on the list ")
		return
	if context.source == context.target:
		### Do not multiply damage to self.
		#print("Self damage")
		return
	
	context.statuses_to_apply = []

func get_description_segments() -> Array[DescriptionSegment]:
	if apply_to_all_cards:
		return DescriptionBuilder.parse_template(tr("MODIFIER_PREVENTAPPLYINGSTATUSESFROMEVENTCARDS_ANY_TEMPLATE"))
	return DescriptionBuilder.parse_template(
		tr("MODIFIER_PREVENTAPPLYINGSTATUSESFROMEVENTCARDS_TEMPLATE"), {"card_names": _card_names(event_card_ids)})

