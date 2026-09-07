@tool
extends TargetingRule
class_name TargetsHaveLessThanNHealthLeft

@export var health_left_threshold: int

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(
		tr("TARGETINGRULE_TARGETSHAVELESSTHANNHEALTHLEFT_TEMPLATE"),
		{"threshold": str(health_left_threshold)})
