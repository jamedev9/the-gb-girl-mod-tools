@tool
extends TargetingRule
class_name TargetMustBeSpecificOpponentType

@export var opponent_type_id: String

func to_json_dict() -> Dictionary:
	return {"type": "TargetMustBeSpecificOpponentType", "opponent_type_id": opponent_type_id}

static func from_json_dict(data: Dictionary) -> TargetMustBeSpecificOpponentType:
	var rule := TargetMustBeSpecificOpponentType.new()
	rule.opponent_type_id = data.get("opponent_type_id", "")
	return rule
