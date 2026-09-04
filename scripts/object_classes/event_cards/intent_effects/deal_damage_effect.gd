@tool
extends EffectIntent
class_name DealDamageEffect

@export var damage: int

func to_json_dict() -> Dictionary:
	var d := super.to_json_dict()
	d["type"] = "DealDamageEffect"
	d["damage"] = damage
	return d

static func from_json_dict(data: Dictionary) -> DealDamageEffect:
	var e := DealDamageEffect.new()
	e.intent_effect_id = data.get("intent_effect_id", "")
	e.damage = int(data.get("damage", 0))
	return e

func create_intent_context(_game_state:GameState,_intent_context: EffectContext) -> EffectContext:
	var context = EffectContext.new()
	context.damage_amount = self.damage
	return context
	
