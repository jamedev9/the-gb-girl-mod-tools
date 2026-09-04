@tool
extends TargetingRule
class_name OpponentOfDifferentType

func to_json_dict() -> Dictionary:
	return {"type": "OpponentOfDifferentType"}

static func from_json_dict(_data: Dictionary) -> OpponentOfDifferentType:
	return OpponentOfDifferentType.new()
