@tool
extends EffectIntent
class_name Intent_RemovePassiveFromPlayer

@export var passive_id: String

func to_json_dict() -> Dictionary:
	var d := super.to_json_dict()
	d["type"] = "Intent_RemovePassiveFromPlayer"
	d["passive_id"] = passive_id
	return d

static func from_json_dict(data: Dictionary) -> Intent_RemovePassiveFromPlayer:
	var e := Intent_RemovePassiveFromPlayer.new()
	e.intent_effect_id = data.get("intent_effect_id", "")
	e.passive_id = data.get("passive_id", "")
	return e

func create_intent_context(game_state: GameState, _intent_context: EffectContext) -> EffectContext:
	var intent_context: TriggeredEffectContext = TriggeredEffectContext.new()
	intent_context.target = PlayerEntity.new(intent_context.game_state)
	intent_context.passive_to_remove_from_target = passive_id
	intent_context.id_of_effect_origin = intent_effect_id
	intent_context.effect_origin = self

	print("Returning context to remove player passive with id: %s" % passive_id)
	return intent_context
