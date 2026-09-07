@tool
extends StatusModifierComponent
class_name MultiplyHealing

@export var damage_phase: DamageSystem.DamagePhase
@export var multiplier: float = 1.0
	
func modify_context(context: EffectContext) -> void:
	if not context.healing_amount:
		return
	context.healing_multipliers.append(self.multiplier)

### Reuses MultiplyDamage's "give"/"receive" verb keys - same concept (outgoing vs incoming),
### just applied to healing instead of damage. Subjectless, same reasoning as MultiplyDamage's
### own get_description_segments(); same DescriptionBuilder.classify_percent_multiplier() cases.
func get_description_segments() -> Array[DescriptionSegment]:
	var infinitive: String = tr("MULTIPLYDAMAGE_INCOMING_VERB_INFINITIVE" if damage_phase == DamageSystem.DamagePhase.INCOMING else "MULTIPLYDAMAGE_OUTGOING_VERB_INFINITIVE")
	var participle: String = tr("MULTIPLYDAMAGE_INCOMING_VERB_PARTICIPLE" if damage_phase == DamageSystem.DamagePhase.INCOMING else "MULTIPLYDAMAGE_OUTGOING_VERB_PARTICIPLE")
	var classification: Dictionary = DescriptionBuilder.classify_percent_multiplier(multiplier)
	match classification.case:
		"blocked":
			return DescriptionBuilder.parse_template(tr("MULTIPLYHEALING_BLOCKED_TEMPLATE"), {"verb": infinitive})
		"inverted":
			return DescriptionBuilder.parse_template(tr("MULTIPLYHEALING_INVERTED_TEMPLATE"), {"verb": participle})
		"inverted_scaled":
			return DescriptionBuilder.parse_template(tr("MULTIPLYHEALING_INVERTED_SCALED_TEMPLATE"), {"verb": participle, "percent": str(classification.percent)})
		"increased":
			return DescriptionBuilder.parse_template(tr("MULTIPLYHEALING_INCREASE_TEMPLATE"), {"verb": participle, "percent": str(classification.percent)})
		_: ### "reduced"
			return DescriptionBuilder.parse_template(tr("MULTIPLYHEALING_REDUCE_TEMPLATE"), {"verb": participle, "percent": str(classification.percent)})

