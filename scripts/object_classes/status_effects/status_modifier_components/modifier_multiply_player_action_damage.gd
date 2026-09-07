@tool
extends StatusModifierComponent
class_name Modifier_MultiplyPlayerActionDamage

@export var actions_ids: Array[String] = []
@export var damage_multiplier: float

func modify_context(context: EffectContext) -> void:
	#print("Effect context origin id: %s"%context.id_of_effect_origin)
	if context.effect_origin is not PlayerAction:
		#print("Effect origin is not player action. ")
		return
	#if context.source is not PlayerEntity:
		##print("Source is not player entity")
		#return
	if context.id_of_effect_origin not in actions_ids:
		#print("Action is not on the list ")
		return
	if context.source == context.target:
		### Do not multiply damage to self.
		return
	
	context.damage_multipliers.append(self.damage_multiplier)

### See DescriptionBuilder.classify_percent_multiplier() for the blocked/increased/reduced/
### inverted cases.
func get_description_segments() -> Array[DescriptionSegment]:
	var action_names: String = _action_names(actions_ids)
	var verb: String = _agreement_verb(actions_ids.size(), "VERB_DEALS_SINGULAR", "VERB_DEALS_PLURAL")
	var classification: Dictionary = DescriptionBuilder.classify_percent_multiplier(damage_multiplier)
	match classification.case:
		"blocked":
			return DescriptionBuilder.parse_template(
				tr("MODIFIER_MULTIPLYPLAYERACTIONDAMAGE_BLOCKED_TEMPLATE"), {"action_names": action_names, "verb": verb})
		"inverted":
			return DescriptionBuilder.parse_template(
				tr("MODIFIER_MULTIPLYPLAYERACTIONDAMAGE_INVERTED_TEMPLATE"), {"action_names": action_names, "verb": verb})
		"inverted_scaled":
			return DescriptionBuilder.parse_template(
				tr("MODIFIER_MULTIPLYPLAYERACTIONDAMAGE_INVERTED_SCALED_TEMPLATE"),
				{"action_names": action_names, "verb": verb, "percent": str(classification.percent)})
		"increased":
			return DescriptionBuilder.parse_template(
				tr("MODIFIER_MULTIPLYPLAYERACTIONDAMAGE_INCREASE_TEMPLATE"),
				{"action_names": action_names, "verb": verb, "percent": str(classification.percent)})
		_: ### "reduced"
			return DescriptionBuilder.parse_template(
				tr("MODIFIER_MULTIPLYPLAYERACTIONDAMAGE_REDUCE_TEMPLATE"),
				{"action_names": action_names, "verb": verb, "percent": str(classification.percent)})
