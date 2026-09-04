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

### No concrete StatusTickComponent subclasses exist yet - this dispatch is here so any
### subclass added later only needs a case added here, matching the pattern used by
### EffectIntent/TargetingRule/StatusModifierComponent.
static func from_json_dict(data: Dictionary) -> StatusTickComponent:
	match data.get("type", ""):
		_:
			push_warning("Unsupported/unknown status_tick_component type in mod data: %s" % data.get("type", ""))
			return null
