@tool
extends Resource
class_name StatusTickComponent

@export var tick_component_id: String
@export var effect_intents: Array[EffectAndTargetIntent]

func are_ticking_conditions_met(_game_state: GameState) -> bool:
	return true

func to_json_dict() -> Dictionary:
	var intent_dicts: Array = []
	for intent in effect_intents:
		intent_dicts.append(intent.to_json_dict())
	return {"type": "StatusTickComponent", "tick_component_id": tick_component_id, "effect_intents": intent_dicts}

static func from_json_dict(data: Dictionary) -> StatusTickComponent:
	match data.get("type", ""):
		"DamageOverTime":
			return DamageOverTime.from_json_dict(data)
		"HealTargetEachTurn":
			return HealTargetEachTurn.from_json_dict(data)
		_:
			push_warning("Unsupported/unknown status_tick_component type in mod data: %s" % data.get("type", ""))
			return null

## Shared by subclasses that add no fields of their own beyond the base class's.
static func _new_with_shared_fields(data: Dictionary, component: StatusTickComponent) -> StatusTickComponent:
	component.tick_component_id = data.get("tick_component_id", "")
	for intent_data in data.get("effect_intents", []):
		var intent: EffectAndTargetIntent = EffectAndTargetIntent.from_json_dict(intent_data)
		if intent:
			component.effect_intents.append(intent)
	return component
