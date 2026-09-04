@tool
extends Resource
class_name EffectIntent

@export var intent_effect_id: String

func to_json_dict() -> Dictionary:
	return {"type": "EffectIntent", "intent_effect_id": intent_effect_id}

static func from_json_dict(data: Dictionary) -> EffectIntent:
	match data.get("type", ""):
		"DealDamageEffect":
			return DealDamageEffect.from_json_dict(data)
		"CardFlowEffect":
			return CardFlowEffect.from_json_dict(data)
		"ApplyStatusEffect":
			return ApplyStatusEffect.from_json_dict(data)
		_:
			push_warning("Unsupported/unknown intent_effect type in mod data: %s" % data.get("type", ""))
			return null

### This method is overwritten by child classes.
### This only changes the effect of a context, not the target or source.
func create_intent_context(_game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var context: EffectContext = EffectContext.new()
	return context
