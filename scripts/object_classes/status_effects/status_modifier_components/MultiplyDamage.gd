@tool
extends StatusModifierComponent
class_name MultiplyDamage

### Multiplies the Pleasure of every hit it applies to, whoever is hit - the source itself included (the player's own
### Finger Yourself too). MultiplyDamageToOthers is the same effect for hits on OTHER targets only. With scale_with_stacks the
### stacks COMPOUND (x0.5 -> x0.25 -> x0.125), so a reduction never reaches zero; IncreaseDamageByPercent is the version whose
### stacks ADD UP (+25%, +50%, +75%).

@export var damage_phase: DamageSystem.DamagePhase
@export var multiplier: float = 1.0
### When this is on a stackable status, scale the multiplier with its stack count (see
### StatusModifierComponent.scale_multiplier_by_stacks()): multiplicative, so x0.5 becomes x0.25 at 2 stacks.
@export var scale_with_stacks: bool = false

func modify_context(context: EffectContext) -> void:
	if not context.damage_amount:
		return
	if not context.damage_phase == self.damage_phase:
		return
	context.damage_multipliers.append(_get_multiplier_for_stacks(context))

func _get_multiplier_for_stacks(context: EffectContext) -> float:
	if scale_with_stacks:
		return scale_multiplier_by_stacks(multiplier, context.modifier_effect_stacks)
	return multiplier

### Generic description support (see DescriptionBuilder). Statuses/passives can in theory be
### applied to either the player or an opponent, so this can't assume "you" - "Pleasure given"/
### "Pleasure received" (subjectless, matches the house style already used by hand-written
### descriptions like Numb's "Receives no Pleasure") instead of "Pleasure you give/receive".
### See DescriptionBuilder.classify_percent_multiplier() for the blocked/increased/reduced/
### inverted cases - a negative multiplier (e.g. Invert Damage's -1.0) reads as "inverted", not
### as a nonsensical "reduced by 200%".
func get_description_segments() -> Array[DescriptionSegment]:
	var segments: Array[DescriptionSegment] = _get_base_description_segments()
	### "per stack (multiplicative)" only where it means something: a plain increase/reduction. Blocking (0) and
	### inverting (negative) don't grow with stacks in a way the player could read off.
	if scale_with_stacks and multiplier > 0.0:
		segments.append(DescriptionSegment.text_segment(" "))
		segments.append_array(DescriptionBuilder.per_stack_multiplicative_segments())
	return segments

func _get_base_description_segments() -> Array[DescriptionSegment]:
	var participle: String = _get_description_participle()
	var classification: Dictionary = DescriptionBuilder.classify_percent_multiplier(multiplier)
	match classification.case:
		"blocked":
			return _get_blocked_description_segments()
		"inverted":
			return DescriptionBuilder.parse_template(tr("MULTIPLYDAMAGE_INVERTED_TEMPLATE"), {"verb": participle})
		"inverted_scaled":
			return DescriptionBuilder.parse_template(tr("MULTIPLYDAMAGE_INVERTED_SCALED_TEMPLATE"), {"verb": participle, "percent": str(classification.percent)})
		"increased":
			return DescriptionBuilder.parse_template(tr("MULTIPLYDAMAGE_INCREASED_TEMPLATE"), {"verb": participle, "percent": str(classification.percent)})
		_: ### "reduced"
			return DescriptionBuilder.parse_template(tr("MULTIPLYDAMAGE_REDUCED_TEMPLATE"), {"verb": participle, "percent": str(classification.percent)})

### The word the description uses for the phase ("given" / "received"). MultiplyDamageToOthers words it differently.
func _get_description_participle() -> String:
	return tr("MULTIPLYDAMAGE_INCOMING_VERB_PARTICIPLE" if damage_phase == DamageSystem.DamagePhase.INCOMING else "MULTIPLYDAMAGE_OUTGOING_VERB_PARTICIPLE")

func _get_blocked_description_segments() -> Array[DescriptionSegment]:
	var infinitive: String = tr("MULTIPLYDAMAGE_INCOMING_VERB_INFINITIVE" if damage_phase == DamageSystem.DamagePhase.INCOMING else "MULTIPLYDAMAGE_OUTGOING_VERB_INFINITIVE")
	return DescriptionBuilder.parse_template(tr("MULTIPLYDAMAGE_BLOCKED_TEMPLATE"), {"verb": infinitive})
