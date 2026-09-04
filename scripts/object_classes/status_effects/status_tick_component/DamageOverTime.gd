@tool
extends StatusTickComponent
class_name DamageOverTime

func to_json_dict() -> Dictionary:
	var d := super.to_json_dict()
	d["type"] = "DamageOverTime"
	return d

static func from_json_dict(data: Dictionary) -> DamageOverTime:
	return StatusTickComponent._new_with_shared_fields(data, DamageOverTime.new())
