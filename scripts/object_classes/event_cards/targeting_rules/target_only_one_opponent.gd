@tool
extends TargetingRule
class_name OnlyOneOpponent

func to_json_dict() -> Dictionary:
	return {"type": "OnlyOneOpponent"}

static func from_json_dict(_data: Dictionary) -> OnlyOneOpponent:
	return OnlyOneOpponent.new()
