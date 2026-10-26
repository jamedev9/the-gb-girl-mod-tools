@tool
extends StatusModifierComponent
class_name IncreaseDamageByPercent

### Raises the Pleasure of every hit it applies to by a share of the base amount for EACH STACK of the status running it, and the
### stacks ADD UP: +25% per stack is x1.25 at 1 stack, x1.5 at 2, x1.75 at 3. MultiplyDamage with scale_with_stacks compounds
### instead (x1.25, x1.5625, x1.953) and is the one to use for a reduction, which stays above zero that way. This class only
### increases. Applies to every target, the source itself included; IncreaseDamageByPercentToOthers skips hits on itself.

@export var damage_phase: DamageSystem.DamagePhase
### The share of the base Pleasure added per stack: 0.25 = +25% per stack.
@export_range(0.0, 10.0, 0.01, "or_greater") var increase_per_stack: float = 0.25

func modify_context(context: EffectContext) -> void:
	if not context.damage_amount:
		return
	if not context.damage_phase == self.damage_phase:
		return
	context.damage_multipliers.append(get_additive_multiplier_for_stacks(increase_per_stack, context.modifier_effect_stacks))

### Generic description support (see DescriptionBuilder): "Pleasure given is increased by 25% per stack (additive)". Reuses
### MultiplyDamage's "is increased by {percent}%" wording and verbs; subjectless for the same reason as MultiplyDamage.
func get_description_segments() -> Array[DescriptionSegment]:
	return get_description_segments_for_stacks(0)

### With the stacks the status has right now (> 0), the parenthesis also says what that comes to: "per stack (additive, currently 60%)".
func get_description_segments_for_stacks(stacks: int) -> Array[DescriptionSegment]:
	var segments: Array[DescriptionSegment] = DescriptionBuilder.parse_template(
		tr("MULTIPLYDAMAGE_INCREASED_TEMPLATE"),
		{"verb": _get_description_participle(), "percent": str(roundi(increase_per_stack * 100.0))})
	segments.append(DescriptionSegment.text_segment(" "))
	var current_percent: int = -1
	if stacks > 0:
		current_percent = roundi(increase_per_stack * 100.0 * float(stacks))
	segments.append_array(DescriptionBuilder.per_stack_additive_segments(current_percent))
	return segments

### The word the description uses for the phase ("given" / "received"). IncreaseDamageByPercentToOthers words it differently.
func _get_description_participle() -> String:
	return tr("MULTIPLYDAMAGE_INCOMING_VERB_PARTICIPLE" if damage_phase == DamageSystem.DamagePhase.INCOMING else "MULTIPLYDAMAGE_OUTGOING_VERB_PARTICIPLE")
