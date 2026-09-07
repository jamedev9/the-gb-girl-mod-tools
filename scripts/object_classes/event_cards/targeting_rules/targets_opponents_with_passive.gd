@tool
extends TargetingRule
class_name TargetsOpponentsWithPassive

@export var passive_id: String

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("TARGETINGRULE_TARGETSOPPONENTSWITHPASSIVE_TEMPLATE"), {"passive_name": _passive_name_segment()})

### Nested reference (hover for what the passive actually does) rather than a plain name -
### matches ApplyStatusEffect._status_name_segment()'s pattern for status references.
func _passive_name_segment() -> DescriptionSegment:
	var passive_def: PassiveEffectDefinition = AutoloadDatabase.passive_effect_definitions.get(passive_id, null)
	if passive_def:
		return DescriptionSegment.nested_segment(passive_def.get_effect_name(), passive_def.get_description_segments())
	return DescriptionSegment.text_segment("?")
