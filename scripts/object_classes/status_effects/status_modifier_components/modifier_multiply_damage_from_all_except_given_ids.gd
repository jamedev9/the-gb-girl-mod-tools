@tool
extends StatusModifierComponent
class_name Modifier_MultiplyDamageFromAllExceptGivenIDs

@export var damage_phase: DamageSystem.DamagePhase
@export var id_of_effects: Array[String] = []
@export var damage_multiplier: float

func modify_context(context: EffectContext) -> void:
	if context.id_of_effect_origin in id_of_effects:
		#print("Found ID in list - returning without modifying")
		return
	if context.damage_phase != damage_phase:
		return
	#print("Modifying damage from effect: %s to be 0"%context.id_of_effect_origin)
	context.damage_multipliers.append(self.damage_multiplier)

### id_of_effects here is an exclusion list of raw effect-origin ids that could be player
### actions, event cards, or passives depending on what's excluded - there's no single id space
### to resolve names from, so this deliberately doesn't try to name them, just states the
### exception exists. See DescriptionBuilder.classify_percent_multiplier() for the blocked/
### increased/reduced/inverted cases.
func get_description_segments() -> Array[DescriptionSegment]:
	var participle: String = tr("MULTIPLYDAMAGE_INCOMING_VERB_PARTICIPLE" if damage_phase == DamageSystem.DamagePhase.INCOMING else "MULTIPLYDAMAGE_OUTGOING_VERB_PARTICIPLE")
	var classification: Dictionary = DescriptionBuilder.classify_percent_multiplier(damage_multiplier)
	match classification.case:
		"blocked":
			return DescriptionBuilder.parse_template(tr("MODIFIER_MULTIPLYDAMAGEFROMALLEXCEPTGIVENIDS_BLOCKED_TEMPLATE"), {"verb": participle})
		"inverted":
			return DescriptionBuilder.parse_template(tr("MODIFIER_MULTIPLYDAMAGEFROMALLEXCEPTGIVENIDS_INVERTED_TEMPLATE"), {"verb": participle})
		"inverted_scaled":
			return DescriptionBuilder.parse_template(tr("MODIFIER_MULTIPLYDAMAGEFROMALLEXCEPTGIVENIDS_INVERTED_SCALED_TEMPLATE"), {"verb": participle, "percent": str(classification.percent)})
		"increased":
			return DescriptionBuilder.parse_template(tr("MODIFIER_MULTIPLYDAMAGEFROMALLEXCEPTGIVENIDS_INCREASE_TEMPLATE"), {"verb": participle, "percent": str(classification.percent)})
		_: ### "reduced"
			return DescriptionBuilder.parse_template(tr("MODIFIER_MULTIPLYDAMAGEFROMALLEXCEPTGIVENIDS_REDUCE_TEMPLATE"), {"verb": participle, "percent": str(classification.percent)})
