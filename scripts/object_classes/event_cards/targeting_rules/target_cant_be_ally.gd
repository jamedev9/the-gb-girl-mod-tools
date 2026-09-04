@tool
extends TargetingRule
class_name TargetCantBeAlly

func to_json_dict() -> Dictionary:
	return {"type": "TargetCantBeAlly"}

static func from_json_dict(_data: Dictionary) -> TargetCantBeAlly:
	return TargetCantBeAlly.new()
