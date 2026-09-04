@tool
extends EffectIntent
class_name DrainPlayerEnergy

func to_json_dict() -> Dictionary:
	var d := super.to_json_dict()
	d["type"] = "DrainPlayerEnergy"
	return d

static func from_json_dict(data: Dictionary) -> DrainPlayerEnergy:
	var e := DrainPlayerEnergy.new()
	e.intent_effect_id = data.get("intent_effect_id", "")
	return e

func create_intent_context(game_state: GameState, _intent_context: EffectContext) -> EffectContext:
	var context: EffectContext = EffectContext.new()
	var player: PlayerEntity = PlayerEntity.new(game_state)
	var energy_to_drain: int = player.get_player_energy()

	context.energy_delta = energy_to_drain
	context.energy_reason = EffectContext.EnergyReason.EVENT_CARD_EFFECT

	return context
