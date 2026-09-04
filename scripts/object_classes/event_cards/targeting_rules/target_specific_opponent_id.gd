@tool
extends TargetingRule
class_name TargetSpecificOpponentId
### This class is called in code, not in resource creation.

@export var unique_opponent_id: String

func to_json_dict() -> Dictionary:
	return {"type": "TargetSpecificOpponentId", "unique_opponent_id": unique_opponent_id}

static func from_json_dict(data: Dictionary) -> TargetSpecificOpponentId:
	var rule := TargetSpecificOpponentId.new()
	rule.unique_opponent_id = data.get("unique_opponent_id", "")
	return rule
