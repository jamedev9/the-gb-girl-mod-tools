@tool
extends StatusTickComponent
class_name HealTargetEachTurn

func to_json_dict() -> Dictionary:
	var d := super.to_json_dict()
	d["type"] = "HealTargetEachTurn"
	return d

static func from_json_dict(data: Dictionary) -> HealTargetEachTurn:
	return StatusTickComponent._new_with_shared_fields(data, HealTargetEachTurn.new())
