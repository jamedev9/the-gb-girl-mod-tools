@tool
extends TargetingRule
class_name TargetMustBeDifferentOpponentType

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(tr("TARGETINGRULE_TARGETMUSTBEDIFFERENTOPPONENTTYPE_TEMPLATE"))
