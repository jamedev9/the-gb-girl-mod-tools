@tool
extends TargetingRule
class_name TargetCantBeAlly

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(tr("TARGETINGRULE_TARGETCANTBEALLY_TEMPLATE"))
