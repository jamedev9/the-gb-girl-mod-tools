@tool
extends TargetingRule
class_name TargetMostRecentlyEnteredOpponent

### The newest arrival is a single winner by definition - always exactly one target.
func targets_potentially_multiple() -> bool:
	return false

func get_description_segments() -> Array[DescriptionSegment]:
	return DescriptionBuilder.parse_template(tr("TARGETINGRULE_TARGETMOSTRECENTLYENTEREDOPPONENT_TEMPLATE"))
