@tool
extends EffectIntent
class_name HealForValueEffect

@export var healing: int

func to_json_dict() -> Dictionary:
	var d := super.to_json_dict()
	d["type"] = "HealForValueEffect"
	d["healing"] = healing
	return d

static func from_json_dict(data: Dictionary) -> HealForValueEffect:
	var e := HealForValueEffect.new()
	e.intent_effect_id = data.get("intent_effect_id", "")
	e.healing = int(data.get("healing", 0))
	return e

func create_intent_context(_game_state: GameState, _intent_context: EffectContext) -> EffectContext:
	var context = EffectContext.new()
	context.healing_amount = self.healing
	return context
