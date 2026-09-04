@tool
extends EffectIntent
class_name Intent_TriggerNOrgasmsAndResetPleasure

@export var orgasms_to_trigger: int

func to_json_dict() -> Dictionary:
	var d := super.to_json_dict()
	d["type"] = "Intent_TriggerNOrgasmsAndResetPleasure"
	d["orgasms_to_trigger"] = orgasms_to_trigger
	return d

static func from_json_dict(data: Dictionary) -> Intent_TriggerNOrgasmsAndResetPleasure:
	var e := Intent_TriggerNOrgasmsAndResetPleasure.new()
	e.intent_effect_id = data.get("intent_effect_id", "")
	e.orgasms_to_trigger = int(data.get("orgasms_to_trigger", 0))
	return e

func create_intent_context(_game_state: GameState, _intent_context: EffectContext) -> EffectContext:
	var context: EffectContext = EffectContext.new()

	context.orgasms_to_trigger = orgasms_to_trigger

	return context
