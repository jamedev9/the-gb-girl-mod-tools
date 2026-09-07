@tool
extends StatusModifierComponent
class_name Modifier_PreventApplyingStatusEffects

func modify_context(context: EffectContext) -> void:
	context.target_is_immune_to_status_effects = true

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(tr("MODIFIER_PREVENTAPPLYINGSTATUSEFFECTS_TEMPLATE"))

