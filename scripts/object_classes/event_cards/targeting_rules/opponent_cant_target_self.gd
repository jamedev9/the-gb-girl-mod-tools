@tool
extends TargetingRule
class_name OpponentCantTargetSelf

func to_json_dict() -> Dictionary:
	return {"type": "OpponentCantTargetSelf"}

static func from_json_dict(_data: Dictionary) -> OpponentCantTargetSelf:
	return OpponentCantTargetSelf.new()
