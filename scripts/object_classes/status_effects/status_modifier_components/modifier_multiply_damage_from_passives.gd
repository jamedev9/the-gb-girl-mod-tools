@tool
extends StatusModifierComponent
class_name Modifier_MultiplyDamageFromPassives

@export var passive_ids: Array[String] = []
@export var damage_multiplier: float

### Checks context.passive_sending_context, NOT effect_origin/id_of_effect_origin - those get
### overwritten to the triggered EffectIntent's own identity by
### main_cardgame.gd's _make_effect_intent_context_without_target() before this modifier ever
### runs, so "effect_origin is PassiveEffectDefinition" can never be true for a triggered
### passive's damage (which is the only kind of damage a passive ever deals). See
### passive_sending_context's other write site in status_effect_manager.gd for the ticking half.
func modify_context(context: EffectContext) -> void:
	if not context.passive_sending_context:
		return
	if context.passive_sending_context.passive_id not in passive_ids:
		return
	if context.source == context.target:
		return

	context.damage_multipliers.append(self.damage_multiplier)

### See DescriptionBuilder.classify_percent_multiplier() for the blocked/increased/reduced/
### inverted cases.
func get_description_segments() -> Array[DescriptionSegment]:
	var names: String = _passive_names(passive_ids)
	var classification: Dictionary = DescriptionBuilder.classify_percent_multiplier(damage_multiplier)
	match classification.case:
		"blocked":
			return DescriptionBuilder.parse_template(tr("MODIFIER_MULTIPLYDAMAGEFROMPASSIVES_BLOCKED_TEMPLATE"), {"names": names})
		"inverted":
			return DescriptionBuilder.parse_template(tr("MODIFIER_MULTIPLYDAMAGEFROMPASSIVES_INVERTED_TEMPLATE"), {"names": names})
		"inverted_scaled":
			return DescriptionBuilder.parse_template(tr("MODIFIER_MULTIPLYDAMAGEFROMPASSIVES_INVERTED_SCALED_TEMPLATE"), {"names": names, "percent": str(classification.percent)})
		"increased":
			return DescriptionBuilder.parse_template(tr("MODIFIER_MULTIPLYDAMAGEFROMPASSIVES_INCREASE_TEMPLATE"), {"names": names, "percent": str(classification.percent)})
		_: ### "reduced"
			return DescriptionBuilder.parse_template(tr("MODIFIER_MULTIPLYDAMAGEFROMPASSIVES_REDUCE_TEMPLATE"), {"names": names, "percent": str(classification.percent)})
