@tool
extends StatusModifierComponent
class_name Modifier_MultiplyEventCardDamage

@export var apply_to_all_cards: bool = false
@export var event_card_ids: Array[String] = []
@export var damage_multiplier: float

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
	
	#print("Multiplying damage wiht effect: %s"%status_modifer_component_id)
	context.damage_multipliers.append(self.damage_multiplier)

### See DescriptionBuilder.classify_percent_multiplier() for the blocked/increased/reduced/
### inverted cases.
func get_description_segments() -> Array[DescriptionSegment]:
	var names: String = tr("MODIFIER_MULTIPLYEVENTCARDDAMAGE_ANY_CARDS") if apply_to_all_cards else _card_names(event_card_ids)
	var classification: Dictionary = DescriptionBuilder.classify_percent_multiplier(damage_multiplier)
	match classification.case:
		"blocked":
			return DescriptionBuilder.parse_template(tr("MODIFIER_MULTIPLYEVENTCARDDAMAGE_BLOCKED_TEMPLATE"), {"names": names})
		"inverted":
			return DescriptionBuilder.parse_template(tr("MODIFIER_MULTIPLYEVENTCARDDAMAGE_INVERTED_TEMPLATE"), {"names": names})
		"inverted_scaled":
			return DescriptionBuilder.parse_template(tr("MODIFIER_MULTIPLYEVENTCARDDAMAGE_INVERTED_SCALED_TEMPLATE"), {"names": names, "percent": str(classification.percent)})
		"increased":
			return DescriptionBuilder.parse_template(tr("MODIFIER_MULTIPLYEVENTCARDDAMAGE_INCREASE_TEMPLATE"), {"names": names, "percent": str(classification.percent)})
		_: ### "reduced"
			return DescriptionBuilder.parse_template(tr("MODIFIER_MULTIPLYEVENTCARDDAMAGE_REDUCE_TEMPLATE"), {"names": names, "percent": str(classification.percent)})
