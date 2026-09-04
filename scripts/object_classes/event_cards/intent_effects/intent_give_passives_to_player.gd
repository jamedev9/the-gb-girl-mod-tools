@tool
extends EffectIntent
class_name Intent_GivePassivesToPlayer

@export var passive_ids: Array[String]

func to_json_dict() -> Dictionary:
	var d := super.to_json_dict()
	d["type"] = "Intent_GivePassivesToPlayer"
	d["passive_ids"] = passive_ids
	return d

static func from_json_dict(data: Dictionary) -> Intent_GivePassivesToPlayer:
	var e := Intent_GivePassivesToPlayer.new()
	e.intent_effect_id = data.get("intent_effect_id", "")
	var ids: Array[String] = []
	for id in data.get("passive_ids", []):
		ids.append(str(id))
	e.passive_ids = ids
	return e

func create_intent_context(game_state: GameState, _intent_context: EffectContext) -> EffectContext:
	var intent_context: TriggeredEffectContext = TriggeredEffectContext.new()
	intent_context.target = PlayerEntity.new(intent_context.game_state)
	intent_context.passives_to_add_to_target = passive_ids
	intent_context.id_of_effect_origin = intent_effect_id
	intent_context.effect_origin = self

	print("Returning context to remove player passive with id: %s" % passive_ids)
	return intent_context
