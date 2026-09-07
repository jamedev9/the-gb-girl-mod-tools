@tool
extends StatusModifierComponent
class_name MultiplyDamage

@export var damage_phase: DamageSystem.DamagePhase
@export var multiplier: float = 1.0
	
func modify_context(context: EffectContext) -> void:
	if not context.damage_amount:
		return
	if not context.damage_phase == self.damage_phase:
		return
	context.damage_multipliers.append(self.multiplier)

### Generic description support (see DescriptionBuilder). Statuses/passives can in theory be
### applied to either the player or an opponent, so this can't assume "you" - "Pleasure given"/
### "Pleasure received" (subjectless, matches the house style already used by hand-written
### descriptions like Numb's "Receives no Pleasure") instead of "Pleasure you give/receive".
### See DescriptionBuilder.classify_percent_multiplier() for the blocked/increased/reduced/
### inverted cases - a negative multiplier (e.g. Invert Damage's -1.0) reads as "inverted", not
### as a nonsensical "reduced by 200%".
func get_description_segments() -> Array[DescriptionSegment]:
	var infinitive: String = tr("MULTIPLYDAMAGE_INCOMING_VERB_INFINITIVE" if damage_phase == DamageSystem.DamagePhase.INCOMING else "MULTIPLYDAMAGE_OUTGOING_VERB_INFINITIVE")
	var participle: String = tr("MULTIPLYDAMAGE_INCOMING_VERB_PARTICIPLE" if damage_phase == DamageSystem.DamagePhase.INCOMING else "MULTIPLYDAMAGE_OUTGOING_VERB_PARTICIPLE")
	var classification: Dictionary = DescriptionBuilder.classify_percent_multiplier(multiplier)
	match classification.case:
		"blocked":
			return DescriptionBuilder.parse_template(tr("MULTIPLYDAMAGE_BLOCKED_TEMPLATE"), {"verb": infinitive})
		"inverted":
			return DescriptionBuilder.parse_template(tr("MULTIPLYDAMAGE_INVERTED_TEMPLATE"), {"verb": participle})
		"inverted_scaled":
			return DescriptionBuilder.parse_template(tr("MULTIPLYDAMAGE_INVERTED_SCALED_TEMPLATE"), {"verb": participle, "percent": str(classification.percent)})
		"increased":
			return DescriptionBuilder.parse_template(tr("MULTIPLYDAMAGE_INCREASED_TEMPLATE"), {"verb": participle, "percent": str(classification.percent)})
		_: ### "reduced"
			return DescriptionBuilder.parse_template(tr("MULTIPLYDAMAGE_REDUCED_TEMPLATE"), {"verb": participle, "percent": str(classification.percent)})
