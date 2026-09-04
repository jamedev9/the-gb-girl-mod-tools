@tool
extends Resource
class_name StatusModifierComponent

@export var status_modifer_component_id: String

func modify_context(_effect_context: EffectContext) -> void:
	pass

func to_json_dict() -> Dictionary:
	return {"type": "StatusModifierComponent", "status_modifer_component_id": status_modifer_component_id}

static func from_json_dict(data: Dictionary) -> StatusModifierComponent:
	match data.get("type", ""):
		"Status_ReducePlayerEnergy":
			return Status_ReducePlayerEnergy.from_json_dict(data)
		"Status_ChangeCostOfPlayingEventCards":
			return Status_ChangeCostOfPlayingEventCards.from_json_dict(data)
		_:
			push_warning("Unsupported/unknown status_modifier_component type in mod data: %s" % data.get("type", ""))
			return null
