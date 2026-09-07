@tool
extends TargetingRule
class_name TargetMustBeSpecificOpponentType

@export var opponent_type_id: String

func get_description_segments() -> Array[DescriptionSegment]:
	var opponent_type: OpponentType = AutoloadDatabase.opponent_types.get(opponent_type_id, null)
	var type_name: String = opponent_type.get_opponent_type_name() if opponent_type else "?"
	return DescriptionBuilder.parse_template(
		tr("TARGETINGRULE_TARGETMUSTBESPECIFICOPPONENTTYPE_TEMPLATE"), {"type_name": type_name})
