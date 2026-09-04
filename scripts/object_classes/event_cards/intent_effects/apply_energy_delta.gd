@tool
extends EffectIntent
class_name ApplyEnergyDelta

@export var energy_delta: int

func to_json_dict() -> Dictionary:
	var d := super.to_json_dict()
	d["type"] = "ApplyEnergyDelta"
	d["energy_delta"] = energy_delta
	return d

static func from_json_dict(data: Dictionary) -> ApplyEnergyDelta:
	var e := ApplyEnergyDelta.new()
	e.intent_effect_id = data.get("intent_effect_id", "")
	e.energy_delta = int(data.get("energy_delta", 0))
	return e

func create_intent_context(_game_state: GameState, _intent_context: EffectContext) -> EffectContext:
	var context: EffectContext = EffectContext.new()
	context.energy_delta = self.energy_delta
	context.energy_reason = EffectContext.EnergyReason.EVENT_CARD_EFFECT
	return context
